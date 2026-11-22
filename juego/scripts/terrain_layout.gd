extends RefCounted
## Recorridos laterales deterministas con rutas altas, bajas y metas.
const GROUND_Y = 520.0
const TILE = 32
const RECIPES = {
 "A": [[], ["meadow", "steps", "gaps", "canopy"], ["river", "steps", "river", "gaps"], ["glass", "canopy", "glass", "steps", "gaps"], ["meadow", "tunnel", "steps", "meadow"], ["canopy", "spikes", "canopy", "river", "canopy"], ["steps", "glass", "tunnel", "tower"], ["wind", "moving", "tower", "wind", "moving"], ["meadow", "gaps", "river", "canopy", "steps"], ["canopy", "moving", "glass", "tower", "meadow", "boss"]],
 "B": [[], ["conveyor", "steps", "tunnel", "gaps"], ["lava", "conveyor", "steam", "lava", "steps"], ["tunnel", "conveyor", "glass", "moving"], ["tower", "moving", "tower", "wind", "steps"], ["conveyor", "gaps", "tunnel", "steam"], ["glass", "steam", "tunnel", "moving", "glass"], ["moving", "steam", "conveyor", "tower", "lava"], ["tower", "conveyor", "wind", "moving", "tunnel"], ["lava", "steam", "moving", "tower", "conveyor", "boss"]],
 "C": [[], ["spikes", "tower", "steps", "gaps"], ["tunnel", "spikes", "steam", "steps"], ["tower", "wind", "gaps", "tower", "moving"], ["meadow", "spikes", "tunnel", "tower"], ["gaps", "moving", "tower", "spikes", "steps"], ["tunnel", "steam", "spikes", "tunnel", "glass"], ["conveyor", "spikes", "gaps", "moving", "steam"], ["tower", "spikes", "tunnel", "wind", "tower"], ["spikes", "steam", "tower", "moving", "tunnel", "boss"]]
}
const BIOMES = {
 "A": ["refuge", "garden", "water", "glass", "village", "forest", "school", "windmill", "valley", "dawn"],
 "B": ["refuge", "scrapyard", "foundry", "workshop", "radio", "market", "laboratory", "energy", "city", "reactor"],
 "C": ["refuge", "checkpoint", "arsenal", "hill", "camp", "wall", "bunker", "blockade", "citadel", "fortress"]
}
static var cache: Dictionary = {}

static func surface(id: String, rect: Rect2, one_way: bool = false, style: String = "brick") -> Dictionary:
 return {"id": id, "rect": rect, "one_way": one_way, "style": style}

static func ground(_level: int) -> float:
 return GROUND_Y

static func stage(branch: String, level: int) -> Dictionary:
 var route = branch if branch in ["A", "B", "C"] else "A"
 var key = "%s:%d" % [route, level]
 if cache.has(key):
  return cache[key]
 var data = {"width": 1920.0 if level == 1 else 0.0, "biome": BIOMES[route][level - 1], "surfaces": [], "hazards": [], "enemies": [], "pickups": [], "moving": [], "restoration": [], "tasks": [], "checkpoints": [Vector2(80, 520)], "decor": [], "rescue": Vector2.ZERO, "device": {}, "secrets": []}
 if level == 1:
  data.surfaces = [surface("ground", Rect2(0, 520, 1920, 160), false, "grass"), surface("intro_step", Rect2(450, 488, 96, 32)), surface("intro_high", Rect2(640, 456, 128, 16), true), surface("home_roof", Rect2(1320, 424, 224, 16), true), surface("home_step", Rect2(1224, 456, 96, 16), true)]
  data.decor = [{"kind": "house", "point": Vector2(1420, 520)}, {"kind": "sign", "point": Vector2(330, 520)}, {"kind": "tree", "point": Vector2(870, 520)}]
  for x in [460, 492, 524, 656, 688, 720, 752, 1024, 1056, 1088]:
   data.pickups.append({"point": Vector2(x, 424 if x >= 640 and x <= 752 else 450), "kind": "seed"})
 else:
  var recipes: Array = RECIPES[route][level - 1]
  var start = 320.0
  data.surfaces.append(surface("ground_start", Rect2(0, 520, start, 160), false, "grass" if route == "A" else "brick"))
  for i in range(recipes.size()):
   module(data, recipes[i], start + i * 640.0, route, level, i)
  data.width = start + recipes.size() * 640.0 + 480
  data.surfaces.append(surface("ground_finish", Rect2(data.width - 480, 520, 480, 160), false, "grass" if route == "A" else "brick"))
  data.checkpoints.append(Vector2(start + 640 * floor(recipes.size() / 2.0) + 32, 520))
  data.decor.append({"kind": "camp", "point": Vector2(data.width - 360, 520)})
  if level == 2:
   data.rescue = data.tasks[-1] + Vector2(40, 0)
   data.decor.append({"kind": "beacon", "point": data.rescue})
  data.tasks.append(Vector2(data.width - 320, 520))
  data.tasks.append(Vector2(data.width - 192, 520))
  add_adventure(data, route, level, recipes)
 cache[key] = data
 return data

