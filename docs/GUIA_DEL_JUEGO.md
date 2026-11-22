> **Nota del repositorio:** documento histórico. Las rutas que menciona son relativas a la carpeta `juego/`. Los atajos `.cmd` están ahora en `comandos/`, y `build/` (capturas, registros y motor incluido) no se sube al repositorio. Para empezar, lee el [README](../README.md).

> **Controles y producción corregidos:** salto con teclado normal, giro sin desplazamiento de cámara ni sprite, animación por distancia, enemigos diferenciados y QA reproducible. Lee [REVISION_PRODUCCION.md](REVISION_PRODUCCION.md). Abre **Jugar Verdaria.cmd** para cargar la revisión. Pruebas: `python tools/verify.py --visual`.

> **Revisión de paisajes y jugabilidad — 19/11/2026.** Abre **Jugar Verdaria.cmd** para ejecutar la carpeta local en Windows con el motor incluido. Diseño, medidas, reglas, cambios, inventario de los 28 mapas y resultados de verificación: [DISENO_Y_CAMBIOS_V2.md](DISENO_Y_CAMBIOS_V2.md).
>
> Paisajes v2 con dos capas; mecanismos y recuerdos funcionales; rutas elevadas con R/LB; menús con ajustes persistentes, volumen, pantalla completa y reducción de movimiento; pausa al perder foco; retorno de cámara y colisiones actualizados. Guardados versión 6. Las secciones históricas siguientes describen la base y se complementan con el documento de revisión.

# Verdaria · Godot 4 · Versión 0.8.1

Abre `project.godot` con Godot 4.7 y pulsa **F5**. Renderizador Compatibility, ventana 1280×800 y física a 60 Hz.

## La nueva base jugable

Aventura de plataformas con desplazamiento lateral, inspirada en la estructura del Mario clásico y con la historia de Verdaria. Hay **28 mapas diferentes**: un refugio compartido de 1920 px y 27 mapas de campaña de 3360–4640 px. Las tres ramas conservan los diez títulos y el orden del GDD. Cada lugar tiene una receta propia de tramos, paleta y paisaje del catálogo.

Los recorridos combinan caminos bajos, rutas elevadas, huecos, túneles, torres, transportadores, plataformas móviles, pinchos, sierras, vapor, agua profunda y lava. El mapa se desplaza con el jugador; la interfaz permanece fija y el fondo usa parallax. La cámara permite regresar para resolver encuentros o recuperar encargos.

El refugio es tranquilo: aprende a caminar y saltar, conoce a los vecinos, explora hasta tu casa y decide repararla, desguazarla o fortificarla. Después llega a la bandera del extremo derecho para empezar la campaña. Decidir en la casa conserva la posición del jugador.

En los demás niveles completa los encargos distribuidos por el recorrido y toca la bandera: una breve celebración da paso automáticamente al siguiente mapa, incluso si llegas saltando. Puedes hacer más encargos de los necesarios. En el último nivel también hay que neutralizar al guardián; al tocar la bandera aparece el desenlace.

## El pulso de Verdaria

Las semillas también sirven para reconstruir el entorno mientras recorres el mapa. Acércate a un núcleo y pulsa **Q**: cuesta tres semillas, crea una pasarela permanente y completa el encargo de ese tramo cuando está pendiente. Cada núcleo se activa una sola vez. La silueta y el color de la pasarela dependen de tu rama.

| Rama | Acción | Efecto adicional |
| --- | --- | --- |
| A · Restauración | Rebrotar | Pasarela vegetal y veinte puntos de vida. |
| B · Industria | Reactivar | Pasarela de energía; apaga vapor, sierras y pinchos de ese tramo. Agua y lava siguen siendo peligrosas. |
| C · Defensa | Reforzar | Pasarela reforzada y nuevo punto de retorno; puedes volver a descansar allí con E. |

Los núcleos aparecen en tramos alternos de los niveles 2–10. En túneles la pasarela se construye sobre el techo para que quepa el personaje. Los cambios permanecen al morir, guardar y continuar; sus acciones también alimentan el cerebro local.

## Controles

- A/D o ←/→: caminar.
- Shift: correr.
- Espacio/W/↑: saltar; mantener da altura completa, soltar acorta el salto.
- E: hablar, completar un encargo o descansar.
- Mantener E: reparar el puente, despejar escombros o rescatar a Elena.
- Q: activar un núcleo de reconstrucción por tres semillas.
- Bandera: avanzar automáticamente cuando estén completos los objetivos.
- Esc: cancela un trabajo activo; durante exploración abre la pausa.

Salta sobre los enemigos para neutralizarlos; el contacto lateral causa daño. El guardián requiere tres impactos. Los enemigos y sus sprites son originales, construidos con patrones pixelados: esporas, recolectores mecánicos, escarabajos, drones y guardián.

Las semillas brillantes se recogen al tocarlas: cada diez recogidas acumuladas dan un material, aunque gastes semillas en reconstruir. Golpear desde abajo una cápsula dorada concede tres semillas y recupera veinte puntos de vida, una sola vez. Ahora todas las cápsulas tienen una plataforma debajo y 112 px de espacio libre para saltar; al golpearlas rebotan visualmente. Recogidas, cápsulas usadas y amenazas neutralizadas se conservan al morir y al cargar.

