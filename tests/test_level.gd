extends TestCase

const PATH := "res://data/niveaux/niveau_1.json"


func test_plan_du_plateau() -> void:
	var lv := Level.load_file(PATH)
	var b := lv.board()
	assert_eq(b.doors().size(), 12, "6 portes de 2 cases")
	assert_eq(b.cells_of(Board.Terrain.TABLE).size(), 8 * 30, "8 tables de 10 x 3")
	assert_eq(b.cells_of(Board.Terrain.TAP).size(), 2, "2 robinets")
	assert_eq(b.cells_of(Board.Terrain.DISH_TUB).size() + b.cells_of(Board.Terrain.TUB).size(), 6, "3 bacs")
	var total := 0
	for t in range(1, 9):
		total += lv.seats(str(t)).size()
	assert_eq(total, 64, "8 places par table")


func test_places_au_contact_de_leur_table() -> void:
	var lv := Level.load_file(PATH)
	var b := lv.board()
	for t in range(1, 9):
		for c in lv.seats(str(t)):
			assert_true(b.is_ground(c), "place %s sur le sol" % c)
			var touches := false
			for n in Board.neighbors8(c):
				if b.is_table(n):
					touches = true
			assert_true(touches, "place %s au contact d'une table" % c)


func test_mise_en_place_a_4_joueurs() -> void:
	var lv := Level.load_file(PATH)
	var s := lv.build_state(GameData.load_default(), DiceRoller.new(1), 4)
	var students := s.units.filter(func(u): return u.kind == Unit.Kind.STUDENT)
	var neutrals := s.units.filter(func(u): return u.kind == Unit.Kind.NEUTRAL)
	assert_eq(students.size(), 24, "4 équipes de 6")
	assert_eq(neutrals.size(), 24)
	assert_eq(s.team_units(0).size(), 6)
	assert_eq(s.winner(), -1)
	# Bande A autour des tables 1 et 4 : Bigleux en premier, à la table 1.
	assert_eq(s.team_units(0)[0].name, "Bigleux")
	assert_true(lv.seats("1").has(s.team_units(0)[0].pos))


func test_mise_en_place_a_2_joueurs() -> void:
	var lv := Level.load_file(PATH)
	var s := lv.build_state(GameData.load_default(), DiceRoller.new(1), 2)
	var neutrals := s.units.filter(func(u): return u.kind == Unit.Kind.NEUTRAL)
	assert_eq(neutrals.size(), 24 + 12, "les élèves des tables libres deviennent neutres")
	assert_eq(s.team_count, 2)


func test_tous_les_pions_sur_des_cases_libres() -> void:
	var lv := Level.load_file(PATH)
	var s := lv.build_state(GameData.load_default(), DiceRoller.new(1), 4)
	var seen := {}
	for u in s.units:
		assert_false(seen.has(u.pos), "deux pions en %s" % u.pos)
		seen[u.pos] = true
		assert_true(s.board.is_ground(u.pos), "%s sur le sol" % u.name)
