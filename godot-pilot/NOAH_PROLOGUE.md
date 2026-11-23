# Noah prologue

Open scenes/ch00_noah_ark.tscn in Godot 4.7.2 and run the current scene (F6).

CLI: Godot --path godot-pilot res://scenes/ch00_noah_ark.tscn -- --stage=3
Use --ararat for the covenant preview. Exported preview_stage defaults to -1 (Act 1).

All narrative text, action labels, choices, outcomes and event links are read from data/ch00_noah_ark.json. Required actions send Noah along a grid A* route, then unlock choices after arrival and the action animation. Choices display their outcome before Continue. The flood takes 14 seconds to rise and recede before its choice unlocks. Worship and covenant mutate no resources and display no resource HUD. The completion panel opens the existing overworld.

Validation: Godot --headless --path godot-pilot --script res://tests/test_noah_prologue.gd
Checks all eight events, stage meshes, rig/clips, reachable obstacle-free paths, action gates, fence choice, unscored worship, flood recession and the real overworld transition.

Capture: Godot --path godot-pilot --resolution 1280x720 --script res://tests/capture_noah.gd
Writes shots/noah_ararat.png. The scene uses existing CC0 props and a procedural miniature landscape; the reference image guides its composition, rather than serving as a rendered backdrop.

The missing rigged Noah asset was generated from CHR_Noah.glb. Rebuild with Python + numpy: python godot-pilot/scripts/build_noah_rig.py. The generator adapts the repository's existing 14-bone rig and preserves the source vertex colors.
