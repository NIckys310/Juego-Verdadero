extends SceneTree
const Terrain = preload("res://scripts/terrain_layout.gd")
const Player = preload("res://scripts/player_controller.gd")

func _initialize() -> void:
 var stages: Array = []
 for branch in ["A", "B", "C"]:
  for level in range(1, 11):
   if level == 1 and branch != "A":
    continue
   var data = Terrain.stage(branch, level)
   var highest: float = 520
   for surface in data.surfaces:
    highest = minf(highest, surface.rect.position.y)
   stages.append({"branch": branch, "level": level, "width": data.width, "biome": data.biome, "surfaces": data.surfaces.size(), "moving_platforms": data.moving.size(), "hazards": data.hazards.size(), "enemies": data.enemies.size(), "pickups": data.pickups.size(), "tasks": data.tasks.size(), "checkpoints": data.checkpoints.size(), "restoration_nodes": data.restoration.size(), "highest_platform": highest, "device": data.device.get("kind", "none")})
 var report = {"physics_hz": Engine.physics_ticks_per_second, "body": [Player.BODY_SIZE.x, Player.BODY_SIZE.y], "jump_height_theoretical": Player.JUMP_SPEED * Player.JUMP_SPEED / (2 * Player.GRAVITY), "jump_duration_same_height": 2 * Player.JUMP_SPEED / Player.GRAVITY, "stages": stages}
 var file = FileAccess.open("res://build/v2_design_audit.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 print("VERDARIA: medidas de 28 mapas exportadas")
 quit()
