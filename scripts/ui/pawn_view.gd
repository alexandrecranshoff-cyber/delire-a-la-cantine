class_name PawnView
extends Node3D
## Pion d'un personnage : modèle 3D animé façon BD (contour à l'encre, ombrage en deux tons), posé
## sur un socle de la couleur de sa bande, avec sa jauge de moral. Si le modèle d'un personnage
## manque, on retombe sur le pion en carton à 5 vues (option C de la bible graphique).
## Les chariots sont des objets 3D étiquetés, toujours visibles.

const CARD_SHADER := preload("res://shaders/pion.gdshader")
const SHADOW_SHADER := preload("res://shaders/pion_ombre.gdshader")
const MODEL_SHADER := preload("res://shaders/personnage.gdshader")
const OUTLINE_SHADER := preload("res://shaders/contour.gdshader")
## Direction des ombres au sol (le soleil entre par les fenêtres, toujours du même côté).
const SHADOW_DIR := Vector3(0.94, 0.0, -0.34)
const LEAN := 0.22  # le carton penche un peu vers la caméra pour rester lisible vu de haut
## Angle à ajouter si un modèle ne regarde pas vers +Z (les nôtres sont remis de face avant le squelette).
const MODEL_YAW := 0.0
const OUTLINE_WIDTH := 0.014
const THROW_SPEED := 2.2
const THROW_RELEASE := 0.42   # fraction du geste où la main lâche le projectile

static var _blob: Texture2D

var unit: Unit
var facing := Vector2(0, 1)       # direction regardée, sur le plateau (x, y)
var shown := true                 # visible pour le joueur (brouillard)

var _lift := Node3D.new()         # tout ce qui saute et sursaute avec le personnage
var _pivot := Node3D.new()        # ce qui fait face à la caméra (carton, jauge, nom, taches)
var _body := Node3D.new()         # modèle 3D, tourné selon la direction regardée
var _card := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _outline := ShaderMaterial.new()
var _shadow_mat := ShaderMaterial.new()
var _shadow := MeshInstance3D.new()
var _base_mat := StandardMaterial3D.new()
var _ring := MeshInstance3D.new()
var _bar_back := MeshInstance3D.new()
var _bar_fill := MeshInstance3D.new()
var _bar_mat := StandardMaterial3D.new()
var _label := Label3D.new()
var _stains := Node3D.new()
var _anim: AnimationPlayer
var _is_model := false
var _height := 1.4
var _cam_angle := 45.0
var _look := {}
var _bob := 0.0
var _turn: Tween
var _action := 0                  # numéro de l'animation en cours, pour ne pas couper la suivante


func setup(p_unit: Unit) -> void:
	unit = p_unit
	_look = GameAssets.look_for(unit)
	_height = _look["taille"]
	add_child(_lift)
	_lift.add_child(_body)
	_lift.add_child(_pivot)
	var scene: PackedScene = null
	if unit.kind != Unit.Kind.CART:
		scene = GameAssets.model(str(_look["image"]))
	if unit.kind == Unit.Kind.CART:
		_setup_cart()
	elif scene != null:
		_setup_model(scene)
	else:
		_setup_card()
	if unit.kind != Unit.Kind.CART:
		_setup_base()
	_setup_ring()
	_setup_gauge()
	refresh()


# --- Corps ------------------------------------------------------------------------

func _setup_model(scene: PackedScene) -> void:
	_is_model = true
	var model: Node3D = scene.instantiate()
	_body.add_child(model)
	_material.shader = MODEL_SHADER
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("width", OUTLINE_WIDTH)
	_material.next_pass = _outline
	var skin_mesh: MeshInstance3D = null
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var source := mi.get_active_material(0) as BaseMaterial3D
		if source != null and source.albedo_texture != null:
			_material.set_shader_parameter("albedo_tex", source.albedo_texture)
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.skin != null:
			skin_mesh = mi
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skin_mesh != null and not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0]
		var library := GameAssets.animations_for(str(_look["image"]), skeleton, skin_mesh.skin, model.get_path_to(skeleton))
		_anim = AnimationPlayer.new()
		model.add_child(_anim)
		_anim.add_animation_library("", library)
		_rest_pose()
	_setup_blob(0.36 if _height < 1.7 else 0.5)
	_stains.position = Vector3(0, _height * 0.56, 0.3)
	_pivot.add_child(_stains)


