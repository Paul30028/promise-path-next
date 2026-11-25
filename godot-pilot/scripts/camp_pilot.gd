extends ChapterRuntimeHost
## Chapter 1 Cartridge Coordinator (`Ch01` Shechem & Bethel 128x96 7-Zone Highland — <= 350 lines on `ChapterRuntimeHost`!):
## Honors cross-chapter `CampaignSaveV3.carryover_ledger` and runs on the exact same V6 Core as `Ch00`!

const DATA_PATH: String = "res://data/ch01_bethel.json"
const BALANCE_RES: Resource = preload("res://resources/ch01_balance.tres")

var world: BethelHighlandWorld
var cast_nodes: Array[Node3D] = []
var cast_labels: Array[Label3D] = []
var flock_animals: Array[Node3D] = []
var tent_fp_local: Vector3 = Vector3(0.0, 0.05, 0.8)
var elapsed: float = 0.0


func _ready() -> void:
	chapter_id = "ch01_bethel"
	register_standard_inputs()
	sim = DeterministicEconomySim.new(BALANCE_RES as ChapterBalanceResource)
	story = StoryStateDirector.new()
	add_child(story)
	chapter = story.setup_from_json(DATA_PATH)

	var init_st: Dictionary = chapter.get("initialState", {})
	sim.res_primary = float(init_st.get("water", 28.0))
	sim.res_secondary = float(init_st.get("firewood", 16.0))
	sim.res_tertiary = float(init_st.get("flock", 64.0))
	sim.harmony = float(init_st.get("harmony", 82.0))
	sim.pasture_pressure = float(init_st.get("pressure", 35.0))
	sim.monument_pct = 20.0
	sim.w_gather = 2; sim.w_build = 1; sim.w_craft = 1; sim.w_guard = 1

	var sv: Node = get_node_or_null("/root/SaveManager")
	if sv != null and sv.get("carryover_ledger") is Dictionary:
		var co: Dictionary = sv.get("carryover_ledger")
		sim.res_primary += float(co.get("p01_water_bonus", 0))
		sim.harmony = clampf(sim.harmony + float(co.get("noah_harmony_bonus", 0)) + float(co.get("p01_harmony_bonus", 0)), 45.0, 100.0)
		sim.pasture_pressure = clampf(sim.pasture_pressure + float(co.get("p01_pressure_offset", 0)), 10.0, 95.0)

	world = BethelHighlandWorld.new()
	add_child(world)
	world.build_all()

	cam_ctrl = RTSCameraController.new()
	cam_ctrl.bounds_xz = Rect2(-60.0, -44.0, 120.0, 88.0)
	add_child(cam_ctrl)
	_spawn_cast_and_flocks()

	mount_hud_v3(chapter.get("codexEntries", []), 5, world.environment, world.sun)
	ui.cutaway_btn.hide()
	story.event_activated.connect(_on_event_entered)

	var start_id: String = str(chapter.get("firstEventId", "act1_return_bethel"))
	var preview_tactical: bool = false
	var preview_fp: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene="): start_id = arg.trim_prefix("--preview-scene="); preview_mode = true
		elif arg == "--bethel-tactical": preview_mode = true; preview_tactical = true
		elif arg == "--bethel-fp": preview_mode = true; preview_fp = true

	if sv != null:
		sv.call("apply_graphics_quality_to_env", world.environment, world.sun)
		_on_host_lang_changed(str(sv.get("current_locale")))
		if not preview_mode and int(sv.get("pending_load_slot")) > 0:
			var sl: int = int(sv.get("pending_load_slot")); sv.set("pending_load_slot", 0)
			story.transition_to(start_id, false); _on_host_load_slot(sl); return

	story.transition_to(start_id, false)
	if preview_tactical:
		var svt: Node = get_node_or_null("/root/SaveManager"); if svt != null: svt.call("set_locale", "zh_CN")
		ui.lang = "zh_CN"; ui.refresh_i18n_texts(); _on_host_lang_changed("zh_CN")
		_on_host_toggle_tactical(); cam_ctrl.focus_on(Vector3(-3, 1.5, 2), 54.0, -0.42, true)
	elif preview_fp:
		var svf: Node = get_node_or_null("/root/SaveManager"); if svf != null: svf.call("set_locale", "zh_CN")
		ui.lang = "zh_CN"; ui.refresh_i18n_texts(); _on_host_lang_changed("zh_CN")
		_on_host_toggle_fp()
	_refresh_chapter_hud()


