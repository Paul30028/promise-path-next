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
var raider_morale: Array[float] = []
var raider_bars: Array[MeshInstance3D] = []
var raider_labels: Array[Label3D] = []
var animal_root: Node3D
var animals: Array[Node3D] = []
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []

# Direct-Control Noah & 3D World Hotspots
var noah_click_target: Vector3 = Vector3.ZERO
var noah_has_click_target: bool = false
var noah_busy_timer: float = 0.0
var noah_busy_clip: String = ""
var noah_deck: int = 0  # 0=Lower(0.65m), 1=Middle(3.95m), 2=Upper(7.15m)
var noah_fp_local: Vector3 = Vector3(-18.0, 0.65, 0.5)
var interior_cutaway: bool = false
var manual_cutaway_lock: bool = false
var first_person_interior: bool = false
var fp_exit_cooldown: float = 0.0
var camera_free_mode: bool = false

var hotspots: Array[Dictionary] = []  # {id, pos, label, done, node, ring}
var active_hotspot: Dictionary = {}

# Real Deep RTS Workforce Strategy State (7 assignable family members across 4 competing stations!)
var flood_countdown: float = 240.0
var flood_failed: bool = false
var ark_build_pct: float = 0.0
var last_ark_vis_stage: int = -1
var ark_completed_chime_played: bool = false
var timber_f: float = 45.0
var pitch_f: float = 15.0
var provisions_f: float = 60.0
var w_log: int = 2
var w_build: int = 3
var w_pitch: int = 1
var w_guard: int = 1
var inspection_boost_timer: float = 0.0
var strategy_alert: String = ""

# Age of Empires-Style Progressive Palisade & Raider Clash State
var fence_build_pct: float = 0.0
var fence_hp: float = 0.0
var fence_max_hp: float = 300.0
var fence_building: bool = false
var fence_status_root: Node3D
var fence_hp_bar: MeshInstance3D
var fence_status_label: Label3D
var raider_clash_sfx_timer: float = 0.0
var rally_cooldown: float = 0.0

# Auto-Boarding State (at 0 days countdown / noah_05_board_ark)
var family_boarded: Array[bool] = []
var family_board_wp: Array[int] = []
var animal_boarded: Array[bool] = []
var animal_board_dist: Array[float] = []
var boarding_complete_timer: float = 0.0

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
var fence_cmd_btn: Button
var interact_prompt: Button
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
		elif arg == "--flood-fp":
			start_id = "noah_06_flood_dove"
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
	# Fixed grip: mallet/weapon head points FORWARD (-Z) out of right fist!
	var tool: Node3D = world.spawn_asset(glb_file, 0.44 if "Sword" in glb_file else 0.40, Vector3(0.0, -0.22, -0.04), ba)
	tool.rotation_degrees = Vector3(-82.0, 0.0, 0.0)


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
	# Normalize by largest mesh AABB extent & compensate for skeleton scale -> exact 0.54m Bronze-Age buckler!
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
	for i in range(fam_files.size()):
		var h: float = 1.72 if i == 0 else (1.58 if i == 1 or i >= 5 else 1.65)
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(0.0 + float(i) * 1.4, 21.0))
		actor.name = "Family_%d" % i
		family.append(actor)
		family_ai_phase.append(float(i) * 1.37)
		# Attach mallet, left-hand Wooden Shield (for guard shield-wall), and carried log to ALL family workers!
		_attach_hand_tool(actor, "WPN_Mallet.glb")
		_attach_left_shield(actor)
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

	# 5 Torch-Bearing Raiders with Bronze Blades & Overhead 3D Morale Bars (AoE real-time raid!)
	for i in range(5):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.68, world.grounded(-18.5 + float(i) * 3.0, 46.0))
		_add_torch(r)
		_attach_hand_tool(r, "WPN_BronzeSword.glb")
		var mb: Dictionary = _attach_status_bar(r, 2.12, "强人士气 100%", Color(0.92, 0.28, 0.18), 1.15)
		raider_bars.append(mb["fill"] as MeshInstance3D)
		raider_labels.append(mb["lbl"] as Label3D)
		raider_morale.append(100.0)
		r.hide()
		raiders.append(r)

	# 3D Overhead Palisade Durability / Build Progress Bar at South Defense Line
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
	# 10 Photorealistic CC0 Grab3D Animals (5 distinct Biblical pairs: Sheep, Bull, Horse, Deer, Lion!)
	# flip_y=true rotates +Z-facing Grab3D meshes 180 deg so ALL animals face -Z (forward with look_at!)
	var species: Array[Dictionary] = [
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.92, "flip": false}, {"file": "CC0_Sheep_Grab3D.glb", "h": 0.88, "flip": false},
		{"file": "CC0_Bull_Grab3D.glb", "h": 1.48, "flip": true}, {"file": "CC0_Bull_Grab3D.glb", "h": 1.40, "flip": true},
		{"file": "CC0_Horse_Grab3D.glb", "h": 1.62, "flip": true}, {"file": "CC0_Horse_Grab3D.glb", "h": 1.54, "flip": true},
		{"file": "CC0_Deer_Grab3D.glb", "h": 1.32, "flip": true}, {"file": "CC0_Deer_Grab3D.glb", "h": 1.24, "flip": true},
		{"file": "CC0_Lion_Grab3D.glb", "h": 1.12, "flip": true}, {"file": "CC0_Lion_Grab3D.glb", "h": 1.04, "flip": true},
	]
	for i in range(species.size()):
		var ani: Node3D = world.spawn_asset(str(species[i].file), float(species[i].h), Vector3.ZERO, animal_root)
		ani.name = "Animal_%d" % i
		if bool(species[i].flip) and ani.get_child_count() > 0:
			(ani.get_child(0) as Node3D).rotation_degrees.y = 180.0
		animals.append(ani)
	animal_root.hide()

	# Boarding path calibrated to 1:1 Biblical 102x17x10.2m Ark (+Z ramp Z=19.5 -> doorway Z=8.5 Y=0.65)
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

	# 2b. Compact Bottom-Left 4-Station Workforce Allocation + AoE Palisade Command Bar (48x44px touch targets!)
	strategy_panel = PanelContainer.new()
	strategy_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strategy_panel.offset_left = 14
	strategy_panel.offset_right = 394
	strategy_panel.offset_top = -362
	strategy_panel.offset_bottom = -84
	strategy_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.86), Color(0.76, 0.58, 0.28, 0.88)))
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
		["guard", "盾阵守望（防盗）"],
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
	fence_cmd_btn = _make_pill("逐段修筑木栅防线 (-40木)", _start_fence_work)
	fence_cmd_btn.custom_minimum_size = Vector2(260, 44)
	fence_cmd_btn.hide()
	st_vb.add_child(fence_cmd_btn)

	# 3. Clickable Center-Bottom [E] World Interaction Button (works with [E] key, mouse click, AND touch!)
	interact_prompt = _make_pill("[E] 交互", _trigger_active_hotspot)
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_prompt.offset_left = -230
	interact_prompt.offset_right = 230
	interact_prompt.offset_top = -128
	interact_prompt.offset_bottom = -82
	interact_prompt.add_theme_font_size_override("font_size", 16)
	interact_prompt.add_theme_stylebox_override("normal", _style_box(Color(0.20, 0.14, 0.06, 0.94), Color(0.98, 0.80, 0.38), 20))
	interact_prompt.add_theme_stylebox_override("hover", _style_box(Color(0.30, 0.21, 0.09, 0.98), Color(1.0, 0.88, 0.52), 20))
	interact_prompt.hide()
	layer.add_child(interact_prompt)

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
	var id: String = str(current_event.get("id", ""))
	if id == "noah_01_revelation":
		return
	first_person_interior = not first_person_interior
	if first_person_interior:
		# Put Noah INSIDE the towering 3.2m-tall Lower Deck corridor of the 102x17x10.2m Biblical Ark!
		interior_cutaway = false
		manual_cutaway_lock = false
		noah_deck = 0
		noah_fp_local = Vector3(-25.0, 0.65, 0.4) if id in ["noah_05_board_ark", "noah_06_flood_dove"] else Vector3(-16.0, 0.65, 0.4)
		family[0].global_position = world.ark_anchor.to_global(noah_fp_local)
		cam_ctrl.first_person_mode = true
		cam_ctrl.fp_yaw = -PI * 0.48
		cam_ctrl.fp_pitch = 0.02
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68, 0.0))
		cam_ctrl._apply_camera_transform()
		family[0].hide()
	else:
		cam_ctrl.first_person_mode = false
		fp_exit_cooldown = 1.6
		noah_deck = 0
		if id == "noah_06_flood_dove":
			# During the Flood, Noah remains safely inside the Ark while camera returns to exterior sea view!
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
	fp_btn.text = "退出第一人称 [F]" if first_person_interior else "第一人称进舱 [F]"
	_refresh_whisper_hud()


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


