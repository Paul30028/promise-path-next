extends Node3D

const GlbAssetLoader = preload("res://scripts/glb_asset_loader.gd")

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


static func _make_draped_roof_mesh(w: float, d: float, ridge_h: float, eave_h: float, skirt_drop: float = 0.26, post_cols: int = 3) -> ArrayMesh:
	# True tensioned woven fabric canopy with post-peak cones, catenary sag, organic edge ripples & hanging eave valance!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sx: int = 20
	var sz: int = 14
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
			var nx: float = abs(u - 0.5) * 2.0
			# Natural catenary roof slope from ridgepole to eaves
			var catenary: float = pow(maxf(0.0, 1.0 - nz), 1.45)
			# Tension sag between timber posts along X
			var span_freq: float = float(post_cols - 1) * PI
			var pole_sag: float = -abs(sin(u * span_freq)) * 0.13 * (0.45 + 0.55 * nz)
			# Subtle cloth wrinkle wave
			var wrinkle: float = sin(u * PI * 9.0 + v * 3.0) * 0.018 * nz
			var y: float = eave_h + (ridge_h - eave_h) * catenary + pole_sag + wrinkle
			# Hanging scalloped fabric valance along outer perimeter (eliminates rigid board edge!)
			if r == 0 or r == sz or c == 0 or c == sx:
				var scallop: float = abs(sin((u + v) * PI * 6.0)) * 0.055
				y -= (skirt_drop + scallop)
			var idx: int = r * (sx + 1) + c
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(u * 2.2, v * 2.2)
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


static func _make_natural_cliff_rock_mesh(seed_val: int) -> ArrayMesh:
	# Type 1: Chiseled flat-faceted Canaanite limestone outcrop (crisp angular geological planes, NO pillows, NO concrete boxes!)
	var base := SphereMesh.new()
	base.radius = 0.62
	base.height = 0.72
	base.radial_segments = 9
	base.rings = 5
	var arrays: Array = base.surface_get_arrays(0)
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var displaced: PackedVector3Array = PackedVector3Array()
	displaced.resize(src_v.size())
	var fseed: float = float(seed_val) * 1.41
	for i in range(src_v.size()):
		var v: Vector3 = src_v[i]
		var lobe1: float = sin(v.x * 3.8 + fseed) * cos(v.z * 3.5 - fseed) * 0.18
		var lobe2: float = sin((v.x - v.z) * 5.2 + v.y * 3.4) * 0.09
		var r_scale: float = 1.0 + lobe1 + lobe2
		var nv := Vector3(v.x * r_scale, v.y * (0.86 + lobe2 * 0.45), v.z * r_scale)
		if nv.y > 0.16:
			nv.y = 0.16 + (nv.y - 0.16) * 0.42
		displaced[i] = nv

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, src_idx.size(), 3):
		var a: int = src_idx[i]
		var b: int = src_idx[i + 1]
		var c: int = src_idx[i + 2]
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


static func _make_masonry_wall_stone_mesh(seed_val: int) -> ArrayMesh:
	# Type 2: Hewn weathered Bronze Age fieldstone block (flat-faceted chiseled limestone, NO smooth pillows!)
	var base := SphereMesh.new()
	base.radius = 0.48
	base.height = 0.54
	base.radial_segments = 8
	base.rings = 4
	var arrays: Array = base.surface_get_arrays(0)
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var displaced: PackedVector3Array = PackedVector3Array()
	displaced.resize(src_v.size())
	var fseed: float = float(seed_val) * 2.13
	for i in range(src_v.size()):
		var v: Vector3 = src_v[i]
		var sx_c: float = signf(v.x) * pow(absf(v.x), 0.82) * 1.10
		var sy_c: float = signf(v.y) * pow(absf(v.y), 0.80) * 0.80
		var sz_c: float = signf(v.z) * pow(absf(v.z), 0.82) * 0.94
		var bump: float = sin(v.x * 4.6 + fseed) * cos(v.z * 4.2 - fseed) * 0.085
		displaced[i] = Vector3(sx_c * (1.0 + bump), sy_c, sz_c * (1.0 - bump * 0.6))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, src_idx.size(), 3):
		var a: int = src_idx[i]
		var b: int = src_idx[i + 1]
		var c: int = src_idx[i + 2]
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


static func _make_sculpted_rock_mesh(seed_val: int) -> ArrayMesh:
	return _make_natural_cliff_rock_mesh(seed_val)


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


static func _make_gnarled_trunk_mesh() -> ArrayMesh:
	# Twisted, root-flared ancient Mediterranean olive trunk (replaces plain cylinder!)
	var rings: int = 8
	var segs: int = 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	grid.resize((rings + 1) * (segs + 1))
	uvs.resize((rings + 1) * (segs + 1))
	for r in range(rings + 1):
		var t: float = float(r) / float(rings)
		var y: float = (t - 0.5) * 1.55
		var base_rad: float = lerpf(0.32, 0.13, pow(t, 0.72))
		if t < 0.18:
			base_rad += (0.18 - t) * 0.65
		var bend_x: float = sin(t * PI * 1.15) * 0.12
		var bend_z: float = cos(t * PI * 0.9) * 0.06
		for s in range(segs + 1):
			var u: float = float(s) / float(segs)
			var ang: float = u * TAU + t * 0.85
			var flute: float = 1.0 + sin(ang * 3.0 + t * 4.0) * 0.14
			var rad: float = base_rad * flute
			var idx: int = r * (segs + 1) + s
			grid[idx] = Vector3(bend_x + cos(ang) * rad, y, bend_z + sin(ang) * rad)
			uvs[idx] = Vector2(u * 2.0, t * 2.0)
	for r in range(rings):
		for s in range(segs):
			var i0: int = r * (segs + 1) + s
			var i1: int = i0 + 1
			var i2: int = i0 + (segs + 1)
			var i3: int = i2 + 1
			for tri in [[i0, i2, i1], [i1, i2, i3]]:
				for vi in tri:
					st.set_uv(uvs[vi])
					st.add_vertex(grid[vi])
	st.generate_normals()
	return st.commit()


