> **Nota del repositorio:** documento histórico. Las rutas que menciona son relativas a la carpeta `juego/`. Los atajos `.cmd` están ahora en `comandos/`, y `build/` (capturas, registros y motor incluido) no se sube al repositorio. Para empezar, lee el [README](../README.md).

# Verdaria — Revisión de controles y producción

19 de noviembre de 2026. Implementación en Godot 4.6, con representación 2D, física a 60 Hz y arte pixelado. Este documento actualiza las decisiones de control, cámara y combate de `DISENO_Y_CAMBIOS_V2.md`.

## Empezar

1. Cierra cualquier instancia anterior para que cargue los scripts nuevos.
2. Abre **Jugar Verdaria.cmd**. Continúa tu partida o inicia una aventura.
3. Espacio, W y flecha arriba saltan; A/D o flechas horizontales mueven; Shift corre.
4. En **Ajustes → Probar controles** puedes comprobar qué acción reconoce cada tecla o botón. La prueba deja el mundo en pausa y no cambia la campaña.

La partida existente quedó intacta. La copia del código previo a esta revisión está en `build/revision_controles_originales`. Los paisajes v2 y las decisiones de campaña siguen disponibles.

## Los tres fallos de control encontrados

### El salto ignoraba el teclado normal

Los tres eventos de salto de `project.godot` especificaban `device=16`. Un evento normal del teclado llega como dispositivo 0. Antes de corregirlo, la sonda `tests/input_probe.gd` produjo:

| Tecla | Dispositivo | Acción de salto reconocida |
| --- | ---: | --- |
| Espacio | 0 | No |
| W | 0 | No |
| Flecha arriba | 0 | No |
| Espacio / W / arriba | 16 | Sí |

Las pruebas anteriores llamaban al movimiento con el argumento de salto activado. Comprobaban la física, pero pasaban por alto el origen de la entrada. Por eso el fallo no aparecía en sus resultados.

La configuración ahora acepta todos los dispositivos (`-1`) y el autoload de entrada registra explícitamente las tres teclas, el mando y sus zonas muertas. Volver a configurar las acciones no duplica sus eventos. También se corrigió el archivo de proyecto, para que no dependa únicamente de la reparación en tiempo de ejecución.

La entrada conserva las pulsaciones y liberaciones recibidas entre dos pasos físicos. Un toque rápido sigue produciendo un salto corto aunque comience y termine antes del siguiente tick. La repetición automática del teclado no cuenta como una pulsación nueva. Abrir o cerrar ventanas y perder foco descarta las entradas pendientes.

### Girar desplazaba el objetivo de cámara 130 píxeles

La cámara usaba una anticipación instantánea de `+65` o `−65` según la orientación. Cambiar de lado alteraba el encuadre 130 px, independientemente de la distancia recorrida. La interpolación prolongaba la sensación de avance después del giro.

El módulo `camera_rig.gd` elimina esa dependencia. Mantiene una zona central entre los píxeles 400 y 560 de la vista de 960 px. Sólo cuando los pies salen de ella se mueve la cámara, y únicamente la distancia necesaria. No hay inercia de cámara al quedarse quieto. La posición visual interpolada del cuerpo sigue haciendo continuo el seguimiento entre ticks físicos.

El retorno al refugio centra la cámara explícitamente y respeta los extremos del mapa. Girar dentro de la zona central no desplaza ni el mundo ni su parallax.

### El reflejo desplazaba el dibujo 32 píxeles

El sprite se dibujaba con ancho negativo para invertirlo y además se trasladaba su origen un ancho completo. En Godot esa combinación cambiaba su posición visible: el personaje parecía saltar lateralmente respecto de sus pies y del cuerpo de colisión.

Se eliminó la traslación adicional del protagonista y de los enemigos. El reflejo ocupa el mismo rectángulo, conserva los pies y mantiene la sombra alineada. La comparación automática de imágenes verifica que no cambie ningún píxel fuera del área del personaje.

## Respuesta de movimiento y animación

