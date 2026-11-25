extends Control

var _save: Node:
	get: return get_node("/root/SaveManager")
var _sound: Node:
	get: return get_node("/root/SoundManager")
var _transition: Node:
	get: return get_node("/root/SceneTransition")
## Commercial Main Menu with Live 3D Dawn Ararat Vista + Audio/Graphics/Bilingual Settings Drawer:
## - Real-time low-power 3D SubViewport background: golden morning sky over Ararat, resting 300-cubit Ark, olive trees & mist
## - 100% `tr()` bilingual (`zh_CN` CUV / `en_US` WEB) + Master/Ambience/SFX dB sliders + Quality presets!

var _vista_cam: Camera3D
var _vista_t: float = 0.0
var title_lbl: Label
var sub_lbl: Label
var continue_btn: Button
var ch00_btn: Button
var p01_btn: Button
var ch01_btn: Button
var settings_btn: Button
var quit_btn: Button
var trial_hdr: Label
var trial_btns: Dictionary = {}
var status_lbl: Label

var settings_modal: ColorRect
var settings_title: Label
var lang_btn: Button
var quality_btn: Button
var headbob_btn: Button
var close_settings_btn: Button
var vol_labels: Array[Array] = []


func _ready() -> void:
	_sound.play_music("bgm_levant_lyre_loop.wav", -12.0)
	_save.ensure_translations_loaded()
	for arg in OS.get_cmdline_user_args():
		if arg == "--zh-preview": _save.set_locale("zh_CN")
		elif arg == "--en-preview": _save.set_locale("en_US")
	_build_3d_ararat_vista()
	_build_menu_ui()
	_refresh_texts()


func _process(delta: float) -> void:
	_vista_t += delta
	if _vista_cam != null and _vista_cam.is_inside_tree():
		var ang: float = -0.22 + sin(_vista_t * 0.14) * 0.14
		_vista_cam.look_at_from_position(Vector3(sin(ang) * 32.0, 9.8 + sin(_vista_t * 0.22) * 0.5, 28.0 + cos(ang) * 8.0), Vector3(-2.0, 5.0, -12.0), Vector3.UP)


func _build_3d_ararat_vista() -> void:
	var svc: SubViewportContainer = SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	var svp: SubViewport = SubViewport.new()
	svp.size = Vector2i(1280, 720)
	svp.own_world_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(svp)

	var root3d: Node3D = Node3D.new()
	root3d.name = "DawnAraratVista3D"
	svp.add_child(root3d)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_m: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_m.sky_top_color = Color(0.14, 0.24, 0.42)
	sky_m.sky_horizon_color = Color(0.92, 0.72, 0.46)
	sky_m.ground_bottom_color = Color(0.14, 0.11, 0.08)
	sky_m.ground_horizon_color = Color(0.58, 0.46, 0.34)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_m
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.34
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.76, 0.56)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.14
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-16.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.52)
	sun.light_energy = 2.05
	sun.shadow_enabled = true
	root3d.add_child(sun)
	_save.apply_graphics_quality_to_env(env, sun)
	env.volumetric_fog_density = 0.0018
	env.fog_density = 0.0012

	# Sculpted Ararat Highland Ridge Mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(36):
		for ix in range(36):
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var px: float = lerpf(-90.0, 90.0, float(ix + c.x) / 36.0)
				var pz: float = lerpf(-85.0, 65.0, float(iz + c.y) / 36.0)
				var ridge: float = exp(-pow((pz + 18.0) / 26.0, 2.0)) * 4.2 + sin(px * 0.07) * cos(pz * 0.08) * 1.4
				st.set_uv(Vector2(px, pz) * 0.08)
				st.add_vertex(Vector3(px, ridge, pz))
	st.generate_normals()
	var t_mi: MeshInstance3D = MeshInstance3D.new()
	t_mi.mesh = st.commit()
	var t_mat: StandardMaterial3D = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.46, 0.42, 0.32)
	t_mat.albedo_texture = load("res://assets/textures/terrain_grass_albedo.png") as Texture2D
	t_mat.uv1_triplanar = true
	t_mat.roughness = 0.92
	t_mi.material_override = t_mat
	root3d.add_child(t_mi)

	# Resting 300-Cubit Noah's Ark + Olive Trees + Covenant Rainbow on Ararat Ridge!
	var ark_ps: PackedScene = load("res://assets/models/BLD_NoahsArk.glb") as PackedScene
	if ark_ps != null:
		var ark_inst: Node3D = ark_ps.instantiate() as Node3D
		ark_inst.position = Vector3(-16.0, 4.0, -10.0)
		ark_inst.rotation.y = 0.42
		ark_inst.scale = Vector3.ONE * 0.44
		for mnode in ark_inst.find_children("*", "MeshInstance3D", true, false):
			if str(mnode.name).begins_with("StageScaffold"):
				(mnode as Node3D).hide()
		root3d.add_child(ark_inst)

	var tree_ps: PackedScene = load("res://assets/models/CC0_OliveTree_Optimized.glb") as PackedScene
	if tree_ps != null:
		for tp: Vector3 in [Vector3(-22, 1.8, 12), Vector3(18, 2.0, 10), Vector3(-28, 3.0, -4), Vector3(24, 3.1, -6)]:
			var tr_n: Node3D = tree_ps.instantiate() as Node3D
			tr_n.position = tp
			tr_n.scale = Vector3.ONE * 1.65
			root3d.add_child(tr_n)

	_vista_cam = Camera3D.new()
	_vista_cam.fov = 46.0
	root3d.add_child(_vista_cam)
	_vista_cam.look_at_from_position(Vector3(-12.0, 9.8, 34.0), Vector3(-4.0, 5.2, -10.0), Vector3.UP)


