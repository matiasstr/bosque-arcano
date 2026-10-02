# Bosque Arcano — instrucciones para Claude

@AGENTS.md
@GESTOS-Y-MUNDO.md
@docs/CONTEXTO-PARA-CLAUDE.md
@docs/ARQUITECTURA-RPG-MAGIA.md
@docs/TERRENO.md
@docs/GUARDADO.md
@docs/MOTOR-CALCULO.md

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
$G --headless --path . --fixed-fps 120 --script res://tests/crater_tests.gd
$G --headless --path . --fixed-fps 120 --script res://tests/save_tests.gd
$G --headless --path . --script res://tests/math_tests.gd
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

### 2026-09-29 — misma sesión: cráteres (en memoria)

El usuario pidió continuar con el próximo paso ("continue with this") antes de revisar en la PC. Se tomó como autorización para cráteres, que el pedido original dejaba para otra sesión; guardado, streaming y biomas siguen sin empezar.

**Hecho** (plan y riesgos en `docs/TERRENO.md`, sección Cráteres):
- `spell_catalog.gd`: `crater_radius`/`crater_depth` por hechizo. Brasa Rúnica 2,2 m / 0,6 m; Aguja de Luz no excava. Sin escalar por precisión (decisión conservadora, pendiente de balance humano).
- `terrain_edit.gd` (nuevo, puro): cuenco suave en milímetros enteros, tope de 1,5 m bajo el terreno original y limitador de escalón (≤ 280 mm por celda de 0,5 m, ~29°) que sube lo excavado hasta que se pueda salir caminando. En la práctica un cráter de 2,2 m no pasa de ~1,2 m. Protegidos: claro del santuario y franja de 2,5 m junto a los límites.
- `magic_combat.gd` emite `surface_hit`; `game.gd` decide si hay cráter (solo si el impacto es sobre un sector de terreno). Combate no conoce el terreno.
- `forest.gd`: copia editable de alturas (`ground`) separada de la descripción base, lista `terrain_edits` (repetible sobre la base: prepara el guardado), reconstrucción solo de los sectores tocados y reubicación hacia abajo de árboles, rocas, marcadores, sotobosque y blancos cercanos. El respawn usa el suelo actual.
- `tests/crater_tests.gd` (nuevo, 19 verificaciones), agregado a `Verificar.cmd`.

**Verificado ejecutando:** `run_tests` 40, `gesture_tests` 27, `destruction_tests` 8, `terrain_tests` 39, `crater_tests` 19; 0 fallos. Cráter en un borde 6,5–6,8 ms; en una esquina 8,9–10,2 ms.

**No verificado:** cómo se ve un cráter (sin GPU), el sombreado del sendero dentro del cráter, sensación de juego, y `capture.gd`. No hay partículas ni efecto nuevo de excavación.

**Consumo:** sigue sin haber acceso al saldo; no hay cifra.

**Revisar en la PC** (además de la lista anterior): `Verificar.cmd` debe dar 40 + 27 + 8 + 39 + 19. En partida, con 2 (Brasa) disparar al suelo: ver el cráter, entrar y salir caminando, disparar varias veces al mismo punto, disparar sobre un borde entre sectores (X o Z = ±11) y buscar grietas, disparar cerca de árboles, rocas, marcadores y cristales y ver que no floten. Árboles al borde del cráter se hunden enteros: decidir si eso alcanza o si hay que romperlos.

**Próximo paso:** guardado local (seed, versión, `destroyed_props` y `terrain_edits` en `user://`), reconstruyendo base + ediciones al cargar.

### 2026-09-30 — misma sesión: guardado local

El usuario pidió seguir con el próximo paso y, al terminarlo, revisar el motor de cálculo.

