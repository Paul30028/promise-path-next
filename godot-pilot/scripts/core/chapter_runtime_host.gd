class_name ChapterRuntimeHost
extends Node3D
## Universal 3D Chapter Cartridge Host (`FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md` §1):
## Provides out-of-the-box InputMap registration, `world_hotspot.tscn` spawning & raycast picking,
## `hud_biblical_v3.tscn` instantiation & save/load/settings wiring, Tactical Sandbox toggle,
## and unified Keyboard + Virtual Thumbstick movement vector calculation for ALL 12 3D Chapters!

const HOTSPOT_PREFAB: PackedScene = preload("res://scenes/prefabs/world_hotspot.tscn")
const HUD_PREFAB: PackedScene = preload("res://scenes/ui/hud_biblical_v3.tscn")

var chapter_id: String = "ch00_noah_ark"
var chapter: Dictionary = {}
var sim: DeterministicEconomySim
var story: StoryStateDirector
var cam_ctrl: RTSCameraController
var hero: PatriarchPlayer3D
var ui: PrologueUIV3

var hotspots: Array[Dictionary] = []
var active_hotspot: Dictionary = {}
var first_person_mode: bool = false
var tactical_sandbox_mode: bool = false
var preview_mode: bool = false


func sfx(file: String, vol: float = -4.0) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.call("play_sfx", file, vol)


func boot_cartridge(id_str: String, data_path: String, bal_res: ChapterBalanceResource, k1: String, k2: String, k3: String) -> void:
	chapter_id = id_str
	register_standard_inputs()
	sim = DeterministicEconomySim.new(bal_res)
	story = StoryStateDirector.new()
	add_child(story)
	chapter = story.setup_from_json(data_path)
	var init_st: Dictionary = chapter.get("initialState", {})
	sim.res_primary = float(init_st.get(k1, 45.0))
	sim.res_secondary = float(init_st.get(k2, 15.0))
	sim.res_tertiary = float(init_st.get(k3, 60.0))
	sim.harmony = float(init_st.get("harmony", 84.0))
	cam_ctrl = RTSCameraController.new()
	add_child(cam_ctrl)


func register_standard_inputs() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"interact": [KEY_E], "toggle_first_person": [KEY_F], "toggle_tactical_map": [KEY_SPACE, KEY_TAB],
		"toggle_cutaway": [KEY_V], "open_codex": [KEY_J], "pause_menu": [KEY_ESCAPE],
	}
	for action_name in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for kc in bindings[action_name]:
				var ev := InputEventKey.new()
				ev.keycode = kc as Key
				InputMap.action_add_event(action_name, ev)


func mount_hud_v3(codex_entries: Array, max_workers: int, env: Environment, sun_light: DirectionalLight3D) -> void:
	ui = HUD_PREFAB.instantiate() as PrologueUIV3
	add_child(ui)
	ui.build_ui(codex_entries)
	ui.request_toggle_fp.connect(_on_host_toggle_fp)
	ui.request_toggle_tactical.connect(_on_host_toggle_tactical)
	ui.request_toggle_cutaway.connect(_on_host_toggle_cutaway)
	ui.request_interact.connect(trigger_active_hotspot)
	ui.request_assign_worker.connect(func(st: String, dv: int) -> void:
		sim.assign_worker(st, dv, max_workers)
		sfx("sfx_assign.wav", -5.0)
		_refresh_chapter_hud()
	)
	ui.request_save_slot.connect(_on_host_save_slot)
	ui.request_load_slot.connect(_on_host_load_slot)
	ui.request_lang_changed.connect(_on_host_lang_changed)
	ui.request_quality_changed.connect(func(_q: int) -> void:
		var sv: Node = get_node_or_null("/root/SaveManager")
		if sv != null:
			sv.call("apply_graphics_quality_to_env", env, sun_light)
	)
	ui.request_main_menu.connect(func() -> void:
		var st: Node = get_node_or_null("/root/SceneTransition")
		if st != null:
			st.call("change_scene", "res://scenes/main_menu.tscn")
	)


func clear_hotspots() -> void:
	for h in hotspots:
		var n: Node = h.get("node") as Node
		if n != null and is_instance_valid(n):
			n.queue_free()
	hotspots.clear()
	active_hotspot = {}
	if ui != null and ui.interact_prompt != null:
		ui.interact_prompt.hide()


func add_hotspot_tr(id: String, pos: Vector3, tr_key: String, clip: String = "Hammer") -> void:
	for ex in hotspots:
		if str(ex.id) == id and not bool(ex.done):
			return
	var node: Area3D = HOTSPOT_PREFAB.instantiate() as Area3D
	node.position = pos
	add_child(node)
	var lbl: Label3D = node.get_node("Label3D") as Label3D
	lbl.text = "[E] " + tr(tr_key)
	hotspots.append({"id": id, "pos": pos, "tr_key": tr_key, "clip": clip, "done": false, "node": node, "lbl": lbl})


