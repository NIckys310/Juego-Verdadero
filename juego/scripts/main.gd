extends Control
const World = preload("res://scripts/world.gd")
const Blocks = preload("res://scripts/block_theme.gd")
var world: Node2D
var screen: Control
var modal: Control
var modal_box: VBoxContainer
var catalog = preload("res://scripts/asset_catalog.gd").new()
var status: Label
var profile: Label
var hint: Label
var pulse_button: Button
var sound_button: Button
var interact_button: Button
var paused: bool = false
var return_focus: Control
var master_volume: float = 0.8
var reduce_motion: bool = false
var retro_screen: bool = false
var screen_filter: ColorRect
var control_tester: Label
const SETTINGS_PATH = "user://verdaria_settings.cfg"
const TouchControls = preload("res://scripts/touch_controls.gd")
const DESIGN_SIZE = Vector2(1280, 800)
## Móvil/tableta: el juego ocupa toda la pantalla y aparecen controles táctiles.
var touch_mode: bool = false
## Lienzo de 1280×800 centrado: menús y ventanas conservan su diseño original.
var stage: Control
var game_view: Control
var touch_layer: Control
var hint_panel: PanelContainer

func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 theme = Blocks.make_theme()
 touch_mode = detect_touch()
 PlayerInput.touch_mode = touch_mode
 if touch_mode:
  # Usa todo el ancho de los teléfonos panorámicos en lugar de franjas negras.
  get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 get_viewport().size_changed.connect(relayout)
 load_settings()
 setup_screen_filter()
 GameManager.changed.connect(refresh)
 show_menu()

static func detect_touch() -> bool:
 if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
  return true
 # iPadOS se presenta como macOS en Safari.
 return OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available()

func view_size() -> Vector2:
 return get_viewport_rect().size

func relayout() -> void:
 if is_instance_valid(stage):
  stage.position = ((view_size() - DESIGN_SIZE) / 2).floor()
 if touch_mode and is_instance_valid(game_view):
  var area: Vector2 = view_size()
  var zoom: float = minf(area.x / 960.0, area.y / 560.0)
  game_view.scale = Vector2(zoom, zoom)
  game_view.position = ((area - Vector2(960, 560) * zoom) / 2).floor()
 if is_instance_valid(hint_panel):
  place_hint()
 if is_instance_valid(modal) and modal.has_meta("panel"):
  place_modal_panel(modal.get_meta("panel"))

func label(text: String, size: int = 18) -> Label:
 var node = Label.new()
 # La fuente incluida para web/móvil no tiene ✦; ◆ mantiene el mismo adorno.
 node.text = text.replace("✦", "◆") if OS.has_feature("web") or OS.has_feature("mobile") else text
 node.add_theme_font_size_override("font_size", size)
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 return node

func button(text: String, callback: Callable) -> Button:
 var node = Button.new()
 node.text = text
 node.custom_minimum_size.y = 64 if touch_mode else 48
 if touch_mode:
  node.add_theme_font_size_override("font_size", 22)
 # Espacio salta durante la exploración; no activa accidentalmente el HUD.
 if is_instance_valid(world) and not is_instance_valid(modal):
  node.focus_mode = Control.FOCUS_NONE
 node.pressed.connect(callback)
 return node

func clear_screen() -> void:
 if is_instance_valid(screen):
  remove_child(screen)
  screen.queue_free()
 world = null
 modal = null
 return_focus = null
 game_view = null
 touch_layer = null
 hint_panel = null
 status = null
 profile = null
 pulse_button = null
 interact_button = null
 screen = Control.new()
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(screen)
 stage = Control.new()
 stage.size = DESIGN_SIZE
 stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.add_child(stage)
 relayout()

func column(parent: Node, position: Vector2, width: float) -> VBoxContainer:
 var node = VBoxContainer.new()
 node.position = position
 node.size.x = width
 node.add_theme_constant_override("separation", 16)
 parent.add_child(node)
 return node

