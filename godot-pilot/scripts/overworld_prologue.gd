extends Node2D

@onready var map_sprite: Sprite2D = $MapLayer/MapSprite
@onready var trail_line: Line2D = $MapLayer/TrailLine
@onready var waypoints_root: Node2D = $MapLayer/WaypointsRoot
@onready var camera: Camera2D = $Camera2D
@onready var hud_layer: CanvasLayer = $HudLayer

var prologue_data: Dictionary = {}
var events_by_id: Dictionary = {}
var event_order: Array[String] = []
var current_event_id: String = ""
var visited_points: PackedVector2Array = PackedVector2Array()
var active_beacon: Polygon2D = null
var beacon_pulse_time: float = 0.0
var cam_tween: Tween = null

# Exact coordinates on world-map-scroll-final.png (1376 x 768)
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

# UI references
var header_label: Label = null
var plate_rect: TextureRect = null
var badge_label: Label = null
var title_label: Label = null
var ref_label: Label = null
var body_label: Label = null
var result_label: Label = null
var carryover_label: Label = null
var choices_box: VBoxContainer = null
var step_buttons: Dictionary = {}


func _ready() -> void:
	_load_map_texture()
	_load_prologue_json()
	_build_waypoints()
	_build_hud()
	if current_event_id != "":
		_show_event(current_event_id, false)


func _load_map_texture() -> void:
	var tex: Texture2D = load("res://assets/overworld/world-map-scroll-final.png")
	if tex != null:
		map_sprite.texture = tex


func _load_prologue_json() -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/ch00_ur_call.json")
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		prologue_data = parsed
		current_event_id = str(parsed.get("firstEventId", "b01_babel_shem"))
		var evs: Array = parsed.get("events", [])
		for ev in evs:
			if ev is Dictionary and ev.has("id"):
				var eid: String = str(ev["id"])
				events_by_id[eid] = ev
				event_order.append(eid)


func _build_waypoints() -> void:
	for eid in event_order:
		var pos: Vector2 = EVENT_MAP_COORDS.get(eid, Vector2(688, 384))
		var ev: Dictionary = events_by_id[eid]
		var dot := Polygon2D.new()
		dot.polygon = _make_circle_poly(11.0, 16)
		dot.color = Color(0.95, 0.72, 0.30, 0.95) if str(ev.get("nodeType", "")) == "prologue" else Color(0.62, 0.80, 0.94, 0.95)
		dot.position = pos
		waypoints_root.add_child(dot)

		var lbl := Label.new()
		lbl.text = "%s · %s" % [str(ev.get("code", "")), str(ev.get("titleZh", "")).left(8)]
		lbl.position = pos + Vector2(-52.0, 14.0)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.99, 0.96, 0.86))
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.04))
		lbl.add_theme_constant_override("outline_size", 5)
		waypoints_root.add_child(lbl)

	# Pulsing golden active beacon
	active_beacon = Polygon2D.new()
	active_beacon.polygon = _make_circle_poly(18.0, 20)
	active_beacon.color = Color(1.0, 0.86, 0.42, 0.45)
	waypoints_root.add_child(active_beacon)


static func _make_circle_poly(rad: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a: float = float(i) / float(segs) * TAU
		pts.append(Vector2(cos(a) * rad, sin(a) * rad))
	return pts


func _make_bronze_panel_style(alpha: float = 0.88) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.07, 0.05, alpha)
	st.border_color = Color(0.84, 0.68, 0.38, 0.90)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(14)
	return st


