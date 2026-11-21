"""
Blender 4.2 Headless Cloth-Simulation & Handcrafted Architecture Builder
Generates two real physics-simulated, handcrafted GLB assets for Promise Path:
  1. BLD_MainTent_cloth.glb      (Ancient Hebrew Patriarch Pavilion Tent)
  2. BLD_HealingCanopy_cloth.glb (Herbal Healing Linen Canopy)
Run: blender.exe --background --python build_blender_tents.py
"""
import os
import math
import bpy
import bmesh
from mathutils import Vector

TEX_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\textures"
OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_pbr_mat(name, base_color=(0.8, 0.7, 0.6, 1.0), albedo_file=None, normal_file=None, roughness=0.90, double_sided=False):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0

    if albedo_file:
        p = os.path.join(TEX_DIR, albedo_file)
        if os.path.exists(p):
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(p, check_existing=True)
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs["B"].default_value = base_color
            nt.links.new(tex.outputs["Color"], mix.inputs["A"])
            nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])

    if normal_file:
        p = os.path.join(TEX_DIR, normal_file)
        if os.path.exists(p):
            ntex = nt.nodes.new("ShaderNodeTexImage")
            ntex.image = bpy.data.images.load(p, check_existing=True)
            ntex.image.colorspace_settings.name = "Non-Color"
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.inputs["Strength"].default_value = 0.85
            nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def add_hewn_timber_post(name, p0, p1, r_bot, r_top, mat, bend=0.03):
    v0 = Vector(p0)
    v1 = Vector(p1)
    axis = v1 - v0
    length = axis.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=1.0, depth=length, location=(v0 + v1) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    # Align Z to axis
    rot_quat = Vector((0, 0, 1)).rotation_difference(axis.normalized())
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = rot_quat
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    # Organic hand-hewn taper & slight timber bend
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=4, use_grid_fill=False)
    for vert in bm.verts:
        t = (vert.co.z + length * 0.5) / max(length, 0.001)
        rad = r_bot + (r_top - r_bot) * t
        # Slight hand-adze facet irregularity
        ang = math.atan2(vert.co.y, vert.co.x)
        irreg = 1.0 + math.sin(ang * 3.0 + t * 5.0) * 0.06
        vert.co.x = math.cos(ang) * rad * irreg + math.sin(t * math.pi) * bend
        vert.co.y = math.sin(ang) * rad * irreg
    bm.to_mesh(obj.data)
    bm.free()
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def add_rope_lashing(name, center, radius, mat):
    objs = []
    for k in range(3):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=radius,
            minor_radius=0.022,
            major_segments=16,
            minor_segments=6,
            location=(center[0], center[1], center[2] + (k - 1) * 0.038),
        )
        t = bpy.context.active_object
        t.name = f"{name}_{k}"
        t.rotation_euler = (0.12 * (k - 1), 0.08 * k, 0.0)
        bpy.ops.object.shade_smooth()
        t.data.materials.append(mat)
        objs.append(t)
    return objs


def simulate_cloth_canopy(name, width, depth, z_ridge, z_eave, pin_coords, mat, frames=38, stiffness=12.0, wind=0.8):
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=30, y_subdivisions=20, size=1.0, location=(0, 0, z_eave))
    cloth = bpy.context.active_object
    cloth.name = name
    cloth.scale = (width, depth, 1.0)
    bpy.ops.object.transform_apply(scale=True)

    # Pre-shape gentle pitched ridge so cloth settles over ridgebeam cleanly
    for v in cloth.data.vertices:
        ny = abs(v.co.y) / (depth * 0.5)
        v.co.z = z_eave + (z_ridge - z_eave) * max(0.0, 1.0 - ny)

    # Create Pin vertex group near post tops & ridgebeam
    vg = cloth.vertex_groups.new(name="Pin")
    pin_indices = []
    for v in cloth.data.vertices:
        for px, py, pr in pin_coords:
            if math.hypot(v.co.x - px, v.co.y - py) <= pr:
                pin_indices.append(v.index)
                break
    vg.add(pin_indices, 1.0, "REPLACE")

    # Add real Blender Cloth Physics Modifier
    cmod = cloth.modifiers.new(name="Cloth", type="CLOTH")
    cmod.settings.mass = 0.45
    cmod.settings.tension_stiffness = stiffness
    cmod.settings.compression_stiffness = stiffness * 0.8
    cmod.settings.shear_stiffness = 6.0
    cmod.settings.bending_stiffness = 0.65
    cmod.settings.vertex_group_mass = "Pin"
    cmod.settings.pin_stiffness = 2.0

    # Add gentle Mediterranean breeze force field
    bpy.ops.object.effector_add(type="WIND", location=(-3.0, -2.0, z_eave))
    wind_obj = bpy.context.active_object
    wind_obj.rotation_euler = (math.radians(78), 0.0, math.radians(-35))
    wind_obj.field.strength = wind
    wind_obj.field.noise = 0.6

    # Step physics simulation
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = frames
    for f in range(1, frames + 1):
        scene.frame_set(f)

    # Bake deformed cloth shape cleanly into static mesh
    bpy.context.view_layer.objects.active = cloth
    bpy.ops.object.modifier_apply(modifier="Cloth")
    bpy.data.objects.remove(wind_obj, do_unlink=True)

    # Add subtle cloth thickness & smooth normals
    sol = cloth.modifiers.new(name="Solidify", type="SOLIDIFY")
    sol.thickness = 0.028
    sol.offset = 0.0
    bpy.ops.object.modifier_apply(modifier="Solidify")
    bpy.ops.object.shade_smooth()
    cloth.data.materials.append(mat)
    return cloth


