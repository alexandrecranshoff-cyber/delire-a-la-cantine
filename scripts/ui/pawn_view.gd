class_name PawnView
extends Node3D
## Pion en carton debout (option C de la bible graphique) : dessin détouré à 5 vues, socle de la
## couleur de la bande, jauge de moral. Le carton se tourne vers la caméra et choisit sa vue
## selon la direction où regarde le personnage.

const SHADER := preload("res://shaders/pion.gdshader")
const SHADOW_SHADER := preload("res://shaders/pion_ombre.gdshader")
## Direction des ombres au sol (le soleil entre par les fenêtres, toujours du même côté).
const SHADOW_DIR := Vector3(0.94, 0.0, -0.34)
const LEAN := 0.22  # le carton penche un peu vers la caméra pour rester lisible vu de haut

var unit: Unit
var facing := Vector2(0, 1)       # direction regardée, sur le plateau (x, y)
var shown := true                 # visible pour le joueur (brouillard)

var _pivot := Node3D.new()        # tout ce qui fait face à la caméra
var _card := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _shadow_mat := ShaderMaterial.new()
var _shadow := MeshInstance3D.new()
var _base_mat := StandardMaterial3D.new()
var _ring := MeshInstance3D.new()
var _bar_back := MeshInstance3D.new()
var _bar_fill := MeshInstance3D.new()
var _bar_mat := StandardMaterial3D.new()
var _label := Label3D.new()
var _stains := Node3D.new()
var _height := 1.4
var _cam_angle := 45.0
var _look := {}
var _bob := 0.0


func setup(p_unit: Unit) -> void:
	unit = p_unit
	_look = GameAssets.look_for(unit)
	_height = _look["taille"]
	var margin: float = _look["marge"]
	var full_h := _height / (1.0 - 2.0 * margin)
	var quad := QuadMesh.new()
	quad.size = Vector2(full_h * float(_look["aspect"]), full_h)
	_material.shader = SHADER
	var family := "accessoires" if unit.kind == Unit.Kind.CART else "pions"
	_material.set_shader_parameter("atlas", GameAssets.texture(family, str(_look["image"]) + ".png"))
	_material.set_shader_parameter("frames", float(_look["vues"]))
	_material.set_shader_parameter("aspect", float(_look["aspect"]))
	_material.set_shader_parameter("border", 0.0 if unit.kind == Unit.Kind.CART else 0.016)
	quad.material = _material
	_card.mesh = quad
	_card.position.y = full_h / 2.0 - full_h * margin + 0.05
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ombre : la silhouette couchée au sol, à l'opposé du soleil.
	var shadow_len := full_h * 0.7
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(quad.size.x, shadow_len)
	_shadow_mat.shader = SHADOW_SHADER
	_shadow_mat.set_shader_parameter("atlas", GameAssets.texture(family, str(_look["image"]) + ".png"))
	_shadow_mat.set_shader_parameter("frames", float(_look["vues"]))
	shadow_quad.material = _shadow_mat
	_shadow.mesh = shadow_quad
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var along := SHADOW_DIR.normalized()
	var side := along.cross(Vector3.UP).normalized()
	# Le bas de l'image (les pieds) reste sous le pion, le haut part dans la direction de l'ombre.
	_shadow.transform = Transform3D(Basis(side, along, Vector3.UP), along * (shadow_len * (0.5 - margin)) + Vector3(0, 0.022, 0))
	add_child(_shadow)
	add_child(_pivot)
	var lean := Node3D.new()
	lean.rotation.x = -LEAN
	_pivot.add_child(lean)
	lean.add_child(_card)
	_stains.position = _card.position + Vector3(0, 0, 0.02)
	lean.add_child(_stains)

	if unit.kind != Unit.Kind.CART:
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.4
		cyl.bottom_radius = 0.42
		cyl.height = 0.07
		cyl.radial_segments = 20
		_base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyl.material = _base_mat
		base.mesh = cyl
		base.position.y = 0.035
		add_child(base)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.47
		rim_mesh.bottom_radius = 0.47
		rim_mesh.height = 0.05
		rim_mesh.radial_segments = 20
		var rim_mat := StandardMaterial3D.new()
		rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rim_mat.albedo_color = BD.INK
		rim_mesh.material = rim_mat
		rim.mesh = rim_mesh
		rim.position.y = 0.025
		add_child(rim)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	torus.rings = 24
	torus.ring_segments = 6
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = BD.YELLOW
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = ring_mat
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.25, 1)
	_ring.position.y = 0.06
	_ring.visible = false
	add_child(_ring)

	# Jauge de moral au-dessus de la tête.
	var back := QuadMesh.new()
	back.size = Vector2(0.78, 0.15)
	var back_mat := StandardMaterial3D.new()
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.albedo_color = BD.INK
	back_mat.no_depth_test = true
	back_mat.render_priority = 5
	back.material = back_mat
	_bar_back.mesh = back
	var fill := QuadMesh.new()
	fill.size = Vector2(0.7, 0.085)
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.no_depth_test = true
	_bar_mat.render_priority = 6
	fill.material = _bar_mat
	_bar_fill.mesh = fill
	_bar_back.position = Vector3(0, _height + 0.38, 0)
	_bar_fill.position = Vector3(0, _height + 0.38, 0.01)
	_bar_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_bar_back)
	_pivot.add_child(_bar_fill)

	_label.font = BD.title_font()
	_label.font_size = 64
	_label.outline_size = 20
	_label.pixel_size = 0.0075
	_label.no_depth_test = true
	_label.render_priority = 7
	_label.outline_render_priority = 6
	_label.outline_modulate = BD.INK
	_label.position = Vector3(0, _height + 0.68, 0)
	_label.visible = false
	_pivot.add_child(_label)
	refresh()


