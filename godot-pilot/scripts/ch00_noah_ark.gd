extends Node3D
## Playable 120x120 Grand RTS Strategy-Survival + Live 3D Crisis Director for Prologue (Gen 6-9).
## Driven by res://data/ch00_noah_ark.json with Free RTS Camera, 4-Zone World, Visible Plot Twists
## (Mocking Villagers & Worker Desertion, Dusk Torch Raiders, Real Rising 3D Flood, Multi-Species Boarding),
## and Minimal Cinematic HUD (NO permanent giant side text box!).

const DATA_PATH: String = "res://data/ch00_noah_ark.json"

var chapter: Dictionary = {}
var event_index: Dictionary = {}
var current_event: Dictionary = {}
var state: Dictionary = {}

var world: NoahRTSWorld
var cam_ctrl: RTSCameraController

# Cast & Actors
var family: Array[Node3D] = []
var hired_workers: Array[Node3D] = []
var villagers: Array[Node3D] = []
var raiders: Array[Node3D] = []
var animal_root: Node3D
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []

# Live RTS simulation state
var elapsed: float = 0.0
var phase_progress: float = 0.0
var worker_boost: float = 1.0
var crisis_triggered: bool = false
var crisis_resolved: bool = false
var flood_level: float = -10.5
var flood_target: float = -10.5
var flood_peak_reached: bool = false
var preview_mode: bool = false

# Minimal Cinematic UI Nodes
var top_bar: PanelContainer
var top_label: Label
var progress_bar: ProgressBar
var subtitle_panel: PanelContainer
var subtitle_title: Label
var subtitle_body: Label
var cmd_dock: HBoxContainer
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
	_build_minimal_hud()

	var start_id: String = str(chapter.get("firstEventId", "noah_01_revelation"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene="):
			var req: String = arg.trim_prefix("--preview-scene=")
			if event_index.has(req):
				start_id = req
				preview_mode = true
	_enter_event(start_id)


func _load_json() -> void:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + DATA_PATH)
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
		ap.play(clip, 0.2)
		ap.advance(0.0)


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
	# 1. All 8 Family Members (Noah + Wife + 3 Sons + 3 Daughters-in-law)
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
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(-2.0 + float(i), 5.0))
		actor.name = "Family_%d" % i
		family.append(actor)
		_anim(actor, "Idle")

	# 2. Hired Workers (who desert during Act 2A crisis!)
	for i in range(2):
		var hw: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.58, world.grounded(14.0 + float(i) * 1.6, 1.5))
		hw.name = "HiredWorker_%d" % i
		hw.hide()
		hired_workers.append(hw)

	# 3. Mocking Villagers (march visibly up from South Village!)
	for i in range(4):
		var v: Node3D = world.spawn_asset("CHR_Abram_rigged.glb" if i % 2 == 0 else "CHR_Noah_Son_rigged.glb", 1.58, world.grounded(-2.0 + float(i) * 1.8, 28.0))
		v.name = "Villager_%d" % i
		v.hide()
		villagers.append(v)

	# 4. Night Raiders with flickering torches (march visibly up the South road during Act 2B!)
	for i in range(3):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.62, world.grounded(-2.5 + float(i) * 2.2, 24.0))
		r.name = "Raider_%d" % i
		_add_torch(r)
		r.hide()
		raiders.append(r)

	# 5. Multi-Species Boarding Animal Pairs
	animal_root = Node3D.new()
	animal_root.name = "AnimalProcession"
	add_child(animal_root)
	var species: Array[Dictionary] = [
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.92},
		{"file": "CC0_Sheep_Grab3D.glb", "h": 0.90},
		{"file": "ANI_Ox.glb", "h": 1.38},
		{"file": "ANI_Ox.glb", "h": 1.34},
		{"file": "ANI_Goat.glb", "h": 0.96},
		{"file": "ANI_Goat.glb", "h": 0.94},
		{"file": "ANI_Donkey.glb", "h": 1.20},
		{"file": "ANI_Donkey.glb", "h": 1.18},
	]
	for i in range(species.size()):
		var sp: Dictionary = species[i]
		var a: Node3D = world.spawn_asset(str(sp.file), float(sp.h), Vector3.ZERO, animal_root)
		a.name = "Animal_%d" % i
	animal_root.hide()

	# Boarding ramp path from courtyard up into Ark doorway
	var ap: Vector3 = world.ark_anchor.position
	var sc: float = world.ark_scale
	boarding_path = [
		world.grounded(3.2, 13.5),
		world.grounded(2.0, 7.2),
		ap + Vector3(0.0, 0.0, 6.4 * sc),
		ap + Vector3(0.0, 1.98 * sc, 2.5 * sc),
		ap + Vector3(0.0, 1.98 * sc, 1.6 * sc),
	]

	# 6. Circling Raven & Olive-Leaf Dove
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


