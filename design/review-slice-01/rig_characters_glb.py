import json
import math
import os
import struct
import numpy as np

MODELS_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"


def read_glb(path):
    with open(path, "rb") as f:
        magic, ver, length = struct.unpack("<4sII", f.read(12))
        assert magic == b"glTF", f"Not a GLB: {path}"
        j_len, j_type = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(j_len).decode("utf-8"))
        b_len, b_type = struct.unpack("<II", f.read(8))
        bin_data = f.read(b_len)
    return gltf, bin_data


def read_accessor(gltf, bin_data, acc_idx):
    acc = gltf["accessors"][acc_idx]
    bv = gltf["bufferViews"][acc["bufferView"]]
    offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    comp_map = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
    type_cnt = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    dtype = comp_map[acc["componentType"]]
    ncomp = type_cnt[acc["type"]]
    arr = np.frombuffer(bin_data, dtype=dtype, count=count * ncomp, offset=offset)
    if ncomp > 1:
        arr = arr.reshape((count, ncomp))
    return arr.copy()


def euler_xyz_to_quat(rx, ry, rz):
    # Returns [x, y, z, w] glTF quaternion
    cx, sx = math.cos(rx * 0.5), math.sin(rx * 0.5)
    cy, sy = math.cos(ry * 0.5), math.sin(ry * 0.5)
    cz, sz = math.cos(rz * 0.5), math.sin(rz * 0.5)
    qx = sx * cy * cz + cx * sy * sz
    qy = cx * sy * cz - sx * cy * sz
    qz = cx * cy * sz + sx * sy * cz
    qw = cx * cy * cz - sx * sy * sz
    n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    return [qx / n, qy / n, qz / n, qw / n]


def dist_point_to_segment(pts, a, b):
    ab = b - a
    ab_len2 = float(np.dot(ab, ab))
    if ab_len2 < 1e-8:
        return np.linalg.norm(pts - a, axis=1)
    t = np.clip(np.dot(pts - a, ab) / ab_len2, 0.0, 1.0)
    proj = a + t[:, None] * ab[None, :]
    return np.linalg.norm(pts - proj, axis=1)


def compute_skin_weights(pos, bone_specs):
    """
    Compute smooth anatomical 4-bone weights for normalized humanoid mesh (Y in [0, 1], X shoulders, +Z forward).
    bone_specs: list of (name, parent_idx, head_xyz, tail_xyz, radius_scale)
    """
    n_verts = pos.shape[0]
    n_bones = len(bone_specs)
    weights_all = np.zeros((n_verts, n_bones), dtype=np.float32)

    x = pos[:, 0]
    y = pos[:, 1]

    for bi, (name, parent, head, tail, rad) in enumerate(bone_specs):
        if bi == 0:
            # Root bone stays identity; Hips carries base weight
            continue
        d = dist_point_to_segment(pos, np.array(head, dtype=np.float32), np.array(tail, dtype=np.float32))
        sigma = rad
        w = np.exp(-0.5 * (d / sigma) ** 2)

        # Anatomical masks so arms don't pull torso and legs don't pull arms
        if "Arm" in name or "Forearm" in name:
            side = 1.0 if name.endswith("_L") else -1.0
            arm_mask = np.clip((x * side - 0.075) / 0.05, 0.0, 1.0) * np.clip((y - 0.36) / 0.12, 0.0, 1.0)
            w *= arm_mask
        elif "Thigh" in name or "Shin" in name:
            side = 1.0 if name.endswith("_L") else -1.0
            # Soft left/right split so linen robe hem deforms smoothly without tearing!
            side_mask = 1.0 / (1.0 + np.exp(-(x * side) / 0.045))
            lower_mask = np.clip((0.52 - y) / 0.10, 0.0, 1.0)
            w *= side_mask * lower_mask
        elif name in ("Neck", "Head"):
            head_mask = np.clip((y - 0.74) / 0.06, 0.0, 1.0)
            w *= head_mask
        elif name in ("Spine", "Chest"):
            torso_mask = np.clip((y - 0.42) / 0.10, 0.0, 1.0) * np.clip((0.86 - y) / 0.08, 0.0, 1.0)
            torso_mask *= np.clip((0.15 - np.abs(x)) / 0.06, 0.15, 1.0)
            w *= torso_mask
        elif name == "Hips":
            hip_mask = np.clip((0.64 - y) / 0.14, 0.0, 1.0) * np.clip((y - 0.28) / 0.14, 0.25, 1.0)
            w *= hip_mask

        weights_all[:, bi] = w

    # Ensure every vertex has non-zero total weight (fallback to Hips=1)
    row_sums = weights_all.sum(axis=1)
    zero_mask = row_sums < 1e-6
    weights_all[zero_mask, 1] = 1.0

    # Keep top 4 influences per vertex & normalize
    top4_idx = np.argsort(-weights_all, axis=1)[:, :4]
    top4_w = np.take_along_axis(weights_all, top4_idx, axis=1)
    top4_w = top4_w / np.maximum(top4_w.sum(axis=1, keepdims=True), 1e-8)

    return top4_idx.astype(np.uint8), top4_w.astype(np.float32)


