extends Area3D
signal damaged(amount: float, destroyed: bool)
const V = preload("res://scripts/visuals.gd")
var health := 90.0
var respawn_left := 0.0
var title: Label3D
var active := true

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	shape.position.y = 1.4
	add_child(shape)
	V.cylinder(self, Vector3(0, 0.35, 0), 0.4, 0.3, 0.7, Color("626f67"))
	V.sphere(self, Vector3(0, 1.4, 0), 0.55, Color("f0bd75"), true)
	title = V.label(self, "90 / 90", Vector3(0, 2.3, 0))
	title.font_size = 24

func take_damage(amount: float) -> void:
	if not active:
		return
	var applied := minf(health, maxf(0, amount))
	health = snappedf(maxf(0, health - applied), 0.01)
	title.text = "%d / 90" % int(health)
	if health <= 0:
		active = false
		visible = false
		set_deferred("collision_layer", 0)
		respawn_left = 3.0
	damaged.emit(applied, not active)

func tick(delta: float) -> void:
	if active:
		return
	respawn_left -= delta
	if respawn_left <= 0:
		health = 90
		active = true
		visible = true
		title.text = "90 / 90"
		set_deferred("collision_layer", 4)
