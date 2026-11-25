extends Node3D
## Prologue M1 Commercial Slice (Genesis 6:13-9:17):
## - Data-driven config (`ch00_noah_ark.json` schemaVersion 3, zero hardcoded balance numbers)
## - Physical East-slope Gopher-Wood felling (4 axe swings -> 90-deg fall -> haul to depot -> +12 Timber 3D popup)
## - 30-Step Progressive Ark Hull + Scaffolding + 35ms Local Hit-Stop & Woodchip/Spark VFX
## - Two-Prong Raider Torch Raid + Timber Stack Fire Crisis + Mountain Spring Water Dousing
## - 4-Phase Dynamic Countdown Weather + Game UI V3 (`PrologueUIV3`: Bronze Sundial, 4 Badges, [Space] 3D Bubbles, [J] Codex, [Esc] 3-Slot Save/Load)
## - Named 8-Member Family Cast + 4 Signature Dramatic Moments (including 5s Reverent "Yahweh Shut Him In" Gen 7:16)

const DATA_PATH: String = "res://data/ch00_noah_ark.json"

var chapter: Dictionary = {}
var sim_cfg: Dictionary = {}
var event_index: Dictionary = {}
var current_event: Dictionary = {}
var state: Dictionary = {}
var lang: String = "zh_CN"

var world: NoahRTSWorld
var cam_ctrl: RTSCameraController
var ui: PrologueUIV3

# Named 8-Member Family & Cast
var family: Array[Node3D] = []
var family_nameplates: Array[Label3D] = []
var family_ai_phase: Array[float] = []
var worker_jobs: Array[Dictionary] = []  # Physical tree-chopping & hauling state per family member
var hitstop_timers: Dictionary = {}      # instance_id -> remaining hitstop sec
var build_hit_timers: Array[float] = []

var hired_workers: Array[Node3D] = []
var villagers: Array[Node3D] = []
var raiders: Array[Node3D] = []
var raider_morale: Array[float] = []
var raider_bars: Array[MeshInstance3D] = []
var raider_labels: Array[Label3D] = []
var animal_root: Node3D
var animals: Array[Node3D] = []
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []
var dove_flight_active: bool = false
var dove_flight_t: float = 0.0

# Direct-Control Noah & Dual-Mode UX
var noah_click_target: Vector3 = Vector3.ZERO
var noah_has_click_target: bool = false
var noah_busy_timer: float = 0.0
var noah_busy_clip: String = ""
var noah_deck: int = 0
var noah_fp_local: Vector3 = Vector3(-18.0, 0.65, 0.5)
var interior_cutaway: bool = false
var manual_cutaway_lock: bool = false
var first_person_interior: bool = false
var fp_exit_cooldown: float = 0.0
var tactical_sandbox_mode: bool = false

var hotspots: Array[Dictionary] = []
var active_hotspot: Dictionary = {}

# Simulation & Economy State (initialized from ch00_noah_ark.json)
var flood_countdown: float = 240.0
var max_flood_days: float = 240.0
var flood_failed: bool = false
var ark_build_pct: float = 0.0
var last_ark_step_idx: int = -1
var ark_completed_chime_played: bool = false
var timber_f: float = 45.0
var pitch_f: float = 15.0
var provisions_f: float = 60.0
var harmony_f: float = 84.0
var w_log: int = 2
var w_build: int = 3
var w_pitch: int = 1
var w_guard: int = 1
var inspection_boost_timer: float = 0.0
var strategy_alert: String = ""

# Palisade, Two-Prong Raider Clash & Timber Fire Crisis (GF-04)
var fence_build_pct: float = 0.0
var fence_hp: float = 0.0
var fence_max_hp: float = 300.0
var fence_building: bool = false
var fence_status_root: Node3D
var fence_hp_bar: MeshInstance3D
var fence_status_label: Label3D
var raider_clash_sfx_timer: float = 0.0
var rally_cooldown: float = 0.0
var timber_fire_intensity: float = 0.0
var fire_triggered_once: bool = false
var auto_douse_timer: float = 0.0

# Dramatic Moments State (Module 4)
var dm01_triggered: bool = false
var dm02_triggered: bool = false
var divine_seal_active: bool = false
var divine_seal_timer: float = 0.0

# Auto-Boarding State
var family_boarded: Array[bool] = []
var family_board_wp: Array[int] = []
var animal_boarded: Array[bool] = []
var animal_board_dist: Array[float] = []
var boarding_complete_timer: float = 0.0

var elapsed: float = 0.0
var crisis_resolved: bool = false
var flood_level: float = -10.5
var flood_target: float = -10.5
var preview_mode: bool = false
var preview_flag: String = ""


func _sfx(file: String, vol: float = -4.0, pitch_var: float = 0.06) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.call("play_sfx", file, vol, pitch_var)


func _ambience(file: String, vol: float = -10.0) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_ambience"):
		sm.call("play_ambience", file, vol)


func _stop_ambience() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("stop_ambience"):
		sm.call("stop_ambience")


func _set_interior_audio(inside: bool) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("set_interior_acoustics"):
		sm.call("set_interior_acoustics", inside)


func _register_input_map() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W],
		"move_back": [KEY_S],
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"interact": [KEY_E],
		"toggle_first_person": [KEY_F],
		"toggle_tactical_map": [KEY_SPACE, KEY_TAB],
		"toggle_cutaway": [KEY_V],
		"open_codex": [KEY_J],
		"pause_menu": [KEY_ESCAPE],
	}
	for action_name in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for kc in bindings[action_name]:
				var ev: InputEventKey = InputEventKey.new()
				ev.keycode = kc as Key
				InputMap.action_add_event(action_name, ev)


func _ready() -> void:
	_register_input_map()
	_load_json()
	world = NoahRTSWorld.new()
	world.name = "NoahRTSWorld"
	add_child(world)
	world.build_all()

	cam_ctrl = RTSCameraController.new()
	cam_ctrl.name = "RTSCameraController"
	add_child(cam_ctrl)

	_spawn_cast_and_animals()

	ui = PrologueUIV3.new()
	ui.name = "PrologueUIV3"
	add_child(ui)
	ui.build_ui(chapter.get("codexEntries", []))
	ui.request_toggle_fp.connect(_toggle_first_person)
	ui.request_toggle_tactical.connect(_toggle_tactical_sandbox)
	ui.request_toggle_cutaway.connect(_toggle_cutaway)
	ui.request_interact.connect(_trigger_active_hotspot)
	ui.request_assign_worker.connect(_assign_worker)
	ui.request_fence_work.connect(_start_fence_work)
	ui.request_douse_fire.connect(_douse_timber_fire)
	ui.request_save_slot.connect(_on_save_slot)
	ui.request_load_slot.connect(_on_load_slot)
	ui.request_lang_changed.connect(_on_lang_changed)
	ui.request_main_menu.connect(_on_return_main_menu)

	var start_id: String = str(chapter.get("firstEventId", "noah_01_revelation"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene="):
			var req: String = arg.trim_prefix("--preview-scene=")
			if event_index.has(req):
				start_id = req
				preview_mode = true
		elif arg == "--interior":
			start_id = "noah_03_hull_decks"
			preview_mode = true
			manual_cutaway_lock = true
			interior_cutaway = true
		elif arg == "--first-person":
			start_id = "noah_03_hull_decks"
			preview_mode = true
			first_person_interior = true
		elif arg == "--flood-fp":
			start_id = "noah_06_flood_dove"
			preview_mode = true
			first_person_interior = true
		elif arg == "--tactical-sandbox":
			start_id = "noah_03_hull_decks"
			preview_mode = true
			preview_flag = "tactical"
		elif arg == "--fire-crisis-preview":
			start_id = "noah_03_hull_decks"
			preview_mode = true
			preview_flag = "fire_crisis"
		elif arg == "--codex-preview":
			start_id = "noah_02_keel_mortise"
			preview_mode = true
			preview_flag = "codex"
		elif arg == "--divine-seal-preview":
			start_id = "noah_05_board_ark"
			preview_mode = true
			preview_flag = "divine_seal"

	# Check if MainMenu requested loading a saved slot
	var sv_mgr: Node = get_node_or_null("/root/SaveManager")
	if not preview_mode and sv_mgr != null and sv_mgr.get("pending_load_slot") != null and int(sv_mgr.get("pending_load_slot")) > 0:
		var slot_to_load: int = int(sv_mgr.get("pending_load_slot"))
		sv_mgr.set("pending_load_slot", 0)
		_enter_event(start_id, false)
		_on_load_slot(slot_to_load)
		return

	_enter_event(start_id, false)
	_apply_preview_overrides()


func _apply_preview_overrides() -> void:
	if preview_flag == "tactical":
		ark_build_pct = 54.0
		flood_countdown = 118.0
		_apply_ark_visibility()
		_toggle_tactical_sandbox()
		cam_ctrl.focus_on(Vector3(6.0, 2.0, 12.0), 66.0, -0.32, true)
	elif preview_flag == "fire_crisis":
		ark_build_pct = 58.0
		flood_countdown = 82.0
		fence_build_pct = 65.0
		fence_hp = 110.0
		world.set_fence_progress(fence_build_pct)
		timber_fire_intensity = 0.92
		fire_triggered_once = true
		world.set_timber_fire_intensity(timber_fire_intensity)
		_ensure_fire_douse_hotspot()
		_apply_ark_visibility()
		family[0].position = world.grounded(-8.5, 16.5)
		family[0].look_at(world.grounded(-15.5, 16.0), Vector3.UP)
		cam_ctrl.pitch_override = -0.36
		cam_ctrl.focus_on(Vector3(-11.0, 1.8, 17.5), 25.0, 0.28, true)
	elif preview_flag == "codex":
		ark_build_pct = 24.0
		flood_countdown = 196.0
		_apply_ark_visibility()
		ui.codex_drawer.show()
		cam_ctrl.focus_on(Vector3(-6.0, 3.0, 8.0), 54.0, -0.44, true)
	elif preview_flag == "divine_seal":
		ark_build_pct = 100.0
		divine_seal_active = true
		_clear_hotspots()
		_stage_all_inside_ark()
		animal_root.hide()
		world.set_ark_progress(100.0, false, true, false)
		var dm3: Dictionary = chapter.get("dramaticMoments", {}).get("dm_03_divine_seal", {})
		ui.show_divine_seal(str(dm3.get("titleZh", "")), str(dm3.get("verseZh", "")), true)
		cam_ctrl.focus_on(Vector3(0.0, 3.5, 12.0), 32.0, -0.25, true)
	_refresh_hud()


func _load_json() -> void:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		chapter = parsed
		sim_cfg = chapter.get("simulationConfig", {})
		state = chapter.get("initialState", {}).duplicate(true)
		max_flood_days = float(sim_cfg.get("floodCountdownDays", 240.0))
		flood_countdown = max_flood_days
		timber_f = float(state.get("timber", 45.0))
		pitch_f = float(state.get("pitch", 15.0))
		provisions_f = float(state.get("provisions", 60.0))
		harmony_f = float(state.get("harmony", 84.0))
		fence_max_hp = float(sim_cfg.get("fenceMaxHp", 300.0))
		for ev in chapter.get("events", []):
			event_index[str(ev.id)] = ev


func _harmony_mul() -> float:
	var base: float = float(sim_cfg.get("harmonyBase", 80.0))
	var mn: float = float(sim_cfg.get("harmonyMinMul", 0.75))
	var mx: float = float(sim_cfg.get("harmonyMaxMul", 1.35))
	var t: float = clampf((harmony_f - 40.0) / 60.0, 0.0, 1.0)
	if harmony_f >= base:
		return lerpf(1.0, mx, clampf((harmony_f - base) / 20.0, 0.0, 1.0))
	return lerpf(mn, 1.0, clampf((harmony_f - 40.0) / maxf(base - 40.0, 1.0), 0.0, 1.0))


func _anim(actor: Node3D, clip: String) -> void:
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(clip):
		return
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if ap.current_animation != clip:
		ap.play(clip, 0.18)
		ap.advance(0.0)


func _trigger_local_hitstop(actor: Node3D, duration: float = 0.035) -> void:
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	ap.speed_scale = 0.04
	hitstop_timers[actor.get_instance_id()] = duration


func _update_hitstops(delta: float) -> void:
	if hitstop_timers.is_empty():
		return
	var done_ids: Array = []
	for iid in hitstop_timers.keys():
		var rem: float = float(hitstop_timers[iid]) - delta
		if rem <= 0.0:
			done_ids.append(iid)
			var obj: Object = instance_from_id(int(iid))
			if obj is Node3D:
				var ap: AnimationPlayer = (obj as Node3D).find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap != null:
					ap.speed_scale = 1.0
		else:
			hitstop_timers[iid] = rem
	for iid in done_ids:
		hitstop_timers.erase(iid)


func _attach_hand_tool(actor: Node3D, glb_file: String) -> void:
	var skel: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var bone_idx: int = skel.find_bone("Forearm_R")
	if bone_idx < 0:
		bone_idx = skel.find_bone("UpperArm_R")
	if bone_idx < 0:
		return
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "RightHandTool"
	ba.bone_idx = bone_idx
	skel.add_child(ba)
	var tool_node: Node3D = world.spawn_asset(glb_file, 0.44 if "Sword" in glb_file else 0.40, Vector3(0.0, -0.22, -0.04), ba)
	tool_node.rotation_degrees = Vector3(-82.0, 0.0, 0.0)


func _attach_left_shield(actor: Node3D) -> void:
	var skel: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var bone_idx: int = skel.find_bone("Forearm_L")
	if bone_idx < 0:
		bone_idx = skel.find_bone("UpperArm_L")
	if bone_idx < 0:
		return
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "LeftHandShield"
	ba.bone_idx = bone_idx
	skel.add_child(ba)
	var sh_scene: PackedScene = load("res://assets/models/WPN_WoodenShield.glb") as PackedScene
	if sh_scene != null:
		var sh: Node3D = sh_scene.instantiate() as Node3D
		ba.add_child(sh)
		var max_dim: float = 0.05
		for mnode in sh.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = mnode as MeshInstance3D
			if mi != null and mi.mesh != null:
				var sz: Vector3 = mi.mesh.get_aabb().size
				max_dim = maxf(max_dim, maxf(maxf(sz.x, sz.y), sz.z))
		var skel_sc: float = maxf(skel.get_parent().scale.y if skel.get_parent() is Node3D else 1.0, 0.25)
		var s: float = (0.56 / max_dim) / skel_sc
		sh.scale = Vector3.ONE * s
		sh.position = Vector3(-0.08, -0.10, -0.06) / skel_sc
		sh.rotation_degrees = Vector3(12.0, 82.0, 0.0)
	ba.hide()


func _attach_status_bar(parent: Node3D, y_off: float, init_text: String, fill_col: Color, width: float = 1.25) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.position = Vector3(0.0, y_off, 0.0)
	parent.add_child(root)

	var bg: MeshInstance3D = MeshInstance3D.new()
	var bg_q: QuadMesh = QuadMesh.new()
	bg_q.size = Vector2(width + 0.08, 0.20)
	bg.mesh = bg_q
	var bg_m: StandardMaterial3D = StandardMaterial3D.new()
	bg_m.albedo_color = Color(0.08, 0.06, 0.05, 0.85)
	bg_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_m.no_depth_test = true
	bg.material_override = bg_m
	root.add_child(bg)

	var fill: MeshInstance3D = MeshInstance3D.new()
	var fq: QuadMesh = QuadMesh.new()
	fq.size = Vector2(width, 0.13)
	fill.mesh = fq
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = fill_col
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	fill.material_override = fm
	fill.position.z = 0.01
	root.add_child(fill)

	var lbl: Label3D = Label3D.new()
	lbl.text = init_text
	lbl.position = Vector3(0.0, 0.24, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 30
	lbl.pixel_size = 0.0042
	lbl.modulate = Color(1.0, 0.94, 0.80)
	lbl.outline_modulate = Color(0.06, 0.04, 0.03)
	lbl.outline_size = 9
	root.add_child(lbl)
	return {"root": root, "fill": fill, "lbl": lbl}


func _attach_carried_log(actor: Node3D) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CarriedLog"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.10
	cm.height = 1.65
	mi.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.38, 0.23, 0.11)
	m.roughness = 0.92
	mi.material_override = m
	mi.position = Vector3(0.24, 1.15, -0.12)
	mi.rotation_degrees = Vector3(82.0, 12.0, 0.0)
	actor.add_child(mi)
	return mi


func _add_torch(parent: Node3D) -> void:
	var stick: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.025
	cyl.height = 0.65
	stick.mesh = cyl
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0.28, 0.16, 0.08)
	stick.material_override = sm
	stick.position = Vector3(0.32, 1.15, -0.25)
	parent.add_child(stick)
	var flame: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.10
	sph.height = 0.22
	flame.mesh = sph
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.65, 0.18)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.52, 0.12)
	fm.emission_energy_multiplier = 2.4
	flame.material_override = fm
	flame.position = Vector3(0.32, 1.52, -0.25)
	parent.add_child(flame)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.32, 1.65, -0.25)
	light.light_color = Color(1.0, 0.58, 0.22)
	light.light_energy = 1.8
	light.omni_range = 6.5
	parent.add_child(light)


