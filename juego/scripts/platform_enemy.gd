extends CharacterBody2D
signal shot(origin: Vector2, speed: Vector2)
## Criaturas originales: patrulla, giro ante bordes y neutralización por salto.
var kind: String = "spore"
var id: int = 0
var hp: int = 1
var direction: float = -1
var left_limit: float = 0
var right_limit: float = 0
var origin_y: float = 520
var clock: float = 0
var stunned: float = 0
var dead: bool = false
var attack_state: String = "patrol"
var attack_timer: float = 1.2
var warning: float = 0.0
static var sprite_cache: Dictionary = {}
const PATTERNS = {
 "turret": ["................", ".....bbbbbb.....", "....bBBBBBBb....", "...bBBByyyyBb...", "...bBBBywwyBbbbb", "...bBBByyyyBBBBb", "....bBBBBBBbbbb.", ".....bbbbbb.....", "....bbbbbbbb....", "...bBBBBBBBBb...", "..bbbbbbbbbbbb..", "................"],
 "hopper": ["................", "....g......g....", ".....gggggg.....", "...ggGGGGGGgg...", "..gGGwwGGwwGGg..", "..gGGGGGGGGGGg..", "...ggGGGGGGgg...", "....gggggggg....", "...ggg....ggg...", "..ggg......ggg..", ".gggg......gggg.", "................"],
 "spore": ["................", ".....gggggg.....", "...ggGGGGggg....", "..gGGgGGgGGgg...", ".gGGGGGGGGGGgg..", ".ggggggggggggg..", "...iiiiiiii.....", "..iiwiwiiwiwi...", "..iiwiwiiwiwi...", "...iiiiiiii.....", "....iiiiii......", "..ggg....ggg...."],
 "crawler": ["................", "....bbbbbbb.....", "...bBBBBBBBb....", "..bBByyyyBBb....", "..bBBywyyBBb....", "..bBByyyyBBb....", ".bbbbbbbbbbbb...", ".bBBBBBBBBBBb...", ".bbbbbbbbbbbb...", "..ii.ii.ii.ii...", "..ii.ii.ii.ii...", "................"],
 "beetle": ["................", "...r......r.....", "....rrrrrr......", "..rrRRRRRRrr....", ".rRRrRRRRrRRr...", ".rRRRRRRRRRRr...", ".rrrRRRRRRrrr...", "...iwiiwi.......", "...iwiiwi.......", "...iiiiii.......", "..rr....rr......", "................"],
 "drone": ["..bbbb....bbbb..", "...bb......bb...", ".....bbbbbb.....", "...bbBBBBBBbb...", "..bBBByyyyBBBb..", "..bBBBwwwwBBBb..", "...bbBBBBBBbb...", ".....bbbbbb.....", "......b..b......", "................", "................", "................"],
 "guardian": [".....yyyyyy.....", "....yYYYYYYy....", "...bbbbbbbbbb...", "..bBBBBBBBBBBb..", "..bBBrrBBrrBBb..", "..bBBwwBBwwBBb..", ".bbBBBBBBBBBBbb.", ".bBbBBBBBBBBbBb.", ".bBbBBBBBBBBbBb.", "...bbbbbbbbbb...", "...bb......bb...", "..bbbb....bbbb.."]
}

func configure(data: Dictionary, index: int) -> void:
 kind = data.kind
 hp = data.hp
 id = index
 position = data.point
 origin_y = position.y
 left_limit = data.left
 right_limit = data.right

func dimensions() -> Vector2:
 return Vector2(48, 48) if kind == "guardian" else Vector2(32, 24)

func bounds() -> Rect2:
 var size = dimensions()
 return Rect2(position - Vector2(size.x / 2, size.y), size)

func _ready() -> void:
 collision_layer = 2
 collision_mask = 1
 var collider = CollisionShape2D.new()
 var shape = RectangleShape2D.new()
 var size = dimensions()
 shape.size = size - Vector2(8, 2)
 collider.shape = shape
 collider.position = Vector2(0, -size.y / 2)
 add_child(collider)
 floor_snap_length = 4

