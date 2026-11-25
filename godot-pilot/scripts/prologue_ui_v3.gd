class_name PrologueUIV3
extends CanvasLayer
## Commercial Game UI V3 (Shared Cartridge HUD for Ch00..Ch11):
## - 100% `tr()` i18n bilingual live switching (`zh_CN` CUV 1919 <-> `en_US` WEB Public Domain)
## - Top-Center Left-Medallion Bronze Sundial + 300-Cubit / Chapter Milestone Bar
## - Top-Left 4 Compact Resource & Faith Badges
## - [Space] Tactical Sandbox 0.35x Frame + 3D-Projected Station Bubbles
## - [J] Bilingual Biblical Canon & Historical Adaptation Codex Drawer
## - [Esc] 3-Slot Thumbnail Save/Load Cards + Master/Ambience/SFX dB Sliders + Graphics Quality
## - Mobile Dynamic Virtual Joystick + Responsive `1920x1080` / `844x390` / `390x844` Layout!

signal request_toggle_fp
signal request_toggle_tactical
signal request_toggle_cutaway
signal request_interact
signal request_assign_worker(station: String, delta_val: int)
signal request_fence_work
signal request_douse_fire
signal request_save_slot(slot: int)
signal request_load_slot(slot: int)
signal request_lang_changed(lang: String)
signal request_quality_changed(quality: int)
signal request_main_menu

class SundialArkGauge extends Control:
	var days_left: float = 240.0
	var max_days: float = 240.0
	var ark_pct: float = 0.0
	var pulse_t: float = 0.0

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var arch_r: float = 21.0
		var arch_cx: float = 28.0
		var arch_cy: float = h * 0.5
		var urgent: bool = days_left < 30.0 and days_left > 0.0
		var dial_bg: Color = Color(0.11, 0.08, 0.04, 0.94)
		var bronze: Color = Color(0.94, 0.36, 0.24) if (urgent and sin(pulse_t * 6.0) > 0.0) else Color(0.86, 0.68, 0.36)
		draw_circle(Vector2(arch_cx, arch_cy), arch_r, dial_bg)
		draw_arc(Vector2(arch_cx, arch_cy), arch_r, 0.0, TAU, 32, bronze, 2.0, true)
		draw_arc(Vector2(arch_cx, arch_cy), arch_r - 4.5, PI, TAU, 20, Color(0.98, 0.84, 0.46, 0.45), 1.2, true)
		var sun_ratio: float = clampf(1.0 - days_left / maxf(max_days, 1.0), 0.0, 1.0)
		var hand_ang: float = PI + sun_ratio * PI
		var tip: Vector2 = Vector2(arch_cx + cos(hand_ang) * (arch_r - 5.0), arch_cy + sin(hand_ang) * (arch_r - 5.0))
		draw_line(Vector2(arch_cx, arch_cy), tip, Color(1.0, 0.88, 0.48), 2.2, true)
		draw_circle(tip, 3.0, Color(1.0, 0.92, 0.56))

		var bx: float = 60.0
		var bw: float = maxf(60.0, w - 70.0)
		var by: float = h - 17.0
		var bh: float = 11.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0.07, 0.05, 0.03, 0.92), true)
		var fill_w: float = bw * clampf(ark_pct / 100.0, 0.0, 1.0)
		if fill_w > 1.0:
			draw_rect(Rect2(bx + 1.0, by + 1.0, fill_w - 2.0, bh - 2.0), Color(0.84, 0.63, 0.28, 0.95), true)
		draw_rect(Rect2(bx, by, bw, bh), bronze, false, 1.4)
		for tick_pct in [0.35, 0.75]:
			var tx: float = bx + bw * tick_pct
			draw_line(Vector2(tx, by - 2.5), Vector2(tx, by + bh + 2.5), Color(0.98, 0.86, 0.52, 0.85), 1.5)


class VirtualThumbstick extends Control:
	var stick_vec: Vector2 = Vector2.ZERO
	var _dragging: bool = false
	var _touch_idx: int = -1

	func _gui_input(event: InputEvent) -> void:
		var center: Vector2 = size * 0.5
		var max_r: float = minf(size.x, size.y) * 0.40
		if event is InputEventScreenTouch:
			var st: InputEventScreenTouch = event
			if st.pressed:
				_dragging = true
				_touch_idx = st.index
				_update_knob(st.position - center, max_r)
			elif st.index == _touch_idx:
				_dragging = false
				_touch_idx = -1
				stick_vec = Vector2.ZERO
				queue_redraw()
			accept_event()
		elif event is InputEventScreenDrag and _dragging and (event as InputEventScreenDrag).index == _touch_idx:
			_update_knob((event as InputEventScreenDrag).position - center, max_r)
			accept_event()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb: InputEventMouseButton = event
			_dragging = mb.pressed
			if _dragging:
				_update_knob(mb.position - center, max_r)
			else:
				stick_vec = Vector2.ZERO
				queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_update_knob((event as InputEventMouseMotion).position - center, max_r)
			accept_event()

	func _update_knob(delta_p: Vector2, max_r: float) -> void:
		var clamped: Vector2 = delta_p.limit_length(max_r)
		stick_vec = clamped / maxf(max_r, 1.0)
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.42
		draw_circle(c, r, Color(0.08, 0.06, 0.04, 0.62))
		draw_arc(c, r, 0.0, TAU, 32, Color(0.88, 0.70, 0.34, 0.82), 2.0, true)
		var knob: Vector2 = c + stick_vec * (r * 0.78)
		draw_circle(knob, r * 0.36, Color(0.96, 0.80, 0.42, 0.90))


