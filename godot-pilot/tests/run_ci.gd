extends SceneTree
## Automated Headless CI Regression Suite (M0 + M1 Gates)
## Run via: godot --headless --path godot-pilot -s res://tests/run_ci.gd

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("FAIL: " + msg)


func _pass(msg: String) -> void:
	print("PASS: " + msg)


func _init() -> void:
	_test_chapter_jsons()
	_test_prologue_v3_schema()
	_test_quadruped_animals()
	_test_humanoid_rigs()
	_test_ark_30_step_glb()
	_test_m1_scripts_compile()
	_test_atomic_save_roundtrip()

	if failures.is_empty():
		print("\n=== ALL HEADLESS CI GATES PASSED (0 failures) ===")
		quit(0)
	else:
		printerr("\n=== HEADLESS CI FAILED (%d errors) ===" % failures.size())
		quit(1)


func _test_chapter_jsons() -> void:
	for p: String in ["res://data/ch00_noah_ark.json", "res://data/ch00_ur_call.json", "res://data/ch01_bethel.json"]:
		var raw: String = FileAccess.get_file_as_string(p)
		var d: Variant = JSON.parse_string(raw)
		if not (d is Dictionary) or not (d.get("events") is Array):
			_fail("Invalid JSON schema: " + p)
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
		_pass("JSON event graph valid: %s (%d events)" % [p, ids.size()])


func _test_prologue_v3_schema() -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/ch00_noah_ark.json")
	var d: Dictionary = JSON.parse_string(raw)
	if int(d.get("schemaVersion", 0)) < 3:
		_fail("ch00_noah_ark.json must be schemaVersion >= 3")
		return
	var cast: Array = d.get("familyCast", [])
	var codex: Array = d.get("codexEntries", [])
	var dms: Dictionary = d.get("dramaticMoments", {})
	var sim: Dictionary = d.get("simulationConfig", {})
	if cast.size() != 8:
		_fail("familyCast must contain all 8 named family members (got %d)" % cast.size())
	elif codex.size() < 4:
		_fail("codexEntries must contain >= 4 entries")
	elif not dms.has("dm_01_drought_mockery") or not dms.has("dm_02_stay_the_blade") or not dms.has("dm_03_divine_seal"):
		_fail("dramaticMoments missing required scenes")
	elif int(sim.get("arkProgressiveSteps", 0)) != 30 or int(sim.get("treeCount", 0)) != 30:
		_fail("simulationConfig missing 30-step Ark / 30-tree parameters")
	else:
		_pass("Prologue V3 schema verified: 8 named family, %d codex entries, 30-step sim config" % codex.size())


func _test_quadruped_animals() -> void:
	var req_anims: Array[String] = ["Idle", "Walk", "StallRest"]
	for fn: String in ["CC0_Sheep_Grab3D.glb", "CC0_Bull_Grab3D.glb", "CC0_Horse_Grab3D.glb", "CC0_Deer_Grab3D.glb", "CC0_Lion_Grab3D.glb"]:
		var rp: String = "res://assets/models/" + fn
		var ps: PackedScene = ResourceLoader.load(rp) as PackedScene
		if ps == null:
			_fail("Cannot load animal PackedScene: " + fn)
			continue
		var inst: Node = ps.instantiate()
		var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if skel == null or skel.get_bone_count() < 9:
			_fail("%s missing 9-bone quadruped skeleton" % fn)
		elif ap == null:
			_fail("%s missing AnimationPlayer" % fn)
		else:
			var ok: bool = true
			for a in req_anims:
				if not ap.has_animation(a):
					_fail("%s missing anim %s" % [fn, a])
					ok = false
			if ok:
				_pass("Quadruped %s: %d bones, anims=%s" % [fn, skel.get_bone_count(), str(ap.get_animation_list())])
		inst.free()


func _test_humanoid_rigs() -> void:
	for fn: String in ["CHR_Noah_rigged.glb", "CHR_Noah_Wife_rigged.glb", "CHR_Noah_Son_rigged.glb", "CHR_Noah_Daughter_rigged.glb", "CHR_Abram_rigged.glb", "CHR_Sarai_rigged.glb"]:
		var ps: PackedScene = ResourceLoader.load("res://assets/models/" + fn) as PackedScene
		if ps == null:
			_fail("Cannot load humanoid: " + fn)
			continue
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null or not ap.has_animation("Walk") or not ap.has_animation("Pray"):
			_fail("Humanoid missing Walk/Pray: " + fn)
		else:
			_pass("Humanoid %s ready (%d anims)" % [fn, ap.get_animation_list().size()])
		inst.free()


func _test_ark_30_step_glb() -> void:
	var ps: PackedScene = ResourceLoader.load("res://assets/models/BLD_NoahsArk.glb") as PackedScene
	if ps == null:
		_fail("Cannot load BLD_NoahsArk.glb")
		return
	var inst: Node = ps.instantiate()
	var step_meshes: int = 0
	for i in range(1, 26):
		if inst.find_child("BuildStep_%02d_Mesh" % i, true, false) != null:
			step_meshes += 1
	for i in range(26, 30):
		if inst.find_child("CutawayRoof_Step_%02d_Mesh" % i, true, false) != null:
			step_meshes += 1
	if inst.find_child("Stage3_Ramp_Mesh", true, false) != null:
		step_meshes += 1
	var has_scaff: bool = inst.find_child("StageScaffold_Mesh", true, false) != null
	var has_door: bool = inst.find_child("SealedSideDoor_Mesh", true, false) != null
	if step_meshes < 30 or not has_scaff or not has_door:
		_fail("BLD_NoahsArk.glb incomplete: steps=%d/30 scaff=%s door=%s" % [step_meshes, str(has_scaff), str(has_door)])
	else:
		_pass("BLD_NoahsArk.glb verified: 30/30 progressive build steps + StageScaffold_Mesh + SealedSideDoor_Mesh")
	inst.free()


func _test_m1_scripts_compile() -> void:
	for sp: String in ["res://scripts/prologue_ui_v3.gd", "res://scripts/noah_rts_world.gd", "res://scripts/ch00_noah_ark.gd"]:
		var scr: Script = load(sp) as Script
		if scr == null or not scr.can_instantiate():
			_fail("Script failed to compile: " + sp)
		else:
			_pass("M1 Script compiled cleanly: " + sp)


func _test_atomic_save_roundtrip() -> void:
	var sm: Node = load("res://scripts/save_manager.gd").new()
	var sample: Dictionary = {"currentScene": "res://scenes/ch00_noah_ark.tscn", "arkBuildPct": 62.5}
	var wrote: bool = sm.save_slot(3, sample)
	var loaded: Dictionary = sm.load_slot(3)
	sm.delete_slot(3)
	sm.free()
	if not wrote or absf(float(loaded.get("arkBuildPct", 0.0)) - 62.5) > 0.01:
		_fail("Atomic SaveManager round-trip mismatch")
	else:
		_pass("SaveManager atomic round-trip PASS")
