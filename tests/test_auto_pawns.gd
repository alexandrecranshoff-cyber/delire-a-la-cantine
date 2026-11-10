extends TestCase
## Pions automatiques du livret : saturés, neutres, profs, cuisinier.

const HALL := [
	"##########",
	"D........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]

const KITCHEN := [
	"##########",
	"D........#",
	"#........#",
	"###..#####",
	"#,,,,,,,,#",
	"#,B,,,,,,#",
	"#,,,,,,,,#",
	"##########",
]


func test_eleve_sature_rejoint_la_sortie() -> void:
	var s := make_state(HALL)
	var e := s.add_student("Ledur", 0, Vector2i(6, 2))
	s.apply_damage(e, 999)
	assert_eq(e.status, Unit.Status.SATURATED)
	AutoPawns.run(s)
	assert_eq(e.status, Unit.Status.OUT, "à 6 cases de la porte : il sort dans le tour")


func test_neutres_partent_au_tour_5() -> void:
	var s := make_state(HALL)
	var n := s.add_unit(Unit.Kind.NEUTRAL, "neutre", Vector2i(8, 1))
	s.turn = 4
	AutoPawns.run(s)
	assert_eq(n.status, Unit.Status.ACTIVE, "tours 1 à 4 : il reste à table")
	s.turn = 5
	AutoPawns.run(s)
	assert_eq(n.status, Unit.Status.FLEEING)
	assert_eq(n.pos, Vector2i(5, 1), "un neutre avance de 3 cases")


func test_prof_poursuit_l_eleve_le_plus_proche() -> void:
	var s := make_state(HALL, [6])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(1, 1))
	var near := s.add_student("Ledur", 0, Vector2i(7, 1))
	s.add_student("Grobill", 1, Vector2i(8, 4))
	s.add_unit(Unit.Kind.NEUTRAL, "neutre", Vector2i(2, 4))
	AutoPawns.run(s)
	assert_eq(Board.distance(prof.pos, near.pos), 2, "4 cases vers l'élève actif le plus proche, pas vers le neutre")
	assert_eq(near.status, Unit.Status.ACTIVE)


func test_prof_capture_puis_emmene_sa_victime() -> void:
	var s := make_state(HALL, [2])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(7, 1))
	var e := s.add_student("Ledur", 0, Vector2i(8, 1))
	s.add_student("Grobill", 0, Vector2i(8, 4))
	AutoPawns.run(s)
	assert_eq(e.status, Unit.Status.CAPTURED, "au contact, 1D6 = 2 : capturé")
	AutoPawns.run(s)
	assert_eq(prof.pos, Vector2i(3, 1), "il emmène sa victime de 4 cases vers la sortie")
	assert_eq(e.pos, prof.pos)
	AutoPawns.run(s)
	assert_eq(prof.status, Unit.Status.OUT)
	assert_eq(e.status, Unit.Status.OUT, "sorti avec le prof")
	assert_eq(s.students_left(0).size(), 1)


func test_entree_d_un_prof_par_la_porte_tiree_au_de() -> void:
	var s := make_state(HALL, [3])
	s.doors = {"3": [Vector2i(0, 1)]}
	s.add_student("Ledur", 0, Vector2i(8, 4))
	s.options["prof_periode"] = 1
	s.team_turns_done = 1
	var events := AutoPawns.run(s)
	var spawn := events.filter(func(e): return e["type"] == "spawn")
	assert_eq(spawn.size(), 1)
	assert_eq(spawn[0]["door"], "3")
	assert_eq(s.teachers_spawned, 1)


func test_prof_periode_espace_les_entrees() -> void:
	var s := make_state(HALL, [3, 3])
	s.doors = {"3": [Vector2i(0, 1)]}
	s.options["prof_periode"] = 2
	s.team_turns_done = 1
	AutoPawns.run(s)
	assert_eq(s.teachers_spawned, 0)
	s.team_turns_done = 2
	AutoPawns.run(s)
	assert_eq(s.teachers_spawned, 1)


func test_cuisinier_dort_tant_que_personne_n_entre() -> void:
	var s := make_state(KITCHEN)
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(6, 5))
	s.add_student("Ledur", 0, Vector2i(3, 2))
	AutoPawns.run(s)
	assert_false(s.cook_awake)
	assert_eq(cook.pos, Vector2i(6, 5))


func test_franchir_le_seuil_reveille_le_cuisinier() -> void:
	var s := make_state(KITCHEN)
	s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(7, 6))
	var e := s.add_student("Ledur", 0, Vector2i(3, 2))
	s.start_team_turn(0)
	var events := GameActions.move(s, e, Vector2i(3, 4))
	assert_true(s.cook_awake)
	assert_eq(events.back()["type"], "cook_wakes")


func test_cuisinier_plonge_l_eleve_pres_d_un_bac() -> void:
	var s := make_state(KITCHEN, [1])
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(6, 5))
	var e := s.add_student("Bigleux", 0, Vector2i(3, 4))
	s.cook_awake = true
	var events := AutoPawns.run(s)
	assert_true(Board.adjacent(cook.pos, Vector2i(3, 4)), "il avance de 3 cases jusqu'au contact")
	assert_eq(e.status, Unit.Status.OUT, "plongé dans le plat du jour")
	assert_eq(events.back()["type"], "plunge")


func test_cuisinier_reste_en_cuisine() -> void:
	var s := make_state(KITCHEN)
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(4, 4))
	s.add_student("Ledur", 0, Vector2i(8, 1))
	s.cook_awake = true
	for i in 3:
		AutoPawns.run(s)
	assert_true(s.board.is_kitchen(cook.pos))


func test_sans_les_adultes_seuls_les_fuyards_bougent() -> void:
	var s := make_state(HALL)
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(1, 1))
	s.add_student("Ledur", 0, Vector2i(8, 1))
	AutoPawns.run(s, false)
	assert_eq(prof.pos, Vector2i(1, 1))


func test_cases_a_portee_d_un_prof() -> void:
	var s := make_state(HALL)
	s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(1, 1))
	var threat := AutoPawns.threat_cells(s)
	assert_true(threat.has(Vector2i(6, 1)), "4 cases de marche, puis le contact")
	assert_false(threat.has(Vector2i(7, 1)), "à plus de 5 cases, on est tranquille pour ce tour")
