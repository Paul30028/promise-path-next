extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var metrics_label: Label = $HudLayer/MetricsLabel

var abram_actor: Node3D = null
var target_pos: Vector3 = Vector3(-1.85, 0.0, 1.25)
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
var smoke_nodes: Array[Node3D] = []
var active_glb_slots: int = 0


static func get_terrain_height(x: float, z: float) -> float:
	var h: float = 0.0
	# 1. North-Central 12-Stone Altar Rocky Rise around (1.0, -4.9)
	var d_altar := Vector2((x - 1.0) * 0.78, (z + 4.9) * 0.92).length()
	if d_altar < 4.6:
		var t: float = clamp((4.6 - d_altar) / 2.2, 0.0, 1.0)
		h = max(h, t * t * (3.0 - 2.0 * t) * 1.65)

	# 2. Central-West Camp Courtyard Terrace around (-2.0, 0.2)
	var d_camp := Vector2((x + 2.0) * 0.62, (z - 0.2) * 0.90).length()
	if d_camp < 4.8:
		var t2: float = clamp((4.8 - d_camp) / 1.1, 0.0, 1.0)
		h = max(h, t2 * t2 * (3.0 - 2.0 * t2) * 0.52)

	# 3. Western Waterfall Spring Hollow around (-7.8, -1.2)
	var d_spring := Vector2((x + 7.8) * 0.9, (z + 1.2) * 0.95).length()
	if d_spring < 2.8:
		var t3: float = clamp((2.8 - d_spring) / 1.4, 0.0, 1.0)
		h -= t3 * t3 * (3.0 - 2.0 * t3) * 0.45

	if z < -6.5:
		h += clamp((-6.5 - z) * 0.14, 0.0, 2.2)

	h += sin(x * 0.22) * cos(z * 0.24) * 0.10
	return h


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
			var nz: float = abs(v - 0.5) * 2.0
			var catenary: float = pow(1.0 - nz, 1.35)
			var pole_sag: float = -sin(u * PI * 2.0) * 0.055 * (1.0 - nz * 0.35)
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


static func _make_sculpted_rock_mesh(seed_val: int) -> ArrayMesh:
	# Faceted, weathered Canaanite limestone block (organic chiseled ridges, NOT a smooth sphere!)
	var base := SphereMesh.new()
	base.radius = 0.48
	base.height = 0.62
	base.radial_segments = 8
	base.rings = 4
	var arrays: Array = base.surface_get_arrays(0)
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var displaced: PackedVector3Array = PackedVector3Array()
	displaced.resize(src_v.size())
	var fseed: float = float(seed_val) * 1.37
	for i in range(src_v.size()):
		var v: Vector3 = src_v[i]
		# Deterministic layered rock displacement
		var n1: float = sin(v.x * 5.2 + fseed) * cos(v.z * 4.8 - fseed) * 0.16
		var n2: float = sin((v.x + v.z) * 7.5 + v.y * 4.0) * 0.08
		var scale_r: float = 1.0 + n1 + n2
		var nv := Vector3(v.x * scale_r, v.y * (0.85 + n2 * 0.5), v.z * scale_r)
		# Flatten top slightly like natural sedimentary limestone
		if nv.y > 0.22:
			nv.y = 0.22 + (nv.y - 0.22) * 0.38
		displaced[i] = nv

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, src_idx.size(), 3):
		var a: int = src_idx[i]
		var b: int = src_idx[i + 1]
		var c: int = src_idx[i + 2]
		# Flat-faceted limestone normals per triangle for crisp chiseled sunlight catch
		var va: Vector3 = displaced[a]
		var vb: Vector3 = displaced[b]
		var vc: Vector3 = displaced[c]
		var nrm: Vector3 = (vc - va).cross(vb - va).normalized()
		for vi in [a, b, c]:
			st.set_normal(nrm)
			st.set_uv(src_uv[vi])
			st.add_vertex(displaced[vi])
	st.generate_tangents()
	return st.commit()


