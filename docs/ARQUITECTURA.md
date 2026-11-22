# Arquitectura del código

Verdaria está escrito por completo en **GDScript** (unas 3600 líneas en 17 scripts). Usa una sola escena (`scenes/main.tscn`) y construye la interfaz y el mundo desde código. No hay escenas por nivel: los 28 mapas se generan de forma determinista a partir de recetas.

## Mapa de sistemas

```mermaid
flowchart TD
    subgraph Autoloads
        GM[GameManager<br/>game_manager.gd<br/>estado, reglas, guardado]        PI[PlayerInput<br/>player_input.gd<br/>teclado, mando y táctil]
    end

    Main[main.gd<br/>menús, HUD, ventanas, ajustes] --> World[world.gd<br/>simulación del nivel]
    Main --> Touch[touch_controls.gd<br/>botones táctiles]
    Touch -- InputEventAction --> PI
    PI --> Player[player_controller.gd<br/>física del personaje]

    World --> Player
    World --> Enemy[platform_enemy.gd<br/>criaturas y guardián]
    World --> Scenery[scenery.gd<br/>parallax y bloques]
    World --> Layout[terrain_layout.gd<br/>recetas de los mapas]
    World --> Camera[camera_rig.gd]
    World --> Anim[character_animator.gd]
    World --> Audio[game_audio.gd<br/>sonido sintetizado]

    GM --> Brain[decision_brain.gd<br/>perfil del jugador]
    GM --> Narrative[narrative_director.gd<br/>causa y efecto]
    World -- acciones --> GM
    GM -- señal changed --> Main
    Main -- refresh/rebuild --> World

    Main --> Theme[block_theme.gd<br/>estilo de bloques]
    Main --> Catalog[asset_catalog.gd<br/>sprites y paisajes]
```

## Responsabilidades

| Script | Líneas | Responsabilidad |
| --- | ---: | --- |
| `world.gd` | ~950 | Corazón del nivel: superficies, peligros, mecanismos, enemigos, proyectiles, núcleos de reconstrucción, trabajos que se mantienen con E, meta y dibujado del HUD dentro del mundo. |
| `main.gd` | ~680 | Interfaz: menú, diseño de PC (panel lateral y pie) y diseño táctil (pantalla completa), ventanas modales, pausa, ajustes persistentes y filtro retro. |
| `game_manager.gd` | ~450 | Fuente de verdad: rama, nivel, recursos, semillas, personajes, decisiones, encargos y diario. Valida acciones y guarda en `user://verdaria_save.json` (versión 6, con migración). |
| `terrain_layout.gd` | ~230 | Genera cada mapa a partir de módulos: caminos bajos y altos, huecos, túneles, torres, cápsulas y posiciones de encargos. Es determinista, así que el mismo nivel siempre se ve igual. |
| `scenery.gd` | ~210 | Fondos en capas con parallax y terreno de bloques; dibuja solo el tramo visible. |
| `touch_controls.gd` | ~210 | Mando analógico con zona de carrera y botones circulares multitáctiles; emite las mismas acciones que el teclado. |
| `player_controller.gd` | ~190 | Física del personaje: salto variable, coyote/buffer, daño por caída, refugios y reaparición. |
| `platform_enemy.gd` | ~160 | Patrulla, giro ante bordes, disparos, pisotón y guardián de tres impactos. |
| `game_audio.gd` | ~110 | Música y efectos sintetizados por código al arrancar y reutilizados; no hay archivos de audio. |
| `narrative_director.gd` | ~110 | Reglas explícitas de diálogo, consecuencias y desenlace según la confianza de cada personaje. |
| `block_theme.gd` | ~80 | Genera por código las texturas de "bloque esmaltado con remaches" del tema de la interfaz. |
| `retro_backdrop.gd` | ~70 | Diorama pixelado alternativo para el menú. |
| `decision_brain.gd` | ~60 | Puntúa el historial del jugador por rama para adaptar los niveles al estilo de juego. |
| `player_input.gd` | ~60 | Asigna teclado y mando a las acciones; captura flancos de salto para no perder pulsaciones. |
| `asset_catalog.gd` | ~55 | Rutas de sprites y paisajes por rama y nivel, con caché y versiones espejadas. |
| `character_animator.gd` | ~20 | Elige la pose según la distancia recorrida, no el tiempo. |
| `camera_rig.gd` | ~20 | Cámara lateral con zona muerta central. |

