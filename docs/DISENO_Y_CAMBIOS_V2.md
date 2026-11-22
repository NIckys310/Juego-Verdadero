> **Nota del repositorio:** documento histórico. Las rutas que menciona son relativas a la carpeta `juego/`. Los atajos `.cmd` están ahora en `comandos/`, y `build/` (capturas, registros y motor incluido) no se sube al repositorio. Para empezar, lee el [README](../README.md).

> **Actualización de controles y producción:** consulta [REVISION_PRODUCCION.md](REVISION_PRODUCCION.md). Corrige la asignación de teclado, el giro de cámara y el desplazamiento del sprite; actualiza física, animación, combate y QA.

# Verdaria — Diseño y revisión funcional v2

Revisión aplicada el 19 de noviembre de 2026. Proyecto Godot 4.6, Windows, render Compatibility. Este documento describe la implementación disponible, sus medidas y su verificación; no es una lista de funciones prometidas.

## 1. Cómo jugar esta revisión

Abre **Jugar Verdaria.cmd** en la raíz del proyecto. Utiliza el motor incluido en `build/runtime/Verdaria.exe`; no hace falta instalar Godot. Conserva la carpeta completa: este acceso ejecuta el proyecto local, no es un instalador ni una exportación independiente. Para editarlo, abre `project.godot` con Godot 4.6 o compatible.

El menú ofrece Nueva aventura, Continuar partida, Guía de juego, Ajustes y Salir. Continuar recibe el foco inicial cuando existe una partida recuperable. Nueva aventura exige confirmación si reemplaza progreso. La partida real existente se conservó: la prueba de reinicio verificó su contenido sin modificarlo.

## 2. Experiencia y estructura de campaña

El ciclo consiste en explorar, superar obstáculos, recoger semillas, completar encargos y decidir cómo reconstruir. El refugio inicial enseña desplazamiento, salto, descanso y conversación. La decisión de la casa fija una ruta: A restaura comunidad y naturaleza, B recupera industria y comercio, C fortalece defensa y resistencia.

Hay 28 mapas distintos: un refugio compartido y nueve lugares por cada ruta. Cada campaña visita diez etapas. Los niveles usan módulos de 640 px; un tramo inicial de 320 px y una llegada de 480 px separan los desafíos del punto de salida. El nivel inicial mide 1920 px. Los módulos combinan escalones, cauces, abismos, cubiertas elevadas, túneles, transportadores, plataformas móviles y zonas peligrosas. La geometría determinista permite comprobar rutas y recuperar guardados sin regenerar otra distribución.

Las tareas requieren alcanzar su punto y pulsar E; reconstruir su núcleo también puede completar el encargo correspondiente. La bandera avanza automáticamente cuando están resueltos los encargos y el guardián no bloquea la salida. Cruzar aplica las consecuencias de encuentros pendientes, precedidas por un aviso. El final conserva decisiones y muestra el resultado narrativo.

## 3. Controles y prioridades de interacción

| Acción | Teclado | Mando con distribución Xbox |
| --- | --- | --- |
| Mover | A/D o flechas | Stick izquierdo o cruceta |
| Correr | Shift | RB |
| Saltar | Espacio, W o flecha arriba | A |
| Interactuar / mantener trabajo | E | X |
| Reconstrucción segura | Q | Y |
| Reconstrucción elevada | R | LB |
| Pausa / volver | Esc | Start |
| Pantalla completa | F11 | Ajustes |

El salto depende de cuánto mantienes el botón. No hay doble salto. Los menús admiten foco y navegación; durante la exploración los botones del HUD no capturan Espacio accidentalmente. Las acciones del mundo y la pausa ahora usan InputMap tanto para teclado como para mando. Las operaciones de mantener interacción también consultan la acción común.

La interacción exige vida, suelo, cercanía y acceso despejado mediante consulta física. El alcance habitual es de 52 px. La altura debe coincidir con la del objetivo; no se puede trabajar desde el aire ni a través de una pared. El objetivo más cercano entre sitios y personajes tiene prioridad. Un mecanismo ofrece Activar cuando no hay uno de esos objetivos seleccionado. El HUD sólo cambia al variar el contexto.

Reparar puente, despejar escombros y rescatar requieren 1,5 s. Moverse, abandonar el alcance, sufrir daño, soltar el botón de trabajo o cancelar interrumpe la operación sin completar su efecto. Abrir una ventana cancela el trabajo pendiente. Los botones de pantalla pueden iniciar el trabajo automáticamente.

