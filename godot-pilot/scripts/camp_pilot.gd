extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var metrics_label: Label = $HudLayer/MetricsLabel

var abram_actor: Node3D = null
var target_pos: Vector3 = Vector3(-1.8, 0.0, 1.3)
var move_speed: float = 4.2
var dragging: bool = false
var drag_distance: float = 0.0
var last_pointer_pos: Vector2 = Vector2.ZERO
var water_count: int = 12
var harmony_score: int = 75
var pending_action: String = ""
var status_note: String = "点击地面移动亚伯兰，或使用下方情境指令"
var status_label: Label = null
var anim_time: float = 0.0
var flame_nodes: Array[Node3D] = []
var smoke_nodes: Array[Node3D] = []


static func _make_draped_roof_mesh(w: float, d: float, ridge_h: float, eave_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sx: int = 12
	var sz: int = 8
	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	verts.resize((sx + 1) * (sz + 1))
	uvs.resize((sx + 1) * (sz + 1))
	for r in range(sz + 1):
		for c in range(sx + 1):
			var u: float = float(c) / float(sx)
			var v: float = float(r) / float(sz)
			var x: float = (u - 0.5) * w
			var z: float = (v - 0.5) * d
			var nz: float = abs(v - 0.5) * 2.0 # 0 at ridge, 1 at front/back eaves
			var catenary: float = pow(1.0 - nz, 1.35)
			var pole_sag: float = -sin(u * PI * 2.0) * 0.05 * (1.0 - nz * 0.4)
			var y: float = eave_h + (ridge_h - eave_h) * catenary + pole_sag
			var idx: int = r * (sx + 1) + c
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(u * 2.0, v * 2.0)
	for r in range(sz):
		for c in range(sx):
			var i0: int = r * (sx + 1) + c
			var i1: int = i0 + 1
			var i2: int = i0 + (sx + 1)
			var i3: int = i2 + 1
			for tri in [[i0, i1, i2], [i1, i3, i2]]:
				for vi in tri:
					st.set_uv(uvs[vi])
					st.add_vertex(verts[vi])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func get_terrain_height(x: float, z: float) -> float:
	var h: float = 0.0
	# 1. North-Central 12-Stone Altar Rocky Rise around (1.0, -4.9)
	var d_altar := Vector2((x - 1.0) * 0.78, (z + 4.9) * 0.92).length()
	if d_altar < 4.6:
		var t: float = clamp((4.6 - d_altar) / 2.2, 0.0, 1.0)
		h = max(h, t * t * (3.0 - 2.0 * t) * 1.65)

	# 2. Central-West Camp Courtyard Terrace around (-2.2, 0.2)
	var d_camp := Vector2((x + 2.2) * 0.62, (z - 0.2) * 0.90).length()
	if d_camp < 4.8:
		var t2: float = clamp((4.8 - d_camp) / 1.1, 0.0, 1.0)
		h = max(h, t2 * t2 * (3.0 - 2.0 * t2) * 0.52)

	# 3. Western Waterfall Spring Hollow around (-7.8, -1.2)
	var d_spring := Vector2((x + 7.8) * 0.9, (z + 1.2) * 0.95).length()
	if d_spring < 2.8:
		var t3: float = clamp((2.8 - d_spring) / 1.4, 0.0, 1.0)
		h -= t3 * t3 * (3.0 - 2.0 * t3) * 0.45

	# Gentle background hill slope to the north
	if z < -6.5:
		h += clamp((-6.5 - z) * 0.14, 0.0, 2.2)

	h += sin(x * 0.22) * cos(z * 0.24) * 0.10
	return h


func _ready() -> void:
	# Hide all legacy low-poly bobblehead placeholders
	for old_name in ["Abram", "MainTent", "WaterJar", "OliveTree1", "OliveTree2", "Sheep1", "Sheep2", "SpringBasin"]:
		var old_n := get_node_or_null(old_name)
		if old_n is Node3D:
			old_n.visible = false

	_build_pbr_terrain()
	_build_courtyard_wall_and_well()
	_build_patriarch_camp_architecture()
	_build_spring_waterfall()
	_build_characters()
	_build_sheep_flocks()
	_build_olive_groves()
	_build_set_dressing_multimesh()
	_build_mobile_hud()
	if abram_actor != null:
		target_pos = abram_actor.global_position


func _build_pbr_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var width: float = 56.0
	var depth: float = 42.0
	var cols: int = 72
	var rows: int = 54
	var dx: float = width / float(cols)
	var dz: float = depth / float(rows)

	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var weights: Array[Color] = []
	verts.resize((cols + 1) * (rows + 1))
	uvs.resize((cols + 1) * (rows + 1))
	weights.resize((cols + 1) * (rows + 1))

	for r in range(rows + 1):
		for c in range(cols + 1):
			var x: float = -width * 0.5 + float(c) * dx
			var z: float = -depth * 0.5 + float(r) * dz
			var y: float = get_terrain_height(x, z)
			var idx: int = r * (cols + 1) + c
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(float(c) / float(cols), float(r) / float(rows))

			var w_dirt: float = 0.04
			var w_grass: float = 0.92
			var w_rock: float = 0.04

			# Winding packed-earth trail matching camp-scene-mobile.png (front steps -> forks to SE & NE)
			var trail_front: float = abs(z - (3.8 - (x + 1.0) * 0.22))
			var trail_right: float = abs(x - (4.2 + sin(z * 0.24) * 1.1))
			var trail_dist: float = minf(trail_front, trail_right)
			if trail_dist < 1.55:
				var pt: float = clamp(1.0 - trail_dist / 1.55, 0.0, 1.0)
				w_dirt += pt * 1.5
				w_grass *= (1.0 - pt * 0.88)

			# Camp courtyard floor
			if Vector2((x + 2.2) * 0.65, (z - 0.2) * 0.92).length() < 4.5:
				w_dirt += 1.8
				w_grass *= 0.08

			# Rocky limestone altar mound & hillside
			if y > 0.72:
				var rt: float = clamp((y - 0.72) / 0.75, 0.0, 1.0)
				w_rock += rt * 2.0
				w_grass *= (1.0 - rt * 0.75)

			weights[idx] = Color(w_dirt, w_grass, w_rock, 1.0)

	for r in range(rows):
		for c in range(cols):
			var i0: int = r * (cols + 1) + c
			var i1: int = i0 + 1
			var i2: int = i0 + (cols + 1)
			var i3: int = i2 + 1
			for tri in [[i0, i1, i2], [i1, i3, i2]]:
				for vi in tri:
					st.set_uv(uvs[vi])
					st.set_color(weights[vi])
					st.add_vertex(verts[vi])

	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()

	var shader: Shader = load("res://shaders/canaan_terrain.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grass_albedo", load("res://assets/textures/terrain_grass_albedo.png"))
	mat.set_shader_parameter("grass_normal", load("res://assets/textures/terrain_grass_normal.png"))
	mat.set_shader_parameter("dirt_albedo", load("res://assets/textures/terrain_dirt_albedo.png"))
	mat.set_shader_parameter("dirt_normal", load("res://assets/textures/terrain_dirt_normal.png"))
	mat.set_shader_parameter("rock_albedo", load("res://assets/textures/rock_boulder_albedo.png"))
	mat.set_shader_parameter("rock_normal", load("res://assets/textures/rock_boulder_normal.png"))
	mat.set_shader_parameter("uv_scale", 0.24)

	var terrain_mesh: MeshInstance3D = $GroundBody/GroundMesh
	terrain_mesh.mesh = mesh
	terrain_mesh.set_surface_override_material(0, mat)


func _build_courtyard_wall_and_well() -> void:
	var root := Node3D.new()
	root.name = "CourtyardAndWell"
	add_child(root)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	wall_mat.normal_enabled = true
	wall_mat.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	wall_mat.albedo_color = Color(0.84, 0.78, 0.68)
	wall_mat.roughness = 0.94

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.24, 0.13)
	wood_mat.roughness = 0.90

	# 3 Wide Stone Steps at front of courtyard (-1.35, 2.75..3.6) using weathered boulder stone
	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	step_mat.normal_enabled = true
	step_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	step_mat.albedo_color = Color(0.76, 0.70, 0.58)
	step_mat.roughness = 0.94
	for s in range(3):
		var step := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.9, 0.24, 0.46)
		step.mesh = sb
		step.material_override = step_mat
		var sx: float = -1.35
		var sz: float = 2.72 + float(s) * 0.42
		step.position = Vector3(sx, get_terrain_height(sx, sz) + 0.28 - float(s) * 0.11, sz)
		root.add_child(step)

	# Circular Stacked-Stone Water Well at front-left (-7.2, 2.2) matching camp-scene-mobile.png
	var wx: float = -7.2
	var wz: float = 2.2
	var wy: float = get_terrain_height(wx, wz)
	var well := Node3D.new()
	well.position = Vector3(wx, wy, wz)
	root.add_child(well)

	var well_body := MeshInstance3D.new()
	var wcyl := CylinderMesh.new()
	wcyl.top_radius = 0.78
	wcyl.bottom_radius = 0.85
	wcyl.height = 0.78
	wcyl.radial_segments = 14
	well_body.mesh = wcyl
	well_body.material_override = wall_mat
	well_body.position = Vector3(0.0, 0.39, 0.0)
	well.add_child(well_body)

	var well_water := MeshInstance3D.new()
	var wdisc := CylinderMesh.new()
	wdisc.top_radius = 0.62
	wdisc.bottom_radius = 0.62
	wdisc.height = 0.04
	well_water.mesh = wdisc
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/spring_water.gdshader")
	well_water.material_override = wmat
	well_water.position = Vector3(0.0, 0.70, 0.0)
	well.add_child(well_water)

	for px in [-0.72, 0.72]:
		var wp := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.055
		pc.bottom_radius = 0.065
		pc.height = 1.25
		wp.mesh = pc
		wp.material_override = wood_mat
		wp.position = Vector3(px, 1.05, 0.0)
		well.add_child(wp)

	var bar := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.055
	bc.bottom_radius = 0.055
	bc.height = 1.65
	bar.mesh = bc
	bar.material_override = wood_mat
	bar.position = Vector3(0.0, 1.62, 0.0)
	bar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	well.add_child(bar)

	var bucket := MeshInstance3D.new()
	var bkc := CylinderMesh.new()
	bkc.top_radius = 0.18
	bkc.bottom_radius = 0.14
	bkc.height = 0.28
	bucket.mesh = bkc
	bucket.material_override = wood_mat
	bucket.position = Vector3(0.0, 1.05, 0.0)
	well.add_child(bucket)