var lang: String = "zh_CN"
var codex_data: Array = []

var sundial_panel: PanelContainer
var sundial_gauge: SundialArkGauge
var sundial_title_lbl: Label
var sundial_sub_lbl: Label

var badges_box: VBoxContainer
var badge_panels: Dictionary = {}
var badge_labels: Dictionary = {}

var top_right_hb: HBoxContainer
var fp_btn: Button
var tactical_btn: Button
var cutaway_btn: Button
var codex_btn: Button
var pause_btn: Button
var fp_crosshair: ColorRect

var tactical_border: PanelContainer
var tactical_banner_lbl: Label
var bubble_layer: Control
var station_bubbles: Dictionary = {}
var station_counts: Dictionary = {}
var fence_bubble_btn: Button
var fire_bubble_panel: PanelContainer
var fire_bubble_btn: Button

var thumbstick: VirtualThumbstick
var interact_prompt: Button
var subtitle_panel: PanelContainer
var subtitle_label: Label

var act_card_root: Control
var act_card_title: Label
var act_card_sub: Label
var _act_card_tween: Tween

var divine_seal_overlay: ColorRect
var divine_seal_title: Label
var divine_seal_verse: Label

var codex_drawer: PanelContainer
var codex_hdr_lbl: Label
var codex_close_btn: Button
var codex_list_vb: VBoxContainer

var pause_overlay: ColorRect
var pause_title_lbl: Label
var save_status_lbl: Label
var slot_thumbs: Dictionary = {}
var slot_meta_lbls: Dictionary = {}
var slot_save_btns: Dictionary = {}
var slot_load_btns: Dictionary = {}
var master_slider: HSlider
var amb_slider: HSlider
var sfx_slider: HSlider
var vol_lbls: Dictionary = {}
var lang_btn: Button
var quality_btn: Button
var headbob_btn: Button
var joystick_btn: Button
var resume_btn: Button
var menu_btn: Button

var modal_overlay: ColorRect
var modal_card: PanelContainer
var modal_title: Label
var modal_ref: Label
var modal_body: Label
var modal_choices: VBoxContainer


func _style_box(bg: Color, border: Color, radius: int = 8, pad_h: int = 10, pad_v: int = 6) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func make_pill(text: String, cb: Callable, min_w: float = 72.0, min_h: float = 44.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(48.0, min_w), maxf(44.0, min_h))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	b.add_theme_stylebox_override("normal", _style_box(Color(0.13, 0.09, 0.05, 0.88), Color(0.76, 0.58, 0.30), 7, 9, 5))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.24, 0.17, 0.09, 0.96), Color(0.96, 0.80, 0.44), 7, 9, 5))
	b.add_theme_stylebox_override("pressed", _style_box(Color(0.30, 0.21, 0.10, 0.98), Color(1.0, 0.86, 0.50), 7, 9, 5))
	b.pressed.connect(cb)
	return b


func _sv() -> Node:
	return get_node_or_null("/root/SaveManager") if is_inside_tree() else null


