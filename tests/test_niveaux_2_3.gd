extends TestCase
## Niveaux 2 (« Jour du poisson ») et 3 (« Repas de Noël ») : plans, menu du jour, flaques.

const LEVELS := ["res://data/niveaux/niveau_2.json", "res://data/niveaux/niveau_3.json"]


func test_plans_complets() -> void:
	for path in LEVELS:
		var lv := Level.load_file(path)
		var b := lv.board()
		assert_eq(b.doors().size(), 12, path + " : 6 portes de 2 cases")
		assert_eq(b.cells_of(Board.Terrain.TABLE).size(), 8 * 30, path + " : 8 tables de 30 cases")
		assert_eq(b.cells_of(Board.Terrain.TAP).size(), 2, path + " : 2 robinets")
		var total := 0
		for t in range(1, 9):
			for c in lv.seats(str(t)):
				total += 1
				assert_true(b.is_ground(c) and not b.is_puddle(c), "%s : place %s sur le sol sec" % [path, c])
				var touches := false
				for n in Board.neighbors8(c):
					if b.is_table(n):
						touches = true
				assert_true(touches, "%s : place %s au contact d'une table" % [path, c])
		assert_eq(total, 64, path)
		for v in lv.raw["places_neutres"]:
			assert_true(b.is_ground(Vector2i(int(v[0]), int(v[1]))), path + " : case N")


func test_mise_en_place_solo() -> void:
	for path in LEVELS:
		var s := GameSetup.new_game(Level.load_file(path), GameData.load_default(), 3, 2, [1], "normal")
		assert_eq(s.team_units(0).size(), 6, path)
		assert_eq(s.team_units(1).size(), 6, path)
		var positions := {}
		for u in s.units:
			assert_false(positions.has(u.pos), "%s : deux pions sur %s" % [path, u.pos])
			positions[u.pos] = true


func test_chariot_de_poisson_dans_la_salle() -> void:
	var s := GameSetup.new_game(Level.load_file(LEVELS[0]), GameData.load_default(), 3, 2, [1], "normal")
	var carts := s.units.filter(func(u): return u.kind == Unit.Kind.CART)
	assert_eq(carts.size(), 3)
	var in_room := carts.filter(func(u): return not s.board.is_kitchen(u.pos))
	assert_eq(in_room.size(), 1, "un chariot hors de la cuisine")


func test_menu_du_jour() -> void:
	var data := GameData.load_default()
	var hareng: String = data.projectile("3")["nom"]
	GameSetup.new_game(Level.load_file(LEVELS[0]), data, 3, 2, [1], "normal")
	assert_eq(data.projectile("3")["nom"], "poisson pané")
	assert_eq(data.projectile("3")["image"], "poisson")
	assert_eq(data.projectile("8")["nom"], GameData.load_default().projectile("8")["nom"], "les autres plats restent")
	assert_true(hareng != "poisson pané")
	var noel := GameData.load_default()
	GameSetup.new_game(Level.load_file(LEVELS[1]), noel, 3, 2, [1], "normal")
	assert_eq(noel.projectile("12")["nom"], "bûche de Noël")
	assert_false(noel.projectiles.has("_note"))
	# Chaque plat a son dessin.
	for d in [data, noel]:
		for key in d.projectiles.keys():
			var img := str(d.projectiles[key].get("image", key))
			assert_true(ResourceLoader.exists("res://assets/sd/projectiles/projectile_%s.png" % img), img)


func test_flaques_coutent_deux_pa() -> void:
	var s := make_state([
		".~~.",
		"....",
	])
	var u := s.add_student("Ledur", 0, Vector2i(0, 0))
	s.start_team_turn(0)
	var flaque := int(s.data.rules["points_action"]["flaque"])
	assert_eq(flaque, 2)
	var reach := Movement.reachable(s, u)
	assert_eq(reach[Vector2i(1, 0)], flaque, "entrer sur une flaque")
	assert_eq(reach[Vector2i(3, 0)], 3, "on contourne par la rangée sèche")
	assert_eq(Movement.path_to(s, u, Vector2i(3, 0)).size(), 3)
	Movement.move(s, u, Vector2i(2, 0))
	assert_eq(u.ap, 12 - 3, "en diagonale puis sur la flaque : 1 + 2")


func test_flaques_du_niveau_3() -> void:
	var lv := Level.load_file(LEVELS[1])
	var b := lv.board()
	var puddles := b.cells_of(Board.Terrain.PUDDLE)
	assert_true(puddles.size() >= 30, "%d flaques" % puddles.size())
	for c in puddles:
		assert_false(b.is_kitchen(c), "pas de flaque en cuisine")
	assert_true(b.is_ground(puddles[0]), "on marche sur une flaque")
	assert_false(b.blocks_shot(puddles[0]), "une flaque n'arrête pas les tirs")


func test_habillage() -> void:
	assert_eq(Level.load_file(LEVELS[1]).decor("sol_salle", "sol_salle.png"), "sol_salle_crade.png")
	assert_eq(Level.load_file("res://data/niveaux/niveau_1.json").decor("sol_salle", "sol_salle.png"), "sol_salle.png")
	for path in LEVELS:
		var decor: Dictionary = Level.load_file(path).raw.get("decor", {})
		for k in decor.keys():
			assert_true(ResourceLoader.exists("res://assets/sd/textures/" + str(decor[k])), str(decor[k]))


func test_cuisine_chaotique_au_niveau_3() -> void:
	var noel := Level.load_file(LEVELS[1])
	assert_eq(noel.decor("sol_cuisine", "sol_cuisine.png"), "sol_cuisine_chaotique.png")
	assert_eq(noel.decor("mur_cuisine", "mur_cuisine.png"), "mur_cuisine_chaotique.png")
	assert_true(noel.kitchen_mess())
	assert_false(Level.load_file(LEVELS[0]).kitchen_mess())
	assert_false(Level.load_file("res://data/niveaux/niveau_1.json").kitchen_mess())
