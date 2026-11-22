extends SceneTree
## Genera los iconos web/PWA (144, 180, 512 px) con el protagonista sobre un fondo de Verdaria.
## Uso: godot --headless --path . --script res://tools/make_icons.gd

func _initialize() -> void:
 var hero: Image = Image.load_from_file(ProjectSettings.globalize_path("res://personajes/protagonista/front.png"))
 hero.convert(Image.FORMAT_RGBA8)
 var used: Rect2i = hero.get_used_rect()
 hero = hero.get_region(used)
 for size in [144, 180, 512]:
  make(hero, size).save_png(ProjectSettings.globalize_path("res://web/icon_%d.png" % size))
 # Icono de la pestaña del navegador.
 make(hero, 64).save_png(ProjectSettings.globalize_path("res://web/favicon.png"))
 # Tamaños del icono de Windows (.ico) para el acceso directo de la app.
 var app_dir: String = ProjectSettings.globalize_path("res://").path_join("../app/icono")
 DirAccess.make_dir_recursive_absolute(app_dir)
 for size in [16, 32, 48, 256]:
  make(hero, size).save_png(app_dir.path_join("icon_%d.png" % size))
 print("VERDARIA: iconos generados")
 quit()

func make(hero: Image, size: int) -> Image:
 var icon = Image.create(size, size, false, Image.FORMAT_RGBA8)
 var top = Color("2a4a7a")
 var bottom = Color("0b1220")
 var px: int = maxi(1, size / 48)
 for y in range(size):
  var t: float = float(y) / size
  for x in range(size):
   var color = top.lerp(bottom, t)
   # Colinas verdes pixeladas al pie.
   var hill: float = size * 0.78 + sin(float(x) / size * TAU * 1.5) * size * 0.04
   if y > hill:
    color = Color("356857") if (y - int(hill)) > px * 2 else Color("83e19a")
   icon.set_pixel(x, y, color)
 # Marco dorado de bloque, como los paneles del juego.
 var border: int = px * 2
 for y in range(size):
  for x in range(size):
   var d: int = mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
   if d < border:
    icon.set_pixel(x, y, Color("11162f"))
   elif d < border + px:
    icon.set_pixel(x, y, Color("ffce63"))
 # Protagonista escalado sin suavizado, centrado sobre las colinas.
 var target_h: int = int(size * 0.66)
 var scale: float = float(target_h) / hero.get_height()
 var w: int = maxi(1, int(hero.get_width() * scale))
 var sprite: Image = hero.duplicate()
 sprite.resize(w, target_h, Image.INTERPOLATE_NEAREST)
 var origin = Vector2i((size - w) / 2, int(size * 0.86) - target_h)
 # Sombra.
 for x in range(int(w * 0.15), int(w * 0.85)):
  for y in range(px * 2):
   var p = origin + Vector2i(x, target_h - px + y)
   if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
    icon.set_pixel(p.x, p.y, icon.get_pixelv(p).darkened(0.35))
 icon.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), origin)
 return icon