func _build_patriarch_camp_architecture() -> void:
	var root := Node3D.new()
	root.name = "PatriarchCampPBR"
	add_child(root)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.40, 0.24, 0.13)
	wood_mat.roughness = 0.88

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_texture = load("res://assets/textures/tent_goathair_albedo.png")
	tent_mat.normal_enabled = true
	tent_mat.normal_texture = load("res://assets/textures/tent_goathair_normal.png")
	tent_mat.roughness = 0.94
	tent_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var tap_mat := StandardMaterial3D.new()
	tap_mat.albedo_texture = load("res://assets/textures/tapestry_tekhelet_albedo.png")
	tap_mat.roughness = 0.84
	tap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	rock_mat.roughness = 0.93

	var clay_mat := StandardMaterial3D.new()
	clay_mat.albedo_color = Color(0.68, 0.36, 0.20)
	clay_mat.roughness = 0.72

	# 1. Main Patriarch Pavilion Tent at (-3.5, y, -0.5)
	var cx: float = -3.5
	var cz: float = -0.5
	var cy: float = get_terrain_height(cx, cz)
	var tent_root := Node3D.new()
	tent_root.position = Vector3(cx, cy, cz)
	root.add_child(tent_root)

	for p in [Vector2(-1.85, -1.15), Vector2(0.0, -1.15), Vector2(1.85, -1.15), Vector2(-1.85, 1.15), Vector2(0.0, 1.15), Vector2(1.85, 1.15)]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.085
		cyl.bottom_radius = 0.105
		cyl.height = 2.0
		post.mesh = cyl
		post.material_override = wood_mat
		post.position = Vector3(p.x, 0.98, p.y)
		tent_root.add_child(post)

	# Draped Catenary Goat-Hair Roof + dark back curtain
	var main_roof := MeshInstance3D.new()
	main_roof.mesh = _make_draped_roof_mesh(4.35, 2.95, 2.42, 1.82)
	main_roof.material_override = tent_mat
	tent_root.add_child(main_roof)

	var back_curtain := MeshInstance3D.new()
	var bcb := BoxMesh.new()
	bcb.size = Vector3(3.8, 1.8, 0.08)
	back_curtain.mesh = bcb
	back_curtain.material_override = tent_mat
	back_curtain.position = Vector3(0.0, 0.95, -1.12)
	tent_root.add_child(back_curtain)

	# 2 Tekhelet Blue & Pomegranate Tapestry Banners + Woven Floor Rug + 2 Wooden Benches
	for bx in [-1.25, 1.25]:
		var banner := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(0.75, 1.12)
		banner.mesh = plane
		banner.material_override = tap_mat
		banner.position = Vector3(bx, 1.18, 1.18)
		tent_root.add_child(banner)

	var rug := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(1.85, 0.03, 1.25)
	rug.mesh = rmesh
	rug.material_override = tap_mat
	rug.position = Vector3(0.0, 0.03, 0.05)
	tent_root.add_child(rug)

	for bench_x in [-0.72, 0.72]:
		var bench := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.92, 0.32, 0.44)
		bench.mesh = bmesh
		bench.material_override = wood_mat
		bench.position = Vector3(bench_x, 0.16, -0.58)
		tent_root.add_child(bench)

	# 3 Terracotta Amphorae Cluster by Left Post (matching camp-scene-mobile.png!)
	for jar in [[Vector3(-2.15, 0.42, 1.35), 0.28, 0.84], [Vector3(-1.72, 0.32, 1.55), 0.22, 0.64], [Vector3(-1.42, 0.22, 1.82), 0.16, 0.44]]:
		var jm := MeshInstance3D.new()
		var jcyl := CylinderMesh.new()
		jcyl.top_radius = float(jar[1]) * 0.55
		jcyl.bottom_radius = float(jar[1])
		jcyl.height = float(jar[2])
		jm.mesh = jcyl
		jm.material_override = clay_mat
		jm.position = jar[0]
		tent_root.add_child(jm)

	# Stone Hearth & Warm Campfire
	var hearth := MeshInstance3D.new()
	var hcyl := CylinderMesh.new()
	hcyl.top_radius = 0.65
	hcyl.bottom_radius = 0.74
	hcyl.height = 0.26
	hearth.mesh = hcyl
	hearth.material_override = rock_mat
	hearth.position = Vector3(-0.35, 0.13, 2.05)
	tent_root.add_child(hearth)

	var fire_outer_mat := StandardMaterial3D.new()
	fire_outer_mat.albedo_color = Color(0.95, 0.32, 0.05)
	fire_outer_mat.emission_enabled = true
	fire_outer_mat.emission = Color(0.98, 0.34, 0.04)
	fire_outer_mat.emission_energy_multiplier = 2.2
	var fire_inner_mat := StandardMaterial3D.new()
	fire_inner_mat.albedo_color = Color(1.0, 0.82, 0.25)
	fire_inner_mat.emission_enabled = true
	fire_inner_mat.emission = Color(1.0, 0.78, 0.22)
	fire_inner_mat.emission_energy_multiplier = 3.0

	var hearth_fire := Node3D.new()
	hearth_fire.position = Vector3(-0.35, 0.24, 2.05)
	tent_root.add_child(hearth_fire)
	flame_nodes.append(hearth_fire)

	# Crossed charred firewood logs
	for ang_deg in [25.0, -35.0, 85.0]:
		var log_m := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.05
		lc.bottom_radius = 0.06
		lc.height = 0.72
		log_m.mesh = lc
		log_m.material_override = wood_mat
		log_m.rotation_degrees = Vector3(78.0, ang_deg, 0.0)
		log_m.position = Vector3(0.0, 0.04, 0.0)
		hearth_fire.add_child(log_m)

	var fcone := CylinderMesh.new()
	fcone.top_radius = 0.02
	fcone.bottom_radius = 0.22
	fcone.height = 0.48
	var flame_out := MeshInstance3D.new()
	flame_out.mesh = fcone
	flame_out.material_override = fire_outer_mat
	flame_out.position = Vector3(0.0, 0.24, 0.0)
	hearth_fire.add_child(flame_out)

	var flame_in := MeshInstance3D.new()
	flame_in.mesh = fcone
	flame_in.material_override = fire_inner_mat
	flame_in.scale = Vector3(0.58, 0.72, 0.58)
	flame_in.position = Vector3(0.0, 0.18, 0.0)
	hearth_fire.add_child(flame_in)

	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.58, 0.20)
	fire_light.light_energy = 1.8
	fire_light.omni_range = 6.5
	fire_light.position = Vector3(-0.35, 0.95, 2.05)
	tent_root.add_child(fire_light)

	# 2. Herbal Healing Linen Canopy at (0.9, y, -0.2) with Pitched Roof & Herb Table
	var hx: float = 0.9
	var hz: float = -0.2
	var hy: float = get_terrain_height(hx, hz)
	var heal_root := Node3D.new()
	heal_root.position = Vector3(hx, hy, hz)
	root.add_child(heal_root)

	var linen_mat := StandardMaterial3D.new()
	linen_mat.albedo_texture = load("res://assets/textures/linen_canopy_albedo.png")
	linen_mat.albedo_color = Color(0.84, 0.79, 0.67)
	linen_mat.roughness = 0.93
	var olive_cloth := StandardMaterial3D.new()
	olive_cloth.albedo_color = Color(0.30, 0.39, 0.20)
	olive_cloth.roughness = 0.92

	for p in [Vector2(-1.15, -0.9), Vector2(1.15, -0.9), Vector2(-1.15, 0.9), Vector2(1.15, 0.9)]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.07
		cyl.height = 1.72
		post.mesh = cyl
		post.material_override = wood_mat
		post.position = Vector3(p.x, 0.86, p.y)
		heal_root.add_child(post)

	var heal_roof := MeshInstance3D.new()
	heal_roof.mesh = _make_draped_roof_mesh(2.70, 2.25, 2.02, 1.56)
	heal_roof.material_override = linen_mat
	heal_root.add_child(heal_roof)

	# Hanging olive side drapes + drying herb bundles + wooden herbalist table + woven basket
	for sx in [-1.14, 1.14]:
		var sd := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.07, 1.35, 1.72)
		sd.mesh = sb
		sd.material_override = olive_cloth
		sd.position = Vector3(sx, 1.0, 0.0)
		heal_root.add_child(sd)

	for hx_b in [-0.55, -0.22, 0.12]:
		var herb := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.03
		hc.bottom_radius = 0.09
		hc.height = 0.34
		herb.mesh = hc
		herb.material_override = olive_cloth
		herb.position = Vector3(hx_b, 1.38, 0.88)
		heal_root.add_child(herb)

	var table := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(1.25, 0.56, 0.58)
	table.mesh = tb
	table.material_override = wood_mat
	table.position = Vector3(0.15, 0.28, 0.32)
	heal_root.add_child(table)

	var basket := MeshInstance3D.new()
	var bkc := CylinderMesh.new()
	bkc.top_radius = 0.24
	bkc.bottom_radius = 0.18
	bkc.height = 0.34
	basket.mesh = bkc
	basket.material_override = linen_mat
	basket.position = Vector3(-0.62, 0.17, 0.52)
	heal_root.add_child(basket)

	# 3. Altar Fire & Rising White Smoke on North-Central Rocky Rise (1.0, -4.9)
	var ay: float = get_terrain_height(1.0, -4.9)
	var altar_fire := Node3D.new()
	altar_fire.position = Vector3(1.0, ay + 0.34, -4.9)
	altar_fire.scale = Vector3(1.4, 1.4, 1.4)
	root.add_child(altar_fire)
	flame_nodes.append(altar_fire)

	var aflame_out := MeshInstance3D.new()
	aflame_out.mesh = fcone
	aflame_out.material_override = fire_outer_mat
	aflame_out.position = Vector3(0.0, 0.24, 0.0)
	altar_fire.add_child(aflame_out)

	var aflame_in := MeshInstance3D.new()
	aflame_in.mesh = fcone
	aflame_in.material_override = fire_inner_mat
	aflame_in.scale = Vector3(0.55, 0.72, 0.55)
	aflame_in.position = Vector3(0.0, 0.18, 0.0)
	altar_fire.add_child(aflame_in)

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.95, 0.92, 0.86, 0.34)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.roughness = 1.0
	for k in range(3):
		var sm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.26 + float(k) * 0.14
		sp.height = sp.radius * 1.4
		sm.mesh = sp
		sm.material_override = smoke_mat
		sm.position = Vector3(1.0 + float(k) * 0.12, ay + 1.25 + float(k) * 0.48, -4.9 - float(k) * 0.08)
		root.add_child(sm)
		smoke_nodes.append(sm)


