extends ChapterRuntimeHost
## Prologue Cartridge Coordinator (`Ch00` Noah's Ark — <= 350 lines on `ChapterRuntimeHost`!):
## Binds only Noah-specific 30-step Ark hull, boarding, flood waves, dove flight & 4 dramatic moments!

const DATA_PATH: String = "res://data/ch00_noah_ark.json"
const BALANCE_RES: Resource = preload("res://resources/ch00_balance.tres")

var world: NoahRTSWorld
var rig: NoahCastAndRaidRig
var interior_cutaway: bool = false
var manual_cutaway_lock: bool = false
var fp_exit_cooldown: float = 0.0
var noah_fp_local: Vector3 = Vector3(-18.0, 0.65, 0.5)
var noah_deck: int = 0
var last_ark_step: int = -1
var rally_cooldown: float = 0.0
var dm01_triggered: bool = false
var dm02_triggered: bool = false
var divine_seal_active: bool = false
var divine_seal_timer: float = 0.0
var last_board_counts: Vector2i = Vector2i.ZERO
var elapsed: float = 0.0
var flood_level: float = -10.5
var flood_target: float = -10.5
var preview_flag: String = ""


func _ready() -> void:
	boot_cartridge("ch00_noah_ark", DATA_PATH, BALANCE_RES as ChapterBalanceResource, "timber", "pitch", "provisions")
	world = NoahRTSWorld.new(); add_child(world); world.build_all()
	rig = NoahCastAndRaidRig.new(); add_child(rig)
	hero = rig.build_cast(world, sim, chapter.get("familyCast", []))
	rig.timber_fire_ignited.connect(_on_fire_event)
	rig.raid_crisis_resolved.connect(_on_raid_resolved)
	rig.all_boarded_ready.connect(_begin_divine_seal)

	mount_hud_v3(chapter.get("codexEntries", []), 7, world.environment, world.sun)
	ui.request_fence_work.connect(_start_fence_work)
	ui.request_douse_fire.connect(_douse_fire)
	story.event_activated.connect(_on_event_entered)

	var start_id: String = str(chapter.get("firstEventId", "noah_01_revelation"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene="): start_id = arg.trim_prefix("--preview-scene="); preview_mode = true
		elif arg == "--flood-fp": start_id = "noah_06_flood_dove"; preview_mode = true; first_person_mode = true
		elif arg == "--tactical-sandbox": start_id = "noah_03_hull_decks"; preview_mode = true; preview_flag = "tactical"
		elif arg == "--fire-crisis-preview": start_id = "noah_03_hull_decks"; preview_mode = true; preview_flag = "fire_crisis"
		elif arg == "--codex-preview": start_id = "noah_02_keel_mortise"; preview_mode = true; preview_flag = "codex"
		elif arg == "--divine-seal-preview": start_id = "noah_05_board_ark"; preview_mode = true; preview_flag = "divine_seal"
		elif arg == "--mobile-hud": start_id = "noah_02_keel_mortise"; preview_mode = true; preview_flag = "mobile_hud"
		elif arg == "--en-preview": start_id = "noah_02_keel_mortise"; preview_mode = true; preview_flag = "en_preview"

	var sv: Node = get_node_or_null("/root/SaveManager")
	if sv != null:
		sv.call("apply_graphics_quality_to_env", world.environment, world.sun)
		rig.sync_locale_labels(str(sv.get("current_locale")))
		if not preview_mode and int(sv.get("pending_load_slot")) > 0:
			var sl: int = int(sv.get("pending_load_slot")); sv.set("pending_load_slot", 0)
			story.transition_to(start_id, false); _on_host_load_slot(sl); return
	story.transition_to(start_id, false)
	_apply_preview_flag()


func _apply_preview_flag() -> void:
	if preview_flag == "tactical":
		sim.monument_pct = 54.0; sim.days_remaining = 118.0; _sync_ark(); _on_host_toggle_tactical(); cam_ctrl.focus_on(Vector3(6, 2, 12), 66.0, -0.32, true)
	elif preview_flag == "fire_crisis":
		sim.monument_pct = 58.0; sim.days_remaining = 82.0; sim.palisade_pct = 65.0; sim.palisade_hp = 110.0; sim.fire_intensity = 0.92
		world.set_fence_progress(65.0); world.set_timber_fire_intensity(0.92); add_hotspot_tr("douse_fire", world.spring_well.position + Vector3(0, 0, 1.4), "HS_DOUSE_FIRE", "Bless")
		_sync_ark(); hero.warp_to(world.grounded(-8.5, 16.5)); cam_ctrl.pitch_override = -0.36; cam_ctrl.focus_on(Vector3(-11, 1.8, 17.5), 25.0, 0.28, true)
	elif preview_flag == "codex":
		sim.monument_pct = 25.0; sim.days_remaining = 195.0; _sync_ark(); ui.codex_drawer.show(); cam_ctrl.focus_on(Vector3(-6, 3, 8), 54.0, -0.44, true)
	elif preview_flag == "divine_seal":
		sim.monument_pct = 100.0; divine_seal_active = true; clear_hotspots(); rig.stage_all_inside_ark(false); rig.animal_root.hide()
		world.set_ark_progress(100.0, false, true, false)
		var dm3: Dictionary = chapter.get("dramaticMoments", {}).get("dm_03_divine_seal", {})
		ui.show_divine_seal(str(dm3.get("titleZh", "")), str(dm3.get("verseZh", "")), true); cam_ctrl.focus_on(Vector3(0, 3.5, 12), 32.0, -0.25, true)
	elif preview_flag == "mobile_hud":
		var sv0: Node = get_node_or_null("/root/SaveManager"); if sv0 != null: sv0.call("set_locale", "zh_CN")
		ui.lang = "zh_CN"; ui.refresh_i18n_texts(); rig.sync_locale_labels("zh_CN"); sync_hotspots_display("release_dove")
		sim.monument_pct = 38.0; _sync_ark(); ui.thumbstick.stick_vec = Vector2(0.32, -0.58); ui.thumbstick.show(); ui.thumbstick.queue_redraw(); ui._apply_responsive_layout()
	elif preview_flag == "en_preview":
		var sv: Node = get_node_or_null("/root/SaveManager")
		if sv != null: sv.call("set_locale", "en_US")
		ui.lang = "en_US"; ui.refresh_i18n_texts(); rig.sync_locale_labels("en_US"); sync_hotspots_display("release_dove")
		sim.monument_pct = 32.0; _sync_ark(); ui.codex_drawer.show()
	_refresh_chapter_hud()


func _sync_ark() -> void:
	var id: String = story.current_event_id
	last_ark_step = 0 if id == "noah_01_revelation" else sim.progressive_step_index()
	var scaf: bool = (last_ark_step >= 1 and sim.monument_pct < 99.5 and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"])
	world.set_ark_progress(0.0 if id == "noah_01_revelation" else sim.monument_pct, interior_cutaway, id == "noah_06_flood_dove" or divine_seal_active, scaf)


func _on_event_entered(id: String, ev: Dictionary, preserve_pos: bool) -> void:
	divine_seal_active = false; rig.dove_flight_active = false; ui.modal_overlay.hide(); ui.hide_divine_seal(); clear_hotspots()
	if not preserve_pos: rig.restore_all_to_world()
	if first_person_mode and not (preview_mode and id == "noah_06_flood_dove") and id not in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		first_person_mode = false; cam_ctrl.set_first_person(false, preview_mode); rig.family[0].show()
	if not preview_mode: ui.show_act_banner(str(ev.get("actBannerEn" if ui.lang == "en_US" else "actBannerZh", "")), str(ev.get("canonRef", "")))

	match id:
		"noah_01_revelation": sim.monument_pct = 0.0
		"noah_02_keel_mortise": sim.monument_pct = maxf(sim.monument_pct, 8.0)
		"noah_03_hull_decks": sim.monument_pct = maxf(sim.monument_pct, 36.0)
		"noah_04_pitch_provisions": sim.monument_pct = maxf(sim.monument_pct, 75.0)
		_: sim.monument_pct = 100.0
	_sync_ark()
	rig.apply_act_visibility(id, int(ev.get("arkStage", 0)), first_person_mode)
	var ap: Vector3 = world.ark_anchor.position; var sm: Node = get_node_or_null("/root/SoundManager")
	match id:
		"noah_01_revelation":
			world.apply_mood("revelation"); flood_target = -15.0
			for i in range(rig.family.size()): rig.family[i].visible = (i == 0); rig.set_actor_props(rig.family[i], false, false, false)
			hero.warp_to(world.grounded(-2, 18)); NoahCastAndRaidRig.play_simple_anim(rig.family[0], "Pray"); cam_ctrl.pitch_override = -0.20
			cam_ctrl.focus_on(hero.global_position + Vector3(2, 2.5, -5), 15.0, -0.52, preview_mode); add_hotspot_tr("accept_call", hero.global_position + Vector3(0, 0, -2.5), "HS_ACCEPT_CALL", "Bless")
		"noah_02_keel_mortise":
			world.apply_mood("build"); cam_ctrl.pitch_override = NAN
			for m in rig.family: m.show()
			if not preserve_pos: hero.warp_to(world.grounded(-10, 16)); cam_ctrl.focus_on(Vector3(0, 3, 6), 58.0, -0.42, preview_mode)
			add_hotspot_tr("keel_west", world.grounded(-18, 9.5), "HS_KEEL_WEST"); add_hotspot_tr("keel_east", world.grounded(18, 9.5), "HS_KEEL_EAST"); add_hotspot_tr("timber_check", world.grounded(-15, 17.5), "HS_TIMBER_CHECK", "Idle")
		"noah_03_hull_decks":
			world.apply_mood("dusk_raid"); cam_ctrl.pitch_override = NAN
			for m in rig.family: m.show()
			rig.stage_raiders(preview_mode, first_person_mode)
			if not preserve_pos: hero.warp_to(world.grounded(-6, 20.5)); cam_ctrl.focus_on(Vector3(-8, 3.2, 18), 42.0, 0.25, preview_mode)
			add_hotspot_tr("inside_lower", ap + Vector3(-8, 0.65, 0), "HS_INSIDE_LOWER"); add_hotspot_tr("inside_mid", ap + Vector3(15.5, 3.95, 0), "HS_INSIDE_MID"); add_hotspot_tr("defend_yard", world.grounded(-12.5, 21.2), "HS_DEFEND_YARD", "Bless")
		"noah_04_pitch_provisions":
			world.apply_mood("build"); cam_ctrl.pitch_override = -0.24
			for m in rig.family: m.show()
			if not preserve_pos: hero.warp_to(world.grounded(10, 18)); cam_ctrl.focus_on(Vector3(-4, 4.5, 6), 56.0, -0.46, preview_mode)
			add_hotspot_tr("pitch_inside", ap + Vector3(-10, 0.65, 0), "HS_PITCH_IN", "BrushPitch"); add_hotspot_tr("pitch_outside", world.grounded(11.5, 15.5), "HS_PITCH_OUT", "BrushPitch"); add_hotspot_tr("provisions_check", world.grounded(15, 15.8), "HS_PROV_CHECK", "Idle")
		"noah_05_board_ark":
			world.apply_mood("dusk_raid"); world.rain.emitting = true; sim.days_remaining = 0.0
			if sm != null: sm.call("play_ambience", "sfx_rain_loop.wav", -10.0)
			rig.init_boarding(); cam_ctrl.pitch_override = -0.26; cam_ctrl.focus_on(Vector3(0, 2.8, 15.5), 34.0, -0.34, preview_mode)
			if preview_mode and preview_flag.is_empty():
				for _s in range(56): last_board_counts = rig.tick_boarding(0.05, 1.0, false, true)
			add_hotspot_tr("seal_door", ap + Vector3(0, 0.65, 12), "HS_SEAL_DOOR", "Bless")
		"noah_06_flood_dove":
			world.apply_mood("flood"); flood_target = 6.5
			if sm != null: sm.call("play_ambience", "sfx_rain_loop.wav", -8.0)
			if preview_mode: flood_level = 6.2; world.flood_water.position.y = 6.2; world.ark_anchor.position.y = 5.0
			rig.stage_all_inside_ark(first_person_mode)
			if first_person_mode and preview_mode:
				noah_fp_local = Vector3(-26, 0.65, 0.4); cam_ctrl.set_first_person(true, true); cam_ctrl.fp_yaw = -PI * 0.48; cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0, 1.68, 0)); cam_ctrl._apply_camera_transform()
			else: cam_ctrl.focus_on(Vector3(0, 7.5, 6), 74.0, -0.48, preview_mode)
			add_hotspot_tr("release_dove", ap + Vector3(6, 7.15, 2.2), "HS_RELEASE_DOVE", "Bless")
		"noah_07_exit_altar", "noah_08_rainbow_covenant":
			world.apply_mood("ararat"); flood_target = -15.0
			if sm != null: sm.call("stop_ambience"); sm.call("set_interior_acoustics", false)
			if preview_mode: flood_level = -15.0; world.flood_water.position.y = -15.0; world.ark_anchor.position.y = world.ark_base_y
			rig.stage_ararat_worship(); cam_ctrl.pitch_override = -0.10 if id == "noah_08_rainbow_covenant" else -0.20; cam_ctrl.focus_on(Vector3(-1, 9, 6), 64.0, -0.24, preview_mode)
			add_hotspot_tr("offer_altar" if id == "noah_07_exit_altar" else "to_overworld", world.altar_group.position + Vector3(0, 0, -2), "HS_OFFER_ALTAR" if id == "noah_07_exit_altar" else "HS_TO_OVERWORLD", "Bless")
	sync_hotspots_display("release_dove"); _refresh_chapter_hud()


func _on_host_toggle_fp() -> void:
	var id: String = story.current_event_id
	if id == "noah_01_revelation": return
	if tactical_sandbox_mode: _on_host_toggle_tactical()
	first_person_mode = not first_person_mode
	if first_person_mode:
		interior_cutaway = false; manual_cutaway_lock = false; noah_deck = 0
		noah_fp_local = Vector3(-25, 0.65, 0.4) if id in ["noah_05_board_ark", "noah_06_flood_dove"] else Vector3(-16, 0.65, 0.4)
		hero.warp_to(world.ark_anchor.to_global(noah_fp_local)); rig.family[0].hide()
		cam_ctrl.set_first_person(true, preview_mode); cam_ctrl.fp_yaw = -PI * 0.48; cam_ctrl.fp_pitch = 0.02
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0, 1.68, 0)); cam_ctrl._apply_camera_transform()
	else:
		cam_ctrl.set_first_person(false, preview_mode); fp_exit_cooldown = 1.6
		if id not in ["noah_05_board_ark", "noah_06_flood_dove"]:
			rig.restore_all_to_world()
			if hero.global_position.z < world.ark_anchor.position.z + 10.0: hero.warp_to(world.grounded(0, 21))
			rig.family[0].show()
	_sync_ark(); sync_hotspots_display("release_dove"); ui.fp_crosshair.visible = first_person_mode
	ui.fp_btn.text = tr("BTN_FP_EXIT" if first_person_mode else "BTN_FP_ENTER"); _refresh_chapter_hud()