func _spawn_cast_and_animals() -> void:
	var fam_files: Array[String] = [
		"CHR_Noah_rigged.glb",
		"CHR_Noah_Wife_rigged.glb",
		"CHR_Noah_Son_rigged.glb",
		"CHR_Noah_Son_rigged.glb",
		"CHR_Noah_Son_rigged.glb",
		"CHR_Noah_Daughter_rigged.glb",
		"CHR_Noah_Daughter_rigged.glb",
		"CHR_Noah_Daughter_rigged.glb",
	]
	var cast_cfg: Array = chapter.get("familyCast", [])
	for i in range(fam_files.size()):
		var h: float = 1.72 if i == 0 else (1.58 if i == 1 or i >= 5 else 1.65)
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(0.0 + float(i) * 1.4, 21.0))
		actor.name = "Family_%d" % i
		family.append(actor)
		family_ai_phase.append(float(i) * 1.37)
		build_hit_timers.append(float(i) * 0.27)
		worker_jobs.append({
			"phase": "to_tree",
			"tree_idx": -1,
			"chop_timer": 0.0,
		})
		_attach_hand_tool(actor, "WPN_Mallet.glb")
		_attach_left_shield(actor)
		if i > 0:
			var lg: Node3D = _attach_carried_log(actor)
			lg.hide()
		# Named Family 3D Nameplate (Genesis 6:10 / 7:7)
		var np_lbl: Label3D = Label3D.new()
		var cinfo: Dictionary = cast_cfg[i] if i < cast_cfg.size() else {}
		np_lbl.text = str(cinfo.get("nameZh", "家人"))
		np_lbl.position = Vector3(0.0, h + 0.34, 0.0)
		np_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		np_lbl.no_depth_test = true
		np_lbl.font_size = 26
		np_lbl.pixel_size = 0.0038
		np_lbl.modulate = Color(1.0, 0.92, 0.72, 0.92)
		np_lbl.outline_modulate = Color(0.06, 0.04, 0.02, 0.95)
		np_lbl.outline_size = 8
		actor.add_child(np_lbl)
		family_nameplates.append(np_lbl)
		_anim(actor, "Idle")

	for i in range(2):
		var hw: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.62, world.grounded(18.0 + float(i) * 2.2, 16.0))
		_attach_hand_tool(hw, "WPN_Mallet.glb")
		hw.hide()
		hired_workers.append(hw)

	for i in range(4):
		var v: Node3D = world.spawn_asset("CHR_Abram_rigged.glb" if i % 2 == 0 else "CHR_Noah_Son_rigged.glb", 1.62, world.grounded(-5.0 + float(i) * 2.8, 42.0))
		v.hide()
		villagers.append(v)

	# 5 Torch Raiders: 0..2 South Main Force, 3..4 Southeast Flank Fire-Raiders!
	for i in range(5):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.68, world.grounded(-18.5 + float(i) * 3.0, 46.0))
		_add_torch(r)
		_attach_hand_tool(r, "WPN_BronzeSword.glb")
		var role_tag: String = "侧翼纵火" if i >= 3 else "南路强人"
		var mb: Dictionary = _attach_status_bar(r, 2.12, "%s 100%%" % role_tag, Color(0.92, 0.28, 0.18), 1.15)
		raider_bars.append(mb["fill"] as MeshInstance3D)
		raider_labels.append(mb["lbl"] as Label3D)
		raider_morale.append(100.0)
		r.hide()
		raiders.append(r)

	fence_status_root = Node3D.new()
	fence_status_root.name = "FenceStatusHUD3D"
	fence_status_root.position = world.grounded(-12.5, 22.5, 2.55)
	add_child(fence_status_root)
	var fb: Dictionary = _attach_status_bar(fence_status_root, 0.0, "木栅防线 未修筑", Color(0.30, 0.82, 0.42), 2.4)
	fence_hp_bar = fb["fill"] as MeshInstance3D
	fence_status_label = fb["lbl"] as Label3D
	fence_status_root.hide()

	animal_root = Node3D.new()
	animal_root.name = "AnimalProcession"
	add_child(animal_root)
	var species: Array[Dictionary] = [
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.92}, {"file": "CC0_Sheep_Grab3D.glb", "h": 0.88},
		{"file": "CC0_Bull_Grab3D.glb", "h": 1.48}, {"file": "CC0_Bull_Grab3D.glb", "h": 1.40},
		{"file": "CC0_Horse_Grab3D.glb", "h": 1.62}, {"file": "CC0_Horse_Grab3D.glb", "h": 1.54},
		{"file": "CC0_Deer_Grab3D.glb", "h": 1.32}, {"file": "CC0_Deer_Grab3D.glb", "h": 1.24},
		{"file": "CC0_Lion_Grab3D.glb", "h": 1.12}, {"file": "CC0_Lion_Grab3D.glb", "h": 1.04},
	]
	for i in range(species.size()):
		var ani: Node3D = world.spawn_asset(str(species[i].file), float(species[i].h), Vector3.ZERO, animal_root)
		ani.name = "Animal_%d" % i
		_anim(ani, "Idle")
		animals.append(ani)
	animal_root.hide()

	var ap: Vector3 = world.ark_anchor.position
	boarding_path = [
		world.grounded(4.5, 29.0),
		world.grounded(1.8, 20.5),
		ap + Vector3(0.0, 0.0, 19.2),
		ap + Vector3(0.0, 0.68, 8.6),
		ap + Vector3(0.0, 0.68, 3.6),
	]

	for bf: String in ["CC0_Bird_Grab3D.glb", "ANI_Dove_Olive.glb"]:
		var b: Node3D = world.spawn_asset(bf, 0.72, Vector3(0.0, 16.0, 0.0))
		b.hide()
		birds.append(b)


func _clear_hotspots() -> void:
	for h in hotspots:
		var n: Node3D = h.get("node") as Node3D
		if n != null and is_instance_valid(n):
			n.queue_free()
	hotspots.clear()
	active_hotspot = {}
	if ui != null and ui.interact_prompt != null:
		ui.interact_prompt.hide()


func _add_hotspot(id: String, pos: Vector3, label: String, clip: String = "Hammer", ring_col: Color = Color(1.0, 0.82, 0.34, 0.88)) -> void:
	for existing in hotspots:
		if str(existing.id) == id and not bool(existing.done):
			return
	var root: Node3D = Node3D.new()
	root.name = "Hotspot_" + id
	root.position = pos
	add_child(root)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.72
	ring.mesh = tm
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.albedo_color = ring_col
	rm.emission_enabled = true
	rm.emission = Color(ring_col.r, ring_col.g, ring_col.b)
	rm.emission_energy_multiplier = 1.6
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position.y = 0.08
	root.add_child(ring)

	var lbl: Label3D = Label3D.new()
	lbl.text = "[E] " + label
	lbl.position = Vector3(0.0, 1.55, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 34
	lbl.pixel_size = 0.0038
	lbl.modulate = Color(1.0, 0.94, 0.76)
	lbl.outline_modulate = Color(0.08, 0.05, 0.03)
	lbl.outline_size = 10
	root.add_child(lbl)

	hotspots.append({"id": id, "pos": pos, "label": label, "clip": clip, "done": false, "node": root, "ring": ring, "lbl": lbl})


func _ensure_fire_douse_hotspot() -> void:
	if world.spring_well != null:
		_add_hotspot("douse_fire", world.spring_well.position + Vector3(0.0, 0.0, 1.4), "山泉提水扑救料堆火情 (-50%火势)", "Bless", Color(0.28, 0.78, 1.0, 0.92))


func _sync_hotspot_labels() -> void:
	for h in hotspots:
		var lbl: Label3D = h.get("lbl") as Label3D
		if lbl != null and is_instance_valid(lbl):
			var allow_fp_hotspot: bool = (str(h.id) == "release_dove")
			lbl.visible = (not first_person_interior) or allow_fp_hotspot


func _assign_worker(station: String, delta_v: int) -> void:
	var idle_pool: int = 7 - (w_log + w_build + w_pitch + w_guard)
	if delta_v > 0 and idle_pool <= 0:
		if station != "log" and w_log > 1:
			w_log -= 1
		elif station != "build" and w_build > 1:
			w_build -= 1
		elif station != "pitch" and w_pitch > 0:
			w_pitch -= 1
		elif station != "guard" and w_guard > 0:
			w_guard -= 1
		else:
			return
	match station:
		"log": w_log = clampi(w_log + delta_v, 0, 7)
		"build": w_build = clampi(w_build + delta_v, 0, 7)
		"pitch": w_pitch = clampi(w_pitch + delta_v, 0, 7)
		"guard": w_guard = clampi(w_guard + delta_v, 0, 7)
	_sfx("sfx_assign.wav", -5.0)
	_refresh_hud()


func _toggle_first_person() -> void:
	var id: String = str(current_event.get("id", ""))
	if id == "noah_01_revelation":
		return
	if tactical_sandbox_mode:
		_toggle_tactical_sandbox()
	first_person_interior = not first_person_interior
	if first_person_interior:
		interior_cutaway = false
		manual_cutaway_lock = false
		noah_deck = 0
		noah_fp_local = Vector3(-25.0, 0.65, 0.4) if id in ["noah_05_board_ark", "noah_06_flood_dove"] else Vector3(-16.0, 0.65, 0.4)
		family[0].global_position = world.ark_anchor.to_global(noah_fp_local)
		cam_ctrl.set_first_person(true, preview_mode)
		cam_ctrl.fp_yaw = -PI * 0.48
		cam_ctrl.fp_pitch = 0.02
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68, 0.0))
		cam_ctrl._apply_camera_transform()
		family[0].hide()
	else:
		cam_ctrl.set_first_person(false, preview_mode)
		fp_exit_cooldown = 1.6
		noah_deck = 0
		if id == "noah_06_flood_dove":
			family[0].hide()
		elif id == "noah_05_board_ark" and family_boarded.size() > 0 and family_boarded[0]:
			family[0].hide()
		else:
			if family[0].get_parent() != self:
				family[0].reparent(self, false)
			var ap: Vector3 = world.ark_anchor.position
			if family[0].position.z < ap.z + 10.0:
				family[0].position = world.grounded(0.0, 21.0)
			family[0].show()
	_apply_ark_visibility()
	_sync_hotspot_labels()
	ui.fp_crosshair.visible = first_person_interior
	ui.fp_btn.text = "退出第一人称 [F]" if first_person_interior else "第一人称 [F]"
	_refresh_hud()


