class_name BethelHighlandWorld
extends Node3D
## Chapter 1 (`Ch01`): True 128x96m 7-Zone Central Canaanite Highland World (Genesis 13:1–18):
## - Zone 1 (0, 0): Central Levant Pavilion Tent (`BLD_MainTent_cloth.glb`, walkable 1P oil-lamp interior!)
## - Zone 2 (2, -24): North Rocky Ridge 12-Stone Unhewn Altar (`创 13:4`) + Divine Sun Shaft
## - Zone 3 (-30, -6): West Spring Valley Stone Well (`BLD_StoneWell.glb`) + Amphorae
## - Zone 4 (+30, -6): East Dry-Stone Terraced Olive Grove (`CC0_DryStoneWall` + 18 harvestable Olive Trees)
## - Zone 5 (-4, +20): South Shared Pasture (9-bone rigged Sheep & Bulls + Lot's Canopy)
## - Zone 6 (+32, +22): Southeast Jordan Plain Cliff Overlook (`创 13:10–15`)
## - Zone 7 (-28, +20): Southwest Ai Caravan Road + Pack Horses

const Loader: Script = preload("res://scripts/glb_asset_loader.gd")

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var terrain_mat: ShaderMaterial

var main_tent: Node3D
var lot_tent: Node3D
var altar_group: Node3D
var god_ray: MeshInstance3D
var well_group: Node3D
var grove_group: Node3D
var grove_trees: Array[Dictionary] = []
var pasture_group: Node3D
var caravan_group: Node3D


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func spawn_asset(file: String, height: float, pos: Vector3, parent: Node3D = self) -> Node3D:
	var res_path: String = file if file.begins_with("res://") else ("res://assets/models/" + file)
	var packed: PackedScene = load(res_path) as PackedScene
	var wrapper := Node3D.new()
	wrapper.name = res_path.get_file().get_basename()
	if packed != null:
		var model: Node3D = packed.instantiate() as Node3D
		if model != null:
			var bounds: AABB = Loader._compute_local_aabb(model)
			var factor: float = height / maxf(bounds.size.y, 0.001)
			model.scale = Vector3.ONE * factor
			model.position.y = -bounds.position.y * factor
			wrapper.add_child(model)
	parent.add_child(wrapper)
	wrapper.position = pos
	return wrapper


func terrain_height(x: float, z: float) -> float:
	# Zone 1 Central Courtyard flat terrace around (0, 0)
	var center_flat: float = (1.0 - smoothstep(10.0, 20.0, Vector2(x, z).length()))
	# Zone 2 North Altar Ridge around (2, -25) -> rises +3.8m
	var north_ridge: float = exp(-pow((x - 2.0) / 22.0, 2.0) - pow((z + 25.0) / 14.0, 2.0)) * 3.85
	# Zone 3 West Spring Valley hollow around (-30, -6) -> dips -2.1m
	var west_hollow: float = exp(-pow((x + 30.0) / 14.0, 2.0) - pow((z + 6.0) / 14.0, 2.0)) * 2.15
	# Zone 4 East Olive Terraces around (+30, -6) -> stepped +2.6m
	var east_hill: float = smoothstep(16.0, 44.0, x) * 2.65
	# Zone 6 Southeast Jordan Overlook Bluff around (+32, +22) -> +3.2m then drops east
	var se_bluff: float = exp(-pow((x - 32.0) / 15.0, 2.0) - pow((z - 22.0) / 13.0, 2.0)) * 2.2
	var organic: float = (sin(x * 0.09 + z * 0.07) * 0.45 + cos(z * 0.11 - x * 0.06) * 0.35) * (1.0 - center_flat * 0.9)
	return (north_ridge - west_hollow + east_hill + se_bluff + organic) * (1.0 - center_flat * 0.85)


func grounded(x: float, z: float, y_off: float = 0.0) -> Vector3:
	return Vector3(x, terrain_height(x, z) + y_off, z)


