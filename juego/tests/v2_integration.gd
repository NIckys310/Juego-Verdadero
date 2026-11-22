extends SceneTree
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures: int = 0
var gm: Node
var main: Control

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_v2_integration.json"
 gm.audio_enabled = false
 var catalog = Catalog.new()
 for branch in ["A", "B", "C"]:
  for level in range(1, 11):
   for layer in ["cielo", "frente", "fondo"]:
    var texture = catalog.texture(catalog.landscape_path(branch, level, layer))
    check(texture != null and texture.get_size() == Vector2(480, 270), "Arte v2: " + branch + str(level) + layer)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 for selection in [["A", 2], ["A", 4], ["A", 5], ["C", 2]]:
  gm.new_game()
  gm.branch = selection[0]
  gm.level = selection[1]
  gm.reset_physical()
  main.show_game()
  var world = main.world
  world.persist_physical = false
  world.set_physics_process(false)
  world.player.set_physics_process(false)
  var device: Dictionary = world.map_data.device
  world.player.travel(device.point)
  for i in range(8):
   await physics_frame
   world.player.simulate(1.0 / 60, 0)
  world.update_nearby()
  check(world.last_context.enabled and world.last_context.button == "Activar [E]", "Mecanismo accesible: " + device.kind)
  world.interact_nearest()
  check(gm.flags().get("device", false), "E activa: " + device.kind)
  check(not gm.activate_device(), "Activación única")
  if device.kind == "water":
   check(world.surfaces.any(func(surface): return surface.id == "device_bridge"), "Compuerta añade colisión real")
   for hazard in world.map_data.hazards:
    if hazard.rect.intersects(device.zone):
     check(not world.hazard_active(hazard), "Paso recuperado desactiva peligro")
  elif device.kind == "lift":
   check(world.moving_platforms.size() == world.map_data.moving.size() + 1, "Elevador físico añadido")
   check(world.surfaces.any(func(surface): return surface.id == "lift_landing"), "Desembarco del elevador")
  elif device.kind == "wind":
   world.player.position = device.zone.get_center()
   world.update_adventure(0)
   check(world.player.environment_lift < -1600, "Corriente contrarresta gravedad")
   world.player.position = Vector2(80, 520)
   world.update_adventure(0)
   check(world.player.environment_lift == 0, "Viento cesa fuera de la zona")
  else:
   for hazard in world.map_data.hazards:
    if hazard.get("section", -1) == device.section and hazard.kind in ["spikes", "steam", "saw"]:
     check(not world.hazard_active(hazard), "Defensa desactiva trampas")
  check(gm.load_game() and gm.flags().get("device", false), "Mecanismo persiste al cargar")
  var secret: Dictionary = world.map_data.secrets[0]
  var before: int = gm.seeds
  world.player.position = secret.point + Vector2(0, 20)
  world.update_adventure(0)
  check(gm.flags().get("secrets", {}).get(secret.id, false) and gm.seeds >= before + 2, "Recuerdo recogido por contacto")
  before = gm.seeds
  world.update_adventure(0)
  check(gm.seeds == before, "Recuerdo no duplica premio")
 # Ruta elevada: coste, colisión y secreto accesible, sin aplicar curación del paso seguro.
 gm.new_game()
 gm.branch = "A"
 gm.level = 3
 gm.reset_physical()
 main.show_game()
 var world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 world.player.set_physics_process(false)
 var node: Dictionary = world.map_data.restoration[0]
 world.player.travel(node.point)
 for i in range(8):
  await physics_frame
  world.player.simulate(1.0 / 60, 0)
 gm.seeds = 7
 gm.seeds_earned = 7
 world.player.health = 60
 world.try_restore("high")
 check(gm.seeds == 2 and world.player.health == 60, "Ruta elevada cuesta cinco y conserva salud")
 check(world.surfaces.any(func(surface): return surface.id == node.raised.id), "Pasarela elevada con colisión")
 var route_secret: Array = world.stage_secrets().filter(func(secret): return secret.id.begins_with("route_"))
 check(route_secret.size() == 1, "Ruta elevada revela recuerdo")
 world.player.position = route_secret[0].point + Vector2(0, 20)
 world.update_adventure(0)
 check(gm.flags().get("secrets", {}).get(route_secret[0].id, false), "Recuerdo elevado recogible")
 main.settings_dialog()
 check(not world.active and main.modal_box.get_child_count() >= 7, "Ajustes pausan y contienen controles")
 main.close_modal()
 var event = InputEventJoypadButton.new()
 event.button_index = JOY_BUTTON_START
 event.pressed = true
 main._unhandled_input(event)
 check(not world.active and is_instance_valid(main.modal), "Start pausa con mando")
 main.close_modal()
 world.player.position = Vector2(2400, 520)
 world.camera_x = 1800
 world.player.respawn()
 check(world.camera_x == world.CameraRig.reset_at(world.player.checkpoint.x, world.map_width), "Cámara retorna inmediatamente al refugio")
 main.queue_free()
 await process_frame
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
  DirAccess.remove_absolute(gm.save_path + suffix)
 print("VERDARIA V2: 28 paisajes, mecanismos, secretos, ruta elevada, mando, ajustes y retorno; fallos = ", failures)
 quit(failures)
