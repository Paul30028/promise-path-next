extends Node3D
## Narrative text, actions, choices, and event transitions come from chapter JSON.
const Loader: Script = preload("res://scripts/glb_asset_loader.gd")
const DATA: String = "res://data/ch00_noah_ark.json"
@export_range(-1, 3) var preview_stage: int = -1
@export var preview_ararat: bool = false
var chapter: Dictionary
var event: Dictionary
var state: Dictionary
var event_index: Dictionary = {}
var phase: String = "build"
var pending_choice: Dictionary = {}
var action_ready: bool = false
var action_running: bool = false
var action_time: float = 0.0
var elapsed: float = 0.0
var waypoints: Array[Vector3] = []
var obstacles: Array[Rect2] = []
var ark: Node3D
var noah: Node3D
var player: AnimationPlayer
var animation: String = ""
var camera: Camera3D
var rig: Node3D
var focus: Vector3 = Vector3.ZERO
var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var ground_material: StandardMaterial3D
var water: MeshInstance3D
var rain: CPUParticles3D
var rainbow: MeshInstance3D
var altar: Node3D
var fence: Node3D
var stakes: Node3D
var provisions: Node3D
var foliage: Node3D
var terrace: Node3D
var hud_panel: PanelContainer
var yard: Node3D
var shoots: Node3D
var sheep: Node3D
var content: VBoxContainer
var hud: Label
var panel: PanelContainer
var mood_tween: Tween
var water_tween: Tween
var flood_finished: bool = true
var prayer: bool = false

func _ready() -> void:
	var file: FileAccess = FileAccess.open(DATA, FileAccess.READ)
	if file == null:
		push_error("Cannot open chapter JSON: " + DATA)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("Invalid chapter JSON: " + DATA)
		return
	chapter = parsed
	state = chapter.initialState.duplicate(true)
	for item in chapter.events:
		event_index[item.id] = item
	_build_world()
	_build_ui()
	var start: String = chapter.firstEventId
	var stage: int = preview_stage
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage = clampi(int(arg.get_slice("=", 1)), 0, 3)
		if arg == "--ararat":
			preview_ararat = true
	if stage >= 0:
		for item in chapter.events:
			if int(item.arkStage) == stage:
				start = item.id
				break
	if preview_ararat:
		start = chapter.events[-1].id
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene="):
			var requested: String = arg.trim_prefix("--preview-scene=")
			if event_index.has(requested):
				start = requested
			else:
				push_warning("Unknown preview scene: " + requested)
	_enter_event(start)

func _material(color: Color, roughness: float = .9) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func _asset(file: String, height: float, pos: Vector3, parent: Node3D = self) -> Node3D:
	var packed: PackedScene = load("res://assets/models/" + file) as PackedScene
	var node: Node3D = null
	if packed != null:
		node = Node3D.new()
		node.name = file.get_basename()
		var model: Node3D = packed.instantiate() as Node3D
		if model != null:
			var bounds: AABB = Loader._compute_local_aabb(model)
			var factor: float = height / maxf(bounds.size.y, 0.001)
			model.scale = Vector3.ONE * factor
			model.position.y = -bounds.position.y * factor
			node.add_child(model)
	if node == null:
		push_error("Missing prologue asset: " + file)
		node = Node3D.new()
	parent.add_child(node)
	node.position = pos
	return node