**Hecho** (plan y riesgos en `docs/GUARDADO.md`):
- `world_save.gd` (nuevo): `user://mundo.json` con formato, semilla, versión del generador, IDs destruidos, excavación como pares `[muestra, mm]` (acotada por la grilla, no crece con la cantidad de impactos) y huella SHA-256. Escritura en `.tmp` y reemplazo; recuperación del `.tmp` si se cortó entre ambos pasos. Validación completa al leer; un archivo inválido se aparta como `.invalido` y nunca se pisa.
- `game.gd`: `persistence` exportado, activo solo en `main.tscn` (los tests no tocan la partida real). Autoguardado 1 s después del último cambio, al pausar/perder foco y al cerrar; regenerar o cambiar semilla reemplaza el guardado. Errores de escritura con aviso y reintento a los 5 s; nunca se anuncia un guardado exitoso falso (solo se avisan la recuperación y los errores).
- `forest.gd` `restore()` y `destructible_prop.gd` `remove_quietly()`: aplican alturas, reconstruyen los 9 sectores, bajan objetos y retiran lo destruido sin mensajes.
- Decisiones conservadoras: un guardado de otra versión del generador no se migra (se aparta con aviso); no se guardan ajustes, posición del jugador, maná ni cristales; la lista `terrain_edits` es solo de la sesión (el guardado usa el resultado).
- `tests/save_tests.gd` (23), agregado a `Verificar.cmd`.

**Verificado ejecutando:** `run_tests` 40, `gesture_tests` 27, `destruction_tests` 8, `terrain_tests` 39, `crater_tests` 19, `save_tests` 23; 0 fallos. Guardado típico 0,3 ms; peor caso 180 KB; reabrir con cráteres ~250 ms.

**No verificado:** cierre real de ventana, rutas de `%APPDATA%` en Windows, `capture.gd`.

**Consumo:** sin acceso al saldo; no hay cifra.

**Revisar en la PC:** `Verificar.cmd` = 40 + 27 + 8 + 39 + 19 + 23. En partida: romper un árbol y hacer un cráter, cerrar con la X, abrir de nuevo y ver el aviso "Mundo recuperado" con el cráter y el árbol faltante. Buscar `mundo.json` en `%APPDATA%\BosqueArcano`. Elegir otra semilla desde el menú y comprobar que al reabrir aparece esa.

**Próximo paso:** que el usuario elija el primer problema del motor de cálculo (`docs/MOTOR-CALCULO.md`: A ruta sobre el terreno, recomendada para calibrar; B viajante chico; C empaquetado; D problema propio) y recién entonces programar el primer incremento descrito ahí.

### 2026-10-02 — misma sesión: motor de cálculo, problema A

El usuario eligió A (ruta sobre el terreno) para calibrar el motor.

**Hecho** (detalle en `docs/MOTOR-CALCULO.md`, sección Estado): `scripts/math/` con `problem.gd` (contrato), `route_problem.gd` (instancia sobre el terreno real con cráteres y destruidos, verificador con motivos, evaluador, óptimo exacto por Dijkstra, operadores), `search.gd` (aleatoria y evolutiva con igual presupuesto y semilla) y `experiment_log.gd` (`user://experimentos.jsonl`). `tests/math_tests.gd` (19) en `Verificar.cmd`. No se conectó al juego ni a la interfaz. `reference()` se llamó `optimum()` porque `RefCounted` ya tiene `reference()`.

**Verificado ejecutando:** las seis suites del juego (156) y `math_tests` 19; 0 fallos. Óptimo 48,238 en 7 ms; brecha al óptimo con 1500 evaluaciones: aleatoria 6,7–9,5 %, evolutiva 0,1–3,2 %.

**No verificado:** nada visual (no hay UI del motor). El registro real `user://experimentos.jsonl` no se escribe todavía desde el juego.

**Consumo:** sin acceso al saldo; no hay cifra.

**Revisar en la PC:** `Verificar.cmd` debe sumar `math_tests` 19 a las seis suites anteriores.

**Próximo paso:** propuestas humanas (modo mapa: dibujar la ruta, adaptador trazo → celdas con reparación registrada) y comparación humano/azar/evolutivo/híbrido con presupuestos comparables y tiempo humano aparte.

