extends CanvasLayer
## Global SceneTransition Autoload (inspired by Scene Manager Tool):
## Smooth parchment-dark fade between scenes with double-click lock so rapid clicks never double-load!

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.05, 0.04, 0.03, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func change_scene(scene_path: String, fade_time: float = 0.45) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t1: Tween = create_tween()
	t1.tween_property(_rect, "color:a", 1.0, fade_time)
	await t1.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var t2: Tween = create_tween()
	t2.tween_property(_rect, "color:a", 0.0, fade_time)
	await t2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
