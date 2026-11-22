extends Node
signal changed
const Brain = preload("res://scripts/decision_brain.gd")
const Narrative = preload("res://scripts/narrative_director.gd")
const SAVE_VERSION = 6
const SAVE_PATH = "user://verdaria_save.json"
var save_path: String = SAVE_PATH
var save_recovered: bool = false
const TITLES = {
 "A": ["El Refugio Base", "El Huerto Comunitario Abandonado", "El Acueducto Seco", "El Invernadero de Cristal Roto", "La Plaza de Intercambio Verde", "El Bosque Contaminado Periférico", "La Escuela de los Sobrevivientes", "El Molino de Viento Comunitario", "El Valle de la Esperanza", "El Nuevo Amanecer de Verdaria"],
 "B": ["El Refugio Base", "El Mercado Negro de Chatarra", "La Fundición Oxidada", "El Distrito de Talleres Clandestinos", "La Torre de Comunicaciones Rota", "La Zona Franca de Verdaria", "El Laboratorio Tecnológico Subterráneo", "La Red de Energía Centralizada", "La Metrópoli Mecanizada", "El Cónclave del Progreso"],
 "C": ["El Refugio Base", "El Puesto de Control Perimetral", "El Arsenal Abandonado", "La Colina de Observación", "El Campamento de la Milicia", "El Muro Este Derruido", "El Búnker Subterráneo", "El Bloqueo de Rutas Principales", "La Ciudadela Acorazada", "La Pax Armada"]
}
const BRANCH_NAMES = {"A": "Restauración social y agrícola", "B": "Comercio e industria tecnológica", "C": "Resistencia y defensa"}
const MISSIONS = {
 "A": ["Reparar el hogar", "Limpiar tierras cultivables", "Purificar el agua con Elena", "Recuperar materiales del invernadero", "Preparar el intercambio ecológico", "Reforestar el bosque", "Equipar la escuela", "Recuperar el molino", "Restaurar el valle", "Consolidar la comunidad"],
 "B": ["Desguazar el hogar", "Recuperar chatarra para trueque", "Activar la fundición", "Equipar los talleres", "Restaurar la radio con Marcos", "Preparar el comercio exterior", "Recuperar tecnología", "Conectar la red energética", "Construir la metrópoli", "Consolidar el progreso"],
 "C": ["Fortificar el hogar", "Instalar barricadas", "Recuperar suministros", "Preparar la vigilancia", "Equipar la milicia con Marcos", "Reforzar el muro este", "Asegurar el búnker", "Controlar los accesos", "Fortificar la ciudadela", "Consolidar la defensa"]
}
var brain = Brain.new()
var narrative = Narrative.new()
var characters: Dictionary = narrative.initial_states()
var decisions: Dictionary = {}
var journal: Array = []
var rewarded_levels: Array = []
var branch: String = ""
var level: int = 1
var world_seed: int = 1
var history: Array = []
var completed: Array = []
var resources: Dictionary = {"comunidad": 0, "materiales": 0, "seguridad": 0}
var finished: bool = false
var save_error: String = ""
var world_flags: Dictionary = {}
var tutorial: Array = []
var physical: Dictionary = {"level": 1, "health": 100, "checkpoint_x": 80.0, "checkpoint_y": 520.0}
var audio_enabled: bool = true
var seeds: int = 0
var seeds_earned: int = 0

func new_game() -> void:
 branch = ""
 level = 1
 world_seed = randi_range(1, 1000000)
 history = []
 characters = narrative.initial_states()
 decisions = {}
 journal = []
 rewarded_levels = []
 completed = []
 resources = {"comunidad": 0, "materiales": 0, "seguridad": 0}
 finished = false
 world_flags = {}
 tutorial = []
 seeds = 0
 seeds_earned = 0
 reset_physical()
 save_game()
 changed.emit()

func choose_home(action: String) -> void:
 if not branch.is_empty() or not action in ["reparar", "vender", "fortificar"]:
  return
 branch = {"reparar": "A", "vender": "B", "fortificar": "C"}[action]
 record(action)
 completed = [0]
 save_game()
 changed.emit()

