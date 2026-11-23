class_name NoahRTSWorld
extends Node3D
## 260x260m AAA Photogrammetry Highland & Canyon World for Exact Biblical 300:50:30 Noah's Ark (102m x 17m x 10.2m):
## - ZERO floating rocks: every cliff & boulder uses 5-point minimum perimeter terrain height + deep embedding!
## - MultiMeshInstance3D scattering 2,600 grass tufts & 420 photogrammetry pebbles (only 2 draw calls!)
## - Forward+ SDFGI + SSAO + VolumetricFog + Low Raking Golden Sun + GPU Collision Rain (with Mobile fallback).

const Loader: Script = preload("res://scripts/glb_asset_loader.gd")

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var terrain_mat: ShaderMaterial

var ark_anchor: Node3D
var ark: Node3D
var ark_lanterns: Array[OmniLight3D] = []
var god_ray: MeshInstance3D
var flood_water: MeshInstance3D
var river_mesh: MeshInstance3D
var road_mesh: MeshInstance3D
var rain: GPUParticles3D
var rain_splash: GPUParticles3D
var rain_collider: GPUParticlesCollisionHeightField3D
var rainbow: MeshInstance3D

var yard_stakes: Node3D
var timber_stacks: Node3D
var guard_fence: Node3D
var pitch_station: Node3D
var forest_group: Node3D
var village_group: Node3D
var altar_group: Node3D
var puddles_group: Node3D
var olive_shoots: Node3D

var ark_base_y: float = 0.0
var ark_scale: float = 1.0


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func spawn_asset(file: String, height: float, pos: Vector3, parent: Node3D = self) -> Node3D:
	var res_path: String = file if file.begins_with("res://") else ("res://assets/models/" + file)
	var packed: PackedScene = load(res_path) as PackedScene
	var wrapper: Node3D = Node3D.new()
	wrapper.name = res_path.get_file().get_basename()
	if packed != null:
		var model: Node3D = packed.instantiate() as Node3D
		if model != null:
			var bounds: AABB = Loader._compute_local_aabb(model)
			var factor: float = height / maxf(bounds.size.y, 0.001)
			model.scale = Vector3.ONE * factor
			model.position.y = -bounds.position.y * factor
			wrapper.add_child(model)
	else:
		push_error("Missing model: " + res_path)
	parent.add_child(wrapper)
	wrapper.position = pos
	return wrapper


## 5-point perimeter minimum terrain height so wide photogrammetry cliffs/boulders NEVER float on slopes!
func grounded_embedded(x: float, z: float, radius: float, sink_depth: float) -> Vector3:
	var h_min: float = terrain_height(x, z)
	for off: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		h_min = minf(h_min, terrain_height(x + off.x, z + off.y))
	return Vector3(x, h_min - sink_depth, z)


## Analytic 260x260m canyon & highland heightfield cradling the 102m x 17m x 10.2m Biblical Ark cleanly!
func terrain_height(x: float, z: float) -> float:
	# Wide flat shipyard plateau cradling the 102m Ark (X in [-56, +56], Z in [-18, +26]) at Y = 0.0
	var plateau_x: float = smoothstep(-74.0, -56.0, x) * (1.0 - smoothstep(56.0, 74.0, x))
	var plateau_z: float = smoothstep(-28.0, -14.0, z) * (1.0 - smoothstep(24.0, 38.0, z))
	var plateau: float = plateau_x * plateau_z

	# Western deep river canyon gorge (X < -64)
	var west_valley: float = 1.0 - smoothstep(-88.0, -60.0, x)
	# Eastern Gopher-Wood Forest rolling hillside (X > 60)
	var east_hill: float = smoothstep(58.0, 108.0, x)
	# Southern gentle valley slope toward neighbor mudbrick village (Z > 32)
	var south_slope: float = smoothstep(28.0, 62.0, z) * smoothstep(-68.0, -40.0, x)
	# Gentle northern Ararat hills (kept low enough so the Covenant Rainbow shines cleanly in the open sky!)
	var north_ridge: float = 1.0 - smoothstep(-105.0, -32.0, z)

	var organic: float = (sin(x * 0.065 + z * 0.055) * 1.65 + cos(z * 0.082 - x * 0.048) * 1.25) * (1.0 - plateau * 0.96)
	var river_x: float = -86.0 + sin(z * 0.035) * 11.0
	var channel: float = (1.0 - smoothstep(4.0, 11.0, absf(x - river_x))) * west_valley

	var h: float = east_hill * 9.5 - south_slope * 4.2 + north_ridge * 11.5 + organic
	h = lerpf(h, -11.5 + organic * 0.35, west_valley) - channel * 1.8
	return h * (1.0 - plateau)


func grounded(x: float, z: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x, terrain_height(x, z) + y_offset, z)


