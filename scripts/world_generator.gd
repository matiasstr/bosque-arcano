extends RefCounted
## Pure world description. Never touches the scene tree or combat RNG.
const VERSION := 1
const HALF_SIZE := 32.0
const SPAWN := Vector3(0, 0.06, 25)
const CLEARINGS := [Vector2(-9, 5), Vector2(10, -12)]
const CLEAR_RADIUS := 6.0
const PATH_RADIUS := 2.5

static func generate(world_seed: int, context: Dictionary = {}) -> Dictionary:
	var layout := RandomNumberGenerator.new()
	layout.seed = world_seed ^ 0x13579
	var path: Array = [Vector2(0, 25), Vector2(-4 + layout.randf_range(-2, 2), 16),
		CLEARINGS[0], Vector2(3 + layout.randf_range(-2, 2), -2), CLEARINGS[1], Vector2(4, -24)]
	var trees: Array = []
	var rocks: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x24680
	for attempt in range(4000):
		if trees.size() >= 155:
			break
		var p := Vector2(snappedf(rng.randf_range(-30, 30), 0.01), snappedf(rng.randf_range(-30, 30), 0.01))
		if protected(p, path, 0.7) or occupied(p, trees, 2.8):
			continue
		trees.append({"x": p.x, "z": p.y, "height": snappedf(rng.randf_range(5.2, 8.5), 0.01),
			"radius": snappedf(rng.randf_range(0.24, 0.42), 0.01), "shade": rng.randf_range(0.0, 1.0)})
	rng.seed = world_seed ^ 0x10203
	for attempt in range(1000):
		if rocks.size() >= 28:
			break
		var p := Vector2(snappedf(rng.randf_range(-29, 29), 0.01), snappedf(rng.randf_range(-29, 29), 0.01))
		if protected(p, path, 1.4) or occupied(p, trees, 1.7) or occupied(p, rocks, 2.5):
			continue
		rocks.append({"x": p.x, "z": p.y, "size": snappedf(rng.randf_range(0.55, 1.15), 0.01)})
	var route: Array = []
	for p in path:
		route.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	return {"seed": world_seed, "generator_version": VERSION, "engine_version": "4.4.1",
		"context": context.duplicate(true), "path": route, "trees": trees, "rocks": rocks}

static func protected(p: Vector2, path: Array, margin: float) -> bool:
	for center in CLEARINGS:
		if p.distance_to(center) < CLEAR_RADIUS + margin:
			return true
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < PATH_RADIUS + margin:
			return true
	return false

static func occupied(p: Vector2, entries: Array, distance: float) -> bool:
	for entry in entries:
		if p.distance_to(Vector2(entry.x, entry.z)) < distance:
			return true
	return false

static func fingerprint(description: Dictionary) -> String:
	# JSON parsing normalizes integer/float variants (1 and 1.0 are the same data).
	var normalized = JSON.parse_string(JSON.stringify(description, "", true))
	return JSON.stringify(normalized, "", true).sha256_text()