func _build_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_density = .008
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	sun.shadow_blur = 1.2
	add_child(sun)
	rig = Node3D.new()
	rig.name = "CameraRig"
	add_child(rig)
	camera = Camera3D.new()
	camera.position = Vector3(-13.5,14.5,22.5)
	camera.fov = 38
	camera.h_offset = 3.2
	camera.far = 220
	rig.add_child(camera)
	camera.look_at(Vector3(1.0,2.4,-1.5))
	camera.current = true
	ground_material = _material(Color(.69,.59,.44))
	ground_material.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	ground_material.normal_enabled = true
	ground_material.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	ground_material.normal_scale = .65
	ground_material.uv1_triplanar = true
	ground_material.uv1_scale = Vector3(.45,.45,.45)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(140,120)
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	add_child(ground)
	var stone: StandardMaterial3D = _material(Color(.49,.47,.41),.75)
	stone.albedo_texture = load("res://assets/textures/rock_boulder_albedo.png")
	stone.uv1_triplanar = true
	# Soft distant highland ridges in warm earthy limestone tones
	for i in range(12):
		var hill: SphereMesh = SphereMesh.new()
		hill.radius = 1.0
		hill.height = 2.0
		hill.radial_segments = 16
		hill.rings = 8
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = hill
		var hill_mat: StandardMaterial3D = _material(Color(.46+i*.008,.44+i*.006,.38), .95)
		hill_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
		hill_mat.uv1_triplanar = true
		hill_mat.uv1_scale = Vector3(.15,.15,.15)
		node.material_override = hill_mat
		node.position = Vector3(-48+i*10,-1.5,-30 - absf(sin(i))*10)
		node.scale = Vector3(13 + i%4, 5.5 + (i%3)*1.8, 10)
		add_child(node)
	ark = _asset("BLD_NoahsArk.glb",4.6,Vector3(0,0,-2.0))
	var bounds: AABB = Loader._compute_local_aabb(ark)
	obstacles.append(Rect2(Vector2(bounds.position.x-.5,bounds.position.z-2.5),Vector2(bounds.size.x+1,6.4)))
	noah = _asset("CHR_Noah_rigged.glb",1.65,Vector3(-7,0,6))
	player = noah.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player != null:
		for clip in ["Idle","Walk","Pray"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	yard = Node3D.new()
	yard.name = "TimberStacks"
	add_child(yard)
	var wood: StandardMaterial3D = _material(Color(.32,.19,.085))
	wood.albedo_texture = load("res://assets/textures/wood_timber_albedo.png")
	for i in range(10):
		_box(yard,Vector3(3,.25,.28),Vector3(-9,.125 + float(i/4)*.25,1.5 + (i%4)*.32),wood)
	obstacles.append(Rect2(-11,1,4,2.5))
	stakes = Node3D.new()
	stakes.name = "YardStakes"
	add_child(stakes)
	for x in [-10.5,10.5]:
		for z in [-4.5,.5]:
			_box(stakes,Vector3(.12,.75,.12),Vector3(x,.375,z),wood)
	provisions = Node3D.new()
	provisions.name = "PitchAndProvisions"
	add_child(provisions)
	for i in range(5):
		_asset("CC0_Amphora.glb",.8,Vector3(7+i*.6,0,3),provisions)
	var pot: MeshInstance3D = MeshInstance3D.new()
	pot.name = "PitchCauldron"
	var pot_mesh: CylinderMesh = CylinderMesh.new()
	pot_mesh.top_radius = .52
	pot_mesh.bottom_radius = .38
	pot_mesh.height = .65
	pot.mesh = pot_mesh
	pot.position = Vector3(6,.325,3)
	pot.material_override = _material(Color(.07,.045,.025))
	provisions.add_child(pot)
	var pitch_mesh: CylinderMesh = CylinderMesh.new()
	pitch_mesh.top_radius = .46
	pitch_mesh.bottom_radius = .46
	pitch_mesh.height = .025
	var pitch: MeshInstance3D = MeshInstance3D.new()
	pitch.mesh = pitch_mesh
	pitch.position = Vector3(6,.66,3)
	pitch.material_override = _material(Color(.025,.018,.012),.45)
	provisions.add_child(pitch)
	obstacles.append(Rect2(6.5,2.5,3.8,1.2))
	foliage = Node3D.new()
	foliage.name = "FramingOlives"
	add_child(foliage)
	for pos in [Vector3(-14,0,-6),Vector3(13,0,7),Vector3(-14,0,8)]:
		_asset("CC0_OliveTree_Optimized.glb",3.5,pos,foliage)
		obstacles.append(Rect2(Vector2(pos.x-.8,pos.z-.8),Vector2(1.6,1.6)))
	fence = Node3D.new()
	fence.name = "GuardFence"
	add_child(fence)
	for i in range(9):
		for z in [.65,3.9]:
			_box(fence,Vector3(.12,1.2,.12),Vector3(-11+i*.5,.6,z),wood)
	for z in [.65,3.9]:
		for y in [.45,.9]:
			_box(fence,Vector3(4.2,.1,.1),Vector3(-9,y,z),wood)
	fence.hide()
	altar = Node3D.new()
	altar.name = "AltarGroup"
	altar.position = Vector3(0,0,7.2)
	add_child(altar)
	for i in range(14):
		var rock: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = .4
		mesh.height = .5
		mesh.radial_segments = 7
		mesh.rings = 3
		rock.mesh = mesh
		rock.material_override = stone
		var a: float = float(i%7)*TAU/7.0
		rock.position = Vector3(cos(a)*.65,.25+float(i/7)*.32,sin(a)*.55)
		altar.add_child(rock)
	var ember_mat: StandardMaterial3D = _material(Color(.36,.19,.07))
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(.95,.52,.16)
	ember_mat.emission_energy_multiplier = .55
	var ember_mesh: CylinderMesh = CylinderMesh.new()
	ember_mesh.top_radius = .45
	ember_mesh.bottom_radius = .52
	ember_mesh.height = .08
	var ember_bed: MeshInstance3D = MeshInstance3D.new()
	ember_bed.mesh = ember_mesh
	ember_bed.material_override = ember_mat
	ember_bed.position = Vector3(0,.62,0)
	altar.add_child(ember_bed)
	var flame: CPUParticles3D = CPUParticles3D.new()
	flame.amount = 24
	flame.lifetime = 1.4
	flame.position.y = .75
	flame.direction = Vector3.UP
	flame.spread = 18
	flame.gravity = Vector3(0,.1,0)
	flame.initial_velocity_min = .18
	flame.initial_velocity_max = .45
	flame.scale_amount_min = .3
	flame.scale_amount_max = .8
	var spark: SphereMesh = SphereMesh.new()
	spark.radius = .055
	spark.height = .15
	spark.material = ember_mat
	flame.mesh = spark
	altar.add_child(flame)
	var embers: OmniLight3D = OmniLight3D.new()
	embers.position.y = .9
	embers.light_color = Color(1,.55,.22)
	embers.light_energy = .55
	embers.omni_range = 3
	altar.add_child(embers)
	obstacles.append(Rect2(-1.3,6.3,2.6,2.0))
	terrace = Node3D.new()
	terrace.name = "WetStoneTerrace"
	add_child(terrace)
	var wet: StandardMaterial3D = _material(Color(.33,.35,.32),.3)
	wet.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png") as Texture2D
	for i in range(9):
		_box(terrace,Vector3(2.1,.16,1.7),Vector3((i%3-1)*2.1,-.085,5.5+float(i/3)*1.7),wet)
	altar.hide()
	shoots = Node3D.new()
	add_child(shoots)
	for pos in [Vector3(5,0,8),Vector3(-6,0,9),Vector3(9,0,-6)]:
		_asset("CC0_OliveTree_Optimized.glb",.85,pos,shoots)
	shoots.hide()
	sheep = Node3D.new()
	sheep.name = "AnimalPairs"
	add_child(sheep)
	for i in range(4):
		_asset("CC0_Sheep_Grab3D.glb",.85,Vector3(3+(i%2)*1.1,0,5+float(i/2)*1.3),sheep)
	sheep.hide()
	water = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(180,160)
	water.mesh = plane
	water.material_override = _material(Color(.075,.13,.15),.23)
	water.position.y = -3
	add_child(water)
	rain = CPUParticles3D.new()
	rain.amount = 650
	rain.lifetime = 1.8
	rain.position = Vector3(0,15,0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(19,4,14)
	rain.direction = Vector3(-.12,-1,.04)
	rain.spread = 5
	rain.initial_velocity_min = 14
	rain.initial_velocity_max = 19
	rain.gravity = Vector3(0,-4,0)
	var drop: BoxMesh = BoxMesh.new()
	drop.size = Vector3(.018,.35,.018)
	drop.material = _material(Color(.5,.62,.68))
	rain.mesh = drop
	rain.emitting = false
	add_child(rain)
	_build_rainbow()

func _build_rainbow() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		for vertex in [Vector2(i,0),Vector2(i+1,0),Vector2(i,1),Vector2(i+1,0),Vector2(i+1,1),Vector2(i,1)]:
			var u: float = vertex.x/96.0
			var a: float = u*PI
			var radius: float = 13.5+vertex.y*2.4
			surface.set_uv(Vector2(u,vertex.y))
			surface.add_vertex(Vector3(cos(a)*radius,sin(a)*radius,0))
	surface.generate_normals()
	rainbow = MeshInstance3D.new()
	rainbow.name = "VFX_CovenantRainbow"
	rainbow.mesh = surface.commit()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/VFX_CovenantRainbow.gdshader")
	rainbow.material_override = mat
	rainbow.position = Vector3(1.5,-1.2,-15.5)
	rainbow.rotation_degrees.y = -24.0
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rainbow)
	rainbow.hide()

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20,16)
	hud.add_theme_color_override("font_color",Color(.97,.88,.69))
	hud.add_theme_constant_override("outline_size",4)
	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(14,10)
	var hud_style: StyleBoxFlat = StyleBoxFlat.new()
	hud_style.bg_color = Color(.11,.08,.05,.74)
	hud_style.border_color = Color(.76,.60,.32,.85)
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(8)
	hud_style.content_margin_left = 12
	hud_style.content_margin_right = 12
	hud_style.content_margin_top = 6
	hud_style.content_margin_bottom = 6
	hud_panel.add_theme_stylebox_override("panel",hud_style)
	layer.add_child(hud_panel)
	hud_panel.add_child(hud)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -370
	panel.offset_right = -16
	panel.offset_top = 68
	panel.offset_bottom = -20
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(.10,.075,.045,.96)
	style.border_color = Color(.72,.51,.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)

