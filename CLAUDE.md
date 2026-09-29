# Bosque Arcano — instrucciones para Claude

@AGENTS.md
@GESTOS-Y-MUNDO.md
@docs/CONTEXTO-PARA-CLAUDE.md
@docs/ARQUITECTURA-RPG-MAGIA.md
@docs/TERRENO.md

`docs/CONTEXTO-PARA-CLAUDE.md` y `docs/ARQUITECTURA-RPG-MAGIA.md` son del 24–28/09 y describen el estado previo a esta bitácora; ante diferencias manda la entrada más reciente de abajo.

## Motor en la nube

La sesión en la nube (Linux, sin GPU) descarga `Godot_v4.4.1-stable_linux.x86_64.zip` de los releases oficiales en `tools/godot/` (ignorado por git). Suites sin ventana:

```sh
G=tools/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import
$G --headless --path . --fixed-fps 120 --script res://tests/run_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/gesture_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/destruction_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/terrain_tests.gd
```

`tests/capture.gd` necesita GPU: no correrlo en la nube. La importación genera `.uid` e `.import` que no venían en el ZIP; no se versionan desde la nube (el editor en la PC los regenera).

## Bitácora

### 2026-09-29 — sesión en la nube: repositorio y preparación

- El código no estaba en GitHub. Se creó el repositorio privado `matiasstr/bosque-arcano`; `main` contiene el ZIP `Bosque-Arcano-para-Claude-2026-09-28.zip` sin cambios, con los dos documentos de contexto en `docs/`. El ZIP no traía `CLAUDE.md` ni `docs/`; este archivo se creó en esta sesión. Tampoco traía algunas capturas que existen en la PC (`preview-*-ligero.png`, `preview-gesto*.png`, etc.).
- Trabajo en la rama `claude/terreno-alturas`, sin merge a `main`.
- Godot 4.4.1 Linux descargado de los releases oficiales. Importación sin errores.
- Ejecutado: `run_tests` 40, `gesture_tests` 27, `destruction_tests` 8 verificaciones, 0 fallos. Coincide con Windows.

### 2026-09-29 — sesión en la nube: terreno por mapa de alturas

**Hecho** (detalle y riesgos en `docs/TERRENO.md`):
- `world_generator.gd` v2: alturas en milímetros enteros sobre una grilla global de 133 × 133 muestras cada 0,5 m (3 × 3 sectores de 22 m, de −33 a 33 m). Ruido de valor propio con hash entero y flujo aleatorio propio (`seed ^ 0x7E44A1`). Sendero, árboles y rocas mantienen exactamente su x/z de la v1.
- Claros, santuario y spawn nivelados; el claro de práctica es la altura 0, así las pruebas de combate no cambiaron.
- `terrain.gd` (nuevo): por sector, `ArrayMesh` + `HeightMapShape3D` con escala uniforme 0,5, leyendo la misma grilla. Los bordes comparten vértices y normales exactas.
- Apoyados en el suelo: spawn, árboles (punto más bajo bajo sus raíces), rocas, blancos, santuario, marcadores del sendero, sotobosque y límites (muros por tramos).
- `tests/terrain_tests.gd` (nuevo, 39 verificaciones) y agregado a `Verificar.cmd`. En `run_tests` se adaptaron 3 alturas fijas (tronco, borde, spawn); en `capture.gd`, las posiciones fijas del jugador.
- Decisiones conservadoras tomadas sin consultar: relieve suave (desnivel típico de 4–5 m; se descartó una primera versión con pendientes de hasta 37° en el sendero); no se versionan `.uid`/`.import` generados en la nube; `Verificar.cmd` y `Jugar.cmd` siguen buscando el motor en `../duelo-arcano/tools/godot/`.

**Verificado ejecutando** (Linux headless, sin GPU): `run_tests` 40, `gesture_tests` 27, `destruction_tests` 8 y `terrain_tests` 39 verificaciones, 0 fallos. La colisión coincide con la malla en 2072 rayos (diferencia 0,0000 m); el jugador recorre los 9 sectores sin despegarse (salto máximo entre frames 2 mm). Tiempos: descripción 71–108 ms (antes 9–10); regenerar la escena 318–348 ms (antes 143–152).

**No verificado:** `capture.gd` (necesita GPU; solo se comprobó que compila), aspecto visual, rendimiento en la GTX 1070, que la huella de las alturas y del layout v1 coincida en Windows, y controles con mouse y teclado reales.

**Consumo:** esta sesión no tiene acceso al saldo ni al gasto de créditos; no hay cifra. Se respetaron los límites de alcance: sin cráteres, guardado, streaming ni biomas.

**Revisar en la PC** (`Verificar.cmd`, después `Jugar.cmd` o `Jugar-ligero.cmd`):
1. `Verificar.cmd` debe dar 40 + 27 + 8 + 39 sin fallos. Si solo falla "terreno no redistribuye…" o "misma semilla…", puede ser una diferencia de formato numérico entre plataformas: avisar antes de tocar el generador.
2. Bordes entre sectores: caminar sobre las líneas x = ±11 y z = ±11 (el HUD muestra X y Z). Buscar grietas, costuras de luz o escalones.
3. Objetos flotando o muy enterrados: árboles en pendiente (raíces del lado bajo), rocas, marcadores amarillos del sendero, blancos del claro y santuario.
4. Pendientes: recorrer el sendero corriendo y saltando; subir y bajar colinas fuera del sendero; acercarse a los muros del borde y comprobar que no se puede salir.
5. Que el sendero y los claros se vean sobre el terreno (el sombreado del camino ahora sigue el relieve).
6. Correr `capture.gd` para regenerar las capturas y mirar la vista general.

**Próximo paso:** después de revisar en la PC, cráteres: editar alturas de los sectores afectados por un impacto, reconstruir solo esa malla y colisión, y resolver árboles y rocas que queden sin apoyo. Luego, guardado de seed, versión y ediciones.