func _build_spring_waterfall() -> void:
	var sx: float = -7.8
	var sz: float = -1.2
	var sy: float = get_terrain_height(sx, sz) + 0.24
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/spring_water.gdshader")

	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.05
	disc.bottom_radius = 2.05
	disc.height = 0.06
	water.mesh = disc
	water.material_override = wmat
	water.position = Vector3(sx, sy, sz)
	add_child(water)

	# Tapered cascading spring stream + foam stones feeding the teal pool
	var fall := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 0.14
	fc.bottom_radius = 0.34
	fc.height = 0.92
	fall.mesh = fc
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.78, 0.91, 0.92, 0.78)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.roughness = 0.22
	fall.material_override = fmat
	fall.position = Vector3(sx - 0.55, sy + 0.38, sz - 1.35)
	fall.rotation_degrees = Vector3(26.0, 20.0, 0.0)
	add_child(fall)


func _make_human_figure(pos: Vector3, tunic_col: Color, cloak_col: Color, has_beard: bool, has_crook: bool) -> Node3D:
	var fig := Node3D.new()
	fig.position = Vector3(pos.x, get_terrain_height(pos.x, pos.z), pos.z)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.76, 0.56, 0.40)
	skin_mat.roughness = 0.82

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.32, 0.28, 0.24) if has_beard else Color(0.20, 0.14, 0.10)
	hair_mat.roughness = 0.92

	var tunic_mat := StandardMaterial3D.new()
	tunic_mat.albedo_color = tunic_col
	tunic_mat.roughness = 0.90

	var cloak_mat := StandardMaterial3D.new()
	cloak_mat.albedo_color = cloak_col
	cloak_mat.roughness = 0.90

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.18, 0.30, 0.52) # Tekhelet trim
	trim_mat.roughness = 0.85

	# 4.0 head-tall stylized Levantine silhouette (total height ~1.52m)
	var skirt := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.17
	scyl.bottom_radius = 0.25
	scyl.height = 0.88
	skirt.mesh = scyl
	skirt.material_override = tunic_mat
	skirt.position = Vector3(0.0, 0.52, 0.0)
	fig.add_child(skirt)

	var hem := MeshInstance3D.new()
	var hcyl := CylinderMesh.new()
	hcyl.top_radius = 0.245
	hcyl.bottom_radius = 0.258
	hcyl.height = 0.10
	hem.mesh = hcyl
	hem.material_override = trim_mat
	hem.position = Vector3(0.0, 0.14, 0.0)
	fig.add_child(hem)

	var torso := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.20
	tcyl.bottom_radius = 0.17
	tcyl.height = 0.42
	torso.mesh = tcyl
	torso.material_override = tunic_mat
	torso.position = Vector3(0.0, 1.02, 0.0)
	fig.add_child(torso)

	# Shoulder mantle draped diagonally
	var cloak := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.18, 0.65, 0.34)
	cloak.mesh = cbox
	cloak.material_override = cloak_mat
	cloak.position = Vector3(-0.15, 0.94, -0.02)
	cloak.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	fig.add_child(cloak)

	# Head & bareheaded wavy hair (NO turban / NO keffiyeh!)
	var head := MeshInstance3D.new()
	var hsp := SphereMesh.new()
	hsp.radius = 0.155
	hsp.height = 0.33
	head.mesh = hsp
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.38, 0.0)
	fig.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_sp := SphereMesh.new()
	hair_sp.radius = 0.168
	hair_sp.height = 0.28
	hair.mesh = hair_sp
	hair.material_override = hair_mat
	hair.position = Vector3(0.0, 1.43, -0.035)
	fig.add_child(hair)

	if has_beard:
		var beard := MeshInstance3D.new()
		var bsp := SphereMesh.new()
		bsp.radius = 0.115
		bsp.height = 0.19
		beard.mesh = bsp
		beard.material_override = hair_mat
		beard.position = Vector3(0.0, 1.28, 0.08)
		fig.add_child(beard)

	# Leather waist belt
	var belt := MeshInstance3D.new()
	var belt_c := CylinderMesh.new()
	belt_c.top_radius = 0.195
	belt_c.bottom_radius = 0.195
	belt_c.height = 0.08
	belt.mesh = belt_c
	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.36, 0.21, 0.11)
	leather_mat.roughness = 0.85
	belt.material_override = leather_mat
	belt.position = Vector3(0.0, 0.88, 0.0)
	fig.add_child(belt)

	# Left & Right Sculpted Arms (tunic sleeve + forearm)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.068
		ac.bottom_radius = 0.052
		ac.height = 0.44
		arm.mesh = ac
		arm.material_override = tunic_mat
		arm.position = Vector3(side * 0.24, 0.96, 0.05 if (has_crook and side > 0) else 0.0)
		arm.rotation_degrees = Vector3(-28.0 if (has_crook and side > 0) else -10.0, 0.0, side * -14.0)
		fig.add_child(arm)

		var hand := MeshInstance3D.new()
		var hsph := SphereMesh.new()
		hsph.radius = 0.055
		hsph.height = 0.11
		hand.mesh = hsph
		hand.material_override = skin_mat
		hand.position = Vector3(side * 0.28, 0.78, 0.16 if (has_crook and side > 0) else 0.05)
		fig.add_child(hand)

	if has_crook:
		var staff := MeshInstance3D.new()
		var stc := CylinderMesh.new()
		stc.top_radius = 0.024
		stc.bottom_radius = 0.024
		stc.height = 1.48
		staff.mesh = stc
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.42, 0.25, 0.12)
		staff.material_override = smat
		staff.position = Vector3(0.31, 0.74, 0.16)
		fig.add_child(staff)

		var crook_top := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.065
		torus.outer_radius = 0.11
		crook_top.mesh = torus
		crook_top.material_override = smat
		crook_top.position = Vector3(0.31, 1.50, 0.24)
		crook_top.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		fig.add_child(crook_top)

	return fig


