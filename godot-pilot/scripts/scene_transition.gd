extends CanvasLayer
## Threaded AsyncSceneLoader & Parchment Curtain Autoload:
## Uses `ResourceLoader.load_threaded_request` with live progress gauge so large 3D chapters never freeze the main thread!

var _rect: ColorRect
var _card: CenterContainer
var _lbl: Label
var _bar: ProgressBar
var _busy: bool = false
var _target_path: String = ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.05, 0.04, 0.03, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_card = CenterContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.hide()
	add_child(_card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 72)
	vb.add_theme_constant_override("separation", 10)
	_card.add_child(vb)

	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	_lbl.add_theme_font_size_override("font_size", 16)
	_lbl.text = "正在展开立约长卷..."
	vb.add_child(_lbl)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(340, 14)
	_bar.max_value = 100.0
	_bar.show_percentage = false
	vb.add_child(_bar)
	set_process(false)


func change_scene(scene_path: String, fade_time: float = 0.35) -> void:
	if _busy or scene_path.is_empty():
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var t1: Tween = create_tween()
	t1.tween_property(_rect, "color:a", 1.0, fade_time)
	await t1.finished

	_lbl.text = tr("UI_LOADING_SCROLL") if tr("UI_LOADING_SCROLL") != "UI_LOADING_SCROLL" else "正在展开立约长卷..."
	_bar.value = 10.0
	_card.show()

	var err: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		get_tree().change_scene_to_file(scene_path)
		await _finish_fade_in(fade_time)
		return

	_target_path = scene_path
	set_process(true)


func _process(_delta: float) -> void:
	if _target_path.is_empty():
		set_process(false)
		return
	var prog: Array = []
	var st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_path, prog)
	if prog.size() > 0:
		_bar.value = clampf(float(prog[0]) * 100.0, 5.0, 99.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: PackedScene = ResourceLoader.load_threaded_get(_target_path) as PackedScene
		var fallback: String = _target_path
		_target_path = ""
		set_process(false)
		_bar.value = 100.0
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(fallback)
		_finish_fade_in(0.35)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var fb: String = _target_path
		_target_path = ""
		set_process(false)
		get_tree().change_scene_to_file(fb)
		_finish_fade_in(0.35)


func _finish_fade_in(fade_time: float) -> void:
	await get_tree().process_frame
	_card.hide()
	var t2: Tween = create_tween()
	t2.tween_property(_rect, "color:a", 0.0, fade_time)
	await t2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
