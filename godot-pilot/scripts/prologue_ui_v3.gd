class_name PrologueUIV3
extends CanvasLayer
## Game UI V3 for Prologue (Noah's Ark):
## - Top-Center Bronze Weather Sundial + 300-Cubit Ark Progress Gauge (35% / 75% / 100% ticks)
## - Top-Left 4 Compact Resource & Family Harmony Badges (zero 7-in-1 text wall!)
## - Top-Right View & Codex Pills (>= 48x44px touch targets)
## - [Space] Tactical Sandbox Overlay + 3D-Projected World Station Bubbles
## - [J] Collapsible Biblical Canon & Historical Adaptation Codex Scroll
## - [Esc] Pause, 3-Slot Atomic Save/Load & CUV/WEB Bilingual Switcher
## - Act Title Card + 5-Second Reverent "Yahweh Shut Him In" (Gen 7:16) Overlay

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
signal request_main_menu

class SundialArkGauge extends Control:
	var days_left: float = 240.0
	var max_days: float = 240.0
	var ark_pct: float = 0.0
	var weather_text: String = "晴空微风"
	var step_count: int = 0
	var pulse_t: float = 0.0

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# 1. Left-side Bronze Sundial Medallion (never crosses text!)
		var arch_r: float = 22.0
		var arch_cx: float = 30.0
		var arch_cy: float = 31.0
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
		draw_circle(tip, 3.2, Color(1.0, 0.92, 0.56))

		# 2. Right-side 300-Cubit Ark Silhouette Progress Bar
		var bx: float = 64.0
		var bw: float = w - 76.0
		var by: float = h - 18.0
		var bh: float = 12.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0.07, 0.05, 0.03, 0.92), true)
		var fill_w: float = bw * clampf(ark_pct / 100.0, 0.0, 1.0)
		if fill_w > 1.0:
			draw_rect(Rect2(bx + 1.0, by + 1.0, fill_w - 2.0, bh - 2.0), Color(0.84, 0.63, 0.28, 0.95), true)
		draw_rect(Rect2(bx, by, bw, bh), bronze, false, 1.4)
		for tick_pct in [0.35, 0.75]:
			var tx: float = bx + bw * tick_pct
			draw_line(Vector2(tx, by - 2.5), Vector2(tx, by + bh + 2.5), Color(0.98, 0.86, 0.52, 0.85), 1.5)


var lang: String = "zh_CN"
var sundial_panel: PanelContainer
var sundial_gauge: SundialArkGauge
var sundial_title_lbl: Label
var sundial_sub_lbl: Label

var badges_box: VBoxContainer
var badge_panels: Dictionary = {}
var badge_labels: Dictionary = {}

var fp_btn: Button
var tactical_btn: Button
var cutaway_btn: Button
var codex_btn: Button
var pause_btn: Button
var fp_crosshair: ColorRect

var tactical_border: PanelContainer
var tactical_banner_lbl: Label
var bubble_layer: Control
var station_bubbles: Dictionary = {}  # key -> PanelContainer
var station_counts: Dictionary = {}   # key -> Label
var fence_bubble_btn: Button
var fire_bubble_panel: PanelContainer
var fire_bubble_btn: Button

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
var codex_list_vb: VBoxContainer

var pause_overlay: ColorRect
var save_status_lbl: Label
var lang_btn: Button
var headbob_btn: Button

var modal_overlay: ColorRect
var modal_title: Label
var modal_ref: Label
var modal_body: Label
var modal_choices: VBoxContainer


func _style_box(bg: Color, border: Color, radius: int = 8, pad_h: int = 12, pad_v: int = 7) -> StyleBoxFlat:
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


func make_pill(text: String, cb: Callable, min_w: float = 84.0, min_h: float = 44.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(48.0, min_w), maxf(44.0, min_h))
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	b.add_theme_stylebox_override("normal", _style_box(Color(0.13, 0.09, 0.05, 0.88), Color(0.76, 0.58, 0.30), 7, 10, 6))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.24, 0.17, 0.09, 0.96), Color(0.96, 0.80, 0.44), 7, 10, 6))
	b.add_theme_stylebox_override("pressed", _style_box(Color(0.30, 0.21, 0.10, 0.98), Color(1.0, 0.86, 0.50), 7, 10, 6))
	b.pressed.connect(cb)
	return b


