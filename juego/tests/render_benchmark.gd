extends SceneTree
var world: Node2D
var physics_count: int = 0

func _initialize() -> void:
 call_deferred("run")

func step() -> void:
 if not is_instance_valid(world):
  return
 physics_count += 1
 var player = world.player
 var axis: float = 1 if physics_count % 320 < 160 else -1
 # Recorrer todos los módulos para medir también parallax, trampas y actores.
 player.position.x = 80 + fposmod(physics_count * 20.0, world.map_width - 180)
 player.previous_position.x = player.position.x
 player.health = 100
 player.simulate(1.0 / 60.0, axis, physics_count % 80 == 0)

func run() -> void:
 root.size = Vector2i(1280, 800)
 var gm = root.get_node("GameManager")
 gm.save_path = "user://verdaria_test_benchmark.json"
 gm.branch = "B"
 gm.level = 7
 gm.reset_physical()
 gm.audio_enabled = false
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 scene.show_game()
 world = scene.world
 world.persist_physical = false
 world.player.set_physics_process(false)
 physics_frame.connect(step)
 var samples: Array = []
 var cpu: Array = []
 var draw_calls: int = 0
 var last: int = Time.get_ticks_usec()
 for i in range(420):
  await process_frame
  var now: int = Time.get_ticks_usec()
  if i >= 60:
   samples.append(float(now - last) / 1000.0)
   cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
   draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
  last = now
 physics_frame.disconnect(step)
 var average: float = 0
 var cpu_average: float = 0
 for value in samples:
  average += value / samples.size()
 for value in cpu:
  cpu_average += value / cpu.size()
 samples.sort()
 var metrics = {"frames": samples.size(), "average_frame_ms": snappedf(average, 0.01), "estimated_fps": snappedf(1000.0 / maxf(average, 0.01), 0.1), "p95_frame_ms": snappedf(samples[int(samples.size() * 0.95)], 0.01), "average_process_ms": snappedf(cpu_average, 0.001), "max_draw_calls": draw_calls, "renderer": "Compatibility · 1280x800", "note": "Medición local de esta máquina; no garantiza el rendimiento de otros equipos o navegadores."}
 var file = FileAccess.open("res://build/render-metrics.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(metrics, "  "))
 file.close()
 print("VERDARIA RENDER: ", JSON.stringify(metrics))
 scene.queue_free()
 await process_frame
 DirAccess.remove_absolute(gm.save_path)
 quit()