func record(action: String) -> void:
 history.append({"action": action, "level": level})
 var resource: String = {"reparar": "comunidad", "restaurar": "comunidad", "vender": "materiales", "reciclar": "materiales", "fortificar": "seguridad", "defender": "seguridad"}.get(action, "materiales")
 resources[resource] += 1

func layout() -> Dictionary:
 var generated = brain.generate(history, branch, level, world_seed)
 var effects = narrative.consequences(branch, level, characters)
 generated.required = clampi(int(generated.required) + int(effects.modifier), 1, generated.sites.size())
 generated.effects = effects
 return generated

func pending_decision() -> String:
 return narrative.pending(level, decisions)

func resolve_decision(id: String, choice: String) -> bool:
 if finished or decisions.has(id) or not narrative.DECISIONS.has(id):
  return false
 var rule: Dictionary = narrative.DECISIONS[id]
 if level != rule.level or not choice in rule.options:
  return false
 if id == "elena_rescue" and choice == "rescatar" and not rescue_ready():
  return false
 if id == "ivo_supplies" and choice == "compartir":
  if resources.materiales < 2:
   return false
  resources.materiales -= 2
 apply_outcome(id, choice)
 save_game()
 changed.emit()
 return true

func flags() -> Dictionary:
 return world_flags.get(str(level), {})

func mark_stage_item(category: String, id: String) -> bool:
 if not world_flags.has(str(level)):
  world_flags[str(level)] = {}
 var stage_flags: Dictionary = world_flags[str(level)]
 if not stage_flags.has(category):
  stage_flags[category] = {}
 if stage_flags[category].get(id, false):
  return false
 stage_flags[category][id] = true
 return true

func collect_pickup(id: int) -> void:
 if mark_stage_item("collected", str(id)):
  seeds += 1
  seeds_earned += 1
  if seeds_earned % 10 == 0:
   resources.materiales += 1
  save_game()
  changed.emit()

func open_bonus(id: String) -> void:
 if mark_stage_item("bonus", id):
  var previous = seeds_earned / 10
  seeds += 3
  seeds_earned += 3
  resources.materiales += seeds_earned / 10 - previous
  save_game()
  changed.emit()

func restore_section(id: int, mode: String = "safe") -> bool:
 if finished or level <= 1 or branch.is_empty() or flags().get("restored", {}).get(str(id), false):
  return false
 var nodes: Array = preload("res://scripts/terrain_layout.gd").stage(branch, level).restoration
 var candidates = nodes.filter(func(node): return int(node.id) == id)
 if not mode in ["safe", "high"]:
  return false
 var cost: int = 5 if mode == "high" else 3
 if candidates.is_empty() or seeds < cost:
  return false
 seeds -= cost
 mark_stage_item("restored", str(id))
 if not flags().has("restoration_modes"):
  flags()["restoration_modes"] = {}
 flags().restoration_modes[str(id)] = mode
 var tasks: Array = layout().sites
 if id < tasks.size() and not id in completed:
  completed.append(id)
  record(tasks[id].action)
 var action: String = {"A": "rebrotar", "B": "reactivar", "C": "reforzar"}[branch]
 history.append({"action": action, "level": level})
 if mode == "high":
  history.append({"action": "explorar_alturas", "level": level})
 journal.append({"level": level, "text": "Elegiste la ruta elevada: una pasarela nueva lleva a un recuerdo y seis semillas." if mode == "high" else {"A": "Hiciste rebrotar una pasarela viva y recuperaste fuerzas.", "B": "Reactivaste una pasarela y desconectaste las trampas de ese tramo.", "C": "Reforzaste una pasarela y abriste un nuevo punto de retorno."}[branch]})
 save_game()
 changed.emit()
 return true

