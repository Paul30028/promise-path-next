extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud_layer: CanvasLayer = $HudLayer

var region_data: Dictionary = {}
var regions: Array = []
var roads: Array = []
var chunk_nodes: Dictionary = {}
var walk_speed: float = 4.8
var stream_radius: float = 44.0
var selected_region_id: String = "reg_camp_altar_ridge"
var hud_label: Label = null
var dragging: bool = false
var last_mouse: Vector2 = Vector2.ZERO
var press_mouse: Vector2 = Vector2.ZERO
var abram: CharacterBody3D
var route: Array[Vector3] = []
var graph_points: Array[Vector2] = []
var graph := AStar2D.new()
var walk_elapsed: float = 0.0
var walking: bool = false
var near_chunks: int = 0
var test_mode: bool = false
var test_destinations: Array[int] = []
var test_steps: int = 0
var test_air_frames: int = 0
var test_max_air: int = 0
var test_peak_dc: int = 0
var target_cam_pos: Vector3 = Vector3(2.0, 2.0, 2.0)


func _ready() -> void:
	_load_region_json()
	_build_128x96_terrain()
	_build_jordan_valley_backdrop()
	_build_shared_roads()
	_build_seven_region_chunks()
	_build_abram()
	_build_greybox_hud()
	test_mode = "--walk-test" in OS.get_cmdline_user_args()
	if test_mode:
		for i in range(graph_points.size()):
			test_destinations.append(i)
	_update_chunk_streaming()


func _load_region_json() -> void:
	var txt: String = FileAccess.get_file_as_string("res://data/ch01_regions.json")
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		region_data = parsed
		regions = parsed.get("regions", [])
		roads = parsed.get("roads", [])
		walk_speed = float(parsed.get("abramWalkSpeed", 4.8))
		stream_radius = float(parsed.get("chunkStreamRadius", 44.0))


func get_height(x: float, z: float) -> float:
	var h: float = 0.0
	var depression: float = 0.0
	for reg in regions:
		var c: Array = reg["center"]
		var cx: float = float(c[0])
		var cz: float = float(c[1])
		var r: float = float(reg["radius"]) * 1.45
		var elev: float = float(reg["elevation"])
		var d: float = Vector2(x - cx, z - cz).length()
		if d < r:
			var t: float = clampf((r - d) / (r * 0.55), 0.0, 1.0)
			var smooth: float = t * t * (3.0 - 2.0 * t)
			if elev >= 0.0:
				h = maxf(h, elev * smooth)
			else:
				depression += elev * smooth
	h += depression
	# Drop off east of x = 56 toward the lush Jordan River Valley
	if x > 54.0:
		var drop: float = clampf((x - 54.0) / 10.0, 0.0, 1.0)
		h = lerpf(h, -2.4, drop * drop * (3.0 - 2.0 * drop))
	# Flat central terrace with a readable, smooth 8m shoulder.
	var ridge_d := Vector2(x + 6.0, z - 2.0).length()
	if ridge_d < 22.0:
		h = lerpf(h, 2.8, 1.0 - smoothstep(14.0, 22.0, ridge_d))
	return h


func _build_128x96_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 128
	var nz: int = 96
	var w: float = 128.0
	var d: float = 96.0
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	verts.resize((nx + 1) * (nz + 1))
	cols.resize((nx + 1) * (nz + 1))

	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var u: float = float(ix) / float(nx)
			var v: float = float(iz) / float(nz)
			var x: float = (u - 0.5) * w
			var z: float = (v - 0.5) * d
			var y: float = get_height(x, z)
			var idx: int = iz * (nx + 1) + ix
			verts[idx] = Vector3(x, y, z)

			# Elevation + biome color coding (olive grass, ochre highlands, limestone crest, lush Jordan valley)
			var col := Color(0.46, 0.52, 0.28)
			if x > 55.0:
				col = Color(0.28, 0.50, 0.24) # Emerald Jordan Valley
			elif y > 2.3:
				col = Color(0.76, 0.70, 0.56) # Pale Judean limestone ridge
			elif y > 1.2:
				col = Color(0.64, 0.56, 0.38) # Ochre highland terrace
			elif y < -0.35:
				col = Color(0.32, 0.46, 0.34) # Spring gorge green
			cols[idx] = col

	for iz in range(nz):
		for ix in range(nx):
			var i0: int = iz * (nx + 1) + ix
			var i1: int = i0 + 1
			var i2: int = i0 + (nx + 1)
			var i3: int = i2 + 1
			for tri in [[i0, i1, i2], [i1, i3, i2]]:
				for vi in tri:
					st.set_color(cols[vi])
					st.add_vertex(verts[vi])
	st.generate_normals()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Terrain128x96"
	mesh_inst.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_add_collision(mesh_inst)


