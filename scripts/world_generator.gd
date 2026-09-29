extends RefCounted
## Pure world description. Never touches the scene tree or combat RNG.
## v2 adds terrain heights; path, trees and rocks keep their v1 x/z layout.
const VERSION := 2
const HALF_SIZE := 32.0
const SPAWN_XZ := Vector2(0, 25)
const SPAWN_CLEARANCE := 0.06
const CLEARINGS := [Vector2(-9, 5), Vector2(10, -12)]
const CLEAR_RADIUS := 6.0
const PATH_RADIUS := 2.5
# Terrain: 3 × 3 sectors reading one shared grid, so borders have identical samples.
const SECTORS := 3
const SECTOR_CELLS := 44
const CELL := 0.5
const TERRAIN_HALF := 33.0
const RELIEF_OCTAVES := [[30.0, 2.2], [14.0, 0.5], [7.0, 0.12]]
const EDGE_RISE := 1.5
# Center, flat radius, transition. The practice clearing is the zero datum.
const FLAT_ZONES := [[Vector2(0, 25), 2.5, 6.0], [Vector2(10, -12), 6.5, 10.0], [Vector2(-9, 5), 6.5, 10.0]]

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
		"context": context.duplicate(true), "path": route, "trees": trees, "rocks": rocks,
		"terrain": terrain(world_seed)}

## Heights in integer millimetres on a global grid. Own RNG stream: never shifts the layout.
static func terrain(world_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x7E44A1
	var salt := rng.randi() & 0x3FFFFFFF
	var layers: Array = []
	for index in range(RELIEF_OCTAVES.size()):
		var inv: float = 1.0 / RELIEF_OCTAVES[index][0]
		var offset := Vector2(rng.randf_range(0, 64), rng.randf_range(0, 64))
		var base := Vector2i(floori(offset.x), floori(offset.y))
		var count := ceili(2 * TERRAIN_HALF * inv) + 2
		var lattice := PackedFloat64Array()
		lattice.resize(count * count)
		for j in range(count):
			for i in range(count):
				lattice[i + j * count] = _hash01(base.x + i, base.y + j, salt + index) * 2.0 - 1.0
		layers.append([inv, offset.x - base.x, offset.y - base.y, count, lattice, RELIEF_OCTAVES[index][1]])
	var levels: Array = []
	for zone in FLAT_ZONES:
		levels.append(_relief(layers, zone[0].x, zone[0].y))
	var datum: float = levels[levels.size() - 1]
	var samples := SECTORS * SECTOR_CELLS + 1
	var heights := PackedInt32Array()
	heights.resize(samples * samples)
	for j in range(samples):
		for i in range(samples):
			var p := Vector2(-TERRAIN_HALF + i * CELL, -TERRAIN_HALF + j * CELL)
			var h := _relief(layers, p.x, p.y)
			for n in range(FLAT_ZONES.size()):
				var zone: Array = FLAT_ZONES[n]
				h = lerpf(h, levels[n], 1.0 - smoothstep(zone[1], zone[1] + zone[2], p.distance_to(zone[0])))
			heights[i + j * samples] = roundi((h - datum) * 1000.0)
	return {"sectors": SECTORS, "sector_cells": SECTOR_CELLS, "cell": CELL, "origin": -TERRAIN_HALF,
		"samples": samples, "heights_mm": heights}

static func _relief(layers: Array, x: float, z: float) -> float:
	var h := EDGE_RISE * smoothstep(24.0, 32.0, maxf(absf(x), absf(z)))
	for layer in layers:
		var u: float = (x + TERRAIN_HALF) * layer[0] + layer[1]
		var v: float = (z + TERRAIN_HALF) * layer[0] + layer[2]
		var i := floori(u)
		var j := floori(v)
		var tu := u - i
		var tv := v - j
		tu = tu * tu * (3.0 - 2.0 * tu)
		tv = tv * tv * (3.0 - 2.0 * tv)
		var count: int = layer[3]
		var lattice: PackedFloat64Array = layer[4]
		var k := i + j * count
		h += lerpf(lerpf(lattice[k], lattice[k + 1], tu), lerpf(lattice[k + count], lattice[k + count + 1], tu), tv) * layer[5]
	return h

## Integer hash in [0, 1]; products stay below 2^63 for the lattice sizes used here.
static func _hash01(ix: int, iz: int, salt: int) -> float:
	var h := (ix * 374761393 + iz * 668265263 + salt * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFFFF) / 16777215.0

## Ground height matching the mesh and HeightMapShape3D triangles (diagonal from x+1 to z+1).
static func height_at(description: Dictionary, x: float, z: float) -> float:
	var t: Dictionary = description.terrain
	var samples: int = t.samples
	var fx := clampf((x - t.origin) / t.cell, 0.0, samples - 1.0)
	var fz := clampf((z - t.origin) / t.cell, 0.0, samples - 1.0)
	var i := mini(floori(fx), samples - 2)
	var j := mini(floori(fz), samples - 2)
	var ax := fx - i
	var az := fz - j
	var k := i + j * samples
	var h00: float = t.heights_mm[k]
	var h10: float = t.heights_mm[k + 1]
	var h01: float = t.heights_mm[k + samples]
	if ax + az <= 1.0:
		return (h00 + (h10 - h00) * ax + (h01 - h00) * az) * 0.001
	var h11: float = t.heights_mm[k + samples + 1]
	return (h11 + (h01 - h11) * (1.0 - ax) + (h10 - h11) * (1.0 - az)) * 0.001

## Lowest ground under a footprint (center plus eight points on an ellipse).
static func footprint_min(description: Dictionary, x: float, z: float, radius: float, z_scale: float = 1.0) -> float:
	var lowest := height_at(description, x, z)
	for n in range(8):
		var angle := n * TAU / 8
		lowest = minf(lowest, height_at(description, x + cos(angle) * radius, z + sin(angle) * radius * z_scale))
	return lowest

static func spawn_point(description: Dictionary) -> Vector3:
	return Vector3(SPAWN_XZ.x, height_at(description, SPAWN_XZ.x, SPAWN_XZ.y) + SPAWN_CLEARANCE, SPAWN_XZ.y)

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
