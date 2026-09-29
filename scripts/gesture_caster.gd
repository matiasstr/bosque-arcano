extends Node
## Captured mouse never warps/unlocks: releasing Ctrl restores look without catch-up.
signal trace_changed
signal lock_changed(locked: bool)
signal spell_prepared(spell: int, result: Dictionary)
signal launch_requested(spell: int, result: Dictionary)
signal feedback(text: String)
const Math = preload("res://scripts/gesture_math.gd")
const Book = preload("res://scripts/spell_catalog.gd")
var enabled := false
var active := false
var selected := 0
var points := PackedVector2Array()
var elapsed := 0.0
var cast_gate: Callable
var overflow := false
var last_result: Dictionary = {}
var prepared: Dictionary = {}

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_CTRL:
			if event.pressed:
				begin()
			else:
				finish()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode in [KEY_1, KEY_2]:
			cancel()
			selected = event.physical_keycode - KEY_1
			trace_changed.emit()
		elif event.pressed and event.physical_keycode == KEY_Q:
			cancel()
			feedback.emit("Trazo cancelado")
	if event is InputEventMouseMotion and active:
		append_motion(event.screen_relative)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			feedback.emit("Hechizo descartado · Ctrl para preparar otro")
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			request_launch()
			get_viewport().set_input_as_handled()

func begin() -> void:
	if not enabled or active:
		return
	if cast_gate.is_valid() and not cast_gate.call(selected):
		feedback.emit("Necesitás recuperar maná para preparar este hechizo")
		return
	prepared.clear()
	active = true
	overflow = false
	elapsed = 0
	points = PackedVector2Array([Vector2.ZERO])
	lock_changed.emit(true)
	trace_changed.emit()

func append_motion(delta: Vector2) -> void:
	if not active or delta.is_zero_approx() or not delta.is_finite():
		return
	if points.size() >= 2048:
		overflow = true
		return
	points.append(points[-1] + delta)
	trace_changed.emit()

func _physics_process(delta: float) -> void:
	if active and enabled:
		elapsed += delta

func finish() -> void:
	if not active:
		return
	active = false
	lock_changed.emit(false)
	last_result = Math.evaluate(points, selected)
	if overflow:
		last_result = {"valid": false, "quality": 0.0, "reason": "Trazo demasiado largo"}
	last_result["seconds"] = elapsed
	last_result["evaluator_version"] = Math.VERSION
	trace_changed.emit()
	if last_result.valid and enabled:
		prepared = last_result.duplicate(true)
		prepared["spell"] = selected
		spell_prepared.emit(selected, prepared.duplicate(true))
		trace_changed.emit()
	else:
		feedback.emit(last_result.reason)

func cancel() -> void:
	active = false
	points.clear()
	prepared.clear()
	lock_changed.emit(false)
	trace_changed.emit()

func request_launch() -> void:
	if not enabled:
		return
	if active:
		feedback.emit("Soltá Ctrl para terminar de preparar")
	elif prepared.is_empty():
		feedback.emit("Primero prepará el hechizo con Ctrl + trazo")
	else:
		launch_requested.emit(prepared.spell, prepared.duplicate(true))

func consume_prepared() -> void:
	prepared.clear()
	points.clear()
	trace_changed.emit()
