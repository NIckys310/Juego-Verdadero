extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  await process_frame

func capture(path: String) -> Image:
 await process_frame
 await RenderingServer.frame_post_draw
 var result: Image = root.get_texture().get_image()
 result.save_png(path)
 return result

func run() -> void:
 root.size = Vector2i(1280, 800)
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_production_preview.json"
 gm.audio_enabled = false
 gm.new_game()
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 scene.show_game()
 var world = scene.world
 world.persist_physical = false
 world.set_physics_process(false)
 world.stage_entry_time = 0
 world.player.invulnerability = 0
 await frames(10)
 var event = InputEventKey.new()
 event.physical_keycode = KEY_SPACE
 event.pressed = true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await frames(8)
 var jump_y: float = world.player.position.y
 await capture("res://build/production_jump.png")
 print("SALTO_RENDER teclado dispositivo 0: pies y=", jump_y, " (suelo y=520)")
 event = event.duplicate()
 event.pressed = false
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await frames(50)
 world.player.set_physics_process(false)
 world.active = false
 world.player.position = Vector2(960, 520)
 world.player.previous_position = world.player.position
 world.camera_x = 480
 world.player.status_timer = 0
 world.player.facing_left = false
 var camera: float = world.camera_x
 var before = await capture("res://build/production_facing_right.png")
 world.player.facing_left = true
 var after = await capture("res://build/production_facing_left.png")
 var camera_after: float = world.camera_x
 var changed_outside: int = 0
 for y in range(before.get_height()):
  for x in range(before.get_width()):
   if before.get_pixel(x, y) != after.get_pixel(x, y) and not Rect2i(480, 590, 48, 64).has_point(Vector2i(x, y)):
    changed_outside += 1
 print("GIRO_RENDER cámara antes=", camera, " después=", world.camera_x, " píxeles externos modificados=", changed_outside)
 scene.settings_dialog()
 await capture("res://build/production_settings.png")
 scene.controls_dialog()
 event = InputEventKey.new()
 event.physical_keycode = KEY_W
 event.pressed = true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await capture("res://build/production_controls.png")
 event = event.duplicate()
 event.pressed = false
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 scene.close_modal()
 scene.retro_screen = true
 scene.screen_filter.visible = true
 await capture("res://build/production_retro.png")
 scene.queue_free()
 await process_frame
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
  DirAccess.remove_absolute(gm.save_path + suffix)
 var report = {"jump_feet_y": jump_y, "ground_y": 520, "camera_before_turn": camera, "camera_after_turn": camera_after, "changed_pixels_outside_character": changed_outside}
 var file = FileAccess.open("res://build/production_visual_report.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 quit(0 if jump_y < 490 and changed_outside == 0 and camera_after == camera else 1)
