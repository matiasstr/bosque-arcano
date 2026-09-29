# Bosque Arcano: contexto para continuar en Claude

Estado revisado el 28/09/2026. Este documento distingue lo implementado de las propuestas. El código adjunto corresponde al prototipo local 0.2.

## Pedido para Claude

Quiero que continúes un juego de magia y exploración que ya estoy desarrollando. Primero leé este resumen, AGENTS.md, README.md, GESTOS-Y-MUNDO.md y el código relevante del proyecto adjunto. No empieces de cero ni cambies de motor sin justificarlo. Conservá las mecánicas que ya funcionan.

Mi prioridad más reciente es un mundo natural procedural con desniveles, vegetación y destrucción del entorno. No quiero construcción con bloques. Quiero que la magia sirva para combatir y, progresivamente, para romper árboles, rocas, estructuras y terreno. La mecánica de habilidad principal usa trazos precisos del mouse para preparar hechizos, y después un click para dispararlos.

El siguiente incremento propuesto es una región pequeña con colinas, cráteres y persistencia de destrucción. Antes de una migración grande del terreno, revisá las dependencias actuales y proponé una implementación acotada con sus riesgos. Trabajá en incrementos pequeños, verificables y jugables. No intentes construir todo el RPG o multiplayer de una sola vez. Si no podés ejecutar Godot, indicá qué verificaste por lectura y qué no probaste.

## 1. Qué juego queremos

- RPG de exploración y magia ofensiva, con habilidad real del jugador: puntería, movimiento y ejecución precisa de gestos.
- Mundo natural, bosque, colinas/valles y eventualmente cuevas, regiones y biomas. Generación reproducible mediante semilla.
- Destrucción del entorno. La comparación con Minecraft se refiere a generación por sectores, extensión del mundo y posibilidad de modificarlo; no a su estética cúbica ni a construir con bloques.
- Referencia artística: bosque de fantasía con árboles altos, vegetación densa, helechos, suelo natural, sombras profundas y luz filtrada con bruma. La referencia enviada era en tercera persona; el prototipo actual sigue en primera persona. No se decidió cambiar de cámara.
- A largo plazo también interesa crear hechizos con materiales y gestos, y conectar las acciones a un motor matemático de búsqueda/investigación. Esa capa todavía no está implementada ni tiene un problema científico concreto elegido.

## 2. Proyectos y ubicación

Hay dos proyectos distintos:

1. **Duelo Arcano 0.3**, prototipo anterior de FPS local de magos: aim, recoil, tres hechizos, bots de práctica, estadísticas y dos mapas fijos. Queda como referencia; no es el proyecto activo. Aunque la idea original mencionaba 5v5, nunca se implementó multiplayer, lobby ni servidor.
2. **Bosque Arcano 0.2**, proyecto activo nuevo, con portado selectivo de componentes. No depende del código del shooter.

Stack actual: **Godot 4.4.1 + GDScript**, Windows, física a 120 Hz. Primera persona. Forward+ por defecto, alternativa Compatibility. No usa Unity, Unreal, C# ni .NET.

En la máquina original:

```text
C:\Users\PC\Documents\Codex\2026-09-18\vi-q\outputs\bosque-arcano
C:\Users\PC\Documents\Codex\2026-09-18\vi-q\outputs\duelo-arcano
```

El ZIP contiene `bosque-arcano/`, la auditoría original y este resumen. No incluye el motor, cachés ni el código del shooter anterior.

GitHub: el proyecto anterior está en el repositorio privado `https://github.com/matiasstr/duelo-arcano`, rama main. Bosque Arcano está local y **todavía no fue publicado allí**. No asumir que clonar ese repositorio trae el código actual del bosque.

## 3. Controles y decisiones ya confirmadas

**Esta es la mecánica final aprobada; reemplazó una versión que disparaba al soltar Ctrl:**

