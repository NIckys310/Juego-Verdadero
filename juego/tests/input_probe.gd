extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 for key in [KEY_SPACE, KEY_W, KEY_UP]:
  for device in [0, 16]:
   var event = InputEventKey.new()
   event.device = device
   event.physical_keycode = key
   event.pressed = true
   Input.parse_input_event(event)
   print("INPUT_PROBE key=", key, " device=", device, " mapped=", event.is_action_pressed("jump"), " pressed=", Input.is_action_pressed("jump"))
   event = event.duplicate()
   event.pressed = false
   Input.parse_input_event(event)
   await process_frame
 quit()