def build_animations(bone_specs, is_sarai=False):
    """
    Generate 3 smooth looping skeletal animations: Idle (3.0s), Walk (0.96s), Pray (2.4s).
    Returns list of (anim_name, duration, times_array, channel_dict)
    where channel_dict maps (bone_idx, path) -> list of values per keyframe.
    """
    anims = []
    # 1. Idle (gentle breathing, subtle head look, relaxed arms)
    n_k = 25
    dur_idle = 3.0
    times_idle = np.linspace(0.0, dur_idle, n_k, dtype=np.float32)
    ch_idle = {}
    phase_off = 1.1 if is_sarai else 0.0
    for k, t in enumerate(times_idle):
        ph = (t / dur_idle) * math.tau + phase_off
        s1 = math.sin(ph)
        s2 = math.sin(ph * 0.5)
        # Hips subtle breath bob
        hips_base = bone_specs[1][2]
        ch_idle.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] + s1 * 0.006, hips_base[2]])
        ch_idle.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(0.0, s1 * 0.035, 0.0))
        ch_idle.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(s1 * 0.028, 0.0, 0.0))
        ch_idle.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(s1 * 0.035, -s1 * 0.025, 0.0))
        ch_idle.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(s1 * 0.03, math.sin(ph) * 0.14, 0.0))
        # Subtle breathing sway on arms
        ch_idle.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(s1 * 0.04, 0.0, -0.05 - s1 * 0.025))
        ch_idle.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-s1 * 0.04, 0.0, 0.05 + s1 * 0.025))
        ch_idle.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.08 + s1 * 0.04, 0.0, 0.0))
        ch_idle.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-0.08 - s1 * 0.04, 0.0, 0.0))
    anims.append(("Idle", dur_idle, times_idle, ch_idle))

    # 2. Walk (expressive miniature-strategy stride — natural FORWARD lean for -Z facing!)
    n_w = 25
    dur_walk = 0.96
    times_walk = np.linspace(0.0, dur_walk, n_w, dtype=np.float32)
    ch_walk = {}
    hips_base = bone_specs[1][2]
    for k, t in enumerate(times_walk):
        ph = (t / dur_walk) * math.tau
        s = math.sin(ph)
        c = math.cos(ph)
        bob = abs(math.sin(ph)) * 0.022
        ch_walk.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] + bob, hips_base[2]])
        # Negative X pitch leans FORWARD when character faces -Z!
        ch_walk.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.04, s * 0.10, -s * 0.035))
        ch_walk.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.06, -s * 0.08, s * 0.025))
        ch_walk.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.05, -s * 0.11, 0.0))
        ch_walk.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.05, s * 0.05, 0.0))
        # Legs alternating stride (around X axis)
        ch_walk.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-s * 0.42, 0.0, 0.0))
        ch_walk.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(max(0.0, c) * 0.34, 0.0, 0.0))
        ch_walk.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(s * 0.42, 0.0, 0.0))
        ch_walk.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(max(0.0, -c) * 0.34, 0.0, 0.0))
        # Counter-swinging arms
        ch_walk.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(s * 0.40, 0.0, -0.05))
        ch_walk.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.20 + max(0.0, -s) * 0.16, 0.0, 0.0))
        ch_walk.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-s * 0.40, 0.0, 0.05))
        ch_walk.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.20 + max(0.0, s) * 0.16, 0.0, 0.0))
    anims.append(("Walk", dur_walk, times_walk, ch_walk))

    # 3. Pray (reverent Bronze Age Hebrew KNEELING & BOWING prayer at the altar — true 跪拜动作!)
    n_p = 25
    dur_pray = 2.6
    times_pray = np.linspace(0.0, dur_pray, n_p, dtype=np.float32)
    ch_pray = {}
    for k, t in enumerate(times_pray):
        ph = (t / dur_pray) * math.tau
        sway = math.sin(ph) * 0.045
        # Drop Hips down to kneeling height (0.46 -> 0.24)
        ch_pray.setdefault((1, "translation"), []).append([hips_base[0], 0.24 + sway * 0.08, hips_base[2] - 0.04])
        # Kneeling thighs forward, shins folded back
        ch_pray.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-1.15, 0.0, 0.04))
        ch_pray.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(1.55, 0.0, 0.0))
        ch_pray.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(-1.15, 0.0, -0.04))
        ch_pray.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(1.55, 0.0, 0.0))
        # Humble forward bow of Spine, Chest & Head (-X pitch leans forward for -Z facing!)
        ch_pray.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.34 - sway * 0.5, 0.0, 0.0))
        ch_pray.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.28 - sway * 0.5, 0.0, 0.0))
        ch_pray.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(-0.26 - sway * 0.6, 0.0, 0.0))
        # Arms lifted forward in reverent prayer / offering
        ch_pray.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(0.68 + sway, -0.18, -0.10))
        ch_pray.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.56 + sway, -0.12, 0.0))
        ch_pray.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(0.68 + sway, 0.18, 0.10))
        ch_pray.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.56 + sway, 0.12, 0.0))
    anims.append(("Pray", dur_pray, times_pray, ch_pray))

    # 4. Hammer (rhythmic carpentry mallet swing for keel mortise & hull planking)
    n_h = 25
    dur_ham = 1.15
    times_ham = np.linspace(0.0, dur_ham, n_h, dtype=np.float32)
    ch_ham = {}
    for k, t in enumerate(times_ham):
        ph = (t / dur_ham) * math.tau
        strike = math.sin(ph)
        # Slight forward brace stance
        ch_ham.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.03 + max(0.0, strike) * 0.015, hips_base[2]])
        ch_ham.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.08, -0.14 + strike * 0.12, 0.0))
        ch_ham.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.14 - strike * 0.12, -0.10 + strike * 0.16, 0.0))
        ch_ham.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.10 - strike * 0.10, -0.08 + strike * 0.12, 0.0))
        ch_ham.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(-0.12, 0.06, 0.0))
        # Right arm (8=UpperArm_R, 9=LowerArm_R) raises high and strikes down cleanly
        ch_ham.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-0.55 - strike * 0.85, 0.08, 0.18))
        ch_ham.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-0.50 - max(0.0, strike) * 0.55, 0.0, 0.0))
        # Left arm (6=UpperArm_L, 7=LowerArm_L) steadies timber peg
        ch_ham.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-0.45, -0.15, -0.12))
        ch_ham.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.42, 0.0, 0.0))
    anims.append(("Hammer", dur_ham, times_ham, ch_ham))

    # 5. BrushPitch (stooped sweeping stroke applying hot bitumen/pitch to hull seams)
    n_b = 25
    dur_br = 1.6
    times_br = np.linspace(0.0, dur_br, n_b, dtype=np.float32)
    ch_br = {}
    for k, t in enumerate(times_br):
        ph = (t / dur_br) * math.tau
        sweep = math.sin(ph)
        ch_br.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.05, hips_base[2]])
        ch_br.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.24, sweep * 0.18, 0.0))
        ch_br.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.18, sweep * 0.22, 0.0))
        ch_br.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(-0.16, sweep * 0.10, 0.0))
        ch_br.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-0.72 + sweep * 0.25, sweep * 0.38, 0.12))
        ch_br.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-0.35 + sweep * 0.18, 0.0, 0.0))
        ch_br.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-0.35, -0.12, -0.10))
        ch_br.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.25, 0.0, 0.0))
    anims.append(("BrushPitch", dur_br, times_br, ch_br))

    # 6. Bless (exact 00_prologue_noah_ark_final.png thanksgiving pose: upright, head lifted skyward, both arms raised!)
    n_bl = 25
    dur_bl = 3.2
    times_bl = np.linspace(0.0, dur_bl, n_bl, dtype=np.float32)
    ch_bl = {}
    for k, t in enumerate(times_bl):
        ph = (t / dur_bl) * math.tau
        sway = math.sin(ph) * 0.04
        ch_bl.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] + sway * 0.12, hips_base[2]])
        ch_bl.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(0.05 + sway * 0.3, 0.0, 0.0))
        ch_bl.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(0.08 + sway * 0.3, 0.0, 0.0))
        ch_bl.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.24 + sway * 0.4, sway * 0.5, 0.0))
        # Both arms raised outward & upward toward the Rainbow Covenant
        ch_bl.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-1.15 - sway, -0.25, -0.45))
        ch_bl.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.48 - sway * 0.5, 0.0, 0.0))
        ch_bl.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-1.15 - sway, 0.25, 0.45))
        ch_bl.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-0.48 - sway * 0.5, 0.0, 0.0))
    anims.append(("Bless", dur_bl, times_bl, ch_bl))

    return anims


