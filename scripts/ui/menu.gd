class_name Menu
extends Control
## Écran titre : campagne (année scolaire) ou partie seule (une des trois cartes, contre l'ordinateur
## ou à deux), difficulté, réglages.

signal start_game
signal open_campaign

var _difficulty_buttons := {}
var _mode_buttons := {}
var _level_buttons := {}
var _summary: Label
var _difficulty_box: Control
var _level_box: Control
var _vs_buttons := {}
var _play: Button
var _mode := "seule"  # "campagne" ou "seule"
var _vs := "ordi"     # partie seule : "ordi" (contre l'ordinateur) ou "duo" (à deux sur le même écran)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = GameAssets.ui_texture("ecrans", "titre.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.05, 0.15, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var sheet := BD.paper_panel(22)
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.offset_right = -48
	sheet.offset_bottom = -44
	sheet.custom_minimum_size = Vector2(780, 0)
	sheet.rotation = -0.012
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	BD.content(sheet).add_child(col)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	col.add_child(modes)
	for spec in [["campagne", "CAMPAGNE"], ["seule", "PARTIE SEULE"]]:
		var b := BD.sticker(spec[1], Color("2f7fe6"), 34)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: String = spec[0]
		b.pressed.connect(func(): _set_mode(mode))
		modes.add_child(b)
		_mode_buttons[mode] = b

	# Partie seule : une des trois cartes (les services construits de data/campagne.json), puis l'adversaire.
	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 8)
	col.add_child(_level_box)
	_level_box.add_child(BD.label("CHOISIS TA CARTE", 30, Color("3a5fb0"), true))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	_level_box.add_child(lrow)
	var n := 0
	for service in Campaign.load_data()["services"]:
		if not Campaign.is_playable(service):
			continue
		n += 1
		var path := Campaign.level_path(service)
		var b := BD.sticker(str(service["titre"]).to_upper(), Color("e07a2f"), 21)
		b.toggle_mode = true
		b.icon = GameAssets.ui_texture("ecrans", "carte_%d.webp" % n)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 176)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = str(service["resume"])
		b.pressed.connect(func(): _set_level(path))
		lrow.add_child(b)
		_level_buttons[path] = b
	var vs := HBoxContainer.new()
	vs.add_theme_constant_override("separation", 10)
	_level_box.add_child(vs)
	for spec in [["ordi", "CONTRE L'ORDINATEUR"], ["duo", "À DEUX, MÊME ÉCRAN"]]:
		var b := BD.sticker(spec[1], Color("7a5fc0"), 22)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = spec[0]
		b.pressed.connect(func(): _set_vs(k))
		vs.add_child(b)
		_vs_buttons[k] = b

	_difficulty_box = VBoxContainer.new()
	_difficulty_box.add_theme_constant_override("separation", 8)
	col.add_child(_difficulty_box)
	_difficulty_box.add_child(BD.label("DIFFICULTÉ", 30, Color("3a5fb0"), true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_difficulty_box.add_child(row)
	var diffs := GameSetup.difficulties()
	var colors := {"facile": Color("36b25a"), "normal": Color("f0a020"), "difficile": Color("c0392b")}
	for key in diffs["ordre"]:
		var b := BD.sticker(str(diffs[key]["nom"]).to_upper(), colors.get(key, Color("6b6b6b")), 23)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = key
		b.pressed.connect(func(): _set_difficulty(k))
		row.add_child(b)
		_difficulty_buttons[key] = b
	_summary = BD.label("", 24)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(580, 62)
	col.add_child(_summary)

	_play = BD.sticker("À TABLE !", BD.RED, 60)
	_play.custom_minimum_size = Vector2(0, 96)
	_play.pressed.connect(_on_play)
	col.add_child(_play)
	# Reprendre une partie sauvegardée (reprise automatique ou emplacement choisi).
	if SaveSlots.has_any():
		var resume := BD.sticker("REPRENDRE UNE PARTIE", Color("2f7fe6"), 28)
		resume.pressed.connect(func():
			var panel := SavePanel.new(false)
			panel.chosen.connect(func(key: String):
				GameConfig.pending_load = SaveSlots.all().get(key, {})
				panel.queue_free()
				start_game.emit())
			add_child(panel))
		col.add_child(resume)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	col.add_child(opts)
	var music := BD.sticker("", Color("7a5fc0"), 20)
	music.toggle_mode = true
	music.button_pressed = GameConfig.music_on
	music.text = "MUSIQUE : OUI" if GameConfig.music_on else "MUSIQUE : NON"
	music.toggled.connect(func(on):
		GameConfig.music_on = on
		music.text = "MUSIQUE : OUI" if on else "MUSIQUE : NON"
		Sound.refresh_settings())
	opts.add_child(music)
	var sfx := BD.sticker("", Color("7a5fc0"), 20)
	sfx.toggle_mode = true
	sfx.button_pressed = GameConfig.sound_on
	sfx.text = "BRUITAGES : OUI" if GameConfig.sound_on else "BRUITAGES : NON"
	sfx.toggled.connect(func(on):
		GameConfig.sound_on = on
		sfx.text = "BRUITAGES : OUI" if on else "BRUITAGES : NON"
		Sound.refresh_settings())
	opts.add_child(sfx)
	if not OS.has_feature("web"):
		var full := BD.sticker("PLEIN ÉCRAN", Color("6b6b6b"), 20)
		full.pressed.connect(func():
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN)
		opts.add_child(full)
		var quit := BD.sticker("QUITTER", Color("6b6b6b"), 20)
		quit.pressed.connect(func(): get_tree().quit())
		opts.add_child(quit)

	var credit := BD.label("D'après le jeu de plateau de D. Guiserix et F. Marcela-Froideval. Prototype personnel, version %s." % ("PC" if GameAssets.is_hd() else "web"), 20, Color.WHITE)
	BD.outline(credit, 6)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.offset_left = 20
	credit.offset_top = -40
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(credit)

	_set_level(GameConfig.level_path)
	_vs = "ordi" if GameConfig.solo else "duo"
	_set_mode("campagne" if GameConfig.campaign else "seule")
	_set_difficulty(GameConfig.difficulty)
	Sound.ambience(false)
	Sound.music("musique_menu")


func _set_mode(mode: String) -> void:
	_mode = mode
	for k in _mode_buttons.keys():
		_mode_buttons[k].set_pressed_no_signal(k == mode)
		_mode_buttons[k].modulate = Color.WHITE if k == mode else Color(0.8, 0.8, 0.8, 0.85)
	_level_box.visible = mode == "seule"
	var year := CampaignStore.load_year() if mode == "campagne" else null
	_play.text = "À TABLE !" if mode == "seule" else ("CONTINUER L'ANNÉE" if year != null else "COMMENCER L'ANNÉE")
	_play.add_theme_font_size_override("font_size", 60 if mode == "seule" else 46)
	_set_vs(_vs)


## Partie seule : contre l'ordinateur ou à deux sur le même écran.
func _set_vs(k: String) -> void:
	_vs = k
	GameConfig.solo = _mode == "campagne" or k == "ordi"
	for key in _vs_buttons.keys():
		_vs_buttons[key].set_pressed_no_signal(key == k)
		_vs_buttons[key].modulate = Color.WHITE if key == k else Color(0.8, 0.8, 0.8, 0.85)
	# Une année en cours garde sa difficulté : on la règle en commençant une nouvelle année.
	var year := CampaignStore.load_year() if _mode == "campagne" else null
	_difficulty_box.modulate = Color(1, 1, 1, 0.35) if not GameConfig.solo or year != null else Color.WHITE
	_set_difficulty(GameConfig.difficulty)


func _set_level(path: String) -> void:
	if not _level_buttons.has(path):
		path = _level_buttons.keys()[0]
	GameConfig.level_path = path
	for k in _level_buttons.keys():
		_level_buttons[k].set_pressed_no_signal(k == path)
		_level_buttons[k].modulate = Color.WHITE if k == path else Color(0.8, 0.8, 0.8, 0.85)


func _on_play() -> void:
	GameConfig.campaign = _mode == "campagne"
	GameConfig.solo = _mode == "campagne" or _vs == "ordi"
	if _mode == "campagne":
		if CampaignStore.load_year() == null:
			CampaignStore.save_year(Campaign.new_year(GameConfig.difficulty, GameData.load_default().student_names()))
		open_campaign.emit()
	else:
		start_game.emit()


func _set_difficulty(key: String) -> void:
	if _mode == "campagne" and CampaignStore.load_year() != null:
		key = CampaignStore.load_year().difficulty()
	GameConfig.difficulty = key
	for k in _difficulty_buttons.keys():
		_difficulty_buttons[k].set_pressed_no_signal(k == key)
		_difficulty_buttons[k].modulate = Color.WHITE if k == key else Color(0.8, 0.8, 0.8, 0.85)
	if _mode == "campagne":
		var year := CampaignStore.load_year()
		if year != null:
			var s := year.current_service()
			_summary.text = "Année en cours : %s, « %s ». Difficulté « %s »." % [str(s["mois"]).to_lower(), s["titre"], GameSetup.difficulties()[key]["nom"]]
		else:
			_summary.text = "L'année scolaire : la même bande de service en service, expérience, colles et bulletin. " + str(GameSetup.difficulties()[key]["resume"])
	elif GameConfig.solo:
		_summary.text = str(GameSetup.difficulties()[key]["resume"]) + " Une partie dure 20 à 30 minutes."
	else:
		_summary.text = "Chacun sa bande, à tour de rôle. Un écran « passe la main » cache le jeu entre deux tours."