func sync_hotspots_display(allow_fp_id: String = "") -> void:
	for h in hotspots:
		var lbl: Label3D = h.get("lbl") as Label3D
		if lbl != null and is_instance_valid(lbl):
			if h.has("tr_key"):
				lbl.text = "[E] " + tr(str(h.tr_key))
			elif h.has("label_zh"):
				lbl.text = "[E] " + str(h.get("label_en" if ui.lang == "en_US" else "label_zh", ""))
			lbl.visible = (not first_person_mode) or (str(h.id) == allow_fp_id)


func update_hotspot_proximity(check_pos: Vector3, auto_single_ids: Array = []) -> void:
	if tactical_sandbox_mode:
		ui.interact_prompt.hide()
		return
	active_hotspot = {}
	for h in hotspots:
		if not bool(h.done) and check_pos.distance_to(h.pos) < 5.2:
			active_hotspot = h
	var single_ok: bool = (hotspots.size() == 1 and not bool(hotspots[0].done) and story.current_event_id in auto_single_ids)
	ui.interact_prompt.visible = (not active_hotspot.is_empty()) or single_ok
	if ui.interact_prompt.visible:
		var uh: Dictionary = active_hotspot if not active_hotspot.is_empty() else hotspots[0]
		if uh.has("tr_key"):
			ui.interact_prompt.text = "[E] " + tr(str(uh.tr_key))
		else:
			ui.interact_prompt.text = "[E] " + str(uh.get("label_en" if ui.lang == "en_US" else "label_zh", ""))


func trigger_active_hotspot() -> void:
	if ui.is_blocking_modal_open():
		return
	if not active_hotspot.is_empty():
		_on_hotspot_triggered(active_hotspot)
	elif hotspots.size() == 1 and not bool(hotspots[0].done):
		_on_hotspot_triggered(hotspots[0])


func compute_wish_move_dir(yaw: float) -> Vector3:
	var joy: Vector2 = ui.get_joystick_vector()
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var mv: Vector3 = fwd * (-joy.y) + right * joy.x
	if Input.is_action_pressed("move_forward"): mv += fwd
	if Input.is_action_pressed("move_back"): mv -= fwd
	if Input.is_action_pressed("move_left"): mv -= right
	if Input.is_action_pressed("move_right"): mv += right
	return mv


func toggle_tactical_overview(overview_center: Vector3, overview_dist: float = 66.0) -> void:
	if first_person_mode:
		_on_host_toggle_fp()
	tactical_sandbox_mode = not tactical_sandbox_mode
	cam_ctrl.free_pan_enabled = tactical_sandbox_mode
	ui.tactical_border.visible = tactical_sandbox_mode
	ui.tactical_btn.text = tr("BTN_TACTICAL_EXIT" if tactical_sandbox_mode else "BTN_TACTICAL_ENTER")
	cam_ctrl.pitch_override = -0.68 if tactical_sandbox_mode else NAN
	cam_ctrl.focus_on(overview_center if tactical_sandbox_mode else (hero.global_position + Vector3(0, 1.6, 0)), overview_dist if tactical_sandbox_mode else 36.0, -0.32 if tactical_sandbox_mode else NAN, false)
	sfx("sfx_ui_click.wav", -6.0)
	_refresh_chapter_hud()


func _on_host_save_slot(slot: int) -> void:
	var sv: Node = get_node_or_null("/root/SaveManager")
	if sv != null and bool(sv.call("save_slot", slot, {
		"chapter_id": chapter_id,
		"event_id": story.current_event_id,
		"ark_build_pct": sim.monument_pct,
		"monument_pct": sim.monument_pct,
		"sim": sim.to_dict(),
	}, get_viewport())):
		ui.refresh_save_slot_cards()


func _on_host_load_slot(slot: int) -> void:
	var sv: Node = get_node_or_null("/root/SaveManager")
	if sv == null:
		return
	var d: Dictionary = sv.call("load_slot", slot)
	if d.is_empty():
		return
	if d.get("sim") is Dictionary:
		sim.from_dict(d["sim"])
	ui.pause_overlay.hide()
	story.transition_to(str(d.get("event_id", story.current_event_id)), false)
	_after_slot_loaded()
	_refresh_chapter_hud()


