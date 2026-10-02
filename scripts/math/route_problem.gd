extends "res://scripts/math/problem.gd"
## Calibration problem A: a walking route over the game's own terrain, on a coarse grid.
## Cost = 3D length + a penalty per metre climbed. Trees and rocks block cells; craters change
## heights. Dijkstra gives the exact optimum, so every search result can be compared with it.
const Generator = preload("res://scripts/world_generator.gd")
const CELL := 2.0
const SIDE := 31
const ORIGIN := -30.0
const UPHILL_PENALTY := 3.0
const BIAS := 1.5
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
var heights := PackedFloat64Array()
var blocked := PackedByteArray()
var start := 0
var goal := 0

## description: generated world (trees, rocks); ground: current heights ({"terrain": ...});
## destroyed: IDs of props that no longer block.
func setup(description: Dictionary, ground: Dictionary, destroyed: Dictionary = {}, from := Vector2(0, 25), to := Vector2(10, -12)) -> void:
	id = "ruta-terreno"
	version = 1
	evaluator_version = 1
	heights.resize(SIDE * SIDE)
	blocked.resize(SIDE * SIDE)
	for k in range(SIDE * SIDE):
		var p := position(k)
		# Millimetre rounding keeps the instance exact and its fingerprint stable.
		heights[k] = roundi(Generator.height_at(ground, p.x, p.y) * 1000.0) * 0.001
		blocked[k] = 0
	for index in range(description.trees.size()):
		if not destroyed.has("tree:%d" % index):
			var tree: Dictionary = description.trees[index]
			_block_around(Vector2(tree.x, tree.z), tree.radius + 0.7)
	for index in range(description.rocks.size()):
		if not destroyed.has("rock:%d" % index):
			var rock: Dictionary = description.rocks[index]
			_block_around(Vector2(rock.x, rock.z), rock.size + 0.3)
	start = nearest(from)
	goal = nearest(to)
	blocked[start] = 0
	blocked[goal] = 0

func _block_around(center: Vector2, radius: float) -> void:
	for k in range(SIDE * SIDE):
		if position(k).distance_to(center) < radius:
			blocked[k] = 1

func position(k: int) -> Vector2:
	return Vector2(ORIGIN + (k % SIDE) * CELL, ORIGIN + (k / SIDE) * CELL)

func nearest(p: Vector2) -> int:
	var i := clampi(roundi((p.x - ORIGIN) / CELL), 0, SIDE - 1)
	var j := clampi(roundi((p.y - ORIGIN) / CELL), 0, SIDE - 1)
	return i + j * SIDE

func fingerprint() -> String:
	var mm := PackedInt32Array()
	for h in heights:
		mm.append(roundi(h * 1000.0))
	return Generator.fingerprint({"id": id, "version": version, "evaluator": evaluator_version, "cell": CELL, "side": SIDE,
		"origin": ORIGIN, "uphill": UPHILL_PENALTY, "start": start, "goal": goal, "heights_mm": mm, "blocked": Array(blocked)})

## Cost of one move, or INF when it is not allowed (blocked, not adjacent, or cutting a corner).
func step_cost(a: int, b: int) -> float:
	if a < 0 or b < 0 or a >= SIDE * SIDE or b >= SIDE * SIDE or blocked[b] == 1:
		return INF
	var d := Vector2i(b % SIDE - a % SIDE, b / SIDE - a / SIDE)
	if d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
		return INF
	if d.x != 0 and d.y != 0 and (blocked[a + d.x] == 1 or blocked[a + d.y * SIDE] == 1):
		return INF
	var run := CELL * (1.4142135623730951 if d.x != 0 and d.y != 0 else 1.0)
	var rise := heights[b] - heights[a]
	return sqrt(run * run + rise * rise) + UPHILL_PENALTY * maxf(rise, 0.0)

func neighbours(k: int) -> Array:
	var result := []
	var cell := Vector2i(k % SIDE, k / SIDE)
	for d in NEIGHBOURS:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.y >= 0 and n.x < SIDE and n.y < SIDE and step_cost(k, n.x + n.y * SIDE) < INF:
			result.append(n.x + n.y * SIDE)
	return result

func verify(candidate: Array) -> Dictionary:
	var violations: Array[String] = []
	if candidate.is_empty():
		violations.append("ruta vacía")
		return {"valid": false, "violations": violations}
	if candidate.size() > SIDE * SIDE:
		violations.append("ruta demasiado larga")
	if candidate[0] != start:
		violations.append("no empieza en el inicio")
	if candidate[candidate.size() - 1] != goal:
		violations.append("no termina en el destino")
	var seen := {}
	for n in range(candidate.size()):
		var k = candidate[n]
		if not k is int or k < 0 or k >= SIDE * SIDE:
			violations.append("celda fuera de la grilla")
			break
		if blocked[k] == 1:
			violations.append("pasa por una celda bloqueada")
		if seen.has(k):
			violations.append("repite celdas")
		seen[k] = true
		if n > 0 and step_cost(candidate[n - 1], k) == INF and blocked[k] == 0:
			violations.append("salto entre celdas no vecinas o corte de esquina")
	var unique: Array[String] = []
	for v in violations:
		if not unique.has(v):
			unique.append(v)
	return {"valid": unique.is_empty(), "violations": unique}

