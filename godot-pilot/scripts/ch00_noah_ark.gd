extends Node3D
## Direct-Control 3D Noah + Walk-Inside 3-Deck Ark Cutaway Inspection + Living AI Family & Crises.
## ZERO dumb "+25%" text-button clicking:
## - WASD / Left-Click ground moves Noah directly across the 130x130 highland, up the wooden gangplank,
##   and INSIDE the 3-deck Ark!
## - Walking inside the Ark (or pressing V) automatically opens the Roof & Front-Wall Cutaway so you can
##   360-degree orbit (Right-Drag + Scroll) and inspect the keel, stalls ("分一间一间地造"), ladders,
##   pitch caulking, and Genesis 6:16 1-cubit sunlit window band!
## - Press E (or click any glowing 3D World Hotspot) to personally inspect, hammer with WPN_Mallet.glb,
##   brush pitch, raise the guard fence against dusk torch raiders, or lead the animals aboard!

const DATA_PATH: String = "res://data/ch00_noah_ark.json"

var chapter: Dictionary = {}
var event_index: Dictionary = {}
var current_event: Dictionary = {}
var state: Dictionary = {}

var world: NoahRTSWorld
var cam_ctrl: RTSCameraController

# Cast & Living AI Workers
var family: Array[Node3D] = []  # 0=Noah, 1=Wife, 2..4=Sons, 5..7=Daughters-in-law
var family_ai_phase: Array[float] = []
var hired_workers: Array[Node3D] = []
var villagers: Array[Node3D] = []
var raiders: Array[Node3D] = []
var animal_root: Node3D
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []

# Direct-Control Noah & 3D World Hotspots
var noah_click_target: Vector3 = Vector3.ZERO
var noah_has_click_target: bool = false
var noah_busy_timer: float = 0.0
var noah_busy_clip: String = ""
var interior_cutaway: bool = false
var manual_cutaway_lock: bool = false
var first_person_interior: bool = false
var fp_exit_cooldown: float = 0.0
var camera_free_mode: bool = false

var hotspots: Array[Dictionary] = []  # {id, pos, label, done, node, ring}
var active_hotspot: Dictionary = {}

# Real Deep RTS Workforce Strategy State (7 assignable family members across 4 competing stations!)
var flood_countdown: float = 240.0
var ark_build_pct: float = 0.0
var timber_f: float = 30.0
var pitch_f: float = 15.0
var provisions_f: float = 60.0
var w_log: int = 2
var w_build: int = 3
var w_pitch: int = 1
var w_guard: int = 1
var inspection_boost_timer: float = 0.0
var strategy_alert: String = ""

# Simulation State
var elapsed: float = 0.0
var crisis_resolved: bool = false
var flood_level: float = -10.5
var flood_target: float = -10.5
var preview_mode: bool = false

# Whisper-Clean HUD + Compact Tactical Workforce Allocation Bar
var top_obj_panel: PanelContainer
var top_obj_label: Label
var strategy_panel: PanelContainer
var strategy_labels: Dictionary = {}
var interact_prompt: PanelContainer
var interact_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var fp_btn: Button
var mode_btn: Button
var cutaway_btn: Button
var modal_overlay: ColorRect
var modal_title: Label
var modal_body: Label
var modal_choices: VBoxContainer


func _ready() -> void:
	_load_json()
	world = NoahRTSWorld.new()
	world.name = "NoahRTSWorld"
	add_child(world)
	world.build_all()

	cam_ctrl = RTSCameraController.new()
	cam_ctrl.name = "RTSCameraController"
	add_child(cam_ctrl)

	_spawn_cast_and_animals()
	_build_whisper_hud()

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
			interior_cutaway = false
			manual_cutaway_lock = false
	_enter_event(start_id)


func _load_json() -> void:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		chapter = parsed
		state = chapter.get("initialState", {"timber": 0, "provisions": 60, "harmony": 80, "arkStage": 0}).duplicate(true)
		for ev in chapter.get("events", []):
			event_index[str(ev.id)] = ev


func _anim(actor: Node3D, clip: String) -> void:
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(clip):
		return
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if ap.current_animation != clip:
		ap.play(clip, 0.18)
		ap.advance(0.0)


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
	# Fixed grip: mallet head points FORWARD (-Z) out of right fist!
	var tool: Node3D = world.spawn_asset(glb_file, 0.40, Vector3(0.0, -0.22, -0.04), ba)
	tool.rotation_degrees = Vector3(-82.0, 0.0, 0.0)


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
	for i in range(fam_files.size()):
		var h: float = 1.72 if i == 0 else (1.58 if i == 1 or i >= 5 else 1.65)
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(0.0 + float(i) * 1.4, 21.0))
		actor.name = "Family_%d" % i
		family.append(actor)
		family_ai_phase.append(float(i) * 1.37)
		# Bug 3 FIX: Attach both mallet & carried log to ALL 7 workers + Noah so role switching always shows right props!
		_attach_hand_tool(actor, "WPN_Mallet.glb")
		if i > 0:
			var lg: Node3D = _attach_carried_log(actor)
			lg.hide()
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

	for i in range(3):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.65, world.grounded(-5.0 + float(i) * 3.2, 40.0))
		_add_torch(r)
		r.hide()
		raiders.append(r)

	animal_root = Node3D.new()
	animal_root.name = "AnimalProcession"
	add_child(animal_root)
	var species: Array[Dictionary] = [
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.92}, {"file": "CC0_Sheep_Grab3D.glb", "h": 0.90},
		{"file": "ANI_Ox.glb", "h": 1.42}, {"file": "ANI_Ox.glb", "h": 1.38},
		{"file": "ANI_Goat.glb", "h": 0.96}, {"file": "ANI_Goat.glb", "h": 0.94},
		{"file": "ANI_Donkey.glb", "h": 1.24}, {"file": "ANI_Donkey.glb", "h": 1.20},
	]
	for i in range(species.size()):
		world.spawn_asset(str(species[i].file), float(species[i].h), Vector3.ZERO, animal_root)
	animal_root.hide()

	# Boarding path calibrated to 1:1 Biblical 102x17x10.2m Ark (+Z ramp Z=19.5 -> doorway Z=8.5 Y=0.65)
	var ap: Vector3 = world.ark_anchor.position
	boarding_path = [
		world.grounded(4.5, 29.0),
		world.grounded(1.8, 20.5),
		ap + Vector3(0.0, 0.0, 19.2),
		ap + Vector3(0.0, 0.68, 8.6),
		ap + Vector3(0.0, 0.68, 4.0),
	]

	for bf: String in ["ANI_Raven.glb", "ANI_Dove_Olive.glb"]:
		var b: Node3D = world.spawn_asset(bf, 0.72, Vector3(0.0, 16.0, 0.0))
		b.hide()
		birds.append(b)