static func module(data: Dictionary, kind: String, x: float, branch: String, level: int, index: int) -> void:
 var hazard_start: int = data.hazards.size()
 var ground_style = "grass" if branch == "A" else "brick"
 var deck_style = "wood" if branch == "A" else "metal"
 var prefix = "s%d_" % index
 var task = Vector2(x + 490, 520)
 var platforms: Array = []
 var ground_segments: Array = [Rect2(x, 520, 640, 160)]
 match kind:
  "meadow":
   platforms = [Rect2(x + 160, 488, 96, 32), Rect2(x + 350, 456, 128, 16)]
   task = Vector2(x + 406, 456)
   data.decor.append({"kind": "tree", "point": Vector2(x + 560, 520)})
  "steps", "glass", "canopy", "wind":
   platforms = [Rect2(x + 48, 456, 96, 16), Rect2(x + 160, 392, 112, 16), Rect2(x + 288, 328, 144, 16), Rect2(x + 448, 392, 96, 16), Rect2(x + 560, 456, 80, 16)]
   task = Vector2(x + 355, 328)
   if kind == "glass":
    deck_style = "glass"
    data.hazards.append({"kind": "saw", "rect": Rect2(x + 320, 486, 28, 28), "range": 120.0, "phase": index * 0.7})
   if kind == "canopy":
    data.decor.append({"kind": "tree", "point": Vector2(x + 350, 520)})
   if kind == "wind":
    data.decor.append({"kind": "windmill", "point": Vector2(x + 350, 520)})
    data.moving.append({"rect": Rect2(x + 332, 240, 96, 16), "axis": Vector2(80, 0), "period": 3.2, "phase": 0.0})
  "gaps", "river", "lava":
   var gap_start = 240 if kind == "gaps" else 224
   var gap_end = 352 if kind == "gaps" else 384
   ground_segments = [Rect2(x, 520, gap_start, 160), Rect2(x + gap_end, 520, 640 - gap_end, 160)]
   platforms = [Rect2(x + 96, 456, 96, 16), Rect2(x + 224, 392, 144, 16), Rect2(x + 400, 456, 96, 16)]
   task = Vector2(x + 280, 392)
   data.hazards.append({"kind": "lava" if kind == "lava" else "water" if kind == "river" else "pit", "rect": Rect2(x + gap_start, 536, gap_end - gap_start, 64), "range": 0.0, "phase": 0.0})
  "moving":
   ground_segments = [Rect2(x, 520, 192, 160), Rect2(x + 272, 520, 64, 160), Rect2(x + 448, 520, 192, 160)]
   platforms = [Rect2(x + 64, 456, 96, 16), Rect2(x + 272, 440, 64, 16), Rect2(x + 464, 456, 96, 16)]
   data.moving.append({"rect": Rect2(x + 164, 392, 104, 16), "axis": Vector2(96, 0), "period": 3.0, "phase": 0.0})
   data.moving.append({"rect": Rect2(x + 332, 392, 104, 16), "axis": Vector2(0, 72), "period": 3.6, "phase": 0.0})
   task = Vector2(x + 304, 440)
   data.hazards.append({"kind": "water", "rect": Rect2(x + 192, 536, 256, 64), "range": 0.0, "phase": 0.0})
  "tower":
   platforms = [Rect2(x + 32, 456, 96, 16), Rect2(x + 144, 392, 96, 16), Rect2(x + 256, 328, 96, 16), Rect2(x + 368, 264, 96, 16), Rect2(x + 480, 328, 80, 16), Rect2(x + 568, 392, 72, 16)]
   task = Vector2(x + 412, 264)
   data.decor.append({"kind": "tower", "point": Vector2(x + 412, 520)})
  "tunnel":
   platforms = [Rect2(x + 40, 456, 96, 16), Rect2(x + 160, 408, 352, 32), Rect2(x + 544, 456, 80, 16)]
   task = Vector2(x + 360, 408)
   data.hazards.append({"kind": "spikes", "rect": Rect2(x + 256, 504, 64, 16), "range": 0.0, "phase": 0.0})
  "spikes", "steam":
   platforms = [Rect2(x + 144, 440, 128, 16), Rect2(x + 352, 392, 144, 16)]
   task = Vector2(x + 420, 392)
   data.hazards.append({"kind": "spikes" if kind == "spikes" else "steam", "rect": Rect2(x + 286, 496 if kind == "spikes" else 408, 64, 24 if kind == "spikes" else 112), "range": 0.0, "phase": index * 0.8})
  "conveyor":
   platforms = [Rect2(x + 176, 440, 112, 16), Rect2(x + 384, 392, 128, 16)]
   task = Vector2(x + 440, 392)
   data.decor.append({"kind": "conveyor", "point": Vector2(x + 128, 520), "width": 384, "speed": -70.0 if index % 2 == 0 else 70.0})
  "boss":
   platforms = [Rect2(x + 112, 440, 96, 16), Rect2(x + 448, 440, 96, 16)]
   task = Vector2(x + 550, 520)
   data.enemies.append({"point": Vector2(x + 330, 520), "kind": "guardian", "left": x + 220, "right": x + 425, "hp": 3, "route": branch})
 for i in range(ground_segments.size()):
  data.surfaces.append(surface(prefix + "ground%d" % i, ground_segments[i], false, ground_style))
 for i in range(platforms.size()):
  var rect: Rect2 = platforms[i]
  data.surfaces.append(surface(prefix + "deck%d" % i, rect, kind != "tunnel" and kind != "meadow", deck_style))
  for coin_x in range(int(rect.position.x) + 24, int(rect.end.x) - 12, 32):
   data.pickups.append({"point": Vector2(coin_x, rect.position.y - 40), "kind": "seed"})
 # Caja sobre una cubierta accesible, con 112 px de espacio libre debajo.
 # El cuerpo ocupa 44 px y el golpe requiere subir 68: cabe y se alcanza.
 var support: Rect2 = platforms[-1] if not platforms.is_empty() else ground_segments[-1]
 var bonus_center: float = support.get_center().x
 data.surfaces.append(surface(prefix + "bonus", Rect2(bonus_center - 16, support.position.y - 144, 32, 32), false, "bonus"))
 for h in range(hazard_start, data.hazards.size()):
  data.hazards[h].section = index
 if index % 2 == 0 or kind == "boss":
  var point = Vector2(x + 72, 520)
  var style = "garden" if branch == "A" else "powered" if branch == "B" else "barricade"
  # En túneles se reconstruye sobre la cubierta: debajo no cabe el cuerpo.
  var restored_y: float = 344 if kind == "tunnel" else 456
  var high_support: Rect2 = platforms[0]
  for deck in platforms:
   if deck.position.y < high_support.position.y:
    high_support = deck
  var raised: Dictionary = surface("raised_%d" % index, Rect2(high_support.get_center().x - 96, high_support.position.y - 64, 192, 16), true, style)
  data.restoration.append({"id": index, "point": point, "cost": 3, "section": index, "surface": surface("restored_%d" % index, Rect2(x + 192, restored_y, 224, 16), true, style), "raised": raised, "boss": kind == "boss"})
 data.tasks.append(task)
 if kind != "boss":
  var enemy_kind: String = "turret" if index % 3 == 1 else "hopper" if index % 3 == 2 else "spore" if branch == "A" else "crawler" if branch == "B" else "beetle"
  data.enemies.append({"point": Vector2(x + 548, 520), "kind": enemy_kind, "left": x + 480, "right": x + 612, "hp": 1, "route": branch})
  if level >= 4 and index % 2 == 1:
   data.enemies.append({"point": Vector2(x + 330, 310), "kind": "drone", "left": x + 200, "right": x + 480, "hp": 1})

