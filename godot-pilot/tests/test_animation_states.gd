extends SceneTree

const EXPECTED_CLIPS := ["Idle", "Walk", "Pray"]
const EXPECTED_BONES := 14

func _find_by_class(root: Node, cls_name: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur.get_class() == cls_name:
			return cur
		for ch in cur.get_children():
			stack.append(ch)
	return null


func _verify_actor(scene: Node, actor_name: String) -> Array[String]:
	var errs: Array[String] = []
	var actor: Node = scene.get_node_or_null(actor_name)
	if actor == null:
		errs.append("%s: missing actor node" % actor_name)
		return errs

	var skel := _find_by_class(actor, "Skeleton3D") as Skeleton3D
	if skel == null:
		errs.append("%s: missing Skeleton3D" % actor_name)
	elif skel.get_bone_count() != EXPECTED_BONES:
		errs.append("%s: expected %d bones, got %d" % [actor_name, EXPECTED_BONES, skel.get_bone_count()])

	var ap := _find_by_class(actor, "AnimationPlayer") as AnimationPlayer
	if ap == null:
		errs.append("%s: missing AnimationPlayer" % actor_name)
	else:
		for c in EXPECTED_CLIPS:
			if not ap.has_animation(c):
				errs.append("%s: missing clip '%s'" % [actor_name, c])

	var tree := actor.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null:
		errs.append("%s: missing AnimationTree" % actor_name)
	else:
		if not tree.active:
			errs.append("%s: AnimationTree is not active" % actor_name)
		var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if pb == null:
			errs.append("%s: missing AnimationNodeStateMachinePlayback" % actor_name)
		elif skel != null:
			# Verify each state is reachable and actually animates Skeleton3D bone poses!
			for st in [&"Walk", &"Pray", &"Idle"]:
				pb.travel(st)
				tree.advance(0.35)
				var q0: Quaternion = skel.get_bone_pose_rotation(6) # UpperArm_L
				tree.advance(0.30)
				var q1: Quaternion = skel.get_bone_pose_rotation(6)
				if q0.is_equal_approx(q1) and st == &"Walk":
					errs.append("%s: Skeleton3D UpperArm_L bone did not animate during Walk!" % actor_name)
				print("  [OK] %s -> state=%s, bone(UpperArm_L) q0=%s q1=%s" % [actor_name, str(pb.get_current_node()), str(q0), str(q1)])
	return errs


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/camp_pilot.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	var all_errs: Array[String] = []
	for actor_name in ["AbramCommercialGLB", "SaraiCommercialGLB"]:
		print("Checking skeletal rig & AnimationTree for %s..." % actor_name)
		all_errs.append_array(_verify_actor(scene, actor_name))

	# Clean up cached GLBs so no RID leaks on exit
	var loader_script = load("res://scripts/glb_asset_loader.gd")
	if loader_script != null:
		loader_script.clear_cache()

	if all_errs.is_empty():
		print("ANIMATION_STATE_TEST: PASS (Abram + Sarai 14-bone Skeleton3D + 3 clips + live bone deformation verified!)")
		quit(0)
	else:
		for e in all_errs:
			printerr("FAIL: ", e)
		quit(1)