## 4. Medidas, movimiento y colisiones

| Parámetro | Valor implementado | Función |
| --- | --- | --- |
| Vista lógica | 1280 × 800 px | Mantiene las proporciones del diseño |
| Ventana inicial | 1152 × 720 px | Cabe en más pantallas |
| Ventana mínima | 960 × 600 px | Evita paneles excesivamente pequeños |
| Área del mundo | 960 × 560 px | Marco de juego separado del diario |
| Baldosa | 32 px | Escala de terreno y obstáculos |
| Sprite normal | 32 × 48 px | Medida visual común de personajes |
| Cuerpo físico | 22 × 44 px | Margen lateral de 5 px respecto del sprite |
| Origen | Centro de los pies | Coincide con suelo y apoyos |
| Física | 60 Hz | Simulación independiente del render |
| Caminar / correr | 260 / 340 px/s | Control normal y carrera |
| Aceleración suelo / aire | 2400 / 1300 px/s² | Respuesta rápida y corrección aérea |
| Gravedad | 1600 px/s² | Arco base del salto |
| Impulso inicial | 590 px/s hacia arriba | Altura teórica de 108,78 px |
| Salto a igual altura | 0,7375 s teóricos | Alcance ideal de 191,75 px caminando |
| Coyote time | 100 ms | Tolerancia tras abandonar un borde |
| Buffer de salto | 120 ms | Permite pulsar un poco antes de aterrizar |
| Salto corto | Recorte a −220 px/s al soltar | Ajuste de altura |
| Velocidad máxima de caída | 1100 px/s | Limita la aceleración vertical |
| Floor snap | 6 px | Estabilidad sobre apoyos |
| Margen del cuerpo | 0,04 px | Contacto preciso con geometría |
| Plataformas unilaterales | Margen de 5 px; móviles 4 px | Paso desde abajo y soporte al caer |

Las medidas base se conservan porque los recorridos y cápsulas ya están construidos alrededor de ellas. Se centralizó el tamaño del cuerpo y se ajustaron margen, reinicio e interpolación. El contacto residual del suelo ya no renueva la tolerancia de salto cuando el personaje está subiendo. La entrada horizontal se limita al intervalo −1 a 1.

Las cubiertas unilaterales permiten atravesar desde abajo; suelo, túneles sólidos y cápsulas bloquean el cuerpo. Los escalones frecuentes son de 32–64 px, por debajo de la altura del salto. Las cápsulas quedan 144 px por encima de su soporte: su cara inferior deja 112 px libres, suficientes para el cuerpo de 44 px y un golpe alcanzable desde abajo.

Las plataformas móviles son cuerpos animables con colisión unilateral y movimiento sinusoidal. Se inicializan en la misma fase usada por la simulación, evitando un salto inicial de posición. La física transporta al jugador. Al retornar se ignora brevemente el arrastre del apoyo anterior y se limpian velocidad, carrera, viento y empujes.

Las pruebas de conectividad comprueban encargos, refugios, rescate y meta en los mapas. También se ejecutaron saltos y aterrizajes físicos; el grafo por sí solo no sustituye esas comprobaciones.

## 5. Salud, peligros, enemigos y retorno

La salud máxima es 100. Las caídas de hasta 224 px desde el punto más alto no dañan. Por encima, el daño es `clamp(int((altura − 224) × 0,45), 0, 100)`. El salto ordinario no provoca daño de caída.

Pinchos, sierras y vapor quitan 25. El vapor funciona en ciclos de 3,2 s y avisa antes de activarse. Agua profunda y lava pueden quitar 100; los abismos se resuelven al salir del terreno. El contacto enemigo normal quita 20 y el guardián 35; el mecanismo del nivel final reduce este último a 20. El período de invulnerabilidad habitual es de 0,9 s. No se debe interpretar como inmunidad permanente frente al entorno.

Caer desde arriba sobre una amenaza la golpea y rebota al jugador con impulso de 410 px/s. El guardián tiene tres puntos de resistencia y un intervalo de aturdimiento de 0,7 s. Las criaturas terrestres patrullan y giran ante bordes; los drones oscilan en altura. La revisión de producción diferencia saltadores y torretas, añade proyectiles con aviso y dota al guardián de preparación, embestida y recuperación; véase el documento actualizado.

