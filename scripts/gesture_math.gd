extends RefCounted
## Ordered, arc-length comparison. Translation/size invariant, NOT rotation invariant.
const VERSION := 1
const ACCEPT := 0.55
const SAMPLES := 32

static func pattern(spell: int) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(0, 120)]) if spell == 0 else PackedVector2Array([Vector2.ZERO, Vector2(65, 100), Vector2(130, 0)])

static func length_of(points: PackedVector2Array) -> float:
	var distance := 0.0
	for i in range(1, points.size()):
		distance += points[i - 1].distance_to(points[i])
	return distance

static func resample(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var total := length_of(points)
	if total < 0.001:
		return result
	var segment := 1
	var covered := 0.0
	for i in range(SAMPLES):
		var at := total * i / float(SAMPLES - 1)
		while segment < points.size() - 1 and covered + points[segment - 1].distance_to(points[segment]) < at:
			covered += points[segment - 1].distance_to(points[segment])
			segment += 1
		var span := points[segment - 1].distance_to(points[segment])
		var p := points[segment - 1].lerp(points[segment], clampf((at - covered) / maxf(span, 0.0001), 0, 1))
		result.append((p - points[0]) / total)
	return result

static func evaluate(points: PackedVector2Array, spell: int) -> Dictionary:
	var total := length_of(points)
	var minimum := 45.0 if spell == 0 else 75.0
	if points.size() < 2 or total < minimum:
		return {"valid": false, "quality": 0.0, "reason": "Trazo demasiado corto"}
	if total > 1600 or points.size() > 2048:
		return {"valid": false, "quality": 0.0, "reason": "Trazo demasiado largo"}
	var actual := resample(points)
	var expected := resample(pattern(spell))
	var error := 0.0
	for i in range(SAMPLES):
		error += actual[i].distance_to(expected[i])
	error = error / SAMPLES * 0.8 + actual[-1].distance_to(expected[-1]) * 0.2
	var quality := clampf(1.0 - error * 4.0, 0, 1)
	return {"valid": quality >= ACCEPT, "quality": quality, "reason": "" if quality >= ACCEPT else "Seguí la forma y el sentido de la guía"}
