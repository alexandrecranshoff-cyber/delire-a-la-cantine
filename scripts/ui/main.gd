extends Node
## Scène principale : écran titre, puis partie.

var _current: Node


func _ready() -> void:
	add_child(Sound.new())
	# Lancement direct d'une partie : godot --path . -- partie [facile|normal|difficile] [graine=N]
	var args := OS.get_cmdline_user_args()
	for a in args:
		# Capture d'écran automatique (contrôle visuel) : capture=fichier.png attente=secondes
		if a.begins_with("capture="):
			_capture_later(a.split("=")[1], args)
	if args.has("annee_ecran"):
		GameConfig.show_bulletin = args.has("bulletin")
		_show_campaign()  # contrôle visuel de l'écran de l'année
		return
	if args.has("partie"):
		for a in args:
			if GameSetup.difficulties().has(a):
				GameConfig.difficulty = a
			if a.begins_with("graine="):
				GameConfig.seed_value = int(a.split("=")[1])
			if a == "duo":
				GameConfig.solo = false
			if a == "annee":
				GameConfig.campaign = true  # essais : service en cours de l'année scolaire
			if a.begins_with("niveau="):
				GameConfig.level_path = "res://data/niveaux/niveau_%s.json" % a.split("=")[1]
			if a == "reprendre":
				GameConfig.pending_load = SaveSlots.all().get("auto", {})  # essais : reprise automatique
		_show_game()
	else:
		_show_menu()


func _swap(node: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)


func _show_menu() -> void:
	var layer := CanvasLayer.new()
	var menu := Menu.new()
	layer.add_child(menu)
	menu.start_game.connect(_show_game)
	menu.open_campaign.connect(_show_campaign)
	_swap(layer)
	if OS.get_cmdline_user_args().has("sauvegardes"):
		menu.add_child(SavePanel.new(false))  # contrôle visuel de la fenêtre des sauvegardes


func _show_game() -> void:
	var game := GameView.new()
	game.back_to_menu.connect(_show_menu)
	game.replay.connect(_show_game)
	game.campaign_next.connect(_show_campaign)
	_swap(game)


## Écran de l'année scolaire (campagne solo).
func _show_campaign() -> void:
	var year := CampaignStore.load_year()
	if year == null:
		year = Campaign.new_year(GameConfig.difficulty, GameData.load_default().student_names())
		CampaignStore.save_year(year)
	var layer := CanvasLayer.new()
	var screen := CampaignScreen.new(year)
	layer.add_child(screen)
	screen.play_service.connect(func():
		GameConfig.campaign = true
		GameConfig.last_gains = {}
		_show_game())
	screen.back_to_menu.connect(func():
		GameConfig.last_gains = {}
		_show_menu())
	_swap(layer)


func _capture_later(file: String, args: Array) -> void:
	var delay := 3.0
	for a in args:
		if a.begins_with("attente="):
			delay = float(a.split("=")[1])
	var count := 1
	var every := 2.0
	for a in args:
		if a.begins_with("nombre="):
			count = int(a.split("=")[1])
		elif a.begins_with("toutes="):
			every = float(a.split("=")[1])
	await get_tree().create_timer(delay, true, false, true).timeout
	for i in count:
		await RenderingServer.frame_post_draw
		var name := file if count == 1 else file.replace(".png", "_%02d.png" % i)
		get_viewport().get_texture().get_image().save_png(name)
		if i < count - 1:
			await get_tree().create_timer(every, true, false, true).timeout
	get_tree().quit()
