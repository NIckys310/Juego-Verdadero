# Verdaria en la web, PC e iPhone

## Archivos
- `comandos/Exportar Web.cmd` genera `export/web/` (el juego para navegador). Necesita las plantillas web de Godot 4.7.2.
- `comandos/Jugar Web (PC).cmd` abre esa versión en tu PC (http://localhost:8060).
- `app/Verdaria.vbs` abre Verdaria como aplicación de escritorio.
- `juego/web/shell.html` es la pantalla de carga, con el aviso de girar el teléfono y el consejo de instalación en iOS.

## Como aplicación en tu PC
- Ejecuta `app/Verdaria.vbs` o un acceso directo a ese archivo con el icono `app/Verdaria.ico`.
- Se abre en su propia ventana de Edge o Chrome, sin barras, y al cerrarla se apaga todo.
- Necesita Python y Microsoft Edge (o Chrome). Las partidas se guardan en `%LOCALAPPDATA%\Verdaria\perfil`.
- Para regenerar el icono: `godot --headless --path juego --script res://tools/make_icons.gd` y después `python app/crear_ico.py`.

## Cómo se comporta
- **PC (navegador):** la misma pantalla que la versión de escritorio. Teclado y mando. F11 o Ajustes → Pantalla completa.
- **Móvil o tableta:** se detecta solo. El juego ocupa toda la pantalla y aparecen botones táctiles:
  - Izquierda: mando para caminar; llévalo al borde para **correr**.
  - Derecha: **SALTAR** (mantén para saltar más alto), **E** (usar; mantén para reparar), **Q** (reconstruir), **R** (ruta elevada).
  - Arriba a la derecha: **pausa** (diario, ruta, sonido, ajustes, guardar).
  - En vertical aparece un aviso para girar el teléfono.

## Publicarlo (hace falta HTTPS para instalarlo en el iPhone)
1. Comprime el contenido de `export/web/` y súbelo a un hosting estático: Netlify Drop, itch.io (proyecto HTML) o GitHub Pages.
2. En el iPhone abre el enlace en **Safari** → **Compartir** → **Añadir a pantalla de inicio**.
3. Se abre como una app a pantalla completa, con su icono, y guarda la partida en el teléfono.

La exportación es sin hilos (*single-threaded*), así que no hace falta configurar cabeceras especiales en el servidor.
