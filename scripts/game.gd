extends Node3D
## Composition root: wires components, not a shared gameplay state bag.
const Generator = preload("res://scripts/world_generator.gd")
const Forest = preload("res://scripts/forest.gd")
const Explorer = preload("res://scripts/explorer.gd")
const Combat = preload("res://scripts/magic_combat.gd")
const Target = preload("res://scripts/practice_target.gd")
const Hud = preload("res://scripts/hud.gd")
const Caster = preload("res://scripts/gesture_caster.gd")
const Book = preload("res://scripts/spell_catalog.gd")
const Save = preload("res://scripts/world_save.gd")
const AUTOSAVE_DELAY := 1.0
const RETRY_DELAY := 5.0
## Only main.tscn turns this on, so tests never touch the player's save.
@export var persistence := false
var save_path := Save.DEFAULT_PATH
## Seconds until the pending autosave; negative when nothing is pending.
var save_wait := -1.0
var last_save_error := OK
var restoring := false
var world_seed := 240926
var forest: Node3D
var explorer: CharacterBody3D
var combat: Node3D
var hud: CanvasLayer
var targets: Array = []
var paused := true
var destroyed_count := 0
var caster: Node

func _ready() -> void:
	_install_inputs()
	_lighting()
	explorer = Explorer.new()
	add_child(explorer)
	combat = Combat.new()
	add_child(combat)
	caster = Caster.new()
	add_child(caster)
	caster.cast_gate = combat.can_begin
	caster.lock_changed.connect(func(locked): explorer.aim_locked = locked)
	caster.spell_prepared.connect(_prepare_gesture)
	caster.launch_requested.connect(_cast_gesture)
	explorer.fell_outside.connect(respawn)
	combat.cast_launched.connect(func(): explorer.kick = 1.0)
	combat.surface_hit.connect(_on_surface_hit)
	hud = Hud.new()
	add_child(hud)
	hud.bind_caster(caster)
	caster.feedback.connect(hud.show_cast)
	hud.resume_requested.connect(func(): set_paused(false))
	hud.seed_requested.connect(regenerate)
	hud.new_seed_requested.connect(func(): regenerate(1 + (world_seed * 48271) % 999999998))
	hud.respawn_requested.connect(respawn)
	hud.sensitivity_changed.connect(func(value): explorer.sensitivity = value)
	if persistence:
		_load_world()
	else:
		regenerate(world_seed)
	set_paused(true)

func _load_world() -> void:
	var loaded := Save.read(save_path)
	restoring = true
	if loaded.ok:
		regenerate(loaded.data.seed)
		forest.restore(loaded.data.destroyed, loaded.data.dug)
		_settle_targets()
		restoring = false
		hud.message.text = "Mundo recuperado · semilla %d · %d objetos destruidos%s" % [world_seed, loaded.data.destroyed.size(), " · terreno excavado" if not loaded.data.dug.is_empty() else ""]
		hud.hint_time = 4.0
		return
	regenerate(world_seed)
	restoring = false
	if not loaded.missing:
		Save.set_aside(save_path)
		hud.message.text = "No se pudo cargar el guardado (%s). Quedó aparte como mundo.json.invalido; empieza un mundo nuevo." % loaded.reason
		hud.hint_time = 6.0
	save_world()

func world_changed() -> void:
	if persistence:
		save_wait = AUTOSAVE_DELAY

## Returns the write result; on failure the change stays pending and is retried later.
func save_world() -> Error:
	if not persistence:
		return ERR_UNAVAILABLE
	save_wait = -1.0
	var data := Save.snapshot(world_seed, forest.destroyed_props, forest.description.terrain.heights_mm, forest.ground.terrain.heights_mm)
	last_save_error = Save.write(save_path, data)
	if last_save_error != OK:
		save_wait = RETRY_DELAY
		hud.message.text = "No se pudo guardar el mundo (%s). Se reintentará." % error_string(last_save_error)
		hud.hint_time = 5.0
	return last_save_error

func _install_inputs() -> void:
	for pair in [["forward", KEY_W], ["back", KEY_S], ["left", KEY_A], ["right", KEY_D], ["sprint", KEY_SHIFT], ["crouch", KEY_C], ["jump", KEY_SPACE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var key := InputEventKey.new()
			key.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], key)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", click)
	Input.use_accumulated_input = false

