extends CharacterBody3D
## Port of FPS movement. No arena, spell database, HUD or research dependencies.
signal fell_outside
const V = preload("res://scripts/visuals.gd")
var controlled := false
var sensitivity := 0.09
var yaw := 0.0
var pitch := 0.0
var crouched := false
var camera: Camera3D
var body_collision: CollisionShape3D
var focus: Node3D
var kick := 0.0
var aim_locked := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body_collision.shape = capsule
	body_collision.position.y = 0.9
	add_child(body_collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 85
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	focus = Node3D.new()
	camera.add_child(focus)
	V.cylinder(focus, Vector3(0.32, -0.5, -0.55), 0.035, 0.04, 0.8, Color("735740"))
	var gem := V.sphere(focus, Vector3(0.32, -0.09, -0.55), 0.12, Color("66e9dc"), true)
	gem.scale = Vector3(0.45, 1.1, 0.45)

func _unhandled_input(event: InputEvent) -> void:
	if controlled and not aim_locked and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.screen_relative.x * sensitivity
		pitch = clampf(pitch - event.screen_relative.y * sensitivity, -85, 85)
		update_camera()

func _physics_process(delta: float) -> void:
	if not controlled:
		return
	step_movement(Input.get_vector("left", "right", "forward", "back"), Input.is_action_pressed("sprint"), Input.is_action_pressed("crouch"), Input.is_action_just_pressed("jump"), delta)
	if not aim_locked:
		kick = move_toward(kick, 0, delta * 5)
	focus.position.z = kick * 0.08
	update_camera()
	if position.y < -8:
		fell_outside.emit()

func step_movement(move: Vector2, sprint: bool, crouch: bool, jump: bool, delta: float) -> void:
	var next_crouch := crouch and is_on_floor()
	if crouched and not next_crouch:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.3
		shape.height = 1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.91)
		query.collision_mask = 1
		query.margin = 0.001
		next_crouch = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	if next_crouch != crouched:
		crouched = next_crouch
		body_collision.shape.height = 1.1 if crouched else 1.8
		body_collision.position.y = 0.55 if crouched else 0.9
	var speed := 2.0 if crouched else 6.0 if sprint else 4.3
	var wish := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(move.x, 0, move.y)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var acceleration := 30.0 if move.length() > 0.01 else 24.0
	if horizontal.dot(wish) < 0:
		acceleration = 65.0
	if not is_on_floor():
		acceleration = 7.0
	horizontal = horizontal.move_toward(wish * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif jump and not crouched:
		velocity.y = 6.3
	move_and_slide()
	camera.position.y = move_toward(camera.position.y, 1.0 if crouched else 1.62, delta * 6)

func update_camera() -> void:
	rotation.y = deg_to_rad(yaw)
	camera.rotation.x = deg_to_rad(pitch)

func reset_at(spawn: Vector3) -> void:
	position = spawn
	velocity = Vector3.ZERO
	yaw = 0
	pitch = 0
	kick = 0
	aim_locked = false
	crouched = false
	body_collision.shape.height = 1.8
	body_collision.position.y = 0.9
	camera.position.y = 1.62
	update_camera()
