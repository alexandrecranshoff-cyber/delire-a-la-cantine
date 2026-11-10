class_name DiceTray
extends VBoxContainer
## Plateau de dés : tous les jets du livret sont montrés, dé par dé, avant leur effet.

const DIE_SIZE := 40.0


## Un dé dessiné : fond de couleur, points, contour à l'encre.
class Die:
	extends Control
	var value := 1
	var color := Color.WHITE
	var pip := BD.INK
	var spin := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(DiceTray.DIE_SIZE, DiceTray.DIE_SIZE)

	func _draw() -> void:
		var s := DiceTray.DIE_SIZE
		draw_set_transform(Vector2(s, s) / 2.0, spin, Vector2.ONE)
		var r := Rect2(-s / 2.0 + 3, -s / 2.0 + 3, s - 6, s - 6)
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = BD.INK
		box.set_border_width_all(3)
		box.set_corner_radius_all(9)
		box.anti_aliasing = true
		draw_style_box(box, r)
		var d := s * 0.23
		var spots := {
			1: [Vector2.ZERO],
			2: [Vector2(-d, -d), Vector2(d, d)],
			3: [Vector2(-d, -d), Vector2.ZERO, Vector2(d, d)],
			4: [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
			5: [Vector2(-d, -d), Vector2(d, -d), Vector2.ZERO, Vector2(-d, d), Vector2(d, d)],
			6: [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, 0), Vector2(d, 0), Vector2(-d, d), Vector2(d, d)],
		}
		for p in spots.get(value, []):
			draw_circle(p, s * 0.085, pip)


func clear() -> void:
	for c in get_children():
		c.queue_free()


func add_text(text: String, size: int = 22, color: Color = BD.INK, title: bool = false) -> Label:
	var l := BD.label(text, size, color, title)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	_trim()
	return l


## Lance des dés à l'écran : ils roulent un instant puis montrent les vraies faces. Attend la fin.
func roll(title: String, result: Dictionary, suffix: String, color: Color = Color.WHITE, time: float = 0.45) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_trim()
	var t := BD.label(title, 22)
	row.add_child(t)
	var faces: Array = result["faces"]
	var dice: Array[Die] = []
	for f in faces:
		var die := Die.new()
		die.color = color
		die.pip = Color.WHITE if color.get_luminance() < 0.5 else BD.INK
		row.add_child(die)
		dice.append(die)
	if int(result["bonus"]) > 0:
		row.add_child(BD.label("+ %d" % int(result["bonus"]), 26, BD.INK, true))
	if not dice.is_empty():
		Sound.play("des", -4.0)
		var steps := maxi(2, int(time / 0.05))
		for i in steps:
			for die in dice:
				die.value = randi_range(1, 6)  # purement visuel : le vrai tirage vient du moteur de règles
				die.spin = randf_range(-0.5, 0.5)
				die.queue_redraw()
			await get_tree().create_timer(0.05).timeout
		for i in dice.size():
			dice[i].value = int(faces[i])
			dice[i].spin = 0.0
			dice[i].queue_redraw()
	var s := BD.label(suffix, 24, BD.INK, true)
	row.add_child(s)


## Tampon de résultat, comme une appréciation dans un carnet.
func stamp(text: String, color: Color) -> void:
	var l := BD.label(text, 34, color, true)
	l.rotation = -0.05
	add_child(l)
	_trim()
	l.pivot_offset = Vector2(60, 20)
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.1)


func _trim() -> void:
	while get_child_count() > 4:
		var c := get_child(0)
		remove_child(c)
		c.queue_free()
