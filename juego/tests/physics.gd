extends SceneTree
const Player = preload("res://scripts/player_controller.gd")
var player: CharacterBody2D
var arena: Node2D
var failures: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func surface(rect: Rect2, one_way: bool = false) -> void:
 var body = StaticBody2D.new()
 var shape = RectangleShape2D.new()
 shape.size = rect.size
 var collider = CollisionShape2D.new()
 collider.shape = shape
 collider.one_way_collision = one_way
 body.position = rect.get_center()
 body.add_child(collider)
 arena.add_child(body)

func tick(axis: float = 0, jump: bool = false, release: bool = false) -> void:
 await physics_frame
 player.simulate(1.0 / 60.0, axis, jump, release)

func settle(point: Vector2) -> void:
 player.travel(point)
 for i in range(8):
  await tick()

func run() -> void:
 arena = Node2D.new()
 root.add_child(arena)
 surface(Rect2(0, 520, 1600, 160))
 surface(Rect2(280, 456, 112, 16), true)
 surface(Rect2(424, 392, 128, 16), true)
 surface(Rect2(584, 328, 128, 16), true)
 surface(Rect2(780, 296, 160, 32))
 player = Player.new()
 arena.add_child(player)
 player.set_physics_process(false)
 await settle(Vector2(80, 520))
 check(player.is_on_floor() and absf(player.position.y - 520) < 1, "Pies exactos en suelo")
 check(InputMap.has_action("jump") and InputMap.action_get_events("jump").filter(func(event): return event is InputEventKey).size() == 3, "Tres teclas de salto")
 check(Player.fall_damage(64) == 0 and Player.fall_damage(224) == 0, "Saltos y caídas bajas seguros")
 check(Player.fall_damage(300) > Player.fall_damage(240), "Daño aumenta con altura")
 await settle(Vector2(330, 520))
 await tick(0, true)
 for i in range(60):
  await tick()
 check(absf(player.position.y - 456) < 1 and player.health == 100, "Plataforma unilateral sostiene al aterrizar")
 await settle(Vector2(850, 520))
 await tick(0, true)
 var high = player.position.y
 for i in range(60):
  await tick()
  high = minf(high, player.position.y)
 check(high > 400 and absf(player.position.y - 520) < 1, "No alcanzar techo triple desde suelo")
 await settle(Vector2(850, 374))
 player.velocity.y = -590
 high = player.position.y
 for i in range(30):
  await tick()
  high = minf(high, player.position.y)
 check(high >= 371, "Cara inferior del techo bloquea salto")
 await settle(Vector2(1100, 520))
 await tick(0, true)
 for i in range(5):
  await tick()
 var velocity = player.velocity.y
 await tick(0, true)
 check(player.velocity.y > velocity, "No existe segundo salto en aire")
 await tick(0, false, true)
 check(player.velocity.y >= -220, "Soltar acorta salto")
 await settle(Vector2(1100, 520))
 player.position = Vector2(1100, 200)
 player.previous_position = player.position
 player.airborne = true
 player.highest_feet = 200
 for i in range(65):
  await tick()
 check(player.health < 100 and player.health > 0, "Caída alta real causa daño")
 await settle(Vector2(80, 520))
 player.running = true
 for i in range(30):
  await tick(1)
 check(absf(player.velocity.x - Player.RUN_SPEED) < 1, "Carrera alcanza velocidad definida")
 for i in range(30):
  await tick()
 check(absf(player.velocity.x) < 1, "Frenado sin deslizamiento eterno")
 player.running = false
 player.take_damage(100, "Prueba")
 for i in range(70):
  await tick()
 check(player.health == 100 and player.position.distance_to(player.checkpoint) < 1, "Reaparición conserva refugio")
 arena.queue_free()
 await process_frame
 print("VERDARIA: colisiones, salto variable, techo, caída, carrera y retorno; fallos = ", failures)
 quit(failures)