func _setup_cart() -> void:
	var food := Color("a5c94f") if unit.name.contains("pur") else Color("cf7a33")
	var mi := MeshInstance3D.new()
	mi.mesh = Props.cart(food)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	_height = 1.05
	_setup_blob(0.62)
	# Étiquette permanente : on doit reconnaître les chariots de loin.
	var tag := Label3D.new()
	tag.text = unit.name.to_upper()
	tag.font = BD.title_font()
	tag.font_size = 52
	tag.outline_size = 16
	tag.pixel_size = 0.006
	tag.modulate = food.lightened(0.45)
	tag.outline_modulate = BD.INK
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 4
	tag.outline_render_priority = 3
	tag.position = Vector3(0, 1.7, 0)
	add_child(tag)


func _setup_card() -> void:
	var margin: float = _look["marge"]
	var full_h := _height / (1.0 - 2.0 * margin)
	var quad := QuadMesh.new()
	quad.size = Vector2(full_h * float(_look["aspect"]), full_h)
	_material.shader = CARD_SHADER
	var atlas := GameAssets.texture("pions", str(_look["image"]) + ".png")
	_material.set_shader_parameter("atlas", atlas)
	_material.set_shader_parameter("frames", float(_look["vues"]))
	_material.set_shader_parameter("aspect", float(_look["aspect"]))
	_material.set_shader_parameter("border", 0.016)
	quad.material = _material
	_card.mesh = quad
	_card.position.y = full_h / 2.0 - full_h * margin + 0.05
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ombre : la silhouette couchée au sol, à l'opposé du soleil.
	var shadow_len := full_h * 0.7
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(quad.size.x, shadow_len)
	_shadow_mat.shader = SHADOW_SHADER
	_shadow_mat.set_shader_parameter("atlas", atlas)
	_shadow_mat.set_shader_parameter("frames", float(_look["vues"]))
	shadow_quad.material = _shadow_mat
	_shadow.mesh = shadow_quad
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var along := SHADOW_DIR.normalized()
	var side := along.cross(Vector3.UP).normalized()
	# Le bas de l'image (les pieds) reste sous le pion, le haut part dans la direction de l'ombre.
	_shadow.transform = Transform3D(Basis(side, along, Vector3.UP), along * (shadow_len * (0.5 - margin)) + Vector3(0, 0.022, 0))
	add_child(_shadow)
	var lean := Node3D.new()
	lean.rotation.x = -LEAN
	_pivot.add_child(lean)
	lean.add_child(_card)
	_stains.position = _card.position + Vector3(0, 0, 0.02)
	lean.add_child(_stains)


## Ombre ronde sous un objet 3D, décalée à l'opposé du soleil.
func _setup_blob(radius: float) -> void:
	if _blob == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.05, 0.03, 0.1, 0.55))
		gradient.set_color(1, Color(0.05, 0.03, 0.1, 0.0))
		gradient.add_point(0.62, Color(0.05, 0.03, 0.1, 0.42))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob = tex
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 3.4, radius * 2.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _blob
	plane.material = mat
	_shadow.mesh = plane
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var along := SHADOW_DIR.normalized()
	_shadow.position = along * radius * 0.75 + Vector3(0, 0.024, 0)
	_shadow.rotation.y = atan2(-along.z, along.x)
	add_child(_shadow)


# --- Socle, anneau, jauge ---------------------------------------------------------------

func _setup_base() -> void:
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
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)


func _setup_ring() -> void:
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
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _setup_gauge() -> void:
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


func has_gauge() -> bool:
	return unit.kind in [Unit.Kind.STUDENT, Unit.Kind.TEACHER, Unit.Kind.COOK] or unit.rallied or unit.status == Unit.Status.BERSERK


