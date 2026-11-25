class_name NoahCastAndRaidRig
extends Node3D
## Modular Cast, RVO Worker Logistics, Layered AnimationTree, Two-Prong Torch Raid & Auto-Boarding Director:
## Extracted cleanly out of `ch00_noah_ark.gd` so the chapter coordinator stays <= 350 lines!

signal timber_fire_ignited
signal raid_crisis_resolved
signal all_boarded_ready

var world: NoahRTSWorld
var sim: DeterministicEconomySim
var hero_body: PatriarchPlayer3D

var family: Array[Node3D] = []
var family_nameplates: Array[Label3D] = []
var family_ai_phase: Array[float] = []
var worker_jobs: Array[Dictionary] = []
var build_hit_timers: Array[float] = []
var hitstop_timers: Dictionary = {}

var hired_workers: Array[Node3D] = []
var villagers: Array[Node3D] = []
var raiders: Array[Node3D] = []
var raider_morale: Array[float] = []
var raider_bars: Array[MeshInstance3D] = []
var raider_labels: Array[Label3D] = []

var fence_status_root: Node3D
var fence_hp_bar: MeshInstance3D
var fence_status_label: Label3D
var raider_clash_sfx_timer: float = 0.0
var fire_triggered_once: bool = false
var auto_douse_timer: float = 0.0
var crisis_resolved: bool = false

var animal_root: Node3D
var animals: Array[Node3D] = []
var birds: Array[Node3D] = []
var boarding_path: Array[Vector3] = []
var family_boarded: Array[bool] = []
var family_board_wp: Array[int] = []
var animal_boarded: Array[bool] = []
var animal_board_dist: Array[float] = []
var boarding_complete_timer: float = 0.0
var dove_flight_active: bool = false
var dove_flight_t: float = 0.0


func _sfx(file: String, vol: float = -5.0) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.call("play_sfx", file, vol)


func build_cast(w: NoahRTSWorld, s: DeterministicEconomySim, cast_cfg: Array) -> PatriarchPlayer3D:
	world = w
	sim = s
	var fam_files: Array[String] = [
		"CHR_Noah_rigged.glb", "CHR_Noah_Wife_rigged.glb",
		"CHR_Noah_Son_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Son_rigged.glb",
		"CHR_Noah_Daughter_rigged.glb", "CHR_Noah_Daughter_rigged.glb", "CHR_Noah_Daughter_rigged.glb",
	]

	hero_body = PatriarchPlayer3D.new()
	hero_body.name = "NoahPlayerBody"
	hero_body.setup_capsule(1.72, 0.36)
	add_child(hero_body)

	for i in range(fam_files.size()):
		var h: float = 1.72 if i == 0 else (1.58 if i == 1 or i >= 5 else 1.65)
		var actor: Node3D = world.spawn_asset(fam_files[i], h, world.grounded(float(i) * 1.4, 21.0), self)
		actor.name = "Family_%d" % i
		if i == 0:
			hero_body.warp_to(world.grounded(-2.0, 18.0))
			hero_body.attach_visual(actor)
		family.append(actor)
		family_ai_phase.append(float(i) * 1.37)
		build_hit_timers.append(float(i) * 0.27)
		worker_jobs.append({"phase": "to_tree", "tree_idx": -1, "chop_timer": 0.0})
		_attach_hand_tool(actor, "WPN_Mallet.glb")
		_attach_left_shield(actor)
		if i > 0:
			var lg: Node3D = _attach_carried_log(actor)
			lg.hide()
		HumanoidRigHelper.setup_layered_anim_tree(actor)

		var np_lbl: Label3D = Label3D.new()
		var cinfo: Dictionary = cast_cfg[i] if i < cast_cfg.size() else {}
		np_lbl.set_meta("name_zh", str(cinfo.get("nameZh", "家人")))
		np_lbl.set_meta("name_en", str(cinfo.get("nameEn", "Family")))
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

	for i in range(2):
		var hw: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.62, world.grounded(18.0 + float(i) * 2.2, 16.0), self)
		_attach_hand_tool(hw, "WPN_Mallet.glb")
		HumanoidRigHelper.setup_layered_anim_tree(hw)
		hw.hide()
		hired_workers.append(hw)

	for i in range(4):
		var v: Node3D = world.spawn_asset("CHR_Abram_rigged.glb" if i % 2 == 0 else "CHR_Noah_Son_rigged.glb", 1.62, world.grounded(-5.0 + float(i) * 2.8, 42.0), self)
		HumanoidRigHelper.setup_layered_anim_tree(v)
		v.hide()
		villagers.append(v)

	for i in range(5):
		var r: Node3D = world.spawn_asset("CHR_Noah_Son_rigged.glb", 1.68, world.grounded(-18.5 + float(i) * 3.0, 46.0), self)
		_add_torch(r)
		_attach_hand_tool(r, "WPN_BronzeSword.glb")
		HumanoidRigHelper.setup_layered_anim_tree(r)
		var mb: Dictionary = attach_status_bar(r, 2.12, "100%", Color(0.92, 0.28, 0.18), 1.15)
		raider_bars.append(mb["fill"] as MeshInstance3D)
		raider_labels.append(mb["lbl"] as Label3D)
		raider_morale.append(100.0)
		r.hide()
		raiders.append(r)

	fence_status_root = Node3D.new()
	fence_status_root.position = world.grounded(-12.5, 22.5, 2.55)
	add_child(fence_status_root)
	var fb: Dictionary = attach_status_bar(fence_status_root, 0.0, "", Color(0.30, 0.82, 0.42), 2.4)
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
		play_simple_anim(ani, "Idle")
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
		var b: Node3D = world.spawn_asset(bf, 0.72, Vector3(0.0, 16.0, 0.0), self)
		b.hide()
		birds.append(b)
	return hero_body