func _add_contact_shadow(parent: Node3D, radius: float, opacity: float = 0.46, y_off: float = 0.03) -> void:
	var disc := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(radius * 2.0, radius * 2.0)
	disc.mesh = qm
	disc.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	disc.position = Vector3(0.0, y_off, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/contact_shadow.gdshader")
	smat.set_shader_parameter("opacity", opacity)
	disc.material_override = smat
	parent.add_child(disc)


func _exit_tree() -> void:
	GlbAssetLoader.clear_cache()


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
	_optimize_small_shadow_casters()
	if abram_actor != null:
		target_pos = abram_actor.global_position


func _optimize_small_shadow_casters() -> void:
	# Cut shadow-cascade draw calls on tiny props (<0.62m) that are already grounded by SSAO + contact shadows!
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and not (cur is MultiMeshInstance3D):
			var mi := cur as MeshInstance3D
			if mi.mesh != null and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				var sz: Vector3 = mi.mesh.get_aabb().size * mi.scale
				var max_dim: float = maxf(sz.x, maxf(sz.y, sz.z))
				if max_dim < 1.05 or sz.y < 0.08:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child in cur.get_children():
			stack.append(child)


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

			# Analytical Grounded Ambient Occlusion baked into COLOR.a!
			var ao: float = 1.0
			# 1. Under Main Patriarch Tent (-3.5, -0.5)
			var d_tent: float = Vector2((x + 3.5) / 2.45, (z + 0.5) / 1.70).length()
			if d_tent < 1.25:
				ao = minf(ao, lerpf(0.56, 1.0, clamp((d_tent - 0.65) / 0.60, 0.0, 1.0)))
			# 2. Under Healing Canopy (0.9, -0.2)
			var d_heal: float = Vector2((x - 0.9) / 1.55, (z + 0.2) / 1.35).length()
			if d_heal < 1.25:
				ao = minf(ao, lerpf(0.60, 1.0, clamp((d_heal - 0.60) / 0.65, 0.0, 1.0)))
			# 3. Along Dry-Stone Courtyard Retaining Wall Ring
			var d_ring: float = abs(Vector2((x + 1.8) / 4.85, (z - 0.1) / 3.10).length() - 1.0)
			if d_ring < 0.22:
				ao = minf(ao, lerpf(0.64, 1.0, clamp(d_ring / 0.22, 0.0, 1.0)))
			# 4. Around 12-Stone Altar Base (1.0, -4.9)
			var d_altar_ao: float = Vector2(x - 1.0, z + 4.9).length()
			if d_altar_ao < 2.2:
				ao = minf(ao, lerpf(0.66, 1.0, clamp((d_altar_ao - 1.1) / 1.1, 0.0, 1.0)))
			# 5. Wet Darkened Bank around Western Spring (-7.8, -1.2)
			var d_wet: float = Vector2(x + 7.8, z + 1.2).length()
			if d_wet < 2.85:
				ao = minf(ao, lerpf(0.54, 1.0, clamp((d_wet - 1.65) / 1.20, 0.0, 1.0)))

			weights[idx] = Color(w_dirt, w_grass, w_rock, ao)

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

	# Circular Stacked-Stone Water Well at front-left (-7.2, 2.2)
	# (Note: 12 courtyard limestone stair slabs are batched into rock_mm in _build_set_dressing_multimesh for fewer Draw Calls!)
	var wx: float = -7.2
	var wz: float = 2.2
	var wy: float = get_terrain_height(wx, wz)
	var well := Node3D.new()
	well.position = Vector3(wx, wy, wz)
	root.add_child(well)
	_add_contact_shadow(well, 1.38, 0.52, 0.04)

	var well_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_StoneWell.glb", 1.75, Vector3(-15.0, 25.0, 11.0), 0.14, 0.85, Color(1.12, 1.08, 1.02))
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
	if FileAccess.file_exists("res://assets/textures/wood_timber_albedo.png"):
		wood_mat.albedo_texture = load("res://assets/textures/wood_timber_albedo.png")
		wood_mat.normal_enabled = true
		wood_mat.normal_texture = load("res://assets/textures/wood_timber_normal.png")
		wood_mat.normal_scale = 1.2
		wood_mat.albedo_color = Color(0.82, 0.72, 0.58)
	else:
		wood_mat.albedo_color = Color(0.38, 0.23, 0.12)
	wood_mat.roughness = 0.88

	var tent_mat := StandardMaterial3D.new()
	tent_mat.albedo_texture = load("res://assets/textures/tent_goathair_albedo.png")
	tent_mat.normal_enabled = true
	tent_mat.normal_texture = load("res://assets/textures/tent_goathair_normal.png")
	tent_mat.albedo_color = Color(0.56, 0.46, 0.38)
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

	# 1. Main Patriarch Pavilion Tent at (-3.65, y, -0.5)
	var cx: float = -3.65
	var cz: float = -0.5
	var cy: float = get_terrain_height(cx, cz)
	var tent_root := Node3D.new()
	tent_root.position = Vector3(cx, cy, cz)
	root.add_child(tent_root)

	var tent_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_MainTent_cloth.glb", 2.68, Vector3(0.0, 0.0, 0.0), 0.04, 0.88, Color(1.04, 1.02, 1.00))
	if tent_glb != null:
		active_glb_slots += 1
		tent_root.add_child(tent_glb)
	else:
		for p in [Vector2(-1.85, -1.15), Vector2(0.0, -1.15), Vector2(1.85, -1.15), Vector2(-1.85, 1.15), Vector2(0.0, 1.15), Vector2(1.85, 1.15)]:
			var post := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.085
			cyl.bottom_radius = 0.11
			cyl.height = 2.02
			post.mesh = cyl
			post.material_override = wood_mat
			post.position = Vector3(p.x, 0.98, p.y)
			tent_root.add_child(post)

			# Thick Hemp Rope Lashing at Post Top
			var lash := MeshInstance3D.new()
			var lt := TorusMesh.new()
			lt.inner_radius = 0.08
			lt.outer_radius = 0.135
			lash.mesh = lt
			var rope_mat := StandardMaterial3D.new()
			rope_mat.albedo_color = Color(0.76, 0.64, 0.42)
			rope_mat.roughness = 0.94
			lash.material_override = rope_mat
			lash.position = Vector3(p.x, 1.82, p.y)
			tent_root.add_child(lash)

		# 4 Taut Diagonal Hemp Guy-Ropes staked into courtyard earth
		var rope_mat2 := StandardMaterial3D.new()
		rope_mat2.albedo_color = Color(0.74, 0.62, 0.40)
		rope_mat2.roughness = 0.92
		for gr in [
			[Vector3(-1.85, 1.82, 1.15), Vector3(-2.55, 0.0, 1.85)],
			[Vector3(1.85, 1.82, 1.15), Vector3(2.55, 0.0, 1.85)],
			[Vector3(-1.85, 1.82, -1.15), Vector3(-2.55, 0.0, -1.85)],
			[Vector3(1.85, 1.82, -1.15), Vector3(2.55, 0.0, -1.85)],
		]:
			var p0: Vector3 = gr[0]
			var p1: Vector3 = gr[1]
			var seg_v: Vector3 = p1 - p0
			var rope_m := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.018
			rc.bottom_radius = 0.018
			rc.height = seg_v.length()
			rope_m.mesh = rc
			rope_m.material_override = rope_mat2
			rope_m.position = (p0 + p1) * 0.5
			var up_dir: Vector3 = seg_v.normalized()
			var side_v: Vector3 = up_dir.cross(Vector3.UP).normalized()
			if side_v.length() < 0.01:
				side_v = Vector3.RIGHT
			var fwd_v: Vector3 = side_v.cross(up_dir).normalized()
			rope_m.basis = Basis(side_v, up_dir, fwd_v)
			tent_root.add_child(rope_m)

		var main_roof := MeshInstance3D.new()
		main_roof.mesh = _make_draped_roof_mesh(4.50, 3.10, 2.52, 1.94, 0.30, 3)
		main_roof.material_override = tent_mat
		tent_root.add_child(main_roof)

		var back_curtain := MeshInstance3D.new()
		var bcb := BoxMesh.new()
		bcb.size = Vector3(3.8, 1.8, 0.08)
		back_curtain.mesh = bcb
		back_curtain.material_override = tent_mat
		back_curtain.position = Vector3(0.0, 0.95, -1.12)
		tent_root.add_child(back_curtain)

		var banner_mat := ShaderMaterial.new()
		banner_mat.shader = load("res://shaders/cloth_sway.gdshader")
		banner_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/tapestry_tekhelet_albedo.png"))
		for bx in [-1.25, 1.25]:
			var banner := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.75, 1.12)
			plane.subdivide_width = 6
			plane.subdivide_depth = 8
			plane.orientation = PlaneMesh.FACE_Z
			banner.mesh = plane
			banner.material_override = banner_mat
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
	var amphora_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/PRP_AmphoraCluster.glb", 0.96, Vector3(0.0, 15.0, 0.0), 0.02, 0.65)
	if amphora_glb != null:
		active_glb_slots += 1
		amphora_glb.position = Vector3(-1.82, 0.0, 1.56)
		tent_root.add_child(amphora_glb)
	else:
		var amphora_mesh := _make_amphora_mesh()
		var handle_mesh := TorusMesh.new()
		handle_mesh.inner_radius = 0.065
		handle_mesh.outer_radius = 0.105
		for jar in [[Vector3(-2.15, 0.0, 1.35), 0.95], [Vector3(-1.68, 0.0, 1.56), 0.72], [Vector3(-1.35, 0.0, 1.85), 0.52]]:
			var jar_n := Node3D.new()
			jar_n.position = jar[0]
			var js: float = float(jar[1])
			jar_n.scale = Vector3(js, js, js)
			var jm := MeshInstance3D.new()
			jm.mesh = amphora_mesh
			jm.material_override = clay_mat
			jar_n.add_child(jm)
			for side_h in [-1.0, 1.0]:
				var hm := MeshInstance3D.new()
				hm.mesh = handle_mesh
				hm.material_override = clay_mat
				hm.position = Vector3(side_h * 0.20, 0.72, 0.0)
				hm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				jar_n.add_child(hm)
			_add_contact_shadow(jar_n, 0.36, 0.40, 0.02)
			tent_root.add_child(jar_n)

	# Real Photoscanned CC0 Stone Campfire Hearth (Poly Haven stone_fire_pit) + Shader Flame!
	var hearth_cc0: Node3D = GlbAssetLoader.load_scene_asset("res://assets/cc0_models/stone_fire_pit/stone_fire_pit_1k.gltf", 0.46, Vector3(0.0, 22.0, 0.0), 0.06, Vector3(1.15, 1.0, 1.15), Color(1.18, 1.10, 0.96))
	if hearth_cc0 != null:
		active_glb_slots += 1
		hearth_cc0.position = Vector3(-0.35, 0.0, 2.05)
		tent_root.add_child(hearth_cc0)
	else:
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

	# Rising Golden Campfire Ember Motes
	var embers := CPUParticles3D.new()
	embers.position = Vector3(-0.35, 0.42, 2.05)
	embers.amount = 14
	embers.lifetime = 2.2
	embers.preprocess = 1.2
	embers.direction = Vector3(0.1, 1.0, -0.05)
	embers.spread = 22.0
	embers.gravity = Vector3(0.0, 0.15, 0.0)
	embers.initial_velocity_min = 0.45
	embers.initial_velocity_max = 0.95
	var em_mesh := SphereMesh.new()
	em_mesh.radius = 0.028
	em_mesh.height = 0.056
	var em_mat := StandardMaterial3D.new()
	em_mat.albedo_color = Color(1.0, 0.72, 0.24)
	em_mat.emission_enabled = true
	em_mat.emission = Color(1.0, 0.55, 0.12)
	em_mat.emission_energy_multiplier = 3.2
	em_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em_mesh.material = em_mat
	embers.mesh = em_mesh
	tent_root.add_child(embers)

	# 2. Herbal Healing Linen Canopy at (1.15, y, -0.2)
	var hx: float = 1.15
	var hz: float = -0.2
	var hy: float = get_terrain_height(hx, hz)
	var heal_root := Node3D.new()
	heal_root.position = Vector3(hx, hy, hz)
	root.add_child(heal_root)

	var heal_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/BLD_HealingCanopy_cloth.glb", 2.15, Vector3(0.0, 0.0, 0.0), 0.04, 0.90, Color(1.04, 1.00, 0.92))
	if heal_glb != null:
		active_glb_slots += 1
		heal_root.add_child(heal_glb)
		# Place real CC0 handcrafted wooden apothecary table & ceramic vase inside!
		var tbl_cc0: Node3D = GlbAssetLoader.load_scene_asset("res://assets/cc0_models/WoodenTable_02/WoodenTable_02_1k.gltf", 0.68, Vector3(0.0, 0.0, 0.0), 0.02, Vector3(0.92, 1.0, 0.85))
		if tbl_cc0 != null:
			tbl_cc0.position = Vector3(0.12, 0.0, 0.25)
			heal_root.add_child(tbl_cc0)
		var vase_cc0: Node3D = GlbAssetLoader.load_scene_asset("res://assets/cc0_models/antique_ceramic_vase_01/antique_ceramic_vase_01_1k.gltf", 0.42, Vector3(0.0, 35.0, 0.0), 0.02)
		if vase_cc0 != null:
			vase_cc0.position = Vector3(-0.62, 0.0, 0.48)
			heal_root.add_child(vase_cc0)
	else:
		var linen_mat := StandardMaterial3D.new()
		linen_mat.albedo_texture = load("res://assets/textures/linen_canopy_albedo.png")
		linen_mat.normal_enabled = true
		linen_mat.normal_texture = load("res://assets/textures/linen_canopy_normal.png")
		linen_mat.normal_scale = 0.75
		linen_mat.albedo_color = Color(1.08, 0.99, 0.82)
		linen_mat.roughness = 0.94
		linen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var olive_cloth := StandardMaterial3D.new()
		olive_cloth.albedo_color = Color(0.24, 0.40, 0.14)
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
		heal_roof.mesh = _make_draped_roof_mesh(2.82, 2.38, 2.12, 1.66, 0.24, 2)
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

		# Woven reed floor mat beneath apothecary table
		var reed_mat_m := MeshInstance3D.new()
		var rmb := BoxMesh.new()
		rmb.size = Vector3(1.65, 0.025, 1.05)
		reed_mat_m.mesh = rmb
		reed_mat_m.material_override = linen_mat
		reed_mat_m.position = Vector3(0.05, 0.02, 0.35)
		heal_root.add_child(reed_mat_m)

		# 4 Clay Herb Bowls with green/lavender Mediterranean herbs on table
		var herb_green_mat := StandardMaterial3D.new()
		herb_green_mat.albedo_color = Color(0.24, 0.44, 0.16)
		herb_green_mat.roughness = 0.90
		var lavender_mat := StandardMaterial3D.new()
		lavender_mat.albedo_color = Color(0.48, 0.34, 0.58)
		lavender_mat.roughness = 0.88
		for bi in range(4):
			var bx_off: float = -0.32 + float(bi) * 0.30
			var bowl := MeshInstance3D.new()
			var bwc := CylinderMesh.new()
			bwc.top_radius = 0.11
			bwc.bottom_radius = 0.07
			bwc.height = 0.10
			bowl.mesh = bwc
			bowl.material_override = clay_mat
			bowl.position = Vector3(bx_off, 0.61, 0.32 + (0.05 if bi % 2 == 0 else -0.04))
			heal_root.add_child(bowl)

			var sprig := MeshInstance3D.new()
			var spm := SphereMesh.new()
			spm.radius = 0.095
			spm.height = 0.12
			sprig.mesh = spm
			sprig.material_override = lavender_mat if bi == 2 else herb_green_mat
			sprig.position = Vector3(bx_off, 0.68, 0.32 + (0.05 if bi % 2 == 0 else -0.04))
			heal_root.add_child(sprig)

		var basket := MeshInstance3D.new()
		var bkc := CylinderMesh.new()
		bkc.top_radius = 0.24
		bkc.bottom_radius = 0.18
		bkc.height = 0.34
		basket.mesh = bkc
		basket.material_override = linen_mat
		basket.position = Vector3(-0.62, 0.17, 0.52)
		heal_root.add_child(basket)

		var b_herbs := MeshInstance3D.new()
		var bhs := SphereMesh.new()
		bhs.radius = 0.22
		bhs.height = 0.22
		b_herbs.mesh = bhs
		b_herbs.material_override = lavender_mat
		b_herbs.position = Vector3(-0.62, 0.36, 0.52)
		heal_root.add_child(b_herbs)

	# 3. Altar Shader Fire & Wispy Rising Smoke Plume on North-Central Rocky Rise (1.0, -4.9)
	var ay: float = get_terrain_height(1.0, -4.9)
	var aflame := MeshInstance3D.new()
	aflame.mesh = flame_card_mesh
	aflame.material_override = flame_shader_mat
	aflame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aflame.position = Vector3(1.0, ay + 0.72, -4.9)
	aflame.scale = Vector3(1.15, 1.15, 1.15)
	root.add_child(aflame)

	var smoke_shader_mat := ShaderMaterial.new()
	smoke_shader_mat.shader = load("res://shaders/smoke_plume.gdshader")
	var plume := MeshInstance3D.new()
	plume.mesh = _make_crossed_card_mesh(1.15, 2.85, false)
	plume.material_override = smoke_shader_mat
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.position = Vector3(1.0, ay + 1.22, -4.9)
	root.add_child(plume)
	smoke_nodes.append(plume)


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
	var fquad := QuadMesh.new()
	fquad.size = Vector2(0.72, 1.25)
	fall.mesh = fquad
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://shaders/waterfall_stream.gdshader")
	fall.material_override = fmat
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fall.position = Vector3(sx - 0.58, sy + 0.44, sz - 1.18)
	fall.rotation_degrees = Vector3(-22.0, 28.0, 0.0)
	add_child(fall)

	# Dark Wet Limestone Boulders framing the waterfall spout
	var wet_rock_mat := StandardMaterial3D.new()
	wet_rock_mat.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	wet_rock_mat.normal_enabled = true
	wet_rock_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	wet_rock_mat.albedo_color = Color(0.68, 0.62, 0.50)
	wet_rock_mat.roughness = 0.42
	var wet_mesh := _make_sculpted_rock_mesh(33)
	for wr in [
		[Vector3(sx - 1.25, sy + 0.42, sz - 1.45), Vector3(1.15, 1.1, 1.05)],
		[Vector3(sx + 0.05, sy + 0.35, sz - 1.55), Vector3(1.05, 0.95, 0.95)],
		[Vector3(sx - 0.65, sy + 0.85, sz - 1.85), Vector3(1.35, 0.85, 1.15)],
	]:
		var bld := MeshInstance3D.new()
		bld.mesh = wet_mesh
		bld.material_override = wet_rock_mat
		bld.position = wr[0]
		bld.scale = wr[1]
		add_child(bld)


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
	var abram_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Abram.glb", 1.72, Vector3(0.0, -75.0, 0.0), 0.02, 0.78, Color(1.10, 1.08, 1.04))
	if abram_glb != null:
		active_glb_slots += 1
		abram_actor = Node3D.new()
		abram_actor.name = "AbramCommercialGLB"
		abram_actor.position = Vector3(-1.85, get_terrain_height(-1.85, 1.25), 1.25)
		abram_actor.rotation_degrees = Vector3(0.0, 25.0, 0.0)
		abram_actor.add_child(abram_glb)
		_add_contact_shadow(abram_actor, 0.52, 0.48, 0.03)
		add_child(abram_actor)
	else:
		abram_actor = _make_human_figure(Vector3(-1.85, 0.0, 1.25), Color(0.28, 0.36, 0.50), true, true)
		abram_actor.name = "AbramStylized"
		abram_actor.rotation_degrees = Vector3(0.0, 65.0, 0.0)
		_add_contact_shadow(abram_actor, 0.52, 0.48, 0.03)
		add_child(abram_actor)

	var sarai_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Sarai.glb", 1.56, Vector3(0.0, -75.0, 0.0), 0.02, 0.80, Color(1.12, 1.08, 1.02))
	if sarai_glb != null:
		active_glb_slots += 1
		var sarai_n := Node3D.new()
		sarai_n.name = "SaraiCommercialGLB"
		sarai_n.position = Vector3(-0.75, get_terrain_height(-0.75, 1.30), 1.30)
		sarai_n.rotation_degrees = Vector3(0.0, -25.0, 0.0)
		sarai_n.add_child(sarai_glb)
		_add_contact_shadow(sarai_n, 0.48, 0.44, 0.03)
		add_child(sarai_n)
	else:
		var sarai := _make_human_figure(Vector3(-0.75, 0.0, 1.30), Color(0.76, 0.50, 0.28), false, false)
		sarai.name = "SaraiStylized"
		sarai.scale = Vector3(0.95, 0.95, 0.95)
		sarai.rotation_degrees = Vector3(0.0, -75.0, 0.0)
		# Sculpted flowing dark wavy back-hair + bronze-gold olive circlet headband (matching camp-scene-mobile.png!)
		var back_hair := MeshInstance3D.new()
		var bh_cyl := CylinderMesh.new()
		bh_cyl.top_radius = 0.14
		bh_cyl.bottom_radius = 0.19
		bh_cyl.height = 0.44
		back_hair.mesh = bh_cyl
		var bh_mat := StandardMaterial3D.new()
		bh_mat.albedo_color = Color(0.18, 0.11, 0.07)
		bh_mat.roughness = 0.88
		back_hair.material_override = bh_mat
		back_hair.position = Vector3(0.0, 1.24, -0.10)
		back_hair.rotation_degrees = Vector3(14.0, 0.0, 0.0)
		sarai.add_child(back_hair)

		var circlet := MeshInstance3D.new()
		var ct := TorusMesh.new()
		ct.inner_radius = 0.145
		ct.outer_radius = 0.168
		circlet.mesh = ct
		var gold_mat := StandardMaterial3D.new()
		gold_mat.albedo_color = Color(0.84, 0.66, 0.28)
		gold_mat.metallic = 0.55
		gold_mat.roughness = 0.35
		circlet.material_override = gold_mat
		circlet.position = Vector3(0.0, 1.46, 0.0)
		sarai.add_child(circlet)

		_add_contact_shadow(sarai, 0.48, 0.46, 0.03)
		add_child(sarai)

	# Replace primitive cylinder healer with clean scaled GLB or omit crude cylinder
	var healer_glb: Node3D = GlbAssetLoader.load_glb_instance("res://assets/models/CHR_Sarai.glb", 1.48, Vector3(0.0, -25.0, 0.0), 0.02, 0.85, Color(0.92, 0.96, 0.84))
	if healer_glb != null:
		healer_glb.position = Vector3(1.15, get_terrain_height(1.15, -0.35), -0.35)
		add_child(healer_glb)


