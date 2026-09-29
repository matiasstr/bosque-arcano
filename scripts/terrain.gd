extends Node3D
## Materializes description.terrain: one mesh and one HeightMapShape3D per sector.
## Every sector reads the same global grid, so shared borders get identical vertices and normals.
var sectors: Array[StaticBody3D] = []

func build(data: Dictionary, material: Material) -> void:
	var samples: int = data.samples
	var heights := PackedFloat32Array()
	heights.resize(samples * samples)
	for k in range(samples * samples):
		heights[k] = data.heights_mm[k] * 0.001
	for sz in range(data.sectors):
		for sx in range(data.sectors):
			sectors.append(_sector(data, heights, sx, sz, material))

func _sector(data: Dictionary, heights: PackedFloat32Array, sx: int, sz: int, material: Material) -> StaticBody3D:
	var samples: int = data.samples
	var cells: int = data.sector_cells
	var cell: float = data.cell
	var origin: float = data.origin
	var side := cells + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var collision := PackedFloat32Array()
	for j in range(side):
		for i in range(side):
			var gi := sx * cells + i
			var gj := sz * cells + j
			var h := heights[gi + gj * samples]
			vertices.append(Vector3(origin + gi * cell, h, origin + gj * cell))
			var x0 := maxi(gi - 1, 0)
			var x1 := mini(gi + 1, samples - 1)
			var z0 := maxi(gj - 1, 0)
			var z1 := mini(gj + 1, samples - 1)
			var slope_x := (heights[x1 + gj * samples] - heights[x0 + gj * samples]) / ((x1 - x0) * cell)
			var slope_z := (heights[gi + z1 * samples] - heights[gi + z0 * samples]) / ((z1 - z0) * cell)
			normals.append(Vector3(-slope_x, 1, -slope_z).normalized())
			# The collision node is scaled uniformly by the cell size, so heights are divided by it.
			collision.append(h / cell)
	var indices := PackedInt32Array()
	for j in range(cells):
		for i in range(cells):
			var a := i + j * side
			# Same split as HeightMapShape3D: (x,z)(x+1,z)(x,z+1) and (x+1,z)(x+1,z+1)(x,z+1).
			indices.append_array([a, a + 1, a + side, a + 1, a + side + 1, a + side])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := StaticBody3D.new()
	body.name = "Sector_%d_%d" % [sx, sz]
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = collision
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.scale = Vector3.ONE * cell
	holder.position = Vector3(origin + (sx + 0.5) * cells * cell, 0, origin + (sz + 0.5) * cells * cell)
	body.add_child(holder)
	return body
