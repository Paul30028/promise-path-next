class_name NoahRTSWorld
extends Node3D
## 130x130m 4-Zone Sculpted Highland & Valley World for Noah's Ark RTS Prologue:
## - Center Plateau: Ark Shipyard Clearing, Timber Depot, Pitch Kiln, Post-Flood Limestone Altar
## - East Slope: Dense Gopher-Wood / Cypress Forest & Logging Camp
## - South Slope: Ancient Mudbrick Neighbor Village & Winding Dirt Road
## - West Deep Gorge: Winding Great River, Distant Mountain Ranges, Rising 3D Floodwater, God-Ray & Rainbow

const Loader: Script = preload("res://scripts/glb_asset_loader.gd")

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var terrain_mat: StandardMaterial3D

var ark_anchor: Node3D
var ark: Node3D
var god_ray: MeshInstance3D
var flood_water: MeshInstance3D
var river_mesh: MeshInstance3D
var rain: CPUParticles3D
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
	var packed: PackedScene = load("res://assets/models/" + file) as PackedScene
	var wrapper: Node3D = Node3D.new()
	wrapper.name = file.get_basename()
	if packed != null:
		var model: Node3D = packed.instantiate() as Node3D
		if model != null:
			var bounds: AABB = Loader._compute_local_aabb(model)
			var factor: float = height / maxf(bounds.size.y, 0.001)
			model.scale = Vector3.ONE * factor
			model.position.y = -bounds.position.y * factor
			wrapper.add_child(model)
	else:
		push_error("Missing model: " + file)
	parent.add_child(wrapper)
	wrapper.position = pos
	return wrapper


## Analytic 130x130m 4-zone heightfield matching 00A_noah_revelation & 00_prologue_noah_ark
func terrain_height(x: float, z: float) -> float:
	# Western deep river valley gorge (X < -15)
	var west_valley: float = 1.0 - smoothstep(-28.0, -14.0, x)
	# Central shipyard clearing plateau (X in [-13, 15], Z in [-10, 13])
	var plateau: float = smoothstep(-15.0, -9.0, x) * (1.0 - smoothstep(13.0, 20.0, x)) * smoothstep(-14.0, -8.0, z) * (1.0 - smoothstep(11.0, 17.0, z))
	# Slight raised rocky shelf for Ark at Z in [-8, -1]
	var ark_shelf: float = smoothstep(-12.0, -7.0, x) * (1.0 - smoothstep(11.0, 16.0, x)) * smoothstep(-11.0, -6.0, z) * (1.0 - smoothstep(-2.0, 2.0, z))
	# Eastern Gopher-Wood forest hillside (X > 18)
	var east_hill: float = smoothstep(16.0, 42.0, x) * (1.0 - smoothstep(26.0, 42.0, z))
	# Southern gentle slope toward neighbor village (Z > 16)
	var south_slope: float = smoothstep(14.0, 34.0, z) * smoothstep(-16.0, -4.0, x)
	# Distant northern mountain wall (Z < -22)
	var north_ridge: float = (1.0 - smoothstep(-58.0, -22.0, z))
	var organic: float = (sin(x * 0.14 + z * 0.11) * 0.85 + cos(z * 0.18 - x * 0.09) * 0.65) * (1.0 - plateau * 0.92)
	var river_x: float = -34.0 + sin(z * 0.065) * 6.5
	var channel: float = (1.0 - smoothstep(2.5, 7.0, absf(x - river_x))) * west_valley
	var h: float = 0.4 + ark_shelf * 1.15 + east_hill * 5.2 - south_slope * 2.4 + north_ridge * 11.5 + organic
	h = lerpf(h, -7.2 + organic * 0.35, west_valley) - channel * 1.1
	return h


func grounded(x: float, z: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x, terrain_height(x, z) + y_offset, z)


func build_all() -> void:
	_build_sky_and_lights()
	_build_terrain()
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
	sky_material.sky_top_color = Color(0.26, 0.35, 0.48)
	sky_material.sky_horizon_color = Color(0.76, 0.71, 0.62)
	sky_material.ground_bottom_color = Color(0.24, 0.21, 0.17)
	sky_material.ground_horizon_color = Color(0.55, 0.48, 0.38)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.74, 0.70, 0.63)
	environment.fog_density = 0.0045
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44.0, -36.0, 0.0)
	sun.light_color = Color(1.0, 0.90, 0.72)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 135.0
	sun.shadow_blur = 1.25
	add_child(sun)