Los respiraderos muestran **!** antes de expulsar vapor. Las sierras se mueven; los transportadores empujan; las plataformas móviles llevan al personaje. El agua profunda y la lava son mortales. Los refugios recuperan vida y guardan el punto de retorno. Puedes silenciar música y efectos desde el panel.

## Los mapas

| Nivel | A · Restauración | B · Industria | C · Defensa |
| --- | --- | --- | --- |
| 1 | Refugio compartido: aprendizaje, vecinos, casa y meta | Mismo refugio | Mismo refugio |
| 2 | Huerto: cultivos, escalones, hueco y dosel | Mercado: cinta, pasarelas, túnel y hueco | Puesto: pinchos, torre, escalones y hueco |
| 3 | Acueducto: cruces de agua y rutas superiores | Fundición: lava, cinta y respiraderos | Arsenal: túneles, pinchos y vapor |
| 4 | Invernadero: cristal, sierras y dosel | Talleres: túnel, cinta y plataformas móviles | Colina: torres, viento, huecos y cubiertas móviles |
| 5 | Plaza: camino bajo, túnel y rutas altas | Radio: torres, cubiertas móviles y viento | Campamento: camino abierto, pinchos, túnel y torre |
| 6 | Bosque: dosel, pinchos y agua | Zona franca: cinta, huecos, túnel y vapor | Muro: huecos, cubiertas móviles, torre y pinchos |
| 7 | Escuela: escalones, cristal, túnel y torre | Laboratorio: cristal, vapor, túnel y cubiertas móviles | Búnker: túneles, vapor, pinchos y cristal |
| 8 | Molino: viento, plataformas móviles y torre | Energía: cubiertas móviles, vapor, cinta, torre y lava | Bloqueo: cinta, pinchos, huecos, cubiertas móviles y vapor |
| 9 | Valle: camino abierto, huecos, agua y dosel | Metrópoli: torre, cinta, viento, cubiertas móviles y túnel | Ciudadela: torres, pinchos, túnel y viento |
| 10 | Amanecer: dosel, cubiertas móviles, cristal, torre y guardián | Cónclave: lava, vapor, cubiertas móviles, torre, cinta y guardián | Pax: pinchos, vapor, torre, cubiertas móviles, túnel y guardián |

Los mapas se componen de tramos de 640 px con recetas explícitas en `terrain_layout.gd`. Comparten piezas para mantener un lenguaje coherente, pero no la distribución completa. El detalle visual y la dificultad podrán seguir ajustándose sobre esta base.

## Historia y cerebro local

La decisión de la casa fija A, B o C. El cerebro local analiza las acciones anteriores y adapta los encargos; neutralizar amenazas también influye en la afinidad defensiva. No utiliza un modelo generativo externo.

| Encuentro | Decisión | Consecuencia |
| --- | --- | --- |
| Nivel 2 · Elena | Rescatar o abandonar | Rescatada: ayuda en 3 y 6. Abandonada: desaparece y el nivel 3 exige otra tarea. |
| Nivel 4 · Ivo | Compartir dos materiales o reservar | Compartir consume materiales y facilita 7 y 8 con herramientas y una pasarela. |
| Nivel 5 · Marcos | Pactar o rechazar | Pactar añade apoyo, recursos y un acceso en 6 y 8. |

El rescate exige despejar los escombros al principio del mapa, reparar el paso y subir hasta Elena. El trabajo dura 1,5 segundos; moverse, recibir daño, saltar, soltar E o pulsar Esc lo interrumpe. Cerca de la bandera aparece un aviso si queda un encuentro sin resolver. Cruzarla aplica la consecuencia de no ayudar y continúa sin pedir confirmación. Estados, confianza, diario y desenlace permanecen guardados.

Las carpetas de personajes siguen sus identificadores: `medic` es Elena, `nerd` es Ivo y `boss` es Marcos. Todos se dibujan con una base visible de **32×48 px**, apropiada para baldosas de 32 px; agacharse o sentarse reduce la altura de la pose. Los márgenes transparentes se recortan en memoria y los PNG originales se conservan. La sombra usa los mismos pies interpolados que el sprite y conserva su centro al invertir la dirección.

## Física y presentación

Cuerpo de 22×44 px con origen en los pies. Velocidad al caminar 260 px/s y carrera 340 px/s. Gravedad 1600 px/s² y salto inicial 590 px/s: altura teórica aproximada 109 px. Coyote time de 100 ms y buffer de 120 ms. No hay doble salto.

Las plataformas unilaterales dejan pasar desde abajo; los techos sólidos y los bloques de provisiones bloquean desde abajo. Los recorridos usan escalones de 32–64 px. Caídas de hasta 224 px son seguras; por encima el daño es `clamp(int((altura - 224) * 0.45), 0, 100)`. Morir devuelve al refugio sin borrar progreso. Al reaparecer se elimina el arrastre de la plataforma anterior.

