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
        assert magic == b"glTF", f"Not GLB: {path}"
        j_len, _ = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(j_len).decode("utf-8"))
        b_len, _ = struct.unpack("<II", f.read(8))
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
    stride = bv.get("byteStride", 0)
    item_bytes = np.dtype(dtype).itemsize * ncomp
    if stride and stride != item_bytes:
        raw = np.frombuffer(bin_data, dtype=np.uint8, count=count * stride, offset=offset).reshape((count, stride))
        arr = np.frombuffer(raw[:, :item_bytes].tobytes(), dtype=dtype)
    else:
        arr = np.frombuffer(bin_data, dtype=dtype, count=count * ncomp, offset=offset)
    if ncomp > 1:
        arr = arr.reshape((count, ncomp))
    return arr.copy()


def euler_xyz_to_quat(rx, ry, rz):
    cx, sx = math.cos(rx * 0.5), math.sin(rx * 0.5)
    cy, sy = math.cos(ry * 0.5), math.sin(ry * 0.5)
    cz, sz = math.cos(rz * 0.5), math.sin(rz * 0.5)
    qx = sx * cy * cz + cx * sy * sz
    qy = cx * sy * cz - sx * cy * sz
    qz = cx * cy * sz + sx * sy * cz
    qw = cx * cy * cz - sx * sy * sz
    n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    return [qx / n, qy / n, qz / n, qw / n]


def decimate_vertex_cluster(pos, nrm, uv, idx, grid_res=72):
    """UV-seam-safe spatial vertex clustering: 240k verts -> ~10k-14k verts with intact PBR UVs."""
    if len(pos) <= 18000:
        return pos, nrm, uv, idx.astype(np.uint32)
    pmin = pos.min(axis=0)
    pmax = pos.max(axis=0)
    span = float(max(pmax - pmin))
    cell = max(span / float(grid_res), 1e-5)

    gx = np.floor((pos[:, 0] - pmin[0]) / cell).astype(np.int64)
    gy = np.floor((pos[:, 1] - pmin[1]) / cell).astype(np.int64)
    gz = np.floor((pos[:, 2] - pmin[2]) / cell).astype(np.int64)
    gu = np.floor(np.clip(uv[:, 0], 0.0, 0.999) * 16.0).astype(np.int64)
    gv = np.floor(np.clip(uv[:, 1], 0.0, 0.999) * 16.0).astype(np.int64)

    # Combine 5 integer keys into a single 64-bit hash key
    keys = (gx * 1000003 + gy) * 1000003 + gz
    keys = (keys * 31 + gu) * 31 + gv
    _, inv, counts = np.unique(keys, return_inverse=True, return_counts=True)
    n_new = len(counts)
    inv = inv.astype(np.int32)
    c_f = counts.astype(np.float32)[:, None]

    new_pos = np.zeros((n_new, 3), dtype=np.float32)
    new_nrm = np.zeros((n_new, 3), dtype=np.float32)
    new_uv = np.zeros((n_new, 2), dtype=np.float32)
    np.add.at(new_pos, inv, pos)
    np.add.at(new_nrm, inv, nrm)
    np.add.at(new_uv, inv, uv)
    new_pos /= c_f
    new_uv /= c_f
    nlen = np.maximum(np.linalg.norm(new_nrm, axis=1, keepdims=True), 1e-8)
    new_nrm /= nlen

    tris = inv[idx.reshape(-1, 3)]
    valid = (tris[:, 0] != tris[:, 1]) & (tris[:, 1] != tris[:, 2]) & (tris[:, 2] != tris[:, 0])
    tris = tris[valid].astype(np.uint32)
    return new_pos, new_nrm, new_uv, tris.reshape(-1)


