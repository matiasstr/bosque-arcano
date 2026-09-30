extends RefCounted
## World save file: seed + generator version + changes over the regenerated base.
## Only I/O and validation; the game decides when to save and how to apply.
const Generator = preload("res://scripts/world_generator.gd")
const Edit = preload("res://scripts/terrain_edit.gd")
const FORMAT := 1
const DEFAULT_PATH := "user://mundo.json"

## Compact state: destroyed IDs and, per terrain sample, how many millimetres it was dug.
static func snapshot(world_seed: int, destroyed: Dictionary, base: PackedInt32Array, current: PackedInt32Array) -> Dictionary:
	var ids: Array = destroyed.keys()
	ids.sort()
	var dug: Array = []
	for k in range(base.size()):
		if current[k] != base[k]:
			dug.append_array([k, base[k] - current[k]])
	var data := {"format": FORMAT, "seed": world_seed, "generator_version": Generator.VERSION,
		"engine_version": "4.4.1", "destroyed": ids, "dug": dug}
	data["checksum"] = Generator.fingerprint(data)
	return data

## Writes to a temporary file first, then replaces the save. Returns the Godot error code.
static func write(path: String, data: Dictionary) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "", true))
	var stored := file.get_error()
	file.close()
	if stored != OK:
		return stored
	return DirAccess.rename_absolute(temp, path)

## {"ok": true, "data": ...} or {"ok": false, "missing": bool, "reason": String}.
## Falls back to the temporary file when the save was interrupted between writing and renaming.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".tmp"):
			return parse(FileAccess.get_file_as_string(path + ".tmp"))
		return {"ok": false, "missing": true, "reason": "no hay guardado"}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return {"ok": false, "missing": false, "reason": "no se pudo leer el archivo"}
	return parse(text)

static func parse(text: String) -> Dictionary:
	# JSON.new().parse reports the error without printing engine errors for a broken file.
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or not json.data.has("checksum"):
		return _invalid("archivo dañado o incompleto")
	var parsed: Dictionary = json.data
	var data: Dictionary = parsed
	var body := data.duplicate()
	body.erase("checksum")
	if Generator.fingerprint(body) != data.checksum:
		return _invalid("la huella no coincide: archivo dañado o modificado")
	if data.get("format") != float(FORMAT):
		return _invalid("formato de guardado desconocido")
	if data.get("generator_version") != float(Generator.VERSION):
		return _invalid("creado con otra versión del generador (%s)" % str(data.get("generator_version")))
	var world_seed = data.get("seed")
	if not (_whole(world_seed) and world_seed >= 1 and world_seed <= 999999999):
		return _invalid("semilla inválida")
	var destroyed = data.get("destroyed")
	if not destroyed is Array:
		return _invalid("lista de destruidos inválida")
	var pattern := RegEx.create_from_string("^(tree|rock):\\d+$")
	for id in destroyed:
		if not id is String or pattern.search(id) == null:
			return _invalid("ID destruido inválido")
	var dug = data.get("dug")
	var samples := Generator.SECTORS * Generator.SECTOR_CELLS + 1
	if not dug is Array or dug.size() % 2 != 0:
		return _invalid("excavación inválida")
	for n in range(0, dug.size(), 2):
		var k = dug[n]
		var mm = dug[n + 1]
		if not (_whole(k) and _whole(mm)):
			return _invalid("excavación inválida")
		if k < 0 or k >= samples * samples or mm <= 0 or mm > Edit.MAX_DIG_MM:
			return _invalid("excavación fuera de rango")
	return {"ok": true, "data": {"seed": int(world_seed), "destroyed": destroyed, "dug": dug}}

## JSON numbers come back as floats; accept only whole values.
static func _whole(value) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))

static func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "missing": false, "reason": reason}

## Keeps an unreadable save aside instead of overwriting it with a new world.
static func set_aside(path: String) -> void:
	for source in [path, path + ".tmp"]:
		if FileAccess.file_exists(source):
			DirAccess.rename_absolute(source, path + ".invalido")
			return
