extends TestCase

const OPEN := [
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
]


func test_huit_directions_et_douze_pa() -> void:
	var s := make_state(OPEN)
	var u := s.add_student("Ledur", 0, Vector2i(0, 2))
	s.start_team_turn(0)
	assert_eq(u.ap, 12)
	var reach := Movement.reachable(s, u)
	assert_eq(reach[Vector2i(12, 2)], 12)
	assert_false(reach.has(Vector2i(13, 2)))
	# Diagonale = 1 case, comme sur le plateau.
	assert_eq(reach[Vector2i(2, 0)], 2)


func test_deplacement_retire_les_pa() -> void:
	var s := make_state(OPEN)
	var u := s.add_student("Ledur", 0, Vector2i(0, 0))
	s.start_team_turn(0)
	assert_eq(Movement.move(s, u, Vector2i(8, 0)).size(), 8)
	assert_eq(u.ap, 4)
	assert_eq(u.pos, Vector2i(8, 0))
	assert_true(Movement.move(s, u, Vector2i(14, 0)).is_empty(), "plus assez de PA")


func test_on_ne_passe_pas_par_dessus_un_pion() -> void:
	var s := make_state([
		"#.#",
		"#.#",
		"#.#",
	])
	var u := s.add_student("Ledur", 0, Vector2i(1, 1))
	s.add_student("Grobill", 1, Vector2i(1, 0))
	s.add_student("Bigleux", 1, Vector2i(1, 2))
	s.start_team_turn(0)
	assert_true(Movement.reachable(s, u).size() == 1, "coincé entre deux pions dans un couloir")


func test_pas_de_faufilage_en_diagonale_entre_deux_tables() -> void:
	var s := make_state([
		"T.",
		".T",
	])
	var u := s.add_student("Ledur", 0, Vector2i(0, 1))
	s.start_team_turn(0)
	assert_false(Movement.can_step(s, u, Vector2i(0, 1), Vector2i(1, 0)))


func test_monter_et_descendre_coutent_le_tour() -> void:
	var s := make_state([
		"....",
		".TT.",
		"....",
	])
	var u := s.add_student("Ledur", 0, Vector2i(0, 1))
	s.start_team_turn(0)
	Movement.move(s, u, Vector2i(0, 0))
	assert_false(Movement.can_climb(s, u, Vector2i(1, 1)), "il faut tous ses PA")
	s.start_team_turn(0)
	assert_true(Movement.climb(s, u, Vector2i(1, 1)))
	assert_eq(u.ap, 0)
	assert_true(u.has_shot, "pas de tir le tour où l'on monte")
	# Sur la table, on circule librement, mais seulement sur la table.
	s.start_team_turn(0)
	var reach := Movement.reachable(s, u)
	assert_true(reach.has(Vector2i(2, 1)))
	assert_false(reach.has(Vector2i(0, 0)))
	s.start_team_turn(0)
	assert_true(s.must_leave_table(u), "2 tours maximum sur une table")
	assert_true(Movement.descend(s, u, Vector2i(3, 1)) == false, "pas au contact")
	assert_true(Movement.descend(s, u, Vector2i(1, 2)))
	assert_false(u.on_table)


func test_pousser_un_chariot() -> void:
	var s := make_state(OPEN)
	var u := s.add_student("Grobill", 0, Vector2i(0, 0))
	var cart := s.add_unit(Unit.Kind.CART, "chariot", Vector2i(1, 0), Unit.NO_TEAM, "chariot purée")
	s.start_team_turn(0)
	assert_false(Movement.push_cart(s, u, cart, Vector2i(5, 0)), "3 cases maximum")
	assert_true(Movement.push_cart(s, u, cart, Vector2i(4, 0)))
	assert_eq(cart.pos, Vector2i(4, 0))
	assert_true(u.has_shot, "pas de tir pour le pousseur")
