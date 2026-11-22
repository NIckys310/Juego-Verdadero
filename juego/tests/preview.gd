extends SceneTree
## Vista de revisión sin modificar el guardado.
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1280, 800)
 var scene = load("res://scenes/main.tscn").instantiate()
 root.get_node("GameManager").save_path = "user://verdaria_test_preview.json"
 DirAccess.make_dir_recursive_absolute("res://build")
 root.add_child(scene)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/menu.png")
 var gm = root.get_node("GameManager")
 gm.branch = "A"
 gm.level = 2
 gm.world_seed = 125
 gm.history = [{"action": "reparar", "level": 1}]
 scene.show_game()
 scene.world.persist_physical = false
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/game.png")
 scene.character_dialog("medic")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/dialogue.png")
 scene.close_modal()
 gm.level = 1
 gm.branch = ""
 gm.history = []
 scene.show_game()
 scene.world.persist_physical = false
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/refuge.png")
 for branch in ["A", "B", "C"]:
  gm.branch = branch
  gm.level = 2
  gm.characters = gm.narrative.initial_states()
  gm.decisions = {}
  gm.world_flags = {}
  scene.show_game()
  scene.world.persist_physical = false
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/opening_%s.png" % branch)
 gm.world_flags = {"2": {"bridge": true, "rubble": true}}
 gm.characters.medic.status = "rescatada"
 gm.decisions = {"elena_rescue": "rescatar"}
 scene.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/rescue_complete.png")
 for branch in ["A", "B", "C"]:
  gm.branch = branch
  gm.level = 8
  scene.show_game()
  scene.world.persist_physical = false
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/branch_%s.png" % branch)
 DirAccess.remove_absolute(gm.save_path)
 quit()
