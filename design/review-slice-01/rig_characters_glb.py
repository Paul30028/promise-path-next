import io
import json
import math
import os
import struct
import numpy as np
from PIL import Image

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


def clean_foot_cutout_bleed(pos_n, uv, idx, img_bytes):
    """
    Remove uncleaned white/cool-gray studio backdrop cutout bleed around character feet & sandals:
    1) Removes pure studio-gray floor sliver triangles below Y=0.045;
    2) Repaints cool-gray/white cutout texels mapped to feet (Y < 0.145) into authentic warm
       ancient leather sandal & dark linen hem tones with 3px UV margin dilation!
    """
    if img_bytes is None:
        return pos_n, idx, img_bytes
    im = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    arr = np.array(im, dtype=np.float32) / 255.0
    H, W, _ = arr.shape

    low = pos_n[:, 1] < 0.145
    if not np.any(low):
        return pos_n, idx, img_bytes

    u_all = np.clip((uv[:, 0] * W).astype(np.int32), 0, W - 1)
    v_all = np.clip((uv[:, 1] * H).astype(np.int32), 0, H - 1)
    cols = arr[v_all, u_all]
    luma = cols.mean(axis=1)
    sat = cols.max(axis=1) - cols.min(axis=1)
    # Studio cutout bleed is cool-gray or bright near-white (B >= R - 0.06, low saturation)
    is_bleed_v = low & (
        ((luma > 0.48) & (sat < 0.18) & (cols[:, 2] >= cols[:, 0] - 0.05))
        | ((luma > 0.68) & (sat < 0.18))
    )

    tris = idx.reshape(-1, 3)
    tri_y = pos_n[tris][:, :, 1].mean(axis=1)
    # Drop pure flat studio-floor sliver triangles right at the bottom sole (Y < 0.045)
    tri_all_bleed = is_bleed_v[tris].all(axis=1) & (tri_y < 0.045)
    if np.any(tri_all_bleed):
        tris = tris[~tri_all_bleed]

    # Re-ground lowest remaining vertex to Y = 0.0
    used_verts = np.unique(tris)
    min_y = float(pos_n[used_verts, 1].min())
    if min_y > 1e-4:
        pos_n = pos_n.copy()
        pos_n[:, 1] -= min_y

    # Build a UV mask of all pixels near low-foot bleed vertices (dilated 4px for crisp edge cleanup!)
    bleed_idx = np.where(is_bleed_v)[0]
    if len(bleed_idx) > 0:
        mask = np.zeros((H, W), dtype=bool)
        bu = u_all[bleed_idx]
        bv = v_all[bleed_idx]
        for dy in range(-5, 6):
            yy = np.clip(bv + dy, 0, H - 1)
            for dx in range(-5, 6):
                xx = np.clip(bu + dx, 0, W - 1)
                mask[yy, xx] = True
        # Within the foot UV neighborhood, repaint all bright/cool-gray pixels to warm leather/robe shadow
        px_luma = arr.mean(axis=2)
        px_sat = arr.max(axis=2) - arr.min(axis=2)
        px_cool = (px_luma > 0.46) & (px_sat < 0.20) & (arr[:, :, 2] >= arr[:, :, 0] - 0.06)
        px_white = (px_luma > 0.64) & (px_sat < 0.20)
        repaint = mask & (px_cool | px_white)
        if np.any(repaint):
            # Subtle organic shade variation based on original pixel luminance (warm dark sandal/hem brown)
            shade = np.clip(0.72 + (px_luma[repaint] - 0.55) * 0.45, 0.55, 0.92)
            arr[repaint, 0] = 0.37 * shade
            arr[repaint, 1] = 0.27 * shade
            arr[repaint, 2] = 0.18 * shade
            out_im = Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).astype(np.uint8), mode="RGB")
            bio = io.BytesIO()
            out_im.save(bio, format="PNG")
            img_bytes = bio.getvalue()
            print(f"   Cleaned foot cutout bleed: {int(tri_all_bleed.sum())} floor tris dropped, {int(repaint.sum())} UV texels repainted")

    return pos_n, tris.reshape(-1).astype(np.uint32), img_bytes


