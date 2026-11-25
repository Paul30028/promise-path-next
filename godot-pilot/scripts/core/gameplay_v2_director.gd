class_name GameplayV2Director
extends Node3D
## Universal Gameplay 2.0 Director (`Phase A` Steam Playability Overhaul):
## - 30s Micro-Loop: Patriarch Shofar Horn `[Q]` shockwave + Rhythmic Perfect Assist `[R]` timing gauge
## - 5m Mid-Loop: 3 physical 3D Camp Workshop Upgrades springing onto the map (`[1][2][3]`)
## - Tactical Pause (`0.0x` freeze / `1.5x` fast) + 3 Historical Tactical Action Cards consuming Command Pips
## - 1st-Person Immersive Objectives: Flood Hull Seam Leak Pitch-Sealing (`Ch00`) & Tent Clay Tablet + Wolf Pack (`Ch01`)!

signal shofar_triggered(origin: Vector3)
signal perfect_assist_hit(tier: String, origin: Vector3)
signal tactical_card_played(card_id: String)
signal workshop_upgraded(slot_idx: int)
signal interior_task_completed(task_id: String)

var chapter_id: String = "ch00_noah_ark"
var sim: DeterministicEconomySim
var cam_ctrl: RTSCameraController
var tactical_paused: bool = false

# Rhythmic Assist Timing State
var assist_active: bool = false
var assist_cursor: float = 0.0
var assist_dir: float = 1.0
var assist_timeout: float = 0.0
var assist_cooldown: float = 0.0
var _pip_half_credit: int = 0

# 3D Workshop Props
var upgrade_nodes: Array[Node3D] = []

# Ch00 1st-Person Hull Leaks
var hull_leaks: Array[Dictionary] = []

# Ch01 Canaanite Wolf Pack & Tent Clay Tablet
var wolves: Array[Node3D] = []
var wolf_fear: Array[float] = []
var wolf_bars: Array[MeshInstance3D] = []
var wolf_labels: Array[Label3D] = []
var wolf_repel_timer: float = 0.0
var wolf_howl_cd: float = 4.0
var tent_tablet_node: Node3D
var tent_tablet_inspected: bool = false


func setup(ch_id: String, econ: DeterministicEconomySim, cam: RTSCameraController) -> void:
	chapter_id = ch_id
	sim = econ
	cam_ctrl = cam


func _sfx(wav: String, db: float = -4.0) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.call("play_sfx", wav, db)


func spawn_popup_3d(pos: Vector3, txt: String, col: Color = Color(1.0, 0.90, 0.42)) -> void:
	if not is_inside_tree():
		return
	var lbl := Label3D.new()
	lbl.text = txt
	lbl.position = pos
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 38
	lbl.pixel_size = 0.0044
	lbl.modulate = col
	lbl.outline_modulate = Color(0.06, 0.04, 0.02, 0.96)
	lbl.outline_size = 10
	add_child(lbl)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y + 2.1, 1.15)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.15).set_delay(0.28)
	tw.chain().tween_callback(lbl.queue_free)


func cast_shofar(origin: Vector3) -> bool:
	if sim == null or not sim.trigger_shofar():
		_sfx("sfx_alert.wav", -7.0)
		return false
	_sfx("sfx_shofar_horn.wav", -2.5)
	if cam_ctrl != null:
		cam_ctrl.add_trauma(0.18)

	# Expanding golden acoustic ring VFX
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.84, 0.36, 0.86)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.78, 0.28)
	rm.emission_energy_multiplier = 2.4
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.position = origin + Vector3(0.0, 0.35, 0.0)
	add_child(ring)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(14.0, 1.0, 14.0), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.85)
	tw.chain().tween_callback(ring.queue_free)

	spawn_popup_3d(origin + Vector3(0.0, 2.3, 0.0), tr("POP_SHOFAR"), Color(1.0, 0.88, 0.36))
	if chapter_id == "ch01_bethel":
		sim.pasture_pressure = maxf(10.0, sim.pasture_pressure - 10.0)
		for i in range(wolf_fear.size()):
			wolf_fear[i] = minf(100.0, wolf_fear[i] + 45.0)
	shofar_triggered.emit(origin)
	return true


