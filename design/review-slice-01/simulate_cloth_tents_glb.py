"""
Real 3D Mass-Spring Verlet Cloth Physics Simulator & Handcrafted Tent GLB Exporter
Produces physics-simulated, UV-textured, non-procedural-looking GLB assets:
  1. BLD_MainTent_cloth.glb      (Patriarch Goat-Hair Pavilion with real tension creases, sag & hanging fringe)
  2. BLD_HealingCanopy_cloth.glb (Herbal Healing Linen Canopy with real cloth sag & pinched olive curtains)
"""
import os
import math
import numpy as np
import trimesh
from PIL import Image

TEX_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\textures"
OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)


def load_tex(fname, tint=(1.0, 1.0, 1.0), size=512):
    p = os.path.join(TEX_DIR, fname)
    im = Image.open(p).convert("RGB").resize((size, size), Image.LANCZOS)
    if tint != (1.0, 1.0, 1.0):
        arr = np.array(im, dtype=np.float32)
        arr[:, :, 0] *= tint[0]
        arr[:, :, 1] *= tint[1]
        arr[:, :, 2] *= tint[2]
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return im


def make_mat(name, tex_im=None, base_color=(200, 180, 150, 255), roughness=0.92, double_sided=True):
    return trimesh.visual.material.PBRMaterial(
        name=name,
        baseColorTexture=tex_im,
        baseColorFactor=base_color if tex_im is None else (255, 255, 255, 255),
        roughnessFactor=roughness,
        metallicFactor=0.0,
        doubleSided=double_sided,
    )


def simulate_verlet_cloth(nx, nz, width, depth, y_ridge, y_eave, pin_fn, wind_vec=(0.18, 0.0, 0.12), steps=220, skirt_drop=0.22):
    """True 3D mass-spring Verlet cloth physics simulation (Y-up for Godot!)."""
    xs = np.linspace(-width * 0.5, width * 0.5, nx)
    zs = np.linspace(-depth * 0.5, depth * 0.5, nz)
    pos = np.zeros((nz, nx, 3), dtype=np.float64)
    uvs = np.zeros((nz, nx, 2), dtype=np.float64)
    pinned = np.zeros((nz, nx), dtype=bool)

    for r in range(nz):
        for c in range(nx):
            u = c / (nx - 1)
            v = r / (nz - 1)
            x = xs[c]
            z = zs[r]
            nz_abs = abs(v - 0.5) * 2.0
            y = y_eave + (y_ridge - y_eave) * max(0.0, 1.0 - nz_abs)
            # Outer valance overhang drops slightly at perimeter
            if r == 0 or r == nz - 1 or c == 0 or c == nx - 1:
                y -= skirt_drop * 0.35
            pos[r, c] = [x, y, z]
            uvs[r, c] = [u * 2.0, v * 2.0]
            if pin_fn(x, z, u, v):
                pinned[r, c] = True

    rest_x = np.linalg.norm(pos[:, 1:] - pos[:, :-1], axis=2) * 1.015
    rest_z = np.linalg.norm(pos[1:, :] - pos[:-1, :], axis=2) * 1.025
    rest_d1 = np.linalg.norm(pos[1:, 1:] - pos[:-1, :-1], axis=2) * 1.015
    rest_d2 = np.linalg.norm(pos[1:, :-1] - pos[:-1, 1:], axis=2) * 1.015

    prev = pos.copy()
    dt = 0.022
    grav = np.array([wind_vec[0], -5.2, wind_vec[2]], dtype=np.float64)

    for step in range(steps):
        vel = (pos - prev) * 0.965
        prev = pos.copy()
        # Subtle spatial breeze gust for asymmetric organic folds
        gust = np.sin(pos[:, :, 0] * 1.7 + step * 0.04) * 0.25
        acc = np.broadcast_to(grav, pos.shape).copy()
        acc[:, :, 1] += gust * 0.35
        pos = pos + vel + acc * (dt * dt)

        # Iterative PBD distance constraints (4 passes per step for crisp fabric tension)
        for _ in range(4):
            # Horizontal
            d = pos[:, 1:] - pos[:, :-1]
            dist = np.linalg.norm(d, axis=2, keepdims=True) + 1e-8
            corr = d * (1.0 - rest_x[:, :, None] / dist) * 0.5
            pos[:, :-1] += corr * (~pinned[:, :-1, None])
            pos[:, 1:] -= corr * (~pinned[:, 1:, None])
            # Vertical
            d = pos[1:, :] - pos[:-1, :]
            dist = np.linalg.norm(d, axis=2, keepdims=True) + 1e-8
            corr = d * (1.0 - rest_z[:, :, None] / dist) * 0.5
            pos[:-1, :] += corr * (~pinned[:-1, :, None])
            pos[1:, :] -= corr * (~pinned[1:, :, None])
            # Shear diagonals (creates authentic diagonal tension creases from posts!)
            d = pos[1:, 1:] - pos[:-1, :-1]
            dist = np.linalg.norm(d, axis=2, keepdims=True) + 1e-8
            corr = d * (1.0 - rest_d1[:, :, None] / dist) * 0.35
            pos[:-1, :-1] += corr * (~pinned[:-1, :-1, None])
            pos[1:, 1:] -= corr * (~pinned[1:, 1:, None])

            d = pos[1:, :-1] - pos[:-1, 1:]
            dist = np.linalg.norm(d, axis=2, keepdims=True) + 1e-8
            corr = d * (1.0 - rest_d2[:, :, None] / dist) * 0.35
            pos[:-1, 1:] += corr * (~pinned[:-1, 1:, None])
            pos[1:, :-1] -= corr * (~pinned[1:, :-1, None])

        # Prevent any unpinned corner from sagging past realistic fabric drape bounds
        pos[:, :, 1] = np.clip(pos[:, :, 1], y_eave - 0.18, y_ridge + 0.10)

    # Add natural hanging scalloped skirt around outer rim
    for r in range(nz):
        for c in range(nx):
            if r == 0 or r == nz - 1 or c == 0 or c == nx - 1:
                pos[r, c, 1] -= skirt_drop * (0.75 + 0.25 * abs(math.sin((c + r) * 0.9)))

    verts = pos.reshape(-1, 3)
    uv_flat = uvs.reshape(-1, 2)
    faces = []
    for r in range(nz - 1):
        for c in range(nx - 1):
            i0 = r * nx + c
            i1 = i0 + 1
            i2 = i0 + nx
            i3 = i2 + 1
            faces.append([i0, i2, i1])
            faces.append([i1, i2, i3])
    return verts, np.array(faces, dtype=np.int64), uv_flat