Al morir hay una espera de 1 s antes de volver al último refugio con salud completa e invulnerabilidad breve. La cámara vuelve inmediatamente al punto de retorno y se reinicia la interpolación del cuerpo, evitando que la vista recorra todo el mapa después de un teletransporte. Volver al refugio desde Pausa ofrece una confirmación y conserva tareas, decisiones y recursos.

## 6. Semillas, reconstrucción y secretos

Las semillas se recogen por proximidad al cuerpo. Cada diez semillas acumuladas otorgan un material; el contador de recogida es distinto del saldo gastable. Gastar semillas no borra el avance hacia el próximo material. Las cápsulas golpeadas desde abajo entregan tres semillas y veinte de vida, una sola vez.

Q invierte tres semillas en el paso seguro. A hace rebrotar una pasarela y cura veinte; B reactiva la pasarela y apaga las trampas del tramo; C refuerza el paso y habilita un refugio. R invierte cinco semillas en una pasarela elevada con un recuerdo que recompensa seis semillas. La ruta elevada tiene su propia geometría y no aplica la curación ni el refugio del paso seguro. La elección de modo se guarda por núcleo y se cobra una sola vez.

Los diarios de los niveles entregan dos semillas y agregan un recuerdo al registro narrativo; los recuerdos de rutas elevadas entregan seis. Los secretos ahora se dibujan, se detectan al tocarlos y persisten sin duplicar recompensas. El progreso y las consecuencias se consultan en Personajes y decisiones.

## 7. Mecanismos que ahora funcionan en el mundo

La base ya contenía datos y guardado de mecanismos; esta revisión conecta su interacción, dibujo, efectos y cuerpos físicos.

| Tipo | Resultado |
| --- | --- |
| Agua / refrigeración | Añade un puente físico sobre el cauce seleccionado y desactiva su peligro |
| Elevador | Crea una plataforma móvil vertical y su cubierta de desembarco |
| Viento | Activa una zona visible con elevación de −2100 px/s² añadida a la gravedad |
| Defensa | Desactiva pinchos, vapor y sierras del tramo correspondiente |

Los mecanismos son gratuitos y de activación única. El viento sólo afecta dentro de su zona y se limpia al salir. La clave de actualización del terreno incluye mecanismo y modo de reconstrucción: cambiar su estado ahora reconstruye las colisiones que corresponden, sin depender de una recogida o de recargar el nivel.

## 8. Paisajes v2 y dirección visual

El ZIP original permanece en la raíz. Se incorporaron sus PNG de paisajes sin copiar encima sus scripts de campaña ni los archivos guardados. El catálogo identifica las carpetas por nombre de lugar y rama, evitando seleccionar las copias antiguas de rutas abreviadas.

Se usan los 28 paisajes v2. Cada uno dispone de cielo, frente transparente, composición y versión HD. La representación activa usa cielo y frente de 480 × 270 px a escala 2× exacta: 960 × 540. El cielo avanza al 5 % de la cámara y el plano próximo al 16 %. Se repiten horizontalmente y conservan filtrado nearest. Si faltan capas, se usa la composición; el entorno procedural queda como respaldo.

Antes, el fondo se mostraba al 20 % y quedaba tapado por cielos y montañas generados. Ahora las capas tienen presencia completa. El gris inicial y la recuperación progresiva de verdes del arte se mantienen; el shader de gradación aporta el matiz de rama y restauración. El terreno con colisión y los elementos interactivos se dibujan por delante para distinguir la ruta jugable de los edificios y suelos pintados del paisaje.

Los árboles de primer plano se redibujaron con tronco, ramas, contorno irregular y racimos de hojas; se eliminaron las grandes franjas rectangulares anteriores. El menú utiliza el paisaje del amanecer y las tarjetas muestran las tres rutas. Los paneles conservan la identidad azul noche, marcos dorados y texto crema.

## 9. Interfaz, ajustes y accesibilidad

El marco lógico mantiene su relación 16:10 al redimensionar. En pantallas con otra relación se usan bandas, conservando proporciones y zonas interactivas. Se revisaron capturas a 1280 × 800, 960 × 600 y 1600 × 900.

La cabecera muestra nivel y encargo. El HUD del mundo muestra salud, semillas, ruta, núcleos y avance. El diario lateral reúne recursos, contexto narrativo y accesos. La franja inferior muestra una acción contextual y reconstrucción; los botones se deshabilitan si no se cumplen las condiciones.

