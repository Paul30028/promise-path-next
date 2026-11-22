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
var target_cam_pos: Vector3 = Vector3(2.0, 2.0, 2.0)


func _ready() -> void:
	_load_region_json()
	_build_128x96_terrain()
	_build_jordan_valley_backdrop()
	_build_shared_roads()
	_build_seven_region_chunks()
	_build_greybox_hud()
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
				h += elev * smooth
	# Drop off east of x = 56 toward the lush Jordan River Valley
	if x > 54.0:
		var drop: float = clampf((x - 54.0) / 10.0, 0.0, 1.0)
		h = lerpf(h, -2.4, drop * drop * (3.0 - 2.0 * drop))
	h += sin(x * 0.09) * cos(z * 0.11) * 0.25
	return h


func _build_128x96_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 80
	var nz: int = 60
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


func _build_shared_roads() -> void:
	# Shared polyline road ribbons (same polylines will drive pathfinding & speed boost!)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.74, 0.60, 0.40)
	rmat.roughness = 0.96
	for poly in roads:
		for i in range(poly.size() - 1):
			var a := Vector2(float(poly[i][0]), float(poly[i][1]))
			var b := Vector2(float(poly[i + 1][0]), float(poly[i + 1][1]))
			var seg_len: float = a.distance_to(b)
			var steps: int = maxi(2, int(ceil(seg_len / 3.5)))
			for s in range(steps):
				var t0: float = float(s) / float(steps)
				var t1: float = float(s + 1) / float(steps)
				var p0: Vector2 = a.lerp(b, t0)
				var p1: Vector2 = a.lerp(b, t1)
				var mid: Vector2 = (p0 + p1) * 0.5
				var strip := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.85, 0.10, p0.distance_to(p1) + 0.35)
				strip.mesh = bm
				strip.material_override = rmat
				strip.position = Vector3(mid.x, get_height(mid.x, mid.y) + 0.06, mid.y)
				strip.rotation.y = atan2(p1.x - p0.x, p1.y - p0.y)
				add_child(strip)


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
		chunk.add_child(ring)

		# Distinct greybox landmark silhouettes per zone
		var lm: String = str(reg["landmark"])
		match lm:
			"citadel_west":
				_add_box(chunk, Vector3(0, 1.4, 0), Vector3(8.5, 2.8, 7.5), Color(0.80, 0.74, 0.62))
				_add_box(chunk, Vector3(-3.8, 2.2, -3.2), Vector3(2.2, 4.4, 2.2), Color(0.74, 0.68, 0.56))
				_add_box(chunk, Vector3(3.8, 2.0, 3.0), Vector3(2.0, 4.0, 2.0), Color(0.74, 0.68, 0.56))
			"spring_well":
				_add_cyl(chunk, Vector3(0, 0.08, 0), 4.6, 0.16, Color(0.16, 0.54, 0.58))
				_add_cyl(chunk, Vector3(3.6, 0.65, 2.2), 1.1, 1.3, Color(0.68, 0.62, 0.52))
				_add_box(chunk, Vector3(-4.2, 1.6, -2.5), Vector3(3.6, 3.2, 4.8), Color(0.72, 0.66, 0.55), 18.0)
			"main_camp_altar":
				# Main Tent + Healing Canopy + Dry-stone perimeter + North Low 12-Stone Altar!
				_add_box(chunk, Vector3(-2.2, 1.3, 0.8), Vector3(5.0, 2.4, 3.4), Color(0.28, 0.18, 0.10))
				_add_box(chunk, Vector3(2.4, 1.1, 0.8), Vector3(3.2, 2.0, 2.6), Color(0.84, 0.80, 0.68))
				# Low unhewn 12-stone altar north of camp (z = -9.5)
				for k in range(12):
					var a: float = float(k) / 12.0 * TAU
					_add_cyl(chunk, Vector3(cos(a) * 1.8, 0.45, -9.5 + sin(a) * 1.8), 0.42, 0.75, Color(0.76, 0.71, 0.60))
				_add_cyl(chunk, Vector3(0.0, 0.9, -9.5), 0.55, 1.5, Color(1.0, 0.58, 0.16))
			"ai_pass_caravan":
				_add_box(chunk, Vector3(2.5, 1.5, -2.5), Vector3(6.8, 3.0, 4.8), Color(0.78, 0.70, 0.56), -14.0)
				_add_box(chunk, Vector3(-2.8, 2.6, 2.4), Vector3(1.6, 5.2, 1.6), Color(0.48, 0.34, 0.20)) # Watchtower
				_add_cyl(chunk, Vector3(-4.8, 0.9, 1.6), 0.9, 1.8, Color(0.70, 0.65, 0.54)) # Boundary cairn
			"wolf_den":
				_add_box(chunk, Vector3(0, 1.8, -1.8), Vector3(7.2, 3.6, 4.5), Color(0.46, 0.40, 0.36), 12.0)
				_add_box(chunk, Vector3(0, 1.0, 0.6), Vector3(2.8, 2.0, 1.2), Color(0.10, 0.08, 0.08))
			"lot_camp":
				_add_box(chunk, Vector3(-2.0, 1.1, 0.0), Vector3(4.0, 2.1, 3.0), Color(0.70, 0.48, 0.24), 15.0)
				_add_box(chunk, Vector3(2.8, 1.0, 1.8), Vector3(3.4, 1.9, 2.6), Color(0.66, 0.44, 0.22), -12.0)
				for s in range(6):
					var sa: float = float(s) / 6.0 * TAU
					_add_cyl(chunk, Vector3(cos(sa) * 5.2, 0.45, sin(sa) * 4.2), 0.55, 0.75, Color(0.94, 0.92, 0.86))
			"jordan_overlook":
				_add_box(chunk, Vector3(-1.0, 1.2, 0.0), Vector3(5.8, 2.4, 6.4), Color(0.84, 0.78, 0.62))
				_add_cyl(chunk, Vector3(1.6, 1.4, 0.0), 0.75, 2.8, Color(0.96, 0.80, 0.32)) # Covenant overlook beacon

		# Floating 3D Region Label
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [str(reg["nameZh"]), str(reg["canonRef"])]
		lbl.font_size = 56
		lbl.pixel_size = 0.036
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(0.99, 0.95, 0.84)
		lbl.outline_modulate = Color(0.10, 0.07, 0.04)
		lbl.outline_size = 14
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
			target_cam_pos = Vector3(float(rc[0]), 2.0, float(rc[1]))
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
	var near_count: int = 0
	var cam_xz := Vector2(camera_rig.position.x, camera_rig.position.z)
	for reg in regions:
		var rid: String = str(reg["id"])
		var c: Array = reg["center"]
		var d: float = cam_xz.distance_to(Vector2(float(c[0]), float(c[1])))
		if d <= stream_radius:
			near_count += 1
	var camp_c := Vector2(-6.0, 2.0)
	var sel_name := "中央高脊"
	var eta_sec := 0.0
	for reg in regions:
		if str(reg["id"]) == selected_region_id:
			sel_name = str(reg["nameZh"])
			var rc: Array = reg["center"]
			eta_sec = camp_c.distance_to(Vector2(float(rc[0]), float(rc[1]))) / maxf(walk_speed, 0.1)
			break
	if hud_label != null:
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		hud_label.text = "第一章 128×96 七区灰盒 | 近区模拟块: %d/7 | Draw Calls: %d | 当前聚焦: %s (主营步行约 %.1fs)" % [near_count, dc, sel_name, eta_sec]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		last_mouse = event.position
	elif event is InputEventMouseMotion and dragging:
		var d: Vector2 = event.position - last_mouse
		last_mouse = event.position
		target_cam_pos.x = clampf(target_cam_pos.x - d.x * 0.09, -56.0, 56.0)
		target_cam_pos.z = clampf(target_cam_pos.z - d.y * 0.09, -40.0, 40.0)


func _process(delta: float) -> void:
	camera_rig.position = camera_rig.position.lerp(target_cam_pos, clampf(delta * 6.0, 0.0, 1.0))
	_update_chunk_streaming()