static func play_simple_anim(actor: Node3D, clip: String, upper_clip: String = "", upper_w: float = 0.0) -> void:
	if actor.find_child("LayeredAnimTree", false, false) != null:
		HumanoidRigHelper.play_layered(actor, clip, upper_clip, upper_w)
		return
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if ap.current_animation != clip:
			ap.play(clip, 0.18)


static func attach_status_bar(parent: Node3D, y_off: float, init_text: String, fill_col: Color, width: float = 1.25) -> Dictionary:
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


static func update_bar_visual(fill: MeshInstance3D, ratio: float, col_high: Color, col_low: Color) -> void:
	if fill == null or not is_instance_valid(fill):
		return
	var r: float = clampf(ratio, 0.0, 1.0)
	fill.scale.x = maxf(0.02, r)
	var mat: StandardMaterial3D = fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = col_low.lerp(col_high, r)


func _attach_hand_tool(actor: Node3D, glb_file: String) -> void:
	var skel: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null: return
	var bi: int = skel.find_bone("Forearm_R")
	if bi < 0: bi = skel.find_bone("UpperArm_R")
	if bi < 0: return
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "RightHandTool"
	ba.bone_idx = bi
	skel.add_child(ba)
	var tn: Node3D = world.spawn_asset(glb_file, 0.44 if "Sword" in glb_file else 0.40, Vector3(0.0, -0.22, -0.04), ba)
	tn.rotation_degrees = Vector3(-82.0, 0.0, 0.0)


func _attach_left_shield(actor: Node3D) -> void:
	var skel: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null: return
	var bi: int = skel.find_bone("Forearm_L")
	if bi < 0: bi = skel.find_bone("UpperArm_L")
	if bi < 0: return
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "LeftHandShield"
	ba.bone_idx = bi
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
		var sc: float = (0.56 / max_dim) / skel_sc
		sh.scale = Vector3.ONE * sc
		sh.position = Vector3(-0.08, -0.10, -0.06) / skel_sc
		sh.rotation_degrees = Vector3(12.0, 82.0, 0.0)
	ba.hide()


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


func set_actor_props(actor: Node3D, show_log: bool, show_tool: bool, show_shield: bool = false) -> void:
	var lg: Node3D = actor.find_child("CarriedLog", false, false) as Node3D
	if lg != null: lg.visible = show_log
	var tl: Node3D = actor.find_child("RightHandTool", true, false) as Node3D
	if tl != null: tl.visible = show_tool
	var sh: Node3D = actor.find_child("LeftHandShield", true, false) as Node3D
	if sh != null: sh.visible = show_shield


func sync_locale_labels(locale_code: String) -> void:
	var is_en: bool = (locale_code == "en_US")
	for npl in family_nameplates:
		if npl != null:
			npl.text = str(npl.get_meta("name_en" if is_en else "name_zh", ""))


func trigger_local_hitstop(actor: Node3D, duration: float = 0.035) -> void:
	var tree: AnimationTree = actor.find_child("LayeredAnimTree", false, false) as AnimationTree
	if tree != null:
		tree.set("parameters/TimeScale/scale", 0.05)
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.speed_scale = 0.04
	hitstop_timers[actor.get_instance_id()] = duration


