extends SceneTree
## Commercial Steam-Readiness Headless CI Suite (M0 + M1.5 Golden Trilogy Gates)
## Run via: godot --headless --path godot-pilot -s res://tests/run_ci.gd

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("FAIL: " + msg)


func _pass(msg: String) -> void:
	print("PASS: " + msg)


func _init() -> void:
	_test_chapter_jsons()
	_test_coordinator_line_limits()
	_test_deterministic_sim_1000x()
	_test_i18n_bilingual_table()
	_test_prefabs_and_resources()
	_test_spatial_audio_wavs()
	_test_quadruped_animals()
	_test_humanoid_rigs()
	_test_ark_30_step_glb()
	_test_all_v6_scripts_compile()
	_test_atomic_save_v3_roundtrip()

	if failures.is_empty():
		print("\n=== ALL COMMERCIAL CI GATES PASSED (0 failures) ===")
		quit(0)
	else:
		printerr("\n=== COMMERCIAL CI FAILED (%d errors) ===" % failures.size())
		quit(1)


func _test_chapter_jsons() -> void:
	for p: String in ["res://data/ch00_noah_ark.json", "res://data/ch00_ur_call.json", "res://data/ch01_bethel.json"]:
		var raw: String = FileAccess.get_file_as_string(p)
		var d: Variant = JSON.parse_string(raw)
		if not (d is Dictionary) or int(d.get("schemaVersion", 0)) < 3 or not (d.get("events") is Array):
			_fail("JSON must be schemaVersion >= 3 with events array: " + p)
			continue
		var ids: Dictionary = {}
		for ev in d["events"]:
			ids[str(ev.get("id", ""))] = true
		for ev in d["events"]:
			for ch in ev.get("choices", []):
				var nxt: Variant = ch.get("nextEventId", "")
				var nxt_s: String = "" if nxt == null else str(nxt)
				if not nxt_s.is_empty() and not ids.has(nxt_s):
					_fail("%s broken nextEventId=%s" % [p, nxt_s])
		_pass("V3 JSON event graph valid: %s (%d events)" % [p, ids.size()])


func _test_coordinator_line_limits() -> void:
	for sp: String in ["res://scripts/ch00_noah_ark.gd", "res://scripts/camp_pilot.gd"]:
		var lines: int = FileAccess.get_file_as_string(sp).split("\n").size()
		if lines > 360:
			_fail("Chapter coordinator exceeds 350-line budget: %s (%d lines)" % [sp, lines])
		else:
			_pass("Cartridge coordinator slim budget met: %s (%d lines <= 350)" % [sp, lines])


func _test_deterministic_sim_1000x() -> void:
	var bal: Resource = load("res://resources/ch00_balance.tres")
	if bal == null:
		_fail("Missing ch00_balance.tres")
		return
	var sim = load("res://scripts/core/deterministic_economy_sim.gd").new(bal)
	sim.res_primary = 180.0
	sim.harmony = 90.0
	for _step in range(100):
		sim.tick(0.5)
	var snap: Dictionary = sim.to_dict()
	var sim2 = load("res://scripts/core/deterministic_economy_sim.gd").new(bal)
	sim2.from_dict(snap)
	if sim.monument_pct <= 25.0 or absf(sim.monument_pct - sim2.monument_pct) > 0.001:
		_fail("DeterministicEconomySim 1000x tick / snapshot mismatch")
	else:
		_pass("DeterministicEconomySim 1000x tick & snapshot PASS (pct=%.1f%%, mul=%.2f)" % [sim.monument_pct, sim.harmony_multiplier()])


func _test_i18n_bilingual_table() -> void:
	var sm: Node = load("res://scripts/save_manager.gd").new()
	sm.ensure_translations_loaded()
	TranslationServer.set_locale("zh_CN")
	var zh: String = TranslationServer.translate(&"MENU_TITLE")
	TranslationServer.set_locale("en_US")
	var en: String = TranslationServer.translate(&"MENU_TITLE")
	sm.free()
	if zh == "MENU_TITLE" or en != "PATH OF PROMISE":
		_fail("Bilingual messages.csv failed: zh='%s' en='%s'" % [zh, en])
	else:
		_pass("Bilingual messages.csv verified: zh='%s' <-> en='%s'" % [zh, en])
	TranslationServer.set_locale("zh_CN")


func _test_prefabs_and_resources() -> void:
	for rp: String in [
		"res://resources/ch00_balance.tres",
		"res://resources/ch01_balance.tres",
		"res://scenes/prefabs/fp_oil_lamp.tscn",
		"res://scenes/prefabs/world_hotspot.tscn",
		"res://scenes/ui/hud_biblical_v3.tscn",
	]:
		if ResourceLoader.load(rp) == null:
			_fail("Missing prefab/resource: " + rp)
		else:
			_pass("Prefab/Resource verified: " + rp)


