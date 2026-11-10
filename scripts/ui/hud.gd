class_name Hud
extends CanvasLayer
## Interface de la maquette : barre d'état en haut, fiche de l'élève, plateau de dés et bouton de fin de tour en bas
## (variante A de la bible graphique, en version provisoire).

signal end_turn_pressed
signal watering_toggled(on: bool)

const TEAM_NAMES := ["rouge", "bleue", "verte", "jaune"]
const PAPER := Color("fbf6e6")
const INK := Color("1d1d1d")

var _status: Label
var _unit_card: Label
var _dice_box: VBoxContainer
var _log: RichTextLabel
var _hint: Label
var _water_button: Button
var _banner: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := _panel(root)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 48
	_status = _label(top, 22)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -190
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	var card := _panel(bottom)
	card.custom_minimum_size = Vector2(300, 0)
	_unit_card = _label(card, 18)

	var dice := _panel(bottom)
	dice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dice_box = VBoxContainer.new()
	dice.add_child(_dice_box)

	var right := _panel(bottom)
	right.custom_minimum_size = Vector2(320, 0)
	var col := VBoxContainer.new()
	right.add_child(col)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(300, 100)
	_log.scroll_following = true
	_log.add_theme_color_override("default_color", INK)
	_log.add_theme_font_size_override("normal_font_size", 14)
	col.add_child(_log)
	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	_water_button = Button.new()
	_water_button.text = "Arroser (R)"
	_water_button.toggle_mode = true
	_water_button.toggled.connect(func(on): watering_toggled.emit(on))
	buttons.add_child(_water_button)
	var end_btn := Button.new()
	end_btn.text = "Fin du tour (Entrée)"
	end_btn.pressed.connect(func(): end_turn_pressed.emit())
	buttons.add_child(end_btn)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 56
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", INK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_hint)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", Color("fff35c"))
	_banner.add_theme_color_override("font_outline_color", INK)
	_banner.add_theme_constant_override("outline_size", 16)
	_banner.visible = false
	root.add_child(_banner)


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


static func team_name(team: int) -> String:
	return "Bande " + TEAM_NAMES[team % TEAM_NAMES.size()]


func set_status(state: GameState) -> void:
	var ammo := "munitions sur les tables" if state.tables_have_ammo() else "tables vides : bacs et chariots !"
	_status.text = "Tour %d   ·   %s   ·   %s" % [state.turn, team_name(state.current_team), ammo]


func set_unit(u: Unit, max_ap: int) -> void:
	if u == null:
		_unit_card.text = "Clique sur un de tes élèves."
		return
	var dex := "%dD" % u.dex_d6 + ("+%d" % u.dex_bonus if u.dex_bonus > 0 else "")
	var lines := [u.name, "Moral : %d / %d" % [u.moral, u.max_moral], "Dextérité : " + dex]
	if u.kind == Unit.Kind.STUDENT or u.rallied:
		lines.append("PA : %d / %d" % [u.ap, max_ap])
		lines.append("Tir : " + ("déjà fait" if u.has_shot else ("prêt" if u.loaded else "pas de munition")))
		if u.on_table:
			lines.append("Debout sur la table (%d tour(s))" % u.turns_on_table)
	_unit_card.text = "\n".join(lines)


func set_hint(text: String) -> void:
	_hint.text = text


func set_watering(on: bool) -> void:
	_water_button.set_pressed_no_signal(on)


func log_line(text: String) -> void:
	_log.append_text(text + "\n")


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


## Affiche les dés d'un compte rendu de tir, avec un court roulement avant la valeur finale.
func show_shot(report: Dictionary, shooter: Unit, victim: Unit) -> void:
	for c in _dice_box.get_children():
		c.queue_free()
	if report.has("projectile_roll"):
		var r: Dictionary = report["projectile_roll"]
		await _dice_row("Projectile", r, " = %d : %s (CX %d)" % [r["total"], report["projectile_name"], report["cx"]])
	else:
		_text_row("Arrosage au robinet (CX 0)")
	_text_row("Seuil à battre : distance %d + CX %d = %d" % [report["distance"], report["cx"], report["threshold"]])
	var dex: Dictionary = report["dex_roll"]
	await _dice_row("Dextérité de " + shooter.name, dex, " = %d  →  %s" % [dex["total"], "TOUCHÉ !" if report["hit"] else "raté…"])
	if victim == null:
		_text_row("La nourriture s'écrase par terre.")
		return
	var dmg: Dictionary = report["damage_roll"]
	var who := victim.name if victim.kind != Unit.Kind.NEUTRAL else "un neutre"
	var prefix := "" if report["hit"] else "Retombée sur %s. " % who
	var pts := "%d point%s de moral" % [dmg["total"], "s" if dmg["total"] > 1 else ""]
	if dmg["faces"].is_empty():
		_text_row(prefix + "Dégâts : " + pts + " (fixe)")
	else:
		await _dice_row(prefix + "Dégâts", dmg, " = " + pts)
	if report.get("saturated", false):
		_text_row("%s est saturé et file vers la sortie !" % who)


func _text_row(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", 16)
	_dice_box.add_child(l)


func _dice_row(title: String, roll: Dictionary, suffix: String) -> void:
	var row := HBoxContainer.new()
	_dice_box.add_child(row)
	var t := Label.new()
	t.text = title + " : "
	t.add_theme_color_override("font_color", INK)
	t.add_theme_font_size_override("font_size", 16)
	row.add_child(t)
	var faces: Array = roll["faces"]
	var dice_labels: Array[Label] = []
	for f in faces:
		var d := Label.new()
		d.custom_minimum_size = Vector2(30, 30)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_color", INK)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.border_color = INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		d.add_theme_stylebox_override("normal", sb)
		row.add_child(d)
		dice_labels.append(d)
	if roll["bonus"] > 0 and not faces.is_empty():
		var b := Label.new()
		b.text = " + %d" % roll["bonus"]
		b.add_theme_color_override("font_color", INK)
		row.add_child(b)
	# Roulement : quelques faces au hasard (purement visuel) avant la vraie valeur.
	for i in 6:
		for d in dice_labels:
			d.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.05).timeout
	for i in faces.size():
		dice_labels[i].text = str(faces[i])
	var s := Label.new()
	s.text = suffix
	s.add_theme_color_override("font_color", INK)
	s.add_theme_font_size_override("font_size", 16)
	row.add_child(s)
