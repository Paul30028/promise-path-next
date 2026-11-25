class_name PatriarchPlayer3D
extends CharacterBody3D
## Reusable Physics-Backed Patriarch / Hero Controller (Ch00 Noah, Ch01 Abram, Ch02-Ch11 Leaders):
## - Layer 3 (Actors), collides with Layer 1 (TerrainGround) & Layer 2 (ArkAndStructures)
## - Smoothly climbs 46-degree stairs, gangplanks & highland terraces via move_and_slide() + floor_snap
## - Supports WASD / Virtual Joystick + Click-to-Walk + First-Person CS2 eye tracking!

var visual_model: Node3D
var walk_speed: float = 4.3
var sprint_speed: float = 7.4
var gravity_accel: float = 22.0
var click_target: Vector3 = Vector3.ZERO
var has_click_target: bool = false
var busy_timer: float = 0.0
var busy_clip: String = "Idle"
var current_deck_hint: int = 0


func setup_capsule(height: float = 1.72, radius: float = 0.36) -> void:
	collision_layer = 4          # Bit 3: Actors
	collision_mask = 1 | 2       # Collides with TerrainGround (1) + ArkAndStructures (2)
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.42
	wall_min_slide_angle = deg_to_rad(12.0)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "HeroCapsule"
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.2)
	col.shape = cap
	col.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(col)


func attach_visual(model: Node3D) -> void:
	visual_model = model
	if model.get_parent() != null:
		model.reparent(self, false)
	else:
		add_child(model)
	model.position = Vector3.ZERO


func warp_to(world_pos: Vector3) -> void:
	global_position = world_pos
	velocity = Vector3.ZERO
	has_click_target = false


func step_movement(delta: float, wish_dir: Vector3, is_sprinting: bool, speed_mul: float = 1.0) -> String:
	if not is_on_floor():
		velocity.y -= gravity_accel * delta
	else:
		velocity.y = -0.5

	var active_clip: String = "Idle"
	if wish_dir.length_squared() > 0.01:
		has_click_target = false
		busy_timer = 0.0
		var dir: Vector3 = wish_dir.normalized()
		var spd: float = (sprint_speed if is_sprinting else walk_speed) * speed_mul
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if visual_model != null:
			visual_model.look_at(global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
		active_clip = "Run" if is_sprinting else "Walk"
	elif has_click_target:
		var flat: Vector3 = Vector3(click_target.x - global_position.x, 0.0, click_target.z - global_position.z)
		if flat.length() < 0.58:
			has_click_target = false
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var dir2: Vector3 = flat.normalized()
			var spd2: float = walk_speed * 1.04 * speed_mul
			velocity.x = dir2.x * spd2
			velocity.z = dir2.z * spd2
			if visual_model != null:
				visual_model.look_at(global_position + dir2, Vector3.UP)
			active_clip = "Walk"
	else:
		velocity.x = move_toward(velocity.x, 0.0, 28.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 28.0 * delta)
		if busy_timer > 0.0:
			busy_timer -= delta
			active_clip = busy_clip

	move_and_slide()
	if global_position.y > 6.0:
		current_deck_hint = 2
	elif global_position.y > 2.8:
		current_deck_hint = 1
	else:
		current_deck_hint = 0
	return active_clip
