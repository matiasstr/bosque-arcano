extends RefCounted
## Contract of the math core: no nodes, no UI, no game state.
## A problem creates and varies candidates, verifies them against its rules and evaluates
## the valid ones. Candidates are treated as immutable: operators return new arrays.
var id := "abstract"
var version := 0
var evaluator_version := 0

func random_candidate(_rng: RandomNumberGenerator) -> Array:
	push_error("%s: random_candidate sin implementar" % id)
	return []

func mutate(candidate: Array, _rng: RandomNumberGenerator) -> Array:
	return candidate.duplicate()

func combine(a: Array, _b: Array, _rng: RandomNumberGenerator) -> Array:
	return a.duplicate()

## {"valid": bool, "violations": Array[String]}
func verify(_candidate: Array) -> Dictionary:
	return {"valid": false, "violations": ["sin implementar"]}

## {"valid", "violations", "cost" (lower is better, null when invalid), "metrics", "evaluator_version"}
func evaluate(candidate: Array) -> Dictionary:
	var check := verify(candidate)
	return {"valid": check.valid, "violations": check.violations, "cost": null, "metrics": {}, "evaluator_version": evaluator_version}

## Stable text form; its SHA-256 identifies the candidate's content.
func canonical(candidate: Array) -> String:
	return "%s-v%d:%s" % [id, version, ",".join(candidate.map(func(v): return str(v)))]

## Identifies the exact instance (rules + data) the candidates belong to.
func fingerprint() -> String:
	return ""
