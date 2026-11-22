extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1280, 800)
 var gm = root.get_node("GameManager")
 # Sólo leer la partida real: no cargarla, migrarla ni guardar sobre ella.
 var before: String = FileAccess.get_file_as_string(gm.save_path) if FileAccess.file_exists(gm.save_path) else ""
 var data: Dictionary = gm.read_save()
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/restart_menu.png")
 var after: String = FileAccess.get_file_as_string(gm.save_path) if FileAccess.file_exists(gm.save_path) else ""
 var buttons: Array[Node] = main.find_children("*", "Button", true, false)
 var resume: Array[Node] = buttons.filter(func(node): return node.text == "Continuar partida")
 var ok: bool = before == after and resume.size() == 1 and resume[0].disabled == data.is_empty()
 if not before.is_empty() and data.is_empty():
  ok = false
  push_error("La partida actual no tiene un guardado válido")
 print("VERDARIA REINICIO: menú cargado, partida disponible = ", not data.is_empty(), "; archivo original intacto = ", before == after, "; fallos = ", 0 if ok else 1)
 main.queue_free()
 await process_frame
 quit(0 if ok else 1)
