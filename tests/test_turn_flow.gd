extends TestCase
## Enchaînement des tours, fin de partie et sonnerie.

const HALL := [
	"##########",
	"D........#",
	"#........#",
	"#........#",
	"##########",
]


func _two_teams() -> GameState:
	var s := make_state(HALL)
	s.team_count = 2
	s.add_student("Ledur", 0, Vector2i(2, 2))
	s.add_student("Grobill", 1, Vector2i(7, 2))
	TurnFlow.start_game(s)
	return s


func test_les_bandes_jouent_a_tour_de_role() -> void:
	var s := _two_teams()
	assert_eq(s.current_team, 0)
	assert_eq(s.turn, 1)
	TurnFlow.end_team_turn(s)
	assert_eq(s.current_team, 1)
	assert_eq(s.turn, 1)
	var events := TurnFlow.end_team_turn(s)
	assert_eq(s.current_team, 0)
	assert_eq(s.turn, 2)
	assert_eq(events.back()["type"], "turn")


func test_les_profs_agissent_en_fin_de_manche() -> void:
	var s := _two_teams()
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(4, 1))
	TurnFlow.end_team_turn(s)
	assert_eq(prof.pos, Vector2i(4, 1), "après la première bande, les profs attendent")
	TurnFlow.end_team_turn(s)
	assert_true(prof.pos != Vector2i(4, 1), "après la dernière bande, ils avancent")


func test_derniere_bande_dans_la_cantine_gagne() -> void:
	var s := _two_teams()
	s.remove_from_board(s.team_units(1)[0])
	var o := s.outcome()
	assert_true(o["over"])
	assert_eq(o["winner"], 0)
	assert_eq(o["reason"], "dernier")


func test_les_neutres_rallies_ne_comptent_pas() -> void:
	var s := _two_teams()
	var n := s.add_unit(Unit.Kind.NEUTRAL, "neutre", Vector2i(5, 3), 1)
	n.rallied = true
	s.remove_from_board(s.students_left(1)[0])
	assert_eq(s.outcome()["winner"], 0)


func test_sonnerie_la_bande_au_meilleur_moral_gagne() -> void:
	var s := _two_teams()
	s.turn = s.max_turns()
	assert_false(s.outcome()["over"], "le dernier tour se joue en entier")
	s.turn = s.max_turns() + 1
	var o := s.outcome()
	assert_true(o["over"])
	assert_eq(o["reason"], "sonnerie")
	assert_eq(o["winner"], 1, "Grobill (90) a plus de moral que Ledur (50)")


func test_sonnerie_egalite() -> void:
	var s := _two_teams()
	s.team_units(1)[0].moral = 50
	s.turn = s.max_turns() + 1
	assert_eq(s.outcome()["winner"], -1)


func test_personne_ne_gagne_si_tout_le_monde_est_sorti() -> void:
	var s := _two_teams()
	for u in s.units:
		s.remove_from_board(u)
	var o := s.outcome()
	assert_eq(o["reason"], "personne")
	assert_eq(o["winner"], -1)