def compute_quadruped_weights(pos, bone_specs):
    """
    9-bone quadruped skinning with strict 4-leg isolation below belly height (Y < 0.46)
    so front-left, front-right, back-left, and back-right legs step cleanly with zero glue!
    Mesh is normalized: feet at Y=0, height=1.0, facing -Z (head at -Z, tail at +Z).
    """
    n_v = pos.shape[0]
    n_b = len(bone_specs)
    w_all = np.zeros((n_v, n_b), dtype=np.float32)

    x = pos[:, 0]
    y = pos[:, 1]
    z = pos[:, 2]
    z_min, z_max = float(z.min()), float(z.max())
    z_mid = 0.5 * (z_min + z_max)

    def d_seg(a, b):
        a = np.array(a, dtype=np.float32)
        b = np.array(b, dtype=np.float32)
        ab = b - a
        ab2 = float(np.dot(ab, ab))
        if ab2 < 1e-8:
            return np.linalg.norm(pos - a, axis=1)
        t = np.clip(np.dot(pos - a, ab) / ab2, 0.0, 1.0)
        return np.linalg.norm(pos - (a + t[:, None] * ab[None, :]), axis=1)

    for bi, (name, _, head, tail, rad) in enumerate(bone_specs):
        if bi == 0:
            continue
        w = np.exp(-0.5 * (d_seg(head, tail) / rad) ** 2)
        if name.startswith("Leg_"):
            is_left = name.endswith("L")
            is_front = "_F" in name
            side_ok = (x >= 0.0) if is_left else (x < 0.0)
            fb_ok = (z <= z_mid) if is_front else (z > z_mid)
            leg_zone = np.clip((0.52 - y) / 0.14, 0.0, 1.0)
            # Hard isolation below belly so legs NEVER pull each other
            w = (w + 0.55 * np.clip((0.35 - y) / 0.12, 0.0, 1.0)) * side_ok.astype(np.float32) * fb_ok.astype(np.float32) * leg_zone
        elif name in ("Neck", "Head"):
            front_mask = np.clip((z_mid - z) / max(abs(z_min - z_mid) * 0.45, 0.08), 0.0, 1.0)
            high_mask = np.clip((y - 0.38) / 0.12, 0.0, 1.0)
            w *= front_mask * high_mask
        elif name in ("Pelvis", "Spine"):
            body_mask = np.clip((y - 0.36) / 0.14, 0.0, 1.0)
            w *= body_mask
        w_all[:, bi] = w

    # Fallback for any zero-weight vertex
    sums = w_all.sum(axis=1)
    zero = np.where(sums < 1e-6)[0]
    for vi in zero:
        if y[vi] < 0.42:
            if z[vi] <= z_mid:
                w_all[vi, 5 if x[vi] >= 0.0 else 6] = 1.0
            else:
                w_all[vi, 7 if x[vi] >= 0.0 else 8] = 1.0
        else:
            w_all[vi, 1] = 1.0

    top4_idx = np.argsort(-w_all, axis=1)[:, :4]
    top4_w = np.take_along_axis(w_all, top4_idx, axis=1)
    top4_w /= np.maximum(top4_w.sum(axis=1, keepdims=True), 1e-8)
    return top4_idx.astype(np.uint8), top4_w.astype(np.float32)


def build_quadruped_anims(bone_specs):
    anims = []
    pelvis_base = bone_specs[1][2]

    # 1. Idle (gentle breathing & curious head turn)
    t_id = np.linspace(0.0, 2.8, 21, dtype=np.float32)
    ch_id = {}
    for t in t_id:
        ph = (float(t) / 2.8) * math.tau
        s = math.sin(ph)
        ch_id.setdefault((1, "translation"), []).append([pelvis_base[0], pelvis_base[1] + s * 0.008, pelvis_base[2]])
        ch_id.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(s * 0.025, 0.0, 0.0))
        ch_id.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(s * 0.04, math.sin(ph * 0.5) * 0.12, 0.0))
        ch_id.setdefault((4, "rotation"), []).append(euler_xyz_to_quat(s * 0.03, math.sin(ph) * 0.18, 0.0))
    anims.append(("Idle", 2.8, t_id, ch_id))

    # 2. Walk (natural diagonal quadruped gait: FL+BR forward while FR+BL push back!)
    t_wk = np.linspace(0.0, 0.88, 21, dtype=np.float32)
    ch_wk = {}
    for t in t_wk:
        ph = (float(t) / 0.88) * math.tau
        s = math.sin(ph)
        bob = -math.cos(2.0 * ph) * 0.018
        ch_wk.setdefault((1, "translation"), []).append([pelvis_base[0], pelvis_base[1] + bob, pelvis_base[2]])
        ch_wk.setdefault((1, "rotation"), []).append(euler_xyz_to_quat(s * 0.03, s * 0.04, -s * 0.03))
        ch_wk.setdefault((2, "rotation"), []).append(euler_xyz_to_quat(-s * 0.03, -s * 0.04, s * 0.025))
        ch_wk.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(bob * 1.4, 0.0, 0.0))
        ch_wk.setdefault((4, "rotation"), []).append(euler_xyz_to_quat(-bob * 1.2, s * 0.04, 0.0))
        # Diagonal pairs: FL(5) + BR(8) in phase; FR(6) + BL(7) opposite phase!
        amp = 0.42
        ch_wk.setdefault((5, "rotation"), []).append(euler_xyz_to_quat(s * amp, 0.0, 0.0))
        ch_wk.setdefault((8, "rotation"), []).append(euler_xyz_to_quat(s * amp, 0.0, 0.0))
        ch_wk.setdefault((6, "rotation"), []).append(euler_xyz_to_quat(-s * amp, 0.0, 0.0))
        ch_wk.setdefault((7, "rotation"), []).append(euler_xyz_to_quat(-s * amp, 0.0, 0.0))
    anims.append(("Walk", 0.88, t_wk, ch_wk))

    # 3. StallRest (peaceful Ark cabin breathing & gentle head nod)
    t_sr = np.linspace(0.0, 3.6, 21, dtype=np.float32)
    ch_sr = {}
    for t in t_sr:
        ph = (float(t) / 3.6) * math.tau
        s = math.sin(ph)
        ch_sr.setdefault((1, "translation"), []).append([pelvis_base[0], pelvis_base[1] + s * 0.010, pelvis_base[2]])
        ch_sr.setdefault((3, "rotation"), []).append(euler_xyz_to_quat(-0.18 + s * 0.14, math.sin(ph * 0.5) * 0.08, 0.0))
        ch_sr.setdefault((4, "rotation"), []).append(euler_xyz_to_quat(-0.12 + s * 0.10, math.cos(ph) * 0.10, 0.0))
    anims.append(("StallRest", 3.6, t_sr, ch_sr))
    return anims