func has_gauge() -> bool:
	return unit.kind in [Unit.Kind.STUDENT, Unit.Kind.TEACHER, Unit.Kind.COOK] or unit.rallied or unit.status == Unit.Status.BERSERK


func refresh() -> void:
	var on_board := unit.is_on_board()
	visible = on_board and shown
	_shadow.visible = not unit.on_table and unit.status != Unit.Status.CAPTURED
	if not on_board:
		return
	var height := BoardView.TABLE_HEIGHT if unit.on_table else 0.0
	position = BoardView.cell_to_world(unit.pos, height)
	_pivot.scale = Vector3.ONE
	_pivot.rotation.z = 0.0
	var team_col := BD.team_color(unit.team if (unit.kind == Unit.Kind.STUDENT or unit.rallied) else -1)
	if unit.kind == Unit.Kind.TEACHER:
		team_col = Color("8d8d8d")
	elif unit.kind == Unit.Kind.COOK:
		team_col = Color("ffffff")
	_material.set_shader_parameter("border_color", team_col)
	_base_mat.albedo_color = team_col
	var tint := Color.WHITE
	var amount := 0.0
	match unit.status:
		Unit.Status.SATURATED:
			tint = Color("8fd14f")
			amount = 0.7
		Unit.Status.BERSERK:
			tint = Color("ff3d6e")
			amount = 0.55
		Unit.Status.FLEEING:
			tint = Color("c8c8d8")
			amount = 0.35
		Unit.Status.CAPTURED:
			_pivot.scale = Vector3.ONE * 0.8
			_pivot.rotation.z = 0.5
			position += Vector3(0.45, 0.0, 0.2)
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("tint_amount", amount)
	var spent := unit.is_controllable() and unit.kind != Unit.Kind.CART and unit.ap <= 0 and unit.has_shot
	_material.set_shader_parameter("dim", 0.0)
	_base_mat.albedo_color = team_col.darkened(0.45) if spent else team_col
	var gauge := has_gauge()
	_bar_back.visible = gauge
	_bar_fill.visible = gauge
	if gauge:
		var ratio := clampf(float(unit.moral) / maxf(1.0, float(unit.max_moral)), 0.0, 1.0)
		_bar_fill.scale.x = maxf(0.001, ratio)
		_bar_fill.position.x = -0.35 * (1.0 - ratio)
		_bar_mat.albedo_color = Color("5fd34a").lerp(Color("ffcf33"), clampf((1.0 - ratio) * 2.0, 0, 1)).lerp(Color("e8433a"), clampf((0.5 - ratio) * 2.0, 0, 1))
	_update_view()