func _compute_ark_vis_stage() -> int:
	var id: String = str(current_event.get("id", ""))
	if id == "noah_01_revelation":
		return 0
	var base_stage: int = int(current_event.get("arkStage", 0))
	var pct_stage: int = 1
	if ark_build_pct >= 75.0:
		pct_stage = 3
	elif ark_build_pct >= 35.0:
		pct_stage = 2
	return maxi(base_stage, pct_stage)


func _apply_ark_visibility() -> void:
	var id: String = str(current_event.get("id", ""))
	var vis_stage: int = _compute_ark_vis_stage()
	last_ark_vis_stage = vis_stage
	world.set_ark_stage(vis_stage, interior_cutaway, id == "noah_06_flood_dove")


func _enter_event(id: String) -> void:
	if not event_index.has(id):
		return
	current_event = event_index[id]
	crisis_resolved = false
	flood_failed = false
	noah_has_click_target = false
	noah_busy_timer = 0.0
	noah_deck = 0
	modal_overlay.hide()
	_clear_hotspots()

	var stage: int = int(current_event.get("arkStage", 0))
	state.arkStage = stage
	# Restore any Ark-parented family/animals back to world before staging the new act!
	_restore_all_to_world()
	# Cleanly exit First-Person mode whenever advancing to a new act (unless launched with --first-person / --flood-fp)
	var keep_fp_preview: bool = preview_mode and ((id == "noah_03_hull_decks") or (id == "noah_06_flood_dove"))
	if first_person_interior and not keep_fp_preview:
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
	if id == "noah_03_hull_decks":
		fence_building = false
		if preview_mode and not first_person_interior and not interior_cutaway:
			# Showcase live Age of Empires clash: 72% built Palisade + 3 Shield Guards vs 5 Torch Raiders!
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
			var rx: float = -21.0 + float(i) * 3.8
			var rz: float = 24.4 if (preview_mode and not first_person_interior) else (44.0 + float(i % 2) * 3.2)
			raiders[i].position = world.grounded(rx, rz)
			raiders[i].look_at(world.grounded(rx, 18.0), Vector3.UP)
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
			SoundManager.stop_ambience()
			SoundManager.play_sfx("sfx_covenant_chime.wav", -6.0, 0.0)
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
			elif preview_mode:
				# Dramatic AoE clash angle framing the 5 torch raiders, rising Palisade & Shield-Wall defenders!
				family[0].position = world.grounded(-10.5, 20.6)
				family[0].look_at(world.grounded(-12.0, 26.0), Vector3.UP)
				_set_actor_props(family[0], false, true, true)
				_anim(family[0], "Brawl")
				cam_ctrl.pitch_override = -0.34
				cam_ctrl.focus_on(Vector3(-12.5, 1.8, 22.0), 22.0, 0.36, true)
				_update_living_family(0.016, id)
				_update_raider_conflict(0.016)
			else:
				family[0].position = world.grounded(-6.0, 20.5)
				cam_ctrl.focus_on(Vector3(-8.0, 3.2, 18.0), 42.0, 0.25, preview_mode)
			_add_hotspot("inside_lower", ap + Vector3(-8.0, 0.65, 0.0), "检查下层龙骨榫卯与大型畜栏", "Hammer")
			_add_hotspot("inside_mid", ap + Vector3(15.5, 3.95, 0.0), "沿中央木梯上中层检查分舱隔间", "Hammer")
			_add_hotspot("defend_yard", world.grounded(-12.5, 21.2), "亲临南坡盾阵鼓舞士气（筑栅/击退强人）", "Bless")
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
			world.rain.emitting = true
			SoundManager.play_ambience("sfx_rain_loop.wav", -10.0)
			SoundManager.play_sfx("sfx_thunder.wav", -5.0)
			flood_countdown = 0.0
			cam_ctrl.pitch_override = -0.26
			_init_auto_boarding()
			cam_ctrl.focus_on(Vector3(0.0, 2.8, 15.5), 34.0, -0.34, preview_mode)
			if preview_mode:
				# Advance 2.8s so screenshot shows family & pairs of animals actively streaming up the gangplank!
				for _step in range(56):
					_update_auto_boarding(0.05)
			_add_hotspot("seal_door", ap + Vector3(0.0, 0.65, 12.0), "立即关上舱门起航（全员入舱亦将自动封门）", "Bless")

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
			# Keep ALL 7 family members & ALL 10 realistic animals ALIVE inside the Ark stalls & decks!
			_stage_all_inside_ark()
			if first_person_interior and preview_mode:
				noah_deck = 0
				noah_fp_local = Vector3(-26.0, 0.65, 0.4)
				family[0].hide()
				cam_ctrl.first_person_mode = true
				cam_ctrl.fp_yaw = -PI * 0.48
				cam_ctrl.fp_pitch = 0.01
				cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68, 0.0))
				cam_ctrl._apply_camera_transform()
			else:
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
			# Low upward-tilted vista framing the family altar, 100% completed 102m Ark & full Covenant Rainbow in open sky!
			cam_ctrl.pitch_override = -0.10 if id == "noah_08_rainbow_covenant" else -0.20
			cam_ctrl.focus_on(Vector3(-1.0, 9.0, 6.0), 64.0, -0.24, preview_mode)
			if id == "noah_07_exit_altar":
				_add_hotspot("offer_altar", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "一家八口筑坛献祭感恩", "Bless")
			else:
				_add_hotspot("to_overworld", world.altar_group.position + Vector3(0.0, 0.0, -2.0), "仰望彩虹永约 · 前往宏观画卷", "Bless")

	_sync_hotspot_labels()
	_refresh_whisper_hud()


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


