class_name GlbAssetLoader
extends RefCounted

static var _cache: Dictionary = {}


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


static func _tune_materials(root: Node, roughness_min: float = 0.62) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.get_active_material(s)
					if mat is StandardMaterial3D:
						var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						sm.roughness = maxf(sm.roughness, roughness_min)
						sm.metallic = minf(sm.metallic, 0.12)
						sm.cull_mode = BaseMaterial3D.CULL_DISABLED
						mi.set_surface_override_material(s, sm)
		for child in cur.get_children():
			stack.append(child)


static func load_glb_instance(
	res_path: String,
	target_height: float,
	rot_y_deg: float = 0.0,
	y_sink: float = 0.0,
	roughness_min: float = 0.62
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
	_tune_materials(inst, roughness_min)

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
	pivot.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	pivot.add_child(inst)
	wrapper.add_child(pivot)
	return wrapper
