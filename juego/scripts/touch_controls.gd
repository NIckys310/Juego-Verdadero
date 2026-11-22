extends Control
## Controles táctiles multitáctiles para móvil y tableta.
## Pulsan las mismas acciones que el teclado y el mando (InputEventAction),
## así que el jugador, el mundo y los menús no necesitan saber de dónde vienen.
const Blocks = preload("res://scripts/block_theme.gd")
const PAD_RADIUS = 118.0
const PAD_DEADZONE = 22.0
const RUN_THRESHOLD = 0.72

var buttons: Array = [
 {"id": "jump", "action": "jump", "radius": 96.0, "glyph": "up", "caption": "SALTAR", "color": Color("3d8a5f")},
 {"id": "interact", "action": "interact", "radius": 70.0, "glyph": "E", "caption": "USAR", "color": Color("345589")},
 {"id": "restore", "action": "restore_safe", "radius": 58.0, "glyph": "Q", "caption": "RECONSTRUIR", "color": Color("6a4d8f")},
 {"id": "high", "action": "restore_high", "radius": 50.0, "glyph": "R", "caption": "RUTA", "color": Color("8a5a35")},
 {"id": "pause", "action": "pause_game", "radius": 38.0, "glyph": "pause", "caption": "", "color": Color("283451")},
]
var pad_center: Vector2
var pad_knob: Vector2 = Vector2.ZERO
var pad_touch: int = -1
var touches: Dictionary = {}
var held: Dictionary = {}
var enabled: Dictionary = {"interact": false, "restore": false}

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 resized.connect(layout)
 visibility_changed.connect(func():
  if not visible:
   release_all())
 layout()

func layout() -> void:
 var area: Vector2 = size
 var edge: float = 54.0
 pad_center = Vector2(edge + PAD_RADIUS + 10, area.y - edge - PAD_RADIUS)
 var jump_center = Vector2(area.x - edge - 96, area.y - edge - 96)
 place("jump", jump_center)
 place("interact", jump_center + Vector2(-190, 34))
 place("restore", jump_center + Vector2(-26, -186))
 place("high", jump_center + Vector2(-176, -128))
 place("pause", Vector2(area.x - edge - 14, edge + 14))
 queue_redraw()

func place(id: String, point: Vector2) -> void:
 for item in buttons:
  if item.id == id:
   item.center = point

func set_context(context: Dictionary) -> void:
 enabled.interact = context.get("enabled", false)
 var caption: String = String(context.get("button", "USAR")).get_slice("[", 0).strip_edges()
 caption = caption.get_slice(" ", 0).to_upper()
 for item in buttons:
  if item.id == "interact":
   item.caption = caption if enabled.interact and caption.length() <= 11 else "USAR"
 var pulse: Dictionary = context.get("pulse", {})
 enabled.restore = pulse.get("enabled", false)
 queue_redraw()

func _input(event: InputEvent) -> void:
 if not is_visible_in_tree():
  return
 if event is InputEventScreenTouch:
  if event.pressed:
   touch_began(event.index, event.position)
  else:
   touch_ended(event.index)
 elif event is InputEventScreenDrag:
  if event.index == pad_touch:
   update_pad(event.position)

func touch_began(index: int, point: Vector2) -> void:
 if point.distance_to(pad_center) <= PAD_RADIUS * 1.7 and point.x < size.x * 0.45:
  pad_touch = index
  update_pad(point)
  get_viewport().set_input_as_handled()
  return
 var best = null
 var best_distance: float = INF
 for item in buttons:
  var distance: float = point.distance_to(item.center)
  if distance <= item.radius * 1.3 and distance < best_distance:
   best = item
   best_distance = distance
 if best == null:
  return
 touches[index] = best.id
 set_action(best.action, true)
 Input.vibrate_handheld(12)
 get_viewport().set_input_as_handled()
 queue_redraw()

func touch_ended(index: int) -> void:
 if index == pad_touch:
  pad_touch = -1
  pad_knob = Vector2.ZERO
  for action in ["move_left", "move_right", "run"]:
   set_action(action, false)
  queue_redraw()
  return
 if touches.has(index):
  var id: String = touches[index]
  touches.erase(index)
  queue_redraw()
  # Un toque rápido debe vivir al menos un fotograma para que el juego lo registre.
  await get_tree().physics_frame
  await get_tree().process_frame
  if is_inside_tree() and not touches.values().has(id):
   set_action(action_of(id), false)

func update_pad(point: Vector2) -> void:
 var offset: Vector2 = point - pad_center
 pad_knob = offset.limit_length(PAD_RADIUS)
 var dx: float = pad_knob.x
 set_action("move_left", dx < -PAD_DEADZONE)
 set_action("move_right", dx > PAD_DEADZONE)
 set_action("run", absf(dx) > PAD_RADIUS * RUN_THRESHOLD)
 queue_redraw()

func action_of(id: String) -> String:
 for item in buttons:
  if item.id == id:
   return item.action
 return ""

