class_name Hud
extends CanvasLayer
## Interface de partie façon cahier d'écolier (variante A de la bible graphique) :
## barre d'état en haut, bande à gauche, fiche de l'élève, plateau de dés et « fin de tour » en bas.

signal end_turn_pressed
signal watering_toggled(on: bool)
signal rotate_pressed(direction: int)
signal project_pressed
signal unit_picked(id: int)
signal menu_pressed
signal replay_pressed
signal speed_toggled(fast: bool)

var dice: DiceTray

var _root: Control
var _turn_label: Label
var _team_label: Label
var _team_dot: Panel
var _ammo_label: Label
var _portrait: TextureRect
var _name_label: Label
var _moral_bar: ProgressBar
var _moral_label: Label
var _ap_box: HBoxContainer
var _info_label: Label
var _card: Control
var _roster: VBoxContainer
var _log: RichTextLabel
var _hint: Label
var _water_button: Button
var _project_button: Button
var _end_button: Button
var _speed_button: Button
var _banner: Control
var _overlay: Control
var _help: Control
var _score_label: Label


## Flèche tournante dessinée (les polices du jeu n'ont pas ce signe, surtout dans le navigateur).
class RotateIcon:
	extends Control
	var direction := 1

	func _draw() -> void:
		# Dessinée pour la droite, retournée en miroir pour la gauche.
		if direction < 0:
			draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.24
		var from := deg_to_rad(-200.0)
		var to := deg_to_rad(35.0)
		draw_arc(c, r, from, to, 20, Color.WHITE, 3.5, true)
		var tip := c + Vector2(cos(to), sin(to)) * r
		var along := Vector2(-sin(to), cos(to))
		var out := Vector2(cos(to), sin(to))
		draw_colored_polygon([tip + along * 10.0, tip - out * 8.0 - along * 2.0, tip + out * 8.0 - along * 2.0], Color.WHITE)


var auto_pass := false  ## essais automatiques : l'écran « passe la main » se ferme seul


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_build_roster()
	_build_bottom()
	_build_hint()
	_build_help()


# --- Construction -----------------------------------------------------------------

func _build_top() -> void:
	var top := BD.paper_panel(8)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = -6
	top.offset_right = 6
	top.offset_top = -8
	top.offset_bottom = 66
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	BD.content(top).add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(12, 0)
	row.add_child(pad)
	_turn_label = BD.label("TOUR 1 / 12", 40, BD.INK, true)
	row.add_child(_turn_label)
	var sep := BD.label("•", 30, Color("9a9a9a"), true)
	row.add_child(sep)
	_team_dot = Panel.new()
	_team_dot.custom_minimum_size = Vector2(34, 34)
	_team_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_team_dot)
	_team_label = BD.label("", 40, BD.INK, true)
	row.add_child(_team_label)
	_score_label = BD.label("", 24)
	_score_label.clip_text = true
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_score_label)
	_ammo_label = BD.label("", 26, Color("3a5fb0"))
	row.add_child(_ammo_label)
	_speed_button = BD.sticker("VITESSE ×1", Color("7a5fc0"), 20)
	_speed_button.toggle_mode = true
	_speed_button.tooltip_text = "Accélérer les animations et les dés (V)"
	_speed_button.toggled.connect(func(on):
		_speed_button.text = "VITESSE ×2" if on else "VITESSE ×1"
		speed_toggled.emit(on))
	row.add_child(_speed_button)
	var help_btn := BD.sticker("?", Color("2f9e8f"), 22)
	help_btn.tooltip_text = "Comment jouer (F1)"
	help_btn.pressed.connect(toggle_help)
	row.add_child(help_btn)
	var menu_btn := BD.sticker("MENU", Color("6b6b6b"), 20)
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu_btn)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(10, 0)
	row.add_child(pad2)


func _build_roster() -> void:
	_roster = VBoxContainer.new()
	_roster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_roster.offset_left = 12
	_roster.offset_top = 84
	_roster.add_theme_constant_override("separation", 6)
	_root.add_child(_roster)


