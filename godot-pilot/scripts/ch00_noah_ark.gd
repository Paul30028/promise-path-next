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
var family: Array[Node3D] = []
var family_players: Array[AnimationPlayer] = []
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []

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
	environment.ambient_light_energy = .32
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
	camera.position = Vector3(-12.5,13.5,20.5)
	camera.fov = 38
	camera.h_offset = 2.8
	camera.far = 220
	rig.add_child(camera)
	camera.look_at(Vector3(-2.0,2.0,-0.5))
	camera.current = true
	ground_material = _material(Color(.69,.59,.44))
	ground_material.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
	ground_material.normal_enabled = true
	ground_material.normal_texture = load("res://assets/textures/terrain_rock_normal.png")
	ground_material.normal_scale = .32
	ground_material.uv1_triplanar = true
	ground_material.uv1_scale = Vector3(.2,.2,.2)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "SculptedAraratTerrain"
	ground.mesh = _terrain_mesh()
	ground.material_override = ground_material
	add_child(ground)
	_build_valley()
	var stone: StandardMaterial3D = _material(Color(.66,.64,.59),.88)
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
		node.mesh = _crag_mesh(hill,float(i))
		var hill_mat: StandardMaterial3D = _material(Color(.46+i*.008,.44+i*.006,.38), .95)
		hill_mat.albedo_texture = load("res://assets/textures/terrain_rock_albedo.png")
		hill_mat.uv1_triplanar = true
		hill_mat.uv1_scale = Vector3(.15,.15,.15)
		node.material_override = hill_mat
		node.position = Vector3(-48+i*10,-1.5,-42 - absf(sin(i))*10)
		node.scale = Vector3(13 + i%4, 7.5 + (i%3)*2.8, 10)
		add_child(node)
	ark = _asset("BLD_NoahsArk.glb",4.0,Vector3(1.8,0,-5.0))
	var bounds: AABB = Loader._compute_local_aabb(ark)
	obstacles.append(Rect2(Vector2(ark.position.x+bounds.position.x-.35,ark.position.z-2.8),Vector2(bounds.size.x+.7,5.5)))
	noah = _asset("CHR_Noah_rigged.glb",1.65,Vector3(-7,0,6))
	_build_family()
	_build_boarding_path()
	yard = Node3D.new()
	yard.name = "TimberStacks"
	add_child(yard)
	var wood: StandardMaterial3D = _material(Color(.32,.19,.085))
	wood.albedo_texture = load("res://assets/textures/wood_timber_albedo.png")
	for i in range(10):
		_box(yard,Vector3(3,.25,.28),Vector3(-5,.125 + float(i/4)*.25,1.5 + (i%4)*.32),wood)
	obstacles.append(Rect2(-7,1,4,2.5))
	stakes = Node3D.new()
	stakes.name = "YardStakes"
	add_child(stakes)
	for x in [-10.5,10.5]:
		for z in [-4.5,.5]:
			_box(stakes,Vector3(.12,.75,.12),Vector3(x,terrain_height(x,z)+.375,z),wood)
	provisions = Node3D.new()
	provisions.name = "PitchAndProvisions"
	add_child(provisions)
	for i in range(5):
		_asset("CC0_Amphora.glb",.8,_grounded(Vector3(7+i*.6,0,3)),provisions)
	var pot: MeshInstance3D = MeshInstance3D.new()
	pot.name = "PitchCauldron"
	var pot_mesh: CylinderMesh = CylinderMesh.new()
	pot_mesh.top_radius = .52
	pot_mesh.bottom_radius = .38
	pot_mesh.height = .65
	pot.mesh = pot_mesh
	pot.position = Vector3(6,terrain_height(6,3)+.325,3)
	pot.material_override = _material(Color(.07,.045,.025))
	provisions.add_child(pot)
	var pitch_mesh: CylinderMesh = CylinderMesh.new()
	pitch_mesh.top_radius = .46
	pitch_mesh.bottom_radius = .46
	pitch_mesh.height = .025
	var pitch: MeshInstance3D = MeshInstance3D.new()
	pitch.mesh = pitch_mesh
	pitch.position = Vector3(6,terrain_height(6,3)+.66,3)
	pitch.material_override = _material(Color(.025,.018,.012),.45)
	provisions.add_child(pitch)
	obstacles.append(Rect2(6.5,2.5,3.8,1.2))
	foliage = Node3D.new()
	foliage.name = "FramingOlives"
	add_child(foliage)
	for pos in [Vector3(-14,0,-6),Vector3(13,0,7),Vector3(-14,0,8)]:
		_asset("CC0_OliveTree_Optimized.glb",3.5,_grounded(pos),foliage)
		obstacles.append(Rect2(Vector2(pos.x-.8,pos.z-.8),Vector2(1.6,1.6)))
	fence = Node3D.new()
	fence.name = "GuardFence"
	add_child(fence)
	for i in range(9):
		for z in [.65,3.9]:
			_box(fence,Vector3(.12,1.2,.12),Vector3(-7+i*.5,.6,z),wood)
	for z in [.65,3.9]:
		for y in [.45,.9]:
			_box(fence,Vector3(4.2,.1,.1),Vector3(-5,y,z),wood)
	fence.hide()
	altar = Node3D.new()
	altar.name = "AltarGroup"
	altar.position = Vector3(0,terrain_height(0,6.2),6.2)
	add_child(altar)
	var limestone: StandardMaterial3D = _material(Color(.76,.73,.67),.92)
	limestone.albedo_texture = stone.albedo_texture
	limestone.uv1_triplanar = true
	for i in range(14):
		var rock: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = .4
		mesh.height = .5
		mesh.radial_segments = 7
		mesh.rings = 3
		rock.mesh = _crag_mesh(mesh,float(i))
		rock.material_override = limestone
		var a: float = float(i%7)*TAU/7.0
		rock.position = Vector3(cos(a)*.65,.25+float(i/7)*.32,sin(a)*.55)
		rock.scale = Vector3(1.0 + .14*sin(i*2.3),1.0 + .12*cos(i*1.7),1.0 + .17*sin(i))
		rock.rotation_degrees = Vector3(i%3*7,i*37,i%4*4)
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
	for i in range(5):
		var log_node: MeshInstance3D = _box(altar,Vector3(1.1,.12,.14),Vector3(0,.74+(i%2)*.12,(i-2)*.15),wood)
		log_node.rotation.y = .55 if i%2 == 0 else -.65
	_smoke(altar,Vector3(0,.9,0),false)
	var embers: OmniLight3D = OmniLight3D.new()
	embers.position.y = .9
	embers.light_color = Color(1,.55,.22)
	embers.light_energy = .55
	embers.omni_range = 3
	altar.add_child(embers)
	obstacles.append(Rect2(-1.2,5.35,2.4,1.7))
	terrace = Node3D.new()
	terrace.name = "WetStoneTerrace"
	add_child(terrace)
	_build_puddles()
	_build_outcrops(stone)
	altar.hide()
	shoots = Node3D.new()
	add_child(shoots)
	for pos in [Vector3(3.5,0,9.5),Vector3(-4,0,8),Vector3(-4,0,3.5)]:
		_asset("CC0_OliveTree_Optimized.glb",.85,_grounded(pos),shoots)
	shoots.hide()
	sheep = Node3D.new()
	sheep.name = "AnimalPairs"
	add_child(sheep)
	var species: Array[String] = ["ANI_Ox.glb","CC0_Sheep_Grab3D.glb","ANI_Goat.glb","ANI_Donkey.glb"]
	for i in range(8):
		var animal: Node3D = _asset(species[i/2],1.05 if i/2 != 1 else .75,Vector3.ZERO,sheep)
		_animate(animal,"Walk")
	_build_birds()
	sheep.hide()
	water = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(180,160)
	water.mesh = plane
	water.material_override = _material(Color(.075,.13,.15),.23)
	water.position.y = -7
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
			var radius: float = 7.5+vertex.y*1.1
			surface.set_uv(Vector2(u,vertex.y))
			surface.add_vertex(Vector3(cos(a)*radius,sin(a)*radius,0))
	surface.generate_normals()
	rainbow = MeshInstance3D.new()
	rainbow.name = "VFX_CovenantRainbow"
	rainbow.mesh = surface.commit()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/VFX_CovenantRainbow.gdshader")
	rainbow.material_override = mat
	rainbow.position = Vector3(-9.5,-2.0,-11.0)
	rainbow.rotation_degrees.y = 26.0
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
	hud_panel.visible = not bool(event.get("hideResourceHud",false)) and str(event.id) not in ["noah_01_revelation","noah_07_exit_altar","noah_08_rainbow_covenant"]
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
	provisions.visible = int(event.arkStage) >= 3 and phase == "build"
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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-scene=") or arg.begins_with("--stage=") or arg == "--ararat":
			mood_tween.custom_step(4.0)
			if phase != "flood":
				water_tween.custom_step(4.0)
	_pose_family()
	_update_procession(0.0)
	_update_birds()
	# Seek all active clips before the first preview frame.
	for animator: AnimationPlayer in family_players:
		if animator != null:
			animator.advance(0.0)
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
	mood_tween.tween_property(sun,"light_color",Color(.64,.7,.78) if storm else Color(1,.94,.82),2)
	mood_tween.tween_property(sun,"light_energy",.3 if storm else (1.05 if morning else 1.0),2)
	mood_tween.tween_property(sky_material,"sky_top_color",Color(.13,.17,.22) if storm else Color(.3,.5,.66),2)
	mood_tween.tween_property(sky_material,"sky_horizon_color",Color(.38,.43,.46) if storm else Color(.86,.8,.65),2)
	mood_tween.tween_property(environment,"fog_density",.022 if storm else (.006 if morning else .003),3)
	mood_tween.tween_property(environment,"fog_light_color",Color(.4,.48,.52) if storm else Color(.85,.82,.71),2)
	mood_tween.tween_property(ground_material,"albedo_color",Color(.65,.61,.54) if morning else Color(.69,.59,.44),2)
	mood_tween.tween_property(ground_material,"roughness",.36 if morning else .95,2)
	flood_finished = not storm
	if storm:
		water_tween = create_tween()
		water_tween.tween_property(water,"position:y",3.4,5).set_trans(Tween.TRANS_SINE)
		water_tween.tween_interval(2)
		water_tween.tween_property(water,"position:y",-7.0,7).set_trans(Tween.TRANS_SINE)
		water_tween.tween_callback(func() -> void:
			flood_finished = true
			rain.emitting = false
			shoots.show()
			_refresh_ui())
	else:
		water_tween = create_tween()
		water_tween.tween_property(water,"position:y",-7.0,2)

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
	if not prayer:
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
		waypoints.append(_grounded(Vector3(point.x,0,point.y)))
	waypoints.append(_grounded(goal))

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
			var facing: Vector3 = Vector3(direction.x,0,direction.z)
			if facing.length_squared() > .0001:
				noah.look_at(noah.global_position + facing,Vector3.UP)
		_play("Walk")
	else:
		_play(_noah_clip())
	if action_running and not moving:
		action_time += delta
		if action_time >= (2.8 if prayer else 1.2):
			action_ready = true
			action_running = false
			_refresh_ui()
	_update_procession(delta)
	_update_birds()

