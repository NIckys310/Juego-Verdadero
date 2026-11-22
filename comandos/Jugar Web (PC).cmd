@echo off
rem Abre la versión web de Verdaria en el navegador de esta PC.
chcp 65001 >nul
cd /d "%~dp0..\export\web"
if not exist index.html (
 echo Primero ejecuta "Exportar Web.cmd".
 pause
 exit /b 1
)
start "" http://localhost:8060/
python -m http.server 8060
