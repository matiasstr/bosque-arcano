# Verificación — Bosque Arcano 0.2

## Terreno por alturas — 2026-09-29, rama `claude/terreno-alturas`

Motor: Godot 4.4.1 Linux x86_64 oficial, sesión en la nube **sin GPU**. Solo suites sin ventana.

- `tests/run_tests.gd`: 40 comprobaciones, 0 fallos (3 adaptadas a la altura real: tronco, borde y spawn).
- `tests/gesture_tests.gd`: 27 comprobaciones, 0 fallos (sin cambios).
- `tests/destruction_tests.gd`: 8 comprobaciones, 0 fallos (sin cambios).
- `tests/terrain_tests.gd` (nuevo): 39 comprobaciones, 0 fallos. Cubre alturas reproducibles por semilla, layout x/z idéntico a la v1 (huellas de 4 semillas), serialización, desnivel y pendientes en 4 semillas, nivelado de claros/santuario/spawn, bordes de sectores con vértices y normales idénticos, colisión igual a la malla (2072 rayos, diferencia 0,0000 m, incluidos los bordes), recorrido físico por los 9 sectores sin despegarse del suelo (salto máximo entre frames 2 mm), spawn libre y apoyado, árboles, rocas, blancos, santuario y sotobosque apoyados.
- **No ejecutado:** `tests/capture.gd` (necesita GPU); solo se comprobó que compila. Las capturas `preview-*.png` siguen mostrando el suelo plano anterior.

Relieve medido (semilla, rango de alturas, pendiente máxima interior / sendero): 240926: −2,71 a 2,34 m, 20,6° / 20,4°; 1: −0,66 a 4,81 m, 23,9° / 6,8°; 42: −1,76 a 2,77 m, 18,1° / 18,0°; 999999999: −2,60 a 1,89 m, 17,6° / 7,6°.

Tiempos en el contenedor (4 núcleos, 7 repeticiones): descripción del mundo 71–108 ms (antes del terreno, 9–10 ms); de eso, alturas ~65 ms. Mallas y colisiones de los 9 sectores: 19–32 ms. Regenerar la escena completa (datos, terreno, árboles, rocas, sotobosque): 318–348 ms (antes 143–152 ms). Árboles: el centro del tronco queda hasta 0,38 m bajo el suelo del lado alto de la pendiente.

## Versión 0.2 — 2026-09-25

Fecha: 2026-09-25. Motor: Godot 4.4.1 Windows x64, existente en el proyecto anterior.

- `tests/run_tests.gd`: 40 comprobaciones, 0 fallos.
- `tests/gesture_tests.gd`: 27 comprobaciones, 0 fallos.
- `tests/destruction_tests.gd`: 8 comprobaciones, 0 fallos.
- `tests/capture.gd`: 23 comprobaciones gráficas, 0 fallos.
- Total: **98 comprobaciones distintas**.
- Capturas reales: menú, exploración, combate, guía de línea, guía de V, carga preparada, resultado de precisión y vista general. Se revisaron visualmente bosque e interfaz.
- Renderizado probado en Forward+ (Vulkan) y Compatibility (OpenGL) sobre NVIDIA GeForce GTX 1070. Pruebas cortas con cámara fija, 120 frames tras calentamiento, 1280 × 720: aproximadamente 16,7 ms/frame, 60 FPS con VSync en ambos. No representan FPS máximos, estabilidad prolongada, escenas de destrucción masiva ni otras GPU.

Las comprobaciones gráficas finales confirman: Ctrl desvía el mouse al trazo, WASD sigue desplazando, yaw/pitch no cambian durante el gesto, soltar Ctrl no dispara ni consume maná, el mouse puede apuntar de nuevo y el click izquierdo usa esa orientación. Click derecho cancela tanto trazo como carga. Ambos hechizos se prepararon con eventos de mouse y teclado, no solo llamadas al evaluador. Las capturas usan ejecución automatizada; no son resultados de habilidad humana.

Las pruebas de destrucción confirman daño por proyectil sobre un tronco, retirada visual/física, raycast libre después de destruir, registro de IDs, destrucción de roca y restauración al regenerar. No cubren excavación porque todavía no existe.

Las comprobaciones del generador cubren diez semillas; el recorrido físico de ida y vuelta corresponde a la semilla inicial 240926. El balance, la comodidad de Ctrl/C y la dificultad de las plantillas requieren prueba humana. Los blancos no son enemigos hostiles.

Comando de pruebas lógicas/físicas desde esta carpeta:

```powershell
& '..\duelo-arcano\tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path . --fixed-fps 120 --script res://tests/run_tests.gd
```

Comando gráfico:

```powershell
& '..\duelo-arcano\tools\godot\Godot_v4.4.1-stable_win64_console.exe' --path . --resolution 1280x720 --script res://tests/capture.gd
```

El sandbox informó avisos de acceso al almacén de certificados y de caché de shaders durante varias ejecuciones. Las suites finalizaron correctamente y los shaders renderizaron. El prototipo no requiere red. Se mantiene desactivado el registro a archivo del motor para evitar escritura de logs fuera del proyecto en este entorno.

No se validó una exportación ejecutable independiente. Jugar.cmd depende de la ubicación del motor portátil descrita en README.md; project.godot permite importar el juego con una instalación de Godot 4.4.1.