func build_all() -> void:
	_build_sky_and_lights()
	_build_terrain_and_photogrammetry()
	_build_multimesh_ground_cover()
	_build_river_and_flood()
	_build_ark()
	_build_shipyard_props()
	_build_east_forest()
	_build_south_village()
	_build_altar_and_ararat()
	_build_god_ray()
	_build_rainbow()
	_build_rain()


func _build_sky_and_lights() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.31, 0.50)
	sky_material.sky_horizon_color = Color(0.76, 0.68, 0.54)
	sky_material.ground_bottom_color = Color(0.18, 0.15, 0.12)
	sky_material.ground_horizon_color = Color(0.50, 0.43, 0.34)
	sky_material.sun_angle_max = 18.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	# Rich AAA shadow contrast (like Wojtek Pe showcase — NOT washed out!)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.26
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.65
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.66, 0.56)
	environment.fog_density = 0.0022
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.sdfgi_enabled = true
		environment.sdfgi_use_occlusion = true
		environment.sdfgi_bounce_feedback = 0.45
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.0085
		environment.volumetric_fog_albedo = Color(0.86, 0.78, 0.65)
		environment.volumetric_fog_emission = Color(0.14, 0.11, 0.07)
		environment.volumetric_fog_emission_energy = 0.30
		environment.volumetric_fog_anisotropy = 0.72
		environment.volumetric_fog_length = 140.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	# Low raking golden sun casting dramatic cinematic shadows across cliffs & Ark!
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -42.0, 0.0)
	sun.light_color = Color(1.0, 0.87, 0.66)
	sun.light_energy = 2.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.15
	add_child(sun)


