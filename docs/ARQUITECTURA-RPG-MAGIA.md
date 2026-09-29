# Auditoría y propuesta: exploración, magia y búsqueda matemática

Fecha: 2026-09-24. Auditoría realizada antes de modificar código. Posteriormente el usuario autorizó comenzar el punto 1 y aclaró que la magia también debe ser ofensiva. La primera entrega está en el proyecto independiente `bosque-arcano`; ver su README. El prototipo anterior no fue modificado.

## Conclusión

Recomiendo **B: un nuevo proyecto Godot, portando componentes concretos**. La base actual es un prototipo FPS local pequeño; conserva trabajo útil, pero su organización gira alrededor de una arena de práctica. El nuevo ciclo será explorar → recolectar → experimentar → evaluar → descubrir → volver a explorar.

Mantendría el prototipo existente como referencia ejecutable. El proyecto nuevo tendría su propio `project.godot` y sus propias pruebas. No extraería una biblioteca compartida entre ambos salvo que aparezca una necesidad real de mantener los dos productos. La selección de componentes se realizó antes de implementar la primera etapa.

## Evidencia y alcance de la revisión

Revisados `project.godot`, los scripts de juego, el mapa Ciudadela, documentación y referencias a pruebas. El repositorio estaba limpio en `main`, siguiendo `origin/main`. La revisión fue estática: no se volvieron a ejecutar las pruebas. `VERIFICACION.md` registra 89 verificaciones anteriores de la versión 0.3; eso no valida todavía el RPG propuesto.

El proyecto disponible es Godot 4.4.1 + GDScript. No contiene networking, lobby, equipos 5v5, inventario, fabricación de hechizos, generación por semillas ni motor matemático. La lista del documento recibido describe sistemas potenciales, no funcionalidades ya implementadas. El Atrio y La Ciudadela crean geometría mediante código, pero sus distribuciones son fijas.

| Componente | Evidencia | Decisión propuesta |
|---|---|---|
| Movimiento y cámara | `scripts/player.gd:66`, `:105`, `:140` | Portar a un controlador de exploración. Separar entrada, movimiento y lanzamiento. Conservar sensibilidad, colisiones y salto; hacer configurables las penalizaciones del shooter. |
| Estado de lanzamiento | `scripts/weapon_state.gd:1` | Aprovechar separación del input, cooldown y maná. Sustituir índices y arreglos fijos de tres hechizos por identificadores y definiciones dinámicas. |
| Impactos y proyectiles | `scripts/combat.gd:37`, `:65` | Extraer consultas de impacto y avance de proyectiles. Quitar dependencias directas de estadísticas, práctica y sonidos. Mantener hitboxes cuando el nuevo combate las necesite. |
| Geometría provisional | `scripts/geometry.gd` | Reutilizar helpers para el bosque inicial; separar descripción del mundo de creación de nodos y colisiones. |
| Coordinador actual | `scripts/arena.gd:35`, `:178`, `:222` | Reemplazar en el RPG. Mezcla construcción del mundo, jugadores, práctica, menú, reinicios, audio y persistencia. |
| UI | `scripts/hud.gd:22`, `:111` | Aprovechar estilo y controles básicos; construir inventario y experimentación nuevos. El HUD actual lee y modifica la arena directamente. |
| Mapas y blancos | `scripts/maps/citadel.gd`, `scripts/target.gd` | Conservar en el prototipo como referencia; no convertirlos en generador ni IA de exploración. Los bots se desplazan lateralmente y no navegan por terrenos. |
| Ensayos y estadísticas | `scripts/practice_session.gd` | Excluir del RPG inicial. Sus puntos por bajas/headshots no representan calidad matemática. |
| Persistencia | `scripts/arena.gd:241`, `:285` | Reemplazar por almacenamiento versionado del mundo, inventario y experimentos. El historial actual solo conserva 20 ensayos. |
| Pruebas | `tests/run_tests.gd`, `tests/map_tests.gd` | Portar comprobaciones útiles de movimiento y colisiones, adaptándolas a los contratos nuevos. Las pruebas actuales dependen de la arena. |

## Comparación de estrategias

- **A — transformar el shooter:** permite reutilizar rápido la escena, pero acumula modos, condicionales y referencias a `arena`. Cada sistema nuevo terminaría negociando con reinicios de práctica, índices de hechizos fijos y estadísticas globales. No la recomiendo.
- **B — proyecto nuevo y portado selectivo:** permite conservar comportamiento probado y diseñar contratos adecuados. Es la recomendación porque el núcleo reutilizable es pequeño y todavía no hay una infraestructura de red que recuperar.
- **C — monorepo con biblioteca compartida:** tendría sentido si ambos juegos continuaran activos. Hoy añade mantenimiento de interfaces y sincronización entre productos sin una necesidad demostrada.