func press_rhythmic_assist(origin: Vector3) -> String:
	if sim == null or assist_cooldown > 0.0:
		return "cooldown"
	if not assist_active:
		assist_active = true
		assist_cursor = 0.08
		assist_dir = 1.0
		assist_timeout = 3.6
		_sfx("sfx_ui_click.wav", -6.0)
		return "armed"

	assist_active = false
	assist_cooldown = 3.2
	var dist_center: float = absf(assist_cursor - 0.50)
	if dist_center <= 0.14:
		_sfx("sfx_perfect_strike.wav", -2.5)
		if cam_ctrl != null:
			cam_ctrl.add_trauma(0.20)
		var bonus_res: int = 14 if chapter_id == "ch00_noah_ark" else 12
		sim.res_primary += float(bonus_res)
		sim.monument_pct = minf(100.0, sim.monument_pct + 2.4)
		_pip_half_credit += 1
		if _pip_half_credit >= 2:
			_pip_half_credit = 0
			sim.gain_pip(1)
		spawn_popup_3d(origin + Vector3(0.0, 2.2, 0.0), "PERFECT! +%d" % bonus_res, Color(1.0, 0.92, 0.34))
		perfect_assist_hit.emit("perfect", origin)
		return "perfect"
	elif dist_center <= 0.28:
		_sfx("sfx_hammer.wav", -4.0)
		sim.res_primary += 6.0
		sim.monument_pct = minf(100.0, sim.monument_pct + 0.9)
		spawn_popup_3d(origin + Vector3(0.0, 2.1, 0.0), "GOOD +6", Color(0.88, 0.84, 0.68))
		perfect_assist_hit.emit("good", origin)
		return "good"
	else:
		_sfx("sfx_alert.wav", -7.0)
		spawn_popup_3d(origin + Vector3(0.0, 2.0, 0.0), tr("POP_MISS"), Color(0.90, 0.48, 0.40))
		return "miss"


func get_workshop_defs() -> Array[Dictionary]:
	if chapter_id == "ch00_noah_ark":
		return [
			{"title": "UPG_CH00_0", "desc": "UPG_CH00_0_DESC"},
			{"title": "UPG_CH00_1", "desc": "UPG_CH00_1_DESC"},
			{"title": "UPG_CH00_2", "desc": "UPG_CH00_2_DESC"},
		]
	return [
		{"title": "UPG_CH01_0", "desc": "UPG_CH01_0_DESC"},
		{"title": "UPG_CH01_1", "desc": "UPG_CH01_1_DESC"},
		{"title": "UPG_CH01_2", "desc": "UPG_CH01_2_DESC"},
	]


func get_tactical_cards() -> Array[Dictionary]:
	if chapter_id == "ch00_noah_ark":
		return [
			{"id": "wet_timber", "cost": 1, "title": "CRD_CH00_0", "desc": "CRD_CH00_0_DESC"},
			{"id": "double_shift", "cost": 2, "title": "CRD_CH00_1", "desc": "CRD_CH00_1_DESC"},
			{"id": "share_grain", "cost": 2, "title": "CRD_CH00_2", "desc": "CRD_CH00_2_DESC"},
		]
	return [
		{"id": "torch_patrol", "cost": 1, "title": "CRD_CH01_0", "desc": "CRD_CH01_0_DESC"},
		{"id": "split_pasture", "cost": 2, "title": "CRD_CH01_1", "desc": "CRD_CH01_1_DESC"},
		{"id": "caravan_barter", "cost": 2, "title": "CRD_CH01_2", "desc": "CRD_CH01_2_DESC"},
	]


