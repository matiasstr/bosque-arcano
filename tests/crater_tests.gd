extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Edit = preload("res://scripts/terrain_edit.gd")
const Game = preload("res://scripts/game.gd")
const Book = preload("res://scripts/spell_catalog.gd")
const Forest = preload("res://scripts/forest.gd")
var checks := 0
var failures := 0
var game

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
	data_checks()
	await scene_checks()
	print("CRÁTERES: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func editable(d: Dictionary) -> Dictionary:
	var t: Dictionary = d.terrain.duplicate()
	t.heights_mm = d.terrain.heights_mm.duplicate()
	return t

func max_step(t: Dictionary) -> int:
	var n: int = t.samples
	var worst := 0
	for j in range(n - 1):
		for i in range(n - 1):
			var k := i + j * n
			worst = maxi(worst, maxi(absi(t.heights_mm[k] - t.heights_mm[k + 1]), absi(t.heights_mm[k] - t.heights_mm[k + n])))
	return worst

func data_checks() -> void:
	var d: Dictionary = Generator.generate(240926)
	var base: PackedInt32Array = d.terrain.heights_mm
	var brasa: Dictionary = Book.SPELLS[1]
	check(Book.SPELLS[0].crater_radius == 0 and brasa.crater_radius > 0 and brasa.crater_depth > 0, "solo Brasa Rúnica excava; su cráter está en el catálogo")
	var t := editable(d)
	var spot := Vector2(-20, -4)
	var before := Generator.height_at({"terrain": t}, spot.x, spot.y)
	var changed := Edit.carve(t, base, spot.x, spot.y, brasa.crater_radius, brasa.crater_depth)
	var drop := before - Generator.height_at({"terrain": t}, spot.x, spot.y)
	check(changed.has_area() and absf(drop - brasa.crater_depth) < 0.01, "cráter baja el centro %.2f m" % drop)
	var outside_same := true
	for j in range(t.samples):
		for i in range(t.samples):
			var p := Vector2(t.origin + i * t.cell, t.origin + j * t.cell)
			if p.distance_to(spot) >= brasa.crater_radius:
				outside_same = outside_same and t.heights_mm[i + j * t.samples] == base[i + j * t.samples]
	check(outside_same, "fuera del radio el terreno no cambia")
	check(base == Generator.generate(240926).terrain.heights_mm, "la descripción base no se modifica")
	var replay := editable(d)
	Edit.carve(replay, base, spot.x, spot.y, brasa.crater_radius, brasa.crater_depth)
	check(replay.heights_mm == t.heights_mm, "repetir la edición sobre la base reproduce las mismas alturas")
	for i in range(12):
		Edit.carve(t, base, spot.x + (i % 3) * 0.4, spot.y, brasa.crater_radius, brasa.crater_depth)
	var deepest := 0
	for k in range(base.size()):
		deepest = maxi(deepest, base[k] - t.heights_mm[k])
	print("13 IMPACTOS: profundidad %.2f m · escalón máximo %d mm por celda" % [deepest * 0.001, max_step(t)])
	check(deepest <= Edit.MAX_DIG_MM and deepest > 1000, "impactos repetidos profundizan sin pasar de 1,5 m")
	check(max_step(t) <= Edit.MAX_STEP_MM, "paredes del cráter caminables (≤ 0,28 m por celda de 0,5 m)")
	var sanctuary := editable(d)
	check(not Edit.carve(sanctuary, base, 10, -12, brasa.crater_radius, brasa.crater_depth).has_area() and sanctuary.heights_mm == base, "el claro del santuario no se excava")
	var edge := editable(d)
	Edit.carve(edge, base, 30.6, 0, brasa.crater_radius, brasa.crater_depth)
	var edge_same := true
	for j in range(edge.samples):
		for i in range(edge.samples):
			if maxf(absf(edge.origin + i * edge.cell), absf(edge.origin + j * edge.cell)) > Edit.EDGE_LIMIT:
				edge_same = edge_same and edge.heights_mm[i + j * edge.samples] == base[i + j * edge.samples]
	check(edge_same and edge.heights_mm != base, "junto a los límites solo se excava hacia adentro")

func sector_ids() -> Array:
	var ids := []
	for body in game.forest.terrain.sectors:
		ids.append(body.get_instance_id())
	return ids

func changed_sectors(before: Array) -> int:
	var count := 0
	var now := sector_ids()
	for i in range(now.size()):
		if now[i] != before[i]:
			count += 1
	return count

func seams_match() -> bool:
	var sectors: Array = game.forest.terrain.sectors
	var ok := true
	for sz in range(3):
		for sx in range(3):
			var here: Array = sectors[sx + sz * 3].get_child(0).mesh.surface_get_arrays(0)
			if sx < 2:
				var east: Array = sectors[sx + 1 + sz * 3].get_child(0).mesh.surface_get_arrays(0)
				for j in range(45):
					ok = ok and here[Mesh.ARRAY_VERTEX][44 + j * 45] == east[Mesh.ARRAY_VERTEX][j * 45] and here[Mesh.ARRAY_NORMAL][44 + j * 45] == east[Mesh.ARRAY_NORMAL][j * 45]
			if sz < 2:
				var south: Array = sectors[sx + (sz + 1) * 3].get_child(0).mesh.surface_get_arrays(0)
				for i in range(45):
					ok = ok and here[Mesh.ARRAY_VERTEX][i + 44 * 45] == south[Mesh.ARRAY_VERTEX][i] and here[Mesh.ARRAY_NORMAL][i + 44 * 45] == south[Mesh.ARRAY_NORMAL][i]
	return ok

## Largest gap between terrain collision and the edited heights around a point (props skipped).
func collision_gap(center: Vector2, reach: float) -> float:
	var worst := 0.0
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	for j in range(-10, 11):
		for i in range(-10, 11):
			var p := center + Vector2(i, j) * reach / 10.0 + Vector2(0.013, 0.021)
			var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 30, p.y), Vector3(p.x, -30, p.y), 1)
			var hit := space.intersect_ray(query)
			while not hit.is_empty() and not game.forest.terrain.sectors.has(hit.collider):
				query.exclude = query.exclude + [hit.rid]
				hit = space.intersect_ray(query)
			if hit.is_empty():
				return INF
			worst = maxf(worst, absf(hit.position.y - Generator.height_at(game.forest.ground, p.x, p.y)))
	return worst

