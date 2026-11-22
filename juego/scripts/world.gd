extends Node2D
signal nearby_changed(text: String)
signal home_requested
signal character_requested(id: String)
signal interaction_changed(context: Dictionary)
signal exit_requested
const Catalog = preload("res://scripts/asset_catalog.gd")
const Player = preload("res://scripts/player_controller.gd")
const Terrain = preload("res://scripts/terrain_layout.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Enemy = preload("res://scripts/platform_enemy.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const CharacterAnimator = preload("res://scripts/character_animator.gd")
const LABELS = {"restaurar": "Restaurar", "reciclar": "Reciclar", "defender": "Fortificar", "bridge": "Reparar puente", "rubble": "Despejar escombros"}
var catalog = Catalog.new()
var player: Player
var sites: Array = []
var npcs: Array = []
var nearby: int = -1
var nearby_npc: String = ""
var active: bool = true:
 set(value):
  active = value
  PlayerInput.discard_edges()
  if is_instance_valid(player):
   player.enabled = value and not GameManager.finished and not exiting
var facing_left: bool = false
var animation_time: float = 0.0
var background: Texture2D
var foreground: Texture2D
var surfaces: Array = []
var terrain_root: Node2D
var terrain_key: String = ""
var landing_time: float = 0.0
var landing_point: Vector2
var damage_flash: float = 0.0
var scenery: Scenery
var audio: Audio
var work_target: Dictionary = {}
var work_progress: float = 0.0
var work_auto: bool = false
var step_distance: float = 0
var last_x: float = 80
var save_queued: bool = false
var stage_key: String = ""
var persist_physical: bool = true
var last_context: Dictionary = {}
var feedback_text: String = ""
var feedback_timer: float = 0.0
var map_data: Dictionary = {}
var map_width: float = 1920
var camera_x: float = 0
var moving_platforms: Array = []
var enemies: Array = []
var projectiles: Array = []
var particles: Array = []
var gameplay_clock: float = 0
var exiting: bool = false
var exit_timer: float = 0
var exit_sent: bool = false
var exit_stage: String = ""
var restoration_pulses: Array = []
var block_bumps: Dictionary = {}
var last_health: int = 100
var stage_entry_time: float = 0

func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 catalog.warm_characters()
 scenery = Scenery.new()
 scenery.show_behind_parent = true
 add_child(scenery)
 audio = Audio.new()
 add_child(audio)
 player = Player.new()
 add_child(player)
 player.respawned.connect(func():
  camera_x = CameraRig.reset_at(player.position.x, map_width)
  projectiles = []
  last_x = player.position.x)
 player.landed.connect(func(_drop, damage):
  landing_point = player.position
  landing_time = 0.25
  if damage > 0:
   damage_flash = 0.4
  audio.play_effect("land"))
 player.jumped.connect(func():
  audio.play_effect("jump")
  GameManager.mark_tutorial("jump"))
 player.condition_changed.connect(func(_health, _message):
  if persist_physical:
   GameManager.capture_physical(player.health, player.checkpoint)
   queue_physical_save()
  if player.health < last_health:
   audio.play_effect("hurt")
  last_health = player.health)
 rebuild()
 restore_physical()

func queue_physical_save() -> void:
 if not save_queued:
  save_queued = true
  call_deferred("flush_physical_save")

func flush_physical_save() -> void:
 if not is_inside_tree() or not persist_physical:
  return
 save_queued = false
 GameManager.save_game()

func restore_physical() -> void:
 var data: Dictionary = GameManager.physical
 var point = Vector2(80, Terrain.ground(GameManager.level))
 if int(data.level) == GameManager.level:
  point = Vector2(data.checkpoint_x, data.checkpoint_y)
  player.health = int(data.health)
  if player.health <= 0:
   player.respawn_timer = 0.2
 player.checkpoint = point
 player.position = point
 player.previous_position = point
 player.velocity = Vector2.ZERO
 player.highest_feet = point.y
 last_health = player.health
 player.airborne = false
 player.reset_platform_frames = 2
 player.reset_physics_interpolation()
 last_x = point.x

func rebuild_terrain() -> void:
 if is_instance_valid(terrain_root):
  remove_child(terrain_root)
  terrain_root.queue_free()
 terrain_root = Node2D.new()
 add_child(terrain_root)
 surfaces = Terrain.build(GameManager.branch, GameManager.level, GameManager.flags(), GameManager.characters)
 moving_platforms = []
 for surface in surfaces:
  add_surface(surface.rect, surface.one_way)
 var mobile: Array = map_data.moving.duplicate()
 if GameManager.flags().get("device", false) and map_data.device.has("lift"):
  mobile.append(map_data.device.lift)
 for item in mobile:
  var body = AnimatableBody2D.new()
  var collision = CollisionShape2D.new()
  var box = RectangleShape2D.new()
  box.size = item.rect.size
  collision.shape = box
  collision.one_way_collision = true
  collision.one_way_collision_margin = 4.0
  body.position = item.rect.get_center() + item.axis * sin(item.phase)
  body.add_child(collision)
  terrain_root.add_child(body)
  moving_platforms.append({"body": body, "data": item})
 for rect in [Rect2(-20, -200, 20, 1000), Rect2(map_width, -200, 20, 1000)]:
  add_surface(rect, false)

func add_surface(rect: Rect2, one_way: bool) -> void:
  var wall = StaticBody2D.new()
  var collision = CollisionShape2D.new()
  var box = RectangleShape2D.new()
  box.size = rect.size
  collision.shape = box
  collision.one_way_collision = one_way
  collision.one_way_collision_margin = 5.0
  wall.position = rect.get_center()
  wall.add_child(collision)
  terrain_root.add_child(wall)

func rebuild() -> void:
 var stage = "refuge:1" if GameManager.level == 1 else "%s:%d" % [GameManager.branch, GameManager.level]
 map_data = Terrain.stage(GameManager.branch, GameManager.level)
 map_width = map_data.width
 audio.set_theme(GameManager.branch)
 var terrain_flags = {"bridge": GameManager.flags().get("bridge", false), "rubble": GameManager.flags().get("rubble", false), "restored": GameManager.flags().get("restored", {}), "restoration_modes": GameManager.flags().get("restoration_modes", {}), "device": GameManager.flags().get("device", false)}
 var key = stage + JSON.stringify(terrain_flags) + JSON.stringify(GameManager.characters)
 if key != terrain_key:
  terrain_key = key
  rebuild_terrain()
  scenery.background = catalog.texture(catalog.landscape_path(GameManager.branch, GameManager.level))
  scenery.background_far = catalog.texture(catalog.landscape_path(GameManager.branch, GameManager.level, "cielo"))
  scenery.background_near = catalog.texture(catalog.landscape_path(GameManager.branch, GameManager.level, "frente"))
  scenery.surfaces = surfaces
  scenery.branch = GameManager.branch
  scenery.level = GameManager.level
  scenery.states = GameManager.characters.duplicate(true)
  scenery.map_data = map_data
  scenery.update_palette()
 if stage != stage_key:
  stage_key = stage
  work_target = {}
  work_progress = 0
  restore_physical()
  camera_x = CameraRig.reset_at(player.position.x, map_width)
  gameplay_clock = 0
  stage_entry_time = 2.6
  particles = []
  projectiles = []
  restoration_pulses = []
  block_bumps = {}
  exiting = false
  exit_sent = false
  for enemy in enemies:
   remove_child(enemy)
   enemy.queue_free()
  enemies = []
  for i in range(map_data.enemies.size()):
   var enemy = Enemy.new()
   enemy.configure(map_data.enemies[i], i)
   enemy.shot.connect(func(origin, speed):
    projectiles.append({"position": origin, "velocity": speed, "time": 3.0})
    audio.play_effect("work"))
   enemy.dead = GameManager.flags().get("defeated", {}).get(str(i), false)
   add_child(enemy)
   enemies.append(enemy)
 if GameManager.level == 1:
  sites = [{"id": 0, "action": "hogar", "x": 1420, "y": Terrain.ground(1)}]
 else:
  sites = GameManager.layout().sites
  for i in range(sites.size()):
   var point = Terrain.task_position(i, GameManager.branch, GameManager.level)
   sites[i].x = point.x
   sites[i].y = point.y
 for i in range(map_data.checkpoints.size()):
  var point: Vector2 = map_data.checkpoints[i]
  sites.append({"id": -1 - i, "action": "descansar", "x": point.x, "y": point.y})
 if GameManager.branch == "C":
  for node in map_data.restoration:
   if GameManager.flags().get("restored", {}).get(str(node.id), false) and GameManager.flags().get("restoration_modes", {}).get(str(node.id), "safe") == "safe":
    sites.append({"id": -100 - node.id, "action": "descansar", "x": node.point.x, "y": node.point.y})
 if GameManager.level == 2:
  var gap = Terrain.gap_bounds(GameManager.branch)
  var rubble = Terrain.rubble_position(GameManager.branch)
  if not GameManager.flags().get("bridge", false):
   sites.append({"id": -3, "action": "bridge", "x": gap.x - 35, "y": 520})
  if not GameManager.flags().get("rubble", false):
   sites.append({"id": -4, "action": "rubble", "x": rubble.x - 38, "y": rubble.y})
 npcs = []
 var roster: Array = GameManager.narrative.roster(GameManager.level, GameManager.characters)
 for i in range(roster.size()):
  var point = Terrain.npc_position(i, GameManager.level, GameManager.branch)
  if roster[i] == "medic" and GameManager.level == 2:
   point = Terrain.rescue_position(GameManager.branch) if GameManager.characters.medic.status == "disponible" else Vector2(map_width - 360, 520)
  npcs.append({"id": roster[i], "x": point.x, "y": point.y})
 nearby = -1
 nearby_npc = ""
 queue_redraw()

func key_down(code: Key) -> bool:
 return Input.is_physical_key_pressed(code)

func _physics_process(delta: float) -> void:
 player.enabled = active and not GameManager.finished and not exiting
 if not active or GameManager.finished:
  return
 if exiting:
  player.previous_position = player.position
  player.position.y = move_toward(player.position.y, 520, 220 * delta)
  exit_timer -= delta
  if exit_timer <= 0 and not exit_sent:
   exit_sent = true
   call_deferred("finish_exit")
  return
 gameplay_clock += delta
 update_platforms()
 update_adventure(delta)
 if absf(player.position.x - last_x) > 0.1 and player.is_on_floor():
  GameManager.mark_tutorial("move")
  step_distance += absf(player.position.x - last_x)
  if step_distance > 64:
   step_distance = 0
   audio.play_effect("step")
 last_x = player.position.x
 update_work(delta)
 update_nearby()
 check_goal()

func _process(delta: float) -> void:
 if active:
  animation_time += delta
  stage_entry_time = maxf(0, stage_entry_time - delta)
  landing_time = maxf(0, landing_time - delta)
  damage_flash = maxf(0, damage_flash - delta)
  feedback_timer = maxf(0, feedback_timer - delta)
  var fraction = Engine.get_physics_interpolation_fraction()
  var visual_x = lerpf(player.previous_position.x, player.position.x, fraction)
  var reduced: bool = get_tree().current_scene != null and get_tree().current_scene.get("reduce_motion") == true
  scenery.reduced_motion = reduced
  camera_x = CameraRig.follow(camera_x, visual_x, map_width)
  for particle in particles:
   particle.time -= delta
   particle.position += particle.velocity * delta
   particle.velocity.y += 350 * delta
  particles = particles.filter(func(particle): return particle.time > 0)
  for pulse in restoration_pulses:
   pulse.time += delta
  restoration_pulses = restoration_pulses.filter(func(pulse): return pulse.time < 0.8)
  for id in block_bumps.keys():
   block_bumps[id] = maxf(0, block_bumps[id] - delta)
 scenery.block_bumps = block_bumps
 scenery.scroll = camera_x
 scenery.clock = gameplay_clock
 scenery.queue_redraw()
 queue_redraw()

func at_goal() -> bool:
 return player.health > 0 and hero_bounds().intersects(Rect2(map_width - 124, 404, 56, 116))

func check_goal() -> void:
 if exiting or not active or not work_target.is_empty() or not at_goal() or not GameManager.can_advance() or guardian_alive():
  return
 exiting = true
 exit_stage = stage_key
 exit_timer = 0.85
 exit_sent = false
 player.enabled = false
 player.velocity = Vector2.ZERO
 burst(Vector2(map_width - 96, 420), Color("ffe09b"))
 audio.play_effect("success")
 notify("Verdaria avanza · Camino completado")

func finish_exit() -> void:
 if is_inside_tree() and exiting and stage_key == exit_stage and not GameManager.finished:
  exit_requested.emit()

func nearby_restoration() -> Dictionary:
 var best: Dictionary = {}
 var distance: float = 72
 for node in map_data.get("restoration", []):
  var candidate: float = player.position.distance_to(node.point)
  if absf(player.position.y - node.point.y) < 14 and candidate < distance:
   best = node
   distance = candidate
 return best

func restoration_context() -> Dictionary:
 var node = nearby_restoration()
 var action: String = {"A": "Rebrotar", "B": "Reactivar", "C": "Reforzar"}.get(GameManager.branch, "Reconstruir")
 var result = {"enabled": false, "button": action + " [Q]", "hint": "Busca un núcleo de reconstrucción"}
 if node.is_empty():
  return result
 if GameManager.flags().get("restored", {}).get(str(node.id), false):
  result.hint = "Este tramo ya está reconstruido"
  return result
 result.button = action + " [Q] · 3"
 result.enabled = active and not exiting and player.health > 0 and player.is_on_floor() and work_target.is_empty() and GameManager.seeds >= node.cost
 result.hint = "Q · Paso seguro: 3 semillas / R · Ruta elevada: 5" if result.enabled else "Necesitas 3 semillas" if GameManager.seeds < node.cost else "Aterriza junto al núcleo para reconstruir"
 return result

func try_restore(mode: String = "safe") -> void:
 if not restoration_context().enabled or (mode == "high" and GameManager.seeds < 5):
  return
 var node = nearby_restoration().duplicate(true)
 if not GameManager.restore_section(node.id, mode):
  return
 var accent: Color = {"A": Color("96e89d"), "B": Color("83d7ed"), "C": Color("ffd084")}[GameManager.branch]
 restoration_pulses.append({"point": node.point - Vector2(0, 24), "time": 0.0, "color": accent})
 burst(node.point - Vector2(0, 25), accent)
 if GameManager.branch == "A" and mode == "safe":
  player.health = mini(100, player.health + 20)
  player.message = "Pasarela viva · +20 vida"
  player.status_timer = 2.5
  player.condition_changed.emit(player.health, player.message)
 elif GameManager.branch == "C" and mode == "safe":
  player.set_checkpoint(node.point)
 notify({"A": "El entorno rebrota · Pasarela viva y +20 vida", "B": "Maquinaria reactivada · Trampas del tramo apagadas", "C": "Paso reforzado · Nuevo punto de retorno"}[GameManager.branch])
 if mode == "high":
  notify("Ruta elevada reconstruida · Sube para encontrar un recuerdo y 6 semillas")
 audio.play_effect("rest")
 update_nearby()

func guardian_alive() -> bool:
 return enemies.any(func(enemy): return enemy.kind == "guardian" and not enemy.dead)

func update_platforms() -> void:
 for entry in moving_platforms:
  var data: Dictionary = entry.data
  entry.body.position = data.rect.get_center() + data.axis * sin(gameplay_clock * TAU / data.period + data.phase)

func hero_bounds() -> Rect2:
 return Rect2(player.position - Vector2(Player.BODY_SIZE.x / 2, Player.BODY_SIZE.y), Player.BODY_SIZE)

func hazard_rect(hazard: Dictionary) -> Rect2:
 var rect: Rect2 = hazard.rect
 if hazard.kind == "saw":
  rect.position.x += sin(gameplay_clock * 2 + hazard.phase) * hazard.range
 return rect

func hazard_active(hazard: Dictionary) -> bool:
 if GameManager.flags().get("device", false) and not map_data.device.is_empty():
  if map_data.device.kind == "water" and hazard.kind in ["water", "lava", "pit"] and hazard.rect.intersects(map_data.device.zone):
   return false
  if map_data.device.kind == "shield" and hazard.get("section", -1) == map_data.device.section and hazard.kind in ["spikes", "steam", "saw"]:
   return false
 if GameManager.branch == "B" and hazard.kind in ["steam", "saw", "spikes"] and GameManager.flags().get("restored", {}).get(str(hazard.get("section", -1)), false) and GameManager.flags().get("restoration_modes", {}).get(str(hazard.get("section", -1)), "safe") == "safe":
  return false
 return hazard.kind != "steam" or fmod(gameplay_clock + hazard.phase, 3.2) > 1.8

func burst(point: Vector2, color: Color) -> void:
 for i in range(6):
  particles.append({"position": point, "velocity": Vector2((i - 2.5) * 42, -110 - (i % 3) * 30), "time": 0.55, "color": color})

func update_adventure(delta: float) -> void:
 player.environment_push = 0
 player.environment_lift = 0
 if GameManager.flags().get("device", false) and not map_data.device.is_empty() and map_data.device.kind == "wind" and map_data.device.zone.has_point(player.position - Vector2(0, 20)):
  player.environment_lift = -2100
 player.wind_push = 35 * sin(gameplay_clock * 0.8) if map_data.biome in ["windmill", "hill", "radio"] else 0
 for decor in map_data.decor:
  if decor.kind == "conveyor" and player.is_on_floor() and absf(player.position.y - decor.point.y) < 4 and player.position.x > decor.point.x and player.position.x < decor.point.x + decor.width:
   player.environment_push = decor.speed
 if player.health <= 0:
  return
 var bounds = hero_bounds()
 for hazard in map_data.hazards:
  if hazard.kind == "pit" or not hazard_active(hazard):
   continue
  if bounds.intersects(hazard_rect(hazard)):
   var fatal: bool = hazard.kind in ["lava", "water"]
   player.take_damage(100 if fatal else 25, "Lava" if hazard.kind == "lava" else "Agua profunda" if hazard.kind == "water" else "Trampa · −25 vida")
   damage_flash = 0.45
   cancel_work("Trabajo interrumpido por daño")
 for enemy in enemies:
  if enemy.dead or absf(enemy.position.x - player.position.x) > 1100:
   continue
  enemy.simulate(delta, player.position)
  if not bounds.intersects(enemy.bounds()) or enemy.stunned > 0:
   continue
  var top: float = enemy.bounds().position.y
  if player.velocity.y > 0 and player.previous_position.y <= top + 12:
   if enemy.stomp():
    player.velocity.y = -410
    player.airborne = true
    player.highest_feet = player.position.y
    burst(enemy.position - Vector2(0, 16), Color("ffe39b"))
    audio.play_effect("stomp")
    if enemy.dead:
     GameManager.defeat_enemy(enemy.id)
     notify("Guardián neutralizado · La salida está libre" if enemy.kind == "guardian" else "Amenaza neutralizada")
  elif player.invulnerability <= 0:
   player.take_damage(35 if enemy.kind == "guardian" and not GameManager.flags().get("device", false) else 20, "Contacto con amenaza")
   player.velocity.y = -240
   player.velocity.x = -220 if player.position.x < enemy.position.x else 220
   damage_flash = 0.4
   cancel_work("Trabajo interrumpido por daño")
 update_projectiles(delta)
 var collected: Dictionary = GameManager.flags().get("collected", {})
 for i in range(map_data.pickups.size()):
  if collected.get(str(i), false):
   continue
  var point: Vector2 = map_data.pickups[i].point
  if bounds.grow(5).has_point(point):
   GameManager.collect_pickup(i)
   burst(point, Color("ffda68"))
   audio.play_effect("pickup")
 for secret in stage_secrets():
  if bounds.grow(6).has_point(secret.point) and GameManager.collect_secret(secret.id):
   burst(secret.point, Color("c4e5ff"))
   audio.play_effect("success")
   notify("Recuerdo descubierto · Consulta el diario")
 # Golpear un bloque por abajo aplica la recompensa una sola vez.
 for i in range(player.get_slide_collision_count()):
  var hit = player.get_slide_collision(i)
  if hit.get_normal().y < 0.5:
   continue
  var point = hit.get_position() - global_position
  for surface in surfaces:
   if surface.style == "bonus" and surface.rect.grow(3).has_point(point) and not GameManager.flags().get("bonus", {}).get(surface.id, false):
    GameManager.open_bonus(surface.id)
    block_bumps[surface.id] = 0.28
    player.health = mini(100, player.health + 20)
    player.condition_changed.emit(player.health, "Provisiones · +20 vida")
    burst(surface.rect.get_center(), Color("83e19a"))
    audio.play_effect("success")
    notify("Provisiones encontradas · +20 vida y +3 semillas")

func update_work(delta: float) -> void:
 if work_target.is_empty():
  return
 var point = Vector2(work_target.x, work_target.y)
 if not player.is_on_floor() or player.health <= 0 or absf(player.velocity.x) > 10 or player.position.distance_to(point) > 52 or (not work_auto and not Input.is_action_pressed("interact")):
  cancel_work("Trabajo cancelado · Detente y vuelve a mantener E")
  return
 work_progress += delta
 if work_progress >= 1.5:
  var action: String = work_target.action
  work_target = {}
  work_progress = 0
  if action == "rescue":
   if GameManager.resolve_decision("elena_rescue", "rescatar"):
    notify("Elena está a salvo · Verdaria recuerda tu ayuda")
  else:
   if GameManager.complete_world_action(action):
    notify("Puente reparado · El paso está abierto" if action == "bridge" else "Escombros retirados · Acceso despejado")
  audio.play_effect("success")
  GameManager.mark_tutorial("work")

func update_projectiles(delta: float) -> void:
 var survivors: Array = []
 for projectile in projectiles:
  projectile.time -= delta
  var start: Vector2 = projectile.position
  var finish: Vector2 = start + projectile.velocity * delta
  if projectile.time <= 0:
   continue
  var query = PhysicsRayQueryParameters2D.create(to_global(start), to_global(finish), 1, [player.get_rid()])
  if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
   burst(finish, Color("bdad83"))
   continue
  if GameManager.flags().get("device", false) and map_data.device.get("kind", "") == "shield" and map_data.device.zone.has_point(finish):
   burst(finish, Color("9de8cc"))
   continue
  var swept = Rect2(Vector2(minf(start.x, finish.x), minf(start.y, finish.y)), Vector2(absf(finish.x - start.x), absf(finish.y - start.y))).grow(4)
  if hero_bounds().intersects(swept):
   player.take_damage(15, "Proyectil · −15 vida")
   cancel_work("Trabajo interrumpido por disparo")
   damage_flash = 0.3
   continue
  projectile.position = finish
  survivors.append(projectile)
 projectiles = survivors

func begin_work(action: String, point: Vector2) -> void:
 if not active or player.health <= 0 or not player.is_on_floor() or not work_target.is_empty() or player.position.distance_to(point) > 52:
  return
 work_target = {"action": action, "x": point.x, "y": point.y}
 work_progress = 0
 work_auto = not Input.is_action_pressed("interact")
 audio.play_effect("work")

func notify(text: String) -> void:
 feedback_text = text
 feedback_timer = 3.0

func cancel_work(reason: String = "Trabajo cancelado") -> void:
 if work_target.is_empty():
  return
 work_target = {}
 work_progress = 0
 notify(reason)

func begin_rescue() -> void:
 if not GameManager.rescue_ready() or GameManager.level != 2 or GameManager.decisions.has("elena_rescue") or not player.is_on_floor():
  return
 var point = Terrain.rescue_position(GameManager.branch)
 if player.position.distance_to(point) <= 52:
  begin_work("rescue", point)

func tutorial_text() -> String:
 if GameManager.level != 1:
  if GameManager.level == 2 and not GameManager.decisions.has("elena_rescue"):
   return "RESCATE · %s · %s · Llega hasta Elena" % ["Puente listo" if GameManager.flags().get("bridge", false) else "Repara el puente [mantén E]", "Acceso abierto" if GameManager.flags().get("rubble", false) else "Despeja escombros [mantén E]"]
  return ""
 for step in ["move", "jump", "rest", "talk"]:
  if not step in GameManager.tutorial:
   if PlayerInput.touch_mode and step in ["move", "jump"]:
    return {"move": "01 · Desliza el mando izquierdo para explorar el refugio.", "jump": "02 · Toca SALTAR. Mantén para subir; suelta para un salto corto."}[step]
   return {"move": "01 · Camina con A/D o ←/→ para explorar el refugio.", "jump": "02 · Salta con Espacio. Mantén para subir; suelta para un salto corto.", "rest": "03 · Acércate al refugio ♥ y pulsa E para guardar tu punto de retorno.", "talk": "04 · Habla con tus vecinos [E]. Luego decide el futuro de la casa."}[step]
 return "Tutorial completado · Elige qué hacer con la casa [E]."

func update_nearby() -> void:
 nearby = -1
 nearby_npc = ""
 var distance: float = 52.0
 var hint = "" if PlayerInput.touch_mode else "A/D · Mover   Espacio/W/↑ · Saltar   E · Interactuar en el suelo"
 for i in range(sites.size()):
  var site: Dictionary = sites[i]
  if site.id in GameManager.completed:
   continue
  if absf(player.position.y - float(site.y)) > 14:
   continue
  var candidate = player.position.distance_to(Vector2(site.x, site.y))
  if candidate < distance and has_clear_access(Vector2(site.x, site.y)):
   nearby = i
   distance = candidate
   hint = "E · Decidir el futuro de la casa" if site.action == "hogar" else "E · Descansar y activar refugio" if site.action == "descansar" else "E · Cruzar la meta" if site.action == "salir" else "Mantén E · " + LABELS[site.action] if site.action in ["bridge", "rubble"] else "E · " + LABELS[site.action]
 for npc in npcs:
  if absf(player.position.y - float(npc.y)) > 14:
   continue
  var candidate = player.position.distance_to(Vector2(npc.x, npc.y))
  if candidate < distance and has_clear_access(Vector2(npc.x, npc.y)):
   nearby = -1
   nearby_npc = npc.id
   distance = candidate
   hint = "E · Hablar con " + catalog.CAST[npc.id].name
 if absf(player.position.x - (map_width - 96)) < 240:
  var pending: String = GameManager.pending_decision()
  if guardian_alive():
   hint = "Neutraliza al guardián para abrir la meta"
  elif not GameManager.can_advance():
   hint = "Completa los encargos pendientes antes de cruzar la bandera"
  elif not pending.is_empty():
   hint = {"elena_rescue": "Cruzar deja a Elena atrás · Su ausencia cambiará los siguientes lugares", "ivo_supplies": "Cruzar sin compartir deja a Ivo sin apoyo", "marcos_pact": "Cruzar sin pactar deja a Marcos fuera de tu alianza"}.get(pending, "Cruzar aplica la consecuencia de dejar pendiente el encuentro")
  else:
   hint = "Toca la bandera · El siguiente tramo comienza automáticamente"
 var context = {"enabled": active and not exiting and not GameManager.finished and player.health > 0 and player.is_on_floor() and (nearby >= 0 or not nearby_npc.is_empty()), "button": "Interactuar [E]", "hint": hint, "pulse": restoration_context()}
 if not nearby_restoration().is_empty() and nearby < 0 and nearby_npc.is_empty():
  context.hint = context.pulse.hint
 elif nearby < 0 and nearby_npc.is_empty() and not exiting:
  for surface in surfaces:
   if surface.style == "bonus" and not GameManager.flags().get("bonus", {}).get(surface.id, false) and absf(player.position.x - surface.rect.get_center().x) < 40 and absf(player.position.y - (surface.rect.position.y + 144)) < 16:
    context.hint = "Salta bajo la cápsula · +3 semillas y +20 vida"
 if not work_target.is_empty():
  context.enabled = false
  context.button = "Trabajando…"
  context.hint = "Mantén E y la posición · Esc para cancelar"
 elif player.health <= 0:
  context.hint = "Volviendo al refugio…"
 elif not player.is_on_floor():
  context.hint = "Aterriza sobre una superficie para interactuar"
 elif not nearby_npc.is_empty():
  var rescue = nearby_npc == "medic" and GameManager.level == 2 and GameManager.rescue_ready() and not GameManager.decisions.has("elena_rescue")
  context.button = "Rescatar [E]" if rescue else "Hablar [E]"
  context.hint = "Mantén E · Rescatar a Elena" if rescue else hint
 elif nearby >= 0:
  var action: String = sites[nearby].action
  context.button = {"hogar": "Decidir [E]", "descansar": "Descansar [E]", "bridge": "Reparar [E]", "rubble": "Despejar [E]"}.get(action, LABELS.get(action, "Interactuar") + " [E]")
 if nearby < 0 and nearby_npc.is_empty() and not nearby_device().is_empty() and work_target.is_empty():
  var device: Dictionary = nearby_device()
  context.enabled = active and not exiting and player.health > 0 and player.is_on_floor()
  context.button = "Activar [E]"
  context.hint = "E · " + device.name
 if context != last_context:
  last_context = context.duplicate()
  nearby_changed.emit(context.hint)
  interaction_changed.emit(context)

func has_clear_access(point: Vector2) -> bool:
 var query = PhysicsRayQueryParameters2D.create(to_global(player.position - Vector2(0, 30)), to_global(point - Vector2(0, 30)), 1, [player.get_rid()])
 return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_input(event: InputEvent) -> void:
 if event.is_echo():
  return
 if active and not exiting and event.is_action_pressed("restore_safe"):
  try_restore()
  get_viewport().set_input_as_handled()
  return
 if active and not exiting and event.is_action_pressed("restore_high"):
  try_restore("high")
  get_viewport().set_input_as_handled()
  return
 if active and event.is_action_pressed("interact"):
  interact_nearest()

func interact_nearest() -> void:
 if not active or exiting or GameManager.finished or player.health <= 0 or not player.is_on_floor():
  return
 update_nearby()
 if not nearby_npc.is_empty():
  GameManager.mark_tutorial("talk")
  if nearby_npc == "medic" and GameManager.level == 2 and GameManager.rescue_ready() and not GameManager.decisions.has("elena_rescue"):
   begin_rescue()
  else:
   character_requested.emit(nearby_npc)
 elif nearby >= 0:
  var site: Dictionary = sites[nearby]
  if site.action == "hogar":
   home_requested.emit()
  elif site.action == "descansar":
   player.set_checkpoint(Vector2(site.x, site.y))
   player.heal()
   GameManager.mark_tutorial("rest")
   audio.play_effect("rest")
  elif site.action in ["bridge", "rubble"]:
   begin_work(site.action, Vector2(site.x, site.y))
  else:
   GameManager.interact(int(site.id), site.action)
   audio.play_effect("work")

 elif not nearby_device().is_empty():
  var device: Dictionary = nearby_device().duplicate(true)
  if GameManager.activate_device():
   notify(device.result)
   audio.play_effect("success")
   burst(device.point - Vector2(0, 20), Color("9de8d2"))

func nearby_device() -> Dictionary:
 if map_data.device.is_empty() or GameManager.flags().get("device", false):
  return {}
 var point: Vector2 = map_data.device.point
 if player.position.distance_to(point) <= 52 and has_clear_access(point):
  return map_data.device
 return {}

func stage_secrets() -> Array:
 var result: Array = map_data.secrets.duplicate()
 for node in map_data.restoration:
  if GameManager.flags().get("restoration_modes", {}).get(str(node.id), "safe") == "high":
   result.append({"id": "route_%d" % node.id, "point": node.raised.rect.get_center() - Vector2(0, 30)})
 return result

func character_size(pose: String) -> Vector2:
 return catalog.CHARACTER_SIZE * Vector2(1, 0.72 if pose in ["crouch", "sit"] else 1.0)

func draw_character(id: String, feet: Vector2, pose: String, _height: float, left: bool = false) -> void:
 var texture = catalog.sprite(id, pose)
 if not texture:
  return
 var dimensions = character_size(pose)
 var height: float = dimensions.y
 var width: float = dimensions.x
 var origin = feet - Vector2(width / 2.0, height)
 # Sombra y sprite comparten los pies interpolados, sin heredar el espejo.
 var shadow: PackedVector2Array = []
 for i in range(12):
  shadow.append(feet + Vector2(cos(i * TAU / 12) * 12, sin(i * TAU / 12) * 3))
 draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
 if left:
  width = -width
 draw_texture_rect(texture, Rect2(origin, Vector2(width, height)), false)

func pixel_frame(rect: Rect2, fill: Color, edge: Color) -> void:
 draw_rect(rect, Color("11162f"))
 draw_rect(rect.grow(-2), edge.darkened(0.55))
 draw_rect(rect.grow(-4), fill)
 draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2), edge, 2)
 draw_line(rect.position + Vector2(2, 2), Vector2(rect.position.x + 2, rect.end.y - 2), edge, 2)
 if rect.size.x > 160:
  for corner_x in [rect.position.x + 6, rect.end.x - 9]:
   draw_rect(Rect2(corner_x, rect.position.y + 6, 3, 3), Color("ffce63"))

