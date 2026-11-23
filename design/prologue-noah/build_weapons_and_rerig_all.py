import os
import sys
import numpy as np
import trimesh

sys.path.insert(0, r"c:\AI\gemini\promise-path-next\design\review-slice-01")
from rig_characters_glb import rig_glb

MODELS = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"


def pbr_mesh(mesh: trimesh.Trimesh, rgba, roughness=0.55, metallic=0.0):
    col = [c / 255.0 if c > 1.0 else float(c) for c in rgba]
    mat = trimesh.visual.material.PBRMaterial(
        baseColorFactor=col,
        metallicFactor=metallic,
        roughnessFactor=roughness,
    )
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def build_weapons():
    rx90 = trimesh.transformations.rotation_matrix(np.pi / 2.0, [1, 0, 0])

    # 1. WPN_BronzeSword.glb (Ancient Levantine/Canaanite straight bronze short sword — NO Islamic scimitar!)
    parts = []
    grip = trimesh.creation.cylinder(radius=0.022, height=0.18, sections=8)
    grip.apply_transform(rx90)
    parts.append(pbr_mesh(grip, [105, 68, 42, 255], roughness=0.85))
    pommel = trimesh.creation.icosphere(subdivisions=1, radius=0.036)
    pommel.apply_translation([0.0, -0.10, 0.0])
    parts.append(pbr_mesh(pommel, [186, 146, 78, 255], roughness=0.40, metallic=0.75))
    guard = trimesh.creation.box(extents=[0.14, 0.025, 0.04])
    guard.apply_translation([0.0, 0.095, 0.0])
    parts.append(pbr_mesh(guard, [186, 146, 78, 255], roughness=0.40, metallic=0.75))
    blade = trimesh.creation.box(extents=[0.048, 0.62, 0.012])
    blade.apply_translation([0.0, 0.41, 0.0])
    parts.append(pbr_mesh(blade, [202, 162, 92, 255], roughness=0.32, metallic=0.82))
    tip = trimesh.creation.cone(radius=0.028, height=0.14, sections=4)
    tip.apply_transform(rx90)
    tip.apply_transform(trimesh.transformations.rotation_matrix(-np.pi, [1, 0, 0]))
    tip.apply_translation([0.0, 0.78, 0.0])
    parts.append(pbr_mesh(tip, [202, 162, 92, 255], roughness=0.32, metallic=0.82))
    s = trimesh.Scene()
    for i, p in enumerate(parts):
        s.add_geometry(p, node_name=f"Sword_{i}")
    out = os.path.join(MODELS, "WPN_BronzeSword.glb")
    s.export(out)
    print(f"OK WEAPON {os.path.basename(out)} ({os.path.getsize(out):,} bytes)")

    # 2. WPN_CompositeBow.glb (Ancient Near Eastern recurve wood-horn composite bow + linen bowstring)
    parts = []
    segs = 14
    for i in range(segs):
        t0 = -1.0 + 2.0 * i / segs
        t1 = -1.0 + 2.0 * (i + 1) / segs
        y0, z0 = t0 * 0.62, -0.18 * (1.0 - t0 * t0) + 0.04 * (t0 ** 4)
        y1, z1 = t1 * 0.62, -0.18 * (1.0 - t1 * t1) + 0.04 * (t1 ** 4)
        dy, dz = y1 - y0, z1 - z0
        seg_len = float(np.hypot(dy, dz))
        limb = trimesh.creation.cylinder(radius=0.018 - 0.006 * abs(t0), height=seg_len * 1.08, sections=8)
        ang = float(np.arctan2(dy, dz))
        limb.apply_transform(trimesh.transformations.rotation_matrix(-ang, [1, 0, 0]))
        limb.apply_translation([0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5])
        parts.append(pbr_mesh(limb, [122, 82, 48, 255], roughness=0.78))
    bstring = trimesh.creation.cylinder(radius=0.004, height=1.22, sections=6)
    bstring.apply_transform(rx90)
    bstring.apply_translation([0.0, 0.0, 0.04])
    parts.append(pbr_mesh(bstring, [224, 212, 188, 255], roughness=0.90))
    s = trimesh.Scene()
    for i, p in enumerate(parts):
        s.add_geometry(p, node_name=f"Bow_{i}")
    out = os.path.join(MODELS, "WPN_CompositeBow.glb")
    s.export(out)
    print(f"OK WEAPON {os.path.basename(out)} ({os.path.getsize(out):,} bytes)")

    # 3. WPN_WoodenShield.glb (Bronze-Age leather-faced timber round/oval shield with bronze boss)
    parts = []
    body = trimesh.creation.cylinder(radius=0.34, height=0.032, sections=16)
    parts.append(pbr_mesh(body, [128, 92, 58, 255], roughness=0.86))
    boss = trimesh.creation.icosphere(subdivisions=2, radius=0.09)
    boss.apply_scale([1.0, 1.0, 0.55])
    boss.apply_translation([0.0, 0.0, -0.025])
    parts.append(pbr_mesh(boss, [186, 146, 78, 255], roughness=0.38, metallic=0.78))
    s = trimesh.Scene()
    for i, p in enumerate(parts):
        s.add_geometry(p, node_name=f"Shield_{i}")
    out = os.path.join(MODELS, "WPN_WoodenShield.glb")
    s.export(out)
    print(f"OK WEAPON {os.path.basename(out)} ({os.path.getsize(out):,} bytes)")

    # 4. WPN_Mallet.glb (Ancient wooden shipwright carpentry mallet for Noah & sons)
    parts = []
    handle = trimesh.creation.cylinder(radius=0.020, height=0.46, sections=8)
    handle.apply_transform(rx90)
    handle.apply_translation([0.0, 0.18, 0.0])
    parts.append(pbr_mesh(handle, [142, 102, 62, 255], roughness=0.88))
    head = trimesh.creation.box(extents=[0.11, 0.11, 0.24])
    head.apply_translation([0.0, 0.40, 0.0])
    parts.append(pbr_mesh(head, [98, 66, 38, 255], roughness=0.90))
    s = trimesh.Scene()
    for i, p in enumerate(parts):
        s.add_geometry(p, node_name=f"Mallet_{i}")
    out = os.path.join(MODELS, "WPN_Mallet.glb")
    s.export(out)
    print(f"OK TOOL {os.path.basename(out)} ({os.path.getsize(out):,} bytes)")


def main():
    build_weapons()
    # Re-rig Abram & Sarai with all 11 animations (including fixed Walk + Run + Combat suite)
    rig_glb(os.path.join(MODELS, "CHR_Abram.glb"), os.path.join(MODELS, "CHR_Abram_rigged.glb"), is_sarai=False)
    rig_glb(os.path.join(MODELS, "CHR_Sarai.glb"), os.path.join(MODELS, "CHR_Sarai_rigged.glb"), is_sarai=True)


if __name__ == "__main__":
    main()