func _build_terrain() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 72
	var nz: int = 72
	var min_x: float = -68.0
	var max_x: float = 68.0
	var min_z: float = -66.0
	var max_z: float = 62.0
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
				# Subtle vertex color biome tinting (greenish-olive valley & forest, warm limestone plateau)
				var valley_t: float = 1.0 - smoothstep(-26.0, -14.0, px)
				var forest_t: float = smoothstep(16.0, 32.0, px) * (1.0 - smoothstep(22.0, 34.0, pz))
				var col: Color = Color(0.86, 0.78, 0.65)
				col = col.lerp(Color(0.56, 0.64, 0.45), clampf(valley_t * 0.6 + forest_t * 0.55, 0.0, 0.75))
				if py > 4.5:
					col = col.lerp(Color(0.68, 0.66, 0.62), clampf((py - 4.5) / 8.0, 0.0, 0.65))
				st.set_color(col)
				st.set_uv(Vector2(px, pz) * 0.14)
				st.add_vertex(Vector3(px, py, pz))
	st.index()
	st.generate_normals()

	terrain_mat = _mat(Color(0.76, 0.68, 0.56), 0.92)
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png") as Texture2D
	terrain_mat.normal_enabled = true
	terrain_mat.normal_texture = load("res://assets/textures/terrain_rock_normal.png") as Texture2D
	terrain_mat.normal_scale = 0.65
	terrain_mat.uv1_triplanar = true
	terrain_mat.uv1_scale = Vector3(0.32, 0.32, 0.32)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "GrandHighlandTerrain"
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	add_child(mi)

	# Smooth terrain-hugging winding dirt road connecting South Village (Z=36) -> Shipyard (Z=8)
	var rst: SurfaceTool = SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rsteps: int = 36
	for i in range(rsteps):
		var t0: float = float(i) / float(rsteps)
		var t1: float = float(i + 1) / float(rsteps)
		var z0: float = lerpf(8.5, 36.0, t0)
		var z1: float = lerpf(8.5, 36.0, t1)
		var x0: float = sin(t0 * 2.8) * 3.8 + 1.5
		var x1: float = sin(t1 * 2.8) * 3.8 + 1.5
		var hw: float = 1.35
		var p0l: Vector3 = grounded(x0 - hw, z0, 0.04)
		var p0r: Vector3 = grounded(x0 + hw, z0, 0.04)
		var p1l: Vector3 = grounded(x1 - hw, z1, 0.04)
		var p1r: Vector3 = grounded(x1 + hw, z1, 0.04)
		for v: Vector3 in [p0l, p0r, p1l, p0r, p1r, p1l]:
			rst.set_uv(Vector2(v.x, v.z) * 0.25)
			rst.add_vertex(v)
	rst.generate_normals()
	var road_mi: MeshInstance3D = MeshInstance3D.new()
	road_mi.name = "VillageDirtRoad"
	road_mi.mesh = rst.commit()
	var road_mat: StandardMaterial3D = _mat(Color(0.50, 0.41, 0.30), 0.96)
	road_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png") as Texture2D
	road_mat.uv1_triplanar = true
	road_mi.material_override = road_mat
	add_child(road_mi)

	# Natural limestone rock outcrops framing cliff edge and Ark shelf
	var rock_mat: StandardMaterial3D = _mat(Color(0.62, 0.59, 0.53), 0.85)
	rock_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png") as Texture2D
	rock_mat.uv1_triplanar = true
	for i in range(52):
		var rx: float = -15.5 + sin(i * 1.93) * 3.2
		var rz: float = -24.0 + float(i) * 1.15
		if i >= 32:
			var a: float = float(i - 32) * 0.31
			rx = cos(a) * 13.5 + 1.0
			rz = -4.5 + sin(a) * 4.2
		var rm: SphereMesh = SphereMesh.new()
		rm.radial_segments = 7
		rm.rings = 4
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = rm
		rock.material_override = rock_mat
		rock.position = grounded(rx, rz, -0.15)
		rock.scale = Vector3(1.1 + float(i % 4) * 0.45, 0.55 + float(i % 3) * 0.32, 0.95 + float(i % 3) * 0.35)
		rock.rotation_degrees = Vector3(i * 11, i * 37, i * 7)
		add_child(rock)