func _unhandled_input(input: InputEvent) -> void:
	if input is InputEventMouseButton and input.pressed and input.button_index == MOUSE_BUTTON_LEFT and phase != "flood" and not prayer and not action_running:
		var origin: Vector3 = camera.project_ray_origin(input.position)
		var direction: Vector3 = camera.project_ray_normal(input.position)
		var hit: Variant = Plane(Vector3.UP,0).intersects_ray(origin,direction)
		if hit != null:
			# Refine the plane intersection against the same sculpted surface.
			var point: Vector3 = hit
			for i in range(6):
				var t: float = (terrain_height(point.x,point.z)-origin.y)/direction.y
				point = origin+direction*t
			_route(_grounded(point))

func _exit_tree() -> void:
	Loader.clear_cache()

# Shared analytic surface for scenery, props, footsteps, and preview poses.
func terrain_height(x: float, z: float) -> float:
	var valley: float = 1.0 - smoothstep(-11.5,-8.0,x)
	var shelf: float = smoothstep(-6.0,-2.0,x) * (1.0-smoothstep(-3.5,1.5,z))
	var terrace_mask: float = smoothstep(-8.0,-5.0,x) * (1.0-smoothstep(10.0,14.0,x)) * smoothstep(-.5,2.0,z) * (1.0-smoothstep(12.0,16.0,z))
	var relief: float = (sin(x*.53+z*.27)*.24+cos(z*.64-x*.21)*.19) * (1.0-terrace_mask)
	var river_x: float = -12.2 + sin(z*.105)*1.4
	var channel: float = (1.0-smoothstep(1.0,2.2,absf(x-river_x))) * valley
	return lerpf(1.4*shelf+relief,-5.5+relief*.4,valley)-channel*.45

