class_name WorldPhysicsBuilder
extends RefCounted
## Builds solid 5-Layer 3D Physics bodies & Interior Acoustic Zones for any chapter world:
## - Layer 1 (1): TerrainGround (`ConcavePolygonShape3D` from generated heightfield mesh)
## - Layer 2 (2): ArkAndStructures (solid `BoxShape3D` compound collider for 3-deck Ark, stairs, gangplank, walls & tents)
## - Layer 5 (16): InteractAreas (`ArkInteriorAcousticZone` auto-switching `SoundManager` LowPass + Cedar Reverb)


static func attach_terrain_collider(terrain_mi: MeshInstance3D) -> StaticBody3D:
	if terrain_mi == null or terrain_mi.mesh == null:
		return null
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "TerrainStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = terrain_mi.mesh.create_trimesh_shape()
	sb.add_child(cs)
	terrain_mi.add_child(sb)
	return sb


static func _add_box_shape(sb: StaticBody3D, extents: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = extents
	cs.shape = bs
	cs.position = pos
	cs.rotation_degrees = rot_deg
	sb.add_child(cs)
	return cs


static func build_ark_walkable_collider(ark_anchor: Node3D) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "ArkWalkableStaticBody"
	sb.collision_layer = 2
	sb.collision_mask = 0
	var L: float = 102.0
	var W: float = 17.0
	var HW: float = W * 0.5

	# Deck 1 floor (top Y = 0.65)
	_add_box_shape(sb, Vector3(L - 3.0, 0.24, W - 2.6), Vector3(0.0, 0.53, 0.0))

	# Deck 2 floor (top Y = 3.95) with North Stair 1 opening (X in [2.0..14.0], Z in [-3.2..-1.15])
	_add_box_shape(sb, Vector3(52.5, 0.24, W - 1.6), Vector3(-24.25, 3.83, 0.0))
	_add_box_shape(sb, Vector3(36.5, 0.24, W - 1.6), Vector3(32.25, 3.83, 0.0))
	_add_box_shape(sb, Vector3(12.2, 0.24, 4.5), Vector3(8.0, 3.83, -5.45))
	_add_box_shape(sb, Vector3(12.2, 0.24, 8.85), Vector3(8.0, 3.83, 3.275))

	# Deck 3 floor (top Y = 7.15) with North Stair 2 opening (X in [18.0..30.0], Z in [-3.2..-1.15])
	_add_box_shape(sb, Vector3(68.5, 0.24, W - 1.4), Vector3(-16.25, 7.03, 0.0))
	_add_box_shape(sb, Vector3(20.5, 0.24, W - 1.4), Vector3(40.25, 7.03, 0.0))
	_add_box_shape(sb, Vector3(12.2, 0.24, 4.5), Vector3(24.0, 7.03, -5.45))
	_add_box_shape(sb, Vector3(12.2, 0.24, 8.85), Vector3(24.0, 7.03, 3.275))

	# Smooth sloped collision ramps for North Stair 1 & North Stair 2
	_add_box_shape(sb, Vector3(11.5, 0.22, 1.90), Vector3(8.0, 2.30, -2.15), Vector3(0.0, 0.0, 16.7))
	_add_box_shape(sb, Vector3(11.5, 0.22, 1.90), Vector3(24.0, 5.55, -2.15), Vector3(0.0, 0.0, 16.2))

	# Exterior Boarding Gangplank Ramp (+Z doorway Z=8.5 Y=0.65 -> Z=19.8 Y=-0.90)
	var ramp_cs: CollisionShape3D = _add_box_shape(sb, Vector3(4.9, 0.26, 11.8), Vector3(0.0, -0.12, HW + 5.6), Vector3(7.8, 0.0, 0.0))
	ramp_cs.name = "GangplankRampCollider"

	# Outer Hull Walls (with +Z Side Doorway opening X in [-2.6, +2.6]!)
	_add_box_shape(sb, Vector3(L - 2.0, 9.4, 0.48), Vector3(0.0, 4.8, -HW + 0.25))
	_add_box_shape(sb, Vector3(46.2, 9.4, 0.48), Vector3(-26.0, 4.8, HW - 0.25))
	_add_box_shape(sb, Vector3(46.2, 9.4, 0.48), Vector3(26.0, 4.8, HW - 0.25))
	_add_box_shape(sb, Vector3(0.55, 9.4, W - 1.0), Vector3(-49.2, 4.8, 0.0))
	_add_box_shape(sb, Vector3(0.55, 9.4, W - 1.0), Vector3(49.2, 4.8, 0.0))

	# Stall Corral Rail Blockers along central aisle (leaving North stair entries & +Z foyer clear!)
	_add_box_shape(sb, Vector3(42.0, 1.5, 0.24), Vector3(-24.0, 1.4, -3.25))
	_add_box_shape(sb, Vector3(42.0, 1.5, 0.24), Vector3(-24.0, 1.4, 3.25))
	_add_box_shape(sb, Vector3(42.0, 1.5, 0.24), Vector3(24.0, 1.4, 3.25))

	ark_anchor.add_child(sb)
	return sb


static func build_interior_acoustic_zone(parent: Node3D, box_size: Vector3, local_pos: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "InteriorAcousticZone"
	area.collision_layer = 16
	area.collision_mask = 4  # Detects PatriarchPlayer3D (Layer 3 = bit 4)
	area.position = local_pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = box_size
	cs.shape = bs
	area.add_child(cs)
	parent.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is PatriarchPlayer3D:
			var sm: Node = area.get_node_or_null("/root/SoundManager")
			if sm != null and sm.has_method("set_interior_acoustics"):
				sm.call("set_interior_acoustics", true)
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is PatriarchPlayer3D:
			var sm: Node = area.get_node_or_null("/root/SoundManager")
			if sm != null and sm.has_method("set_interior_acoustics"):
				sm.call("set_interior_acoustics", false)
	)
	return area