func _build_river_and_flood() -> void:
	# Winding Western Valley Great River
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var rz: float = -64.0 + float(i + c.y) * 1.32
			var rx: float = -34.0 + sin(rz * 0.065) * 6.5 + (float(c.x) - 0.5) * 7.5
			st.set_uv(Vector2(float(c.x), float(i + c.y) * 0.08))
			st.add_vertex(Vector3(rx, -7.25, rz))
	st.generate_normals()
	river_mesh = MeshInstance3D.new()
	river_mesh.name = "WesternGreatRiver"
	river_mesh.mesh = st.commit()
	var rmat: StandardMaterial3D = _mat(Color(0.18, 0.33, 0.39), 0.14, 0.25)
	river_mesh.material_override = rmat
	add_child(river_mesh)

	# Real 3D Rising Floodwater Plane with animated rolling waves & white foam shader!
	flood_water = MeshInstance3D.new()
	flood_water.name = "RisingFloodWater"
	var fp: PlaneMesh = PlaneMesh.new()
	fp.size = Vector2(240.0, 240.0)
	fp.subdivide_width = 64
	fp.subdivide_depth = 64
	flood_water.mesh = fp
	var fmat: ShaderMaterial = ShaderMaterial.new()
	fmat.shader = load("res://shaders/VFX_FloodWaves.gdshader") as Shader
	flood_water.material_override = fmat
	flood_water.position.y = -10.5
	add_child(flood_water)


func _build_ark() -> void:
	ark_anchor = Node3D.new()
	ark_anchor.name = "ArkAnchor"
	ark_base_y = terrain_height(1.0, -4.5)
	ark_anchor.position = Vector3(1.0, ark_base_y, -4.5)
	add_child(ark_anchor)
	ark = spawn_asset("BLD_NoahsArk.glb", 4.8, Vector3.ZERO, ark_anchor)
	ark_scale = 4.8 / 4.93494165
	# Warm hanging oil-lantern lights along all 3 decks inside the enclosed Ark for First-Person Inspection!
	for lx in [-6.5, 0.0, 6.5]:
		var int_light: OmniLight3D = OmniLight3D.new()
		int_light.name = "ArkLantern_%d" % int(lx)
		int_light.position = Vector3(lx, 2.35, -0.2)
		int_light.light_color = Color(1.0, 0.80, 0.48)
		int_light.light_energy = 2.4
		int_light.omni_range = 12.0
		ark_anchor.add_child(int_light)


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
	var wood: StandardMaterial3D = _mat(Color(0.36, 0.22, 0.11), 0.90)
	wood.albedo_texture = load("res://assets/textures/wood_timber_albedo.png") as Texture2D

	# Layout stakes for Act 1 Revelation
	yard_stakes = Node3D.new()
	yard_stakes.name = "YardStakes"
	add_child(yard_stakes)
	for sx in [-9.5, 11.5]:
		for sz in [-6.8, -2.0]:
			_box(yard_stakes, Vector3(0.14, 0.9, 0.14), grounded(sx, sz, 0.45), wood)

	# Timber stacks
	timber_stacks = Node3D.new()
	timber_stacks.name = "TimberStacks"
	add_child(timber_stacks)
	for i in range(12):
		var tx: float = -7.5 + float(i % 2) * 0.4
		var tz: float = 2.5 + float(i % 4) * 0.42
		var ty: float = float(i / 4) * 0.28 + 0.14
		_box(timber_stacks, Vector3(3.4, 0.26, 0.28), grounded(tx, tz, ty), wood)

	# Non-lethal wooden Guard Fence (built during Night Raider crisis!)
	guard_fence = Node3D.new()
	guard_fence.name = "GuardFence"
	add_child(guard_fence)
	for i in range(11):
		var fx: float = -10.5 + float(i) * 1.1
		var fz: float = 8.2
		_box(guard_fence, Vector3(0.16, 1.45, 0.16), grounded(fx, fz, 0.72), wood)
		if i < 10:
			_box(guard_fence, Vector3(1.15, 0.12, 0.12), grounded(fx + 0.55, fz, 0.55), wood)
			_box(guard_fence, Vector3(1.15, 0.12, 0.12), grounded(fx + 0.55, fz, 1.05), wood)
	guard_fence.hide()

	# Pitch Cauldron & Provisions Amphorae
	pitch_station = Node3D.new()
	pitch_station.name = "PitchStation"
	add_child(pitch_station)
	var pot_mi: MeshInstance3D = MeshInstance3D.new()
	var pot_cm: CylinderMesh = CylinderMesh.new()
	pot_cm.top_radius = 0.62
	pot_cm.bottom_radius = 0.45
	pot_cm.height = 0.72
	pot_mi.mesh = pot_cm
	pot_mi.material_override = _mat(Color(0.08, 0.06, 0.04), 0.75)
	pot_mi.position = grounded(8.2, 2.2, 0.36)
	pitch_station.add_child(pot_mi)
	for i in range(6):
		spawn_asset("CC0_Amphora.glb", 0.85, grounded(9.6 + float(i % 3) * 0.75, 1.8 + float(i / 3) * 0.85), pitch_station)


