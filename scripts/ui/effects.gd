class_name Effects
extends Node3D
## Effets de BD : projectiles qui volent, onomatopées, taches au sol, bulles, chiffres de dégâts.

## Projectile du livret -> onomatopée, tache au sol, couleur de la tache.
const IMPACTS := {
	"2": ["bloup", "tache_creme", Color(0.6, 0.85, 1.0, 0.8)],
	"3": ["floc", "tache_marron", Color(0.75, 0.8, 0.85)],
	"4": ["splatch", "tache_verte", Color.WHITE],
	"5": ["floc", "tache_marron", Color(1.0, 0.8, 0.5)],
	"6": ["schlurp", "tache_creme", Color.WHITE],
	"7": ["paf", "tache_marron", Color(1.0, 0.9, 0.8)],
	"8": ["splatch", "tache_marron", Color.WHITE],
	"9": ["schlurp", "tache_creme", Color(1.0, 0.95, 0.7)],
	"10": ["splatch", "tache_orange", Color.WHITE],
	"11": ["paf", "tache_creme", Color(1.0, 0.8, 0.9)],
	"12": ["schlurp", "tache_verte", Color.WHITE],
	"robinet": ["bloup", "tache_creme", Color(0.6, 0.85, 1.0, 0.7)],
}
const MAX_FLOOR_STAINS := 70

var cam_angle := 45.0
var _floor_stains: Array[Node3D] = []


func impact_info(projectile: String) -> Array:
	return IMPACTS.get(projectile, IMPACTS["7"])


func _sprite(family: String, name: String, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	var tex := GameAssets.texture(family, name)
	s.texture = tex
	if tex != null:
		s.pixel_size = height / float(tex.get_height())
	s.shaded = false
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.render_priority = 10
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


## Le projectile vole en cloche du tireur à sa cible. Attend l'arrivée.
func throw_projectile(projectile: String, from: Vector3, to: Vector3, time: float) -> void:
	var s := _sprite("projectiles", "projectile_%s.png" % projectile, 0.75)
	# Les projectiles sont dessinés filant vers la droite de l'écran.
	var right := Vector3(cos(deg_to_rad(cam_angle)), 0, -sin(deg_to_rad(cam_angle)))
	s.flip_h = (to - from).dot(right) < 0.0
	add_child(s)
	var arc := clampf(from.distance_to(to) * 0.22, 0.6, 2.6)
	var tw := create_tween()
	var next_dot := [0.08]
	tw.tween_method(func(t: float):
		s.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * arc, 0)
		s.rotation.z = (-1.0 if s.flip_h else 1.0) * (0.5 - t) * 0.9
		# Traînée en pointillés, comme les trajectoires dessinées en BD.
		while t >= next_dot[0]:
			_trail_dot(from.lerp(to, next_dot[0]) + Vector3(0, sin(next_dot[0] * PI) * arc, 0))
			next_dot[0] += 0.09
	, 0.0, 1.0, time)
	await tw.finished
	s.queue_free()


static var _dot_mesh: SphereMesh

func _trail_dot(pos: Vector3) -> void:
	if _dot_mesh == null:
		_dot_mesh = SphereMesh.new()
		_dot_mesh.radius = 0.045
		_dot_mesh.height = 0.09
		_dot_mesh.radial_segments = 8
		_dot_mesh.rings = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = BD.INK
		_dot_mesh.material = mat
	var dot := MeshInstance3D.new()
	dot.mesh = _dot_mesh
	dot.position = pos
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dot)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(dot, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(dot.queue_free)


## Onomatopée dessinée qui surgit puis s'efface.
func onomatopoeia(name: String, pos: Vector3, size: float = 1.5) -> void:
	var s := _sprite("effets", name + ".png", size)
	s.position = pos
	s.scale = Vector3.ONE * 0.2
	s.rotation.z = randf_range(-0.2, 0.2)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(s, "position:y", pos.y + 0.6, 0.25)
	tw.tween_callback(s.queue_free)


## Tache qui reste par terre jusqu'à la fin du service.
func floor_stain(name: String, cell_pos: Vector3, color: Color = Color.WHITE) -> void:
	var tex := GameAssets.texture("effets", name + ".png")
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = randf_range(0.8, 1.15) / float(tex.get_width())
	s.axis = Vector3.AXIS_Y
	s.shaded = false
	s.modulate = Color(color, 0.92)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = cell_pos + Vector3(randf_range(-0.2, 0.2), 0.012 + 0.0004 * _floor_stains.size(), randf_range(-0.2, 0.2))
	s.rotation.y = randf_range(0, TAU)
	s.scale = Vector3.ONE * 0.1
	add_child(s)
	create_tween().tween_property(s, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_floor_stains.append(s)
	if _floor_stains.size() > MAX_FLOOR_STAINS:
		_floor_stains.pop_front().queue_free()


## Bulle de BD au-dessus d'une tête. `kind` : "ovale" (parole), "cri", "pensee".
func bubble(text: String, pos: Vector3, kind: String = "ovale", time: float = 1.4, color: Color = BD.INK) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.55, 0)
	add_child(holder)
	var width := clampf(0.5 + 0.2 * text.length(), 1.5, 4.2)
	var s := _sprite("effets", "bulle_%s.png" % kind, 1.0)
	if s.texture != null:
		# La bulle s'étire avec le texte.
		var ratio := float(s.texture.get_width()) / float(s.texture.get_height())
		s.scale = Vector3(width / ratio, 1.1 if kind != "cri" else 1.45, 1)
	s.render_priority = 11
	holder.add_child(s)
	var l := Label3D.new()
	l.text = text
	l.font = BD.title_font()
	l.font_size = 64
	l.pixel_size = 0.0058
	l.modulate = color
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 12
	l.position = Vector3(0, 0.07 if kind != "cri" else 0.02, 0)
	holder.add_child(l)
	holder.scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(time)
	tw.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.15)
	tw.tween_callback(holder.queue_free)


## Chiffre qui s'envole (points de moral perdus).
func floating_text(text: String, pos: Vector3, color: Color = BD.YELLOW, size: int = 84) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = BD.title_font()
	l.font_size = size
	l.outline_size = 22
	l.pixel_size = 0.007
	l.modulate = color
	l.outline_modulate = BD.INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 14
	l.outline_render_priority = 13
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", pos.y + 1.2, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.tween_callback(l.queue_free)


## Petit nuage de poussière (course, chute).
func puff(pos: Vector3, size: float = 0.8) -> void:
	var s := _sprite("effets", "nuage.png", size)
	s.no_depth_test = false
	s.position = pos + Vector3(0, size * 0.4, 0)
	s.modulate = Color(1, 1, 1, 0.9)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.5, 0.35)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
	tw.tween_callback(s.queue_free)
