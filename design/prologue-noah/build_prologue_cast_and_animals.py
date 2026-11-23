import io
import os
import sys
import struct
import json
import numpy as np
import trimesh
from PIL import Image

sys.path.insert(0, r"c:\AI\gemini\promise-path-next\design\review-slice-01")
from rig_characters_glb import rig_glb, read_glb

MODELS = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"


def tint_glb_texture(in_glb: str, out_glb: str, tint_rgb: tuple, brightness: float = 1.0):
    """Copy a UV-baked GLB while subtly shifting garment palette in PIL for distinct family members."""
    gltf, bin_data = read_glb(in_glb)
    buf = bytearray(bin_data)
    if gltf.get("images"):
        img_def = gltf["images"][0]
        bv = gltf["bufferViews"][img_def["bufferView"]]
        off = bv.get("byteOffset", 0)
        length = bv["byteLength"]
        raw = bytes(buf[off:off + length])
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        arr = np.array(im, dtype=np.float32) / 255.0
        # Preserve skin/hair luminance, shift fabric tones gently
        tint = np.array(tint_rgb, dtype=np.float32)[None, None, :]
        arr = np.clip(arr * tint * brightness, 0.0, 1.0)
        out_im = Image.fromarray((arr * 255.0).astype(np.uint8), mode="RGB")
        bio = io.BytesIO()
        out_im.save(bio, format="PNG")
        new_bytes = bio.getvalue()
        while len(buf) % 4 != 0:
            buf.append(0)
        new_off = len(buf)
        buf.extend(new_bytes)
        bv["byteOffset"] = new_off
        bv["byteLength"] = len(new_bytes)
        img_def["mimeType"] = "image/png"
    while len(buf) % 4 != 0:
        buf.append(0)
    gltf["buffers"][0]["byteLength"] = len(buf)
    j_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(j_bytes) % 4 != 0:
        j_bytes += b" "
    total_len = 12 + 8 + len(j_bytes) + 8 + len(buf)
    with open(out_glb, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total_len))
        f.write(struct.pack("<II", len(j_bytes), 0x4E4F534A))
        f.write(j_bytes)
        f.write(struct.pack("<II", len(buf), 0x004E4942))
        f.write(buf)