func _toggle_tactical_sandbox() -> void:
	var id: String = str(current_event.get("id", ""))
	if id not in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		return
	if first_person_interior:
		_toggle_first_person()
	tactical_sandbox_mode = not tactical_sandbox_mode
	cam_ctrl.free_pan_enabled = tactical_sandbox_mode
	ui.tactical_border.visible = tactical_sandbox_mode
	ui.tactical_btn.text = "退出沙盘 [Space]" if tactical_sandbox_mode else "沙盘派工 [Space]"
	if tactical_sandbox_mode:
		cam_ctrl.pitch_override = -0.68
		cam_ctrl.focus_on(Vector3(4.0, 2.0, 12.0), 68.0, -0.30, false)
	else:
		cam_ctrl.pitch_override = NAN
		cam_ctrl.focus_on(family[0].position + Vector3(0.0, 1.6, 0.0), 38.0, NAN, false)
	_sfx("sfx_ui_click.wav", -6.0)
	_refresh_hud()


func _toggle_cutaway() -> void:
	if first_person_interior:
		_toggle_first_person()
	manual_cutaway_lock = not manual_cutaway_lock
	interior_cutaway = manual_cutaway_lock
	_apply_ark_visibility()
	ui.cutaway_btn.text = "关剖面 [V]" if interior_cutaway else "剖面 [V]"


func _compute_ark_step_idx() -> int:
	var id: String = str(current_event.get("id", ""))
	if id == "noah_01_revelation" or ark_build_pct <= 0.01:
		return 0
	return clampi(int(ceil(ark_build_pct / 100.0 * 30.0)), 1, 30)


