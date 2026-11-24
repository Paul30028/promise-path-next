"""
Build Biblical 300:50:30 Noah's Ark GLB (Genesis 6:14-16) at true monumental scale:
  - Ratio: EXACT 300 : 50 : 30 cubits (at 0.34 m/cubit -> 102.0m L x 17.0m W x 10.2m H)
  - 3 Spacious Walkable Decks (each ~3.2m clear headroom so Noah at 1.68m eye height feels truly INSIDE a cathedral-scale wooden vessel!):
      * Deck 1 (Lower):  Floor Y = 0.65m, Ceiling Y = 3.85m (Keel spine, twin rows of animal stalls, 6.2m wide central walkway)
      * Deck 2 (Middle): Floor Y = 3.95m, Ceiling Y = 7.05m (Reached via wide gradual central wooden stairs, grain & clean-animal rooms)
      * Deck 3 (Upper):  Floor Y = 7.15m, Roof Ridge Y = 10.20m (1-cubit = 0.36m continuous sunlit/vent window band under eaves, aviaries & family quarters)
  - Side Doorway on +Z wall (X in [-2.6, +2.6], Y in [0.65, 3.65]) with sturdy handrail boarding ramp descending to Y = -0.8m (embeds cleanly into ground).
  - Toggleable Stage & Cutaway Node Groups:
      Stage1_KeelRibs_Mesh
      Stage2_HullBackEnds_Mesh / Stage2_HullBackEnds_Bitumen_Mesh
      Stage2_HullFrontCutaway_Mesh / Stage2_HullFrontCutaway_Bitumen_Mesh
      Interior_3Decks_Mesh / Interior_Bitumen_Mesh
      Stage3_RoofCutaway_Mesh
      Stage3_Ramp_Mesh
"""
import os
import numpy as np
import trimesh
from PIL import Image, ImageDraw

OUT_GLB = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models\BLD_NoahsArk.glb"

# Exact Biblical 300:50:30 cubits at 0.34 m/cubit
L = 102.0   # X in [-51.0, +51.0]
W = 17.0    # Z in [-8.5, +8.5]
H = 10.2    # Y in [0.0, 10.2]
HL = L * 0.5
HW = W * 0.5


def make_aged_cypress_texture(size=512, mode="wood"):
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
            # Distinct darker weathered cedar shingle/plank roof so finished 100% Ark reads unmistakably sealed!
            base = np.array([64, 44, 30], dtype=np.float32) + rng.uniform(-9, 9, 3)
        else:
            base = np.array([108, 76, 48], dtype=np.float32) + rng.uniform(-12, 12, 3)
        block = base[None, None, :] * (1.0 + grain[y0:y1, :, None] * 0.14)
        block[:3, :, :] *= 0.45
        block[-2:, :, :] *= 0.68
        jx = int(rng.integers(40, size - 40))
        block[:, max(0, jx - 1):min(size, jx + 2), :] *= 0.50
        img[y0:y1, :, :] = np.clip(block, 0, 255)
    return Image.fromarray(img.astype(np.uint8), mode="RGB")


def box_uv(extents, center, rot_x=0.0, rot_z=0.0, uv_scale=0.18):
    m = trimesh.creation.box(extents=extents)
    if rot_x != 0.0:
        m.apply_transform(trimesh.transformations.rotation_matrix(rot_x, [1, 0, 0]))
    if rot_z != 0.0:
        m.apply_transform(trimesh.transformations.rotation_matrix(rot_z, [0, 0, 1]))
    m.apply_translation(center)
    # Clean world-box planar UVs based on dominant normal
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
    m.visual = trimesh.visual.TextureVisuals(uv=uv)
    return m


def merge_group(meshes, img, roughness=0.88):
    if not meshes:
        return None
    comb = trimesh.util.concatenate(meshes)
    mat = trimesh.visual.material.PBRMaterial(
        baseColorTexture=img,
        metallicFactor=0.0,
        roughnessFactor=roughness,
    )
    comb.visual = trimesh.visual.TextureVisuals(uv=comb.visual.uv, material=mat)
    return comb