func build_ui(codex_entries: Array) -> void:
	layer = 10

	# 0. Tactical Sandbox Golden Frame Banner (shown ONLY when [Space] Tactical Mode is active!)
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
	tactical_banner_lbl.text = "【沙盘战术俯瞰 · 时间 0.35x】WASD 平移镜头 · 点击 3D 区域气泡派工 · 再按 [Space] 返回亲临"
	tactical_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	tactical_banner_lbl.add_theme_font_size_override("font_size", 12)
	tb_chip.add_child(tactical_banner_lbl)

	# 1. 3D-Projected Tactical Station Bubbles Layer
	bubble_layer = Control.new()
	bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble_layer)
	_build_3d_station_bubbles()

	# 2. Top-Left 4 Compact Resource & Harmony Badges
	badges_box = VBoxContainer.new()
	badges_box.position = Vector2(14, 12)
	badges_box.add_theme_constant_override("separation", 5)
	add_child(badges_box)
	var hb_row1: HBoxContainer = HBoxContainer.new()
	hb_row1.add_theme_constant_override("separation", 6)
	badges_box.add_child(hb_row1)
	var hb_row2: HBoxContainer = HBoxContainer.new()
	hb_row2.add_theme_constant_override("separation", 6)
	badges_box.add_child(hb_row2)

	for spec in [
		["timber", "歌斐木 45", hb_row1],
		["pitch", "松香 15", hb_row1],
		["provisions", "粮草 60", hb_row2],
		["harmony", "家族信心 84%", hb_row2],
	]:
		var k: String = str(spec[0])
		var pc: PanelContainer = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.84), Color(0.72, 0.55, 0.28, 0.86), 6, 10, 5))
		(spec[2] as HBoxContainer).add_child(pc)
		var lb: Label = Label.new()
		lb.text = str(spec[1])
		lb.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80))
		lb.add_theme_font_size_override("font_size", 13)
		pc.add_child(lb)
		badge_panels[k] = pc
		badge_labels[k] = lb

	# 3. Top-Center Bronze Sundial + 300-Cubit Ark Gauge
	sundial_panel = PanelContainer.new()
	sundial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sundial_panel.offset_left = -215
	sundial_panel.offset_right = 155
	sundial_panel.offset_top = 10
	sundial_panel.offset_bottom = 82
	sundial_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.88), Color(0.80, 0.62, 0.32, 0.90), 10, 8, 4))
	add_child(sundial_panel)

	var sd_root: Control = Control.new()
	sd_root.custom_minimum_size = Vector2(354, 62)
	sundial_panel.add_child(sd_root)
	sundial_gauge = SundialArkGauge.new()
	sundial_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	sd_root.add_child(sundial_gauge)

	sundial_title_lbl = Label.new()
	sundial_title_lbl.position = Vector2(64, 3)
	sundial_title_lbl.size = Vector2(280, 20)
	sundial_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sundial_title_lbl.add_theme_color_override("font_color", Color(0.99, 0.92, 0.74))
	sundial_title_lbl.add_theme_font_size_override("font_size", 13)
	sd_root.add_child(sundial_title_lbl)

	sundial_sub_lbl = Label.new()
	sundial_sub_lbl.position = Vector2(64, 22)
	sundial_sub_lbl.size = Vector2(280, 18)
	sundial_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sundial_sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	sundial_sub_lbl.add_theme_font_size_override("font_size", 11)
	sd_root.add_child(sundial_sub_lbl)

	# 4. Top-Right Action Pills (>= 48x44px, zero right-edge clipping!)
	var tr_hb: HBoxContainer = HBoxContainer.new()
	tr_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_hb.offset_left = -488
	tr_hb.offset_right = -12
	tr_hb.offset_top = 12
	tr_hb.offset_bottom = 58
	tr_hb.alignment = BoxContainer.ALIGNMENT_END
	tr_hb.add_theme_constant_override("separation", 4)
	add_child(tr_hb)

	fp_btn = make_pill("第一人称 [F]", func() -> void: request_toggle_fp.emit(), 86, 44)
	tr_hb.add_child(fp_btn)
	tactical_btn = make_pill("沙盘 [Space]", func() -> void: request_toggle_tactical.emit(), 92, 44)
	tr_hb.add_child(tactical_btn)
	cutaway_btn = make_pill("剖面 [V]", func() -> void: request_toggle_cutaway.emit(), 62, 44)
	tr_hb.add_child(cutaway_btn)
	codex_btn = make_pill("手卷 [J]", toggle_codex, 68, 44)
	tr_hb.add_child(codex_btn)
	pause_btn = make_pill("菜单 [Esc]", toggle_pause_menu, 74, 44)
	tr_hb.add_child(pause_btn)

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

	# 6. Center-Bottom [E] World Interaction Pill (>= 44px height)
	interact_prompt = make_pill("[E] 交互", func() -> void: request_interact.emit(), 360, 46)
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_prompt.offset_left = -220
	interact_prompt.offset_right = 220
	interact_prompt.offset_top = -124
	interact_prompt.offset_bottom = -78
	interact_prompt.add_theme_font_size_override("font_size", 15)
	interact_prompt.add_theme_stylebox_override("normal", _style_box(Color(0.20, 0.14, 0.06, 0.94), Color(0.98, 0.80, 0.38), 20, 16, 8))
	interact_prompt.hide()
	add_child(interact_prompt)

	# 7. Pure Cinematic Subtitle Strip (100% free of parenthetical dev notes!)
	subtitle_panel = PanelContainer.new()
	subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_panel.offset_left = 96
	subtitle_panel.offset_right = -96
	subtitle_panel.offset_top = -68
	subtitle_panel.offset_bottom = -12
	subtitle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.05, 0.04, 0.80), Color(0.66, 0.50, 0.25, 0.68), 8, 14, 7))
	add_child(subtitle_panel)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_panel.add_child(subtitle_label)

	# 8. Upper-Center Gold Serif Act Title Card (fades out cleanly after 2.4s)
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
	ac_pc.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.05, 0.03, 0.88), Color(0.92, 0.74, 0.36, 0.92), 10, 24, 10))
	ac_cc.add_child(ac_pc)
	var ac_vb: VBoxContainer = VBoxContainer.new()
	ac_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ac_pc.add_child(ac_vb)
	act_card_title = Label.new()
	act_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	act_card_title.add_theme_font_size_override("font_size", 20)
	ac_vb.add_child(act_card_title)
	act_card_sub = Label.new()
	act_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_card_sub.add_theme_color_override("font_color", Color(0.88, 0.80, 0.64))
	act_card_sub.add_theme_font_size_override("font_size", 13)
	ac_vb.add_child(act_card_sub)

	# 9. Reverent 5-Second "Yahweh Shut Him In" (Gen 7:16) Overlay
	divine_seal_overlay = ColorRect.new()
	divine_seal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	divine_seal_overlay.color = Color(0.02, 0.02, 0.03, 0.42)
	divine_seal_overlay.hide()
	add_child(divine_seal_overlay)
	var ds_cc: CenterContainer = CenterContainer.new()
	ds_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	divine_seal_overlay.add_child(ds_cc)
	var ds_card: PanelContainer = PanelContainer.new()
	ds_card.custom_minimum_size = Vector2(720, 150)
	ds_card.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.94), Color(0.92, 0.74, 0.36), 12, 28, 22))
	ds_cc.add_child(ds_card)
	var ds_vb: VBoxContainer = VBoxContainer.new()
	ds_vb.add_theme_constant_override("separation", 12)
	ds_card.add_child(ds_vb)
	divine_seal_title = Label.new()
	divine_seal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_seal_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	divine_seal_title.add_theme_font_size_override("font_size", 26)
	ds_vb.add_child(divine_seal_title)
	divine_seal_verse = Label.new()
	divine_seal_verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_seal_verse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	divine_seal_verse.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	divine_seal_verse.add_theme_font_size_override("font_size", 17)
	ds_vb.add_child(divine_seal_verse)

	# 10. [J] Biblical Canon & Historical Adaptation Codex Drawer
	_build_codex_drawer(codex_entries)

	# 11. [Esc] Pause, 3-Slot Save/Load & Bilingual Menu
	_build_pause_menu()

	# 12. Dramatic Choice Scroll Modal
	_build_dramatic_modal()