func build_ui(codex_entries: Array) -> void:
	layer = 10
	codex_data = codex_entries
	var sv: Node = _sv()
	if sv != null:
		sv.call("ensure_translations_loaded")
		lang = str(sv.get("current_locale"))

	# 0. Tactical Sandbox Golden Frame Banner
	tactical_border = PanelContainer.new()
	tactical_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	tactical_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb_style: StyleBoxFlat = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.06, 0.04, 0.02, 0.08)
	tb_style.border_color = Color(0.94, 0.76, 0.36, 0.82)
	tb_style.set_border_width_all(3)
	tactical_border.add_theme_stylebox_override("panel", tb_style)
	tactical_border.hide()
	add_child(tactical_border)

	var tb_overlay: Control = Control.new()
	tb_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tb_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_border.add_child(tb_overlay)
	var tb_top: CenterContainer = CenterContainer.new()
	tb_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tb_top.offset_top = 86
	tb_top.offset_bottom = 118
	tb_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb_overlay.add_child(tb_top)
	var tb_chip: PanelContainer = PanelContainer.new()
	tb_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb_chip.add_theme_stylebox_override("panel", _style_box(Color(0.14, 0.10, 0.04, 0.93), Color(0.96, 0.78, 0.38), 14, 14, 4))
	tb_top.add_child(tb_chip)
	tactical_banner_lbl = Label.new()
	tactical_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	tactical_banner_lbl.add_theme_font_size_override("font_size", 12)
	tb_chip.add_child(tactical_banner_lbl)

	# 1. 3D-Projected Tactical Station Bubbles
	bubble_layer = Control.new()
	bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble_layer)
	_build_3d_station_bubbles()

	# 2. Top-Left 4 Compact Resource & Harmony Badges
	badges_box = VBoxContainer.new()
	badges_box.position = Vector2(12, 10)
	badges_box.add_theme_constant_override("separation", 4)
	add_child(badges_box)
	var hb_row1: HBoxContainer = HBoxContainer.new()
	hb_row1.add_theme_constant_override("separation", 5)
	badges_box.add_child(hb_row1)
	var hb_row2: HBoxContainer = HBoxContainer.new()
	hb_row2.add_theme_constant_override("separation", 5)
	badges_box.add_child(hb_row2)

	for spec in [["timber", hb_row1], ["pitch", hb_row1], ["provisions", hb_row2], ["harmony", hb_row2]]:
		var k: String = str(spec[0])
		var pc: PanelContainer = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.85), Color(0.72, 0.55, 0.28, 0.86), 6, 9, 4))
		(spec[1] as HBoxContainer).add_child(pc)
		var lb: Label = Label.new()
		lb.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80))
		lb.add_theme_font_size_override("font_size", 13)
		pc.add_child(lb)
		badge_panels[k] = pc
		badge_labels[k] = lb

	# 3. Top-Center Bronze Sundial + Progress Gauge
	sundial_panel = PanelContainer.new()
	sundial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sundial_panel.offset_left = -216
	sundial_panel.offset_right = 178
	sundial_panel.offset_top = 10
	sundial_panel.offset_bottom = 80
	sundial_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.88), Color(0.80, 0.62, 0.32, 0.90), 10, 8, 4))
	add_child(sundial_panel)

	var sd_root: Control = Control.new()
	sd_root.custom_minimum_size = Vector2(374, 60)
	sundial_panel.add_child(sd_root)
	sundial_gauge = SundialArkGauge.new()
	sundial_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	sd_root.add_child(sundial_gauge)

	sundial_title_lbl = Label.new()
	sundial_title_lbl.position = Vector2(60, 2)
	sundial_title_lbl.size = Vector2(308, 20)
	sundial_title_lbl.add_theme_color_override("font_color", Color(0.99, 0.92, 0.74))
	sundial_title_lbl.add_theme_font_size_override("font_size", 13)
	sd_root.add_child(sundial_title_lbl)

	sundial_sub_lbl = Label.new()
	sundial_sub_lbl.position = Vector2(60, 21)
	sundial_sub_lbl.size = Vector2(308, 18)
	sundial_sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	sundial_sub_lbl.add_theme_font_size_override("font_size", 11)
	sd_root.add_child(sundial_sub_lbl)

	# 4. Top-Right Action Pills (>= 48x44px)
	top_right_hb = HBoxContainer.new()
	top_right_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_hb.offset_left = -488
	top_right_hb.offset_right = -10
	top_right_hb.offset_top = 10
	top_right_hb.offset_bottom = 56
	top_right_hb.alignment = BoxContainer.ALIGNMENT_END
	top_right_hb.add_theme_constant_override("separation", 4)
	add_child(top_right_hb)

	fp_btn = make_pill(tr("BTN_FP_ENTER"), func() -> void: request_toggle_fp.emit(), 84, 44)
	top_right_hb.add_child(fp_btn)
	tactical_btn = make_pill(tr("BTN_TACTICAL_ENTER"), func() -> void: request_toggle_tactical.emit(), 90, 44)
	top_right_hb.add_child(tactical_btn)
	cutaway_btn = make_pill(tr("BTN_CUTAWAY_ON"), func() -> void: request_toggle_cutaway.emit(), 60, 44)
	top_right_hb.add_child(cutaway_btn)
	codex_btn = make_pill(tr("BTN_CODEX"), toggle_codex, 66, 44)
	top_right_hb.add_child(codex_btn)
	pause_btn = make_pill(tr("BTN_MENU"), toggle_pause_menu, 72, 44)
	top_right_hb.add_child(pause_btn)

	# 5. Subtle 4px First-Person Crosshair Dot
	fp_crosshair = ColorRect.new()
	fp_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	fp_crosshair.offset_left = -2
	fp_crosshair.offset_right = 2
	fp_crosshair.offset_top = -2
	fp_crosshair.offset_bottom = 2
	fp_crosshair.color = Color(1.0, 0.94, 0.78, 0.72)
	fp_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp_crosshair.hide()
	add_child(fp_crosshair)

	# 6. Mobile Dynamic Virtual Thumbstick (Bottom-Left)
	thumbstick = VirtualThumbstick.new()
	thumbstick.custom_minimum_size = Vector2(124, 124)
	thumbstick.size = Vector2(124, 124)
	thumbstick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	thumbstick.offset_left = 20
	thumbstick.offset_right = 144
	thumbstick.offset_top = -198
	thumbstick.offset_bottom = -74
	thumbstick.visible = bool(sv.get("touch_stick_enabled")) if sv != null else false
	add_child(thumbstick)

	# 7. Center-Bottom [E] World Interaction Pill (>= 46px height)
	interact_prompt = make_pill("[E]", func() -> void: request_interact.emit(), 300, 46)
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_prompt.offset_left = -210
	interact_prompt.offset_right = 210
	interact_prompt.offset_top = -124
	interact_prompt.offset_bottom = -78
	interact_prompt.add_theme_font_size_override("font_size", 15)
	interact_prompt.add_theme_stylebox_override("normal", _style_box(Color(0.20, 0.14, 0.06, 0.94), Color(0.98, 0.80, 0.38), 20, 16, 8))
	interact_prompt.hide()
	add_child(interact_prompt)

	# 8. Pure Cinematic Subtitle Strip
	subtitle_panel = PanelContainer.new()
	subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_panel.offset_left = 84
	subtitle_panel.offset_right = -84
	subtitle_panel.offset_top = -68
	subtitle_panel.offset_bottom = -10
	subtitle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.05, 0.04, 0.82), Color(0.66, 0.50, 0.25, 0.68), 8, 12, 6))
	add_child(subtitle_panel)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_panel.add_child(subtitle_label)

	# 9. Act Title Card
	act_card_root = Control.new()
	act_card_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	act_card_root.offset_top = 104
	act_card_root.offset_bottom = 186
	act_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_card_root.modulate.a = 0.0
	add_child(act_card_root)
	var ac_cc: CenterContainer = CenterContainer.new()
	ac_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ac_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_card_root.add_child(ac_cc)
	var ac_pc: PanelContainer = PanelContainer.new()
	ac_pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ac_pc.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.05, 0.03, 0.88), Color(0.92, 0.74, 0.36, 0.92), 10, 22, 10))
	ac_cc.add_child(ac_pc)
	var ac_vb: VBoxContainer = VBoxContainer.new()
	ac_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ac_pc.add_child(ac_vb)
	act_card_title = Label.new()
	act_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	act_card_title.add_theme_font_size_override("font_size", 19)
	ac_vb.add_child(act_card_title)
	act_card_sub = Label.new()
	act_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_card_sub.add_theme_color_override("font_color", Color(0.88, 0.80, 0.64))
	act_card_sub.add_theme_font_size_override("font_size", 13)
	ac_vb.add_child(act_card_sub)

	# 10. Reverent 5s Divine Seal Card
	divine_seal_overlay = ColorRect.new()
	divine_seal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	divine_seal_overlay.color = Color(0.02, 0.02, 0.03, 0.42)
	divine_seal_overlay.hide()
	add_child(divine_seal_overlay)
	var ds_cc: CenterContainer = CenterContainer.new()
	ds_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	divine_seal_overlay.add_child(ds_cc)
	var ds_card: PanelContainer = PanelContainer.new()
	ds_card.custom_minimum_size = Vector2(680, 145)
	ds_card.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.94), Color(0.92, 0.74, 0.36), 12, 24, 20))
	ds_cc.add_child(ds_card)
	var ds_vb: VBoxContainer = VBoxContainer.new()
	ds_vb.add_theme_constant_override("separation", 12)
	ds_card.add_child(ds_vb)
	divine_seal_title = Label.new()
	divine_seal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_seal_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	divine_seal_title.add_theme_font_size_override("font_size", 25)
	ds_vb.add_child(divine_seal_title)
	divine_seal_verse = Label.new()
	divine_seal_verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_seal_verse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	divine_seal_verse.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	divine_seal_verse.add_theme_font_size_override("font_size", 16)
	ds_vb.add_child(divine_seal_verse)

	_build_codex_drawer()
	_build_pause_menu()
	_build_dramatic_modal()

	if is_inside_tree() and get_viewport() != null:
		get_viewport().size_changed.connect(_apply_responsive_layout)
	refresh_i18n_texts()
	_apply_responsive_layout()


