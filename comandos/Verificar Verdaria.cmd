@echo off
rem Ejecuta las pruebas automáticas. Acepta --visual para capturas y medición de rendimiento.
call "%~dp0_godot.cmd" || (pause & exit /b 1)
python "%~dp0..\juego\tools\verify.py" %*
if errorlevel 1 (
 echo.
 echo Revisa los registros en juego\build.
 exit /b 1
)
