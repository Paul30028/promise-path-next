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
var camera_free_mode: bool = false

var hotspots: Array[Dictionary] = []  # {id, pos, label, done, node, ring}
var active_hotspot: Dictionary = {}

# Simulation State
var elapsed: float = 0.0
var crisis_resolved: bool = false
var flood_level: float = -10.5
var flood_target: float = -10.5
var preview_mode: bool = false

# Whisper-Clean HUD (ZERO giant right box, ZERO "+25%" button spam!)
var top_obj_panel: PanelContainer
var top_obj_label: Label
var interact_prompt: PanelContainer
var interact_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var subtitle_timer: float = 0.0
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
	var tool: Node3D = world.spawn_asset(glb_file, 0.42, Vector3(0.0, -0.14, -0.05), ba)
	tool.rotation_degrees = Vector3(85.0, 0.0, 0.0)


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
		var h: float = 1.68 if i == 0 else (1.56 if i == 1 or i >= 5 else 1.62)
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(0.0 + float(i) * 1.1, 5.5))
		actor.name = "Family_%d" % i
		family.append(actor)
		family_ai_phase.append(float(i) * 1.37)
		if i in [0, 4]:
			_attach_hand_tool(actor, "WPN_Mallet.glb")
		if i in [2, 3]:
			_attach_carried_log(actor)
		_anim(actor, "Idle")

	for i in range(2):
		var hw: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.58, world.grounded(13.0 + float(i) * 1.8, 1.5))
		_attach_hand_tool(hw, "WPN_Mallet.glb")
		hw.hide()
		hired_workers.append(hw)

	for i in range(4):
		var v: Node3D = world.spawn_asset("CHR_Abram_rigged.glb" if i % 2 == 0 else "CHR_Noah_Son_rigged.glb", 1.58, world.grounded(-2.5 + float(i) * 1.9, 25.0))
		v.hide()
		villagers.append(v)

	for i in range(3):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.62, world.grounded(-2.5 + float(i) * 2.3, 24.0))
		_add_torch(r)
		r.hide()
		raiders.append(r)

	animal_root = Node3D.new()
	animal_root.name = "AnimalProcession"
	add_child(animal_root)
	var species: Array[Dictionary] = [
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.92}, {"file": "CC0_Sheep_Grab3D.glb", "h": 0.90},
		{"file": "ANI_Ox.glb", "h": 1.38}, {"file": "ANI_Ox.glb", "h": 1.34},
		{"file": "ANI_Goat.glb", "h": 0.96}, {"file": "ANI_Goat.glb", "h": 0.94},
		{"file": "ANI_Donkey.glb", "h": 1.20}, {"file": "ANI_Donkey.glb", "h": 1.18},
	]
	for i in range(species.size()):
		world.spawn_asset(str(species[i].file), float(species[i].h), Vector3.ZERO, animal_root)
	animal_root.hide()

	var ap: Vector3 = world.ark_anchor.position
	var sc: float = world.ark_scale
	boarding_path = [
		world.grounded(3.2, 13.5),
		world.grounded(2.0, 7.2),
		ap + Vector3(0.0, 0.0, 6.4 * sc),
		ap + Vector3(0.0, 1.98 * sc, 2.5 * sc),
		ap + Vector3(0.0, 1.98 * sc, 1.6 * sc),
	]

	for bf: String in ["ANI_Raven.glb", "ANI_Dove_Olive.glb"]:
		var b: Node3D = world.spawn_asset(bf, 0.45, Vector3(0.0, 9.0, 0.0))
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

	# 2. Top-Right 2-Button View Control (Interior 360° Cutaway Toggle + Camera Mode)
	var tr_hb: HBoxContainer = HBoxContainer.new()
	tr_hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_hb.offset_left = -330
	tr_hb.offset_right = -14
	tr_hb.offset_top = 14
	tr_hb.offset_bottom = 54
	tr_hb.alignment = BoxContainer.ALIGNMENT_END
	tr_hb.add_theme_constant_override("separation", 8)
	layer.add_child(tr_hb)
	cutaway_btn = _make_pill("透视方舟内部 [V]", _toggle_cutaway)
	tr_hb.add_child(cutaway_btn)
	mode_btn = _make_pill("跟随挪亚 [Tab]", _toggle_camera_mode)
	tr_hb.add_child(mode_btn)

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
	lbl.font_size = 42
	lbl.pixel_size = 0.0065
	lbl.modulate = Color(1.0, 0.94, 0.76)
	lbl.outline_modulate = Color(0.08, 0.05, 0.03)
	lbl.outline_size = 10
	root.add_child(lbl)

	hotspots.append({"id": id, "pos": pos, "label": label, "clip": clip, "done": false, "node": root, "ring": ring})