func visible_point(point: Vector2, margin: float = 120) -> bool:
 return point.x >= camera_x - margin and point.x <= camera_x + 960 + margin

func _draw() -> void:
 if not is_instance_valid(player) or map_data.is_empty():
  return
 var accent: Color = {"A": Color("96e89d"), "B": Color("ffd084"), "C": Color("a5d8ff")}.get(GameManager.branch, Color("ffdc8b"))
 var font: Font = get_parent().get_theme_default_font() if get_parent() is Control else ThemeDB.fallback_font
 draw_set_transform(Vector2(-floor(camera_x), 0))
 for hazard in map_data.hazards:
  var rect = hazard_rect(hazard)
  if not visible_point(rect.get_center()):
   continue
  var disabled: bool = not hazard_active(hazard) and hazard.kind != "steam"
  if hazard.kind == "steam":
   disabled = (GameManager.branch == "B" and GameManager.flags().get("restored", {}).get(str(hazard.get("section", -1)), false) and GameManager.flags().get("restoration_modes", {}).get(str(hazard.get("section", -1)), "safe") == "safe") or (GameManager.flags().get("device", false) and map_data.device.get("kind", "") == "shield" and hazard.get("section", -1) == map_data.device.section)
  if disabled:
   draw_rect(Rect2(rect.position.x, rect.end.y - 6, rect.size.x, 6), Color("426f76"))
   draw_rect(Rect2(rect.get_center().x - 3, rect.end.y - 5, 6, 3), Color("a1eaae"))
   continue
  if hazard.kind == "spikes":
   for x in range(int(rect.position.x), int(rect.end.x), 16):
    draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 8, rect.position.y), Vector2(x + 16, rect.end.y)]), Color("d7dae5"))
    draw_line(Vector2(x + 8, rect.position.y), Vector2(x + 14, rect.end.y), Color("815a7d"), 3)
  elif hazard.kind == "saw":
   var center = rect.get_center()
   for tooth in range(8):
    var tip = center + Vector2(cos(gameplay_clock * 4 + tooth * TAU / 8), sin(gameplay_clock * 4 + tooth * TAU / 8)) * 13
    draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), Color("f58d84"))
   draw_circle(center, 11, Color("bd576b"))
   draw_circle(center, 4, Color("ffe1a2"))
  elif hazard.kind == "steam":
   draw_rect(Rect2(rect.position.x, 516, rect.size.x, 6), Color("dea35e"))
   if hazard_active(hazard):
    for i in range(6):
     var width = 26 + i % 2 * 12
     var y = 510 - fposmod(gameplay_clock * 86 + i * 20, rect.size.y)
     draw_rect(Rect2(rect.position.x + rect.size.x / 2 - width / 2, y, width, 14), Color(0.86, 0.9, 0.93, 0.65))
   elif fmod(gameplay_clock + hazard.phase, 3.2) > 1.1:
    draw_string(font, Vector2(rect.position.x + 22, 492), "!", HORIZONTAL_ALIGNMENT_LEFT, 40, 22, Color("ffca6a"))
  elif hazard.kind in ["water", "lava"]:
   var color = Color("ff945f") if hazard.kind == "lava" else Color("609dd3")
   draw_rect(rect, color.darkened(0.25))
   for x in range(int(rect.position.x), int(rect.end.x), 16):
    var y = rect.position.y + sin(gameplay_clock * 3 + x * 0.1) * 3
    draw_rect(Rect2(x, y, 16, 5), color)
 if not map_data.device.is_empty():
  var device: Dictionary = map_data.device
  var point: Vector2 = device.point
  if visible_point(point):
   var on: bool = GameManager.flags().get("device", false)
   pixel_frame(Rect2(point - Vector2(18, 38), Vector2(36, 38)), Color("27474d"), Color("91e8cc") if on else Color("e7b769"))
   draw_line(point - Vector2(0, 8), point + Vector2(9 if on else -9, -30), Color("dceacb"), 4)
   draw_string(font, point + Vector2(-32, -50), "ACTIVO" if on else "E · ACTIVAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e2edd0"))
  if GameManager.flags().get("device", false) and device.kind == "wind":
   var zone: Rect2 = device.zone
   for i in range(8):
    var y: float = zone.end.y - fposmod(gameplay_clock * 90 + i * 32, zone.size.y)
    draw_line(Vector2(zone.position.x + 18 + (i % 4) * 32, y), Vector2(zone.position.x + 18 + (i % 4) * 32, y - 18), Color(0.7, 0.95, 0.9, 0.5), 2)
 for secret in stage_secrets():
  if GameManager.flags().get("secrets", {}).get(secret.id, false) or not visible_point(secret.point):
   continue
  var point: Vector2 = secret.point
  draw_circle(point, 15, Color(0.65, 0.85, 1, 0.15))
  draw_rect(Rect2(point - Vector2(9, 9), Vector2(18, 18)), Color("e3dcba"))
  draw_rect(Rect2(point - Vector2(6, 7), Vector2(3, 14)), Color("68899d"))
  for line_y in [-4, 0, 4]:
   draw_line(point + Vector2(0, line_y), point + Vector2(6, line_y), Color("637a87"), 1)
 for entry in moving_platforms:
  var rect: Rect2 = entry.data.rect
  rect.position = entry.body.position - rect.size / 2
  if visible_point(rect.get_center()):
   draw_texture_rect(Scenery.tile("metal"), rect, true)
   draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("b6f2d3"), 3)
   var start: Vector2 = entry.data.rect.get_center()
   draw_line(start - entry.data.axis, start + entry.data.axis, Color(0.7, 0.85, 0.9, 0.35), 2)
 var collected: Dictionary = GameManager.flags().get("collected", {})
 for i in range(map_data.pickups.size()):
  var point: Vector2 = map_data.pickups[i].point
  if collected.get(str(i), false) or not visible_point(point, 24):
   continue
  var width = 5 + absf(sin(animation_time * 3 + i * 0.4)) * 4
  draw_rect(Rect2(point - Vector2(width, 10), Vector2(width * 2, 20)), Color("8d5c39"))
  draw_rect(Rect2(point - Vector2(width - 2, 8), Vector2(maxf(2, width * 2 - 4), 16)), Color("ffd56c"))
  draw_rect(Rect2(point + Vector2(-2, -6), Vector2(3, 12)), Color("fff3ba"))
  draw_rect(Rect2(point + Vector2(2, -13), Vector2(5, 3)), Color("a9e28c"))
 for node in map_data.restoration:
  var p: Vector2 = node.point
  if not visible_point(p):
   continue
  var restored: bool = GameManager.flags().get("restored", {}).get(str(node.id), false)
  var glow: Color = {"A": Color("96e89d"), "B": Color("83d7ed"), "C": Color("ffd084")}.get(GameManager.branch, accent)
  var fill = glow if restored else Color("5c697e")
  draw_rect(Rect2(p - Vector2(17, 32), Vector2(34, 32)), Color("172f43"))
  draw_rect(Rect2(p - Vector2(13, 28), Vector2(26, 24)), fill.darkened(0.5))
  draw_rect(Rect2(p - Vector2(13, 28), Vector2(26, 3)), glow)
  if GameManager.branch == "A":
   draw_line(p - Vector2(0, 7), p - Vector2(0, 21), glow, 3)
   draw_rect(Rect2(p - Vector2(8, 23), Vector2(8, 5)), glow)
   draw_rect(Rect2(p - Vector2(0, 17), Vector2(8, 5)), glow)
  elif GameManager.branch == "B":
   draw_colored_polygon(PackedVector2Array([p + Vector2(3, -25), p + Vector2(-7, -14), p + Vector2(0, -14), p + Vector2(-3, -6), p + Vector2(8, -18), p + Vector2(1, -18)]), glow)
  else:
   draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -23), p + Vector2(8, -23), p + Vector2(7, -12), p + Vector2(0, -6), p + Vector2(-7, -12)]), glow)
  if not restored and player.position.distance_to(p) >= 100:
   draw_string(font, p + Vector2(-4, -40), "Q", HORIZONTAL_ALIGNMENT_LEFT, 24, 15, glow)
  if player.position.distance_to(p) < 100:
   var label_y: float = -112 if npcs.any(func(npc): return absf(npc.x - p.x) < 130 and absf(npc.y - p.y) < 24) else -79
   pixel_frame(Rect2(p + Vector2(-72, label_y), Vector2(144, 24)), Color("202e4b"), glow)
   draw_string(font, p + Vector2(-69, label_y + 17), "Reconstruido" if restored else "[Q] 3 semillas", HORIZONTAL_ALIGNMENT_CENTER, 138, 12, glow)
 for i in range(sites.size()):
  var site: Dictionary = sites[i]
  var point = Vector2(site.x, site.y)
  if not visible_point(point) or site.action == "salir" or site.id <= -100:
   continue
  var done: bool = site.id in GameManager.completed
  var color: Color = accent if done else Color("fff0bf")
  if site.action == "descansar":
   draw_rect(Rect2(point + Vector2(-18, -22), Vector2(36, 22)), Color("567380"))
   draw_rect(Rect2(point + Vector2(-14, -27), Vector2(28, 6)), Color("d7c599"))
   draw_string(font, point + Vector2(-9, -4), "♥", HORIZONTAL_ALIGNMENT_LEFT, 40, 20, Color("f58294"))
  elif site.action != "hogar":
   draw_rect(Rect2(point + Vector2(-14, -25), Vector2(28, 25)), Color("253c54"))
   draw_rect(Rect2(point + Vector2(-11, -22), Vector2(22, 4)), color)
   var glyph: String = "✓" if done else "♣" if site.action == "restaurar" else "+" if site.action == "reciclar" else "!" if site.action == "defender" else "E"
   draw_string(font, point + Vector2(-8, -2), glyph, HORIZONTAL_ALIGNMENT_LEFT, 24, 19, color)
  if i == nearby or site.action in ["hogar", "bridge", "rubble"]:
   var text: String = "Casa" if site.action == "hogar" else "Refugio" if site.action == "descansar" else LABELS.get(site.action, "Encargo")
   pixel_frame(Rect2(point + Vector2(-64, 8), Vector2(128, 23)), Color("202e4b"), color)
   draw_string(font, point + Vector2(-61, 25), text, HORIZONTAL_ALIGNMENT_CENTER, 122, 12, color)
 for npc in npcs:
  var feet = Vector2(npc.x, npc.y)
  if not visible_point(feet):
   continue
  var pose: String = "hurt" if npc.id == "medic" and GameManager.level == 2 and GameManager.characters.medic.status == "disponible" else "idle%d" % (int(animation_time * 2) % 2)
  draw_character(npc.id, feet, pose, 48)
  pixel_frame(Rect2(feet + Vector2(-47, -78), Vector2(94, 22)), Color("202e4b"), accent)
  draw_string(font, feet + Vector2(-44, -62), catalog.CAST[npc.id].name, HORIZONTAL_ALIGNMENT_CENTER, 88, 13, accent)
  if nearby_npc == npc.id:
   draw_rect(Rect2(feet - Vector2(21, 52), Vector2(42, 54)), accent, false, 2)
 for enemy in enemies:
  if enemy.dead or not visible_point(enemy.position, 60):
   continue
  var rect: Rect2 = enemy.bounds()
  if enemy.direction < 0:
   rect.size.x *= -1
  draw_texture_rect(Enemy.sprite(enemy.kind, int(animation_time * 6) % 2), rect, false, Color(1, 1, 1, 0.5 if enemy.stunned > 0 else 1.0))
  if enemy.warning > 0:
   draw_string(font, enemy.position + Vector2(-4, -enemy.dimensions().y - 12), "!", HORIZONTAL_ALIGNMENT_LEFT, 16, 20, Color("ffcf78"))
   draw_line(enemy.position + Vector2(-14, 3), enemy.position + Vector2(-14 + enemy.warning * 28, 3), Color("ffb765"), 3)
  if enemy.kind == "guardian":
   for heart in range(enemy.hp):
    draw_rect(Rect2(enemy.position + Vector2(-16 + heart * 12, -60), Vector2(8, 5)), Color("f17f92"))
 for projectile in projectiles:
  draw_line(projectile.position - projectile.velocity.normalized() * 12, projectile.position, Color("b97157"), 3)
  draw_rect(Rect2(projectile.position - Vector2(3, 3), Vector2(6, 6)), Color("ffe1a0"))
 var pose: String = CharacterAnimator.pose(player, active, exiting, work_target, animation_time)
 var fraction: float = Engine.get_physics_interpolation_fraction() if active else 1.0
 var visual_feet = player.previous_position.lerp(player.position, fraction)
 if player.invulnerability <= 0 or int(animation_time * 12) % 2 == 0:
  draw_character("protagonista", visual_feet, pose, 48, player.facing_left)
 var goal = Vector2(map_width - 96, 520)
 if visible_point(goal):
  draw_rect(Rect2(goal + Vector2(-4, -108), Vector2(8, 108)), Color("e8dec4"))
  var flag = Color("83df9a") if GameManager.can_advance() and not guardian_alive() else Color("ba7287")
  draw_colored_polygon(PackedVector2Array([goal + Vector2(4, -106), goal + Vector2(62, -94), goal + Vector2(4, -74)]), flag)
  draw_string(font, goal + Vector2(-26, 26), "META", HORIZONTAL_ALIGNMENT_LEFT, 100, 14, Color("fff0bf"))
 if landing_time > 0:
  for side in [-1, 1]:
   draw_rect(Rect2(landing_point + Vector2(side * (12 + (0.25 - landing_time) * 64), -4), Vector2(6, 3)), Color(0.9, 0.85, 0.65, landing_time * 3))
 for particle in particles:
  draw_rect(Rect2(particle.position, Vector2(3, 3)), particle.color)
 for pulse in restoration_pulses:
  var radius: float = 22 + pulse.time * 410
  var color: Color = pulse.color
  color.a = 1 - pulse.time / 0.8
  for section in range(24):
   var angle = section * TAU / 24
   var p: Vector2 = pulse.point + Vector2(cos(angle), sin(angle)) * radius
   draw_rect(Rect2(p, Vector2(5, 5)), color)
 draw_set_transform(Vector2.ZERO)
 pixel_frame(Rect2(0, 0, 960, 44), Color("202e4b"), accent)
 var banner: String = "EXPLORA EL REFUGIO · DECIDE EN TU CASA" if GameManager.level == 1 else "RUTA %s · TRAMO %d / 10" % [GameManager.branch, GameManager.level]
 if GameManager.level > 1:
  banner += " · PULSOS %d / %d" % [GameManager.flags().get("restored", {}).size(), map_data.restoration.size()]
 draw_string(font, Vector2(14, 28), banner, HORIZONTAL_ALIGNMENT_LEFT, 500, 14, accent)
 draw_string(font, Vector2(530, 28), "SEMILLAS %03d" % GameManager.seeds, HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color("ffda68"))
 for heart in range(10):
  var spot = Vector2(792 + heart * 15, 14)
  var color: Color = Color("f16d80") if player.health > heart * 10 else Color("445271")
  draw_rect(Rect2(spot + Vector2(1, 0), Vector2(4, 4)), color)
  draw_rect(Rect2(spot + Vector2(7, 0), Vector2(4, 4)), color)
  draw_rect(Rect2(spot + Vector2(0, 3), Vector2(12, 5)), color)
  draw_rect(Rect2(spot + Vector2(3, 8), Vector2(6, 3)), color)
  draw_rect(Rect2(spot + Vector2(5, 11), Vector2(2, 2)), color)
 draw_string(font, Vector2(792, 40), "VIDA %d / 100" % player.health, HORIZONTAL_ALIGNMENT_LEFT, 160, 10, Color("fff0bf"))
 var tutorial_hint = tutorial_text()
 if not tutorial_hint.is_empty():
  pixel_frame(Rect2(10, 54, 940, 32), Color("243655"), accent.darkened(0.3))
  draw_string(font, Vector2(22, 76), tutorial_hint, HORIZONTAL_ALIGNMENT_LEFT, 910, 13, accent)
 if stage_entry_time > 0:
  pixel_frame(Rect2(120, 92, 720, 58), Color("202e4b"), accent)
  draw_string(font, Vector2(132, 116), GameManager.title(), HORIZONTAL_ALIGNMENT_CENTER, 696, 16, Color("ffe4a0"))
  draw_string(font, Vector2(132, 138), GameManager.mission(), HORIZONTAL_ALIGNMENT_CENTER, 696, 12, accent)
 elif player.status_timer > 0:
  pixel_frame(Rect2(120, 92, 720, 30), Color("202e4b"), accent)
  draw_string(font, Vector2(132, 113), player.message, HORIZONTAL_ALIGNMENT_CENTER, 696, 13, accent)
 if not work_target.is_empty():
  pixel_frame(Rect2(260, 154, 440, 56), Color("202e4b"), accent)
  draw_rect(Rect2(272, 190, 416, 10), Color("121b33"))
  draw_rect(Rect2(272, 190, 416 * minf(work_progress / 1.5, 1), 10), accent)
  var verb: String = {"bridge": "Reparando el puente", "rubble": "Despejando escombros", "rescue": "Rescatando a Elena"}.get(work_target.action, "Trabajando")
  draw_string(font, Vector2(274, 177), verb + " · %d%%" % (work_progress / 1.5 * 100), HORIZONTAL_ALIGNMENT_LEFT, 410, 14, Color.WHITE)
 if feedback_timer > 0:
  pixel_frame(Rect2(180, 128, 600, 30), Color("274b53"), accent)
  draw_string(font, Vector2(192, 150), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, 576, 13, Color.WHITE)
 var progress = clampf(player.position.x / (map_width - 96), 0, 1)
 draw_rect(Rect2(10, 550, 940, 4), Color("23334c"))
 draw_rect(Rect2(10, 550, 940 * progress, 4), accent)
 for node in map_data.restoration:
  var marker_x: float = 10 + node.point.x / (map_width - 96) * 940
  var color = accent if GameManager.flags().get("restored", {}).get(str(node.id), false) else Color("8c7698")
  draw_rect(Rect2(marker_x - 2, 547, 4, 10), color)
 if damage_flash > 0 and not (get_tree().current_scene != null and get_tree().current_scene.get("reduce_motion") == true):
  draw_rect(Rect2(0, 0, 960, 560), Color(0.8, 0.15, 0.1, damage_flash * 0.25))
