# Verificación — Bosque Arcano 0.2

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
