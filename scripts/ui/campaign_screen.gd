class_name CampaignScreen
extends Control
## Année scolaire : calendrier des services, fiches des six élèves (expérience et améliorations),
## lancement du service du mois, bulletin de fin de trimestre. Les règles sont dans Campaign.

signal play_service
signal back_to_menu

const MONTH_COLORS := {"gagne": Color("36b25a"), "actuel": Color("e23b30"), "a_venir": Color("2f7fe6"), "bientot": Color("8a8a8a")}

var campaign: Campaign
var _data: GameData
var _body: VBoxContainer
var _overlay: Control


func _init(p_campaign: Campaign) -> void:
	campaign = p_campaign


func _ready() -> void:
	_data = GameData.load_default()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = GameAssets.ui_texture("ecrans", "titre.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.07, 0.16, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var sheet := BD.paper_panel(24)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.custom_minimum_size = Vector2(1780, 0)
	sheet.rotation = -0.006
	add_child(sheet)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	BD.content(sheet).add_child(_body)
	_rebuild()
	Sound.ambience(false)
	Sound.music("musique_menu")
	if GameConfig.show_bulletin:
		GameConfig.show_bulletin = false
		_show_bulletin.call_deferred()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var diffs := GameSetup.difficulties()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	_body.add_child(head)
	var title := BD.label(str(campaign.data["nom"]).to_upper(), 54, BD.RED, true)
	BD.outline(title, 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var diff_key := campaign.difficulty()
	head.add_child(BD.label("Difficulté : %s" % (diffs[diff_key]["nom"] if diffs.has(diff_key) else diff_key), 30, Color("3a5fb0"), true))

	_body.add_child(_calendar())
	_body.add_child(_service_box())
	_body.add_child(BD.label("LA BANDE", 30, Color("3a5fb0"), true))
	var help := BD.label("Après chaque service, les élèves gagnent des points : tirs réussis, adversaires saturés, rester à table jusqu'au bout, victoire. Dépense-les ici. Un élève emmené par un prof ou plongé dans un bac est collé : il commence le service suivant avec moins de moral.", 22)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(1700, 0)
	_body.add_child(help)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	_body.add_child(cards)
	for name in _names():
		cards.add_child(_student_card(name))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var service := campaign.current_service()
	var play := BD.sticker("À TABLE ! (%s)" % str(service["mois"]).to_upper(), BD.RED, 44)
	play.disabled = not Campaign.is_playable(service)
	play.pressed.connect(func(): play_service.emit())
	row.add_child(play)
	if campaign.progress["termine"]:
		var report := BD.sticker("BULLETIN DU TRIMESTRE", Color("f0a020"), 30)
		report.pressed.connect(_show_bulletin)
		row.add_child(report)
	var fresh := BD.sticker("NOUVELLE ANNÉE", Color("7a5fc0"), 26)
	fresh.pressed.connect(_confirm_new_year)
	row.add_child(fresh)
	var menu := BD.sticker("MENU", Color("6b6b6b"), 26)
	menu.pressed.connect(func(): back_to_menu.emit())
	row.add_child(menu)


## Les six mois de l'année : gagnés, mois en cours, à venir, pas encore construits.
func _calendar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var current := campaign.service_index()
	var i := 0
	for s in campaign.services():
		var state := "a_venir"
		if campaign.is_won(s["id"]):
			state = "gagne"
		elif i == current:
			state = "actuel"
		elif not Campaign.is_playable(s):
			state = "bientot"
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", BD.flat_box(MONTH_COLORS[state], 10, 10, 4 if state != "actuel" else 6))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if state == "bientot":
			box.modulate = Color(1, 1, 1, 0.7)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		box.add_child(col)
		var month := BD.label(str(s["mois"]).to_upper(), 30, Color.WHITE, true)
		BD.outline(month, 6)
		month.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(month)
		var sub := {"gagne": "✓ " + str(s["titre"]), "actuel": "► " + str(s["titre"]), "a_venir": str(s["titre"]), "bientot": "bientôt"}
		var t := BD.label(sub[state], 22, Color.WHITE)
		BD.outline(t, 4)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
		row.add_child(box)
		i += 1
	return row


func _service_box() -> Control:
	var s := campaign.current_service()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", BD.flat_box(Color("fff3c4"), 14, 8, 3))
	var col := VBoxContainer.new()
	box.add_child(col)
	var won_all: bool = campaign.progress["termine"] and campaign.is_won(s["id"])
	var line := "%s : « %s »" % [str(s["mois"]), str(s["titre"])]
	if won_all:
		line = "Premier trimestre terminé ! La suite de l'année arrive bientôt."
	col.add_child(BD.label(line, 34, BD.INK, true))
	var text := str(s["resume"])
	if not won_all and Campaign.is_playable(s):
		var lv := Level.load_file(Campaign.level_path(s))
		if lv.menu_name() != "":
			text += "  Menu : %s." % lv.menu_name().to_lower()
	if won_all:
		text = "Tu peux rejouer décembre pour gagner encore des points, ou lire le bulletin."
	var r := BD.label(text, 24)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(1680, 0)
	col.add_child(r)
	if not GameConfig.last_gains.is_empty():
		var g: Dictionary = GameConfig.last_gains
		var msg := "Service gagné ! Le mois suivant est ouvert." if bool(g.get("gagne", false)) else "Service perdu : il faut le refaire. Les points gagnés sont gardés."
		col.add_child(BD.label(msg, 26, Color("2c9a3f") if bool(g.get("gagne", false)) else BD.RED, true))
	return box


func _student_card(name: String) -> Control:
	var e := campaign.student(name)
	var base: Dictionary = _data.characters[name]
	var s := campaign.sheet(name, base)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", BD.flat_box(Color.WHITE, 10, 8, 3))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var face := TextureRect.new()
	var u := Unit.new()
	u.kind = Unit.Kind.STUDENT
	u.name = name
	u.team = 0
	face.texture = GameAssets.portrait(u)
	face.custom_minimum_size = Vector2(92, 92)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(face)
	var names := VBoxContainer.new()
	top.add_child(names)
	names.add_child(BD.label(name.to_upper(), 30, BD.TEAM_COLORS[0], true))
	var pts := BD.label("%d point%s" % [int(e["xp"]), "s" if int(e["xp"]) > 1 else ""], 26, Color("3a5fb0"), true)
	names.add_child(pts)
	var gains: Dictionary = GameConfig.last_gains.get("eleves", {})
	if gains.has(name):
		names.add_child(BD.label("+%d ce service" % int(gains[name]["xp"]), 20, Color("2c9a3f")))
	if bool(e["colle"]):
		var stamp := BD.label("COLLÉ !", 26, BD.RED, true)
		stamp.rotation = -0.08
		names.add_child(stamp)
	var dex := "%dD%s" % [s["dex_d6"], ("+%d" % s["dex_bonus"]) if s["dex_bonus"] > 0 else ""]
	col.add_child(BD.label("Moral %d · Adresse %s · %d PA" % [s["moral"], dex, _data.ap_per_turn() + int(s["ap_bonus"])], 22))
	for kind in Campaign.UPGRADES:
		var info: Dictionary = campaign.data["ameliorations"][kind]
		var level := int(e[kind])
		var label := "%s  (%d pts)" % [str(info["nom"]).to_upper(), int(info["cout"])]
		if level >= campaign.upgrade_max(kind):
			label = "%s : MAXIMUM" % str(info["nom"]).to_upper()
		var b := BD.sticker(label, Color("36b25a"), 18)
		b.disabled = not campaign.can_upgrade(name, kind)
		var k: String = kind
		b.pressed.connect(func():
			if campaign.upgrade(name, k):
				CampaignStore.save_year(campaign)
				Sound.play("lancer", -6.0)
				_rebuild())
		col.add_child(b)
	return card


func _confirm_new_year() -> void:
	var bg := _dim()
	var sheet := _center_sheet(bg, 820)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	BD.content(sheet).add_child(col)
	var t := BD.label("Recommencer l'année ? Les points et les services gagnés seront perdus.", 30)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(760, 0)
	col.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	var diffs := GameSetup.difficulties()
	for key in diffs["ordre"]:
		var b := BD.sticker(str(diffs[key]["nom"]).to_upper(), Color("7a5fc0"), 26)
		var k: String = key
		b.pressed.connect(func():
			campaign = Campaign.new_year(k, _data.student_names())
			CampaignStore.save_year(campaign)
			GameConfig.last_gains = {}
			bg.queue_free()
			_rebuild())
		row.add_child(b)
	var cancel := BD.sticker("ANNULER", Color("6b6b6b"), 26)
	cancel.pressed.connect(func(): bg.queue_free())
	row.add_child(cancel)


## Bulletin du premier trimestre : une note et une appréciation par élève.
func _show_bulletin() -> void:
	var bg := _dim()
	var sheet := _center_sheet(bg, 1500)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	BD.content(sheet).add_child(col)
	col.add_child(BD.label("COLLÈGE JULES-FERRY · %s" % str(campaign.data["nom"]).to_upper(), 24, Color("3a5fb0"), true))
	var t := BD.label("BULLETIN DU PREMIER TRIMESTRE", 64, BD.RED, true)
	BD.outline(t, 10)
	col.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["Élève", "Note", "Tirs réussis", "Saturés", "Appréciation"]:
		grid.add_child(BD.label(h, 26, Color("3a5fb0"), true))
	var total := 0
	for name in _names():
		var e := campaign.student(str(name))
		var g := campaign.grade(str(name))
		total += g
		grid.add_child(BD.label(str(name), 30, BD.INK, true))
		grid.add_child(BD.label("%d/20" % g, 32, BD.RED if g < 10 else Color("2c9a3f"), true))
		grid.add_child(BD.label(str(int(e["touches"])), 28))
		grid.add_child(BD.label(str(int(e["satures"])), 28))
		var a := BD.label(campaign.appreciation(str(name)), 24, Color("b3261e"))
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		a.custom_minimum_size = Vector2(760, 0)
		grid.add_child(a)
	col.add_child(grid)
	var avg := float(total) / maxf(1.0, campaign.progress["eleves"].size())
	var verdict := "Avis du conseil de classe : félicitations… de la part des autres élèves." if avg >= 12.0 else "Avis du conseil de classe : encouragements. La cantine n'a pas fini d'entendre parler de vous."
	if avg < 9.0:
		verdict = "Avis du conseil de classe : avertissement pour manque de chahut. Un comble."
	var v := BD.label(verdict, 28)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size = Vector2(1420, 0)
	col.add_child(v)
	var close := BD.sticker("FERMER", Color("6b6b6b"), 30)
	close.pressed.connect(func(): bg.queue_free())
	col.add_child(close)
	Sound.play("victoire", -4.0)


## Élèves dans l'ordre de la fiche du livret.
func _names() -> Array:
	return _data.student_names().filter(func(n): return campaign.progress["eleves"].has(n))


func _dim() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.16, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_overlay = bg
	return bg


func _center_sheet(parent: Control, width: float) -> PanelContainer:
	var sheet := BD.paper_panel(26)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.custom_minimum_size = Vector2(width, 0)
	parent.add_child(sheet)
	return sheet