func _build_east_forest() -> void:
	forest_group = Node3D.new()
	forest_group.name = "EastGopherWoodForest"
	add_child(forest_group)
	# ZERO plastic green cone trees! Pure handcrafted CC0 olive/cedar grove across East Slope & Western River Bank
	for i in range(28):
		var fx: float = 18.5 + fmod(float(i) * 7.3, 27.0)
		var fz: float = -22.0 + fmod(float(i) * 9.7, 44.0)
		var tree: Node3D = spawn_asset("CC0_OliveTree_Optimized.glb", 3.4 + float(i % 4) * 1.15, grounded(fx, fz), forest_group)
		tree.rotation.y = float(i) * 1.27
	# Lush valley olive trees along the western river bank & highland cliff
	for vz in [-28.0, -16.0, -4.0, 8.0, 20.0, 32.0]:
		var vx: float = -23.0 + sin(vz * 0.18) * 3.5
		var vt: Node3D = spawn_asset("CC0_OliveTree_Optimized.glb", 3.4 + absf(sin(vz)) * 1.1, grounded(vx, vz), forest_group)
		vt.rotation.y = vz * 0.4


func _build_south_village() -> void:
	village_group = Node3D.new()
	village_group.name = "SouthNeighborVillage"
	add_child(village_group)
	var mud_mat: StandardMaterial3D = _mat(Color(0.74, 0.63, 0.48), 0.94)
	var roof_mat: StandardMaterial3D = _mat(Color(0.58, 0.47, 0.34), 0.96)
	var door_mat: StandardMaterial3D = _mat(Color(0.22, 0.14, 0.08), 0.92)
	var houses: Array[Vector3] = [
		Vector3(-6.0, 0.0, 25.0), Vector3(7.5, 0.0, 24.0), Vector3(-2.5, 0.0, 31.5),
		Vector3(6.0, 0.0, 32.0), Vector3(13.5, 0.0, 29.0), Vector3(-9.0, 0.0, 34.0),
		Vector3(1.5, 0.0, 38.0), Vector3(11.0, 0.0, 37.5), Vector3(-5.0, 0.0, 41.0),
	]
	for i in range(houses.size()):
		var hp: Vector3 = houses[i]
		var w: float = 3.4 + float(i % 3) * 0.9
		var h: float = 2.4 + float(i % 2) * 0.7
		var d: float = 3.2 + float((i + 1) % 3) * 0.7
		var base: Vector3 = grounded(hp.x, hp.z)
		var rot: float = float(i % 4) * 0.22 - 0.3
		_box(village_group, Vector3(w, h, d), base + Vector3(0.0, h * 0.5 - 0.15, 0.0), mud_mat, rot)
		_box(village_group, Vector3(w + 0.16, 0.22, d + 0.16), base + Vector3(0.0, h - 0.1, 0.0), roof_mat, rot)
		_box(village_group, Vector3(0.75, 1.35, 0.12), base + Vector3(0.0, 0.65, -d * 0.5 - 0.02), door_mat, rot)


