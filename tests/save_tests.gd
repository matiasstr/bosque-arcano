extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Save = preload("res://scripts/world_save.gd")
const Game = preload("res://scripts/game.gd")
const Forest = preload("res://scripts/forest.gd")
# Own folder: tests never read or write the player's user://mundo.json.
const DIR := "user://pruebas-guardado"
const PATH := DIR + "/mundo.json"
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

func clean() -> void:
	for name in ["mundo.json", "mundo.json.tmp", "mundo.json.invalido", "bloqueo"]:
		if FileAccess.file_exists(DIR + "/" + name):
			DirAccess.remove_absolute(DIR + "/" + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	clean()
	file_checks()
	await game_checks()
	clean()
	DirAccess.remove_absolute(DIR)
	print("GUARDADO: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func sample_state() -> Dictionary:
	var d: Dictionary = Generator.generate(4321)
	var current: PackedInt32Array = d.terrain.heights_mm.duplicate()
	current[500] -= 300
	current[501] -= 1200
	return Save.snapshot(4321, {"tree:7": true, "rock:2": true}, d.terrain.heights_mm, current)

func write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func file_checks() -> void:
	check(not Save.read(PATH).ok and Save.read(PATH).missing, "sin archivo: no hay guardado y no es un error")
	var state := sample_state()
	var start := Time.get_ticks_usec()
	var written := Save.write(PATH, state)
	print("TIEMPO escribir guardado %.2f ms · %d bytes" % [(Time.get_ticks_usec() - start) / 1000.0, FileAccess.get_file_as_bytes(PATH).size()])
	var loaded := Save.read(PATH)
	check(written == OK and loaded.ok and loaded.data.seed == 4321 and loaded.data.destroyed == ["rock:2", "tree:7"] and loaded.data.dug.map(func(v): return int(v)) == [500, 300, 501, 1200], "guardar y leer conserva semilla, destruidos y excavación")
	check(not FileAccess.file_exists(PATH + ".tmp"), "no queda archivo temporal después de guardar")
	var text := FileAccess.get_file_as_string(PATH)
	write_raw(PATH, text.substr(0, text.length() / 2))
	check(not Save.read(PATH).ok and not Save.read(PATH).missing, "archivo cortado a la mitad se detecta como dañado")
	write_raw(PATH, text.replace("\"seed\":4321", "\"seed\":4322"))
	check(text.contains("\"seed\":4321") and "huella" in Save.read(PATH).reason, "un valor alterado no pasa la huella")
	var other := state.duplicate()
	other.generator_version = Generator.VERSION + 1
	other.erase("checksum")
	other.checksum = Generator.fingerprint(other)
	Save.write(PATH, other)
	check("versión del generador" in Save.read(PATH).reason, "guardado de otra versión del generador se rechaza")
	var bad := state.duplicate()
	bad.dug = [999999, 10]
	bad.erase("checksum")
	bad.checksum = Generator.fingerprint(bad)
	Save.write(PATH, bad)
	check(not Save.read(PATH).ok, "excavación fuera de la grilla se rechaza")
	Save.write(PATH, state)
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	check(Save.read(PATH).ok and Save.read(PATH).data.seed == 4321, "corte entre escribir y renombrar: se recupera el temporal")
	DirAccess.remove_absolute(PATH + ".tmp")
	write_raw(DIR + "/bloqueo", "no es una carpeta")
	var failed := Save.write(DIR + "/bloqueo/mundo.json", state)
	check(failed != OK and not FileAccess.file_exists(DIR + "/bloqueo/mundo.json"), "si no se puede escribir, se devuelve el error (%s)" % error_string(failed))
	var huge := {}
	for i in range(155):
		huge["tree:%d" % i] = true
	var d: Dictionary = Generator.generate(1)
	var all_dug: PackedInt32Array = d.terrain.heights_mm.duplicate()
	for k in range(all_dug.size()):
		all_dug[k] -= 1500
	Save.write(PATH, Save.snapshot(1, huge, d.terrain.heights_mm, all_dug))
	var size := FileAccess.get_file_as_bytes(PATH).size()
	print("PEOR CASO todo el terreno excavado y 155 árboles: %d KB" % (size / 1024))
	check(Save.read(PATH).ok and size < 400 * 1024, "el tamaño queda acotado aunque se excave toda la región")
	clean()

func new_game(path: String) -> Node:
	var game := Game.new()
	game.persistence = true
	game.save_path = path
	root.add_child(game)
	await frames(3)
	return game

func game_checks() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var plain := Game.new()
	check(scene.persistence and not plain.persistence, "solo la escena principal guarda; el juego creado por tests no")
	scene.free()
	plain.free()
	var game = await new_game(PATH)
	check(game.forest.terrain_edits.is_empty() and Save.read(PATH).ok and Save.read(PATH).data.seed == game.world_seed, "primera apertura crea un guardado del mundo nuevo")
	game.regenerate(777)
	await frames(2)
	check(Save.read(PATH).data.seed == 777, "elegir otra semilla reemplaza el mundo guardado")
	game.set_paused(false)
	game.explorer.controlled = false
	var forest: Node3D = game.forest
	var tree = null
	var rock = null
	for node in forest.get_children():
		if node.get("prop_id") == "tree:3":
			tree = node
		if node.get("prop_id") == "rock:1":
			rock = node
	tree.take_damage(500)
	rock.take_damage(500)
	var d: Dictionary = forest.description
	var spot := Vector2(d.path[1][0], d.path[1][1]).lerp(Vector2(d.path[2][0], d.path[2][1]), 0.5)
	game._on_surface_hit(Vector3(spot.x, 0, spot.y), forest.terrain.sectors[4], 1)
	await frames(30)
	check(Save.read(PATH).data.destroyed.is_empty(), "el autoguardado espera un segundo después del último cambio")
	await frames(120)
	var saved := Save.read(PATH)
	check(saved.ok and saved.data.destroyed == ["rock:1", "tree:3"] and not saved.data.dug.is_empty(), "un segundo después se guardan destruidos y cráter")
	var heights: PackedInt32Array = forest.ground.terrain.heights_mm.duplicate()
	game._on_surface_hit(Vector3(spot.x + 1, 0, spot.y), forest.terrain.sectors[4], 1)
	game.set_paused(true)
	check(Save.read(PATH).data.dug.size() > saved.data.dug.size(), "pausar guarda el cambio pendiente de inmediato")
	heights = forest.ground.terrain.heights_mm.duplicate()
	game.queue_free()
	await frames(2)
	var start := Time.get_ticks_usec()
	var again = await new_game(PATH)
	print("TIEMPO abrir el juego y recuperar el mundo %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	var restored: Node3D = again.forest
	var ids := []
	for node in restored.get_children():
		if node.get("prop_id") != null and not node.broken:
			ids.append(node.prop_id)
	check(again.world_seed == 777 and restored.ground.terrain.heights_mm == heights, "al reabrir: misma semilla y el terreno excavado idéntico")
	check(not ids.has("tree:3") and not ids.has("rock:1") and restored.destroyed_props.has("tree:3") and ids.size() == d.trees.size() + d.rocks.size() - 2, "al reabrir: siguen destruidos exactamente el árbol y la roca")
	var floats := false
	for node in restored.get_children():
		var id = node.get("prop_id")
		if id == null or node.broken:
			continue
		var index := int(String(id).split(":")[1])
		if String(id).begins_with("tree:"):
			var entry: Dictionary = d.trees[index]
			floats = floats or node.position.y > Generator.footprint_min(restored.ground, entry.x, entry.z, entry.radius * 2.0) + 0.0001
		else:
			floats = floats or node.position.y > Forest.rock_center_y(restored.ground, d.rocks[index]) + 0.0001
	check(not floats, "al reabrir: nada flota sobre los cráteres recuperados")
	var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spot.x, 30, spot.y), Vector3(spot.x, -30, spot.y), 1))
	check(not hit.is_empty() and absf(hit.position.y - Generator.height_at(restored.ground, spot.x, spot.y)) < 0.01, "al reabrir: la colisión incluye el cráter")
	check("recuperado" in again.hud.message.text, "aviso en pantalla: mundo recuperado")
	again.queue_free()
	await frames(2)
	write_raw(PATH, "{\"roto\": ")
	var broken = await new_game(PATH)
	check(FileAccess.file_exists(PATH + ".invalido") and "No se pudo cargar" in broken.hud.message.text, "guardado dañado: se aparta, se avisa y empieza un mundo nuevo")
	check(Save.read(PATH).ok and broken.forest.destroyed_props.is_empty(), "el mundo nuevo queda guardado sin pisar la copia dañada")
	broken.queue_free()
	await frames(2)