func _avg_raider_morale() -> float:
	if raider_morale.is_empty():
		return 0.0
	var s: float = 0.0
	for m in raider_morale:
		s += maxf(0.0, m)
	return s / float(raider_morale.size())


func _refresh_whisper_hud() -> void:
	var id: String = str(current_event.get("id", ""))
	var is_build_act: bool = id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]
	var hide_top: bool = bool(current_event.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	top_obj_panel.visible = not hide_top or first_person_interior
	strategy_panel.visible = is_build_act and not first_person_interior
	if fence_cmd_btn != null:
		var show_fcmd: bool = (id == "noah_03_hull_decks" and not crisis_resolved)
		fence_cmd_btn.visible = show_fcmd
		if show_fcmd:
			if fence_building:
				fence_cmd_btn.text = "正在逐段修筑木栅... (%d%%)" % int(roundf(fence_build_pct))
			elif fence_build_pct < 100.0:
				fence_cmd_btn.text = "逐段修筑木栅防线 (-40木)"
			elif fence_hp < fence_max_hp - 10.0:
				fence_cmd_btn.text = "抢修受损木栅 (-20木 | %d/%d)" % [int(fence_hp), int(fence_max_hp)]
			else:
				fence_cmd_btn.text = "木栅防线已完工 (%d/%d)" % [int(fence_hp), int(fence_max_hp)]
	if first_person_interior:
		var fp_extra: String = "（舱内可巡视已登舟家人与活物！）" if id in ["noah_05_board_ark", "noah_06_flood_dove"] else "（主道直通后舱 · 靠北木梯上下层）"
		top_obj_label.text = "第一人称船舱（第%d层）%s  |  WASD 行走 · 拖动/方向键 360° 环视 · [F] 退出" % [noah_deck + 1, fp_extra]
	elif id == "noah_06_flood_dove":
		top_obj_label.text = "洪水滔天 · 方舟蒙神保守漂流于渊面  |  按 [F] 可第一人称进舱查看家人与活物  |  按 [E] 放鸽探看水退"
	elif id == "noah_05_board_ark":
		var fam_in: int = 0
		for b in family_boarded:
			if b:
				fam_in += 1
		var ani_in: int = 0
		for b in animal_boarded:
			if b:
				ani_in += 1
		top_obj_label.text = "距洪水: 0天（倾盆大雨）  |  全员自动登舟: %d/%d  |  活物自动入舱: %d/%d  |  按 [F] 进舱查看" % [
			fam_in, family.size(), ani_in, animals.size()
		]
	else:
		var boost_tag: String = "  [宗师监造+60%]" if inspection_boost_timer > 0.0 else ""
		var raid_tag: String = ""
		if id == "noah_03_hull_decks" and not crisis_resolved:
			raid_tag = "  |  木栅:%d/%d  |  强人士气:%d%%" % [int(fence_hp), int(fence_max_hp), int(roundf(_avg_raider_morale()))]
		var alert_tag: String = ("  |  " + strategy_alert) if not strategy_alert.is_empty() else ""
		top_obj_label.text = "距洪水: %d天  |  工程: %d%%  |  歌斐木: %d  |  松香: %d  |  粮草: %d%s%s%s" % [
			int(maxf(flood_countdown, 0.0)),
			int(roundf(ark_build_pct)),
			int(timber_f),
			int(pitch_f),
			int(provisions_f),
			boost_tag,
			raid_tag,
			alert_tag,
		]
	if strategy_labels.has("log"):
		(strategy_labels["log"] as Label).text = "东坡伐木: %d人 (+%d木/s)" % [w_log, w_log * 4]
		(strategy_labels["build"] as Label).text = "船坞建舟: %d人 (耗%d木/s)" % [w_build, w_build * 3]
		(strategy_labels["pitch"] as Label).text = "松香备粮: %d人 (+%d漆/s)" % [w_pitch, w_pitch * 2]
		(strategy_labels["guard"] as Label).text = "盾阵守望: %d人 (%s)" % [w_guard, "严阵以待" if w_guard >= 2 else "防线薄弱!"]
	subtitle_label.text = "【%s · %s】%s" % [
		str(current_event.get("speakerZh", "")),
		str(current_event.get("canonRef", "")),
		str(current_event.get("bodyZh", "")),
	]


func _trigger_active_hotspot() -> void:
	if modal_overlay.visible:
		return
	if not active_hotspot.is_empty():
		_trigger_hotspot(active_hotspot)
	elif hotspots.size() == 1 and not bool(hotspots[0].done):
		_trigger_hotspot(hotspots[0])


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
			_trigger_active_hotspot()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# In First-Person mode, Left-drag is dedicated to 360-degree look (use [E] or click the [E] button to interact!)
		if first_person_interior:
			return
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
					if (family[0].visible or first_person_interior) and family[0].position.distance_to(hp) > 3.2:
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


func _start_fence_work() -> void:
	var id: String = str(current_event.get("id", ""))
	if id != "noah_03_hull_decks" or crisis_resolved:
		return
	if fence_building:
		strategy_alert = "家人正逐段抢筑木栅（%d%%），可增派守望/建舟加快！" % int(roundf(fence_build_pct))
		_refresh_whisper_hud()
		return
	if fence_build_pct >= 100.0 and fence_hp >= fence_max_hp - 10.0:
		strategy_alert = "木栅防线完好！请派盾阵守望或亲临南坡击溃强人士气！"
		_refresh_whisper_hud()
		return
	var cost: float = 40.0 if fence_build_pct < 100.0 else 20.0
	if timber_f < cost:
		strategy_alert = "歌斐木不足 %d，无法动工筑栅！请先增派东坡伐木！" % int(cost)
		SoundManager.play_sfx("sfx_alert.wav", -5.0)
		_refresh_whisper_hud()
		return
	timber_f -= cost
	fence_building = true
	SoundManager.play_sfx("sfx_hammer.wav", -4.0)
	strategy_alert = "已下令逐段修筑木栅防线！工人与盾阵守望正奔赴南坡施工！"
	_refresh_whisper_hud()


func _trigger_hotspot(h: Dictionary) -> void:
	if bool(h.done):
		return
	var hid: String = str(h.id)
	if hid == "defend_yard" and not crisis_resolved:
		# Age of Empires-style real-time command & shield-wall rally (NEVER instant popup!)
		if fence_hp <= 0.0 and not fence_building and timber_f >= 40.0:
			_start_fence_work()
		if rally_cooldown <= 0.0:
			rally_cooldown = 5.0
			noah_busy_timer = 1.2
			noah_busy_clip = "Brawl"
			SoundManager.play_sfx("sfx_hammer.wav", -3.0)
			for i in range(raider_morale.size()):
				if raider_morale[i] > 0.0:
					raider_morale[i] = maxf(0.0, raider_morale[i] - 22.0)
			if fence_hp > 0.0:
				fence_hp = minf(fence_max_hp, fence_hp + 28.0)
			strategy_alert = "挪亚高声喝止并稳住盾阵！强人士气动摇！"
		else:
			strategy_alert = "盾阵正在激战中！增派【盾阵守望】或修筑木栅击溃强人士气！"
		_refresh_whisper_hud()
		return
	h.done = true
	var n: Node3D = h.get("node") as Node3D
	if n != null and is_instance_valid(n):
		n.hide()
	noah_busy_timer = 1.1
	noah_busy_clip = str(h.get("clip", "Hammer"))
	SoundManager.play_sfx("sfx_hammer.wav" if noah_busy_clip == "Hammer" else "sfx_ui_click.wav", -4.0)
	# Pure +60% Master Shipwright efficiency boost — NO magic free timber/progress handout!
	inspection_boost_timer = 22.0
	if family[0].visible:
		_anim(family[0], noah_busy_clip)
	_refresh_whisper_hud()
	_check_act_complete()


func _open_flood_fail_modal() -> void:
	if flood_failed:
		return
	flood_failed = true
	world.rain.emitting = true
	SoundManager.play_sfx("sfx_thunder.wav", -3.0)
	modal_overlay.show()
	modal_title.text = "距洪水 0 天 · 倾盆大雨已至"
	modal_body.text = "倒计时已归零（0 天），暴雨倾盆而下！当前工程 %d%%，松香 %d，粮草 %d。你可以立即下令紧急封顶，让全员与动物自动登舟入舱，或重整分工重新备料建造：" % [
		int(roundf(ark_build_pct)), int(pitch_f), int(provisions_f)
	]
	for c in modal_choices.get_children():
		modal_choices.remove_child(c)
		c.queue_free()
	modal_choices.add_child(_make_pill("全员与动物立刻自动登舟入舱避洪", func() -> void:
		ark_build_pct = 100.0
		flood_failed = false
		modal_overlay.hide()
		_enter_event("noah_05_board_ark")
	))
	modal_choices.add_child(_make_pill("重整家族分工 · 重新备料建造本幕", func() -> void:
		flood_countdown = 240.0
		flood_failed = false
		timber_f = maxf(timber_f, 55.0)
		world.rain.emitting = false
		modal_overlay.hide()
		_enter_event(str(current_event.get("id", "noah_02_keel_mortise")))
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
	if id == "noah_03_hull_decks":
		if not crisis_resolved:
			strategy_alert = "尚有强人袭扰南坡！请筑栅并派盾阵守望彻底击溃其士气！"
			_refresh_whisper_hud()
			return
		if ark_build_pct < 70.0:
			strategy_alert = "三层船壳需达 70%%（当前 %d%%），请调度家人抓紧施工！" % int(ark_build_pct)
			_refresh_whisper_hud()
			return
	if id == "noah_04_pitch_provisions" and (ark_build_pct < 98.0 or pitch_f < 25.0 or provisions_f < 80.0):
		strategy_alert = "登舟门槛：工程 ≥98%%、松香 ≥25、粮草 ≥80（当前 %d%%/%d/%d）" % [int(ark_build_pct), int(pitch_f), int(provisions_f)]
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
	var vis_stage: int = _compute_ark_vis_stage()
	# Exact 1:1 Biblical 102m x 17m x 10.2m Ark Interior Floors + Side-Mounted North Staircases!
	# Walking along the wide 4.3m Main Corridor (rel_z > -1.15) goes STRAIGHT PAST every staircase to the East Rear Cabin!
	if vis_stage >= 2 and absf(x - ap.x) < 49.5 and z > ap.z - 8.0 and z < ap.z + 8.0:
		var rel_x: float = x - ap.x
		var rel_z: float = z - ap.z
		var on_north_stair_aisle: bool = (rel_z <= -1.15 and rel_z >= -3.15)
		# North Stair 1 (X=2.5..13.5, Z in [-3.15, -1.15]): Lower Deck (0.65m) <-> Middle Deck (3.95m)
		if on_north_stair_aisle and rel_x >= 2.5 and rel_x <= 13.5 and noah_deck <= 1:
			var s1: float = clampf((rel_x - 2.5) / 11.0, 0.0, 1.0)
			if s1 < 0.25:
				noah_deck = 0
			elif s1 > 0.75:
				noah_deck = 1
			return lerpf(ap.y + 0.65, ap.y + 3.95, s1)
		# North Stair 2 (X=18.5..29.5, Z in [-3.15, -1.15]): Middle Deck (3.95m) <-> Upper Deck (7.15m)
		if on_north_stair_aisle and rel_x >= 18.5 and rel_x <= 29.5 and noah_deck >= 1:
			var s2: float = clampf((rel_x - 18.5) / 11.0, 0.0, 1.0)
			if s2 < 0.25:
				noah_deck = 1
			elif s2 > 0.75:
				noah_deck = 2
			return lerpf(ap.y + 3.95, ap.y + 7.15, s2)
		if noah_deck == 2:
			return ap.y + 7.15
		if noah_deck == 1:
			return ap.y + 3.95
		return ap.y + 0.65
	# Exterior Boarding Gangplank Ramp (+Z side, Z=8.0..19.5)
	if vis_stage >= 2 and absf(x - ap.x) < 2.8 and z >= ap.z + 8.0 and z <= ap.z + 19.8:
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
	var noah_near_fence: bool = noah.visible and noah.position.z > 16.5 and noah.position.z < 28.0 and absf(noah.position.x + 12.5) < 16.0

	# 1. Age of Empires-style Progressive Palisade Construction (0% -> 100% over real time!)
	if fence_building:
		var builders: int = maxi(1, w_guard + mini(w_build, 2))
		var build_rate: float = 5.5 + float(builders) * 3.4 + (4.5 if noah_near_fence else 0.0)
		if fence_build_pct < 100.0:
			fence_build_pct = minf(100.0, fence_build_pct + build_rate * delta)
			fence_hp = minf(fence_max_hp, fence_hp + build_rate * 3.0 * delta)
			world.set_fence_progress(fence_build_pct)
			if fence_build_pct >= 100.0:
				fence_building = false
				state.guardFence = true
				fence_hp = fence_max_hp
				SoundManager.play_sfx("sfx_covenant_chime.wav", -5.0)
		else:
			fence_hp = minf(fence_max_hp, fence_hp + (build_rate * 4.2) * delta)
			world.set_fence_progress(maxf(20.0, fence_hp / fence_max_hp * 100.0))
			if fence_hp >= fence_max_hp:
				fence_building = false

	# 2. Update Palisade 3D Overhead HP / Construction Bar
	if fence_status_root != null:
		fence_status_root.visible = not first_person_interior and not crisis_resolved
		if fence_building and fence_build_pct < 100.0:
			fence_status_label.text = "正在逐段修筑木栅 %d%%" % int(roundf(fence_build_pct))
			_update_bar_visual(fence_hp_bar, fence_build_pct / 100.0, Color(0.95, 0.76, 0.24), Color(0.95, 0.50, 0.16))
		elif fence_hp > 0.0:
			fence_status_label.text = "木栅防线耐久 %d/%d" % [int(roundf(fence_hp)), int(fence_max_hp)]
			_update_bar_visual(fence_hp_bar, fence_hp / fence_max_hp, Color(0.28, 0.86, 0.42), Color(0.92, 0.24, 0.18))
		else:
			fence_status_label.text = "南坡无木栅防护！（点击左下筑栅）"
			_update_bar_visual(fence_hp_bar, 0.02, Color(0.92, 0.24, 0.18), Color(0.92, 0.24, 0.18))

	# 3. 5 Torch-Bearing Raiders Advance, Smash Palisade OR Breach Timber Depot, Clash vs Shield Guards!
	var active_raiders: int = 0
	var engaged_raiders: int = 0
	for i in range(raiders.size()):
		var r: Node3D = raiders[i]
		var morale: float = raider_morale[i]
		var rx_slot: float = -21.0 + float(i) * 3.8
		if morale <= 0.0:
			# Morale Broken -> Visibly Rout back down the South valley road!
			var flee_pt: Vector3 = world.grounded(rx_slot * 0.6, 56.0)
			if r.position.distance_to(flee_pt) > 0.6:
				r.position = r.position.move_toward(flee_pt, delta * 5.2)
				r.look_at(flee_pt, Vector3.UP)
				_anim(r, "Run")
			else:
				_anim(r, "Idle")
			raider_labels[i].text = "士气溃散 · 逃离!"
			_update_bar_visual(raider_bars[i], 0.0, Color(0.8, 0.2, 0.2), Color(0.5, 0.5, 0.5))
			continue

		active_raiders += 1
		var target_z: float = 23.7 if fence_hp > 0.0 else 16.4
		var target_x: float = rx_slot if fence_hp > 0.0 else (-18.0 + float(i) * 1.4)
		var tg: Vector3 = world.grounded(target_x, target_z)
		if r.position.distance_to(tg) > 0.65:
			r.position = r.position.move_toward(tg, delta * 3.6)
			r.look_at(tg, Vector3.UP)
			_anim(r, "Run")
		else:
			engaged_raiders += 1
			r.look_at(world.grounded(target_x, 12.0), Vector3.UP)
			_anim(r, "Slash" if i % 2 == 0 else "Brawl")
			if fence_hp > 0.0:
				var dmg_mul: float = 0.65 if noah_near_fence else 1.0
				fence_hp = maxf(0.0, fence_hp - 2.6 * dmg_mul * delta)
				if not fence_building:
					world.set_fence_progress(maxf(0.0, fence_hp / fence_max_hp * 100.0))
				if fence_hp <= 0.0:
					strategy_alert = "警告：木栅被攻破！强人正冲向歌斐木料堆！"
					SoundManager.play_sfx("sfx_alert.wav", -4.0)
			else:
				timber_f = maxf(0.0, timber_f - 1.8 * delta)
				strategy_alert = "防线失守！强人正在木料堆强抢歌斐木！"

			# Guard Shield-Wall + Noah Rally Counter-Pressure drains Raider Morale in real time!
			var guard_dps: float = float(w_guard) * 4.8 + (10.5 if noah_near_fence else 0.0)
			if fence_hp > 0.0 and w_guard > 0:
				guard_dps *= 1.35  # Fighting behind a Palisade holds the line much better!
			if guard_dps > 0.0:
				raider_morale[i] = maxf(0.0, raider_morale[i] - (guard_dps / float(maxi(1, engaged_raiders))) * delta)

		raider_labels[i].text = "强人士气 %d%%" % int(roundf(raider_morale[i]))
		_update_bar_visual(raider_bars[i], raider_morale[i] / 100.0, Color(0.95, 0.30, 0.18), Color(0.96, 0.72, 0.22))

	if engaged_raiders > 0 and raider_clash_sfx_timer <= 0.0 and not preview_mode:
		raider_clash_sfx_timer = 1.6
		SoundManager.play_sfx("sfx_hammer.wav", -8.0)

	# 4. Victory condition: All 5 Raiders' Morale broken -> Complete defend_yard hotspot cleanly!
	if active_raiders == 0 and not crisis_resolved:
		crisis_resolved = true
		SoundManager.play_sfx("sfx_covenant_chime.wav", -4.0)
		strategy_alert = "强人士气溃散撤退！木料堆转危为安！"
		for h in hotspots:
			if str(h.id) == "defend_yard" and not bool(h.done):
				h.done = true
				var hn: Node3D = h.get("node") as Node3D
				if hn != null and is_instance_valid(hn):
					hn.hide()
		_check_act_complete()


func _process(delta: float) -> void:
	elapsed += delta
	if fp_exit_cooldown > 0.0:
		fp_exit_cooldown -= delta
	var id: String = str(current_event.get("id", ""))
	var noah: Node3D = family[0]

	# 1. Direct-Control Noah: First-Person works inside the Ark even during Boarding (noah_05) & The Flood (noah_06)!
	if not modal_overlay.visible and first_person_interior and id != "noah_01_revelation":
		var move_dir: Vector3 = Vector3.ZERO
		var yaw: float = cam_ctrl.fp_yaw
		var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
		var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
		if Input.is_key_pressed(KEY_W):
			move_dir += fwd
		if Input.is_key_pressed(KEY_S):
			move_dir -= fwd
		if Input.is_key_pressed(KEY_A):
			move_dir -= right
		if Input.is_key_pressed(KEY_D):
			move_dir += right
		if move_dir.length_squared() > 0.01:
			move_dir = move_dir.normalized()
			var fp_spd: float = 6.4 if Input.is_key_pressed(KEY_SHIFT) else 4.0
			var lp: Vector3 = noah_fp_local + move_dir * fp_spd * delta
			lp.x = clampf(lp.x, -46.5, 46.5)
			var can_exit_door: bool = (id != "noah_06_flood_dove" and noah_deck == 0 and absf(lp.x) < 2.6)
			var max_z: float = 9.2 if can_exit_door else 3.0
			lp.z = clampf(lp.z, -3.0, max_z)
			# Compute local deck height using side-mounted North stairs
			var on_stair: bool = (lp.z <= -1.15 and lp.z >= -3.15)
			if on_stair and lp.x >= 2.5 and lp.x <= 13.5 and noah_deck <= 1:
				var s1: float = clampf((lp.x - 2.5) / 11.0, 0.0, 1.0)
				if s1 < 0.25:
					noah_deck = 0
				elif s1 > 0.75:
					noah_deck = 1
				lp.y = lerpf(0.65, 3.95, s1)
			elif on_stair and lp.x >= 18.5 and lp.x <= 29.5 and noah_deck >= 1:
				var s2: float = clampf((lp.x - 18.5) / 11.0, 0.0, 1.0)
				if s2 < 0.25:
					noah_deck = 1
				elif s2 > 0.75:
					noah_deck = 2
				lp.y = lerpf(3.95, 7.15, s2)
			elif noah_deck == 2:
				lp.y = 7.15
			elif noah_deck == 1:
				lp.y = 3.95
			else:
				lp.y = 0.65
			noah_fp_local = lp
			if can_exit_door and lp.z > 8.6:
				_toggle_first_person()
		noah.global_position = world.ark_anchor.to_global(noah_fp_local)
		var bob_y: float = sin(elapsed * 6.0) * (0.03 if move_dir.length_squared() > 0.01 else 0.0)
		cam_ctrl.fp_eye_pos = world.ark_anchor.to_global(noah_fp_local + Vector3(0.0, 1.68 + bob_y, 0.0))
	elif not modal_overlay.visible and id not in ["noah_01_revelation", "noah_05_board_ark", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		var move_dir: Vector3 = Vector3.ZERO
		if noah.visible and not camera_free_mode:
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

			# Equip Wooden Shield on Noah automatically when standing near the South Defense Line during the raid!
			var noah_defending: bool = (id == "noah_03_hull_decks" and not crisis_resolved and noah.position.z > 16.5)
			_set_actor_props(noah, false, true, noah_defending)

			# Auto-enter First-Person Interior cleanly when Noah walks through the +Z doorway (respecting cooldown!)
			var ap: Vector3 = world.ark_anchor.position
			if fp_exit_cooldown <= 0.0 and _compute_ark_vis_stage() >= 2 and absf(noah.position.x - ap.x) < 48.0 and noah.position.z < ap.z + 7.8 and noah.position.z > ap.z - 8.0 and not manual_cutaway_lock:
				_toggle_first_person()

			cam_ctrl.focus_on(noah.position + Vector3(0.0, 1.6, 0.0), -1.0, NAN, false)

	# 1b. Live Real-Time RTS Economy, Progressive Ark Hull Completion & Flood Countdown Failure!
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"] and not modal_overlay.visible:
		flood_countdown = maxf(0.0, flood_countdown - delta)
		if inspection_boost_timer > 0.0:
			inspection_boost_timer -= delta
		timber_f += float(w_log) * 4.0 * delta
		pitch_f += float(w_pitch) * 2.0 * delta
		provisions_f += float(w_pitch) * 1.6 * delta
		var timber_need: float = float(w_build) * 3.0 * delta
		strategy_alert = ""
		if timber_f >= timber_need and w_build > 0:
			timber_f -= timber_need
			var boost: float = 1.6 if inspection_boost_timer > 0.0 else 1.0
			ark_build_pct = minf(100.0, ark_build_pct + float(w_build) * 1.4 * boost * delta)
		elif w_build > 0:
			strategy_alert = "歌斐木不足！请加派人手东坡伐木"

		# Update visible 3D Ark structure IMMEDIATELY when ark_build_pct hits 35% / 75% / 100%!
		var new_vis: int = _compute_ark_vis_stage()
		if new_vis != last_ark_vis_stage:
			_apply_ark_visibility()
			SoundManager.play_sfx("sfx_covenant_chime.wav", -5.0)
		if ark_build_pct >= 100.0 and not ark_completed_chime_played:
			ark_completed_chime_played = true
			SoundManager.play_sfx("sfx_covenant_chime.wav", -3.0)

		if flood_countdown <= 0.0 and not preview_mode:
			if ark_build_pct >= 95.0:
				# 0 Days reached & Ark is ready -> Immediately auto-board ALL 8 family members & ALL animals!
				ark_build_pct = 100.0
				_enter_event("noah_05_board_ark")
				return
			else:
				_open_flood_fail_modal()
		state.timber = int(timber_f)
		_check_act_complete()
		_refresh_whisper_hud()

	# 2. Check proximity to 3D Hotspots for clickable [E] Button + pulse rings
	active_hotspot = {}
	for h in hotspots:
		if bool(h.done):
			continue
		var ring: MeshInstance3D = h.get("ring") as MeshInstance3D
		if ring != null:
			var s: float = 1.0 + sin(elapsed * 3.5) * 0.09
			ring.scale = Vector3(s, 1.0, s)
		if (noah.visible or first_person_interior) and noah.position.distance_to(h.pos) < 4.8:
			active_hotspot = h
	if not active_hotspot.is_empty():
		interact_prompt.show()
		interact_prompt.text = "[E] %s" % str(active_hotspot.label)
	elif hotspots.size() == 1 and id in ["noah_01_revelation", "noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		interact_prompt.show()
		interact_prompt.text = "[E] %s" % str(hotspots[0].label)
	else:
		interact_prompt.hide()

	# 3. Living AI Family (Sons haul REAL logs, hammer Ark ribs, build Palisade & form Shield Wall!)
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks", "noah_04_pitch_provisions"]:
		_update_living_family(delta, id)

	# 4. Live Villagers, Deserting Hired Workers & Age of Empires 5-Raider Conflict!
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
		if ark_build_pct >= 20.0:
			for i in range(hired_workers.size()):
				var hw: Node3D = hired_workers[i]
				var away: Vector3 = world.grounded(2.0 + float(i) * 2.5, 48.0)
				if hw.position.distance_to(away) > 0.5:
					hw.position = hw.position.move_toward(away, delta * 3.0)
					hw.look_at(away, Vector3.UP)
					_anim(hw, "Walk")
	elif id == "noah_03_hull_decks":
		_update_raider_conflict(delta)

	# 5. Full Automatic Boarding Sequence (0 Days / noah_05_board_ark): ALL 8 Family Members + ALL Animals Enter Ark!
	if id == "noah_05_board_ark":
		_update_auto_boarding(delta)
		_refresh_whisper_hud()

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
		var bird_y: float = world.ark_anchor.position.y + 13.5 + float(i) * 1.4 + sin(a * 2.0) * 0.6
		var bp: Vector3 = Vector3(-1.0 + cos(a) * (12.0 + float(i) * 3.5), bird_y, -3.0 + sin(a) * 8.0)
		var tan_v: Vector3 = Vector3(-sin(a) * 10.0, cos(a * 2.0) * 0.8, cos(a) * 6.0)
		b.position = bp
		b.look_at(bp + tan_v, Vector3.UP)
		b.rotation.z = sin(a) * 0.16


func _update_living_family(_delta: float, id: String) -> void:
	var assigned: int = 0
	var guard_slot: int = 0
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
				_set_actor_props(member, not going_back, false, false)
				_anim(member, "Walk")
			"build":
				if id == "noah_03_hull_decks" and fence_building and k <= 3:
					# Builders rush down to hammer the Palisade segments up in real time!
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
				_set_actor_props(member, false, false, false)
				_anim(member, "Walk")
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
		# Noah is represented by player camera when in First-Person, or stands at the bow corridor
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
		[Vector3(-16.2, 0.65, -2.0), Vector3(-16.2, 0.65, -5.2), "Idle"],   # 1: Wife tending sheep & bulls
		[Vector3(-11.8, 0.65, 2.0), Vector3(-11.8, 0.65, 5.2), "Idle"],     # 2: Son 1 tending horses
		[Vector3(-4.8, 0.65, -1.9), Vector3(-4.8, 0.65, -5.2), "Idle"],     # 3: Son 2 watching lion stall
		[Vector3(16.0, 3.95, 0.8), Vector3(0.0, 3.95, 0.8), "Idle"],        # 4: Son 3 on Middle Deck
		[Vector3(-19.5, 0.65, 2.0), Vector3(-19.5, 0.65, 5.0), "Pray"],     # 5: Daughter 1 praying beside deer
		[Vector3(-7.5, 3.95, 0.6), Vector3(-16.0, 3.95, 0.6), "Pray"],      # 6: Daughter 2 praying on Middle Deck
		[Vector3(8.0, 3.95, 1.0), Vector3(0.0, 3.95, 1.0), "Idle"],         # 7: Daughter 3 tending Middle Deck
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
	# 10 Realistic Animals settled inside Lower Deck Port (-Z) & Starboard (+Z) Biblical Timber Stalls!
	var stalls: Array[Array] = [
		[Vector3(-21.2, 0.65, -4.9), Vector3(-21.2, 0.65, 0.0)],  # 0: Sheep 1 (Port)
		[Vector3(-19.3, 0.65, -4.9), Vector3(-19.3, 0.65, 0.0)],  # 1: Sheep 2 (Port)
		[Vector3(-13.8, 0.65, -5.1), Vector3(-13.8, 0.65, 0.0)],  # 2: Bull 1 (Port)
		[Vector3(-11.0, 0.65, -5.1), Vector3(-11.0, 0.65, 0.0)],  # 3: Bull 2 (Port)
		[Vector3(-13.8, 0.65, 5.1), Vector3(-13.8, 0.65, 0.0)],   # 4: Horse 1 (Starboard)
		[Vector3(-11.0, 0.65, 5.1), Vector3(-11.0, 0.65, 0.0)],   # 5: Horse 2 (Starboard)
		[Vector3(-21.2, 0.65, 4.9), Vector3(-21.2, 0.65, 0.0)],   # 6: Deer 1 (Starboard)
		[Vector3(-19.3, 0.65, 4.9), Vector3(-19.3, 0.65, 0.0)],   # 7: Deer 2 (Starboard)
		[Vector3(-5.6, 0.65, -5.1), Vector3(-5.6, 0.65, 0.0)],    # 8: Lion 1 (Port)
		[Vector3(-3.2, 0.65, -5.1), Vector3(-3.2, 0.65, 0.0)],    # 9: Lion 2 (Port)
	]
	var cfg: Array = stalls[mini(i, stalls.size() - 1)]
	var ani: Node3D = animals[i]
	if ani.get_parent() != world.ark_anchor:
		ani.reparent(world.ark_anchor, false)
	ani.position = cfg[0] as Vector3
	ani.look_at(world.ark_anchor.to_global(cfg[1] as Vector3), Vector3.UP)
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
		# Stagger pairs naturally along the approach road -> ramp -> Ark doorway
		animal_board_dist.append(-float(i / 2) * 3.6)


func _update_auto_boarding(delta: float) -> void:
	var ap: Vector3 = world.ark_anchor.position
	# 1. ALL 8 Family Members automatically walk/jog up the Wooden Gangplank & settle INSIDE the Ark!
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

	# 2. ALL 10 Realistic Animals automatically march two-by-two up the gangplank & settle into Ark Stalls!
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
			var dir: Vector3 = (boarding_path[j + 1] - boarding_path[j]).normalized()
			var p: Vector3 = boarding_path[j].lerp(boarding_path[j + 1], rem / maxf(segs[j], 0.01))
			p.x += -0.68 if i % 2 == 0 else 0.68
			if j < 2:
				p.y = world.terrain_height(p.x, p.z)
			p.y += absf(sin(elapsed * 6.5 + float(i))) * 0.04
			animal.position = p
			animal.look_at(p + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
			break

	# 3. Once ALL 8 family members AND ALL 10 animals are settled inside -> Auto-seal Ark door & launch Flood!
	if not preview_mode and fam_in >= family.size() and ani_in >= animals.size():
		boarding_complete_timer += delta
		if boarding_complete_timer >= 1.5:
			SoundManager.play_sfx("sfx_covenant_chime.wav", -4.0)
			_enter_event("noah_06_flood_dove")
