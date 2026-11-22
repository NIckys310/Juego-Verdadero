extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func capture(path: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)

func run() -> void:
 root.size = Vector2i(1280, 800)
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_v2_visual.json"
 gm.audio_enabled = false
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 scene.settings_dialog()
 await capture("res://build/v2_settings.png")
 scene.close_modal()
 gm.new_game()
 gm.branch = "A"
 gm.level = 5
 gm.reset_physical()
 scene.show_game()
 scene.world.persist_physical = false
 scene.pause_dialog()
 await capture("res://build/v2_pause.png")
 scene.close_modal()
 root.size = Vector2i(960, 600)
 await capture("res://build/v2_small_window.png")
 root.size = Vector2i(1600, 900)
 await capture("res://build/v2_wide_window.png")
 scene.queue_free()
 await process_frame
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
  DirAccess.remove_absolute(gm.save_path + suffix)
 print("VERDARIA V2: capturas de ajustes, pausa y dos tamaños de ventana")
 quit()