func _spawn_cast_and_flocks() -> void:
	hero = PatriarchPlayer3D.new()
	hero.name = "AbramPlayerBody"
	hero.setup_capsule(1.72, 0.36)
	add_child(hero)
	var files: Array[String] = ["CHR_Abram_rigged.glb", "CHR_Sarai_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Son_rigged.glb"]
	var cast_cfg: Array = chapter.get("familyCast", [])
	for i in range(files.size()):
		var h: float = 1.72 if i == 0 else (1.58 if i == 1 else 1.66)
		var actor: Node3D = world.spawn_asset(files[i], h, world.grounded(float(i) * 1.6, 4.0), self)
		if i == 0: hero.warp_to(world.grounded(-1.5, 4.5)); hero.attach_visual(actor)
		HumanoidRigHelper.setup_layered_anim_tree(actor)
		cast_nodes.append(actor)
		var ci: Dictionary = cast_cfg[i] if i < cast_cfg.size() else {}
		var lbl := Label3D.new()
		lbl.set_meta("name_zh", str(ci.get("nameZh", ""))); lbl.set_meta("name_en", str(ci.get("nameEn", ""))); lbl.text = str(ci.get("nameZh", ""))
		lbl.position = Vector3(0, h + 0.34, 0); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
		lbl.font_size = 26; lbl.pixel_size = 0.0038; lbl.modulate = Color(1.0, 0.92, 0.72); lbl.outline_size = 8
		actor.add_child(lbl); cast_labels.append(lbl)

	for si in range(8):
		var ani: Node3D = world.spawn_asset("CC0_Sheep_Grab3D.glb" if si < 6 else "CC0_Bull_Grab3D.glb", 0.90 if si < 6 else 1.44, world.grounded(-10.0 + float(si % 4) * 4.2, 17.5 + float(si / 4) * 4.5), self)
		ani.rotation.y = float(si) * 0.9; NoahCastAndRaidRig.play_simple_anim(ani, "StallRest" if si % 2 == 0 else "Idle"); flock_animals.append(ani)


func _add_b_hs(id: String, pos: Vector3, l_zh: String, l_en: String, clip: String = "Bless") -> void:
	var node: Area3D = HOTSPOT_PREFAB.instantiate() as Area3D
	node.position = pos; add_child(node)
	var lbl: Label3D = node.get_node("Label3D") as Label3D
	lbl.text = "[E] " + (l_en if ui.lang == "en_US" else l_zh)
	hotspots.append({"id": id, "pos": pos, "label_zh": l_zh, "label_en": l_en, "clip": clip, "done": false, "node": node, "lbl": lbl})


func _on_event_entered(id: String, ev: Dictionary, preserve_pos: bool) -> void:
	clear_hotspots()
	if not preview_mode: ui.show_act_banner(str(ev.get("actBannerEn" if ui.lang == "en_US" else "actBannerZh", "")), str(ev.get("canonRef", "")))
	world.god_ray.visible = id in ["act2_restore_altar", "act5_parting_promise"]
	match id:
		"act1_return_bethel":
			sim.monument_pct = 20.0
			if not preserve_pos: hero.warp_to(world.grounded(-3.0, 5.5)); cam_ctrl.focus_on(Vector3(-4, 2.0, 2), 34.0, -0.38, preview_mode)
			_add_b_hs("well_draw", world.grounded(-28.0, -5.5), "西谷石井汲水 (+12活水)", "Draw West Well Water (+12)")
			_add_b_hs("tent_check", world.grounded(-2.0, 2.2), "整顿中央织锦主帐（[F] 提灯入帐）", "Ready Main Pavilion Tent ([F] Enter)")
		"act2_restore_altar":
			sim.monument_pct = 45.0; _add_b_hs("pray_altar", world.altar_group.position + Vector3(0, 0, 2.4), "十二石旧坛前求告耶和华的名（创 13:4）", "Call on Yahweh at the 12-Stone Altar", "Pray")
		"act3_herdsmen_strife":
			sim.monument_pct = 65.0; sim.pasture_pressure = 78.0; _add_b_hs("calm_strife", world.grounded(-2.0, 18.0), "南坡牧场调解两家牧人争水", "Mediate Herdsmen's Strife")
		"act4_canaan_caravan":
			sim.monument_pct = 82.0; _add_b_hs("meet_caravan", world.grounded(-25.5, 19.5), "西南艾城驿道接待行商驼马队", "Greet Caravan on Southwest Road")
		"act5_parting_promise":
			sim.monument_pct = 100.0; cast_nodes[2].position = world.grounded(30.5, 20.5)
			_add_b_hs("jordan_overlook", world.grounded(31.5, 21.5), "东南眺望崖向罗得谦让分地并领受四望之约", "Yield First Choice & Receive Promise")
	sync_hotspots_display(); _refresh_chapter_hud()