func _on_host_toggle_tactical() -> void:
	if story.current_event_id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		toggle_tactical_overview(Vector3(4, 2, 12), 68.0)


func _on_host_toggle_cutaway() -> void:
	if first_person_mode: _on_host_toggle_fp()
	manual_cutaway_lock = not manual_cutaway_lock; interior_cutaway = manual_cutaway_lock; _sync_ark()
	ui.cutaway_btn.text = tr("BTN_CUTAWAY_OFF" if interior_cutaway else "BTN_CUTAWAY_ON")


func _on_host_lang_changed(lc: String) -> void:
	rig.sync_locale_labels(lc); sync_hotspots_display("release_dove"); _refresh_chapter_hud()


func _after_slot_loaded() -> void:
	world.set_fence_progress(sim.palisade_pct); _sync_ark()


func _start_fence_work() -> void:
	if story.current_event_id != "noah_03_hull_decks" or rig.crisis_resolved or sim.palisade_building: return
	var cost: float = sim.cfg.palisade_build_cost if sim.palisade_pct < 100.0 else sim.cfg.palisade_repair_cost
	if sim.res_primary < cost: sfx("sfx_alert.wav", -5.0); return
	sim.res_primary -= cost; sim.palisade_building = true; sfx("sfx_hammer.wav", -4.0); _refresh_chapter_hud()