func _make_btn(text: String, cb: Callable, min_w: float = 110.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40.0)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	b.add_theme_stylebox_override("normal", _style_box(Color(0.20, 0.14, 0.08, 0.92), Color(0.76, 0.58, 0.30), 6))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.30, 0.21, 0.11, 0.96), Color(0.94, 0.76, 0.42), 6))
	b.pressed.connect(cb)
	return b


func _build_minimal_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	# 1. Top-Center Slim Status Bar (hidden in Silent Revelation & Worship/Rainbow!)
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 180
	top_bar.offset_right = -260
	top_bar.offset_top = 12
	top_bar.offset_bottom = 66
	top_bar.add_theme_stylebox_override("panel", _style_box(Color(0.09, 0.07, 0.05, 0.80), Color(0.72, 0.56, 0.28, 0.85)))
	layer.add_child(top_bar)
	var tvb: VBoxContainer = VBoxContainer.new()
	tvb.add_theme_constant_override("separation", 4)
	top_bar.add_child(tvb)
	top_label = Label.new()
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_label.add_theme_color_override("font_color", Color(0.97, 0.90, 0.72))
	top_label.add_theme_font_size_override("font_size", 15)
	tvb.add_child(top_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 10
	progress_bar.show_percentage = false
	progress_bar.max_value = 100.0
	tvb.add_child(progress_bar)

	# 2. Top-Right Compact Camera Quick-Jump Strip
	var cam_panel: PanelContainer = PanelContainer.new()
	cam_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_panel.offset_left = -246
	cam_panel.offset_right = -12
	cam_panel.offset_top = 12
	cam_panel.offset_bottom = 66
	cam_panel.add_theme_stylebox_override("panel", _style_box(Color(0.09, 0.07, 0.05, 0.74), Color(0.65, 0.50, 0.26, 0.75)))
	layer.add_child(cam_panel)
	var chb: HBoxContainer = HBoxContainer.new()
	chb.add_theme_constant_override("separation", 4)
	cam_panel.add_child(chb)
	chb.add_child(_make_btn("船坞", func() -> void: cam_ctrl.focus_on(Vector3(1.0, 1.5, 0.0), 25.0, -0.45), 50.0))
	chb.add_child(_make_btn("森林", func() -> void: cam_ctrl.focus_on(Vector3(26.0, 3.0, 0.0), 26.0, -0.75), 50.0))
	chb.add_child(_make_btn("村落", func() -> void: cam_ctrl.focus_on(Vector3(2.0, -1.0, 29.0), 26.0, -0.25), 50.0))
	chb.add_child(_make_btn("全景", func() -> void: cam_ctrl.focus_on(Vector3(0.0, 0.0, 4.0), 50.0, -0.52), 50.0))

	# 3. Bottom Cinematic Subtitle Bar + Compact RTS Command Dock
	var bottom_vb: VBoxContainer = VBoxContainer.new()
	bottom_vb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_vb.offset_left = 72
	bottom_vb.offset_right = -72
	bottom_vb.offset_top = -152
	bottom_vb.offset_bottom = -12
	bottom_vb.add_theme_constant_override("separation", 8)
	layer.add_child(bottom_vb)

	subtitle_panel = PanelContainer.new()
	subtitle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.05, 0.04, 0.80), Color(0.70, 0.54, 0.28, 0.70), 8))
	bottom_vb.add_child(subtitle_panel)
	var svb: VBoxContainer = VBoxContainer.new()
	svb.add_theme_constant_override("separation", 4)
	subtitle_panel.add_child(svb)
	subtitle_title = Label.new()
	subtitle_title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))
	subtitle_title.add_theme_font_size_override("font_size", 15)
	svb.add_child(subtitle_title)
	subtitle_body = Label.new()
	subtitle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_body.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	subtitle_body.add_theme_font_size_override("font_size", 15)
	svb.add_child(subtitle_body)

	cmd_dock = HBoxContainer.new()
	cmd_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	cmd_dock.add_theme_constant_override("separation", 10)
	bottom_vb.add_child(cmd_dock)

	# 4. Centered Crisis Decision Modal Scroll (ONLY appears on live dramatic twists!)
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(0.03, 0.02, 0.02, 0.52)
	modal_overlay.hide()
	layer.add_child(modal_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0, 260.0)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.11, 0.08, 0.05, 0.96), Color(0.84, 0.65, 0.32), 10))
	center.add_child(card)
	var mvb: VBoxContainer = VBoxContainer.new()
	mvb.add_theme_constant_override("separation", 12)
	card.add_child(mvb)
	modal_title = Label.new()
	modal_title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.48))
	modal_title.add_theme_font_size_override("font_size", 22)
	mvb.add_child(modal_title)
	modal_body = Label.new()
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	modal_body.add_theme_font_size_override("font_size", 16)
	mvb.add_child(modal_body)
	modal_choices = VBoxContainer.new()
	modal_choices.add_theme_constant_override("separation", 8)
	mvb.add_child(modal_choices)


