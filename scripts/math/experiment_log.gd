extends RefCounted
## JSONL record of every evaluation: one attempt per line, never rewritten.
## Repeated candidates keep all their events; deduplicate by candidate_hash when analysing.
const FORMAT := 1
const DEFAULT_PATH := "user://experimentos.jsonl"
var file: FileAccess
var run_id := ""
var count := 0

func open(path: String, run: String) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	file = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	run_id = run
	count = 0
	return OK

func record(problem, candidate: Array, parents: Array, operator: String, search: String, seed: int, result: Dictionary, usec: int) -> String:
	var text: String = problem.canonical(candidate)
	var hash := text.sha256_text()
	var line := {"format": FORMAT, "id": "%s:%d" % [run_id, count], "run": run_id, "problem": problem.id,
		"problem_version": problem.version, "instance": problem.fingerprint(), "candidate": text,
		"candidate_hash": hash, "parents": parents, "operator": operator, "search": search, "seed": seed,
		"evaluator_version": result.evaluator_version, "valid": result.valid, "violations": result.violations,
		"cost": result.cost, "metrics": result.metrics, "eval_usec": usec}
	count += 1
	if file != null:
		file.store_line(JSON.stringify(line, "", true))
	return hash

func close() -> Error:
	if file == null:
		return OK
	var error := file.get_error()
	file.close()
	file = null
	return error

## {"records": Array, "incomplete": int}. A cut last line (or any unreadable one) is counted, not loaded.
static func read(path: String) -> Dictionary:
	var records := []
	var incomplete := 0
	if not FileAccess.file_exists(path):
		return {"records": records, "incomplete": 0}
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary and json.data.has("candidate_hash"):
			records.append(json.data)
		else:
			incomplete += 1
	return {"records": records, "incomplete": incomplete}
