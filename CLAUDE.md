# Bosque Arcano — instrucciones para Claude

@AGENTS.md
@GESTOS-Y-MUNDO.md
@docs/CONTEXTO-PARA-CLAUDE.md
@docs/ARQUITECTURA-RPG-MAGIA.md

`docs/CONTEXTO-PARA-CLAUDE.md` y `docs/ARQUITECTURA-RPG-MAGIA.md` son del 24–28/09 y describen el estado previo a esta bitácora; ante diferencias manda la entrada más reciente de abajo.

## Motor en la nube

La sesión en la nube (Linux, sin GPU) descarga `Godot_v4.4.1-stable_linux.x86_64.zip` de los releases oficiales en `tools/godot/` (ignorado por git). Suites sin ventana:

```sh
G=tools/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import
$G --headless --path . --fixed-fps 120 --script res://tests/run_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/gesture_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/destruction_tests.gd
```

`tests/capture.gd` necesita GPU: no correrlo en la nube. La importación genera `.uid` e `.import` que no venían en el ZIP; no se versionan desde la nube (el editor en la PC los regenera).

## Bitácora

### 2026-09-29 — sesión en la nube: repositorio y preparación

- El código no estaba en GitHub. Se creó el repositorio privado `matiasstr/bosque-arcano`; `main` contiene el ZIP `Bosque-Arcano-para-Claude-2026-09-28.zip` sin cambios, con los dos documentos de contexto en `docs/`. El ZIP no traía `CLAUDE.md` ni `docs/`; este archivo se creó en esta sesión. Tampoco traía algunas capturas que existen en la PC (`preview-*-ligero.png`, `preview-gesto*.png`, etc.).
- Trabajo en la rama `claude/terreno-alturas`, sin merge a `main`.
- Godot 4.4.1 Linux descargado de los releases oficiales. Importación sin errores.
- Ejecutado: `run_tests` 40, `gesture_tests` 27, `destruction_tests` 8 verificaciones, 0 fallos. Coincide con Windows.