Los diálogos detienen física del mundo y música; cerrar los reactiva y devuelve el foco cuando corresponde. Perder el foco de la aplicación abre Pausa y guarda. El menú de pausa se acortó para mostrar las acciones sin una larga guía antes de ellas; la guía detallada sigue en el menú principal.

Ajustes ofrece pantalla completa, volumen general y reducción de movimiento. Se guardan aparte de la campaña en `user://verdaria_settings.cfg`. La cámara utiliza siempre una zona central sin desplazamiento por orientación; la reducción fija el parallax y suprime el destello de daño. No cambia las físicas. El volumen general se aplica al bus maestro y puede llegar a silencio; el botón de sonido de la partida conserva su función adicional.

El audio sintetizado se reutiliza desde caché. Al salir de una escena se detienen sus reproductores y se liberan sus streams; también se pausan los efectos con el mundo.

## 10. Guardado y compatibilidad

El formato actual es versión 6, centralizado en `GameManager.SAVE_VERSION`. Se conservan campaña, rama, decisiones, personajes, tareas, salud, refugio, recursos, semillas disponibles y acumuladas, enemigos derrotados, cápsulas, núcleos, modo de reconstrucción, mecanismos y secretos.

Se mantiene escritura temporal y copia de respaldo. La carga recupera una copia válida si falta o está corrupto el archivo principal. Un temporal incompleto no se considera una partida completa. La migración admite versiones anteriores y conserva las reglas existentes para adaptar las posiciones físicas.

Las pruebas usan rutas `verdaria_test_*` separadas. Los ajustes de visualización no se guardan durante las pruebas visuales. La copia previa del código está en `build/revision_v2_originales`; el archivo original de configuración lleva extensión `.bak` para que Godot no lo detecte como proyecto anidado. Los recursos originales anteriores también siguen dentro del ZIP suministrado.

## 11. Inventario medido de mapas

Datos generados por `tests/design_audit.gd`, disponibles en `build/v2_design_audit.json`. Ancho y alturas se expresan en píxeles del mundo. Las superficies son las iniciales; no incluyen las que se agregan al reconstruir o activar mecanismos. “Móviles” cuenta las iniciales; un elevador activo puede añadir otra. Las semillas cuentan posiciones iniciales, no recompensas de cápsulas o secretos.

| Mapa | Bioma interno | Ancho | Superficies | Móviles | Peligros | Enemigos | Semillas | Núcleos | Mecanismo |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| A1 | refuge | 1920 | 5 | 0 | 0 | 0 | 10 | 0 | none |
| A2 | garden | 3360 | 26 | 0 | 1 | 4 | 39 | 2 | water |
| A3 | water | 3360 | 27 | 0 | 3 | 4 | 37 | 2 | water |
| A4 | glass | 4000 | 36 | 0 | 3 | 7 | 60 | 3 | lift |
| A5 | village | 3360 | 22 | 0 | 1 | 6 | 37 | 2 | wind |
| A6 | forest | 4000 | 33 | 0 | 2 | 7 | 54 | 3 | water |
| A7 | school | 3360 | 29 | 0 | 2 | 6 | 52 | 2 | lift |
| A8 | windmill | 4000 | 38 | 6 | 2 | 7 | 48 | 3 | wind |
| A9 | valley | 4000 | 32 | 0 | 2 | 7 | 47 | 3 | water |
| A10 | dawn | 4640 | 39 | 2 | 2 | 8 | 52 | 4 | shield |
| B2 | scrapyard | 3360 | 24 | 0 | 2 | 4 | 41 | 2 | lift |
| B3 | foundry | 4000 | 29 | 0 | 3 | 5 | 42 | 3 | water |
| B4 | workshop | 3360 | 25 | 2 | 3 | 6 | 38 | 2 | lift |
| B5 | radio | 4000 | 39 | 3 | 1 | 7 | 55 | 3 | wind |
| B6 | market | 3360 | 21 | 0 | 3 | 6 | 35 | 2 | lift |
| B7 | laboratory | 4000 | 32 | 2 | 5 | 7 | 52 | 3 | shield |
| B8 | energy | 4000 | 31 | 2 | 3 | 7 | 38 | 3 | wind |
| B9 | city | 4000 | 33 | 3 | 2 | 7 | 50 | 3 | lift |
| B10 | reactor | 4640 | 35 | 2 | 3 | 8 | 42 | 4 | water |
| C2 | checkpoint | 3360 | 27 | 0 | 2 | 4 | 40 | 2 | shield |
| C3 | arsenal | 3360 | 22 | 0 | 3 | 4 | 41 | 2 | shield |
| C4 | hill | 4000 | 38 | 3 | 2 | 7 | 50 | 3 | wind |
| C5 | camp | 3360 | 23 | 0 | 2 | 6 | 38 | 2 | shield |
| C6 | wall | 4000 | 34 | 2 | 3 | 7 | 45 | 3 | lift |
| C7 | bunker | 4000 | 27 | 0 | 5 | 7 | 55 | 3 | shield |
| C8 | blockade | 4000 | 27 | 2 | 4 | 7 | 33 | 3 | lift |
| C9 | citadel | 4000 | 34 | 1 | 2 | 7 | 58 | 3 | wind |
| C10 | fortress | 4640 | 34 | 2 | 4 | 8 | 49 | 4 | shield |

