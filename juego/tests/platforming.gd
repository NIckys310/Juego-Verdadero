extends SceneTree
const Terrain = preload("res://scripts/terrain_layout.gd")
const Player = preload("res://scripts/player_controller.gd")
var failures: int = 0
var main: Control
var world: Node2D
var player: CharacterBody2D
var gm: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func reachable(surfaces: Array, start: Vector2) -> Dictionary:
 var visited: Dictionary = {}
 var queue: Array = []
 for i in range(surfaces.size()):
  var rect: Rect2 = surfaces[i].rect
  if absf(rect.position.y - start.y) < 1 and start.x >= rect.position.x and start.x <= rect.end.x:
   queue.append(i)
   visited[i] = true
 while not queue.is_empty():
  var i: int = queue.pop_front()
  var from: Rect2 = surfaces[i].rect
  for j in range(surfaces.size()):
   if visited.has(j):
    continue
   var to: Rect2 = surfaces[j].rect
   var rise: float = from.position.y - to.position.y
   if rise > 100 or rise < -160:
    continue
   var distance = maxf(0, maxf(to.position.x - from.end.x, from.position.x - to.end.x)) + 20
   var discriminant: float = Player.JUMP_SPEED * Player.JUMP_SPEED - 2 * Player.GRAVITY * rise
   if discriminant < 0:
    continue
   var travel: float = (Player.JUMP_SPEED + sqrt(discriminant)) / Player.GRAVITY * Player.SPEED
   if distance > travel - 10:
    continue
   visited[j] = true
   queue.append(j)
 return visited

func supported(point: Vector2, surfaces: Array, visited: Dictionary) -> bool:
 for i in visited:
  var rect: Rect2 = surfaces[i].rect
  if absf(point.y - rect.position.y) < 1 and point.x >= rect.position.x + 10 and point.x <= rect.end.x - 10:
   return true
 return false

func tick(axis: float = 0, jump: bool = false) -> void:
 await physics_frame
 player.simulate(1.0 / 60.0, axis, jump)

func settle(point: Vector2) -> void:
 player.travel(point)
 for i in range(6):
  await tick()