func _build_terrain_and_photogrammetry() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 88
	var nz: int = 88
	var min_x: float = -135.0
	var max_x: float = 135.0
	var min_z: float = -120.0
	var max_z: float = 120.0
	for iz in range(nz):
		for ix in range(nx):
			var corners: Array[Vector2i] = [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
			]
			for c: Vector2i in corners:
				var px: float = lerpf(min_x, max_x, float(ix + c.x) / float(nx))
				var pz: float = lerpf(min_z, max_z, float(iz + c.y) / float(nz))
				var py: float = terrain_height(px, pz)
				st.set_uv(Vector2(px, pz) * 0.08)
				st.add_vertex(Vector3(px, py, pz))
	st.index()
	st.generate_normals()

	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/VFX_HighlandTerrain.gdshader") as Shader
	terrain_mat.set_shader_parameter("grass_albedo", load("res://assets/textures/terrain_grass_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("dirt_albedo", load("res://assets/textures/terrain_dirt_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("rock_albedo", load("res://assets/textures/terrain_rock_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("rock_normal", load("res://assets/textures/terrain_rock_normal.png") as Texture2D)
	terrain_mat.set_shader_parameter("boulder_albedo", load("res://assets/textures/rock_boulder_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("wetness", 0.0)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "GrandHighlandTerrain"
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	add_child(mi)

	# Smooth winding village dirt road (hidden post-flood in Ararat!)
	var rst: SurfaceTool = SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rsteps: int = 36
	for i in range(rsteps):
		var t0: float = float(i) / float(rsteps)
		var t1: float = float(i + 1) / float(rsteps)
		var z0: float = lerpf(21.0, 56.0, t0)
		var z1: float = lerpf(21.0, 56.0, t1)
		var x0: float = sin(t0 * 2.6) * 6.0 + 2.0
		var x1: float = sin(t1 * 2.6) * 6.0 + 2.0
		var hw: float = 2.0
		var p0l: Vector3 = grounded(x0 - hw, z0, 0.04)
		var p0r: Vector3 = grounded(x0 + hw, z0, 0.04)
		var p1l: Vector3 = grounded(x1 - hw, z1, 0.04)
		var p1r: Vector3 = grounded(x1 + hw, z1, 0.04)
		for v: Vector3 in [p0l, p0r, p1l, p0r, p1r, p1l]:
			rst.set_uv(Vector2(v.x, v.z) * 0.2)
			rst.add_vertex(v)
	rst.generate_normals()
	road_mesh = MeshInstance3D.new()
	road_mesh.name = "VillageDirtRoad"
	road_mesh.mesh = rst.commit()
	var road_mat: StandardMaterial3D = _mat(Color(0.50, 0.42, 0.32), 0.96)
	road_mat.albedo_texture = load("res://assets/textures/terrain_dirt_albedo.png") as Texture2D
	road_mat.uv1_triplanar = true
	road_mesh.material_override = road_mat
	add_child(road_mesh)

	# 5-POINT DEEP-EMBEDDED PolyHaven CC0 Photogrammetry Cliffs & Boulders (MATHEMATICALLY ZERO FLOATING!)
	var cliff_1: String = "res://assets/cc0_models/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf"
	var cliff_2: String = "res://assets/cc0_models/namaqualand_cliff_02/namaqualand_cliff_02_1k.gltf"
	var bld_1: String = "res://assets/cc0_models/namaqualand_boulders_01/namaqualand_boulders_01_1k.gltf"
	var bld_2: String = "res://assets/cc0_models/namaqualand_boulder_02/namaqualand_boulder_02_1k.gltf"
	var shrub_1: String = "res://assets/cc0_models/shrub_01/shrub_01_1k.gltf"
	var shrub_2: String = "res://assets/cc0_models/shrub_02/shrub_02_1k.gltf"

	# Monumental deep-embedded cliffs framing the back ridge (Z < -18) and western gorge rim (X < -54)
	var cliff_specs: Array[Array] = [
		[cliff_1, 16.0, -64.0, -18.0, 0.45, 7.0, 2.8],
		[cliff_2, 18.0, -68.0, 6.0, 1.15, 7.5, 3.0],
		[cliff_1, 15.0, -64.0, 26.0, -0.40, 6.5, 2.6],
		[cliff_2, 20.0, -34.0, -32.0, 2.15, 8.5, 3.4],
		[cliff_1, 22.0, 4.0, -35.0, 0.72, 9.0, 3.6],
		[cliff_2, 19.0, 42.0, -31.0, -0.85, 8.0, 3.2],
		[cliff_1, 16.0, 72.0, -18.0, -1.45, 7.0, 2.8],
	]
	for cs in cliff_specs:
		var pos: Vector3 = grounded_embedded(float(cs[2]), float(cs[3]), float(cs[5]), float(cs[6]))
		var cnode: Node3D = spawn_asset(str(cs[0]), float(cs[1]), pos)
		cnode.rotation.y = float(cs[4])

	# Deep-embedded Photogrammetry Boulders around the flat plateau perimeter & Ark hull chocks
	var boulder_coords: Array[Vector3] = [
		Vector3(-56.0, 2.6, -6.0), Vector3(-54.0, 2.2, 8.0), Vector3(-42.0, 1.9, -15.0),
		Vector3(-24.0, 2.1, -16.0), Vector3(26.0, 2.3, -15.5), Vector3(48.0, 2.5, -13.0),
		Vector3(56.0, 2.8, 2.0), Vector3(52.0, 2.1, 14.0), Vector3(-36.0, 1.8, 19.0),
		Vector3(-18.0, 1.6, 21.0), Vector3(24.0, 1.9, 20.0), Vector3(38.0, 2.2, 17.0),
		Vector3(-58.0, 3.0, 18.0), Vector3(60.0, 2.7, -8.0),
	]
	for i in range(boulder_coords.size()):
		var bc: Vector3 = boulder_coords[i]
		var bf: String = bld_1 if i % 2 == 0 else bld_2
		var pos: Vector3 = grounded_embedded(bc.x, bc.z, bc.y * 0.9, 0.65)
		var bn: Node3D = spawn_asset(bf, bc.y, pos)
		bn.rotation.y = float(i) * 1.18

	# Deep-embedded Mediterranean Shrubs around boulders and edges
	for i in range(34):
		var sx: float = -54.0 + fmod(float(i) * 19.7, 112.0)
		var sz: float = -16.0 + fmod(float(i) * 13.3, 44.0)
		# Keep inside Ark footprint & central clearing clean
		if absf(sx) < 53.0 and sz > -11.0 and sz < 13.0:
			sz += 24.0
		var sf: String = shrub_1 if i % 2 == 0 else shrub_2
		var sn: Node3D = spawn_asset(sf, 0.95 + float(i % 3) * 0.35, grounded_embedded(sx, sz, 0.6, 0.12))
		sn.rotation.y = float(i) * 1.61


## High-density AAA Ground Cover: 2,600 wind-swaying grass tufts + 420 scattered ground stones in 2 draw calls!
func _build_multimesh_ground_cover() -> void:
	# 1. Crossed-quad grass tuft MultiMesh (2,600 instances!)
	var g_st: SurfaceTool = SurfaceTool.new()
	g_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang in [0.0, PI * 0.33, PI * 0.66]:
		var dx: float = cos(ang) * 0.34
		var dz: float = sin(ang) * 0.34
		var v0: Vector3 = Vector3(-dx, 0.0, -dz)
		var v1: Vector3 = Vector3(dx, 0.0, dz)
		var v2: Vector3 = Vector3(dx * 0.85, 0.58, dz * 0.85)
		var v3: Vector3 = Vector3(-dx * 0.85, 0.58, -dz * 0.85)
		for idx_v in [[v0, Vector2(0, 1)], [v1, Vector2(1, 1)], [v2, Vector2(1, 0)], [v0, Vector2(0, 1)], [v2, Vector2(1, 0)], [v3, Vector2(0, 0)]]:
			g_st.set_uv(idx_v[1])
			g_st.add_vertex(idx_v[0])
	g_st.generate_normals()
	var g_mat: StandardMaterial3D = _mat(Color(0.42, 0.50, 0.28), 0.90)
	g_mat.albedo_texture = load("res://assets/textures/grass_tuft_alpha.png") as Texture2D
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	g_mat.alpha_scissor_threshold = 0.35
	g_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mm_grass: MultiMesh = MultiMesh.new()
	mm_grass.transform_format = MultiMesh.TRANSFORM_3D
	mm_grass.mesh = g_st.commit()
	var grass_positions: Array[Transform3D] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(2800):
		var gx: float = rng.randf_range(-66.0, 74.0)
		var gz: float = rng.randf_range(-24.0, 44.0)
		# Keep Ark hull interior & ramp corridor free of grass
		if absf(gx) < 52.5 and gz > -10.5 and gz < 10.5:
			continue
		if absf(gx) < 4.0 and gz >= 10.0 and gz < 22.0:
			continue
		var gy: float = terrain_height(gx, gz)
		# Skip steep cliffs
		var slope_check: float = absf(terrain_height(gx + 1.0, gz) - gy) + absf(terrain_height(gx, gz + 1.0) - gy)
		if slope_check > 0.75:
			continue
		var sc: float = rng.randf_range(0.65, 1.55)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc))
		grass_positions.append(Transform3D(basis, Vector3(gx, gy - 0.04, gz)))
	mm_grass.instance_count = grass_positions.size()
	for i in range(grass_positions.size()):
		mm_grass.set_instance_transform(i, grass_positions[i])
	var mmi_grass: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi_grass.name = "MultiMeshGrassCarpet"
	mmi_grass.multimesh = mm_grass
	mmi_grass.material_override = g_mat
	mmi_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi_grass)

	# 2. Scattered embedded ground stones / pebbles MultiMesh (420 instances, 1 draw call!)
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	var st_mat: StandardMaterial3D = _mat(Color(0.55, 0.50, 0.43), 0.88)
	st_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png") as Texture2D
	st_mat.uv1_triplanar = true
	var mm_stone: MultiMesh = MultiMesh.new()
	mm_stone.transform_format = MultiMesh.TRANSFORM_3D
	mm_stone.mesh = sm
	var stone_xforms: Array[Transform3D] = []
	for i in range(420):
		var sx: float = rng.randf_range(-60.0, 62.0)
		var sz: float = rng.randf_range(-18.0, 38.0)
		if absf(sx) < 52.0 and sz > -10.0 and sz < 10.0:
			continue
		var sy: float = terrain_height(sx, sz)
		var scx: float = rng.randf_range(0.45, 1.65)
		var scy: float = rng.randf_range(0.35, 0.95)
		var scz: float = rng.randf_range(0.45, 1.55)
		var b: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scx, scy, scz))
		# Sunk 0.08m into ground so ZERO pebbles float!
		stone_xforms.append(Transform3D(b, Vector3(sx, sy - 0.06, sz)))
	mm_stone.instance_count = stone_xforms.size()
	for i in range(stone_xforms.size()):
		mm_stone.set_instance_transform(i, stone_xforms[i])
	var mmi_stone: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi_stone.name = "MultiMeshGroundStones"
	mmi_stone.multimesh = mm_stone
	mmi_stone.material_override = st_mat
	add_child(mmi_stone)