func _style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _make_btn(primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	var bg: Color = Color(0.28, 0.20, 0.09, 0.94) if primary else Color(0.12, 0.09, 0.06, 0.88)
	var bd: Color = Color(0.95, 0.78, 0.40) if primary else Color(0.72, 0.56, 0.30, 0.85)
	b.add_theme_stylebox_override("normal", _style(bg, bd, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.14), Color(1.0, 0.88, 0.54), 8))
	b.pressed.connect(cb)
	return b


func _build_menu_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.03, 0.02, 0.36)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 470)
	card.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.04, 0.90), Color(0.86, 0.68, 0.36), 14))
	cc.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(0.99, 0.86, 0.52))
	vb.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	vb.add_child(sub_lbl)

	var has_sv: bool = _save.first_existing_slot() >= 0
	continue_btn = _make_btn(true, _on_continue)
	continue_btn.visible = has_sv
	vb.add_child(continue_btn)

	ch00_btn = _make_btn(not has_sv, func() -> void: _transition.change_scene("res://scenes/ch00_noah_ark.tscn"))
	vb.add_child(ch00_btn)
	p01_btn = _make_btn(false, func() -> void: _transition.change_scene("res://scenes/overworld_prologue.tscn"))
	vb.add_child(p01_btn)
	ch01_btn = _make_btn(false, func() -> void: _transition.change_scene("res://scenes/camp_pilot.tscn"))
	vb.add_child(ch01_btn)
	settings_btn = _make_btn(false, func() -> void: settings_modal.show())
	vb.add_child(settings_btn)
	quit_btn = _make_btn(false, func() -> void: get_tree().quit())
	vb.add_child(quit_btn)

	trial_hdr = Label.new()
	trial_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(trial_hdr)
	var trials := HBoxContainer.new()
	trials.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(trials)
	for key: String in ["drought", "imminent", "pacifist"]:
		var b := Button.new()
		b.toggle_mode = true; b.custom_minimum_size = Vector2(120, 44)
		b.pressed.connect(func() -> void: _save.toggle_trial_mutator(key); _refresh_texts())
		trials.add_child(b); trial_btns[key] = b
	status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.78, 0.74, 0.64))
	vb.add_child(status_lbl)

	_build_settings_modal()