static func _make_amphora_mesh() -> ArrayMesh:
	# Lathe-turned Middle Bronze Age Canaanite amphora profile (curved belly, narrow neck, flared rim)
	var profile: Array[Vector2] = [
		Vector2(0.11, 0.00),
		Vector2(0.16, 0.10),
		Vector2(0.28, 0.30),
		Vector2(0.30, 0.48),
		Vector2(0.23, 0.66),
		Vector2(0.12, 0.78),
		Vector2(0.12, 0.90),
		Vector2(0.17, 0.96),
		Vector2(0.14, 1.00),
	]
	var segs: int = 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(profile.size() - 1):
		var p0: Vector2 = profile[r]
		var p1: Vector2 = profile[r + 1]
		var v0: float = float(r) / float(profile.size() - 1)
		var v1: float = float(r + 1) / float(profile.size() - 1)
		for s in range(segs):
			var a0: float = float(s) / float(segs) * TAU
			var a1: float = float(s + 1) / float(segs) * TAU
			var q00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var q10 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var q01 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var q11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var u0: float = float(s) / float(segs)
			var u1: float = float(s + 1) / float(segs)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(q00)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(q01)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(q10)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(q10)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(q01)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(q11)
	st.generate_normals()
	return st.commit()


static func _make_crossed_card_mesh(w: float, h: float, centered_y: bool) -> ArrayMesh:
	# 3-plane crossed foliage/grass/flame star card for rich 3D volume from all camera angles
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float = -h * 0.5 if centered_y else 0.0
	var y1: float = h * 0.5 if centered_y else h
	for i in range(3):
		var ang: float = float(i) * (PI / 3.0)
		var ca: float = cos(ang) * (w * 0.5)
		var sa: float = sin(ang) * (w * 0.5)
		var bl := Vector3(-ca, y0, -sa)
		var br := Vector3(ca, y0, sa)
		var tl := Vector3(-ca, y1, -sa)
		var tr := Vector3(ca, y1, sa)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(bl)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(tr)
	st.generate_normals()
	return st.commit()


func _ready() -> void:
	_build_pbr_terrain()
	_build_courtyard_steps_and_well()
	_build_patriarch_camp_architecture()
	_build_spring_waterfall()
	_build_characters()
	_build_sheep_flocks()
	_build_olive_groves()
	_build_grass_meadow_multimesh()
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

			var trail_front: float = abs(z - (3.8 - (x + 1.0) * 0.22))
			var trail_right: float = abs(x - (4.2 + sin(z * 0.24) * 1.1))
			var trail_dist: float = minf(trail_front, trail_right)
			if trail_dist < 1.55:
				var pt: float = clamp(1.0 - trail_dist / 1.55, 0.0, 1.0)
				w_dirt += pt * 1.5
				w_grass *= (1.0 - pt * 0.88)

			if Vector2((x + 2.0) * 0.65, (z - 0.2) * 0.92).length() < 4.5:
				w_dirt += 1.8
				w_grass *= 0.08

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