func set_selected(on: bool) -> void:
	_ring.visible = on
	_label.visible = on
	_label.text = unit.name
	_label.modulate = BD.YELLOW


## Affiche le nom au survol.
func set_hover(on: bool, text: String = "") -> void:
	if _ring.visible:
		return
	_label.visible = on
	_label.text = text if text != "" else unit.name
	_label.modulate = Color.WHITE


func look_at_cell(c: Vector2i) -> void:
	var d := Vector2(c - unit.pos)
	if d != Vector2.ZERO:
		set_facing(d)


func set_facing(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	facing = d.normalized()
	_update_view()


## Les cartons se tournent vers la caméra (autour de la verticale seulement).
func face_camera(angle_deg: float) -> void:
	_cam_angle = angle_deg
	_pivot.rotation.y = deg_to_rad(angle_deg)
	_update_view()


## Choisit la vue : face, 3/4 face, profil, 3/4 dos ou dos, retournée si le personnage regarde à gauche.
func _update_view() -> void:
	if int(_look.get("vues", 1)) < 5:
		return
	var a := deg_to_rad(_cam_angle)
	var toward := Vector2(sin(a), cos(a))
	var right := Vector2(cos(a), -sin(a))
	var ang := atan2(facing.dot(right), facing.dot(toward))
	var index := clampi(roundi(absf(ang) / (PI / 4.0)), 0, 4)
	var flip := 1.0 if ang < 0.0 and index != 0 and index != 4 else 0.0
	_material.set_shader_parameter("frame", float(index))
	_material.set_shader_parameter("flip", flip)
	_shadow_mat.set_shader_parameter("frame", float(index))
	_shadow_mat.set_shader_parameter("flip", flip)


func _process(delta: float) -> void:
	if _ring.visible:
		_bob += delta
		var s := 1.0 + 0.08 * sin(_bob * 5.0)
		_ring.scale = Vector3(s, 0.25, s)


## Éclair blanc quand le pion est touché, avec un petit sursaut.
func hit_flash() -> void:
	var tw := create_tween()
	tw.tween_method(func(v): _material.set_shader_parameter("flash", v), 0.9, 0.0, 0.35)
	var tw2 := create_tween()
	tw2.tween_property(_pivot, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tw2.tween_property(_pivot, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Petit saut sur place (lancer, joie, sursaut).
func hop(height: float = 0.35, time: float = 0.22) -> void:
	var tw := create_tween()
	tw.tween_property(_pivot, "position:y", height, time * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_pivot, "position:y", 0.0, time * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## La tache reste collée au personnage jusqu'à la fin du service.
func add_stain(tex: Texture2D, color: Color = Color.WHITE) -> void:
	if tex == null or _stains.get_child_count() >= 5:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = (_height * 0.3) / float(tex.get_height())
	s.modulate = color
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = Vector3(randf_range(-0.14, 0.14), randf_range(-_height * 0.22, _height * 0.2), 0.0)
	s.rotation.z = randf_range(-PI, PI)
	s.render_priority = 2
	_stains.add_child(s)


func head_position() -> Vector3:
	return global_position + Vector3(0, _height + 0.2, 0)


func body_position() -> Vector3:
	return global_position + Vector3(0, _height * 0.6, 0)