func nothing_floats() -> bool:
	var forest: Node3D = game.forest
	var ok := true
	for node in forest.get_children():
		var id = node.get("prop_id")
		if id == null:
			continue
		var index := int(String(id).split(":")[1])
		if String(id).begins_with("tree:"):
			var entry: Dictionary = forest.description.trees[index]
			ok = ok and node.position.y <= Generator.footprint_min(forest.ground, entry.x, entry.z, entry.radius * 2.0) + 0.0001
		else:
			ok = ok and node.position.y <= Forest.rock_center_y(forest.ground, forest.description.rocks[index]) + 0.0001
	for pair in forest.markers:
		var p: Vector3 = pair[0].position
		ok = ok and p.y - 0.35 <= Generator.footprint_min(forest.ground, p.x, p.z, 0.16) + 0.0001
	for record in forest.undergrowth:
		for transform in record.transforms:
			ok = ok and absf(transform.origin.y - 0.015 - Generator.height_at(forest.ground, transform.origin.x, transform.origin.z)) < 0.001
	for target in game.targets:
		ok = ok and absf(target.position.y - Generator.height_at(forest.ground, target.position.x, target.position.z)) < 0.001
	return ok

func walk_to(destination: Vector2) -> bool:
	for i in range(1800):
		var here := Vector2(game.explorer.position.x, game.explorer.position.z)
		if here.distance_to(destination) < 0.4:
			return true
		await physics_frame
		game.explorer.step_movement(here.direction_to(destination), true, false, false, 1.0 / 120.0)
	return false