func _build_courtyard_steps_and_well() -> void:
	var root := Node3D.new()
	root.name = "CourtyardAndWell"
	add_child(root)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	wall_mat.normal_enabled = true
	wall_mat.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	wall_mat.albedo_color = Color(0.80, 0.74, 0.63)
	wall_mat.roughness = 0.94

	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	step_mat.normal_enabled = true
	step_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	step_mat.albedo_color = Color(0.76, 0.69, 0.56)
	step_mat.roughness = 0.94

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.36, 0.22, 0.12)
	wood_mat.roughness = 0.90

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

	# Circular Stacked-Stone Water Well at front-left (-7.2, 2.2)
	var wx: float = -7.2
	var wz: float = 2.2
	var wy: float = get_terrain_height(wx, wz)
	var well := Node3D.new()
	well.position = Vector3(wx, wy, wz)
	root.add_child(well)

	var well_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_StoneWell.glb", 1.85, 25.0, 0.04, 0.72)
	if well_glb != null:
		active_glb_slots += 1
		well.add_child(well_glb)
	else:
		var well_body := MeshInstance3D.new()
		var wcyl := CylinderMesh.new()
		wcyl.top_radius = 0.78
		wcyl.bottom_radius = 0.86
		wcyl.height = 0.78
		wcyl.radial_segments = 16
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
	wood_mat.albedo_color = Color(0.38, 0.23, 0.12)
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
	rock_mat.albedo_color = Color(0.80, 0.74, 0.62)
	rock_mat.roughness = 0.94

	var clay_mat := StandardMaterial3D.new()
	clay_mat.albedo_color = Color(0.68, 0.34, 0.18)
	clay_mat.roughness = 0.68

	var flame_shader_mat := ShaderMaterial.new()
	flame_shader_mat.shader = load("res://shaders/campfire_flame.gdshader")
	var flame_card_mesh := _make_crossed_card_mesh(0.62, 0.82, false)

	# 1. Main Patriarch Pavilion Tent at (-3.5, y, -0.5)
	var cx: float = -3.5
	var cz: float = -0.5
	var cy: float = get_terrain_height(cx, cz)
	var tent_root := Node3D.new()
	tent_root.position = Vector3(cx, cy, cz)
	root.add_child(tent_root)

	var tent_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_MainTent.glb", 2.75, -18.0, 0.04, 0.78)
	if tent_glb != null:
		active_glb_slots += 1
		tent_root.add_child(tent_glb)
	else:
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

	# 3 Lathe-Turned Bronze Age Canaanite Amphorae by Left Post (or Commercial GLB!)
	var amphora_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/PRP_AmphoraCluster.glb", 0.96, 15.0, 0.02, 0.65)
	if amphora_glb != null:
		active_glb_slots += 1
		amphora_glb.position = Vector3(-1.82, 0.0, 1.56)
		tent_root.add_child(amphora_glb)
	else:
		var amphora_mesh := _make_amphora_mesh()
		for jar in [[Vector3(-2.15, 0.0, 1.35), 0.95], [Vector3(-1.68, 0.0, 1.56), 0.72], [Vector3(-1.35, 0.0, 1.85), 0.52]]:
			var jm := MeshInstance3D.new()
			jm.mesh = amphora_mesh
			jm.material_override = clay_mat
			jm.position = jar[0]
			var js: float = float(jar[1])
			jm.scale = Vector3(js, js, js)
			tent_root.add_child(jm)

	# Stone Hearth + Crossed Logs + Shader Flame
	var hearth := MeshInstance3D.new()
	var hcyl := CylinderMesh.new()
	hcyl.top_radius = 0.65
	hcyl.bottom_radius = 0.74
	hcyl.height = 0.24
	hearth.mesh = hcyl
	hearth.material_override = rock_mat
	hearth.position = Vector3(-0.35, 0.12, 2.05)
	tent_root.add_child(hearth)

	for ang_deg in [25.0, -35.0, 85.0]:
		var log_m := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.05
		lc.bottom_radius = 0.06
		lc.height = 0.72
		log_m.mesh = lc
		log_m.material_override = wood_mat
		log_m.rotation_degrees = Vector3(78.0, ang_deg, 0.0)
		log_m.position = Vector3(-0.35, 0.28, 2.05)
		tent_root.add_child(log_m)

	var hflame := MeshInstance3D.new()
	hflame.mesh = flame_card_mesh
	hflame.material_override = flame_shader_mat
	hflame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hflame.position = Vector3(-0.35, 0.22, 2.05)
	tent_root.add_child(hflame)

	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.58, 0.20)
	fire_light.light_energy = 1.9
	fire_light.omni_range = 6.5
	fire_light.position = Vector3(-0.35, 0.95, 2.05)
	tent_root.add_child(fire_light)

	# 2. Herbal Healing Linen Canopy at (0.9, y, -0.2)
	var hx: float = 0.9
	var hz: float = -0.2
	var hy: float = get_terrain_height(hx, hz)
	var heal_root := Node3D.new()
	heal_root.position = Vector3(hx, hy, hz)
	root.add_child(heal_root)

	var heal_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_HealingCanopy.glb", 2.15, -12.0, 0.04, 0.78)
	if heal_glb != null:
		active_glb_slots += 1
		heal_root.add_child(heal_glb)
	else:
		var linen_mat := StandardMaterial3D.new()
		linen_mat.albedo_texture = load("res://assets/textures/linen_canopy_albedo.png")
		linen_mat.albedo_color = Color(0.84, 0.79, 0.67)
		linen_mat.roughness = 0.93
		linen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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

	# 3. Altar Shader Fire & Drifting Smoke on North-Central Rocky Rise (1.0, -4.9)
	var ay: float = get_terrain_height(1.0, -4.9)
	var aflame := MeshInstance3D.new()
	aflame.mesh = flame_card_mesh
	aflame.material_override = flame_shader_mat
	aflame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aflame.position = Vector3(1.0, ay + 0.30, -4.9)
	aflame.scale = Vector3(1.55, 1.55, 1.55)
	root.add_child(aflame)

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.95, 0.92, 0.86, 0.30)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.roughness = 1.0
	for k in range(3):
		var sm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.28 + float(k) * 0.14
		sp.height = sp.radius * 1.4
		sm.mesh = sp
		sm.material_override = smoke_mat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

	var fall := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 0.14
	fc.bottom_radius = 0.36
	fc.height = 0.92
	fall.mesh = fc
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.76, 0.90, 0.92, 0.78)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.roughness = 0.22
	fall.material_override = fmat
	fall.position = Vector3(sx - 0.55, sy + 0.38, sz - 1.35)
	fall.rotation_degrees = Vector3(26.0, 20.0, 0.0)
	add_child(fall)


