extends Node2D
## V6 Campaign Overworld Scroll Engine (`B01 -> P01 -> B02`):
## - Reads Noah's `noah_harmony_bonus` from `SaveManager.carryover_ledger` & displays Covenant Stone #1
## - Full `zh_CN / en_US` bilingual switch + atomic auto-save + threaded transition into `Ch01 Bethel`!

@onready var map_sprite: Sprite2D = $MapLayer/MapSprite
@onready var trail_line: Line2D = $MapLayer/TrailLine
@onready var waypoints_root: Node2D = $MapLayer/WaypointsRoot
@onready var camera: Camera2D = $Camera2D
@onready var hud_layer: CanvasLayer = $HudLayer

const EVENT_MAP_COORDS := {
	"b01_babel_shem": Vector2(1118.0, 82.0),
	"p01_leave_ur": Vector2(1210.0, 128.0),
	"p01_haran_call": Vector2(1015.0, 148.0),
	"p01_shechem_bethel": Vector2(688.0, 342.0),
	"b02_egypt_return": Vector2(258.0, 545.0),
}

const EVENT_PLATES := {
	"b01_babel_shem": "res://assets/overworld/B01_babel_shem_final.png",
	"p01_leave_ur": "res://assets/overworld/P01_leave_ur_haran_final.png",
	"p01_haran_call": "res://assets/overworld/P01_leave_ur_haran_final.png",
	"p01_shechem_bethel": "res://assets/overworld/level01-128x96-7zone-final.png",
	"b02_egypt_return": "res://assets/overworld/B02_egypt_return_final.png",
}

var prologue_data: Dictionary = {}
var events_by_id: Dictionary = {}
var event_order: Array[String] = []
var current_event_id: String = ""
var visited_points: PackedVector2Array = PackedVector2Array()
var active_beacon: Polygon2D = null
var beacon_pulse_time: float = 0.0
var cam_tween: Tween = null

var header_label: Label
var lang_btn: Button
var menu_btn: Button
var plate_rect: TextureRect
var title_label: Label
var ref_label: Label
var body_label: Label
var carryover_label: Label
var choices_box: VBoxContainer
var step_buttons: Dictionary = {}


func _ready() -> void:
	SaveManager.ensure_translations_loaded()
	for arg in OS.get_cmdline_user_args():
		if arg == "--zh-preview": SaveManager.set_locale("zh_CN")
	RenderingServer.set_default_clear_color(Color(0.84, 0.76, 0.58))
	var tex: Texture2D = load("res://assets/overworld/world-map-scroll-final.png") as Texture2D
	if tex != null:
		map_sprite.texture = tex
	_load_json()
	_build_waypoints()
	_build_v3_hud()
	if not current_event_id.is_empty():
		_show_event(current_event_id, false)


func _process(delta: float) -> void:
	beacon_pulse_time += delta
	if active_beacon != null:
		var s: float = 1.0 + sin(beacon_pulse_time * 4.2) * 0.18
		active_beacon.scale = Vector2(s, s)


func _load_json() -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/ch00_ur_call.json")
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		prologue_data = parsed
		for ev in prologue_data.get("events", []):
			var eid: String = str(ev.get("id", ""))
			events_by_id[eid] = ev
			event_order.append(eid)
		current_event_id = str(prologue_data.get("firstEventId", "b01_babel_shem"))


func _style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _make_btn(txt: String, cb: Callable, min_w: float = 110.0) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(min_w, 44.0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.99, 0.94, 0.82))
	b.add_theme_stylebox_override("normal", _style(Color(0.16, 0.11, 0.06, 0.92), Color(0.84, 0.66, 0.34), 8))
	b.add_theme_stylebox_override("hover", _style(Color(0.28, 0.20, 0.10, 0.98), Color(1.0, 0.86, 0.50), 8))
	b.pressed.connect(cb)
	return b


func _build_waypoints() -> void:
	for eid in event_order:
		var pt: Vector2 = EVENT_MAP_COORDS.get(eid, Vector2(688, 384))
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)])
		dot.color = Color(0.98, 0.82, 0.38, 0.95)
		dot.position = pt
		waypoints_root.add_child(dot)

	active_beacon = Polygon2D.new()
	active_beacon.polygon = PackedVector2Array([Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)])
	active_beacon.color = Color(1.0, 0.92, 0.52, 0.55)
	waypoints_root.add_child(active_beacon)