func _toggle_cutaway() -> void:
	manual_cutaway_lock = not manual_cutaway_lock
	interior_cutaway = manual_cutaway_lock
	_apply_ark_visibility()
	cutaway_btn.text = "关闭内部透视 [V]" if interior_cutaway else "透视方舟内部 [V]"


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
			flood_target = -10.5
			for i in range(family.size()):
				family[i].visible = (i == 0)
			family[0].position = world.grounded(-1.0, 3.8)
			family[0].look_at(world.grounded(1.5, -8.0), Vector3.UP)
			_anim(family[0], "Pray")
			# Low cinematic angle looking past kneeling Noah into the soft golden god-ray & distant valley!
			cam_ctrl.pitch_override = -0.22
			cam_ctrl.focus_on(family[0].position + Vector3(1.5, 2.0, -3.0), 11.5, -0.52, preview_mode)
			_add_hotspot("accept_call", family[0].position + Vector3(0.0, 0.0, -1.8), "领受三百肘造舟天启", "Bless")

		"noah_02_keel_mortise":
			world.apply_mood("build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			family[0].position = world.grounded(-4.2, 3.8)
			_anim(family[0], "Idle")
			cam_ctrl.focus_on(family[0].position + Vector3(3.0, 1.5, -2.0), 22.0, -0.45, preview_mode)
			_add_hotspot("keel_west", world.grounded(-4.5, -1.2), "检查西段龙骨榫卯", "Hammer")
			_add_hotspot("keel_east", world.grounded(5.5, -1.2), "敲紧东段肋骨木楔", "Hammer")
			_add_hotspot("timber_check", world.grounded(-6.2, 3.6), "验收歌斐木料堆", "Idle")

		"noah_03_hull_decks":
			world.apply_mood("dusk_raid" if not interior_cutaway else "build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			if interior_cutaway and preview_mode:
				# Place Noah RIGHT INSIDE the 3-deck Ark on the Lower/Middle deck inspecting the stalls!
				family[0].position = ap + Vector3(-1.5, 0.55, -0.2)
				family[0].look_at(ap + Vector3(4.0, 0.55, -1.5), Vector3.UP)
				_anim(family[0], "Hammer")
				cam_ctrl.pitch_override = -0.28
				cam_ctrl.focus_on(ap + Vector3(0.0, 2.2, 0.0), 14.5, -0.28, true)
			else:
				family[0].position = world.grounded(1.0, 4.2)
				cam_ctrl.focus_on(family[0].position + Vector3(0.0, 1.5, -2.0), 22.0, -0.35, preview_mode)
			# 3D Walk-Inside Inspection Stations INSIDE the Ark + Raider Defense outside!
			_add_hotspot("inside_lower", ap + Vector3(-4.2, 0.55, -0.4), "入舱检查下层龙骨与畜栏", "Hammer")
			_add_hotspot("inside_mid", ap + Vector3(4.2, 0.55, -0.4), "检查分舱隔间与一肘透光带", "Hammer")
			_add_hotspot("defend_yard", world.grounded(-3.5, 7.2), "筑木栅与三子护材对峙", "Bless")

		"noah_04_pitch_provisions":
			world.apply_mood("build")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			family[0].position = world.grounded(5.0, 3.6)
			cam_ctrl.focus_on(family[0].position, 20.0, -0.42, preview_mode)
			_add_hotspot("pitch_inside", ap + Vector3(-2.5, 0.55, -0.3), "入舱检查内壁松香防水缝", "BrushPitch")
			_add_hotspot("pitch_outside", world.grounded(7.2, 2.8), "熬漆里外厚涂松香", "BrushPitch")
			_add_hotspot("provisions_check", world.grounded(9.2, 3.2), "清点干湿分区粮草陶罐", "Idle")

		"noah_05_board_ark":
			world.apply_mood("dusk_raid")
			cam_ctrl.pitch_override = NAN
			for m in family:
				m.show()
			family[0].position = world.grounded(-1.8, 5.2)
			cam_ctrl.focus_on(Vector3(1.0, 1.8, 3.5), 22.0, -0.38, preview_mode)
			_add_hotspot("seal_door", ap + Vector3(0.0, 0.55, 2.2), "引导众活物入舱并关上舱门", "Bless")

		"noah_06_flood_dove":
			world.apply_mood("flood")
			cam_ctrl.pitch_override = NAN
			flood_target = 4.2
			if preview_mode:
				flood_level = 3.9
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = flood_level - 0.45
			for m in family:
				m.hide()
			cam_ctrl.focus_on(Vector3(-1.0, 3.5, 2.0), 38.0, -0.52, preview_mode)
			_add_hotspot("release_dove", ap + Vector3(0.0, 4.8, 0.0), "放出乌鸦与鸽子探看水退", "Bless")

		"noah_07_exit_altar", "noah_08_rainbow_covenant":
			world.apply_mood("ararat")
			cam_ctrl.pitch_override = NAN
			flood_target = -10.5
			if preview_mode:
				flood_level = -10.5
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = world.ark_base_y
			_stage_ararat_worship()
			cam_ctrl.focus_on(Vector3(-1.5, 1.8, 4.0), 26.0, -0.52, preview_mode)
			if id == "noah_07_exit_altar":
				_add_hotspot("offer_altar", world.altar_group.position + Vector3(0.0, 0.0, -1.6), "一家八口筑坛献祭感恩", "Bless")
			else:
				_add_hotspot("to_overworld", world.altar_group.position + Vector3(0.0, 0.0, -1.6), "仰望彩虹永约 · 前往宏观画卷", "Bless")

	_refresh_whisper_hud()


func _stage_ararat_worship() -> void:
	var slots: Array[Vector2] = [
		Vector2(0.5, 4.6), Vector2(3.1, 5.8), Vector2(-2.2, 5.8), Vector2(-1.1, 4.8),
		Vector2(2.0, 4.8), Vector2(-1.2, 8.0), Vector2(2.1, 8.0), Vector2(3.6, 7.1),
	]
	for i in range(family.size()):
		family[i].show()
		family[i].position = world.grounded(slots[i].x, slots[i].y)
		var target: Vector3 = world.altar_group.position if i != 0 else (family[i].position + Vector3(0.0, 0.0, 5.0))
		target.y = family[i].position.y
		family[i].look_at(target, Vector3.UP)
		_anim(family[i], "Bless" if i == 0 else ("Pray" if i in [5, 6] else "Idle"))


func _refresh_whisper_hud() -> void:
	var id: String = str(current_event.get("id", ""))
	var hide_top: bool = bool(current_event.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	top_obj_panel.visible = not hide_top
	var done_cnt: int = 0
	for h in hotspots:
		if bool(h.done):
			done_cnt += 1
	top_obj_label.text = "%s  |  巡检进度: %d/%d  |  歌斐木: %d  |  WASD移动 · 右键360°环视 · [V]透视船舱 · [E]交互" % [
		str(current_event.get("titleZh", "")),
		done_cnt,
		hotspots.size(),
		int(state.get("timber", 0)),
	]
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
		if kc == KEY_V:
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
	if family[0].visible:
		_anim(family[0], noah_busy_clip)
	state.timber = int(state.get("timber", 0)) + 25
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
	match id:
		"noah_01_revelation": _enter_event("noah_02_keel_mortise")
		"noah_02_keel_mortise": _enter_event("noah_03_hull_decks")
		"noah_03_hull_decks": _enter_event("noah_04_pitch_provisions")
		"noah_04_pitch_provisions": _enter_event("noah_05_board_ark")
		"noah_05_board_ark": _enter_event("noah_06_flood_dove")
		"noah_06_flood_dove": _enter_event("noah_07_exit_altar")
		"noah_07_exit_altar": _enter_event("noah_08_rainbow_covenant")
		"noah_08_rainbow_covenant": get_tree().change_scene_to_file("res://scenes/overworld_prologue.tscn")


func _surface_height_for_noah(x: float, z: float) -> float:
	var ap: Vector3 = world.ark_anchor.position
	# Inside Ark Lower Deck!
	if int(state.get("arkStage", 0)) >= 2 and absf(x - ap.x) < 10.2 and z > ap.z - 2.2 and z < ap.z + 2.2:
		return ap.y + 0.55
	# Walking up the wooden boarding ramp (+Z side of Ark)!
	if int(state.get("arkStage", 0)) >= 2 and absf(x - ap.x) < 1.8 and z >= ap.z + 2.2 and z <= ap.z + 6.4:
		var t: float = clampf((z - (ap.z + 2.2)) / 4.2, 0.0, 1.0)
		return lerpf(ap.y + 0.55, world.terrain_height(x, z), t)
	return world.terrain_height(x, z)


func _process(delta: float) -> void:
	elapsed += delta
	var id: String = str(current_event.get("id", ""))
	var noah: Node3D = family[0]

	# 1. Direct-Control Noah (WASD / Click-to-Walk + Automatic Walk-Inside 3-Deck Cutaway!)
	if noah.visible and not modal_overlay.visible and id not in ["noah_01_revelation", "noah_07_exit_altar", "noah_08_rainbow_covenant"]:
		var move_dir: Vector3 = Vector3.ZERO
		if not camera_free_mode:
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
			var spd: float = 5.4 if Input.is_key_pressed(KEY_SHIFT) else 3.4
			var np: Vector3 = noah.position + move_dir * spd * delta
			np.x = clampf(np.x, -18.0, 38.0)
			np.z = clampf(np.z, -10.0, 34.0)
			np.y = _surface_height_for_noah(np.x, np.z)
			noah.position = np
			noah.look_at(noah.position + move_dir, Vector3.UP)
			_anim(noah, "Run" if Input.is_key_pressed(KEY_SHIFT) else "Walk")
		elif noah_has_click_target:
			var flat_d: Vector3 = Vector3(noah_click_target.x - noah.position.x, 0.0, noah_click_target.z - noah.position.z)
			if flat_d.length() < 0.45:
				noah_has_click_target = false
			else:
				var dir: Vector3 = flat_d.normalized()
				var np: Vector3 = noah.position + dir * 3.6 * delta
				np.y = _surface_height_for_noah(np.x, np.z)
				noah.position = np
				noah.look_at(noah.position + dir, Vector3.UP)
				_anim(noah, "Walk")
		elif noah_busy_timer > 0.0:
			noah_busy_timer -= delta
			_anim(noah, noah_busy_clip)
		else:
			_anim(noah, "Idle")

		# Auto-open 3-Deck Interior Cutaway whenever Noah steps onto the ramp or INSIDE the Ark!
		if not manual_cutaway_lock:
			var ap: Vector3 = world.ark_anchor.position
			var inside_now: bool = int(state.get("arkStage", 0)) >= 2 and absf(noah.position.x - ap.x) < 10.6 and noah.position.z < ap.z + 3.2 and noah.position.z > ap.z - 2.6
			if inside_now != interior_cutaway:
				interior_cutaway = inside_now
				_apply_ark_visibility()
				cutaway_btn.text = "关闭内部透视 [V]" if interior_cutaway else "透视方舟内部 [V]"

		if not camera_free_mode:
			cam_ctrl.focus_on(noah.position + Vector3(0.0, 1.4, 0.0), -1.0, NAN, false)

	# 2. Check proximity to 3D Hotspots for [E] Prompt + pulse rings
	active_hotspot = {}
	for h in hotspots:
		if bool(h.done):
			continue
		var ring: MeshInstance3D = h.get("ring") as MeshInstance3D
		if ring != null:
			var s: float = 1.0 + sin(elapsed * 3.5) * 0.09
			ring.scale = Vector3(s, 1.0, s)
		if noah.visible and noah.position.distance_to(h.pos) < 3.4:
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

	# 4. Live Villagers & Raiders
	if id == "noah_02_keel_mortise":
		for i in range(villagers.size()):
			var v: Node3D = villagers[i]
			var tg: Vector3 = world.grounded(-3.5 + float(i) * 2.1, 11.5)
			if v.position.distance_to(tg) > 0.3:
				v.position = v.position.move_toward(tg, delta * 2.0)
				v.look_at(tg, Vector3.UP)
				_anim(v, "Walk")
			else:
				_anim(v, "Idle")
	elif id == "noah_03_hull_decks":
		for i in range(raiders.size()):
			var r: Node3D = raiders[i]
			var rg: Vector3 = world.grounded(-2.5 + float(i) * 2.3, 28.0 if crisis_resolved else 10.5)
			if r.position.distance_to(rg) > 0.35:
				r.position = r.position.move_toward(rg, delta * 2.6)
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


func _update_living_family(delta: float, id: String) -> void:
	# Sons 2 & 3 actively walk back and forth hauling logs from East Forest (X=22) <-> Timber Depot (X=-6)
	for idx in [2, 3]:
		var son: Node3D = family[idx]
		var cycle: float = fposmod(elapsed * 0.14 + family_ai_phase[idx], 2.0)
		var going_back: bool = cycle >= 1.0
		var t: float = cycle - 1.0 if going_back else cycle
		var p_forest: Vector3 = world.grounded(21.0, -3.0 + float(idx) * 2.2)
		var p_depot: Vector3 = world.grounded(-5.5, 2.2 + float(idx - 2) * 1.4)
		var target: Vector3 = p_depot.lerp(p_forest, t) if going_back else p_forest.lerp(p_depot, t)
		var dir: Vector3 = target - son.position
		son.position = target
		if dir.length_squared() > 0.0001:
			son.look_at(son.position + dir.normalized(), Vector3.UP)
		var log_node: Node3D = son.find_child("CarriedLog", false, false) as Node3D
		if log_node != null:
			log_node.visible = not going_back
		_anim(son, "Walk")

	# Son 4 actively hammers/brushes along the Ark side
	var s4: Node3D = family[4]
	s4.position = world.grounded(3.8, -0.4)
	s4.look_at(world.grounded(3.8, -4.5), Vector3.UP)
	_anim(s4, "BrushPitch" if id == "noah_04_pitch_provisions" else "Hammer")

	# Wife (1) & Daughters (5..7) patrol between Provisions Amphorae & Boarding Ramp
	for idx in [1, 5, 6, 7]:
		var w: Node3D = family[idx]
		var cyc: float = fposmod(elapsed * 0.18 + family_ai_phase[idx], 2.0)
		var t: float = 2.0 - cyc if cyc >= 1.0 else cyc
		var pa: Vector3 = world.grounded(8.8 + float(idx % 2) * 1.2, 3.0 + float(idx % 3) * 0.9)
		var pb: Vector3 = world.grounded(2.8, 3.5 + float(idx % 2) * 0.8)
		var np: Vector3 = pa.lerp(pb, t)
		var d: Vector3 = np - w.position
		w.position = np
		if d.length_squared() > 0.0001:
			w.look_at(w.position + d.normalized(), Vector3.UP)
		_anim(w, "Walk")


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
