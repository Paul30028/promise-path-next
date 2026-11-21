extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var abram: Node3D = $Abram
@onready var metrics_label: Label = $HudLayer/MetricsLabel

var target_pos: Vector3 = Vector3(-1.5, 0.0, 2.2)
var move_speed: float = 4.2
var dragging: bool = false
var drag_distance: float = 0.0
var last_pointer_pos: Vector2 = Vector2.ZERO


static func get_terrain_height(x: float, z: float) -> float:
	var h: float = 0.0
	# 1. North-Central 12-Stone Altar Rocky Rise around (1.0, -7.2)
	var d_altar := Vector2((x - 1.0) * 0.85, z + 7.2).length()
	if d_altar < 6.2:
		var t: float = clamp((6.2 - d_altar) / 3.0, 0.0, 1.0)
		h = max(h, t * t * (3.0 - 2.0 * t) * 1.55)

	# 2. Central-West Camp Terrace around (-2.2, 0.0)
	var d_camp := Vector2((x + 2.2) * 0.65, (z - 0.2) * 0.85).length()
	if d_camp < 5.6:
		var t2: float = clamp((5.6 - d_camp) / 1.6, 0.0, 1.0)
		h = max(h, t2 * t2 * (3.0 - 2.0 * t2) * 0.45)

	# 3. Western Waterfall Spring Hollow around (-9.2, -0.5)
	var d_spring := Vector2((x + 9.2) * 0.9, (z + 0.5) * 0.85).length()
	if d_spring < 3.4:
		var t3: float = clamp((3.4 - d_spring) / 1.6, 0.0, 1.0)
		h -= t3 * t3 * (3.0 - 2.0 * t3) * 0.55

	h += sin(x * 0.20) * cos(z * 0.22) * 0.14
	return h


func _ready() -> void:
	# Hide old low-poly tent & spring placeholders in favor of PBR camp centerpiece
	for old_name in ["MainTent", "SpringBasin"]:
		var old_n := get_node_or_null(old_name)
		if old_n is Node3D:
			old_n.visible = false

	_build_pbr_terrain()
	_build_patriarch_camp_architecture()
	_build_spring_basin()
	_build_set_dressing_multimesh()
	_snap_scene_props_to_terrain()
	target_pos = abram.global_position


func _build_pbr_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var width: float = 56.0
	var depth: float = 42.0
	var cols: int = 64
	var rows: int = 48
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

			# Splat weights: R = packed dirt path, G = olive meadow grass, B = rocky limestone
			var w_dirt: float = 0.05
			var w_grass: float = 0.90
			var w_rock: float = 0.05

			# Winding dirt trail (camp -> southeast meadow & north to altar)
			var path_dist: float = minf(
				abs(z - (3.8 + (x + 2.0) * 0.25)),
				abs(x - (5.2 + sin(z * 0.28) * 1.2))
			)
			if path_dist < 1.9:
				var pt: float = clamp(1.0 - path_dist / 1.9, 0.0, 1.0)
				w_dirt += pt * 1.4
				w_grass *= (1.0 - pt * 0.85)

			# Camp terrace sandy courtyard
			if Vector2((x + 2.2) * 0.72, (z - 0.2) * 0.9).length() < 4.8:
				w_dirt += 1.6
				w_grass *= 0.15

			# Elevated limestone altar mound & hillside ledges
			if y > 0.62:
				var rt: float = clamp((y - 0.62) / 0.7, 0.0, 1.0)
				w_rock += rt * 1.8
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
	mat.set_shader_parameter("rock_albedo", load("res://assets/textures/terrain_rock_albedo.png"))
	mat.set_shader_parameter("rock_normal", load("res://assets/textures/terrain_rock_normal.png"))
	mat.set_shader_parameter("uv_scale", 0.24)

	var terrain_mesh: MeshInstance3D = $GroundBody/GroundMesh
	terrain_mesh.mesh = mesh
	terrain_mesh.set_surface_override_material(0, mat)


