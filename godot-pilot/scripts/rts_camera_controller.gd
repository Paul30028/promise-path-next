class_name RTSCameraController
extends Node3D
## Reusable Free 3D RTS Camera: WASD pan, Mouse-wheel zoom (close-up to grand overview),
## Right-drag orbit rotation, Middle-drag pan, and smooth cinematic focus_on().

@export var min_distance: float = 6.5
@export var max_distance: float = 58.0
@export var pan_speed: float = 24.0
@export var zoom_speed: float = 3.0
@export var orbit_sensitivity: float = 0.0055
@export var bounds_xz: Rect2 = Rect2(-46.0, -38.0, 92.0, 82.0)

var free_pan_enabled: bool = false
var pitch_override: float = NAN

var target_focus: Vector3 = Vector3(0.0, 1.0, 2.0)
var target_distance: float = 28.0
var target_yaw: float = -0.46
var target_pitch: float = -0.62

var current_distance: float = 28.0
var current_yaw: float = -0.46
var current_pitch: float = -0.62

var camera: Camera3D
var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "RTSCamera3D"
	camera.fov = 40.0
	camera.near = 0.25
	camera.far = 320.0
	add_child(camera)
	camera.current = true
	position = target_focus
	_apply_camera_transform()


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
		current_pitch = _pitch_for_distance(current_distance)
		_apply_camera_transform()


func _pitch_for_distance(dist: float) -> float:
	var t: float = clampf((dist - min_distance) / maxf(max_distance - min_distance, 1.0), 0.0, 1.0)
	return lerpf(-0.46, -0.78, t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			target_distance = clampf(target_distance - zoom_speed, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			target_distance = clampf(target_distance + zoom_speed, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
			_last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_last_mouse = mb.position
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		var rel: Vector2 = mm.position - _last_mouse
		_last_mouse = mm.position
		if _orbiting:
			target_yaw -= rel.x * orbit_sensitivity
		elif _panning:
			var scale: float = current_distance * 0.0022
			var right: Vector3 = Vector3(cos(current_yaw), 0.0, -sin(current_yaw))
			var fwd: Vector3 = Vector3(-sin(current_yaw), 0.0, -cos(current_yaw))
			target_focus -= right * rel.x * scale
			target_focus += fwd * rel.y * scale
			_clamp_focus()


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		target_yaw += delta * 1.15
	if Input.is_key_pressed(KEY_E):
		pass
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
	var horiz: float = cos(-current_pitch) * current_distance
	var vert: float = sin(-current_pitch) * current_distance
	var offset: Vector3 = Vector3(sin(current_yaw) * horiz, vert, cos(current_yaw) * horiz)
	camera.position = offset
	camera.look_at(global_position, Vector3.UP)
