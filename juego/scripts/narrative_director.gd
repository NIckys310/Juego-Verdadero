extends RefCounted
## Reglas explícitas de causa/efecto. No cambia la ruta fijada en el refugio.
const DECISIONS = {
 "elena_rescue": {"level": 2, "character": "medic", "default": "abandonar", "options": ["rescatar", "abandonar"]},
 "ivo_supplies": {"level": 4, "character": "nerd", "default": "reservar", "options": ["compartir", "reservar"]},
 "marcos_pact": {"level": 5, "character": "boss", "default": "rechazar", "options": ["pactar", "rechazar"]}
}

func initial_states() -> Dictionary:
 return {
  "medic": {"status": "disponible", "trust": 0},
  "nerd": {"status": "disponible", "trust": 0},
  "boss": {"status": "disponible", "trust": 0}
 }

func pending(level: int, decisions: Dictionary) -> String:
 for id in DECISIONS:
  if DECISIONS[id].level == level and not decisions.has(id):
   return id
 return ""

func outcome(id: String, choice: String) -> Dictionary:
 match id:
  "elena_rescue":
   if choice == "rescatar":
    return {"character": "medic", "status": "rescatada", "trust": 2, "action": "salvar_personaje", "summary": "Rescataste a Elena. Volverá para ayudar con el agua y la comunidad."}
   return {"character": "medic", "status": "desaparecida", "trust": -2, "action": "abandonar_personaje", "summary": "Dejaste atrás a Elena. No estará en los siguientes encuentros; tendrás que resolver el agua sin su ayuda."}
  "ivo_supplies":
   if choice == "compartir":
    return {"character": "nerd", "status": "aliado", "trust": 2, "action": "compartir_suministros", "summary": "Compartiste materiales con Ivo. Preparará herramientas para los niveles tecnológicos y energéticos."}
   return {"character": "nerd", "status": "distante", "trust": -1, "action": "reservar_suministros", "summary": "Reservaste los materiales. Ivo seguirá en Verdaria, pero no ofrecerá apoyo técnico."}
  "marcos_pact":
   if choice == "pactar":
    return {"character": "boss", "status": "aliado", "trust": 2, "action": "pactar_defensa", "summary": "Pactaste con Marcos. Su equipo ayudará a asegurar los accesos."}
   return {"character": "boss", "status": "distante", "trust": -1, "action": "rechazar_pacto", "summary": "Rechazaste el pacto. El control de las rutas dependerá de ti."}
 return {}

func roster(level: int, states: Dictionary) -> Array:
 var ids: Array = {
  1: ["medic", "nerd", "boss"], 2: ["medic"], 3: ["medic", "nerd"],
  4: ["nerd"], 5: ["boss"], 6: ["medic", "boss"], 7: ["nerd"],
  8: ["boss", "medic"], 9: ["medic", "nerd", "boss"], 10: ["medic", "nerd", "boss"]
 }.get(level, [])
 return ids.filter(func(id): return states[id].status != "desaparecida")

func consequences(branch: String, level: int, states: Dictionary) -> Dictionary:
 var modifier: int = 0
 var notes: Array = []
 var reward = {"comunidad": 0, "materiales": 0, "seguridad": 0}
 if level in [3, 6] and states.medic.status == "rescatada":
  modifier -= 1
  reward.comunidad = 2
  notes.append("Elena está aquí gracias al rescate: aporta suministros y reduce una tarea.")
 elif level == 3 and states.medic.status == "desaparecida":
  modifier += 1
  notes.append("Elena no volvió tras ser abandonada: necesitas una tarea adicional sin su ayuda.")
 if level in [7, 8] and states.nerd.status == "aliado":
  modifier -= 1
  reward.materiales = 2
  notes.append("Ivo devuelve tu ayuda: herramientas recuperadas y una tarea menos.")
 if level in [6, 8] and states.boss.status == "aliado":
  modifier -= 1
  reward.seguridad = 2
  notes.append("El pacto con Marcos asegura los accesos: una tarea menos y apoyo defensivo.")
 if notes.is_empty():
  notes.append("Sin apoyo especial en este lugar. Las decisiones anteriores permanecen guardadas.")
 var mission: String = ""
 if branch == "A" and level == 3 and states.medic.status == "desaparecida":
  mission = "Purificar el agua sin Elena · Recuperar filtros de emergencia"
 elif branch in ["B", "C"] and level == 5 and states.boss.status != "aliado":
  mission = "Restaurar la radio y negociar con Marcos" if branch == "B" else "Organizar la milicia y negociar con Marcos"
 return {"modifier": modifier, "notes": notes, "reward": reward, "mission": mission}

func dialogue(id: String, level: int, states: Dictionary, decisions: Dictionary) -> Dictionary:
 var decision_id = pending(level, decisions)
 if not decision_id.is_empty() and DECISIONS[decision_id].character == id:
  match decision_id:
   "elena_rescue":
    return {"decision": decision_id, "text": "Elena quedó atrapada al derrumbarse una estructura. Puedes abrir una salida ahora. Si te vas sin ayudarla, desaparecerá de los siguientes encuentros.", "choices": [["Rescatar a Elena", "rescatar"], ["Dejarla atrás", "abandonar"]]}
   "ivo_supplies":
    return {"decision": decision_id, "text": "Ivo necesita dos materiales para reparar herramientas. Si compartes, podrá ayudarte en los niveles 7 y 8. Si reservas tus recursos, no contará contigo.", "choices": [["Compartir 2 materiales", "compartir"], ["Reservar mis materiales", "reservar"]]}
   "marcos_pact":
    return {"decision": decision_id, "text": "Marcos propone coordinar vigilancia e intercambio. Aceptar su pacto dará apoyo en los niveles 6 y 8; rechazarlo deja los accesos bajo tu responsabilidad.", "choices": [["Pactar con Marcos", "pactar"], ["Rechazar el pacto", "rechazar"]]}
 var text: String = ""
 match id:
  "medic":
   text = "Aquí todavía hay calma. Podemos reconstruir el refugio antes de decidir el futuro de Verdaria." if level == 1 else "No olvidé que me sacaste de allí. Estoy preparando agua y suministros para la comunidad."
  "nerd":
   text = "Entre estas ruinas quedan herramientas útiles. Buscaré una manera de recuperarlas."
   if states.nerd.status == "aliado":
    text = "Compartiste cuando lo necesitaba. Mis herramientas son también tuyas."
   elif states.nerd.status == "distante":
    text = "Conservo mis herramientas. Tendrás que reparar tu equipo por tu cuenta."
  "boss":
   text = "Comercio y defensa necesitan organización. Cuando llegue el momento, hablaremos."
   if states.boss.status == "aliado":
    text = "Nuestro pacto sigue en pie. Mi equipo está asegurando los accesos."
   elif states.boss.status == "distante":
    text = "Elegiste trabajar por tu cuenta. Mi equipo no intervendrá."
 return {"decision": "", "text": text, "choices": []}

func ending(states: Dictionary) -> String:
 var lines: Array = []
 lines.append("Elena: " + ("a salvo, reconstruye la comunidad." if states.medic.status == "rescatada" else "desaparecida tras quedar atrás." if states.medic.status == "desaparecida" else "sin encuentro registrado."))
 lines.append("Ivo: " + ("colabora contigo en la recuperación tecnológica." if states.nerd.status == "aliado" else "trabaja por su cuenta."))
 lines.append("Marcos: " + ("mantiene el pacto de vigilancia." if states.boss.status == "aliado" else "mantiene a su equipo al margen."))
 return "\n".join(lines)