func _build_jordan_valley_backdrop() -> void:
	# Distant shimmering Jordan River ribbon east of the overlook cliff (x = +60)
	var river := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.5, 96.0)
	river.mesh = pm
	river.position = Vector3(60.5, -2.15, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.14, 0.44, 0.52)
	rmat.roughness = 0.22
	river.material_override = rmat
	add_child(river)


# Interpolate the same 1m triangles used by terrain rendering and physics.
func _ground(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var u := x - ix
	var v := z - iz
	var a := get_height(ix, iz)
	var b := get_height(ix + 1.0, iz)
	var c := get_height(ix, iz + 1.0)
	var d := get_height(ix + 1.0, iz + 1.0)
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


func _add_collision(instance: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(instance.mesh.get_faces())
	shape.shape = concave
	body.add_child(shape)
	instance.add_child(body)


func _road_id(p: Vector2) -> int:
	var id := graph_points.find(p)
	if id < 0:
		id = graph_points.size()
		graph_points.append(p)
		graph.add_point(id, p)
	return id


func _build_shared_roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in roads:
		for i in range(poly.size() - 1):
			var a := Vector2(float(poly[i][0]), float(poly[i][1]))
			var b := Vector2(float(poly[i + 1][0]), float(poly[i + 1][1]))
			graph.connect_points(_road_id(a), _road_id(b))
			var side := Vector2(-(b - a).y, (b - a).x).normalized() * 0.925
			var steps := maxi(2, int(ceil(a.distance_to(b) / 0.25)))
			for s in range(steps):
				var p := a.lerp(b, float(s) / steps)
				var q := a.lerp(b, float(s + 1) / steps)
				# Shared cross sections, no raised boxes or gaps at segment ends.
				for lane in range(8):
					var left := -1.0 + float(lane) / 4.0
					var right := left + 0.25
					for point in [p + side * left, q + side * left, p + side * right, p + side * right, q + side * left, q + side * right]:
						st.add_vertex(Vector3(point.x, _ground(point.x, point.y) + 0.06, point.y))
	# Filled junction fans join every branch into the same surface.
	for center in graph_points:
		for k in range(20):
			var a := center + Vector2.from_angle(float(k) / 20.0 * TAU) * 0.925
			var b := center + Vector2.from_angle(float(k + 1) / 20.0 * TAU) * 0.925
			for p in [center, a, b]:
				st.add_vertex(Vector3(p.x, _ground(p.x, p.y) + 0.061, p.y))

	st.generate_normals()
	var ribbon := MeshInstance3D.new()
	ribbon.name = "SharedRoadNetwork"
	ribbon.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.60, 0.40)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.96
	ribbon.material_override = mat
	add_child(ribbon)


func _add_box(parent: Node3D, pos: Vector3, sz: Vector3, col: Color, rot_y_deg: float = 0.0) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	m.mesh = b
	m.position = pos
	m.rotation_degrees.y = rot_y_deg
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88
	m.material_override = mat
	parent.add_child(m)


func _add_cyl(parent: Node3D, pos: Vector3, rad: float, h: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rad
	c.bottom_radius = rad * 1.08
	c.height = h
	m.mesh = c
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.86
	m.material_override = mat
	parent.add_child(m)


func _build_seven_region_chunks() -> void:
	for reg in regions:
		var rid: String = str(reg["id"])
		var c: Array = reg["center"]
		var cx: float = float(c[0])
		var cz: float = float(c[1])
		var cy: float = get_height(cx, cz)
		var col_arr: Array = reg["color"]
		var col := Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))

		var chunk := Node3D.new()
		chunk.name = "Chunk_" + rid
		chunk.position = Vector3(cx, cy, cz)
		add_child(chunk)
		chunk_nodes[rid] = chunk
		var details := Node3D.new()
		details.name = "NearDetails"
		chunk.add_child(details)

		# Ground zone ring disc
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(reg["radius"]) * 0.55
		cm.bottom_radius = float(reg["radius"]) * 0.58
		cm.height = 0.14
		ring.mesh = cm
		ring.position = Vector3(0.0, 0.05, 0.0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = col.darkened(0.18)
		rmat.roughness = 0.92
		ring.material_override = rmat
		ring.free()

		# Distinct greybox landmark silhouettes per zone
		var lm: String = str(reg["landmark"])
		match lm:
			"citadel_west":
				_add_box(details, Vector3(0, 1.4, 0), Vector3(8.5, 2.8, 7.5), Color(0.80, 0.74, 0.62))
				_add_box(details, Vector3(-3.8, 2.2, -3.2), Vector3(2.2, 4.4, 2.2), Color(0.74, 0.68, 0.56))
				_add_box(details, Vector3(3.8, 2.0, 3.0), Vector3(2.0, 4.0, 2.0), Color(0.74, 0.68, 0.56))
			"spring_well":
				_add_cyl(details, Vector3(0, 0.08, 0), 4.6, 0.16, Color(0.16, 0.54, 0.58))
				_add_cyl(details, Vector3(3.6, 0.65, 2.2), 1.1, 1.3, Color(0.68, 0.62, 0.52))
				_add_box(details, Vector3(-4.2, 1.6, -2.5), Vector3(3.6, 3.2, 4.8), Color(0.72, 0.66, 0.55), 18.0)
			"main_camp_altar":
				# Main Tent + Healing Canopy + Dry-stone perimeter + North Low 12-Stone Altar!
				_add_box(details, Vector3(-2.2, 1.3, 5.0), Vector3(5.0, 2.4, 3.4), Color(0.28, 0.18, 0.10))
				_add_box(details, Vector3(2.4, 1.1, 5.0), Vector3(3.2, 2.0, 2.6), Color(0.84, 0.80, 0.68))
				# Irregular unhewn stone ring, each stone 0.35–0.52m high.
				for k in range(12):
					var angle: float = float(k) / 12.0 * TAU + sin(k * 2.7) * 0.08
					var height: float = 0.35 + float(k % 5) / 4.0 * 0.17
					var radius: float = 1.65 + sin(k * 1.9) * 0.18
					var px: float = cos(angle) * radius
					var pz: float = -9.5 + sin(angle) * radius
					_add_box(details, Vector3(px, _ground(cx + px, cz + pz) - cy + height * 0.5, pz), Vector3(0.55 + float(k % 3) * 0.12, height, 0.48 + float(k % 4) * 0.08), Color(0.76, 0.71, 0.60), k * 37.0)

			"ai_pass_caravan":
				_add_box(details, Vector3(2.5, 1.5, -2.5), Vector3(6.8, 3.0, 4.8), Color(0.78, 0.70, 0.56), -14.0)
				_add_box(details, Vector3(-2.8, 2.6, 2.4), Vector3(1.6, 5.2, 1.6), Color(0.48, 0.34, 0.20)) # Watchtower
				_add_cyl(details, Vector3(-4.8, 0.9, 1.6), 0.9, 1.8, Color(0.70, 0.65, 0.54)) # Boundary cairn
			"wolf_den":
				_add_box(details, Vector3(0, 1.8, -1.8), Vector3(7.2, 3.6, 4.5), Color(0.46, 0.40, 0.36), 12.0)
				_add_box(details, Vector3(0, 1.0, 0.6), Vector3(2.8, 2.0, 1.2), Color(0.10, 0.08, 0.08))
			"lot_camp":
				# Council tent faces the fire; west/east entrances leave a clear through route.
				_add_box(details, Vector3(0, 1.35, 5.6), Vector3(6.4, 2.7, 3.4), Color(0.70, 0.48, 0.24))
				_add_box(details, Vector3(5.4, 0.95, 4.8), Vector3(2.8, 1.9, 2.6), Color(0.66, 0.44, 0.22), -12.0)
				_add_cyl(details, Vector3(0, 0.15, 0), 0.7, 0.3, Color(0.30, 0.23, 0.17))
				_add_cyl(details, Vector3(0, 0.35, 0), 0.28, 0.4, Color(1.0, 0.52, 0.12))
				for s in range(8):
					var sa: float = float(s) / 8.0 * TAU + PI / 8.0
					_add_box(details, Vector3(cos(sa) * 2.8, 0.22, sin(sa) * 2.8), Vector3(1.1, 0.44, 0.55), Color(0.57, 0.43, 0.27), -rad_to_deg(sa))
				# Two conversation groups beside, rather than across, the approach.
				for s in range(4):
					_add_cyl(details, Vector3(-4.3 + float(s % 2) * 1.1, 0.65, 2.2 + float(s / 2) * 1.2), 0.25, 1.3, Color(0.79, 0.74, 0.62))

			"jordan_overlook":
				_add_box(details, Vector3(-1.0, 1.2, 0.0), Vector3(5.8, 2.4, 6.4), Color(0.84, 0.78, 0.62))
				_add_cyl(details, Vector3(1.6, 1.4, 0.0), 0.75, 2.8, Color(0.96, 0.80, 0.32)) # Covenant overlook beacon

		var landmark_mesh: MeshInstance3D = details.get_child(0).duplicate()
		_merge_details(details)
		var far_lod := Node3D.new()
		far_lod.name = "FarSilhouette"
		chunk.add_child(far_lod)
		far_lod.add_child(landmark_mesh)

		# Floating 3D Region Label
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [str(reg["nameZh"]), str(reg["canonRef"])]
		lbl.font_size = 56
		lbl.pixel_size = 0.025
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(0.18, 0.12, 0.06)
		lbl.outline_modulate = Color(0.10, 0.07, 0.04)
		lbl.outline_size = 0
		lbl.position = Vector3(0.0, 6.2, 0.0)
		chunk.add_child(lbl)


func _build_greybox_hud() -> void:
	var top_panel := PanelContainer.new()
	top_panel.offset_left = 14.0
	top_panel.offset_top = 12.0
	top_panel.offset_right = 880.0
	top_panel.offset_bottom = 66.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.08, 0.05, 0.82)
	st.border_color = Color(0.82, 0.65, 0.34, 0.90)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	top_panel.add_theme_stylebox_override("panel", st)
	hud_layer.add_child(top_panel)

	hud_label = Label.new()
	hud_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	top_panel.add_child(hud_label)

	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -560.0
	bar.offset_right = 560.0
	bar.offset_top = -58.0
	bar.offset_bottom = -12.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	hud_layer.add_child(bar)

	for reg in regions:
		var btn := Button.new()
		btn.text = str(reg["nameZh"]).split("·")[0].strip_edges()
		btn.custom_minimum_size = Vector2(118, 44)
		var rid: String = str(reg["id"])
		var rc: Array = reg["center"]
		btn.pressed.connect(func() -> void:
			selected_region_id = rid
			_start_walk(Vector2(float(rc[0]), float(rc[1])))
		)
		bar.add_child(btn)

	var reset_btn := Button.new()
	reset_btn.text = "全景 128×96"
	reset_btn.custom_minimum_size = Vector2(124, 44)
	reset_btn.pressed.connect(func() -> void:
		target_cam_pos = Vector3(2.0, 2.0, 2.0)
	)
	bar.add_child(reset_btn)