func _build_sheep_flocks() -> void:
	var spots: Array[Vector2] = [
		Vector2(-0.4, 5.2), Vector2(0.5, 4.9), Vector2(1.2, 5.4), Vector2(0.2, 5.8),
		Vector2(4.6, 4.6), Vector2(5.4, 4.3), Vector2(6.0, 5.0), Vector2(5.2, 5.5), Vector2(6.5, 4.5),
	]
	if FileAccess.file_exists("res://assets/models/CHR_Sheep.glb"):
		var mesh_data: Dictionary = GlbAssetLoader.extract_first_mesh_data("res://assets/models/CHR_Sheep.glb", 0.90, Color(1.12, 1.08, 1.00))
		if not mesh_data.is_empty():
			var s_mesh: Mesh = mesh_data["mesh"]
			var s_mat: Material = mesh_data["material"]
			var s_aabb: AABB = mesh_data["aabb"]
			var s_mm := MultiMesh.new()
			s_mm.transform_format = MultiMesh.TRANSFORM_3D
			s_mm.mesh = s_mesh
			s_mm.instance_count = spots.size()
			var rng_g := RandomNumberGenerator.new()
			rng_g.seed = 909
			for i in range(spots.size()):
				var s: Vector2 = spots[i]
				var target_h: float = rng_g.randf_range(0.64, 0.76)
				var sf: float = target_h / maxf(s_aabb.size.y, 0.001)
				var yaw: float = deg_to_rad(rng_g.randf_range(-55.0, 55.0))
				var rot := Basis().rotated(Vector3.UP, yaw).scaled(Vector3(sf, sf, sf))
				var sy: float = get_terrain_height(s.x, s.y) - s_aabb.position.y * sf - 0.02
				s_mm.set_instance_transform(i, Transform3D(rot, Vector3(s.x, sy, s.y)))
			var s_node := MultiMeshInstance3D.new()
			s_node.name = "SheepFlockGLB_MultiMesh"
			s_node.multimesh = s_mm
			s_node.material_override = s_mat
			add_child(s_node)
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
	var tree_spots: Array[Vector3] = [
		Vector3(-7.6, 0.0, -4.6),
		Vector3(-4.2, 0.0, -4.2),
		Vector3(-9.2, 0.0, 3.8),
		Vector3(5.6, 0.0, -4.4),
		Vector3(8.2, 0.0, -2.8),
		Vector3(4.2, 0.0, -6.8),
		Vector3(-10.5, 0.0, -6.8),
		Vector3(-6.2, 0.0, -7.8),
		Vector3(-2.4, 0.0, -8.2),
		Vector3(6.8, 0.0, -7.2),
		Vector3(10.2, 0.0, -5.8),
		Vector3(11.4, 0.0, -1.8),
		Vector3(-11.2, 0.0, 0.4),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 407

	# REAL Photoscanned Airy Branched Mediterranean Trees & Shrubs (Poly Haven CC0 — ZERO broccoli blobs!)
	if ResourceLoader.exists("res://assets/cc0_models/island_tree_01/island_tree_01_1k.gltf"):
		var trees_root := Node3D.new()
		trees_root.name = "PhotoscannedOliveGrovesCC0"
		add_child(trees_root)
		var tree_paths: Array[String] = [
			"res://assets/cc0_models/island_tree_01/island_tree_01_1k.gltf",
			"res://assets/cc0_models/island_tree_02/island_tree_02_1k.gltf",
		]
		var tree_tint := Color(0.92, 0.98, 0.76)
		for i in range(tree_spots.size()):
			var spot: Vector3 = tree_spots[i]
			var tpath: String = tree_paths[i % tree_paths.size()]
			var target_h: float = rng.randf_range(3.6, 4.8)
			var yaw_d: float = rng.randf_range(0.0, 360.0)
			var t_inst: Node3D = GlbAssetLoader.load_scene_asset(tpath, target_h, Vector3(0.0, yaw_d, 0.0), 0.18, Vector3(1.12, 0.92, 1.12), tree_tint)
			if t_inst != null:
				t_inst.position = Vector3(spot.x, get_terrain_height(spot.x, spot.z), spot.z)
				trees_root.add_child(t_inst)
		# Real Photoscanned Mediterranean Shrubs tucked organically along boulders, water bank & walls!
		var shrub_paths: Array[String] = [
			"res://assets/cc0_models/shrub_01/shrub_01_1k.gltf",
			"res://assets/cc0_models/shrub_02/shrub_02_1k.gltf",
		]
		var shrub_spots: Array[Vector2] = [
			Vector2(-6.4, 0.6), Vector2(-5.8, -2.6), Vector2(-4.9, 3.1), Vector2(2.8, 2.5),
			Vector2(3.7, 1.0), Vector2(3.8, -1.9), Vector2(-0.9, -3.4), Vector2(3.1, -3.7),
			Vector2(-5.5, -3.5), Vector2(5.4, 2.2), Vector2(-7.8, 3.6), Vector2(-3.2, 4.4),
			Vector2(6.8, -0.5), Vector2(7.4, 2.2),
		]
		for si in range(shrub_spots.size()):
			var bs: Vector2 = shrub_spots[si]
			var spath: String = shrub_paths[si % shrub_paths.size()]
			var sh_inst: Node3D = GlbAssetLoader.load_scene_asset(spath, rng.randf_range(0.55, 0.95), Vector3(0.0, rng.randf_range(0.0, 360.0), 0.0), 0.06, Vector3.ONE, Color(0.90, 0.96, 0.72))
			if sh_inst != null:
				sh_inst.position = Vector3(bs.x, get_terrain_height(bs.x, bs.y), bs.y)
				trees_root.add_child(sh_inst)
		active_glb_slots += 1
		return

	# Fallback: Local RTX 5060 Olive Tree GLB
	if FileAccess.file_exists("res://assets/models/ENV_OliveTree.glb"):
		var tdata: Dictionary = GlbAssetLoader.extract_first_mesh_data("res://assets/models/ENV_OliveTree.glb", 0.90, Color(1.06, 1.08, 1.00))
		if not tdata.is_empty():
			var t_mesh: Mesh = tdata["mesh"]
			var t_mat: Material = tdata["material"]
			var t_aabb: AABB = tdata["aabb"]
			var t_mm := MultiMesh.new()
			t_mm.transform_format = MultiMesh.TRANSFORM_3D
			t_mm.mesh = t_mesh
			t_mm.instance_count = tree_spots.size()
			for i in range(tree_spots.size()):
				var spot: Vector3 = tree_spots[i]
				var target_h: float = rng.randf_range(3.2, 4.3)
				var sf: float = target_h / maxf(t_aabb.size.y, 0.001)
				var yaw: float = deg_to_rad(rng.randf_range(-40.0, 40.0))
				var rot := Basis().rotated(Vector3.UP, yaw).scaled(Vector3(sf * 1.12, sf, sf * 1.12))
				var ty: float = get_terrain_height(spot.x, spot.z) - t_aabb.position.y * sf - 0.14
				t_mm.set_instance_transform(i, Transform3D(rot, Vector3(spot.x, ty, spot.z)))
			var t_node := MultiMeshInstance3D.new()
			t_node.name = "OliveGrovesGLB_MultiMesh"
			t_node.multimesh = t_mm
			t_node.material_override = t_mat
			add_child(t_node)
			active_glb_slots += 1
			return

	# Fallback procedural olive trees if ENV_OliveTree.glb is absent
	var bark_mat := StandardMaterial3D.new()
	if FileAccess.file_exists("res://assets/textures/wood_timber_albedo.png"):
		bark_mat.albedo_texture = load("res://assets/textures/wood_timber_albedo.png")
		bark_mat.normal_enabled = true
		bark_mat.normal_texture = load("res://assets/textures/wood_timber_normal.png")
		bark_mat.normal_scale = 1.4
		bark_mat.albedo_color = Color(0.68, 0.60, 0.50)
	else:
		bark_mat.albedo_color = Color(0.32, 0.21, 0.13)
	bark_mat.roughness = 0.95

	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = load("res://shaders/foliage_sway.gdshader")
	leaf_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/olive_leaves_alpha.png"))
	leaf_mat.set_shader_parameter("tint_bottom", Color(0.14, 0.25, 0.11))
	leaf_mat.set_shader_parameter("tint_top", Color(0.78, 0.88, 0.42))
	leaf_mat.set_shader_parameter("wind_strength", 0.05)
	leaf_mat.set_shader_parameter("wind_speed", 1.3)

	var offsets: Array[Vector3] = [
		Vector3(0.0, 1.75, 0.0),
		Vector3(-0.92, 1.54, 0.36),
		Vector3(0.92, 1.56, -0.30),
		Vector3(0.28, 1.58, 0.78),
		Vector3(-0.38, 1.52, -0.76),
		Vector3(0.32, 1.92, 0.14),
		Vector3(-0.46, 1.84, 0.28),
	]

	var trunk_tfs: Array[Transform3D] = []
	var leaf_tfs: Array[Transform3D] = []

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
			var rad: float = rng.randf_range(1.30, 1.85) * sf
			var lb := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-12.0, 12.0))).scaled(Vector3(rad, rad * 0.48, rad))
			leaf_tfs.append(Transform3D(lb, Vector3(spot.x + off.x, ty + off.y, spot.z + off.z)))

	var gnarled_trunk := _make_gnarled_trunk_mesh()
	var t_mm := MultiMesh.new()
	t_mm.transform_format = MultiMesh.TRANSFORM_3D
	t_mm.mesh = gnarled_trunk
	t_mm.instance_count = trunk_tfs.size()
	for i in range(trunk_tfs.size()):
		t_mm.set_instance_transform(i, trunk_tfs[i])
	var t_node := MultiMeshInstance3D.new()
	t_node.multimesh = t_mm
	t_node.material_override = bark_mat
	add_child(t_node)

	# Also add 18 low Mediterranean olive-green scrub bushes tucked along walls & boulders (same 1 Draw Call!)
	var bush_spots: Array[Vector2] = [
		Vector2(-6.6, 0.8), Vector2(-6.1, -2.5), Vector2(-4.8, 3.2), Vector2(2.6, 2.7),
		Vector2(3.6, 1.2), Vector2(3.8, -1.8), Vector2(-0.8, -3.5), Vector2(3.0, -3.8),
		Vector2(-5.4, -3.4), Vector2(5.4, 2.4), Vector2(-7.8, 3.6), Vector2(-3.2, 4.4),
		Vector2(6.8, -0.5), Vector2(7.4, 2.2), Vector2(-1.6, -5.2), Vector2(2.8, -6.0),
		Vector2(-8.6, 0.6), Vector2(4.4, -5.4),
	]
	for bs in bush_spots:
		var by: float = get_terrain_height(bs.x, bs.y)
		var br: float = rng.randf_range(0.65, 1.15)
		var bb := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(br, br * 0.55, br))
		leaf_tfs.append(Transform3D(bb, Vector3(bs.x, by + 0.24 * br, bs.y)))

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
	grass_mat.set_shader_parameter("tint_bottom", Color(0.20, 0.38, 0.10))
	grass_mat.set_shader_parameter("tint_top", Color(0.94, 0.96, 0.46))
	grass_mat.set_shader_parameter("wind_strength", 0.07)
	grass_mat.set_shader_parameter("wind_speed", 2.0)

	var tfs: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# De-noised organic clustered grass tufts (1,400 tufts along trails, rocks & meadow pockets — NO uniform carpet!)
	for _i in range(1400):
		var gx: float = rng.randf_range(-15.5, 14.5)
		var gz: float = rng.randf_range(-10.5, 10.5)
		if Vector2((gx + 2.0) * 0.65, (gz - 0.2) * 0.92).length() < 5.0:
			continue
		if Vector2(gx + 7.8, gz + 1.2).length() < 2.5:
			continue
		var trail_front: float = abs(gz - (3.8 - (gx + 1.0) * 0.22))
		var trail_right: float = abs(gx - (4.2 + sin(gz * 0.24) * 1.1))
		if minf(trail_front, trail_right) < 1.25:
			continue
		var gy: float = get_terrain_height(gx, gz)
		if gy > 1.10:
			continue
		# Natural clumping wave so grass grows in organic clusters with breathing room
		var clump: float = sin(gx * 0.65) * cos(gz * 0.58)
		if clump < -0.15 and rng.randf() < 0.72:
			continue
		var s: float = rng.randf_range(0.32, 0.62)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * rng.randf_range(0.75, 1.15), s))
		tfs.append(Transform3D(b, Vector3(gx, gy - 0.02, gz)))

	var g_mm := MultiMesh.new()
	g_mm.transform_format = MultiMesh.TRANSFORM_3D
	g_mm.mesh = _make_crossed_card_mesh(0.80, 0.56, false)
	g_mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		g_mm.set_instance_transform(i, tfs[i])

	var g_node := MultiMeshInstance3D.new()
	g_node.multimesh = g_mm
	g_node.material_override = grass_mat
	g_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g_node)


