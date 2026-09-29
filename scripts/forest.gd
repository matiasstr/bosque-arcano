extends Node3D
signal prop_destroyed(kind: String)
const V = preload("res://scripts/visuals.gd")
const Generator = preload("res://scripts/world_generator.gd")
const Assets = preload("res://scripts/forest_assets.gd")
const Destructible = preload("res://scripts/destructible_prop.gd")
const Terrain = preload("res://scripts/terrain.gd")
const TerrainEdit = preload("res://scripts/terrain_edit.gd")
var description: Dictionary
var destroyed_props: Dictionary = {}
var terrain: Node3D
var sanctuary: Node3D
## Editable copy of the heights ({"terrain": ...}, same shape as the description for height_at).
## The description itself stays the unedited base.
var ground: Dictionary
## Craters applied in order; replaying them over the base rebuilds the same ground (future saving).
var terrain_edits: Array = []
var undergrowth: Array = []
var markers: Array = []

func build(data: Dictionary) -> void:
	description = data
	Assets.prepare()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/ground.gdshader")
	var route := PackedVector2Array()
	for pair in data.path:
		route.append(Vector2(pair[0], pair[1]))
	mat.set_shader_parameter("route", route)
	ground = {"terrain": data.terrain.duplicate()}
	ground.terrain.heights_mm = data.terrain.heights_mm.duplicate()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(ground.terrain, mat)
	for index in range(data.trees.size()):
		var entry: Dictionary = data.trees[index]
		var tree := Assets.tree(self, entry, index)
		# Roots reach twice the trunk radius: rest on the lowest ground they cover.
		tree.position.y = Generator.footprint_min(data, entry.x, entry.z, entry.radius * 2.0) - 0.05
		tree.destroyed.connect(_on_prop_destroyed)
	for index in range(data.rocks.size()):
		var rock: Dictionary = data.rocks[index]
		var body := Destructible.new()
		body.prop_id = "rock:%d" % index
		body.kind = "Roca"
		body.health = 60
		body.collision_layer = 1
		body.position = Vector3(rock.x, rock_center_y(data, rock), rock.z)
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
	undergrowth = Assets.undergrowth(self, data)

func _on_prop_destroyed(prop_id: String, kind: String) -> void:
	destroyed_props[prop_id] = true
	prop_destroyed.emit(kind)

## Rock ellipsoid (radii size, 0.72 size, 0.85 size): its underside stays below the ground at
## the center and at half and 80 % of its radius. On flat ground this is the old 0.35 × size.
static func rock_center_y(data: Dictionary, rock: Dictionary) -> float:
	var size: float = rock.size
	var center := INF
	for k in [0.0, 0.5, 0.8]:
		var ground := Generator.footprint_min(data, rock.x, rock.z, size * k, 0.85)
		center = minf(center, ground + 0.72 * size * sqrt(1.0 - k * k))
	return center - 0.082 * size

func _boundaries() -> void:
	# Visible escarpment doubles as physical boundary; no invisible walls.
	# Ten segments per side, each from below its lowest ground to 4 m above its highest.
	for side in [-1.0, 1.0]:
		for n in range(10):
			var a := -32.5 + n * 6.5
			var low := INF
			var high := -INF
			for step in range(14):
				for depth in [31.4, 32.0, 32.6]:
					for h in [Generator.height_at(description, side * depth, a + step * 0.5), Generator.height_at(description, a + step * 0.5, side * depth)]:
						low = minf(low, h)
						high = maxf(high, h)
			var height := high + 4.0 - (low - 1.0)
			var y := low - 1.0 + height * 0.5
			V.box(self, Vector3(side * 32, y, a + 3.25), Vector3(1.2, height, 6.5), Color("52665a"), true)
			V.box(self, Vector3(a + 3.25, y, side * 32), Vector3(6.5, height, 1.2), Color("52665a"), true)
		for k in range(-30, 31, 6):
			for p in [Vector3(side * 33, 2, k), Vector3(k, 2, side * 33)]:
				p.y += Generator.height_at(description, p.x, p.z)
				var rock := V.sphere(self, p, 4, Color("52665a"))
				rock.scale = Vector3(1, 1.8 + sin(k) * 0.3, 1)
				rock.material_override = Assets.stone

