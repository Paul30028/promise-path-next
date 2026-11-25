class_name GameplayV2HudBar
extends Control
## Modular Gameplay 2.0 HUD Overlay (`Phase A` Steam Playability Overhaul):
## - Top-Left (below Resource Badges): Companion Stamina/Rest Strip + 3 Camp Workshop Upgrade Pills (`[1][2][3]`)
## - Bottom-Right (above Subtitle): Patriarch Active Skill Bar (`[Q] Shofar` + `[R] Rhythmic Assist` + live Bronze Timing Gauge)
## - Bottom-Center (in `[Space]` Tactical Mode): `[P] 0.0x Pause / 0.35x Flow` + 3 Historical Tactical Action Cards!

signal request_shofar
signal request_assist
signal request_upgrade(slot_idx: int)
signal request_play_card(card_idx: int)
signal request_toggle_freeze

class TimingGaugeBar extends Control:
	var active: bool = false
	var cursor: float = 0.5

	func _draw() -> void:
		if not active:
			return
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.06, 0.04, 0.94), true)
		# Bronze outer good zone (0.22..0.78)
		draw_rect(Rect2(size.x * 0.22, 2.0, size.x * 0.56, size.y - 4.0), Color(0.46, 0.34, 0.16, 0.78), true)
		# Bright Gold PERFECT sweet spot (0.36..0.64)
		draw_rect(Rect2(size.x * 0.36, 2.0, size.x * 0.28, size.y - 4.0), Color(0.98, 0.82, 0.28, 0.95), true)
		draw_rect(r, Color(0.86, 0.68, 0.34), false, 1.5)
		var nx: float = clampf(cursor, 0.02, 0.98) * size.x
		draw_line(Vector2(nx, -2.0), Vector2(nx, size.y + 2.0), Color(1.0, 0.98, 0.88), 3.0)


var left_workshop_vb: VBoxContainer
var comp_strip_lbl: Label
var deluge_warn_lbl: Label
var upg_btns: Array[Button] = []

var skill_dock: VBoxContainer
var timing_gauge: TimingGaugeBar
var shofar_btn: Button
var assist_btn: Button

var card_dock: PanelContainer
var pip_lbl: Label
var freeze_btn: Button
var card_btns: Array[Button] = []


func _box(bg: Color, border: Color, rad: int = 7, ph: int = 8, pv: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(rad)
	s.content_margin_left = ph
	s.content_margin_right = ph
	s.content_margin_top = pv
	s.content_margin_bottom = pv
	return s


func _btn(txt: String, cb: Callable, mw: float = 84.0, mh: float = 40.0, fsz: int = 12) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(mw, mh)
	b.add_theme_font_size_override("font_size", fsz)
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	b.add_theme_stylebox_override("normal", _box(Color(0.12, 0.09, 0.05, 0.90), Color(0.78, 0.60, 0.30)))
	b.add_theme_stylebox_override("hover", _box(Color(0.24, 0.17, 0.09, 0.96), Color(0.98, 0.82, 0.44)))
	b.add_theme_stylebox_override("disabled", _box(Color(0.09, 0.08, 0.06, 0.72), Color(0.42, 0.36, 0.26)))
	b.pressed.connect(cb)
	return b


func build_bars() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Top-Left Companion Stamina Strip + 3 Workshop Upgrade Buttons (y = 74)
	left_workshop_vb = VBoxContainer.new()
	left_workshop_vb.position = Vector2(12, 74)
	left_workshop_vb.add_theme_constant_override("separation", 4)
	left_workshop_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_workshop_vb)

	var comp_pc := PanelContainer.new()
	comp_pc.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.04, 0.86), Color(0.68, 0.54, 0.28), 6, 8, 3))
	left_workshop_vb.add_child(comp_pc)
	comp_strip_lbl = Label.new()
	comp_strip_lbl.add_theme_font_size_override("font_size", 11)
	comp_strip_lbl.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	comp_pc.add_child(comp_strip_lbl)

	var upg_hb := HBoxContainer.new()
	upg_hb.add_theme_constant_override("separation", 4)
	left_workshop_vb.add_child(upg_hb)
	for i in range(3):
		var idx: int = i
		var ub: Button = _btn("[1]", func() -> void: request_upgrade.emit(idx), 92.0, 36.0, 11)
		upg_hb.add_child(ub)
		upg_btns.append(ub)

	deluge_warn_lbl = Label.new()
	deluge_warn_lbl.add_theme_font_size_override("font_size", 12)
	deluge_warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.46, 0.36))
	deluge_warn_lbl.hide()
	left_workshop_vb.add_child(deluge_warn_lbl)

	# 2. Bottom-Right Patriarch Active Skill Bar (`[Q] Shofar` + `[R] Assist` + Timing Gauge)
	skill_dock = VBoxContainer.new()
	skill_dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skill_dock.offset_left = -268
	skill_dock.offset_right = -14
	skill_dock.offset_top = -146
	skill_dock.offset_bottom = -78
	skill_dock.alignment = BoxContainer.ALIGNMENT_END
	skill_dock.add_theme_constant_override("separation", 4)
	add_child(skill_dock)

	timing_gauge = TimingGaugeBar.new()
	timing_gauge.custom_minimum_size = Vector2(250, 18)
	timing_gauge.hide()
	skill_dock.add_child(timing_gauge)

	var sk_hb := HBoxContainer.new()
	sk_hb.alignment = BoxContainer.ALIGNMENT_END
	sk_hb.add_theme_constant_override("separation", 6)
	skill_dock.add_child(sk_hb)
	shofar_btn = _btn("Shofar [Q]", func() -> void: request_shofar.emit(), 116.0, 44.0, 12)
	sk_hb.add_child(shofar_btn)
	assist_btn = _btn("Assist [R]", func() -> void: request_assist.emit(), 126.0, 44.0, 12)
	sk_hb.add_child(assist_btn)

	# 3. Bottom-Center Tactical Pause & Historical Action Cards Dock (visible in `[Space]` mode)
	card_dock = PanelContainer.new()
	card_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card_dock.offset_left = -365
	card_dock.offset_right = 365
	card_dock.offset_top = -152
	card_dock.offset_bottom = -78
	card_dock.add_theme_stylebox_override("panel", _box(Color(0.09, 0.06, 0.04, 0.94), Color(0.92, 0.74, 0.36), 10, 10, 6))
	card_dock.hide()
	add_child(card_dock)

	var cd_hb := HBoxContainer.new()
	cd_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	cd_hb.add_theme_constant_override("separation", 8)
	card_dock.add_child(cd_hb)

	var left_meta := VBoxContainer.new()
	left_meta.alignment = BoxContainer.ALIGNMENT_CENTER
	cd_hb.add_child(left_meta)
	pip_lbl = Label.new()
	pip_lbl.add_theme_font_size_override("font_size", 12)
	pip_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	left_meta.add_child(pip_lbl)
	freeze_btn = _btn("Freeze [P]", func() -> void: request_toggle_freeze.emit(), 108.0, 36.0, 11)
	left_meta.add_child(freeze_btn)

	for ci in range(3):
		var cidx: int = ci
		var cb_card: Button = _btn("Card", func() -> void: request_play_card.emit(cidx), 186.0, 56.0, 11)
		cb_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cd_hb.add_child(cb_card)
		card_btns.append(cb_card)


