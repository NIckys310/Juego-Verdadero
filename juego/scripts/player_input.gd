extends Node
## Las mismas acciones sirven para teclado y mando, incluidos menús y pausa.
const KEYS = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "run": [KEY_SHIFT], "interact": [KEY_E], "restore_safe": [KEY_Q], "restore_high": [KEY_R], "pause_game": [KEY_ESCAPE]}
## Lo activa main.gd en móviles/tabletas para adaptar los textos de ayuda.
var touch_mode: bool = false
var jump_pressed: bool = false
var jump_released: bool = false

func _ready() -> void:
 configure()

func configure() -> void:
 for action in KEYS:
  if not InputMap.has_action(action):
   InputMap.add_action(action, 0.24)
  InputMap.action_erase_events(action)
  InputMap.action_set_deadzone(action, 0.24)
  for key in KEYS[action]:
   var event = InputEventKey.new()
   event.device = -1
   event.physical_keycode = key
   InputMap.action_add_event(action, event)
 for entry in [["move_left", JOY_BUTTON_DPAD_LEFT], ["move_right", JOY_BUTTON_DPAD_RIGHT], ["jump", JOY_BUTTON_A], ["interact", JOY_BUTTON_X], ["restore_safe", JOY_BUTTON_Y], ["restore_high", JOY_BUTTON_LEFT_SHOULDER], ["run", JOY_BUTTON_RIGHT_SHOULDER], ["pause_game", JOY_BUTTON_START]]:
  var event = InputEventJoypadButton.new()
  event.device = -1
  event.button_index = entry[1]
  InputMap.action_add_event(entry[0], event)
 for entry in [["move_left", -1.0], ["move_right", 1.0]]:
  var event = InputEventJoypadMotion.new()
  event.device = -1
  event.axis = JOY_AXIS_LEFT_X
  event.axis_value = entry[1]
  InputMap.action_add_event(entry[0], event)

func _input(event: InputEvent) -> void:
 if event.is_echo():
  return
 if event.is_action_pressed("jump"):
  jump_pressed = true
 if event.is_action_released("jump"):
  jump_released = true

func consume_jump() -> Vector2i:
 var edges = Vector2i(int(jump_pressed or Input.is_action_just_pressed("jump")), int(jump_released or Input.is_action_just_released("jump")))
 discard_edges()
 return edges

func discard_edges() -> void:
 jump_pressed = false
 jump_released = false

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  discard_edges()
  for action in KEYS:
   Input.action_release(action)

