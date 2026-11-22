extends SceneTree
var gm: Node
var main: Control
var world: Node2D

func _initialize() -> void:
 call_deferred("run")

func stage(branch: String, level: int) -> void:
 gm.branch = branch
 gm.level = level
 gm.completed = []
 gm.world_flags = {}
 gm.decisions = {}
 gm.finished = false
 gm.characters = gm.narrative.initial_states()
 gm.seeds = 12
 gm.seeds_earned = 12
 gm.reset_physical()
 main.show_game()
 world = main.world
 world.persist_physical = false
 world.set_physics_process(false)
 world.player.set_physics_process(false)
 world.set_process(false)
 world.gameplay_clock = 2.5

func place(point: Vector2, camera: float) -> void:
 world.player.travel(point)
 for i in range(7):
  await physics_frame
  world.player.simulate(1.0 / 60.0, 0)
 world.camera_x = camera
 world.player.previous_position = world.player.position
 world.player.message = ""
 world.player.status_timer = 0
 world.scenery.scroll = camera
 world.scenery.clock = world.gameplay_clock
 world.update_nearby()

func capture(name: String) -> void:
 world.scenery.queue_redraw()
 world.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/premium_%s.png" % name)

func run() -> void:
 root.size = Vector2i(1280, 800)
 gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_premium_preview.json"
 gm.audio_enabled = false
 gm.new_game()
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 for branch in ["A", "B", "C"]:
  stage(branch, 3)
  var node: Dictionary = world.map_data.restoration[1] if branch == "B" else world.map_data.restoration[0]
  await place(node.point + Vector2(40, 0), maxf(0, node.point.x - 250))
  world.player.health = 60
  await capture(branch + "_antes")
  world.try_restore()
  for pulse in world.restoration_pulses:
   pulse.time = 0.4
  await capture(branch + "_despues")
 for level in [2, 3]:
  stage("C", level)
  var box: Dictionary = world.surfaces.filter(func(surface): return surface.style == "bonus")[1 if level == 2 else 0]
  var point: Vector2 = Vector2(box.rect.get_center().x, box.rect.position.y + 144)
  await place(point, clampf(point.x - 420, 0, world.map_width - 960))
  await capture("caja_nivel_%d" % level)
 stage("C", 3)
 for site in gm.layout().sites:
  gm.interact(site.id, site.action)
 await place(Vector2(world.map_width - 96, 520), world.map_width - 960)
 world.check_goal()
 await capture("bandera")
 main.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 print("VERDARIA: nueve vistas de reconstrucción, cajas y bandera")
 quit()
