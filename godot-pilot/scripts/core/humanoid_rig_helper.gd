class_name HumanoidRigHelper
extends RefCounted
## Layered Upper/Lower Body AnimationTree + Lightweight RVO Agent Separation Helper:
## - Builds an AnimationTree (`AnimationNodeBlendTree`) with upper-body bone mask (`Spine..Forearm_L/R`)
##   so characters smoothly walk/run with their legs while carrying logs, raising shields, or holding torches!
## - Computes smooth RVO-style crowd separation velocity so workers, herdsmen & raiders NEVER stack on ramps!

const UPPER_BONES: Array[String] = [
	"Spine", "Chest", "Neck", "Head",
	"Shoulder_L", "UpperArm_L", "Forearm_L", "Hand_L",
	"Shoulder_R", "UpperArm_R", "Forearm_R", "Hand_R",
]


static func setup_layered_anim_tree(actor: Node3D) -> AnimationTree:
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if ap == null or skel == null:
		return null
	for anim_name in ap.get_animation_list():
		var anim: Animation = ap.get_animation(anim_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR

	var existing: AnimationTree = actor.find_child("LayeredAnimTree", false, false) as AnimationTree
	if existing != null:
		return existing

	var tree: AnimationTree = AnimationTree.new()
	tree.name = "LayeredAnimTree"
	actor.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(ap.get_parent())

	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var base_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	base_node.animation = &"Idle"
	var upper_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	upper_node.animation = &"Idle"
	var blend2: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	blend2.filter_enabled = true

	for bi in range(skel.get_bone_count()):
		var bname: String = skel.get_bone_name(bi)
		for ub in UPPER_BONES:
			if bname == ub or bname.contains(ub):
				var skel_rel: String = str(ap.get_parent().get_path_to(skel))
				blend2.set_filter_path(NodePath(skel_rel + ":" + bname), true)
				break

	bt.add_node(&"BaseAnim", base_node, Vector2(-240, -60))
	bt.add_node(&"UpperAnim", upper_node, Vector2(-240, 120))
	bt.add_node(&"UpperBlend", blend2, Vector2(40, 20))
	bt.connect_node(&"UpperBlend", 0, &"BaseAnim")
	bt.connect_node(&"UpperBlend", 1, &"UpperAnim")
	bt.connect_node(&"output", 0, &"UpperBlend")

	tree.tree_root = bt
	tree.set("parameters/UpperBlend/blend_amount", 0.0)
	tree.active = true
	return tree


static func play_layered(actor: Node3D, base_clip: String, upper_clip: String = "", upper_weight: float = 0.0) -> void:
	var tree: AnimationTree = actor.find_child("LayeredAnimTree", false, false) as AnimationTree
	var ap: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if tree == null or not tree.active or ap == null:
		if ap != null and ap.has_animation(base_clip) and ap.current_animation != base_clip:
			ap.play(base_clip, 0.18)
		return
	var bt: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
	if bt == null:
		return
	var bn: AnimationNodeAnimation = bt.get_node(&"BaseAnim") as AnimationNodeAnimation
	if bn != null and ap.has_animation(base_clip) and bn.animation != StringName(base_clip):
		bn.animation = StringName(base_clip)
	var un: AnimationNodeAnimation = bt.get_node(&"UpperAnim") as AnimationNodeAnimation
	if not upper_clip.is_empty() and un != null and ap.has_animation(upper_clip):
		if un.animation != StringName(upper_clip):
			un.animation = StringName(upper_clip)
		tree.set("parameters/UpperBlend/blend_amount", clampf(upper_weight, 0.0, 1.0))
	else:
		tree.set("parameters/UpperBlend/blend_amount", 0.0)


## RVO-style local crowd separation vector on XZ plane so agents never overlap on gangplanks or paths
static func compute_rvo_step(agent: Node3D, desired_target: Vector3, speed: float, neighbors: Array, radius: float, delta: float) -> Vector3:
	var to_t: Vector3 = Vector3(desired_target.x - agent.position.x, 0.0, desired_target.z - agent.position.z)
	if to_t.length_squared() < 0.001:
		return Vector3.ZERO
	var pref_vel: Vector3 = to_t.normalized() * speed
	var sep: Vector3 = Vector3.ZERO
	for nb in neighbors:
		var other: Node3D = nb as Node3D
		if other == null or other == agent or not other.visible:
			continue
		var diff: Vector3 = Vector3(agent.position.x - other.position.x, 0.0, agent.position.z - other.position.z)
		var dist: float = diff.length()
		if dist > 0.001 and dist < radius * 2.0:
			var push: float = (radius * 2.0 - dist) / (radius * 2.0)
			sep += (diff / dist) * (push * speed * 1.35)
	var final_v: Vector3 = pref_vel + sep
	if final_v.length() > speed * 1.15:
		final_v = final_v.normalized() * (speed * 1.15)
	return final_v * delta