func _on_host_toggle_fp() -> void:
	if tactical_sandbox_mode: _on_host_toggle_tactical()
	first_person_mode = not first_person_mode
	if first_person_mode:
		tent_fp_local = Vector3(-1.05, 0.05, -0.65); cast_nodes[0].hide()
		cast_nodes[1].position = world.grounded(-0.5, 1.8); cast_nodes[1].look_at(world.main_tent.global_position, Vector3.UP)
		cam_ctrl.set_first_person(true, preview_mode); cam_ctrl.fp_yaw = 2.72; cam_ctrl.fp_pitch = -0.05
		cam_ctrl.fp_eye_pos = world.main_tent.to_global(tent_fp_local + Vector3(0, 1.58, 0)); cam_ctrl._apply_camera_transform()
	else:
		cam_ctrl.set_first_person(false, preview_mode); cast_nodes[0].show(); hero.warp_to(world.grounded(-2.0, 3.2))
	ui.fp_crosshair.visible = first_person_mode; sync_hotspots_display()
	ui.fp_btn.text = tr("BTN_FP_EXIT" if first_person_mode else "BTN_FP_ENTER"); _refresh_chapter_hud()


func _on_host_toggle_tactical() -> void:
	toggle_tactical_overview(Vector3(0, 2, 2), 64.0)


func _on_host_lang_changed(lc: String) -> void:
	var is_en: bool = (lc == "en_US")
	for lbl in cast_labels: lbl.text = str(lbl.get_meta("name_en" if is_en else "name_zh", ""))
	sync_hotspots_display(); _refresh_chapter_hud()


func _on_hotspot_triggered(h: Dictionary) -> void:
	if bool(h.done): return
	h.done = true; (h.node as Node3D).hide(); hero.busy_timer = 1.2; hero.busy_clip = str(h.clip); sfx("sfx_covenant_chime.wav", -5.0)
	if str(h.id) == "well_draw": sim.res_primary += 12.0; world.spawn_floating_text_3d(h.pos + Vector3(0, 2.0, 0), "+12 " + tr("RES_WATER"))
	for rh in hotspots:
		if not bool(rh.done): _refresh_chapter_hud(); return
	var ev: Dictionary = story.current_event(); var chs: Array = ev.get("choices", [])
	if chs.size() > 1:
		var opts: Array = []
		for c in chs:
			var cd: Dictionary = c
			opts.append({"label": str(cd.get("labelZh", "")), "callback": func() -> void:
				sim.res_primary = maxf(0.0, sim.res_primary + float(cd.get("deltaWater", 0.0)))
				sim.harmony = clampf(sim.harmony + float(cd.get("deltaHarmony", 0.0)), 40.0, 100.0)
				story.transition_to(str(cd.get("nextEventId", "")), true)
			})
		ui.open_choice_modal(str(ev.get("actBannerEn" if ui.lang == "en_US" else "actBannerZh", "")), str(ev.get("canonRef", "")), str(ev.get("bodyEn" if ui.lang == "en_US" else "bodyZh", "")), opts)
	elif chs.size() == 1:
		var nxt: String = str(chs[0].get("nextEventId", ""))
		if not nxt.is_empty(): story.transition_to(nxt, true)
		else:
			var sv: Node = get_node_or_null("/root/SaveManager")
			if sv != null: sv.call("light_covenant_stone", 2); sv.call("save_slot", 1, {"chapter_id": "ch01_bethel", "monument_pct": 100.0}, get_viewport())
			ui.open_choice_modal("第一章完结 · 希伯仑幔利橡树筑坛（创 13:18）", "Gen 13:14–18", "第二枚圣约石已点亮！亚伯兰凭信谦让分地，领受四境永约，迁往希伯仑幔利橡树筑坛。", [{"label": tr("BTN_MAIN_MENU"), "callback": func() -> void: var st: Node = get_node_or_null("/root/SceneTransition"); if st != null: st.call("change_scene", "res://scenes/main_menu.tscn")}])


