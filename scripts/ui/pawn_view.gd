class_name PawnView
extends Node3D
## Pion provisoire en carton debout (option C de la bible graphique) : une plaque colorée et un nom.

const TEAM_COLORS: Array[Color] = [Color("e8433a"), Color("3a7be8"), Color("3ab85a"), Color("f0a020")]
const OTHER_COLORS := {
	Unit.Kind.TEACHER: Color("6b6b6b"), Unit.Kind.COOK: Color("ffffff"),
	Unit.Kind.NEUTRAL: Color("c9b8a0"), Unit.Kind.CART: Color("a0a8b0"),
}
## Hauteurs en mètres, d'après la planche d'échelle (élèves ~1,30-1,58 m, adultes ~1,85-1,90 m).
const HEIGHTS := {
	Unit.Kind.STUDENT: 1.45, Unit.Kind.TEACHER: 1.85, Unit.Kind.COOK: 1.9,
	Unit.Kind.NEUTRAL: 1.4, Unit.Kind.CART: 0.9,
}

var unit: Unit
var _card: MeshInstance3D
var _label: Label3D
var _material := StandardMaterial3D.new()
var _ring: MeshInstance3D


func setup(p_unit: Unit) -> void:
	unit = p_unit
	var h: float = HEIGHTS[unit.kind]
	_card = MeshInstance3D.new()
	var box := BoxMesh.new()
	if unit.kind == Unit.Kind.CART:
		box.size = Vector3(0.9, h, 0.9)
	else:
		box.size = Vector3(0.7, h, 0.08)
	box.material = _material
	_card.mesh = box
	_card.position.y = h / 2.0
	add_child(_card)

	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 0.06
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("2b2b2b")
	cyl.material = base_mat
	base.mesh = cyl
	add_child(base)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("fff35c")
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = ring_mat
	_ring.mesh = torus
	_ring.visible = false
	add_child(_ring)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.008
	_label.position.y = h + 0.35
	add_child(_label)
	refresh()


func base_color() -> Color:
	if unit.kind == Unit.Kind.STUDENT or (unit.kind == Unit.Kind.NEUTRAL and unit.rallied):
		return TEAM_COLORS[unit.team % TEAM_COLORS.size()]
	return OTHER_COLORS[unit.kind]


func refresh() -> void:
	visible = unit.is_on_board() and unit.status != Unit.Status.CAPTURED
	var height := BoardView.TABLE_HEIGHT if unit.on_table else 0.0
	position = BoardView.cell_to_world(unit.pos, height)
	var col := base_color()
	match unit.status:
		Unit.Status.SATURATED: col = col.lerp(Color("7ac143"), 0.6)
		Unit.Status.BERSERK: col = Color("b0207a")
		Unit.Status.FLEEING: col = col.darkened(0.4)
	_material.albedo_color = col
	var text := unit.name
	if unit.kind in [Unit.Kind.STUDENT, Unit.Kind.TEACHER, Unit.Kind.COOK] or unit.rallied:
		text += "\n%d" % unit.moral
	if unit.kind == Unit.Kind.NEUTRAL and not unit.rallied:
		text = ""
	_label.text = text


func set_selected(on: bool) -> void:
	_ring.visible = on


## Les pions en carton se tournent vers la caméra (rotation autour de la verticale seulement).
func face_camera(angle_deg: float) -> void:
	_card.rotation.y = deg_to_rad(angle_deg)