func _on_fire_event() -> void:
	if sim.fire_intensity >= 0.99: sfx("sfx_alert.wav", -3.0); add_hotspot_tr("douse_fire", world.spring_well.position + Vector3(0, 0, 1.4), "HS_DOUSE_FIRE", "Bless")
	else: _douse_fire()


func _douse_fire() -> void:
	if sim.fire_intensity <= 0.01: return
	sim.fire_intensity = maxf(0.0, sim.fire_intensity - 0.55)
	world.set_timber_fire_intensity(sim.fire_intensity); world.spawn_hit_particles(world.grounded(-15.5, 16.0, 1.4), false)
	world.spawn_floating_text_3d(world.grounded(-15.5, 16.0, 2.2), "-50% FIRE", Color(0.42, 0.88, 1.0)); sfx("sfx_ui_click.wav", -3.0)
	if sim.fire_intensity <= 0.02:
		sim.fire_intensity = 0.0; world.set_timber_fire_intensity(0.0)
		for h in hotspots:
			if str(h.id) == "douse_fire": h.done = true; (h.node as Node3D).hide()
	_refresh_chapter_hud()


func _on_raid_resolved() -> void:
	sfx("sfx_covenant_chime.wav", -4.0)
	for h in hotspots:
		if str(h.id) == "defend_yard": h.done = true; (h.node as Node3D).hide()
	_check_act_complete()