func _landmarks() -> void:
	V.label(self, "CLARO DE PRÁCTICA", Vector3(-9, Generator.height_at(description, -9, 2) + 3.5, 2))
	# The sanctuary clearing is levelled; every piece shares its height.
	sanctuary = Node3D.new()
	sanctuary.position.y = Generator.height_at(description, 10, -12)
	add_child(sanctuary)
	V.label(sanctuary, "SANTUARIO DEL BOSQUE", Vector3(10, 4.4, -15))
	V.cylinder(sanctuary, Vector3(10, 0.03, -14), 2.4, 2.4, 0.06, Color("6e8279"))
	for offset in [-2.3, 2.3]:
		V.box(sanctuary, Vector3(10 + offset, 1.7, -15), Vector3(0.6, 3.4, 0.8), Color("879888"), true)
	V.box(sanctuary, Vector3(10, 3.5, -15), Vector3(5.3, 0.5, 0.8), Color("879888"), true)
	var crystal := V.sphere(sanctuary, Vector3(10, 2.1, -14), 0.65, Color("68dfbb"), true)
	crystal.scale = Vector3(0.65, 1.8, 0.65)
	for i in range(8):
		var angle := i * TAU / 8
		var pos := Vector3(10 + cos(angle) * 4.6, 0.18, -12 + sin(angle) * 4.6)
		V.cylinder(sanctuary, pos, 0.16, 0.16, 0.3, Color("8de7be"), true)
	# Route markers remain fixed and do not claim to be collectable yet.
	for pair in description.path:
		var x: float = pair[0] + 1.9
		var z: float = pair[1]
		var p := Vector3(x, Generator.footprint_min(description, x, z, 0.16) + 0.35, z)
		markers.append([V.cylinder(self, p, 0.16, 0.12, 0.8, Color("665744")), V.sphere(self, p + Vector3.UP * 0.5, 0.16, Color("f1cf7a"), true)])

## Digs a crater, rebuilds only the touched sectors and lowers nearby objects onto the new
## ground. Returns false when the spot is protected or nothing changed.
func carve_crater(point: Vector3, radius: float, depth: float) -> bool:
	var edit := {"x": snappedf(point.x, 0.01), "z": snappedf(point.z, 0.01), "radius": radius, "depth": depth}
	var changed := TerrainEdit.carve(ground.terrain, description.terrain.heights_mm, edit.x, edit.z, radius, depth)
	if not changed.has_area():
		return false
	terrain_edits.append(edit)
	terrain.rebuild(changed)
	_settle_near(Vector2(edit.x, edit.z), radius + 2.5)
	return true

## Objects only ever move down: craters never raise the ground.
func _settle_near(center: Vector2, reach: float) -> void:
	for node in get_children():
		var id = node.get("prop_id")
		if id == null or Vector2(node.position.x, node.position.z).distance_to(center) > reach:
			continue
		var index := int(String(id).split(":")[1])
		if String(id).begins_with("tree:"):
			var entry: Dictionary = description.trees[index]
			node.position.y = minf(node.position.y, Generator.footprint_min(ground, entry.x, entry.z, entry.radius * 2.0) - 0.05)
		else:
			node.position.y = minf(node.position.y, rock_center_y(ground, description.rocks[index]))
	for pair in markers:
		var p: Vector3 = pair[0].position
		if Vector2(p.x, p.z).distance_to(center) <= reach:
			var y := minf(p.y, Generator.footprint_min(ground, p.x, p.z, 0.16) + 0.35)
			pair[0].position.y = y
			pair[1].position.y = y + 0.5
	for record in undergrowth:
		for i in range(record.transforms.size()):
			var transform: Transform3D = record.transforms[i]
			if Vector2(transform.origin.x, transform.origin.z).distance_to(center) <= reach:
				transform.origin.y = minf(transform.origin.y, Generator.height_at(ground, transform.origin.x, transform.origin.z) + 0.015)
				record.transforms[i] = transform
				record.node.multimesh.set_instance_transform(i, transform)
