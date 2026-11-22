extends SceneTree
const Enemy = preload("res://scripts/platform_enemy.gd")
var failures: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_combat.json"
 gm.audio_enabled = false
 gm.new_game()
 gm.branch = "C"
 gm.level = 2
 gm.reset_physical()
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.show_game()
 var world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 world.player.set_physics_process(false)
 var turret = Enemy.new()
 turret.configure({"kind": "turret", "hp": 1, "point": Vector2(150, 520), "left": 100, "right": 200}, 99)
 world.add_child(turret)
 var shots: Array = []
 turret.shot.connect(func(origin, speed): shots.append({"origin": origin, "speed": speed}))
 for i in range(8):
  await physics_frame
  turret.simulate(1.0 / 60, Vector2(80, 520))
 var original: float = turret.position.x
 turret.attack_timer = 0
 turret.simulate(1.0 / 60, Vector2(80, 520))
 check(turret.attack_state == "charge" and shots.is_empty(), "Torreta prepara disparo antes de atacar")
 turret.simulate(0.3, Vector2(80, 520))
 check(turret.warning > 0 and shots.is_empty(), "Aviso de ataque visible")
 turret.simulate(0.4, Vector2(80, 520))
 check(shots.size() == 1 and shots[0].speed.x < 0 and absf(turret.position.x - original) < 0.01, "Torreta estacionaria dispara hacia el objetivo")
 turret.stomp()
 turret.simulate(5, Vector2(80, 520))
 check(shots.size() == 1 and turret.dead, "Torreta derrotada no dispara")
 # Swept hit catches a projectile crossing the whole body in one tick.
 world.player.position = Vector2(100, 520)
 world.player.invulnerability = 0
 world.projectiles = [{"position": Vector2(30, 500), "velocity": Vector2(210, 0), "time": 3.0}]
 world.update_projectiles(0.6)
 check(world.player.health == 85 and world.projectiles.is_empty(), "Barrido de proyectil evita atravesar al jugador")
 # Wall blocks the shot before it can reach the body.
 var wall = StaticBody2D.new()
 var collider = CollisionShape2D.new()
 var shape = RectangleShape2D.new()
 shape.size = Vector2(8, 80)
 collider.shape = shape
 wall.position = Vector2(65, 480)
 wall.add_child(collider)
 world.add_child(wall)
 await physics_frame
 world.player.health = 100
 world.player.invulnerability = 0
 world.projectiles = [{"position": Vector2(30, 500), "velocity": Vector2(210, 0), "time": 3.0}]
 world.update_projectiles(0.6)
 check(world.player.health == 100 and world.projectiles.is_empty(), "Pared detiene proyectil")
 # Pause freezes the simulation and respawn clears old threats.
 world.projectiles = [{"position": Vector2(300, 500), "velocity": Vector2(210, 0), "time": 3.0}]
 world.active = false
 world._physics_process(1)
 check(world.projectiles[0].position == Vector2(300, 500), "Pausa congela proyectiles")
 world.player.respawn()
 check(world.projectiles.is_empty(), "Retorno limpia proyectiles")
 world.active = true
 var guardian = Enemy.new()
 guardian.configure({"kind": "guardian", "hp": 3, "point": Vector2(200, 520), "left": 160, "right": 360}, 100)
 world.add_child(guardian)
 guardian.attack_timer = 0
 guardian.simulate(1.0 / 60, Vector2(300, 520))
 check(guardian.attack_state == "charge", "Guardián anuncia embestida")
 guardian.simulate(0.75, Vector2(300, 520))
 guardian.simulate(1.0 / 60, Vector2(300, 520))
 check(guardian.attack_state == "dash" and guardian.velocity.x > 100, "Guardián embiste tras aviso")
 guardian.stomp()
 check(guardian.hp == 2 and guardian.stunned > 0, "Salto interrumpe ataque del guardián")
 main.queue_free()
 await process_frame
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
  DirAccess.remove_absolute(gm.save_path + suffix)
 print("VERDARIA COMBATE: aviso, torreta, proyectiles, paredes, pausa, retorno y guardián; fallos = ", failures)
 quit(failures)