def make_hewn_post(p0, p1, r0, r1, mat, bend=0.025, segs=10, rings=7):
    p0 = np.array(p0, dtype=np.float64)
    p1 = np.array(p1, dtype=np.float64)
    axis = p1 - p0
    length = np.linalg.norm(axis)
    up = axis / max(length, 1e-6)
    ref = np.array([1.0, 0.0, 0.0]) if abs(up[0]) < 0.8 else np.array([0.0, 0.0, 1.0])
    side = np.cross(up, ref)
    side /= np.linalg.norm(side)
    fwd = np.cross(side, up)

    verts, uvs, faces = [], [], []
    for r in range(rings):
        t = r / (rings - 1)
        center = p0 + axis * t + side * (math.sin(t * math.pi) * bend)
        rad = r0 + (r1 - r0) * t
        for s in range(segs + 1):
            ang = (s / segs) * math.tau
            irreg = 1.0 + math.sin(ang * 3.0 + t * 5.0) * 0.06
            pt = center + (side * math.cos(ang) + fwd * math.sin(ang)) * (rad * irreg)
            verts.append(pt)
            uvs.append([s / segs, t * 2.0])
    for r in range(rings - 1):
        for s in range(segs):
            i0 = r * (segs + 1) + s
            i1 = i0 + 1
            i2 = i0 + (segs + 1)
            i3 = i2 + 1
            faces.append([i0, i2, i1])
            faces.append([i1, i2, i3])
    return trimesh.Trimesh(
        vertices=np.array(verts),
        faces=np.array(faces),
        visual=trimesh.visual.TextureVisuals(uv=np.array(uvs), material=mat),
        process=False,
    )