func _build_bottom() -> void:
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -232
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)

	# Fiche de l'élève : photo d'identité, moral, points d'action cochés.
	var card := BD.paper_panel(12)
	card.custom_minimum_size = Vector2(520, 0)
	bottom.add_child(card)
	_card = card
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	BD.content(card).add_child(card_row)
	var photo := PanelContainer.new()
	var photo_box := BD.flat_box(Color("f7f3ea"), 8, 4, 3)
	photo_box.content_margin_bottom = 20
	photo.add_theme_stylebox_override("panel", photo_box)
	photo.rotation = -0.04
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_row.add_child(photo)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(132, 132)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	card_row.add_child(col)
	_name_label = BD.label("", 38, BD.INK, true)
	col.add_child(_name_label)
	var moral_row := HBoxContainer.new()
	moral_row.add_theme_constant_override("separation", 8)
	col.add_child(moral_row)
	moral_row.add_child(BD.label("MORAL", 22, BD.RED, true))
	_moral_bar = ProgressBar.new()
	_moral_bar.custom_minimum_size = Vector2(170, 22)
	_moral_bar.show_percentage = false
	_moral_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_moral_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg := BD.flat_box(Color("ffffff"), 0, 5, 3)
	bar_bg.shadow_size = 0
	var bar_fill := BD.flat_box(BD.RED, 0, 5, 3)
	bar_fill.shadow_size = 0
	_moral_bar.add_theme_stylebox_override("background", bar_bg)
	_moral_bar.add_theme_stylebox_override("fill", bar_fill)
	moral_row.add_child(_moral_bar)
	_moral_label = BD.label("", 24, BD.INK, true)
	moral_row.add_child(_moral_label)
	var ap_row := HBoxContainer.new()
	ap_row.add_theme_constant_override("separation", 8)
	col.add_child(ap_row)
	ap_row.add_child(BD.label("PA", 22, Color("3a5fb0"), true))
	_ap_box = HBoxContainer.new()
	_ap_box.add_theme_constant_override("separation", 2)
	ap_row.add_child(_ap_box)
	_info_label = BD.label("", 22)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info_label)

	# Plateau de dés.
	var tray := BD.paper_panel(12)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(tray)
	# Le plateau garde sa taille : les jets défilent dedans sans pousser le reste de l'interface.
	var clip := Control.new()
	clip.clip_contents = true
	BD.content(tray).add_child(clip)
	dice = DiceTray.new()
	dice.add_theme_constant_override("separation", 0)
	dice.set_anchors_preset(Control.PRESET_TOP_WIDE)
	clip.add_child(dice)
	dice.add_text("Plateau de dés : chaque jet du livret roule ici.", 22, Color("8a8a8a"))

	# Journal et actions.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 8)
	bottom.add_child(right)
	var log_panel := BD.paper_panel(8)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.bbcode_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_override("normal_font", BD.hand_font())
	_log.add_theme_font_override("bold_font", BD.title_font())
	_log.add_theme_font_size_override("normal_font_size", 18)
	_log.add_theme_font_size_override("bold_font_size", 18)
	_log.add_theme_color_override("default_color", BD.INK)
	BD.content(log_panel).add_child(_log)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_water_button = BD.sticker("ARROSER", Color("2f7fe6"), 20)
	_water_button.tooltip_text = "Au contact d'un robinet : portée 5, dégâts 1D (R)"
	_water_button.toggle_mode = true
	_water_button.toggled.connect(func(on): watering_toggled.emit(on))
	buttons.add_child(_water_button)
	_project_button = BD.sticker("PROJETER", Color("c2571a"), 20)
	_project_button.tooltip_text = "À trois autour d'un ennemi, près d'un bac ou d'un chariot : dans le plat du jour ! (P)"
	_project_button.pressed.connect(func(): project_pressed.emit())
	buttons.add_child(_project_button)
	for spec in [["gauche", -1, "Tourner la vue à gauche (Q)"], ["droite", 1, "Tourner la vue à droite (E)"]]:
		var rot := BD.sticker("", Color("6b6b6b"), 22)
		rot.custom_minimum_size = Vector2(48, 0)
		var icon := RotateIcon.new()
		icon.direction = spec[1]
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rot.add_child(icon)
		rot.tooltip_text = spec[2]
		rot.pressed.connect(func(): rotate_pressed.emit(spec[1]))
		buttons.add_child(rot)
	_end_button = BD.sticker("FIN DE TOUR !", BD.RED, 40)
	_end_button.tooltip_text = "Entrée"
	_end_button.custom_minimum_size = Vector2(0, 76)
	_end_button.rotation = -0.02
	_end_button.pressed.connect(func(): end_turn_pressed.emit())
	right.add_child(_end_button)