func update_hitstops(delta: float) -> void:
	if hitstop_timers.is_empty(): return
	var done_ids: Array = []
	for iid in hitstop_timers.keys():
		var rem: float = float(hitstop_timers[iid]) - delta
		if rem <= 0.0:
			done_ids.append(iid)
			var obj: Object = instance_from_id(int(iid))
			if obj is Node3D:
				var ap: AnimationPlayer = (obj as Node3D).find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap != null: ap.speed_scale = 1.0
		else:
			hitstop_timers[iid] = rem
	for iid in done_ids:
		hitstop_timers.erase(iid)


func restore_all_to_world() -> void:
	if family.size() > 0 and family[0].get_parent() != hero_body:
		hero_body.attach_visual(family[0])
	for i in range(1, family.size()):
		if family[i].get_parent() != self:
			family[i].reparent(self, false)
	for ani in animals:
		if ani.get_parent() != animal_root:
			ani.reparent(animal_root, false)


func stage_raiders(preview: bool, fp_mode: bool) -> void:
	crisis_resolved = false
	fire_triggered_once = false
	for i in range(raiders.size()):
		raider_morale[i] = 68.0 if (preview and not fp_mode) else 100.0
		if i < 3:
			var rx: float = -20.0 + float(i) * 4.2
			var rz: float = 24.4 if (preview and not fp_mode) else (44.0 + float(i % 2) * 3.0)
			raiders[i].position = world.grounded(rx, rz)
			raiders[i].look_at(world.grounded(rx, 18.0), Vector3.UP)
		else:
			var fx: float = 10.0 + float(i - 3) * 4.5
			var fz: float = 26.0 if (preview and not fp_mode) else 38.0
			raiders[i].position = world.grounded(fx, fz)
			raiders[i].look_at(world.grounded(-12.0, 16.0), Vector3.UP)
		raiders[i].show()