func sync_hud(v2: GameplayV2Director, sim: DeterministicEconomySim, show_economy: bool, tactical_mode: bool, fp_mode: bool) -> void:
	if v2 == null or sim == null:
		return
	left_workshop_vb.visible = show_economy and (not fp_mode)
	skill_dock.visible = show_economy and (not tactical_mode) and (not fp_mode)
	card_dock.visible = show_economy and tactical_mode

	comp_strip_lbl.text = tr("HUD_COMP_STRIP") % [int(roundf(sim.average_stamina())), sim.resting_companion_count()]
	deluge_warn_lbl.visible = sim.deluge_emergency
	if sim.deluge_emergency:
		deluge_warn_lbl.text = tr("HUD_DELUGE_WARN")

	var u_defs: Array[Dictionary] = v2.get_workshop_defs()
	for i in range(mini(3, u_defs.size())):
		var b: Button = upg_btns[i]
		var built: bool = sim.upgrades_unlocked[i]
		var cost: Vector2 = sim.upgrade_cost(i)
		if built:
			b.text = "%s %s" % [tr(str(u_defs[i]["title"])), tr("UPG_DONE")]
			b.disabled = true
			b.modulate = Color(0.68, 1.0, 0.74)
		else:
			var c_str: String = "(%d)" % int(cost.x) if cost.y <= 0.1 else "(%d/%d)" % [int(cost.x), int(cost.y)]
			b.text = "%s %s" % [tr(str(u_defs[i]["title"])), c_str]
			b.tooltip_text = tr(str(u_defs[i]["desc"]))
			b.disabled = not sim.can_unlock_upgrade(i)
			b.modulate = Color.WHITE

	# Patriarch Shofar & Assist
	if sim.shofar_cd > 0.05:
		shofar_btn.text = tr("BTN_SHOFAR_CD") % int(ceil(sim.shofar_cd))
		shofar_btn.disabled = true
	else:
		shofar_btn.text = tr("BTN_SHOFAR_READY")
		shofar_btn.disabled = false
	shofar_btn.modulate = Color(1.0, 0.92, 0.55) if sim.shofar_buff_timer > 0.0 else Color.WHITE

	timing_gauge.active = v2.assist_active
	timing_gauge.visible = v2.assist_active
	timing_gauge.cursor = v2.assist_cursor
	if v2.assist_active:
		timing_gauge.queue_redraw()
		assist_btn.text = tr("BTN_ASSIST_HIT")
		assist_btn.disabled = false
	else:
		assist_btn.text = tr("BTN_ASSIST_IDLE")
		assist_btn.disabled = (v2.assist_cooldown > 0.05)

	# Tactical Pause & Historical Action Cards
	if card_dock.visible:
		var pips_dots: String = "●".repeat(sim.command_pips) + "○".repeat(maxi(0, sim.cfg.command_pip_max - sim.command_pips))
		pip_lbl.text = "%s %s" % [tr("HUD_PIPS_LABEL") % [sim.command_pips, sim.cfg.command_pip_max], pips_dots]
		freeze_btn.text = tr("BTN_PAUSE_FLOW" if v2.tactical_paused else "BTN_PAUSE_FREEZE")
		var cards: Array[Dictionary] = v2.get_tactical_cards()
		for ci in range(mini(3, cards.size())):
			var cd: Dictionary = cards[ci]
			var cb: Button = card_btns[ci]
			cb.text = "%s\n%s" % [tr(str(cd["title"])), tr(str(cd["desc"]))]
			cb.disabled = (sim.command_pips < int(cd["cost"]))
