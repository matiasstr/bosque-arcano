extends StaticBody3D
## First destruction layer: authored props, independent of terrain excavation.
signal destroyed(prop_id: String, kind: String)
var prop_id := ""
var kind := "Objeto"
var health := 90.0
var broken := false

func take_damage(amount: float) -> void:
	if broken or not is_finite(amount) or amount <= 0:
		return
	health = snappedf(maxf(0, health - amount), 0.01)
	if health <= 0:
		broken = true
		visible = false
		set_deferred("collision_layer", 0)
		destroyed.emit(prop_id, kind)
		queue_free()