func tick_workers_and_raid(delta: float, elapsed: float, act_id: String, cam_ctrl: RTSCameraController, preview: bool) -> void:
	var assigned: int = 0
	var guard_slot: int = 0
	var rain_mul: float = sim.cfg.rain_mud_speed_mul if sim.days_remaining < 25.0 else 1.0

	for k in range(1, family.size()):
		var member: Node3D = family[k]
		var role: String = "guard"
		if assigned < sim.w_gather: role = "log"
		elif assigned < sim.w_gather + sim.w_build: role = "build"
		elif assigned < sim.w_gather + sim.w_build + sim.w_craft: role = "pitch"
		assigned += 1

		match role:
			"log":
				var job: Dictionary = worker_jobs[k]
				var phase: String = str(job.get("phase", "to_tree"))
				var p_depot: Vector3 = world.grounded(-14.5, 15.2 + float(k % 3) * 1.1)
				if phase == "to_depot":
					var to_d: Vector3 = Vector3(p_depot.x - member.position.x, 0.0, p_depot.z - member.position.z)
					if to_d.length() < 1.15:
						var gained: int = sim.deposit_gathered_trip()
						_sfx("sfx_hammer.wav", -6.0)
						var pop_fmt: String = "+%d %s" % [gained, tr("RES_TIMBER") if tr("RES_TIMBER") != "RES_TIMBER" else "歌斐木"]
						world.spawn_floating_text_3d(p_depot + Vector3(0.0, 2.1, 0.0), pop_fmt, Color(1.0, 0.90, 0.44))
						job.phase = "to_tree"
						job.tree_idx = -1
						set_actor_props(member, false, true, false)
					else:
						var rvo_step: Vector3 = HumanoidRigHelper.compute_rvo_step(member, p_depot, 6.8 * rain_mul, family, 0.62, delta)
						var np: Vector3 = member.position + rvo_step
						np.y = world.terrain_height(np.x, np.z)
						member.position = np
						if rvo_step.length_squared() > 0.0001:
							member.look_at(member.position + rvo_step.normalized(), Vector3.UP)
						set_actor_props(member, true, false, false)
						# Layered AnimationTree: Walk legs + Carry upper body!
						play_simple_anim(member, "Walk", "Bless", 0.35)
				else:
					var tidx: int = int(job.get("tree_idx", -1))
					if tidx < 0 or tidx >= world.forest_trees.size() or bool(world.forest_trees[tidx].felled):
						tidx = world.find_standing_tree_near(k)
						job.tree_idx = tidx
					if tidx < 0:
						play_simple_anim(member, "Idle")
						continue
					var tpos: Vector3 = (world.forest_trees[tidx].pos as Vector3) + Vector3(-1.1, 0.0, 0.4)
					tpos.y = world.terrain_height(tpos.x, tpos.z)
					var to_t: Vector3 = Vector3(tpos.x - member.position.x, 0.0, tpos.z - member.position.z)
					if to_t.length() > 1.25:
						var rvo_t: Vector3 = HumanoidRigHelper.compute_rvo_step(member, tpos, 7.6 * rain_mul, family, 0.62, delta)
						var np2: Vector3 = member.position + rvo_t
						np2.y = world.terrain_height(np2.x, np2.z)
						member.position = np2
						if rvo_t.length_squared() > 0.0001:
							member.look_at(member.position + rvo_t.normalized(), Vector3.UP)
						set_actor_props(member, false, true, false)
						play_simple_anim(member, "Run", "Hammer", 0.25)
					else:
						var lt: Vector3 = world.forest_trees[tidx].pos as Vector3
						lt.y = member.position.y
						member.look_at(lt, Vector3.UP)
						set_actor_props(member, false, true, false)
						play_simple_anim(member, "Hammer")
						job.chop_timer = float(job.get("chop_timer", 0.0)) + delta
						if float(job.chop_timer) >= sim.cfg.chop_interval_sec:
							job.chop_timer = 0.0
							trigger_local_hitstop(member, 0.035)
							if world.chop_tree(tidx, sim.cfg.tree_chop_hits):
								_sfx("sfx_hammer.wav", -5.0)
								job.phase = "to_depot"
								set_actor_props(member, true, false, false)

			"build":
				if act_id == "noah_03_hull_decks" and sim.palisade_building and k <= 3:
					var fx: float = -22.0 + clampf(sim.palisade_pct / 100.0, 0.0, 1.0) * 20.0 + float(k % 2) * 1.6
					member.position = world.grounded(fx, 21.3)
					member.look_at(world.grounded(fx, 23.0), Vector3.UP)
					set_actor_props(member, false, true, false)
					play_simple_anim(member, "Hammer")
				else:
					var bx: float = -18.0 + float(k % 4) * 10.5
					member.position = world.grounded(bx, 10.2)
					member.look_at(world.grounded(bx, 0.0), Vector3.UP)
					set_actor_props(member, false, true, false)
					play_simple_anim(member, "BrushPitch" if act_id == "noah_04_pitch_provisions" else "Hammer")
					build_hit_timers[k] += delta
					if build_hit_timers[k] >= 1.18:
						build_hit_timers[k] = 0.0
						if act_id != "noah_04_pitch_provisions":
							trigger_local_hitstop(member, 0.035)
							world.spawn_hit_particles(member.position + Vector3(0.0, 1.25, -0.8), false)
							if hero_body.global_position.distance_to(member.position) < 8.5:
								cam_ctrl.add_trauma(0.06)

			"pitch":
				var cyc: float = fposmod(elapsed * 0.16 + family_ai_phase[k], 2.0)
				var pt: float = 2.0 - cyc if cyc >= 1.0 else cyc
				var pa: Vector3 = world.spring_well.position + Vector3(1.2, 0.0, 0.5) if sim.fire_intensity > 0.02 else world.grounded(13.5 + float(k % 2) * 1.6, 15.0 + float(k % 3) * 1.1)
				var pb: Vector3 = world.grounded(-14.2, 16.2) if sim.fire_intensity > 0.02 else world.grounded(5.5, 16.5 + float(k % 2) * 1.1)
				var np3: Vector3 = pa.lerp(pb, pt)
				np3.y = world.terrain_height(np3.x, np3.z)
				var d: Vector3 = np3 - member.position
				member.position = np3
				if d.length_squared() > 0.0001:
					member.look_at(member.position + d.normalized(), Vector3.UP)
				set_actor_props(member, false, false, false)
				play_simple_anim(member, "Run" if sim.fire_intensity > 0.02 else "Walk")

			"guard":
				var gx: float = -19.5 + float(guard_slot) * 3.8
				guard_slot += 1
				var gz: float = 21.3 if (sim.palisade_hp > 0.0 or act_id != "noah_03_hull_decks") else 18.2
				member.position = world.grounded(gx, gz)
				member.look_at(world.grounded(gx, 42.0), Vector3.UP)
				var clashing: bool = (act_id == "noah_03_hull_decks" and not crisis_resolved)
				set_actor_props(member, false, true, true)
				play_simple_anim(member, "Brawl" if clashing else "Idle")

	if act_id == "noah_02_keel_mortise":
		for i in range(villagers.size()):
			var v: Node3D = villagers[i]
			var tg: Vector3 = world.grounded(-6.0 + float(i) * 3.2, 23.0)
			if v.position.distance_to(tg) > 0.4:
				v.position = v.position.move_toward(tg, delta * 2.4)
				v.look_at(tg, Vector3.UP)
				play_simple_anim(v, "Walk")
			else:
				play_simple_anim(v, "Idle")
		if sim.monument_pct >= 20.0:
			for i in range(hired_workers.size()):
				var hw: Node3D = hired_workers[i]
				var away: Vector3 = world.grounded(2.0 + float(i) * 2.5, 48.0)
				if hw.position.distance_to(away) > 0.5:
					hw.position = hw.position.move_toward(away, delta * 3.0)
					hw.look_at(away, Vector3.UP)
					play_simple_anim(hw, "Walk")
	elif act_id == "noah_03_hull_decks":
		_tick_raiders(delta, cam_ctrl, preview)


