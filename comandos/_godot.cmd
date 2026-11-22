@echo off
rem Busca Godot 4.7 y deja su ruta en GODOT (consola) y GODOT_GUI (editor).
rem Orden: variable GODOT ya definida, carpeta habitual del Escritorio, programa en el PATH.
chcp 65001 >nul
if defined GODOT if exist "%GODOT%" goto :gui
set "GODOT=%USERPROFILE%\Desktop\DISEÑO DE SOFTWARE\godot\Godot_v4.7.2-stable_win64_console.exe"
if exist "%GODOT%" goto :gui
for %%G in (godot.exe godot4.exe) do (
 if not "%%~$PATH:G"=="" (
  set "GODOT=%%~$PATH:G"
  goto :gui
 )
)
echo No encuentro Godot 4.7. Define la variable GODOT con la ruta de Godot_v4.7.2-stable_win64_console.exe
exit /b 1
:gui
set "GODOT_GUI=%GODOT:_console.exe=.exe%"
if not exist "%GODOT_GUI%" set "GODOT_GUI=%GODOT%"
exit /b 0