func _build_3d_station_bubbles() -> void:
	var specs: Array[Array] = [
		["log", "东坡伐木"],
		["build", "船坞建舟"],
		["pitch", "松香储粮"],
		["guard", "南坡盾卫"],
	]
	for sp in specs:
		var k: String = str(sp[0])
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
		var bm: Button = make_pill("-", func() -> void: request_assign_worker.emit(k, -1), 48, 44)
		hb.add_child(bm)
		var lb: Label = Label.new()
		lb.custom_minimum_size = Vector2(106, 36)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
		lb.add_theme_font_size_override("font_size", 14)
		hb.add_child(lb)
		var bp: Button = make_pill("+", func() -> void: request_assign_worker.emit(k, 1), 48, 44)
		hb.add_child(bp)
		if k == "guard":
			fence_bubble_btn = make_pill("修筑木栅 (-40木)", func() -> void: request_fence_work.emit(), 196, 44)
			fence_bubble_btn.hide()
			vb.add_child(fence_bubble_btn)
		station_bubbles[k] = pc
		station_counts[k] = lb

	fire_bubble_panel = PanelContainer.new()
	fire_bubble_panel.add_theme_stylebox_override("panel", _style_box(Color(0.32, 0.08, 0.04, 0.95), Color(1.0, 0.48, 0.20), 10, 8, 5))
	fire_bubble_panel.hide()
	bubble_layer.add_child(fire_bubble_panel)
	fire_bubble_btn = make_pill("山泉提水扑救火情!", func() -> void: request_douse_fire.emit(), 188, 44)
	fire_bubble_panel.add_child(fire_bubble_btn)


