extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var abram: Node3D = $Abram
@onready var metrics_label: Label = $HudLayer/MetricsLabel

var target_pos: Vector3 = Vector3(-1.5, 0.0, 2.2)
var move_speed: float = 4.2
var dragging: bool = false
var drag_distance: float = 0.0
var last_pointer_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	target_pos = abram.global_position


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
		target_pos = Vector3(clamp(p.x, -28.0, 28.0), 0.0, clamp(p.z, -20.0, 20.0))


func _process(delta: float) -> void:
	var to_target := target_pos - abram.global_position
	to_target.y = 0.0
	if to_target.length() > 0.12:
		var step := to_target.normalized() * minf(move_speed * delta, to_target.length())
		abram.global_position += step
		abram.look_at(abram.global_position + to_target.normalized(), Vector3.UP)

	var fps := Engine.get_frames_per_second()
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	metrics_label.text = "Godot 4 Pilot | FPS: %d | Draw Calls: %d | Static Mem: %.1f MB | Tap ground to move Abram" % [fps, int(draw_calls), mem_mb]