func _update_chunk_streaming() -> void:
	near_chunks = 0
	var focus := Vector2(abram.position.x, abram.position.z)
	for reg in regions:
		var rid: String = str(reg["id"])
		var c: Array = reg["center"]
		var is_near := focus.distance_to(Vector2(float(c[0]), float(c[1]))) <= stream_radius
		var chunk: Node3D = chunk_nodes[rid]
		chunk.get_node("NearDetails").visible = is_near
		chunk.get_node("FarSilhouette").visible = not is_near
		if is_near:
			near_chunks += 1
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	test_peak_dc = maxi(test_peak_dc, dc)
	if hud_label != null:
		hud_label.text = "第一章 128×96 | Draw Calls: %d | 近区块数: %d/7 | 亚伯兰步行: %.1fs | %s\n点击地面/区域按钮沿共享道路行走；拖动平移视角" % [dc, near_chunks, walk_elapsed, "行走中" if walking else "已抵达"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed:
			press_mouse = event.position
		if not event.pressed and event.position.distance_to(press_mouse) < 5.0:
			var origin := camera.project_ray_origin(event.position)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 400.0, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				_start_walk(Vector2(hit.position.x, hit.position.z))
		last_mouse = event.position
	elif event is InputEventMouseMotion and dragging:
		var d: Vector2 = event.position - last_mouse
		last_mouse = event.position
		target_cam_pos.x = clampf(target_cam_pos.x - d.x * 0.09, -56.0, 56.0)
		target_cam_pos.z = clampf(target_cam_pos.z - d.y * 0.09, -40.0, 40.0)


func _process(delta: float) -> void:
	camera_rig.position = camera_rig.position.lerp(target_cam_pos, clampf(delta * 6.0, 0.0, 1.0))
	_update_chunk_streaming()


# Bake each chunk's detail props into one vertex-coloured surface.
func _merge_details(details: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in details.get_children():
		if child is MeshInstance3D:
			var col: Color = child.material_override.albedo_color
			for vertex in child.mesh.get_faces():
				st.set_color(col)
				st.add_vertex(child.transform * vertex)
			details.remove_child(child)
			child.queue_free()
	st.generate_normals()
	var merged := MeshInstance3D.new()
	merged.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	merged.material_override = mat
	details.add_child(merged)


func _build_abram() -> void:
	abram = CharacterBody3D.new()
	abram.name = "AbramWalkValidator"
	abram.collision_layer = 2
	abram.collision_mask = 1
	abram.floor_snap_length = 0.6
	abram.floor_max_angle = deg_to_rad(48.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	abram.add_child(shape)
	_add_cyl(abram, Vector3(0, 0.85, 0), 0.3, 1.7, Color(0.22, 0.12, 0.07))
	_add_cyl(abram, Vector3(0, 1.85, 0), 0.22, 0.35, Color(0.96, 0.76, 0.45))
	add_child(abram)
	abram.position = Vector3(-6, _ground(-6, 2) + 0.03, 2)
	var label := Label3D.new()
	label.text = "亚伯兰 · 行走验收"
	label.position.y = 2.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	abram.add_child(label)


func _start_walk(destination: Vector2) -> void:
	var current := Vector2(abram.position.x, abram.position.z)
	# Finish the current edge at its next junction before accepting a new route.
	var start_id := graph.get_closest_point(current)
	if not route.is_empty():
		start_id = graph.get_closest_point(Vector2(route[0].x, route[0].z))
	var end_id := graph.get_closest_point(destination)
	route.clear()
	for p in graph.get_point_path(start_id, end_id):
		route.append(Vector3(p.x, _ground(p.x, p.y), p.y))
	walk_elapsed = 0.0
	walking = true


func _physics_process(delta: float) -> void:
	if abram == null:
		return
	if test_mode and not walking:
		if test_destinations.is_empty():
			print("WALK_TEST: completed destinations=%d max_air_frames=%d peak_draw_calls=%d position=%s" % [graph_points.size(), test_max_air, test_peak_dc, abram.position])
			get_tree().quit(0 if test_max_air < 5 and test_peak_dc < 80 else 1)
			return
		var destination_id: int = test_destinations.pop_front()
		print("WALK_TEST destination=%d remaining=%d" % [destination_id, test_destinations.size()])
		_start_walk(graph_points[destination_id])
	if walking:
		walk_elapsed += delta
		if route.is_empty():
			walking = false
			abram.velocity.x = 0.0
			abram.velocity.z = 0.0
		else:
			var offset := route[0] - abram.position
			offset.y = 0.0
			if offset.length() < 0.12:
				route.pop_front()
			else:
				var speed := minf(walk_speed, offset.length() / delta)
				abram.velocity.x = offset.normalized().x * speed
				abram.velocity.z = offset.normalized().z * speed
	else:
		abram.velocity.x = 0.0
		abram.velocity.z = 0.0
	abram.velocity.y -= 20.0 * delta
	abram.move_and_slide()
	if abram.is_on_floor():
		test_air_frames = 0
	else:
		test_air_frames += 1
		test_max_air = maxi(test_max_air, test_air_frames)
	if test_mode:
		test_steps += 1
		if test_steps > 18000:
			push_error("WALK_TEST stuck or timed out: %s" % abram.position)
			get_tree().quit(1)