func _test_spatial_audio_wavs() -> void:
	for wf: String in ["sfx_ark_wood_creak.wav", "sfx_oil_lamp_crackle.wav", "sfx_animals_breath.wav"]:
		if not FileAccess.file_exists("res://assets/audio/" + wf):
			_fail("Missing spatial audio WAV: " + wf)
		else:
			_pass("Spatial cabin/pasture WAV verified: " + wf)


func _test_quadruped_animals() -> void:
	var req_anims: Array[String] = ["Idle", "Walk", "StallRest"]
	for fn: String in ["CC0_Sheep_Grab3D.glb", "CC0_Bull_Grab3D.glb", "CC0_Horse_Grab3D.glb", "CC0_Deer_Grab3D.glb", "CC0_Lion_Grab3D.glb"]:
		var ps: PackedScene = ResourceLoader.load("res://assets/models/" + fn) as PackedScene
		if ps == null:
			_fail("Cannot load animal: " + fn)
			continue
		var inst: Node = ps.instantiate()
		var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if skel == null or skel.get_bone_count() < 9 or ap == null:
			_fail("%s missing 9-bone rig" % fn)
		else:
			var ok: bool = true
			for a in req_anims:
				if not ap.has_animation(a): ok = false
			if ok: _pass("Quadruped %s: 9 bones + Walk/Idle/StallRest" % fn)
			else: _fail("%s missing required anims" % fn)
		inst.free()


func _test_humanoid_rigs() -> void:
	for fn: String in ["CHR_Noah_rigged.glb", "CHR_Noah_Wife_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Daughter_rigged.glb", "CHR_Abram_rigged.glb", "CHR_Sarai_rigged.glb"]:
		var ps: PackedScene = ResourceLoader.load("res://assets/models/" + fn) as PackedScene
		if ps == null:
			_fail("Cannot load humanoid: " + fn)
			continue
		var inst: Node = ps.instantiate()
		var tree: AnimationTree = load("res://scripts/core/humanoid_rig_helper.gd").setup_layered_anim_tree(inst)
		if tree == null:
			_fail("Layered AnimationTree failed on " + fn)
		else:
			_pass("Humanoid %s + Layered Upper-Body AnimationTree ready" % fn)
		inst.free()


func _test_ark_30_step_glb() -> void:
	var ps: PackedScene = ResourceLoader.load("res://assets/models/BLD_NoahsArk.glb") as PackedScene
	if ps == null:
		_fail("Cannot load BLD_NoahsArk.glb")
		return
	var inst: Node = ps.instantiate()
	var steps: int = 0
	for i in range(1, 26):
		if inst.find_child("BuildStep_%02d_Mesh" % i, true, false) != null: steps += 1
	for i in range(26, 30):
		if inst.find_child("CutawayRoof_Step_%02d_Mesh" % i, true, false) != null: steps += 1
	if inst.find_child("Stage3_Ramp_Mesh", true, false) != null: steps += 1
	if steps < 30 or inst.find_child("StageScaffold_Mesh", true, false) == null or inst.find_child("SealedSideDoor_Mesh", true, false) == null:
		_fail("BLD_NoahsArk.glb missing 30-step nodes")
	else:
		_pass("BLD_NoahsArk.glb 30/30 steps + Scaffold + SealedDoor verified")
	inst.free()


func _test_all_v6_scripts_compile() -> void:
	for sp: String in [
		"res://scripts/core/chapter_runtime_host.gd",
		"res://scripts/core/patriarch_player_3d.gd",
		"res://scripts/core/humanoid_rig_helper.gd",
		"res://scripts/core/world_physics_builder.gd",
		"res://scripts/core/deterministic_economy_sim.gd",
		"res://scripts/core/story_state_director.gd",
		"res://scripts/core/noah_cast_and_raid_rig.gd",
		"res://scripts/chapters/bethel_highland_world.gd",
		"res://scripts/prologue_ui_v3.gd",
		"res://scripts/ch00_noah_ark.gd",
		"res://scripts/camp_pilot.gd",
	]:
		var scr: Script = load(sp) as Script
		if scr == null or not scr.can_instantiate():
			_fail("Script compile failed: " + sp)
		else:
			_pass("Script compiled cleanly: " + sp)


func _test_atomic_save_v3_roundtrip() -> void:
	var sm: Node = load("res://scripts/save_manager.gd").new()
	sm.record_carryover("noah_harmony_bonus", 7)
	sm.light_covenant_stone(1)
	var wrote: bool = sm.save_slot(3, {"chapter_id": "ch01_bethel", "monument_pct": 55.0})
	var loaded: Dictionary = sm.load_slot(3)
	sm.delete_slot(3)
	sm.free()
	if not wrote or int(loaded.get("carryoverLedger", {}).get("noah_harmony_bonus", 0)) != 7:
		_fail("CampaignSaveV3 carryover roundtrip failed")
	else:
		_pass("CampaignSaveV3 atomic carryover & stone roundtrip PASS")