func run() -> void:
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_platforming.json"
 gm.new_game()
 var shapes: Dictionary = {}
 for branch in ["A", "B", "C"]:
  for level in range(2, 11):
   var data: Dictionary = Terrain.stage(branch, level)
   var surfaces: Array = Terrain.build(branch, level, {"bridge": true, "rubble": true})
   var reachable_nodes = reachable(surfaces, Vector2(80, 520))
   check(data.width >= 3200, "Recorrido de varias pantallas: " + branch + str(level))
   for point in data.tasks:
    check(supported(point, surfaces, reachable_nodes), "Encargo con ruta alcanzable: " + branch + str(level) + str(point))
   check(supported(Vector2(data.width - 96, 520), surfaces, reachable_nodes), "Ruta conectada hasta meta: " + branch + str(level))
   for checkpoint in data.checkpoints:
    check(supported(checkpoint, surfaces, reachable_nodes), "Refugio sobre suelo accesible")
   if level == 2:
    check(supported(data.rescue, surfaces, reachable_nodes), "Elena sobre plataforma alcanzable: " + branch)
   var shape = JSON.stringify(data.surfaces) + JSON.stringify(data.hazards) + JSON.stringify(data.moving)
   check(not shapes.has(shape), "Mapa diferente de los otros: " + branch + str(level))
   shapes[shape] = true
 check(shapes.size() == 27, "27 mapas de campaña distintos más refugio compartido")
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 gm.branch = "A"
 gm.level = 3
 gm.reset_physical()
 main.show_game()
 world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 player = world.player
 player.set_physics_process(false)
 await settle(Vector2(440, 520))
 await tick(0, true)
 for i in range(60):
  await tick()
 check(absf(player.position.y - 456) < 1, "Salto real atraviesa plataforma unilateral y aterriza exactamente")
 check(player.health == 100, "Salto de un escalón no daña")
 await settle(Vector2(530, 456))
 await tick(1, true)
 for i in range(65):
  await tick(clampf((600 - player.position.x) / 24, -1, 1))
 check(absf(player.position.y - 392) < 1, "Ruta elevada real sobre el acueducto")
 # Hueco: caer devuelve al refugio; no queda atrapado debajo del mapa.
 await settle(Vector2(80, 520))
 player.position = Vector2(580, 520)
 player.previous_position = player.position
 player.velocity = Vector2.ZERO
 player.health = 100
 for i in range(100):
  await tick()
 check(player.health == 100 and player.position.distance_to(player.checkpoint) < 1, "Abismo retorna a refugio")
 # Semillas y cofres no duplican recompensas al cargar.
 for i in range(10):
  gm.collect_pickup(i)
 gm.collect_pickup(0)
 check(gm.seeds == 10 and gm.resources.materiales == 1, "Diez semillas dan un material, recogida única")
 gm.open_bonus("test_bonus")
 gm.open_bonus("test_bonus")
 check(gm.seeds == 13, "Cofre con recompensa única")
 var terrain_root = world.terrain_root
 gm.collect_pickup(11)
 check(world.terrain_root == terrain_root, "Recoger semillas conserva colisiones y plataformas")
 check(gm.load_game() and gm.seeds == 14, "Coleccionables persistentes")
 # Stomp y contacto lateral son consecuencias diferentes.
 var enemy = world.enemies[0]
 enemy.position = Vector2(400, 520)
 player.invulnerability = 0
 player.health = 100
 player.position = Vector2(390, 520)
 player.previous_position = player.position
 player.velocity = Vector2.ZERO
 world.update_adventure(0)
 check(player.health == 80 and not enemy.dead, "Contacto lateral daña sin derrotar enemigo")
 player.invulnerability = 0
 player.position = Vector2(400, 498)
 player.previous_position = Vector2(400, 484)
 player.velocity = Vector2(0, 240)
 world.update_adventure(0)
 check(enemy.dead and player.velocity.y < 0, "Salto encima derrota amenaza y rebota")
 check(gm.flags().get("defeated", {}).get("0", false), "Enemigo neutralizado permanece guardado")
 # Bloque real, golpeado desde abajo.
 var bonus: Dictionary = world.surfaces.filter(func(surface): return surface.id == "s0_bonus")[0]
 var bonus_point = Vector2(bonus.rect.get_center().x, bonus.rect.position.y + 144)
 await settle(bonus_point)
 player.health = 60
 await tick(0, true)
 for i in range(45):
  await tick()
  world.update_adventure(0)
 check(gm.flags().get("bonus", {}).get("s0_bonus", false), "Golpe por abajo abre bloque de provisiones")
 check(player.health == 80, "Provisiones recuperan veinte puntos")
 # Vapor avisa y alterna un tiempo seguro con otro peligroso.
 var steam = {"kind": "steam", "rect": Rect2(400, 408, 64, 112), "phase": 0.0}
 world.gameplay_clock = 1
 check(not world.hazard_active(steam), "Intervalo seguro de respiradero")
 world.gameplay_clock = 2
 check(world.hazard_active(steam), "Intervalo activo de respiradero")
 # Las plataformas móviles transportan al jugador, no sólo su dibujo.
 gm.level = 8
 gm.reset_physical()
 world.rebuild()
 world.gameplay_clock = 0
 world.update_platforms()
 var moving_entry: Dictionary = world.moving_platforms[0]
 var deck: Rect2 = moving_entry.data.rect
 await settle(Vector2(deck.get_center().x, deck.position.y))
 var initial_x: float = player.position.x
 for i in range(45):
  world.gameplay_clock += 1.0 / 60.0
  world.update_platforms()
  await tick()
 check(absf(player.position.x - initial_x) > 50 and absf(player.position.y - deck.position.y) < 2, "Plataforma horizontal lleva al jugador")
 moving_entry = world.moving_platforms.filter(func(entry): return entry.data.axis.y != 0)[0]
 world.gameplay_clock = 0
 world.update_platforms()
 deck = moving_entry.data.rect
 await settle(Vector2(deck.get_center().x, deck.position.y))
 for i in range(45):
  world.gameplay_clock += 1.0 / 60.0
  world.update_platforms()
  await tick()
 var moving_top: float = moving_entry.body.position.y - deck.size.y / 2
 check(absf(player.position.y - moving_top) < 3 and player.is_on_floor(), "Plataforma vertical conserva apoyo: jugador=%s cubierta=%.2f suelo=%s" % [player.position, moving_top, player.is_on_floor()])
 gm.level = 10
 gm.reset_physical()
 world.rebuild()
 var guardian = world.enemies[-1]
 check(world.guardian_alive(), "Guardián bloquea salida")
 for i in range(3):
  guardian.stunned = 0
  guardian.stomp()
 check(guardian.dead and not world.guardian_alive(), "Guardián requiere tres impactos")
 player.position = Vector2(80, 520)
 check(not world.at_goal(), "No saltar el recorrido desde botón")
 await settle(Vector2(world.map_width - 96, 520))
 check(world.at_goal(), "Meta física al final del recorrido")
 player.position.x = 1500
 world._process(0.5)
 check(world.camera_x > 0 and world.camera_x <= world.map_width - 960, "Cámara sigue al jugador dentro de límites")
 main.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA: 28 mapas, rutas, saltos, enemigos, cofres, trampas, cámara y persistencia; fallos = ", failures)
 quit(failures)