func _tick_raiders(delta: float, cam_ctrl: RTSCameraController, preview: bool) -> void:
	if raider_clash_sfx_timer > 0.0:
		raider_clash_sfx_timer -= delta
	var noah_pos: Vector3 = hero_body.global_position
	var noah_near: bool = family[0].visible and noah_pos.z > 15.0 and noah_pos.z < 28.0 and absf(noah_pos.x + 11.0) < 18.0

	if sim.palisade_building:
		var builders: int = maxi(1, sim.w_guard + mini(sim.w_build, 2))
		var rate: float = (5.5 + float(builders) * 3.4 + (4.5 if noah_near else 0.0)) * sim.harmony_multiplier()
		if sim.palisade_pct < 100.0:
			sim.palisade_pct = minf(100.0, sim.palisade_pct + rate * delta)
			sim.palisade_hp = minf(sim.cfg.palisade_max_hp, sim.palisade_hp + rate * 3.0 * delta)
			world.set_fence_progress(sim.palisade_pct)
			if sim.palisade_pct >= 100.0:
				sim.palisade_building = false
				sim.palisade_hp = sim.cfg.palisade_max_hp
				_sfx("sfx_covenant_chime.wav", -5.0)
		else:
			sim.palisade_hp = minf(sim.cfg.palisade_max_hp, sim.palisade_hp + rate * 4.2 * delta)
			world.set_fence_progress(maxf(20.0, sim.palisade_hp / sim.cfg.palisade_max_hp * 100.0))
			if sim.palisade_hp >= sim.cfg.palisade_max_hp:
				sim.palisade_building = false

	if fence_status_root != null:
		if sim.palisade_building and sim.palisade_pct < 100.0:
			fence_status_label.text = "%s %d%%" % [tr("HUD_FENCE_BUILDING"), int(roundf(sim.palisade_pct))]
			update_bar_visual(fence_hp_bar, sim.palisade_pct / 100.0, Color(0.95, 0.76, 0.24), Color(0.95, 0.50, 0.16))
		elif sim.palisade_hp > 0.0:
			fence_status_label.text = "%s %d/%d" % [tr("HUD_FENCE_HP"), int(roundf(sim.palisade_hp)), int(sim.cfg.palisade_max_hp)]
			update_bar_visual(fence_hp_bar, sim.palisade_hp / sim.cfg.palisade_max_hp, Color(0.28, 0.86, 0.42), Color(0.92, 0.24, 0.18))
		else:
			fence_status_label.text = tr("HUD_FENCE_NONE")
			update_bar_visual(fence_hp_bar, 0.02, Color(0.92, 0.24, 0.18), Color(0.92, 0.24, 0.18))

	var active_raiders: int = 0
	var engaged: int = 0
	for i in range(raiders.size()):
		var r: Node3D = raiders[i]
		var morale: float = raider_morale[i]
		var flank: bool = (i >= 3)
		var rx_slot: float = (-20.0 + float(i) * 4.2) if not flank else (-12.5 + float(i - 3) * 2.4)
		if morale <= 0.0:
			var flee_pt: Vector3 = world.grounded(rx_slot * 0.6 if not flank else 18.0, 56.0)
			if r.position.distance_to(flee_pt) > 0.6:
				r.position = r.position.move_toward(flee_pt, delta * 5.2)
				r.look_at(flee_pt, Vector3.UP)
				play_simple_anim(r, "Run")
			else:
				play_simple_anim(r, "Idle")
			raider_labels[i].text = tr("HUD_RAIDER_ROUTED")
			update_bar_visual(raider_bars[i], 0.0, Color(0.8, 0.2, 0.2), Color(0.5, 0.5, 0.5))
			continue

		active_raiders += 1
		var tz: float = (23.7 if sim.palisade_hp > 0.0 else 16.4) if not flank else (22.0 if (sim.palisade_hp > 0.0 and sim.w_guard >= 2) else 16.6)
		var tg: Vector3 = world.grounded(rx_slot, tz)
		if r.position.distance_to(tg) > 0.65:
			var step_r: Vector3 = HumanoidRigHelper.compute_rvo_step(r, tg, 3.5, raiders, 0.65, delta)
			var npr: Vector3 = r.position + step_r
			npr.y = world.terrain_height(npr.x, npr.z)
			r.position = npr
			if step_r.length_squared() > 0.0001:
				r.look_at(r.position + step_r.normalized(), Vector3.UP)
			play_simple_anim(r, "Run", "Slash", 0.35)
		else:
			engaged += 1
			r.look_at(world.grounded(rx_slot, 12.0), Vector3.UP)
			play_simple_anim(r, "Slash" if i % 2 == 0 else "Brawl")
			if sim.palisade_hp > 0.0 and (not flank or sim.w_guard >= 2):
				var dmul: float = 0.65 if noah_near else 1.0
				sim.palisade_hp = maxf(0.0, sim.palisade_hp - 2.6 * dmul * delta)
				if not sim.palisade_building:
					world.set_fence_progress(maxf(0.0, sim.palisade_hp / sim.cfg.palisade_max_hp * 100.0))
				if not fire_triggered_once and sim.palisade_hp < sim.cfg.palisade_max_hp * 0.40:
					_ignite_fire()
			else:
				if not fire_triggered_once:
					_ignite_fire()
				sim.res_primary = maxf(0.0, sim.res_primary - 1.4 * delta)

			var gdps: float = (float(sim.w_guard) * 5.2 + (11.5 if noah_near else 0.0)) * sim.harmony_multiplier()
			if sim.palisade_hp > 0.0 and sim.w_guard > 0:
				gdps *= 1.35
			if gdps > 0.0:
				raider_morale[i] = maxf(0.0, raider_morale[i] - (gdps / float(maxi(1, engaged))) * delta)

		raider_labels[i].text = "%s %d%%" % [tr("HUD_RAIDER_MORALE"), int(roundf(raider_morale[i]))]
		update_bar_visual(raider_bars[i], raider_morale[i] / 100.0, Color(0.95, 0.30, 0.18), Color(0.96, 0.72, 0.22))

	if engaged > 0 and raider_clash_sfx_timer <= 0.0 and not preview:
		raider_clash_sfx_timer = 1.25
		_sfx("sfx_hammer.wav", -8.0)
		world.spawn_hit_particles(world.grounded(-14.0, 22.5, 1.2), true)
		if sim.palisade_hp > 0.0:
			world.pulse_fence_hit(-14.0)
		if noah_near:
			cam_ctrl.add_trauma(0.10)

	if sim.fire_intensity > 0.02 and sim.w_craft > 0:
		auto_douse_timer += delta * float(sim.w_craft)
		if auto_douse_timer >= 8.5:
			auto_douse_timer = 0.0
			timber_fire_ignited.emit()  # triggers douse check via coordinator

	if active_raiders == 0 and not crisis_resolved:
		crisis_resolved = true
		raid_crisis_resolved.emit()