1. Mouse normalmente: apuntar y girar cámara.
2. Mantener Ctrl: dibujar el gesto. La cámara conserva yaw/pitch; WASD, correr y saltar siguen funcionando. No hay cámara lenta ni cambio de escala temporal.
3. Soltar Ctrl: evaluar el gesto y **PREPARAR una carga**, sin disparar ni gastar maná.
4. Se puede volver a apuntar con el mouse y moverse con la carga preparada.
5. **Click izquierdo: DISPARAR**, desde la posición y orientación actuales; entonces consumir carga y maná.
6. **Click derecho o Q: CANCELAR** el trazo o descartar la carga.

Solo se almacena una carga. Empezar un nuevo trazo la reemplaza. Se puede preparar mientras transcurre el cooldown, pero el click no lo elude; si falta maná o cooldown, conserva la carga para intentar disparar después. Cambio de hechizo, pausa, pérdida de foco, respawn y regeneración descartan carga/trazo. No hay disparo automático al mantener click.

Otros controles: 1/2 seleccionan hechizo, Shift corre, **C agacha**, Espacio salta, Esc pausa, F5 vuelve al inicio, F11 alterna pantalla completa. Ctrl ya no agacha.

Se usa mouse capturado y `screen_relative`, con eventos sin acumulación. Los desplazamientos utilizados para el dibujo nunca se suman después a la cámara. El bloqueo conserva orientación: caminar sí traslada la cámara y puede cambiar dónde apunta respecto del escenario.

## 4. Hechizos y evaluación de precisión

| Hechizo | Gesto | Daño aceptable → perfecto | Maná aceptable → perfecto | Velocidad | Cooldown |
|---|---|---|---|---|---|
| Aguja de Luz, tecla 1 | Línea hacia abajo | 18 → 36 | 16 → 10 | 34 m/s | 0,28 s |
| Brasa Rúnica, tecla 2 | V: abajo-derecha, arriba-derecha | 26 → 52 | 24 → 16 | 22 m/s | 0,55 s |

Más precisión aumenta daño y reduce maná. Mejorar la ejecución permite preparar más rápido; el tiempo no da bonus por sí mismo ni hay una animación obligatoria de carga.

Evaluador actual, independiente de nodos:

- Remuestreo de 32 puntos uniformes por longitud recorrida.
- Ignora traslación y tamaño uniforme; conserva orientación, sentido y proporciones.
- Penaliza desviación, retrocesos y forma incorrecta.
- `q = clamp(1 - 4 * (0.8 * error_medio + 0.2 * error_final), 0, 1)`.
- Umbral de aceptación: 0,55. Maestría de balance: `clamp((q - 0.55) / 0.45, 0, 1)`.
- Mínimo 45 px para Aguja y 75 px para Brasa; máximo 1600 px y 2048 muestras.
- Daño y costo se redondean a centésimas. El porcentaje mostrado mide ajuste a la plantilla, no probabilidad de acertar.
- Un gesto inválido pierde el tiempo utilizado pero no maná. Este balance todavía requiere prueba humana.

Maná máximo 100; regenera 18/s tras 0,8 s sin disparar. Proyectiles de punto con comprobación de todo el segmento por tick y vida máxima de 2,5 s. La calidad se fija al disparar y no cambia por seleccionar otra magia.

## 5. Mundo y gráficos implementados

- Mapa finito de **64 × 64 m**, suelo plano, dos claros, sendero, santuario y límites físicos.
- Seed inicial 240926. Misma semilla y versiones reconstruyen la distribución.
- 155 árboles y 28 rocas en la semilla inicial; se reservan corredores y claros. Las semillas varían vegetación, rocas y algunos puntos del sendero; no generan topologías completamente nuevas.
- Árboles ramificados con hojas; pasto/helechos con viento; materiales procedurales para corteza, roca y suelo; niebla, sombras, estelas e impactos.
- Mallas compartidas y vegetación con MultiMesh por sectores, mayor detalle en el primer tramo de unos 24 × 23 m. Estos sectores visuales NO son streaming de terreno.
- Forward+ añade niebla volumétrica y SSAO; `Jugar-ligero.cmd` usa Compatibility.
- Assets originales hechos por código. No hay paquetes de arte descargados ni modelos de Blender. El resultado es una mejora de prototipo, todavía lejos del acabado de la referencia.
- Tres cristales de práctica de 90 de vida, respawn a los 3 s. Son blancos, no enemigos que ataquen.