func _build_altar_and_ararat() -> void:
	altar_group = Node3D.new()
	altar_group.name = "LimestoneAltar"
	altar_group.position = grounded(0.5, 6.4)
	add_child(altar_group)

	var lime: StandardMaterial3D = _mat(Color(0.78, 0.75, 0.69), 0.88)
	lime.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png") as Texture2D
	lime.uv1_triplanar = true
	for i in range(16):
		var a: float = float(i % 8) * TAU / 8.0 + float(i / 8) * 0.35
		var rad: float = 0.74 if i < 8 else 0.58
		var ry: float = 0.24 if i < 8 else 0.58
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.36
		sm.height = 0.44
		sm.radial_segments = 7
		sm.rings = 3
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = sm
		rock.material_override = lime
		rock.position = Vector3(cos(a) * rad, ry, sin(a) * rad * 0.88)
		altar_group.add_child(rock)

	var log_mat: StandardMaterial3D = _mat(Color(0.28, 0.17, 0.09), 0.92)
	_box(altar_group, Vector3(0.95, 0.12, 0.14), Vector3(0.0, 0.82, 0.0), log_mat, 0.55)
	_box(altar_group, Vector3(0.95, 0.12, 0.14), Vector3(0.0, 0.86, 0.0), log_mat, -0.62)

	var ember: StandardMaterial3D = _mat(Color(0.95, 0.50, 0.14), 0.85)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.54, 0.16)
	ember.emission_energy_multiplier = 0.75
	_box(altar_group, Vector3(0.55, 0.08, 0.45), Vector3(0.0, 0.78, 0.0), ember)

	var fire_light: OmniLight3D = OmniLight3D.new()
	fire_light.position = Vector3(0.0, 1.15, 0.0)
	fire_light.light_color = Color(1.0, 0.62, 0.25)
	fire_light.light_energy = 0.85
	fire_light.omni_range = 4.5
	altar_group.add_child(fire_light)

	# Delicate translucent white rising smoke wisps
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
	smoke.scale_amount_min = 0.20
	smoke.scale_amount_max = 0.52
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

	# Wet reflective puddles & olive shoots for Ararat post-flood phase
	puddles_group = Node3D.new()
	puddles_group.name = "AraratPuddles"
	add_child(puddles_group)
	var pmat: StandardMaterial3D = _mat(Color(0.20, 0.28, 0.34, 0.52), 0.07, 0.28)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spots: Array[Vector2] = [
		Vector2(-3.2, 5.0), Vector2(-1.8, 8.6), Vector2(2.2, 9.2),
		Vector2(4.2, 7.6), Vector2(-4.4, 7.2), Vector2(5.0, 4.4),
	]
	for i in range(spots.size()):
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 0.72
		disc.bottom_radius = 0.72
		disc.height = 0.01
		var pm: MeshInstance3D = MeshInstance3D.new()
		pm.mesh = disc
		pm.material_override = pmat
		pm.position = grounded(spots[i].x, spots[i].y, 0.025)
		pm.scale = Vector3(1.15 + float(i % 3) * 0.25, 1.0, 0.7 + float(i % 2) * 0.22)
		pm.rotation.y = float(i) * 1.1
		puddles_group.add_child(pm)
	puddles_group.hide()

	olive_shoots = Node3D.new()
	olive_shoots.name = "FreshOliveShoots"
	add_child(olive_shoots)
	for sp: Vector2 in [Vector2(-4.6, 8.8), Vector2(5.4, 8.4), Vector2(-6.0, 2.2)]:
		spawn_asset("CC0_OliveTree_Optimized.glb", 0.95, grounded(sp.x, sp.y), olive_shoots)
	olive_shoots.hide()


