@echo off
setlocal
set "BOSQUE_ROOT=%~dp0"
set "BOSQUE_ENGINE=%BOSQUE_ROOT%..\duelo-arcano\tools\godot\Godot_v4.4.1-stable_win64.exe"
if not exist "%BOSQUE_ENGINE%" (
  echo Falta Godot 4.4.1. Importa project.godot con el motor o consulta README.md.
  pause
  exit /b 1
)
start "Bosque Arcano" "%BOSQUE_ENGINE%" --path "%BOSQUE_ROOT%."