def separate_lower_legs_mesh(pos_n, nrm_r, uv, idx, is_sarai=False):
    """
    Physically separate fused TripoSR left/right feet & lower legs so there are ZERO
    bridging/webbed triangles crossing X=0 when characters walk or run!
    Also pushes inner-ankle vertices gently apart around X=0 so both feet read cleanly.
    """
    tris = idx.reshape(-1, 3)
    # Split threshold height: men's tunics split cleanly below knee/mid-thigh (0.34),
    # women's long robes split below lower shin/ankle (0.20) so both sandaled feet step cleanly!
    split_y = 0.20 if is_sarai else 0.34
    foot_y = 0.16

    v_tri = pos_n[tris]  # (T, 3, 3)
    tri_y = v_tri[:, :, 1].mean(axis=1)
    tri_xmin = v_tri[:, :, 0].min(axis=1)
    tri_xmax = v_tri[:, :, 0].max(axis=1)

    # 1. Drop bridging triangles that span across X=0 in the lower leg / foot zone
    crosses_center = (tri_xmin < -0.001) & (tri_xmax > 0.001) & (tri_y < split_y)
    # Also remove very thin centerline slivers right between the two ankles/feet
    center_sliver = (tri_y < foot_y) & (np.abs(v_tri[:, :, 0].mean(axis=1)) < 0.014)
    keep = ~(crosses_center | center_sliver)
    tris_clean = tris[keep]

    # 2. Gently carve a crisp natural air gap between the inner left and right ankles/feet
    pos_out = pos_n.copy()
    x = pos_out[:, 0]
    y = pos_out[:, 1]
    in_foot_gap = (y < split_y) & (np.abs(x) < 0.036)
    if np.any(in_foot_gap):
        # Smooth ramp: strongest separation at feet (Y=0..0.16), tapering smoothly to 0 at split_y
        t_h = np.clip((split_y - y[in_foot_gap]) / max(split_y - 0.06, 0.05), 0.0, 1.0)
        signs = np.where(x[in_foot_gap] >= 0.0, 1.0, -1.0)
        min_gap = 0.024 * t_h
        cur_abs = np.abs(x[in_foot_gap])
        push = np.maximum(0.0, min_gap - cur_abs)
        pos_out[in_foot_gap, 0] = x[in_foot_gap] + signs * push

    return pos_out, nrm_r, uv, tris_clean.reshape(-1).astype(np.uint32)