func _build_god_ray() -> void:
	# Soft Fresnel-faded volumetric golden light shaft + SpotLight3D (Act 1 Revelation — NO figure of God!)
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 6.4
	cyl.height = 42.0
	cyl.radial_segments = 32
	cyl.cap_top = false
	cyl.cap_bottom = false
	god_ray = MeshInstance3D.new()
	god_ray.name = "DivineLightShaft"
	god_ray.mesh = cyl
	var gmat: ShaderMaterial = ShaderMaterial.new()
	gmat.shader = load("res://shaders/VFX_GodRay.gdshader") as Shader
	god_ray.material_override = gmat
	god_ray.position = Vector3(1.5, 18.0, -2.5)
	god_ray.rotation_degrees = Vector3(10.0, 0.0, -16.0)
	god_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot: SpotLight3D = SpotLight3D.new()
	spot.position = Vector3(0.0, 14.0, 0.0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color(1.0, 0.86, 0.54)
	spot.light_energy = 7.5
	spot.spot_range = 46.0
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
			var r: float = 20.0 + v.y * 3.2
			st.set_uv(Vector2(u, v.y))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r, 0.0))
	st.generate_normals()
	rainbow = MeshInstance3D.new()
	rainbow.name = "VFX_CovenantRainbow"
	rainbow.mesh = st.commit()
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = load("res://shaders/VFX_CovenantRainbow.gdshader") as Shader
	rainbow.material_override = smat
	rainbow.position = Vector3(-18.0, -4.5, -18.0)
	rainbow.rotation_degrees.y = 32.0
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rainbow)
	rainbow.hide()


func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "FloodRain"
	rain.amount = 900
	rain.lifetime = 1.6
	rain.position = Vector3(0.0, 24.0, 4.0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(36.0, 4.0, 32.0)
	rain.direction = Vector3(-0.14, -1.0, 0.06)
	rain.spread = 4.0
	rain.initial_velocity_min = 18.0
	rain.initial_velocity_max = 24.0
	rain.gravity = Vector3(0.0, -6.0, 0.0)
	var drop: BoxMesh = BoxMesh.new()
	drop.size = Vector3(0.022, 0.55, 0.022)
	drop.material = _mat(Color(0.65, 0.76, 0.84, 0.55), 0.2)
	rain.mesh = drop
	rain.emitting = false
	add_child(rain)


func apply_mood(mode: String) -> void:
	var t: Tween = create_tween().set_parallel(true)
	match mode:
		"revelation":
			rain.emitting = false
			god_ray.show()
			t.tween_property(sun, "light_color", Color(1.0, 0.82, 0.52), 1.4)
			t.tween_property(sun, "light_energy", 1.35, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.11, 0.14, 0.21), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.56, 0.47, 0.36), 1.4)
		"build":
			rain.emitting = false
			god_ray.hide()
			t.tween_property(sun, "light_color", Color(1.0, 0.90, 0.72), 1.4)
			t.tween_property(sun, "light_energy", 1.65, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.28, 0.42, 0.60), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.79, 0.74, 0.64), 1.4)
		"dusk_raid":
			rain.emitting = false
			god_ray.hide()
			t.tween_property(sun, "light_color", Color(0.75, 0.46, 0.30), 1.4)
			t.tween_property(sun, "light_energy", 0.55, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.06, 0.08, 0.15), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.32, 0.22, 0.20), 1.4)
		"flood":
			rain.emitting = true
			god_ray.hide()
			t.tween_property(sun, "light_color", Color(0.58, 0.66, 0.76), 1.4)
			t.tween_property(sun, "light_energy", 0.65, 1.4)
			t.tween_property(sky_material, "sky_top_color", Color(0.10, 0.13, 0.18), 1.4)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.26, 0.31, 0.36), 1.4)
		"ararat":
			rain.emitting = false
			god_ray.hide()
			t.tween_property(sun, "light_color", Color(1.0, 0.87, 0.64), 1.6)
			t.tween_property(sun, "light_energy", 1.75, 1.6)
			t.tween_property(sky_material, "sky_top_color", Color(0.30, 0.46, 0.62), 1.6)
			t.tween_property(sky_material, "sky_horizon_color", Color(0.84, 0.77, 0.65), 1.6)