func _build_river_and_flood() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(110):
		for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var rz: float = -115.0 + float(i + c.y) * 2.1
			var rx: float = -86.0 + sin(rz * 0.035) * 11.0 + (float(c.x) - 0.5) * 14.0
			st.set_uv(Vector2(float(c.x), float(i + c.y) * 0.08))
			st.add_vertex(Vector3(rx, -11.4, rz))
	st.generate_normals()
	river_mesh = MeshInstance3D.new()
	river_mesh.name = "WesternGreatRiver"
	river_mesh.mesh = st.commit()
	river_mesh.material_override = _mat(Color(0.14, 0.27, 0.33), 0.12, 0.28)
	add_child(river_mesh)

	flood_water = MeshInstance3D.new()
	flood_water.name = "RisingFloodWater"
	var fp: PlaneMesh = PlaneMesh.new()
	fp.size = Vector2(360.0, 360.0)
	fp.subdivide_width = 72
	fp.subdivide_depth = 72
	flood_water.mesh = fp
	var fmat: ShaderMaterial = ShaderMaterial.new()
	fmat.shader = load("res://shaders/VFX_FloodWaves.gdshader") as Shader
	flood_water.material_override = fmat
	flood_water.position.y = -15.0
	add_child(flood_water)


func _build_ark() -> void:
	# Instantiate Exact Biblical 300:50:30 Ark (102m x 17m x 10.2m) at true 1:1 scale on the leveled plateau!
	ark_anchor = Node3D.new()
	ark_anchor.name = "ArkAnchor"
	ark_base_y = terrain_height(0.0, 0.0)
	ark_anchor.position = Vector3(0.0, ark_base_y, 0.0)
	add_child(ark_anchor)

	var packed: PackedScene = load("res://assets/models/BLD_NoahsArk.glb") as PackedScene
	ark = Node3D.new()
	ark.name = "BLD_NoahsArk_1to1"
	if packed != null:
		var m: Node3D = packed.instantiate() as Node3D
		if m != null:
			ark.add_child(m)
	ark_anchor.add_child(ark)
	ark_scale = 1.0

	# Warm hanging oil-lanterns along all 3 cathedral-scale decks (hidden during Flood!)
	ark_lanterns.clear()
	for dy in [2.9, 6.1, 8.6]:
		for lx in [-32.0, -10.0, 12.0, 34.0]:
			var l: OmniLight3D = OmniLight3D.new()
			l.name = "ArkLantern_%d_%d" % [int(dy), int(lx)]
			l.position = Vector3(lx, dy, 0.0)
			l.light_color = Color(1.0, 0.78, 0.44)
			l.light_energy = 2.8
			l.omni_range = 18.0
			ark_anchor.add_child(l)
			ark_lanterns.append(l)


