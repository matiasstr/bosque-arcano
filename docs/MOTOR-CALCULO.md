# Motor de cálculo — propuesta (sin implementar)

Parte de `docs/ARQUITECTURA-RPG-MAGIA.md` (capas, contratos `Candidate`/`Experiment`/`EvaluationResult`, comparación humano/aleatorio/evolutivo). Esta página baja eso a un primer incremento. **Falta una decisión del usuario: qué problema resolver primero.**

## Qué es y qué no

Un núcleo sin nodos ni UI que recibe un candidato, lo **verifica** (¿cumple las reglas?), lo **evalúa** (¿qué tan bueno es?) y registra cada intento con sus padres, operador, semilla y versiones. El juego solo aporta acciones (gestos, materiales) y muestra resultados. El evaluador de gestos actual es una mecánica de habilidad, no este motor. Nada de esto demuestra utilidad científica hasta medirlo contra un algoritmo de referencia.

## Opciones para el primer problema

| Opción | Verificar / evaluar | Referencia para comparar | Encaje con el juego | Valor |
|---|---|---|---|---|
| **A. Ruta sobre el terreno del juego** (recomendada para calibrar) | Ruta continua por celdas permitidas / costo por largo y pendiente | Dijkstra da el óptimo exacto | Dibujar la ruta con el mouse; los cráteres cambian costos; podría ser un hechizo "sendero rúnico" | Ninguno científico: valida el circuito completo |
| **B. Viajante pequeño (TSP, 10–40 puntos)** | Recorrido que visita todo una vez / largo total | Óptimo exacto en tamaños chicos; 2-opt | El trazo del gesto *es* un recorrido; los humanos son buenos en TSP visual chico | Clásico, bien estudiado; bueno para medir humano vs algoritmo |
| **C. Empaquetado de círculos o Tammes** | Sin solapes / distancia mínima o radio | Récords publicados (Packomania) | Colocar runas en un círculo mágico | Problemas reales con récords, pero difícil superar lo conocido |
| **D. Un problema propio del usuario** | Según el caso | Según el caso | A diseñar | El que importe de verdad |

Recomendación: **A primero** (una o dos sesiones), porque tiene respuesta exacta: si el motor, el registro o la comparación fallan, se nota enseguida. Después, **B o C/D** con el circuito ya probado.

## Primer incremento propuesto (con A, verificable sin GPU)

- `scripts/math/problem.gd`: contrato — `id`, `version`, `random_candidate(rng)`, `mutate(candidate, rng)`, `combine(a, b, rng)`, `verify(candidate)`, `evaluate(candidate)`, `canonical(candidate)`.
- `scripts/math/route_problem.gd`: instancia fija por semilla sobre una grilla del terreno (inicio, destino, celdas bloqueadas), costo = largo + pendiente; `reference()` con Dijkstra.
- `scripts/math/search.gd`: búsqueda aleatoria y evolutiva (1+λ) con **el mismo presupuesto de evaluaciones** y semilla fija.
- `scripts/math/experiment_log.gd`: `user://experimentos.jsonl`, un intento por línea (candidato canónico + hash, padres, operador, semilla, versiones, validez, métricas, costo); detecta líneas incompletas al leer.
- `tests/math_tests.gd`: reproducibilidad, verificador rechaza rutas inválidas, el evaluador coincide con Dijkstra en instancias chicas, aleatorio vs evolutivo con igual presupuesto (se informa la brecha al óptimo, sin prometer que gane nadie).
- Fuera de este incremento: gesto → candidato, materiales, UI, procesos externos y cómputo distribuido.

## Riesgos

- Elegir un problema sin referencia exacta impide saber si el motor funciona.
- Si el gesto se vuelve la única forma de proponer candidatos, el tiempo humano domina la comparación: medirlo aparte, como pide la auditoría.
- GDScript alcanza para A y B chicos; C grande o problemas científicos pesados pueden pedir un proceso externo (Python/C++) detrás de un adaptador. Decidirlo con el problema elegido.