func _build_characters() -> void:
	# 1. Patriarch Abram (4.0 head-tall, bareheaded wavy hair, linen tunic + blue-gray mantle)
	abram_actor = _make_human_figure(
		Vector3(-1.85, 0.0, 1.25),
		Color(0.88, 0.82, 0.69),
		Color(0.28, 0.36, 0.50),
		true,
		true
	)
	abram_actor.name = "AbramStylized"
	abram_actor.rotation_degrees = Vector3(0.0, 65.0, 0.0)
	add_child(abram_actor)

	# 2. Sarai conversing with Abram in courtyard
	var sarai := _make_human_figure(
		Vector3(-0.75, 0.0, 1.30),
		Color(0.86, 0.78, 0.64),
		Color(0.68, 0.42, 0.28),
		false,
		false
	)
	sarai.name = "SaraiStylized"
	sarai.scale = Vector3(0.94, 0.94, 0.94)
	sarai.rotation_degrees = Vector3(0.0, -75.0, 0.0)
	add_child(sarai)

	# 3. Herbalist tending balm table inside Healing Canopy
	var healer := _make_human_figure(
		Vector3(1.15, 0.0, -0.35),
		Color(0.82, 0.77, 0.64),
		Color(0.36, 0.44, 0.24),
		false,
		false
	)
	healer.scale = Vector3(0.92, 0.92, 0.92)
	add_child(healer)


