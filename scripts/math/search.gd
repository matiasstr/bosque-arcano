extends RefCounted
## Search strategies under the same evaluation budget. Same problem + seed + budget gives the
## same result. Every evaluation can be written to an experiment log.

## Best-so-far curve per evaluation, so strategies can be compared at any budget.
static func random_search(problem, seed: int, budget: int, journal = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var state := {"best": [], "best_cost": INF, "curve": PackedFloat64Array(), "evaluations": 0}
	while state.evaluations < budget:
		_evaluate(problem, problem.random_candidate(rng), [], "aleatorio", "aleatoria", seed, state, journal)
	return state

## (μ + λ): each child is a mutation of a parent, sometimes combined with a second parent first.
static func evolutionary(problem, seed: int, budget: int, journal = null, mu := 4, lam := 8, combine_rate := 0.3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var state := {"best": [], "best_cost": INF, "curve": PackedFloat64Array(), "evaluations": 0}
	var population := []
	while population.size() < mu and state.evaluations < budget:
		var first: Array = problem.random_candidate(rng)
		var result := _evaluate(problem, first, [], "aleatorio", "evolutiva", seed, state, journal)
		if result.valid:
			population.append({"candidate": first, "cost": result.cost, "hash": result.hash})
	while state.evaluations < budget and not population.is_empty():
		for child_index in range(lam):
			if state.evaluations >= budget:
				break
			var a: Dictionary = population[rng.randi_range(0, population.size() - 1)]
			var child: Array = a.candidate
			var parents := [a.hash]
			var operator := "mutación"
			if population.size() > 1 and rng.randf() < combine_rate:
				var b: Dictionary = population[rng.randi_range(0, population.size() - 1)]
				child = problem.combine(a.candidate, b.candidate, rng)
				parents.append(b.hash)
				operator = "combinación+mutación"
			child = problem.mutate(child, rng)
			var result := _evaluate(problem, child, parents, operator, "evolutiva", seed, state, journal)
			if result.valid:
				population.append({"candidate": child, "cost": result.cost, "hash": result.hash})
		# Keep the μ best. sort_custom is not stable, but it is deterministic for the same input.
		population.sort_custom(func(x, y): return x.cost < y.cost)
		population = population.slice(0, mu)
	return state

static func _evaluate(problem, candidate: Array, parents: Array, operator: String, search: String, seed: int, state: Dictionary, journal) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result: Dictionary = problem.evaluate(candidate)
	var usec := Time.get_ticks_usec() - start
	result["hash"] = journal.record(problem, candidate, parents, operator, search, seed, result, usec) if journal != null else problem.canonical(candidate).sha256_text()
	state.evaluations += 1
	if result.valid and result.cost < state.best_cost:
		state.best_cost = result.cost
		state.best = candidate
	state.curve.append(state.best_cost)
	return result