func _build_codex_drawer(codex_entries: Array) -> void:
	codex_drawer = PanelContainer.new()
	codex_drawer.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	codex_drawer.offset_left = -460
	codex_drawer.offset_right = -16
	codex_drawer.offset_top = -245
	codex_drawer.offset_bottom = 245
	codex_drawer.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.96), Color(0.88, 0.70, 0.36), 10, 16, 12))
	codex_drawer.hide()
	add_child(codex_drawer)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	codex_drawer.add_child(vb)

	var hdr_hb: HBoxContainer = HBoxContainer.new()
	vb.add_child(hdr_hb)
	var hdr: Label = Label.new()
	hdr.text = "正典经文与历史工程考据手卷 [J]"
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	hdr.add_theme_font_size_override("font_size", 17)
	hdr_hb.add_child(hdr)
	hdr_hb.add_child(make_pill("关闭", toggle_codex, 64, 44))

	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	codex_list_vb = VBoxContainer.new()
	codex_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_list_vb.custom_minimum_size = Vector2(394, 0)
	codex_list_vb.add_theme_constant_override("separation", 10)
	sc.add_child(codex_list_vb)

	for entry in codex_entries:
		if not (entry is Dictionary):
			continue
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style_box(Color(0.16, 0.12, 0.07, 0.92), Color(0.68, 0.52, 0.26), 7, 12, 8))
		codex_list_vb.add_child(card)
		var cvb: VBoxContainer = VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 4)
		card.add_child(cvb)
		var tl: Label = Label.new()
		tl.text = "%s  ·  %s" % [str(entry.get("titleZh", "")), str(entry.get("canonRef", ""))]
		tl.add_theme_color_override("font_color", Color(0.99, 0.86, 0.50))
		tl.add_theme_font_size_override("font_size", 14)
		cvb.add_child(tl)
		var cl: Label = Label.new()
		cl.text = str(entry.get("canonTextZh", ""))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
		cl.add_theme_font_size_override("font_size", 13)
		cvb.add_child(cl)
		var al: Label = Label.new()
		al.text = str(entry.get("adaptationNoteZh", ""))
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.add_theme_color_override("font_color", Color(0.76, 0.86, 0.74))
		al.add_theme_font_size_override("font_size", 12)
		cvb.add_child(al)