Paneles azul noche, bordes dorados, botones con estados de interacción y tipografía sin suavizado. El HUD muestra corazones, semillas, misión, núcleos activados y avance por el mapa. Paisajes del usuario incorporados al fondo; terreno, decorados y cielos pixelados hacen legible la geometría jugable. Los núcleos emiten un pulso al activarse y los rótulos se separan de los personajes próximos. Música chiptune y efectos sintetizados originales, con melodías según rama y pausa junto al juego.

Texturas, sprites, baldosas y audio quedan en caché. La cámara y los personajes usan interpolación; sólo se dibuja el tramo visible. Recoger semillas o actualizar el HUD conserva los cuerpos de colisión. El menú dibuja su diorama a 10 Hz.

Medición local de la versión 0.8 en el laboratorio B7 recorriendo los módulos, Compatibility 1280×800 y RTX 3050 Laptop: 360 frames tras calentamiento, media 6,94 ms (~144 FPS) y percentil 95 de 7,70 ms. El resultado corresponde a esta máquina. Datos: `build/render-metrics.json`.

## Guardado

JSON versión 6 en `user://verdaria_save.json`; en web, `localStorage`. Guarda campaña, decisiones, recursos, semillas disponibles y acumuladas, núcleos reconstruidos, enemigos neutralizados, cápsulas abiertas, recogidas, salud y refugio activado.

En escritorio se escribe primero un archivo temporal y se cierra antes de sustituir el principal. `verdaria_save.json.bak` conserva el guardado válido anterior. Si falta el principal o está corrupto, **Continuar partida** recupera esa copia y vuelve a generar el archivo principal. Un temporal incompleto se ignora. La recuperación corresponde al último guardado válido disponible; no garantiza conservar una acción interrumpida por un apagado.

La versión 4 migra conservando salud, punto de retorno, recursos y semillas. Las versiones 1–3 migran a los mapas nuevos conservando progreso narrativo y recursos, y empiezan en el refugio inicial del nivel. La vida de la versión anterior se conserva si está disponible. Una nueva partida permite recorrer la introducción completa; reemplazar el guardado tiene confirmación en el menú.

## Verificación

Las pruebas usan archivos `verdaria_test_*.json` separados de la partida del jugador.

- `platforming.gd`: 27 geometrías distintas, conexión de encargos/meta/refugios mediante grafo de salto, saltos reales, abismos, recogidas, cofres, contacto lateral, stomp, vapor, plataformas que transportan al jugador, guardián, cámara y persistencia.
- `premium.gd`: soporte y altura de cápsulas en 27 mapas; golpes reales a las 25 cápsulas de los niveles 2 y 3, pulso de las tres ramas, espacio para el cuerpo y aterrizajes sobre pasarelas nuevas, coste único, economía acumulada, guardado del nuevo punto de retorno y bandera automática desde suelo y aire, con consecuencias narrativas y bloqueo por objetivos pendientes.
- `opening.gd`: recorrido físico, puente, escombros y subida hasta Elena en las tres ramas.
- `refuge.gd`: recorrido de introducción, obstáculos, casa y meta.
- `physics.gd`: colisiones, techos, salto variable, ausencia de doble salto, caídas, carrera y retorno.
- `presentation.gd`: tamaño de sprites, obstáculos de interacción, botones y cancelación de trabajo.
- `smoke.gd`: progresión de las tres campañas y persistencia.
- `narrative.gd`: 24 combinaciones de decisiones y sus consecuencias.
- `save_compatibility.gd`: migración, continuidad, costes, sustitución del archivo, recuperación ante escritura interrumpida o archivo ausente y rechazo de JSON corrupto sin copia válida.
- `restart.gd`: arranque del menú y disponibilidad del guardado real, comprobando que su contenido permanezca intacto; captura en `build/restart_menu.png`.
- `platform_preview.gd`: seis vistas y comparación de píxeles de la sombra al girar.
- `premium_preview.gd`: nueve capturas de núcleos antes/después, cápsulas corregidas y celebración en la bandera (`build/premium_*.png`).
- `preview.gd` y `render_benchmark.gd`: capturas y medición local de render.

Ejemplo: Godot con `--headless --path . --script res://tests/platforming.gd`. Las capturas y el benchmark se ejecutan con render gráfico.

## Archivos y siguiente pase

`terrain_layout.gd` define recorridos; `scenery.gd` dibuja el entorno; `platform_enemy.gd` controla criaturas; `player_controller.gd` controla movimiento; `world.gd` integra cámara, peligros e interacción. `game_manager.gd`, `decision_brain.gd` y `narrative_director.gd` conservan campaña y consecuencias. `main.gd`, `block_theme.gd`, `retro_backdrop.gd` y `game_audio.gd` aportan interfaz y presentación.

Base funcional para iterar: ajustar la dificultad mediante partidas humanas, enriquecer encuentros y animaciones, y validar la exportación en los dispositivos objetivo. Los encargos pueden completarse con E o reconstruyendo su tramo con Q; el guardián tiene un patrón simple. Todavía no se ha publicado una versión ni validado una exportación web.