func _make_human_figure(pos: Vector3, cloak_col: Color, has_beard: bool, has_crook: bool) -> Node3D:
	var fig := Node3D.new()
	fig.position = Vector3(pos.x, get_terrain_height(pos.x, pos.z), pos.z)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.74, 0.54, 0.38)
	skin_mat.roughness = 0.82

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.32, 0.28, 0.24) if has_beard else Color(0.18, 0.12, 0.09)
	hair_mat.roughness = 0.92

	var tunic_mat := StandardMaterial3D.new()
	tunic_mat.albedo_texture = load("res://assets/textures/linen_tunic_albedo.png")
	tunic_mat.roughness = 0.92

	var cloak_mat := StandardMaterial3D.new()
	cloak_mat.albedo_color = cloak_col
	cloak_mat.roughness = 0.90

	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color(0.36, 0.21, 0.11)
	leather_mat.roughness = 0.85

	# Woven Linen Tunic with Geometric Tekhelet & Pomegranate Hem
	var skirt := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.17
	scyl.bottom_radius = 0.26
	scyl.height = 0.92
	skirt.mesh = scyl
	skirt.material_override = tunic_mat
	skirt.position = Vector3(0.0, 0.54, 0.0)
	fig.add_child(skirt)

	var torso := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.20
	tcyl.bottom_radius = 0.17
	tcyl.height = 0.40
	torso.mesh = tcyl
	torso.material_override = tunic_mat
	torso.position = Vector3(0.0, 1.04, 0.0)
	fig.add_child(torso)

	var cloak := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.18, 0.68, 0.36)
	cloak.mesh = cbox
	cloak.material_override = cloak_mat
	cloak.position = Vector3(-0.15, 0.94, -0.02)
	cloak.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	fig.add_child(cloak)

	var belt := MeshInstance3D.new()
	var belt_c := CylinderMesh.new()
	belt_c.top_radius = 0.195
	belt_c.bottom_radius = 0.195
	belt_c.height = 0.08
	belt.mesh = belt_c
	belt.material_override = leather_mat
	belt.position = Vector3(0.0, 0.88, 0.0)
	fig.add_child(belt)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.068
		ac.bottom_radius = 0.052
		ac.height = 0.44
		arm.mesh = ac
		arm.material_override = tunic_mat
		arm.position = Vector3(side * 0.24, 0.96, 0.06 if (has_crook and side > 0) else 0.0)
		arm.rotation_degrees = Vector3(-30.0 if (has_crook and side > 0) else -10.0, 0.0, side * -14.0)
		fig.add_child(arm)

		var hand := MeshInstance3D.new()
		var hsph := SphereMesh.new()
		hsph.radius = 0.055
		hsph.height = 0.11
		hand.mesh = hsph
		hand.material_override = skin_mat
		hand.position = Vector3(side * 0.28, 0.78, 0.18 if (has_crook and side > 0) else 0.05)
		fig.add_child(hand)

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
	hair_sp.radius = 0.172
	hair_sp.height = 0.28
	hair.mesh = hair_sp
	hair.material_override = hair_mat
	hair.position = Vector3(0.0, 1.43, -0.035)
	fig.add_child(hair)

	if has_beard:
		var beard := MeshInstance3D.new()
		var bsp := SphereMesh.new()
		bsp.radius = 0.118
		bsp.height = 0.19
		beard.mesh = bsp
		beard.material_override = hair_mat
		beard.position = Vector3(0.0, 1.28, 0.08)
		fig.add_child(beard)

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
	var abram_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Abram.glb", 1.65, 0.0, 0.02, 0.72)
	if abram_glb != null:
		active_glb_slots += 1
		abram_actor = Node3D.new()
		abram_actor.name = "AbramCommercialGLB"
		abram_actor.position = Vector3(-1.85, get_terrain_height(-1.85, 1.25), 1.25)
		abram_actor.rotation_degrees = Vector3(0.0, 65.0, 0.0)
		abram_actor.add_child(abram_glb)
		add_child(abram_actor)
	else:
		abram_actor = _make_human_figure(Vector3(-1.85, 0.0, 1.25), Color(0.28, 0.36, 0.50), true, true)
		abram_actor.name = "AbramStylized"
		abram_actor.rotation_degrees = Vector3(0.0, 65.0, 0.0)
		add_child(abram_actor)

	var sarai_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Sarai.glb", 1.54, 0.0, 0.02, 0.72)
	if sarai_glb != null:
		active_glb_slots += 1
		var sarai_n := Node3D.new()
		sarai_n.name = "SaraiCommercialGLB"
		sarai_n.position = Vector3(-0.75, get_terrain_height(-0.75, 1.30), 1.30)
		sarai_n.rotation_degrees = Vector3(0.0, -75.0, 0.0)
		sarai_n.add_child(sarai_glb)
		add_child(sarai_n)
	else:
		var sarai := _make_human_figure(Vector3(-0.75, 0.0, 1.30), Color(0.68, 0.42, 0.28), false, false)
		sarai.name = "SaraiStylized"
		sarai.scale = Vector3(0.94, 0.94, 0.94)
		sarai.rotation_degrees = Vector3(0.0, -75.0, 0.0)
		add_child(sarai)

	var healer := _make_human_figure(Vector3(1.15, 0.0, -0.35), Color(0.34, 0.42, 0.22), false, false)
	healer.scale = Vector3(0.92, 0.92, 0.92)
	add_child(healer)


