class_name BoardView
extends Node3D
## Maquette grise du plateau : une case = 1 m. Le sol est en damier comme sur le plateau.

const TABLE_HEIGHT := 0.75
const WALL_HEIGHT := 1.2

const COLORS := {
	"floor_a": Color("7fc4c9"), "floor_b": Color("b7e0dc"),
	"kitchen_a": Color("e8e1a8"), "kitchen_b": Color("c9d6a2"),
	"wall": Color("f2c84b"), "table": Color("f3b6c8"), "door": Color("8a5a3c"),
	"tap": Color("9aa5ad"), "tub": Color("c0c8cf"), "dish_tub": Color("8fb6c9"),
}

var board: Board


func build(p_board: Board) -> void:
	board = p_board
	for child in get_children():
		child.queue_free()
	var boxes := {}  # couleur -> liste de Transform3D
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			var t := board.terrain(c)
			var checker := (x + y) % 2 == 0
			match t:
				Board.Terrain.FLOOR:
					_add(boxes, "floor_a" if checker else "floor_b", c, 0.05, 0.0)
				Board.Terrain.KITCHEN:
					_add(boxes, "kitchen_a" if checker else "kitchen_b", c, 0.05, 0.0)
				Board.Terrain.DOOR:
					_add(boxes, "door", c, 0.05, 0.0)
				Board.Terrain.TABLE:
					_add(boxes, "floor_a" if checker else "floor_b", c, 0.05, 0.0)
					_add(boxes, "table", c, TABLE_HEIGHT, 0.0, 0.98)
				Board.Terrain.WALL:
					_add(boxes, "wall", c, WALL_HEIGHT, 0.0)
				Board.Terrain.TAP:
					_add(boxes, "tap", c, WALL_HEIGHT, 0.0)
				Board.Terrain.TUB:
					_add(boxes, "tub", c, 0.9, 0.0)
				Board.Terrain.DISH_TUB:
					_add(boxes, "dish_tub", c, 0.9, 0.0)
	for key in boxes.keys():
		_emit_multimesh(COLORS[key], boxes[key])


static func cell_to_world(c: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(c.x, height, c.y)


func _add(boxes: Dictionary, key: String, c: Vector2i, h: float, base: float, size: float = 1.0) -> void:
	var t := Transform3D(Basis().scaled(Vector3(size, h, size)), cell_to_world(c, base + h / 2.0))
	if not boxes.has(key):
		boxes[key] = []
	boxes[key].append(t)


func _emit_multimesh(color: Color, transforms: Array) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