func _text(value: String, size: int = 18) -> void:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color(.97,.91,.77))
	label.add_theme_font_size_override("font_size",size)
	content.add_child(label)

func _button(value: String, callback: Callable, disabled: bool = false) -> void:
	var button: Button = Button.new()
	button.text = value
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.disabled = disabled
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(.24,.17,.09)
	style.border_color = Color(.72,.51,.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal",style)
	button.pressed.connect(callback)
	content.add_child(button)

func _refresh_ui() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var ui: Dictionary = chapter.ui
	hud_panel.visible = not bool(event.get("hideResourceHud",false)) and str(event.id) not in ["noah_07_exit_altar","noah_08_rainbow_covenant"]
	hud.visible = hud_panel.visible
	hud.text = "歌斐木: %d  |  粮草: %d  |  家族同心: %d" % [int(state.timber),int(state.provisions),int(state.harmony)]
	_text(chapter.titleZh,16)
	_text(event.titleZh,24)
	_text(event.canonRef,16)
	_text(event.speakerZh,16)
	_text(ui.adaptationZh if event.isAdaptation else ui.canonZh,14)
	if not pending_choice.is_empty():
		_text(pending_choice.resultZh)
		_button(ui.continueZh,_continue_story)
		return
	_text(event.bodyZh)
	var action: String = event.get("requiredAction", "")
	if not action.is_empty() and not action_ready:
		_text(ui.actionHintZh % ui.actions[action],16)
		_button(ui.actions[action],_perform_action,action_running)
	var choices: Array = event.get("choices",[])
	for choice: Dictionary in choices:
		_button(str(choice.labelZh),_choose.bind(choice),not action_ready or not flood_finished)
	if choices.is_empty():
		_button(str(ui.continueZh),_advance_without_choice,not action_ready or not flood_finished)

func _enter_event(id: String) -> void:
	if not event_index.has(id):
		push_error("Unknown chapter event: " + id)
		return
	event = event_index[id]
	pending_choice = {}
	action_ready = not event.has("requiredAction")
	action_running = false
	prayer = int(event.act) >= 5
	state.arkStage = int(event.arkStage)
	for node in ark.find_children("*","MeshInstance3D",true,false):
		var stage: int = 3
		if str(node.name).begins_with("Stage1"):
			stage = 1
		elif str(node.name).begins_with("Stage2"):
			stage = 2
		node.visible = int(event.arkStage) >= stage
	phase = "ararat" if int(event.act) >= 5 else ("flood" if int(event.act) == 4 else "build")
	stakes.visible = int(event.arkStage) == 0
	yard.visible = phase == "build" and int(event.arkStage) > 0
	provisions.visible = int(event.arkStage) >= 3
	foliage.visible = phase != "flood"
	terrace.visible = phase == "ararat"
	fence.visible = bool(state.get("guardFence",false)) and phase == "build"
	altar.visible = phase == "ararat"
	shoots.visible = phase == "ararat"
	rainbow.visible = id == "noah_08_rainbow_covenant"
	sheep.visible = int(event.act) == 3
	noah.visible = phase != "flood"
	focus = Vector3.ZERO
	_mood()
	var goal: Vector3 = Vector3(-5,0,4)
	if int(event.arkStage) == 2:
		goal = Vector3(5,0,5)
	elif int(event.arkStage) == 3:
		goal = Vector3(6,0,5)
	if prayer:
		goal = Vector3(0,0,5.6)
	var is_preview_jump: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene=") or arg.begins_with("--stage=") or arg == "--ararat":
			is_preview_jump = true
	if is_preview_jump and elapsed < 0.05:
		noah.position = goal
		waypoints.clear()
		if prayer:
			noah.look_at(altar.position, Vector3.UP)
			if player != null and player.has_animation("Pray"):
				animation = "Pray"
				player.play("Pray")
	else:
		_route(goal)
	_refresh_ui()

func _mood() -> void:
	if mood_tween != null:
		mood_tween.kill()
	if water_tween != null:
		water_tween.kill()
	mood_tween = create_tween().set_parallel(true)
	var storm: bool = phase == "flood"
	var morning: bool = phase == "ararat"
	rain.emitting = storm
	mood_tween.tween_property(sun,"light_color",Color(.64,.7,.78) if storm else Color(1,.87,.64),2)
	mood_tween.tween_property(sun,"light_energy",.3 if storm else (1.45 if morning else 1.2),2)
	mood_tween.tween_property(sky_material,"sky_top_color",Color(.13,.17,.22) if storm else Color(.3,.5,.66),2)
	mood_tween.tween_property(sky_material,"sky_horizon_color",Color(.38,.43,.46) if storm else Color(.86,.8,.65),2)
	mood_tween.tween_property(environment,"fog_density",.022 if storm else (.006 if morning else .003),3)
	mood_tween.tween_property(environment,"fog_light_color",Color(.4,.48,.52) if storm else Color(.85,.82,.71),2)
	mood_tween.tween_property(ground_material,"albedo_color",Color(.48,.47,.42) if morning else Color(.69,.59,.44),2)
	mood_tween.tween_property(ground_material,"roughness",.36 if morning else .95,2)
	flood_finished = not storm
	if storm:
		water_tween = create_tween()
		water_tween.tween_property(water,"position:y",2.0,5).set_trans(Tween.TRANS_SINE)
		water_tween.tween_interval(2)
		water_tween.tween_property(water,"position:y",-2.5,7).set_trans(Tween.TRANS_SINE)
		water_tween.tween_callback(func() -> void:
			flood_finished = true
			rain.emitting = false
			shoots.show()
			_refresh_ui())
	else:
		water_tween = create_tween()
		water_tween.tween_property(water,"position:y",-2.5,2)

func _choose(choice: Dictionary) -> void:
	if not action_ready or not flood_finished or not pending_choice.is_empty():
		return
	pending_choice = choice
	if choice.id == "hull_fence_watch":
		state.guardFence = true
		fence.show()
	# Worship and covenant never mutate resource or performance state.
	if int(event.act) < 5 and not bool(event.get("hideResourceHud",false)):
		state.harmony = clampi(int(state.harmony) + int(choice.get("deltaHarmony",0)),0,100)
		state.timber = maxi(0,int(state.timber) + int(choice.get("deltaTimber",0)))
		state.provisions = maxi(0,int(state.provisions) + int(choice.get("deltaProvisions",0)))
	_refresh_ui()

func _advance_without_choice() -> void:
	var events: Array = chapter.events
	var index: int = events.find(event)
	var next_id: String = str(event.get("nextEventId",""))
	if next_id.is_empty() and index >= 0 and index + 1 < events.size():
		next_id = str(events[index+1].id)
	pending_choice = {"nextEventId":next_id}
	_continue_story()

func _continue_story() -> void:
	var next: String = pending_choice.get("nextEventId", "")
	if not next.is_empty():
		_enter_event(next)
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for key in ["titleZh","canonRef","bodyZh","previewZh"]:
		_text(chapter.completion[key])
	_button(chapter.ui.overworldZh,func() -> void:
		get_tree().change_scene_to_file("res://scenes/overworld_prologue.tscn"))

func _perform_action() -> void:
	if action_running or action_ready:
		return
	action_running = true
	action_time = 0
	var goal: Vector3 = Vector3(-5,0,4)
	match str(event.requiredAction):
		"build_hull": goal = Vector3(5,0,5)
		"coat_pitch": goal = Vector3(6,0,4.5)
		"board_ark": goal = Vector3(3,0,4)
		"pray": goal = Vector3(0,0,5.8)
	_route(goal)
	_refresh_ui()

# Grid A* uses inflated, solid prop footprints. Every movement segment follows
# an unobstructed grid edge; diagonal corner cutting is deliberately disallowed.
func _blocked(cell: Vector2i) -> bool:
	var point: Vector2 = Vector2(cell)
	for rect in obstacles:
		if rect.has_point(point):
			return true
	return false

func _route(goal: Vector3) -> void:
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(-17,-12,35,25)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(-17,18):
		for z in range(-12,13):
			var cell: Vector2i = Vector2i(x,z)
			grid.set_point_solid(cell,_blocked(cell))
	var from: Vector2i = Vector2i(roundi(noah.position.x),roundi(noah.position.z))
	var to: Vector2i = Vector2i(roundi(goal.x),roundi(goal.z))
	waypoints.clear()
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to) or grid.is_point_solid(to):
		return
	for point in grid.get_id_path(from,to):
		waypoints.append(Vector3(point.x,0,point.y))
	waypoints.append(goal)