func _ignite_fire() -> void:
	fire_triggered_once = true
	sim.fire_intensity = 1.0
	world.set_timber_fire_intensity(1.0)
	world.spawn_hit_particles(world.grounded(-15.5, 16.0, 1.3), true)
	timber_fire_ignited.emit()


func init_boarding() -> void:
	restore_all_to_world()
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
		var st: Vector2 = fam_starts[i]
		set_actor_props(family[i], false, false, false)
		family[i].show()
		if i == 0:
			hero_body.warp_to(world.grounded(st.x, st.y))
		else:
			family[i].position = world.grounded(st.x, st.y)
		play_simple_anim(family[i], "Walk")
	animal_root.show()
	for i in range(animals.size()):
		animals[i].show()
		animal_boarded.append(false)
		animal_board_dist.append(-float(i / 2) * 3.6)


func tick_boarding(delta: float, elapsed: float, fp_mode: bool, preview: bool) -> Vector2i:
	var ap: Vector3 = world.ark_anchor.position
	var fam_wps: Array[Vector3] = [
		world.grounded(0.0, 19.6),
		ap + Vector3(0.0, 0.02, 14.0),
		ap + Vector3(0.0, 0.65, 8.6),
		ap + Vector3(0.0, 0.65, 2.2),
	]
	var fam_in: int = 0
	for i in range(family.size()):
		if i >= family_boarded.size(): break
		if family_boarded[i]:
			fam_in += 1
			continue
		if i == 0 and fp_mode:
			family_boarded[0] = true
			fam_in += 1
			continue
		var mover: Node3D = hero_body if i == 0 else family[i]
		var wpi: int = family_board_wp[i]
		var lane_x: float = (-0.75 if i % 2 == 0 else 0.75) * (0.45 if wpi >= 1 else 1.0)
		var tg: Vector3 = fam_wps[wpi] + Vector3(lane_x, 0.0, 0.0)
		var spd: float = 4.6 if i == 0 else (3.8 + float(i % 3) * 0.35)
		var flat: Vector3 = Vector3(tg.x - mover.position.x, 0.0, tg.z - mover.position.z)
		if flat.length() < 0.65:
			wpi += 1
			if wpi >= fam_wps.size():
				family_boarded[i] = true
				place_family_inside_ark(i, fp_mode)
				fam_in += 1
				continue
			family_board_wp[i] = wpi
		else:
			var dir: Vector3 = flat.normalized()
			var np: Vector3 = mover.position + dir * spd * delta
			if wpi >= 1:
				var rt: float = clampf((np.z - (ap.z + 8.0)) / 11.5, 0.0, 1.0)
				np.y = lerpf(ap.y + 0.65, world.terrain_height(np.x, np.z), rt)
			else:
				np.y = world.terrain_height(np.x, np.z)
			mover.position = np
			family[i].look_at(family[i].global_position + dir, Vector3.UP)
			play_simple_anim(family[i], "Run" if wpi == 0 else "Walk")

	var segs: Array[float] = []
	var total: float = 0.0
	for i in range(boarding_path.size() - 1):
		var d: float = boarding_path[i].distance_to(boarding_path[i + 1])
		segs.append(d)
		total += d
	var ani_in: int = 0
	for i in range(animals.size()):
		var animal: Node3D = animals[i]
		if i >= animal_boarded.size(): break
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
			place_animal_inside_ark(i)
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
			if j < 2: p.y = world.terrain_height(p.x, p.z)
			p.y += absf(sin(elapsed * 6.5 + float(i))) * 0.02
			animal.position = p
			animal.look_at(p + Vector3(dir2.x, 0.0, dir2.z), Vector3.UP)
			play_simple_anim(animal, "Walk")
			break

	if not preview and fam_in >= family.size() and ani_in >= animals.size():
		boarding_complete_timer += delta
		if boarding_complete_timer >= 0.8:
			all_boarded_ready.emit()
	return Vector2i(fam_in, ani_in)


