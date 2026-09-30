# Guardado local del mundo — plan

Alcance: recordar el mundo al cerrar y abrir el juego. No incluye ajustes, posición del jugador, inventario, varias ranuras ni sincronización en línea.

## Qué se guarda

`user://mundo.json` (carpeta de datos del usuario de Godot: `%APPDATA%\BosqueArcano` en Windows, fuera del proyecto):

- `format` (1), `seed`, `generator_version`, `engine_version`.
- `destroyed`: IDs de árboles y rocas destruidos (`tree:12`, `rock:3`), ordenados.
- `dug`: pares `[muestra, milímetros]` con cuánto bajó cada muestra respecto del terreno base. Es el resultado de todos los cráteres, no su historial: el tamaño queda acotado por la grilla (a lo sumo 17.689 muestras) aunque se disparen miles de hechizos.
- `checksum`: huella SHA-256 del contenido, para detectar archivos incompletos o alterados.

Al cargar se regenera la base con la semilla y se aplican los cambios: alturas, reconstrucción de los 9 sectores, objetos que bajan con el suelo y retiro de lo destruido, sin mensajes de destrucción.

## Cuándo se guarda

- Un segundo después del último cambio (árbol, roca o cráter), para no escribir en cada impacto.
- Al pausar (Esc o perder el foco) y al cerrar la ventana, si hay cambios pendientes.
- Al regenerar o elegir otra semilla desde el menú: regenerar sigue siendo un reinicio explícito del mundo.

Solo el juego real guarda: `main.tscn` activa `persistence`. Los tests crean el juego sin persistencia o con una ruta propia, así nunca pisan la partida del usuario.

## Errores (sin anunciar éxitos falsos)

- Escritura en `mundo.json.tmp` y después reemplazo del archivo. Si al abrir solo existe el `.tmp` válido (corte entre ambos pasos), se usa ese.
- Si el archivo no se puede leer, está incompleto, falla la huella, tiene otro formato o **otra versión del generador**, no se carga: se conserva como `mundo.json.invalido` y se empieza un mundo nuevo con un aviso en pantalla. Migrar partidas entre versiones del generador queda pendiente.
- Si una escritura falla se muestra el error y el cambio queda pendiente para el próximo intento.

## Riesgos

1. En Windows, Godot borra el archivo anterior antes de renombrar el `.tmp`: un corte justo ahí deja solo el `.tmp` (cubierto por la recuperación de arriba).
2. La huella detecta daño, no impide editar el archivo a mano recalculándola: no es una protección contra trampas.
3. Cambiar las reglas del generador invalida los guardados anteriores hasta que exista una migración.
4. Los cristales de práctica, la posición del jugador y el maná no se guardan.