func _build_sheep_flocks() -> void:
	# Batched GPU-instanced grazing flocks (2 Draw Calls total for all 9 sheep!)
	var wool_mat := StandardMaterial3D.new()
	wool_mat.albedo_color = Color(0.88, 0.84, 0.74)
	wool_mat.roughness = 0.95
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.24, 0.20, 0.16)
	dark_mat.roughness = 0.92

	var spots: Array[Vector2] = [
		Vector2(-0.4, 5.2), Vector2(0.5, 4.9), Vector2(1.2, 5.4), Vector2(0.2, 5.8),
		Vector2(4.6, 4.6), Vector2(5.4, 4.3), Vector2(6.0, 5.0), Vector2(5.2, 5.5), Vector2(6.5, 4.5),
	]
	var body_mm := MultiMesh.new()
	body_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := SphereMesh.new()
	bm.radius = 0.28
	bm.height = 0.46
	bm.radial_segments = 10
	bm.rings = 6
	body_mm.mesh = bm
	body_mm.instance_count = spots.size()

	var head_mm := MultiMesh.new()
	head_mm.transform_format = MultiMesh.TRANSFORM_3D
	var hm := SphereMesh.new()
	hm.radius = 0.11
	hm.height = 0.22
	head_mm.mesh = hm
	head_mm.instance_count = spots.size()

	var leg_mm := MultiMesh.new()
	leg_mm.transform_format = MultiMesh.TRANSFORM_3D
	var lm := CylinderMesh.new()
	lm.top_radius = 0.032
	lm.bottom_radius = 0.026
	lm.height = 0.26
	lm.radial_segments = 6
	leg_mm.mesh = lm
	leg_mm.instance_count = spots.size() * 4

	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var leg_offsets: Array[Vector3] = [
		Vector3(-0.11, 0.13, 0.16),
		Vector3(0.11, 0.13, 0.16),
		Vector3(-0.11, 0.13, -0.16),
		Vector3(0.11, 0.13, -0.16),
	]
	for i in range(spots.size()):
		var s: Vector2 = spots[i]
		var sy: float = get_terrain_height(s.x, s.y)
		var yaw: float = rng.randf_range(0.0, TAU)
		var rot := Basis().rotated(Vector3.UP, yaw)
		body_mm.set_instance_transform(i, Transform3D(rot.scaled(Vector3(1.0, 0.85, 1.35)), Vector3(s.x, sy + 0.34, s.y)))
		var h_off: Vector3 = rot * Vector3(0.0, 0.27, 0.36)
		head_mm.set_instance_transform(i, Transform3D(rot, Vector3(s.x + h_off.x, sy + h_off.y, s.y + h_off.z)))
		for j in range(4):
			var lo: Vector3 = rot * leg_offsets[j]
			leg_mm.set_instance_transform(i * 4 + j, Transform3D(rot, Vector3(s.x + lo.x, sy + lo.y, s.y + lo.z)))

	var b_node := MultiMeshInstance3D.new()
	b_node.multimesh = body_mm
	b_node.material_override = wool_mat
	add_child(b_node)

	var h_node := MultiMeshInstance3D.new()
	h_node.multimesh = head_mm
	h_node.material_override = dark_mat
	add_child(h_node)

	var l_node := MultiMeshInstance3D.new()
	l_node.multimesh = leg_mm
	l_node.material_override = dark_mat
	add_child(l_node)


