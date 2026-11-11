class_name Menu
extends Control
## Écran titre : mode de jeu (solo, deux joueurs, année scolaire), salle, difficulté, réglages.

signal start_game
signal open_campaign

var _difficulty_buttons := {}
var _mode_buttons := {}
var _level_buttons := {}
var _summary: Label
var _difficulty_box: Control
var _level_box: Control
var _play: Button
var _mode := "solo"   # "solo", "duo" ou "annee"


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
	sheet.custom_minimum_size = Vector2(640, 0)
	sheet.rotation = -0.012
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	BD.content(sheet).add_child(col)

	col.add_child(BD.label("MODE DE JEU", 30, Color("3a5fb0"), true))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	col.add_child(modes)
	for spec in [["annee", "ANNÉE SCOLAIRE"], ["solo", "PARTIE SOLO"], ["duo", "2 JOUEURS"]]:
		var b := BD.sticker(spec[1], Color("2f7fe6"), 26)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: String = spec[0]
		b.pressed.connect(func(): _set_mode(mode))
		modes.add_child(b)
		_mode_buttons[mode] = b

	# Salle de la partie libre : les services construits de l'année (data/campagne.json).
	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 8)
	col.add_child(_level_box)
	_level_box.add_child(BD.label("SERVICE", 30, Color("3a5fb0"), true))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	_level_box.add_child(lrow)
	for service in Campaign.load_data()["services"]:
		if not Campaign.is_playable(service):
			continue
		var path := Campaign.level_path(service)
		var b := BD.sticker(str(service["titre"]).to_upper(), Color("e07a2f"), 21)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _set_level(path))
		lrow.add_child(b)
		_level_buttons[path] = b

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
	_set_mode("annee" if GameConfig.campaign else ("solo" if GameConfig.solo else "duo"))
	_set_difficulty(GameConfig.difficulty)
	Sound.ambience(false)
	Sound.music("musique_menu")


func _set_mode(mode: String) -> void:
	_mode = mode
	GameConfig.solo = mode != "duo"
	for k in _mode_buttons.keys():
		_mode_buttons[k].set_pressed_no_signal(k == mode)
		_mode_buttons[k].modulate = Color.WHITE if k == mode else Color(0.8, 0.8, 0.8, 0.85)
	# Une année en cours garde sa difficulté : on la règle en commençant une nouvelle année.
	var year := CampaignStore.load_year() if mode == "annee" else null
	_difficulty_box.modulate = Color(1, 1, 1, 0.35) if mode == "duo" or year != null else Color.WHITE
	_level_box.visible = mode != "annee"
	_play.text = "À TABLE !" if mode != "annee" else ("CONTINUER L'ANNÉE" if year != null else "COMMENCER L'ANNÉE")
	_play.add_theme_font_size_override("font_size", 60 if mode != "annee" else 46)
	_set_difficulty(GameConfig.difficulty)


func _set_level(path: String) -> void:
	if not _level_buttons.has(path):
		path = _level_buttons.keys()[0]
	GameConfig.level_path = path
	for k in _level_buttons.keys():
		_level_buttons[k].set_pressed_no_signal(k == path)
		_level_buttons[k].modulate = Color.WHITE if k == path else Color(0.8, 0.8, 0.8, 0.85)


func _on_play() -> void:
	GameConfig.campaign = _mode == "annee"
	if _mode == "annee":
		if CampaignStore.load_year() == null:
			CampaignStore.save_year(Campaign.new_year(GameConfig.difficulty, GameData.load_default().student_names()))
		open_campaign.emit()
	else:
		start_game.emit()


func _set_difficulty(key: String) -> void:
	if _mode == "annee" and CampaignStore.load_year() != null:
		key = CampaignStore.load_year().difficulty()
	GameConfig.difficulty = key
	for k in _difficulty_buttons.keys():
		_difficulty_buttons[k].set_pressed_no_signal(k == key)
		_difficulty_buttons[k].modulate = Color.WHITE if k == key else Color(0.8, 0.8, 0.8, 0.85)
	if _mode == "annee":
		var year := CampaignStore.load_year()
		if year != null:
			var s := year.current_service()
			_summary.text = "Année en cours : %s, « %s ». Difficulté « %s »." % [str(s["mois"]).to_lower(), s["titre"], GameSetup.difficulties()[key]["nom"]]
		else:
			_summary.text = "La même bande toute l'année, de septembre à juin : expérience, colles et bulletin. " + str(GameSetup.difficulties()[key]["resume"])
	elif GameConfig.solo:
		_summary.text = str(GameSetup.difficulties()[key]["resume"])
	else:
		_summary.text = "Chacun sa bande, à tour de rôle. Un écran « passe la main » cache le jeu entre deux tours."
