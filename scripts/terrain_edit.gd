extends RefCounted
## Pure crater carving on terrain heights (integer millimetres). No nodes, no RNG:
## replaying the same edits over the same base always gives the same heights.
const MAX_DIG_MM := 1500
# Per 0.5 m cell, about 29°: crater walls stay walkable even after repeated hits.
const MAX_STEP_MM := 280
const SANCTUARY := Vector2(10, -12)
const SANCTUARY_RADIUS := 6.5
const EDGE_LIMIT := 30.5

static func protected(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(SANCTUARY) < SANCTUARY_RADIUS or maxf(absf(x), absf(z)) > EDGE_LIMIT

## Lowers terrain.heights_mm in place. Returns the sample rectangle that may have changed,
## or an empty Rect2i when nothing was dug.
static func carve(terrain: Dictionary, base: PackedInt32Array, x: float, z: float, radius: float, depth: float) -> Rect2i:
	var samples: int = terrain.samples
	var cell: float = terrain.cell
	var origin: float = terrain.origin
	var heights: PackedInt32Array = terrain.heights_mm
	var i0 := clampi(floori((x - radius - origin) / cell), 0, samples - 1)
	var i1 := clampi(ceili((x + radius - origin) / cell), 0, samples - 1)
	var j0 := clampi(floori((z - radius - origin) / cell), 0, samples - 1)
	var j1 := clampi(ceili((z + radius - origin) / cell), 0, samples - 1)
	var before := heights.duplicate()
	var dug := false
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var px := origin + i * cell
			var pz := origin + j * cell
			var t := Vector2(px, pz).distance_to(Vector2(x, z)) / radius
			if t >= 1.0 or protected(px, pz):
				continue
			var k := i + j * samples
			var target := maxi(heights[k] - roundi(depth * 1000.0 * pow(1.0 - t * t, 2)), base[k] - MAX_DIG_MM)
			if target < heights[k]:
				heights[k] = target
				dug = true
	if not dug:
		return Rect2i()
	# Only dug samples can break the step limit, and they all lie inside this window.
	for sweep in range(64):
		var raised := false
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k := i + j * samples
				var limit := heights[k]
				if i > 0:
					limit = maxi(limit, heights[k - 1] - MAX_STEP_MM)
				if i < samples - 1:
					limit = maxi(limit, heights[k + 1] - MAX_STEP_MM)
				if j > 0:
					limit = maxi(limit, heights[k - samples] - MAX_STEP_MM)
				if j < samples - 1:
					limit = maxi(limit, heights[k + samples] - MAX_STEP_MM)
				limit = mini(limit, before[k])
				if limit > heights[k]:
					heights[k] = limit
					raised = true
		if not raised:
			break
	terrain.heights_mm = heights
	return Rect2i(i0, j0, i1 - i0 + 1, j1 - j0 + 1)