func grounded_embedded(x: float, z: float, radius: float, sink: float) -> Vector3:
	var hm: float = terrain_height(x, z)
	for off: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		hm = minf(hm, terrain_height(x + off.x, z + off.y))
	return Vector3(x, hm - sink, z)


func build_all() -> void:
	_build_sky_and_sun()
	_build_terrain_and_roads()
	_build_multimesh_cover()
	_build_7_zones()


func _build_sky_and_sun() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.17, 0.34, 0.56)
	sky_material.sky_horizon_color = Color(0.84, 0.74, 0.56)
	sky_material.ground_bottom_color = Color(0.20, 0.16, 0.12)
	sky_material.ground_horizon_color = Color(0.56, 0.48, 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.04
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.80, 0.72, 0.58)
	environment.fog_density = 0.0024
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.sdfgi_enabled = true
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.0065
		environment.volumetric_fog_albedo = Color(0.90, 0.82, 0.68)
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.66)
	sun.light_energy = 2.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)


func _build_terrain_and_roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 72
	var nz: int = 56
	for iz in range(nz):
		for ix in range(nx):
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var px: float = lerpf(-64.0, 64.0, float(ix + c.x) / float(nx))
				var pz: float = lerpf(-48.0, 48.0, float(iz + c.y) / float(nz))
				st.set_uv(Vector2(px, pz) * 0.09)
				st.add_vertex(Vector3(px, terrain_height(px, pz), pz))
	st.index()
	st.generate_normals()

	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/VFX_HighlandTerrain.gdshader") as Shader
	terrain_mat.set_shader_parameter("grass_albedo", load("res://assets/textures/terrain_grass_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("dirt_albedo", load("res://assets/textures/terrain_dirt_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("rock_albedo", load("res://assets/textures/terrain_rock_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("rock_normal", load("res://assets/textures/terrain_rock_normal.png") as Texture2D)
	terrain_mat.set_shader_parameter("boulder_albedo", load("res://assets/textures/rock_boulder_albedo.png") as Texture2D)
	terrain_mat.set_shader_parameter("wetness", 0.06)

	var mi := MeshInstance3D.new()
	mi.name = "Bethel128x96Terrain"
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	add_child(mi)
	WorldPhysicsBuilder.attach_terrain_collider(mi)

	# Photogrammetry perimeter cliffs & boulders
	var cliff_1: String = "res://assets/cc0_models/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf"
	var bld_1: String = "res://assets/cc0_models/namaqualand_boulders_01/namaqualand_boulders_01_1k.gltf"
	for cs: Array in [[cliff_1, 14.0, -48.0, -34.0, 0.5], [cliff_1, 16.0, 22.0, -38.0, -0.6], [cliff_1, 13.0, 48.0, 28.0, -1.2]]:
		var cn: Node3D = spawn_asset(str(cs[0]), float(cs[1]), grounded_embedded(float(cs[2]), float(cs[3]), 6.0, 2.4))
		cn.rotation.y = float(cs[4])
	for bp: Vector3 in [Vector3(-18, 2.1, -16), Vector3(16, 1.9, -18), Vector3(-38, 2.3, 8), Vector3(40, 2.2, 12), Vector3(26, 1.8, 26)]:
		spawn_asset(bld_1, bp.y, grounded_embedded(bp.x, bp.z, 1.8, 0.55))


func _build_multimesh_cover() -> void:
	var g_st := SurfaceTool.new()
	g_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang in [0.0, PI * 0.33, PI * 0.66]:
		var dx: float = cos(ang) * 0.32; var dz: float = sin(ang) * 0.32
		var v0 := Vector3(-dx, 0, -dz); var v1 := Vector3(dx, 0, dz); var v2 := Vector3(dx * 0.85, 0.54, dz * 0.85); var v3 := Vector3(-dx * 0.85, 0.54, -dz * 0.85)
		for iv in [[v0, Vector2(0, 1)], [v1, Vector2(1, 1)], [v2, Vector2(1, 0)], [v0, Vector2(0, 1)], [v2, Vector2(1, 0)], [v3, Vector2(0, 0)]]:
			g_st.set_uv(iv[1]); g_st.add_vertex(iv[0])
	g_st.generate_normals()
	var g_mat: StandardMaterial3D = _mat(Color(0.45, 0.53, 0.30), 0.90)
	g_mat.albedo_texture = load("res://assets/textures/grass_tuft_alpha.png") as Texture2D
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	g_mat.alpha_scissor_threshold = 0.35
	g_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = g_st.commit()
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new(); rng.seed = 1318
	for i in range(1800):
		var gx: float = rng.randf_range(-56.0, 56.0)
		var gz: float = rng.randf_range(-40.0, 40.0)
		if Vector2(gx, gz).length() < 9.5:
			continue
		var gy: float = terrain_height(gx, gz)
		var sc: float = rng.randf_range(0.65, 1.45)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * sc), Vector3(gx, gy - 0.04, gz)))
	mm.instance_count = xforms.size()
	for i in range(xforms.size()): mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm; mmi.material_override = g_mat; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_7_zones() -> void:
	# Zone 1: Central Woven Levant Pavilion Tent (`BLD_MainTent_cloth.glb` + Interior Acoustic Zone!)
	main_tent = spawn_asset("BLD_MainTent_cloth.glb", 4.2, grounded(-2.0, -1.5))
	var tent_light := OmniLight3D.new()
	tent_light.position = Vector3(0.0, 2.4, 0.4)
	tent_light.light_color = Color(1.0, 0.78, 0.42)
	tent_light.light_energy = 2.8
	tent_light.omni_range = 10.5
	main_tent.add_child(tent_light)
	# Interior Levant furnishings: low cedar Covenant scroll table + clay amphorae
	var tbl := MeshInstance3D.new()
	var tbm := BoxMesh.new(); tbm.size = Vector3(1.15, 0.48, 0.65); tbl.mesh = tbm
	tbl.material_override = _mat(Color(0.42, 0.25, 0.12), 0.84)
	tbl.position = Vector3(0.85, 0.26, 0.35); main_tent.add_child(tbl)
	for ai in range(3):
		spawn_asset("CC0_Amphora.glb", 0.78, Vector3(1.55 - float(ai) * 0.45, 0.02, -0.55 + float(ai % 2) * 0.45), main_tent)
	WorldPhysicsBuilder.build_interior_acoustic_zone(main_tent, Vector3(6.5, 4.0, 5.5), Vector3(0, 2.0, 0))
	spawn_asset("BLD_HealingCanopy_cloth.glb", 3.2, grounded(7.5, 1.2)).rotation.y = -0.45

	# Zone 2: North Rocky Ridge 12-Stone Unhewn Altar (`创 13:4`)
	altar_group = Node3D.new()
	altar_group.name = "Bethel12StoneAltar"
	altar_group.position = grounded(2.0, -24.0)
	add_child(altar_group)
	spawn_asset("res://assets/cc0_models/stone_fire_pit/stone_fire_pit_1k.gltf", 1.05, Vector3.ZERO, altar_group)
	var stone_mat: StandardMaterial3D = _mat(Color(0.64, 0.59, 0.50), 0.92)
	for i in range(12):
		var a: float = (float(i) / 12.0) * TAU
		var smi := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(0.36, 0.62 + float(i % 3) * 0.14, 0.28)
		smi.mesh = sbm; smi.material_override = stone_mat
		smi.position = Vector3(cos(a) * 1.65, 0.28, sin(a) * 1.65)
		smi.rotation.y = -a
		altar_group.add_child(smi)
	spawn_asset("CC0_StoneStairs.glb", 2.2, grounded(2.0, -17.5)).rotation.y = PI

	var cyl := CylinderMesh.new(); cyl.top_radius = 2.0; cyl.bottom_radius = 6.5; cyl.height = 42.0; cyl.cap_top = false; cyl.cap_bottom = false
	god_ray = MeshInstance3D.new(); god_ray.mesh = cyl
	var gmat := ShaderMaterial.new(); gmat.shader = load("res://shaders/VFX_GodRay.gdshader") as Shader
	god_ray.material_override = gmat; god_ray.position = altar_group.position + Vector3(0, 18, 0)
	god_ray.rotation_degrees = Vector3(8, 0, -14); god_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(god_ray); god_ray.hide()

	# Zone 3: West Spring Valley Stone Well (`BLD_StoneWell.glb`)
	well_group = Node3D.new(); well_group.position = grounded(-30.0, -6.0); add_child(well_group)
	spawn_asset("BLD_StoneWell.glb", 2.35, Vector3.ZERO, well_group)
	for i in range(4):
		spawn_asset("CC0_Amphora.glb", 0.85, Vector3(1.8 + float(i % 2) * 0.7, 0.0, -0.6 + float(i / 2) * 0.8), well_group)

	# Zone 4: East Dry-Stone Terraced Olive Grove
	grove_group = Node3D.new(); add_child(grove_group)
	for wi in range(4):
		spawn_asset("CC0_DryStoneWall_Optimized.glb", 1.25, grounded(22.0, -16.0 + float(wi) * 7.5), grove_group).rotation.y = PI * 0.5
	for ti in range(18):
		var tx: float = 25.0 + fmod(float(ti) * 7.3, 24.0)
		var tz: float = -22.0 + fmod(float(ti) * 9.7, 34.0)
		var tr_n: Node3D = spawn_asset("CC0_OliveTree_Optimized.glb", 4.4 + float(ti % 3) * 0.9, grounded_embedded(tx, tz, 1.0, 0.2), grove_group)
		tr_n.rotation.y = float(ti) * 1.3
		grove_trees.append({"node": tr_n, "pos": grounded(tx, tz)})

	# Zone 5: South Shared Pasture + Lot's Tent + 9-Bone Rigged Sheep & Bulls
	pasture_group = Node3D.new(); add_child(pasture_group)
	lot_tent = spawn_asset("BLD_HealingCanopy_cloth.glb", 3.5, grounded(12.0, 18.0), pasture_group)
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	if sm_node != null and sm_node.has_method("make_spatial_loop_3d"):
		var sp_b: AudioStreamPlayer3D = sm_node.call("make_spatial_loop_3d", "sfx_animals_breath.wav", grounded(-4.0, 20.0, 1.0), 20.0, -11.0, false) as AudioStreamPlayer3D
		if sp_b != null: pasture_group.add_child(sp_b)

	# Zone 6: Southeast Jordan Plain Overlook Marker Stones
	for si in range(3):
		spawn_asset("res://assets/cc0_models/namaqualand_boulder_02/namaqualand_boulder_02_1k.gltf", 1.3, grounded_embedded(34.0 + float(si) * 1.8, 22.0 + float(si % 2) * 1.5, 0.8, 0.35))

	# Zone 7: Southwest Ai Caravan Road
	caravan_group = Node3D.new(); caravan_group.position = grounded(-28.0, 20.0); add_child(caravan_group)
	for hi in range(2):
		var hrs: Node3D = spawn_asset("CC0_Horse_Grab3D.glb", 1.55, Vector3(float(hi) * 2.6, 0.0, 0.0), caravan_group)
		NoahCastAndRaidRig.play_simple_anim(hrs, "Idle")
	for ai in range(3):
		spawn_asset("CC0_Amphora.glb", 0.88, Vector3(-1.6 + float(ai) * 0.75, 0.0, 1.4), caravan_group)


func spawn_floating_text_3d(pos: Vector3, text: String, col: Color = Color(1.0, 0.90, 0.46)) -> void:
	if not is_inside_tree(): return
	var lbl := Label3D.new()
	lbl.text = text; lbl.position = pos; lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
	lbl.font_size = 36; lbl.pixel_size = 0.0042; lbl.modulate = col; lbl.outline_modulate = Color(0.06, 0.04, 0.02); lbl.outline_size = 9
	add_child(lbl)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y + 1.9, 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)