def build_pbr_part(mesh: trimesh.Trimesh, color_rgba, roughness=0.88):
    col = [c / 255.0 if c > 1.0 else float(c) for c in color_rgba]
    mat = trimesh.visual.material.PBRMaterial(
        baseColorFactor=col,
        metallicFactor=0.0,
        roughnessFactor=roughness,
    )
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def make_quadruped(out_path, body_size, leg_h, neck_len, head_size, body_col, accent_col, horns=None, long_ears=False):
    parts = []
    rx90 = trimesh.transformations.rotation_matrix(np.pi / 2.0, [1, 0, 0])
    # Body (rounded ellipsoid along Z)
    body = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    body.apply_scale([body_size[0] * 0.5, body_size[1] * 0.5, body_size[2] * 0.5])
    body.apply_translation([0.0, leg_h + body_size[1] * 0.42, 0.0])
    parts.append(build_pbr_part(body, body_col))

    # 4 vertical legs along Y grounded at Y=0
    lx = body_size[0] * 0.28
    lz = body_size[2] * 0.34
    for sx in (-1, 1):
        for sz in (-1, 1):
            leg = trimesh.creation.cylinder(radius=body_size[0] * 0.11, height=leg_h, sections=8)
            leg.apply_transform(rx90)
            leg.apply_translation([sx * lx, leg_h * 0.5, sz * lz])
            parts.append(build_pbr_part(leg, accent_col))

    # Neck & Head facing -Z
    neck = trimesh.creation.cylinder(radius=body_size[0] * 0.20, height=neck_len, sections=10)
    neck.apply_transform(rx90)
    neck.apply_transform(trimesh.transformations.rotation_matrix(0.55, [1, 0, 0]))
    neck.apply_translation([0.0, leg_h + body_size[1] * 0.58, -body_size[2] * 0.44])
    parts.append(build_pbr_part(neck, body_col))

    head = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    head.apply_scale([head_size[0] * 0.5, head_size[1] * 0.5, head_size[2] * 0.5])
    head_y = leg_h + body_size[1] * 0.72 + neck_len * 0.28
    head_z = -body_size[2] * 0.56 - neck_len * 0.22
    head.apply_translation([0.0, head_y, head_z])
    parts.append(build_pbr_part(head, accent_col))

    # Tail hanging down at +Z
    tail = trimesh.creation.cylinder(radius=0.03, height=leg_h * 0.55, sections=6)
    tail.apply_transform(rx90)
    tail.apply_transform(trimesh.transformations.rotation_matrix(-0.25, [1, 0, 0]))
    tail.apply_translation([0.0, leg_h + body_size[1] * 0.28, body_size[2] * 0.48])
    parts.append(build_pbr_part(tail, accent_col))

    # Horns (Ox / Goat)
    if horns == "ox":
        for sx in (-1, 1):
            h1 = trimesh.creation.cone(radius=0.05, height=0.42, sections=8)
            h1.apply_transform(rx90)
            h1.apply_transform(trimesh.transformations.rotation_matrix(sx * -1.15, [0, 0, 1]))
            h1.apply_translation([sx * (head_size[0] * 0.52), head_y + head_size[1] * 0.32, head_z + 0.04])
            parts.append(build_pbr_part(h1, [225, 212, 184, 255], roughness=0.65))
    elif horns == "goat":
        for sx in (-1, 1):
            h1 = trimesh.creation.cone(radius=0.035, height=0.28, sections=8)
            h1.apply_transform(rx90)
            h1.apply_transform(trimesh.transformations.rotation_matrix(-0.55, [1, 0, 0]))
            h1.apply_transform(trimesh.transformations.rotation_matrix(sx * -0.35, [0, 0, 1]))
            h1.apply_translation([sx * (head_size[0] * 0.35), head_y + head_size[1] * 0.42, head_z + 0.06])
            parts.append(build_pbr_part(h1, [190, 175, 148, 255], roughness=0.7))

    if long_ears:
        for sx in (-1, 1):
            ear = trimesh.creation.cone(radius=0.045, height=0.30, sections=6)
            ear.apply_transform(rx90)
            ear.apply_transform(trimesh.transformations.rotation_matrix(sx * -0.35, [0, 0, 1]))
            ear.apply_translation([sx * (head_size[0] * 0.38), head_y + head_size[1] * 0.46, head_z + 0.06])
            parts.append(build_pbr_part(ear, accent_col))

    scene = trimesh.Scene()
    for i, p in enumerate(parts):
        scene.add_geometry(p, node_name=f"Part_{i}")
    scene.export(out_path)
    print(f"OK ANIMAL {os.path.basename(out_path)} ({os.path.getsize(out_path):,} bytes)")


def make_bird(out_path, body_col, wing_col, olive_twig=False):
    parts = []
    body = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    body.apply_scale([0.16, 0.13, 0.34])
    parts.append(build_pbr_part(body, body_col, roughness=0.78))

    head = trimesh.creation.icosphere(subdivisions=2, radius=0.10)
    head.apply_translation([0.0, 0.08, -0.32])
    parts.append(build_pbr_part(head, body_col, roughness=0.78))

    beak = trimesh.creation.cone(radius=0.03, height=0.11, sections=6)
    beak.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2.0, [1, 0, 0]))
    beak.apply_translation([0.0, 0.07, -0.43])
    parts.append(build_pbr_part(beak, [215, 165, 78, 255], roughness=0.6))

    # Outspread wings
    for sx in (-1, 1):
        w = trimesh.creation.box(extents=[0.55, 0.03, 0.24])
        w.apply_transform(trimesh.transformations.rotation_matrix(sx * 0.24, [0, 0, 1]))
        w.apply_translation([sx * 0.34, 0.06, -0.02])
        parts.append(build_pbr_part(w, wing_col, roughness=0.82))

    tail = trimesh.creation.box(extents=[0.22, 0.025, 0.24])
    tail.apply_translation([0.0, 0.02, 0.36])
    parts.append(build_pbr_part(tail, wing_col, roughness=0.82))

    if olive_twig:
        twig = trimesh.creation.cylinder(radius=0.012, height=0.22, sections=6)
        twig.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2.0, [0, 0, 1]))
        twig.apply_translation([0.0, 0.05, -0.49])
        parts.append(build_pbr_part(twig, [92, 128, 66, 255], roughness=0.75))
        for lx in (-0.08, 0.08):
            leaf = trimesh.creation.icosphere(subdivisions=1, radius=0.05)
            leaf.apply_scale([1.4, 0.4, 0.8])
            leaf.apply_translation([lx, 0.05, -0.52])
            parts.append(build_pbr_part(leaf, [104, 152, 74, 255], roughness=0.72))

    scene = trimesh.Scene()
    for i, p in enumerate(parts):
        scene.add_geometry(p, node_name=f"Bird_{i}")
    scene.export(out_path)
    print(f"OK BIRD {os.path.basename(out_path)} ({os.path.getsize(out_path):,} bytes)")


