extends SceneTree
const Game = preload("res://scripts/game.gd")
var count := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	count += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", text])
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_paused(false)
	game.explorer.controlled = false
	await physics_frame
	var tree = null
	var rock = null
	for node in game.forest.get_children():
		if node.get("prop_id") == "tree:0":
			tree = node
		if node.get("prop_id") == "rock:0":
			rock = node
	check(tree != null and rock != null, "árboles y rocas tienen IDs destructibles")
	var point: Vector3 = tree.global_position + Vector3(0, 1.4, 1)
	var ray := PhysicsRayQueryParameters3D.create(point, point - Vector3(0, 0, 2), 1)
	check(root.world_3d.direct_space_state.intersect_ray(ray).get("collider") == tree, "colisión del tronco recibe impactos")
	game.combat.fire(point, Vector3.FORWARD, 0, 1)
	for i in range(30):
		await physics_frame
	check(tree.health == 54, "proyectil quita vida al árbol")
	tree.take_damage(54)
	await process_frame
	await physics_frame
	check(not is_instance_valid(tree), "destruir elimina geometría y cuerpo del árbol")
	check(game.forest.destroyed_props.has("tree:0"), "registro local conserva ID destruido")
	check(root.world_3d.direct_space_state.intersect_ray(ray).is_empty(), "árbol destruido deja de bloquear")
	rock.take_damage(60)
	await process_frame
	check(not is_instance_valid(rock) and game.forest.destroyed_props.has("rock:0"), "roca destruida se retira y registra")
	game.regenerate(game.world_seed)
	await physics_frame
	check(game.forest.destroyed_props.is_empty(), "regeneración explícita restaura mundo de prueba")
	game.queue_free()
	await process_frame
	print("DESTRUCCIÓN: %d verificaciones, %d fallos" % [count, failures])
	quit(0 if failures == 0 else 1)