func _build_set_dressing_multimesh() -> void:
	# 100% REAL PHOTOSCANNED CC0 GEOLOGICAL LIMESTONE CLIFFS, BOULDERS & FIELDSTONES (ZERO procedural polyhedra!)
	if ResourceLoader.exists("res://assets/cc0_models/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf"):
		var rocks_root := Node3D.new()
		rocks_root.name = "PhotoscannedLimestoneCC0"
		add_child(rocks_root)
		var rng_r := RandomNumberGenerator.new()
		rng_r.seed = 777
		var limestone_tint := Color(1.16, 1.08, 0.92)

		var cliff1 := "res://assets/cc0_models/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf"
		var cliff2 := "res://assets/cc0_models/namaqualand_cliff_02/namaqualand_cliff_02_1k.gltf"
		var bld1 := "res://assets/cc0_models/namaqualand_boulders_01/namaqualand_boulders_01_1k.gltf"
		var bld2 := "res://assets/cc0_models/namaqualand_boulder_02/namaqualand_boulder_02_1k.gltf"
		var stones := "res://assets/cc0_models/namaqualand_stones_01/namaqualand_stones_01_1k.gltf"

		# 1. Monumental North-Central Altar Rocky Massif (real geological cliff scans!)
		for cl in [
			[cliff1, Vector3(1.0, 0.0, -5.2), 2.25, Vector3(0.0, 20.0, 0.0), 0.85, Vector3(1.12, 0.82, 1.02)],
			[bld1, Vector3(-1.6, 0.0, -4.4), 1.65, Vector3(0.0, 55.0, 0.0), 0.48, Vector3(1.15, 0.88, 1.05)],
			[cliff2, Vector3(3.6, 0.0, -4.4), 2.15, Vector3(0.0, -65.0, 0.0), 0.78, Vector3(1.02, 0.82, 0.96)],
			# Western Spring Grotto Cliff Outcrops
			[cliff1, Vector3(-8.4, 0.0, -2.5), 1.95, Vector3(0.0, 55.0, 0.0), 0.55, Vector3(0.92, 0.90, 0.90)],
			[bld1, Vector3(-9.5, 0.0, -0.6), 1.35, Vector3(0.0, 110.0, 0.0), 0.35, Vector3.ONE],
			[bld2, Vector3(-6.4, 0.0, -2.6), 1.25, Vector3(0.0, -30.0, 0.0), 0.32, Vector3.ONE],
		]:
			var pos_v: Vector3 = cl[1]
			var inst: Node3D = GlbAssetLoader.load_scene_asset(cl[0], cl[2], cl[3], cl[4], cl[5], limestone_tint)
			if inst != null:
				inst.position = Vector3(pos_v.x, get_terrain_height(pos_v.x, pos_v.z), pos_v.z)
				rocks_root.add_child(inst)

		# 2. 12-Stone Covenant Altar Ring on North Hill Summit (real photoscanned weathered boulders!)
		for i in range(12):
			var ang: float = float(i) / 12.0 * TAU
			var rx: float = 1.0 + cos(ang) * 1.12
			var rz: float = -4.9 + sin(ang) * 1.12
			var st_inst: Node3D = GlbAssetLoader.load_scene_asset(bld2, rng_r.randf_range(0.52, 0.68), Vector3(0.0, rad_to_deg(ang) + rng_r.randf_range(-25, 25), 0.0), 0.14, Vector3.ONE, Color(1.22, 1.14, 0.98))
			if st_inst != null:
				st_inst.position = Vector3(rx, get_terrain_height(rx, rz), rz)
				rocks_root.add_child(st_inst)

		# 3. Hand-Laid Irregular Courtyard Retaining Wall & Steps (real photoscanned stone clusters, staggered & half-buried!)
		for i in range(24):
			var ang: float = float(i) / 24.0 * TAU
			var rx: float = -1.75 + cos(ang) * 4.55
			var rz: float = 0.25 + sin(ang) * 2.65
			if rz > 2.15 and rx > -2.35 and rx < -0.35:
				continue
			var src_p: String = stones if (i % 2 == 0) else bld2
			var w_inst: Node3D = GlbAssetLoader.load_scene_asset(src_p, rng_r.randf_range(0.62, 0.82), Vector3(0.0, rad_to_deg(ang) + 90.0 + rng_r.randf_range(-18, 18), 0.0), 0.18, Vector3(1.15, 0.82, 0.92), limestone_tint)
			if w_inst != null:
				w_inst.position = Vector3(rx, get_terrain_height(rx, rz), rz)
				rocks_root.add_child(w_inst)

		# 3-Tier Worn Courtyard Entry Steps (half-buried photoscanned flat boulders)
		for s in range(3):
			var sz: float = 2.65 + float(s) * 0.44
			for b in range(3):
				var sx: float = -1.92 + float(b) * 0.58 + (0.08 if s % 2 == 1 else 0.0)
				var step_n: Node3D = GlbAssetLoader.load_scene_asset(bld2, 0.36, Vector3(0.0, rng_r.randf_range(0, 360), 0.0), 0.14, Vector3(1.35, 0.65, 1.15), Color(1.20, 1.12, 0.96))
				if step_n != null:
					step_n.position = Vector3(sx, get_terrain_height(sx, sz) + 0.10 - float(s) * 0.06, sz)
					rocks_root.add_child(step_n)

		# 4. Curated Natural Hillside Boulder Clusters (grounded, half-buried, NOT random uniform scatter!)
		for hb in [
			[bld1, Vector3(4.2, 0.0, 2.2), 1.05, 35.0],
			[bld2, Vector3(5.0, 0.0, 1.6), 0.72, 140.0],
			[bld1, Vector3(-6.8, 0.0, 4.2), 0.95, -55.0],
			[stones, Vector3(-5.8, 0.0, 4.6), 0.68, 80.0],
			[bld2, Vector3(7.2, 0.0, -1.6), 1.10, 15.0],
			[stones, Vector3(-9.8, 0.0, -5.8), 0.85, 20.0],
			[stones, Vector3(-5.8, 0.0, -6.4), 0.88, 12.0],
			[stones, Vector3(6.2, 0.0, -5.6), 0.88, -18.0],
			[stones, Vector3(9.6, 0.0, -6.2), 0.85, -24.0],
		]:
			var hp: Vector3 = hb[1]
			var bi: Node3D = GlbAssetLoader.load_scene_asset(hb[0], hb[2], Vector3(0.0, hb[3], 0.0), 0.22, Vector3.ONE, limestone_tint)
			if bi != null:
				bi.position = Vector3(hp.x, get_terrain_height(hp.x, hp.z), hp.z)
				rocks_root.add_child(bi)

		active_glb_slots += 1
		return

	# Fallback procedural rocks only if CC0 scans are absent
	var cliff_mat := StandardMaterial3D.new()
	cliff_mat.albedo_texture = load("res://assets/textures/linen_canopy_albedo.png")
	cliff_mat.normal_enabled = true
	cliff_mat.normal_texture = load("res://assets/textures/rock_boulder_normal.png")
	cliff_mat.normal_scale = 0.50
	cliff_mat.albedo_color = Color(1.14, 0.98, 0.72)
	cliff_mat.vertex_color_use_as_albedo = true
	cliff_mat.roughness = 0.93

	var wall_mat := cliff_mat.duplicate() as StandardMaterial3D
	wall_mat.albedo_color = Color(1.20, 1.04, 0.78)

	var cliff_transforms: Array[Transform3D] = []
	var wall_transforms: Array[Transform3D] = []
	var palette: Array[Color] = [
		Color(1.00, 0.96, 0.86),
		Color(0.93, 0.87, 0.76),
		Color(0.86, 0.79, 0.68),
		Color(0.96, 0.91, 0.80),
		Color(0.82, 0.76, 0.66),
	]

	# Type 2 (Masonry Fieldstone): 12 Foot-Worn Rounded Limestone Entry Steps
	for s in range(3):
		var sz: float = 2.66 + float(s) * 0.42
		for b in range(4):
			var sx: float = -2.02 + float(b) * 0.46 + (0.06 if (s % 2 == 1) else 0.0)
			var sy: float = get_terrain_height(sx, sz) + 0.14 - float(s) * 0.08
			var sb := Basis().rotated(Vector3.UP, deg_to_rad(float((s * 3 + b) * 23 % 360))).scaled(Vector3(0.72, 0.40, 0.66))
			wall_transforms.append(Transform3D(sb, Vector3(sx, sy, sz)))

	# Type 2 (Masonry Fieldstone): 12-Stone Covenant Altar on north rise (1.0, -4.9)
	for i in range(12):
		var ang: float = float(i) / 12.0 * TAU
		var rx: float = 1.0 + cos(ang) * 1.10
		var rz: float = -4.9 + sin(ang) * 1.10
		var ry: float = get_terrain_height(rx, rz) + 0.18
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.15, 0.92, 1.05))
		wall_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Type 1 (Natural Rounded Cliff Outcrop): Organic Limestone Strata wrapping Altar Hill
	for tier in range(2):
		var ring_r: float = 2.25 + float(tier) * 1.15
		var count_c: int = 16 + tier * 6
		for i in range(count_c):
			var ang: float = float(i) / float(count_c) * TAU + float(tier) * 0.25
			var rx: float = 1.0 + cos(ang) * ring_r * 1.18
			var rz: float = -4.9 + sin(ang) * ring_r * 0.88
			var ry: float = get_terrain_height(rx, rz) + 0.10
			var crag_s: float = 1.35 + float(i % 3) * 0.35
			var b := Basis().rotated(Vector3.UP, ang * 1.7).scaled(Vector3(crag_s, crag_s * 0.82, crag_s * 0.92))
			cliff_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Type 2 (Masonry Fieldstone): Upper-Left & Upper-Right Canaanite Dry-Stone Terrace Walls
	for i in range(22):
		var t_u: float = float(i) / 21.0
		var rx: float = lerpf(-12.5, -2.5, t_u)
		var rz: float = -6.8 - sin(t_u * PI) * 0.9
		var ry: float = get_terrain_height(rx, rz) + 0.14
		var b := Basis().rotated(Vector3.UP, 0.15 + float(i % 2) * 0.1).scaled(Vector3(0.95, 0.66, 0.72))
		wall_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))
	for i in range(18):
		var t_u: float = float(i) / 17.0
		var rx: float = lerpf(4.8, 12.8, t_u)
		var rz: float = -5.4 - t_u * 1.4 + sin(t_u * PI) * 0.6
		var ry: float = get_terrain_height(rx, rz) + 0.14
		var b := Basis().rotated(Vector3.UP, -0.22).scaled(Vector3(0.95, 0.66, 0.72))
		wall_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Type 2 (Masonry Fieldstone): 2-tier hand-laid dry-stone courtyard retaining wall
	for tier in range(2):
		for i in range(44):
			var ang: float = float(i) / 44.0 * TAU
			var rx: float = -1.75 + cos(ang) * 4.55
			var rz: float = 0.25 + sin(ang) * 2.65
			if rz > 2.2 and rx > -2.35 and rx < -0.35:
				continue
			var ry: float = get_terrain_height(rx, rz) + 0.08 + float(tier) * 0.28
			var b := Basis().rotated(Vector3.UP, ang + float(tier) * 0.2).scaled(Vector3(0.98, 0.62, 0.80))
			wall_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	# Type 1 (Natural Rounded Cliff Outcrop): Western spring grotto & hillside outcrops
	for i in range(14):
		var ang: float = float(i) / 14.0 * TAU
		var rx: float = -7.8 + cos(ang) * 2.2
		var rz: float = -1.2 + sin(ang) * 2.0
		var ry: float = get_terrain_height(rx, rz) + 0.18
		var b := Basis().rotated(Vector3.UP, ang).scaled(Vector3(1.25, 0.95, 1.05))
		cliff_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1318
	for _i in range(42):
		var rx: float = rng.randf_range(-14.0, 13.0)
		var rz: float = rng.randf_range(-10.0, 9.0)
		if Vector2(rx + 2.0, rz - 0.2).length() < 5.6:
			continue
		var ry: float = get_terrain_height(rx, rz) + 0.02
		var s: float = rng.randf_range(0.50, 1.30)
		var b := Basis().rotated(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s * 0.60, s * 0.88))
		cliff_transforms.append(Transform3D(b, Vector3(rx, ry, rz)))

	var crng := RandomNumberGenerator.new()
	crng.seed = 4040

	# MultiMesh A: Natural Limestone Cliff Outcrops (1 Draw Call)
	var cliff_mm := MultiMesh.new()
	cliff_mm.transform_format = MultiMesh.TRANSFORM_3D
	cliff_mm.use_colors = true
	cliff_mm.mesh = _make_natural_cliff_rock_mesh(13)
	cliff_mm.instance_count = cliff_transforms.size()
	for i in range(cliff_transforms.size()):
		cliff_mm.set_instance_transform(i, cliff_transforms[i])
		cliff_mm.set_instance_color(i, palette[crng.randi() % palette.size()])
	var cliff_node := MultiMeshInstance3D.new()
	cliff_node.multimesh = cliff_mm
	cliff_node.material_override = cliff_mat
	add_child(cliff_node)

	# MultiMesh B: Hand-Laid Tumbled Limestone Masonry Wall, Altar & Steps (1 Draw Call)
	var wall_mm := MultiMesh.new()
	wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	wall_mm.use_colors = true
	wall_mm.mesh = _make_masonry_wall_stone_mesh(29)
	wall_mm.instance_count = wall_transforms.size()
	for i in range(wall_transforms.size()):
		wall_mm.set_instance_transform(i, wall_transforms[i])
		wall_mm.set_instance_color(i, palette[crng.randi() % palette.size()])
	var wall_node := MultiMeshInstance3D.new()
	wall_node.multimesh = wall_mm
	wall_node.material_override = wall_mat
	add_child(wall_node)