def build_main_tent():
    print("=== Building BLD_MainTent_cloth.glb (Real Blender Cloth Simulation) ===", flush=True)
    clear_scene()

    wood_mat = make_pbr_mat("CedarWood", (0.76, 0.62, 0.46, 1.0), "wood_timber_albedo.png", "wood_timber_normal.png", 0.88)
    rope_mat = make_pbr_mat("HempRope", (0.76, 0.65, 0.44, 1.0), "linen_canopy_albedo.png", "linen_canopy_normal.png", 0.94)
    goat_mat = make_pbr_mat("GoatHairRoof", (0.62, 0.50, 0.40, 1.0), "tent_goathair_albedo.png", "tent_goathair_normal.png", 0.95, double_sided=True)
    tap_mat = make_pbr_mat("TekheletTapestry", (1.05, 1.05, 1.05, 1.0), "tapestry_tekhelet_albedo.png", "linen_canopy_normal.png", 0.88, double_sided=True)
    cushion_mat = make_pbr_mat("LinenCushion", (0.90, 0.84, 0.72, 1.0), "linen_canopy_albedo.png", "linen_canopy_normal.png", 0.92)

    # 1. Six hand-hewn cedar posts (Blender Z-up)
    posts = [
        (-1.85, -1.15), (0.0, -1.15), (1.85, -1.15),
        (-1.85,  1.15), (0.0,  1.15), (1.85,  1.15),
    ]
    for idx, (px, py) in enumerate(posts):
        add_hewn_timber_post(f"Post_{idx}", (px, py, 0.0), (px, py, 2.02), 0.105, 0.082, wood_mat, bend=0.025 * (1 if idx % 2 == 0 else -1))
        add_rope_lashing(f"Lash_{idx}", (px, py, 1.88), 0.11, rope_mat)

    # Ridgebeam & front/back eave beams
    add_hewn_timber_post("RidgeBeam", (-2.05, 0.0, 2.48), (2.05, 0.0, 2.48), 0.075, 0.072, wood_mat, bend=0.01)
    add_hewn_timber_post("FrontBeam", (-2.00, -1.15, 1.92), (2.00, -1.15, 1.92), 0.068, 0.065, wood_mat, bend=0.015)
    add_hewn_timber_post("BackBeam",  (-2.00,  1.15, 1.92), (2.00,  1.15, 1.92), 0.068, 0.065, wood_mat, bend=0.015)

    # 4 diagonal guy-ropes with wooden ground stakes
    for idx, (p0, p1) in enumerate([
        ((-1.85, -1.15, 1.90), (-2.55, -1.80, 0.0)),
        (( 1.85, -1.15, 1.90), ( 2.55, -1.80, 0.0)),
        ((-1.85,  1.15, 1.90), (-2.55,  1.80, 0.0)),
        (( 1.85,  1.15, 1.90), ( 2.55,  1.80, 0.0)),
    ]):
        add_hewn_timber_post(f"GuyRope_{idx}", p0, p1, 0.016, 0.016, rope_mat, bend=0.02)
        add_hewn_timber_post(f"Stake_{idx}", (p1[0], p1[1], -0.05), (p1[0] * 1.04, p1[1] * 1.04, 0.24), 0.032, 0.024, wood_mat, bend=0.0)

    # 2. REAL CLOTH-SIMULATED GOAT-HAIR CANOPY ROOF!
    pins = [
        (-1.85, -1.15, 0.28), (0.0, -1.15, 0.28), (1.85, -1.15, 0.28),
        (-1.85,  1.15, 0.28), (0.0,  1.15, 0.28), (1.85,  1.15, 0.28),
        (-1.85,  0.00, 0.28), (-0.90, 0.0, 0.22), (0.0, 0.0, 0.28), (0.90, 0.0, 0.22), (1.85, 0.0, 0.28),
    ]
    simulate_cloth_canopy("MainCanopyCloth", 4.55, 3.15, 2.52, 1.94, pins, goat_mat, frames=36, stiffness=14.0, wind=0.65)

    # 3. Draped woven back curtain (real soft cloth wave)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=18, y_subdivisions=10, size=1.0, location=(0.0, 1.12, 0.96))
    back_c = bpy.context.active_object
    back_c.name = "BackWindbreakCurtain"
    back_c.rotation_euler = (math.radians(90), 0.0, 0.0)
    back_c.scale = (3.72, 1.84, 1.0)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    for v in back_c.data.vertices:
        t_h = max(0.0, 1.0 - v.co.z / 1.85)
        v.co.y += math.sin(v.co.x * 4.5) * 0.055 * t_h
    bpy.ops.object.shade_smooth()
    back_c.data.materials.append(goat_mat)

    # 4. Two hanging Tekhelet-blue & pomegranate-red woven banners on front eaves (with natural fabric sway)
    for idx, bx in enumerate([-1.28, 1.28]):
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=8, y_subdivisions=12, size=1.0, location=(bx, -1.18, 1.24))
        ban = bpy.context.active_object
        ban.name = f"TekheletBanner_{idx}"
        ban.rotation_euler = (math.radians(90), 0.0, 0.0)
        ban.scale = (0.76, 1.18, 1.0)
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for v in ban.data.vertices:
            drop = max(0.0, (1.82 - v.co.z) / 1.18)
            v.co.y -= math.sin(drop * math.pi * 1.4 + idx) * 0.05 * drop
        bpy.ops.object.shade_smooth()
        ban.data.materials.append(tap_mat)

    # 5. Interior woven Tekhelet rug + 2 cushioned cedar benches
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=10, y_subdivisions=8, size=1.0, location=(0.0, 0.05, 0.02))
    rug = bpy.context.active_object
    rug.name = "InteriorRug"
    rug.scale = (1.92, 1.32, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    for v in rug.data.vertices:
        v.co.z += math.sin(v.co.x * 5.0) * math.cos(v.co.y * 4.0) * 0.008
    rug.data.materials.append(tap_mat)

    for idx, bx in enumerate([-0.74, 0.74]):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.58, 0.24))
        bench = bpy.context.active_object
        bench.name = f"Bench_{idx}"
        bench.scale = (0.94, 0.44, 0.09)
        bpy.ops.object.transform_apply(scale=True)
        bench.data.materials.append(wood_mat)
        for lx in [-0.38, 0.38]:
            add_hewn_timber_post(f"BenchLeg_{idx}_{lx}", (bx + lx, 0.58, 0.0), (bx + lx, 0.58, 0.24), 0.045, 0.042, wood_mat, 0.0)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.58, 0.31))
        cush = bpy.context.active_object
        cush.name = f"Cushion_{idx}"
        cush.scale = (0.86, 0.38, 0.07)
        bpy.ops.object.transform_apply(scale=True)
        bev = cush.modifiers.new("Bevel", "BEVEL")
        bev.width = 0.025
        bev.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
        bpy.ops.object.shade_smooth()
        cush.data.materials.append(cushion_mat)

    out_path = os.path.join(OUT_DIR, "BLD_MainTent_cloth.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True)
    print(f"  EXPORTED: {out_path} ({os.path.getsize(out_path):,} bytes)", flush=True)


def build_healing_canopy():
    print("=== Building BLD_HealingCanopy_cloth.glb (Real Blender Cloth Simulation) ===", flush=True)
    clear_scene()

    wood_mat = make_pbr_mat("CedarWoodH", (0.76, 0.62, 0.46, 1.0), "wood_timber_albedo.png", "wood_timber_normal.png", 0.88)
    rope_mat = make_pbr_mat("HempRopeH", (0.76, 0.65, 0.44, 1.0), "linen_canopy_albedo.png", "linen_canopy_normal.png", 0.94)
    linen_mat = make_pbr_mat("CreamLinenRoof", (0.98, 0.92, 0.80, 1.0), "linen_canopy_albedo.png", "linen_canopy_normal.png", 0.93, double_sided=True)
    olive_mat = make_pbr_mat("OliveCurtain", (0.34, 0.46, 0.22, 1.0), "linen_canopy_albedo.png", "linen_canopy_normal.png", 0.93, double_sided=True)
    herb_mat = make_pbr_mat("DriedHerbs", (0.28, 0.42, 0.16, 1.0), "linen_canopy_albedo.png", None, 0.94)
    clay_mat = make_pbr_mat("TerracottaBowls", (0.72, 0.36, 0.18, 1.0), None, None, 0.72)
    lav_mat = make_pbr_mat("Lavender", (0.48, 0.34, 0.58, 1.0), None, None, 0.90)

    # 4 Corner posts + crossbars + lashings
    corners = [(-1.18, -0.92), (1.18, -0.92), (-1.18, 0.92), (1.18, 0.92)]
    for idx, (px, py) in enumerate(corners):
        add_hewn_timber_post(f"HPost_{idx}", (px, py, 0.0), (px, py, 1.82), 0.072, 0.058, wood_mat, bend=0.02)
        add_rope_lashing(f"HLash_{idx}", (px, py, 1.70), 0.08, rope_mat)
    add_hewn_timber_post("HFrontBar", (-1.24, -0.92, 1.72), (1.24, -0.92, 1.72), 0.048, 0.046, wood_mat, 0.01)
    add_hewn_timber_post("HBackBar",  (-1.24,  0.92, 1.72), (1.24,  0.92, 1.72), 0.048, 0.046, wood_mat, 0.01)

    # REAL CLOTH-SIMULATED CREAM LINEN CANOPY!
    pins = [
        (-1.18, -0.92, 0.25), (1.18, -0.92, 0.25),
        (-1.18,  0.92, 0.25), (1.18,  0.92, 0.25),
        (0.0, 0.0, 0.22),
    ]
    simulate_cloth_canopy("HealLinenCloth", 2.86, 2.38, 2.08, 1.72, pins, linen_mat, frames=38, stiffness=10.0, wind=0.75)

    # Sculpted tied-back olive-green side curtains (pinched gracefully at waist height!)
    for side in [-1.0, 1.0]:
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=12, y_subdivisions=14, size=1.0, location=(side * 1.16, 0.0, 0.92))
        curt = bpy.context.active_object
        curt.name = f"OliveCurtain_{int(side)}"
        curt.rotation_euler = (math.radians(90), 0.0, math.radians(90))
        curt.scale = (1.76, 1.56, 1.0)
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        for v in curt.data.vertices:
            # Pinch curtain gracefully toward front post around z=0.85
            pinch = math.exp(-((v.co.z - 0.82) ** 2) / 0.18)
            v.co.y = v.co.y * (1.0 - 0.55 * pinch) - 0.35 * pinch
            v.co.x += math.sin(v.co.y * 8.0) * 0.045 * (1.0 - 0.5 * pinch)
        bpy.ops.object.shade_smooth()
        curt.data.materials.append(olive_mat)

    # 4 Hanging dried herb bundles under front crossbar
    for idx, hx in enumerate([-0.68, -0.26, 0.16, 0.56]):
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.095, radius2=0.025, depth=0.38, location=(hx, -0.90, 1.48))
        hb = bpy.context.active_object
        hb.name = f"HerbBundle_{idx}"
        hb.rotation_euler = (0.08, 0.06 * (idx - 1.5), 0.0)
        bpy.ops.object.shade_smooth()
        hb.data.materials.append(herb_mat)

    # Rustic apothecary table + 4 clay bowls + overflowing lavender basket
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.18, -0.22, 0.62))
    ttop = bpy.context.active_object
    ttop.scale = (1.32, 0.62, 0.07)
    bpy.ops.object.transform_apply(scale=True)
    ttop.data.materials.append(wood_mat)
    for lx in [-0.55, 0.55]:
        for ly in [-0.22, 0.22]:
            add_hewn_timber_post(f"TLeg_{lx}_{ly}", (0.18 + lx, -0.22 + ly, 0.0), (0.18 + lx, -0.22 + ly, 0.60), 0.04, 0.036, wood_mat, 0.0)

    for bi in range(4):
        bx = -0.28 + bi * 0.30
        by = -0.22 + (0.06 if bi % 2 == 0 else -0.05)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.09, depth=0.09, location=(bx, by, 0.70))
        bw = bpy.context.active_object
        bw.data.materials.append(clay_mat)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.085, location=(bx, by, 0.76))
        sp = bpy.context.active_object
        sp.scale = (1.0, 1.0, 0.65)
        sp.data.materials.append(lav_mat if bi == 2 else herb_mat)

    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.22, depth=0.36, location=(-0.64, -0.45, 0.18))
    bask = bpy.context.active_object
    bask.data.materials.append(rope_mat)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.21, location=(-0.64, -0.45, 0.38))
    bherb = bpy.context.active_object
    bherb.scale = (1.0, 1.0, 0.75)
    bherb.data.materials.append(lav_mat)

    out_path = os.path.join(OUT_DIR, "BLD_HealingCanopy_cloth.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True)
    print(f"  EXPORTED: {out_path} ({os.path.getsize(out_path):,} bytes)", flush=True)


if __name__ == "__main__":
    build_main_tent()
    build_healing_canopy()
    print("ALL_BLENDER_CLOTH_GLBS_DONE", flush=True)