| Parámetro | Valor actual |
| --- | ---: |
| Caminar | 260 px/s |
| Correr | 340 px/s |
| Aceleración en suelo | 2400 px/s² |
| Frenado sin dirección | 5200 px/s² |
| Aceleración aérea | 1300 px/s² |
| Impulso de salto | 590 px/s hacia arriba |
| Gravedad | 1600 px/s² |
| Altura teórica de salto completo | 108,78 px |
| Tolerancia tras perder el borde | 100 ms |
| Anticipación de pulsación antes de aterrizar | 120 ms |
| Cuerpo de colisión | 22 × 44 px |
| Sprite normal | 32 × 48 px |
| Cadencia de animación al caminar | Un ciclo cada 56 px recorridos |
| Cadencia al correr | Un ciclo cada 48 px recorridos |

Al invertir la dirección sobre suelo se elimina la velocidad residual que apuntaba al lado anterior antes de aplicar la aceleración nueva. Las cintas transportadoras conservan su empuje físico. La orientación responde a la intención del jugador, mientras que la cámara responde a su posición.

`character_animator.gd` decide entre reposo lateral, marcha, carrera, ascenso/caída, trabajo, derrota y celebración. La secuencia de pasos usa distancia acumulada; esperar o girar no hace avanzar el ciclo. La pose de reposo mira de lado y utiliza el mismo reflejo centrado que las poses de movimiento. Las imágenes existentes se precargan y reutilizan.

El salto conserva altura variable, tolerancia al borde, buffer de aterrizaje y ausencia de doble salto. Si el botón se suelta mientras el salto está almacenado en el buffer, se conserva esa intención de salto corto cuando finalmente se ejecuta.

## Combate con preparación y consecuencias visibles

Las variantes ahora tienen comportamientos diferenciados:

| Enemigo | Comportamiento |
| --- | --- |
| Patrulleros | Recorren su tramo y giran ante bordes y paredes |
| Dron | Recorre su tramo con oscilación vertical |
| Saltador | Alterna desplazamiento, preparación de 0,35 s y salto con impulso de 360 px/s |
| Torreta | Permanece quieta, apunta, avisa 0,65 s y dispara; espera 1,7 s antes de preparar otro disparo |
| Guardián | Alterna patrulla, preparación de 0,7 s, embestida de 0,65 s y recuperación de 0,8 s |

El aviso se representa con `!` y una barra de preparación. Una torreta dispara cuando el objetivo está a menos de 520 px horizontales y 160 px verticales. Sus proyectiles viajan a 210 px/s, duran hasta 3 s y quitan 15 de vida. Las paredes los detienen; el mecanismo de defensa también puede bloquearlos. La comprobación de impacto usa el tramo recorrido, para detectar cruces que ocurran entre dos posiciones del proyectil.

El guardián conserva tres puntos de resistencia. Saltar sobre él lo aturde e interrumpe su ataque. La embestida usa 180 px/s y deja una recuperación antes del siguiente ciclo. Los peligros, la invulnerabilidad y los costes de reconstrucción mantienen sus reglas.

Los proyectiles se congelan con la pausa, se limpian al reaparecer y no pasan a otra etapa. Son estado temporal, mientras que los enemigos derrotados siguen guardándose en la campaña. Las texturas de torreta y saltador son patrones pixelados propios del renderizador del juego.

## Presentación vintage

- Se conservan los 28 paisajes v2 del ZIP, sus capas de cielo y frente, el terreno jugable separado y el filtrado nearest.
- Cada entrada de etapa muestra el nombre del lugar y su encargo durante 2,6 s, sin bloquear los controles.
- Los menús conservan bordes dorados, paneles oscuros, foco visible y navegación con teclado o mando.
- **Monitor retro** añade líneas suaves y viñeta mediante un shader opcional. No deforma el mapa, no cambia colisiones y deja pasar los clics.
- **Reducir movimiento** fija el parallax y suprime destellos. La cámara normal ya no incorpora el desplazamiento causado por orientación.
- El probador de controles reconoce movimiento, carrera, salto, interacción y ambas reconstrucciones. Esc vuelve a los ajustes.

El filtro de monitor se guarda en el archivo de ajustes, separado de la campaña. Las capturas de comprobación activan sus opciones sin escribir preferencias del usuario.

## Arquitectura para continuar produciendo el juego