func place_family_inside_ark(i: int, fp_mode: bool) -> void:
	if i == 0:
		var m0: Node3D = family[0]
		if m0.get_parent() != world.ark_anchor:
			m0.reparent(world.ark_anchor, false)
		m0.position = Vector3(-25.0, 0.65, 0.4)
		m0.look_at(world.ark_anchor.to_global(Vector3(0.0, 0.65, 0.4)), Vector3.UP)
		set_actor_props(m0, false, false, false)
		play_simple_anim(m0, "Idle")
		m0.visible = not fp_mode
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
	set_actor_props(m, false, false, false)
	play_simple_anim(m, str(cfg[2]))
	m.show()


func place_animal_inside_ark(i: int) -> void:
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
	play_simple_anim(ani, "StallRest")
	ani.show()


func stage_all_inside_ark(fp_mode: bool) -> void:
	for i in range(family.size()):
		place_family_inside_ark(i, fp_mode)
	for i in range(animals.size()):
		place_animal_inside_ark(i)


func stage_ararat_worship() -> void:
	restore_all_to_world()
	var slots: Array[Vector2] = [
		Vector2(0.5, 21.0), Vector2(3.6, 22.4), Vector2(-2.6, 22.4), Vector2(-1.4, 21.2),
		Vector2(2.4, 21.2), Vector2(-1.6, 24.8), Vector2(2.6, 24.8), Vector2(4.2, 23.8),
	]
	for i in range(family.size()):
		family[i].show()
		set_actor_props(family[i], false, false, false)
		var pos_w: Vector3 = world.grounded(slots[i].x, slots[i].y)
		if i == 0:
			hero_body.warp_to(pos_w)
		else:
			family[i].position = pos_w
		var target: Vector3 = world.altar_group.position if i != 0 else (pos_w + Vector3(0.0, 0.0, 6.0))
		target.y = pos_w.y
		family[i].look_at(target, Vector3.UP)
		play_simple_anim(family[i], "Bless" if i == 0 else ("Pray" if i in [5, 6] else "Idle"))