func simulate(delta: float, target: Vector2 = Vector2.INF) -> void:
 if dead:
  return
 clock += delta
 warning = 0
 stunned = maxf(0, stunned - delta)
 if stunned > 0:
  attack_state = "patrol"
  attack_timer = 1.0
  return
 if kind == "drone":
  position.x += direction * 74 * delta
  position.y = origin_y + sin(clock * 2.2) * 34
 else:
  velocity.y = minf(velocity.y + 1600 * delta, 900)
  velocity.x = direction * (88 if kind == "guardian" else 58)
  attack_timer -= delta
  if kind == "turret":
   velocity.x = 0
   if target.is_finite() and absf(target.x - position.x) < 520 and absf(target.y - position.y) < 160:
    if attack_state == "patrol":
     direction = -1 if target.x < position.x else 1
     if attack_timer <= 0:
      attack_state = "charge"
      attack_timer = 0.65
    elif attack_state == "charge":
     warning = 1.0 - maxf(0, attack_timer) / 0.65
     if attack_timer <= 0:
      shot.emit(position + Vector2(direction * 20, -18), Vector2(direction * 210, 0))
      attack_state = "patrol"
      attack_timer = 1.7
   else:
    attack_state = "patrol"
    attack_timer = maxf(attack_timer, 0.5)
  elif kind == "hopper" and is_on_floor():
   if attack_timer < 0.35:
    velocity.x = 0
    warning = 1.0 - maxf(attack_timer, 0) / 0.35
   if attack_timer <= 0:
    velocity.y = -360
    attack_timer = 1.5
  elif kind == "guardian" and target.is_finite() and absf(target.x - position.x) < 440:
   if attack_state == "patrol" and attack_timer <= 0:
    attack_state = "charge"
    attack_timer = 0.7
    direction = -1 if target.x < position.x else 1
   if attack_state == "charge":
    velocity.x = 0
    warning = 1.0 - maxf(attack_timer, 0) / 0.7
    if attack_timer <= 0:
     attack_state = "dash"
     attack_timer = 0.65
   elif attack_state == "dash":
    velocity.x = direction * 180
    if attack_timer <= 0:
     attack_state = "recover"
     attack_timer = 0.8
   elif attack_state == "recover":
    velocity.x = 0
    if attack_timer <= 0:
     attack_state = "patrol"
     attack_timer = 1.2
  if is_on_floor() and kind != "turret":
   var edge = Vector2(direction * (dimensions().x / 2 + 6), -6)
   var ray = PhysicsRayQueryParameters2D.create(to_global(edge), to_global(edge + Vector2(0, 18)), 1)
   if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
    direction *= -1
  move_and_slide()
  if is_on_wall():
   direction *= -1
 if kind != "turret" and position.x <= left_limit:
  direction = 1
 elif kind != "turret" and position.x >= right_limit:
  direction = -1
 if position.y > 680:
  dead = true

func stomp() -> bool:
 if dead or stunned > 0:
  return false
 hp -= 1
 stunned = 0.7
 dead = hp <= 0
 direction *= -1
 return true

static func sprite(type: String, frame: int = 0) -> Texture2D:
 var key = type + str(frame % 2)
 if sprite_cache.has(key):
  return sprite_cache[key]
 var colors = {"g": Color("214f46"), "G": Color("7edb6a"), "i": Color("263148"), "w": Color("fff3d2"), "b": Color("193254"), "B": Color("6ba0be"), "y": Color("96623d"), "Y": Color("ffc75a"), "r": Color("622f4e"), "R": Color("d76d75")}
 var image = Image.create(16, 12, false, Image.FORMAT_RGBA8)
 var pattern: Array = PATTERNS.get(type, PATTERNS.spore)
 for y in range(12):
  for x in range(16):
   var character: String = pattern[y][x]
   if character != ".":
    var shifted_x = x + (1 if frame % 2 == 1 and y >= 10 and x < 14 else 0)
    image.set_pixel(shifted_x, y, colors.get(character, Color.WHITE))
 var texture = ImageTexture.create_from_image(image)
 sprite_cache[key] = texture
 return texture