func get_joystick_vector() -> Vector2:
	if thumbstick != null and thumbstick.visible:
		return thumbstick.stick_vec
	return Vector2.ZERO


func _build_3d_station_bubbles() -> void:
	for k: String in ["log", "build", "pitch", "guard"]:
		var pc: PanelContainer = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _style_box(Color(0.10, 0.07, 0.04, 0.93), Color(0.90, 0.72, 0.34), 10, 8, 5))
		pc.hide()
		bubble_layer.add_child(pc)
		var vb: VBoxContainer = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		pc.add_child(vb)
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		vb.add_child(hb)
		hb.add_child(make_pill("-", func() -> void: request_assign_worker.emit(k, -1), 48, 44))
		var lb: Label = Label.new()
		lb.custom_minimum_size = Vector2(106, 36)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
		lb.add_theme_font_size_override("font_size", 13)
		hb.add_child(lb)
		hb.add_child(make_pill("+", func() -> void: request_assign_worker.emit(k, 1), 48, 44))
		if k == "guard":
			fence_bubble_btn = make_pill(tr("BTN_FENCE_BUILD"), func() -> void: request_fence_work.emit(), 196, 44)
			fence_bubble_btn.hide()
			vb.add_child(fence_bubble_btn)
		station_bubbles[k] = pc
		station_counts[k] = lb

	fire_bubble_panel = PanelContainer.new()
	fire_bubble_panel.add_theme_stylebox_override("panel", _style_box(Color(0.32, 0.08, 0.04, 0.95), Color(1.0, 0.48, 0.20), 10, 8, 5))
	fire_bubble_panel.hide()
	bubble_layer.add_child(fire_bubble_panel)
	fire_bubble_btn = make_pill(tr("BTN_DOUSE_FIRE"), func() -> void: request_douse_fire.emit(), 188, 44)
	fire_bubble_panel.add_child(fire_bubble_btn)