func _build_olive_groves() -> void:
	# Batched GPU-instanced olive groves (3 Draw Calls total for all 6 trees & 36 foliage clusters!)
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.32, 0.21, 0.13)
	bark_mat.roughness = 0.95

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_texture = load("res://assets/textures/terrain_grass_albedo.png")
	leaf_mat.normal_enabled = true
	leaf_mat.normal_texture = load("res://assets/textures/terrain_grass_normal.png")
	leaf_mat.albedo_color = Color(0.60, 0.66, 0.46)
	leaf_mat.roughness = 0.94

	var leaf_mat_hi := StandardMaterial3D.new()
	leaf_mat_hi.albedo_texture = load("res://assets/textures/terrain_grass_albedo.png")
	leaf_mat_hi.normal_enabled = true
	leaf_mat_hi.normal_texture = load("res://assets/textures/terrain_grass_normal.png")
	leaf_mat_hi.albedo_color = Color(0.76, 0.80, 0.56)
	leaf_mat_hi.roughness = 0.92

	var tree_spots: Array[Vector3] = [
		Vector3(-7.6, 0.0, -4.6),
		Vector3(-4.2, 0.0, -4.2),
		Vector3(-8.8, 0.0, 4.6),
		Vector3(5.6, 0.0, -4.4),
		Vector3(8.2, 0.0, -2.8),
		Vector3(4.2, 0.0, -6.8),
	]
	var offsets: Array[Vector3] = [
		Vector3(0.0, 1.75, 0.0),
		Vector3(-0.68, 1.54, 0.28),
		Vector3(0.68, 1.56, -0.24),
		Vector3(0.20, 1.60, 0.58),
		Vector3(-0.30, 1.52, -0.56),
		Vector3(0.32, 1.94, 0.12),
	]

	var trunk_tfs: Array[Transform3D] = []
	var leaf_dark_tfs: Array[Transform3D] = []
	var leaf_hi_tfs: Array[Transform3D] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 407
	for spot in tree_spots:
		var ty: float = get_terrain_height(spot.x, spot.z)
		var sf: float = rng.randf_range(0.90, 1.22)
		var tb := Basis().rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6.0, 6.0))).rotated(Vector3.FORWARD, deg_to_rad(rng.randf_range(-8.0, 8.0))).scaled(Vector3(sf, sf, sf))
		trunk_tfs.append(Transform3D(tb, Vector3(spot.x, ty + 0.74 * sf, spot.z)))

		for j in range(offsets.size()):
			var off: Vector3 = offsets[j] * sf
			var rad: float = rng.randf_range(0.55, 0.78) * sf
			var lb := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rad, rad * 0.65, rad))
			var tf := Transform3D(lb, Vector3(spot.x + off.x, ty + off.y, spot.z + off.z))
			if j % 2 == 0:
				leaf_hi_tfs.append(tf)
			else:
				leaf_dark_tfs.append(tf)

	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.14
	tcyl.bottom_radius = 0.24
	tcyl.height = 1.48
	tcyl.radial_segments = 7
	var t_mm := MultiMesh.new()
	t_mm.transform_format = MultiMesh.TRANSFORM_3D
	t_mm.mesh = tcyl
	t_mm.instance_count = trunk_tfs.size()
	for i in range(trunk_tfs.size()):
		t_mm.set_instance_transform(i, trunk_tfs[i])
	var t_node := MultiMeshInstance3D.new()
	t_node.multimesh = t_mm
	t_node.material_override = bark_mat
	add_child(t_node)

	var lmesh := SphereMesh.new()
	lmesh.radius = 1.0
	lmesh.height = 1.7
	lmesh.radial_segments = 8
	lmesh.rings = 5
	for pair in [[leaf_dark_tfs, leaf_mat], [leaf_hi_tfs, leaf_mat_hi]]:
		var arr: Array[Transform3D] = pair[0]
		var l_mm := MultiMesh.new()
		l_mm.transform_format = MultiMesh.TRANSFORM_3D
		l_mm.mesh = lmesh
		l_mm.instance_count = arr.size()
		for i in range(arr.size()):
			l_mm.set_instance_transform(i, arr[i])
		var l_node := MultiMeshInstance3D.new()
		l_node.multimesh = l_mm
		l_node.material_override = pair[1]
		add_child(l_node)