def main():
    # 1. Re-rig Noah with all 6 animations (Idle, Walk, Pray, Hammer, BrushPitch, Bless)
    rig_glb(os.path.join(MODELS, "CHR_Noah.glb"), os.path.join(MODELS, "CHR_Noah_rigged.glb"), is_sarai=False)

    # 2. Generate distinct-attire rigged family members (Wife, Sons, Daughters-in-law)
    tmp_wife = os.path.join(MODELS, "_tmp_wife.glb")
    tmp_son = os.path.join(MODELS, "_tmp_son.glb")
    tmp_dau = os.path.join(MODELS, "_tmp_dau.glb")

    tint_glb_texture(os.path.join(MODELS, "CHR_Sarai.glb"), tmp_wife, (0.92, 0.90, 0.86), 0.96)
    rig_glb(tmp_wife, os.path.join(MODELS, "CHR_Noah_Wife_rigged.glb"), is_sarai=True)

    tint_glb_texture(os.path.join(MODELS, "CHR_Abram.glb"), tmp_son, (0.94, 0.86, 0.78), 0.94)
    rig_glb(tmp_son, os.path.join(MODELS, "CHR_Noah_Son_rigged.glb"), is_sarai=False)

    tint_glb_texture(os.path.join(MODELS, "CHR_Sarai.glb"), tmp_dau, (0.86, 0.90, 0.96), 0.95)
    rig_glb(tmp_dau, os.path.join(MODELS, "CHR_Noah_Daughter_rigged.glb"), is_sarai=True)

    for p in (tmp_wife, tmp_son, tmp_dau):
        if os.path.exists(p):
            os.remove(p)

    # 3. Generate multi-species boarding animals + Raven & Olive-leaf Dove
    make_quadruped(
        os.path.join(MODELS, "ANI_Ox.glb"),
        body_size=(0.82, 0.76, 1.55), leg_h=0.68, neck_len=0.45, head_size=(0.42, 0.42, 0.56),
        body_col=[145, 98, 66, 255], accent_col=[108, 72, 48, 255], horns="ox",
    )
    make_quadruped(
        os.path.join(MODELS, "ANI_Goat.glb"),
        body_size=(0.44, 0.46, 0.92), leg_h=0.48, neck_len=0.32, head_size=(0.24, 0.26, 0.36),
        body_col=[176, 152, 122, 255], accent_col=[126, 102, 78, 255], horns="goat",
    )
    make_quadruped(
        os.path.join(MODELS, "ANI_Donkey.glb"),
        body_size=(0.56, 0.58, 1.24), leg_h=0.62, neck_len=0.44, head_size=(0.28, 0.30, 0.46),
        body_col=[142, 136, 126, 255], accent_col=[102, 96, 88, 255], horns=None, long_ears=True,
    )
    make_bird(os.path.join(MODELS, "ANI_Raven.glb"), [42, 44, 48, 255], [30, 32, 36, 255], olive_twig=False)
    make_bird(os.path.join(MODELS, "ANI_Dove_Olive.glb"), [242, 238, 228, 255], [228, 224, 214, 255], olive_twig=True)


if __name__ == "__main__":
    main()