func _build_pause_menu() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.02, 0.02, 0.02, 0.64)
	pause_overlay.hide()
	add_child(pause_overlay)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(cc)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 360)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.97), Color(0.86, 0.68, 0.36), 10, 20, 16))
	cc.add_child(card)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var tl: Label = Label.new()
	tl.text = "行旅菜单 · 原子存档与双语设置"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	tl.add_theme_font_size_override("font_size", 19)
	vb.add_child(tl)

	save_status_lbl = Label.new()
	save_status_lbl.text = "选择槽位保存或读取进度（公有领域经文 CUV / WEB）"
	save_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	save_status_lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(save_status_lbl)

	for slot in [1, 2, 3]:
		var shb: HBoxContainer = HBoxContainer.new()
		shb.add_theme_constant_override("separation", 8)
		vb.add_child(shb)
		var sb: Button = make_pill("保存至槽位 %d" % slot, func() -> void: request_save_slot.emit(slot), 196, 44)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shb.add_child(sb)
		var lb: Button = make_pill("读取槽位 %d" % slot, func() -> void: request_load_slot.emit(slot), 196, 44)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shb.add_child(lb)

	lang_btn = make_pill("经文与界面语言：简体中文 (和合本 CUV)", func() -> void:
		lang = "en_US" if lang == "zh_CN" else "zh_CN"
		lang_btn.text = "Language: English (WEB Public Domain)" if lang == "en_US" else "经文与界面语言：简体中文 (和合本 CUV)"
		request_lang_changed.emit(lang)
	, 380, 44)
	vb.add_child(lang_btn)

	var hb_bot: HBoxContainer = HBoxContainer.new()
	hb_bot.add_theme_constant_override("separation", 8)
	vb.add_child(hb_bot)
	var resume_b: Button = make_pill("继续立约之旅 [Esc]", toggle_pause_menu, 190, 44)
	resume_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_bot.add_child(resume_b)
	var menu_b: Button = make_pill("返回标题主菜单", func() -> void: request_main_menu.emit(), 190, 44)
	menu_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_bot.add_child(menu_b)


func _build_dramatic_modal() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(0.02, 0.02, 0.02, 0.56)
	modal_overlay.hide()
	add_child(modal_overlay)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.add_child(cc)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(580.0, 260.0)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.97), Color(0.88, 0.70, 0.36), 10, 20, 16))
	cc.add_child(card)
	var mvb: VBoxContainer = VBoxContainer.new()
	mvb.add_theme_constant_override("separation", 10)
	card.add_child(mvb)
	modal_title = Label.new()
	modal_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	modal_title.add_theme_font_size_override("font_size", 20)
	mvb.add_child(modal_title)
	modal_ref = Label.new()
	modal_ref.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56))
	modal_ref.add_theme_font_size_override("font_size", 12)
	mvb.add_child(modal_ref)
	modal_body = Label.new()
	modal_body.custom_minimum_size = Vector2(530.0, 0.0)
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	modal_body.add_theme_font_size_override("font_size", 15)
	mvb.add_child(modal_body)
	modal_choices = VBoxContainer.new()
	modal_choices.add_theme_constant_override("separation", 8)
	mvb.add_child(modal_choices)


func toggle_codex() -> void:
	codex_drawer.visible = not codex_drawer.visible
	if codex_drawer.visible:
		pause_overlay.hide()


func toggle_pause_menu() -> void:
	pause_overlay.visible = not pause_overlay.visible
	if pause_overlay.visible:
		codex_drawer.hide()


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
	for c in modal_choices.get_children():
		modal_choices.remove_child(c)
		c.queue_free()
	for opt in options:
		var lbl: String = str(opt.get("label", "继续"))
		var cb: Callable = opt.get("callback", Callable())
		var b: Button = make_pill(lbl, func() -> void:
			modal_overlay.hide()
			if cb.is_valid():
				cb.call()
		, 520, 46)
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
			clampf(sp.x - sz.x * 0.5, 12.0, maxf(12.0, vp_size.x - sz.x - 12.0)),
			clampf(sp.y - sz.y * 0.5, 92.0, maxf(92.0, vp_size.y - sz.y - 84.0))
		)
		pc.show()
	if fire_active and not cam.is_position_behind(fire_pos_3d):
		var fp2: Vector2 = cam.unproject_position(fire_pos_3d)
		var fsz: Vector2 = fire_bubble_panel.get_combined_minimum_size()
		fire_bubble_panel.position = Vector2(
			clampf(fp2.x - fsz.x * 0.5, 12.0, maxf(12.0, vp_size.x - fsz.x - 12.0)),
			clampf(fp2.y - fsz.y - 10.0, 92.0, maxf(92.0, vp_size.y - fsz.y - 84.0))
		)
		fire_bubble_panel.show()
	else:
		fire_bubble_panel.hide()