func _build_mobile_hud() -> void:
	var hud: CanvasLayer = $HudLayer

	# Subtle Warm Mediterranean Film Vignette
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_mat := ShaderMaterial.new()
	vig_mat.shader = load("res://shaders/vignette.gdshader")
	vig.material = vig_mat
	hud.add_child(vig)
	hud.move_child(vig, 0)

	# Golden Mediterranean Sunlit Dust Motes drifting across courtyard
	var dust := CPUParticles3D.new()
	dust.position = Vector3(-1.5, 2.2, 0.5)
	dust.amount = 36
	dust.lifetime = 5.5
	dust.preprocess = 2.5
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(8.5, 2.4, 5.5)
	dust.direction = Vector3(0.4, 0.12, 0.2)
	dust.spread = 45.0
	dust.gravity = Vector3(0.0, 0.02, 0.0)
	dust.initial_velocity_min = 0.12
	dust.initial_velocity_max = 0.28
	var d_mesh := SphereMesh.new()
	d_mesh.radius = 0.022
	d_mesh.height = 0.044
	var d_mat := StandardMaterial3D.new()
	d_mat.albedo_color = Color(1.0, 0.92, 0.68, 0.55)
	d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d_mat.emission_enabled = true
	d_mat.emission = Color(1.0, 0.88, 0.55)
	d_mat.emission_energy_multiplier = 1.6
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mesh.material = d_mat
	dust.mesh = d_mesh
	add_child(dust)

	# Luxury Bronze-Bordered Top Resource Pill
	var top_panel := PanelContainer.new()
	top_panel.offset_left = 14.0
	top_panel.offset_top = 10.0
	top_panel.offset_right = 640.0
	top_panel.offset_bottom = 48.0
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.11, 0.08, 0.05, 0.74)
	top_style.border_color = Color(0.76, 0.60, 0.32, 0.85)
	top_style.set_border_width_all(2)
	top_style.set_corner_radius_all(10)
	top_style.content_margin_left = 14.0
	top_style.content_margin_right = 14.0
	top_style.content_margin_top = 4.0
	top_style.content_margin_bottom = 4.0
	top_panel.add_theme_stylebox_override("panel", top_style)
	hud.add_child(top_panel)
	hud.move_child(top_panel, 0)

	metrics_label.offset_left = 26.0
	metrics_label.offset_top = 16.0

	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -290.0
	bar.offset_right = 290.0
	bar.offset_top = -66.0
	bar.offset_bottom = -14.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	hud.add_child(bar)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.10, 0.06, 0.82)
	btn_style.border_color = Color(0.80, 0.64, 0.34, 0.90)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(10)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.22, 0.16, 0.09, 0.92)
	btn_hover.border_color = Color(0.95, 0.78, 0.42, 1.0)

	var actions: Array[Array] = [
		["取水 · 西谷清泉", "water"],
		["筑坛求告 · 创13:4", "pray"],
		["归营 · 主帐", "camp"],
	]
	for act in actions:
		var btn := Button.new()
		btn.text = act[0]
		btn.custom_minimum_size = Vector2(176, 48)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
		var action_key: String = act[1]
		btn.pressed.connect(func() -> void: _trigger_action(action_key))
		bar.add_child(btn)

	status_label = Label.new()
	status_label.offset_left = 18.0
	status_label.offset_top = 52.0
	status_label.offset_right = 820.0
	status_label.offset_bottom = 84.0
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