func activate_device() -> bool:
 if level <= 1 or finished or flags().get("device", false):
  return false
 var device: Dictionary = preload("res://scripts/terrain_layout.gd").stage(branch, level).device
 if device.is_empty():
  return false
 if not world_flags.has(str(level)):
  world_flags[str(level)] = {}
 world_flags[str(level)]["device"] = true
 history.append({"action": "accionar_mecanismo", "level": level})
 journal.append({"level": level, "text": "Pusiste en marcha: " + device.name + ". " + device.result})
 save_game()
 changed.emit()
 return true

func collect_secret(id: String) -> bool:
 if level <= 1 or finished or flags().get("secrets", {}).get(id, false):
  return false
 var data: Dictionary = preload("res://scripts/terrain_layout.gd").stage(branch, level)
 var valid: bool = data.secrets.any(func(secret): return secret.id == id)
 if id.begins_with("route_"):
  var node_id: String = id.trim_prefix("route_")
  valid = data.restoration.any(func(node): return str(node.id) == node_id) and flags().get("restoration_modes", {}).get(node_id, "safe") == "high"
 if not valid:
  return false
 mark_stage_item("secrets", id)
 var reward: int = 6 if id.begins_with("route_") else 2
 var before: int = seeds_earned / 10
 seeds += reward
 seeds_earned += reward
 resources.materiales += seeds_earned / 10 - before
 history.append({"action": "descubrir_recuerdo", "level": level})
 var memories: Dictionary = {"A": "Un viejo diario explica cómo los vecinos compartían el agua antes del colapso.", "B": "Una bitácora conserva planos de máquinas construidas para servir a la comunidad.", "C": "Una carta recuerda que proteger Verdaria también significa cuidar a quienes quedan atrás."}
 journal.append({"level": level, "text": memories[branch] + " Encontraste un recuerdo en " + title() + "."})
 save_game()
 changed.emit()
 return true

func secret_count() -> int:
 var total: int = 0
 for stage_flags in world_flags.values():
  total += stage_flags.get("secrets", {}).size()
 return total

func defeat_enemy(id: int) -> void:
 if mark_stage_item("defeated", str(id)):
  history.append({"action": "neutralizar_amenaza", "level": level})
  save_game()
  changed.emit()

func complete_world_action(action: String) -> bool:
 if level != 2 or finished or not action in ["bridge", "rubble"] or flags().get(action, false):
  return false
 if not world_flags.has(str(level)):
  world_flags[str(level)] = {}
 world_flags[str(level)][action] = true
 journal.append({"level": level, "text": "Reparaste el paso: ahora hay un puente transitable." if action == "bridge" else "Despejaste los escombros que bloqueaban el acceso a Elena."})
 save_game()
 changed.emit()
 return true

func rescue_ready() -> bool:
 return flags().get("bridge", false) and flags().get("rubble", false)

func reset_physical() -> void:
 physical = {"level": level, "health": 100, "checkpoint_x": 80.0, "checkpoint_y": 520.0}

func capture_physical(health: int, checkpoint: Vector2) -> void:
 physical = {"level": level, "health": clampi(health, 0, 100), "checkpoint_x": checkpoint.x, "checkpoint_y": checkpoint.y}

func mark_tutorial(step: String) -> void:
 if step in tutorial:
  return
 tutorial.append(step)
 # El guardado normal incorpora el tutorial, sin escritura por cada fotograma.

func apply_outcome(id: String, choice: String) -> void:
 var result = narrative.outcome(id, choice)
 decisions[id] = choice
 characters[result.character] = {"status": result.status, "trust": result.trust}
 history.append({"action": result.action, "level": level, "decision": id, "choice": choice})
 journal.append({"level": level, "text": result.summary})

func apply_arrival() -> void:
 if level in rewarded_levels:
  return
 rewarded_levels.append(level)
 var effects = narrative.consequences(branch, level, characters)
 var rewarded: bool = false
 for key in resources:
  resources[key] += effects.reward[key]
  rewarded = rewarded or effects.reward[key] > 0
 if rewarded or (level == 3 and characters.medic.status == "desaparecida"):
  journal.append({"level": level, "text": " ".join(effects.notes)})

func mission() -> String:
 if branch.is_empty():
  return "Habla con los vecinos y decide qué hacer con tu hogar"
 var override: String = narrative.consequences(branch, level, characters).mission
 return MISSIONS[branch][level - 1] if override.is_empty() else override