func _build_set_dressing_multimesh() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	rock_mat.albedo_color = Color(0.84, 0.78, 0.67)
	rock_mat.roughness = 0.94

	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.44
	rock_mesh.height = 0.54
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 5
	rock_mm.mesh = rock_mesh

	var rock_transforms: Array[Transform3D] = []

	# 12-Stone Covenant Altar on north rise (1.0, -4.9)
	for i in range(12):
		var ang: float = float(i) / 12.0 * TAU
		var rx: float = 1.0 + cos(ang) * 1.05
		var rz: float = -4.9 + sin(ang) * 1.05
		var ry: float = get_terrain_height(rx, rz) + 0.18
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.15, 0.95, 1.05))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Tightly stacked organic dry-stone courtyard retaining wall (2 tiers, leaving front step gap at x in [-2.3, -0.4])
	for tier in range(2):
		for i in range(44):
			var ang: float = float(i) / 44.0 * TAU
			var rx: float = -1.75 + cos(ang) * 4.55
			var rz: float = 0.25 + sin(ang) * 2.65
			if rz > 2.2 and rx > -2.35 and rx < -0.35:
				continue # front stone steps opening
			var ry: float = get_terrain_height(rx, rz) + 0.08 + float(tier) * 0.28
			var b := Basis().rotated(Vector3.UP, ang + float(tier) * 0.2).scaled(Vector3(0.95, 0.56, 0.78))
			rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Western spring rim boulders
	for i in range(14):
		var ang: float = float(i) / 14.0 * TAU
		var rx: float = -7.8 + cos(ang) * 2.2
		var rz: float = -1.2 + sin(ang) * 2.0
		var ry: float = get_terrain_height(rx, rz) + 0.22
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.3, 1.05, 1.1))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1318
	for i in range(52):
		var rx: float = rng.randf_range(-14.0, 13.0)
		var rz: float = rng.randf_range(-10.0, 9.0)
		if Vector2(rx + 2.2, rz - 0.2).length() < 5.6:
			continue
		var ry: float = get_terrain_height(rx, rz) + 0.04
		var s: float = rng.randf_range(0.55, 1.45)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s * 0.65, s * 0.9))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	rock_mm.instance_count = rock_transforms.size()
	for i in range(rock_transforms.size()):
		rock_mm.set_instance_transform(i, rock_transforms[i])

	var rock_node := MultiMeshInstance3D.new()
	rock_node.multimesh = rock_mm
	rock_node.material_override = rock_mat
	add_child(rock_node)

	# Olive shrubs & golden wildflower tufts
	var bush_mm := MultiMesh.new()
	bush_mm.transform_format = MultiMesh.TRANSFORM_3D
	bush_mm.use_colors = true
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.32
	bush_mesh.height = 0.44
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	bush_mm.mesh = bush_mesh

	var bush_transforms: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	for i in range(75):
		var bx: float = rng.randf_range(-13.5, 12.5)
		var bz: float = rng.randf_range(-9.5, 9.0)
		if Vector2(bx + 2.2, bz - 0.2).length() < 4.9:
			continue
		var by: float = get_terrain_height(bx, bz) + 0.12
		var s: float = rng.randf_range(0.55, 1.25)
		var b := Basis().scaled(Vector3(s, s * 0.72, s))
		bush_transforms.append(Transform3D(b, Vector3(bx, by, bz)))
		if i % 5 == 0:
			bush_colors.append(Color(0.80, 0.66, 0.18))
		else:
			bush_colors.append(Color(rng.randf_range(0.22, 0.34), rng.randf_range(0.32, 0.42), rng.randf_range(0.14, 0.20)))

	bush_mm.instance_count = bush_transforms.size()
	for i in range(bush_transforms.size()):
		bush_mm.set_instance_transform(i, bush_transforms[i])
		bush_mm.set_instance_color(i, bush_colors[i])

	var bush_mat := StandardMaterial3D.new()
	bush_mat.vertex_color_use_as_albedo = true
	bush_mat.roughness = 0.92
	var bush_node := MultiMeshInstance3D.new()
	bush_node.multimesh = bush_mm
	bush_node.material_override = bush_mat
	add_child(bush_node)