func _process(delta: float) -> void:
	var sim_dt: float = 0.0 if ui.is_blocking_modal_open() else (delta * (sim.cfg.tactical_time_scale if tactical_sandbox_mode else 1.0))
	elapsed += sim_dt
	if not ui.is_blocking_modal_open() and first_person_mode:
		var mv: Vector3 = compute_wish_move_dir(cam_ctrl.fp_yaw)
		if mv.length_squared() > 0.01:
			tent_fp_local += mv.normalized() * 3.2 * delta
			tent_fp_local.x = clampf(tent_fp_local.x, -2.4, 2.4); tent_fp_local.z = clampf(tent_fp_local.z, -2.0, 2.6)
			if tent_fp_local.z > 2.45: _on_host_toggle_fp()
		cam_ctrl.fp_move_intensity = lerpf(cam_ctrl.fp_move_intensity, 1.0 if mv.length_squared() > 0.01 else 0.0, delta * 8.0)
		cam_ctrl.fp_eye_pos = world.main_tent.to_global(tent_fp_local + Vector3(0, 1.58, 0))
	elif not ui.is_blocking_modal_open() and not tactical_sandbox_mode:
		var clip: String = hero.step_movement(delta, compute_wish_move_dir(cam_ctrl.current_yaw), Input.is_key_pressed(KEY_SHIFT))
		NoahCastAndRaidRig.play_simple_anim(cast_nodes[0], clip)
		cam_ctrl.focus_on(hero.global_position + Vector3(0, 1.6, 0), -1.0, NAN, false)

	if sim_dt > 0.0:
		sim.res_primary += float(sim.w_gather) * 0.45 * sim.harmony_multiplier() * sim_dt
		sim.res_secondary += float(sim.w_craft) * 0.35 * sim.harmony_multiplier() * sim_dt
		sim.pasture_pressure = clampf(sim.pasture_pressure + (0.35 - float(sim.w_guard) * 0.28) * sim_dt, 12.0, 95.0)
		var zone_pts: Array[Vector3] = [world.grounded(-2.5, 1.8), world.grounded(-28.0, -5.0), world.grounded(26.0, -6.0), world.grounded(-3.0, 18.5), world.grounded(8.0, 17.5)]
		for k in range(1, cast_nodes.size()):
			var dest: Vector3 = zone_pts[(k - 1) % zone_pts.size()] + Vector3(sin(elapsed * 0.5 + float(k)) * 2.2, 0, cos(elapsed * 0.4 + float(k)) * 2.2)
			dest.y = world.terrain_height(dest.x, dest.z)
			var step_v: Vector3 = HumanoidRigHelper.compute_rvo_step(cast_nodes[k], dest, 2.8, cast_nodes, 0.65, sim_dt)
			if step_v.length() > 0.02:
				var np: Vector3 = cast_nodes[k].position + step_v; np.y = world.terrain_height(np.x, np.z)
				cast_nodes[k].position = np; cast_nodes[k].look_at(np + step_v.normalized(), Vector3.UP)
				NoahCastAndRaidRig.play_simple_anim(cast_nodes[k], "Walk")
			else: NoahCastAndRaidRig.play_simple_anim(cast_nodes[k], "Idle")
		_refresh_chapter_hud()

	if first_person_mode: ui.interact_prompt.hide()
	else: update_hotspot_proximity(hero.global_position)
	ui.update_3d_bubbles(cam_ctrl.camera, tactical_sandbox_mode, {"log": world.grounded(-30, -6, 3.5), "build": world.altar_group.position + Vector3(0, 3.2, 0), "pitch": world.grounded(28, -6, 3.5), "guard": world.grounded(-4, 20, 3.2)}, {"log": tr("ST_WELL") % sim.w_gather, "build": tr("ST_ALTAR") % sim.w_build, "pitch": tr("ST_GROVE") % sim.w_craft, "guard": tr("ST_PASTURE") % sim.w_guard}, false, "", false, Vector3.ZERO)


func _refresh_chapter_hud() -> void:
	if ui == null: return
	var ev: Dictionary = story.current_event(); var is_en: bool = (ui.lang == "en_US")
	(ui.badge_labels["timber"] as Label).text = "%s %d" % [tr("RES_WATER"), int(sim.res_primary)]
	(ui.badge_labels["pitch"] as Label).text = "%s %d" % [tr("RES_WOOD"), int(sim.res_secondary)]
	(ui.badge_labels["provisions"] as Label).text = "%s %d" % [tr("RES_FLOCK"), int(sim.res_tertiary)]
	(ui.badge_labels["harmony"] as Label).text = "%s %d%% (x%.2f)" % [tr("RES_FAITH"), int(sim.harmony), sim.harmony_multiplier()]
	ui.sundial_gauge.days_left = 100.0 - sim.pasture_pressure; ui.sundial_gauge.max_days = 100.0; ui.sundial_gauge.ark_pct = sim.monument_pct; ui.sundial_gauge.pulse_t = elapsed; ui.sundial_gauge.queue_redraw()
	if first_person_mode: ui.sundial_title_lbl.text = "1st-Person Oil-Lamp · Abram's Pavilion" if is_en else "主帐油灯漫游 · 亚伯兰织锦家帐"; ui.sundial_sub_lbl.text = tr("HUD_FP_SUB")
	else: ui.sundial_title_lbl.text = tr("HUD_BETHEL_TITLE") % int(sim.pasture_pressure); ui.sundial_sub_lbl.text = tr("HUD_BETHEL_SUB") % int(sim.monument_pct)
	var ref_s: String = str(ev.get("canonRef", "")).replace("创 ", "Gen ") if is_en else str(ev.get("canonRef", ""))
	ui.subtitle_label.text = "【%s · %s】%s" % [str(ev.get("speakerEn" if is_en else "speakerZh", "")), ref_s, str(ev.get("bodyEn" if is_en else "bodyZh", ""))]