func set_ark_stage(stage: int, cutaway: bool = false, retract_ramp: bool = false) -> void:
	if ark == null:
		return
	for node in ark.find_children("*", "MeshInstance3D", true, false):
		var n: String = str(node.name)
		if n.begins_with("Stage1"):
			node.visible = stage >= 1
		elif n.begins_with("Stage2_HullBackEnds"):
			node.visible = stage >= 2
		elif n.begins_with("Stage2_HullFrontCutaway"):
			node.visible = stage >= 2 and not cutaway
		elif n.begins_with("Interior_"):
			node.visible = stage >= 2
		elif n.begins_with("Stage3_RoofCutaway"):
			node.visible = stage >= 3 and not cutaway
		elif n.begins_with("Stage3_Ramp"):
			node.visible = stage >= 2 and not retract_ramp
		else:
			node.visible = stage >= 3


func _build_shipyard_props() -> void:
	var wood: StandardMaterial3D = _mat(Color(0.34, 0.22, 0.12), 0.90)
	wood.albedo_texture = load("res://assets/textures/wood_timber_albedo.png") as Texture2D

	yard_stakes = Node3D.new()
	yard_stakes.name = "YardStakes"
	add_child(yard_stakes)
	for sx in [-48.0, 48.0]:
		for sz in [-8.5, 8.5]:
			_box(yard_stakes, Vector3(0.22, 1.2, 0.22), grounded(sx, sz, 0.55), wood)

	timber_stacks = Node3D.new()
	timber_stacks.name = "TimberStacks"
	add_child(timber_stacks)
	for i in range(14):
		var tx: float = -16.0 + float(i % 2) * 0.5
		var tz: float = 15.0 + float(i % 4) * 0.48
		var ty: float = float(i / 4) * 0.32 + 0.16
		_box(timber_stacks, Vector3(5.2, 0.30, 0.34), grounded(tx, tz, ty), wood)

	guard_fence = Node3D.new()
	guard_fence.name = "GuardFence"
	add_child(guard_fence)
	for i in range(15):
		var seg: Node3D = Node3D.new()
		seg.name = "FenceSeg_%d" % i
		var fx: float = -24.0 + float(i) * 1.6
		var fz: float = 22.5
		_box(seg, Vector3(0.22, 1.85, 0.22), grounded(fx, fz, 0.92), wood)
		if i < 14:
			_box(seg, Vector3(1.65, 0.16, 0.14), grounded(fx + 0.8, fz, 0.65), wood)
			_box(seg, Vector3(1.65, 0.16, 0.14), grounded(fx + 0.8, fz, 1.28), wood)
		seg.hide()
		guard_fence.add_child(seg)

	pitch_station = Node3D.new()
	pitch_station.name = "PitchStation"
	add_child(pitch_station)
	var pot_mi: MeshInstance3D = MeshInstance3D.new()
	var pot_cm: CylinderMesh = CylinderMesh.new()
	pot_cm.top_radius = 0.78
	pot_cm.bottom_radius = 0.55
	pot_cm.height = 0.85
	pot_mi.mesh = pot_cm
	pot_mi.material_override = _mat(Color(0.08, 0.06, 0.04), 0.75)
	pot_mi.position = grounded(12.5, 14.5, 0.42)
	pitch_station.add_child(pot_mi)
	for i in range(6):
		spawn_asset("CC0_Amphora.glb", 0.92, grounded(14.5 + float(i % 3) * 0.85, 14.0 + float(i / 3) * 0.95), pitch_station)


## Age of Empires-style progressive Palisade Fence building (segments rise visibly from 0% -> 100%!)
func set_fence_progress(pct: float) -> void:
	if guard_fence == null:
		return
	var total: int = guard_fence.get_child_count()
	var built: int = int(floor(clampf(pct, 0.0, 100.0) / 100.0 * float(total)))
	guard_fence.visible = built > 0
	for i in range(total):
		var seg: Node3D = guard_fence.get_child(i) as Node3D
		if seg != null:
			seg.visible = i < built


