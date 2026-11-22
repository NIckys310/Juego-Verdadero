extends SceneTree
var failures: int = 0
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1280, 800)
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_platform_preview.json"
 gm.audio_enabled = false
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 DirAccess.make_dir_recursive_absolute("res://build")
 var views = [
  ["A", 3, Vector2(640, 392), 300.0, "acueducto"],
  ["B", 3, Vector2(790, 520), 300.0, "fundicion"],
  ["C", 4, Vector2(732, 264), 350.0, "colina"],
  ["A", 8, Vector2(1256, 440), 850.0, "molino"],
  ["B", 7, Vector2(675, 328), 300.0, "laboratorio"],
  ["C", 10, Vector2(3680, 440), 3360.0, "guardian"]
 ]
 for view in views:
  gm.branch = view[0]
  gm.level = view[1]
  gm.completed = []
  gm.world_flags = {}
  gm.characters = gm.narrative.initial_states()
  gm.reset_physical()
  main.show_game()
  var world = main.world
  world.persist_physical = false
  world.active = false
  world.camera_x = view[3]
  world.scenery.scroll = world.camera_x
  world.player.position = view[2]
  world.player.previous_position = view[2]
  world.player.velocity = Vector2.ZERO
  world.scenery.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/mapa_%s.png" % view[4])
 # Regresión visual: misma sombra debajo de los mismos pies al cambiar dirección.
 var world = main.world
 world.player.invulnerability = 0
 world.player.facing_left = false
 world.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var right = root.get_texture().get_image()
 world.player.facing_left = true
 world.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var left = root.get_texture().get_image()
 var feet: Vector2 = world.player.position - Vector2(floor(world.camera_x), 0) + Vector2(24, 125)
 for x in range(int(feet.x) - 10, int(feet.x) + 10):
  for y in range(int(feet.y) + 1, int(feet.y) + 3):
   if right.get_pixel(x, y) != left.get_pixel(x, y):
    failures += 1
 if failures > 0:
  push_error("La sombra se desplaza al girar")
 print("VERDARIA: seis vistas de mapas y sombra estable al girar; fallos = ", failures)
 main.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 quit(failures)