func _on_hotspot_triggered(h: Dictionary) -> void:
	if bool(h.done): return
	var hid: String = str(h.id)
	if hid == "douse_fire": _douse_fire(); return
	if hid == "defend_yard" and not rig.crisis_resolved:
		if sim.palisade_hp <= 0.0 and not sim.palisade_building and sim.res_primary >= sim.cfg.palisade_build_cost: _start_fence_work()
		if rally_cooldown <= 0.0:
			rally_cooldown = 5.0; hero.busy_timer = 1.2; hero.busy_clip = "Brawl"; sfx("sfx_hammer.wav", -3.0); cam_ctrl.add_trauma(0.14)
			for i in range(rig.raider_morale.size()): rig.raider_morale[i] = maxf(0.0, rig.raider_morale[i] - 24.0)
			if sim.palisade_hp > 0.0: sim.palisade_hp = minf(sim.cfg.palisade_max_hp, sim.palisade_hp + 30.0)
		return
	if hid == "seal_door": h.done = true; (h.node as Node3D).hide(); rig.stage_all_inside_ark(first_person_mode); _begin_divine_seal(); return
	if hid == "release_dove":
		h.done = true; (h.node as Node3D).hide(); rig.dove_flight_active = true; rig.dove_flight_t = 0.0; sfx("sfx_covenant_chime.wav", -4.0)
		create_tween().tween_callback(_check_act_complete).set_delay(2.2); return
	h.done = true; (h.node as Node3D).hide(); hero.busy_timer = 1.1; hero.busy_clip = str(h.clip); sfx("sfx_hammer.wav", -4.0)
	cam_ctrl.add_trauma(0.14); world.spawn_hit_particles(h.pos + Vector3(0, 0.8, 0), false); sim.inspection_boost_timer = sim.cfg.inspection_boost_sec
	_check_act_complete()