func _grounded(pos: Vector3) -> Vector3:
	return Vector3(pos.x,terrain_height(pos.x,pos.z),pos.z)

func _terrain_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(52):
		for x in range(56):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var px: float = -55.0 + float(x+corner.x)*110.0/56.0
				var pz: float = -60.0 + float(z+corner.y)*100.0/52.0
				surface.set_uv(Vector2(px,pz)*.15)
				surface.add_vertex(Vector3(px,terrain_height(px,pz),pz))
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _smoke(parent: Node3D, pos: Vector3, mist: bool) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = "ValleyMist" if mist else "WhiteAltarSmoke"
	particles.position = pos
	particles.amount = 14 if mist else 14
	particles.lifetime = 9.0 if mist else 3.2
	particles.preprocess = particles.lifetime
	particles.direction = Vector3(.12,1,.04)
	particles.spread = 16.0
	particles.gravity = Vector3(.01,.02,0)
	particles.initial_velocity_min = .035 if mist else .15
	particles.initial_velocity_max = .19 if mist else .62
	particles.scale_amount_min = 1.4 if mist else .18
	particles.scale_amount_max = 3.2 if mist else .48
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(3,.2,2) if mist else Vector3(.10,.04,.10)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0,Color(.92,.94,.95,0))
	gradient.add_point(.25,Color(.92,.94,.95,.07 if mist else .085))
	gradient.set_color(1,Color(.92,.94,.95,0))
	particles.color_ramp = gradient
	var quad: QuadMesh = QuadMesh.new()
	var mat: StandardMaterial3D = _material(Color(1,1,1,.045 if mist else .16))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var texture: GradientTexture2D = GradientTexture2D.new()
	var radial: Gradient = Gradient.new()
	radial.set_color(0,Color.WHITE)
	radial.set_color(1,Color(1,1,1,0))
	texture.gradient = radial
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	mat.albedo_texture = texture
	quad.material = mat
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)