func apply_act_visibility(id: String, stage: int, fp_mode: bool) -> void:
	world.yard_stakes.visible = (id == "noah_01_revelation")
	world.timber_stacks.visible = (stage >= 1 and id != "noah_06_flood_dove")
	world.spring_well.visible = (stage >= 1 and id not in ["noah_06_flood_dove", "noah_07_exit_altar", "noah_08_rainbow_covenant"])
	world.pitch_station.visible = (stage >= 2 and id != "noah_06_flood_dove")
	sim.fire_intensity = 0.0
	world.set_timber_fire_intensity(0.0)
	fence_status_root.visible = (id == "noah_03_hull_decks" and not fp_mode)
	for r in raiders: r.hide()
	for hw in hired_workers: hw.visible = (id == "noah_02_keel_mortise")
	for v in villagers: v.visible = (id == "noah_02_keel_mortise")
	for b in birds: b.visible = id in ["noah_06_flood_dove", "noah_07_exit_altar"]
	animal_root.visible = (id == "noah_05_board_ark")
	world.altar_group.visible = id in ["noah_07_exit_altar", "noah_08_rainbow_covenant"]
	world.puddles_group.visible = world.altar_group.visible
	world.olive_shoots.visible = world.altar_group.visible
	world.rainbow.visible = (id == "noah_08_rainbow_covenant")


func step_ark_deck_walk(local_pos: Vector3, deck: int, mv: Vector3, can_exit: bool, delta: float) -> Dictionary:
	var lp: Vector3 = local_pos + mv.normalized() * (6.4 if Input.is_key_pressed(KEY_SHIFT) else 4.0) * delta
	var nd: int = deck
	lp.x = clampf(lp.x, -46.5, 46.5)
	lp.z = clampf(lp.z, -3.0, 9.2 if can_exit else 3.0)
	if lp.z <= -1.15 and lp.x >= 2.5 and lp.x <= 13.5 and nd <= 1:
		var s1: float = clampf((lp.x - 2.5) / 11.0, 0.0, 1.0)
		nd = 0 if s1 < 0.25 else (1 if s1 > 0.75 else nd)
		lp.y = lerpf(0.65, 3.95, s1)
	elif lp.z <= -1.15 and lp.x >= 18.5 and lp.x <= 29.5 and nd >= 1:
		var s2: float = clampf((lp.x - 18.5) / 11.0, 0.0, 1.0)
		nd = 1 if s2 < 0.25 else (2 if s2 > 0.75 else nd)
		lp.y = lerpf(3.95, 7.15, s2)
	else:
		lp.y = 7.15 if nd == 2 else (3.95 if nd == 1 else 0.65)
	return {"pos": lp, "deck": nd, "exited": can_exit and lp.z > 8.6}


func tick_flood_and_dove(id: String, flood_level: float, elapsed: float, delta: float) -> void:
	world.flood_water.position.y = flood_level
	if id == "noah_06_flood_dove":
		var wv: float = sin(elapsed * 1.4) * 0.28
		world.flood_water.position.y = flood_level + wv * 0.35
		if flood_level > world.ark_base_y + 0.3:
			world.ark_anchor.position.y = flood_level - 0.45 + wv
			world.ark_anchor.rotation = Vector3(cos(elapsed * 0.72) * 0.024, 0.0, sin(elapsed * 0.95) * 0.035)
	else:
		world.ark_anchor.position.y = lerpf(world.ark_anchor.position.y, world.ark_base_y, 1.0 - exp(-delta * 4.0))
		world.ark_anchor.rotation = world.ark_anchor.rotation.lerp(Vector3.ZERO, 1.0 - exp(-delta * 4.0))
	if dove_flight_active and birds.size() >= 2:
		dove_flight_t += delta
		birds[1].show()
		birds[1].position = world.ark_anchor.to_global(Vector3(6.0, 9.0, 4.5)) + Vector3(sin(dove_flight_t * 2.4) * 14.0, 2.5, 8.0 + sin(dove_flight_t * 1.3) * 8.0)
