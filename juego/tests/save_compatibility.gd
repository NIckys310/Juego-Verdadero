extends SceneTree
var failures: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, description: String) -> void:
 if not condition:
  failures += 1
  push_error(description)

func write_save(gm: Node, text: String) -> void:
 var file = FileAccess.open(gm.save_path, FileAccess.WRITE)
 file.store_string(text)
 file.close()

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_compatibility.json"
 var previous: String = FileAccess.get_file_as_string(gm.save_path) if FileAccess.file_exists(gm.save_path) else ""
 gm.new_game()
 gm.choose_home("reparar")
 gm.advance()
 var site: Dictionary = gm.layout().sites[0]
 gm.interact(int(site.id), site.action)
 var history_size: int = gm.history.size()
 check(gm.load_game(), "Cargar progreso parcial")
 gm.interact(int(site.id), site.action)
 check(gm.history.size() == history_size and gm.completed.size() == 1, "IDs JSON no duplican tareas al continuar")
 gm.level = 4
 gm.resources.materiales = 1
 check(not gm.resolve_decision("ivo_supplies", "compartir"), "Rechazar coste sin fondos")
 check(gm.resources.materiales == 1 and not gm.decisions.has("ivo_supplies"), "No gastar ni decidir al fallar")
 var legacy: Dictionary = {"version": 1, "branch": "A", "level": 6, "seed": 55, "history": [], "completed": [], "resources": {"comunidad": 3, "materiales": 5, "seguridad": 2}, "finished": false}
 write_save(gm, JSON.stringify(legacy))
 check(gm.load_game(), "Migrar guardado versión 1")
 check(gm.decisions.size() == 3 and gm.characters.medic.status == "desaparecida", "Encuentros superados migran sin aliados")
 check(gm.read_save().version == gm.SAVE_VERSION, "Migración serializada a la versión actual")
 var funds: Dictionary = gm.resources.duplicate()
 check(gm.load_game(), "Recargar migración")
 gm.apply_arrival()
 check(gm.resources == funds, "No duplicar recompensas al migrar o cargar")
 # La versión anterior conserva su refugio y salud al adoptar la nueva economía.
 var version_four: Dictionary = gm.read_save()
 version_four.version = 4
 version_four.seeds = 17
 version_four.erase("seeds_earned")
 version_four.physical = {"level": gm.level, "health": 63, "checkpoint_x": 1234.0, "checkpoint_y": 520.0}
 write_save(gm, JSON.stringify(version_four))
 check(gm.load_game(), "Migrar guardado versión 4")
 check(gm.physical.health == 63 and gm.physical.checkpoint_x == 1234, "Migración conserva salud y punto de retorno")
 check(gm.seeds == 17 and gm.seeds_earned == 17 and gm.read_save().version == gm.SAVE_VERSION, "Migración conserva semillas y adopta contador de recogida")
 gm.seeds = 21
 gm.seeds_earned = 21
 gm.save_game()
 check(gm.save_error.is_empty() and gm.read_save().seeds == 21, "Sustitución completa del guardado en Windows")
 var interrupted = FileAccess.open(gm.save_path + ".tmp", FileAccess.WRITE)
 interrupted.store_string("{interrupted-write")
 interrupted.close()
 write_save(gm, "{invalid-json")
 check(not gm.read_save().is_empty() and gm.save_recovered, "Recuperar copia válida si se interrumpe el guardado principal")
 check(gm.load_game() and gm.save_error.is_empty(), "Continuar restaura el archivo principal")
 check(gm.seeds == 17 and gm.physical.health == 63, "Recuperación mantiene recursos y salud de la copia anterior")
 check(not gm.read_save().is_empty() and not gm.save_recovered, "La recuperación deja un archivo principal válido")
 DirAccess.remove_absolute(gm.save_path)
 check(gm.load_game() and gm.save_error.is_empty(), "Recuperar copia si falta el archivo principal")
 write_save(gm, "{invalid-json")
 var backup = FileAccess.open(gm.save_path + ".bak", FileAccess.WRITE)
 backup.store_string("{invalid-backup")
 backup.close()
 check(gm.read_save().is_empty(), "Guardado corrupto se rechaza sin bloquear menú")
 for suffix in [".tmp", ".bak", ".bak.tmp"]:
  if FileAccess.file_exists(gm.save_path + suffix):
   DirAccess.remove_absolute(gm.save_path + suffix)
 if previous.is_empty():
  DirAccess.remove_absolute(gm.save_path)
 else:
  write_save(gm, previous)
 print("VERDARIA: carga parcial, costes, migración y corrupción; fallos = ", failures)
 quit(failures)
