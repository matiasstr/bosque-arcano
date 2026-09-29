# Bosque Arcano

Proyecto independiente Godot 4.4.1 + GDScript. Leer README.md, CLAUDE.md (bitácora) y docs/ARQUITECTURA-RPG-MAGIA.md.

- Objetivo actualizado: RPG de exploración y magia con usos ofensivos, futura creación de hechizos mediante materiales y gestos. El usuario priorizó empezar por un bosque procedural pequeño.
- Mantener separación entre controlador, descripción del mundo, presentación, combate y UI. No introducir dependencias hacia Duelo Arcano; sus accesos solo comparten el ejecutable del motor.
- Versión 0.2: Ctrl + trazo PREPARA; soltar devuelve cámara, click izquierdo LANZA, click derecho/Q CANCELA. WASD sigue activo, sin cámara lenta. C agacha. No volver a disparar automáticamente al soltar Ctrl.
- No afirmar que existen inventario, recolección, investigación matemática, red o enemigos hostiles: no están implementados.
- La prioridad nueva es mundo natural destructible sin construcción de bloques. Ya se pueden romper árboles y rocas; suelo/santuario/límites no. Destrucción en memoria, todavía sin guardado. Ver GESTOS-Y-MUNDO.md antes de ampliar terreno.
- El generador debe reservar caminos, ser acotado y reproducible con sus versiones. Si cambian sus reglas, incrementar su versión y documentar impacto sobre semillas.
- No cambiar el prototipo anterior como parte de tareas de este proyecto.
- Probar movimiento/mundo/combate con tests/run_tests.gd; gestos/carga con tests/gesture_tests.gd; destrucción con tests/destruction_tests.gd. Usar tests/capture.gd y revisar imágenes si cambia presentación o entrada.
- Jugar.cmd usa Forward+; Jugar-ligero.cmd Compatibility. Assets actuales son originales por código, sin paquetes importados. Rendimiento observado: prueba corta 60 FPS a 720p con VSync sobre GTX 1070, no garantía universal.
- Cuidar presupuesto: incrementos pequeños. No prometer un aviso al 50 % de créditos sin acceso real al saldo.
- No versionar motores, .godot ni archivos de datos del usuario. No migrar a multiplayer o servicios remotos hasta completar el MVP local.
