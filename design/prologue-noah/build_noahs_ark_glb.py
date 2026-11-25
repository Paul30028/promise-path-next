"""
Build Biblical 300:50:30 Noah's Ark GLB (Genesis 6:14-16) with 30 Progressive Construction Steps (V6 GF-02):
  - Ratio: EXACT 300 : 50 : 30 cubits (at 0.34 m/cubit -> 102.0m L x 17.0m W x 10.2m H)
  - 3 Spacious Walkable Decks (~3.2m clear headroom each):
      * Deck 1 (Lower):  Floor Y = 0.65m, Ceiling Y = 3.85m
      * Deck 2 (Middle): Floor Y = 3.95m, Ceiling Y = 7.05m (North-side Stair 1 leaves 4.3m central aisle clear)
      * Deck 3 (Upper):  Floor Y = 7.15m, Roof Ridge Y = 10.20m (1-cubit sunlit window band under eaves)
  - 30 Progressive Structural Step Groups (every +3.3% engineering visibly nails new ribs/planks/decks/pitch/roof!):
      * BuildStep_01_Mesh .. BuildStep_25_Mesh (+ CutawayFront_Step_XX_Mesh for +Z cutaway wall)
      * CutawayRoof_Step_26_Mesh .. CutawayRoof_Step_29_Mesh (4 progressive roof bays)
      * Stage3_Ramp_Mesh (Step 30 boarding gangplank)
      * StageScaffold_Mesh (exterior log scaffolding, dismantled at 100%)
  - Shared single 512x1536 3-band texture atlas (Wood / Pitch / Roof) -> compact ~1.1 MB GLB!
"""
import os
import numpy as np
import trimesh
from PIL import Image

OUT_GLB = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models\BLD_NoahsArk.glb"

L = 102.0   # X in [-51.0, +51.0]
W = 17.0    # Z in [-8.5, +8.5]
H = 10.2    # Y in [0.0, 10.2]
HL = L * 0.5
HW = W * 0.5


def make_band_pixels(size=512, mode="wood"):
    rng = np.random.default_rng(101 if mode == "wood" else (202 if mode == "pitch" else 303))
    img = np.zeros((size, size, 3), dtype=np.float32)
    planks = 12
    ph = size // planks
    y_grid = np.linspace(0, 1, size)[:, None]
    x_grid = np.linspace(0, 1, size)[None, :]
    grain = (
        np.sin(x_grid * 18.0 + np.sin(y_grid * 42.0) * 1.8) * 0.5
        + np.sin(y_grid * 190.0 + x_grid * 9.0) * 0.3
        + rng.normal(0, 0.08, (size, size))
    )
    for p in range(planks):
        y0 = p * ph
        y1 = size if p == planks - 1 else (p + 1) * ph
        if mode == "pitch":
            base = np.array([32, 26, 22], dtype=np.float32) + rng.uniform(-4, 5, 3)
        elif mode == "roof":
            base = np.array([64, 44, 30], dtype=np.float32) + rng.uniform(-9, 9, 3)
        else:
            base = np.array([108, 76, 48], dtype=np.float32) + rng.uniform(-12, 12, 3)
        block = base[None, None, :] * (1.0 + grain[y0:y1, :, None] * 0.14)
        block[:3, :, :] *= 0.45
        block[-2:, :, :] *= 0.68
        jx = int(rng.integers(40, size - 40))
        block[:, max(0, jx - 1):min(size, jx + 2), :] *= 0.50
        img[y0:y1, :, :] = np.clip(block, 0, 255)
    return img.astype(np.uint8)


def make_shared_atlas(size=512):
    # Band 0 (top in image, V in [0.67..1.00]): wood
    # Band 1 (mid in image, V in [0.34..0.66]): pitch
    # Band 2 (bot in image, V in [0.00..0.33]): roof
    wood = make_band_pixels(size, "wood")
    pitch = make_band_pixels(size, "pitch")
    roof = make_band_pixels(size, "roof")
    atlas = np.vstack([wood, pitch, roof])
    return Image.fromarray(atlas, mode="RGB")