static func build(branch: String, level: int, flags: Dictionary = {}, states: Dictionary = {}) -> Array:
 var data = stage(branch, level)
 var result: Array = data.surfaces.duplicate(true)
 for node in data.restoration:
  if flags.get("restored", {}).get(str(node.id), false):
   var mode: String = flags.get("restoration_modes", {}).get(str(node.id), "safe")
   result.append((node.raised if mode == "high" else node.surface).duplicate(true))
 if flags.get("device", false) and not data.device.is_empty():
  for deck in data.device.get("surfaces", []):
   result.append(deck.duplicate(true))
 if level == 2:
  var gap = gap_bounds(branch)
  if flags.get("bridge", false):
   result.append(surface("repaired_bridge", Rect2(gap.x, 520, gap.y - gap.x, 16), false, "wood"))
  if not flags.get("rubble", false):
   var point = rubble_position(branch)
   result.append(surface("rubble", Rect2(point.x - 16, point.y - 32, 32, 32), false, "rubble"))
 if states.get("nerd", {}).get("status", "") == "aliado" and level in [7, 8]:
  result.append(surface("ivo_lift", Rect2(1008, 456, 144, 16), true, "glass"))
 if states.get("boss", {}).get("status", "") == "aliado" and level in [6, 8]:
  result.append(surface("marcos_bridge", Rect2(1184, 440, 160, 16), true, "metal"))
 return result

