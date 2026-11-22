extends SceneTree
var failures: int = 0
var world: Node2D
var player: CharacterBody2D
var gm: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func tick(axis: float = 0, jump: bool = false) -> void:
 await physics_frame
 player.simulate(1.0 / 60.0, axis, jump)
 world._physics_process(1.0 / 60.0)

func walk(x: float) -> void:
 for i in range(500):
  await tick(clampf((x - player.position.x) / 20, -1, 1), player.is_on_wall() and player.is_on_floor())
  if absf(player.position.x - x) < 1 and absf(player.velocity.x) < 5 and player.is_on_floor():
   return

func jump_to(x: float) -> void:
 await tick(signf(x - player.position.x), true)
 await walk(x)

func run() -> void:
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_refuge.json"
 gm.new_game()
 world = load("res://scripts/world.gd").new()
 world.persist_physical = false
 root.add_child(world)
 gm.changed.connect(world.rebuild)
 world.set_physics_process(false)
 player = world.player
 player.set_physics_process(false)
 for i in range(6):
  await tick()
 check(world.tutorial_text().begins_with("01"), "Introducción empieza con movimiento")
 world.interact_nearest()
 check("rest" in gm.tutorial, "Descanso registrado")
 await walk(410)
 await jump_to(490)
 check(absf(player.position.y - 488) < 1 and "jump" in gm.tutorial, "Primer obstáculo de aprendizaje")
 await walk(535)
 await jump_to(682)
 check(absf(player.position.y - 456) < 1, "Ruta elevada opcional de introducción")
 check(player.health == 100, "Introducción sin daño innecesario")
 await walk(1420)
 world.update_nearby()
 check(world.nearby >= 0 and world.sites[world.nearby].action == "hogar", "Casa al final de la exploración")
 gm.choose_home("reparar")
 check(gm.can_advance() and not world.at_goal(), "Decisión lista, recorrido aún pendiente")
 await walk(world.map_width - 96)
 check(world.at_goal(), "Refugio conecta casa y bandera")
 gm.changed.disconnect(world.rebuild)
 world.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA: recorrido del refugio, salto de aprendizaje, casa y meta; fallos = ", failures)
 quit(failures)