## 12. Verificación y rendimiento

Once suites terminaron con cero fallos de comprobación:

- Física: suelo, techo, salto variable, ausencia de doble salto, carrera, caída y retorno.
- Presentación: escalas, contexto, botones, acceso físico y cancelación.
- Smoke: secuencia de diez etapas en las tres rutas y persistencia.
- Narrativa: 24 combinaciones y consecuencias.
- Compatibilidad: migración a la versión actual, costes y recuperación de archivos.
- Refugio: recorrido inicial, obstáculos, casa y salida.
- Apertura: recorrido y rescate físico A/B/C.
- Platforming: 28 mapas, conexión de rutas, amenazas, plataformas y cámara.
- Premium: 25 cápsulas golpeadas físicamente, pulsos A/B/C, economía y bandera automática.
- Integración v2: catálogo y dimensiones de capas, cuatro mecanismos, secretos, ruta elevada, mando mediante evento, ajustes y retorno de cámara.
- Reinicio: menú y disponibilidad de la partida real, verificando que su archivo quedara intacto.

Se corrigieron dos expectativas antiguas de pruebas: el salto también incluye un evento de mando y el guardado actual ya era versión 6. No se eliminaron verificaciones de comportamiento para lograr el resultado.

Capturas revisadas: `build/menu.png`, `build/game.png`, `build/v2_settings.png`, `build/v2_pause.png`, `build/v2_small_window.png` y `build/v2_wide_window.png`. Los registros están en `build/v2_*.log` y `build/v2_final_*.log`. En algunos cierres acelerados sin pantalla Godot advierte sobre instancias de reproducción de audio; las comprobaciones funcionales terminan con cero fallos.

La medición gráfica local del laboratorio B7, con recorrido de módulos y 360 frames después de calentamiento, dio:

- Media: **6.94 ms/frame**, aproximadamente **144.0 FPS**.
- Percentil 95: **8.27 ms**.
- Máximo de llamadas de dibujo: **128**.
- Compatibility, 1280 × 800, NVIDIA RTX 3050 Laptop.

Las cifras describen esta máquina y este recorrido, no todos los niveles ni equipos. Informe original de la medición: `build/render-metrics.json`.

## 13. Alcance pendiente

La revisión implementa y verifica mejoras concretas sobre el juego existente. No equivale a una campaña completa jugada por personas en todos los niveles. El equilibrio fino de dificultad, las sensaciones con un mando físico y equipos distintos requieren pruebas humanas. No se validaron exportaciones web, móviles ni una distribución comercial; el acceso entregado ejecuta la carpeta local en Windows. Los tipos de enemigos comparten varios patrones y siguen admitiendo ampliación de comportamiento y animación.

## 14. Organización para continuar el desarrollo

`main.gd`: pantallas, diálogos, ajustes, foco y pausa. `world.gd`: interacción, mecanismos, recogidas, amenazas y cámara. `player_controller.gd`: cuerpo, salto, salud y retorno. `terrain_layout.gd`: recetas, medidas, superficies y objetivos. `asset_catalog.gd`: rutas de arte y cachés. `scenery.gd`: parallax y dibujo del terreno. `game_manager.gd`: progreso y persistencia. `platform_enemy.gd`: enemigos. `game_audio.gd`: música y efectos. Los tests documentan las invariantes y usan guardados aislados.
