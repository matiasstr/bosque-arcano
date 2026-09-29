extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Game = preload("res://scripts/game.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Explorer = preload("res://scripts/explorer.gd")
const Assets = preload("res://scripts/forest_assets.gd")
# Path/trees/rocks fingerprints from generator v1 (before terrain). Terrain must not move them.
const LAYOUT_V1 := {
	240926: "1c143c38ffe829b466d4a14c3840803d141a73df8a2a6d021d99a7c4bb1b1b9f",
	1: "0b075f2d86f4ceae17a8e922affa15c79a9fefbfc205d6debc8e2c977ba1ea80",
	42: "855b27cc2b76ae83532b784548738e5620e74894d93deacfb77452cf52669973",
	999999999: "308eb06ecb860011ab903e6528e3f160701a6d5a70961c04bb95921e8ea0270b",
}
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", description])

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	await data_checks()
	await terrain_only_checks()
	await placement_checks()
	print("TERRENO: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func data_checks() -> void:
	var start := Time.get_ticks_usec()
	var a: Dictionary = Generator.generate(240926)
	var total_ms := (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	Generator.terrain(240926)
	var heights_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("TIEMPO descripción completa %.1f ms · alturas %.1f ms" % [total_ms, heights_ms])
	check(a.generator_version == 2 and a.terrain.heights_mm.size() == 133 * 133, "descripción v2 con grilla de 133 × 133 muestras")
	check(a.terrain.heights_mm == Generator.generate(240926).terrain.heights_mm, "misma semilla y versión dan las mismas alturas")
	check(a.terrain.heights_mm != Generator.generate(240927).terrain.heights_mm, "otra semilla cambia el relieve")
	var layout_ok := true
	for seed_value in LAYOUT_V1:
		var d: Dictionary = Generator.generate(seed_value)
		layout_ok = layout_ok and Generator.fingerprint({"path": d.path, "trees": d.trees, "rocks": d.rocks}) == LAYOUT_V1[seed_value]
	check(layout_ok, "terreno no redistribuye sendero, árboles ni rocas (huellas v1 en 4 semillas)")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(a))
	check(is_equal_approx(Generator.height_at(restored, 3.3, -7.7), Generator.height_at(a, 3.3, -7.7)), "alturas sobreviven a la serialización JSON")
	for seed_value in [240926, 1, 42, 999999999]:
		var d: Dictionary = Generator.generate(seed_value)
		var stats := relief_stats(d)
		print("RELIEVE semilla %d: %.2f a %.2f m · pendiente máx. interior %.1f° · total %.1f° · sendero %.1f°" % [seed_value, stats.low, stats.high, rad_to_deg(atan(stats.interior)), rad_to_deg(atan(stats.overall)), rad_to_deg(atan(stats.path))])
		check(stats.high - stats.low > 2.0 and stats.low > -6.0, "semilla %d tiene desniveles sin caer bajo el límite de respawn" % seed_value)
		check(stats.interior < tan(deg_to_rad(30)) and stats.overall < tan(deg_to_rad(40)), "semilla %d: pendientes caminables (< 30° interior, < 40° borde)" % seed_value)
		check(stats.path < tan(deg_to_rad(25)), "semilla %d: sendero con pendiente < 25°" % seed_value)
		# Level cores are 6.5 m and 2.5 m; interpolation reaches the transition one cell earlier.
		check(flat_spread(d, Vector2(-9, 5), 5.75) < 0.002 and flat_spread(d, Vector2(10, -12), 5.75) < 0.002 and flat_spread(d, Generator.SPAWN_XZ, 1.75) < 0.002, "semilla %d: claros, santuario y spawn nivelados" % seed_value)
		check(absf(Generator.height_at(d, -9, 5)) < 0.001, "semilla %d: claro de práctica en el nivel 0" % seed_value)

func relief_stats(d: Dictionary) -> Dictionary:
	var t: Dictionary = d.terrain
	var n: int = t.samples
	var stats := {"low": INF, "high": -INF, "interior": 0.0, "overall": 0.0, "path": 0.0}
	for j in range(n - 1):
		for i in range(n - 1):
			var h: float = t.heights_mm[i + j * n] * 0.001
			stats.low = minf(stats.low, h)
			stats.high = maxf(stats.high, h)
			var gx: float = (t.heights_mm[i + 1 + j * n] - t.heights_mm[i + j * n]) * 0.001 / t.cell
			var gz: float = (t.heights_mm[i + (j + 1) * n] - t.heights_mm[i + j * n]) * 0.001 / t.cell
			var slope := Vector2(gx, gz).length()
			var x: float = t.origin + i * t.cell
			var z: float = t.origin + j * t.cell
			stats.overall = maxf(stats.overall, slope)
			if maxf(absf(x), absf(z)) < 24:
				stats.interior = maxf(stats.interior, slope)
	for k in range(d.path.size() - 1):
		var a := Vector2(d.path[k][0], d.path[k][1])
		var b := Vector2(d.path[k + 1][0], d.path[k + 1][1])
		for step in range(int(a.distance_to(b) / 0.5)):
			var p := a + a.direction_to(b) * step * 0.5
			for side in [-1.5, 0.0, 1.5]:
				var q: Vector2 = p + a.direction_to(b).orthogonal() * side
				var gx := (Generator.height_at(d, q.x + 0.5, q.y) - Generator.height_at(d, q.x - 0.5, q.y)) / 1.0
				var gz := (Generator.height_at(d, q.x, q.y + 0.5) - Generator.height_at(d, q.x, q.y - 0.5)) / 1.0
				stats.path = maxf(stats.path, Vector2(gx, gz).length())
	return stats

func flat_spread(d: Dictionary, center: Vector2, radius: float) -> float:
	var low := INF
	var high := -INF
	for r in [0.0, radius * 0.5, radius]:
		for n in range(16):
			var h := Generator.height_at(d, center.x + cos(n * TAU / 16) * r, center.y + sin(n * TAU / 16) * r)
			low = minf(low, h)
			high = maxf(high, h)
	return high - low

func ground_ray(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -30, z), 1)
	return root.world_3d.direct_space_state.intersect_ray(query)

func terrain_only_checks() -> void:
	var d: Dictionary = Generator.generate(42)
	var holder := Node3D.new()
	root.add_child(holder)
	var start := Time.get_ticks_usec()
	var terrain := Terrain.new()
	holder.add_child(terrain)
	terrain.build(d.terrain, StandardMaterial3D.new())
	print("TIEMPO mallas y colisiones de 9 sectores %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	await frames(2)
	check(terrain.sectors.size() == 9, "región de 3 × 3 sectores")
	var seams_ok := true
	for sz in range(3):
		for sx in range(3):
			var here: PackedVector3Array = terrain.sectors[sx + sz * 3].get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var here_n: PackedVector3Array = terrain.sectors[sx + sz * 3].get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			if sx < 2:
				var east: Array = terrain.sectors[sx + 1 + sz * 3].get_child(0).mesh.surface_get_arrays(0)
				for j in range(45):
					seams_ok = seams_ok and here[44 + j * 45] == east[Mesh.ARRAY_VERTEX][j * 45] and here_n[44 + j * 45] == east[Mesh.ARRAY_NORMAL][j * 45]
			if sz < 2:
				var south: Array = terrain.sectors[sx + (sz + 1) * 3].get_child(0).mesh.surface_get_arrays(0)
				for i in range(45):
					seams_ok = seams_ok and here[i + 44 * 45] == south[Mesh.ARRAY_VERTEX][i] and here_n[i + 44 * 45] == south[Mesh.ARRAY_NORMAL][i]
	check(seams_ok, "sectores vecinos comparten vértices y normales exactas en el borde")
	var mesh_arrays: Array = terrain.sectors[4].get_child(0).mesh.surface_get_arrays(0)
	var v: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
	check(Plane(v[index[0]], v[index[1]], v[index[2]]).normal.y > 0.5 and Plane(v[index[3]], v[index[4]], v[index[5]]).normal.y > 0.5, "triángulos de la malla orientados hacia arriba")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	var missed := 0
	var points: Array = []
	for n in range(500):
		points.append(Vector2(rng.randf_range(-32.9, 32.9), rng.randf_range(-32.9, 32.9)))
	for border in [-11.0, 11.0]:
		for step in range(-65, 66):
			for delta in [-0.001, 0.0, 0.001]:
				points.append(Vector2(border + delta, step * 0.5 + 0.13))
				points.append(Vector2(step * 0.5 + 0.13, border + delta))
	for p in points:
		var hit := ground_ray(p.x, p.y)
		if hit.is_empty():
			missed += 1
		else:
			worst = maxf(worst, absf(hit.position.y - Generator.height_at(d, p.x, p.y)))
	print("COLISIÓN %d rayos · diferencia máxima con la malla %.4f m" % [points.size(), worst])
	check(missed == 0 and worst < 0.01, "colisión coincide con la malla en toda la región y sobre los bordes (< 1 cm)")
	var explorer := Explorer.new()
	holder.add_child(explorer)
	explorer.controlled = false
	var route := [Vector2(-22, -22), Vector2(22, -22), Vector2(22, 0), Vector2(-22, 0), Vector2(-22, 22), Vector2(22, 22), Vector2(-22, -22)]
	explorer.reset_at(Vector3(route[0].x, Generator.height_at(d, route[0].x, route[0].y) + 0.06, route[0].y))
	for i in range(120):
		await physics_frame
		explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	var reached := 0
	var grounded := 0
	var airborne := 0
	var drift := 0.0
	var jump := 0.0
	var last_gap := NAN
	var sectors_seen := {}
	for target in route.slice(1):
		for i in range(2400):
			var here := Vector2(explorer.position.x, explorer.position.z)
			if here.distance_to(target) < 0.5:
				reached += 1
				break
			await physics_frame
			# Direction in the explorer's local frame: yaw stays 0, so world x/z map directly.
			explorer.step_movement(here.direction_to(target), true, false, false, 1.0 / 120.0)
			sectors_seen["%d:%d" % [floori((here.x + 33) / 22), floori((here.y + 33) / 22)]] = true
			if explorer.is_on_floor():
				grounded += 1
				var gap := explorer.position.y - Generator.height_at(d, explorer.position.x, explorer.position.z)
				drift = maxf(drift, absf(gap))
				if not is_nan(last_gap):
					jump = maxf(jump, absf(gap - last_gap))
				last_gap = gap
			else:
				airborne += 1
				last_gap = NAN
	print("RECORRIDO %d tramos · %d sectores · %d frames en el suelo, %d en el aire · separación máx. %.3f m · salto máx. entre frames %.4f m" % [reached, sectors_seen.size(), grounded, airborne, drift, jump])
	check(reached == route.size() - 1 and sectors_seen.size() == 9, "se camina por los 9 sectores cruzando sus bordes")
	# A 0.3 m capsule rests up to 0.3 × (1 / cos 30° − 1) ≈ 0.046 m above the point under its center.
	check(airborne < grounded / 50 and drift < 0.06 and jump < 0.01, "al cruzar bordes el jugador sigue el suelo sin escalones ni caídas")
	holder.queue_free()
	await frames(2)

func placement_checks() -> void:
	var game := Game.new()
	root.add_child(game)
	await frames(3)
	var start := Time.get_ticks_usec()
	game.regenerate(240926)
	print("TIEMPO regenerar la región completa (datos, terreno, bosque y sotobosque) %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	await frames(2)
	var d: Dictionary = game.forest.description
	var spawn := Generator.spawn_point(d)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, spawn + Vector3.UP * 0.92)
	query.collision_mask = 1
	check(root.world_3d.direct_space_state.intersect_shape(query, 1).is_empty(), "punto de aparición libre de obstáculos")
	check(absf(ground_ray(spawn.x, spawn.z).position.y + Generator.SPAWN_CLEARANCE - spawn.y) < 0.01, "punto de aparición apoyado sobre la colisión del suelo")
	game.set_paused(false)
	game.explorer.controlled = false
	for i in range(150):
		await physics_frame
		game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	check(game.explorer.is_on_floor() and game.explorer.position.distance_to(spawn) < 0.15, "jugador aparece y queda quieto sobre el suelo")
	var trees_ok := true
	var rocks_ok := true
	var tree_count := 0
	var rock_count := 0
	var worst_sink := 0.0
	for node in game.forest.get_children():
		var id = node.get("prop_id")
		if id == null:
			continue
		if String(id).begins_with("tree:"):
			tree_count += 1
			var entry: Dictionary = d.trees[int(String(id).split(":")[1])]
			var base: float = node.position.y
			var center := Generator.height_at(d, entry.x, entry.z)
			worst_sink = maxf(worst_sink, center - base)
			trees_ok = trees_ok and base <= Generator.footprint_min(d, entry.x, entry.z, entry.radius * 2.0) + 0.0001 and center - base < 0.6
		else:
			rock_count += 1
			var rock: Dictionary = d.rocks[int(String(id).split(":")[1])]
			var size: float = rock.size
			var y: float = node.position.y
			for k in [0.0, 0.5, 0.8]:
				rocks_ok = rocks_ok and y - 0.72 * size * sqrt(1.0 - k * k) <= Generator.footprint_min(d, rock.x, rock.z, size * k, 0.85) + 0.0001
			var highest := -INF
			for n in range(8):
				highest = maxf(highest, Generator.height_at(d, rock.x + cos(n * TAU / 8) * size, rock.z + sin(n * TAU / 8) * size * 0.85))
			rocks_ok = rocks_ok and y + 0.72 * size > highest + 0.1 * size
	print("APOYO %d árboles (hundimiento máx. del centro %.2f m) · %d rocas" % [tree_count, worst_sink, rock_count])
	check(tree_count == d.trees.size() and trees_ok, "árboles apoyados: base bajo toda la huella de raíces, sin enterrarse más de 0,6 m")
	check(rock_count == d.rocks.size() and rocks_ok, "rocas apoyadas: base bajo el suelo y cima visible")
	var targets_ok := true
	for target in game.targets:
		targets_ok = targets_ok and absf(target.position.y - ground_ray(target.position.x, target.position.z).position.y) < 0.01
	check(targets_ok, "blancos de práctica apoyados en el suelo físico")
	var sanctuary_y: float = game.forest.sanctuary.position.y
	check(absf(sanctuary_y - Generator.height_at(d, 10, -12)) < 0.001 and flat_spread(d, Vector2(10, -12), 5.0) < 0.002, "santuario sobre su claro nivelado")
	# Headless rendering does not keep MultiMesh buffers, so check the placement data they receive.
	var grass_ok := true
	var grass_count := 0
	for batch in Assets.undergrowth_batches(d).values():
		for transform in batch.transforms:
			var p: Vector3 = transform.origin
			grass_ok = grass_ok and absf(p.y - 0.015 - Generator.height_at(d, p.x, p.z)) < 0.001
			grass_count += 1
	check(grass_count > 1000 and grass_ok, "sotobosque sobre el suelo (%d plantas)" % grass_count)
	game.queue_free()
	await frames(2)