func _unhandled_input(event: InputEvent) -> void:
	if ui == null:
		return
	if event.is_action_pressed("pause_menu") and not event.is_echo():
		ui.toggle_pause_menu()
		return
	if event.is_action_pressed("open_codex") and not event.is_echo():
		ui.toggle_codex()
		return
	if ui.is_blocking_modal_open():
		return
	if event.is_action_pressed("toggle_first_person") and not event.is_echo():
		_on_host_toggle_fp()
	elif event.is_action_pressed("toggle_tactical_map") and not event.is_echo():
		_on_host_toggle_tactical()
	elif event.is_action_pressed("toggle_cutaway") and not event.is_echo():
		_on_host_toggle_cutaway()
	elif event.is_action_pressed("interact") and not event.is_echo():
		trigger_active_hotspot()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not first_person_mode and not tactical_sandbox_mode:
		var mb: InputEventMouseButton = event
		var orig: Vector3 = cam_ctrl.camera.project_ray_origin(mb.position)
		var dir: Vector3 = cam_ctrl.camera.project_ray_normal(mb.position)
		for h in hotspots:
			if not bool(h.done):
				var t: float = (h.pos - orig).dot(dir)
				if t > 0.0 and (orig + dir * t).distance_to(h.pos + Vector3(0, 0.8, 0)) < 1.8:
					if hero.global_position.distance_to(h.pos) > 3.2:
						hero.click_target = h.pos
						hero.has_click_target = true
					else:
						_on_hotspot_triggered(h)
					return
		var hit: Variant = Plane(Vector3.UP, hero.global_position.y).intersects_ray(orig, dir)
		if hit != null:
			hero.click_target = hit
			hero.has_click_target = true


# Virtual hooks overridden by chapter cartridge coordinators (<= 350 lines each)
func open_dramatic_moment(dm_key: String, on_choice: Callable = Callable()) -> void:
	var dm: Dictionary = chapter.get("dramaticMoments", {}).get(dm_key, {})
	if dm.is_empty():
		return
	var is_en: bool = (ui.lang == "en_US")
	var opts: Array = []
	for ch in dm.get("choices", []):
		var cd: Dictionary = ch
		var cb: Callable = func() -> void:
			sim.harmony = clampf(sim.harmony + float(cd.get("deltaHarmony", 0.0)), 40.0, 100.0)
			sim.res_primary += float(cd.get("deltaTimber", 0.0))
			if on_choice.is_valid():
				on_choice.call(cd)
			sfx("sfx_covenant_chime.wav", -5.0)
			_refresh_chapter_hud()
		opts.append({"label": str(cd.get("labelEn" if (is_en and cd.has("labelEn")) else "labelZh", "")), "callback": cb})
	ui.open_choice_modal(str(dm.get("titleEn" if is_en else "titleZh", "")), str(dm.get("canonRef", "")), str(dm.get("bodyEn" if (is_en and dm.has("bodyEn")) else "bodyZh", "")), opts)


func sync_common_hud_badges(k1: String, k2: String, k3: String, k4: String, ev: Dictionary, elapsed_t: float) -> void:
	(ui.badge_labels["timber"] as Label).text = "%s %d%s" % [tr(k1), int(sim.res_primary), tr("FIRE_TAG") if sim.fire_intensity > 0.02 else ""]
	(ui.badge_labels["pitch"] as Label).text = "%s %d" % [tr(k2), int(sim.res_secondary)]
	(ui.badge_labels["provisions"] as Label).text = "%s %d" % [tr(k3), int(sim.res_tertiary)]
	(ui.badge_labels["harmony"] as Label).text = "%s %d%% (x%.2f)" % [tr(k4), int(sim.harmony), sim.harmony_multiplier()]
	(ui.badge_panels["timber"] as Control).modulate = Color(1.0, 0.58, 0.52) if (sim.res_primary < 12.0 or sim.fire_intensity > 0.02) else Color.WHITE
	ui.sundial_gauge.days_left = sim.days_remaining
	ui.sundial_gauge.max_days = sim.cfg.total_countdown_days
	ui.sundial_gauge.ark_pct = sim.monument_pct
	ui.sundial_gauge.pulse_t = elapsed_t
	ui.sundial_gauge.queue_redraw()
	var is_en: bool = (ui.lang == "en_US")
	var ref_txt: String = str(ev.get("canonRef", "")).replace("创 ", "Gen ") if is_en else str(ev.get("canonRef", ""))
	ui.subtitle_label.text = "【%s · %s】%s" % [str(ev.get("speakerEn" if is_en else "speakerZh", "")), ref_txt, str(ev.get("bodyEn" if is_en else "bodyZh", ""))]


func _on_host_toggle_fp() -> void: pass
func _on_host_toggle_tactical() -> void: pass
func _on_host_toggle_cutaway() -> void: pass
func _on_host_lang_changed(_lc: String) -> void: pass
func _on_hotspot_triggered(_h: Dictionary) -> void: pass
func _after_slot_loaded() -> void: pass
func _refresh_chapter_hud() -> void: pass