func _build_patriarch_camp_architecture() -> void:
	var root := Node3D.new()
	root.name = "PatriarchCampPBR"
	add_child(root)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.26, 0.14)
	wood_mat.roughness = 0.88

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_texture = load("res://assets/textures/tent_goathair_albedo.png")
	tent_mat.normal_enabled = true
	tent_mat.normal_texture = load("res://assets/textures/tent_goathair_normal.png")
	tent_mat.roughness = 0.92
	tent_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var tap_mat := StandardMaterial3D.new()
	tap_mat.albedo_texture = load("res://assets/textures/tapestry_tekhelet_albedo.png")
	tap_mat.roughness = 0.82
	tap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	rock_mat.roughness = 0.92

	# 1. Main Patriarch Pavilion Tent at (-3.6, y, -0.6)
	var cx: float = -3.6
	var cz: float = -0.6
	var cy: float = get_terrain_height(cx, cz)
	var tent_root := Node3D.new()
	tent_root.position = Vector3(cx, cy, cz)
	root.add_child(tent_root)

	# 6 Cedar Posts
	for p in [Vector2(-1.7, -1.1), Vector2(0.0, -1.1), Vector2(1.7, -1.1), Vector2(-1.7, 1.1), Vector2(0.0, 1.1), Vector2(1.7, 1.1)]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.10
		cyl.height = 1.95
		post.mesh = cyl
		post.material_override = wood_mat
		post.position = Vector3(p.x, 0.95, p.y)
		tent_root.add_child(post)

	# Draped Goat-Hair Roof (Pitched with subtle ridge)
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(4.1, 0.14, 2.9)
	roof.mesh = roof_box
	roof.material_override = tent_mat
	roof.position = Vector3(0.0, 2.02, 0.0)
	roof.rotation_degrees = Vector3(8.0, 0.0, 0.0)
	tent_root.add_child(roof)

	# 2 Tekhelet Blue & Pomegranate Tapestry Banners hanging on front posts
	for bx in [-1.15, 1.15]:
		var banner := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(0.72, 1.05)
		banner.mesh = plane
		banner.material_override = tap_mat
		banner.position = Vector3(bx, 1.22, 1.14)
		tent_root.add_child(banner)

	# Stone Hearth & Warm Campfire in front of Main Tent
	var hearth := MeshInstance3D.new()
	var hcyl := CylinderMesh.new()
	hcyl.top_radius = 0.62
	hcyl.bottom_radius = 0.72
	hcyl.height = 0.24
	hearth.mesh = hcyl
	hearth.material_override = rock_mat
	hearth.position = Vector3(0.0, 0.12, 2.15)
	tent_root.add_child(hearth)

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.12)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.45, 0.08)
	fire_mat.emission_energy_multiplier = 2.4
	var flame := MeshInstance3D.new()
	var fcone := CylinderMesh.new()
	fcone.top_radius = 0.02
	fcone.bottom_radius = 0.24
	fcone.height = 0.55
	flame.mesh = fcone
	flame.material_override = fire_mat
	flame.position = Vector3(0.0, 0.42, 2.15)
	tent_root.add_child(flame)

	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.62, 0.25)
	fire_light.light_energy = 1.6
	fire_light.omni_range = 6.5
	fire_light.position = Vector3(0.0, 0.9, 2.15)
	tent_root.add_child(fire_light)

	# 2. Herbal Healing Linen Canopy right beside Main Tent at (0.8, y, -0.3)
	var hx: float = 0.8
	var hz: float = -0.3
	var hy: float = get_terrain_height(hx, hz)
	var heal_root := Node3D.new()
	heal_root.position = Vector3(hx, hy, hz)
	root.add_child(heal_root)

	var linen_mat := StandardMaterial3D.new()
	linen_mat.albedo_color = Color(0.92, 0.87, 0.76)
	linen_mat.roughness = 0.9
	var olive_cloth := StandardMaterial3D.new()
	olive_cloth.albedo_color = Color(0.36, 0.44, 0.24)
	olive_cloth.roughness = 0.9

	for p in [Vector2(-1.05, -0.85), Vector2(1.05, -0.85), Vector2(-1.05, 0.85), Vector2(1.05, 0.85)]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.07
		cyl.height = 1.65
		post.mesh = cyl
		post.material_override = wood_mat
		post.position = Vector3(p.x, 0.82, p.y)
		heal_root.add_child(post)

	var hroof := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(2.5, 0.12, 2.1)
	hroof.mesh = hbox
	hroof.material_override = linen_mat
	hroof.position = Vector3(0.0, 1.70, 0.0)
	hroof.rotation_degrees = Vector3(6.0, 0.0, 0.0)
	heal_root.add_child(hroof)

	var drape := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(2.3, 0.35, 0.08)
	drape.mesh = dbox
	drape.material_override = olive_cloth
	drape.position = Vector3(0.0, 1.48, 0.86)
	heal_root.add_child(drape)

	# 3. Altar Fire on North Rocky Rise (1.0, y, -7.2)
	var ay: float = get_terrain_height(1.0, -7.2)
	var aflame := MeshInstance3D.new()
	aflame.mesh = fcone
	aflame.material_override = fire_mat
	aflame.position = Vector3(1.0, ay + 0.55, -7.2)
	aflame.scale = Vector3(1.35, 1.35, 1.35)
	root.add_child(aflame)


