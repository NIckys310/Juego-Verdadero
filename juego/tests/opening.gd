extends SceneTree
const Terrain = preload("res://scripts/terrain_layout.gd")
var failures: int = 0
var gm: Node
var world: Node2D
var player: CharacterBody2D

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func tick(axis: float = 0, jump: bool = false) -> void:
 await physics_frame
 player.simulate(1.0 / 60.0, axis, jump)
 world.update_work(1.0 / 60.0)

func walk(x: float, limit: int = 900) -> void:
 for i in range(limit):
  var axis = clampf((x - player.position.x) / 20, -1, 1)
  await tick(axis, player.is_on_wall() and player.is_on_floor())
  if absf(player.position.x - x) < 1 and absf(player.velocity.x) < 8 and player.is_on_floor():
   return

func jump_to(x: float) -> void:
 await tick(signf(x - player.position.x), true)
 await walk(x, 90)

func work(action: String, point: Vector2) -> void:
 await walk(point.x)
 world.begin_work(action, point)
 world.work_auto = true
 for i in range(100):
  await tick()

func run() -> void:
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_opening.json"
 for home in ["reparar", "vender", "fortificar"]:
  gm.new_game()
  gm.choose_home(home)
  gm.advance()
  world = load("res://scripts/world.gd").new()
  world.persist_physical = false
  root.add_child(world)
  gm.changed.connect(world.rebuild)
  world.set_physics_process(false)
  player = world.player
  player.set_physics_process(false)
  for i in range(6):
   await tick()
  check(not gm.resolve_decision("elena_rescue", "rescatar"), "No rescatar antes de abrir acceso")
  await work("rubble", Terrain.rubble_position(gm.branch) - Vector2(38, 0))
  check(gm.flags().get("rubble", false), "Escombros despejados mediante trabajo: " + gm.branch)
  check(not world.surfaces.any(func(s): return s.id == "rubble"), "Bloqueo retirado de colisiones")
  var gap = Terrain.gap_bounds(gm.branch)
  await work("bridge", Vector2(gap.x - 35, 520))
  check(gm.flags().get("bridge", false), "Puente reparado: " + gm.branch)
  check(world.surfaces.any(func(s): return s.id == "repaired_bridge"), "Puente con colisión real")
  var base: float = 320 + 3 * 640
  if gm.branch == "A":
   await walk(base + 96)
   await jump_to(base + 96)
   check(absf(player.position.y - 456) < 1, "Primer escalón de rescate A")
   await walk(base + 130)
   await jump_to(base + 205)
   check(absf(player.position.y - 392) < 1, "Segundo escalón de rescate A")
   await walk(base + 252)
   await jump_to(base + 365)
  else:
   await walk(base + 150)
   await jump_to(base + 150)
   check(absf(player.position.y - 456) < 1, "Primer escalón de rescate " + gm.branch)
   await walk(base + 180)
   await jump_to(base + 290)
  var rescue = Terrain.rescue_position(gm.branch)
  await walk(rescue.x)
  check(player.is_on_floor() and absf(player.position.y - rescue.y) < 1, "Ruta física hasta Elena: " + gm.branch)
  world.begin_rescue()
  world.work_auto = true
  for i in range(100):
   await tick()
  check(gm.characters.medic.status == "rescatada", "Rescate por contacto y trabajo: " + gm.branch)
  var checkpoint: Vector2 = world.map_data.checkpoints[1]
  gm.capture_physical(63, checkpoint)
  gm.mark_tutorial("move")
  gm.save_game()
  check(gm.load_game(), "Carga de mapa extenso")
  world.restore_physical()
  check(player.health == 63 and player.checkpoint == checkpoint, "Vida y refugio de mapa extenso persistentes")
  gm.changed.disconnect(world.rebuild)
  world.queue_free()
  await process_frame
 var allies = {"nerd": {"status": "aliado"}, "boss": {"status": "aliado"}}
 check(Terrain.build("A", 8, {}, allies).any(func(s): return s.id == "ivo_lift"), "Atajo de Ivo")
 check(Terrain.build("C", 8, {}, allies).any(func(s): return s.id == "marcos_bridge"), "Acceso de Marcos")
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA: recorridos A/B/C, rescate físico y guardado de mapas extensos; fallos = ", failures)
 quit(failures)
