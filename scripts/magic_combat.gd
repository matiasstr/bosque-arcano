extends Node3D
## Offensive spell prototype; no crafting/research coupling.
signal cast_launched
## Every impact point, so the world can react (craters) without combat knowing the terrain.
signal surface_hit(point: Vector3, collider: Object, spell: int)
const V = preload("res://scripts/visuals.gd")
const Book = preload("res://scripts/spell_catalog.gd")
var enabled := false
var mana := 100.0
var cooldown := 0.0
var since_cast := 10.0
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var last_cast: Dictionary = {}

func can_begin(spell: int) -> bool:
	# Preparation may overlap recovery. Only launching is gated by cooldown.
	return enabled and mana >= Book.SPELLS[spell].cost_min

func fire(origin: Vector3, direction: Vector3, spell: int = 0, quality: float = 0.85) -> bool:
	if spell < 0 or spell >= Book.SPELLS.size() or not is_finite(quality) or quality < 0.55:
		return false
	var stats := Book.stats(spell, quality)
	if not enabled or cooldown > 0 or mana + 0.0001 < stats.cost or not direction.is_finite() or direction.length_squared() < 0.001:
		return false
	mana = maxf(0, mana - stats.cost)
	cooldown = stats.cooldown
	since_cast = 0
	var mesh := V.sphere(self, origin, 0.075 if spell == 0 else 0.13, stats.color, true)
	projectiles.append({"node": mesh, "velocity": direction.normalized() * stats.speed, "life": 2.5, "damage": stats.damage, "color": stats.color, "trail": 0.0, "spell": spell})
	last_cast = {"spell": spell, "quality": quality, "damage": stats.damage, "cost": stats.cost, "origin": origin, "direction": direction.normalized()}
	cast_launched.emit()
	return true

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	cooldown = maxf(0, cooldown - delta)
	since_cast += delta
	if since_cast > 0.8:
		mana = minf(100, mana + 18 * delta)
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var start: Vector3 = shot.node.position
		var end: Vector3 = start + shot.velocity * delta
		var query := PhysicsRayQueryParameters3D.create(start, end, 5)
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		shot.life -= delta
		if not hit.is_empty() or shot.life <= 0:
			if not hit.is_empty():
				if hit.collider.has_method("take_damage"):
					hit.collider.take_damage(shot.damage)
				surface_hit.emit(hit.position, hit.collider, shot.spell)
				for n in range(6):
					var offset := Vector3(cos(n * TAU / 6), sin(n * TAU / 6), 0) * 0.1
					var spark := V.sphere(self, hit.position + offset, 0.08, shot.color, true)
					effects.append({"node": spark, "life": 0.22, "velocity": offset * 6})
			shot.node.queue_free()
			projectiles.remove_at(i)
		else:
			shot.node.position = end
			shot.trail += delta
			if shot.trail > 0.025:
				shot.trail = 0.0
				var tail := V.sphere(self, start, 0.045, shot.color, true)
				effects.append({"node": tail, "life": 0.13, "velocity": Vector3.ZERO})
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		effects[i].node.position += effects[i].velocity * delta
		effects[i].node.scale *= maxf(0.1, 1.0 - delta * 4)
		if effects[i].life <= 0:
			effects[i].node.queue_free()
			effects.remove_at(i)

func reset() -> void:
	for shot in projectiles:
		shot.node.queue_free()
	for effect in effects:
		effect.node.queue_free()
	projectiles.clear()
	effects.clear()
	mana = 100
	cooldown = 0
	since_cast = 10