func _build_spring_basin() -> void:
	var sx: float = -9.2
	var sz: float = -0.5
	var sy: float = get_terrain_height(sx, sz) + 0.28
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.4
	disc.bottom_radius = 2.4
	disc.height = 0.06
	water.mesh = disc
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/spring_water.gdshader")
	water.material_override = wmat
	water.position = Vector3(sx, sy, sz)
	add_child(water)


func _build_set_dressing_multimesh() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	rock_mat.roughness = 0.93

	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.44
	rock_mesh.height = 0.56
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 5
	rock_mm.mesh = rock_mesh

	var rock_transforms: Array[Transform3D] = []

	# 12-Stone Covenant Altar on north rise (1.0, -7.2)
	for i in range(12):
		var ang: float = float(i) / 12.0 * TAU
		var rx: float = 1.0 + cos(ang) * 1.15
		var rz: float = -7.2 + sin(ang) * 1.15
		var ry: float = get_terrain_height(rx, rz) + 0.16
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.2, 0.95, 1.05))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Dry-stone camp terrace retaining ring
	for i in range(28):
		var ang: float = float(i) / 28.0 * TAU
		var rx: float = -2.2 + cos(ang) * 5.2
		var rz: float = 0.2 + sin(ang) * 3.8
		var ry: float = get_terrain_height(rx, rz) + 0.08
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.25, 0.72, 0.9))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Western spring boulders
	for i in range(14):
		var ang: float = float(i) / 14.0 * TAU
		var rx: float = -9.2 + cos(ang) * 2.55
		var rz: float = -0.5 + sin(ang) * 2.35
		var ry: float = get_terrain_height(rx, rz) + 0.22
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.3, 1.05, 1.1))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1318
	for i in range(55):
		var rx: float = rng.randf_range(-16.0, 14.0)
		var rz: float = rng.randf_range(-12.0, 11.0)
		if Vector2(rx + 2.2, rz - 0.2).length() < 5.8:
			continue
		var ry: float = get_terrain_height(rx, rz) + 0.05
		var s: float = rng.randf_range(0.6, 1.65)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s * 0.68, s * 0.92))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	rock_mm.instance_count = rock_transforms.size()
	for i in range(rock_transforms.size()):
		rock_mm.set_instance_transform(i, rock_transforms[i])

	var rock_node := MultiMeshInstance3D.new()
	rock_node.multimesh = rock_mm
	rock_node.material_override = rock_mat
	add_child(rock_node)

	# Olive shrubs & golden wildflower bushes (1 Draw Call!)
	var bush_mm := MultiMesh.new()
	bush_mm.transform_format = MultiMesh.TRANSFORM_3D
	bush_mm.use_colors = true
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.36
	bush_mesh.height = 0.50
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	bush_mm.mesh = bush_mesh

	var bush_transforms: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	for i in range(72):
		var bx: float = rng.randf_range(-15.0, 14.0)
		var bz: float = rng.randf_range(-11.0, 11.0)
		if Vector2(bx + 2.2, bz - 0.2).length() < 5.0:
			continue
		var by: float = get_terrain_height(bx, bz) + 0.14
		var s: float = rng.randf_range(0.55, 1.35)
		var b := Basis().scaled(Vector3(s, s * 0.72, s))
		bush_transforms.append(Transform3D(b, Vector3(bx, by, bz)))
		if i % 5 == 0:
			bush_colors.append(Color(0.78, 0.66, 0.20))
		else:
			bush_colors.append(Color(rng.randf_range(0.24, 0.36), rng.randf_range(0.34, 0.44), rng.randf_range(0.16, 0.22)))

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


func _snap_scene_props_to_terrain() -> void:
	for node_name in ["Abram", "WaterJar", "OliveTree1", "OliveTree2", "Sheep1", "Sheep2"]:
		var n := get_node_or_null(node_name)
		if n is Node3D:
			var p: Vector3 = n.global_position
			p.y = get_terrain_height(p.x, p.z)
			n.global_position = p


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
	var to_target := target_pos - abram.global_position
	to_target.y = 0.0
	if to_target.length() > 0.12:
		var step: Vector3 = to_target.normalized() * minf(move_speed * delta, to_target.length())
		abram.global_position += step
		abram.global_position.y = get_terrain_height(abram.global_position.x, abram.global_position.z)
		abram.look_at(abram.global_position + to_target.normalized(), Vector3.UP)

	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	metrics_label.text = "Godot 4.7 PBR Camp Pilot | Draw Calls: %d | Static Mem: %.1f MB" % [int(draw_calls), mem_mb]