func _style_box(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _make_pill(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96.0, 36.0)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	b.add_theme_stylebox_override("normal", _style_box(Color(0.14, 0.10, 0.06, 0.86), Color(0.75, 0.58, 0.30), 6))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.24, 0.17, 0.09, 0.95), Color(0.95, 0.78, 0.44), 6))
	b.pressed.connect(cb)
	return b


func _build_whisper_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	# 1. Top-Left Minimal Objective Tracker (auto-hidden in Silent Revelation & Worship/Rainbow!)
	top_obj_panel = PanelContainer.new()
	top_obj_panel.position = Vector2(16, 14)
	top_obj_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.78), Color(0.74, 0.56, 0.28, 0.85)))
	layer.add_child(top_obj_panel)
	top_obj_label = Label.new()
	top_obj_label.add_theme_color_override("font_color", Color(0.98, 0.91, 0.74))
	top_obj_label.add_theme_font_size_override("font_size", 15)
	top_obj_panel.add_child(top_obj_label)

	# 2. Top-Right 3-Button View Control (True First-Person Interior + Cutaway + Camera Mode)
	var tr_hb: HBoxContainer = HBoxContainer.new()
	tr_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_hb.offset_left = -460
	tr_hb.offset_right = -14
	tr_hb.offset_top = 14
	tr_hb.offset_bottom = 54
	tr_hb.alignment = BoxContainer.ALIGNMENT_END
	tr_hb.add_theme_constant_override("separation", 6)
	layer.add_child(tr_hb)
	fp_btn = _make_pill("第一人称进舱 [F]", _toggle_first_person)
	tr_hb.add_child(fp_btn)
	cutaway_btn = _make_pill("剖面透视 [V]", _toggle_cutaway)
	tr_hb.add_child(cutaway_btn)
	mode_btn = _make_pill("跟随挪亚 [Tab]", _toggle_camera_mode)
	tr_hb.add_child(mode_btn)

	# 2b. Compact Bottom-Left 4-Station Workforce Allocation Tactical Bar (48x44px mobile touch targets!)
	strategy_panel = PanelContainer.new()
	strategy_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strategy_panel.offset_left = 14
	strategy_panel.offset_right = 380
	strategy_panel.offset_top = -316
	strategy_panel.offset_bottom = -88
	strategy_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.84), Color(0.76, 0.58, 0.28, 0.88)))
	layer.add_child(strategy_panel)
	var st_vb: VBoxContainer = VBoxContainer.new()
	st_vb.add_theme_constant_override("separation", 6)
	strategy_panel.add_child(st_vb)
	var st_hdr: Label = Label.new()
	st_hdr.text = "家族 7 人实时分工调度（人力博弈）"
	st_hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.48))
	st_hdr.add_theme_font_size_override("font_size", 14)
	st_vb.add_child(st_hdr)
	var rows: Array[Array] = [
		["log", "东坡伐木（产木）"],
		["build", "船坞建舟（耗木）"],
		["pitch", "松香备粮（稳心）"],
		["guard", "木栅守望（防盗）"],
	]
	for row in rows:
		var key: String = str(row[0])
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		st_vb.add_child(hb)
		var lb: Label = Label.new()
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
		lb.add_theme_font_size_override("font_size", 14)
		hb.add_child(lb)
		strategy_labels[key] = lb
		var bm: Button = _make_pill("-", func() -> void: _assign_worker(key, -1))
		bm.custom_minimum_size = Vector2(48, 44)
		hb.add_child(bm)
		var bp: Button = _make_pill("+", func() -> void: _assign_worker(key, 1))
		bp.custom_minimum_size = Vector2(48, 44)
		hb.add_child(bp)

	# 3. Floating Center-Bottom [E] World Interaction Prompt (only visible when Noah is near a 3D Hotspot!)
	interact_prompt = PanelContainer.new()
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_prompt.offset_left = -220
	interact_prompt.offset_right = 220
	interact_prompt.offset_top = -126
	interact_prompt.offset_bottom = -82
	interact_prompt.add_theme_stylebox_override("panel", _style_box(Color(0.18, 0.13, 0.06, 0.92), Color(0.96, 0.78, 0.36), 20))
	interact_prompt.hide()
	layer.add_child(interact_prompt)
	interact_label = Label.new()
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	interact_label.add_theme_font_size_override("font_size", 16)
	interact_prompt.add_child(interact_label)

	# 4. Subtle Movie Subtitle Strip (bottom edge, auto-compact, non-blocking)
	subtitle_panel = PanelContainer.new()
	subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_panel.offset_left = 120
	subtitle_panel.offset_right = -120
	subtitle_panel.offset_top = -68
	subtitle_panel.offset_bottom = -14
	subtitle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.05, 0.04, 0.76), Color(0.66, 0.50, 0.25, 0.65), 8))
	layer.add_child(subtitle_panel)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_panel.add_child(subtitle_label)

	# 5. Centered Crisis Modal Scroll (ONLY on dramatic plot twists!)
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(0.02, 0.02, 0.02, 0.52)
	modal_overlay.hide()
	layer.add_child(modal_overlay)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.add_child(cc)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(540.0, 240.0)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.96), Color(0.84, 0.66, 0.34), 10))
	cc.add_child(card)
	var mvb: VBoxContainer = VBoxContainer.new()
	mvb.add_theme_constant_override("separation", 12)
	card.add_child(mvb)
	modal_title = Label.new()
	modal_title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.48))
	modal_title.add_theme_font_size_override("font_size", 21)
	mvb.add_child(modal_title)
	modal_body = Label.new()
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	modal_body.add_theme_font_size_override("font_size", 15)
	mvb.add_child(modal_body)
	modal_choices = VBoxContainer.new()
	modal_choices.add_theme_constant_override("separation", 8)
	mvb.add_child(modal_choices)