func _play(clip: String) -> void:
	if animation == clip or player == null or not player.has_animation(clip):
		return
	animation = clip
	player.play(clip,.22)

func _process(delta: float) -> void:
	if noah == null:
		return
	elapsed += delta
	rig.position = rig.position.lerp(focus,1.0-exp(-delta*2.0))
	var moving: bool = not waypoints.is_empty() and noah.visible
	if moving:
		var direction: Vector3 = waypoints[0]-noah.position
		if direction.length() < .04:
			waypoints.pop_front()
		else:
			noah.position = noah.position.move_toward(waypoints[0],delta*2.8)
			noah.look_at(noah.global_position + direction.normalized(),Vector3.UP)
		_play("Walk")
	elif prayer:
		noah.look_at(Vector3(0,0,7.2),Vector3.UP)
		_play("Pray")
	else:
		_play("Idle")
	if action_running and not moving:
		action_time += delta
		if action_time >= (2.8 if prayer else 1.2):
			action_ready = true
			action_running = false
			_refresh_ui()
	if sheep.visible:
		for i in range(sheep.get_child_count()):
			var animal: Node3D = sheep.get_child(i) as Node3D
			animal.position.z = 4.9+float(i/2)*1.3+sin(elapsed*.5+i)*.35

func _unhandled_input(input: InputEvent) -> void:
	if input is InputEventMouseButton and input.pressed and input.button_index == MOUSE_BUTTON_LEFT and phase != "flood" and not prayer and not action_running:
		var origin: Vector3 = camera.project_ray_origin(input.position)
		var direction: Vector3 = camera.project_ray_normal(input.position)
		var hit: Variant = Plane(Vector3.UP,0).intersects_ray(origin,direction)
		if hit != null:
			_route(hit)

func _exit_tree() -> void:
	Loader.clear_cache()