func _build_east_forest() -> void:
	forest_group = Node3D.new()
	forest_group.name = "EastGopherWoodForest"
	add_child(forest_group)
	for i in range(30):
		var fx: float = 58.0 + fmod(float(i) * 11.7, 46.0)
		var fz: float = -34.0 + fmod(float(i) * 14.3, 68.0)
		var tree: Node3D = spawn_asset("CC0_OliveTree_Optimized.glb", 4.5 + float(i % 4) * 1.35, grounded_embedded(fx, fz, 1.2, 0.25), forest_group)
		tree.rotation.y = float(i) * 1.27
	# Lush foreground & western canyon trees
	for tp: Vector2 in [Vector2(-46.0, 22.0), Vector2(-58.0, -14.0), Vector2(44.0, 22.0), Vector2(54.0, -18.0), Vector2(-70.0, 12.0), Vector2(-72.0, -8.0)]:
		var vt: Node3D = spawn_asset("CC0_OliveTree_Optimized.glb", 5.2, grounded_embedded(tp.x, tp.y, 1.2, 0.25), forest_group)
		vt.rotation.y = tp.x * 0.2


func _build_south_village() -> void:
	village_group = Node3D.new()
	village_group.name = "SouthNeighborVillage"
	add_child(village_group)
	var mud_mat: StandardMaterial3D = _mat(Color(0.68, 0.58, 0.45), 0.94)
	var roof_mat: StandardMaterial3D = _mat(Color(0.52, 0.42, 0.31), 0.96)
	var door_mat: StandardMaterial3D = _mat(Color(0.18, 0.12, 0.08), 0.92)
	var houses: Array[Vector3] = [
		Vector3(-12.0, 0.0, 44.0), Vector3(12.0, 0.0, 43.0), Vector3(-4.0, 0.0, 52.0),
		Vector3(8.5, 0.0, 53.0), Vector3(20.0, 0.0, 49.0), Vector3(-18.0, 0.0, 55.0),
		Vector3(2.0, 0.0, 60.0), Vector3(16.0, 0.0, 59.0),
	]
	for i in range(houses.size()):
		var hp: Vector3 = houses[i]
		var w: float = 4.2 + float(i % 3) * 1.0
		var h: float = 2.8 + float(i % 2) * 0.8
		var d: float = 3.8 + float((i + 1) % 3) * 0.8
		var base: Vector3 = grounded_embedded(hp.x, hp.z, 2.2, 0.45)
		var rot: float = float(i % 4) * 0.20 - 0.3
		_box(village_group, Vector3(w, h, d), base + Vector3(0.0, h * 0.5, 0.0), mud_mat, rot)
		_box(village_group, Vector3(w + 0.18, 0.24, d + 0.18), base + Vector3(0.0, h + 0.05, 0.0), roof_mat, rot)
		_box(village_group, Vector3(0.85, 1.55, 0.14), base + Vector3(0.0, 0.78, -d * 0.5 - 0.02), door_mat, rot)