func _build_v3_hud() -> void:
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 14
	top_bar.offset_right = -14
	top_bar.offset_top = 10
	top_bar.offset_bottom = 62
	top_bar.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.90), Color(0.82, 0.64, 0.32), 10))
	hud_layer.add_child(top_bar)

	var thb := HBoxContainer.new()
	thb.add_theme_constant_override("separation", 8)
	top_bar.add_child(thb)

	header_label = Label.new()
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	thb.add_child(header_label)

	for eid in event_order:
		var ev: Dictionary = events_by_id[eid]
		var cap_id: String = eid
		var sb: Button = _make_btn(str(ev.get("code", eid)), func() -> void: _show_event(cap_id, true), 64.0)
		thb.add_child(sb)
		step_buttons[eid] = sb

	lang_btn = _make_btn("中文/EN", func() -> void:
		var nxt: String = "en_US" if SaveManager.current_locale == "zh_CN" else "zh_CN"
		SaveManager.set_locale(nxt)
		_show_event(current_event_id, false)
	, 82.0)
	thb.add_child(lang_btn)

	menu_btn = _make_btn(tr("BTN_MAIN_MENU"), func() -> void: SceneTransition.change_scene("res://scenes/main_menu.tscn"), 116.0)
	thb.add_child(menu_btn)

	# Right-Side Story & Illustrated Plate Scroll Card
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	card.offset_left = -500
	card.offset_right = -16
	card.offset_top = -590
	card.offset_bottom = -16
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.07, 0.04, 0.94), Color(0.86, 0.68, 0.36), 12))
	hud_layer.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	plate_rect = TextureRect.new()
	plate_rect.custom_minimum_size = Vector2(440, 210)
	plate_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vb.add_child(plate_rect)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	vb.add_child(title_label)

	ref_label = Label.new()
	ref_label.add_theme_font_size_override("font_size", 12)
	ref_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56))
	vb.add_child(ref_label)

	body_label = Label.new()
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	vb.add_child(body_label)

	carryover_label = Label.new()
	carryover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carryover_label.add_theme_font_size_override("font_size", 12)
	carryover_label.add_theme_color_override("font_color", Color(0.76, 0.90, 0.74))
	vb.add_child(carryover_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 6)
	vb.add_child(choices_box)


func _show_event(eid: String, animate_cam: bool) -> void:
	if not events_by_id.has(eid):
		return
	current_event_id = eid
	var ev: Dictionary = events_by_id[eid]
	var is_en: bool = (SaveManager.current_locale == "en_US")
	header_label.text = tr("OW_HEADER")
	menu_btn.text = tr("BTN_MAIN_MENU")

	var pt: Vector2 = EVENT_MAP_COORDS.get(eid, Vector2(688, 384))
	active_beacon.position = pt
	if not visited_points.has(pt):
		visited_points.append(pt)
		trail_line.points = visited_points

	var cam_target := Vector2(clampf(pt.x + 140.0, 560.0, 1180.0), clampf(pt.y + 180.0, 360.0, 680.0))
	if animate_cam:
		if cam_tween != null and cam_tween.is_valid(): cam_tween.kill()
		cam_tween = create_tween()
		cam_tween.tween_property(camera, "position", cam_target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		camera.position = cam_target

	var p_path: String = EVENT_PLATES.get(eid, "")
	if not p_path.is_empty():
		plate_rect.texture = load(p_path) as Texture2D

	title_label.text = "%s · %s" % [str(ev.get("code", "")), str(ev.get("titleEn" if is_en else "titleZh", ""))]
	ref_label.text = "%s · %s" % [str(ev.get("speakerEn" if is_en else "speakerZh", "")), str(ev.get("canonRef", ""))]
	body_label.text = str(ev.get("bodyEn" if is_en else "bodyZh", ""))

	var noah_h: int = int(SaveManager.carryover_ledger.get("noah_harmony_bonus", 0))
	var w_b: int = int(SaveManager.carryover_ledger.get("p01_water_bonus", 0))
	var h_b: int = noah_h + int(SaveManager.carryover_ledger.get("p01_harmony_bonus", 0))
	carryover_label.text = ("Covenant Carryover -> Ch.1 Water +%d | Faith +%d%%" if is_en else "跨章立约传承 → 第一章初始活水 +%d  |  家族信心 +%d%%") % [w_b, h_b]

	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	for ch in ev.get("choices", []):
		var cd: Dictionary = ch
		var lbl: String = str(cd.get("labelEn" if is_en else "labelZh", "Continue"))
		var btn: Button = _make_btn(lbl, func() -> void: _on_choice(cd), 420.0)
		choices_box.add_child(btn)


func _on_choice(cd: Dictionary) -> void:
	SoundManager.play_sfx("sfx_covenant_chime.wav", -5.0)
	var dw: int = int(cd.get("deltaWater", 0))
	var dh: int = int(cd.get("deltaHarmony", 0))
	var dp: int = int(cd.get("deltaPressure", 0))
	CampaignState.add_carryover(dw, dh, dp)
	SaveManager.record_carryover("p01_water_bonus", int(SaveManager.carryover_ledger.get("p01_water_bonus", 0)) + dw)
	SaveManager.record_carryover("p01_harmony_bonus", int(SaveManager.carryover_ledger.get("p01_harmony_bonus", 0)) + dh)
	SaveManager.record_carryover("p01_pressure_offset", int(SaveManager.carryover_ledger.get("p01_pressure_offset", 0)) + dp)

	var nxt: String = str(cd.get("nextEventId", ""))
	if not nxt.is_empty() and events_by_id.has(nxt):
		_show_event(nxt, true)
	else:
		CampaignState.prologue_completed = true
		SaveManager.save_slot(1, {"chapter_id": "ch01_bethel", "monument_pct": 10.0}, get_viewport())
		SceneTransition.change_scene("res://scenes/camp_pilot.tscn")