func _enter_event(id: String) -> void:
	if not event_index.has(id):
		return
	current_event = event_index[id]
	phase_progress = 0.0
	worker_boost = 1.0
	crisis_triggered = false
	crisis_resolved = false
	modal_overlay.hide()

	var stage: int = int(current_event.get("arkStage", 0))
	state.arkStage = stage
	world.set_ark_stage(stage)

	# Visibility of world props & actors per act
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

	# Hide crisis NPCs by default
	for hw in hired_workers:
		hw.visible = (id == "noah_02_keel_mortise")
	for v in villagers:
		v.visible = (id == "noah_02_keel_mortise")
	for r in raiders:
		r.visible = (id == "noah_03_hull_decks")

	# Mood, flood water, camera focus, and cast staging
	match id:
		"noah_01_revelation":
			world.apply_mood("revelation")
			flood_target = -10.5
			cam_ctrl.focus_on(Vector3(1.0, 1.8, 2.0), 22.0, -0.58, preview_mode)
			_stage_revelation()
		"noah_02_keel_mortise":
			world.apply_mood("build")
			flood_target = -10.5
			cam_ctrl.focus_on(Vector3(4.0, 1.5, 4.0), 36.0, -0.45, preview_mode)
			_stage_shipyard_work("Hammer")
			_reset_villagers_and_workers()
		"noah_03_hull_decks":
			world.apply_mood("dusk_raid")
			flood_target = -10.5
			cam_ctrl.focus_on(Vector3(0.0, 1.2, 8.0), 32.0, -0.35, preview_mode)
			_stage_shipyard_work("Hammer")
			_reset_raiders()
		"noah_04_pitch_provisions":
			world.apply_mood("build")
			flood_target = -10.5
			cam_ctrl.focus_on(Vector3(3.0, 1.5, 2.0), 29.0, -0.42, preview_mode)
			_stage_shipyard_work("BrushPitch")
		"noah_05_board_ark":
			world.apply_mood("dusk_raid")
			flood_target = -10.5
			cam_ctrl.focus_on(Vector3(1.5, 1.6, 5.0), 27.0, -0.38, preview_mode)
			_stage_boarding_watch()
		"noah_06_flood_dove":
			world.apply_mood("flood")
			flood_target = 4.2
			if preview_mode:
				flood_level = 3.8
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = flood_level - 0.55
			cam_ctrl.focus_on(Vector3(-2.0, 2.5, 4.0), 48.0, -0.55, preview_mode)
			for m in family:
				m.hide()
		"noah_07_exit_altar", "noah_08_rainbow_covenant":
			world.apply_mood("ararat")
			flood_target = -10.5
			if preview_mode:
				flood_level = -10.5
				world.flood_water.position.y = flood_level
				world.ark_anchor.position.y = world.ark_base_y
			cam_ctrl.focus_on(Vector3(-2.5, 1.6, 3.5), 32.0, -0.52, preview_mode)
			_stage_ararat_worship()

	_refresh_hud()


func _stage_revelation() -> void:
	for i in range(family.size()):
		family[i].visible = (i == 0)
	family[0].position = world.grounded(0.5, 3.5)
	family[0].look_at(world.grounded(0.5, -10.0), Vector3.UP)
	_anim(family[0], "Pray")


