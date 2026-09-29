extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	await snapshot("res://preview-menu.png")
	var cross: Control = game.hud.root.get_node("Crosshair")
	verify(cross.get_global_rect().get_center().distance_to(Vector2(640, 360)) < 12, "mira centrada en pantalla")
	# Press the real menu button through pointer input.
	var button: Button = game.hud.menu.get_child(0).get_child(2)
	var point := button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = point
	Input.parse_input_event(up)
	await process_frame
	verify(not game.paused, "botón real inicia exploración")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(12, -3)
	move.screen_relative = move.relative
	Input.parse_input_event(move)
	await process_frame
	verify(absf(game.explorer.yaw) > 0.1, "mouse modifica orientación")
	game.explorer.reset_at(Vector3(0, 0.06, 25))
	await snapshot("res://preview-bosque.png")
	game.explorer.reset_at(Vector3(-9, 0.06, 8))
	await snapshot("res://preview-combate.png")
	game.explorer.pitch = -1.8
	game.explorer.update_camera()
	var before_yaw: float = game.explorer.yaw
	var before_pitch: float = game.explorer.pitch
	var before_position: Vector3 = game.explorer.position
	await key(KEY_CTRL, true)
	verify(game.caster.active and game.explorer.aim_locked, "Ctrl inicia el trazo y bloquea giro")
	Input.action_press("left")
	for i in range(24):
		await motion(Vector2(0, 5))
		if i == 8:
			Input.action_release("left")
	verify(game.explorer.position.distance_to(before_position) > 0.02, "WASD mueve durante el gesto")
	verify(is_equal_approx(game.explorer.yaw, before_yaw) and is_equal_approx(game.explorer.pitch, before_pitch), "trazo no cambia orientación de cámara")
	verify(is_equal_approx(Engine.time_scale, 1.0), "gesto mantiene tiempo real")
	await snapshot("res://preview-gesto.png")
	await key(KEY_CTRL, false)
	verify(not game.caster.active and not game.explorer.aim_locked, "soltar Ctrl devuelve control de cámara")
	verify(is_equal_approx(game.explorer.yaw, before_yaw) and is_equal_approx(game.explorer.pitch, before_pitch), "sin salto de cámara al terminar")
	verify(not game.caster.prepared.is_empty() and game.combat.projectiles.is_empty() and game.combat.mana == 100, "soltar Ctrl carga sin disparar ni consumir maná")
	await snapshot("res://preview-cargado.png")
	await motion(Vector2(2, 0))
	var launch_direction: Vector3 = -game.explorer.camera.global_basis.z
	await click(MOUSE_BUTTON_LEFT)
	verify(game.combat.last_cast.direction.distance_to(launch_direction) < 0.001, "click dispara hacia la nueva puntería después de preparar")
	verify(game.caster.prepared.is_empty(), "click consume la única carga")
	for i in range(65):
		await physics_frame
	verify(game.targets[1].health < 90, "gesto y click reales dañan un blanco")
	await snapshot("res://preview-precision.png")
	await key(KEY_2, true)
	await key(KEY_2, false)
	verify(game.caster.selected == 1, "tecla 2 selecciona Brasa")
	await key(KEY_CTRL, true)
	for i in range(13):
		await motion(Vector2(5, 100.0 / 13))
	for i in range(13):
		await motion(Vector2(5, -100.0 / 13))
	await snapshot("res://preview-gesto-v.png")
	await key(KEY_CTRL, false)
	verify(game.caster.prepared.spell == 1 and game.caster.prepared.quality > 0.99, "V real de mouse prepara Brasa")
	await click(MOUSE_BUTTON_LEFT)
	verify(game.combat.last_cast.spell == 1 and game.combat.last_cast.quality > 0.99, "V real de mouse lanza Brasa con máxima precisión")
	for i in range(80):
		await physics_frame
	await key(KEY_CTRL, true)
	verify(game.caster.active, "nuevo ritual disponible después del cooldown")
	await motion(Vector2(10, 10))
	var mana_before_cancel: float = game.combat.mana
	await click(MOUSE_BUTTON_RIGHT)
	await key(KEY_CTRL, false)
	verify(not game.caster.active and game.combat.mana >= mana_before_cancel, "click derecho cancela trazo sin consumir maná")
	await key(KEY_CTRL, true)
	await motion(Vector2(65, 100))
	await motion(Vector2(65, -100))
	await key(KEY_CTRL, false)
	verify(not game.caster.prepared.is_empty(), "segunda carga lista para descartar")
	await click(MOUSE_BUTTON_RIGHT)
	verify(game.caster.prepared.is_empty(), "click derecho descarta hechizo preparado")
	await motion(Vector2(8, 0))
	verify(not is_equal_approx(game.explorer.yaw, before_yaw), "mouse vuelve a apuntar después del trazo")
	await key(KEY_CTRL, true)
	await motion(Vector2(0, 40))
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	verify(game.paused and game.hud.menu.visible, "Escape abre menú y pausa")
	verify(not game.caster.active and not game.explorer.aim_locked, "pausa cancela trazo sin lanzar")
	await key(KEY_CTRL, false)
	game.set_paused(false)
	game.explorer.reset_at(Vector3(0, 0.06, 25))
	for i in range(45):
		await process_frame
	var start := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
	var ms := (Time.get_ticks_usec() - start) / 120000.0
	print("RENDER %s / 1280x720 / 120 frames / media %.2f ms (%.1f FPS)" % [RenderingServer.get_current_rendering_method(), ms, 1000.0 / ms])
	game.hud.visible = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(46, 54, 56)
	camera.fov = 46
	camera.look_at(Vector3(0, 0, -1))
	camera.current = true
	await snapshot("res://preview-plano.png")
	game.queue_free()
	await process_frame
	print("RESULTADO GRÁFICO: %d verificaciones, %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func verify(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", description])

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func motion(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	await process_frame

func click(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(640, 360)
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = button
	event.position = Vector2(640, 360)
	Input.parse_input_event(event)
	await process_frame

func snapshot(path: String) -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		path = path.replace(".png", "-ligero.png")
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		push_error("No se pudo guardar captura: " + path)