func scene_checks() -> void:
	game = Game.new()
	root.add_child(game)
	await frames(3)
	game.set_paused(false)
	game.explorer.controlled = false
	var forest: Node3D = game.forest
	var before := sector_ids()
	var start := Time.get_ticks_usec()
	var carved: bool = forest.carve_crater(Vector3(11, 0, 2), 2.2, 0.6)
	print("TIEMPO cráter sobre un borde (excavar + 2 sectores + reubicar) %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	await frames(2)
	check(carved and changed_sectors(before) == 2, "cráter sobre el borde x = 11 reconstruye solo sus 2 sectores")
	check(seams_match(), "después del cráter los bordes siguen compartiendo vértices y normales")
	var gap := collision_gap(Vector2(11, 2), 3.0)
	print("COLISIÓN EN EL CRÁTER diferencia máxima %.4f m" % gap)
	check(gap < 0.01, "la colisión sigue a la malla dentro del cráter")
	before = sector_ids()
	start = Time.get_ticks_usec()
	forest.carve_crater(Vector3(-11, 0, -11), 2.2, 0.6)
	print("TIEMPO cráter en una esquina (4 sectores) %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	await frames(2)
	check(changed_sectors(before) == 4 and seams_match() and collision_gap(Vector2(-11, -11), 3.0) < 0.01, "cráter en la esquina de 4 sectores sin grietas")
	# Same route as a real impact: combat signal → game → forest, which also lowers the targets.
	game._on_surface_hit(Vector3(-9, 0, 1.5), forest.terrain.sectors[4], 1)
	check(nothing_floats(), "árboles, rocas, marcadores, sotobosque y blancos bajan con el suelo")
	var d: Dictionary = forest.description
	var a := Vector2(d.path[0][0], d.path[0][1])
	var b := Vector2(d.path[1][0], d.path[1][1])
	var m := a.lerp(b, 0.5)
	var ground := Generator.height_at(forest.ground, m.x, m.y)
	var origin := Vector3(m.x, ground + 3, m.y + 3)
	var aim := (Vector3(m.x, ground, m.y) - origin).normalized()
	var edits: int = forest.terrain_edits.size()
	game.combat.fire(origin, aim, 0, 1.0)
	await frames(40)
	check(forest.terrain_edits.size() == edits, "la Aguja de Luz no excava")
	game.combat.fire(origin, aim, 1, 1.0)
	await frames(40)
	var dug := ground - Generator.height_at(forest.ground, m.x, m.y)
	check(forest.terrain_edits.size() == edits + 1 and dug > 0.4, "un impacto de Brasa sobre el suelo abre un cráter (%.2f m)" % dug)
	for i in range(3):
		forest.carve_crater(Vector3(m.x, 0, m.y), 2.2, 0.6)
	game.explorer.reset_at(Vector3(a.x, Generator.height_at(forest.ground, a.x, a.y) + 0.06, a.y))
	for i in range(120):
		await physics_frame
		game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	var entered: bool = await walk_to(m)
	var inside: float = game.explorer.position.y
	var floor_here := Generator.height_at(forest.ground, game.explorer.position.x, game.explorer.position.z)
	# The step limiter caps a 2.2 m crater at about 1.2 m deep, whatever the number of hits.
	check(entered and game.explorer.is_on_floor() and ground - inside > 0.6 and absf(inside - floor_here) < 0.1, "el jugador entra caminando y queda %.2f m bajo el suelo original" % (ground - inside))
	check(await walk_to(b) and game.explorer.is_on_floor(), "y sale caminando por el otro lado")
	game.regenerate(game.world_seed)
	await frames(2)
	check(game.forest.terrain_edits.is_empty() and game.forest.ground.terrain.heights_mm == game.forest.description.terrain.heights_mm, "regenerar restaura el terreno: los cráteres aún no se guardan")
	game.queue_free()
	await frames(2)