func _apply_ark_visibility() -> void:
	var id: String = str(current_event.get("id", ""))
	var step_idx: int = _compute_ark_step_idx()
	last_ark_step_idx = step_idx
	var show_scaffold: bool = (step_idx >= 1 and ark_build_pct < 99.5 and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"])
	var seal_door: bool = (id == "noah_06_flood_dove") or divine_seal_active
	world.set_ark_progress(0.0 if id == "noah_01_revelation" else ark_build_pct, interior_cutaway, seal_door, show_scaffold)


func _enter_event(id: String, preserve_positions: bool = false) -> void:
	if not event_index.has(id):
		return
	var prev_id: String = str(current_event.get("id", ""))
	current_event = event_index[id]
	crisis_resolved = false
	flood_failed = false
	divine_seal_active = false
	dove_flight_active = false
	noah_has_click_target = false
	noah_busy_timer = 0.0
	noah_deck = 0
	if ui != null:
		ui.modal_overlay.hide()
		ui.hide_divine_seal()
	_clear_hotspots()

	var stage: int = int(current_event.get("arkStage", 0))
	state.arkStage = stage
	if not preserve_positions:
		_restore_all_to_world()
	var keep_fp_preview: bool = preview_mode and ((id == "noah_03_hull_decks" and first_person_interior) or (id == "noah_06_flood_dove" and first_person_interior))
	if first_person_interior and not keep_fp_preview and id not in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		first_person_interior = false
		cam_ctrl.set_first_person(false, preview_mode)
		family[0].show()
	if tactical_sandbox_mode and id not in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		tactical_sandbox_mode = false
		cam_ctrl.free_pan_enabled = false
		ui.tactical_border.hide()

	if ui != null:
		ui.fp_crosshair.visible = first_person_interior
		ui.fp_btn.text = "退出第一人称 [F]" if first_person_interior else "第一人称 [F]"
		var banner_title: String = str(current_event.get("actBannerEn" if lang == "en_US" else "actBannerZh", ""))
		if not preview_mode:
			ui.show_act_banner(banner_title, str(current_event.get("canonRef", "")))

	match id:
		"noah_01_revelation": ark_build_pct = 0.0
		"noah_02_keel_mortise": ark_build_pct = maxf(ark_build_pct, 8.0)
		"noah_03_hull_decks": ark_build_pct = maxf(ark_build_pct, 36.0)
		"noah_04_pitch_provisions": ark_build_pct = maxf(ark_build_pct, 75.0)
		"noah_05_board_ark", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant": ark_build_pct = 100.0
	if not manual_cutaway_lock:
		interior_cutaway = false
	_apply_ark_visibility()

	world.yard_stakes.visible = (id == "noah_01_revelation")
	world.timber_stacks.visible = (stage >= 1 and id != "noah_06_flood_dove")
	world.spring_well.visible = (stage >= 1 and id not in ["noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"])
	world.pitch_station.visible = (stage >= 2 and id != "noah_06_flood_dove")
	timber_fire_intensity = 0.0
	fire_triggered_once = false
	world.set_timber_fire_intensity(0.0)

	if id == "noah_03_hull_decks":
		fence_building = false
		if preview_mode and preview_flag.is_empty() and not first_person_interior and not interior_cutaway:
			fence_build_pct = 72.0
			fence_hp = 215.0
			w_log = 1
			w_build = 2
			w_pitch = 1
			w_guard = 3
		else:
			fence_build_pct = 0.0 if not bool(state.get("guardFence", false)) else 100.0
			fence_hp = 0.0 if not bool(state.get("guardFence", false)) else fence_max_hp
		world.set_fence_progress(fence_build_pct)
		fence_status_root.visible = not first_person_interior
		for i in range(raiders.size()):
			raider_morale[i] = 68.0 if (preview_mode and not first_person_interior) else 100.0
			if i < 3:
				# South Main Prong (3 raiders)
				var rx: float = -20.0 + float(i) * 4.2
				var rz: float = 24.4 if (preview_mode and not first_person_interior) else (44.0 + float(i % 2) * 3.0)
				raiders[i].position = world.grounded(rx, rz)
				raiders[i].look_at(world.grounded(rx, 18.0), Vector3.UP)
			else:
				# Southeast Fire-Raider Flank (2 raiders)
				var fx: float = 10.0 + float(i - 3) * 4.5
				var fz: float = 26.0 if (preview_mode and not first_person_interior) else 38.0
				raiders[i].position = world.grounded(fx, fz)
				raiders[i].look_at(world.grounded(-12.0, 16.0), Vector3.UP)
			raiders[i].show()
	else:
		fence_status_root.hide()
		if bool(state.get("guardFence", false)) and stage >= 2 and id not in ["noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
			world.set_fence_progress(100.0)
		else:
			world.set_fence_progress(0.0)
		for r in raiders:
			r.hide()

	world.altar_group.visible = id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	world.puddles_group.visible = id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	world.olive_shoots.visible = id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	world.rainbow.visible = (id == "noah_08_rainbow_covenant")
	animal_root.visible = (id == "noah_05_board_ark")
	for b in birds:
		b.visible = id in ["noah_06_flood_dove", "noah_07_exit_altar"]
	for hw in hired_workers:
		hw.visible = (id == "noah_02_keel_mortise")
	for v in villagers:
		v.visible = (id == "noah_02_keel_mortise")

	var ap: Vector3 = world.ark_anchor.position
	match id:
		"noah_01_revelation":
			world.apply_mood("revelation")
			_stop_ambience()
			_sfx("sfx_covenant_chime.wav", -6.0, 0.0)
			flood_target = -15.0
			for i in range(family.size()):
				family[i].visible = (i == 0)
				_set_actor_props(family[i], false, false, false)
			family[0].position = world.grounded(-2.0, 18.0)
			family[0].look_at(world.grounded(2.0, -10.0), Vector3.UP)
			_anim(family[0], "Pray")
			cam_ctrl.pitch_override = -0.20
			cam_ctrl.focus_on(family[0].position + Vector3(2.0, 2.5, -5.0), 15.0, -0.52, preview_mode)
			_add_hotspot("accept_call", family[0].position + Vector3(0.0, 0.0, -2.5), "领受三百肘造舟天启", "Bless")

		"noah_02_keel_mortise":
			world.apply_mood("build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			if not preserve_positions or prev_id == "noah_01_revelation":
				family[0].position = world.grounded(-10.0, 16.0)
				_anim(family[0], "Idle")
				cam_ctrl.focus_on(Vector3(0.0, 3.0, 6.0), 58.0, -0.42, preview_mode)
			_add_hotspot("keel_west", world.grounded(-18.0, 9.5), "检查西段三百肘龙骨榫卯", "Hammer")
			_add_hotspot("keel_east", world.grounded(18.0, 9.5), "敲紧东段肋骨木楔", "Hammer")
			_add_hotspot("timber_check", world.grounded(-15.0, 17.5), "验收东坡歌斐木料堆", "Idle")

		"noah_03_hull_decks":
			world.apply_mood("build" if (interior_cutaway or first_person_interior) else "dusk_raid")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			if first_person_interior and preview_mode:
				interior_cutaway = false
				_apply_ark_visibility()
				family[0].position = ap + Vector3(-18.0, 0.65, 0.0)
				family[0].hide()
				cam_ctrl.set_first_person(true, true)
				cam_ctrl.fp_eye_pos = family[0].position + Vector3(0.0, 1.68, 0.0)
				cam_ctrl.fp_yaw = -PI * 0.48
				cam_ctrl.fp_pitch = 0.03
				cam_ctrl._apply_camera_transform()
			elif interior_cutaway and preview_mode:
				family[0].position = ap + Vector3(-8.0, 0.65, 0.0)
				family[0].look_at(ap + Vector3(12.0, 0.65, 0.0), Vector3.UP)
				_anim(family[0], "Hammer")
				cam_ctrl.pitch_override = -0.32
				cam_ctrl.focus_on(ap + Vector3(0.0, 4.5, 0.0), 48.0, -0.30, true)
			elif preview_mode and preview_flag.is_empty():
				family[0].position = world.grounded(-10.5, 20.6)
				family[0].look_at(world.grounded(-12.0, 26.0), Vector3.UP)
				_set_actor_props(family[0], false, true, true)
				_anim(family[0], "Brawl")
				cam_ctrl.pitch_override = -0.34
				cam_ctrl.focus_on(Vector3(-12.5, 1.8, 22.0), 22.0, 0.36, true)
				_update_living_family(0.016, id)
				_update_raider_conflict(0.016)
			elif not preserve_positions:
				family[0].position = world.grounded(-6.0, 20.5)
				cam_ctrl.focus_on(Vector3(-8.0, 3.2, 18.0), 42.0, 0.25, preview_mode)
			_add_hotspot("inside_lower", ap + Vector3(-8.0, 0.65, 0.0), "检查下层龙骨榫卯与大型畜栏", "Hammer")
			_add_hotspot("inside_mid", ap + Vector3(15.5, 3.95, 0.0), "沿北侧木梯上中层检查分舱隔间", "Hammer")
			_add_hotspot("defend_yard", world.grounded(-12.5, 21.2), "亲临南坡盾阵鼓舞士气（止戈惊退强人）", "Bless")
			_sync_hotspot_labels()

		"noah_04_pitch_provisions":
			world.apply_mood("build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			if not preserve_positions:
				family[0].position = world.grounded(10.0, 18.0)
				cam_ctrl.pitch_override = -0.24
				cam_ctrl.focus_on(Vector3(-4.0, 4.5, 6.0), 56.0, -0.46, preview_mode)
			_add_hotspot("pitch_inside", ap + Vector3(-10.0, 0.65, 0.0), "入舱检查内壁松香防水缝", "BrushPitch")
			_add_hotspot("pitch_outside", world.grounded(11.5, 15.5), "熬漆里外厚涂松香", "BrushPitch")
			_add_hotspot("provisions_check", world.grounded(15.0, 15.8), "清点干湿分区粮草陶罐", "Idle")

		"noah_05_board_ark":
			world.apply_mood("dusk_raid")
			world.rain.emitting = true
			_ambience("sfx_rain_loop.wav", -10.0)
			_sfx("sfx_thunder.wav", -5.0)
			flood_countdown = 0.0
			cam_ctrl.pitch_override = -0.26
			_init_auto_boarding()
			cam_ctrl.focus_on(Vector3(0.0, 2.8, 15.5), 34.0, -0.34, preview_mode)
			if preview_mode and preview_flag.is_empty():
				for _step in range(56):
					_update_auto_boarding(0.05)
			_add_hotspot("seal_door", ap + Vector3(0.0, 0.65, 12.0), "加速引导全员入舱（全员入舱后耶和华亲自封门）", "Bless")

		"noah_06_flood_dove":
			world.apply_mood("flood")
			_ambience("sfx_rain_loop.wav", -8.0)
			_sfx("sfx_thunder.wav", -4.0)
			cam_ctrl.pitch_override = NAN
			flood_target = 6.5
			if preview_mode:
				flood_level = 6.2
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = flood_level - 1.2
			_stage_all_inside_ark()
			if first_person_interior and preview_mode:
				noah_deck = 0
				noah_fp_local = Vector3(-26.0, 0.65, 0.4)
				family[0].hide()
				cam_ctrl.set_first_person(true, true)
				cam_ctrl.fp_yaw = -PI * 0.48
				cam_ctrl.fp_pitch = 0.01
				cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68, 0.0))
				cam_ctrl._apply_camera_transform()
			else:
				_set_interior_audio(false)
				cam_ctrl.focus_on(Vector3(0.0, 7.5, 6.0), 74.0, -0.48, preview_mode)
			# Dramatic Moment IV: Dove release hotspot placed on 3rd-deck 1-cubit window (and clickable via [E]!)
			_add_hotspot("release_dove", ap + Vector3(6.0, 7.15, 2.2), "于三层一肘透光窗放飞白鸽探看水退", "Bless")

		"noah_07_exit_altar", "noah_08_rainbow_covenant":
			world.apply_mood("ararat")
			_stop_ambience()
			_set_interior_audio(false)
			if id == "noah_08_rainbow_covenant":
				_sfx("sfx_covenant_chime.wav", -5.0, 0.0)
			flood_target = -15.0
			if preview_mode:
				flood_level = -15.0
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = world.ark_base_y
			_stage_ararat_worship()
			cam_ctrl.pitch_override = -0.10 if id == "noah_08_rainbow_covenant" else -0.20
			cam_ctrl.focus_on(Vector3(-1.0, 9.0, 6.0), 64.0, -0.24, preview_mode)
			if id == "noah_07_exit_altar":
				_add_hotspot("offer_altar", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "一家八口筑坛献祭感恩", "Bless")
			else:
				_add_hotspot("to_overworld", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "仰望彩虹永约 · 前往宏观画卷", "Bless")

	_sync_hotspot_labels()
	_refresh_hud()


func _set_actor_props(actor: Node3D, show_log: bool, show_tool: bool, show_shield: bool = false) -> void:
	var lg: Node3D = actor.find_child("CarriedLog", false, false) as Node3D
	if lg != null:
		lg.visible = show_log
	var tl: Node3D = actor.find_child("RightHandTool", true, false) as Node3D
	if tl != null:
		tl.visible = show_tool
	var sh: Node3D = actor.find_child("LeftHandShield", true, false) as Node3D
	if sh != null:
		sh.visible = show_shield


func _stage_ararat_worship() -> void:
	var slots: Array[Vector2] = [
		Vector2(0.5, 21.0), Vector2(3.6, 22.4), Vector2(-2.6, 22.4), Vector2(-1.4, 21.2),
		Vector2(2.4, 21.2), Vector2(-1.6, 24.8), Vector2(2.6, 24.8), Vector2(4.2, 23.8),
	]
	for i in range(family.size()):
		family[i].show()
		_set_actor_props(family[i], false, false, false)
		family[i].position = world.grounded(slots[i].x, slots[i].y)
		var target: Vector3 = world.altar_group.position if i != 0 else (family[i].position + Vector3(0.0, 0.0, 6.0))
		target.y = family[i].position.y
		family[i].look_at(target, Vector3.UP)
		_anim(family[i], "Bless" if i == 0 else ("Pray" if i in [5, 6] else "Idle"))


func _weather_label_for_days(days: float) -> String:
	if lang == "en_US":
		if days > 160.0: return "Clear Sun"
		if days > 90.0: return "Rising Wind"
		if days > 25.0: return "Thunderheads"
		return "Storm Squall"
	if days > 160.0: return "晴空暖阳"
	if days > 90.0: return "高云起风"
	if days > 25.0: return "积云闷雷"
	return "狂风暴雨"


func _refresh_hud() -> void:
	if ui == null:
		return
	var id: String = str(current_event.get("id", ""))
	var hide_top: bool = bool(current_event.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"] or divine_seal_active
	ui.badges_box.visible = (not hide_top) and (id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"])
	ui.sundial_panel.visible = not hide_top
	ui.tactical_btn.visible = id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]

	# Update 4 Resource & Harmony Badges
	var h_mul: float = _harmony_mul()
	(ui.badge_labels["timber"] as Label).text = ("Timber %d" if lang == "en_US" else "歌斐木 %d") % int(timber_f) + (" [起火!]" if timber_fire_intensity > 0.02 else "")
	(ui.badge_labels["pitch"] as Label).text = ("Pitch %d" if lang == "en_US" else "松香 %d") % int(pitch_f)
	(ui.badge_labels["provisions"] as Label).text = ("Food %d" if lang == "en_US" else "粮草 %d") % int(provisions_f)
	(ui.badge_labels["harmony"] as Label).text = ("Faith %d%% (x%.2f)" if lang == "en_US" else "家族信心 %d%% (x%.2f)") % [int(roundf(harmony_f)), h_mul]

	var t_panel: PanelContainer = ui.badge_panels["timber"] as PanelContainer
	var low_timber: bool = timber_f < 12.0 or timber_fire_intensity > 0.02
	t_panel.modulate = Color(1.0, 0.58, 0.52) if low_timber else Color.WHITE

	# Update Top-Center Bronze Sundial & 300-Cubit Ark Gauge
	ui.sundial_gauge.days_left = flood_countdown
	ui.sundial_gauge.max_days = max_flood_days
	ui.sundial_gauge.ark_pct = ark_build_pct
	ui.sundial_gauge.pulse_t = elapsed
	ui.sundial_gauge.queue_redraw()

	if first_person_interior:
		ui.sundial_title_lbl.text = "第一人称提灯巡舱 · 第 %d 层" % (noah_deck + 1)
		ui.sundial_sub_lbl.text = "WASD 行走 · 鼠标直转环视 · Alt 唤出光标 · [F] 退出"
	elif id == "noah_05_board_ark":
		var fam_in: int = 0
		for b in family_boarded:
			if b: fam_in += 1
		var ani_in: int = 0
		for b in animal_boarded:
			if b: ani_in += 1
		ui.sundial_title_lbl.text = "距洪水 0 天 · 倾盆大雨登舟"
		ui.sundial_sub_lbl.text = "八口登舟 %d/%d  ·  众活物入舱 %d/%d" % [fam_in, family.size(), ani_in, animals.size()]
	elif id == "noah_06_flood_dove":
		ui.sundial_title_lbl.text = "浩大洪水漂流 · 亚拉腊众山（创 8:4）"
		ui.sundial_sub_lbl.text = "按 [F] 提陶油灯巡视三层船舱 · 登三层透光窗按 [E] 放飞白鸽"
	else:
		var w_txt: String = _weather_label_for_days(flood_countdown)
		ui.sundial_title_lbl.text = ("%s · %d Days Left" if lang == "en_US" else "%s · 距洪水 %d 天") % [w_txt, int(maxf(flood_countdown, 0.0))]
		var step30: int = _compute_ark_step_idx()
		var sub: String = "三百肘工程 %d%%（%d/30 段构件）" % [int(roundf(ark_build_pct)), step30]
		if not strategy_alert.is_empty():
			sub = strategy_alert
		ui.sundial_sub_lbl.text = sub

	# Pure Cinematic Subtitle (ZERO dev-note parentheses!)
	var spk: String = str(current_event.get("speakerEn" if lang == "en_US" else "speakerZh", ""))
	var body: String = str(current_event.get("bodyEn" if lang == "en_US" else "bodyZh", ""))
	ui.subtitle_label.text = "【%s · %s】%s" % [spk, str(current_event.get("canonRef", "")), body]


func _trigger_active_hotspot() -> void:
	if ui.is_blocking_modal_open():
		return
	if not active_hotspot.is_empty():
		_trigger_hotspot(active_hotspot)
	elif hotspots.size() == 1 and not bool(hotspots[0].done):
		_trigger_hotspot(hotspots[0])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and not event.is_echo():
		ui.toggle_pause_menu()
		return
	if event.is_action_pressed("open_codex") and not event.is_echo():
		ui.toggle_codex()
		return
	if ui.is_blocking_modal_open():
		return
	if event.is_action_pressed("toggle_first_person") and not event.is_echo():
		_toggle_first_person()
	elif event.is_action_pressed("toggle_tactical_map") and not event.is_echo():
		_toggle_tactical_sandbox()
	elif event.is_action_pressed("toggle_cutaway") and not event.is_echo():
		_toggle_cutaway()
	elif event.is_action_pressed("interact") and not event.is_echo():
		_trigger_active_hotspot()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if first_person_interior or tactical_sandbox_mode:
			return
		var mb: InputEventMouseButton = event
		var orig: Vector3 = cam_ctrl.camera.project_ray_origin(mb.position)
		var dir: Vector3 = cam_ctrl.camera.project_ray_normal(mb.position)
		for h in hotspots:
			if bool(h.done):
				continue
			var hp: Vector3 = h.pos
			var t: float = (hp - orig).dot(dir)
			if t > 0.0:
				var closest: Vector3 = orig + dir * t
				if closest.distance_to(hp + Vector3(0.0, 0.8, 0.0)) < 1.8:
					if family[0].visible and family[0].position.distance_to(hp) > 3.2:
						noah_click_target = hp
						noah_has_click_target = true
					else:
						_trigger_hotspot(h)
					return
		if family[0].visible:
			var hit: Variant = Plane(Vector3.UP, family[0].position.y).intersects_ray(orig, dir)
			if hit != null:
				noah_click_target = hit
				noah_has_click_target = true


func _start_fence_work() -> void:
	var id: String = str(current_event.get("id", ""))
	if id != "noah_03_hull_decks" or crisis_resolved:
		return
	if fence_building:
		strategy_alert = "正在逐段修筑木栅（%d%%）！" % int(roundf(fence_build_pct))
		_refresh_hud()
		return
	if fence_build_pct >= 100.0 and fence_hp >= fence_max_hp - 10.0:
		strategy_alert = "木栅防线完好！请派盾卫守住南坡！"
		_refresh_hud()
		return
	var cost: float = float(sim_cfg.get("fenceBuildCost", 40.0)) if fence_build_pct < 100.0 else float(sim_cfg.get("fenceRepairCost", 20.0))
	if timber_f < cost:
		strategy_alert = "歌斐木不足 %d，请增派东坡伐木！" % int(cost)
		_sfx("sfx_alert.wav", -5.0)
		_refresh_hud()
		return
	timber_f -= cost
	fence_building = true
	_sfx("sfx_hammer.wav", -4.0)
	strategy_alert = "已下令修筑木栅防线！"
	_refresh_hud()


func _douse_timber_fire() -> void:
	if timber_fire_intensity <= 0.01:
		return
	var douse_pct: float = float(sim_cfg.get("waterDousePct", 50.0)) / 100.0
	timber_fire_intensity = maxf(0.0, timber_fire_intensity - douse_pct - 0.05)
	world.set_timber_fire_intensity(timber_fire_intensity)
	world.spawn_hit_particles(world.grounded(-15.5, 16.0, 1.4), false)
	world.spawn_floating_text_3d(world.grounded(-15.5, 16.0, 2.2), "山泉灭火!" if timber_fire_intensity <= 0.02 else "火势 -50%", Color(0.42, 0.88, 1.0))
	_sfx("sfx_ui_click.wav", -3.0)
	if timber_fire_intensity <= 0.02:
		timber_fire_intensity = 0.0
		world.set_timber_fire_intensity(0.0)
		strategy_alert = "木料堆火情已彻底扑灭！"
		for h in hotspots:
			if str(h.id) == "douse_fire":
				h.done = true
				var hn: Node3D = h.get("node") as Node3D
				if hn != null and is_instance_valid(hn):
					hn.hide()
	_refresh_hud()


func _trigger_hotspot(h: Dictionary) -> void:
	if bool(h.done):
		return
	var hid: String = str(h.id)
	if hid == "douse_fire":
		_douse_timber_fire()
		return
	if hid == "defend_yard" and not crisis_resolved:
		if fence_hp <= 0.0 and not fence_building and timber_f >= float(sim_cfg.get("fenceBuildCost", 40.0)):
			_start_fence_work()
		if rally_cooldown <= 0.0:
			rally_cooldown = 5.0
			noah_busy_timer = 1.2
			noah_busy_clip = "Brawl"
			_sfx("sfx_hammer.wav", -3.0)
			cam_ctrl.add_trauma(0.14)
			for i in range(raider_morale.size()):
				if raider_morale[i] > 0.0:
					raider_morale[i] = maxf(0.0, raider_morale[i] - 24.0)
			if fence_hp > 0.0:
				fence_hp = minf(fence_max_hp, fence_hp + 30.0)
			world.spawn_floating_text_3d(family[0].position + Vector3(0, 2.2, 0), "义人止戈 · 强人胆寒!", Color(1.0, 0.88, 0.44))
			strategy_alert = "挪亚高举木盾喝止强暴，来犯者士气大挫！"
		_refresh_hud()
		return
	if hid == "seal_door":
		# Fast-forward remaining boarding cleanly into the 5s Divine Seal moment!
		for i in range(family.size()):
			if i < family_boarded.size() and not family_boarded[i]:
				family_boarded[i] = true
				_place_family_inside_ark(i)
		for i in range(animals.size()):
			if i < animal_boarded.size() and not animal_boarded[i]:
				animal_boarded[i] = true
				_place_animal_inside_ark(i)
		h.done = true
		var sn: Node3D = h.get("node") as Node3D
		if sn != null and is_instance_valid(sn):
			sn.hide()
		_begin_divine_seal_sequence()
		return
	if hid == "release_dove" and not dove_flight_active:
		h.done = true
		var dn: Node3D = h.get("node") as Node3D
		if dn != null and is_instance_valid(dn):
			dn.hide()
		dove_flight_active = true
		dove_flight_t = 0.0
		_sfx("sfx_covenant_chime.wav", -4.0)
		world.spawn_floating_text_3d(world.ark_anchor.to_global(Vector3(6.0, 8.8, 2.4)), "放飞白鸽 · 衔回新拧橄榄叶!", Color(0.75, 1.0, 0.68))
		var tw: Tween = create_tween()
		tw.tween_interval(2.4)
		tw.tween_callback(func() -> void: _check_act_complete())
		return

	h.done = true
	var n: Node3D = h.get("node") as Node3D
	if n != null and is_instance_valid(n):
		n.hide()
	noah_busy_timer = 1.1
	noah_busy_clip = str(h.get("clip", "Hammer"))
	_sfx("sfx_hammer.wav" if noah_busy_clip == "Hammer" else "sfx_ui_click.wav", -4.0)
	if noah_busy_clip == "Hammer":
		cam_ctrl.add_trauma(0.15)
		world.spawn_hit_particles(h.pos + Vector3(0, 0.8, 0), false)
	inspection_boost_timer = float(sim_cfg.get("inspectionBoostSec", 22.0))
	if family[0].visible:
		_anim(family[0], noah_busy_clip)
	_refresh_hud()
	_check_act_complete()


func _begin_divine_seal_sequence() -> void:
	if divine_seal_active:
		return
	divine_seal_active = true
	divine_seal_timer = float(sim_cfg.get("divineSealSilenceSec", 5.0))
	animal_root.hide()
	# Heavy side door & ramp seal themselves without player input (Genesis 7:16)
	world.set_ark_progress(100.0, false, true, false)
	_set_interior_audio(true)
	cam_ctrl.add_trauma(0.24)
	_sfx("sfx_covenant_chime.wav", -3.0, 0.0)
	var dm3: Dictionary = chapter.get("dramaticMoments", {}).get("dm_03_divine_seal", {})
	var t_txt: String = str(dm3.get("titleEn" if lang == "en_US" else "titleZh", "耶和华就把他关在方舟里头"))
	var v_txt: String = str(dm3.get("verseEn" if lang == "en_US" else "verseZh", ""))
	ui.show_divine_seal(t_txt, v_txt)
	_refresh_hud()


func _trigger_dramatic_moment(dm_key: String) -> void:
	var dms: Dictionary = chapter.get("dramaticMoments", {})
	if not dms.has(dm_key):
		return
	var dm: Dictionary = dms[dm_key]
	var opts: Array = []
	for ch in dm.get("choices", []):
		var cdict: Dictionary = ch
		var cb_dm: Callable = func() -> void:
			harmony_f = clampf(harmony_f + float(cdict.get("deltaHarmony", 0.0)), 40.0, 100.0)
			timber_f += float(cdict.get("deltaTimber", 0.0))
			if float(cdict.get("bonusFenceHp", 0.0)) > 0.0:
				fence_build_pct = maxf(fence_build_pct, 50.0)
				fence_hp = minf(fence_max_hp, fence_hp + float(cdict.get("bonusFenceHp", 0.0)))
				world.set_fence_progress(fence_build_pct)
			var mdrop: float = float(cdict.get("moraleDrop", 0.0))
			if mdrop > 0.0:
				for ri in range(raider_morale.size()):
					raider_morale[ri] = maxf(0.0, raider_morale[ri] - mdrop)
			strategy_alert = str(cdict.get("toastZh", ""))
			_sfx("sfx_covenant_chime.wav", -5.0)
			_refresh_hud()
		opts.append({
			"label": str(cdict.get("labelZh", "继续")),
			"callback": cb_dm,
		})
	ui.open_choice_modal(
		str(dm.get("titleEn" if lang == "en_US" else "titleZh", "")),
		str(dm.get("canonRef", "")),
		str(dm.get("bodyZh", "")),
		opts
	)


func _open_flood_fail_modal() -> void:
	if flood_failed:
		return
	flood_failed = true
	world.rain.emitting = true
	_sfx("sfx_thunder.wav", -3.0)
	var cb_board_now: Callable = func() -> void:
		ark_build_pct = 100.0
		flood_failed = false
		_enter_event("noah_05_board_ark", false)
	var cb_retry_act: Callable = func() -> void:
		flood_countdown = max_flood_days
		flood_failed = false
		timber_f = maxf(timber_f, 55.0)
		world.rain.emitting = false
		_enter_event(str(current_event.get("id", "noah_02_keel_mortise")), false)
	ui.open_choice_modal(
		"距洪水 0 天 · 倾盆大雨已至",
		"创世记 7:10–11",
		"倒计时已归零，暴雨倾盆！当前工程 %d%%，松香 %d，粮草 %d。可立即紧急封顶引导全员与活物登舟，或重整分工重新建造本幕：" % [
			int(roundf(ark_build_pct)), int(pitch_f), int(provisions_f)
		],
		[
			{"label": "紧急完工封顶 · 全员与众活物立即登舟", "callback": cb_board_now},
			{"label": "重整家族分工 · 重新备料建造本幕", "callback": cb_retry_act},
		]
	)


func _check_act_complete() -> void:
	for h in hotspots:
		if str(h.id) == "douse_fire":
			continue
		if not bool(h.done):
			return
	var id: String = str(current_event.get("id", ""))
	var keel_ms: float = float(sim_cfg.get("keelMilestonePct", 35.0))
	var hull_ms: float = float(sim_cfg.get("hullMilestonePct", 75.0))
	var comp_ms: float = float(sim_cfg.get("completeMilestonePct", 98.0))
	if id == "noah_02_keel_mortise" and ark_build_pct < keel_ms:
		strategy_alert = "龙骨里程碑需达 %d%%（当前 %d%%），请继续采木凿榫！" % [int(keel_ms), int(ark_build_pct)]
		_refresh_hud()
		return
	if id == "noah_03_hull_decks":
		if not crisis_resolved or timber_fire_intensity > 0.02:
			strategy_alert = "请先惊退来犯强人并扑灭料堆火情！"
			_refresh_hud()
			return
		if ark_build_pct < hull_ms:
			strategy_alert = "三层船壳需达 %d%%（当前 %d%%），请继续钉合船板！" % [int(hull_ms), int(ark_build_pct)]
			_refresh_hud()
			return
	if id == "noah_04_pitch_provisions":
		var p_req: float = float(sim_cfg.get("pitchMilestone", 25.0))
		var f_req: float = float(sim_cfg.get("provisionsMilestone", 80.0))
		if ark_build_pct < comp_ms or pitch_f < p_req or provisions_f < f_req:
			strategy_alert = "封顶门槛：工程≥%d%% · 松香≥%d · 粮草≥%d" % [int(comp_ms), int(p_req), int(f_req)]
			_refresh_hud()
			return
	# Seamless ZERO-TELEPORT transitions between build acts (noah_02 -> noah_03 -> noah_04)!
	match id:
		"noah_01_revelation": _enter_event("noah_02_keel_mortise", false)
		"noah_02_keel_mortise": _enter_event("noah_03_hull_decks", true)
		"noah_03_hull_decks": _enter_event("noah_04_pitch_provisions", true)
		"noah_04_pitch_provisions": _enter_event("noah_05_board_ark", false)
		"noah_05_board_ark": _begin_divine_seal_sequence()
		"noah_06_flood_dove": _enter_event("noah_07_exit_altar", false)
		"noah_07_exit_altar": _enter_event("noah_08_rainbow_covenant", false)
		"noah_08_rainbow_covenant":
			_auto_save_completion()
			var st: Node = get_node_or_null("/root/SceneTransition")
			if st != null and st.has_method("change_scene"):
				st.call("change_scene", "res://scenes/overworld_prologue.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/overworld_prologue.tscn")


func _auto_save_completion() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_slot"):
		sm.call("save_slot", 1, {
			"chapter_id": "overworld_prologue",
			"completed_ch00": true,
			"harmony": int(roundf(harmony_f)),
		})


func _on_save_slot(slot: int) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_slot"):
		var ok: bool = bool(sm.call("save_slot", slot, {
			"chapter_id": "ch00_noah_ark",
			"event_id": str(current_event.get("id", "noah_02_keel_mortise")),
			"flood_countdown": flood_countdown,
			"ark_build_pct": ark_build_pct,
			"timber": timber_f,
			"pitch": pitch_f,
			"provisions": provisions_f,
			"harmony": harmony_f,
			"w_log": w_log,
			"w_build": w_build,
			"w_pitch": w_pitch,
			"w_guard": w_guard,
			"lang": lang,
		}))
		ui.save_status_lbl.text = ("已原子保存至槽位 %d！" % slot) if ok else "保存失败"


func _on_load_slot(slot: int) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("load_slot"):
		return
	var data: Dictionary = sm.call("load_slot", slot)
	if data.is_empty():
		ui.save_status_lbl.text = "槽位 %d 尚无存档" % slot
		return
	var ev_id: String = str(data.get("event_id", "noah_02_keel_mortise"))
	flood_countdown = float(data.get("flood_countdown", max_flood_days))
	ark_build_pct = float(data.get("ark_build_pct", 10.0))
	timber_f = float(data.get("timber", 45.0))
	pitch_f = float(data.get("pitch", 15.0))
	provisions_f = float(data.get("provisions", 60.0))
	harmony_f = float(data.get("harmony", 84.0))
	w_log = int(data.get("w_log", 2))
	w_build = int(data.get("w_build", 3))
	w_pitch = int(data.get("w_pitch", 1))
	w_guard = int(data.get("w_guard", 1))
	ui.pause_overlay.hide()
	_enter_event(ev_id, false)
	ui.save_status_lbl.text = "已读取槽位 %d" % slot


func _on_lang_changed(new_lang: String) -> void:
	lang = new_lang
	_refresh_hud()


func _on_return_main_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var st: Node = get_node_or_null("/root/SceneTransition")
	if st != null and st.has_method("change_scene"):
		st.call("change_scene", "res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _surface_height_for_noah(x: float, z: float) -> float:
	var ap: Vector3 = world.ark_anchor.position
	var step_idx: int = _compute_ark_step_idx()
	if step_idx >= 12 and absf(x - ap.x) < 49.5 and z > ap.z - 8.0 and z < ap.z + 8.0:
		var rel_x: float = x - ap.x
		var rel_z: float = z - ap.z
		var on_north_stair_aisle: bool = (rel_z <= -1.15 and rel_z >= -3.15)
		if on_north_stair_aisle and rel_x >= 2.5 and rel_x <= 13.5 and noah_deck <= 1:
			var s1: float = clampf((rel_x - 2.5) / 11.0, 0.0, 1.0)
			if s1 < 0.25: noah_deck = 0
			elif s1 > 0.75: noah_deck = 1
			return lerpf(ap.y + 0.65, ap.y + 3.95, s1)
		if on_north_stair_aisle and rel_x >= 18.5 and rel_x <= 29.5 and noah_deck >= 1:
			var s2: float = clampf((rel_x - 18.5) / 11.0, 0.0, 1.0)
			if s2 < 0.25: noah_deck = 1
			elif s2 > 0.75: noah_deck = 2
			return lerpf(ap.y + 3.95, ap.y + 7.15, s2)
		if noah_deck == 2: return ap.y + 7.15
		if noah_deck == 1: return ap.y + 3.95
		return ap.y + 0.65
	if step_idx >= 12 and absf(x - ap.x) < 2.8 and z >= ap.z + 8.0 and z <= ap.z + 19.8:
		noah_deck = 0
		var t: float = clampf((z - (ap.z + 8.0)) / 11.5, 0.0, 1.0)
		return lerpf(ap.y + 0.65, world.terrain_height(x, z), t)
	noah_deck = 0
	return world.terrain_height(x, z)


func _update_bar_visual(fill: MeshInstance3D, ratio: float, col_high: Color, col_low: Color) -> void:
	if fill == null or not is_instance_valid(fill):
		return
	var r: float = clampf(ratio, 0.0, 1.0)
	fill.scale.x = maxf(0.02, r)
	var mat: StandardMaterial3D = fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = col_low.lerp(col_high, r)


func _update_raider_conflict(delta: float) -> void:
	if rally_cooldown > 0.0:
		rally_cooldown -= delta
	if raider_clash_sfx_timer > 0.0:
		raider_clash_sfx_timer -= delta
	var noah: Node3D = family[0]
	var noah_near_fence: bool = noah.visible and noah.position.z > 15.0 and noah.position.z < 28.0 and absf(noah.position.x + 11.0) < 18.0

	# 1. Progressive Palisade Construction
	if fence_building:
		var builders: int = maxi(1, w_guard + mini(w_build, 2))
		var build_rate: float = (5.5 + float(builders) * 3.4 + (4.5 if noah_near_fence else 0.0)) * _harmony_mul()
		if fence_build_pct < 100.0:
			fence_build_pct = minf(100.0, fence_build_pct + build_rate * delta)
			fence_hp = minf(fence_max_hp, fence_hp + build_rate * 3.0 * delta)
			world.set_fence_progress(fence_build_pct)
			if fence_build_pct >= 100.0:
				fence_building = false
				state.guardFence = true
				fence_hp = fence_max_hp
				_sfx("sfx_covenant_chime.wav", -5.0)
		else:
			fence_hp = minf(fence_max_hp, fence_hp + (build_rate * 4.2) * delta)
			world.set_fence_progress(maxf(20.0, fence_hp / fence_max_hp * 100.0))
			if fence_hp >= fence_max_hp:
				fence_building = false

	if fence_status_root != null:
		fence_status_root.visible = not first_person_interior and not crisis_resolved
		if fence_building and fence_build_pct < 100.0:
			fence_status_label.text = "正在修筑木栅 %d%%" % int(roundf(fence_build_pct))
			_update_bar_visual(fence_hp_bar, fence_build_pct / 100.0, Color(0.95, 0.76, 0.24), Color(0.95, 0.50, 0.16))
		elif fence_hp > 0.0:
			fence_status_label.text = "木栅耐久 %d/%d" % [int(roundf(fence_hp)), int(fence_max_hp)]
			_update_bar_visual(fence_hp_bar, fence_hp / fence_max_hp, Color(0.28, 0.86, 0.42), Color(0.92, 0.24, 0.18))
		else:
			fence_status_label.text = "南坡无木栅（按 Space 沙盘或靠近筑栅）"
			_update_bar_visual(fence_hp_bar, 0.02, Color(0.92, 0.24, 0.18), Color(0.92, 0.24, 0.18))

	# 2. Dramatic Moment II Trigger: Noah Stays Ham's Bronze Blade!
	if not preview_mode and not dm02_triggered and raiders.size() > 0 and raiders[0].position.z < 33.5:
		dm02_triggered = true
		_trigger_dramatic_moment("dm_02_stay_the_blade")
		return

	# 3. Two-Prong Raider Advance + Torch Fire Crisis (GF-04)
	var active_raiders: int = 0
	var engaged_raiders: int = 0
	for i in range(raiders.size()):
		var r: Node3D = raiders[i]
		var morale: float = raider_morale[i]
		var is_flanker: bool = (i >= 3)
		var rx_slot: float = (-20.0 + float(i) * 4.2) if not is_flanker else (-12.5 + float(i - 3) * 2.4)
		if morale <= 0.0:
			var flee_pt: Vector3 = world.grounded(rx_slot * 0.6 if not is_flanker else 18.0, 56.0)
			if r.position.distance_to(flee_pt) > 0.6:
				r.position = r.position.move_toward(flee_pt, delta * 5.2)
				r.look_at(flee_pt, Vector3.UP)
				_anim(r, "Run")
			else:
				_anim(r, "Idle")
			raider_labels[i].text = "士气溃散 · 退走!"
			_update_bar_visual(raider_bars[i], 0.0, Color(0.8, 0.2, 0.2), Color(0.5, 0.5, 0.5))
			continue

		active_raiders += 1
		var target_z: float = (23.7 if fence_hp > 0.0 else 16.4) if not is_flanker else (22.0 if (fence_hp > 0.0 and w_guard >= 2) else 16.6)
		var tg: Vector3 = world.grounded(rx_slot, target_z)
		if r.position.distance_to(tg) > 0.65:
			r.position = r.position.move_toward(tg, delta * 3.5)
			r.look_at(tg, Vector3.UP)
			_anim(r, "Run")
		else:
			engaged_raiders += 1
			r.look_at(world.grounded(rx_slot, 12.0), Vector3.UP)
			_anim(r, "Slash" if i % 2 == 0 else "Brawl")
			if fence_hp > 0.0 and (not is_flanker or w_guard >= 2):
				var dmg_mul: float = 0.65 if noah_near_fence else 1.0
				fence_hp = maxf(0.0, fence_hp - 2.6 * dmg_mul * delta)
				if not fence_building:
					world.set_fence_progress(maxf(0.0, fence_hp / fence_max_hp * 100.0))
				# Ignite timber stack if fence falls below 40%!
				if not fire_triggered_once and fence_hp < fence_max_hp * float(sim_cfg.get("fireIgniteFenceThreshold", 0.40)):
					_ignite_timber_stack()
			else:
				if not fire_triggered_once:
					_ignite_timber_stack()
				timber_f = maxf(0.0, timber_f - 1.4 * delta)

			var guard_dps: float = (float(w_guard) * 5.2 + (11.5 if noah_near_fence else 0.0)) * _harmony_mul()
			if fence_hp > 0.0 and w_guard > 0:
				guard_dps *= 1.35
			if guard_dps > 0.0:
				raider_morale[i] = maxf(0.0, raider_morale[i] - (guard_dps / float(maxi(1, engaged_raiders))) * delta)

		var tag_p: String = "侧翼纵火" if is_flanker else "强人士气"
		raider_labels[i].text = "%s %d%%" % [tag_p, int(roundf(raider_morale[i]))]
		_update_bar_visual(raider_bars[i], raider_morale[i] / 100.0, Color(0.95, 0.30, 0.18), Color(0.96, 0.72, 0.22))

	# Hit-sparks & Palisade elastic bounce on clash beat (GF-03)
	if engaged_raiders > 0 and raider_clash_sfx_timer <= 0.0 and not preview_mode:
		raider_clash_sfx_timer = 1.25
		_sfx("sfx_hammer.wav", -8.0)
		world.spawn_hit_particles(world.grounded(-14.0, 22.5, 1.2), true)
		if fence_hp > 0.0:
			world.pulse_fence_hit(-14.0)
		if noah_near_fence:
			cam_ctrl.add_trauma(0.10)

	# Burn timber while on fire + allow pitch/water workers to auto-assist dousing!
	if timber_fire_intensity > 0.02:
		var burn_rate: float = float(sim_cfg.get("fireBurnRatePerSec", 3.5))
		timber_f = maxf(0.0, timber_f - burn_rate * timber_fire_intensity * delta)
		if w_pitch > 0:
			auto_douse_timer += delta * float(w_pitch)
			if auto_douse_timer >= 8.5:
				auto_douse_timer = 0.0
				_douse_timber_fire()

	if active_raiders == 0 and not crisis_resolved:
		crisis_resolved = true
		_sfx("sfx_covenant_chime.wav", -4.0)
		strategy_alert = "来犯强人尽皆胆寒退去，全无流血伤亡！"
		for h in hotspots:
			if str(h.id) == "defend_yard" and not bool(h.done):
				h.done = true
				var hn: Node3D = h.get("node") as Node3D
				if hn != null and is_instance_valid(hn):
					hn.hide()
		_check_act_complete()


func _ignite_timber_stack() -> void:
	fire_triggered_once = true
	timber_fire_intensity = 1.0
	world.set_timber_fire_intensity(1.0)
	world.spawn_hit_particles(world.grounded(-15.5, 16.0, 1.3), true)
	world.spawn_floating_text_3d(world.grounded(-15.5, 16.0, 2.4), "火把引燃木料堆! 快赴山泉提水!", Color(1.0, 0.44, 0.20))
	_sfx("sfx_alert.wav", -3.0)
	strategy_alert = "警报：侧翼火把引燃歌斐木堆！快赴山泉按 [E] 提水灭火！"
	_ensure_fire_douse_hotspot()


func _process(delta: float) -> void:
	_update_hitstops(delta)
	var sim_scale: float = float(sim_cfg.get("tacticalTimeScale", 0.35)) if tactical_sandbox_mode else 1.0
	var sim_dt: float = 0.0 if (ui != null and (ui.modal_overlay.visible or ui.pause_overlay.visible)) else (delta * sim_scale)
	elapsed += sim_dt

	if divine_seal_active and not preview_mode:
		divine_seal_timer -= delta
		if divine_seal_timer <= 0.0:
			divine_seal_active = false
			ui.hide_divine_seal()
			_enter_event("noah_06_flood_dove", false)
		return

	if fp_exit_cooldown > 0.0:
		fp_exit_cooldown -= delta
	var id: String = str(current_event.get("id", ""))
	var noah: Node3D = family[0]

	# Update Named Family 3D Nameplates visibility (visible when Noah within 15m or in Tactical Sandbox Mode!)
	for i in range(family.size()):
		var npl: Label3D = family_nameplates[i]
		if npl != null:
			if i == 0:
				npl.visible = tactical_sandbox_mode
			else:
				npl.visible = tactical_sandbox_mode or (not first_person_interior and family[i].position.distance_to(noah.position) < 16.0) or (first_person_interior and family[i].global_position.distance_to(cam_ctrl.fp_eye_pos) < 11.0)

	# 1. First-Person Oil-Lamp Walk (CS2 Captured Mouse)
	if not ui.is_blocking_modal_open() and first_person_interior and id != "noah_01_revelation":
		var move_dir: Vector3 = Vector3.ZERO
		var yaw: float = cam_ctrl.fp_yaw
		var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
		var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
		if Input.is_action_pressed("move_forward"): move_dir += fwd
		if Input.is_action_pressed("move_back"): move_dir -= fwd
		if Input.is_action_pressed("move_left"): move_dir -= right
		if Input.is_action_pressed("move_right"): move_dir += right
		if move_dir.length_squared() > 0.01:
			move_dir = move_dir.normalized()
			var fp_spd: float = 6.4 if Input.is_key_pressed(KEY_SHIFT) else 4.0
			var lp: Vector3 = noah_fp_local + move_dir * fp_spd * delta
			lp.x = clampf(lp.x, -46.5, 46.5)
			var can_exit_door: bool = (id != "noah_06_flood_dove" and noah_deck == 0 and absf(lp.x) < 2.6)
			lp.z = clampf(lp.z, -3.0, 9.2 if can_exit_door else 3.0)
			var on_stair: bool = (lp.z <= -1.15 and lp.z >= -3.15)
			if on_stair and lp.x >= 2.5 and lp.x <= 13.5 and noah_deck <= 1:
				var s1: float = clampf((lp.x - 2.5) / 11.0, 0.0, 1.0)
				if s1 < 0.25: noah_deck = 0
				elif s1 > 0.75: noah_deck = 1
				lp.y = lerpf(0.65, 3.95, s1)
			elif on_stair and lp.x >= 18.5 and lp.x <= 29.5 and noah_deck >= 1:
				var s2: float = clampf((lp.x - 18.5) / 11.0, 0.0, 1.0)
				if s2 < 0.25: noah_deck = 1
				elif s2 > 0.75: noah_deck = 2
				lp.y = lerpf(3.95, 7.15, s2)
			elif noah_deck == 2: lp.y = 7.15
			elif noah_deck == 1: lp.y = 3.95
			else: lp.y = 0.65
			noah_fp_local = lp
			if can_exit_door and lp.z > 8.6:
				_toggle_first_person()
		noah.global_position = world.ark_anchor.to_global(noah_fp_local)
		var moving_fp: bool = move_dir.length_squared() > 0.01
		cam_ctrl.fp_move_intensity = lerpf(cam_ctrl.fp_move_intensity, 1.0 if moving_fp else 0.0, delta * 8.0)
		var bob_y: float = (sin(elapsed * 6.0) * 0.03) if (moving_fp and cam_ctrl.fp_head_bob_enabled) else 0.0
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68 + bob_y, 0.0))

	# 1b. Third-Person Patriarch Control (Modal A)
	elif not ui.is_blocking_modal_open() and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		if noah.visible and not tactical_sandbox_mode:
			var move_dir: Vector3 = Vector3.ZERO
			var yaw: float = cam_ctrl.current_yaw
			var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
			var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
			if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_UP): move_dir += fwd
			if Input.is_action_pressed("move_back") or Input.is_key_pressed(KEY_DOWN): move_dir -= fwd
			if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT): move_dir -= right
			if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT): move_dir += right
			var rain_mul: float = float(sim_cfg.get("rainMudSpeedMul", 0.85)) if flood_countdown < 25.0 else 1.0
			if move_dir.length_squared() > 0.01:
				noah_has_click_target = false
				noah_busy_timer = 0.0
				move_dir = move_dir.normalized()
				var spd: float = (7.2 if Input.is_key_pressed(KEY_SHIFT) else 4.2) * rain_mul
				var np: Vector3 = noah.position + move_dir * spd * delta
				np.x = clampf(np.x, -56.0, 72.0)
				np.z = clampf(np.z, -16.0, 56.0)
				np.y = _surface_height_for_noah(np.x, np.z)
				noah.position = np
				noah.look_at(noah.position + move_dir, Vector3.UP)
				_anim(noah, "Run" if Input.is_key_pressed(KEY_SHIFT) else "Walk")
			elif noah_has_click_target:
				var flat_d: Vector3 = Vector3(noah_click_target.x - noah.position.x, 0.0, noah_click_target.z - noah.position.z)
				if flat_d.length() < 0.55:
					noah_has_click_target = false
				else:
					var dir: Vector3 = flat_d.normalized()
					var np: Vector3 = noah.position + dir * 4.4 * rain_mul * delta
					np.y = _surface_height_for_noah(np.x, np.z)
					noah.position = np
					noah.look_at(noah.position + dir, Vector3.UP)
					_anim(noah, "Walk")
			elif noah_busy_timer > 0.0:
				noah_busy_timer -= delta
				_anim(noah, noah_busy_clip)
			else:
				_anim(noah, "Idle")

			var noah_defending: bool = (id == "noah_03_hull_decks" and not crisis_resolved and noah.position.z > 16.5)
			_set_actor_props(noah, false, true, noah_defending)

			var ap: Vector3 = world.ark_anchor.position
			if fp_exit_cooldown <= 0.0 and _compute_ark_step_idx() >= 12 and absf(noah.position.x - ap.x) < 48.0 and noah.position.z < ap.z + 7.8 and noah.position.z > ap.z - 8.0 and not manual_cutaway_lock:
				_toggle_first_person()

			cam_ctrl.focus_on(noah.position + Vector3(0.0, 1.6, 0.0), -1.0, NAN, false)

	# 1c. Live Simulation: 30-Step Ark Construction, Dynamic Countdown Sky & Dramatic Moment I
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"] and sim_dt > 0.0:
		flood_countdown = maxf(0.0, flood_countdown - sim_dt)
		if id != "noah_03_hull_decks":
			world.update_countdown_weather(flood_countdown, max_flood_days, sim_dt)
		world.update_forest_regrowth(sim_dt, float(sim_cfg.get("stumpRegrowSec", 45.0)))
		if inspection_boost_timer > 0.0:
			inspection_boost_timer -= sim_dt

		var h_mul: float = _harmony_mul()
		pitch_f += float(w_pitch) * float(sim_cfg.get("pitchPerWorkerSec", 2.0)) * h_mul * sim_dt
		provisions_f += float(w_pitch) * float(sim_cfg.get("provisionsPerWorkerSec", 1.6)) * h_mul * sim_dt
		var timber_need: float = float(w_build) * float(sim_cfg.get("buildTimberPerWorkerSec", 2.4)) * sim_dt
		if timber_f >= timber_need and w_build > 0:
			timber_f -= timber_need
			var boost: float = float(sim_cfg.get("inspectionBoostMul", 1.6)) if inspection_boost_timer > 0.0 else 1.0
			ark_build_pct = minf(100.0, ark_build_pct + float(w_build) * float(sim_cfg.get("buildPctPerWorkerSec", 1.45)) * boost * h_mul * sim_dt)
		elif w_build > 0 and timber_fire_intensity <= 0.02:
			strategy_alert = "等待东坡原木入库（或按 [Space] 增派伐木人手）"

		# Update 30-Step Progressive Ark Hull EVERY +3.3% step!
		var new_step: int = _compute_ark_step_idx()
		if new_step != last_ark_step_idx:
			_apply_ark_visibility()
			var hull_x: float = lerpf(-44.0, 44.0, float(new_step) / 30.0)
			world.spawn_hit_particles(world.ark_anchor.position + Vector3(hull_x, 3.5, 8.2), false)
			if new_step in [10, 22, 30]:
				_sfx("sfx_covenant_chime.wav", -5.0)
			else:
				_sfx("sfx_hammer.wav", -7.0)
		if ark_build_pct >= 100.0 and not ark_completed_chime_played:
			ark_completed_chime_played = true
			_apply_ark_visibility()
			_sfx("sfx_covenant_chime.wav", -3.0)

		# Dramatic Moment I: Cloudless Sky Mockery at 20% Ark Build!
		if not preview_mode and id == "noah_02_keel_mortise" and not dm01_triggered and ark_build_pct >= 20.0:
			dm01_triggered = true
			_trigger_dramatic_moment("dm_01_drought_mockery")

		if flood_countdown <= 0.0 and not preview_mode:
			if ark_build_pct >= 95.0:
				ark_build_pct = 100.0
				_enter_event("noah_05_board_ark", false)
				return
			else:
				_open_flood_fail_modal()
		state.timber = int(timber_f)
		_check_act_complete()
		_refresh_hud()

	# 2. Update 3D-Projected Tactical Station Bubbles ([Space] Mode)
	var show_bubbles: bool = tactical_sandbox_mode and id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]
	var fence_btn_txt: String = "修筑木栅 (-40木)"
	if fence_building:
		fence_btn_txt = "修筑中 %d%%" % int(roundf(fence_build_pct))
	elif fence_build_pct >= 100.0 and fence_hp < fence_max_hp - 10.0:
		fence_btn_txt = "抢修木栅 (-20木)"
	elif fence_build_pct >= 100.0:
		fence_btn_txt = "木栅完好 %d" % int(fence_hp)
	ui.update_3d_bubbles(
		cam_ctrl.camera,
		show_bubbles,
		{
			"log": world.grounded(56.0, 2.0, 4.5),
			"build": world.ark_anchor.position + Vector3(-2.0, 6.2, 8.5),
			"pitch": world.grounded(13.5, 15.0, 3.2),
			"guard": world.grounded(-12.5, 22.5, 3.8),
		},
		{
			"log": "东坡伐木 %d人" % w_log,
			"build": "船坞建舟 %d人" % w_build,
			"pitch": "松香储粮 %d人" % w_pitch,
			"guard": "南坡盾卫 %d人" % w_guard,
		},
		id == "noah_03_hull_decks" and not crisis_resolved,
		fence_btn_txt,
		timber_fire_intensity > 0.02,
		world.grounded(-14.5, 16.0, 3.5)
	)

	# 3. Check 3D Hotspot Proximity
	active_hotspot = {}
	for h in hotspots:
		if bool(h.done):
			continue
		var ring: MeshInstance3D = h.get("ring") as MeshInstance3D
		if ring != null:
			var s: float = 1.0 + sin(elapsed * 3.5) * 0.09
			ring.scale = Vector3(s, 1.0, s)
		var check_pos: Vector3 = noah.global_position
		if (noah.visible or first_person_interior) and check_pos.distance_to(h.pos) < 5.2:
			active_hotspot = h
	if not active_hotspot.is_empty():
		ui.interact_prompt.show()
		ui.interact_prompt.text = "[E] %s" % str(active_hotspot.label)
	elif hotspots.size() == 1 and not bool(hotspots[0].done) and id in ["noah_01_revelation", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		ui.interact_prompt.show()
		ui.interact_prompt.text = "[E] %s" % str(hotspots[0].label)
	else:
		ui.interact_prompt.hide()

	# 4. Physical Family AI (Real Tree Chopping -> Log Hauling -> Hull Hammering -> Shield Wall!)
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"] and sim_dt > 0.0:
		_update_living_family(sim_dt, id)

	# 5. Villagers, Deserting Workers & Two-Prong Raider Fire Conflict
	if id == "noah_02_keel_mortise" and sim_dt > 0.0:
		for i in range(villagers.size()):
			var v: Node3D = villagers[i]
			var tg: Vector3 = world.grounded(-6.0 + float(i) * 3.2, 23.0)
			if v.position.distance_to(tg) > 0.4:
				v.position = v.position.move_toward(tg, sim_dt * 2.4)
				v.look_at(tg, Vector3.UP)
				_anim(v, "Walk")
			else:
				_anim(v, "Idle")
		if ark_build_pct >= 20.0:
			for i in range(hired_workers.size()):
				var hw: Node3D = hired_workers[i]
				var away: Vector3 = world.grounded(2.0 + float(i) * 2.5, 48.0)
				if hw.position.distance_to(away) > 0.5:
					hw.position = hw.position.move_toward(away, sim_dt * 3.0)
					hw.look_at(away, Vector3.UP)
					_anim(hw, "Walk")
	elif id == "noah_03_hull_decks" and sim_dt > 0.0:
		_update_raider_conflict(sim_dt)

	# 6. Auto-Boarding -> Automatic 5s Divine Seal!
	if id == "noah_05_board_ark" and not divine_seal_active:
		_update_auto_boarding(delta)
		_refresh_hud()

	# 7. Rolling Flood Waves + Dove Flight
	if absf(flood_level - flood_target) > 0.02:
		flood_level = move_toward(flood_level, flood_target, delta * 2.4)
		world.flood_water.position.y = flood_level
	if id == "noah_06_flood_dove":
		var wave: float = sin(elapsed * 1.4) * 0.28
		world.flood_water.position.y = flood_level + wave * 0.35
		if flood_level > world.ark_base_y + 0.3:
			world.ark_anchor.position.y = flood_level - 0.45 + wave
			world.ark_anchor.rotation.z = sin(elapsed * 0.95) * 0.035
			world.ark_anchor.rotation.x = cos(elapsed * 0.72) * 0.024
	else:
		world.ark_anchor.position.y = lerpf(world.ark_anchor.position.y, world.ark_base_y, 1.0 - exp(-delta * 4.0))
		world.ark_anchor.rotation = world.ark_anchor.rotation.lerp(Vector3.ZERO, 1.0 - exp(-delta * 4.0))

	if dove_flight_active and birds.size() >= 2:
		dove_flight_t += delta
		var dove: Node3D = birds[1]
		dove.show()
		var win_origin: Vector3 = world.ark_anchor.to_global(Vector3(6.0, 9.0, 4.5))
		var out_arc: Vector3 = win_origin + Vector3(sin(dove_flight_t * 2.4) * 14.0, 2.5 + sin(dove_flight_t * 1.6) * 2.2, 8.0 + sin(dove_flight_t * 1.3) * 8.0)
		var dir_d: Vector3 = out_arc - dove.position
		dove.position = out_arc
		if dir_d.length_squared() > 0.001:
			dove.look_at(dove.position + dir_d.normalized(), Vector3.UP)

	for i in range(birds.size()):
		if dove_flight_active and i == 1:
			continue
		var b: Node3D = birds[i]
		if not b.visible:
			continue
		var a: float = elapsed * 0.35 + float(i) * PI
		var bird_y: float = world.ark_anchor.position.y + 13.5 + float(i) * 1.4 + sin(a * 2.0) * 0.6
		var bp: Vector3 = Vector3(-1.0 + cos(a) * (12.0 + float(i) * 3.5), bird_y, -3.0 + sin(a) * 8.0)
		var tan_v: Vector3 = Vector3(-sin(a) * 10.0, cos(a * 2.0) * 0.8, cos(a) * 6.0)
		b.position = bp
		b.look_at(bp + tan_v, Vector3.UP)
		b.rotation.z = sin(a) * 0.16


func _update_living_family(delta: float, id: String) -> void:
	var assigned: int = 0
	var guard_slot: int = 0
	var chop_interval: float = float(sim_cfg.get("chopIntervalSec", 1.1))
	var chops_req: int = int(sim_cfg.get("treeChopsRequired", 4))
	var log_yield: float = float(sim_cfg.get("logYieldTimber", 12.0))
	var rain_mul: float = float(sim_cfg.get("rainMudSpeedMul", 0.85)) if flood_countdown < 25.0 else 1.0

	for k in range(1, family.size()):
		var member: Node3D = family[k]
		var role: String = "guard"
		if assigned < w_log:
			role = "log"
		elif assigned < w_log + w_build:
			role = "build"
		elif assigned < w_log + w_build + w_pitch:
			role = "pitch"
		assigned += 1

		match role:
			"log":
				# GF-01: Physical Tree-Chopping -> Felling -> Log-Hauling -> +12 Timber Popup at Depot!
				var job: Dictionary = worker_jobs[k]
				var phase: String = str(job.get("phase", "to_tree"))
				var p_depot: Vector3 = world.grounded(-14.5, 15.2 + float(k % 3) * 1.1)
				if phase == "to_depot":
					var to_d: Vector3 = p_depot - member.position
					to_d.y = 0.0
					if to_d.length() < 1.1:
						var gained: int = int(roundf(log_yield * _harmony_mul()))
						timber_f += float(gained)
						_sfx("sfx_hammer.wav", -6.0)
						world.spawn_floating_text_3d(p_depot + Vector3(0.0, 2.1, 0.0), "+%d 歌斐木" % gained, Color(1.0, 0.90, 0.44))
						job.phase = "to_tree"
						job.tree_idx = -1
						_set_actor_props(member, false, true, false)
					else:
						var step_d: Vector3 = to_d.normalized() * 6.8 * rain_mul * delta
						var np: Vector3 = member.position + step_d
						np.y = world.terrain_height(np.x, np.z)
						member.position = np
						member.look_at(member.position + to_d.normalized(), Vector3.UP)
						_set_actor_props(member, true, false, false)
						_anim(member, "Walk")
				else:
					var tidx: int = int(job.get("tree_idx", -1))
					if tidx < 0 or tidx >= world.forest_trees.size() or bool(world.forest_trees[tidx].felled):
						tidx = world.find_standing_tree_near(k)
						job.tree_idx = tidx
					if tidx < 0:
						_anim(member, "Idle")
						continue
					var tpos: Vector3 = (world.forest_trees[tidx].pos as Vector3) + Vector3(-1.1, 0.0, 0.4)
					tpos.y = world.terrain_height(tpos.x, tpos.z)
					var to_t: Vector3 = tpos - member.position
					to_t.y = 0.0
					if to_t.length() > 1.25:
						var step_t: Vector3 = to_t.normalized() * 7.6 * rain_mul * delta
						var np2: Vector3 = member.position + step_t
						np2.y = world.terrain_height(np2.x, np2.z)
						member.position = np2
						member.look_at(member.position + to_t.normalized(), Vector3.UP)
						_set_actor_props(member, false, true, false)
						_anim(member, "Run")
					else:
						var look_tree: Vector3 = world.forest_trees[tidx].pos as Vector3
						look_tree.y = member.position.y
						member.look_at(look_tree, Vector3.UP)
						_set_actor_props(member, false, true, false)
						_anim(member, "Hammer")
						job.chop_timer = float(job.get("chop_timer", 0.0)) + delta
						if float(job.chop_timer) >= chop_interval:
							job.chop_timer = 0.0
							_trigger_local_hitstop(member, 0.035)
							var felled_now: bool = world.chop_tree(tidx, chops_req)
							if felled_now:
								_sfx("sfx_hammer.wav", -5.0)
								job.phase = "to_depot"
								_set_actor_props(member, true, false, false)

			"build":
				if id == "noah_03_hull_decks" and fence_building and k <= 3:
					var fx: float = -22.0 + clampf(fence_build_pct / 100.0, 0.0, 1.0) * 20.0 + float(k % 2) * 1.6
					member.position = world.grounded(fx, 21.3)
					member.look_at(world.grounded(fx, 23.0), Vector3.UP)
					_set_actor_props(member, false, true, false)
					_anim(member, "Hammer")
				else:
					var bx: float = -18.0 + float(k % 4) * 10.5
					member.position = world.grounded(bx, 10.2)
					member.look_at(world.grounded(bx, 0.0), Vector3.UP)
					_set_actor_props(member, false, true, false)
					_anim(member, "BrushPitch" if id == "noah_04_pitch_provisions" else "Hammer")
					# GF-03: 35ms hit-stop + flying woodchips on hammer impact!
					build_hit_timers[k] += delta
					if build_hit_timers[k] >= 1.18:
						build_hit_timers[k] = 0.0
						if id != "noah_04_pitch_provisions":
							_trigger_local_hitstop(member, 0.035)
							world.spawn_hit_particles(member.position + Vector3(0.0, 1.25, -0.8), false)
							if family[0].visible and family[0].position.distance_to(member.position) < 8.5:
								cam_ctrl.add_trauma(0.06)

			"pitch":
				var cyc: float = fposmod(elapsed * 0.16 + family_ai_phase[k], 2.0)
				var pt: float = 2.0 - cyc if cyc >= 1.0 else cyc
				var pa: Vector3 = world.spring_well.position + Vector3(1.2, 0.0, 0.5) if timber_fire_intensity > 0.02 else world.grounded(13.5 + float(k % 2) * 1.6, 15.0 + float(k % 3) * 1.1)
				var pb: Vector3 = world.grounded(-14.2, 16.2) if timber_fire_intensity > 0.02 else world.grounded(5.5, 16.5 + float(k % 2) * 1.1)
				var np3: Vector3 = pa.lerp(pb, pt)
				np3.y = world.terrain_height(np3.x, np3.z)
				var d: Vector3 = np3 - member.position
				member.position = np3
				if d.length_squared() > 0.0001:
					member.look_at(member.position + d.normalized(), Vector3.UP)
				_set_actor_props(member, false, false, false)
				_anim(member, "Run" if timber_fire_intensity > 0.02 else "Walk")

			"guard":
				var gx: float = -19.5 + float(guard_slot) * 3.8
				guard_slot += 1
				var gz: float = 21.3 if (fence_hp > 0.0 or id != "noah_03_hull_decks") else 18.2
				member.position = world.grounded(gx, gz)
				member.look_at(world.grounded(gx, 42.0), Vector3.UP)
				var clashing: bool = (id == "noah_03_hull_decks" and not crisis_resolved)
				_set_actor_props(member, false, true, true)
				_anim(member, "Brawl" if clashing else "Idle")


func _restore_all_to_world() -> void:
	for m in family:
		if m.get_parent() != self:
			m.reparent(self, false)
	for ani in animals:
		if ani.get_parent() != animal_root:
			ani.reparent(animal_root, false)


func _place_family_inside_ark(i: int) -> void:
	if i == 0:
		var m0: Node3D = family[0]
		if m0.get_parent() != world.ark_anchor:
			m0.reparent(world.ark_anchor, false)
		m0.position = Vector3(-25.0, 0.65, 0.4)
		m0.look_at(world.ark_anchor.to_global(Vector3(0.0, 0.65, 0.4)), Vector3.UP)
		_set_actor_props(m0, false, false, false)
		_anim(m0, "Idle")
		m0.visible = not first_person_interior
		return
	var slots: Array[Array] = [
		[Vector3(-16.2, 0.65, -2.0), Vector3(-16.2, 0.65, -5.2), "Idle"],
		[Vector3(-11.8, 0.65, 2.0), Vector3(-11.8, 0.65, 5.2), "Pray"],
		[Vector3(-4.8, 0.65, -1.9), Vector3(-4.8, 0.65, -5.2), "Idle"],
		[Vector3(16.0, 3.95, 0.8), Vector3(0.0, 3.95, 0.8), "Idle"],
		[Vector3(-19.5, 0.65, 2.0), Vector3(-19.5, 0.65, 5.0), "Pray"],
		[Vector3(-7.5, 3.95, 0.6), Vector3(-16.0, 3.95, 0.6), "Pray"],
		[Vector3(4.5, 7.15, 1.2), Vector3(6.0, 7.15, 3.5), "Pray"],
	]
	var cfg: Array = slots[mini(i - 1, slots.size() - 1)]
	var m: Node3D = family[i]
	if m.get_parent() != world.ark_anchor:
		m.reparent(world.ark_anchor, false)
	m.position = cfg[0] as Vector3
	m.look_at(world.ark_anchor.to_global(cfg[1] as Vector3), Vector3.UP)
	_set_actor_props(m, false, false, false)
	_anim(m, str(cfg[2]))
	m.show()


func _place_animal_inside_ark(i: int) -> void:
	var stalls: Array[Array] = [
		[Vector3(-21.2, 0.65, -4.9), Vector3(-21.2, 0.65, 0.0)],
		[Vector3(-19.3, 0.65, -4.9), Vector3(-19.3, 0.65, 0.0)],
		[Vector3(-13.8, 0.65, -5.1), Vector3(-13.8, 0.65, 0.0)],
		[Vector3(-11.0, 0.65, -5.1), Vector3(-11.0, 0.65, 0.0)],
		[Vector3(-13.8, 0.65, 5.1), Vector3(-13.8, 0.65, 0.0)],
		[Vector3(-11.0, 0.65, 5.1), Vector3(-11.0, 0.65, 0.0)],
		[Vector3(-21.2, 0.65, 4.9), Vector3(-21.2, 0.65, 0.0)],
		[Vector3(-19.3, 0.65, 4.9), Vector3(-19.3, 0.65, 0.0)],
		[Vector3(-5.6, 0.65, -5.1), Vector3(-5.6, 0.65, 0.0)],
		[Vector3(-3.2, 0.65, -5.1), Vector3(-3.2, 0.65, 0.0)],
	]
	var cfg: Array = stalls[mini(i, stalls.size() - 1)]
	var ani: Node3D = animals[i]
	if ani.get_parent() != world.ark_anchor:
		ani.reparent(world.ark_anchor, false)
	ani.position = cfg[0] as Vector3
	ani.look_at(world.ark_anchor.to_global(cfg[1] as Vector3), Vector3.UP)
	_anim(ani, "StallRest")
	ani.show()


func _stage_all_inside_ark() -> void:
	for i in range(family.size()):
		_place_family_inside_ark(i)
	for i in range(animals.size()):
		_place_animal_inside_ark(i)


func _init_auto_boarding() -> void:
	_restore_all_to_world()
	family_boarded.clear()
	family_board_wp.clear()
	animal_boarded.clear()
	animal_board_dist.clear()
	boarding_complete_timer = 0.0
	var fam_starts: Array[Vector2] = [
		Vector2(-2.2, 22.0), Vector2(2.4, 21.6), Vector2(-6.5, 20.5), Vector2(6.8, 20.2),
		Vector2(-10.5, 19.2), Vector2(10.2, 18.8), Vector2(-4.5, 24.5), Vector2(4.6, 24.2),
	]
	for i in range(family.size()):
		family_boarded.append(false)
		family_board_wp.append(0)
		var m: Node3D = family[i]
		m.show()
		_set_actor_props(m, false, false, false)
		var st: Vector2 = fam_starts[i]
		m.position = world.grounded(st.x, st.y)
		_anim(m, "Walk")
	animal_root.show()
	for i in range(animals.size()):
		var animal: Node3D = animals[i]
		animal.show()
		animal_boarded.append(false)
		animal_board_dist.append(-float(i / 2) * 3.6)


func _update_auto_boarding(delta: float) -> void:
	var ap: Vector3 = world.ark_anchor.position
	var fam_wps: Array[Vector3] = [
		world.grounded(0.0, 19.6),
		ap + Vector3(0.0, 0.02, 14.0),
		ap + Vector3(0.0, 0.65, 8.6),
		ap + Vector3(0.0, 0.65, 2.2),
	]
	var fam_in: int = 0
	for i in range(family.size()):
		if i >= family_boarded.size():
			break
		if family_boarded[i]:
			fam_in += 1
			continue
		if i == 0 and first_person_interior:
			family_boarded[0] = true
			fam_in += 1
			continue
		var m: Node3D = family[i]
		var wpi: int = family_board_wp[i]
		var lane_x: float = (-0.75 if i % 2 == 0 else 0.75) * (0.45 if wpi >= 1 else 1.0)
		var tg: Vector3 = fam_wps[wpi] + Vector3(lane_x, 0.0, 0.0)
		var spd: float = 4.6 if i == 0 else (3.8 + float(i % 3) * 0.35)
		var flat: Vector3 = Vector3(tg.x - m.position.x, 0.0, tg.z - m.position.z)
		if flat.length() < 0.65:
			wpi += 1
			if wpi >= fam_wps.size():
				family_boarded[i] = true
				_place_family_inside_ark(i)
				fam_in += 1
				continue
			family_board_wp[i] = wpi
		else:
			var dir: Vector3 = flat.normalized()
			var np: Vector3 = m.position + dir * spd * delta
			np.y = _surface_height_for_noah(np.x, np.z)
			m.position = np
			m.look_at(m.position + dir, Vector3.UP)
			_anim(m, "Run" if wpi == 0 else "Walk")

	var segs: Array[float] = []
	var total: float = 0.0
	for i in range(boarding_path.size() - 1):
		var d: float = boarding_path[i].distance_to(boarding_path[i + 1])
		segs.append(d)
		total += d
	var ani_in: int = 0
	for i in range(animals.size()):
		var animal: Node3D = animals[i]
		if i >= animal_boarded.size():
			break
		if animal_boarded[i]:
			ani_in += 1
			continue
		animal_board_dist[i] += delta * 2.65
		var dist: float = animal_board_dist[i]
		if dist < 0.0:
			var p0: Vector3 = boarding_path[0] + Vector3(-0.72 if i % 2 == 0 else 0.72, 0.0, -dist * 0.45)
			p0.y = world.terrain_height(p0.x, p0.z)
			animal.position = p0
			animal.look_at(boarding_path[1], Vector3.UP)
			continue
		if dist >= total:
			animal_boarded[i] = true
			_place_animal_inside_ark(i)
			ani_in += 1
			continue
		var rem: float = dist
		for j in range(segs.size()):
			if rem > segs[j]:
				rem -= segs[j]
				continue
			var dir2: Vector3 = (boarding_path[j + 1] - boarding_path[j]).normalized()
			var p: Vector3 = boarding_path[j].lerp(boarding_path[j + 1], rem / maxf(segs[j], 0.01))
			p.x += -0.68 if i % 2 == 0 else 0.68
			if j < 2:
				p.y = world.terrain_height(p.x, p.z)
			p.y += absf(sin(elapsed * 6.5 + float(i))) * 0.02
			animal.position = p
			animal.look_at(p + Vector3(dir2.x, 0.0, dir2.z), Vector3.UP)
			_anim(animal, "Walk")
			break

	# Dramatic Moment III: When ALL 8 family + ALL 10 animals cross the doorway -> Yahweh Shuts the Door (5s silence)!
	if not preview_mode and fam_in >= family.size() and ani_in >= animals.size():
		boarding_complete_timer += delta
		if boarding_complete_timer >= 0.8:
			_begin_divine_seal_sequence()