def process_animal_glb(filename, flip_180=False, add_rig=True, grid_res=72):
    path = os.path.join(MODELS_DIR, filename)
    if not os.path.exists(path):
        print(f"MISSING {filename}")
        return
    orig_mb = os.path.getsize(path) / (1024 * 1024)
    gltf, bin_data = read_glb(path)
    prim = gltf["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]

    pos = read_accessor(gltf, bin_data, attrs["POSITION"]).astype(np.float32)
    uv = read_accessor(gltf, bin_data, attrs["TEXCOORD_0"]).astype(np.float32) if "TEXCOORD_0" in attrs else np.zeros((len(pos), 2), dtype=np.float32)
    idx = read_accessor(gltf, bin_data, prim["indices"]).astype(np.uint32)
    if "NORMAL" in attrs:
        nrm = read_accessor(gltf, bin_data, attrs["NORMAL"]).astype(np.float32)
    else:
        nrm = np.zeros_like(pos)
        nrm[:, 1] = 1.0

    # Normalize & orient consistently so ALL animals face -Z with feet on Y=0 and height=1.0
    if flip_180:
        pos = np.stack([-pos[:, 0], pos[:, 1], -pos[:, 2]], axis=1)
        nrm = np.stack([-nrm[:, 0], nrm[:, 1], -nrm[:, 2]], axis=1)

    pmin = pos.min(axis=0)
    pmax = pos.max(axis=0)
    h = max(float(pmax[1] - pmin[1]), 1e-4)
    cx = float(0.5 * (pmin[0] + pmax[0]))
    cz = float(0.5 * (pmin[2] + pmax[2]))
    pos = np.stack([(pos[:, 0] - cx) / h, (pos[:, 1] - pmin[1]) / h, (pos[:, 2] - cz) / h], axis=1).astype(np.float32)

    # Decimate high-poly Grab3D mesh cleanly while preserving UVs
    pos, nrm, uv, idx = decimate_vertex_cluster(pos, nrm, uv, idx, grid_res=grid_res)

    # Extract & compress embedded images (1024px JPEG/PNG)
    out_images_bytes = []
    for img in gltf.get("images", []):
        bv = gltf["bufferViews"][img["bufferView"]]
        off = bv.get("byteOffset", 0)
        raw = bin_data[off:off + bv["byteLength"]]
        try:
            im = Image.open(io.BytesIO(raw))
            if max(im.size) > 1024:
                im.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
            bio = io.BytesIO()
            im.convert("RGB").save(bio, format="JPEG", quality=84, optimize=True)
            out_images_bytes.append((bio.getvalue(), "image/jpeg"))
        except Exception:
            out_images_bytes.append((raw, img.get("mimeType", "image/jpeg")))

    # Build fresh compact GLB
    buf = bytearray()
    bvs = []
    accs = []

    def add_bv(raw_bytes, target=None):
        while len(buf) % 4 != 0:
            buf.append(0)
        off = len(buf)
        buf.extend(raw_bytes)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": len(raw_bytes)}
        if target is not None:
            bv["target"] = target
        bvs.append(bv)
        return len(bvs) - 1

    def add_acc(arr, ctype, atype, target=None, minmax=False):
        bvi = add_bv(arr.tobytes(), target=target)
        a = {"bufferView": bvi, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        if minmax:
            if arr.ndim == 1:
                a["min"] = [float(arr.min())]
                a["max"] = [float(arr.max())]
            else:
                a["min"] = [float(v) for v in arr.min(axis=0)]
                a["max"] = [float(v) for v in arr.max(axis=0)]
        accs.append(a)
        return len(accs) - 1

    acc_pos = add_acc(pos, 5126, "VEC3", target=34962, minmax=True)
    acc_nrm = add_acc(nrm, 5126, "VEC3", target=34962)
    acc_uv = add_acc(uv, 5126, "VEC2", target=34962)
    acc_idx = add_acc(idx, 5125, "SCALAR", target=34963)

    prim_attrs = {"POSITION": acc_pos, "NORMAL": acc_nrm, "TEXCOORD_0": acc_uv}

    images_json = []
    samplers_json = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    for raw_img, mime in out_images_bytes:
        ibv = add_bv(raw_img)
        images_json.append({"bufferView": ibv, "mimeType": mime})

    # Preserve exact original glTF texture -> image source mapping so baseColor/normal/roughness never swap!
    orig_textures = gltf.get("textures", [])
    if orig_textures:
        textures_json = []
        for t in orig_textures:
            src = int(t.get("source", 0))
            if src >= len(images_json):
                src = 0
            textures_json.append({"sampler": 0, "source": src})
    else:
        textures_json = [{"sampler": 0, "source": i} for i in range(len(images_json))]

    # Preserve original material texture bindings (baseColor + metallicRoughness + normal)
    mats = gltf.get("materials", [{"name": "AnimalPBR", "pbrMetallicRoughness": {"roughnessFactor": 0.85, "metallicFactor": 0.0}}])
    if mats and len(textures_json) > 0:
        m0 = json.loads(json.dumps(mats[0]))
        m0["doubleSided"] = True
        pbr = m0.setdefault("pbrMetallicRoughness", {})
        if "baseColorTexture" in pbr and pbr["baseColorTexture"]["index"] < len(textures_json):
            pass
        else:
            pbr["baseColorTexture"] = {"index": 0}
        if "normalTexture" in m0 and m0["normalTexture"]["index"] >= len(textures_json):
            del m0["normalTexture"]
        if "metallicRoughnessTexture" in m0.get("pbrMetallicRoughness", {}) and m0["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"] >= len(textures_json):
            del m0["pbrMetallicRoughness"]["metallicRoughnessTexture"]
        if "occlusionTexture" in m0 and m0["occlusionTexture"]["index"] >= len(textures_json):
            del m0["occlusionTexture"]
        mats = [m0]

    nodes = []
    skins = []
    gltf_anims = []

    if add_rig:
        z_min, z_max = float(pos[:, 2].min()), float(pos[:, 2].max())
        x_hw = max(float(np.percentile(np.abs(pos[pos[:, 1] < 0.35, 0]), 65)) if np.any(pos[:, 1] < 0.35) else 0.14, 0.09)
        zf = z_min * 0.55
        zb = z_max * 0.58
        bone_specs = [
            ("Root",   -1, [0.0, 0.0, 0.0],       [0.0, 0.1, 0.0],        0.08),
            ("Pelvis",  0, [0.0, 0.54, zb * 0.6], [0.0, 0.56, 0.0],       0.24),
            ("Spine",   1, [0.0, 0.56, 0.0],      [0.0, 0.60, zf * 0.85], 0.24),
            ("Neck",    2, [0.0, 0.62, zf * 0.9], [0.0, 0.78, z_min*0.75],0.18),
            ("Head",    3, [0.0, 0.78, z_min*0.75],[0.0, 0.82, z_min],    0.16),
            ("Leg_FL",  2, [ x_hw, 0.48, zf],     [ x_hw, 0.02, zf],      0.14),
            ("Leg_FR",  2, [-x_hw, 0.48, zf],     [-x_hw, 0.02, zf],      0.14),
            ("Leg_BL",  1, [ x_hw, 0.48, zb],     [ x_hw, 0.02, zb],      0.14),
            ("Leg_BR",  1, [-x_hw, 0.48, zb],     [-x_hw, 0.02, zb],      0.14),
        ]
        j_u8, w_f32 = compute_quadruped_weights(pos, bone_specs)
        prim_attrs["JOINTS_0"] = add_acc(j_u8, 5121, "VEC4", target=34962)
        prim_attrs["WEIGHTS_0"] = add_acc(w_f32, 5126, "VEC4", target=34962)

        ibm_list = []
        for _, _, head, _, _ in bone_specs:
            m = np.eye(4, dtype=np.float32)
            m[0, 3], m[1, 3], m[2, 3] = -head[0], -head[1], -head[2]
            ibm_list.append(m.T.reshape(-1))
        acc_ibm = add_acc(np.concatenate(ibm_list).reshape((len(bone_specs), 16)), 5126, "MAT4")

        nodes = [
            {"name": "AnimalRoot", "children": [1, 2]},
            {"name": "AnimalMesh", "mesh": 0, "skin": 0},
        ]
        j_off = 2
        j_nodes = []
        for bi, (bname, parent, head, _, _) in enumerate(bone_specs):
            rel = head if parent == -1 else [head[k] - bone_specs[parent][2][k] for k in range(3)]
            nd = {"name": bname, "translation": [round(float(v), 5) for v in rel]}
            ch = [j_off + ci for ci, (_, cp, _, _, _) in enumerate(bone_specs) if cp == bi]
            if ch:
                nd["children"] = ch
            j_nodes.append(j_off + bi)
            nodes.append(nd)

        skins = [{"name": "Quadruped9", "inverseBindMatrices": acc_ibm, "skeleton": j_off, "joints": j_nodes}]
        for aname, dur, times, ch_dict in build_quadruped_anims(bone_specs):
            acc_t = add_acc(times, 5126, "SCALAR", minmax=True)
            samps, chans = [], []
            for (bi, pth), vals in ch_dict.items():
                va = np.array(vals, dtype=np.float32)
                acc_v = add_acc(va, 5126, "VEC4" if pth == "rotation" else "VEC3")
                samps.append({"input": acc_t, "interpolation": "LINEAR", "output": acc_v})
                chans.append({"sampler": len(samps) - 1, "target": {"node": j_off + bi, "path": pth}})
            gltf_anims.append({"name": aname, "channels": chans, "samplers": samps})
    else:
        nodes = [{"name": "BirdRoot", "mesh": 0}]

    while len(buf) % 4 != 0:
        buf.append(0)

    out_gltf = {
        "asset": {"version": "2.0", "generator": "PathOfPromise-QuadrupedRigger"},
        "scene": 0,
        "scenes": [{"name": "AnimalScene", "nodes": [0]}],
        "nodes": nodes,
        "meshes": [{"name": "AnimalMesh", "primitives": [{"attributes": prim_attrs, "indices": acc_idx, "material": 0}]}],
        "materials": mats,
        "samplers": samplers_json,
        "textures": textures_json,
        "images": images_json,
        "accessors": accs,
        "bufferViews": bvs,
        "buffers": [{"byteLength": len(buf)}],
    }
    if skins:
        out_gltf["skins"] = skins
    if gltf_anims:
        out_gltf["animations"] = gltf_anims

    j_bytes = json.dumps(out_gltf, separators=(",", ":")).encode("utf-8")
    while len(j_bytes) % 4 != 0:
        j_bytes += b" "
    total_len = 12 + 8 + len(j_bytes) + 8 + len(buf)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total_len))
        f.write(struct.pack("<II", len(j_bytes), 0x4E4F534A))
        f.write(j_bytes)
        f.write(struct.pack("<II", len(buf), 0x004E4942))
        f.write(buf)
    new_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"OK {filename:24s} {orig_mb:5.2f} MB -> {new_mb:4.2f} MB | verts={len(pos):6d} tris={len(idx)//3:6d} | rigged={add_rig}")


def main():
    # Sheep already faces -Z; Bull, Horse, Deer, Lion face +Z -> flip_180=True so ALL natively face -Z!
    process_animal_glb("CC0_Sheep_Grab3D.glb", flip_180=False, add_rig=True, grid_res=76)
    process_animal_glb("CC0_Bull_Grab3D.glb",  flip_180=True,  add_rig=True, grid_res=74)
    process_animal_glb("CC0_Horse_Grab3D.glb", flip_180=True,  add_rig=True, grid_res=74)
    process_animal_glb("CC0_Deer_Grab3D.glb",  flip_180=True,  add_rig=True, grid_res=74)
    process_animal_glb("CC0_Lion_Grab3D.glb",  flip_180=True,  add_rig=True, grid_res=74)
    process_animal_glb("CC0_Bird_Grab3D.glb",  flip_180=False, add_rig=False, grid_res=60)


if __name__ == "__main__":
    main()