func refresh() -> void:
	var on_board := unit.is_on_board()
	# Les chariots sont du mobilier : on les voit même dans le brouillard.
	visible = on_board and (shown or unit.kind == Unit.Kind.CART)
	_shadow.visible = not unit.on_table and unit.status != Unit.Status.CAPTURED
	if not on_board:
		return
	var height := BoardView.TABLE_HEIGHT if unit.on_table else 0.0
	position = BoardView.cell_to_world(unit.pos, height)
	_lift.scale = Vector3.ONE
	_lift.rotation.z = 0.0
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
			_lift.scale = Vector3.ONE * 0.8
			_lift.rotation.z = 0.5
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
	if _is_model:
		# Le pion choisi respire et son contour passe au jaune.
		_outline.set_shader_parameter("color", BD.YELLOW if on else BD.INK)
		_outline.set_shader_parameter("width", OUTLINE_WIDTH * (1.7 if on else 1.0))
		if _anim != null and _anim.current_animation in ["", "repos"]:
			if on:
				_anim.play("repos")
			else:
				_rest_pose()


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


func set_facing(d: Vector2, instant: bool = false) -> void:
	if d == Vector2.ZERO:
		return
	facing = d.normalized()
	_update_view(instant)


## Jauge, nom et cartons se tournent vers la caméra (autour de la verticale seulement).
func face_camera(angle_deg: float) -> void:
	_cam_angle = angle_deg
	_pivot.rotation.y = deg_to_rad(angle_deg)
	if not _is_model:
		_update_view()


func _update_view(instant: bool = false) -> void:
	if _is_model or unit.kind == Unit.Kind.CART:
		# Le modèle pivote vers la direction regardée, par le plus court chemin.
		var goal := atan2(facing.x, facing.y) + MODEL_YAW
		if _turn != null:
			_turn.kill()
		if instant or not is_inside_tree() or absf(angle_difference(_body.rotation.y, goal)) < 0.01:
			_body.rotation.y = goal
			return
		var from := _body.rotation.y
		_turn = create_tween()
		_turn.tween_method(func(t: float): _body.rotation.y = lerp_angle(from, goal, t), 0.0, 1.0, 0.14)
		return
	if int(_look.get("vues", 1)) < 5:
		return
	# Carton : face, 3/4 face, profil, 3/4 dos ou dos, retourné si le personnage regarde à gauche.
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


# --- Animations -----------------------------------------------------------------------

## Pose de repos figée : un pion immobile ne coûte rien à l'affichage.
func _rest_pose() -> void:
	if _anim == null or not _anim.has_animation("repos"):
		return
	_anim.play("repos")
	_anim.seek(fmod(unit.id * 0.37, _anim.get_animation("repos").length), true)
	_anim.pause()


## Marche sur place pendant que le jeu déplace le pion.
func walk(on: bool) -> void:
	if _anim == null or not _anim.has_animation("marche"):
		return
	_action += 1
	if on:
		_anim.play("marche", 0.1, 1.9)
	elif _ring.visible:
		_anim.play("repos", 0.15)
	else:
		_rest_pose()


## Joue une animation une fois, puis revient au repos.
func _play_once(clip: String, speed: float, from: float = 0.0) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_action += 1
	var mine := _action
	_anim.play(clip, 0.08, speed)
	if from > 0.0:
		_anim.seek(from, true)
	await get_tree().create_timer((_anim.get_animation(clip).length - from) / speed, false).timeout
	if mine == _action and is_inside_tree():
		if _ring.visible:
			_anim.play("repos", 0.2)
		else:
			_rest_pose()


## Geste du lancer : rend la main au moment où le projectile doit partir.
func throw_anim() -> void:
	if _anim == null or not _anim.has_animation("lancer"):
		hop(0.3)
		return
	var length := _anim.get_animation("lancer").length
	_play_once("lancer", THROW_SPEED)
	await get_tree().create_timer(length * THROW_RELEASE / THROW_SPEED, false).timeout


## Éclair blanc quand le pion est touché, avec un petit sursaut.
func hit_flash() -> void:
	var tw := create_tween()
	tw.tween_method(func(v): _material.set_shader_parameter("flash", v), 0.9, 0.0, 0.35)
	var tw2 := create_tween()
	tw2.tween_property(_lift, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tw2.tween_property(_lift, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_play_once("touche", 1.6)


## Petit saut sur place (lancer, joie, sursaut).
func hop(height: float = 0.35, time: float = 0.22) -> void:
	var tw := create_tween()
	tw.tween_property(_lift, "position:y", height, time * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_lift, "position:y", 0.0, time * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


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