func _build_valley() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(100):
		for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
			var z: float = -60.0+float(i+corner.y)
			var x: float = -12.2+sin(z*.105)*1.4+(float(corner.x)-.5)*1.9
			surface.set_uv(Vector2(float(corner.x),float(i+corner.y)*.05))
			surface.add_vertex(Vector3(x,-5.62,z))
	surface.generate_normals()
	var river: MeshInstance3D = MeshInstance3D.new()
	river.name = "WindingValleyRiver"
	river.mesh = surface.commit()
	var mat: StandardMaterial3D = _material(Color(.16,.28,.34),.12)
	mat.metallic = .22
	river.material_override = mat
	add_child(river)
	for i in range(5):
		_smoke(self,Vector3(-15.0+sin(i)*2,-4.3,-25.0+i*10),true)

func _build_puddles() -> void:
	var wet: StandardMaterial3D = _material(Color(.18,.23,.26,.55),.08)
	wet.metallic = .22
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spots: Array[Vector2] = [Vector2(-3.8,4.6),Vector2(-2.2,8.4),Vector2(1.4,9.1),Vector2(3.6,7.8),Vector2(-4.4,7.1),Vector2(4.8,4.5),Vector2(0.8,3.6),Vector2(-1.1,9.6)]
	for i in range(spots.size()):
		var x: float = spots[i].x
		var z: float = spots[i].y
		var puddle: MeshInstance3D = MeshInstance3D.new()
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = .55
		disc.bottom_radius = .55
		disc.height = .008
		disc.radial_segments = 24
		puddle.mesh = disc
		puddle.material_override = wet
		puddle.position = Vector3(x,terrain_height(x,z)+.02,z)
		puddle.scale = Vector3(1.1+sin(i*1.9)*.35,1,.65+float(i%3)*.18)
		puddle.rotation.y = i*1.3
		terrace.add_child(puddle)