func _make_btn_style(primary: bool = false) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.32, 0.23, 0.11, 0.94) if primary else Color(0.15, 0.11, 0.07, 0.88)
	st.border_color = Color(0.94, 0.78, 0.44, 1.0) if primary else Color(0.76, 0.60, 0.32, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(9)
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 8.0
	st.content_margin_bottom = 8.0
	return st


func _build_hud() -> void:
	# 1. Top-left Brand & Era Banner
	var top_panel := PanelContainer.new()
	top_panel.offset_left = 16.0
	top_panel.offset_top = 14.0
	top_panel.offset_right = 760.0
	top_panel.offset_bottom = 86.0
	top_panel.add_theme_stylebox_override("panel", _make_bronze_panel_style(0.84))
	hud_layer.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_panel.add_child(top_vbox)

	header_label = Label.new()
	header_label.text = "应许之路 · 古代近东至迦南史诗战役画卷（序章 · 出迦勒底的吾珥）"
	header_label.add_theme_font_size_override("font_size", 18)
	header_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48))
	top_vbox.add_child(header_label)

	carryover_label = Label.new()
	carryover_label.text = "创 11:31–12:9（参徒 7:2–4）  |  序章整备加成：饮水 +0  ·  和睦 +0%"
	carryover_label.add_theme_font_size_override("font_size", 13)
	carryover_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	top_vbox.add_child(carryover_label)

	# 2. Right Scroll Dossier & Prologue Choice Panel
	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -456.0
	right_panel.offset_right = -16.0
	right_panel.offset_top = 14.0
	right_panel.offset_bottom = -16.0
	right_panel.add_theme_stylebox_override("panel", _make_bronze_panel_style(0.92))
	hud_layer.add_child(right_panel)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(r_vbox)

	badge_label = Label.new()
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	r_vbox.add_child(badge_label)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color(0.99, 0.96, 0.88))
	r_vbox.add_child(title_label)

	ref_label = Label.new()
	ref_label.add_theme_font_size_override("font_size", 13)
	ref_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.94))
	r_vbox.add_child(ref_label)

	plate_rect = TextureRect.new()
	plate_rect.custom_minimum_size = Vector2(408, 224)
	plate_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r_vbox.add_child(plate_rect)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80))
	r_vbox.add_child(body_label)

	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 13)
	result_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.46))
	r_vbox.add_child(result_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	r_vbox.add_child(choices_box)

	# 3. Bottom-Left Timeline & Direct Scene Jump Bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 16.0
	bottom_bar.offset_right = 780.0
	bottom_bar.offset_top = -66.0
	bottom_bar.offset_bottom = -14.0
	bottom_bar.add_theme_constant_override("separation", 8)
	hud_layer.add_child(bottom_bar)

	for eid in event_order:
		var ev: Dictionary = events_by_id[eid]
		var sbtn := Button.new()
		sbtn.text = str(ev.get("code", eid))
		sbtn.custom_minimum_size = Vector2(68, 48)
		sbtn.add_theme_stylebox_override("normal", _make_btn_style(false))
		sbtn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
		var target_eid: String = eid
		sbtn.pressed.connect(func() -> void: _show_event(target_eid, true))
		bottom_bar.add_child(sbtn)
		step_buttons[eid] = sbtn

	var btn_camp := Button.new()
	btn_camp.text = "▶ 进入第一章 3D 营地"
	btn_camp.custom_minimum_size = Vector2(188, 48)
	btn_camp.add_theme_stylebox_override("normal", _make_btn_style(true))
	btn_camp.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	btn_camp.pressed.connect(func() -> void: _enter_chapter1_camp())
	bottom_bar.add_child(btn_camp)

	var btn_greybox := Button.new()
	btn_greybox.text = "🗺 128×96 七区灰盒"
	btn_greybox.custom_minimum_size = Vector2(162, 48)
	btn_greybox.add_theme_stylebox_override("normal", _make_btn_style(false))
	btn_greybox.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	btn_greybox.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ch01_region_greybox.tscn"))
	bottom_bar.add_child(btn_greybox)


func _show_event(eid: String, animate_cam: bool = true) -> void:
	if not events_by_id.has(eid):
		return
	current_event_id = eid
	var ev: Dictionary = events_by_id[eid]

	# Update golden migration trail up to current station
	var idx: int = event_order.find(eid)
	visited_points.clear()
	for i in range(idx + 1):
		var p_id: String = event_order[i]
		visited_points.append(EVENT_MAP_COORDS.get(p_id, Vector2(688, 384)))
	trail_line.points = visited_points

	var focus_pt: Vector2 = EVENT_MAP_COORDS.get(eid, Vector2(688, 384))
	if active_beacon != null:
		active_beacon.position = focus_pt

	# Pan & zoom camera slightly right so the active landmark sits comfortably left of the right dossier panel!
	var target_cam := Vector2(clampf(focus_pt.x + 220.0, 520.0, 1180.0), clampf(focus_pt.y + 30.0, 260.0, 540.0))
	var target_zoom := Vector2(1.24, 1.24)
	if animate_cam:
		if cam_tween != null:
			cam_tween.kill()
		cam_tween = create_tween().set_parallel(true)
		cam_tween.tween_property(camera, "position", target_cam, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "zoom", target_zoom, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		camera.position = target_cam
		camera.zoom = target_zoom

	# Update right dossier panel
	var ntype: String = str(ev.get("nodeType", "prologue"))
	badge_label.text = "%s  ·  %s  ·  %s" % [
		str(ev.get("code", "")),
		"可玩交互画卷序章" if ntype == "prologue" else "纪年桥接画卷",
		str(ev.get("speakerZh", "")),
	]
	title_label.text = str(ev.get("titleZh", ""))
	ref_label.text = "经文依据：%s" % str(ev.get("canonRef", ""))
	body_label.text = str(ev.get("bodyZh", ""))
	result_label.text = ""

	var plate_path: String = EVENT_PLATES.get(eid, "")
	if plate_path != "" and ResourceLoader.exists(plate_path):
		plate_rect.texture = load(plate_path)

	# Refresh step button highlight
	for k in step_buttons.keys():
		var b: Button = step_buttons[k]
		b.add_theme_stylebox_override("normal", _make_btn_style(k == eid))

	# Rebuild choices
	for ch in choices_box.get_children():
		ch.queue_free()
	var choices: Array = ev.get("choices", [])
	for c in choices:
		if not (c is Dictionary):
			continue
		var btn := Button.new()
		btn.text = str(c.get("labelZh", "继续"))
		btn.custom_minimum_size = Vector2(390, 48)
		btn.add_theme_stylebox_override("normal", _make_btn_style(true))
		btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
		var choice_copy: Dictionary = c
		btn.pressed.connect(func() -> void: _on_choice_pressed(choice_copy))
		choices_box.add_child(btn)

	_refresh_carryover_text()


func _on_choice_pressed(choice: Dictionary) -> void:
	var dw: int = int(choice.get("deltaWater", 0))
	var dh: int = int(choice.get("deltaHarmony", 0))
	var dp: int = int(choice.get("deltaPressure", 0))
	var state := get_node_or_null("/root/CampaignState")
	if state != null:
		state.add_carryover(dw, dh, dp)
	result_label.text = str(choice.get("resultZh", ""))
	_refresh_carryover_text()

	var next_id: String = str(choice.get("nextEventId", ""))
	if next_id != "" and events_by_id.has(next_id):
		_show_event(next_id, true)
	else:
		_enter_chapter1_camp()


func _refresh_carryover_text() -> void:
	var state := get_node_or_null("/root/CampaignState")
	var wb: int = state.water_bonus if state != null else 0
	var hb: int = state.harmony_bonus if state != null else 0
	carryover_label.text = "创 11:31–12:9（参徒 7:2–4）  |  序章整备带入第一章：饮水 +%d  ·  和睦 +%d%%" % [wb, hb]


func _enter_chapter1_camp() -> void:
	var state := get_node_or_null("/root/CampaignState")
	if state != null:
		state.prologue_completed = true
	get_tree().change_scene_to_file("res://scenes/camp_pilot.tscn")


func _process(delta: float) -> void:
	beacon_pulse_time += delta * 2.8
	if active_beacon != null:
		var s: float = 1.0 + sin(beacon_pulse_time) * 0.25
		active_beacon.scale = Vector2(s, s)