func _begin_divine_seal() -> void:
	if divine_seal_active: return
	divine_seal_active = true; divine_seal_timer = 5.0; rig.animal_root.hide(); world.set_ark_progress(100.0, false, true, false)
	var sm: Node = get_node_or_null("/root/SoundManager"); if sm != null: sm.call("set_interior_acoustics", true)
	cam_ctrl.add_trauma(0.24); sfx("sfx_covenant_chime.wav", -3.0)
	var dm3: Dictionary = chapter.get("dramaticMoments", {}).get("dm_03_divine_seal", {})
	ui.show_divine_seal(str(dm3.get("titleEn" if ui.lang == "en_US" else "titleZh", "")), str(dm3.get("verseEn" if ui.lang == "en_US" else "verseZh", "")))
	_refresh_chapter_hud()


func _open_dm(dm_key: String) -> void:
	open_dramatic_moment(dm_key, func(cd: Dictionary) -> void:
		if float(cd.get("bonusFenceHp", 0.0)) > 0.0: sim.palisade_pct = maxf(sim.palisade_pct, 50.0); sim.palisade_hp = minf(sim.cfg.palisade_max_hp, sim.palisade_hp + float(cd.get("bonusFenceHp", 0.0))); world.set_fence_progress(sim.palisade_pct)
		for ri in range(rig.raider_morale.size()): rig.raider_morale[ri] = maxf(0.0, rig.raider_morale[ri] - float(cd.get("moraleDrop", 0.0)))
	)


