extends SceneTree
var failures: int = 0
func check(ok: bool, detail: String) -> void:
 if not ok:
  failures += 1
  push_error(detail)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/ch00_noah_ark.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 print("Ark bounds: ",scene.obstacles[0])
 check(scene.player != null,"Noah AnimationPlayer missing")
 var skeleton = scene.noah.find_children("*","Skeleton3D",true,false)
 check(skeleton.size() == 1 and skeleton[0].get_bone_count() == 14,"Expected 14 bones")
 for clip in ["Idle","Walk","Pray"]:
  check(scene.player.has_animation(clip),"Missing clip: " + clip)
 for item in scene.chapter.events:
  scene._enter_event(item.id)
  var visible_count: int = 0
  for mesh in scene.ark.find_children("*","MeshInstance3D",true,false):
   if mesh.visible:
    visible_count += 1
  check(visible_count == [0,1,3,5][int(item.arkStage)],"Wrong ark stage: " + item.id)
  check(not scene.waypoints.is_empty(),"Unreachable waypoint: " + item.id)
  for point in scene.waypoints:
   check(not scene._blocked(Vector2i(roundi(point.x),roundi(point.z))),"Route intersects obstacle")
  if item.has("requiredAction"):
   scene._perform_action()
   for frame in range(1500):
    scene._process(.016)
    if scene.action_ready:
     break
   check(scene.action_ready,"Action did not complete: " + item.id)
  if int(item.act) == 4:
   scene.water_tween.custom_step(20)
   check(scene.flood_finished,"Flood did not recede")
  if int(item.act) >= 5:
   check(not scene.hud.visible,"Worship HUD must be hidden")
   check(scene.animation == "Pray" or not scene.waypoints.is_empty(),"No altar prayer")
  var before: Dictionary = scene.state.duplicate(true)
  var choice: Dictionary = item.choices[0]
  scene._choose(choice)
  check(not scene.pending_choice.is_empty(),"Choice rejected: " + item.id)
  if int(item.act) >= 5:
   check(scene.state == before,"Worship changed resources")
  if choice.id == "hull_fence_watch":
   check(scene.fence.visible,"Fence choice did not show fence")
  scene._continue_story()
 # The completion button must actually transition to the overworld.
 var button = scene.content.get_child(scene.content.get_child_count()-1)
 button.pressed.emit()
 await process_frame
 await process_frame
 check(current_scene != null and current_scene.scene_file_path == "res://scenes/overworld_prologue.tscn","Overworld transition failed")
 print("NOAH_PROLOGUE failures=",failures)
 quit(1 if failures else 0)
