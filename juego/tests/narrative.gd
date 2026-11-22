extends SceneTree
var failures: int = 0
const Catalog = preload("res://scripts/asset_catalog.gd")

func check(condition: bool, description: String) -> void:
 if not condition:
  failures += 1
  push_error(description)

func _initialize() -> void:
 call_deferred("run")

func complete_tasks(gm: Node) -> void:
 for site in gm.layout().sites:
  gm.interact(int(site.id), site.action)

func run() -> void:
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_narrative.json"
 var previous: String = FileAccess.get_file_as_string(gm.save_path) if FileAccess.file_exists(gm.save_path) else ""
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var catalog = Catalog.new()
 for branch in ["A", "B", "C"]:
  for level in range(1, 11):
   for layer in ["cielo", "fondo", "frente", "hd"]:
    check(ResourceLoader.exists(catalog.landscape_path(branch, level, layer)), "Paisaje identificado: %s/%d/%s" % [branch, level, layer])
 for id in ["medic", "nerd", "boss"]:
  for pose in ["idle0", "idle1", "talk0", "hurt"]:
   check(catalog.character(id, pose) != null, "Sprite de personaje: %s/%s" % [id, pose])
 for home in ["reparar", "vender", "fortificar"]:
  for variant in range(8):
   var rescue: bool = (variant & 1) != 0
   var share: bool = (variant & 2) != 0
   var pact: bool = (variant & 4) != 0
   gm.new_game()
   gm.choose_home(home)
   scene.show_game()
   check(scene.world.npcs.size() == 3, "Refugio con tres personajes")
   gm.advance()
   var elena = scene.world.npcs[0]
   scene.world.player.position = Vector2(elena.x, elena.y)
   scene.world.update_nearby()
   check(scene.world.nearby_npc == "medic", "Interacción por proximidad")
   scene.character_dialog("medic")
   check(not scene.world.active, "Diálogo pausa movimiento")
   scene.close_modal()
   check(scene.world.active, "Cerrar diálogo reanuda movimiento")
   check(not gm.resolve_decision("ivo_supplies", "compartir"), "No decidir fuera de nivel")
   if rescue:
    check(not gm.resolve_decision("elena_rescue", "rescatar"), "No rescatar sin abrir acceso")
    gm.complete_world_action("bridge")
    gm.complete_world_action("rubble")
    check(gm.resolve_decision("elena_rescue", "rescatar"), "Rescate registrado")
    check(not gm.resolve_decision("elena_rescue", "abandonar"), "Decisión irreversible")
   complete_tasks(gm)
   gm.advance() # Ignorar el encuentro deja atrás a Elena.
   check(gm.decisions.elena_rescue == ("rescatar" if rescue else "abandonar"), "Ignorar tiene consecuencia persistente")
   check(("medic" in gm.narrative.roster(3, gm.characters)) == rescue, "Presencia futura de Elena")
   var base: int = gm.brain.generate(gm.history, gm.branch, 3, gm.world_seed).required
   check(gm.layout().required == base + (-1 if rescue else 1), "Rescate cambia objetivo posterior")
   check(gm.load_game() and gm.characters.medic.status == ("rescatada" if rescue else "desaparecida"), "Recarga conserva estado")
   var funds: Dictionary = gm.resources.duplicate()
   gm.apply_arrival()
   check(gm.resources == funds, "No duplicar ayuda al volver o cargar")
   complete_tasks(gm)
   gm.advance()
   scene.character_dialog("nerd")
   scene.close_modal()
   complete_tasks(gm)
   var materials: int = gm.resources.materiales
   check(materials >= 2, "Reciclaje permite compartir en todas las rutas")
   check(gm.resolve_decision("ivo_supplies", "compartir" if share else "reservar"), "Decisión de Ivo")
   check(gm.resources.materiales == materials - (2 if share else 0), "Coste real de compartir")
   gm.advance()
   scene.character_dialog("boss")
   scene.close_modal()
   check(gm.resolve_decision("marcos_pact", "pactar" if pact else "rechazar"), "Pacto de Marcos")
   complete_tasks(gm)
   gm.advance()
   for stage in range(6, 11):
    if stage == 7:
     check(gm.layout().effects.reward.materiales == (2 if share else 0), "Herramientas de Ivo dependen de confianza")
    if stage == 8:
     check(gm.layout().effects.reward.seguridad == (2 if pact else 0), "Apoyo de Marcos depende del pacto")
    complete_tasks(gm)
    check(gm.can_advance(), "Objetivos alcanzables con cada combinación")
    gm.advance()
   check(gm.finished and gm.journal.size() >= 3, "Final con memoria narrativa")
   var states: Dictionary = gm.characters.duplicate(true)
   check(gm.load_game() and gm.characters == states and gm.decisions.size() == 3, "Persistencia completa")
   scene.ending_dialog()
   scene.journal_dialog()
   scene.close_modal()
 # Fondos y UI cambian con cada combinación; guardado original intacto.
 if previous.is_empty():
  DirAccess.remove_absolute(gm.save_path)
 else:
  var file = FileAccess.open(gm.save_path, FileAccess.WRITE)
  file.store_string(previous)
 scene.queue_free()
 await process_frame
 print("VERDARIA: 24 campañas narrativas, assets, UI y persistencia; fallos = ", failures)
 quit(failures)
