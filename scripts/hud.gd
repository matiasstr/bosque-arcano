extends CanvasLayer
signal resume_requested
signal seed_requested(value: int)
signal new_seed_requested
signal respawn_requested
signal sensitivity_changed(value: float)
const Overlay = preload("res://scripts/gesture_overlay.gd")
const Book = preload("res://scripts/spell_catalog.gd")
var root: Control
var status: Label
var message: Label
var mana: ColorRect
var mana_text: Label
var seed_value: Label
var menu: PanelContainer
var seed_input: LineEdit
var hint_time := 0.0
var spell_label: Label
var gesture_overlay: Control
var cast_report: Label

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label("B O S Q U E   A R C A N O", Vector2(30, 24), 23)
	title.modulate = Color("d3f4e0")
	seed_value = _label("", Vector2(31, 58), 15)
	status = _label("", Vector2(31, 84), 15)
	message = _label("Seguí las luces hasta el claro de práctica.", Vector2(30, 122), 17)
	message.modulate = Color("f1d79e")
	var cross := _label("+", Vector2.ZERO, 24)
	cross.name = "Crosshair"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -8
	cross.offset_right = 8
	cross.offset_top = -17
	cross.offset_bottom = 17
	var background := ColorRect.new()
	background.position = Vector2(30, 617)
	background.size = Vector2(245, 8)
	background.color = Color(0.025, 0.08, 0.06, 0.85)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	mana = ColorRect.new()
	mana.size = Vector2(245, 8)
	mana.color = Color("79ddc0")
	mana.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(mana)
	mana_text = _label("", Vector2(30, 631), 18)
	spell_label = _label("", Vector2(30, 588), 15)
	cast_report = _label("Ctrl + trazo prepara · Click izquierdo lanza", Vector2(30, 558), 17)
	cast_report.modulate = Color("edd5a5")
	_label("WASD mover   ·   Shift correr   ·   Espacio saltar   ·   C agacharse", Vector2(30, 676), 14)
	_label("Ctrl trazar · Izq. lanzar · Der. descartar · 1 / 2 hechizo", Vector2(790, 676), 14)
	gesture_overlay = Overlay.new()
	root.add_child(gesture_overlay)
	_menu()

func _label(text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("edf7ec"))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.03, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _menu() -> void:
	menu = PanelContainer.new()
	menu.position = Vector2(411, 125)
	menu.size = Vector2(458, 455)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.065, 0.98)
	style.border_color = Color("608876")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	menu.add_theme_stylebox_override("panel", style)
	root.add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	menu.add_child(column)
	var title := Label.new()
	title.text = "EL BOSQUE DESPIERTA"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	var info := Label.new()
	info.text = "Ctrl + trazo prepara. Soltá y volvé a apuntar.\nClick izq. lanza · Click der. descarta."
	column.add_child(info)
	_button(column, "ENTRAR / CONTINUAR", func(): resume_requested.emit())
	var row := HBoxContainer.new()
	column.add_child(row)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Semilla (1–999999999)"
	seed_input.max_length = 9
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.text_submitted.connect(func(_text): _submit_seed())
	row.add_child(seed_input)
	_button(row, "GENERAR", _submit_seed)
	_button(column, "OTRA SEMILLA", func(): new_seed_requested.emit())
	_button(column, "VOLVER AL INICIO", func(): respawn_requested.emit())
	var sensitivity := Label.new()
	sensitivity.text = "Sensibilidad del mouse"
	column.add_child(sensitivity)
	var slider := HSlider.new()
	slider.min_value = 0.02
	slider.max_value = 0.2
	slider.step = 0.005
	slider.value = 0.09
	slider.value_changed.connect(func(value): sensitivity_changed.emit(value))
	column.add_child(slider)
	var footer := Label.new()
	footer.text = "Prototipo 0.2 · Gestos de precisión · Tiempo real"
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)
	_button(column, "SALIR", func(): get_tree().quit())

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _submit_seed() -> void:
	if not seed_input.text.is_valid_int() or int(seed_input.text) < 1:
		seed_input.text = ""
		seed_input.placeholder_text = "Ingresá un entero entre 1 y 999999999"
		return
	seed_requested.emit(clampi(int(seed_input.text), 1, 999999999))

func set_seed(value: int) -> void:
	seed_value.text = "SEMILLA %d   /   GENERADOR 1   /   EXPLORACIÓN" % value
	seed_input.text = str(value)

func set_paused(value: bool) -> void:
	menu.visible = value
	gesture_overlay.visible = not value
	if not value:
		var focused := root.get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()

func update_state(value: float, position: Vector3, destroyed: int) -> void:
	mana.size.x = 245 * clampf(value / 100, 0, 1)
	mana_text.text = "MANÁ  %03d / 100" % int(value)
	status.text = "X %5.1f    Z %5.1f    ·    CRISTALES DESTRUIDOS %d" % [position.x, position.z, destroyed]

func hit_feedback(amount: float, destroyed: bool) -> void:
	message.text = "Cristal destruido · reaparece en 3 segundos" if destroyed else "Impacto · %d de daño" % int(amount)
	hint_time = 2.5

func bind_caster(caster: Node) -> void:
	gesture_overlay.caster = caster
	caster.trace_changed.connect(func():
		var data: Dictionary = Book.SPELLS[caster.selected]
		spell_label.text = "%s · %.0f–%.0f daño · %.0f–%.0f maná" % [data.name, data.damage_min, data.damage_max, data.cost_min, data.cost_max])
	caster.trace_changed.emit()

func show_cast(text: String) -> void:
	cast_report.text = text

func tick(delta: float) -> void:
	hint_time = maxf(0, hint_time - delta)
	if hint_time <= 0:
		message.text = "Seguí las luces: claro de práctica → santuario."