func _lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("536d79")
	sky_material.sky_horizon_color = Color("b5b7a2")
	sky_material.ground_bottom_color = Color("1d261b")
	sky_material.ground_horizon_color = Color("b5b7a2")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9eafb7")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("91a18c")
	environment.fog_density = 0.008
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.018
		environment.volumetric_fog_length = 45
		environment.volumetric_fog_albedo = Color("b8c0a2")
		environment.volumetric_fog_anisotropy = 0.65
		environment.ssao_enabled = true
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("ffe4b1")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func regenerate(value: int) -> void:
	caster.cancel()
	world_seed = clampi(value, 1, 999999999)
	combat.reset()
	targets.clear()
	if is_instance_valid(forest):
		remove_child(forest)
		forest.queue_free()
	forest = Forest.new()
	add_child(forest)
	forest.prop_destroyed.connect(func(kind):
		hud.message.text = "%s destruido" % kind
		hud.hint_time = 2.5
		world_changed())
	forest.build(Generator.generate(world_seed))
	for point in [Vector3(-12, 0, 3), Vector3(-9, 0, 1), Vector3(-6, 0, 3)]:
		var target := Target.new()
		forest.add_child(target)
		target.position = Vector3(point.x, Generator.height_at(forest.description, point.x, point.z), point.z)
		target.damaged.connect(_on_damage)
		targets.append(target)
	destroyed_count = 0
	explorer.reset_at(Generator.spawn_point(forest.description))
	hud.set_seed(world_seed)
	hud.show_cast("Ctrl + trazo prepara · Click izquierdo lanza")
	hud.update_state(combat.mana, explorer.position, destroyed_count)
	# Regenerating is an explicit reset: the new world replaces the saved one.
	if persistence and not restoring:
		save_world()

func respawn() -> void:
	caster.cancel()
	hud.show_cast("Volviste al inicio · Ctrl + trazo prepara")
	# Current ground, so a crater dug at the spawn does not drop the player from the old height.
	explorer.reset_at(Generator.spawn_point(forest.ground))
	combat.reset()

func set_paused(value: bool) -> void:
	paused = value
	if value:
		if persistence and save_wait >= 0:
			save_world()
		if caster.active or not caster.prepared.is_empty():
			hud.show_cast("Hechizo descartado al pausar · Ctrl prepara otro")
		caster.cancel()
	caster.enabled = not value
	explorer.controlled = not value
	combat.enabled = not value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	hud.set_paused(value)

func _prepare_gesture(spell: int, result: Dictionary) -> void:
	var stats := Book.stats(spell, result.quality)
	hud.show_cast("CARGADO · %d%% precisión · %.0f daño · %.1f maná · Click izq. lanza" % [roundi(result.quality * 100), stats.damage, stats.cost])

func _cast_gesture(spell: int, result: Dictionary) -> void:
	if combat.fire(explorer.camera.global_position, -explorer.camera.global_basis.z, spell, result.quality):
		caster.consume_prepared()
		hud.show_cast("Precisión %d%% · %.2f s · %.0f daño · %.1f maná" % [roundi(result.quality * 100), result.seconds, combat.last_cast.damage, combat.last_cast.cost])
	else:
		hud.show_cast("Carga conservada · esperá el cooldown o recuperá maná")

func _on_surface_hit(point: Vector3, collider: Object, spell: int) -> void:
	var source: Dictionary = Book.SPELLS[spell]
	if source.crater_radius <= 0 or not forest.terrain.sectors.has(collider):
		return
	if forest.carve_crater(point, source.crater_radius, source.crater_depth):
		_settle_targets()
		world_changed()

func _settle_targets() -> void:
	for target in targets:
		target.position.y = minf(target.position.y, Generator.height_at(forest.ground, target.position.x, target.position.z))

func _on_damage(amount: float, destroyed: bool) -> void:
	if destroyed:
		destroyed_count += 1
	hud.hit_feedback(amount, destroyed)

func _physics_process(delta: float) -> void:
	if save_wait >= 0:
		save_wait -= delta
		if save_wait < 0:
			save_world()
	if not paused:
		for target in targets:
			target.tick(delta)
		hud.tick(delta)
	hud.update_state(combat.mana, explorer.position, destroyed_count)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F5:
			respawn()
		elif event.physical_keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and persistence and save_wait >= 0:
		save_world()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		set_paused(true)