func _build_sheep_flocks() -> void:
	var spots: Array[Vector2] = [
		Vector2(-0.4, 5.2), Vector2(0.5, 4.9), Vector2(1.2, 5.4), Vector2(0.2, 5.8),
		Vector2(4.6, 4.6), Vector2(5.4, 4.3), Vector2(6.0, 5.0), Vector2(5.2, 5.5), Vector2(6.5, 4.5),
	]
	if FileAccess.file_exists("res://assets/models/CHR_Sheep.glb"):
		var rng_g := RandomNumberGenerator.new()
		rng_g.seed = 909
		var flock_root := Node3D.new()
		flock_root.name = "SheepFlockGLB"
		add_child(flock_root)
		var loaded_any := false
		for s in spots:
			var sf: float = rng_g.randf_range(0.62, 0.76)
			var yaw_deg: float = rng_g.randf_range(0.0, 360.0)
			var sheep_inst: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Sheep.glb", sf, yaw_deg, 0.02, 0.85)
			if sheep_inst != null:
				loaded_any = true
				sheep_inst.position = Vector3(s.x, get_terrain_height(s.x, s.y), s.y)
				flock_root.add_child(sheep_inst)
		if loaded_any:
			active_glb_slots += 1
			return

	var wool_mat := StandardMaterial3D.new()
	wool_mat.albedo_color = Color(0.88, 0.84, 0.74)
	wool_mat.roughness = 0.95
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.24, 0.20, 0.16)
	dark_mat.roughness = 0.92
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
	# Sculpted multi-branch olive trees with alpha-cutout leaf cards (ONLY 2 Draw Calls total!)
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.32, 0.21, 0.13)
	bark_mat.roughness = 0.95

	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = load("res://shaders/foliage_sway.gdshader")
	leaf_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/olive_leaves_alpha.png"))
	leaf_mat.set_shader_parameter("tint_bottom", Color(0.46, 0.52, 0.32))
	leaf_mat.set_shader_parameter("tint_top", Color(0.96, 0.98, 0.82))
	leaf_mat.set_shader_parameter("wind_strength", 0.05)
	leaf_mat.set_shader_parameter("wind_speed", 1.3)

	var tree_spots: Array[Vector3] = [
		Vector3(-7.6, 0.0, -4.6),
		Vector3(-4.2, 0.0, -4.2),
		Vector3(-8.8, 0.0, 4.6),
		Vector3(5.6, 0.0, -4.4),
		Vector3(8.2, 0.0, -2.8),
		Vector3(4.2, 0.0, -6.8),
	]
	var offsets: Array[Vector3] = [
		Vector3(0.0, 1.85, 0.0),
		Vector3(-0.78, 1.58, 0.34),
		Vector3(0.78, 1.62, -0.28),
		Vector3(0.24, 1.64, 0.68),
		Vector3(-0.34, 1.56, -0.66),
		Vector3(0.28, 2.08, 0.12),
		Vector3(-0.42, 1.96, 0.26),
	]

	var trunk_tfs: Array[Transform3D] = []
	var leaf_tfs: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 407

	for spot in tree_spots:
		var ty: float = get_terrain_height(spot.x, spot.z)
		var sf: float = rng.randf_range(0.92, 1.24)
		# Main trunk + 2 forked upper limbs
		var tb := Basis().rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6.0, 6.0))).rotated(Vector3.FORWARD, deg_to_rad(rng.randf_range(-8.0, 8.0))).scaled(Vector3(sf, sf, sf))
		trunk_tfs.append(Transform3D(tb, Vector3(spot.x, ty + 0.72 * sf, spot.z)))
		trunk_tfs.append(Transform3D(Basis().rotated(Vector3.FORWARD, 0.48).scaled(Vector3(sf * 0.58, sf * 0.65, sf * 0.58)), Vector3(spot.x - 0.32 * sf, ty + 1.28 * sf, spot.z + 0.1 * sf)))
		trunk_tfs.append(Transform3D(Basis().rotated(Vector3.FORWARD, -0.45).scaled(Vector3(sf * 0.58, sf * 0.65, sf * 0.58)), Vector3(spot.x + 0.34 * sf, ty + 1.26 * sf, spot.z - 0.1 * sf)))

		for j in range(offsets.size()):
			var off: Vector3 = offsets[j] * sf
			var rad: float = rng.randf_range(1.15, 1.65) * sf
			var lb := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-16.0, 16.0))).scaled(Vector3(rad, rad * 0.72, rad))
			leaf_tfs.append(Transform3D(lb, Vector3(spot.x + off.x, ty + off.y, spot.z + off.z)))

	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.14
	tcyl.bottom_radius = 0.25
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

	var l_mm := MultiMesh.new()
	l_mm.transform_format = MultiMesh.TRANSFORM_3D
	l_mm.mesh = _make_crossed_card_mesh(1.0, 1.0, true)
	l_mm.instance_count = leaf_tfs.size()
	for i in range(leaf_tfs.size()):
		l_mm.set_instance_transform(i, leaf_tfs[i])
	var l_node := MultiMeshInstance3D.new()
	l_node.multimesh = l_mm
	l_node.material_override = leaf_mat
	add_child(l_node)


