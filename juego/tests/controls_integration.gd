extends SceneTree
const Rig = preload("res://scripts/camera_rig.gd")
const Animator = preload("res://scripts/character_animator.gd")
var failures: int = 0
var main: Control
var world: Node2D
var player: CharacterBody2D

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func key(code: Key, pressed: bool, device: int = 0, repeat: bool = false) -> void:
 var event = InputEventKey.new()
 event.device = device
 event.physical_keycode = code
 event.keycode = code
 event.pressed = pressed
 event.echo = repeat
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  await process_frame

func settle() -> void:
 player.travel(Vector2(80, 520))
 await frames(10)
 check(player.is_on_floor(), "Suelo antes de entrada real")

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_controls.json"
 gm.audio_enabled = false
 gm.new_game()
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main.show_game()
 world = main.world
 world.persist_physical = false
 player = world.player
 var jumps: Array = []
 player.jumped.connect(func(): jumps.append(player.position))
 # Full input path: physical device 0 -> Input -> autoload -> automatic physics.
 for code in [KEY_SPACE, KEY_W, KEY_UP]:
  await settle()
  var before: int = jumps.size()
  key(code, true)
  await frames(6)
  check(jumps.size() == before + 1 and player.position.y < 490, "Salto real con " + OS.get_keycode_string(code))
  key(code, false)
  await frames(50)
  check(player.is_on_floor() and jumps.size() == before + 1, "Una pulsación produce un salto")
 # The controller path uses the same physical event pipeline.
 await settle()
 root.get_node("PlayerInput").discard_edges()
 var joy = InputEventJoypadButton.new()
 joy.device = 2
 joy.button_index = JOY_BUTTON_A
 joy.pressed = true
 Input.parse_input_event(joy)
 Input.flush_buffered_events()
 await frames(5)
 check(player.position.y < 490, "Botón A de un segundo mando salta")
 joy = joy.duplicate()
 joy.pressed = false
 Input.parse_input_event(joy)
 Input.flush_buffered_events()
 await frames(50)
 # Landing buffer: press while still airborne, not after reaching the floor.
 await settle()
 player.position = Vector2(80, 506)
 player.previous_position = player.position
 player.velocity = Vector2(0, 240)
 player.airborne = true
 player.highest_feet = 480
 await frames(1)
 var landing_before: int = jumps.size()
 key(KEY_SPACE, true)
 await frames(7)
 check(jumps.size() == landing_before + 1 and player.velocity.y < 0, "Buffer acepta salto pulsado antes de aterrizar")
 key(KEY_SPACE, false)
 await frames(50)
 # A late press just after leaving a platform still produces a jump.
 player.travel(Vector2(500, 488))
 await frames(10)
 check(player.is_on_floor(), "Apoyo inicial para tolerancia de borde")
 player.position.x = 580
 player.previous_position = player.position
 await frames(2)
 var edge_before: int = jumps.size()
 key(KEY_W, true)
 await frames(2)
 check(jumps.size() == edge_before + 1 and player.velocity.y < 0, "Tolerancia de borde acepta pulsación después de perder suelo")
 key(KEY_W, false)
 await frames(60)
 # A short tap can begin and end between two physics ticks.
 await settle()
 var before: int = jumps.size()
 key(KEY_SPACE, true)
 key(KEY_SPACE, false)
 await frames(2)
 check(jumps.size() == before + 1 and player.position.y < 520, "Pulsación corta no se pierde entre ticks")
 await frames(45)
 # Repeat events cannot retrigger a held key after landing.
 key(KEY_W, true)
 await frames(55)
 before = jumps.size()
 for i in range(4):
  key(KEY_W, true, 0, true)
  await frames(2)
 check(jumps.size() == before, "Repetición del teclado no produce saltos automáticos")
 key(KEY_W, false)
 await settle()
 # Space must still jump after clicking a contextual HUD button.
 main.interact_button.emit_signal("pressed")
 key(KEY_SPACE, true)
 await frames(5)
 check(player.position.y < 490 and not is_instance_valid(main.modal), "HUD no secuestra Espacio")
 key(KEY_SPACE, false)
 await settle()
 # Reverse and release from real keyboard input, without calling simulate.
 key(KEY_D, true)
 await frames(20)
 check(player.velocity.x > 250, "Caminar alcanza velocidad")
 key(KEY_D, false)
 key(KEY_A, true)
 await frames(1)
 check(player.facing_left and player.velocity.x < 0, "Giro inmediato sin seguir avanzando a la derecha")
 key(KEY_A, false)
 var stop_x: float = player.position.x
 await frames(6)
 check(absf(player.velocity.x) < 1 and absf(player.position.x - stop_x) < 10, "Frenado en menos de diez píxeles")
 # Paused jumps must neither move the body nor queue on resume.
 await settle()
 main.pause_dialog()
 before = jumps.size()
 key(KEY_SPACE, true)
 key(KEY_SPACE, false)
 await frames(3)
 main.close_modal()
 await frames(3)
 check(jumps.size() == before and player.is_on_floor(), "Pausa no deja salto pendiente")
 # Facing alone cannot move the camera or progress along the map.
 var camera: float = 1000
 var feet_x: float = 1480
 for i in range(120):
  player.facing_left = i % 2 == 0
  camera = Rig.follow(camera, feet_x, 4000)
 check(camera == 1000, "Girar sin desplazamiento no mueve cámara")
 check(Rig.follow(camera, feet_x + 4, 4000) == camera, "Microajuste dentro de zona muerta no desplaza escenario")
 var tracked: float = Rig.follow(camera, 1700, 4000)
 check(tracked == 1140 and Rig.follow(tracked, 1700, 4000) == tracked, "Cámara sigue distancia real y no deriva en reposo")
 check(Rig.follow(2000, 5000, 4000) == 3040 and Rig.follow(0, -40, 4000) == 0, "Límites del mapa")
 await settle()
 var stride: float = player.stride_distance
 var resting: String = Animator.pose(player, true, false, {}, 0)
 player.facing_left = not player.facing_left
 await frames(4)
 check(player.stride_distance == stride and Animator.pose(player, true, false, {}, 10) == resting, "Orientación e inactividad no inventan pasos")
 main.controls_dialog()
 key(KEY_W, true)
 await frames(2)
 check("Saltar" in main.control_tester.text and not world.active, "Probador reconoce teclas sin mover el mundo")
 key(KEY_W, false)
 main.close_modal()
 # Configuration is idempotent and accepts ordinary keyboards and controllers.
 var input = root.get_node("PlayerInput")
 var count: int = InputMap.action_get_events("jump").size()
 input.configure()
 check(InputMap.action_get_events("jump").size() == count, "Reconfigurar no duplica eventos")
 for device in [0, 1, 16]:
  var event = InputEventKey.new()
  event.device = device
  event.physical_keycode = KEY_W
  event.pressed = true
  check(event.is_action_pressed("jump"), "Teclado aceptado en dispositivo " + str(device))
 main.queue_free()
 await process_frame
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
  DirAccess.remove_absolute(gm.save_path + suffix)
 print("VERDARIA CONTROLES: eventos de teclado, mando, taps, buffer, HUD, pausa, giro, frenado, cámara y animación; fallos = ", failures)
 quit(failures)