def main():
    wood_img = make_aged_cypress_texture(512, mode="wood")
    pitch_img = make_aged_cypress_texture(512, mode="pitch")
    roof_img = make_aged_cypress_texture(512, mode="roof")

    s1_wood = []
    s2_back_wood, s2_back_pitch = [], []
    s2_front_wood, s2_front_pitch = [], []
    int_wood, int_pitch = [], []
    s3_roof_wood = []
    s3_ramp_wood = []

    # --- STAGE 1: Monumental Keel, Low Cribbing Blocks & 25 Inner Structural Ribs (STRICTLY INSIDE HULL!) ---
    s1_wood.append(box_uv([L - 3.0, 0.72, 1.4], [0.0, 0.36, 0.0]))
    for sz in (-4.8, 4.8):
        s1_wood.append(box_uv([L - 6.0, 0.55, 0.75], [0.0, 0.30, sz]))
    for cx in np.linspace(-46.0, 46.0, 19):
        s1_wood.append(box_uv([1.2, 0.42, W - 4.4], [cx, 0.21, 0.0]))

    rib_xs = np.linspace(-47.5, 47.5, 25)
    for rx in rib_xs:
        # Keep structural ribs strictly INSIDE the tapered lower bilge (<= HW - 1.35) so ZERO skeleton pokes out of finished hull!
        hz_inner = HW - 1.45
        door_zone = abs(rx) < 3.0
        s1_wood.append(box_uv([0.50, 0.45, hz_inner * 2.0], [rx, 0.50, 0.0]))
        for side in (-1, 1):
            if side == 1 and door_zone:
                s1_wood.append(box_uv([0.50, 4.6, 0.50], [rx, 6.4, side * hz_inner]))
            else:
                s1_wood.append(box_uv([0.50, 8.2, 0.50], [rx, 4.55, side * hz_inner]))
            s1_wood.append(box_uv([0.42, 2.0, 0.42], [rx, 1.15, side * (hz_inner - 0.65)], rot_x=side * 0.45))

    # --- STAGE 2: Seamless Sealed Watertight Hull Planking + Crisp Recessed 1-Cubit Window Band ---
    course_ys = np.linspace(0.55, 8.15, 10)
    for ci, cy in enumerate(course_ys):
        bilge_in = (1.0 - ci / 3.0) * 0.95 if ci < 3 else 0.0
        cz = HW - bilge_in
        is_pitch_band = ci < 3
        # Overlap plank height slightly (0.90m) so hull is 100% solid watertight with ZERO gaps!
        (s2_back_pitch if is_pitch_band else s2_back_wood).append(
            box_uv([L - 1.2 - bilge_in * 1.4, 0.90, 0.48], [0.0, cy, -cz])
        )
        if cy < 3.9:
            seg_len = HL - 2.7 - bilge_in * 0.7
            for sx in (-1, 1):
                (s2_front_pitch if is_pitch_band else s2_front_wood).append(
                    box_uv([seg_len, 0.90, 0.48], [sx * (2.7 + seg_len * 0.5), cy, cz])
                )
        else:
            (s2_front_pitch if is_pitch_band else s2_front_wood).append(
                box_uv([L - 1.2 - bilge_in * 1.4, 0.90, 0.48], [0.0, cy, cz])
            )

    for sx in (-1, 1):
        for ci, cy in enumerate(course_ys):
            bilge_in = (1.0 - ci / 3.0) * 0.95 if ci < 3 else 0.0
            is_pitch_band = ci < 3
            (s2_back_pitch if is_pitch_band else s2_back_wood).append(
                box_uv([0.60, 0.90, (HW - bilge_in) * 2.0 + 0.45], [sx * (HL - 0.65 - bilge_in * 0.7), cy, 0.0])
            )
        s2_back_wood.append(box_uv([1.2, 10.6, 1.4], [sx * (HL - 0.1), 5.3, 0.0], rot_z=-sx * 0.06))

    # Genesis 6:16 Crisp 1-Cubit (~0.50m) Window Band (Y=8.60..9.15) with bold dark shadow recess & evenly spaced mullions!
    for mx in np.linspace(-48.0, 48.0, 33):
        s2_back_wood.append(box_uv([0.34, 0.68, 0.36], [mx, 8.88, -HW]))
        s2_front_wood.append(box_uv([0.34, 0.68, 0.36], [mx, 8.88, HW]))
    # Continuous dark pitch eaves fascia framing the 1-cubit window band so it reads crisply even from 60m away!
    s2_back_pitch.append(box_uv([L + 0.4, 0.28, 0.62], [0.0, 8.55, -HW]))
    s2_front_pitch.append(box_uv([L + 0.4, 0.28, 0.62], [0.0, 8.55, HW]))
    s2_back_pitch.append(box_uv([L + 0.8, 0.44, 0.82], [0.0, 9.35, -HW]))
    s2_front_pitch.append(box_uv([L + 0.8, 0.44, 0.82], [0.0, 9.35, HW]))

    # Side doorway frame (always visible on Stage 2+)
    s2_back_wood.append(box_uv([0.55, 3.6, 0.75], [-2.75, 2.3, HW]))
    s2_back_wood.append(box_uv([0.55, 3.6, 0.75], [2.75, 2.3, HW]))
    s2_back_wood.append(box_uv([6.2, 0.55, 0.85], [0.0, 4.1, HW]))

    # --- WALKABLE 3-DECK BIBLICAL INTERIOR (Each Deck ~3.2m Tall, Wide Central Aisle + Twin Stall Rows!) ---
    # Deck 1 (Lower Deck Floor Y = 0.65)
    int_wood.append(box_uv([L - 3.0, 0.24, W - 2.6], [0.0, 0.55, 0.0]))
    # Inner bitumen pitch waterproof strips along lower deck edges
    for sz in (-HW + 1.3, HW - 1.3):
        int_pitch.append(box_uv([L - 3.4, 0.35, 0.35], [0.0, 0.75, sz]))

    # Deck 2 (Middle Deck Floor Y = 3.95) — stairwell opening ONLY on North side aisle (Z in [-3.2, -1.15]),
    # leaving a completely open 4.3m-wide main corridor (Z in [-1.15, +3.15]) straight past the stairs to the rear cabin!
    int_wood.append(box_uv([52.5, 0.24, W - 1.6], [-24.25, 3.85, 0.0]))   # West half (-50.5..+2.0)
    int_wood.append(box_uv([36.5, 0.24, W - 1.6], [32.25, 3.85, 0.0]))    # East half (+14.0..+50.5)
    int_wood.append(box_uv([12.2, 0.24, 4.5], [8.0, 3.85, -5.45]))        # North stalls behind Stair 1
    int_wood.append(box_uv([12.2, 0.24, 8.85], [8.0, 3.85, 3.275]))       # Wide open central+south walkway past Stair 1!
    int_wood.append(box_uv([11.8, 0.14, 0.14], [8.0, 4.75, -1.18]))       # Deck 2 stairwell guardrail

    # Deck 3 (Upper Deck Floor Y = 7.15) — stairwell opening ONLY on North side aisle (Z in [-3.2, -1.15])
    int_wood.append(box_uv([68.5, 0.24, W - 1.4], [-16.25, 7.05, 0.0]))   # West half (-50.5..+18.0)
    int_wood.append(box_uv([20.5, 0.24, W - 1.4], [40.25, 7.05, 0.0]))    # East half (+30.0..+50.5)
    int_wood.append(box_uv([12.2, 0.24, 4.5], [24.0, 7.05, -5.45]))       # North stalls behind Stair 2
    int_wood.append(box_uv([12.2, 0.24, 8.85], [24.0, 7.05, 3.275]))      # Wide open central+south walkway past Stair 2!
    int_wood.append(box_uv([11.8, 0.14, 0.14], [24.0, 7.95, -1.18]))      # Deck 3 stairwell guardrail

    # Heavy interior structural pillars & overhead deck beams + Biblical Compartment Stalls ("分一间一间地造" Gen 6:14)
    stall_xs = np.linspace(-44.0, 44.0, 12)
    for sx in stall_xs:
        # Twin rows of towering interior pillars flanking the 6.4m wide central aisle (Z = ±3.2)
        for sz in (-3.2, 3.2):
            int_wood.append(box_uv([0.46, 8.8, 0.46], [sx, 4.95, sz]))
        # Cross ceiling beams on Deck 1, 2, 3
        for by in (3.65, 6.85, 9.20):
            int_wood.append(box_uv([0.42, 0.36, W - 1.4], [sx, by, 0.0]))
        # Wooden stall divider walls & rails along Port (-Z: -8.0..-3.2) & Starboard (+Z: +3.2..+8.0)
        for deck_y in (0.65, 3.95, 7.15):
            for side in (-1, 1):
                if deck_y == 0.65 and side == 1 and abs(sx) < 5.0:
                    continue  # Keep side entrance foyer wide open!
                # Stall partition wall (timber slats)
                int_wood.append(box_uv([0.18, 1.75, 4.4], [sx, deck_y + 0.92, side * 5.5]))
                # Front stall horizontal corral rails facing the central walkway
                for ry in (0.65, 1.35):
                    int_wood.append(box_uv([7.2, 0.14, 0.14], [sx + 3.6, deck_y + ry, side * 3.2]))
                # Pitch caulked base strip along stall wall
                int_pitch.append(box_uv([0.24, 0.24, 4.4], [sx, deck_y + 0.14, side * 5.5]))

    # Side-Mounted Timber Staircases along North Aisle (Z=-2.15, width 1.85m) so the 4.3m Main Corridor
    # goes straight past every staircase into the Rear Cabin on Deck 1, Deck 2, and Deck 3!
    # Stair 1: Lower Deck (X=2.5, Y=0.65) -> Middle Deck (X=13.5, Y=3.95)
    for i in range(14):
        t = (i + 0.5) / 14.0
        stx = 2.5 + t * 11.0
        sty = 0.65 + t * 3.30
        int_wood.append(box_uv([0.95, 0.18, 1.85], [stx, sty, -2.15]))
    for sz in (-3.08, -1.22):
        int_wood.append(box_uv([11.8, 0.22, 0.14], [8.0, 2.95, sz], rot_z=0.29))

    # Stair 2: Middle Deck (X=18.5, Y=3.95) -> Upper Deck (X=29.5, Y=7.15)
    for i in range(14):
        t = (i + 0.5) / 14.0
        stx = 18.5 + t * 11.0
        sty = 3.95 + t * 3.20
        int_wood.append(box_uv([0.95, 0.18, 1.85], [stx, sty, -2.15]))
    for sz in (-3.08, -1.22):
        int_wood.append(box_uv([11.8, 0.22, 0.14], [24.0, 6.20, sz], rot_z=0.28))

    # --- STAGE 3: Pitched Gabled Timber Roof (Cutaway) + Sturdy Boarding Ramp (Retractable) ---
    roof_slope = 0.13
    for side in (-1, 1):
        s3_roof_wood.append(
            box_uv([L + 1.8, 0.32, HW + 1.5], [0.0, 9.75, side * (HW * 0.5 + 0.15)], rot_x=side * roof_slope)
        )
    # Ridge cap beam at Y = 10.2
    s3_roof_wood.append(box_uv([L + 2.0, 0.52, 0.85], [0.0, 10.18, 0.0]))

    # --- PROGRESSIVE TIMBER SCAFFOLDING (Visible while 5%..99% built, dismantled at 100%!) ---
    s_scaff_wood = []
    for sx in np.linspace(-44.0, 44.0, 11):
        if abs(sx) < 5.5:
            continue  # Keep boarding doorway clear
        for sz in (HW + 1.35, -HW - 1.35):
            # Vertical timber scaffold poles
            s_scaff_wood.append(box_uv([0.24, 9.8, 0.24], [sx, 4.9, sz]))
            s_scaff_wood.append(box_uv([0.22, 9.8, 0.22], [sx, 4.9, sz + (1.2 if sz > 0 else -1.2)]))
            # Horizontal plank catwalks at Deck 2 (3.9m) & Deck 3 (7.2m)
            for cy in (3.8, 7.1):
                s_scaff_wood.append(box_uv([8.6, 0.14, 1.15], [sx, cy, sz + (0.6 if sz > 0 else -0.6)]))
                s_scaff_wood.append(box_uv([0.16, 0.16, 1.45], [sx, cy - 0.1, sz + (0.6 if sz > 0 else -0.6)]))

    # Wide Boarding Gangplank Ramp (+Z side, descending from Z=+8.5 Y=0.65 down to Z=+19.5 Y=-0.90)
    ramp_steps = 22
    for i in range(ramp_steps):
        t = i / float(ramp_steps - 1)
        rz = HW + t * 11.0
        ry = 0.62 - t * 1.45
        s3_ramp_wood.append(box_uv([5.0, 0.22, 0.62], [0.0, ry, rz]))
    for sx in (-2.55, 2.55):
        # Sloped handrail beams + support posts
        s3_ramp_wood.append(box_uv([0.22, 0.20, 11.4], [sx, 1.05, HW + 5.5], rot_x=0.13))
        for p in range(6):
            pt = p / 5.0
            pz = HW + 0.5 + pt * 10.0
            py = 0.62 - pt * 1.35
            s3_ramp_wood.append(box_uv([0.24, 1.55, 0.24], [sx, py + 0.65, pz]))

    # Assemble clean named scene
    scene = trimesh.Scene()
    groups = [
        ("Stage1_KeelRibs_Mesh", s1_wood, wood_img, 0.89),
        ("Stage2_HullBackEnds_Mesh", s2_back_wood, wood_img, 0.88),
        ("Stage2_HullBackEnds_Bitumen_Mesh", s2_back_pitch, pitch_img, 0.68),
        ("Stage2_HullFrontCutaway_Mesh", s2_front_wood, wood_img, 0.88),
        ("Stage2_HullFrontCutaway_Bitumen_Mesh", s2_front_pitch, pitch_img, 0.68),
        ("Interior_3Decks_Mesh", int_wood, wood_img, 0.86),
        ("Interior_Bitumen_Mesh", int_pitch, pitch_img, 0.66),
        ("Stage3_RoofCutaway_Mesh", s3_roof_wood, roof_img, 0.86),
        ("Stage3_Ramp_Mesh", s3_ramp_wood, wood_img, 0.90),
        ("StageScaffold_Mesh", s_scaff_wood, wood_img, 0.92),
    ]
    total_tris = 0
    for name, mlist, tex, rough in groups:
        m = merge_group(mlist, tex, rough)
        if m is not None:
            scene.add_geometry(m, node_name=name, geom_name=name.replace("_Mesh", ""))
            total_tris += len(m.faces)

    scene.export(OUT_GLB)
    print(f"OK BIBLICAL ARK GLB: {OUT_GLB} ({os.path.getsize(OUT_GLB):,} bytes)")
    print(f"   Dimensions (300:50:30 @ 0.34m/cubit): {L}m L x {W}m W x {H}m H | Tris: {total_tris:,}")
    print(f"   Bounds: {scene.bounds.round(3).tolist()}")
    print(f"   Nodes: {list(scene.graph.nodes_geometry)}")


if __name__ == "__main__":
    main()