func evaluate(candidate: Array) -> Dictionary:
	var check := verify(candidate)
	if not check.valid:
		return {"valid": false, "violations": check.violations, "cost": null, "metrics": {}, "evaluator_version": evaluator_version}
	var cost := 0.0
	var length := 0.0
	var climb := 0.0
	for n in range(1, candidate.size()):
		cost += step_cost(candidate[n - 1], candidate[n])
		var a: int = candidate[n - 1]
		var b: int = candidate[n]
		length += position(a).distance_to(position(b))
		climb += maxf(heights[b] - heights[a], 0.0)
	return {"valid": true, "violations": [], "cost": cost, "evaluator_version": evaluator_version,
		"metrics": {"steps": candidate.size() - 1, "length_m": length, "climb_m": climb}}

## Exact optimum (Dijkstra with a binary heap). {"cost": float, "route": Array}; route empty if unreachable.
func optimum() -> Dictionary:
	var best := PackedFloat64Array()
	best.resize(SIDE * SIDE)
	best.fill(INF)
	var previous := PackedInt32Array()
	previous.resize(SIDE * SIDE)
	previous.fill(-1)
	best[start] = 0.0
	var heap: Array = [[0.0, start]]
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var k: int = top[1]
		if top[0] > best[k]:
			continue
		if k == goal:
			break
		for n in neighbours(k):
			var cost: float = best[k] + step_cost(k, n)
			if cost < best[n]:
				best[n] = cost
				previous[n] = k
				_push(heap, [cost, n])
	if best[goal] == INF:
		return {"cost": INF, "route": []}
	var route := [goal]
	while route[0] != start:
		route.push_front(previous[route[0]])
	return {"cost": best[goal], "route": route}

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0 and heap[(i - 1) / 2][0] > heap[i][0]:
		var parent := (i - 1) / 2
		var swap = heap[parent]
		heap[parent] = heap[i]
		heap[i] = swap
		i = parent

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var smallest := i
		for child in [2 * i + 1, 2 * i + 2]:
			if child < heap.size() and heap[child][0] < heap[smallest][0]:
				smallest = child
		if smallest == i:
			break
		var swap = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = swap
		i = smallest
	return top

## Randomized depth-first walk biased towards the target; backtracks out of dead ends.
func _walk(from: int, to: int, rng: RandomNumberGenerator, max_steps: int) -> Array:
	var path := [from]
	var visited := {from: true}
	var target := position(to)
	for step in range(max_steps):
		var here: int = path[path.size() - 1]
		if here == to:
			return path
		var options := []
		var weights := []
		var total := 0.0
		for n in neighbours(here):
			if visited.has(n):
				continue
			var gain := (position(here).distance_to(target) - position(n).distance_to(target)) / CELL
			var weight := exp(BIAS * gain)
			options.append(n)
			weights.append(weight)
			total += weight
		if options.is_empty():
			path.pop_back()
			if path.is_empty():
				return []
			continue
		var pick := rng.randf() * total
		var chosen: int = options[options.size() - 1]
		for o in range(options.size()):
			pick -= weights[o]
			if pick <= 0.0:
				chosen = options[o]
				break
		visited[chosen] = true
		path.append(chosen)
	return []

## Cuts every loop: when a cell repeats, the detour between both visits is dropped.
static func remove_loops(route: Array) -> Array:
	var result := []
	var index := {}
	for k in route:
		if index.has(k):
			var keep: int = index[k]
			for removed in result.slice(keep + 1):
				index.erase(removed)
			result = result.slice(0, keep + 1)
		else:
			index[k] = result.size()
			result.append(k)
	return result

func random_candidate(rng: RandomNumberGenerator) -> Array:
	return _walk(start, goal, rng, SIDE * SIDE * 4)

## Replaces a short stretch with a new random detour between the same two cells.
func mutate(candidate: Array, rng: RandomNumberGenerator) -> Array:
	if candidate.size() < 3:
		return candidate.duplicate()
	var i := rng.randi_range(0, candidate.size() - 2)
	var j := mini(candidate.size() - 1, i + rng.randi_range(2, 10))
	var detour := _walk(candidate[i], candidate[j], rng, 300)
	if detour.is_empty():
		return candidate.duplicate()
	return remove_loops(candidate.slice(0, i) + detour + candidate.slice(j + 1))

## Joins the start of one route with the end of another at a shared cell.
func combine(a: Array, b: Array, rng: RandomNumberGenerator) -> Array:
	var in_b := {}
	for n in range(1, b.size() - 1):
		in_b[b[n]] = n
	var shared := []
	for n in range(1, a.size() - 1):
		if in_b.has(a[n]):
			shared.append(n)
	if shared.is_empty():
		return a.duplicate()
	var cut: int = shared[rng.randi_range(0, shared.size() - 1)]
	return remove_loops(a.slice(0, cut) + b.slice(in_b[a[cut]]))