func interact(site_id: int, action: String) -> void:
 if branch.is_empty() or finished or site_id in completed:
  return
 var valid: bool = false
 for site in layout().sites:
  if int(site.id) == site_id and site.action == action:
   valid = true
 if not valid or level == 1:
  return
 completed.append(site_id)
 record(action)
 save_game()
 changed.emit()

func can_advance() -> bool:
 return not branch.is_empty() and not finished and (level == 1 or completed.size() >= layout().required)

func advance() -> void:
 if not can_advance():
  return
 var pending = pending_decision()
 if not pending.is_empty():
  apply_outcome(pending, narrative.DECISIONS[pending].default)
 if level == 10:
  finished = true
 else:
  level += 1
  completed = []
  reset_physical()
  apply_arrival()
 save_game()
 changed.emit()

func title() -> String:
 return TITLES.get(branch, TITLES.A)[level - 1]

func save_game() -> void:
 var data = {"version": SAVE_VERSION, "branch": branch, "level": level, "seed": world_seed, "history": history, "completed": completed, "resources": resources, "finished": finished, "characters": characters, "decisions": decisions, "journal": journal, "rewarded_levels": rewarded_levels, "world_flags": world_flags, "tutorial": tutorial, "physical": physical, "audio_enabled": audio_enabled, "seeds": seeds, "seeds_earned": seeds_earned}
 var payload = JSON.stringify(data)
 save_error = ""
 if OS.has_feature("web"):
  var result = JavaScriptBridge.eval("(function(){try{localStorage.setItem('verdaria_save'," + JSON.stringify(payload) + ");return true;}catch(e){return false;}})()")
  if result != true:
   save_error = "El navegador no permite guardar esta partida."
 else:
  # Escribir y cerrar antes de sustituir el archivo de la partida.
  var temporary: String = save_path + ".tmp"
  var file = FileAccess.open(temporary, FileAccess.WRITE)
  if not file:
   save_error = "No se pudo guardar la partida."
   return
  file.store_string(payload)
  file.flush()
  var write_error: Error = file.get_error()
  file.close()
  if write_error != OK:
   save_error = "No se pudo completar el guardado. La partida anterior se conserva."
   return
  # Una escritura interrumpida nunca sustituye la copia válida anterior.
  if FileAccess.file_exists(save_path) and not parse_save(FileAccess.get_file_as_string(save_path)).is_empty():
   var backup_temporary: String = save_path + ".bak.tmp"
   if DirAccess.copy_absolute(save_path, backup_temporary) != OK or DirAccess.rename_absolute(backup_temporary, save_path + ".bak") != OK:
    save_error = "No se pudo conservar la copia anterior. La partida anterior sigue disponible."
    return
  if DirAccess.rename_absolute(temporary, save_path) != OK:
   save_error = "No se pudo sustituir el guardado. La partida anterior se conserva."
  else:
   save_recovered = false

func read_save() -> Dictionary:
 save_recovered = false
 var payload = ""
 if OS.has_feature("web"):
  var result = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('verdaria_save') || '';}catch(e){return '';}})()")
  if result is String:
   payload = result
 elif FileAccess.file_exists(save_path):
  payload = FileAccess.get_file_as_string(save_path)
 var data: Dictionary = parse_save(payload)
 if data.is_empty() and not OS.has_feature("web") and FileAccess.file_exists(save_path + ".bak"):
  data = parse_save(FileAccess.get_file_as_string(save_path + ".bak"))
  save_recovered = not data.is_empty()
 return data