func _check_act_complete() -> void:
	for h in hotspots:
		if str(h.id) != "douse_fire" and not bool(h.done): return
	var id: String = story.current_event_id
	if id == "noah_02_keel_mortise" and sim.monument_pct < 35.0: return
	if id == "noah_03_hull_decks" and (not rig.crisis_resolved or sim.fire_intensity > 0.02 or sim.monument_pct < 75.0): return
	if id == "noah_04_pitch_provisions" and (sim.monument_pct < 98.0 or sim.res_secondary < 25.0 or sim.res_tertiary < 80.0): return
	var next_map: Dictionary = {"noah_01_revelation": "noah_02_keel_mortise", "noah_02_keel_mortise": "noah_03_hull_decks", "noah_03_hull_decks": "noah_04_pitch_provisions", "noah_04_pitch_provisions": "noah_05_board_ark", "noah_06_flood_dove": "noah_07_exit_altar", "noah_07_exit_altar": "noah_08_rainbow_covenant"}
	if next_map.has(id): story.transition_to(next_map[id], id in ["noah_02_keel_mortise", "noah_03_hull_decks"])
	elif id == "noah_08_rainbow_covenant":
		var sv: Node = get_node_or_null("/root/SaveManager")
		if sv != null: sv.call("light_covenant_stone", 1); sv.call("record_carryover", "noah_harmony_bonus", maxi(2, int(roundf((sim.harmony - 75.0) * 0.4)))); sv.call("save_slot", 1, {"chapter_id": "overworld_prologue", "monument_pct": 100.0}, get_viewport())
		var st: Node = get_node_or_null("/root/SceneTransition"); if st != null: st.call("change_scene", "res://scenes/overworld_prologue.tscn")