func _build_outcrops(mat: Material) -> void:
	for i in range(65):
		var x: float = -9.0+sin(i*2.399)*2.1
		var z: float = -22.0+float(i)*.61
		if i > 39:
			x = 2.5+cos(i*2.399)*10.8
			z = -2.0+sin(i*2.399)*3.2
		var rock: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radial_segments = 7
		mesh.rings = 4
		rock.mesh = mesh
		rock.material_override = mat
		rock.position = _grounded(Vector3(x,0,z))
		rock.scale = Vector3(1.0+float(i%3)*.4,.55+float(i%5)*.28,.8+float(i%4)*.25)
		rock.rotation_degrees = Vector3(i*13,i*47,i*7)
		add_child(rock)

func _animate(actor: Node3D, clip: String) -> AnimationPlayer:
	var animator: AnimationPlayer = actor.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animator != null and animator.has_animation(clip):
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animator.play(clip)
		animator.advance(0.0)
	return animator

func _build_family() -> void:
	family.append(noah)
	var files: Array[String] = ["CHR_Noah_Wife_rigged.glb","CHR_Noah_Son_rigged.glb","CHR_Noah_Son_rigged.glb","CHR_Noah_Son_rigged.glb","CHR_Noah_Daughter_rigged.glb","CHR_Noah_Daughter_rigged.glb","CHR_Noah_Daughter_rigged.glb"]
	for i in range(7):
		var member: Node3D = _asset(files[i],1.5+float(i%3)*.06,Vector3.ZERO)
		member.name = "Wife" if i == 0 else ("Son%d" % i if i < 4 else "DaughterInLaw%d" % (i-3))
		family.append(member)
	for member: Node3D in family:
		var animator: AnimationPlayer = _animate(member,"Idle")
		if animator != null:
			for clip: String in ["Idle","Walk","Pray","Hammer","BrushPitch","Bless"]:
				if animator.has_animation(clip):
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		family_players.append(animator)
	player = family_players[0]

func _noah_clip() -> String:
	if prayer:
		return "Bless"
	if str(event.id) in ["noah_02_keel_mortise","noah_03_hull_decks"]:
		return "Hammer"
	if str(event.id) == "noah_04_pitch_provisions":
		return "BrushPitch"
	return "Idle"

func _pose_family() -> void:
	waypoints.clear()
	var worship: Array[Vector3] = [Vector3(0,0,4.65),Vector3(2.7,0,5.5),Vector3(-2.7,0,5.5),Vector3(-1.5,0,4.6),Vector3(1.5,0,4.6),Vector3(-1.65,0,7.6),Vector3(1.65,0,7.6),Vector3(3.1,0,6.8)]
	var work: Array[Vector3] = [Vector3(-4,0,1.5),Vector3(8,0,4),Vector3(-1.5,0,1.8),Vector3(2.5,0,1.9),Vector3(5.7,0,1.7),Vector3(8.9,0,4.6),Vector3(7.2,0,5.2),Vector3(9.5,0,5.7)]
	if str(event.id) == "noah_04_pitch_provisions":
		work[0] = Vector3(5.2,0,3.2)
		work[2] = Vector3(6.7,0,3.8)
		work[3] = Vector3(4.8,0,2)
		work[4] = Vector3(7.4,0,2)
	for i in range(family.size()):
		var member: Node3D = family[i]
		member.visible = phase != "flood"
		member.position = _grounded(worship[i] if prayer else work[i])
		var target: Vector3 = altar.position if prayer else Vector3(member.position.x,member.position.y,-2)
		if i == 0 and prayer:
			target = member.position+Vector3(0,0,4)
		target.y = member.position.y
		member.look_at(target,Vector3.UP)
		var clip: String = "Idle"
		if prayer:
			clip = "Bless" if i == 0 else ("Pray" if i in [5,6] else "Idle")
		elif i in [0,2,3,4]:
			clip = _noah_clip()
		_animate(member,clip)
	animation = _noah_clip()

func _build_boarding_path() -> void:
	# Asset-space plank centres from the upgraded GLB, including normalization.
	var model: Node3D = ark.get_child(0) as Node3D
	boarding_path = [_grounded(ark.position+Vector3(1.0,0,14.0)),_grounded(ark.position+Vector3(0,0,8.0))]
	for local_point: Vector3 in [Vector3(0,-.17,6.35),Vector3(0,1.22,2.58),Vector3(0,1.22,1.8)]:
		boarding_path.append(ark.position+model.transform*local_point)