Deuda concreta de A: `player.gd` lanza mediante `arena.combat`, escribe `arena.hud` y `arena.deaths`, y obtiene allí su respawn. `combat.gd` registra directamente ensayos y tiros. La UI conoce modos y campos internos. Antes de reutilizarlos hay que reemplazar esos accesos por dependencias explícitas y eventos de dominio. El chequeo de techo del jugador también necesita pasar de rayo central a volumen antes de probar geometría irregular.

## Arquitectura propuesta

Inicialmente mantendría Godot y GDScript para el cliente y un núcleo matemático pequeño sin nodos, física ni UI. Las capas son límites de responsabilidad, no tres servidores desde el primer día. Si el problema real requiere bibliotecas científicas o mucho cómputo, un adaptador podrá llamar a un proceso externo; su lenguaje se decidirá con ese problema definido.

```text
Juego: exploración, materiales, inventario, rituales, combate, UI
        ↓ GameAction
Adaptador de problema: materiales + gesto → operación matemática
        ↓ CandidateMutation
Núcleo matemático: candidato → verificación → evaluación
        ↓ EvaluationResult
Aplicación: guardar experimento y relaciones entre candidatos
        ↓ presentación de propiedades
Juego: nuevo hechizo, efectos, información para el siguiente intento
```

1. **Juego.** Controlador del jugador, mundo, interacción, inventario, hechizos y presentación. Recibe propiedades de hechizos y estados de evaluación. No implementa la función objetivo.
2. **Núcleo matemático.** Un contrato de problema con creación, combinación/mutación, verificación y evaluación. La búsqueda local y otros operadores se añaden según el problema. Debe poder probarse sin abrir un mapa.
3. **Investigación y persistencia.** Conserva candidatos, intentos y evaluaciones; organiza experimentos y presupuestos. Primero local. Después podrá repartir trabajos y comparar estrategias.

El adaptador depende del problema elegido: reemplazar el problema puede exigir otro mapeo de materiales, gestos y propiedades. No implica rehacer movimiento, inventario o presentación del mundo. Evitar una abstracción universal que prometa representar cualquier problema sin adaptación.

### Contratos mínimos

- `GameAction`: versión, materiales seleccionados, contexto del ritual y referencia a la trayectoria capturada.
- `GestureTrace`: muestras con tiempo y sistema de coordenadas definido; conservar captura original y transformación normalizada. Remuestrear antes de interpretar el gesto para reducir dependencia de FPS y frecuencia del mouse.
- `Candidate`: `problem_id`, versión de representación y datos matemáticos canónicos e inmutables.
- `Experiment`: identificador propio, candidatos padres —pueden ser varios—, operador, parámetros, semilla, candidato resultante y versión del adaptador. Un candidato duplicado puede tener distintos caminos de descubrimiento: no borrar esos eventos al deduplicar contenido.
- `EvaluationResult`: validez, violaciones, métricas, score, versión del evaluador y costo de evaluación. El verificador valida restricciones; un score alto no prueba optimalidad global.
- `SpellProperties`: valores jugables derivados mediante reglas documentadas y versionadas. Un porcentaje de estabilidad debe tener una definición explícita; no se inventa para decorar la interfaz.

Separar identidad del candidato de su evaluación: el mismo candidato puede evaluarse bajo diferentes versiones. Usar serialización canónica para identificadores por contenido. Guardar también intentos inválidos, útiles para analizar la búsqueda.