func _process(delta: float) -> void:
	rig.update_hitstops(delta)
	if rally_cooldown > 0.0: rally_cooldown -= delta
	if fp_exit_cooldown > 0.0: fp_exit_cooldown -= delta
	if divine_seal_active and not preview_mode:
		divine_seal_timer -= delta
		if divine_seal_timer <= 0.0: divine_seal_active = false; ui.hide_divine_seal(); story.transition_to("noah_06_flood_dove", false)
		return
	var sim_dt: float = 0.0 if ui.is_blocking_modal_open() else (delta * (sim.cfg.tactical_time_scale if tactical_sandbox_mode else 1.0))
	elapsed += sim_dt; var id: String = story.current_event_id
	for i in range(rig.family.size()):
		rig.family_nameplates[i].visible = tactical_sandbox_mode if i == 0 else (tactical_sandbox_mode or rig.family[i].global_position.distance_to(cam_ctrl.fp_eye_pos if first_person_mode else hero.global_position) < 15.0)

	if not ui.is_blocking_modal_open() and first_person_mode:
		var mv: Vector3 = compute_wish_move_dir(cam_ctrl.fp_yaw)
		if mv.length_squared() > 0.01:
			var ws: Dictionary = rig.step_ark_deck_walk(noah_fp_local, noah_deck, mv, id != "noah_06_flood_dove" and noah_deck == 0 and absf(noah_fp_local.x) < 2.6, delta)
			noah_fp_local = ws.pos; noah_deck = int(ws.deck)
			if bool(ws.exited): _on_host_toggle_fp()
		cam_ctrl.fp_move_intensity = lerpf(cam_ctrl.fp_move_intensity, 1.0 if mv.length_squared() > 0.01 else 0.0, delta * 8.0)
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0, 1.68 + (sin(elapsed * 6.0) * 0.03 if mv.length_squared() > 0.01 and cam_ctrl.fp_head_bob_enabled else 0.0), 0))
	elif not ui.is_blocking_modal_open() and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"] and not tactical_sandbox_mode:
		var clip: String = hero.step_movement(delta, compute_wish_move_dir(cam_ctrl.current_yaw), Input.is_key_pressed(KEY_SHIFT), sim.cfg.rain_mud_speed_mul if sim.days_remaining < 25.0 else 1.0)
		NoahCastAndRaidRig.play_simple_anim(rig.family[0], clip)
		rig.set_actor_props(rig.family[0], false, true, id == "noah_03_hull_decks" and not rig.crisis_resolved and hero.global_position.z > 16.5)
		var ap: Vector3 = world.ark_anchor.position
		if fp_exit_cooldown <= 0.0 and sim.progressive_step_index() >= 12 and absf(hero.global_position.x - ap.x) < 48.0 and hero.global_position.z < ap.z + 7.8 and hero.global_position.z > ap.z - 8.0 and not manual_cutaway_lock:
			_on_host_toggle_fp()
		cam_ctrl.focus_on(hero.global_position + Vector3(0, 1.6, 0), -1.0, NAN, false)

	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"] and sim_dt > 0.0:
		sim.tick(sim_dt); world.update_forest_regrowth(sim_dt, sim.cfg.stump_regrow_sec)
		if id != "noah_03_hull_decks": world.update_countdown_weather(sim.days_remaining, sim.cfg.total_countdown_days, sim_dt)
		if sim.progressive_step_index() != last_ark_step: _sync_ark(); sfx("sfx_hammer.wav", -7.0)
		if not preview_mode and id == "noah_02_keel_mortise" and not dm01_triggered and sim.monument_pct >= 20.0: dm01_triggered = true; _open_dm("dm_01_drought_mockery")
		if not preview_mode and id == "noah_03_hull_decks" and not dm02_triggered and rig.raiders[0].position.z < 33.5: dm02_triggered = true; _open_dm("dm_02_stay_the_blade")
		rig.tick_workers_and_raid(sim_dt, elapsed, id, cam_ctrl, preview_mode); _check_act_complete(); _refresh_chapter_hud()
	elif id == "noah_05_board_ark" and not divine_seal_active:
		last_board_counts = rig.tick_boarding(delta, elapsed, first_person_mode, preview_mode); _refresh_chapter_hud()

	update_hotspot_proximity(world.ark_anchor.to_global(noah_fp_local) if first_person_mode else hero.global_position, ["noah_01_revelation", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"])
	var f_txt: String = (tr("BTN_FENCE_BUILDING") % int(sim.palisade_pct)) if sim.palisade_building else (tr("BTN_FENCE_BUILD") if sim.palisade_pct < 100.0 else ((tr("BTN_FENCE_REPAIR")) if sim.palisade_hp < sim.cfg.palisade_max_hp - 10.0 else (tr("BTN_FENCE_OK") % int(sim.palisade_hp))))
	ui.update_3d_bubbles(cam_ctrl.camera, tactical_sandbox_mode, {"log": world.grounded(56, 2, 4.5), "build": world.ark_anchor.position + Vector3(-2, 6.2, 8.5), "pitch": world.grounded(13.5, 15, 3.2), "guard": world.grounded(-12.5, 22.5, 3.8)}, {"log": tr("ST_LOG") % sim.w_gather, "build": tr("ST_BUILD") % sim.w_build, "pitch": tr("ST_PITCH") % sim.w_craft, "guard": tr("ST_GUARD") % sim.w_guard}, id == "noah_03_hull_decks" and not rig.crisis_resolved, f_txt, sim.fire_intensity > 0.02, world.grounded(-14.5, 16, 3.5))
	flood_level = move_toward(flood_level, flood_target, delta * 2.4)
	rig.tick_flood_and_dove(id, flood_level, elapsed, delta)


func _refresh_chapter_hud() -> void:
	if ui == null: return
	var id: String = story.current_event_id; var ev: Dictionary = story.current_event()
	var hide_top: bool = bool(ev.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"] or divine_seal_active
	ui.badges_box.visible = (not hide_top) and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]
	ui.sundial_panel.visible = not hide_top; ui.tactical_btn.visible = ui.badges_box.visible
	sync_common_hud_badges("RES_TIMBER", "RES_PITCH", "RES_FOOD", "RES_FAITH", ev, elapsed)
	if first_person_mode: ui.sundial_title_lbl.text = tr("HUD_FP_TITLE") % (noah_deck + 1); ui.sundial_sub_lbl.text = tr("HUD_FP_SUB")
	elif id == "noah_05_board_ark": ui.sundial_title_lbl.text = tr("HUD_BOARD_TITLE"); ui.sundial_sub_lbl.text = tr("HUD_BOARD_SUB") % [last_board_counts.x, rig.family.size(), last_board_counts.y, rig.animals.size()]
	elif id == "noah_06_flood_dove": ui.sundial_title_lbl.text = tr("HUD_FLOOD_TITLE"); ui.sundial_sub_lbl.text = tr("HUD_FLOOD_SUB")
	else:
		var wk: String = "WTH_SUNNY" if sim.days_remaining > 160 else ("WTH_WINDY" if sim.days_remaining > 90 else ("WTH_THUNDER" if sim.days_remaining > 25 else "WTH_STORM"))
		ui.sundial_title_lbl.text = tr("HUD_DAYS_LEFT") % [tr(wk), int(sim.days_remaining)]; ui.sundial_sub_lbl.text = tr("HUD_ARK_STEPS") % [int(roundf(sim.monument_pct)), sim.progressive_step_index()]