def build_main_tent():
    print("=== Simulating BLD_MainTent_cloth.glb (Verlet Cloth Physics) ===", flush=True)
    scene = trimesh.Scene()
    wood_mat = make_mat("CedarWood", load_tex("wood_timber_albedo.png", (0.82, 0.70, 0.54)), roughness=0.88)
    rope_mat = make_mat("HempRope", load_tex("linen_canopy_albedo.png", (0.85, 0.74, 0.52)), roughness=0.94)
    goat_mat = make_mat("GoatHairRoof", load_tex("tent_goathair_albedo.png", (0.68, 0.56, 0.44)), roughness=0.95)
    tap_mat = make_mat("TekheletTap", load_tex("tapestry_tekhelet_albedo.png", (1.10, 1.08, 1.08)), roughness=0.86)
    cush_mat = make_mat("LinenCushion", load_tex("linen_canopy_albedo.png", (0.96, 0.90, 0.78)), roughness=0.92)

    posts = [(-1.85, -1.15), (0.0, -1.15), (1.85, -1.15), (-1.85, 1.15), (0.0, 1.15), (1.85, 1.15)]
    for i, (px, pz) in enumerate(posts):
        scene.add_geometry(make_hewn_post((px, 0.0, pz), (px, 1.78, pz), 0.11, 0.085, wood_mat, bend=0.022 * (1 if i % 2 == 0 else -1)))
        tor = trimesh.creation.torus(major_radius=0.115, minor_radius=0.026, major_sections=14, minor_sections=6)
        tor.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [1, 0, 0]))
        tor.apply_translation([px, 1.66, pz])
        tor.visual = trimesh.visual.TextureVisuals(uv=np.zeros((len(tor.vertices), 2)), material=rope_mat)
        scene.add_geometry(tor)

    # Ridgebeam & eave beams tucked cleanly UNDER the cloth canopy (zero beam poke-through!)
    scene.add_geometry(make_hewn_post((-1.92, 2.28, 0.0), (1.92, 2.28, 0.0), 0.068, 0.064, wood_mat, 0.01))
    scene.add_geometry(make_hewn_post((-1.90, 1.70, 1.15), (1.90, 1.70, 1.15), 0.060, 0.056, wood_mat, 0.01))
    scene.add_geometry(make_hewn_post((-1.90, 1.70, -1.15), (1.90, 1.70, -1.15), 0.060, 0.056, wood_mat, 0.01))

    # 4 Guy-ropes + wooden ground stakes
    for p0, p1 in [
        ((-1.85, 1.70, 1.15), (-2.55, 0.0, 1.82)),
        ((1.85, 1.70, 1.15), (2.55, 0.0, 1.82)),
        ((-1.85, 1.70, -1.15), (-2.55, 0.0, -1.82)),
        ((1.85, 1.70, -1.15), (2.55, 0.0, -1.82)),
    ]:
        scene.add_geometry(make_hewn_post(p0, p1, 0.016, 0.016, rope_mat, 0.015, segs=6, rings=4))
        scene.add_geometry(make_hewn_post((p1[0], -0.04, p1[2]), (p1[0] * 1.03, 0.24, p1[2] * 1.03), 0.032, 0.022, wood_mat, 0.0, segs=6, rings=3))

    # REAL PHYSICS-SIMULATED GOAT-HAIR CANOPY ROOF DRAPED CLEANLY OVER THE BEAMS!
    def pin_main(x, z, u, v):
        if abs(z) < 0.18 and abs(x) <= 2.02:
            return True
        if abs(abs(z) - 1.15) < 0.16 and abs(x) <= 1.98:
            return True
        return False

    verts, faces, uvs = simulate_verlet_cloth(36, 24, 4.45, 2.98, 2.56, 2.04, pin_main, wind_vec=(0.14, 0.0, 0.10), steps=180, skirt_drop=0.22)
    roof_m = trimesh.Trimesh(vertices=verts, faces=faces, visual=trimesh.visual.TextureVisuals(uv=uvs, material=goat_mat), process=False)
    scene.add_geometry(roof_m)

    # Draped dark woven back windbreak curtain (with real soft folds)
    bx = np.linspace(-1.86, 1.86, 18)
    by = np.linspace(0.02, 1.90, 10)
    bverts, buvs, bfaces = [], [], []
    for r, yv in enumerate(by):
        for c, xv in enumerate(bx):
            t_drop = max(0.0, 1.0 - yv / 1.90)
            zv = -1.12 + math.sin(xv * 4.2) * 0.065 * t_drop
            bverts.append([xv, yv, zv])
            buvs.append([c / 17.0 * 2.0, r / 9.0 * 1.5])
    for r in range(9):
        for c in range(17):
            i0 = r * 18 + c
            bfaces.extend([[i0, i0 + 18, i0 + 1], [i0 + 1, i0 + 18, i0 + 19]])
    scene.add_geometry(trimesh.Trimesh(vertices=np.array(bverts), faces=np.array(bfaces), visual=trimesh.visual.TextureVisuals(uv=np.array(buvs), material=goat_mat), process=False))

    # 2 Hanging Tekhelet & Pomegranate woven banners cleanly visible in front of eaves
    for idx, cx in enumerate([-1.28, 1.28]):
        ux = np.linspace(-0.40, 0.40, 8)
        uy = np.linspace(0.56, 1.72, 12)
        tv, tuv, tf = [], [], []
        for r, yv in enumerate(uy):
            drop = max(0.0, (1.72 - yv) / 1.16)
            for c, dx in enumerate(ux):
                zv = 1.28 + math.sin(drop * 3.8 + idx * 1.3 + dx * 2.0) * 0.045 * drop
                tv.append([cx + dx, yv, zv])
                tuv.append([c / 7.0, 1.0 - r / 11.0])
        for r in range(11):
            for c in range(7):
                i0 = r * 8 + c
                tf.extend([[i0, i0 + 8, i0 + 1], [i0 + 1, i0 + 8, i0 + 9]])
        scene.add_geometry(trimesh.Trimesh(vertices=np.array(tv), faces=np.array(tf), visual=trimesh.visual.TextureVisuals(uv=np.array(tuv), material=tap_mat), process=False))

    # Woven interior rug + 2 cushioned cedar benches
    rug = trimesh.creation.box(extents=[1.92, 0.025, 1.30])
    rug.apply_translation([0.0, 0.02, 0.05])
    rug.visual = trimesh.visual.TextureVisuals(uv=np.column_stack([(rug.vertices[:, 0] + 0.96) / 1.92, (rug.vertices[:, 2] + 0.65) / 1.30]), material=tap_mat)
    scene.add_geometry(rug)

    for bx_c in [-0.74, 0.74]:
        btop = trimesh.creation.box(extents=[0.94, 0.08, 0.44])
        btop.apply_translation([bx_c, 0.24, -0.58])
        btop.visual = trimesh.visual.TextureVisuals(uv=np.zeros((len(btop.vertices), 2)), material=wood_mat)
        scene.add_geometry(btop)
        cush = trimesh.creation.box(extents=[0.86, 0.07, 0.38])
        cush.apply_translation([bx_c, 0.31, -0.58])
        cush.visual = trimesh.visual.TextureVisuals(uv=np.zeros((len(cush.vertices), 2)), material=cush_mat)
        scene.add_geometry(cush)

    out_p = os.path.join(OUT_DIR, "BLD_MainTent_cloth.glb")
    scene.export(out_p)
    print(f"  SUCCESS: {out_p} ({os.path.getsize(out_p):,} bytes) bounds={scene.bounds.tolist()}", flush=True)