La persistencia inicial puede ser un registro local JSONL de experimentos y archivos de candidatos, detrás de una interfaz de almacenamiento. Debe detectar registros incompletos al cargar y no comunicar éxito de guardado ante un error. Ajustes y partidas irían en `user://`, ubicación de datos persistentes prevista por Godot, en lugar de `res://`. [Documentación oficial](https://docs.godotengine.org/en/4.4/tutorials/io/data_paths.html).

## Bosque procedural acotado

Propuesta inicial: área de unos 64 × 64 metros, dos claros, caminos conectados, árboles, rocas, tres materiales y un lugar de experimentación. Generación al entrar, con límites visibles y sin carga infinita de terreno.

```text
WorldSeed + GenerationRulesVersion + MathematicalContext opcional
                          ↓
                    WorldDescription
                          ↓
               nodos, colisiones y recursos
```

El generador produce datos antes de construir la escena. El contexto matemático contiene parámetros acotados que el generador entiende; no referencias al evaluador. Sin contexto, el bosque sigue funcionando con sus reglas normales.

Separar flujos aleatorios de terreno, vegetación y recursos para que agregar una variante visual no redistribuya los materiales. Registrar seed, versiones del generador y motor, reglas y contexto. Godot documenta secuencias reproducibles con seed, pero advierte que el algoritmo interno es un detalle de implementación: no prometer idénticos resultados entre versiones arbitrarias. [Documentación oficial](https://docs.godotengine.org/en/4.4/classes/class_randomnumbergenerator.html).

Validar spawn libre, rutas conectadas, recursos alcanzables y ausencia de solapamientos bloqueantes. Acotar los intentos de colocación y disponer de una distribución de respaldo. Dar IDs estables a recursos para guardar cuáles se recolectaron; regenerar el bosque no debe duplicar el inventario. El contexto matemático se fija para esa generación y no cambia silenciosamente el mapa durante un experimento.

## MVP y criterios de aceptación

| Etapa | Resultado jugable | Comprobación |
|---|---|---|
| 1. Exploración | Controlador portado y bosque generado por seed | Misma entrada y versiones producen la misma descripción; se recorren caminos y recursos sin quedar bloqueado. |
| 2. Recolección | Tres materiales e inventario mínimo | Un recurso se recoge una sola vez; guardar y cargar conserva inventario y agotamiento del mundo. |
| 3. Ritual | Combinar materiales y dibujar un gesto con el mouse | La trayectoria queda registrada y normalizada; el modo ritual distingue dibujar de mover la cámara. |
| 4. Experimento | Acción traducida, candidato, verificación y evaluación | Repetir datos y versiones reproduce el resultado; entradas inválidas producen un motivo claro. |
| 5. Descubrimiento | Propiedades del hechizo y consulta de sus antecedentes | Puede cerrarse el juego, abrirlo y reconstruir materiales, gesto, padres, operación y evaluación. |

Estas cinco etapas cubren los diez puntos del MVP solicitado. El primer incremento sería solamente la etapa 1. El recoil puede conservarse como parámetro opcional de lanzamiento, pero su papel se decide después de probar el nuevo ciclo de juego.

### Problema inicial pendiente

Falta elegir el problema matemático real. Si todavía no está definido, propongo uno de calibración: buscar rutas cortas sobre una grilla pequeña con inicio, destino y obstáculos fijos. El gesto propone o modifica una ruta; los materiales habilitan operadores; el verificador comprueba continuidad y celdas permitidas, y el evaluador calcula longitud/costo. Puede contrastarse con un solucionador exacto para detectar errores del prototipo. Las reglas y el objetivo se mantienen fijos dentro del experimento; no cambian para favorecer una receta.

Este ejemplo valida el circuito técnico y la claridad de la interacción. No demuestra utilidad científica ni garantiza que los jugadores superen a un algoritmo. La selección queda pendiente de la respuesta del usuario.

## Comparación de búsquedas y distribución posterior

Primero comparar humano y aleatorio sobre las mismas instancias, representación, operadores y cantidad de evaluaciones. Después agregar evolutivo y humano + evolutivo; el presupuesto del modo combinado debe incluir ambas fuentes. Registrar tiempo humano, tiempo de cómputo, evaluaciones, validez y mejor resultado por presupuesto; usar varias instancias y semillas. El tiempo de explorar y recolectar se mide por separado o se igualan materiales iniciales en el modo experimental.

La ventaja humana es una hipótesis a medir. Conviene mostrar resultados también frente a un solucionador de referencia cuando exista, no solo frente a azar.

Más adelante la capa distribuida tendrá trabajos con problema y versiones, límite de cómputo, entradas y estado; trabajadores devolverán candidatos y evidencia. El coordinador deduplicará entregas y verificará o reevaluará resultados según el problema, en vez de confiar en scores declarados por clientes. El multiplayer del juego y la distribución de trabajos son sistemas distintos: ninguno es requisito para validar el MVP local. Surrogate models, ranking online y coordinación remota quedan fuera de esta primera implementación.

## Siguiente paso propuesto

El usuario autorizó empezar por exploración y aclaró que la magia debe tener uso ofensivo. Se implementó el proyecto separado Bosque Arcano 0.1: bosque por seed, controlador de movimiento, pulso ofensivo y blancos. La siguiente etapa propuesta es recolección e inventario, para después conectar materiales y gestos a hechizos utilizables en combate. La elección del problema matemático sigue pendiente; no se implementó evaluación científica ni computación distribuida.