func _build_codex_drawer() -> void:
	codex_drawer = PanelContainer.new()
	codex_drawer.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	codex_drawer.offset_left = -456
	codex_drawer.offset_right = -14
	codex_drawer.offset_top = -245
	codex_drawer.offset_bottom = 245
	codex_drawer.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.96), Color(0.88, 0.70, 0.36), 10, 14, 10))
	codex_drawer.hide()
	add_child(codex_drawer)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	codex_drawer.add_child(vb)

	var hdr_hb: HBoxContainer = HBoxContainer.new()
	vb.add_child(hdr_hb)
	codex_hdr_lbl = Label.new()
	codex_hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_hdr_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	codex_hdr_lbl.add_theme_font_size_override("font_size", 16)
	hdr_hb.add_child(codex_hdr_lbl)
	codex_close_btn = make_pill(tr("BTN_CLOSE"), toggle_codex, 64, 44)
	hdr_hb.add_child(codex_close_btn)

	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	codex_list_vb = VBoxContainer.new()
	codex_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_list_vb.custom_minimum_size = Vector2(390, 0)
	codex_list_vb.add_theme_constant_override("separation", 8)
	sc.add_child(codex_list_vb)
	_populate_codex_entries()


func _populate_codex_entries() -> void:
	if codex_list_vb == null:
		return
	for c in codex_list_vb.get_children():
		codex_list_vb.remove_child(c)
		c.queue_free()
	var is_en: bool = (lang == "en_US")
	for entry in codex_data:
		if not (entry is Dictionary):
			continue
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style_box(Color(0.16, 0.12, 0.07, 0.92), Color(0.68, 0.52, 0.26), 7, 10, 8))
		codex_list_vb.add_child(card)
		var cvb: VBoxContainer = VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 4)
		card.add_child(cvb)
		var tl: Label = Label.new()
		tl.text = "%s  ·  %s" % [str(entry.get("titleEn" if (is_en and entry.has("titleEn")) else "titleZh", "")), str(entry.get("canonRef", ""))]
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_color_override("font_color", Color(0.99, 0.86, 0.50))
		tl.add_theme_font_size_override("font_size", 14)
		cvb.add_child(tl)
		var cl: Label = Label.new()
		cl.text = str(entry.get("canonTextEn" if (is_en and entry.has("canonTextEn")) else "canonTextZh", ""))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
		cl.add_theme_font_size_override("font_size", 13)
		cvb.add_child(cl)
		var al: Label = Label.new()
		al.text = str(entry.get("adaptationNoteEn" if (is_en and entry.has("adaptationNoteEn")) else "adaptationNoteZh", ""))
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.add_theme_color_override("font_color", Color(0.76, 0.86, 0.74))
		al.add_theme_font_size_override("font_size", 12)
		cvb.add_child(al)