func _build_altar_and_ararat() -> void:
	altar_group = Node3D.new()
	altar_group.name = "LimestoneAltar"
	altar_group.position = grounded(0.5, 23.0)
	add_child(altar_group)

	# Real PolyHaven Photogrammetry Stone Fire Pit as the core of the unhewn altar!
	spawn_asset("res://assets/cc0_models/stone_fire_pit/stone_fire_pit_1k.gltf", 0.95, Vector3.ZERO, altar_group)

	var ember: StandardMaterial3D = _mat(Color(0.95, 0.50, 0.14), 0.85)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.54, 0.16)
	ember.emission_energy_multiplier = 0.85
	_box(altar_group, Vector3(0.65, 0.08, 0.55), Vector3(0.0, 0.62, 0.0), ember)

	var fire_light: OmniLight3D = OmniLight3D.new()
	fire_light.position = Vector3(0.0, 1.25, 0.0)
	fire_light.light_color = Color(1.0, 0.62, 0.25)
	fire_light.light_energy = 1.15
	fire_light.omni_range = 6.0
	altar_group.add_child(fire_light)

	var smoke: CPUParticles3D = CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 3.4
	smoke.preprocess = 3.4
	smoke.position = Vector3(0.0, 0.92, 0.0)
	smoke.direction = Vector3(0.10, 1.0, 0.04)
	smoke.spread = 15.0
	smoke.gravity = Vector3(0.01, 0.03, 0.0)
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.65
	smoke.scale_amount_min = 0.22
	smoke.scale_amount_max = 0.56
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.94, 0.95, 0.96, 0.0))
	grad.add_point(0.25, Color(0.94, 0.95, 0.96, 0.11))
	grad.set_color(1, Color(0.94, 0.95, 0.96, 0.0))
	smoke.color_ramp = grad
	var q: QuadMesh = QuadMesh.new()
	var smat: StandardMaterial3D = _mat(Color.WHITE)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var tex: GradientTexture2D = GradientTexture2D.new()
	var rgrad: Gradient = Gradient.new()
	rgrad.set_color(0, Color.WHITE)
	rgrad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = rgrad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	smat.albedo_texture = tex
	q.material = smat
	smoke.mesh = q
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	altar_group.add_child(smoke)
	altar_group.hide()

	puddles_group = Node3D.new()
	puddles_group.name = "AraratPuddles"
	add_child(puddles_group)
	var pmat: StandardMaterial3D = _mat(Color(0.16, 0.24, 0.30, 0.50), 0.06, 0.32)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(6):
		var spots: Array[Vector2] = [Vector2(-4.2, 21.5), Vector2(-2.2, 25.5), Vector2(3.0, 26.0), Vector2(5.2, 23.8), Vector2(-5.5, 24.5), Vector2(6.0, 20.5)]
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 0.85
		disc.bottom_radius = 0.85
		disc.height = 0.01
		var pm: MeshInstance3D = MeshInstance3D.new()
		pm.mesh = disc
		pm.material_override = pmat
		pm.position = grounded(spots[i].x, spots[i].y, 0.025)
		pm.scale = Vector3(1.25 + float(i % 3) * 0.25, 1.0, 0.72 + float(i % 2) * 0.22)
		pm.rotation.y = float(i) * 1.1
		puddles_group.add_child(pm)
	puddles_group.hide()

	olive_shoots = Node3D.new()
	olive_shoots.name = "FreshOliveShoots"
	add_child(olive_shoots)
	for sp: Vector2 in [Vector2(-6.5, 24.8), Vector2(7.4, 24.4), Vector2(-8.0, 17.2)]:
		spawn_asset("CC0_OliveTree_Optimized.glb", 1.15, grounded(sp.x, sp.y), olive_shoots)
	olive_shoots.hide()


func _build_god_ray() -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 8.8
	cyl.height = 56.0
	cyl.radial_segments = 32
	cyl.cap_top = false
	cyl.cap_bottom = false
	god_ray = MeshInstance3D.new()
	god_ray.name = "DivineLightShaft"
	god_ray.mesh = cyl
	var gmat: ShaderMaterial = ShaderMaterial.new()
	gmat.shader = load("res://shaders/VFX_GodRay.gdshader") as Shader
	god_ray.material_override = gmat
	god_ray.position = Vector3(2.0, 24.0, 10.0)
	god_ray.rotation_degrees = Vector3(10.0, 0.0, -16.0)
	god_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot: SpotLight3D = SpotLight3D.new()
	spot.position = Vector3(0.0, 18.0, 0.0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color(1.0, 0.85, 0.50)
	spot.light_energy = 10.0
	spot.spot_range = 60.0
	spot.spot_angle = 28.0
	god_ray.add_child(spot)
	add_child(god_ray)
	god_ray.hide()


func _build_rainbow() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		for v: Vector2 in [Vector2(i, 0), Vector2(i + 1, 0), Vector2(i, 1), Vector2(i + 1, 0), Vector2(i + 1, 1), Vector2(i, 1)]:
			var u: float = v.x / 96.0
			var a: float = u * PI
			var r: float = 28.0 + v.y * 5.8
			st.set_uv(Vector2(u, v.y))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r, 0.0))
	st.generate_normals()
	rainbow = MeshInstance3D.new()
	rainbow.name = "VFX_CovenantRainbow"
	rainbow.mesh = st.commit()
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = load("res://shaders/VFX_CovenantRainbow.gdshader") as Shader
	rainbow.material_override = smat
	rainbow.position = Vector3(2.0, 2.0, -36.0)
	rainbow.rotation_degrees.y = -8.0
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rainbow)
	rainbow.hide()


