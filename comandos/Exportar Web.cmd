@echo off
rem Exporta Verdaria para navegador (PC, iPhone, Android) en la carpeta export\web.
rem Requiere las plantillas web de Godot 4.7.2 instaladas.
setlocal
call "%~dp0_godot.cmd" || (pause & exit /b 1)
set "PROJECT=%~dp0..\juego"
set "OUT=%~dp0..\export\web"
if not exist "%OUT%" mkdir "%OUT%"
"%GODOT%" --headless --path "%PROJECT%" --import
"%GODOT%" --headless --path "%PROJECT%" --export-release "Web" "%OUT%\index.html"
if errorlevel 1 (
 echo.
 echo La exportación falló. Revisa que las plantillas web de Godot 4.7.2 estén instaladas.
 exit /b 1
)
echo.
echo Listo: export\web  (sube esa carpeta completa a tu hosting)
endlocal