func _build_pause_menu() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.02, 0.02, 0.02, 0.68)
	pause_overlay.hide()
	add_child(pause_overlay)

	var sc: ScrollContainer = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_overlay.add_child(sc)

	var cc: CenterContainer = CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 420)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.98), Color(0.86, 0.68, 0.36), 10, 18, 14))
	cc.add_child(card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	card.add_child(vb)

	pause_title_lbl = Label.new()
	pause_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	pause_title_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(pause_title_lbl)

	save_status_lbl = Label.new()
	save_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	save_status_lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(save_status_lbl)

	# 3 Visual Save-Slot Cards with 96x54 Screenshot Thumbnails + Timestamps!
	for slot in [1, 2, 3]:
		var spc: PanelContainer = PanelContainer.new()
		spc.add_theme_stylebox_override("panel", _style_box(Color(0.16, 0.12, 0.07, 0.92), Color(0.66, 0.50, 0.25), 7, 8, 5))
		vb.add_child(spc)
		var shb: HBoxContainer = HBoxContainer.new()
		shb.add_theme_constant_override("separation", 8)
		spc.add_child(shb)

		var tr_img: TextureRect = TextureRect.new()
		tr_img.custom_minimum_size = Vector2(88, 50)
		tr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shb.add_child(tr_img)
		slot_thumbs[slot] = tr_img

		var mlb: Label = Label.new()
		mlb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mlb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mlb.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		mlb.add_theme_font_size_override("font_size", 12)
		shb.add_child(mlb)
		slot_meta_lbls[slot] = mlb

		var cap_slot: int = slot
		var sb: Button = make_pill(tr("BTN_SAVE") % slot, func() -> void: request_save_slot.emit(cap_slot), 98, 44)
		shb.add_child(sb)
		slot_save_btns[slot] = sb
		var lb: Button = make_pill(tr("BTN_LOAD") % slot, func() -> void: request_load_slot.emit(cap_slot), 98, 44)
		shb.add_child(lb)
		slot_load_btns[slot] = lb

	# Audio Volume dB Sliders (Master / Ambience / SFX)
	var sv: Node = _sv()
	for vspec in [
		["master", "LBL_VOL_MASTER", float(sv.get("master_db")) if sv != null else 0.0],
		["amb", "LBL_VOL_AMB", float(sv.get("ambience_db")) if sv != null else -2.0],
		["sfx", "LBL_VOL_SFX", float(sv.get("sfx_db")) if sv != null else 0.0],
	]:
		var vk: String = str(vspec[0])
		var vhb: HBoxContainer = HBoxContainer.new()
		vhb.add_theme_constant_override("separation", 8)
		vb.add_child(vhb)
		var vlb: Label = Label.new()
		vlb.custom_minimum_size = Vector2(82, 24)
		vlb.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
		vlb.add_theme_font_size_override("font_size", 12)
		vhb.add_child(vlb)
		vol_lbls[vk] = [vlb, str(vspec[1])]
		var sld: HSlider = HSlider.new()
		sld.min_value = -40.0
		sld.max_value = 6.0
		sld.step = 0.5
		sld.value = float(vspec[2])
		sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sld.custom_minimum_size = Vector2(180, 28)
		vhb.add_child(sld)
		sld.value_changed.connect(func(val: float) -> void:
			var s_mgr: Node = _sv()
			if s_mgr == null: return
			if vk == "master": s_mgr.set("master_db", val)
			elif vk == "amb": s_mgr.set("ambience_db", val)
			else: s_mgr.set("sfx_db", val)
			s_mgr.call("save_settings")
		)
		if vk == "master": master_slider = sld
		elif vk == "amb": amb_slider = sld
		else: sfx_slider = sld

	var hb_opts: HBoxContainer = HBoxContainer.new()
	hb_opts.add_theme_constant_override("separation", 6)
	vb.add_child(hb_opts)

	quality_btn = make_pill("", func() -> void:
		var s_mgr: Node = _sv()
		if s_mgr == null: return
		var nxt_q: int = (int(s_mgr.get("graphics_quality")) + 1) % 3
		s_mgr.set("graphics_quality", nxt_q)
		s_mgr.call("save_settings")
		refresh_i18n_texts()
		request_quality_changed.emit(nxt_q)
	, 155, 44)
	quality_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_opts.add_child(quality_btn)

	headbob_btn = make_pill("", func() -> void:
		var s_mgr: Node = _sv()
		if s_mgr == null: return
		s_mgr.set("head_bob_enabled", not bool(s_mgr.get("head_bob_enabled")))
		s_mgr.call("save_settings")
		refresh_i18n_texts()
	, 155, 44)
	headbob_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_opts.add_child(headbob_btn)

	joystick_btn = make_pill("", func() -> void:
		var s_mgr: Node = _sv()
		if s_mgr != null:
			var nv: bool = not bool(s_mgr.get("touch_stick_enabled"))
			s_mgr.set("touch_stick_enabled", nv)
			s_mgr.call("save_settings")
			thumbstick.visible = nv
		else:
			thumbstick.visible = not thumbstick.visible
		refresh_i18n_texts()
	, 155, 44)
	joystick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_opts.add_child(joystick_btn)

	lang_btn = make_pill("", func() -> void:
		lang = "en_US" if lang == "zh_CN" else "zh_CN"
		var s_mgr: Node = _sv()
		if s_mgr != null and s_mgr.has_method("set_locale"):
			s_mgr.call("set_locale", lang)
		else:
			TranslationServer.set_locale(lang)
		refresh_i18n_texts()
		request_lang_changed.emit(lang)
	, 380, 44)
	vb.add_child(lang_btn)

	var hb_bot: HBoxContainer = HBoxContainer.new()
	hb_bot.add_theme_constant_override("separation", 8)
	vb.add_child(hb_bot)
	resume_btn = make_pill("", toggle_pause_menu, 190, 44)
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_bot.add_child(resume_btn)
	menu_btn = make_pill("", func() -> void: request_main_menu.emit(), 190, 44)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_bot.add_child(menu_btn)


func _build_dramatic_modal() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(0.02, 0.02, 0.02, 0.56)
	modal_overlay.hide()
	add_child(modal_overlay)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.add_child(cc)
	modal_card = PanelContainer.new()
	modal_card.custom_minimum_size = Vector2(560.0, 240.0)
	modal_card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.97), Color(0.88, 0.70, 0.36), 10, 18, 14))
	cc.add_child(modal_card)
	var mvb: VBoxContainer = VBoxContainer.new()
	mvb.add_theme_constant_override("separation", 10)
	modal_card.add_child(mvb)
	modal_title = Label.new()
	modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	modal_title.add_theme_font_size_override("font_size", 19)
	mvb.add_child(modal_title)
	modal_ref = Label.new()
	modal_ref.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56))
	modal_ref.add_theme_font_size_override("font_size", 12)
	mvb.add_child(modal_ref)
	modal_body = Label.new()
	modal_body.custom_minimum_size = Vector2(320.0, 0.0)
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	modal_body.add_theme_font_size_override("font_size", 14)
	mvb.add_child(modal_body)
	modal_choices = VBoxContainer.new()
	modal_choices.add_theme_constant_override("separation", 8)
	mvb.add_child(modal_choices)