func try_unlock_workshop(slot_idx: int) -> bool:
	if sim == null or not sim.unlock_upgrade(slot_idx):
		_sfx("sfx_alert.wav", -6.0)
		return false
	_sfx("sfx_covenant_chime.wav", -3.5)
	if slot_idx < upgrade_nodes.size() and upgrade_nodes[slot_idx] != null:
		var n: Node3D = upgrade_nodes[slot_idx]
		n.scale = Vector3.ONE * 0.05
		n.show()
		create_tween().tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		spawn_popup_3d(n.global_position + Vector3(0.0, 2.5, 0.0), tr(get_workshop_defs()[slot_idx]["title"]), Color(1.0, 0.90, 0.44))
	workshop_upgraded.emit(slot_idx)
	return true


func sync_unlocked_workshop_visuals() -> void:
	for i in range(mini(sim.upgrades_unlocked.size(), upgrade_nodes.size())):
		if upgrade_nodes[i] != null:
			upgrade_nodes[i].visible = sim.upgrades_unlocked[i]


func play_tactical_card(card_idx: int, anchor_pos: Vector3) -> bool:
	var cards: Array[Dictionary] = get_tactical_cards()
	if card_idx < 0 or card_idx >= cards.size() or sim == null:
		return false
	var cd: Dictionary = cards[card_idx]
	if not sim.spend_pips(int(cd["cost"])):
		_sfx("sfx_alert.wav", -6.0)
		return false

	var cid: String = str(cd["id"])
	_sfx("sfx_covenant_chime.wav", -3.5)
	match cid:
		"wet_timber":
			sim.fire_intensity = 0.0
			sim.fireproof_timer = 25.0
			sim.res_secondary += 8.0
		"double_shift":
			sim.double_shift_timer = 14.0
			sim.res_tertiary = maxf(0.0, sim.res_tertiary - 10.0)
		"share_grain":
			sim.res_tertiary = maxf(0.0, sim.res_tertiary - 14.0)
			sim.harmony = minf(100.0, sim.harmony + 6.0)
		"torch_patrol":
			wolf_repel_timer = 24.0
			for i in range(wolf_fear.size()):
				wolf_fear[i] = 100.0
		"split_pasture":
			sim.pasture_pressure = maxf(10.0, sim.pasture_pressure - 28.0)
			sim.harmony = minf(100.0, sim.harmony + 4.0)
		"caravan_barter":
			sim.res_secondary = maxf(0.0, sim.res_secondary - 8.0)
			sim.res_primary += 22.0
			sim.res_tertiary += 8.0
	spawn_popup_3d(anchor_pos + Vector3(0.0, 2.6, 0.0), tr(str(cd["title"])), Color(0.55, 0.94, 1.0))
	tactical_card_played.emit(cid)
	return true


func build_ch00_workshop_props(world: NoahRTSWorld) -> void:
	upgrade_nodes.clear()
	var wood_m := StandardMaterial3D.new(); wood_m.albedo_color = Color(0.42, 0.25, 0.12); wood_m.roughness = 0.88
	var stone_m := StandardMaterial3D.new(); stone_m.albedo_color = Color(0.55, 0.50, 0.44); stone_m.roughness = 0.94

	# 0: Timber Pulley Crane beside Ark
	var crane := Node3D.new(); crane.position = world.grounded(-8.5, 11.2); add_child(crane)
	for lx: float in [-1.1, 1.1]:
		var post := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.24, 4.6, 0.24)
		post.mesh = bm; post.material_override = wood_m; post.position = Vector3(lx, 2.3, 0.0); crane.add_child(post)
	var beam := MeshInstance3D.new(); var bbm := BoxMesh.new(); bbm.size = Vector3(2.8, 0.26, 0.28)
	beam.mesh = bbm; beam.material_override = wood_m; beam.position = Vector3(0.0, 4.5, 0.0); crane.add_child(beam)
	crane.hide(); upgrade_nodes.append(crane)

	# 1: Twin Pitch Kilns
	var kiln := Node3D.new(); kiln.position = world.grounded(14.5, 13.5); add_child(kiln)
	for kx: float in [-0.9, 0.9]:
		var km := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.72; cm.height = 1.15
		km.mesh = cm; km.material_override = stone_m; km.position = Vector3(kx, 0.55, 0.0); kiln.add_child(km)
	var kl := OmniLight3D.new(); kl.position = Vector3(0.0, 1.4, 0.0); kl.light_color = Color(1.0, 0.56, 0.18); kl.light_energy = 2.0; kl.omni_range = 6.0; kiln.add_child(kl)
	kiln.hide(); upgrade_nodes.append(kiln)

	# 2: Rain Store Canopy
	var canopy: Node3D = world.spawn_asset("BLD_HealingCanopy_cloth.glb", 3.3, world.grounded(-21.5, 18.2), self)
	canopy.hide(); upgrade_nodes.append(canopy)