## 6. Destrucción actual y límites

- Árboles: 90 de vida. Rocas: 60. Reciben daño por hechizos.
- Al romperlos se retiran sus visuales y colisiones. IDs destruidos registrados en memoria.
- No hay caída física de árboles, fragmentos, botín ni fractura arbitraria.
- **Regenerar o cerrar restaura lo destruido. No existe persistencia aún.**
- Suelo, santuario, límites y vegetación decorativa todavía no se destruyen.
- Todavía no existen colinas, excavación, terreno volumétrico, chunks de terreno, streaming, biomas ni mundo infinito.

También faltan inventario, recolección, recetas de creación de hechizos, guardado de ajustes, enemigos hostiles, sistema completo de daño al jugador, multiplayer, motor científico, lineage y coordinación distribuida.

## 7. Mapa del código

| Archivo | Responsabilidad |
|---|---|
| `scripts/game.gd` | Conectar componentes, pausa, crear/regenerar mundo y transferir preparación a lanzamiento. |
| `scripts/explorer.gd` | Movimiento y cámara; `aim_locked` evita giro durante trazo. |
| `scripts/gesture_caster.gd` | Input y estados de trazo/carga; señales `spell_prepared` y `launch_requested`. |
| `scripts/gesture_math.gd` | Evaluación pura de forma y sentido. |
| `scripts/spell_catalog.gd` | Balance y conversión de calidad a estadísticas. |
| `scripts/magic_combat.gd` | Maná, cooldown, proyectiles, impactos y efectos. |
| `scripts/world_generator.gd` | Descripción serializable por seed; no crea nodos. |
| `scripts/forest.gd` | Materializar mapa, colisiones, objetos y registro de destrucción. |
| `scripts/forest_assets.gd` | Biblioteca procedural de árboles y sotobosque. |
| `scripts/destructible_prop.gd` | Vida y destrucción de árboles/rocas. |
| `scripts/practice_target.gd` | Blancos con vida y respawn. |
| `scripts/hud.gd`, `scripts/gesture_overlay.gd` | Menú, estado, guía y trazo. |
| `assets/shaders/` | Suelo, corteza/roca y follaje. |

La versión de distribución procedural sigue siendo 1. Su huella identifica datos del layout, no equivalencia de física/render entre versiones. El contexto matemático opcional se copia como dato, pero todavía no influye en el bosque.

## 8. Próximo incremento propuesto, todavía NO implementado

Objetivo: una región pequeña de terreno natural con desniveles, un cráter producido por un hechizo y persistencia al cerrar/abrir.

Para poder excavar y eventualmente crear cuevas/voladizos, la propuesta es evaluar terreno volumétrico de densidad/SDF con malla suave. Las celdas serían internas; visualmente no habría cubos ni construcción de bloques. Un mapa de alturas basta para colinas, pero no para todas esas excavaciones.

Antes de integrar una solución:

1. Comparar implementación acotada propia con una extensión compatible con Godot 4.4.1; no hay una extensión ya seleccionada/instalada.
2. Probar una región pequeña, por ejemplo 3 × 3 sectores. Posiciones, altura del spawn, vegetación, blancos y santuario hoy asumen suelo plano: adaptar su colocación y sus pruebas.
3. Compartir muestras/bordes entre sectores; reconstruir malla y colisión afectadas tras destruir. Evitar grietas, colisiones obsoletas y árboles flotantes.
4. Guardar seed, versión, objetos destruidos y ediciones del terreno; comprobar que volver a cargar conserva todo.
5. Medir costo de generación, destrucción y memoria antes de añadir streaming alrededor del jugador.
6. Dejar biomas, cuevas extensas, fractura de estructuras y mundo muy grande para incrementos posteriores.

