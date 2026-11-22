extends RefCounted
## Motor analítico local. La ruta queda fija; el perfil adapta cada mapa.
const WEIGHTS = {
 "explorar_alturas": {"A": 1, "B": 1, "C": 1},
 "accionar_mecanismo": {"A": 1, "B": 2, "C": 1},
 "descubrir_recuerdo": {"A": 2, "B": 1, "C": 1},
 "neutralizar_amenaza": {"A": 0, "B": 0, "C": 1},
 "rebrotar": {"A": 3, "B": 0, "C": 0},
 "reactivar": {"A": 0, "B": 3, "C": 0},
 "reforzar": {"A": 0, "B": 0, "C": 3},
 "reparar": {"A": 5, "B": 0, "C": 0},
 "vender": {"A": 0, "B": 5, "C": 0},
 "fortificar": {"A": 0, "B": 0, "C": 5},
 "restaurar": {"A": 3, "B": 0, "C": 0},
 "reciclar": {"A": 1, "B": 3, "C": 0},
 "defender": {"A": 0, "B": 0, "C": 3},
 "salvar_personaje": {"A": 4, "B": 0, "C": 1},
 "abandonar_personaje": {"A": 0, "B": 2, "C": 1},
 "compartir_suministros": {"A": 2, "B": 3, "C": 0},
 "reservar_suministros": {"A": 0, "B": 2, "C": 1},
 "pactar_defensa": {"A": 0, "B": 1, "C": 4},
 "rechazar_pacto": {"A": 1, "B": 1, "C": 0}
}

func analyze(history: Array, locked_branch: String) -> Dictionary:
 var scores = {"A": 0, "B": 0, "C": 0}
 for event in history:
  var weights: Dictionary = WEIGHTS.get(event.get("action", ""), {})
  for key in weights:
   scores[key] += weights[key]
 var dominant = "A"
 for key in ["B", "C"]:
  if scores[key] > scores[dominant]:
   dominant = key
 var total: float = max(1, scores.A + scores.B + scores.C)
 return {"scores": scores, "dominant": dominant,
  "confidence": float(scores[dominant]) / total,
  "branch": locked_branch if not locked_branch.is_empty() else dominant,
  "reason": "La decisión del refugio fija la ruta. Las acciones posteriores adaptan los encargos y el entorno."}

func generate(history: Array, branch: String, level: int, world_seed: int) -> Dictionary:
 var previous_history: Array = history.filter(func(event): return int(event.get("level", 1)) < level)
 var profile = analyze(previous_history, branch)
 var rng = RandomNumberGenerator.new()
 rng.seed = world_seed + level * 7919
 var actions: Array = ["restaurar", "reciclar", "defender"]
 var preferred: String = {"A": "restaurar", "B": "reciclar", "C": "defender"}.get(branch, "restaurar")
 var sites: Array = []
 var count: int = 4 + mini(level / 3, 3)
 for i in range(count):
  var action: String = preferred if i < 2 else actions[rng.randi_range(0, 2)]
  sites.append({"id": i, "action": action,
   "x": 120.0 + i * (720.0 / maxf(1, count - 1)) + rng.randf_range(-8, 8),
   "y": 480.0 + (i % 2) * 32.0})
 # Una acción del perfil dominante aparece en el siguiente entorno.
 if sites.size() > 2:
  sites[2].action = {"A": "restaurar", "B": "reciclar", "C": "defender"}[profile.dominant]
 # Materiales accesibles para la decisión de Ivo, cualquiera que sea la ruta.
 sites[-1].action = "reciclar"
 return {"sites": sites, "required": mini(3 + level / 4, count), "profile": profile}
