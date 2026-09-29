extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Game = preload("res://scripts/game.gd")
const V = preload("res://scripts/visuals.gd")
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
	var a: Dictionary = Generator.generate(240926)
	check(a == Generator.generate(240926), "misma semilla reproduce toda la descripción")
	check(Generator.fingerprint(a) != Generator.fingerprint(Generator.generate(240927)), "otra semilla cambia el mundo")
	var canonical: String = JSON.stringify(a, "", true)
	var restored: Dictionary = JSON.parse_string(canonical)
	check(Generator.fingerprint(restored) == Generator.fingerprint(a) and int(restored.seed) == 240926 and is_equal_approx(restored.trees[0].x, a.trees[0].x), "descripción conserva identidad y coordenadas al serializar")
	var context := {"problem_id": "demo", "version": 1}
	var with_context: Dictionary = Generator.generate(4, context)
	context.problem_id = "changed"
	check(with_context.context.problem_id == "demo", "contexto opcional copiado sin alias")
	check(with_context.trees == Generator.generate(4).trees, "contexto reservado no altera el bosque base")
	var layouts_ok := true
	for seed_value in [1, 2, 3, 7, 42, 100, 999, 240926, 987654321, 999999999]:
		var data: Dictionary = Generator.generate(seed_value)
		var route: Array = []
		for pair in data.path:
			route.append(Vector2(pair[0], pair[1]))
		layouts_ok = layouts_ok and data.trees.size() >= 140 and data.rocks.size() >= 20
		for tree in data.trees:
			layouts_ok = layouts_ok and not Generator.protected(Vector2(tree.x, tree.z), route, 0.65)
		for rock in data.rocks:
			layouts_ok = layouts_ok and not Generator.protected(Vector2(rock.x, rock.z), route, 1.35)
	check(layouts_ok, "10 semillas mantienen densidad, claros y corredores libres")
	game = Game.new()
	root.add_child(game)
	await frames(3)
	check(game.paused and not game.combat.enabled, "inicio en menú con combate pausado")
	game.set_paused(false)
	game.explorer.controlled = false
	await settle()
	check(game.explorer.is_on_floor(), "jugador apoyado sobre suelo físico")
	for pair in game.forest.description.path.slice(1):
		check(await walk_to(Vector2(pair[0], pair[1])), "recorrido físico hasta %.1f / %.1f" % [pair[0], pair[1]])
	for pair in [game.forest.description.path[3], game.forest.description.path[2], game.forest.description.path[1], game.forest.description.path[0]]:
		check(await walk_to(Vector2(pair[0], pair[1])), "recorrido de regreso %.1f / %.1f" % [pair[0], pair[1]])
	game.respawn()
	await settle()
	var start_y: float = game.explorer.position.y
	game.explorer.step_movement(Vector2.ZERO, false, false, true, 1.0 / 120.0)
	for i in range(18):
		await physics_frame
		game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	check(game.explorer.position.y > start_y + 0.4, "salto eleva al jugador")
	await settle()
	game.explorer.step_movement(Vector2.ZERO, false, true, false, 1.0 / 120.0)
	check(game.explorer.crouched and game.explorer.body_collision.shape.height < 1.2, "agacharse reduce el volumen físico")
	var ceiling := V.box(game, game.explorer.position + Vector3(0, 1.5, 0), Vector3(2, 0.2, 2), Color.WHITE, true)
	await frames(2)
	game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	check(game.explorer.crouched, "prueba de volumen impide levantarse bajo techo")
	ceiling.queue_free()
	await frames(2)
	game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)
	check(not game.explorer.crouched, "puede levantarse al salir del techo")
	var tree: Dictionary = game.forest.description.trees[0]
	var trunk_start := Vector3(tree.x, 1, tree.z + 1)
	var ray := PhysicsRayQueryParameters3D.create(trunk_start, trunk_start - Vector3(0, 0, 2), 1)
	check(not root.world_3d.direct_space_state.intersect_ray(ray).is_empty(), "troncos tienen colisión física")
	game.explorer.reset_at(Vector3(0, 0.05, 30))
	await settle()
	for i in range(140):
		await physics_frame
		game.explorer.step_movement(Vector2(0, 1), true, false, false, 1.0 / 120.0)
	check(game.explorer.position.z < 31.3, "borde visible impide salir del bosque")
	game.combat.reset()
	check(game.combat.fire(Vector3(-9, 1.4, 7), Vector3.FORWARD), "ataque ofensivo crea un proyectil")
	check(is_equal_approx(game.combat.mana, 88), "lanzamiento consume maná")
	check(not game.combat.fire(Vector3.ZERO, Vector3.FORWARD), "cooldown impide disparos inmediatos")
	await frames(60)
	check(is_equal_approx(game.targets[1].health, 60), "proyectil impacta y aplica 30 de daño")
	for i in range(2):
		game.combat.fire(Vector3(-9, 1.4, 7), Vector3.FORWARD)
		await frames(60)
	check(not game.targets[1].active and game.destroyed_count == 1, "tres impactos destruyen el cristal y notifican al juego")
	game.set_paused(true)
	var remaining: float = game.targets[1].respawn_left
	await frames(30)
	check(is_equal_approx(remaining, game.targets[1].respawn_left), "pausa congela respawn")
	check(not game.combat.fire(Vector3.ZERO, Vector3.FORWARD), "pausa bloquea lanzamiento")
	game.set_paused(false)
	game.explorer.controlled = false
	await frames(380)
	check(game.targets[1].active and game.targets[1].health == 90, "cristal reaparece con vida completa")
	var wall := V.box(game, Vector3(-9, 1.4, 4), Vector3(2, 3, 0.3), Color.WHITE, true)
	await frames(2)
	game.combat.fire(Vector3(-9, 1.4, 7), Vector3.FORWARD)
	await frames(60)
	check(game.targets[1].health == 90, "hechizo no atraviesa un obstáculo")
	wall.queue_free()
	game.combat.mana = 0
	check(not game.combat.fire(Vector3.ZERO, Vector3.FORWARD), "sin maná no se puede lanzar")
	await frames(180)
	check(game.combat.mana > 5, "maná se recupera después de lanzar")
	game.combat.fire(Vector3(0, 2, 25), Vector3.FORWARD)
	var before: int = game.get_child_count()
	for value in [45, 240926, 9, 240926]:
		game.regenerate(value)
		await frames(3)
	check(game.get_child_count() == before and game.targets.size() == 3, "regenerar no acumula mapas ni blancos")
	check(game.combat.projectiles.is_empty() and game.combat.mana == 100, "regenerar limpia proyectiles y recursos")
	check(game.forest.description == a, "volver a semilla inicial reconstruye el bosque original")
	check(game.explorer.position.distance_to(Generator.SPAWN) < 0.1, "regenerar devuelve al spawn seguro")
	var old_seed: int = game.world_seed
	game.hud.seed_input.text = "incorrecto"
	game.hud._submit_seed()
	check(game.world_seed == old_seed, "menú rechaza semilla inválida")
	game.hud.seed_input.text = "42"
	game.hud._submit_seed()
	check(game.world_seed == 42, "semilla del menú regenera el mundo")
	game.queue_free()
	await process_frame
	print("RESULTADO: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func settle() -> void:
	for i in range(150):
		await physics_frame
		game.explorer.step_movement(Vector2.ZERO, false, false, false, 1.0 / 120.0)

func walk_to(destination: Vector2) -> bool:
	for i in range(1800):
		var here := Vector2(game.explorer.position.x, game.explorer.position.z)
		if here.distance_to(destination) < 0.4:
			return true
		await physics_frame
		game.explorer.step_movement(here.direction_to(destination), true, false, false, 1.0 / 120.0)
	return false