func _clear_hotspots() -> void:
	for h in hotspots:
		var n: Node3D = h.get("node") as Node3D
		if n != null and is_instance_valid(n):
			n.queue_free()
	hotspots.clear()
	active_hotspot = {}
	interact_prompt.hide()


func _add_hotspot(id: String, pos: Vector3, label: String, clip: String = "Hammer") -> void:
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
	rm.albedo_color = Color(1.0, 0.82, 0.34, 0.88)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.76, 0.24)
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
	lbl.font_size = 36
	lbl.pixel_size = 0.0038
	lbl.modulate = Color(1.0, 0.94, 0.76)
	lbl.outline_modulate = Color(0.08, 0.05, 0.03)
	lbl.outline_size = 10
	root.add_child(lbl)

	hotspots.append({"id": id, "pos": pos, "label": label, "clip": clip, "done": false, "node": root, "ring": ring, "lbl": lbl})


func _sync_hotspot_labels() -> void:
	for h in hotspots:
		var lbl: Label3D = h.get("lbl") as Label3D
		if lbl != null and is_instance_valid(lbl):
			lbl.visible = not first_person_interior


func _assign_worker(station: String, delta_v: int) -> void:
	var idle_pool: int = 7 - (w_log + w_build + w_pitch + w_guard)
	if delta_v > 0 and idle_pool <= 0:
		# Rebalance automatically from the largest other station so player never gets stuck!
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
	SoundManager.play_sfx("sfx_assign.wav", -5.0)
	_refresh_whisper_hud()


func _toggle_first_person() -> void:
	first_person_interior = not first_person_interior
	var ap: Vector3 = world.ark_anchor.position
	if first_person_interior:
		# Put Noah INSIDE the towering 3.2m-tall Lower Deck corridor of the 102x17x10.2m Biblical Ark!
		interior_cutaway = false
		manual_cutaway_lock = false
		if absf(family[0].position.x - ap.x) > 48.0 or family[0].position.z > ap.z + 8.0:
			family[0].position = ap + Vector3(-16.0, 0.65, 0.0)
		cam_ctrl.first_person_mode = true
		cam_ctrl.fp_yaw = -PI * 0.48
		cam_ctrl.fp_pitch = 0.03
		cam_ctrl.fp_eye_pos = family[0].position + Vector3(0.0, 1.68, 0.0)
		family[0].hide()
	else:
		# Bug 2 FIX: Step Noah safely onto the exterior boarding ramp + set cooldown so [F] NEVER loops back in!
		cam_ctrl.first_person_mode = false
		fp_exit_cooldown = 1.6
		if family[0].position.z < ap.z + 10.0:
			family[0].position = world.grounded(0.0, 21.0)
		family[0].show()
	_apply_ark_visibility()
	_sync_hotspot_labels()
	fp_btn.text = "退出第一人称 [F]" if first_person_interior else "第一人称进舱 [F]"


func _toggle_cutaway() -> void:
	if first_person_interior:
		_toggle_first_person()
	manual_cutaway_lock = not manual_cutaway_lock
	interior_cutaway = manual_cutaway_lock
	_apply_ark_visibility()
	cutaway_btn.text = "关闭剖面透视 [V]" if interior_cutaway else "剖面透视 [V]"


func _toggle_camera_mode() -> void:
	camera_free_mode = not camera_free_mode
	cam_ctrl.free_pan_enabled = camera_free_mode
	mode_btn.text = "自由上帝视角 [Tab]" if camera_free_mode else "跟随挪亚 [Tab]"


func _apply_ark_visibility() -> void:
	var id: String = str(current_event.get("id", ""))
	var stage: int = int(current_event.get("arkStage", 0))
	world.set_ark_stage(stage, interior_cutaway, id == "noah_06_flood_dove")


