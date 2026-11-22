extends Node2D
## Fondo en parallax y terreno de bloques; sólo dibuja el tramo visible.
var background: Texture2D
var background_far: Texture2D
var background_near: Texture2D
var surfaces: Array = []
var branch: String = ""
var level: int = 1
var states: Dictionary = {}
var map_data: Dictionary = {}
var reduced_motion: bool = false
var scroll: float = 0
var clock: float = 0
var block_bumps: Dictionary = {}
static var tiles: Dictionary = {}
const PALETTES = {
 "A": [["789dc0", "568991", "346b61"], ["74b8d1", "62a29a", "387b62"], ["649cc5", "507b96", "2c637d"], ["93bcd0", "5f9a93", "3d7770"], ["d7bd88", "9bad83", "548064"], ["456e89", "38635e", "245246"], ["9baac9", "6d8998", "426c70"], ["88b5d0", "739aab", "477788"], ["94c8ce", "7bad8e", "4b8d6d"], ["d7aa94", "ad9d93", "6c9482"]],
 "B": [["789dc0", "568991", "346b61"], ["a68880", "806a76", "4b526c"], ["462d4d", "704a58", "3a3148"], ["7993aa", "576780", "39465b"], ["637cac", "52698f", "344e72"], ["c1ab91", "9f8c83", "5e6875"], ["304769", "315771", "203e57"], ["484d7a", "535276", "303455"], ["7f9bb5", "617e9a", "3e577d"], ["343253", "574862", "2e344c"]],
 "C": [["789dc0", "568991", "346b61"], ["8d9eae", "657e87", "445d69"], ["4d5968", "475363", "2d394a"], ["8ea9c6", "7185a5", "456581"], ["b2a58b", "8f8c77", "596b63"], ["89929c", "6e7787", "455765"], ["343b58", "444b67", "29364e"], ["b08b8b", "8b6e80", "525770"], ["5a718f", "526583", "344a64"], ["51466b", "625278", "343851"]]
}

func _ready() -> void:
 var grading = ShaderMaterial.new()
 grading.shader = preload("res://shaders/landscape_grade.gdshader")
 material = grading
 for type in ["dirt", "brick", "wood", "metal", "glass", "bonus", "rubble", "garden", "powered", "barricade"]:
  tile(type)

func update_palette() -> void:
 if material is ShaderMaterial:
  var restored: float = GameManager.flags().get("restored", {}).size()
  material.set_shader_parameter("tint", {"A": Color("baffca"), "B": Color("9cdaff"), "C": Color("ffe0ad")}.get(branch, Color("efffdb")))
  material.set_shader_parameter("warmth", minf(0.06 + restored * 0.05, 0.24))
  material.set_shader_parameter("saturation", 1.12)
  material.set_shader_parameter("contrast", 1.02)
 queue_redraw()

static func tile(type: String) -> Texture2D:
 if tiles.has(type):
  return tiles[type]
 var base: Color = {"dirt": Color("89564b"), "brick": Color("625a78"), "wood": Color("ac794d"), "metal": Color("587993"), "glass": Color("6bb5ba"), "bonus": Color("e9ae4f"), "rubble": Color("716c80"), "garden": Color("568557"), "powered": Color("458ea8"), "barricade": Color("ac7952")}.get(type, Color("89564b"))
 var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
 for y in range(32):
  for x in range(32):
   var color = base
   var joint: bool = y % 16 < 2 or (x + (16 if y >= 16 else 0)) % 32 < 2
   if type in ["brick", "dirt", "rubble"]:
    if joint:
     color = base.darkened(0.35)
    elif y % 16 < 4:
     color = base.lightened(0.15)
    elif (x * 13 + y * 7) % 31 < 2:
     color = base.lightened(0.1)
   else:
    if x < 2 or y < 2:
     color = base.lightened(0.35)
    elif x >= 29 or y >= 29:
     color = base.darkened(0.4)
    elif type == "wood" and y % 8 < 2:
     color = base.darkened(0.22)
    elif type == "glass" and (x + y) % 24 < 3:
     color = base.lightened(0.4)
    elif type == "metal" and x in [5, 26] and y in [5, 26]:
     color = Color("ead3a1")
   img.set_pixel(x, y, color)
 var tex = ImageTexture.create_from_image(img)
 tiles[type] = tex
 return tex

func block(rect: Rect2, color: String) -> void:
 draw_rect(rect, Color(color))

