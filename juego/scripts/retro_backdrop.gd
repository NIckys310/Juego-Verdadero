extends Node2D
## Diorama original de menú. Coordenadas enteras y paleta de consola clásica.
var catalog = preload("res://scripts/asset_catalog.gd").new()
var elapsed: float = 0.0
var tick: float = 0.0

func _ready() -> void:
 scale = Vector2(2, 2)
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
 elapsed += delta
 tick += delta
 if tick >= 0.1:
  tick = 0.0
  queue_redraw()

func block(x: float, y: float, w: float, h: float, color: String) -> void:
 draw_rect(Rect2(floor(x), floor(y), w, h), Color(color))

func cloud(x: float, y: float) -> void:
 block(x, y + 8, 64, 12, "adcfe3")
 block(x + 8, y + 3, 47, 12, "fff1d2")
 block(x + 20, y, 22, 8, "fff1d2")

func tree(x: float, y: float, tall: float) -> void:
 block(x - 4, y - tall, 8, tall, "5c3940")
 block(x, y - tall, 3, tall, "a86444")
 for layer in range(3):
  var width = 30 + layer * 12
  block(x - width / 2, y - tall - 12 + layer * 13, width, 18, "245e5a")
  block(x - width / 2 + 3, y - tall - 12 + layer * 13, width - 8, 5, "4fa875")

func _draw() -> void:
 for band in range(16):
  draw_rect(Rect2(0, band * 25, 640, 25), Color("263960").lerp(Color("98cfbc"), band / 18.0))
 block(533, 45, 30, 30, "e9ae59")
 block(536, 42, 24, 30, "ffeab0")
 for i in range(18):
  var x = (i * 97 + 21) % 630
  var y = (i * 37 + 18) % 119
  if i % 3 == 0:
   block(x - 2, y, 5, 1, "a6c9ce")
   block(x, y - 2, 1, 5, "a6c9ce")
  else:
   block(x, y, 2, 2, "a6c9ce")
 for i in range(5):
  cloud(fmod(i * 153.0 + floor(elapsed * 2), 780) - 70, 44 + (i % 3) * 13)
 for layer in range(2):
  for x in range(0, 640, 8):
   var ridge = 218 + layer * 52 + floor(sin(x * 0.017 + layer * 2) * 29 + sin(x * 0.043) * 13)
   block(x, ridge, 8, 400 - ridge, "41637a" if layer == 0 else "315964")
 for x in [30, 105, 552, 614]:
  tree(x, 346, 72 + x % 33)
 block(0, 348, 640, 52, "49394d")
 block(0, 348, 640, 7, "89c763")
 block(0, 355, 640, 5, "3d835f")
 for y in range(365, 400, 12):
  for x in range(0, 640, 20):
   block(x + (y % 2) * 7, y, 15, 2, "72505a")
 for x in [55, 140, 504, 582]:
  block(x, 340, 2, 8, "b1de75")
  block(x - 2, 337, 6, 3, "ffcd75")
 var ids = ["protagonista", "medic", "nerd", "boss"]
 var spots = [Vector2(40, 282), Vector2(100, 282), Vector2(516, 282), Vector2(574, 282)]
 for i in range(4):
  var pose = "main" if i == 0 else "idle0"
  var sprite = catalog.sprite(ids[i], pose)
  draw_rect(Rect2(spots[i] + Vector2(-2, 64), Vector2(42, 4)), Color("293747"))
  draw_texture_rect(sprite, Rect2(spots[i], Vector2(36, 66)), false)