func _build_mobile_hud() -> void:
	var hud: CanvasLayer = $HudLayer
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -280.0
	bar.offset_right = 280.0
	bar.offset_top = -68.0
	bar.offset_bottom = -14.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)

	var actions: Array[Array] = [
		["取水 · 西谷清泉", "water"],
		["筑坛求告 · 创13:4", "pray"],
		["归营 · 主帐", "camp"],
	]
	for act in actions:
		var btn := Button.new()
		btn.text = act[0]
		btn.custom_minimum_size = Vector2(168, 48)
		var action_key: String = act[1]
		btn.pressed.connect(func() -> void: _trigger_action(action_key))
		bar.add_child(btn)

	status_label = Label.new()
	status_label.offset_left = 16.0
	status_label.offset_top = 42.0
	status_label.offset_right = 820.0
	status_label.offset_bottom = 76.0
	status_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	status_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.text = status_note
	hud.add_child(status_label)


func _trigger_action(action_key: String) -> void:
	pending_action = action_key
	if action_key == "water":
		target_pos = Vector3(-5.8, get_terrain_height(-5.8, -0.8), -0.8)
		status_note = "亚伯兰正前往西谷清泉取水..."
	elif action_key == "pray":
		target_pos = Vector3(1.0, get_terrain_height(1.0, -3.5), -3.5)
		status_note = "亚伯兰正登北坡前往十二石立约祭坛求告..."
	else:
		target_pos = Vector3(-1.85, get_terrain_height(-1.85, 1.25), 1.25)
		status_note = "亚伯兰正返回主营大帐..."
	if status_label != null:
		status_label.text = status_note


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_distance = 0.0
			last_pointer_pos = event.position
		else:
			dragging = false
			if drag_distance < 12.0:
				_order_move_from_screen(event.position)
	elif event is InputEventMouseMotion and dragging:
		var delta: Vector2 = event.position - last_pointer_pos
		drag_distance += delta.length()
		last_pointer_pos = event.position
		if drag_distance >= 12.0:
			camera_rig.position.x = clamp(camera_rig.position.x - delta.x * 0.025, -24.0, 24.0)
			camera_rig.position.z = clamp(camera_rig.position.z - delta.y * 0.025, -18.0, 18.0)


func _order_move_from_screen(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		var tx: float = clamp(p.x, -26.0, 26.0)
		var tz: float = clamp(p.z, -18.0, 18.0)
		target_pos = Vector3(tx, get_terrain_height(tx, tz), tz)


func _process(delta: float) -> void:
	anim_time += delta
	for i in range(flame_nodes.size()):
		var fn: Node3D = flame_nodes[i]
		var flick: float = 1.0 + sin(anim_time * 9.5 + float(i) * 2.1) * 0.14
		fn.scale = Vector3(1.0, flick, 1.0) * (1.4 if i == 1 else 1.0)
	for k in range(smoke_nodes.size()):
		var sm: Node3D = smoke_nodes[k]
		sm.position.x = 1.0 + float(k) * 0.12 + sin(anim_time * 1.4 + float(k)) * 0.08

	if abram_actor != null:
		var to_target := target_pos - abram_actor.global_position
		to_target.y = 0.0
		if to_target.length() > 0.12:
			var step: Vector3 = to_target.normalized() * minf(move_speed * delta, to_target.length())
			abram_actor.global_position += step
			abram_actor.global_position.y = get_terrain_height(abram_actor.global_position.x, abram_actor.global_position.z)
			abram_actor.look_at(abram_actor.global_position + to_target.normalized(), Vector3.UP)
		elif pending_action != "":
			if pending_action == "water":
				water_count += 5
				status_note = "已从西谷清泉取水 +5（当前饮水：%d）" % water_count
			elif pending_action == "pray":
				harmony_score = mini(100, harmony_score + 15)
				status_note = "【创 13:4】亚伯兰在坛前求告耶和华的名，全营和睦升至 %d%%" % harmony_score
			else:
				status_note = "亚伯兰已回到主营大帐"
			pending_action = ""
			if status_label != null:
				status_label.text = status_note

	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	metrics_label.text = "饮水: %d  |  和睦: %d%%  |  Draw Calls: %d  |  内存: %.1f MB" % [water_count, harmony_score, int(draw_calls), mem_mb]
