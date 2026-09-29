extends Control
const Math = preload("res://scripts/gesture_math.gd")
const Book = preload("res://scripts/spell_catalog.gd")
var caster

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	position = Vector2(944, 174)
	size = Vector2(308, 306)

func _draw() -> void:
	if caster == null:
		return
	var font := ThemeDB.fallback_font
	var color: Color = Book.SPELLS[caster.selected].color
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var loaded: bool = not caster.prepared.is_empty()
	draw_string(font, Vector2(18, 29), "TRAZÁ CON CTRL" if caster.active else "HECHIZO PREPARADO" if loaded else "GUÍA DEL HECHIZO", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	draw_string(font, Vector2(18, 53), "Soltá para cargar · Der. cancela" if caster.active else "Izq. lanzar · Der. descartar" if loaded else "1 Aguja ↓   /   2 Brasa V", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9dfd2"))
	var origin := Vector2(76, 105)
	var guide := Math.pattern(caster.selected)
	var transformed := PackedVector2Array()
	for p in guide:
		transformed.append(origin + p)
	draw_polyline(transformed, Color(color, 0.35), 12, true)
	draw_polyline(transformed, Color(color, 0.8), 2, true)
	draw_circle(origin, 6, color)
	draw_string(font, origin + Vector2(-22, -16), "INICIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	var end: Vector2 = transformed[-1]
	var direction: Vector2 = (end - transformed[-2]).normalized()
	draw_line(end, end - direction.rotated(0.55) * 14, color, 2, true)
	draw_line(end, end - direction.rotated(-0.55) * 14, color, 2, true)
	if caster.active and caster.points.size() > 1:
		var trace := PackedVector2Array()
		for point in caster.points:
			trace.append(origin + point)
		draw_polyline(trace, Color("ffffff"), 3, true)
		draw_circle(trace[-1], 4, Color.WHITE)
	var hint := "WASD sigue activo · cámara fija" if caster.active else "Podés moverte y volver a apuntar" if loaded else "Respetá forma y dirección"
	draw_string(font, Vector2(18, 263), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c5cfc1"))
	draw_string(font, Vector2(18, 285), "%.2f s" % caster.elapsed if caster.active else "%d%% precisión" % roundi(caster.prepared.quality * 100) if loaded else "El tamaño del gesto puede variar", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.04, 0.84 if caster.active else 0.63)
	style.border_color = Color(0.5, 0.7, 0.55, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _process(_delta: float) -> void:
	if caster != null:
		queue_redraw()