def rig_glb(in_path, out_path, is_sarai=False):
    gltf, bin_data = read_glb(in_path)
    prim = gltf["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]

    pos = read_accessor(gltf, bin_data, attrs["POSITION"]).astype(np.float32)
    uv = read_accessor(gltf, bin_data, attrs["TEXCOORD_0"]).astype(np.float32)
    idx = read_accessor(gltf, bin_data, prim["indices"]).astype(np.uint32)
    if "NORMAL" in attrs:
        nrm = read_accessor(gltf, bin_data, attrs["NORMAL"]).astype(np.float32)
    else:
        # Compute smooth area-weighted vertex normals from triangle faces
        tris = idx.reshape(-1, 3)
        v0, v1, v2 = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
        fn = np.cross(v1 - v0, v2 - v0)
        nrm = np.zeros_like(pos, dtype=np.float32)
        np.add.at(nrm, tris[:, 0], fn)
        np.add.at(nrm, tris[:, 1], fn)
        np.add.at(nrm, tris[:, 2], fn)
        nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-8)

    # Rotate +90 deg around Y so character faces +Z (TripoSR faces +X, shoulders along Z -> shoulders along X)
    # x' = z, y' = y, z' = -x
    pos_r = np.stack([pos[:, 2], pos[:, 1], -pos[:, 0]], axis=1)
    nrm_r = np.stack([nrm[:, 2], nrm[:, 1], -nrm[:, 0]], axis=1)
    nrm_len = np.maximum(np.linalg.norm(nrm_r, axis=1, keepdims=True), 1e-8)
    nrm_r = nrm_r / nrm_len

    # Normalize so feet sit at Y=0.0, height = 1.0, centered at X=0, Z=0
    pmin = pos_r.min(axis=0)
    pmax = pos_r.max(axis=0)
    h = float(pmax[1] - pmin[1])
    cx = float((pmin[0] + pmax[0]) * 0.5)
    cz = float((pmin[2] + pmax[2]) * 0.5)
    pos_n = np.stack([
        (pos_r[:, 0] - cx) / h,
        (pos_r[:, 1] - pmin[1]) / h,
        (pos_r[:, 2] - cz) / h,
    ], axis=1).astype(np.float32)

    # Extract embedded baseColor image bytes & mimeType
    img_bytes = None
    img_mime = "image/png"
    if gltf.get("images"):
        img = gltf["images"][0]
        img_mime = img.get("mimeType", "image/png")
        ibv = gltf["bufferViews"][img["bufferView"]]
        ioff = ibv.get("byteOffset", 0)
        img_bytes = bin_data[ioff:ioff + ibv["byteLength"]]

    # 14-bone Humanoid Skeleton (Y in [0, 1], shoulders along +-X, +Z forward)
    # (name, parent_idx, head_xyz, tail_xyz, sigma)
    bone_specs = [
        ("Root",       -1, [0.00, 0.00, 0.00], [0.00, 0.05, 0.00], 0.05),
        ("Hips",        0, [0.00, 0.46, 0.00], [0.00, 0.56, 0.00], 0.14),
        ("Spine",       1, [0.00, 0.58, 0.00], [0.00, 0.69, 0.00], 0.13),
        ("Chest",       2, [0.00, 0.70, 0.00], [0.00, 0.80, 0.00], 0.13),
        ("Neck",        3, [0.00, 0.81, 0.00], [0.00, 0.86, 0.00], 0.08),
        ("Head",        4, [0.00, 0.87, 0.00], [0.00, 0.99, 0.00], 0.11),
        ("UpperArm_L",  3, [0.11, 0.75, 0.00], [0.17, 0.61, 0.00], 0.09),
        ("Forearm_L",   6, [0.17, 0.61, 0.00], [0.22, 0.44, 0.00], 0.09),
        ("UpperArm_R",  3, [-0.11, 0.75, 0.00], [-0.17, 0.61, 0.00], 0.09),
        ("Forearm_R",   8, [-0.17, 0.61, 0.00], [-0.22, 0.44, 0.00], 0.09),
        ("Thigh_L",     1, [0.06, 0.45, 0.00], [0.06, 0.24, 0.00], 0.12),
        ("Shin_L",     10, [0.06, 0.24, 0.00], [0.06, 0.02, 0.00], 0.12),
        ("Thigh_R",     1, [-0.06, 0.45, 0.00], [-0.06, 0.24, 0.00], 0.12),
        ("Shin_R",     12, [-0.06, 0.24, 0.00], [-0.06, 0.02, 0.00], 0.12),
    ]

    joints_u8, weights_f32 = compute_skin_weights(pos_n, bone_specs)

    # Inverse bind matrices (translation-only bind pose -> inverse is translate(-head_xyz), column-major!)
    ibm_list = []
    for _, _, head, _, _ in bone_specs:
        m = np.eye(4, dtype=np.float32)
        m[0, 3] = -head[0]
        m[1, 3] = -head[1]
        m[2, 3] = -head[2]
        # glTF stores matrices in column-major order
        ibm_list.append(m.T.reshape(-1))
    ibm_arr = np.concatenate(ibm_list).astype(np.float32)

    # Build binary buffer & glTF structures
    buf = bytearray()
    buffer_views = []
    accessors = []

    def add_bv(raw_bytes, target=None):
        while len(buf) % 4 != 0:
            buf.append(0)
        off = len(buf)
        buf.extend(raw_bytes)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": len(raw_bytes)}
        if target is not None:
            bv["target"] = target
        bv_idx = len(buffer_views)
        buffer_views.append(bv)
        return bv_idx

    def add_acc(arr, comp_type, acc_type, target=None, with_minmax=False):
        bv_idx = add_bv(arr.tobytes(), target=target)
        acc = {
            "bufferView": bv_idx,
            "componentType": comp_type,
            "count": int(arr.shape[0]),
            "type": acc_type,
        }
        if with_minmax:
            if arr.ndim == 1:
                acc["min"] = [float(arr.min())]
                acc["max"] = [float(arr.max())]
            else:
                acc["min"] = [float(v) for v in arr.min(axis=0)]
                acc["max"] = [float(v) for v in arr.max(axis=0)]
        acc_idx = len(accessors)
        accessors.append(acc)
        return acc_idx

    acc_pos = add_acc(pos_n, 5126, "VEC3", target=34962, with_minmax=True)
    acc_nrm = add_acc(nrm_r.astype(np.float32), 5126, "VEC3", target=34962)
    acc_uv = add_acc(uv.astype(np.float32), 5126, "VEC2", target=34962)
    acc_jnt = add_acc(joints_u8, 5121, "VEC4", target=34962)
    acc_wgt = add_acc(weights_f32, 5126, "VEC4", target=34962)
    acc_idx = add_acc(idx, 5125, "SCALAR", target=34963)
    acc_ibm = add_acc(ibm_arr.reshape((len(bone_specs), 16)), 5126, "MAT4")

    # Image + Texture + Material
    images = []
    textures = []
    samplers = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    pbr = {"metallicFactor": 0.0, "roughnessFactor": 0.85}
    if img_bytes is not None:
        img_bv = add_bv(img_bytes)
        images.append({"bufferView": img_bv, "mimeType": img_mime})
        textures.append({"sampler": 0, "source": 0})
        pbr["baseColorTexture"] = {"index": 0}
    materials = [{"name": "CharacterLinenPBR", "pbrMetallicRoughness": pbr, "doubleSided": True}]

    # Nodes: 0 = CharacterRoot, 1 = SkinnedMesh, 2..(2+N-1) = Skeleton joints
    nodes = [
        {"name": "CharacterRoot", "children": [1, 2]},
        {"name": "CharacterMesh", "mesh": 0, "skin": 0},
    ]
    joint_node_offset = 2
    joint_nodes = []
    for bi, (bname, parent, head, _, _) in enumerate(bone_specs):
        if parent == -1:
            rel = head
        else:
            phead = bone_specs[parent][2]
            rel = [head[0] - phead[0], head[1] - phead[1], head[2] - phead[2]]
        n_dict = {"name": bname, "translation": [round(v, 5) for v in rel]}
        children = [joint_node_offset + ci for ci, (_, cp, _, _, _) in enumerate(bone_specs) if cp == bi]
        if children:
            n_dict["children"] = children
        joint_nodes.append(joint_node_offset + bi)
        nodes.append(n_dict)

    # Animations
    raw_anims = build_animations(bone_specs, is_sarai=is_sarai)
    gltf_anims = []
    for anim_name, dur, times, ch_dict in raw_anims:
        acc_time = add_acc(times, 5126, "SCALAR", with_minmax=True)
        anim_samplers = []
        anim_channels = []
        for (bi, path), vals in ch_dict.items():
            val_arr = np.array(vals, dtype=np.float32)
            vtype = "VEC4" if path == "rotation" else "VEC3"
            acc_val = add_acc(val_arr, 5126, vtype)
            s_idx = len(anim_samplers)
            anim_samplers.append({"input": acc_time, "interpolation": "LINEAR", "output": acc_val})
            anim_channels.append({
                "sampler": s_idx,
                "target": {"node": joint_node_offset + bi, "path": path},
            })
        gltf_anims.append({"name": anim_name, "channels": anim_channels, "samplers": anim_samplers})

    while len(buf) % 4 != 0:
        buf.append(0)

    out_gltf = {
        "asset": {"version": "2.0", "generator": "PathOfPromise-AutoRigger"},
        "scene": 0,
        "scenes": [{"name": "CharacterScene", "nodes": [0]}],
        "nodes": nodes,
        "meshes": [{
            "name": "CharacterMesh",
            "primitives": [{
                "attributes": {
                    "POSITION": acc_pos,
                    "NORMAL": acc_nrm,
                    "TEXCOORD_0": acc_uv,
                    "JOINTS_0": acc_jnt,
                    "WEIGHTS_0": acc_wgt,
                },
                "indices": acc_idx,
                "material": 0,
            }],
        }],
        "skins": [{
            "name": "HumanoidSkeleton14",
            "inverseBindMatrices": acc_ibm,
            "skeleton": joint_node_offset,
            "joints": joint_nodes,
        }],
        "animations": gltf_anims,
        "materials": materials,
        "samplers": samplers,
        "textures": textures,
        "images": images,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(buf)}],
    }

    j_bytes = json.dumps(out_gltf, separators=(",", ":")).encode("utf-8")
    while len(j_bytes) % 4 != 0:
        j_bytes += b" "

    total_len = 12 + 8 + len(j_bytes) + 8 + len(buf)
    with open(out_path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total_len))
        f.write(struct.pack("<II", len(j_bytes), 0x4E4F534A))
        f.write(j_bytes)
        f.write(struct.pack("<II", len(buf), 0x004E4942))
        f.write(buf)
    print(f"OK RIGGED {os.path.basename(out_path)}: {len(pos_n)} verts, {len(bone_specs)} bones, {len(gltf_anims)} anims ({[a['name'] for a in gltf_anims]}), {total_len/1024:.1f} KB")


if __name__ == "__main__":
    rig_glb(os.path.join(MODELS_DIR, "CHR_Abram.glb"), os.path.join(MODELS_DIR, "CHR_Abram_rigged.glb"), is_sarai=False)
    rig_glb(os.path.join(MODELS_DIR, "CHR_Sarai.glb"), os.path.join(MODELS_DIR, "CHR_Sarai_rigged.glb"), is_sarai=True)
