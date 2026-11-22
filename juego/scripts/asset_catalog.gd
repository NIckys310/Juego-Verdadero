extends RefCounted
## Nombres de carpetas del usuario = identificadores estables del catálogo.
const CAST = {
 "medic": {"name": "Elena", "role": "Médica · Agua y comunidad"},
 "nerd": {"name": "Ivo", "role": "Técnico · Energía y recuperación"},
 "boss": {"name": "Marcos", "role": "Coordinador · Comercio y defensa"},
 "protagonista": {"name": "Restaurador", "role": "Jugador"}
}
static var textures: Dictionary = {}
static var sprites: Dictionary = {}
const CHARACTER_SIZE = Vector2(32, 48)

func sprite(id: String, pose: String = "idle0") -> Texture2D:
 var key = id + "/" + pose
 if not sprites.has(key):
  var original = character(id, pose)
  if not original:
   return null
  var pixels = original.get_image()
  if pixels.is_compressed():
   pixels.decompress()
  var region = pixels.get_used_rect()
  var atlas = AtlasTexture.new()
  atlas.atlas = original
  atlas.region = Rect2(region)
  sprites[key] = atlas
 return sprites[key]

func warm_characters() -> void:
 for id in ["medic", "nerd", "boss"]:
  for pose in ["idle0", "idle1", "talk0", "talk1", "talk2", "hurt", "walk0", "walk1", "walk2", "walk3"]:
   sprite(id, pose)
 for pose in ["right", "walk", "stand", "main", "run", "jump", "crouch", "sit", "talk0", "talk1", "talk2", "talk3", "talk4", "wave"]:
  sprite("protagonista", pose)

## Lugar de cada nivel (2–10) por rama; coincide con las carpetas de res://paisajes.
const PLACES = {
 "A": ["huerto", "acueducto", "invernadero", "plaza", "bosque", "escuela", "molino", "valle", "amanecer"],
 "B": ["mercado", "fundicion", "talleres", "radio", "zona_franca", "laboratorio", "energia", "metropoli", "conclave"],
 "C": ["puesto", "arsenal", "colina", "campamento", "muro", "bunker", "bloqueo", "ciudadela", "pax"]
}

func landscape_path(branch: String, level: int, layer: String = "fondo") -> String:
 if level == 1:
  return "res://paisajes/nivel1/paisaje_nivel1_%s.png" % layer
 var place: String = PLACES.get(branch, PLACES.A)[level - 2]
 return "res://paisajes/rama%s/nivel%d_%s/paisaje_%s_nivel%d_%s.png" % [branch, level, place, branch, level, layer]

func texture(path: String) -> Texture2D:
 if not textures.has(path):
  textures[path] = load(path) if ResourceLoader.exists(path) else null
 return textures[path]

func character(id: String, pose: String = "idle0") -> Texture2D:
 return texture("res://personajes/%s/%s.png" % [id, pose])
