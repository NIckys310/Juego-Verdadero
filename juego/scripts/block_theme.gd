extends RefCounted
## Verdaria: aventura de 16 colores, esmalte azul y remaches de cobre.
const INK = Color("11162f")
const CREAM = Color("fff1d2")
const GOLD = Color("ffce63")
const GREEN = Color("83e19a")

static func slab(base: Color, grain: bool = false, highlighted: bool = false) -> StyleBoxTexture:
 var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
 for y in range(24):
  for x in range(24):
   var color = base
   if grain:
    color = base.lightened(0.045) if y % 6 == 0 else base
   if x < 2 or y < 2 or x >= 22 or y >= 22:
    color = GOLD if highlighted else INK
   elif x < 4 or y < 4:
    color = Color("fff1bf") if highlighted else Color("758fba")
   elif x >= 20 or y >= 20:
    color = base.darkened(0.5)
   elif x < 6 or y < 6 or x >= 18 or y >= 18:
    color = Color("b78145") if highlighted else Color("344c78")
   # Remaches dentro de las esquinas: el centro de nueve partes se estira.
   if grain and x in [4, 19] and y in [4, 19]:
    color = GOLD.darkened(0.15)
   image.set_pixel(x, y, color)
 var style = StyleBoxTexture.new()
 style.texture = ImageTexture.create_from_image(image)
 for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
  style.set_texture_margin(side, 6)
  style.set_content_margin(side, 12)
 return style

static func make_theme() -> Theme:
 var result = Theme.new()
 var font = SystemFont.new()
 font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
 font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
 # Navegadores y móviles no exponen fuentes del sistema: se incluye Cascadia Mono (OFL).
 if OS.has_feature("web") or OS.has_feature("mobile"):
  var bundled = load("res://fonts/CascadiaMono.ttf")
  if bundled is FontFile:
   bundled.antialiasing = TextServer.FONT_ANTIALIASING_NONE
   font = bundled
 result.default_font = font
 result.default_font_size = 17
 result.set_color("font_color", "Label", CREAM)
 result.set_color("font_shadow_color", "Label", Color("101310"))
 result.set_constant("shadow_offset_x", "Label", 2)
 result.set_constant("shadow_offset_y", "Label", 2)
 for type in ["Button", "CheckButton"]:
  result.set_stylebox("normal", type, slab(Color("345589"), true))
  result.set_stylebox("hover", type, slab(Color("456f9e"), true, true))
  result.set_stylebox("pressed", type, slab(Color("254866"), true, true))
  result.set_stylebox("disabled", type, slab(Color("252f49")))
  result.set_stylebox("focus", type, slab(Color(0, 0, 0, 0), false, true))
  result.set_color("font_color", type, CREAM)
  result.set_color("font_hover_color", type, Color.WHITE)
  result.set_color("font_pressed_color", type, GOLD)
  result.set_color("font_disabled_color", type, Color("8895b0"))
 result.set_stylebox("panel", "PanelContainer", slab(Color("202c4d"), true))
 result.set_stylebox("background", "ProgressBar", slab(Color("172039")))
 result.set_stylebox("fill", "ProgressBar", slab(GREEN))
 result.set_color("font_color", "ProgressBar", CREAM)
 result.set_stylebox("scroll", "VScrollBar", slab(Color("22281f")))
 result.set_stylebox("grabber", "VScrollBar", slab(Color("676f57")))
 result.set_stylebox("grabber_highlight", "VScrollBar", slab(Color("82926b")))
 result.set_stylebox("grabber_pressed", "VScrollBar", slab(Color("9ba97e")))
 return result

static func panel(parent: Node, position: Vector2, size: Vector2, wood: bool = false) -> PanelContainer:
 var node = PanelContainer.new()
 node.position = position
 node.size = size
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.add_theme_stylebox_override("panel", slab(Color("283451") if wood else Color("19243f"), true, wood))
 parent.add_child(node)
 return node
