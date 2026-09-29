extends RefCounted
## Geometry helpers ported from Duelo Arcano, extended for forest blockout art.
static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.65
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color, glow)
	parent.add_child(node)
	node.position = pos
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := mesh(parent, shape, pos, color)
	if solid:
		var collision := BoxShape3D.new()
		collision.size = size
		body(node, collision)
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, top: float, height: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 7
	return mesh(parent, shape, pos, color, glow)

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 8
	shape.rings = 4
	return mesh(parent, shape, pos, color, glow)

static func body(parent: Node3D, shape: Shape3D) -> StaticBody3D:
	var node := StaticBody3D.new()
	node.collision_layer = 1
	node.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	node.add_child(collision)
	parent.add_child(node)
	return node

static func label(parent: Node3D, text: String, pos: Vector3) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = 32
	node.pixel_size = 0.009
	node.modulate = Color("c8e1ce")
	node.outline_size = 5
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(node)
	node.position = pos
	return node