def box_uv(extents, center, rot_x=0.0, rot_z=0.0, uv_scale=0.18, mat_band="wood"):
    m = trimesh.creation.box(extents=extents)
    if rot_x != 0.0:
        m.apply_transform(trimesh.transformations.rotation_matrix(rot_x, [1, 0, 0]))
    if rot_z != 0.0:
        m.apply_transform(trimesh.transformations.rotation_matrix(rot_z, [0, 0, 1]))
    m.apply_translation(center)
    v = m.vertices
    n = m.vertex_normals
    uv = np.zeros((len(v), 2), dtype=np.float32)
    abs_n = np.abs(n)
    use_yz = (abs_n[:, 0] >= abs_n[:, 1]) & (abs_n[:, 0] >= abs_n[:, 2])
    use_xz = (abs_n[:, 1] > abs_n[:, 0]) & (abs_n[:, 1] >= abs_n[:, 2])
    use_xy = ~(use_yz | use_xz)
    uv[use_yz] = v[use_yz][:, [2, 1]] * uv_scale
    uv[use_xz] = v[use_xz][:, [0, 2]] * uv_scale
    uv[use_xy] = v[use_xy][:, [0, 1]] * uv_scale
    # Remap V cleanly into the selected atlas band (PIL top=V:1.0, bottom=V:0.0 in glTF/trimesh)
    v_frac = np.mod(uv[:, 1], 1.0)
    if mat_band == "wood":
        v_low, v_span = 0.69, 0.29
    elif mat_band == "pitch":
        v_low, v_span = 0.36, 0.28
    else:
        v_low, v_span = 0.02, 0.29
    uv[:, 1] = v_low + v_frac * v_span
    m.visual = trimesh.visual.TextureVisuals(uv=uv)
    return m


def merge_group(meshes, shared_mat):
    if not meshes:
        return None
    comb = trimesh.util.concatenate(meshes)
    comb.visual = trimesh.visual.TextureVisuals(uv=comb.visual.uv, material=shared_mat)
    return comb


