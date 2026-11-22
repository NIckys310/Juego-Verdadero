extends SceneTree
## Ejecutar con Godot --headless --path . --script res://tests/smoke.gd
var failures: int = 0

func check(condition: bool, description: String) -> void:
 if not condition:
  failures += 1
  push_error(description)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_smoke.json"
 var previous: String = FileAccess.get_file_as_string(gm.save_path) if FileAccess.file_exists(gm.save_path) else ""
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 for choice in ["reparar", "vender", "fortificar"]:
  gm.new_game()
  check(not gm.can_advance(), "La casa exige decisión")
  gm.choose_home(choice)
  var route: String = gm.branch
  scene.show_game()
  await process_frame
  check(gm.can_advance(), "La decisión desbloquea nivel 2")
  gm.advance()
  for stage in range(2, 11):
   check(gm.level == stage, "Secuencia de niveles")
   check(not gm.can_advance(), "No avanzar sin objetivo")
   var generated: Dictionary = gm.layout()
   check(generated == gm.layout(), "Generación reproducible")
   for site in generated.sites:
    gm.interact(int(site.id), site.action)
    var count: int = gm.history.size()
    gm.interact(int(site.id), site.action)
    check(count == gm.history.size(), "No duplicar interacción")
   check(gm.branch == route, "La ruta inicial permanece fija")
   check(gm.can_advance(), "Objetivo completado")
   gm.advance()
  check(gm.finished and gm.level == 10, "Final de campaña")
  check(gm.load_game() and gm.finished and gm.branch == route, "Persistencia de campaña")
  scene.ending_dialog()
  await process_frame
 if previous.is_empty():
  DirAccess.remove_absolute(gm.save_path)
 else:
  var file = FileAccess.open(gm.save_path, FileAccess.WRITE)
  file.store_string(previous)
 scene.queue_free()
 await process_frame
 print("VERDARIA: tres rutas, 30 etapas, UI y persistencia verificadas; fallos = ", failures)
 quit(failures)