func show_menu() -> void:
 clear_screen()
 var backdrop = TextureRect.new()
 backdrop.texture = catalog.texture(catalog.landscape_path("A", 10))
 backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.add_child(backdrop)
 var veil = ColorRect.new()
 veil.color = Color(0.025, 0.045, 0.09, 0.55)
 veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(veil)
 # El fondo queda detrás del lienzo centrado del menú.
 screen.move_child(stage, -1)
 var kicker = label("✦  UNA AVENTURA PARA RECONSTRUIR EL MAÑANA  ✦", 18)
 kicker.position = Vector2(0, 76)
 kicker.size.x = 1280
 kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 kicker.add_theme_color_override("font_color", Blocks.GOLD)
 stage.add_child(kicker)
 var title = label("VERDARIA", 88)
 title.position = Vector2(0, 108)
 title.size.x = 1280
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_color_override("font_color", Color("ffe39b"))
 title.add_theme_constant_override("outline_size", 12)
 title.add_theme_color_override("font_outline_color", Blocks.INK)
 title.add_theme_constant_override("shadow_offset_y", 8)
 title.add_theme_color_override("font_shadow_color", Color("a76438"))
 stage.add_child(title)
 var subtitle = label("Una casa. Tres futuros. Tus decisiones permanecen.", 18)
 subtitle.position = Vector2(0, 226)
 subtitle.size.x = 1280
 subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 stage.add_child(subtitle)
 var panel = Blocks.panel(stage, Vector2(390, 280), Vector2(500, 340), true)
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation", 12)
 panel.add_child(box)
 var start_button = button("▶  NUEVA AVENTURA", request_new_game)
 start_button.add_theme_stylebox_override("normal", Blocks.slab(Color("356857"), true, true))
 box.add_child(start_button)

 var resume = button("Continuar partida", func():
  if GameManager.load_game():
   show_game())
 resume.disabled = GameManager.read_save().is_empty()
 call_deferred("focus_if_visible", start_button if resume.disabled else resume)
 box.add_child(resume)
 box.add_child(button("Guía de juego", func():
  show_modal("Guía del restaurador", "A/D o ←/→ para caminar. Shift para correr. Espacio/W/↑ para saltar; suelta antes para un salto corto.\n\nSalta sobre las amenazas. Evita pinchos, sierras, lava y vapor; los respiraderos avisan con !. Los guardianes requieren tres saltos.\n\nRecoge semillas: cada diez recogidas dan un material. Golpea las cápsulas doradas desde abajo: contienen tres semillas y veinte puntos de vida.\n\nE también activa compuertas, elevadores, viento y defensas. Los diarios de las alturas guardan recuerdos. R crea una ruta elevada por cinco semillas.

Q: pulso de reconstrucción junto a un núcleo. Cuesta tres semillas y completa el encargo de ese tramo. A hace rebrotar una pasarela y recupera vida; B reactiva una pasarela y apaga sus trampas; C refuerza una pasarela y abre un punto de retorno. Estos cambios permanecen guardados.\n\nE: hablar, descansar o trabajar. Mantén E para reparar, despejar o rescatar; Esc cancela el trabajo.\n\nCompleta los encargos y toca la bandera: pasarás automáticamente al siguiente lugar. Al aproximarte verás un aviso si queda un encuentro sin resolver; cruzar conserva sus consecuencias.\n\nLa casa fija tu ruta y lo que hagas por tus vecinos cambia el futuro. Los refugios guardan y recuperan vida." + ("\n\nEN PANTALLA TÁCTIL\nMando izquierdo: caminar; llévalo al borde para correr. SALTAR, USAR (E), Q y R a la derecha. La pausa está arriba a la derecha." if touch_mode else ""), [["Entendido", close_modal]])))
 box.add_child(button("Ajustes", settings_dialog))
 if not OS.has_feature("web"):
  box.add_child(button("Salir", func(): get_tree().quit()))
 var names = {"A": "RESTAURACIÓN", "B": "INDUSTRIA", "C": "DEFENSA"}
 for i in range(3):
  var branch: String = ["A", "B", "C"][i]
  var card = Blocks.panel(stage, Vector2(265 + i * 250, 636), Vector2(240, 90))
  var row = HBoxContainer.new()
  row.add_theme_constant_override("separation", 10)
  card.add_child(row)
  var preview = TextureRect.new()
  preview.texture = catalog.texture(catalog.landscape_path(branch, 2))
  preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  preview.custom_minimum_size = Vector2(74, 60)
  row.add_child(preview)
  var name = label(names[branch], 13)
  name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(name)
 var controls = label("Mantén el mando izquierdo para moverte · lleva el dedo al borde para correr" if touch_mode else "A/D · Mover    ESPACIO · Saltar    E · Interactuar    Q · Reconstruir    F11 · Pantalla completa", 14)
 controls.position = Vector2(0, 756)
 controls.size.x = 1280
 controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 stage.add_child(controls)

func request_new_game() -> void:
 if GameManager.read_save().is_empty():
  start_new()
 else:
  show_modal("Nueva partida", "Se reemplazará el progreso guardado.", [["Empezar de nuevo", start_new], ["Cancelar", close_modal]])

func start_new() -> void:
 GameManager.new_game()
 show_game()

func connect_world() -> void:
 world.nearby_changed.connect(func(text):
  hint.text = text
  if is_instance_valid(hint_panel):
   place_hint())
 world.interaction_changed.connect(update_interaction)
 world.home_requested.connect(home_dialog)
 world.character_requested.connect(character_dialog)
 world.exit_requested.connect(request_advance)

## Diseño táctil: el mundo llena la pantalla; el diario vive en la pausa.
func show_game_touch() -> void:
 clear_screen()
 paused = false
 var backdrop = ColorRect.new()
 backdrop.color = Color("0b1220")
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.add_child(backdrop)
 screen.move_child(backdrop, 0)
 world = World.new()
 game_view = Control.new()
 game_view.size = Vector2(960, 560)
 game_view.clip_contents = true
 game_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.add_child(game_view)
 game_view.add_child(world)
 status = label("", 1)
 status.visible = false
 screen.add_child(status)
 hint_panel = PanelContainer.new()
 hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var pill = Blocks.slab(Color("19243f"), true, true)
 pill.modulate_color = Color(1, 1, 1, 0.9)
 hint_panel.add_theme_stylebox_override("panel", pill)
 hint = label("", 20)
 hint.autowrap_mode = TextServer.AUTOWRAP_OFF
 hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 hint_panel.add_child(hint)
 screen.add_child(hint_panel)
 touch_layer = TouchControls.new()
 screen.add_child(touch_layer)
 connect_world()
 relayout()
 refresh()
 if GameManager.finished:
  ending_dialog()

func place_hint() -> void:
 hint_panel.visible = not hint.text.is_empty()
 hint_panel.reset_size()
 var area: Vector2 = view_size()
 hint_panel.position = Vector2(floor((area.x - hint_panel.size.x) / 2), (game_view.position.y + 164 * game_view.scale.y if is_instance_valid(game_view) else 18.0))

func show_game() -> void:
 if touch_mode:
  show_game_touch()
  return
 clear_screen()
 paused = false
 Blocks.panel(screen, Vector2(16, 12), Vector2(1248, 94), true)
 var header = column(screen, Vector2(32, 20), 1216)
 header.add_theme_constant_override("separation", 3)
 var heading = label("VERDARIA  /  DIARIO DE AVENTURA", 20)
 heading.add_theme_color_override("font_color", Blocks.GOLD)
 header.add_child(heading)
 status = label("", 16)
 header.add_child(status)
 Blocks.panel(screen, Vector2(16, 117), Vector2(976, 576))
 world = World.new()
 game_view = Control.new()
 game_view.position = Vector2(24, 125)
 game_view.size = Vector2(960, 560)
 game_view.clip_contents = true
 screen.add_child(game_view)
 game_view.add_child(world)
 connect_world()
 var side_panel = Blocks.panel(screen, Vector2(1008, 117), Vector2(256, 576), true)
 var side = VBoxContainer.new()
 side.add_theme_constant_override("separation", 12)
 side_panel.add_child(side)
 var side_title = label("✦ TU AVENTURA", 20)
 side_title.add_theme_color_override("font_color", Blocks.GOLD)
 side.add_child(side_title)
 var side_scroll = ScrollContainer.new()
 side_scroll.custom_minimum_size.y = 300
 side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 side.add_child(side_scroll)
 profile = label("", 15)
 profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 side_scroll.add_child(profile)
 side.add_child(button("Personajes y decisiones", journal_dialog))
 side.add_child(button("Ver ruta completa", route_dialog))
 side.add_child(button("Pausa / Guardar", pause_dialog))
 Blocks.panel(screen, Vector2(16, 704), Vector2(1248, 84))
 var footer = column(screen, Vector2(32, 712), 1216)
 footer.add_theme_constant_override("separation", 3)
 hint = label("Acércate a un objetivo para interactuar.", 15)
 footer.add_child(hint)
 var row = HBoxContainer.new()
 footer.add_child(row)
 row.add_theme_constant_override("separation", 12)
 interact_button = button("Interactuar [E]", func(): world.interact_nearest())
 interact_button.disabled = true
 interact_button.custom_minimum_size = Vector2(240, 42)
 row.add_child(interact_button)
 pulse_button = button("Reconstruir [Q]", func(): world.try_restore())
 pulse_button.custom_minimum_size = Vector2(230, 42)
 row.add_child(pulse_button)
 sound_button = button("Sonido: " + ("activado" if GameManager.audio_enabled else "silenciado"), func():
  GameManager.audio_enabled = not GameManager.audio_enabled
  sound_button.text = "Sonido: " + ("activado" if GameManager.audio_enabled else "silenciado")
  GameManager.save_game())
 sound_button.custom_minimum_size = Vector2(220, 42)
 row.add_child(sound_button)
 var keys = label("A/D · SHIFT · ESPACIO · E · Q · ESC", 11)
 keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 row.add_child(keys)
 refresh()
 if GameManager.finished:
  ending_dialog()

func update_interaction(context: Dictionary) -> void:
 if is_instance_valid(touch_layer):
  touch_layer.set_context(context)
 if not is_instance_valid(interact_button):
  return
 interact_button.disabled = not context.enabled
 interact_button.text = context.button
 interact_button.tooltip_text = context.hint
 if is_instance_valid(pulse_button):
  pulse_button.disabled = not context.pulse.enabled
  pulse_button.text = context.pulse.button
  pulse_button.tooltip_text = context.pulse.hint

func refresh() -> void:
 if not is_instance_valid(world) or not is_instance_valid(status):
  return
 world.rebuild()
 var gm = GameManager
 var required: int = 1 if gm.level == 1 else int(gm.layout().required)
 var mission: String = gm.mission()
 status.text = "NIVEL %d / 10 · %s\n%s · %d / %d tareas" % [gm.level, gm.title(), mission, gm.completed.size(), required]
 var place_notes: String = "\n".join(gm.layout().effects.notes)
 if gm.level == 1:
  place_notes = "Explora hacia la derecha. Conoce a tus vecinos y decide el futuro de tu casa."
 elif gm.level == 2 and not gm.decisions.has("elena_rescue"):
  place_notes = "Elena necesita ayuda. Repara el puente, despeja el acceso y llega hasta ella."
 if not is_instance_valid(profile):
  return
 profile.text = "CAMINO\n%s\n\nRECURSOS\nSemillas    %d\nComunidad   %d\nMateriales  %d\nSeguridad   %d\n\nEN ESTE LUGAR\n%s" % [gm.BRANCH_NAMES.get(gm.branch, "El futuro aún está abierto"), gm.seeds, gm.resources.comunidad, gm.resources.materiales, gm.resources.seguridad, place_notes]
 if not gm.journal.is_empty():
  profile.text += "\n\nÚLTIMA DECISIÓN / EFECTO\n" + gm.journal[-1].text
 if not gm.save_error.is_empty():
  profile.text += "\n" + gm.save_error
 var pulse: Dictionary = world.restoration_context()
 pulse_button.disabled = not pulse.enabled
 pulse_button.text = pulse.button
 pulse_button.tooltip_text = pulse.hint

func show_modal(title_text: String, body: String, choices: Array) -> void:
 var previous_focus = get_viewport().gui_get_focus_owner()
 close_modal()
 return_focus = previous_focus
 if world:
  world.cancel_work()
  world.active = false
 modal = Control.new()
 modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(modal)
 var shade = ColorRect.new()
 shade.color = Color(0.015, 0.025, 0.02, 0.80)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal.add_child(shade)
 var panel = Blocks.panel(modal, Vector2(210, 60), Vector2(860, 680), true)
 modal.set_meta("panel", panel)
 place_modal_panel(panel)
 if is_instance_valid(touch_layer):
  touch_layer.visible = false
 var scroll = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation", 16)
 scroll.add_child(box)
 modal_box = box
 box.add_child(label(title_text, 38 if touch_mode else 32))
 box.add_child(label(body, 24 if touch_mode else 18))
 var holder: Container = box
 # En pantallas táctiles apaisadas, muchas opciones caben mejor en dos columnas.
 if touch_mode and choices.size() >= 4:
  var grid = GridContainer.new()
  grid.columns = 2
  grid.add_theme_constant_override("h_separation", 14)
  grid.add_theme_constant_override("v_separation", 12)
  box.add_child(grid)
  holder = grid
 var first: Button = null
 for choice in choices:
  var node = button(choice[0], choice[1])
  node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  holder.add_child(node)
  if first == null:
   first = node
 if first != null:
  call_deferred("focus_if_visible", first)

## En móvil la ventana crece con la pantalla para que el texto sea legible.
func place_modal_panel(panel: Control) -> void:
 var area: Vector2 = view_size()
 var panel_size = Vector2(860, 680)
 if touch_mode:
  panel_size = Vector2(minf(area.x - 120, 1240), area.y - 60)
 panel.size = panel_size
 panel.position = ((area - panel_size) / 2).floor()

func focus_if_visible(node: Control) -> void:
 if is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree():
  node.grab_focus()

func close_modal() -> void:
 if is_instance_valid(modal):
  screen.remove_child(modal)
  modal.queue_free()
 modal = null
 if world:
  world.active = true
 if is_instance_valid(touch_layer):
  touch_layer.visible = true
 paused = false
 if is_instance_valid(return_focus):
  call_deferred("focus_if_visible", return_focus)
 return_focus = null

func home_dialog() -> void:
 show_modal("La Casa del Restaurador", "El refugio está en ruinas. La acción que tomes aquí definirá los nueve lugares que visitarás después.", [
  ["A · Limpiar y reparar → Restauración", func(): choose("reparar")],
  ["B · Vender y desguazar → Industria", func(): choose("vender")],
  ["C · Abandonar y fortificar → Defensa", func(): choose("fortificar")],
  ["Volver a explorar", close_modal]])

func choose(action: String) -> void:
 GameManager.choose_home(action)
 close_modal()

func request_advance() -> void:
 if not world.exiting or not GameManager.can_advance() or world.guardian_alive():
  return
 perform_advance()

func perform_advance() -> void:
 close_modal()
 GameManager.advance()
 if not GameManager.finished:
  world.restore_physical()
 else:
  ending_dialog()

func character_dialog(id: String) -> void:
 var info: Dictionary = catalog.CAST[id]
 var dialogue: Dictionary = GameManager.narrative.dialogue(id, GameManager.level, GameManager.characters, GameManager.decisions)
 if dialogue.decision == "elena_rescue":
  dialogue.text = "Elena está atrapada arriba. Repara el puente y despeja los escombros manteniendo E en los puntos señalados. Después sube hasta ella y mantén E para completar el rescate. Salir sin ayudarla tendrá consecuencias."
  dialogue.choices = [["Voy a abrir el acceso", "preparar"], ["Dejarla atrás", "abandonar"]]
 var choices: Array = []
 for option in dialogue.choices:
  var decision_id: String = dialogue.decision
  var choice: String = option[1]
  choices.append([option[0], func(): resolve_narrative(decision_id, choice)])
 choices.append(["Volver a explorar", close_modal])
 show_modal(info.name, dialogue.text, choices)
 var portrait_row = HBoxContainer.new()
 portrait_row.add_theme_constant_override("separation", 20)
 var portrait = TextureRect.new()
 portrait.texture = catalog.sprite(id, "talk0")
 portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 portrait.stretch_mode = TextureRect.STRETCH_SCALE
 portrait.custom_minimum_size = Vector2(72, 108)
 portrait_row.add_child(portrait)
 var description = label(info.role + "\nEstado: " + GameManager.characters[id].status + "\nConfianza: " + str(GameManager.characters[id].trust), 18)
 description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 portrait_row.add_child(description)
 modal_box.add_child(portrait_row)
 modal_box.move_child(portrait_row, 1)
 if dialogue.decision == "ivo_supplies" and GameManager.resources.materiales < 2:
  for child in modal_box.find_children("*", "Button", true, false):
   if child.text.begins_with("Compartir"):
    child.disabled = true
    child.text = "Compartir · Necesitas 2 materiales (recicla)"

func resolve_narrative(id: String, choice: String) -> void:
 if choice == "preparar":
  close_modal()
  return
 if GameManager.resolve_decision(id, choice):
  show_modal("Verdaria recuerda", GameManager.journal[-1].text, [["Continuar", close_modal]])

func journal_dialog() -> void:
 var body: String = "PERSONAJES\n"
 for id in GameManager.characters:
  var state: Dictionary = GameManager.characters[id]
  body += "%s · %s · Confianza %d\n" % [catalog.CAST[id].name, state.status, state.trust]
 body += "\nMEMORIA DE LA PARTIDA\n"
 if GameManager.journal.is_empty():
  body += "Todavía no has tomado decisiones narrativas.\n"
 for entry in GameManager.journal:
  body += "\nNivel %d · %s\n" % [entry.level, entry.text]
 body += "\nLa decisión del refugio fija la ruta. Las decisiones de personajes cambian la ayuda, los encuentros y el desenlace."
 show_modal("Personajes y decisiones", body, [["Volver", pause_dialog if touch_mode and not GameManager.finished else close_modal]])

func route_dialog() -> void:
 var body = "Primero decide el futuro de la casa para fijar tu ruta."
 if not GameManager.branch.is_empty():
  body = GameManager.BRANCH_NAMES[GameManager.branch] + "\n\n"
  for i in range(10):
   body += "%s %02d · %s\n" % ["→" if i + 1 == GameManager.level else "·", i + 1, GameManager.TITLES[GameManager.branch][i]]
 show_modal("Tu camino en Verdaria", body, [["Volver", pause_dialog if touch_mode and not GameManager.finished else close_modal]])

func pause_dialog() -> void:
 GameManager.capture_physical(world.player.health, world.player.checkpoint)
 GameManager.save_game()
 if touch_mode:
  show_modal("Partida en pausa", "Tu progreso, vida y refugio están guardados.\n\n" + status.text + "\n\nMando izquierdo: caminar (al borde, correr) · SALTAR: mantén para más altura\nUSAR (E): hablar o activar; mantén para reparar · Q: paso seguro (3 semillas) · R: ruta elevada (5 semillas)", [["Continuar", close_modal], ["Personajes y decisiones", journal_dialog], ["Ver ruta completa", route_dialog], ["Sonido: " + ("activado" if GameManager.audio_enabled else "silenciado"), func():
   GameManager.audio_enabled = not GameManager.audio_enabled
   GameManager.save_game()
   pause_dialog()], ["Ajustes", settings_dialog], ["Volver al refugio", return_to_checkpoint], ["Volver al menú", show_menu]])
  paused = true
  return
 show_modal("Partida en pausa", "Tu progreso, vida y refugio están guardados.\n\nA/D o stick: caminar · Shift/RB: correr · Espacio/A: saltar\nE/X: interactuar · Q/Y: paso seguro (3 semillas)\nR/LB: ruta elevada (5 semillas) · Esc/Start: continuar\n\nCompleta los encargos y llega a la bandera. Busca los diarios en las alturas y activa los mecanismos de cada lugar.\n\nPuedes regresar al refugio si necesitas recuperar fuerzas.", [["Continuar", close_modal], ["Ajustes", settings_dialog], ["Volver al refugio", return_to_checkpoint], ["Volver al menú", show_menu]])
 paused = true

func ending_dialog() -> void:
 show_modal("El futuro de Verdaria", "%s\n\nHas completado los diez niveles de la ruta %s.\n\n%s\n\nTu partida y tus decisiones están guardadas." % [GameManager.title(), GameManager.branch, GameManager.narrative.ending(GameManager.characters)], [["Ver decisiones y personajes", journal_dialog], ["Ver camino recorrido", route_dialog], ["Menú principal", show_menu]])

func _unhandled_input(event: InputEvent) -> void:
 if event.is_echo():
  return
 if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F11:
  toggle_fullscreen()
  get_viewport().set_input_as_handled()
  return
 if event.is_action_pressed("pause_game"):
  if is_instance_valid(control_tester) and control_tester.is_inside_tree():
   settings_dialog()
   get_viewport().set_input_as_handled()
   return
  if not is_instance_valid(world):
   if is_instance_valid(modal):
    close_modal()
   return
  get_viewport().set_input_as_handled()
  if not world.work_target.is_empty():
   world.cancel_work()
   get_viewport().set_input_as_handled()
   return
  if is_instance_valid(modal) and not GameManager.finished:
   close_modal()
  elif not GameManager.finished:
   pause_dialog()


func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(world) and not is_instance_valid(modal) and not GameManager.finished:
  pause_dialog()

func return_to_checkpoint() -> void:
 show_modal("Volver al refugio", "Recuperarás la vida en tu último refugio. Tus encargos, semillas y decisiones se conservan.", [["Volver al refugio", func():
  world.player.respawn()
  world.camera_x = world.CameraRig.reset_at(world.player.position.x, world.map_width)
  close_modal()], ["Cancelar", pause_dialog]])

func load_settings() -> void:
 var config = ConfigFile.new()
 if config.load(SETTINGS_PATH) == OK:
  master_volume = clampf(config.get_value("audio", "volume", 0.8), 0, 1)
  reduce_motion = config.get_value("display", "reduce_motion", false)
  retro_screen = config.get_value("display", "retro_screen", false)
  if config.get_value("display", "fullscreen", false):
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
 AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
 AudioServer.set_bus_mute(0, master_volume <= 0)

func save_settings() -> void:
 var config = ConfigFile.new()
 config.set_value("audio", "volume", master_volume)
 config.set_value("display", "reduce_motion", reduce_motion)
 config.set_value("display", "retro_screen", retro_screen)
 config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
 config.save(SETTINGS_PATH)

func toggle_fullscreen() -> void:
 var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
 save_settings()

func settings_dialog() -> void:
 var in_game: bool = is_instance_valid(world)
 show_modal("Ajustes", "Elige cómo explorar Verdaria. Los ajustes se conservan entre sesiones.\n\nF11 alterna pantalla completa. Mando: stick/cruceta para moverte, A salta, X interactúa, Y reconstruye y Start pausa.", [])
 var fullscreen = CheckButton.new()
 fullscreen.visible = not OS.has_feature("web_ios")
 fullscreen.text = "Pantalla completa"
 fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
 fullscreen.toggled.connect(func(_value): toggle_fullscreen())
 modal_box.add_child(fullscreen)
 var motion = CheckButton.new()
 motion.text = "Reducir movimiento de cámara y destellos"
 motion.button_pressed = reduce_motion
 motion.toggled.connect(func(value):
  reduce_motion = value
  save_settings())
 modal_box.add_child(motion)
 var retro = CheckButton.new()
 retro.text = "Monitor retro · líneas suaves y viñeta"
 retro.button_pressed = retro_screen
 retro.toggled.connect(func(value):
  retro_screen = value
  screen_filter.visible = value
  save_settings())
 modal_box.add_child(retro)
 if not touch_mode:
  modal_box.add_child(button("Probar controles", controls_dialog))
 var volume_label = label("Volumen general: %d %%" % roundi(master_volume * 100))
 modal_box.add_child(volume_label)
 var volume = HSlider.new()
 volume.min_value = 0
 volume.max_value = 100
 volume.step = 5
 volume.value = master_volume * 100
 volume.custom_minimum_size.y = 40
 volume.value_changed.connect(func(value):
  master_volume = value / 100.0
  volume_label.text = "Volumen general: %d %%" % value
  AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
  AudioServer.set_bus_mute(0, master_volume <= 0)
  save_settings())
 modal_box.add_child(volume)
 modal_box.add_child(button("Volver", pause_dialog if in_game else close_modal))
 call_deferred("focus_if_visible", fullscreen)

func setup_screen_filter() -> void:
 var layer = CanvasLayer.new()
 layer.layer = 100
 add_child(layer)
 screen_filter = ColorRect.new()
 screen_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var effect = ShaderMaterial.new()
 effect.shader = preload("res://shaders/retro_screen.gdshader")
 screen_filter.material = effect
 screen_filter.visible = retro_screen
 layer.add_child(screen_filter)

func controls_dialog() -> void:
 show_modal("Prueba de controles", "Pulsa una tecla o un botón del mando para comprobar su acción. La aventura permanece en pausa.\n\nA/D o flechas: mover · Shift: correr\nEspacio / W / ↑: saltar · E: interactuar\nQ: paso seguro · R: ruta elevada\n\nEsc vuelve a los ajustes.", [["Volver a ajustes", settings_dialog]])
 control_tester = label("Esperando una entrada…", 24)
 control_tester.add_theme_color_override("font_color", Blocks.GREEN)
 modal_box.add_child(control_tester)

func _input(event: InputEvent) -> void:
 if not is_instance_valid(control_tester) or not control_tester.is_inside_tree() or event.is_echo():
  return
 var names = {"move_left": "Mover a la izquierda", "move_right": "Mover a la derecha", "jump": "Saltar", "run": "Correr", "interact": "Interactuar", "restore_safe": "Reconstruir paso seguro", "restore_high": "Reconstruir ruta elevada"}
 for action in names:
  if event.is_action_pressed(action):
   var source: String = OS.get_keycode_string(event.physical_keycode) if event is InputEventKey else "Mando"
   control_tester.text = "✓ " + names[action] + " · " + source
   get_viewport().set_input_as_handled()
   return