def build_healing_canopy():
    print("=== Simulating BLD_HealingCanopy_cloth.glb (Verlet Cloth Physics) ===", flush=True)
    scene = trimesh.Scene()
    wood_mat = make_mat("CedarWoodH", load_tex("wood_timber_albedo.png", (0.82, 0.70, 0.54)), roughness=0.88)
    rope_mat = make_mat("HempRopeH", load_tex("linen_canopy_albedo.png", (0.85, 0.74, 0.52)), roughness=0.94)
    linen_mat = make_mat("CreamLinenRoof", load_tex("linen_canopy_albedo.png", (1.02, 0.94, 0.80)), roughness=0.93)
    olive_mat = make_mat("OliveCurtain", load_tex("linen_canopy_albedo.png", (0.36, 0.50, 0.22)), roughness=0.93)
    herb_mat = make_mat("DriedHerbs", base_color=(64, 98, 38, 255), roughness=0.94)

    corners = [(-1.18, -0.92), (1.18, -0.92), (-1.18, 0.92), (1.18, 0.92)]
    for i, (px, pz) in enumerate(corners):
        scene.add_geometry(make_hewn_post((px, 0.0, pz), (px, 1.56, pz), 0.072, 0.058, wood_mat, bend=0.02))
    scene.add_geometry(make_hewn_post((-1.14, 1.50, 0.92), (1.14, 1.50, 0.92), 0.044, 0.042, wood_mat, 0.01))
    scene.add_geometry(make_hewn_post((-1.14, 1.50, -0.92), (1.14, 1.50, -0.92), 0.044, 0.042, wood_mat, 0.01))

    # REAL PHYSICS-SIMULATED WARM CREAM LINEN CANOPY DRAPED CLEANLY OVER BEAMS!
    def pin_heal(x, z, u, v):
        if math.hypot(x, z) < 0.22:
            return True
        if abs(abs(z) - 0.92) < 0.15 and abs(x) <= 1.22:
            return True
        return False

    verts, faces, uvs = simulate_verlet_cloth(28, 22, 2.75, 2.28, 2.12, 1.82, pin_heal, wind_vec=(0.14, 0.0, 0.10), steps=180, skirt_drop=0.20)
    scene.add_geometry(trimesh.Trimesh(vertices=verts, faces=faces, visual=trimesh.visual.TextureVisuals(uv=uvs, material=linen_mat), process=False))

    # Sculpted tied-back olive-green side curtains (stay strictly UNDER 1.62m crossbars!)
    for side in [-1.0, 1.0]:
        uz = np.linspace(-0.84, 0.84, 12)
        uy = np.linspace(0.14, 1.60, 14)
        cv, cuv, cf = [], [], []
        for r, yv in enumerate(uy):
            pinch = math.exp(-((yv - 0.82) ** 2) / 0.16)
            for c, zv in enumerate(uz):
                z_p = zv * (1.0 - 0.56 * pinch) + 0.36 * pinch
                x_p = side * 1.16 + math.sin(zv * 7.5) * 0.045 * (1.0 - 0.45 * pinch)
                cv.append([x_p, yv, z_p])
                cuv.append([c / 11.0, r / 13.0])
        for r in range(13):
            for c in range(11):
                i0 = r * 12 + c
                cf.extend([[i0, i0 + 12, i0 + 1], [i0 + 1, i0 + 12, i0 + 13]])
        scene.add_geometry(trimesh.Trimesh(vertices=np.array(cv), faces=np.array(cf), visual=trimesh.visual.TextureVisuals(uv=np.array(cuv), material=olive_mat), process=False))

    # 4 Hanging dried herb bundles under front beam
    for idx, hx in enumerate([-0.68, -0.26, 0.16, 0.56]):
        cone = trimesh.creation.cone(radius=0.095, height=0.38, sections=8)
        cone.apply_transform(trimesh.transformations.rotation_matrix(math.pi, [1, 0, 0]))
        cone.apply_translation([hx, 1.50, 0.90])
        cone.visual = trimesh.visual.TextureVisuals(uv=np.zeros((len(cone.vertices), 2)), material=herb_mat)
        scene.add_geometry(cone)

    out_p = os.path.join(OUT_DIR, "BLD_HealingCanopy_cloth.glb")
    scene.export(out_p)
    print(f"  SUCCESS: {out_p} ({os.path.getsize(out_p):,} bytes) bounds={scene.bounds.tolist()}", flush=True)


if __name__ == "__main__":
    build_main_tent()
    build_healing_canopy()
    print("ALL_CLOTH_GLBS_READY", flush=True)