| Responsabilidad | Archivo |
| --- | --- |
| Registro y captura de entrada | `scripts/player_input.gd` |
| Movimiento y estado físico del personaje | `scripts/player_controller.gd` |
| Política de seguimiento de cámara | `scripts/camera_rig.gd` |
| Selección de poses por estado y distancia | `scripts/character_animator.gd` |
| Integración de mundo, colisiones, proyectiles e interacción | `scripts/world.gd` |
| Comportamientos enemigos y patrones visuales | `scripts/platform_enemy.gd` |
| Menús, ajustes y prueba de controles | `scripts/main.gd` |
| Filtro de presentación retro | `shaders/retro_screen.gdshader` |
| Campaña y persistencia | `scripts/game_manager.gd` |
| Geometría determinista de los niveles | `scripts/terrain_layout.gd` |
| Ejecución reproducible de QA | `tools/verify.py` |

La cámara es una función independiente y no modifica el cuerpo. La animación selecciona una pose y no modifica ni posición ni colisión. La entrada conserva eventos y la física los consume. Los proyectiles tienen un ciclo de vida explícito. Estas separaciones evitan que un efecto visual vuelva a producir desplazamientos físicos o apariencias de pasos adicionales.

Se utiliza Godot como entorno especializado de desarrollo; no se cambió de motor ni se creó un editor independiente. La carpeta continúa siendo un proyecto editable y ejecutable localmente, con motor de Windows incluido.

## Verificación reproducible

Desde la raíz:

```powershell
python tools/verify.py
python tools/verify.py --visual
```

También existe `Verificar Verdaria.cmd`; acepta `--visual`. Requiere Python y usa el motor incluido, con guardados de prueba separados. El ejecutor captura la salida, detecta errores, impone un tiempo máximo por proceso y escribe `build/qa_summary.json` junto a los registros individuales.

La última ejecución terminó con **18/18 comprobaciones satisfactorias**:

1. Entrada, mando, salto, toques breves, buffer, coyote time, pausa, HUD, inversión, frenado, animación y probador.
2. Física: suelo, plataformas, techos, daño de caída, carrera y retorno.
3. Combate: preparación, torreta, impactos, paredes, pausa, retorno y embestida.
4. Presentación e interacción.
5. Integración de paisajes, mecanismos, secretos y rutas elevadas.
6. Compatibilidad y recuperación del guardado.
7. Progresión de las tres campañas.
8. Narrativa y consecuencias.
9. Recorrido del refugio.
10. Apertura y rescate físico en las tres ramas.
11. Conectividad y plataformas de los 28 mapas.
12. Cápsulas, reconstrucción, economía y bandera automática.
13. Captura del salto desde un evento de teclado y comparación visual de giro.
14. Vistas generales del juego y menú.
15. Ajustes y varios tamaños de ventana.
16. Vistas de mapas y sombra al girar.
17. Reinicio y comprobación de que el archivo de la partida real permanece intacto.
18. Medición gráfica de rendimiento.

Las pruebas de entrada inyectan eventos `InputEventKey` y `InputEventJoypadButton`, con procesamiento automático de entrada y física. No llaman a `simulate()` para forzar el salto. Esto valida el recorrido que estaba ausente en las pruebas anteriores, aunque no sustituye una prueba manual con hardware físico.

La captura gráfica midió los pies en **y=453,74** tras pulsar Espacio, frente al suelo en **y=520**. El giro mantuvo la cámara en **x=480** y modificó **cero píxeles fuera del personaje**. Los datos están en `build/production_visual_report.json`; las capturas son `production_jump.png`, `production_facing_right.png` y `production_facing_left.png`.

En la medición local de 360 frames después del calentamiento: **6,94 ms por frame**, **144 FPS de media**, percentil 95 de **8,27 ms**, con un máximo de **128 llamadas de dibujo**. Equipo: RTX 3050 Laptop, Compatibility, 1280 × 800. El informe está en `build/render-metrics.json`; estas cifras no garantizan el rendimiento en otras máquinas ni en todos los encuentros.

## Límites de esta comprobación

La conexión de control de Windows falló con `Computer Use native pipe is unavailable (os error 2)`, incluso tras reiniciarla. Por eso no se declara una partida manual con teclado o mando físico. Sí se ejecutaron los eventos de entrada dentro del motor, las físicas, los recorridos automáticos y las capturas con render real.

La revisión no equivale a una certificación de producto comercial ni a una campaña completa evaluada por jugadores. Queda probar las sensaciones y la dificultad con personas, mandos físicos, otras pantallas y otros equipos. Algunos cierres acelerados de pruebas todavía producen una advertencia de Godot sobre reproducción de audio al salir; el ejecutor conserva esos mensajes en los registros. No se publicaron ni validaron exportaciones web o móviles.
