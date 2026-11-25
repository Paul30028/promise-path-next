class_name RTSCameraController
extends Node3D
## Universal 3-Modal Camera Rig (RTS Tactical Overview <-> 3P Anti-Clip Hero Follow <-> CS2 1P Oil-Lamp):
## - Instantiates `res://scenes/prefabs/fp_oil_lamp.tscn` with spatial wick-crackle audio
## - Physics ray spring-arm anti-wall-clipping on Layer 2 (`ArkAndStructures`) during close 3P follow
## - Supports Mouse-Captured 1P look, Right-Drag 3P orbit, AND Right-Half Touchscreen Drag on Mobile!

const LAMP_PREFAB: PackedScene = preload("res://scenes/prefabs/fp_oil_lamp.tscn")

@export var min_distance: float = 7.5
@export var max_distance: float = 115.0
@export var pan_speed: float = 34.0
@export var zoom_speed: float = 5.5
@export var orbit_sensitivity: float = 0.0055
@export var bounds_xz: Rect2 = Rect2(-95.0, -75.0, 190.0, 165.0)

var free_pan_enabled: bool = false
var pitch_override: float = NAN
var first_person_mode: bool = false
var fp_eye_pos: Vector3 = Vector3.ZERO
var fp_yaw: float = 0.0
var fp_pitch: float = -0.05
var fp_move_intensity: float = 0.0
var fp_head_bob_enabled: bool = true
var trauma: float = 0.0

var target_focus: Vector3 = Vector3(0.0, 1.0, 2.0)
var target_distance: float = 28.0
var target_yaw: float = -0.46
var target_pitch: float = -0.62

var current_distance: float = 28.0
var current_yaw: float = -0.46
var current_pitch: float = -0.62

var camera: Camera3D
var fp_oil_lamp: Node3D
var fp_lamp_light: OmniLight3D
var fp_lamp_audio: AudioStreamPlayer3D
var _lamp_time: float = 0.0
var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	var sv_node: Node = get_node_or_null("/root/SaveManager") if is_inside_tree() else null
	if sv_node != null and sv_node.get("head_bob_enabled") != null:
		fp_head_bob_enabled = bool(sv_node.get("head_bob_enabled"))
	camera = Camera3D.new()
	camera.name = "RTSCamera3D"
	camera.fov = 42.0
	camera.near = 0.14
	camera.far = 520.0
	add_child(camera)
	camera.current = true
	camera.rotation_order = EULER_ORDER_YXZ
	_build_fp_oil_lamp()
	position = target_focus
	_apply_camera_transform()


func _build_fp_oil_lamp() -> void:
	fp_oil_lamp = LAMP_PREFAB.instantiate() as Node3D
	camera.add_child(fp_oil_lamp)
	fp_lamp_light = fp_oil_lamp.get_node_or_null("LampLight") as OmniLight3D
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	if sm_node != null and sm_node.has_method("make_spatial_loop_3d"):
		fp_lamp_audio = sm_node.call("make_spatial_loop_3d", "sfx_oil_lamp_crackle.wav", Vector3(0, 0.04, -0.06), 4.0, -16.0, true) as AudioStreamPlayer3D
		if fp_lamp_audio != null:
			fp_lamp_audio.autoplay = false
			fp_oil_lamp.add_child(fp_lamp_audio)
	fp_oil_lamp.hide()


func set_first_person(enabled: bool, is_preview: bool = false) -> void:
	first_person_mode = enabled
	if fp_oil_lamp != null:
		fp_oil_lamp.visible = enabled
	if fp_lamp_audio != null:
		if enabled and not fp_lamp_audio.playing:
			fp_lamp_audio.play()
		elif not enabled and fp_lamp_audio.playing:
			fp_lamp_audio.stop()
	if not is_preview and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	if sm_node != null and sm_node.has_method("set_interior_acoustics"):
		sm_node.call("set_interior_acoustics", enabled)


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func focus_on(pos: Vector3, distance: float = -1.0, yaw: float = NAN, instant: bool = false) -> void:
	target_focus = Vector3(
		clampf(pos.x, bounds_xz.position.x, bounds_xz.end.x),
		pos.y,
		clampf(pos.z, bounds_xz.position.y, bounds_xz.end.y)
	)
	if distance > 0.0:
		target_distance = clampf(distance, min_distance, max_distance)
	if not is_nan(yaw):
		target_yaw = yaw
	if instant:
		position = target_focus
		current_distance = target_distance
		current_yaw = target_yaw
		current_pitch = pitch_override if not is_nan(pitch_override) else _pitch_for_distance(current_distance)
		_apply_camera_transform()


