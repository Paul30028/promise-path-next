extends Control
## Commercial Parchment Main Menu — unified entry into Season 1 Campaign (Ch00 -> Overworld -> Ch01).

var continue_btn: Button
var status_lbl: Label


func _ready() -> void:
	_build_menu_ui()


func _style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _make_btn(label: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(340, 50)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	var bg: Color = Color(0.28, 0.20, 0.09, 0.94) if primary else Color(0.12, 0.09, 0.06, 0.88)
	var bd: Color = Color(0.95, 0.78, 0.40) if primary else Color(0.72, 0.56, 0.30, 0.85)
	b.add_theme_stylebox_override("normal", _style(bg, bd, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.14), Color(1.0, 0.88, 0.54), 8))
	b.pressed.connect(cb)
	return b


func _build_menu_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_tex := TextureRect.new()
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var map_tex: Texture2D = load("res://assets/overworld/world-map-scroll-final.png") as Texture2D
	if map_tex != null:
		bg_tex.texture = map_tex
	add_child(bg_tex)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.03, 0.58)
	add_child(shade)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 480)
	card.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.92), Color(0.86, 0.68, 0.36), 14))
	cc.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var title := Label.new()
	title.text = "应 许 之 路"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.99, 0.86, 0.52))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "PATH OF PROMISE  ·  圣经历史策略叙事史诗（第一季）"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	vb.add_child(sub)

	continue_btn = _make_btn("继续立约之旅（读取存档）", true, _on_continue)
	continue_btn.visible = SaveManager.first_existing_slot() >= 0
	vb.add_child(continue_btn)

	vb.add_child(_make_btn("序章 · 诺亚方舟与彩虹之约（创 6–9）", not continue_btn.visible, func() -> void:
		SceneTransition.change_scene("res://scenes/ch00_noah_ark.tscn")
	))
	vb.add_child(_make_btn("宏观战役画卷 · 巴别与出吾珥（P01）", false, func() -> void:
		SceneTransition.change_scene("res://scenes/overworld_prologue.tscn")
	))
	vb.add_child(_make_btn("第一章 · 伯特利与艾城筑坛（创 13）", false, func() -> void:
		SceneTransition.change_scene("res://scenes/camp_pilot.tscn")
	))
	vb.add_child(_make_btn("静音 / 防晕3D开关", false, _toggle_comfort))
	vb.add_child(_make_btn("退出游戏", false, func() -> void: get_tree().quit()))

	status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	_update_status()
	vb.add_child(status_lbl)


func _on_continue() -> void:
	var s: int = SaveManager.first_existing_slot()
	if s < 0:
		s = 1
	var d: Dictionary = SaveManager.load_slot(s)
	SaveManager.pending_load_slot = s
	var ch_id: String = str(d.get("chapter_id", "ch00_noah_ark"))
	var target: String = "res://scenes/overworld_prologue.tscn" if ch_id == "overworld_prologue" else str(d.get("currentScene", "res://scenes/ch00_noah_ark.tscn"))
	SceneTransition.change_scene(target)


func _toggle_comfort() -> void:
	SaveManager.head_bob_enabled = not SaveManager.head_bob_enabled
	SaveManager.save_settings()
	SoundManager.play_sfx("sfx_ui_click.wav", -5.0)
	_update_status()


func _update_status() -> void:
	var bob_txt: String = "开启" if SaveManager.head_bob_enabled else "关闭（防晕3D）"
	status_lbl.text = "第一人称步伐晃动：%s  |  Godot 4.7.2 · MIT / CC0 合规版" % bob_txt
