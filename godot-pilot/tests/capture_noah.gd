extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 var scene = load("res://scenes/ch00_noah_ark.tscn").instantiate()
 scene.preview_ararat = true
 root.add_child(scene)
 scene.mood_tween.custom_step(4)
 scene.water_tween.custom_step(4)
 for i in range(1000):
  scene._process(.016)
 for i in range(30):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://shots/noah_ararat.png")
 quit()