func _enter_event(id: String) -> void:
	if not event_index.has(id):
		return
	current_event = event_index[id]
	crisis_resolved = false
	noah_has_click_target = false
	noah_busy_timer = 0.0
	modal_overlay.hide()
	_clear_hotspots()

	var stage: int = int(current_event.get("arkStage", 0))
	state.arkStage = stage
	# Bug 4 FIX: Cleanly exit First-Person mode whenever advancing to a new act (unless launched with --first-person)
	if first_person_interior and not (preview_mode and id == "noah_03_hull_decks"):
		first_person_interior = false
		cam_ctrl.first_person_mode = false
		family[0].show()
	fp_btn.text = "退出第一人称 [F]" if first_person_interior else "第一人称进舱 [F]"
	match id:
		"noah_01_revelation": ark_build_pct = 0.0
		"noah_02_keel_mortise": ark_build_pct = maxf(ark_build_pct, 10.0)
		"noah_03_hull_decks": ark_build_pct = maxf(ark_build_pct, 45.0)
		"noah_04_pitch_provisions": ark_build_pct = maxf(ark_build_pct, 75.0)
		"noah_05_board_ark", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant": ark_build_pct = 100.0
	if not manual_cutaway_lock:
		interior_cutaway = false
	_apply_ark_visibility()

	world.yard_stakes.visible = (id == "noah_01_revelation")
	world.timber_stacks.visible = (stage >= 1 and id != "noah_06_flood_dove")
	world.pitch_station.visible = (stage >= 3 and id != "noah_06_flood_dove")
	world.guard_fence.visible = bool(state.get("guardFence", false)) and stage >= 2 and id not in ["noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]
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
	for r in raiders:
		r.visible = (id == "noah_03_hull_decks")

	var ap: Vector3 = world.ark_anchor.position
	match id:
		"noah_01_revelation":
			world.apply_mood("revelation")
			SoundManager.stop_ambience()
			SoundManager.play_sfx("sfx_covenant_chime.wav", -6.0, 0.0)
			flood_target = -15.0
			for i in range(family.size()):
				family[i].visible = (i == 0)
				_set_actor_props(family[i], false, false)
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
			family[0].position = world.grounded(-10.0, 16.0)
			_anim(family[0], "Idle")
			cam_ctrl.focus_on(Vector3(0.0, 3.0, 6.0), 62.0, -0.42, preview_mode)
			_add_hotspot("keel_west", world.grounded(-18.0, 9.5), "检查西段三百肘龙骨榫卯", "Hammer")
			_add_hotspot("keel_east", world.grounded(18.0, 9.5), "敲紧东段肋骨木楔", "Hammer")
			_add_hotspot("timber_check", world.grounded(-15.0, 17.5), "验收东坡歌斐木料堆", "Idle")

		"noah_03_hull_decks":
			world.apply_mood("build" if (interior_cutaway or first_person_interior) else "dusk_raid")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			if first_person_interior and preview_mode:
				# TRUE 1.68m EYE-LEVEL FIRST-PERSON NOAH INSIDE THE 3.2m-TALL BIBLICAL ARK CORRIDOR!
				interior_cutaway = false
				_apply_ark_visibility()
				family[0].position = ap + Vector3(-18.0, 0.65, 0.0)
				family[0].hide()
				cam_ctrl.first_person_mode = true
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
			else:
				family[0].position = world.grounded(0.0, 22.0)
				cam_ctrl.focus_on(Vector3(0.0, 3.5, 12.0), 58.0, -0.38, preview_mode)
			_add_hotspot("inside_lower", ap + Vector3(-8.0, 0.65, 0.0), "检查下层龙骨榫卯与大型畜栏", "Hammer")
			_add_hotspot("inside_mid", ap + Vector3(15.5, 3.95, 0.0), "沿中央木梯上中层检查分舱隔间", "Hammer")
			_add_hotspot("defend_yard", world.grounded(-8.0, 22.0), "筑木栅与三子护材对峙", "Bless")
			_sync_hotspot_labels()

		"noah_04_pitch_provisions":
			world.apply_mood("build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			family[0].position = world.grounded(10.0, 18.0)
			# Cinematic low-angle scenic showcase framing the colossal 102m Biblical Ark, embedded cliffs & grass!
			cam_ctrl.pitch_override = -0.24
			cam_ctrl.focus_on(Vector3(-4.0, 4.5, 6.0), 56.0, -0.46, preview_mode)
			_add_hotspot("pitch_inside", ap + Vector3(-10.0, 0.65, 0.0), "入舱检查内壁松香防水缝", "BrushPitch")
			_add_hotspot("pitch_outside", world.grounded(11.5, 15.5), "熬漆里外厚涂松香", "BrushPitch")
			_add_hotspot("provisions_check", world.grounded(15.0, 15.8), "清点干湿分区粮草陶罐", "Idle")

		"noah_05_board_ark":
			world.apply_mood("dusk_raid")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			family[0].position = world.grounded(-4.0, 21.0)
			cam_ctrl.focus_on(Vector3(0.0, 4.0, 12.0), 46.0, -0.36, preview_mode)
			_add_hotspot("seal_door", ap + Vector3(0.0, 0.65, 12.0), "引导众活物入舱并关上舱门", "Bless")

		"noah_06_flood_dove":
			world.apply_mood("flood")
			SoundManager.play_ambience("sfx_rain_loop.wav", -8.0)
			SoundManager.play_sfx("sfx_thunder.wav", -4.0)
			cam_ctrl.pitch_override = NAN
			flood_target = 6.5
			if preview_mode:
				flood_level = 6.2
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = flood_level - 1.2
			for m in family:
				m.hide()
			cam_ctrl.focus_on(Vector3(0.0, 7.5, 6.0), 74.0, -0.48, preview_mode)
			_add_hotspot("release_dove", ap + Vector3(0.0, 10.5, 0.0), "放出乌鸦与鸽子探看水退", "Bless")

		"noah_07_exit_altar", "noah_08_rainbow_covenant":
			world.apply_mood("ararat")
			SoundManager.stop_ambience()
			if id == "noah_08_rainbow_covenant":
				SoundManager.play_sfx("sfx_covenant_chime.wav", -5.0, 0.0)
			flood_target = -15.0
			if preview_mode:
				flood_level = -15.0
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = world.ark_base_y
			_stage_ararat_worship()
			cam_ctrl.pitch_override = -0.22
			cam_ctrl.focus_on(Vector3(-2.0, 5.5, 10.0), 62.0, -0.34, preview_mode)
			if id == "noah_07_exit_altar":
				_add_hotspot("offer_altar", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "一家八口筑坛献祭感恩", "Bless")
			else:
				_add_hotspot("to_overworld", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "仰望彩虹永约 · 前往宏观画卷", "Bless")

	_sync_hotspot_labels()
	_refresh_whisper_hud()


func _set_actor_props(actor: Node3D, show_log: bool, show_tool: bool) -> void:
	var lg: Node3D = actor.find_child("CarriedLog", false, false) as Node3D
	if lg != null:
		lg.visible = show_log
	var tl: Node3D = actor.find_child("RightHandTool", true, false) as Node3D
	if tl != null:
		tl.visible = show_tool


func _stage_ararat_worship() -> void:
	var slots: Array[Vector2] = [
		Vector2(0.5, 21.0), Vector2(3.6, 22.4), Vector2(-2.6, 22.4), Vector2(-1.4, 21.2),
		Vector2(2.4, 21.2), Vector2(-1.6, 24.8), Vector2(2.6, 24.8), Vector2(4.2, 23.8),
	]
	for i in range(family.size()):
		family[i].show()
		_set_actor_props(family[i], false, false)
		family[i].position = world.grounded(slots[i].x, slots[i].y)
		var target: Vector3 = world.altar_group.position if i != 0 else (family[i].position + Vector3(0.0, 0.0, 6.0))
		target.y = family[i].position.y
		family[i].look_at(target, Vector3.UP)
		_anim(family[i], "Bless" if i == 0 else ("Pray" if i in [5, 6] else "Idle"))


func _refresh_whisper_hud() -> void:
	var id: String = str(current_event.get("id", ""))
	var is_build_act: bool = id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]
	var hide_top: bool = bool(current_event.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	top_obj_panel.visible = not hide_top
	strategy_panel.visible = is_build_act and not first_person_interior
	if id == "noah_06_flood_dove":
		top_obj_label.text = "洪水滔天 · 方舟蒙神保守漂流于渊面  |  请按 [E] 放出乌鸦与鸽子探看水退"
	elif id == "noah_05_board_ark":
		top_obj_label.text = "方舟完工 100%%  |  众活物正成双登舟  |  请按 [E] 引导全员入舱并关上舱门"
	else:
		var boost_tag: String = "  [宗师监造+60%]" if inspection_boost_timer > 0.0 else ""
		var alert_tag: String = ("  |  " + strategy_alert) if not strategy_alert.is_empty() else ""
		top_obj_label.text = "距大雨: %ds  |  工程: %d%%  |  歌斐木: %d  |  松香: %d  |  粮草: %d%s%s" % [
			int(maxf(flood_countdown, 0.0)),
			int(roundf(ark_build_pct)),
			int(timber_f),
			int(pitch_f),
			int(provisions_f),
			boost_tag,
			alert_tag,
		]
	if strategy_labels.has("log"):
		(strategy_labels["log"] as Label).text = "东坡伐木: %d人 (+%d木/s)" % [w_log, w_log * 4]
		(strategy_labels["build"] as Label).text = "船坞建舟: %d人 (耗%d木/s)" % [w_build, w_build * 3]
		(strategy_labels["pitch"] as Label).text = "松香备粮: %d人 (+%d漆/s)" % [w_pitch, w_pitch * 2]
		(strategy_labels["guard"] as Label).text = "木栅守望: %d人 (%s)" % [w_guard, "安全" if w_guard >= 2 else "易被盗材!"]
	subtitle_label.text = "【%s · %s】%s" % [
		str(current_event.get("speakerZh", "")),
		str(current_event.get("canonRef", "")),
		str(current_event.get("bodyZh", "")),
	]


func _unhandled_input(event: InputEvent) -> void:
	if modal_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_F:
			_toggle_first_person()
		elif kc == KEY_V:
			_toggle_cutaway()
		elif kc == KEY_TAB:
			_toggle_camera_mode()
		elif kc == KEY_E:
			if not active_hotspot.is_empty():
				_trigger_hotspot(active_hotspot)
			elif hotspots.size() == 1 and not bool(hotspots[0].done):
				_trigger_hotspot(hotspots[0])
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		var orig: Vector3 = cam_ctrl.camera.project_ray_origin(mb.position)
		var dir: Vector3 = cam_ctrl.camera.project_ray_normal(mb.position)
		# Check if clicking directly on a 3D Hotspot!
		for h in hotspots:
			if bool(h.done):
				continue
			var hp: Vector3 = h.pos
			var t: float = (hp - orig).dot(dir)
			if t > 0.0:
				var closest: Vector3 = orig + dir * t
				if closest.distance_to(hp + Vector3(0.0, 0.8, 0.0)) < 1.8:
					if family[0].visible and family[0].position.distance_to(hp) > 2.6:
						noah_click_target = hp
						noah_has_click_target = true
					else:
						_trigger_hotspot(h)
					return
		# Otherwise click-to-walk Noah on the ground / Ark deck!
		if family[0].visible and not camera_free_mode:
			var hit: Variant = Plane(Vector3.UP, family[0].position.y).intersects_ray(orig, dir)
			if hit != null:
				noah_click_target = hit
				noah_has_click_target = true


func _trigger_hotspot(h: Dictionary) -> void:
	if bool(h.done):
		return
	var hid: String = str(h.id)
	if hid == "defend_yard" and not crisis_resolved:
		_open_raider_modal(h)
		return
	h.done = true
	var n: Node3D = h.get("node") as Node3D
	if n != null and is_instance_valid(n):
		n.hide()
	noah_busy_timer = 1.1
	noah_busy_clip = str(h.get("clip", "Hammer"))
	SoundManager.play_sfx("sfx_hammer.wav" if noah_busy_clip == "Hammer" else "sfx_ui_click.wav", -4.0)
	# Bug 5 FIX: Pure +60% Master Shipwright efficiency boost — NO magic free timber/progress handout!
	inspection_boost_timer = 22.0
	if family[0].visible:
		_anim(family[0], noah_busy_clip)
	_refresh_whisper_hud()
	_check_act_complete()


func _open_raider_modal(h: Dictionary) -> void:
	modal_overlay.show()
	modal_title.text = "夜间危机 · 强人举火把逼近木料堆"
	modal_body.text = "三名强人举着火把顺着南坡山路逼近你的歌斐木料堆！请决定如何护材（非致命防卫）："
	for c in modal_choices.get_children():
		modal_choices.remove_child(c)
		c.queue_free()
	modal_choices.add_child(_make_pill("立即筑起木栅栏，派三子举火把夜巡对峙驱离", func() -> void:
		crisis_resolved = true
		state.guardFence = true
		world.guard_fence.show()
		modal_overlay.hide()
		_trigger_hotspot(h)
	))
	modal_choices.add_child(_make_pill("主动分让部分边角废料，以和息争避免流血", func() -> void:
		crisis_resolved = true
		modal_overlay.hide()
		_trigger_hotspot(h)
	))


func _check_act_complete() -> void:
	for h in hotspots:
		if not bool(h.done):
			return
	var id: String = str(current_event.get("id", ""))
	if id == "noah_02_keel_mortise" and ark_build_pct < 35.0:
		strategy_alert = "龙骨工程需达 35%%（当前 %d%%），请调度家人继续伐木建舟！" % int(ark_build_pct)
		_refresh_whisper_hud()
		return
	if id == "noah_03_hull_decks" and ark_build_pct < 70.0:
		strategy_alert = "三层船壳需达 70%%（当前 %d%%），请调度家人抓紧施工！" % int(ark_build_pct)
		_refresh_whisper_hud()
		return
	if id == "noah_04_pitch_provisions" and (ark_build_pct < 98.0 or pitch_f < 25.0):
		strategy_alert = "需工程 98%% 且松香 ≥25 才可登舟！"
		_refresh_whisper_hud()
		return
	match id:
		"noah_01_revelation": _enter_event("noah_02_keel_mortise")
		"noah_02_keel_mortise": _enter_event("noah_03_hull_decks")
		"noah_03_hull_decks": _enter_event("noah_04_pitch_provisions")
		"noah_04_pitch_provisions": _enter_event("noah_05_board_ark")
		"noah_05_board_ark": _enter_event("noah_06_flood_dove")
		"noah_06_flood_dove": _enter_event("noah_07_exit_altar")
		"noah_07_exit_altar": _enter_event("noah_08_rainbow_covenant")
		"noah_08_rainbow_covenant": SceneTransition.change_scene("res://scenes/overworld_prologue.tscn")


func _surface_height_for_noah(x: float, z: float) -> float:
	var ap: Vector3 = world.ark_anchor.position
	# Exact 1:1 Biblical 102m x 17m x 10.2m Ark Interior Floors + Central Wooden Staircases!
	if int(state.get("arkStage", 0)) >= 2 and absf(x - ap.x) < 49.5 and z > ap.z - 8.0 and z < ap.z + 8.0:
		var rel_x: float = x - ap.x
		var rel_z: float = z - ap.z
		# Central Stair 1 (X=2.5..13.5, Z in [-2.4, +2.4]): Lower Deck (0.65m) -> Middle Deck (3.95m)
		if rel_x >= 2.5 and rel_x <= 13.5 and absf(rel_z) < 2.6:
			var s1: float = clampf((rel_x - 2.5) / 11.0, 0.0, 1.0)
			return lerpf(ap.y + 0.65, ap.y + 3.95, s1)
		# Middle Deck (X=13.5..18.5)
		if rel_x > 13.5 and rel_x < 18.5:
			return ap.y + 3.95
		# Central Stair 2 (X=18.5..29.5, Z in [-2.4, +2.4]): Middle Deck (3.95m) -> Upper Deck (7.15m)
		if rel_x >= 18.5 and rel_x <= 29.5 and absf(rel_z) < 2.6:
			var s2: float = clampf((rel_x - 18.5) / 11.0, 0.0, 1.0)
			return lerpf(ap.y + 3.95, ap.y + 7.15, s2)
		if rel_x > 29.5:
			return ap.y + 7.15
		return ap.y + 0.65
	# Exterior Boarding Gangplank Ramp (+Z side, Z=8.0..19.5)
	if int(state.get("arkStage", 0)) >= 2 and absf(x - ap.x) < 2.8 and z >= ap.z + 8.0 and z <= ap.z + 19.8:
		var t: float = clampf((z - (ap.z + 8.0)) / 11.5, 0.0, 1.0)
		return lerpf(ap.y + 0.65, world.terrain_height(x, z), t)
	return world.terrain_height(x, z)


func _process(delta: float) -> void:
	elapsed += delta
	if fp_exit_cooldown > 0.0:
		fp_exit_cooldown -= delta
	var id: String = str(current_event.get("id", ""))
	var noah: Node3D = family[0]

	# 1. Direct-Control Noah (1.68m Eye-Level First-Person inside 3.2m-tall Ark Decks OR 3rd-Person outside!)
	if not modal_overlay.visible and id not in ["noah_01_revelation", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		var move_dir: Vector3 = Vector3.ZERO
		if first_person_interior:
			var yaw: float = cam_ctrl.fp_yaw
			var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
			var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				move_dir += fwd
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				move_dir -= fwd
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				move_dir -= right
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				move_dir += right
			if move_dir.length_squared() > 0.01:
				move_dir = move_dir.normalized()
				var fp_spd: float = 6.2 if Input.is_key_pressed(KEY_SHIFT) else 3.8
				var np: Vector3 = noah.position + move_dir * fp_spd * delta
				var ap: Vector3 = world.ark_anchor.position
				np.x = clampf(np.x, ap.x - 48.0, ap.x + 48.0)
				np.z = clampf(np.z, ap.z - 7.2, ap.z + 9.2)
				np.y = _surface_height_for_noah(np.x, np.z)
				noah.position = np
				# Bug 2 FIX: Walk smoothly back outside through the side doorway!
				if np.z > ap.z + 8.6 and absf(np.x - ap.x) < 2.6:
					_toggle_first_person()
			cam_ctrl.fp_eye_pos = noah.position + Vector3(0.0, 1.68 + sin(elapsed * 6.0) * (0.03 if move_dir.length_squared() > 0.01 else 0.0), 0.0)
		elif noah.visible and not camera_free_mode:
			var yaw: float = cam_ctrl.current_yaw
			var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
			var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				move_dir += fwd
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				move_dir -= fwd
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				move_dir -= right
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				move_dir += right
			if move_dir.length_squared() > 0.01:
				noah_has_click_target = false
				noah_busy_timer = 0.0
				move_dir = move_dir.normalized()
				var spd: float = 7.2 if Input.is_key_pressed(KEY_SHIFT) else 4.2
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
					var np: Vector3 = noah.position + dir * 4.4 * delta
					np.y = _surface_height_for_noah(np.x, np.z)
					noah.position = np
					noah.look_at(noah.position + dir, Vector3.UP)
					_anim(noah, "Walk")
			elif noah_busy_timer > 0.0:
				noah_busy_timer -= delta
				_anim(noah, noah_busy_clip)
			else:
				_anim(noah, "Idle")

			# Auto-enter First-Person Interior cleanly when Noah walks through the +Z doorway (respecting cooldown!)
			var ap: Vector3 = world.ark_anchor.position
			if fp_exit_cooldown <= 0.0 and int(state.get("arkStage", 0)) >= 2 and absf(noah.position.x - ap.x) < 48.0 and noah.position.z < ap.z + 7.8 and noah.position.z > ap.z - 8.0 and not manual_cutaway_lock:
				_toggle_first_person()

			cam_ctrl.focus_on(noah.position + Vector3(0.0, 1.6, 0.0), -1.0, NAN, false)

	# 1b. Live Real-Time RTS Economy, Countdown & Raider Theft Simulation!
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		flood_countdown = maxf(0.0, flood_countdown - delta)
		if inspection_boost_timer > 0.0:
			inspection_boost_timer -= delta
		timber_f += float(w_log) * 4.0 * delta
		pitch_f += float(w_pitch) * 2.0 * delta
		provisions_f += float(w_pitch) * 1.6 * delta
		var timber_need: float = float(w_build) * 3.0 * delta
		strategy_alert = ""
		if id == "noah_03_hull_decks" and not crisis_resolved and w_guard < 2:
			timber_f = maxf(0.0, timber_f - 5.0 * delta)
			strategy_alert = "强人正在盗材！调派守望或建栅栏"
		if timber_f >= timber_need and w_build > 0:
			timber_f -= timber_need
			var boost: float = 1.6 if inspection_boost_timer > 0.0 else 1.0
			ark_build_pct = minf(100.0, ark_build_pct + float(w_build) * 1.4 * boost * delta)
		elif w_build > 0:
			strategy_alert = "歌斐木不足！请加派人手东坡伐木"
		if flood_countdown <= 0.0:
			strategy_alert = "暴雨已破堤！请速完成收尾登舟！"
			world.rain.emitting = true
		state.timber = int(timber_f)
		_check_act_complete()
		_refresh_whisper_hud()

	# 2. Check proximity to 3D Hotspots for [E] Prompt + pulse rings
	active_hotspot = {}
	for h in hotspots:
		if bool(h.done):
			continue
		var ring: MeshInstance3D = h.get("ring") as MeshInstance3D
		if ring != null:
			var s: float = 1.0 + sin(elapsed * 3.5) * 0.09
			ring.scale = Vector3(s, 1.0, s)
		# Bug 1 FIX: Check proximity in BOTH 3rd-person AND First-Person Interior mode!
		if (noah.visible or first_person_interior) and noah.position.distance_to(h.pos) < 4.5:
			active_hotspot = h
	if not active_hotspot.is_empty():
		interact_prompt.show()
		interact_label.text = "[E] %s" % str(active_hotspot.label)
	elif hotspots.size() == 1 and id in ["noah_01_revelation", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		interact_prompt.show()
		interact_label.text = "[E] %s" % str(hotspots[0].label)
	else:
		interact_prompt.hide()

	# 3. Living AI Family (Sons haul REAL logs from East Forest <-> Shipyard & hammer Ark ribs!)
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		_update_living_family(delta, id)

	# 4. Live Villagers, Deserting Hired Workers & Dusk Raiders (calibrated to 260x260 world)
	if id == "noah_02_keel_mortise":
		for i in range(villagers.size()):
			var v: Node3D = villagers[i]
			var tg: Vector3 = world.grounded(-6.0 + float(i) * 3.2, 23.0)
			if v.position.distance_to(tg) > 0.4:
				v.position = v.position.move_toward(tg, delta * 2.4)
				v.look_at(tg, Vector3.UP)
				_anim(v, "Walk")
			else:
				_anim(v, "Idle")
		# Bug 6 FIX: Hired workers visibly abandon site and walk away down the South village road!
		if ark_build_pct >= 20.0:
			for i in range(hired_workers.size()):
				var hw: Node3D = hired_workers[i]
				var away: Vector3 = world.grounded(2.0 + float(i) * 2.5, 48.0)
				if hw.position.distance_to(away) > 0.5:
					hw.position = hw.position.move_toward(away, delta * 3.0)
					hw.look_at(away, Vector3.UP)
					_anim(hw, "Walk")
	elif id == "noah_03_hull_decks":
		for i in range(raiders.size()):
			var r: Node3D = raiders[i]
			var rg: Vector3 = world.grounded(-6.0 + float(i) * 3.5, 46.0 if crisis_resolved else 23.5)
			if r.position.distance_to(rg) > 0.45:
				r.position = r.position.move_toward(rg, delta * 3.2)
				r.look_at(rg, Vector3.UP)
				_anim(r, "Run")
			else:
				_anim(r, "Brawl" if not crisis_resolved else "Idle")

	# 5. Animal Boarding Procession
	if animal_root.visible:
		_update_animal_procession()

	# 6. Animated Rolling 3D Flood + Floating Ark + Circling Birds
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

	for i in range(birds.size()):
		var b: Node3D = birds[i]
		if not b.visible:
			continue
		var a: float = elapsed * 0.35 + float(i) * PI
		var bp: Vector3 = Vector3(-1.0 + cos(a) * (10.0 + float(i) * 3.0), 8.2 + float(i) * 1.1 + sin(a * 2.0) * 0.5, -3.0 + sin(a) * 6.0)
		var tan_v: Vector3 = Vector3(-sin(a) * 10.0, cos(a * 2.0) * 0.8, cos(a) * 6.0)
		b.position = bp
		b.look_at(bp + tan_v, Vector3.UP)
		b.rotation.z = sin(a) * 0.16


func _update_living_family(_delta: float, id: String) -> void:
	var assigned: int = 0
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
				var cycle: float = fposmod(elapsed * 0.11 + family_ai_phase[k], 2.0)
				var going_back: bool = cycle >= 1.0
				var t: float = cycle - 1.0 if going_back else cycle
				var p_forest: Vector3 = world.grounded(60.0, 2.0 + float(k) * 2.2)
				var p_depot: Vector3 = world.grounded(-14.0, 15.0 + float(k % 3) * 1.4)
				var target: Vector3 = p_depot.lerp(p_forest, t) if going_back else p_forest.lerp(p_depot, t)
				var dir: Vector3 = target - member.position
				member.position = target
				if dir.length_squared() > 0.0001:
					member.look_at(member.position + dir.normalized(), Vector3.UP)
				_set_actor_props(member, not going_back, false)
				_anim(member, "Walk")
			"build":
				var bx: float = -18.0 + float(k % 4) * 10.5
				member.position = world.grounded(bx, 10.2)
				member.look_at(world.grounded(bx, 0.0), Vector3.UP)
				_set_actor_props(member, false, true)
				_anim(member, "BrushPitch" if id == "noah_04_pitch_provisions" else "Hammer")
			"pitch":
				var cyc: float = fposmod(elapsed * 0.16 + family_ai_phase[k], 2.0)
				var pt: float = 2.0 - cyc if cyc >= 1.0 else cyc
				var pa: Vector3 = world.grounded(13.5 + float(k % 2) * 1.6, 15.0 + float(k % 3) * 1.1)
				var pb: Vector3 = world.grounded(5.5, 16.5 + float(k % 2) * 1.1)
				var np: Vector3 = pa.lerp(pb, pt)
				var d: Vector3 = np - member.position
				member.position = np
				if d.length_squared() > 0.0001:
					member.look_at(member.position + d.normalized(), Vector3.UP)
				_set_actor_props(member, false, false)
				_anim(member, "Walk")
			"guard":
				var gx: float = -16.0 + float(k % 4) * 4.5
				member.position = world.grounded(gx, 21.5)
				member.look_at(world.grounded(gx, 42.0), Vector3.UP)
				_set_actor_props(member, false, true)
				_anim(member, "Idle")


func _update_animal_procession() -> void:
	var segs: Array[float] = []
	var total: float = 0.0
	for i in range(boarding_path.size() - 1):
		var d: float = boarding_path[i].distance_to(boarding_path[i + 1])
		segs.append(d)
		total += d
	for i in range(animal_root.get_child_count()):
		var animal: Node3D = animal_root.get_child(i) as Node3D
		var dist: float = fposmod(elapsed * 1.1 + total - float(i / 2) * 2.2, total)
		for j in range(segs.size()):
			if dist > segs[j]:
				dist -= segs[j]
				continue
			var dir: Vector3 = (boarding_path[j + 1] - boarding_path[j]).normalized()
			var p: Vector3 = boarding_path[j].lerp(boarding_path[j + 1], dist / maxf(segs[j], 0.01))
			p.x += -0.42 if i % 2 == 0 else 0.42
			if j < 2:
				p.y = world.terrain_height(p.x, p.z)
			p.y += absf(sin(elapsed * 6.5 + float(i))) * 0.05
			animal.position = p
			animal.look_at(p + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
			break
