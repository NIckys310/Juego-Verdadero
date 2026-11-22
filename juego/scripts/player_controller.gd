extends CharacterBody2D
signal condition_changed(health: int, message: String)
signal landed(drop: float, damage: int)
signal respawned
signal jumped
const BODY_SIZE = Vector2(22, 44)
const COYOTE_TIME = 0.10
const JUMP_BUFFER_TIME = 0.12
const MAX_FALL_SPEED = 1100.0
const GROUND_ACCELERATION = 2400.0
const GROUND_BRAKING = 5200.0
const AIR_ACCELERATION = 1300.0
const SPEED = 260.0
const RUN_SPEED = 340.0
const GRAVITY = 1600.0
const JUMP_SPEED = 590.0
const SAFE_FALL = 224.0
const MAX_HEALTH = 100
var health: int = MAX_HEALTH
var enabled: bool = true
var facing_left: bool = false
var checkpoint = Vector2(80, 520)
var coyote: float = 0.0
var jump_buffer: float = 0.0
var airborne: bool = false
var highest_feet: float = 520.0
var invulnerability: float = 0.0
var respawn_timer: float = 0.0
var status_timer: float = 0.0
var message: String = "Listo para explorar"
var previous_position = Vector2(80, 520)
var running: bool = false
var environment_push: float = 0.0
var wind_push: float = 0.0
var environment_lift: float = 0.0
var reset_platform_frames: int = 2
var jump_buffer_released: bool = false
var stride_distance: float = 0.0
var movement_state: String = "idle"
@onready var input_source = get_node("/root/PlayerInput")

func _ready() -> void:
 var collider = CollisionShape2D.new()
 var box = RectangleShape2D.new()
 box.size = BODY_SIZE
 collider.shape = box
 collider.position = Vector2(0, -22)
 add_child(collider)
 collision_mask = 1
 safe_margin = 0.04
 floor_snap_length = 6.0
 floor_stop_on_slope = true
 position = checkpoint

static func fall_damage(drop: float) -> int:
 # El salto normal (~109 px) y los escalones (64 px) nunca dañan.
 return clampi(int((drop - SAFE_FALL) * 0.45), 0, 100)

func _physics_process(delta: float) -> void:
 if not enabled:
  input_source.discard_edges()
  return
 var horizontal: float = Input.get_axis("move_left", "move_right")
 var edges: Vector2i = input_source.consume_jump()
 running = Input.is_action_pressed("run")
 simulate(delta, horizontal, edges.x == 1, edges.y == 1)

func simulate(delta: float, horizontal: float, jump_pressed: bool = false, jump_released: bool = false) -> void:
 horizontal = clampf(horizontal, -1.0, 1.0)
 previous_position = position
 # Al volver a un refugio no se hereda el movimiento de la cubierta anterior.
 platform_floor_layers = 0 if reset_platform_frames > 0 else 1
 reset_platform_frames = maxi(0, reset_platform_frames - 1)
 invulnerability = maxf(0, invulnerability - delta)
 status_timer = maxf(0, status_timer - delta)
 if health <= 0:
  respawn_timer -= delta
  velocity = Vector2.ZERO
  if respawn_timer <= 0:
   respawn()
  return
 var was_grounded = is_on_floor()
 if was_grounded and velocity.y >= 0:
  coyote = COYOTE_TIME
 else:
  coyote = maxf(0, coyote - delta)
 jump_buffer = JUMP_BUFFER_TIME if jump_pressed else maxf(0, jump_buffer - delta)
 if jump_pressed:
  jump_buffer_released = false
 if jump_released and jump_buffer > 0:
  jump_buffer_released = true
 var acceleration: float = GROUND_ACCELERATION if was_grounded else AIR_ACCELERATION
 var target_speed: float = horizontal * (RUN_SPEED if running else SPEED)
 target_speed += environment_push if was_grounded else wind_push
 if was_grounded and horizontal != 0 and velocity.x * horizontal < 0:
  # Girar cambia la intención inmediatamente, sin caminar de espaldas por inercia.
  velocity.x = environment_push
 if was_grounded and is_zero_approx(horizontal):
  acceleration = GROUND_BRAKING
 velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
 if horizontal != 0:
  facing_left = horizontal < 0
 if not was_grounded:
  velocity.y = clampf(velocity.y + (GRAVITY + environment_lift) * delta, -430, 1100.0) if environment_lift < 0 else minf(velocity.y + GRAVITY * delta, 1100.0)
 if jump_buffer > 0 and coyote > 0:
  velocity.y = -JUMP_SPEED
  coyote = 0
  jump_buffer = 0
  airborne = true
  highest_feet = position.y
  jumped.emit()
  if jump_buffer_released:
   velocity.y = -220
 if jump_released and velocity.y < -220:
  velocity.y = -220 # Soltar antes produce un salto corto.
 if not was_grounded and not airborne:
  airborne = true
  highest_feet = position.y
 if airborne:
  highest_feet = minf(highest_feet, position.y)
 move_and_slide()
 var travelled: float = absf(position.x - previous_position.x)
 if is_on_floor() and absf(horizontal) > 0.05 and travelled < 32:
  stride_distance += travelled
 movement_state = "dead" if health <= 0 else "rise" if not is_on_floor() and velocity.y < 0 else "fall" if not is_on_floor() else "run" if travelled > 0.1 and running else "walk" if travelled > 0.1 else "idle"
 if airborne:
  highest_feet = minf(highest_feet, position.y)
 if is_on_floor() and airborne:
  var drop: float = maxf(0, position.y - highest_feet)
  var damage: int = fall_damage(drop)
  airborne = false
  if damage > 0:
   take_damage(damage, "Caída de %d px · −%d vida" % [drop, damage])
  landed.emit(drop, damage)
 if position.y > 680:
  invulnerability = 0
  take_damage(100, "Caída fuera del terreno")

func take_damage(amount: int, reason: String) -> void:
 if invulnerability > 0 or health <= 0:
  return
 health = maxi(0, health - amount)
 invulnerability = 0.9
 message = reason
 status_timer = 3.0
 if health == 0:
  message = "Sin fuerzas · Volviendo al último refugio…"
  respawn_timer = 1.0
 condition_changed.emit(health, message)

func heal() -> void:
 health = MAX_HEALTH
 message = "Descanso en refugio · Vida recuperada"
 status_timer = 3.0
 condition_changed.emit(health, message)

func set_checkpoint(point: Vector2) -> void:
 checkpoint = point
 message = "Refugio activado · Punto de retorno guardado para este nivel"
 status_timer = 3.0
 condition_changed.emit(health, message)

func respawn() -> void:
 position = checkpoint
 reset_physics_interpolation()
 previous_position = position
 velocity = Vector2.ZERO
 health = MAX_HEALTH
 airborne = false
 highest_feet = position.y
 coyote = 0
 jump_buffer = 0
 jump_buffer_released = false
 stride_distance = 0
 movement_state = "idle"
 input_source.discard_edges()
 reset_platform_frames = 2
 running = false
 environment_push = 0
 wind_push = 0
 environment_lift = 0
 invulnerability = 0.6
 respawned.emit()
 message = "De vuelta en el refugio · Tus decisiones y tareas se conservan"
 status_timer = 3.0
 condition_changed.emit(health, message)

func travel(point: Vector2) -> void:
 checkpoint = point
 respawn()
