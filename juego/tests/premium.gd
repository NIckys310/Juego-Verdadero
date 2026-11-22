extends SceneTree
const Terrain = preload("res://scripts/terrain_layout.gd")
var gm: Node
var main: Control
var world: Node2D
var player: CharacterBody2D
var failures: int = 0
var tested_boxes: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func stage(branch: String, level: int) -> void:
 gm.branch = branch
 gm.level = level
 gm.world_flags = {}
 gm.completed = []
 gm.decisions = {}
 gm.characters = gm.narrative.initial_states()
 gm.finished = false
 gm.reset_physical()
 main.show_game()
 world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 player = world.player
 player.set_physics_process(false)

func tick() -> void:
 await physics_frame
 player.simulate(1.0 / 60.0, 0)

func settle(point: Vector2) -> void:
 player.travel(point)
 for i in range(7):
  await tick()

func box_support(surface: Dictionary) -> Vector2:
 return Vector2(surface.rect.get_center().x, surface.rect.position.y + 144)

func finish() -> void:
 world.check_goal()
 for i in range(65):
  await physics_frame
  world._physics_process(1.0 / 60.0)

func run() -> void:
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_premium.json"
 gm.audio_enabled = false
 gm.new_game()
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 # Todas las cajas tienen una cubierta real y espacio para cuerpo + salto.
 for branch in ["A", "B", "C"]:
  for level in range(2, 11):
   var surfaces: Array = Terrain.build(branch, level)
   for node in Terrain.stage(branch, level).restoration:
    var standing_body: Rect2 = Rect2(node.surface.rect.position + Vector2(110, -44), Vector2(22, 44))
    check(not surfaces.any(func(surface): return not surface.one_way and surface.rect.intersects(standing_body)), "Cuerpo cabe sobre pasarela reconstruida: " + branch + str(level))
   for surface in surfaces:
    if surface.style != "bonus":
     continue
    var point = box_support(surface)
    var support: bool = surfaces.any(func(other): return other.id != surface.id and absf(other.rect.position.y - point.y) < 1 and point.x >= other.rect.position.x + 11 and point.x <= other.rect.end.x - 11)
    check(support, "Cubierta bajo caja: " + branch + str(level) + surface.id)
    check(point.y - surface.rect.end.y >= 100, "Espacio para cabeza y salto")
 # Golpes reales desde las cubiertas de TODOS los bloques de niveles 2 y 3.
 for branch in ["A", "B", "C"]:
  for level in [2, 3]:
   stage(branch, level)
   var boxes: Array = world.surfaces.filter(func(surface): return surface.style == "bonus")
   for box in boxes:
    await settle(box_support(box))
    player.health = 60
    var before: int = gm.seeds
    player.simulate(1.0 / 60.0, 0, true)
    for i in range(45):
     await tick()
     world.update_adventure(0)
    check(gm.flags().get("bonus", {}).get(box.id, false), "Caja accesible mediante salto: " + branch + str(level) + box.id)
    check(player.health >= 80, "Caja entrega vida")
    check(gm.seeds >= before + 3, "Caja entrega semillas")
    tested_boxes += 1
 # Efectos distintos, coste único y recompensa de misión.
 for branch in ["A", "B", "C"]:
  stage(branch, 3)
  gm.seeds = 8
  gm.seeds_earned = 8
  gm.resources = {"comunidad": 0, "materiales": 0, "seguridad": 0}
  var node: Dictionary = world.map_data.restoration[1] if branch == "B" else world.map_data.restoration[0]
  await settle(node.point)
  player.health = 60
  world.persist_physical = branch == "C"
  world.update_nearby()
  check(not main.pulse_button.disabled, "Botón Q refleja disponibilidad")
  world.try_restore()
  await process_frame
  check(gm.seeds == 5 and gm.seeds_earned == 8, "Gasto de semillas conserva contador de recogida")
  check(gm.flags().get("restored", {}).get(str(node.id), false), "Reconstrucción persistente")
  check(world.surfaces.any(func(surface): return surface.id == node.surface.id), "Reconstrucción añade colisión")
  check(node.id in gm.completed, "Reconstruir completa el encargo de ese tramo")
  world.try_restore()
  check(gm.seeds == 5, "No cobrar dos veces")
  if branch == "A":
   check(player.health == 80, "Rebrotar recupera vida")
  elif branch == "B":
   var steam: Dictionary = world.map_data.hazards.filter(func(hazard): return hazard.kind == "steam")[0]
   world.gameplay_clock = 2.5
   check(not world.hazard_active(steam), "Reactivar apaga vapor de ese tramo")
   var lava: Dictionary = world.map_data.hazards.filter(func(hazard): return hazard.kind == "lava")[0]
   check(world.hazard_active(lava), "La lava conserva su peligro")
  else:
   check(player.checkpoint == node.point, "Reforzar abre punto de retorno")
  # Colocar para la caída sin modificar el punto de retorno ni la salud.
  player.position = Vector2(node.surface.rect.position.x + 110, node.surface.rect.position.y - 30)
  player.previous_position = player.position
  player.highest_feet = player.position.y
  player.velocity = Vector2.ZERO
  player.airborne = true
  player.reset_platform_frames = 2
  for i in range(25):
   await tick()
  check(absf(player.position.y - node.surface.rect.position.y) < 1, "Aterrizaje real sobre pasarela reconstruida: " + branch)
  gm.collect_pickup(800)
  gm.collect_pickup(801)
  check(gm.seeds == 7 and gm.seeds_earned == 10 and gm.resources.materiales >= 1, "Material por diez recogidas, aunque se gasten semillas")
  gm.save_game()
  check(gm.load_game() and gm.flags().get("restored", {}).get(str(node.id), false), "Cargar conserva reconstrucción")
  if branch == "C":
   check(gm.physical.checkpoint_x == node.point.x and gm.physical.health == 60, "Nuevo punto de retorno guardado con salud")
 # Flag desde suelo: ninguna tecla, un solo avance y ninguna ventana intermedia.
 stage("A", 1)
 gm.branch = ""
 gm.choose_home("reparar")
 await settle(Vector2(world.map_width - 96, 520))
 var events: Array = []
 world.exit_requested.connect(func(): events.append(1))
 await finish()
 check(gm.level == 2 and events.size() == 1, "Bandera cambia exactamente una vez sin E")
 check(not is_instance_valid(main.modal), "Sin diálogo para pasar nivel")
 # La bandera también detecta contacto en el aire.
 stage("C", 3)
 for site in gm.layout().sites:
  gm.interact(site.id, site.action)
 player.position = Vector2(world.map_width - 96, 440)
 player.previous_position = player.position
 player.velocity = Vector2(0, 100)
 await finish()
 check(gm.level == 4, "Bandera desde salto pasa automáticamente")
 # Encuentro ignorado: aviso previo y consecuencia, sin confirmar al cruzar.
 stage("C", 2)
 for site in gm.layout().sites:
  gm.interact(site.id, site.action)
 await settle(Vector2(world.map_width - 96, 520))
 world.update_nearby()
 check("Cruzar" in world.last_context.hint, "Aviso de consecuencia antes de cruzar")
 await finish()
 check(gm.level == 3 and gm.characters.medic.status == "desaparecida", "Cruzar sin rescatar mantiene consecuencia narrativa")
 check(not is_instance_valid(main.modal), "No exigir confirmación al cruzar")
 # Objetivos incompletos y guardián bloquean el avance automático.
 stage("B", 3)
 await settle(Vector2(world.map_width - 96, 520))
 world.check_goal()
 check(not world.exiting and gm.level == 3, "No pasar sin encargos")
 stage("C", 10)
 for site in gm.layout().sites:
  gm.interact(site.id, site.action)
 await settle(Vector2(world.map_width - 96, 520))
 world.check_goal()
 check(not world.exiting, "Guardián bloquea la meta")
 for enemy in world.enemies:
  if enemy.kind == "guardian":
   enemy.dead = true
 await finish()
 check(gm.finished and is_instance_valid(main.modal), "Bandera final presenta desenlace automáticamente")
 main.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA PREMIUM: ", tested_boxes, " cajas físicas, pulso A/B/C, economía, guardado y bandera automática; fallos = ", failures)
 quit(failures)