func set_action(action: String, pressed: bool) -> void:
 if action.is_empty() or held.get(action, false) == pressed:
  return
 held[action] = pressed
 var event = InputEventAction.new()
 event.action = action
 event.pressed = pressed
 event.strength = 1.0 if pressed else 0.0
 Input.parse_input_event(event)

func release_all() -> void:
 for action in held.keys():
  set_action(action, false)
 touches.clear()
 pad_touch = -1
 pad_knob = Vector2.ZERO
 queue_redraw()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  release_all()

func is_pressed(id: String) -> bool:
 return touches.values().has(id)

func _draw() -> void:
 var font: Font = get_theme_default_font()
 draw_pad(font)
 for item in buttons:
  draw_button_item(item, font)

func draw_pad(font: Font) -> void:
 var active: bool = pad_touch >= 0
 draw_circle(pad_center + Vector2(0, 6), PAD_RADIUS, Color(0, 0, 0, 0.18))
 draw_circle(pad_center, PAD_RADIUS, Color(0.12, 0.17, 0.3, 0.55 if pad_touch >= 0 else 0.32))
 draw_arc(pad_center, PAD_RADIUS - 3, 0, TAU, 64, Blocks.INK, 6, true)
 draw_arc(pad_center, PAD_RADIUS - 9, 0, TAU, 64, Color(Blocks.GOLD, 0.85 if active else 0.45), 3, true)
 # Zona de carrera: el anillo exterior.
 draw_arc(pad_center, PAD_RADIUS * RUN_THRESHOLD, 0, TAU, 64, Color(1, 1, 1, 0.10), 2, true)
 for side in [-1, 1]:
  var lit: bool = active and sign(pad_knob.x) == side and absf(pad_knob.x) > PAD_DEADZONE
  var tip = pad_center + Vector2(side * (PAD_RADIUS - 26), 0)
  var tri = PackedVector2Array([tip, tip + Vector2(-side * 30, -26), tip + Vector2(-side * 30, 26)])
  draw_colored_polygon(tri, Blocks.GOLD if lit else Color(Blocks.CREAM, 0.8))
 var knob = pad_center + pad_knob
 draw_circle(knob + Vector2(0, 5), 46, Color(0, 0, 0, 0.3))
 draw_circle(knob, 46, Color("456f9e") if active else Color(0.27, 0.43, 0.62, 0.6))
 draw_arc(knob, 44, 0, TAU, 48, Blocks.INK, 5, true)
 draw_arc(knob, 38, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.35), 4, true)
 if active and absf(pad_knob.x) > PAD_RADIUS * RUN_THRESHOLD:
  draw_string(font, pad_center + Vector2(-60, -PAD_RADIUS - 16), "CORRER", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Blocks.GOLD)

func draw_button_item(item: Dictionary, font: Font) -> void:
 var center: Vector2 = item.center
 var radius: float = item.radius
 var pressed: bool = is_pressed(item.id)
 var available: bool = enabled.get(item.id, true)
 var base: Color = item.color
 if not available:
  base = Color("252f49")
 var alpha: float = 0.92 if available else 0.55
 var shift = Vector2(0, 4 if pressed else 0)
 draw_circle(center + Vector2(0, 7), radius, Color(0, 0, 0, 0.3))
 draw_circle(center + shift, radius, Color(base.darkened(0.25) if pressed else base, alpha))
 draw_arc(center + shift, radius - 2, 0, TAU, 64, Blocks.INK, 6, true)
 draw_arc(center + shift, radius - 8, 0, TAU, 64, Color(Blocks.GOLD if pressed else Color("758fba"), alpha), 3, true)
 if not pressed:
  draw_arc(center, radius - 15, PI * 1.12, PI * 1.88, 32, Color(1, 1, 1, 0.22), 5, true)
 var ink: Color = Blocks.GOLD if pressed else Color(Blocks.CREAM, 1.0 if available else 0.5)
 var c = center + shift
 match item.glyph:
  "up":
   draw_colored_polygon(PackedVector2Array([c + Vector2(0, -38), c + Vector2(-32, 10), c + Vector2(32, 10)]), ink)
   draw_rect(Rect2(c + Vector2(-11, 8), Vector2(22, 20)), ink)
  "pause":
   draw_rect(Rect2(c + Vector2(-13, -15), Vector2(9, 30)), ink)
   draw_rect(Rect2(c + Vector2(4, -15), Vector2(9, 30)), ink)
  _:
   var glyph_size: int = int(radius * 0.72)
   draw_string(font, c + Vector2(-radius, glyph_size * 0.36), item.glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, glyph_size, ink)
 if not item.caption.is_empty():
  var caption_size: int = 17
  var width: float = font.get_string_size(item.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x + 18
  var tag = Rect2(center + Vector2(-width / 2, radius + 4), Vector2(width, 26))
  draw_rect(tag, Color(0.07, 0.09, 0.18, 0.78))
  draw_rect(tag, Color(Blocks.INK, 0.9), false, 2)
  draw_string(font, tag.position + Vector2(9, 19), item.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(Blocks.CREAM, 1.0 if available else 0.55))