def compute_skin_weights(pos, bone_specs, is_sarai=False):
    """
    Compute anatomical 4-bone weights with STRICT left/right leg isolation so
    left and right feet stride completely independently with ZERO cross-leg glue!
    bone_specs: list of (name, parent_idx, head_xyz, tail_xyz, radius_scale)
    """
    n_verts = pos.shape[0]
    n_bones = len(bone_specs)
    weights_all = np.zeros((n_verts, n_bones), dtype=np.float32)

    x = pos[:, 0]
    y = pos[:, 1]
    split_y = 0.22 if is_sarai else 0.36

    for bi, (name, parent, head, tail, rad) in enumerate(bone_specs):
        if bi == 0:
            continue
        d = dist_point_to_segment(pos, np.array(head, dtype=np.float32), np.array(tail, dtype=np.float32))
        sigma = rad
        w = np.exp(-0.5 * (d / sigma) ** 2)

        if "Arm" in name or "Forearm" in name:
            side = 1.0 if name.endswith("_L") else -1.0
            arm_mask = np.clip((x * side - 0.075) / 0.045, 0.0, 1.0) * np.clip((y - 0.36) / 0.10, 0.0, 1.0)
            w *= arm_mask
        elif "Thigh" in name or "Shin" in name:
            side = 1.0 if name.endswith("_L") else -1.0
            # HARD side isolation below split_y so Left Foot NEVER receives Right Leg weight (and vice versa!)
            hard_side = (x * side >= 0.0).astype(np.float32)
            soft_side = 1.0 / (1.0 + np.exp(-(x * side) / 0.022))
            blend_t = np.clip((y - split_y) / 0.10, 0.0, 1.0)
            side_mask = hard_side * (1.0 - blend_t) + soft_side * blend_t
            lower_mask = np.clip((0.48 - y) / 0.08, 0.0, 1.0)
            if "Shin" in name:
                # Shin owns knee-to-foot (Y < 0.27) strongly; zero influence above hip
                shin_band = np.clip((0.29 - y) / 0.07, 0.0, 1.0)
                w = (w + 0.65 * np.clip((0.20 - y) / 0.08, 0.0, 1.0)) * side_mask * shin_band
            else:
                # Thigh owns hip-to-knee (Y in 0.20..0.47)
                thigh_band = np.clip((y - 0.18) / 0.07, 0.0, 1.0) * lower_mask
                w *= side_mask * thigh_band
        elif name in ("Neck", "Head"):
            head_mask = np.clip((y - 0.74) / 0.06, 0.0, 1.0)
            w *= head_mask
        elif name in ("Spine", "Chest"):
            torso_mask = np.clip((y - 0.44) / 0.08, 0.0, 1.0) * np.clip((0.86 - y) / 0.08, 0.0, 1.0)
            torso_mask *= np.clip((0.15 - np.abs(x)) / 0.06, 0.15, 1.0)
            w *= torso_mask
        elif name == "Hips":
            # Hips fades cleanly to ZERO below Y=0.34 so feet/shins are 100% controlled by leg bones!
            hip_mask = np.clip((0.64 - y) / 0.12, 0.0, 1.0) * np.clip((y - 0.34) / 0.10, 0.0, 1.0)
            w *= hip_mask

        weights_all[:, bi] = w

    # Ensure every vertex has non-zero total weight (fallback to nearest leg below Y=0.34, else Hips)
    row_sums = weights_all.sum(axis=1)
    zero_mask = row_sums < 1e-6
    if np.any(zero_mask):
        z_idx = np.where(zero_mask)[0]
        for vi in z_idx:
            if y[vi] < 0.24:
                weights_all[vi, 11 if x[vi] >= 0.0 else 13] = 1.0
            elif y[vi] < 0.44:
                weights_all[vi, 10 if x[vi] >= 0.0 else 12] = 1.0
            else:
                weights_all[vi, 1] = 1.0

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

    # 2. Walk (natural 3D biomechanical stride: separated feet, forward thigh swing +X, backward knee bend -X!)
    n_w = 25
    dur_walk = 0.96
    times_walk = np.linspace(0.0, dur_walk, n_w, dtype=np.float32)
    ch_walk = {}
    hips_base = bone_specs[1][2]
    for k, t in enumerate(times_walk):
        ph = (t / dur_walk) * math.tau
        s = math.sin(ph)
        # Double-frequency vertical stride bob + lateral weight shift onto planted foot
        bob = -math.cos(2.0 * ph) * 0.020
        sway_x = -s * 0.020
        ch_walk.setdefault((1, "translation"), []).append([hips_base[0] + sway_x, hips_base[1] + bob, hips_base[2]])
        # Negative X pitch leans torso subtly forward toward -Z; natural hip counter-yaw
        ch_walk.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.05, -s * 0.12, s * 0.045))
        ch_walk.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.04, s * 0.09, -s * 0.03))
        ch_walk.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.03, s * 0.13, -s * 0.02))
        ch_walk.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.05, -s * 0.07, 0.0))
        # Crisp alternating two-foot stride (+X swings leg forward toward -Z; -X bends knee backward toward +Z!)
        l_swing = max(0.0, math.sin(ph + 0.55))
        r_swing = max(0.0, math.sin(ph + math.pi + 0.55))
        stride_amp = 0.34 if is_sarai else 0.46
        ch_walk.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(s * stride_amp + l_swing * 0.16, 0.0, 0.025))
        ch_walk.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(-l_swing * 0.62, 0.0, 0.0))
        ch_walk.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(-s * stride_amp + r_swing * 0.16, 0.0, -0.025))
        ch_walk.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(-r_swing * 0.62, 0.0, 0.0))
        # Natural opposite-arm counter-swing (+X swings arm forward toward -Z)
        ch_walk.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-s * 0.38, 0.0, -0.07))
        ch_walk.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.24 + max(0.0, -s) * 0.24, 0.0, 0.0))
        ch_walk.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(s * 0.38, 0.0, 0.07))
        ch_walk.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.24 + max(0.0, s) * 0.24, 0.0, 0.0))
    anims.append(("Walk", dur_walk, times_walk, ch_walk))

    # 2b. Run (athletic forward sprint with clear alternating two-leg drive & backward knee fold)
    n_r = 25
    dur_run = 0.66
    times_run = np.linspace(0.0, dur_run, n_r, dtype=np.float32)
    ch_run = {}
    for k, t in enumerate(times_run):
        ph = (t / dur_run) * math.tau
        s = math.sin(ph)
        bob = -math.cos(2.0 * ph) * 0.036
        ch_run.setdefault((1, "translation"), []).append([hips_base[0] - s * 0.024, hips_base[1] + bob - 0.02, hips_base[2]])
        ch_run.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.15, -s * 0.16, s * 0.05))
        ch_run.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.10, s * 0.14, -s * 0.03))
        ch_run.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.08, s * 0.16, 0.0))
        ch_run.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.16, -s * 0.09, 0.0))
        l_sw = max(0.0, math.sin(ph + 0.5))
        r_sw = max(0.0, math.sin(ph + math.pi + 0.5))
        ch_run.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(s * 0.60 + l_sw * 0.24, 0.0, 0.02))
        ch_run.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(-l_sw * 0.95, 0.0, 0.0))
        ch_run.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(-s * 0.60 + r_sw * 0.24, 0.0, -0.02))
        ch_run.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(-r_sw * 0.95, 0.0, 0.0))
        ch_run.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-s * 0.68, 0.0, -0.10))
        ch_run.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.95 + max(0.0, -s) * 0.25, 0.0, 0.0))
        ch_run.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(s * 0.68, 0.0, 0.10))
        ch_run.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.95 + max(0.0, s) * 0.25, 0.0, 0.0))
    anims.append(("Run", dur_run, times_run, ch_run))

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
        # Kneeling thighs forward (+X), shins folded back (-X)
        ch_pray.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(1.15, 0.0, 0.04))
        ch_pray.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(-1.55, 0.0, 0.0))
        ch_pray.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(1.15, 0.0, -0.04))
        ch_pray.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(-1.55, 0.0, 0.0))
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
        # Right arm (8=UpperArm_R, 9=LowerArm_R) raises FORWARD & UP (+X) then strikes DOWN onto timber!
        ch_ham.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(0.95 + strike * 0.72, -0.10, 0.14))
        ch_ham.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.65 + max(0.0, strike) * 0.45, 0.0, 0.0))
        # Left arm (6=UpperArm_L, 7=LowerArm_L) steadies timber peg in front
        ch_ham.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(0.58, 0.18, -0.10))
        ch_ham.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.52, 0.0, 0.0))
    anims.append(("Hammer", dur_ham, times_ham, ch_ham))

    # 5. BrushPitch (stooped sweeping stroke applying hot bitumen/pitch forward on hull seams)
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
        ch_br.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(0.82 + sweep * 0.22, sweep * 0.35, 0.10))
        ch_br.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.42 + sweep * 0.16, 0.0, 0.0))
        ch_br.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(0.45, 0.12, -0.10))
        ch_br.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.35, 0.0, 0.0))
    anims.append(("BrushPitch", dur_br, times_br, ch_br))

    # 6. Bless (exact 00_prologue_noah_ark_final.png thanksgiving pose: upright, head lifted skyward, both arms raised FORWARD & UP!)
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
        # Both arms raised forward & upward (+X) toward the Rainbow Covenant
        ch_bl.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(1.35 + sway, -0.22, -0.42))
        ch_bl.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(0.45 + sway * 0.4, 0.0, 0.0))
        ch_bl.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(1.35 + sway, 0.22, 0.42))
        ch_bl.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(0.45 + sway * 0.4, 0.0, 0.0))
    anims.append(("Bless", dur_bl, times_bl, ch_bl))

    # 7. DrawSword (拔刀: reach across to left hip scabbard, draw bronze blade upward into guard stance)
    n_ds = 25
    dur_ds = 1.25
    times_ds = np.linspace(0.0, dur_ds, n_ds, dtype=np.float32)
    ch_ds = {}
    for k, t in enumerate(times_ds):
        u = t / dur_ds
        # Phase 0..0.35 reach to left hip; 0.35..0.75 sweep upward/outward; 0.75..1.0 settle into guard
        if u < 0.35:
            p = u / 0.35
            yaw_t = -0.35 * p
            r_arm_x, r_arm_y, r_arm_z = -0.45 * p, -0.75 * p, -0.25 * p
            r_elb = -0.75 * p
            l_arm_x, l_arm_z = -0.25 * p, -0.15 * p
        elif u < 0.75:
            p = (u - 0.35) / 0.40
            yaw_t = -0.35 + 0.65 * p
            r_arm_x = -0.45 - 0.85 * math.sin(p * math.pi) - 0.30 * p
            r_arm_y = -0.75 + 1.05 * p
            r_arm_z = -0.25 + 0.65 * p
            r_elb = -0.75 + 0.40 * p
            l_arm_x, l_arm_z = -0.25 - 0.45 * p, -0.15 - 0.15 * p
        else:
            p = (u - 0.75) / 0.25
            yaw_t = 0.30 * (1.0 - 0.25 * p)
            r_arm_x, r_arm_y, r_arm_z = -0.75 + 0.10 * p, 0.30 - 0.10 * p, 0.40 - 0.12 * p
            r_elb = -0.35 - 0.15 * p
            l_arm_x, l_arm_z = -0.70, -0.30
        ch_ds.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.04, hips_base[2]])
        ch_ds.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.08, yaw_t * 0.5, 0.0))
        ch_ds.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.08, yaw_t * 0.7, 0.0))
        ch_ds.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.06, yaw_t, 0.0))
        ch_ds.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.06, -yaw_t * 0.6, 0.0))
        ch_ds.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(l_arm_x, 0.15, l_arm_z))
        ch_ds.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.65, 0.0, 0.0))
        ch_ds.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(r_arm_x, r_arm_y, r_arm_z))
        ch_ds.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(r_elb, 0.0, 0.0))
        ch_ds.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-0.22, 0.0, 0.06))
        ch_ds.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(0.28, 0.0, 0.0))
        ch_ds.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(0.18, 0.0, -0.06))
        ch_ds.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(0.22, 0.0, 0.0))
    anims.append(("DrawSword", dur_ds, times_ds, ch_ds))

    # 8. Slash (劈杀: explosive hip-driven diagonal bronze-sword cleave with torso twist & follow-through)
    n_sl = 25
    dur_sl = 1.05
    times_sl = np.linspace(0.0, dur_sl, n_sl, dtype=np.float32)
    ch_sl = {}
    for k, t in enumerate(times_sl):
        u = t / dur_sl
        # 0..0.32 wind-up high right; 0.32..0.58 explosive cleave down-left; 0.58..1.0 recover
        if u < 0.32:
            p = u / 0.32
            twist = 0.58 * p
            lean = 0.08 * p
            r_x, r_y, r_z = -0.6 - 1.35 * p, 0.35 * p, 0.55 * p
            r_elb = -0.75 * p
        elif u < 0.58:
            p = (u - 0.32) / 0.26
            e = p * p * (3.0 - 2.0 * p)
            twist = 0.58 - 1.30 * e
            lean = 0.08 - 0.34 * e
            r_x = -1.95 + 2.30 * e
            r_y = 0.35 - 1.05 * e
            r_z = 0.55 - 0.95 * e
            r_elb = -0.75 + 0.55 * e
        else:
            p = (u - 0.58) / 0.42
            twist = -0.72 * (1.0 - p)
            lean = -0.26 * (1.0 - p) - 0.08 * p
            r_x = 0.35 * (1.0 - p) - 0.60 * p
            r_y = -0.70 * (1.0 - p)
            r_z = -0.40 * (1.0 - p) + 0.15 * p
            r_elb = -0.20 - 0.25 * p
        lunge = math.sin(min(u / 0.58, 1.0) * math.pi)
        ch_sl.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.05 - 0.04 * lunge, hips_base[2] - 0.06 * lunge])
        ch_sl.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(lean * 0.5, twist * 0.55, 0.0))
        ch_sl.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(lean * 0.7, twist * 0.75, 0.0))
        ch_sl.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(lean, twist, 0.0))
        ch_sl.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(-lean * 0.6, -twist * 0.75, 0.0))
        ch_sl.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-0.72, 0.25 - twist * 0.2, -0.32))
        ch_sl.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.85, 0.0, 0.0))
        ch_sl.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(r_x, r_y, r_z))
        ch_sl.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(r_elb, 0.0, 0.0))
        ch_sl.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-0.35 - 0.25 * lunge, 0.0, 0.08))
        ch_sl.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(0.42 + 0.25 * lunge, 0.0, 0.0))
        ch_sl.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(0.28 + 0.15 * lunge, 0.0, -0.08))
        ch_sl.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(0.25, 0.0, 0.0))
    anims.append(("Slash", dur_sl, times_sl, ch_sl))

    # 9. Brawl (搏斗: close-quarters left jab/shield bash -> right power cross combo)
    n_brw = 25
    dur_brw = 1.10
    times_brw = np.linspace(0.0, dur_brw, n_brw, dtype=np.float32)
    ch_brw = {}
    for k, t in enumerate(times_brw):
        ph = (t / dur_brw) * math.tau
        jab = max(0.0, math.sin(ph))
        cross = max(0.0, math.sin(ph - math.pi))
        twist = -jab * 0.42 + cross * 0.55
        ch_brw.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.06, hips_base[2] - 0.04 * (jab + cross)])
        ch_brw.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.14, twist * 0.5, 0.0))
        ch_brw.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.12, twist * 0.7, 0.0))
        ch_brw.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.10, twist, 0.0))
        ch_brw.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.14, -twist * 0.8, 0.0))
        # Left arm jab
        ch_brw.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-0.85 - jab * 0.65, 0.15, -0.22))
        ch_brw.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-1.10 + jab * 0.92, 0.0, 0.0))
        # Right arm power cross
        ch_brw.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-0.85 - cross * 0.72, -0.15, 0.22))
        ch_brw.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-1.10 + cross * 0.95, 0.0, 0.0))
        ch_brw.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-0.32, 0.0, 0.08))
        ch_brw.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(0.45, 0.0, 0.0))
        ch_brw.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(0.24, 0.0, -0.08))
        ch_brw.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(0.32, 0.0, 0.0))
    anims.append(("Brawl", dur_brw, times_brw, ch_brw))

    # 10. BowShoot (射箭: side-on archer stance, left bow arm extended toward -Z, right hand draws string to cheek & releases)
    n_bw = 25
    dur_bw = 1.65
    times_bw = np.linspace(0.0, dur_bw, n_bw, dtype=np.float32)
    ch_bw = {}
    for k, t in enumerate(times_bw):
        u = t / dur_bw
        # 0..0.42 draw back; 0.42..0.72 hold full draw; 0.72..0.84 crisp release recoil; 0.84..1.0 relax
        if u < 0.42:
            draw = u / 0.42
            recoil = 0.0
        elif u < 0.72:
            draw = 1.0
            recoil = 0.0
        elif u < 0.84:
            draw = 1.0 - (u - 0.72) / 0.12
            recoil = math.sin(((u - 0.72) / 0.12) * math.pi)
        else:
            draw = 0.0
            recoil = 0.0
        stance_yaw = 1.05  # Body turned ~60 deg right so left shoulder points straight at target (-Z)
        ch_bw.setdefault((1, "translation"), []).append([hips_base[0], hips_base[1] - 0.04, hips_base[2]])
        ch_bw.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(-0.04, stance_yaw * 0.55, 0.0))
        ch_bw.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-0.04, stance_yaw * 0.25, 0.0))
        ch_bw.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.03, stance_yaw * 0.25, 0.0))
        # Head looks straight over left shoulder at target (-Z)
        ch_bw.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(0.04, -stance_yaw * 0.95, 0.0))
        # Left arm holds composite bow extended forward toward -Z
        ch_bw.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-1.42 - recoil * 0.08, -0.95, -0.18))
        ch_bw.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-0.08, 0.0, 0.0))
        # Right arm pulls bowstring back to cheek, snaps back on release
        ch_bw.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(-1.25 + draw * 0.35 + recoil * 0.22, 0.35 + draw * 0.45, 0.65 + draw * 0.25))
        ch_bw.setdefault((9, "rotation"), []).append(euler_xyz_to_quat(-0.45 - draw * 1.15 + recoil * 0.55, 0.0, 0.0))
        # Wide stable archer stance
        ch_bw.setdefault((10, "rotation"), []).append(euler_xyz_to_quat(-0.18, 0.0, 0.14))
        ch_bw.setdefault((11, "rotation"), []).append(euler_xyz_to_quat(0.22, 0.0, 0.0))
        ch_bw.setdefault((12, "rotation"), []).append(euler_xyz_to_quat(0.16, 0.0, -0.14))
        ch_bw.setdefault((13, "rotation"), []).append(euler_xyz_to_quat(0.20, 0.0, 0.0))
    anims.append(("BowShoot", dur_bw, times_bw, ch_bw))

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

    # Clean uncleaned studio-white/gray cutout bleed on feet & sandals (especially Noah!), then separate legs!
    if not is_sarai:
        pos_n, idx, img_bytes = clean_foot_cutout_bleed(pos_n, uv, idx, img_bytes)
        img_mime = "image/png"
    pos_n, nrm_r, uv, idx = separate_lower_legs_mesh(pos_n, nrm_r, uv, idx, is_sarai=is_sarai)

    # 14-bone Humanoid Skeleton (Y in [0, 1], shoulders along +-X, -Z forward)
    # Tight leg bone sigmas (0.075) aligned to real foot centers (±0.075) for clean independent leg motion!
    bone_specs = [
        ("Root",       -1, [0.00, 0.00, 0.00], [0.00, 0.05, 0.00], 0.05),
        ("Hips",        0, [0.00, 0.46, 0.00], [0.00, 0.56, 0.00], 0.13),
        ("Spine",       1, [0.00, 0.58, 0.00], [0.00, 0.69, 0.00], 0.12),
        ("Chest",       2, [0.00, 0.70, 0.00], [0.00, 0.80, 0.00], 0.12),
        ("Neck",        3, [0.00, 0.81, 0.00], [0.00, 0.86, 0.00], 0.08),
        ("Head",        4, [0.00, 0.87, 0.00], [0.00, 0.99, 0.00], 0.11),
        ("UpperArm_L",  3, [0.11, 0.75, 0.00], [0.17, 0.61, 0.00], 0.085),
        ("Forearm_L",   6, [0.17, 0.61, 0.00], [0.22, 0.44, 0.00], 0.085),
        ("UpperArm_R",  3, [-0.11, 0.75, 0.00], [-0.17, 0.61, 0.00], 0.085),
        ("Forearm_R",   8, [-0.17, 0.61, 0.00], [-0.22, 0.44, 0.00], 0.085),
        ("Thigh_L",     1, [0.075, 0.44, 0.00], [0.075, 0.24, 0.00], 0.075),
        ("Shin_L",     10, [0.075, 0.24, 0.00], [0.075, 0.02, 0.00], 0.075),
        ("Thigh_R",     1, [-0.075, 0.44, 0.00], [-0.075, 0.24, 0.00], 0.075),
        ("Shin_R",     12, [-0.075, 0.24, 0.00], [-0.075, 0.02, 0.00], 0.075),
    ]

    joints_u8, weights_f32 = compute_skin_weights(pos_n, bone_specs, is_sarai=is_sarai)

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