def main():
    atlas_img = make_shared_atlas(512)
    shared_mat = trimesh.visual.material.PBRMaterial(
        name="ArkSharedPBR",
        baseColorTexture=atlas_img,
        metallicFactor=0.0,
        roughnessFactor=0.84,
    )

    groups = {}  # node_name -> list of trimesh

    def add(node_name, mesh):
        groups.setdefault(node_name, []).append(mesh)

    # --- STEPS 01..10: Monumental Keel, Cribbing & 8 Progressive Rib Bays (0% -> 35%) ---
    add("BuildStep_01_Mesh", box_uv([L - 3.0, 0.72, 1.4], [0.0, 0.36, 0.0], mat_band="wood"))
    for sz in (-4.8, 4.8):
        add("BuildStep_01_Mesh", box_uv([L - 6.0, 0.55, 0.75], [0.0, 0.30, sz], mat_band="wood"))

    for cx in np.linspace(-46.0, 46.0, 19):
        add("BuildStep_02_Mesh", box_uv([1.2, 0.42, W - 4.4], [cx, 0.21, 0.0], mat_band="wood"))

    rib_xs = np.linspace(-47.5, 47.5, 25)
    for ri, rx in enumerate(rib_xs):
        step_idx = 3 + min(7, int(ri * 8 / len(rib_xs)))  # Steps 03..10
        gname = f"BuildStep_{step_idx:02d}_Mesh"
        hz_inner = HW - 1.45
        door_zone = abs(rx) < 3.0
        add(gname, box_uv([0.50, 0.45, hz_inner * 2.0], [rx, 0.50, 0.0], mat_band="wood"))
        for side in (-1, 1):
            if side == 1 and door_zone:
                add(gname, box_uv([0.50, 4.6, 0.50], [rx, 6.4, side * hz_inner], mat_band="wood"))
            else:
                add(gname, box_uv([0.50, 8.2, 0.50], [rx, 4.55, side * hz_inner], mat_band="wood"))
            add(gname, box_uv([0.42, 2.0, 0.42], [rx, 1.15, side * (hz_inner - 0.65)], rot_x=side * 0.45, mat_band="wood"))

    # --- STEP 11: Deck 1 (Lower Deck) Floor ---
    add("BuildStep_11_Mesh", box_uv([L - 3.0, 0.24, W - 2.6], [0.0, 0.55, 0.0], mat_band="wood"))

    # --- STEPS 12..16 & STEP 23: Outer Hull Planking Strakes + Waterproof Bilge Pitch ---
    course_ys = np.linspace(0.55, 8.15, 10)
    for ci, cy in enumerate(course_ys):
        bilge_in = (1.0 - ci / 3.0) * 0.95 if ci < 3 else 0.0
        cz = HW - bilge_in
        is_pitch_band = ci < 3
        band = "pitch" if is_pitch_band else "wood"
        # Wood hull rises in Steps 12..16; bottom 3 bilge courses also appear as wood in Step 12 and pitch-coated overlay in Step 23!
        step_back = f"BuildStep_{12 + min(4, ci // 2):02d}_Mesh"
        step_front = f"CutawayFront_Step_{12 + min(4, ci // 2):02d}_Mesh"
        add(step_back, box_uv([L - 1.2 - bilge_in * 1.4, 0.90, 0.48], [0.0, cy, -cz], mat_band="wood"))
        if is_pitch_band:
            add("BuildStep_23_Mesh", box_uv([L - 1.15 - bilge_in * 1.4, 0.91, 0.52], [0.0, cy, -cz], mat_band="pitch"))
        if cy < 3.9:
            seg_len = HL - 2.7 - bilge_in * 0.7
            for sx in (-1, 1):
                add(step_front, box_uv([seg_len, 0.90, 0.48], [sx * (2.7 + seg_len * 0.5), cy, cz], mat_band="wood"))
                if is_pitch_band:
                    add("CutawayFront_Step_23_Mesh", box_uv([seg_len, 0.91, 0.52], [sx * (2.7 + seg_len * 0.5), cy, cz], mat_band="pitch"))
        else:
            add(step_front, box_uv([L - 1.2 - bilge_in * 1.4, 0.90, 0.48], [0.0, cy, cz], mat_band="wood"))

    for sx in (-1, 1):
        for ci, cy in enumerate(course_ys):
            bilge_in = (1.0 - ci / 3.0) * 0.95 if ci < 3 else 0.0
            step_back = f"BuildStep_{12 + min(4, ci // 2):02d}_Mesh"
            add(step_back, box_uv([0.60, 0.90, (HW - bilge_in) * 2.0 + 0.45], [sx * (HL - 0.65 - bilge_in * 0.7), cy, 0.0], mat_band="wood"))
            if ci < 3:
                add("BuildStep_23_Mesh", box_uv([0.64, 0.91, (HW - bilge_in) * 2.0 + 0.49], [sx * (HL - 0.65 - bilge_in * 0.7), cy, 0.0], mat_band="pitch"))
        add("BuildStep_16_Mesh", box_uv([1.2, 10.6, 1.4], [sx * (HL - 0.1), 5.3, 0.0], rot_z=-sx * 0.06, mat_band="wood"))

    # --- STEPS 17..21: 3-Deck Interior Pillars, Stalls ("分一间一间地造") & Side-Mounted North Stairs ---
    stall_xs = np.linspace(-44.0, 44.0, 12)
    for sx in stall_xs:
        for sz in (-3.2, 3.2):
            add("BuildStep_17_Mesh", box_uv([0.46, 8.8, 0.46], [sx, 4.95, sz], mat_band="wood"))
        add("BuildStep_17_Mesh", box_uv([0.42, 0.36, W - 1.4], [sx, 3.65, 0.0], mat_band="wood"))
        add("BuildStep_19_Mesh", box_uv([0.42, 0.36, W - 1.4], [sx, 6.85, 0.0], mat_band="wood"))
        add("BuildStep_21_Mesh", box_uv([0.42, 0.36, W - 1.4], [sx, 9.20, 0.0], mat_band="wood"))
        for di, deck_y in enumerate((0.65, 3.95, 7.15)):
            st_step = ("BuildStep_17_Mesh", "BuildStep_19_Mesh", "BuildStep_21_Mesh")[di]
            for side in (-1, 1):
                if deck_y == 0.65 and side == 1 and abs(sx) < 5.0:
                    continue
                add(st_step, box_uv([0.18, 1.75, 4.4], [sx, deck_y + 0.92, side * 5.5], mat_band="wood"))
                for ry in (0.65, 1.35):
                    add(st_step, box_uv([7.2, 0.14, 0.14], [sx + 3.6, deck_y + ry, side * 3.2], mat_band="wood"))
                add("BuildStep_24_Mesh", box_uv([0.24, 0.24, 4.4], [sx, deck_y + 0.14, side * 5.5], mat_band="pitch"))

    # North Stair 1 (Step 17) & Deck 2 Floor (Step 18)
    for i in range(14):
        t = (i + 0.5) / 14.0
        add("BuildStep_17_Mesh", box_uv([0.95, 0.18, 1.85], [2.5 + t * 11.0, 0.65 + t * 3.30, -2.15], mat_band="wood"))
    for sz in (-3.08, -1.22):
        add("BuildStep_17_Mesh", box_uv([11.8, 0.22, 0.14], [8.0, 2.95, sz], rot_z=0.29, mat_band="wood"))

    add("BuildStep_18_Mesh", box_uv([52.5, 0.24, W - 1.6], [-24.25, 3.85, 0.0], mat_band="wood"))
    add("BuildStep_18_Mesh", box_uv([36.5, 0.24, W - 1.6], [32.25, 3.85, 0.0], mat_band="wood"))
    add("BuildStep_18_Mesh", box_uv([12.2, 0.24, 4.5], [8.0, 3.85, -5.45], mat_band="wood"))
    add("BuildStep_18_Mesh", box_uv([12.2, 0.24, 8.85], [8.0, 3.85, 3.275], mat_band="wood"))
    add("BuildStep_18_Mesh", box_uv([11.8, 0.14, 0.14], [8.0, 4.75, -1.18], mat_band="wood"))

    # North Stair 2 (Step 19) & Deck 3 Floor (Step 20)
    for i in range(14):
        t = (i + 0.5) / 14.0
        add("BuildStep_19_Mesh", box_uv([0.95, 0.18, 1.85], [18.5 + t * 11.0, 3.95 + t * 3.20, -2.15], mat_band="wood"))
    for sz in (-3.08, -1.22):
        add("BuildStep_19_Mesh", box_uv([11.8, 0.22, 0.14], [24.0, 6.20, sz], rot_z=0.28, mat_band="wood"))

    add("BuildStep_20_Mesh", box_uv([68.5, 0.24, W - 1.4], [-16.25, 7.05, 0.0], mat_band="wood"))
    add("BuildStep_20_Mesh", box_uv([20.5, 0.24, W - 1.4], [40.25, 7.05, 0.0], mat_band="wood"))
    add("BuildStep_20_Mesh", box_uv([12.2, 0.24, 4.5], [24.0, 7.05, -5.45], mat_band="wood"))
    add("BuildStep_20_Mesh", box_uv([12.2, 0.24, 8.85], [24.0, 7.05, 3.275], mat_band="wood"))
    add("BuildStep_20_Mesh", box_uv([11.8, 0.14, 0.14], [24.0, 7.95, -1.18], mat_band="wood"))

    # --- STEP 22: Side Doorway Frame + Genesis 6:16 1-Cubit Window Band ---
    add("BuildStep_22_Mesh", box_uv([0.55, 3.6, 0.75], [-2.75, 2.3, HW], mat_band="wood"))
    add("BuildStep_22_Mesh", box_uv([0.55, 3.6, 0.75], [2.75, 2.3, HW], mat_band="wood"))
    add("BuildStep_22_Mesh", box_uv([6.2, 0.55, 0.85], [0.0, 4.1, HW], mat_band="wood"))
    for mx in np.linspace(-48.0, 48.0, 33):
        add("BuildStep_22_Mesh", box_uv([0.34, 0.68, 0.36], [mx, 8.88, -HW], mat_band="wood"))
        add("CutawayFront_Step_22_Mesh", box_uv([0.34, 0.68, 0.36], [mx, 8.88, HW], mat_band="wood"))

    # --- STEPS 24..25: Interior & Eaves Pitch Sealing ---
    for sz in (-HW + 1.3, HW - 1.3):
        add("BuildStep_24_Mesh", box_uv([L - 3.4, 0.35, 0.35], [0.0, 0.75, sz], mat_band="pitch"))
    add("BuildStep_25_Mesh", box_uv([L + 0.4, 0.28, 0.62], [0.0, 8.55, -HW], mat_band="pitch"))
    add("CutawayFront_Step_25_Mesh", box_uv([L + 0.4, 0.28, 0.62], [0.0, 8.55, HW], mat_band="pitch"))
    add("BuildStep_25_Mesh", box_uv([L + 0.8, 0.44, 0.82], [0.0, 9.35, -HW], mat_band="pitch"))
    add("CutawayFront_Step_25_Mesh", box_uv([L + 0.8, 0.44, 0.82], [0.0, 9.35, HW], mat_band="pitch"))

    # --- STEPS 26..29: 4 Progressive Pitched Roof Bays (Cutaway-Compatible) ---
    roof_slope = 0.13
    bay_len = (L + 1.8) / 4.0
    for bi in range(4):
        rname = f"CutawayRoof_Step_{26 + bi:02d}_Mesh"
        bx = -0.5 * (L + 1.8) + (bi + 0.5) * bay_len
        for side in (-1, 1):
            add(rname, box_uv([bay_len + 0.08, 0.32, HW + 1.5], [bx, 9.75, side * (HW * 0.5 + 0.15)], rot_x=side * roof_slope, mat_band="roof"))
        add(rname, box_uv([bay_len + 0.12, 0.52, 0.85], [bx, 10.18, 0.0], mat_band="roof"))

    # --- STEP 30: Boarding Gangplank Ramp + Sliding Heavy Side Door ---
    ramp_steps = 22
    for i in range(ramp_steps):
        t = i / float(ramp_steps - 1)
        add("Stage3_Ramp_Mesh", box_uv([5.0, 0.22, 0.62], [0.0, 0.62 - t * 1.45, HW + t * 11.0], mat_band="wood"))
    for sx in (-2.55, 2.55):
        add("Stage3_Ramp_Mesh", box_uv([0.22, 0.20, 11.4], [sx, 1.05, HW + 5.5], rot_x=0.13, mat_band="wood"))
        for p in range(6):
            pt = p / 5.0
            add("Stage3_Ramp_Mesh", box_uv([0.24, 1.55, 0.24], [sx, 0.62 - pt * 1.35 + 0.65, HW + 0.5 + pt * 10.0], mat_band="wood"))

    # Sealed Side Door Leaf (visible when ramp is retracted / Yahweh shuts the door in Gen 7:16!)
    add("SealedSideDoor_Mesh", box_uv([5.4, 3.45, 0.46], [0.0, 2.25, HW - 0.05], mat_band="pitch"))

    # --- PROGRESSIVE TIMBER SCAFFOLDING (StageScaffold_Mesh) ---
    for sx in np.linspace(-44.0, 44.0, 11):
        if abs(sx) < 5.5:
            continue
        for sz in (HW + 1.35, -HW - 1.35):
            add("StageScaffold_Mesh", box_uv([0.24, 9.8, 0.24], [sx, 4.9, sz], mat_band="wood"))
            add("StageScaffold_Mesh", box_uv([0.22, 9.8, 0.22], [sx, 4.9, sz + (1.2 if sz > 0 else -1.2)], mat_band="wood"))
            for cy in (3.8, 7.1):
                add("StageScaffold_Mesh", box_uv([8.6, 0.14, 1.15], [sx, cy, sz + (0.6 if sz > 0 else -0.6)], mat_band="wood"))
                add("StageScaffold_Mesh", box_uv([0.16, 0.16, 1.45], [sx, cy - 0.1, sz + (0.6 if sz > 0 else -0.6)], mat_band="wood"))

    scene = trimesh.Scene()
    total_tris = 0
    for name in sorted(groups.keys()):
        m = merge_group(groups[name], shared_mat)
        if m is not None:
            scene.add_geometry(m, node_name=name, geom_name=name.replace("_Mesh", ""))
            total_tris += len(m.faces)

    scene.export(OUT_GLB)
    print(f"OK 30-STEP BIBLICAL ARK GLB: {OUT_GLB} ({os.path.getsize(OUT_GLB):,} bytes)")
    print(f"   Nodes ({len(groups)}): {total_tris:,} tris")


if __name__ == "__main__":
    main()