func _build_grass_meadow_multimesh() -> void:
	# 1,500 GPU-instanced wind-swaying grass & wildflower tufts (1 Draw Call!)
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/foliage_sway.gdshader")
	grass_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/grass_tuft_alpha.png"))
	grass_mat.set_shader_parameter("tint_bottom", Color(0.42, 0.48, 0.22))
	grass_mat.set_shader_parameter("tint_top", Color(0.98, 0.96, 0.72))
	grass_mat.set_shader_parameter("wind_strength", 0.07)
	grass_mat.set_shader_parameter("wind_speed", 2.0)

	var tfs: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for _i in range(1800):
		var gx: float = rng.randf_range(-14.0, 13.0)
		var gz: float = rng.randf_range(-9.5, 9.5)
		# Keep courtyard floor, spring water & main dirt path clear
		if Vector2((gx + 2.0) * 0.65, (gz - 0.2) * 0.92).length() < 4.9:
			continue
		if Vector2(gx + 7.8, gz + 1.2).length() < 2.4:
			continue
		var trail_front: float = abs(gz - (3.8 - (gx + 1.0) * 0.22))
		var trail_right: float = abs(gx - (4.2 + sin(gz * 0.24) * 1.1))
		if minf(trail_front, trail_right) < 1.15:
			continue
		var gy: float = get_terrain_height(gx, gz)
		if gy > 1.05:
			continue # rocky altar peak stays bare limestone
		var s: float = rng.randf_range(0.34, 0.66)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		tfs.append(Transform3D(b, Vector3(gx, gy - 0.02, gz)))

	var g_mm := MultiMesh.new()
	g_mm.transform_format = MultiMesh.TRANSFORM_3D
	g_mm.mesh = _make_crossed_card_mesh(0.85, 0.65, false)
	g_mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		g_mm.set_instance_transform(i, tfs[i])

	var g_node := MultiMeshInstance3D.new()
	g_node.multimesh = g_mm
	g_node.material_override = grass_mat
	g_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g_node)