Criterios de aceptación: caminar por colinas, destruir un trozo del suelo, entrar/salir del cráter, destruir cerca de una frontera sin grietas, recargar conservando cambios y mantener intactos los controles de gestos y disparo.

La destrucción total es una visión a largo plazo; retirar un árbol, fracturar una estructura y excavar suelo requieren sistemas diferentes. No afirmar que todo es destructible cuando solo se hayan implementado algunos objetos.

## 9. Arquitectura matemática a largo plazo

El usuario propuso tres capas: juego, núcleo matemático e investigación distribuida. Flujo deseado:

`GameAction → MathematicalAction → CandidateMutation → EvaluationResult → GameFeedback`.

Materiales y gestos podrían proponer candidatos; el verificador comprueba restricciones, el evaluador puntúa, se guardan padres/operaciones/resultados y se presentan propiedades del hechizo. El problema matemático debe poder cambiar mediante un adaptador. Más adelante interesan comparaciones entre búsqueda humana, aleatoria, evolutiva e híbrida bajo presupuestos comparables.

Todo esto sigue conceptual. La evaluación geométrica de trazos ya implementada es una mecánica de habilidad; no demuestra utilidad científica ni constituye la infraestructura distribuida. No mezclar ese proyecto de investigación con la siguiente mejora de terreno.

## 10. Ejecutar y verificar

Importar `bosque-arcano/project.godot` con Godot 4.4.1 estándar. Los `.cmd` buscan el motor de la máquina original en `../duelo-arcano/tools/godot/`; en otro equipo hay que usar una instalación propia. El ZIP no incluye ese ejecutable.

Desde la carpeta `bosque-arcano`, si Godot está en PATH:

```text
godot --path .
godot --path . --rendering-method gl_compatibility
godot --headless --path . --fixed-fps 120 --script res://tests/run_tests.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gesture_tests.gd
godot --headless --path . --fixed-fps 120 --script res://tests/destruction_tests.gd
godot --path . --resolution 1280x720 --script res://tests/capture.gd
```

Última ejecución documentada, 25/09/2026: **98 comprobaciones aprobadas**: 40 mundo/combate, 27 gestos/carga, 8 destrucción, 23 gráficas. La suite gráfica se ejecutó en ambos renderizadores. Para preparar este paquete el 28/09 se revisaron los archivos; no se volvieron a ejecutar las pruebas.

Hardware probado: GTX 1070. Prueba corta a 1280 × 720, 120 frames y VSync: unos 60 FPS en ambos renderizadores. No es un benchmark sin límite ni una garantía para terreno volumétrico o destrucción masiva. El entorno restringido emitió avisos de certificados/caché de shaders; los tests y render finalizaron. No hay exportación ejecutable independiente validada.

## 11. Forma de trabajo

- Mantener español en UI y explicaciones claras.
- Conservar separación entre controlador, gestos, combate, mundo, presentación y futura matemática.
- Respetar la distinción preparar/disparar: no volver al lanzamiento al soltar Ctrl.
- Evitar reescrituras grandes, dependencias innecesarias y trabajo online antes de validar el prototipo local.
- Revisar capturas reales al cambiar apariencia o UI; verificar colisiones y recorrido cuando cambie el terreno.
- El usuario cuida créditos y prefiere incrementos pequeños. No prometer un aviso al 50 % de créditos si no hay acceso al saldo real.
- Si Claude funciona como chat sin acceso a archivos locales, usar el ZIP adjunto. Si no puede abrir ZIP, descomprimirlo y adjuntar este resumen y los scripts relevantes.

La captura `bosque-arcano/preview-cargado.png` muestra el estado actual. La auditoría original incluida sirve de contexto histórico; este resumen y las decisiones de GESTOS-Y-MUNDO.md son posteriores.