func _build_settings_modal() -> void:
	settings_modal = ColorRect.new()
	settings_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_modal.color = Color(0.02, 0.02, 0.02, 0.68)
	settings_modal.hide()
	add_child(settings_modal)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_modal.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 360)
	card.add_theme_stylebox_override("panel", _style(Color(0.10, 0.07, 0.04, 0.97), Color(0.88, 0.70, 0.36), 12))
	cc.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	settings_title = Label.new()
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 19)
	settings_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50))
	vb.add_child(settings_title)

	for spec in [
		["master_db", "LBL_VOL_MASTER", _save.master_db],
		["ambience_db", "LBL_VOL_AMB", _save.ambience_db],
		["sfx_db", "LBL_VOL_SFX", _save.sfx_db],
	]:
		var prop: String = str(spec[0])
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		vb.add_child(hb)
		var lb := Label.new()
		lb.custom_minimum_size = Vector2(96, 26)
		lb.add_theme_color_override("font_color", Color(0.94, 0.88, 0.76))
		hb.add_child(lb)
		vol_labels.append([lb, str(spec[1])])
		var sld := HSlider.new()
		sld.min_value = -40.0
		sld.max_value = 6.0
		sld.step = 0.5
		sld.value = float(spec[2])
		sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sld.custom_minimum_size = Vector2(200, 30)
		sld.value_changed.connect(func(v: float) -> void:
			_save.set(prop, v)
			_save.save_settings()
		)
		hb.add_child(sld)

	lang_btn = _make_btn(false, func() -> void:
		var nxt: String = "en_US" if _save.current_locale == "zh_CN" else "zh_CN"
		_save.set_locale(nxt)
		_sound.play_sfx("sfx_ui_click.wav", -5.0)
		_refresh_texts()
	)
	vb.add_child(lang_btn)

	quality_btn = _make_btn(false, func() -> void:
		_save.graphics_quality = (_save.graphics_quality + 1) % 3
		_save.save_settings()
		_sound.play_sfx("sfx_ui_click.wav", -5.0)
		_refresh_texts()
	)
	vb.add_child(quality_btn)

	headbob_btn = _make_btn(false, func() -> void:
		_save.head_bob_enabled = not _save.head_bob_enabled
		_save.save_settings()
		_sound.play_sfx("sfx_ui_click.wav", -5.0)
		_refresh_texts()
	)
	vb.add_child(headbob_btn)

	close_settings_btn = _make_btn(true, func() -> void: settings_modal.hide())
	vb.add_child(close_settings_btn)


func _on_continue() -> void:
	var s: int = _save.first_existing_slot()
	if s < 0:
		s = 1
	var d: Dictionary = _save.load_slot(s)
	_save.pending_load_slot = s
	var ch_id: String = str(d.get("chapter_id", "ch00_noah_ark"))
	var target: String = "res://scenes/ch00_noah_ark.tscn"
	if ch_id == "overworld_prologue":
		target = "res://scenes/overworld_prologue.tscn"
	elif ch_id == "ch01_bethel":
		target = "res://scenes/camp_pilot.tscn"
	_transition.change_scene(target)


func _refresh_texts() -> void:
	title_lbl.text = tr("MENU_TITLE")
	sub_lbl.text = tr("MENU_SUBTITLE")
	continue_btn.text = tr("MENU_CONTINUE")
	ch00_btn.text = tr("MENU_CH00")
	p01_btn.text = tr("MENU_P01")
	ch01_btn.text = tr("MENU_CH01")
	settings_btn.text = tr("MENU_SETTINGS")
	quit_btn.text = tr("MENU_QUIT")
	settings_title.text = tr("MENU_SETTINGS")
	lang_btn.text = tr("BTN_LANG_SWITCH")
	var q_keys: Array[String] = ["QUAL_HIGH", "QUAL_BALANCED", "QUAL_MOBILE"]
	var q_txt: String = tr(q_keys[clampi(_save.graphics_quality, 0, 2)])
	quality_btn.text = tr("BTN_QUALITY_CYCLE") % q_txt
	var bob_txt: String = tr("ON_TXT" if _save.head_bob_enabled else "OFF_TXT")
	headbob_btn.text = tr("BTN_HEADBOB_TOGGLE") % bob_txt
	close_settings_btn.text = tr("BTN_CLOSE")
	for pair in vol_labels:
		(pair[0] as Label).text = tr(str(pair[1]))
	trial_hdr.text = tr("TRIAL_HDR")
	for key in trial_btns:
		var b: Button = trial_btns[key]
		b.text = tr("TRIAL_" + str(key).to_upper())
		b.set_pressed_no_signal(bool(_save.trial_mutators.get(key, false)))
		b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.09, 0.06), Color(0.6, 0.48, 0.28), 18))
		b.add_theme_stylebox_override("pressed", _style(Color(0.28, 0.20, 0.09), Color(1.0, 0.82, 0.32), 18))
	status_lbl.text = tr("MENU_FOOTER") % [bob_txt, q_txt, _save.covenant_stones_lit.size()] + "\n" + tr("MENU_SEALS") % _save.golden_seals_earned.size()