## Flujo de una partida

1. `main.gd` muestra el menú. *Nueva aventura* llama a `GameManager.new_game()`.
2. `show_game()` crea el `World` dentro de una vista de 960×560 (PC) o la escala a pantalla completa (táctil).
3. `World` pide a `terrain_layout.gd` el mapa del nivel actual y lo dibuja con `scenery.gd`.
4. Cada fotograma de física, `player_controller.gd` lee las acciones de `PlayerInput` y `World` resuelve colisiones, peligros y enemigos.
5. Al hablar, reparar o activar algo, `World` informa a `GameManager`. Este valida la acción, actualiza el estado, guarda la partida y emite `changed`.
6. `main.gd` recibe `changed`, actualiza el HUD y reconstruye el mundo si hace falta.
7. Al tocar la bandera con los encargos completos, `GameManager.advance()` pasa al siguiente mapa. En el nivel 10 muestra el desenlace.

## Entrada unificada

Todo control termina en **acciones** del `InputMap` (`move_left`, `jump`, `interact`…):

- Teclado y mando: los configura `player_input.gd` al arrancar.
- Táctil: `touch_controls.gd` envía `InputEventAction` con `Input.parse_input_event`, así que el jugador, el mundo y los menús no distinguen el origen. Un toque rápido se mantiene al menos un fotograma para no perderse.

## Adaptación por plataforma

| Detección | Efecto |
| --- | --- |
| `OS.has_feature("web")` o `"mobile"` | Usa la fuente incluida Cascadia Mono, porque el navegador no expone las fuentes del sistema. |
| `web_ios`, `web_android`, `mobile` o iPad (`web_macos` con pantalla táctil) | Modo táctil: proporción `EXPAND`, juego a pantalla completa, botones táctiles, ventanas más grandes y textos de ayuda adaptados. |
| `web_ios` | Oculta la opción de pantalla completa, que Safari en iPhone no admite. |

## Pruebas

`tests/` tiene 21 scripts que se ejecutan como `SceneTree` independientes y usan guardados de prueba separados:

- **12 suites de jugabilidad** (`verify.py`): controles, física, combate, presentación, integración v2, compatibilidad de guardados, humo, narrativa, refugio, apertura, plataformas y núcleos.
- **6 suites visuales** (`verify.py --visual`): capturas de menús y mapas, espejado de sprites y benchmark de render.
- Utilidades: `design_audit.gd` (inventario de mapas) e `input_probe.gd` (sonda de dispositivos de entrada).

## Análisis y recomendaciones

**Puntos fuertes**

- Lógica separada del dibujo en las piezas reutilizables (`camera_rig`, `character_animator`, `terrain_layout` y `decision_brain` son `RefCounted` sin estado de escena), lo que permite probarlas sin ventana.
- Generación de mapas determinista: mismos datos, mismo nivel, y pruebas reproducibles.
- Guardado robusto: versión explícita, migración desde v1 y recuperación ante archivos corruptos.
- Sin archivos de audio ni fuentes externas en escritorio: el proyecto es ligero (unos 17 MB de arte).
- Buena cobertura automática del recorrido completo de las tres ramas.

**Áreas de mejora**

1. **`world.gd` (~950 líneas) concentra demasiado.** Conviene separar peligros, mecanismos, núcleos de reconstrucción y el HUD del mundo en nodos o scripts propios.
2. **`main.gd` mezcla los diseños de PC y táctil.** Se podrían extraer `menu`, `hud_pc`, `hud_touch` y `modal` a escenas pequeñas.
3. **Interfaz construida solo por código.** Mover el menú y las ventanas a escenas `.tscn` permitiría ajustarlos en el editor sin tocar código.
4. **Indentación de un espacio.** GDScript la acepta, pero la guía oficial usa tabuladores. Unificarla mejora la lectura en el editor de Godot.
5. **Textos en el código.** Mover diálogos y ayudas a un archivo de traducción (CSV/PO) facilitaría corregirlos y traducir el juego.
6. **Motor de pruebas incluido en `build/runtime`**, que no se versiona. Ahora `verify.py` también acepta la variable `GODOT`. Un flujo de CI en GitHub Actions podría ejecutar las 12 suites en cada cambio.
