@echo off
setlocal
set "BOSQUE_ROOT=%~dp0"
set "BOSQUE_ENGINE=%BOSQUE_ROOT%..\duelo-arcano\tools\godot\Godot_v4.4.1-stable_win64_console.exe"
if not exist "%BOSQUE_ENGINE%" (
  echo Falta Godot 4.4.1. Consulta README.md.
  pause
  exit /b 1
)
"%BOSQUE_ENGINE%" --headless --path "%BOSQUE_ROOT%." --fixed-fps 120 --script res://tests/run_tests.gd
set "BOSQUE_RESULT=%ERRORLEVEL%"
if not "%BOSQUE_RESULT%"=="0" goto done
"%BOSQUE_ENGINE%" --headless --path "%BOSQUE_ROOT%." --fixed-fps 120 --script res://tests/gesture_tests.gd
set "BOSQUE_RESULT=%ERRORLEVEL%"
if not "%BOSQUE_RESULT%"=="0" goto done
"%BOSQUE_ENGINE%" --headless --path "%BOSQUE_ROOT%." --fixed-fps 120 --script res://tests/destruction_tests.gd
set "BOSQUE_RESULT=%ERRORLEVEL%"
if not "%BOSQUE_RESULT%"=="0" goto done
"%BOSQUE_ENGINE%" --headless --path "%BOSQUE_ROOT%." --fixed-fps 120 --script res://tests/terrain_tests.gd
set "BOSQUE_RESULT=%ERRORLEVEL%"
if not "%BOSQUE_RESULT%"=="0" goto done
"%BOSQUE_ENGINE%" --headless --path "%BOSQUE_ROOT%." --fixed-fps 120 --script res://tests/crater_tests.gd
set "BOSQUE_RESULT=%ERRORLEVEL%"
:done
pause
exit /b %BOSQUE_RESULT%