func _update_procession(_delta: float) -> void:
	if sheep == null or not sheep.visible:
		return
	var lengths: Array[float] = []
	var total: float = 0.0
	for i in range(boarding_path.size()-1):
		var segment: float = boarding_path[i].distance_to(boarding_path[i+1])
		lengths.append(segment)
		total += segment
	for i in range(sheep.get_child_count()):
		var animal: Node3D = sheep.get_child(i) as Node3D
		var distance: float = fposmod(elapsed*.65+total*.7-float(i/2)*1.65,total)
		animal.visible = distance < total-.25
		for j in range(lengths.size()):
			if distance > lengths[j]:
				distance -= lengths[j]
				continue
			var direction: Vector3 = (boarding_path[j+1]-boarding_path[j]).normalized()
			animal.position = boarding_path[j].lerp(boarding_path[j+1],distance/lengths[j])
			animal.position.x += -.29 if i%2 == 0 else .29
			if j < 2:
				animal.position.y = terrain_height(animal.position.x,animal.position.z)
			animal.position.y += absf(sin(elapsed*6.0+i))*.035
			_stride(animal,i)
			animal.look_at(animal.position+Vector3(direction.x,0,direction.z),Vector3.UP)
			break

func _build_birds() -> void:
	for file: String in ["ANI_Raven.glb","ANI_Dove_Olive.glb"]:
		var bird: Node3D = _asset(file,.38,Vector3.ZERO)
		birds.append(bird)
		_animate(bird,"Fly")

func _update_birds() -> void:
	for i in range(birds.size()):
		var bird: Node3D = birds[i]
		bird.visible = str(event.get("id","")) in ["noah_06_flood_dove","noah_07_exit_altar"]
		var angle: float = elapsed*.28+float(i)*PI
		bird.position = Vector3(-3+cos(angle)*(7+i*2),6.5+i+sin(angle*2)*.45,-5+sin(angle)*4)
		var tangent: Vector3 = Vector3(-sin(angle)*(7+i*2),cos(angle*2)*.9,cos(angle)*4)
		bird.look_at(bird.position+tangent,Vector3.UP)
		bird.rotation.z = sin(angle)*.12
		for wing_index in [3,4]:
			var wing: Node3D = bird.find_child("Bird_%d" % wing_index,true,false) as Node3D
			if wing != null:
				var flap: float = sin(elapsed*5.5+i)*.3*(1 if wing_index == 3 else -1)
				_pivot_part(wing,Vector3(0,.06,-.02),Vector3(0,0,1),flap)

func _crag_mesh(source: SphereMesh, seed_value: float) -> ArrayMesh:
	var arrays: Array = source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var displacement: float = 1.0 + .16*sin(v.x*13.0+seed_value)*cos(v.z*11.0-seed_value) + .09*sin(v.y*17.0+v.x*7.0)
		vertices[i] = v*displacement
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.create_from(mesh,0)
	surface.generate_normals()
	return surface.commit()

func _pivot_part(part: Node3D, pivot: Vector3, axis: Vector3, angle: float) -> void:
	if not part.has_meta("rest_transform"):
		part.set_meta("rest_transform",part.transform)
	var rest: Transform3D = part.get_meta("rest_transform")
	var rotation_basis: Basis = Basis(axis,angle)
	part.transform = rest*Transform3D(rotation_basis,pivot-rotation_basis*pivot)

func _stride(animal: Node3D, index: int) -> void:
	# Generated quadrupeds have separate baked leg parts, but no skeletal clips.
	for leg_index in range(1,5):
		var leg: Node3D = animal.find_child("Part_%d" % leg_index,true,false) as Node3D
		if leg != null:
			if not leg.has_meta("hip"):
				var bounds: AABB = Loader._compute_local_aabb(leg)
				leg.set_meta("hip",Vector3(bounds.get_center().x,bounds.end.y,bounds.get_center().z))
			var hip: Vector3 = leg.get_meta("hip")
			_pivot_part(leg,hip,Vector3.RIGHT,sin(elapsed*6.0+index+float(leg_index%3)*PI)*.28)
