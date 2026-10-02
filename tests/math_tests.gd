extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Route = preload("res://scripts/math/route_problem.gd")
const Search = preload("res://scripts/math/search.gd")
const Log = preload("res://scripts/math/experiment_log.gd")
const Edit = preload("res://scripts/terrain_edit.gd")
# Own folder: never touches the player's user://experimentos.jsonl.
const DIR := "user://pruebas-motor"
const LOG_PATH := DIR + "/experimentos.jsonl"
const BUDGET := 1500
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", description])

func problem_for(d: Dictionary, ground: Dictionary = {}, destroyed: Dictionary = {}) -> Route:
	var problem := Route.new()
	problem.setup(d, ground if not ground.is_empty() else d, destroyed)
	return problem

func run() -> void:
	var d: Dictionary = Generator.generate(240926)
	var problem := problem_for(d)
	check(problem.fingerprint() == problem_for(d).fingerprint() and problem.fingerprint() != problem_for(Generator.generate(240927)).fingerprint(), "misma semilla y reglas dan la misma instancia; otra semilla, otra")
	var blocked := 0
	for b in problem.blocked:
		blocked += b
	check(problem.blocked[problem.start] == 0 and problem.blocked[problem.goal] == 0 and blocked > 50, "inicio (spawn) y destino (santuario) libres; %d de %d celdas bloqueadas por árboles y rocas" % [blocked, Route.SIDE * Route.SIDE])
	var start := Time.get_ticks_usec()
	var best: Dictionary = problem.optimum()
	print("ÓPTIMO Dijkstra: costo %.3f · %d pasos · %.1f ms" % [best.cost, best.route.size() - 1, (Time.get_ticks_usec() - start) / 1000.0])
	var graded: Dictionary = problem.evaluate(best.route)
	check(graded.valid and absf(graded.cost - best.cost) < 1e-9, "la ruta óptima es válida y el evaluador da el mismo costo")
	var r: Array = best.route
	var blocked_cell := -1
	for k in range(problem.blocked.size()):
		if problem.blocked[k] == 1:
			blocked_cell = k
			break
	var cases := [
		[[], "ruta vacía"],
		[r.slice(1), "no empieza en el inicio"],
		[r.slice(0, r.size() - 1), "no termina en el destino"],
		[[r[0], r[r.size() - 1]], "salto entre celdas no vecinas o corte de esquina"],
		[r.slice(0, 2) + [r[1]] + r.slice(2), "repite celdas"],
		[r.slice(0, 1) + [blocked_cell] + r.slice(1), "pasa por una celda bloqueada"],
	]
	var verifier_ok := true
	for case in cases:
		var result: Dictionary = problem.verify(case[0])
		verifier_ok = verifier_ok and not result.valid and result.violations.has(case[1])
	check(verifier_ok, "el verificador rechaza cada regla rota con su motivo (6 casos)")
	check(problem.evaluate(cases[3][0]).cost == null, "una ruta inválida no recibe costo")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var all_valid := true
	var never_better := true
	var candidate: Array = problem.random_candidate(rng)
	for i in range(200):
		var other: Array = problem.random_candidate(rng) if i % 20 == 0 else candidate
		var next: Array = problem.mutate(candidate, rng) if i % 2 == 0 else problem.combine(candidate, other, rng)
		var result: Dictionary = problem.evaluate(next)
		all_valid = all_valid and result.valid
		never_better = never_better and (not result.valid or result.cost >= best.cost - 1e-9)
		candidate = next
	check(all_valid, "rutas aleatorias, mutadas y combinadas son siempre válidas (200)")
	check(never_better, "ninguna ruta encontrada mejora el óptimo exacto (control del evaluador)")
	var first: Dictionary = Search.evolutionary(problem, 5, 300)
	var again: Dictionary = Search.evolutionary(problem, 5, 300)
	var random_a: Dictionary = Search.random_search(problem, 5, 300)
	var random_b: Dictionary = Search.random_search(problem, 5, 300)
	check(first.best == again.best and first.best_cost == again.best_cost and random_a.best == random_b.best, "misma semilla y presupuesto reproducen exactamente la búsqueda")
	var gaps := {"aleatoria": [], "evolutiva": []}
	var budgets_ok := true
	start = Time.get_ticks_usec()
	for seed in [1, 2, 3]:
		var random_result: Dictionary = Search.random_search(problem, seed, BUDGET)
		var evolved: Dictionary = Search.evolutionary(problem, seed, BUDGET)
		budgets_ok = budgets_ok and random_result.evaluations == BUDGET and evolved.evaluations == BUDGET
		gaps.aleatoria.append(100.0 * (random_result.best_cost / best.cost - 1.0))
		gaps.evolutiva.append(100.0 * (evolved.best_cost / best.cost - 1.0))
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	print("COMPARACIÓN %d evaluaciones por búsqueda, semillas 1–3 (brecha al óptimo): aleatoria %s · evolutiva %s · %.0f ms en total" % [BUDGET, _percent(gaps.aleatoria), _percent(gaps.evolutiva), elapsed])
	check(budgets_ok, "ambas estrategias usan exactamente el mismo presupuesto (%d evaluaciones)" % BUDGET)
	check(gaps.aleatoria.all(func(g): return g >= -1e-6) and gaps.evolutiva.all(func(g): return g >= -1e-6), "ninguna estrategia baja del óptimo (las brechas se informan, no se exige un ganador)")
	var ground := {"terrain": d.terrain.duplicate()}
	ground.terrain.heights_mm = d.terrain.heights_mm.duplicate()
	var middle: Vector2 = problem.position(best.route[best.route.size() / 2])
	for i in range(3):
		Edit.carve(ground.terrain, d.terrain.heights_mm, middle.x, middle.y, 2.2, 0.6)
	var cratered := problem_for(d, ground)
	var after: Dictionary = cratered.optimum()
	check(cratered.fingerprint() != problem.fingerprint() and absf(after.cost - best.cost) > 1e-6, "un cráter sobre la ruta cambia la instancia y su óptimo (%.3f → %.3f)" % [best.cost, after.cost])
	var opened := problem_for(d, {}, {"tree:0": true, "tree:1": true, "tree:2": true})
	var opened_blocked := 0
	for b in opened.blocked:
		opened_blocked += b
	check(opened_blocked < blocked, "árboles destruidos dejan de bloquear (%d → %d celdas)" % [blocked, opened_blocked])
	await log_checks(problem)
	print("MOTOR: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _percent(values: Array) -> String:
	return " / ".join(values.map(func(v): return "%.1f %%" % v))

func log_checks(problem: Route) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
	var journal := Log.new()
	check(journal.open(LOG_PATH, "prueba") == OK, "se abre el registro de experimentos")
	var result: Dictionary = Search.evolutionary(problem, 9, 200, journal)
	check(journal.close() == OK, "el registro se cierra sin errores")
	var read: Dictionary = Log.read(LOG_PATH)
	var records: Array = read.records
	var fields_ok: bool = records.size() == 200 and read.incomplete == 0
	var ids := {}
	var hashes := {}
	var with_parents := 0
	for entry in records:
		fields_ok = fields_ok and entry.candidate.sha256_text() == entry.candidate_hash and entry.instance == problem.fingerprint() and entry.seed == 9.0
		ids[entry.id] = true
		hashes[entry.candidate_hash] = true
		if not entry.parents.is_empty():
			with_parents += 1
	check(fields_ok and ids.size() == 200, "una línea por evaluación con candidato, huella, instancia, semilla e ID único")
	check(with_parents > 100 and records[0].operator == "aleatorio" and records[0].parents.is_empty(), "los hijos registran a sus padres y el operador (%d con padres)" % with_parents)
	check(hashes.size() < records.size(), "candidatos repetidos conservan todos sus eventos (%d únicos de %d)" % [hashes.size(), records.size()])
	var best_logged := INF
	for entry in records:
		if entry.valid:
			best_logged = minf(best_logged, entry.cost)
	check(is_equal_approx(best_logged, result.best_cost), "el mejor costo del registro coincide con el de la búsqueda")
	var text := FileAccess.get_file_as_string(LOG_PATH)
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	file.store_string(text + text.split("\n", false)[0].substr(0, 40))
	file.close()
	read = Log.read(LOG_PATH)
	check(read.records.size() == 200 and read.incomplete == 1, "una última línea cortada se detecta y no se carga")
	DirAccess.remove_absolute(LOG_PATH)
	DirAccess.remove_absolute(DIR)
