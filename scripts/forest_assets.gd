extends RefCounted
## Original procedural mesh library. Shared meshes/materials, no external art downloads.
const V = preload("res://scripts/visuals.gd")
const Destructible = preload("res://scripts/destructible_prop.gd")
const Generator = preload("res://scripts/world_generator.gd")
static var trunks: Array[ArrayMesh] = []
static var crowns: Array[ArrayMesh] = []
static var grass: ArrayMesh
static var fern: ArrayMesh
static var bark: ShaderMaterial
static var leaves: ShaderMaterial
static var stone: ShaderMaterial

static func prepare() -> void:
	if not trunks.is_empty():
		return
	bark = ShaderMaterial.new()
	bark.shader = preload("res://assets/shaders/bark.gdshader")
	stone = bark.duplicate()
	stone.set_shader_parameter("stone", true)
	leaves = ShaderMaterial.new()
	leaves.shader = preload("res://assets/shaders/foliage.gdshader")
	for variant in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 912 + variant * 71
		var wood := SurfaceTool.new()
		wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		_branch(wood, Vector3.ZERO, Vector3(0.05, 8, 0.06), 0.35, 0.12)
		for i in range(6):
			var angle := i * TAU / 6 + variant
			_branch(wood, Vector3(0, 0.15, 0), Vector3(cos(angle) * 0.7, 0.015, sin(angle) * 0.7), 0.12, 0.02)
		var canopy := SurfaceTool.new()
		canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
		for limb in range(5):
			var angle := limb * TAU / 5 + variant * 0.7
			var start := Vector3(0, 5.3 + limb * 0.35, 0)
			var center := Vector3(cos(angle) * 1.9, 7.6 + rng.randf_range(-0.8, 1.2), sin(angle) * 1.9)
			_branch(wood, start, center, 0.14, 0.035)
			for leaf in range(150):
				var offset := Vector3(rng.randf_range(-1.7, 1.7), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.7, 1.7))
				if Vector2(offset.x, offset.z).length() > 1.7:
					continue
				var length := rng.randf_range(0.18, 0.4)
				var direction := Vector3(cos(rng.randf() * TAU), rng.randf_range(-0.3, 0.3), sin(rng.randf() * TAU)).normalized()
				_leaf(canopy, center + offset, direction * length, length * 0.40, Color("274321").lerp(Color("5b7732"), rng.randf()))
		wood.generate_normals()
		trunks.append(wood.commit())
		canopy.generate_normals()
		crowns.append(canopy.commit())
	var blades := SurfaceTool.new()
	blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(9):
		var a := i * 2.4
		var base := Vector3(cos(a) * 0.09, 0, sin(a) * 0.09)
		_leaf(blades, base, Vector3(cos(a) * 0.13, 0.23 + (i % 4) * 0.08, sin(a) * 0.13), 0.021, Color("617744").darkened(i * 0.035))
	blades.generate_normals()
	grass = blades.commit()
	var fronds := SurfaceTool.new()
	fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(7):
		var a := i * TAU / 7
		var axis := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		for j in range(1, 11):
			var t := j / 11.0
			var center := axis * t * 0.7 + Vector3.UP * sin(t * PI * 0.75) * 0.48
			var width := sin(t * PI) * 0.22
			_leaf(fronds, center, side * width + axis * 0.11, 0.028, Color("487340"))
			_leaf(fronds, center, -side * width + axis * 0.11, 0.028, Color("527c41"))
	fronds.generate_normals()
	fern = fronds.commit()

static func _branch(surface: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var axis := a.direction_to(b)
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.1:
		right = Vector3.RIGHT
	var side := axis.cross(right).normalized()
	for i in range(9):
		var u := (right * cos(i * TAU / 9) + side * sin(i * TAU / 9))
		var v := (right * cos((i + 1) * TAU / 9) + side * sin((i + 1) * TAU / 9))
		for p in [a + u * r0, a + v * r0, b + u * r1, b + u * r1, a + v * r0, b + v * r1]:
			surface.add_vertex(p)

static func _leaf(surface: SurfaceTool, base: Vector3, axis: Vector3, width: float, color: Color) -> void:
	var side := axis.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var mid := base + axis * 0.48
	for p in [base, mid - side * width, mid + Vector3.UP * width * 0.25, mid + Vector3.UP * width * 0.25, mid - side * width, base + axis, base + axis, mid + side * width, mid + Vector3.UP * width * 0.25, mid + Vector3.UP * width * 0.25, mid + side * width, base]:
		surface.set_color(color)
		surface.set_uv(Vector2(0.5, base.distance_to(p) / maxf(axis.length(), 0.01)))
		surface.add_vertex(p)

static func tree(parent: Node3D, data: Dictionary, index: int) -> StaticBody3D:
	prepare()
	var variant := int(absf(data.x * 17 + data.z * 11)) % 3
	var height: float = data.height * 1.35
	var scale := Vector3(data.radius / 0.35, height / 8, data.radius / 0.35)
	var collider := Destructible.new()
	collider.prop_id = "tree:%d" % index
	collider.kind = "Árbol"
	collider.collision_layer = 1
	parent.add_child(collider)
	collider.position = Vector3(data.x, 0, data.z)
	for entry in [[trunks[variant], bark], [crowns[variant], leaves]]:
		var node := MeshInstance3D.new()
		node.mesh = entry[0]
		node.material_override = entry[1]
		collider.add_child(node)
		node.scale = scale
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = data.radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height * 0.5
	collider.add_child(shape)
	return collider

## Returns one record per MultiMesh ({node, transforms}) so the ground can be followed later.
static func undergrowth(parent: Node3D, data: Dictionary) -> Array:
	prepare()
	var records: Array = []
	for batch in undergrowth_batches(data).values():
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = fern if batch.fern else grass
		mesh.instance_count = batch.transforms.size()
		for i in range(mesh.instance_count):
			mesh.set_instance_transform(i, batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mesh
		node.material_override = leaves
		node.visibility_range_end = 36 if batch.fern else 27
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		records.append({"node": node, "transforms": batch.transforms})
	return records

## Placement data only, so it can be checked without a renderer.
static func undergrowth_batches(data: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.seed) ^ 0x45391
	var batches := {}
	# Richest detail in the first twenty-metre stretch; sparse elsewhere.
	for i in range(20000):
		var p := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		var distance := 100.0
		for j in range(data.path.size() - 1):
			var a := Vector2(data.path[j][0], data.path[j][1])
			var b := Vector2(data.path[j + 1][0], data.path[j + 1][1])
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0, 1)
			distance = minf(distance, p.distance_to(a.lerp(b, t)))
		if distance < 1.85 or p.distance_to(Vector2(-9, 5)) < 4.9 or p.distance_to(Vector2(10, -12)) < 4.9:
			continue
		var detailed := Rect2(-16, 4, 24, 23).has_point(p)
		if not detailed and rng.randf() > 0.32:
			continue
		var is_fern := detailed and rng.randf() < 0.08
		var key := "%d:%d:%d" % [floori(p.x / 10), floori(p.y / 10), int(is_fern)]
		if not batches.has(key):
			batches[key] = {"fern": is_fern, "transforms": []}
		var size := rng.randf_range(0.65, 1.25)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
		batches[key].transforms.append(Transform3D(basis, Vector3(p.x, Generator.height_at(data, p.x, p.y) + 0.015, p.y)))
	return batches