func _stage_shipyard_work(work_clip: String) -> void:
	var slots: Array[Vector2] = [
		Vector2(-4.5, 1.5), Vector2(8.6, 3.6), Vector2(-1.2, 1.8), Vector2(3.2, 1.8),
		Vector2(6.5, 1.6), Vector2(9.8, 4.2), Vector2(7.6, 4.8), Vector2(10.6, 5.2),
	]
	for i in range(family.size()):
		family[i].show()
		family[i].position = world.grounded(slots[i].x, slots[i].y)
		var look_t: Vector3 = world.grounded(slots[i].x, -4.5)
		look_t.y = family[i].position.y
		family[i].look_at(look_t, Vector3.UP)
		_anim(family[i], work_clip if i in [0, 2, 3, 4] else "Idle")


func _stage_boarding_watch() -> void:
	var slots: Array[Vector2] = [
		Vector2(-3.2, 4.5), Vector2(5.2, 4.8), Vector2(-1.8, 5.5), Vector2(4.4, 5.8),
		Vector2(6.2, 3.5), Vector2(7.4, 4.2), Vector2(-4.6, 5.2), Vector2(6.8, 5.4),
	]
	for i in range(family.size()):
		family[i].show()
		family[i].position = world.grounded(slots[i].x, slots[i].y)
		var look_t: Vector3 = world.grounded(1.0, 2.0)
		look_t.y = family[i].position.y
		family[i].look_at(look_t, Vector3.UP)
		_anim(family[i], "Idle")


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


func _reset_villagers_and_workers() -> void:
	for i in range(hired_workers.size()):
		hired_workers[i].position = world.grounded(12.0 + float(i) * 2.0, 1.2)
		_anim(hired_workers[i], "Hammer")
	for i in range(villagers.size()):
		var start_z: float = 12.5 if preview_mode else 26.0
		villagers[i].position = world.grounded(-3.5 + float(i) * 2.2, start_z)
		_anim(villagers[i], "Walk")


func _reset_raiders() -> void:
	for i in range(raiders.size()):
		var rz: float = 11.5 if preview_mode else 25.0
		raiders[i].position = world.grounded(-3.0 + float(i) * 2.4, rz)
		raiders[i].look_at(world.grounded(0.0, 2.0), Vector3.UP)
		_anim(raiders[i], "Run")