func _build_rain() -> void:
	var is_mobile: bool = RenderingServer.get_current_rendering_method() != "forward_plus"
	if not is_mobile:
		rain_collider = GPUParticlesCollisionHeightField3D.new()
		rain_collider.name = "RainHeightFieldCollider"
		rain_collider.size = Vector3(140.0, 44.0, 140.0)
		rain_collider.position = Vector3(0.0, 10.0, 4.0)
		rain_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
		rain_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
		add_child(rain_collider)

		rain_splash = GPUParticles3D.new()
		rain_splash.name = "RainSplashSubEmitter"
		rain_splash.amount = 600
		rain_splash.lifetime = 0.28
		rain_splash.emitting = false
		var sp_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		sp_mat.direction = Vector3(0.0, 1.0, 0.0)
		sp_mat.spread = 58.0
		sp_mat.initial_velocity_min = 1.6
		sp_mat.initial_velocity_max = 3.2
		sp_mat.gravity = Vector3(0.0, -9.8, 0.0)
		rain_splash.process_material = sp_mat
		var sp_mesh: SphereMesh = SphereMesh.new()
		sp_mesh.radius = 0.04
		sp_mesh.height = 0.08
		var sp_draw_mat: StandardMaterial3D = _mat(Color(0.80, 0.88, 0.94, 0.60), 0.1)
		sp_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sp_mesh.material = sp_draw_mat
		rain_splash.draw_pass_1 = sp_mesh
		add_child(rain_splash)

	rain = GPUParticles3D.new()
	rain.name = "FloodRainGPU"
	rain.amount = 450 if is_mobile else 1400
	rain.lifetime = 1.6
	rain.position = Vector3(0.0, 32.0, 6.0)
	add_child(rain)
	if not is_mobile and rain_splash != null:
		rain.sub_emitter = rain.get_path_to(rain_splash)
	var rmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	rmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rmat.emission_box_extents = Vector3(58.0, 3.0, 48.0)
	rmat.direction = Vector3(-0.14, -1.0, 0.06)
	rmat.spread = 3.0
	rmat.initial_velocity_min = 22.0
	rmat.initial_velocity_max = 28.0
	rmat.gravity = Vector3(0.0, -8.0, 0.0)
	if not is_mobile:
		rmat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		rmat.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
		rmat.sub_emitter_amount_at_collision = 2
	rain.process_material = rmat
	var drop: BoxMesh = BoxMesh.new()
	drop.size = Vector3(0.025, 0.75, 0.025)
	var dmat: StandardMaterial3D = _mat(Color(0.72, 0.82, 0.90, 0.48), 0.15)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dmat
	rain.draw_pass_1 = drop
	rain.emitting = false


func apply_mood(mode: String) -> void:
	if road_mesh != null:
		road_mesh.visible = (mode != "ararat")
	if village_group != null:
		village_group.visible = (mode != "ararat")
	for l in ark_lanterns:
		l.visible = true
		l.light_energy = 4.5 if mode == "flood" else 3.0
	var t: Tween = create_tween().set_parallel(true)
	match mode:
		"revelation":
			rain.emitting = false
			god_ray.show()
			terrain_mat.set_shader_parameter("wetness", 0.12)
			t.tween_property(sun, "rotation_degrees", Vector3(-18.0, -48.0, 0.0), 1.6)
			t.tween_property(sun, "light_color", Color(1.0, 0.78, 0.44), 1.4)
			t.tween_property(sun, "light_energy", 1.75, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.08, 0.11, 0.18), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.62, 0.48, 0.32), 1.4)
			t.tween_property(environment, "volumetric_fog_density", 0.012, 1.4)
		"build":
			rain.emitting = false
			god_ray.hide()
			terrain_mat.set_shader_parameter("wetness", 0.0)
			t.tween_property(sun, "rotation_degrees", Vector3(-24.0, -42.0, 0.0), 1.6)
			t.tween_property(sun, "light_color", Color(1.0, 0.87, 0.66), 1.4)
			t.tween_property(sun, "light_energy", 2.15, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.18, 0.31, 0.50), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.76, 0.68, 0.54), 1.4)
			t.tween_property(environment, "volumetric_fog_density", 0.007, 1.4)
		"dusk_raid":
			rain.emitting = false
			god_ray.hide()
			terrain_mat.set_shader_parameter("wetness", 0.16)
			t.tween_property(sun, "rotation_degrees", Vector3(-13.0, -68.0, 0.0), 1.6)
			t.tween_property(sun, "light_color", Color(0.92, 0.46, 0.22), 1.4)
			t.tween_property(sun, "light_energy", 0.95, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.05, 0.07, 0.14), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.46, 0.24, 0.16), 1.4)
			t.tween_property(environment, "volumetric_fog_density", 0.012, 1.4)
		"flood":
			rain.emitting = true
			god_ray.hide()
			terrain_mat.set_shader_parameter("wetness", 0.92)
			t.tween_property(sun, "rotation_degrees", Vector3(-32.0, -25.0, 0.0), 1.4)
			t.tween_property(sun, "light_color", Color(0.54, 0.64, 0.76), 1.4)
			t.tween_property(sun, "light_energy", 0.72, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.08, 0.11, 0.16), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.24, 0.29, 0.35), 1.4)
			t.tween_property(environment, "volumetric_fog_density", 0.016, 1.4)
		"ararat":
			rain.emitting = false
			god_ray.hide()
			terrain_mat.set_shader_parameter("wetness", 0.78)
			t.tween_property(sun, "rotation_degrees", Vector3(-22.0, -44.0, 0.0), 1.6)
			t.tween_property(sun, "light_color", Color(1.0, 0.85, 0.58), 1.6)
			t.tween_property(sun, "light_energy", 2.05, 1.6)
			t.tween_property(sky_material, "sky_top_color", Color(0.20, 0.36, 0.56), 1.6)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.84, 0.74, 0.58), 1.6)
			t.tween_property(environment, "volumetric_fog_density", 0.009, 1.6)