func _build_hint() -> void:
	_hint = BD.label("", 26, BD.INK)
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color("fffbea")
	strip.border_color = BD.INK
	strip.set_border_width_all(3)
	strip.set_corner_radius_all(6)
	strip.content_margin_left = 16
	strip.content_margin_right = 16
	strip.content_margin_top = 2
	strip.content_margin_bottom = 2
	_hint.add_theme_stylebox_override("normal", strip)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_bottom = -250
	_hint.offset_top = -292
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_root.add_child(_hint)


func _build_help() -> void:
	_help = ColorRect.new()
	_help.color = Color(0, 0, 0, 0.55)
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.visible = false
	_help.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			toggle_help())
	_root.add_child(_help)
	var sheet := BD.paper_panel(28)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(1180, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	BD.content(sheet).add_child(col)
	col.add_child(BD.label("COMMENT JOUER", 54, BD.RED, true))
	var lines := [
		"But : être la dernière bande dans la cantine. À la sonnerie (tour 12), la bande qui garde le plus de moral gagne.",
		"Clic sur un de tes élèves pour le choisir (ou Tab), clic sur une case verte pour y aller : 1 PA par case, 12 PA par tour. Cases rouges : à portée d'un prof ou du cuisinier.",
		"Clic sur un adversaire pour lui lancer ce qui te tombe sous la main : 4 PA, une fois par tour. Deux dés désignent le projectile.",
		"Pour toucher, les dés de dextérité doivent atteindre la distance + la difficulté (CX) du projectile. Plus tu es près, mieux c'est.",
		"Munitions : au contact d'une table (tours 1 à 4), puis seulement des bacs et des chariots de la cuisine. On garde une munition en poche.",
		"Moral à zéro : l'élève est saturé et file vers la sortie. Un tir raté retombe sur un voisin.",
		"Les profs entrent par une porte tirée au dé. À la fin de chaque tour complet, ils avancent de 4 cases vers l'élève le plus proche et l'attrapent au contact : tiens-toi à plus de 5 cases, ou sature-les (30 de moral).",
		"Le cuisinier défend sa cuisine, lui aussi en fin de tour : il tire et plonge les imprudents dans le plat du jour.",
		"Neutre touché : sur 1 il te rejoint, sur 6 il devient berserk, sinon il s'enfuit.",
		"Clic sur une table au contact pour grimper dessus (tout le tour). Clic sur un chariot au contact pour le pousser de 3 cases.",
		"Caméra : clic droit pour tourner, Q et E par crans, molette pour zoomer, flèches ou clic molette pour se déplacer.",
		"Entrée : fin du tour.  R : arroser au robinet.  P : projeter.  V : vitesse.  Échap : désélectionner.",
	]
	for line in lines:
		var l := BD.label("•  " + line, 25)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(1120, 0)
		col.add_child(l)
	col.add_child(BD.label("Clique pour fermer", 22, Color("7a7a7a")))


# --- Mise à jour ------------------------------------------------------------------

func set_status(state: GameState, human_turn: bool) -> void:
	_turn_label.text = "TOUR %d / %d" % [mini(state.turn, state.max_turns()), state.max_turns()]
	var col := BD.team_color(state.current_team)
	_team_label.text = BD.team_name(state.current_team).to_upper() + ("" if human_turn else " (ordi)")
	_team_label.add_theme_color_override("font_color", col.darkened(0.15))
	var dot := StyleBoxFlat.new()
	dot.bg_color = col
	dot.border_color = BD.INK
	dot.set_border_width_all(4)
	dot.set_corner_radius_all(17)
	_team_dot.add_theme_stylebox_override("panel", dot)
	var left := int(state.data.rules["tours_munitions_tables"]) - state.turn + 1
	if state.tables_have_ammo():
		_ammo_label.text = "Tables garnies : encore %d tour%s" % [left, "s" if left > 1 else ""]
		_ammo_label.add_theme_color_override("font_color", Color("3a5fb0"))
	else:
		_ammo_label.text = "Tables vides : bacs et chariots !"
		_ammo_label.add_theme_color_override("font_color", BD.RED)
	var parts := []
	for t in state.team_count:
		parts.append("%s : %d élève%s, moral %d" % [BD.TEAM_NAMES[t].capitalize(), state.students_left(t).size(), "s" if state.students_left(t).size() > 1 else "", state.team_moral(t)])
	_score_label.text = "   •   ".join(parts)
	_end_button.disabled = not human_turn


## `playing` : nom de la bande qui joue quand ce n'est pas au joueur (ordinateur, profs).
func set_unit(u: Unit, max_ap: int, playing: String = "") -> void:
	if u == null:
		_card.modulate = Color(1, 1, 1, 0.55)
		_portrait.texture = null
		_name_label.text = "Choisis un élève" if playing == "" else playing.to_upper() + " JOUE…"
		_moral_bar.value = 0
		_moral_label.text = ""
		_info_label.text = "Clique sur un de tes pions, ou appuie sur Tab." if playing == "" else "Regarde bien : ton tour arrive."
		_fill_ap(0, 0)
		return
	_card.modulate = Color.WHITE
	_portrait.texture = GameAssets.portrait(u)
	_name_label.text = u.name.to_upper() if u.kind != Unit.Kind.NEUTRAL else ("NEUTRE RALLIÉ" if u.rallied else "NEUTRE")
	_name_label.add_theme_color_override("font_color", BD.team_color(u.team).darkened(0.2) if u.team >= 0 else BD.INK)
	_moral_bar.max_value = maxi(1, u.max_moral)
	_moral_bar.value = u.moral
	_moral_label.text = "%d / %d" % [u.moral, u.max_moral]
	var dex := "%dD" % u.dex_d6 + ("+%d" % u.dex_bonus if u.dex_bonus > 0 else "")
	var lines := ["Dextérité : " + dex]
	if u.is_controllable():
		_fill_ap(u.ap, max_ap)
		if u.has_shot:
			lines.append("Tir : déjà fait ce tour")
		elif u.loaded:
			lines.append("Tir : prêt (munition en main)")
		else:
			lines.append("Tir : pas de munition !")
		if u.on_table:
			lines.append("Debout sur la table (tour %d sur 2)" % (u.turns_on_table + 1))
	else:
		_fill_ap(0, 0)
		match u.kind:
			Unit.Kind.TEACHER: lines.append("Attrape l'élève le plus proche (1 à 4 sur 1D)")
			Unit.Kind.COOK: lines.append("Défend sa cuisine : tire et plonge dans le plat du jour")
			Unit.Kind.NEUTRAL: lines.append("Berserk : tire sur tout le monde !" if u.status == Unit.Status.BERSERK else "Mange tranquillement… pour l'instant")
			Unit.Kind.STUDENT: lines.append("Élève de la " + BD.team_name(u.team).to_lower())
	_info_label.text = "\n".join(lines)


func _fill_ap(ap: int, max_ap: int) -> void:
	for c in _ap_box.get_children():
		c.queue_free()
	for i in max_ap:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(19, 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("3a5fb0") if i < ap else Color(1, 1, 1, 0.6)
		sb.border_color = BD.INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		box.add_theme_stylebox_override("panel", sb)
		_ap_box.add_child(box)


## Vignettes de la bande, à gauche : un clic choisit l'élève.
func set_roster(units: Array, selected: Unit) -> void:
	for c in _roster.get_children():
		c.queue_free()
	for u in units:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(96, 86)
		var active: bool = u.is_controllable()
		var col := BD.team_color(u.team)
		var normal := BD.flat_box(BD.YELLOW if u == selected else BD.PAPER, 4, 8, 4 if u == selected else 3)
		normal.border_color = col.darkened(0.2) if u != selected else BD.INK
		b.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = normal.bg_color.lightened(0.3)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("disabled", normal)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.disabled = not active
		b.tooltip_text = "%s : moral %d / %d, %d PA" % [u.name, u.moral, u.max_moral, u.ap]
		var id: int = u.id
		b.pressed.connect(func(): unit_picked.emit(id))
		var face := TextureRect.new()
		face.texture = GameAssets.portrait(u)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.offset_left = 6
		face.offset_top = 4
		face.offset_right = -6
		face.offset_bottom = -18
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = maxi(1, u.max_moral)
		bar.value = u.moral
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 8
		bar.offset_right = -8
		bar.offset_top = -16
		bar.offset_bottom = -6
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = BD.INK
		bg.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = BD.RED
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		b.add_child(bar)
		if not active:
			face.modulate = Color(0.45, 0.45, 0.45, 0.8)
			var tag := BD.label("PRIS" if u.status == Unit.Status.CAPTURED else "SORTI", 24, BD.RED, true)
			BD.outline(tag, 6, Color.WHITE)
			tag.set_anchors_preset(Control.PRESET_CENTER)
			tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
			tag.grow_vertical = Control.GROW_DIRECTION_BOTH
			tag.rotation = -0.2
			b.add_child(tag)
		elif u.ap <= 0 or (u.has_shot and u.ap < 1):
			face.modulate = Color(0.75, 0.75, 0.75)
		elif not u.has_shot:
			# Pastille : cet élève peut encore tirer.
			var dot := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("5fd34a")
			sb.border_color = BD.INK
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(8)
			dot.add_theme_stylebox_override("panel", sb)
			dot.position = Vector2(74, 4)
			dot.size = Vector2(16, 16)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
		_roster.add_child(b)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


func set_watering(on: bool) -> void:
	_water_button.set_pressed_no_signal(on)


func set_actions(can_water: bool, can_project: bool, human_turn: bool) -> void:
	_water_button.disabled = not can_water
	_project_button.disabled = not can_project
	_end_button.disabled = not human_turn


func set_fast(on: bool) -> void:
	_speed_button.set_pressed_no_signal(on)
	_speed_button.text = "VITESSE ×2" if on else "VITESSE ×1"


func log_line(text: String) -> void:
	_log.append_text(text + "\n")


func toggle_help() -> void:
	_help.visible = not _help.visible


func help_open() -> bool:
	return _help.visible


## Grand titre qui traverse l'écran (changement de tour, sonnerie). Attend qu'il soit passé.
func show_banner(text: String, color: Color = BD.YELLOW, sub: String = "", time: float = 1.1) -> void:
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	var box := VBoxContainer.new()
	_banner = box
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_top = -160
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var l := BD.label(text, 110, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BD.outline(l, 26)
	box.add_child(l)
	if sub != "":
		var s := BD.label(sub, 40, Color.WHITE, true)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		BD.outline(s, 14)
		box.add_child(s)
	box.modulate.a = 0.0
	box.position.x -= 200
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(box, "position:x", box.position.x + 200, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(time)
	tw.tween_property(box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(box.queue_free)
	await tw.finished


func _dim_overlay() -> Control:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.16, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_overlay = bg
	return bg


## Écran « passe la main » entre deux joueurs sur le même écran. Attend le clic.
func show_pass_screen(team: int) -> void:
	var bg := _dim_overlay()
	bg.color = Color(0.1, 0.07, 0.16, 1.0)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 26)
	bg.add_child(col)
	var t := BD.label("PASSE LA MAIN !", 120, BD.YELLOW, true)
	BD.outline(t, 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var s := BD.label("Au tour de la %s" % BD.team_name(team).to_lower(), 60, BD.team_color(team).lightened(0.2), true)
	BD.outline(s, 16)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	var go := BD.sticker("C'EST MOI !", BD.team_color(team), 48)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(go)
	if auto_pass:
		await get_tree().create_timer(2.5).timeout
	else:
		await go.pressed
	bg.queue_free()


## Bulletin de fin de partie.
func show_game_over(title: String, color: Color, intro: String, teams: Array, rows: Array, comment: String) -> void:
	var bg := _dim_overlay()
	var sheet := BD.paper_panel(30)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(900, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	BD.content(sheet).add_child(col)
	col.add_child(BD.label("BULLETIN DE FIN DE SERVICE", 30, Color("3a5fb0"), true))
	var t := BD.label(title, 84, color, true)
	BD.outline(t, 14)
	col.add_child(t)
	var first := BD.label(intro, 30)
	first.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first.custom_minimum_size = Vector2(820, 0)
	col.add_child(first)
	# Le tableau du bulletin : une colonne par bande.
	var grid := GridContainer.new()
	grid.columns = teams.size() + 1
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 2)
	grid.add_child(Control.new())
	for team in teams:
		var head := BD.label(BD.team_name(team), 34, BD.team_color(team), true)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(170, 0)
		grid.add_child(head)
	for r in rows:
		for i in r.size():
			var cell := BD.label(str(r[i]), 28 if i == 0 else 32, BD.INK, i > 0)
			if i > 0:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(cell)
	col.add_child(grid)
	if comment != "":
		var note := BD.label(comment, 28, Color("b3261e"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(820, 0)
		col.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var again := BD.sticker("REJOUER", BD.RED, 40)
	again.pressed.connect(func(): replay_pressed.emit())
	row.add_child(again)
	var menu := BD.sticker("MENU", Color("6b6b6b"), 40)
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)
	sheet.scale = Vector2(0.6, 0.6)
	sheet.pivot_offset = Vector2(450, 200)
	create_tween().tween_property(sheet, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