func landscape_layer(tex: Texture2D, speed: float) -> void:
 var bx = 0.0 if reduced_motion else -fposmod(floor(scroll * speed / 2) * 2, 960)
 for shift in [0, 960]:
  draw_texture_rect(tex, Rect2(bx + shift, 0, 960, 540), false)

func _draw() -> void:
 if map_data.is_empty():
  return
 var colors: Array = PALETTES.get(branch, PALETTES.A)[level - 1]
 var indoor: bool = map_data.biome in ["foundry", "laboratory", "reactor", "bunker", "arsenal", "energy"]
 for band in range(12):
  draw_rect(Rect2(0, band * 48, 960, 48), Color(colors[0]).lerp(Color(colors[1]), band / 15.0))
 # Paisajes pixel art (480x270, repetibles en x) a escala 2x exacta y con parallax en dos capas.
 if background_far and background_near:
  landscape_layer(background_far, 0.05)
  landscape_layer(background_near, 0.16)
 elif background:
  landscape_layer(background, 0.12)
 # Sin paisaje, se dibuja el fondo procedural de respaldo.
 if background or (background_far and background_near):
  pass
 elif indoor:
  for x in range(-64, 1000, 64):
   for y in range(100, 520, 64):
    var px = x - fmod(scroll * 0.28, 64)
    draw_rect(Rect2(px, y, 62, 62), Color(colors[2]).lightened(0.05 if (x / 64 + y / 64) % 2 == 0 else 0.0))
  for x in range(-128, 1000, 192):
   var px = x - fmod(scroll * 0.35, 192)
   block(Rect2(px, 140, 12, 380), "587184")
   block(Rect2(px + 2, 142, 3, 376), "7797aa")
   block(Rect2(px + 30, 210, 80, 112), "162b45")
   block(Rect2(px + 34, 214, 72, 104), "375976")
 else:
  for layer in range(2):
   var offset = scroll * (0.18 + layer * 0.12)
   for x in range(-32, 992, 16):
    var wx = x + offset
    var ridge = 360 + layer * 48 + floor(sin(wx * 0.008 + level) * 36 + sin(wx * 0.023) * 16)
    draw_rect(Rect2(x, ridge, 16, 560 - ridge), Color(colors[1 if layer == 0 else 2]))
  for i in range(6):
   var x = fposmod(i * 231.0 - scroll * 0.08 + clock * 2, 1150) - 100
   var y = 145 + (i % 3) * 43
   draw_rect(Rect2(x, y, 76, 16), Color("e5ece0"))
   draw_rect(Rect2(x + 14, y - 10, 42, 16), Color("f4efd4"))
 for decor in map_data.decor:
  var p: Vector2 = decor.point - Vector2(scroll, 0)
  if p.x < -240 or p.x > 1200:
   continue
  if decor.kind == "tree":
   block(Rect2(p.x - 7, p.y - 146, 14, 146), "433e36")
   block(Rect2(p.x - 3, p.y - 146, 4, 146), "746653")
   for side in [-1, 1]:
    draw_line(p - Vector2(0, 65), p + Vector2(side * 35, -120), Color("514d3d"), 6)
   for cluster in [Vector2(-38, -144), Vector2(34, -151), Vector2(0, -180), Vector2(-12, -132), Vector2(23, -122)]:
    var center: Vector2 = p + cluster
    var crown = PackedVector2Array([center + Vector2(-34, -8), center + Vector2(-22, -28), center + Vector2(8, -32), center + Vector2(30, -16), center + Vector2(36, 10), center + Vector2(16, 26), center + Vector2(-20, 22), center + Vector2(-36, 8)])
    draw_colored_polygon(crown, Color("273e36"))
    for row in range(-2, 3):
     for col in range(-3, 4):
      var leaf: Vector2 = center + Vector2(col * 8, row * 8)
      if Vector2(col, row).length() > 3 or (col * 7 + row * 13) % 5 == 0:
       continue
      block(Rect2(leaf, Vector2(8, 6)), ["3c5841", "506b49", "6b8055"][posmod(col * 13 + row * 7, 3)])
  elif decor.kind in ["house", "camp"]:
   var w = 200 if decor.kind == "house" else 112
   block(Rect2(p.x - w / 2, p.y - 88, w, 88), "b88b69")
   block(Rect2(p.x - w / 2 - 8, p.y - 100, w + 16, 16), "405a76")
   block(Rect2(p.x - w / 2 + 12, p.y - 112, w - 24, 16), "50799a")
   block(Rect2(p.x - 16, p.y - 58, 32, 58), "293a50")
   for side in [-1, 1]:
    block(Rect2(p.x + side * 54 - 12, p.y - 60, 24, 28), "ffdb87")
    block(Rect2(p.x + side * 54 - 1, p.y - 60, 2, 28), "8b6c51")
  elif decor.kind in ["tower", "windmill"]:
   block(Rect2(p.x - 30, p.y - 264, 60, 264), "6a7083")
   for y in range(int(p.y) - 244, int(p.y) - 20, 48):
    block(Rect2(p.x - 8, y, 16, 24), "2c3b56")
   block(Rect2(p.x - 40, p.y - 274, 80, 16), "b6c3bb")
   if decor.kind == "windmill":
    for arm in range(4):
     var tip = p + Vector2(cos(clock * 0.6 + arm * PI / 2), sin(clock * 0.6 + arm * PI / 2)) * 75 - Vector2(0, 230)
     draw_line(p - Vector2(0, 230), tip, Color("e0c8a0"), 8)
  elif decor.kind == "conveyor":
   block(Rect2(p.x, p.y - 5, decor.width, 10), "293a54")
   for x in range(0, decor.width, 24):
    var offset = fposmod(clock * decor.speed, 24)
    block(Rect2(p.x + x + offset, p.y - 4, 10, 4), "d8ba6e")
  elif decor.kind == "beacon":
   block(Rect2(p.x - 3, p.y - 48, 6, 48), "dde8d7")
   block(Rect2(p.x + 3, p.y - 48, 24, 16), "e27e89")
 for item in surfaces:
  var rect: Rect2 = item.rect
  rect.position.x -= scroll
  if item.style == "bonus":
   var bump: float = block_bumps.get(item.id, 0.0)
   rect.position.y -= sin(bump / 0.28 * PI) * 7
  if rect.end.x < 0 or rect.position.x > 960:
   continue
  var style: String = item.style
  var visible = rect.intersection(Rect2(0, 0, 960, 560))
  if not visible.has_area():
   continue
  var tex = tile("dirt" if style == "grass" else style)
  # Filas enteras conservan el tamaño real de cada baldosa.
  for y in range(int(rect.position.y), mini(int(rect.end.y), 560), 32):
   for x in range(maxi(int(rect.position.x), int(floor(-scroll / 32) * 32)), mini(int(rect.end.x), 992), 32):
    var tile_rect = Rect2(x, y, minf(32, rect.end.x - x), minf(32, rect.end.y - y))
    draw_texture_rect_region(tex, tile_rect, Rect2(Vector2.ZERO, tile_rect.size))
  if style in ["grass", "garden"]:
   block(Rect2(rect.position.x, rect.position.y, rect.size.x, 6), "9cce68")
   block(Rect2(rect.position.x, rect.position.y + 6, rect.size.x, 4), "41785b")
  elif style != "bonus":
   draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d2d8b4"), 2)
  if style == "bonus":
   var used = GameManager.flags().get("bonus", {}).get(item.id, false)
   draw_rect(rect.grow(-4), Color("7a6470") if used else Color("f6c465"))
   var glyph = Color("aa96a1") if used else Color("355e55")
   draw_rect(Rect2(rect.position + Vector2(15, 12), Vector2(3, 12)), glyph)
   draw_rect(Rect2(rect.position + Vector2(8, 10), Vector2(8, 5)), glyph)
   draw_rect(Rect2(rect.position + Vector2(18, 15), Vector2(7, 5)), glyph)
   draw_rect(Rect2(rect.position + Vector2(9, 9), Vector2(5, 2)), Color("d7ed9b") if not used else glyph)
  elif style == "garden":
   for x in range(int(rect.position.x) + 12, int(rect.end.x), 32):
    draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y - 12), Color("91e892"), 3)
    block(Rect2(x - 5, rect.position.y - 12, 5, 4), "dceea2")
  elif style == "powered":
   draw_line(rect.position + Vector2(0, 4), Vector2(rect.end.x, rect.position.y + 4), Color("a3f6f1"), 3)
  elif style == "barricade":
   for x in range(int(rect.position.x) + 8, int(rect.end.x), 32):
    block(Rect2(x, rect.position.y + 4, 3, 10), "ffe3a2")
 if states.get("medic", {}).get("status", "") == "rescatada" and level in [3, 6]:
  var p: Vector2 = map_data.checkpoints[-1] - Vector2(scroll, 0)
  block(Rect2(p.x + 45, p.y - 32, 48, 32), "578d9b")
  block(Rect2(p.x + 67, p.y - 26, 4, 20), "fff1d2")
  block(Rect2(p.x + 59, p.y - 18, 20, 4), "fff1d2")
