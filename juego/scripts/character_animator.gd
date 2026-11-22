extends RefCounted
## El ciclo sigue la distancia recorrida; girar o esperar no genera pasos.
const WALK_CYCLE = ["right", "walk", "stand", "walk"]
const RUN_CYCLE = ["run", "walk", "run", "stand"]

static func pose(player: CharacterBody2D, active: bool, exiting: bool, work: Dictionary, clock: float) -> String:
 if player.health <= 0:
  return "sit"
 if exiting:
  return "wave"
 if not work.is_empty():
  return "crouch" if work.action == "rubble" else "talk%d" % (int(clock * 8) % 5)
 if not player.is_on_floor():
  return "jump"
 if not active or absf(player.velocity.x) < 8:
  return "right"
 var cycle: Array = RUN_CYCLE if player.running else WALK_CYCLE
 var stride: float = 48.0 if player.running else 56.0
 return cycle[int(fposmod(player.stride_distance, stride) / stride * cycle.size())]
