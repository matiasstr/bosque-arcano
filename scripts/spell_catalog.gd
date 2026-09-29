extends RefCounted
const SPELLS := [
	{"name": "AGUJA DE LUZ", "gesture": "Línea hacia abajo ↓", "color": Color("83eddf"), "speed": 34.0, "cooldown": 0.28, "damage_min": 18.0, "damage_max": 36.0, "cost_min": 10.0, "cost_max": 16.0, "crater_radius": 0.0, "crater_depth": 0.0},
	{"name": "BRASA RÚNICA", "gesture": "V: abajo-derecha, arriba-derecha", "color": Color("ffb966"), "speed": 22.0, "cooldown": 0.55, "damage_min": 26.0, "damage_max": 52.0, "cost_min": 16.0, "cost_max": 24.0, "crater_radius": 2.2, "crater_depth": 0.6}
]

static func stats(spell: int, quality: float) -> Dictionary:
	var source: Dictionary = SPELLS[clampi(spell, 0, SPELLS.size() - 1)]
	var mastery := clampf((quality - 0.55) / 0.45, 0, 1)
	return {"damage": snappedf(lerpf(source.damage_min, source.damage_max, mastery), 0.01),
		"cost": snappedf(lerpf(source.cost_max, source.cost_min, mastery), 0.01), "speed": source.speed,
		"cooldown": source.cooldown, "color": source.color}