static func add_adventure(data: Dictionary, branch: String, level: int, recipes: Array) -> void:
 var kinds: Dictionary = {
  "A": ["water", "water", "lift", "wind", "water", "lift", "wind", "water", "shield"],
  "B": ["lift", "water", "lift", "wind", "lift", "shield", "wind", "lift", "water"],
  "C": ["shield", "shield", "wind", "shield", "lift", "shield", "lift", "wind", "shield"]}
 var names: Dictionary = {
  "A": ["Riego del huerto", "Compuerta del acueducto", "Elevador del invernadero", "Ventilación de la plaza", "Canal del bosque", "Montacargas de la escuela", "Aspas del molino", "Canal del valle", "Raíces protectoras"],
  "B": ["Montacargas del mercado", "Refrigeración de la forja", "Elevador de talleres", "Antena de viento", "Grúa de la zona franca", "Aislamiento del laboratorio", "Turbina de energía", "Elevador de la metrópoli", "Refrigeración del reactor"],
  "C": ["Barricada del puesto", "Seguro del arsenal", "Corriente de la colina", "Barricada del campamento", "Elevador del muro", "Seguro del búnker", "Montacargas del bloqueo", "Viento de la ciudadela", "Escudo de la fortaleza"]}
 var kind: String = kinds[branch][level - 2]
 var section: int = recipes.find("boss") if level == 10 else 0
 var x: float = 320 + section * 640
 var device: Dictionary = {"kind": kind, "name": names[branch][level - 2], "point": Vector2(x - 56, 520), "section": section, "surfaces": [], "zone": Rect2(x + 220, 256, 160, 264)}
 if kind == "water":
  var selected: Array = data.hazards.filter(func(hazard): return hazard.kind in ["water", "lava", "pit"] and (level != 10 or hazard.section == section - 1))
  if not selected.is_empty():
   section = selected[0].section
   device.section = section
   var hazard: Dictionary = selected[0]
   device.zone = hazard.rect
   device.surfaces.append(surface("device_bridge", Rect2(hazard.rect.position.x, 520, hazard.rect.size.x, 16), false, "garden" if branch == "A" else "powered"))
  device.result = "Canal abierto · Paso recuperado"
 elif kind == "lift":
  device.lift = {"rect": Rect2(x + 48, 408, 112, 16), "axis": Vector2(0, 80), "period": 4.0, "phase": PI / 2}
  device.surfaces.append(surface("lift_landing", Rect2(x + 176, 328, 160, 16), true, "powered"))
  device.result = "Elevador conectado · Sube a la cubierta cuando baje"
 elif kind == "wind":
  device.result = "Corriente abierta · Salta dentro para elevarte"
 else:
  device.zone = Rect2(x + 180, 444, 256, 76)
  device.result = "Barricada lista · Trampas retraídas y cobertura de disparos"
 if level == 10:
  device.result = "Núcleo estabilizado · Ataques del guardián debilitados"
 data.device = device
 var high: Array = data.surfaces.filter(func(deck): return deck.id.begins_with("s0_deck"))
 high.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y)
 if not high.is_empty():
  var deck: Rect2 = high[0].rect
  data.secrets.append({"id": "diary", "point": Vector2(deck.get_center().x + 20, deck.position.y - 22), "kind": "diary"})

static func gap_bounds(branch: String) -> Vector2:
 var recipes: Array = RECIPES[branch if branch in RECIPES else "A"][1]
 var index = recipes.find("gaps")
 if index < 0:
  index = 2
 var x = 320 + index * 640
 return Vector2(x + 240, x + 352)

static func rubble_position(_branch: String) -> Vector2:
 return Vector2(430, 520)

static func rescue_position(branch: String) -> Vector2:
 return stage(branch, 2).rescue

static func task_position(index: int, branch: String = "", level: int = 3) -> Vector2:
 var tasks: Array = stage(branch, level).tasks
 return tasks[index % tasks.size()] if not tasks.is_empty() else Vector2(1420, 520)

static func npc_position(index: int, level: int = 3, branch: String = "") -> Vector2:
 if level == 1:
  return [Vector2(200, 520), Vector2(950, 520), Vector2(1640, 520)][index % 3]
 return [Vector2(190, 520), stage(branch, level).checkpoints[1] + Vector2(90, 0), Vector2(stage(branch, level).width - 360, 520)][index % 3]