func _refresh_hud() -> void:
	var id: String = str(current_event.get("id", ""))
	var hide_hud: bool = bool(current_event.get("hideResourceHud", false)) or id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	top_bar.visible = not hide_hud
	top_label.text = "%s  |  歌斐木: %d  |  粮草: %d  |  家族同心: %d  |  阶段进度: %d%%" % [
		str(current_event.get("titleZh", "")),
		int(state.get("timber", 0)),
		int(state.get("provisions", 60)),
		int(state.get("harmony", 80)),
		int(roundf(phase_progress)),
	]
	progress_bar.value = phase_progress
	subtitle_title.text = "%s · %s（%s）" % [
		str(current_event.get("titleZh", "")),
		str(current_event.get("speakerZh", "")),
		str(current_event.get("canonRef", "")),
	]
	subtitle_body.text = str(current_event.get("bodyZh", ""))

	for c in cmd_dock.get_children():
		cmd_dock.remove_child(c)
		c.queue_free()

	match id:
		"noah_01_revelation":
			cmd_dock.add_child(_make_btn("领受启示 · 展开三百肘造舟蓝图", func() -> void: _enter_event("noah_02_keel_mortise"), 280.0))
		"noah_02_keel_mortise":
			cmd_dock.add_child(_make_btn("[1] 派人东坡采运歌斐木 (+25%)", func() -> void: _boost_work(25.0, 35, 0), 210.0))
			cmd_dock.add_child(_make_btn("[2] 全员凿刻榫卯立龙骨 (+30%)", func() -> void: _boost_work(30.0, 15, 0), 210.0))
			if phase_progress >= 100.0 and crisis_resolved:
				cmd_dock.add_child(_make_btn("进入下一阶段 · 搭建三层船壳 →", func() -> void: _enter_event("noah_03_hull_decks"), 220.0))
		"noah_03_hull_decks":
			cmd_dock.add_child(_make_btn("[1] 搭建三层隔间与透光带 (+35%)", func() -> void: _boost_work(35.0, 20, 0), 230.0))
			if not crisis_resolved:
				cmd_dock.add_child(_make_btn("[!] 应对南坡强人夜袭", _open_crisis_modal, 190.0))
			elif phase_progress >= 100.0:
				cmd_dock.add_child(_make_btn("进入下一阶段 · 塞缝抹松香 →", func() -> void: _enter_event("noah_04_pitch_provisions"), 220.0))
		"noah_04_pitch_provisions":
			cmd_dock.add_child(_make_btn("[1] 麻絮塞缝 · 里外厚涂松香 (+40%)", func() -> void: _boost_work(40.0, 0, 10), 240.0))
			cmd_dock.add_child(_make_btn("[2] 分舱储藏粮草陶罐 (+35%)", func() -> void: _boost_work(35.0, 0, 25), 210.0))
			if phase_progress >= 100.0:
				cmd_dock.add_child(_make_btn("风暴将至 · 引导百兽登舟 →", func() -> void: _enter_event("noah_05_board_ark"), 220.0))
		"noah_05_board_ark":
			cmd_dock.add_child(_make_btn("引导洁净与不洁净活物成双入舟 (+50%)", func() -> void: _boost_work(50.0, 0, 0), 290.0))
			if phase_progress >= 100.0:
				cmd_dock.add_child(_make_btn("关上舱门 · 迎接大洪水 →", func() -> void: _enter_event("noah_06_flood_dove"), 210.0))
		"noah_06_flood_dove":
			cmd_dock.add_child(_make_btn("放出乌鸦与鸽子探看水势", func() -> void: _enter_event("noah_07_exit_altar"), 240.0))
		"noah_07_exit_altar":
			cmd_dock.add_child(_make_btn("一家八口筑坛献祭 · 仰望彩虹永约 →", func() -> void: _enter_event("noah_08_rainbow_covenant"), 280.0))
		"noah_08_rainbow_covenant":
			cmd_dock.add_child(_make_btn("展开宏观战役画卷（前往 B01 / P01 出吾珥）", func() -> void: get_tree().change_scene_to_file("res://scenes/overworld_prologue.tscn"), 340.0))


func _boost_work(delta_pct: float, timber_add: int, prov_add: int) -> void:
	phase_progress = minf(100.0, phase_progress + delta_pct * worker_boost)
	state.timber = int(state.get("timber", 0)) + timber_add
	state.provisions = int(state.get("provisions", 60)) + prov_add
	var id: String = str(current_event.get("id", ""))
	if id in ["noah_02_keel_mortise", "noah_03_hull_decks"] and phase_progress >= 45.0 and not crisis_triggered:
		crisis_triggered = true
		_open_crisis_modal()
	_refresh_hud()


func _open_crisis_modal() -> void:
	var id: String = str(current_event.get("id", ""))
	modal_overlay.show()
	for c in modal_choices.get_children():
		modal_choices.remove_child(c)
		c.queue_free()
	if id == "noah_02_keel_mortise":
		cam_ctrl.focus_on(Vector3(2.0, 0.5, 13.0), 26.0, -0.28)
		modal_title.text = "突发波折 · 乡邻嘲笑与雇工溃散"
		modal_body.text = "南坡村民成群走上船坞外围嘲笑旱地造舟，两名雇工当场扔下斧头沿山路离去！建造效率骤降，你如何应对？"
		modal_choices.add_child(_make_btn("重排一家八口跨季轮班，亲手顶上榫卯与伐木（家族同心 +8）", func() -> void: _resolve_crisis(8, false), 480.0))
		modal_choices.add_child(_make_btn("分发部分粮草稳住人心，缓慢坚持工期（粮草 -10，同心 +4）", func() -> void: _resolve_crisis(4, false), 480.0))
	elif id == "noah_03_hull_decks":
		cam_ctrl.focus_on(Vector3(0.0, 0.5, 11.0), 25.0, -0.32)
		modal_title.text = "夜间危机 · 强人举火把逼近木料堆"
		modal_body.text = "夜幕降临，三名强人举着火把顺着南坡山路逼近你的歌斐木料堆，企图强抢大木！请立刻下令应对（非致命防卫）："
		modal_choices.add_child(_make_btn("立即筑起木栅栏，派三子举火把夜巡对峙驱离强人", func() -> void: _resolve_crisis(6, true), 480.0))
		modal_choices.add_child(_make_btn("主动分让部分边角废料，以和息争避免流血（木材 -15）", func() -> void: _resolve_crisis(4, false), 480.0))
	else:
		modal_overlay.hide()