func parse_save(payload: String) -> Dictionary:
 if payload.is_empty():
  return {}
 var parser = JSON.new()
 if parser.parse(payload) != OK:
  return {}
 var data = parser.data
 if not data is Dictionary:
  return {}
 if not int(data.get("version", 0)) in [1, 2, 3, 4, 5, 6] or not data.get("branch", "") in ["", "A", "B", "C"]:
  return {}
 if not data.get("level") is float and not data.get("level") is int:
  return {}
 if int(data.level) < 1 or int(data.level) > 10:
  return {}
 if not data.get("history") is Array or not data.get("completed") is Array or not data.get("resources") is Dictionary:
  return {}
 for key in ["comunidad", "materiales", "seguridad"]:
  if not data.resources.get(key) is float and not data.resources.get(key) is int:
   return {}
 for event in data.history:
  if not event is Dictionary or not event.get("action") is String:
   return {}
 if int(data.version) >= 2:
  if not data.get("characters") is Dictionary or not data.get("decisions") is Dictionary or not data.get("journal") is Array or not data.get("rewarded_levels") is Array:
   return {}
  for id in narrative.initial_states():
   var state = data.characters.get(id)
   if not state is Dictionary or not state.get("status") in ["disponible", "rescatada", "desaparecida", "aliado", "distante"]:
    return {}
  for id in data.decisions:
   if not narrative.DECISIONS.has(id) or not data.decisions[id] in narrative.DECISIONS[id].options:
    return {}
  for entry in data.journal:
   if not entry is Dictionary or not entry.get("text") is String or not entry.has("level"):
    return {}
 if int(data.version) >= 3:
  if not data.get("world_flags") is Dictionary or not data.get("tutorial") is Array or not data.get("physical") is Dictionary:
   return {}
  for key in ["level", "health", "checkpoint_x", "checkpoint_y"]:
   var value = data.physical.get(key)
   if not value is float and not value is int:
    return {}
  if int(data.physical.level) != int(data.level) or float(data.physical.health) < 0 or float(data.physical.health) > 100:
   return {}
  if not is_finite(float(data.physical.checkpoint_x)) or not is_finite(float(data.physical.checkpoint_y)):
   return {}
  var max_x: float = 945 if int(data.version) < 4 else preload("res://scripts/terrain_layout.gd").stage(data.branch, int(data.level)).width - 32
  if float(data.physical.checkpoint_x) < 15 or float(data.physical.checkpoint_x) > max_x or not float(data.physical.checkpoint_y) in [432.0, 520.0]:
   return {}
  for key in data.world_flags:
   if not data.world_flags[key] is Dictionary:
    return {}
  for step in data.tutorial:
   if not step is String:
    return {}
 return data

func load_game() -> bool:
 var data = read_save()
 if data.is_empty():
  return false
 branch = data.branch
 level = int(data.level)
 world_seed = int(data.get("seed", 1))
 history = data.history
 completed = []
 for site_id in data.completed:
  completed.append(int(site_id))
 resources = data.resources
 finished = bool(data.get("finished", false))
 characters = data.get("characters", narrative.initial_states())
 for id in characters:
  characters[id].trust = int(characters[id].get("trust", 0))
 decisions = data.get("decisions", {})
 journal = data.get("journal", [])
 rewarded_levels = []
 for rewarded_level in data.get("rewarded_levels", []):
  rewarded_levels.append(int(rewarded_level))
 world_flags = data.get("world_flags", {})
 tutorial = data.get("tutorial", [])
 audio_enabled = bool(data.get("audio_enabled", true))
 seeds = maxi(0, int(data.get("seeds", 0)))
 seeds_earned = maxi(seeds, int(data.get("seeds_earned", seeds)))
 reset_physical()
 if int(data.version) >= 4:
  physical = data.get("physical", physical)
 else:
  physical.health = clampi(int(data.get("physical", {}).get("health", 100)), 0, 100)
 if data.version == 1:
  for id in narrative.DECISIONS:
   if level > narrative.DECISIONS[id].level:
    apply_outcome(id, narrative.DECISIONS[id].default)
  journal.append({"level": level, "text": "Partida de la base anterior: encuentros ya superados se migraron sin aliados; las nuevas decisiones siguen disponibles en niveles pendientes."})
  # Evita regalar recursos al cargar repetidamente una partida antigua.
  rewarded_levels = range(1, level + 1)
 if int(data.version) < SAVE_VERSION or save_recovered:
  save_game()
 changed.emit()
 return true
