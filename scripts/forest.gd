extends Node3D
signal prop_destroyed(kind: String)
const V = preload("res://scripts/visuals.gd")
const Generator = preload("res://scripts/world_generator.gd")
const Assets = preload("res://scripts/forest_assets.gd")
const Destructible = preload("res://scripts/destructible_prop.gd")
var description: Dictionary
var destroyed_props: Dictionary = {}

func build(data: Dictionary) -> void:
	description = data
	Assets.prepare()
	var ground := V.box(self, Vector3(0, -0.4, 0), Vector3(64, 0.8, 64), Color("354b35"), true)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/ground.gdshader")
	var route := PackedVector2Array()
	for pair in data.path:
		route.append(Vector2(pair[0], pair[1]))
	mat.set_shader_parameter("route", route)
	ground.material_override = mat
	for index in range(data.trees.size()):
		var tree := Assets.tree(self, data.trees[index], index)
		tree.destroyed.connect(_on_prop_destroyed)
	for index in range(data.rocks.size()):
		var rock: Dictionary = data.rocks[index]
		var body := Destructible.new()
		body.prop_id = "rock:%d" % index
		body.kind = "Roca"
		body.health = 60
		body.collision_layer = 1
		body.position = Vector3(rock.x, rock.size * 0.35, rock.z)
		add_child(body)
		body.destroyed.connect(_on_prop_destroyed)
		var node := V.sphere(body, Vector3.ZERO, rock.size, Color("697970"))
		node.scale = Vector3(1, 0.72, 0.85)
		node.material_override = Assets.stone
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in vertices:
			points.append(p * node.scale)
		shape.points = points
		collision.shape = shape
		body.add_child(collision)
	_boundaries()
	_landmarks()
	Assets.undergrowth(self, data)

func _on_prop_destroyed(prop_id: String, kind: String) -> void:
	destroyed_props[prop_id] = true
	prop_destroyed.emit(kind)

func _boundaries() -> void:
	# Visible escarpment doubles as physical boundary; no invisible walls.
	for side in [-1.0, 1.0]:
		V.box(self, Vector3(side * 32, 2, 0), Vector3(1.2, 4, 65), Color("52665a"), true)
		V.box(self, Vector3(0, 2, side * 32), Vector3(65, 4, 1.2), Color("52665a"), true)
		for k in range(-30, 31, 6):
			for p in [Vector3(side * 33, 2, k), Vector3(k, 2, side * 33)]:
				var rock := V.sphere(self, p, 4, Color("52665a"))
				rock.scale = Vector3(1, 1.8 + sin(k) * 0.3, 1)
				rock.material_override = Assets.stone

func _landmarks() -> void:
	V.label(self, "CLARO DE PRÁCTICA", Vector3(-9, 3.5, 2))
	V.label(self, "SANTUARIO DEL BOSQUE", Vector3(10, 4.4, -15))
	V.cylinder(self, Vector3(10, 0.03, -14), 2.4, 2.4, 0.06, Color("6e8279"))
	for offset in [-2.3, 2.3]:
		V.box(self, Vector3(10 + offset, 1.7, -15), Vector3(0.6, 3.4, 0.8), Color("879888"), true)
	V.box(self, Vector3(10, 3.5, -15), Vector3(5.3, 0.5, 0.8), Color("879888"), true)
	var crystal := V.sphere(self, Vector3(10, 2.1, -14), 0.65, Color("68dfbb"), true)
	crystal.scale = Vector3(0.65, 1.8, 0.65)
	for i in range(8):
		var angle := i * TAU / 8
		var pos := Vector3(10 + cos(angle) * 4.6, 0.18, -12 + sin(angle) * 4.6)
		V.cylinder(self, pos, 0.16, 0.16, 0.3, Color("8de7be"), true)
	# Route markers remain fixed and do not claim to be collectable yet.
	for pair in description.path:
		var p := Vector3(pair[0] + 1.9, 0.4, pair[1])
		V.cylinder(self, p, 0.16, 0.12, 0.8, Color("665744"))
		V.sphere(self, p + Vector3.UP * 0.5, 0.16, Color("f1cf7a"), true)