func _pitch_for_distance(dist: float) -> float:
	var t: float = clampf((dist - min_distance) / maxf(max_distance - min_distance, 1.0), 0.0, 1.0)
	return lerpf(-0.46, -0.78, t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		var vp_w: float = get_viewport().get_visible_rect().size.x
		# Right half of touchscreen rotates camera smoothly in both 1P and 3P!
		if sd.position.x >= vp_w * 0.42:
			if first_person_mode:
				fp_yaw = wrapf(fp_yaw - sd.relative.x * orbit_sensitivity * 1.35, -PI, PI)
				fp_pitch = clampf(fp_pitch - sd.relative.y * orbit_sensitivity * 1.05, -1.22, 1.25)
			else:
				target_yaw -= sd.relative.x * orbit_sensitivity
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and not first_person_mode:
			target_distance = clampf(target_distance - zoom_speed * maxf(target_distance * 0.08, 1.0), min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and not first_person_mode:
			target_distance = clampf(target_distance + zoom_speed * maxf(target_distance * 0.08, 1.0), min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or (first_person_mode and mb.button_index == MOUSE_BUTTON_LEFT):
			_orbiting = mb.pressed
			_last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and not first_person_mode:
			_panning = mb.pressed
			_last_mouse = mb.position
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		var rel: Vector2 = mm.relative if mm.relative.length_squared() > 0.0 else (mm.position - _last_mouse)
		_last_mouse = mm.position
		if _orbiting or (first_person_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
			if first_person_mode:
				fp_yaw = wrapf(fp_yaw - rel.x * orbit_sensitivity * 1.45, -PI, PI)
				fp_pitch = clampf(fp_pitch - rel.y * orbit_sensitivity * 1.15, -1.22, 1.25)
			else:
				target_yaw -= rel.x * orbit_sensitivity
		elif _panning:
			var sc: float = current_distance * 0.0022
			var right: Vector3 = Vector3(cos(current_yaw), 0.0, -sin(current_yaw))
			var fwd: Vector3 = Vector3(-sin(current_yaw), 0.0, -cos(current_yaw))
			target_focus -= right * rel.x * sc
			target_focus += fwd * rel.y * sc
			_clamp_focus()


func _process(delta: float) -> void:
	_lamp_time += delta
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 2.2)
	if first_person_mode:
		if DisplayServer.get_name() != "headless":
			if Input.is_key_pressed(KEY_ALT):
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
			fp_yaw = wrapf(fp_yaw + delta * 2.1, -PI, PI)
		if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_RIGHT):
			fp_yaw = wrapf(fp_yaw - delta * 2.1, -PI, PI)
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_PAGEUP):
			fp_pitch = clampf(fp_pitch + delta * 1.35, -1.22, 1.25)
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_PAGEDOWN):
			fp_pitch = clampf(fp_pitch - delta * 1.35, -1.22, 1.25)
		if fp_oil_lamp != null:
			fp_oil_lamp.visible = true
			var bob_mul: float = (0.35 + fp_move_intensity * 0.85) if fp_head_bob_enabled else 0.0
			fp_oil_lamp.position = Vector3(
				0.34 + sin(_lamp_time * 4.8) * 0.012 * bob_mul,
				-0.22 + absf(cos(_lamp_time * 4.8)) * 0.015 * bob_mul,
				-0.58
			)
			if fp_lamp_light != null:
				fp_lamp_light.light_energy = 1.75 + sin(_lamp_time * 13.0) * 0.14 + cos(_lamp_time * 7.3) * 0.09
		_apply_camera_transform()
		return

	if Input.is_key_pressed(KEY_Q):
		target_yaw += delta * 1.15
	if free_pan_enabled:
		var move: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y -= 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1.0
		if move.length_squared() > 0.0:
			move = move.normalized()
			var right: Vector3 = Vector3(cos(current_yaw), 0.0, -sin(current_yaw))
			var fwd: Vector3 = Vector3(-sin(current_yaw), 0.0, -cos(current_yaw))
			var speed_mul: float = lerpf(0.65, 1.85, (current_distance - min_distance) / maxf(max_distance - min_distance, 1.0))
			target_focus += (right * move.x + fwd * move.y) * pan_speed * speed_mul * delta
			_clamp_focus()

	var k: float = 1.0 - exp(-delta * 7.5)
	position = position.lerp(target_focus, k)
	current_distance = lerpf(current_distance, target_distance, k)
	current_yaw = lerpf(current_yaw, target_yaw, k)
	target_pitch = pitch_override if not is_nan(pitch_override) else _pitch_for_distance(target_distance)
	current_pitch = lerpf(current_pitch, target_pitch, k)
	_apply_camera_transform()


func _clamp_focus() -> void:
	target_focus.x = clampf(target_focus.x, bounds_xz.position.x, bounds_xz.end.x)
	target_focus.z = clampf(target_focus.z, bounds_xz.position.y, bounds_xz.end.y)


func _apply_camera_transform() -> void:
	if camera == null:
		return
	if first_person_mode:
		camera.fov = lerpf(camera.fov, 64.0, 0.22)
		global_position = fp_eye_pos
		camera.position = Vector3.ZERO
		camera.rotation = Vector3(fp_pitch, fp_yaw, 0.0)
		return
	camera.fov = lerpf(camera.fov, 40.0, 0.22)
	var eff_dist: float = current_distance
	var horiz: float = cos(-current_pitch) * eff_dist
	var vert: float = sin(-current_pitch) * eff_dist
	var offset: Vector3 = Vector3(sin(current_yaw) * horiz, vert, cos(current_yaw) * horiz)

	# Spring-Arm Physics Anti-Clip Raycast on Layer 2 (ArkAndStructures) during close 3P follow!
	if is_inside_tree() and not free_pan_enabled and current_distance < 26.0:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + offset, 2)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit["position"]
				var safe_len: float = maxf(2.5, global_position.distance_to(hit_pos) - 0.45)
				offset = offset.normalized() * safe_len

	var shake: Vector3 = Vector3.ZERO
	if trauma > 0.001:
		var s2: float = trauma * trauma * 0.35
		shake = Vector3(sin(_lamp_time * 47.0) * s2, cos(_lamp_time * 53.0) * s2, 0.0)
	camera.position = offset + shake
	camera.look_at(global_position, Vector3.UP)