func _build_set_dressing_multimesh() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	rock_mat.normal_enabled = true
	rock_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	rock_mat.albedo_color = Color(0.82, 0.76, 0.65)
	rock_mat.roughness = 0.94

	# Sculpted faceted Canaanite limestone boulder mesh (NO smooth spheres!)
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.mesh = _make_sculpted_rock_mesh(13)

	var rock_transforms: Array[Transform3D] = []

	# 12-Stone Covenant Altar on north rise (1.0, -4.9)
	for i in range(12):
		var ang: float = float(i) / 12.0 * TAU
		var rx: float = 1.0 + cos(ang) * 1.08
		var rz: float = -4.9 + sin(ang) * 1.08
		var ry: float = get_terrain_height(rx, rz) + 0.16
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.18, 0.95, 1.05))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# 2-tier sculpted dry-stone courtyard retaining wall
	for tier in range(2):
		for i in range(44):
			var ang: float = float(i) / 44.0 * TAU
			var rx: float = -1.75 + cos(ang) * 4.55
			var rz: float = 0.25 + sin(ang) * 2.65
			if rz > 2.2 and rx > -2.35 and rx < -0.35:
				continue
			var ry: float = get_terrain_height(rx, rz) + 0.08 + float(tier) * 0.28
			var b := Basis().rotated(Vector3.UP, ang + float(tier) * 0.2).scaled(Vector3(0.95, 0.56, 0.78))
			rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Western spring cliff boulders
	for i in range(14):
		var ang: float = float(i) / 14.0 * TAU
		var rx: float = -7.8 + cos(ang) * 2.2
		var rz: float = -1.2 + sin(ang) * 2.0
		var ry: float = get_terrain_height(rx, rz) + 0.22
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.3, 1.05, 1.1))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1318
	for _i in range(52):
		var rx: float = rng.randf_range(-14.0, 13.0)
		var rz: float = rng.randf_range(-10.0, 9.0)
		if Vector2(rx + 2.0, rz - 0.2).length() < 5.6:
			continue
		var ry: float = get_terrain_height(rx, rz) + 0.04
		var s: float = rng.randf_range(0.55, 1.55)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s * 0.65, s * 0.9))
		rock_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	rock_mm.instance_count = rock_transforms.size()
	for i in range(rock_transforms.size()):
		rock_mm.set_instance_transform(i, rock_transforms[i])

	var rock_node := MultiMeshInstance3D.new()
	rock_node.multimesh = rock_mm
	rock_node.material_override = rock_mat
	add_child(rock_node)


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
	metrics_label.text = "饮水: %d  |  和睦: %d%%  |  GLB资产: %d  |  Draw Calls: %d  |  内存: %.1f MB" % [water_count, harmony_score, active_glb_slots, int(draw_calls), mem_mb]
