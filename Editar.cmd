@echo off
setlocal
set "BOSQUE_ROOT=%~dp0"
set "BOSQUE_ENGINE=%BOSQUE_ROOT%..\duelo-arcano\tools\godot\Godot_v4.4.1-stable_win64.exe"
if not exist "%BOSQUE_ENGINE%" (
  echo Importa project.godot con Godot 4.4.1.
  pause
  exit /b 1
)
start "Editar Bosque Arcano" "%BOSQUE_ENGINE%" --editor --path "%BOSQUE_ROOT%."