func setup_ark_flood_repairs(ark_anchor: Node3D) -> void:
	for lk in hull_leaks:
		if is_instance_valid(lk.get("node")):
			(lk["node"] as Node).queue_free()
	hull_leaks.clear()
	var sm: Node = get_node_or_null("/root/SoundManager")
	for idx in range(2):
		var lpos: Vector3 = Vector3(-19.5, 1.15, -2.5) if idx == 0 else Vector3(-8.5, 1.15, 2.5)
		var root_lk := Node3D.new()
		root_lk.position = lpos
		ark_anchor.add_child(root_lk)

		var spray := GPUParticles3D.new()
		spray.amount = 26
		spray.lifetime = 0.55
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 0.35, 1.0 if idx == 0 else -1.0)
		pm.spread = 24.0
		pm.initial_velocity_min = 2.2
		pm.initial_velocity_max = 3.8
		pm.gravity = Vector3(0.0, -5.5, 0.0)
		spray.process_material = pm
		var qm := QuadMesh.new(); qm.size = Vector2(0.12, 0.12)
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.62, 0.86, 1.0, 0.78)
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = wm
		spray.draw_pass_1 = qm
		root_lk.add_child(spray)

		var lbl := Label3D.new()
		lbl.text = "[E] " + tr("HS_SEAL_LEAK")
		lbl.position = Vector3(0.0, 0.75, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 28
		lbl.pixel_size = 0.0040
		lbl.modulate = Color(0.56, 0.92, 1.0)
		root_lk.add_child(lbl)

		if sm != null and sm.has_method("make_spatial_loop_3d"):
			var aud: AudioStreamPlayer3D = sm.call("make_spatial_loop_3d", "sfx_hull_leak.wav", Vector3.ZERO, 14.0, -7.0, true) as AudioStreamPlayer3D
			if aud != null:
				root_lk.add_child(aud)
		hull_leaks.append({"id": "leak_%d" % idx, "node": root_lk, "lbl": lbl, "sealed": false})


func active_leak_count() -> int:
	var n: int = 0
	for lk in hull_leaks:
		if not bool(lk.get("sealed", true)):
			n += 1
	return n


func try_seal_nearest_leak(global_eye: Vector3) -> bool:
	for lk in hull_leaks:
		if bool(lk.get("sealed", true)):
			continue
		var n: Node3D = lk["node"] as Node3D
		if n != null and is_instance_valid(n) and n.global_position.distance_to(global_eye) < 5.5:
			lk["sealed"] = true
			n.hide()
			_sfx("sfx_perfect_strike.wav", -3.0)
			sim.harmony = minf(100.0, sim.harmony + 4.0)
			spawn_popup_3d(n.global_position + Vector3(0.0, 0.6, 0.0), tr("POP_LEAK_SEALED"), Color(0.55, 0.96, 1.0))
			interior_task_completed.emit(str(lk["id"]))
			return true
	return false


func build_ch01_workshop_and_wolves(world: BethelHighlandWorld) -> void:
	upgrade_nodes.clear()
	var stone_m := StandardMaterial3D.new(); stone_m.albedo_color = Color(0.64, 0.59, 0.50); stone_m.roughness = 0.90
	var water_m := StandardMaterial3D.new(); water_m.albedo_color = Color(0.22, 0.56, 0.76, 0.88); water_m.roughness = 0.15

	# 0: Split Limestone Watering Trough
	var trough := Node3D.new(); trough.position = world.grounded(-25.2, -4.5); add_child(trough)
	var tb := MeshInstance3D.new(); var tbm := BoxMesh.new(); tbm.size = Vector3(3.6, 0.58, 1.1)
	tb.mesh = tbm; tb.material_override = stone_m; tb.position.y = 0.29; trough.add_child(tb)
	var twa := MeshInstance3D.new(); var twm := BoxMesh.new(); twm.size = Vector3(3.2, 0.12, 0.82)
	twa.mesh = twm; twa.material_override = water_m; twa.position.y = 0.54; trough.add_child(twa)
	trough.hide(); upgrade_nodes.append(trough)

	# 1: Dry-Stone Protective Sheepfold
	var fold := Node3D.new(); fold.position = world.grounded(-5.5, 16.5); add_child(fold)
	for wi in range(3):
		var wn: Node3D = world.spawn_asset("CC0_DryStoneWall_Optimized.glb", 1.15, Vector3(-4.0 + float(wi) * 4.0, 0.0, 4.5), fold)
		wn.rotation.y = 0.15 * float(wi - 1)
	fold.hide(); upgrade_nodes.append(fold)

	# 2: Hospitality Woven Pavilion
	var hosp: Node3D = world.spawn_asset("BLD_HealingCanopy_cloth.glb", 3.4, world.grounded(-21.5, 16.5), self)
	hosp.hide(); upgrade_nodes.append(hosp)

	# Glowing Ur Covenant Clay Tablet inside Abram's Main Tent!
	tent_tablet_node = Node3D.new()
	tent_tablet_node.position = Vector3(0.85, 0.54, 0.35)
	world.main_tent.add_child(tent_tablet_node)
	var tab_mi := MeshInstance3D.new(); var tab_b := BoxMesh.new(); tab_b.size = Vector3(0.38, 0.06, 0.28)
	tab_mi.mesh = tab_b
	var tab_m := StandardMaterial3D.new(); tab_m.albedo_color = Color(0.82, 0.66, 0.42)
	tab_m.emission_enabled = true; tab_m.emission = Color(1.0, 0.78, 0.32); tab_m.emission_energy_multiplier = 1.4
	tab_mi.material_override = tab_m; tent_tablet_node.add_child(tab_mi)
	var tab_lbl := Label3D.new()
	tab_lbl.name = "TabletLabel"
	tab_lbl.text = "[E] " + tr("HS_TENT_TABLET")
	tab_lbl.position = Vector3(0.0, 0.42, 0.0)
	tab_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tab_lbl.no_depth_test = true
	tab_lbl.font_size = 24
	tab_lbl.pixel_size = 0.0036
	tab_lbl.modulate = Color(1.0, 0.92, 0.58)
	tent_tablet_node.add_child(tab_lbl)

	# 2 Prowling Canaanite Wolves on South Pasture Perimeter
	var wolf_pelt := StandardMaterial3D.new()
	wolf_pelt.albedo_color = Color(0.24, 0.22, 0.20)
	wolf_pelt.roughness = 0.88
	for wi in range(2):
		var wpos: Vector3 = world.grounded(-12.0 + float(wi) * 14.0, 34.0)
		var wf: Node3D = world.spawn_asset("CC0_Lion_Grab3D.glb", 0.72, wpos, self)
		wf.name = "CanaanWolf_%d" % wi
		for mn in wf.find_children("*", "MeshInstance3D", true, false):
			(mn as MeshInstance3D).material_override = wolf_pelt
		var sb: Dictionary = NoahCastAndRaidRig.attach_status_bar(wf, 1.15, tr("HUD_WOLF_PROWL"), Color(0.95, 0.36, 0.20), 1.05)
		wolves.append(wf)
		wolf_fear.append(0.0)
		wolf_bars.append(sb["fill"] as MeshInstance3D)
		wolf_labels.append(sb["lbl"] as Label3D)


func try_inspect_tent_tablet(global_eye: Vector3) -> bool:
	if tent_tablet_inspected or tent_tablet_node == null or not is_instance_valid(tent_tablet_node):
		return false
	if tent_tablet_node.global_position.distance_to(global_eye) > 4.2:
		return false
	tent_tablet_inspected = true
	var tlbl: Node3D = tent_tablet_node.get_node_or_null("TabletLabel") as Node3D
	if tlbl != null:
		tlbl.hide()
	_sfx("sfx_covenant_chime.wav", -3.0)
	sim.gain_pip(1)
	sim.res_secondary += 8.0
	sim.harmony = minf(100.0, sim.harmony + 4.0)
	spawn_popup_3d(tent_tablet_node.global_position + Vector3(0.0, 0.5, 0.0), "+1 PIP · " + tr("POP_TABLET_READ"), Color(1.0, 0.90, 0.44))
	interior_task_completed.emit("tent_tablet")
	return true


func tick_director(delta: float, sim_dt: float, world_bethel: BethelHighlandWorld = null, hero_pos: Vector3 = Vector3.ZERO) -> void:
	if assist_cooldown > 0.0:
		assist_cooldown = maxf(0.0, assist_cooldown - delta)
	if assist_active:
		assist_timeout -= delta
		assist_cursor += assist_dir * 1.75 * delta
		if assist_cursor >= 0.96:
			assist_cursor = 0.96; assist_dir = -1.0
		elif assist_cursor <= 0.04:
			assist_cursor = 0.04; assist_dir = 1.0
		if assist_timeout <= 0.0:
			assist_active = false

	if world_bethel == null or wolves.is_empty() or sim_dt <= 0.0:
		return

	if wolf_repel_timer > 0.0:
		wolf_repel_timer = maxf(0.0, wolf_repel_timer - sim_dt)
	if wolf_howl_cd > 0.0:
		wolf_howl_cd = maxf(0.0, wolf_howl_cd - sim_dt)

	var fold_built: bool = sim.upgrades_unlocked[1]
	var trough_built: bool = sim.upgrades_unlocked[0]
	if trough_built:
		sim.pasture_pressure = maxf(10.0, sim.pasture_pressure - 0.18 * sim_dt)

	for i in range(wolves.size()):
		var w: Node3D = wolves[i]
		var near_hero: bool = w.global_position.distance_to(hero_pos) < 8.5
		if near_hero or sim.w_guard >= 2 or wolf_repel_timer > 0.0:
			wolf_fear[i] = minf(100.0, wolf_fear[i] + (28.0 if near_hero else 14.0) * sim_dt)
		else:
			wolf_fear[i] = maxf(0.0, wolf_fear[i] - 8.5 * sim_dt)

		var retreating: bool = (wolf_fear[i] >= 65.0 or wolf_repel_timer > 0.0)
		var target_z: float = 41.0 if retreating else (23.5 if fold_built else 19.2)
		var target_x: float = -14.0 + float(i) * 18.0
		var tg: Vector3 = world_bethel.grounded(target_x, target_z)
		if w.position.distance_to(tg) > 0.6:
			var dir: Vector3 = (tg - w.position).normalized()
			var np: Vector3 = w.position + dir * (4.6 if retreating else 2.6) * sim_dt
			np.y = world_bethel.terrain_height(np.x, np.z)
			w.position = np
			w.look_at(np + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
			NoahCastAndRaidRig.play_simple_anim(w, "Walk")
		else:
			NoahCastAndRaidRig.play_simple_anim(w, "Idle")
			if not retreating and not fold_built and sim.w_guard == 0:
				sim.res_tertiary = maxf(20.0, sim.res_tertiary - 0.45 * sim_dt)
				if wolf_howl_cd <= 0.0:
					wolf_howl_cd = 14.0
					_sfx("sfx_wolf_howl.wav", -5.5)

		wolf_labels[i].text = tr("HUD_WOLF_FLEE" if retreating else "HUD_WOLF_PROWL")
		NoahCastAndRaidRig.update_bar_visual(wolf_bars[i], 1.0 - wolf_fear[i] / 100.0, Color(0.95, 0.32, 0.18), Color(0.45, 0.78, 0.92))
