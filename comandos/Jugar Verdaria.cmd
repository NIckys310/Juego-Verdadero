@echo off
rem Ejecuta el juego directamente con Godot (versión de escritorio).
call "%~dp0_godot.cmd" || (pause & exit /b 1)
start "" "%GODOT_GUI%" --path "%~dp0..\juego"