func refresh_save_slot_cards() -> void:
	var sv: Node = _sv()
	for slot in [1, 2, 3]:
		var mlb: Label = slot_meta_lbls.get(slot) as Label
		var tr_img: TextureRect = slot_thumbs.get(slot) as TextureRect
		if mlb == null or tr_img == null:
			continue
		if sv != null and bool(sv.call("has_save", slot)):
			var d: Dictionary = sv.call("load_slot", slot)
			var ch_name: String = str(d.get("chapter_id", "ch00"))
			var iso: String = str(d.get("savedAtIso", "")).replace("T", " ")
			var pct: int = int(roundf(float(d.get("ark_build_pct", d.get("monument_pct", 0.0)))))
			mlb.text = "#%d [%s] %d%%\n%s" % [slot, ch_name, pct, iso]
			tr_img.texture = sv.call("load_slot_thumbnail", slot) as Texture2D
		else:
			mlb.text = "#%d · %s" % [slot, tr("SLOT_EMPTY")]
			tr_img.texture = null


func refresh_i18n_texts() -> void:
	var sv: Node = _sv()
	tactical_banner_lbl.text = tr("TACTICAL_BANNER")
	fp_btn.text = tr("BTN_FP_EXIT" if fp_crosshair.visible else "BTN_FP_ENTER")
	tactical_btn.text = tr("BTN_TACTICAL_EXIT" if tactical_border.visible else "BTN_TACTICAL_ENTER")
	cutaway_btn.text = tr("BTN_CUTAWAY_ON")
	codex_btn.text = tr("BTN_CODEX")
	pause_btn.text = tr("BTN_MENU")
	codex_hdr_lbl.text = tr("CODEX_HEADER")
	codex_close_btn.text = tr("BTN_CLOSE")
	fire_bubble_btn.text = tr("BTN_DOUSE_FIRE")
	pause_title_lbl.text = tr("PAUSE_TITLE")
	save_status_lbl.text = tr("PAUSE_HINT")
	lang_btn.text = tr("BTN_LANG_SWITCH")
	resume_btn.text = tr("BTN_RESUME")
	menu_btn.text = tr("BTN_MAIN_MENU")

	var q_idx: int = int(sv.get("graphics_quality")) if sv != null else 0
	var q_keys: Array[String] = ["QUAL_HIGH", "QUAL_BALANCED", "QUAL_MOBILE"]
	quality_btn.text = tr("BTN_QUALITY_CYCLE") % tr(q_keys[clampi(q_idx, 0, 2)])
	var hb_on: bool = bool(sv.get("head_bob_enabled")) if sv != null else true
	headbob_btn.text = tr("BTN_HEADBOB_TOGGLE") % tr("ON_TXT" if hb_on else "OFF_TXT")
	var js_on: bool = thumbstick.visible if thumbstick != null else false
	joystick_btn.text = tr("BTN_JOYSTICK_TOGGLE") % tr("ON_TXT" if js_on else "OFF_TXT")

	for slot in [1, 2, 3]:
		(slot_save_btns[slot] as Button).text = tr("BTN_SAVE") % slot
		(slot_load_btns[slot] as Button).text = tr("BTN_LOAD") % slot
	for vk in vol_lbls.keys():
		var pair: Array = vol_lbls[vk]
		(pair[0] as Label).text = tr(str(pair[1]))
	_populate_codex_entries()
	refresh_save_slot_cards()


func _apply_responsive_layout() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.x < 580.0
	var is_compact_land: bool = (not is_portrait) and vp.x < 980.0

	if is_portrait:
		# 390x844 Portrait Phone: Stack Sundial Row 1, Action Pills Row 2, Badges Row 3 — ZERO Overlap!
		sundial_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
		sundial_panel.offset_left = 10
		sundial_panel.offset_right = -10
		sundial_panel.offset_top = 8
		sundial_panel.offset_bottom = 74
		top_right_hb.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top_right_hb.offset_left = 8
		top_right_hb.offset_right = -8
		top_right_hb.offset_top = 78
		top_right_hb.offset_bottom = 124
		top_right_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		badges_box.position = Vector2(10, 128)
		subtitle_panel.offset_left = 10
		subtitle_panel.offset_right = -10
		codex_drawer.offset_left = -minf(370.0, vp.x - 16.0)
		modal_card.custom_minimum_size.x = minf(540.0, vp.x - 20.0)
	elif is_compact_land:
		# 844x390 Mobile Landscape: Compact margins + thumb-safe bottom corners!
		badges_box.position = Vector2(8, 8)
		sundial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		sundial_panel.offset_left = -168
		sundial_panel.offset_right = 92
		sundial_panel.offset_top = 6
		sundial_panel.offset_bottom = 68
		top_right_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		top_right_hb.offset_left = -360
		top_right_hb.offset_right = -8
		top_right_hb.offset_top = 8
		top_right_hb.offset_bottom = 52
		subtitle_panel.offset_left = 148
		subtitle_panel.offset_right = -148
		modal_card.custom_minimum_size.x = minf(520.0, vp.x - 32.0)
	else:
		badges_box.position = Vector2(12, 10)
		sundial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		sundial_panel.offset_left = -216
		sundial_panel.offset_right = 178
		sundial_panel.offset_top = 10
		sundial_panel.offset_bottom = 80
		top_right_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		top_right_hb.offset_left = -488
		top_right_hb.offset_right = -10
		top_right_hb.offset_top = 10
		top_right_hb.offset_bottom = 56
		top_right_hb.alignment = BoxContainer.ALIGNMENT_END
		subtitle_panel.offset_left = 84
		subtitle_panel.offset_right = -84
		modal_card.custom_minimum_size.x = 560.0


