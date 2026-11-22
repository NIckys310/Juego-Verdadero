extends SceneTree
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, description: String) -> void:
 if not condition:
  failures += 1
  push_error(description)

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_presentation.json"
 gm.new_game()
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.show_game()
 var world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 var player = world.player
 player.set_physics_process(false)
 for i in range(8):
  await physics_frame
  player.simulate(1.0 / 60.0, 0)
 world.update_nearby()
 check(world.last_context.enabled and world.last_context.button == "Descansar [E]", "Acción contextual del refugio")
 check(not main.interact_button.disabled, "Botón sincronizado con acción disponible")
 var emitted: Array = []
 world.interaction_changed.connect(func(context): emitted.append(context))
 world.update_nearby()
 world.update_nearby()
 check(emitted.is_empty(), "No reconstruir HUD si el contexto no cambia")
 player.velocity.y = -550
 await physics_frame
 player.simulate(1.0 / 60.0, 0)
 world.update_nearby()
 check(not world.last_context.enabled and main.interact_button.disabled, "No interactuar desde el aire")
 # Línea de acceso global: el mundo está desplazado dentro del marco.
 var blocker = StaticBody2D.new()
 var collider = CollisionShape2D.new()
 var shape = RectangleShape2D.new()
 shape.size = Vector2(14, 90)
 collider.shape = shape
 blocker.add_child(collider)
 blocker.position = Vector2(180, 490)
 world.add_child(blocker)
 await physics_frame
 player.position = Vector2(150, 520)
 check(not world.has_clear_access(Vector2(215, 520)), "Obstáculo bloquea interacción a través del mundo desplazado")
 blocker.queue_free()
 await physics_frame
 check(world.has_clear_access(Vector2(215, 520)), "Retirar obstáculo vuelve a permitir acceso")
 var catalog = Catalog.new()
 for id in ["protagonista", "medic", "nerd", "boss"]:
  var pose: String = "main" if id == "protagonista" else "idle0"
  var texture = catalog.sprite(id, pose)
  check(texture is AtlasTexture and texture.region.size.x > 0, "Región visible de sprite: " + id)
  check(world.character_size(pose) == Vector2(32, 48), "Dimensiones comunes de personaje: " + id)
 check(world.character_size("crouch").y < 48, "Pose agachada conserva su altura natural")
 # Trabajo cancelable por movimiento, sin aplicar cambios de escenario.
 gm.choose_home("reparar")
 gm.advance()
 world.rebuild()
 var bridge_point: Vector2 = preload("res://scripts/terrain_layout.gd").gap_bounds(gm.branch)
 bridge_point = Vector2(bridge_point.x - 35, 520)
 player.position = bridge_point
 player.velocity = Vector2.ZERO
 for i in range(8):
  await physics_frame
  player.simulate(1.0 / 60.0, 0)
 world.begin_work("bridge", bridge_point)
 check(not world.work_target.is_empty(), "Trabajo comienza con acceso válido")
 world.cancel_work()
 check(world.work_target.is_empty() and not gm.flags().get("bridge", false), "Cancelar no completa el puente")
 world.begin_work("bridge", bridge_point)
 player.velocity.x = 60
 world.update_work(1.0 / 60.0)
 check(world.work_target.is_empty(), "Movimiento interrumpe trabajo")
 check(main.theme.get_stylebox("hover", "Button") is StyleBoxTexture, "Tema de bloques con estados de botón")
 main.character_dialog("medic")
 check(not world.active, "Diálogo detiene la exploración")
 main.close_modal()
 check(world.active, "Cerrar diálogo reactiva juego")
 main.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA: escalas, interfaz, contexto, obstáculos y cancelación; fallos = ", failures)
 quit(failures)