func _resolve_crisis(harmony_delta: int, build_fence: bool) -> void:
	crisis_resolved = true
	worker_boost = 1.0
	state.harmony = int(state.get("harmony", 80)) + harmony_delta
	if build_fence:
		state.guardFence = true
		world.guard_fence.show()
	modal_overlay.hide()
	cam_ctrl.focus_on(Vector3(1.5, 1.5, 2.0), 30.0, -0.45)
	_refresh_hud()


func _process(delta: float) -> void:
	elapsed += delta
	var id: String = str(current_event.get("id", ""))

	# 1. Live Villagers marching up & Hired Workers deserting in Act 2A
	if id == "noah_02_keel_mortise":
		for i in range(villagers.size()):
			var v: Node3D = villagers[i]
			var tz: float = 11.8 + float(i % 2) * 1.4
			var target: Vector3 = world.grounded(-3.5 + float(i) * 2.2, tz)
			if v.position.distance_to(target) > 0.25:
				v.position = v.position.move_toward(target, delta * 2.2)
				v.look_at(target, Vector3.UP)
				_anim(v, "Walk")
			else:
				_anim(v, "Idle")
		if crisis_triggered:
			for i in range(hired_workers.size()):
				var hw: Node3D = hired_workers[i]
				var away: Vector3 = world.grounded(2.0 + float(i) * 1.5, 32.0)
				if hw.position.distance_to(away) > 0.3:
					hw.position = hw.position.move_toward(away, delta * 2.8)
					hw.look_at(away, Vector3.UP)
					_anim(hw, "Walk")

	# 2. Live Night Raiders marching up or retreating in Act 2B
	if id == "noah_03_hull_decks":
		for i in range(raiders.size()):
			var r: Node3D = raiders[i]
			var goal: Vector3 = world.grounded(-2.5 + float(i) * 2.4, 28.0 if crisis_resolved else 10.2)
			if r.position.distance_to(goal) > 0.3:
				r.position = r.position.move_toward(goal, delta * 2.9)
				r.look_at(goal, Vector3.UP)
				_anim(r, "Run")
			else:
				_anim(r, "Brawl" if not crisis_resolved else "Idle")

	# 3. Live Multi-Species Animal Boarding Procession in Act 3
	if animal_root.visible:
		_update_animal_procession()

	# 4. Real 3D Rising Floodwater submerging village/forest & floating Ark in Act 4!
	if absf(flood_level - flood_target) > 0.02:
		flood_level = move_toward(flood_level, flood_target, delta * 2.4)
		world.flood_water.position.y = flood_level
	if id == "noah_06_flood_dove":
		var wave: float = sin(elapsed * 1.35) * 0.22
		world.flood_water.position.y = flood_level + wave * 0.4
		if flood_level > world.ark_base_y + 0.4:
			world.ark_anchor.position.y = flood_level - 0.55 + wave
			world.ark_anchor.rotation.z = sin(elapsed * 0.9) * 0.032
			world.ark_anchor.rotation.x = cos(elapsed * 0.75) * 0.022
	else:
		world.ark_anchor.position.y = lerpf(world.ark_anchor.position.y, world.ark_base_y, 1.0 - exp(-delta * 4.0))
		world.ark_anchor.rotation = world.ark_anchor.rotation.lerp(Vector3.ZERO, 1.0 - exp(-delta * 4.0))

	# 5. Circling Raven & Olive-Leaf Dove
	for i in range(birds.size()):
		var b: Node3D = birds[i]
		if not b.visible:
			continue
		var a: float = elapsed * 0.34 + float(i) * PI
		var pos: Vector3 = Vector3(-2.0 + cos(a) * (10.0 + float(i) * 3.0), 8.2 + float(i) * 1.1 + sin(a * 2.0) * 0.5, -3.0 + sin(a) * 6.0)
		var tan_v: Vector3 = Vector3(-sin(a) * 10.0, cos(a * 2.0) * 0.8, cos(a) * 6.0)
		b.position = pos
		b.look_at(pos + tan_v, Vector3.UP)
		b.rotation.z = sin(a) * 0.16


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