func toggle_codex() -> void:
	codex_drawer.visible = not codex_drawer.visible
	if codex_drawer.visible:
		pause_overlay.hide()


func toggle_pause_menu() -> void:
	pause_overlay.visible = not pause_overlay.visible
	if pause_overlay.visible:
		codex_drawer.hide()
		refresh_save_slot_cards()
		if DisplayServer.get_name() != "headless":
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func is_blocking_modal_open() -> bool:
	return modal_overlay.visible or pause_overlay.visible or divine_seal_overlay.visible


func show_act_banner(title_txt: String, ref_txt: String) -> void:
	if title_txt.is_empty():
		return
	act_card_title.text = title_txt
	act_card_sub.text = ref_txt
	if _act_card_tween != null and _act_card_tween.is_valid():
		_act_card_tween.kill()
	act_card_root.modulate.a = 0.0
	_act_card_tween = create_tween()
	_act_card_tween.tween_property(act_card_root, "modulate:a", 1.0, 0.45)
	_act_card_tween.tween_interval(2.0)
	_act_card_tween.tween_property(act_card_root, "modulate:a", 0.0, 0.65)


func show_divine_seal(title_txt: String, verse_txt: String, instant: bool = false) -> void:
	divine_seal_title.text = title_txt
	divine_seal_verse.text = verse_txt
	divine_seal_overlay.modulate.a = 1.0 if instant else 0.0
	divine_seal_overlay.show()
	if not instant:
		create_tween().tween_property(divine_seal_overlay, "modulate:a", 1.0, 0.55)


func hide_divine_seal() -> void:
	divine_seal_overlay.hide()


func open_choice_modal(title_txt: String, ref_txt: String, body_txt: String, options: Array) -> void:
	modal_title.text = title_txt
	modal_ref.text = ref_txt
	modal_body.text = body_txt
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for c in modal_choices.get_children():
		modal_choices.remove_child(c)
		c.queue_free()
	for opt in options:
		var lbl: String = str(opt.get("label", "Continue"))
		var cb: Callable = opt.get("callback", Callable())
		var b: Button = make_pill(lbl, func() -> void:
			modal_overlay.hide()
			if cb.is_valid():
				cb.call()
		, 320, 46)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_choices.add_child(b)
	modal_overlay.show()


func update_3d_bubbles(cam: Camera3D, show_bubbles: bool, anchors_3d: Dictionary, counts: Dictionary, show_fence_btn: bool, fence_txt: String, fire_active: bool, fire_pos_3d: Vector3) -> void:
	if not show_bubbles or cam == null:
		for k in station_bubbles.keys():
			(station_bubbles[k] as Control).hide()
		fire_bubble_panel.hide()
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for k in station_bubbles.keys():
		var pc: PanelContainer = station_bubbles[k] as PanelContainer
		var wp: Vector3 = anchors_3d.get(k, Vector3.ZERO)
		if cam.is_position_behind(wp):
			pc.hide()
			continue
		var sp: Vector2 = cam.unproject_position(wp)
		(station_counts[k] as Label).text = str(counts.get(k, ""))
		if k == "guard" and fence_bubble_btn != null:
			fence_bubble_btn.visible = show_fence_btn
			fence_bubble_btn.text = fence_txt
		var sz: Vector2 = pc.get_combined_minimum_size()
		pc.position = Vector2(
			clampf(sp.x - sz.x * 0.5, 14.0, maxf(14.0, vp_size.x - sz.x - 14.0)),
			clampf(sp.y - sz.y * 0.5, 130.0, maxf(130.0, vp_size.y - sz.y - 102.0))
		)
		pc.show()
	if fire_active and not cam.is_position_behind(fire_pos_3d):
		var fp2: Vector2 = cam.unproject_position(fire_pos_3d)
		var fsz: Vector2 = fire_bubble_panel.get_combined_minimum_size()
		fire_bubble_panel.position = Vector2(
			clampf(fp2.x - fsz.x * 0.5, 14.0, maxf(14.0, vp_size.x - fsz.x - 14.0)),
			clampf(fp2.y - fsz.y - 10.0, 130.0, maxf(130.0, vp_size.y - fsz.y - 102.0))
		)
		fire_bubble_panel.show()
	else:
		fire_bubble_panel.hide()
