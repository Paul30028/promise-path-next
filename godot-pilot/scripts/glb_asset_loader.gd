class_name GlbAssetLoader
extends RefCounted

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	for k in _cache.keys():
		var n: Node = _cache[k]
		if is_instance_valid(n):
			n.free()
	_cache.clear()


static func _compute_combined_aabb(node: Node3D, root_inv: Transform3D) -> AABB:
	var combined := AABB()
	var has_any := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var local_aabb: AABB = mi.mesh.get_aabb()
				var rel_xf: Transform3D = root_inv * mi.global_transform
				var transformed: AABB = rel_xf * local_aabb
				if not has_any:
					combined = transformed
					has_any = true
				else:
					combined = combined.merge(transformed)
		for child in cur.get_children():
			stack.append(child)
	return combined


static func _compute_local_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var has_any := false
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var cur: Node = pair[0]
		var xf: Transform3D = pair[1]
		if cur is Node3D and cur != node:
			xf = xf * (cur as Node3D).transform
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var local_aabb: AABB = mi.mesh.get_aabb()
				var transformed: AABB = xf * local_aabb
				if not has_any:
					combined = transformed
					has_any = true
				else:
					combined = combined.merge(transformed)
		for child in cur.get_children():
			stack.append([child, xf])
	return combined


static func _tune_materials(root: Node, roughness_min: float = 0.62, albedo_boost: Color = Color(1.15, 1.12, 1.06)) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.get_active_material(s)
					var sm: StandardMaterial3D = null
					if mat is StandardMaterial3D:
						sm = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					else:
						sm = StandardMaterial3D.new()
					sm.roughness = maxf(sm.roughness, roughness_min)
					sm.metallic = minf(sm.metallic, 0.08)
					sm.cull_mode = BaseMaterial3D.CULL_DISABLED
					var fmt: int = mi.mesh.surface_get_format(s)
					if (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0 and sm.albedo_texture == null:
						sm.vertex_color_use_as_albedo = true
					sm.albedo_color = albedo_boost
					mi.set_surface_override_material(s, sm)
		for child in cur.get_children():
			stack.append(child)


static func load_glb_instance(
	res_path: String,
	target_height: float,
	rot_deg: Vector3 = Vector3.ZERO,
	y_sink: float = 0.0,
	roughness_min: float = 0.62,
	albedo_boost: Color = Color(1.15, 1.12, 1.06)
) -> Node3D:
	if not FileAccess.file_exists(res_path):
		return null

	var proto: Node3D = null
	if _cache.has(res_path):
		proto = _cache[res_path]
	else:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if bytes.is_empty():
			return null
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var err: int = gltf.append_from_buffer(bytes, "", state)
		if err != OK:
			push_warning("GlbAssetLoader: failed to parse %s (err=%d)" % [res_path, err])
			return null
		var scene_node: Node = gltf.generate_scene(state)
		if scene_node == null or not (scene_node is Node3D):
			return null
		proto = scene_node as Node3D
		_cache[res_path] = proto

	var inst: Node3D = proto.duplicate() as Node3D
	_tune_materials(inst, roughness_min, albedo_boost)

	var aabb: AABB = _compute_local_aabb(inst)
	var wrapper := Node3D.new()
	wrapper.name = res_path.get_file().get_basename()

	if aabb.size.y > 0.0001:
		var scale_f: float = target_height / aabb.size.y
		inst.scale = Vector3(scale_f, scale_f, scale_f)
		var center_xz := Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5
		)
		inst.position = Vector3(
			-center_xz.x * scale_f,
			-center_xz.y * scale_f - y_sink,
			-center_xz.z * scale_f
		)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation_degrees = rot_deg
	pivot.add_child(inst)
	wrapper.add_child(pivot)
	return wrapper


static func extract_first_mesh_data(res_path: String, roughness_min: float = 0.82, albedo_boost: Color = Color(1.08, 1.06, 1.02)) -> Dictionary:
	# Extracts Mesh, tuned Material, and normalized AABB for 1-Draw-Call MultiMesh instancing!
	var node: Node3D = load_glb_instance(res_path, 1.0, Vector3.ZERO, 0.0, roughness_min, albedo_boost)
	if node == null:
		return {}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var mat: Material = mi.get_surface_override_material(0)
				if mat == null:
					mat = mi.get_active_material(0)
				var aabb: AABB = mi.mesh.get_aabb()
				var res := {
					"mesh": mi.mesh,
					"material": mat,
					"aabb": aabb,
				}
				node.free()
				return res
		for child in cur.get_children():
			stack.append(child)
	node.free()
	return {}
