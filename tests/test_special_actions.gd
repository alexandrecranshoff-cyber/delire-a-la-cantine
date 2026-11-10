extends TestCase

const KITCHEN := [
	",,,,,,",
	",B,,,,",
	",,,,,,",
	",,,,,,",
]


func test_capture_reussie_de_1_a_4() -> void:
	var s := make_state(KITCHEN, [4])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(4, 3))
	var e := s.add_student("Ledur", 0, Vector2i(5, 3))
	var r := SpecialActions.attempt_capture(s, prof, e)
	assert_true(r["success"])
	assert_eq(e.status, Unit.Status.CAPTURED)
	assert_eq(e.pos, prof.pos, "l'élève capturé est placé sous le prof")


func test_capture_ratee_sur_5() -> void:
	var s := make_state(KITCHEN, [5])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(4, 3))
	var e := s.add_student("Ledur", 0, Vector2i(5, 3))
	assert_false(SpecialActions.attempt_capture(s, prof, e)["success"])
	assert_eq(e.status, Unit.Status.ACTIVE)


func test_double_prise() -> void:
	var s := make_state(KITCHEN, [3, 2])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(4, 2))
	var a := s.add_student("Ledur", 0, Vector2i(5, 2))
	var b := s.add_student("Grobill", 1, Vector2i(3, 2))
	assert_false(SpecialActions.attempt_double_capture(s, prof, a, b)["success"], "3 : échec")
	assert_eq(a.status, Unit.Status.ACTIVE)
	assert_eq(b.status, Unit.Status.ACTIVE, "échec : aucun n'est pris")
	assert_true(SpecialActions.attempt_double_capture(s, prof, a, b)["success"], "2 : réussi")


func test_prof_sature_relache_sa_victime() -> void:
	var s := make_state(KITCHEN, [1])
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(4, 3))
	var e := s.add_student("Ledur", 0, Vector2i(5, 3))
	SpecialActions.attempt_capture(s, prof, e)
	s.apply_damage(prof, 30)
	assert_eq(e.status, Unit.Status.ACTIVE)
	assert_true(prof.captive_ids.is_empty())


func test_plongeon_du_cuisinier() -> void:
	var s := make_state(KITCHEN, [2])
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(2, 2))
	var e := s.add_student("Bigleux", 0, Vector2i(3, 2))
	var r := SpecialActions.attempt_plunge(s, cook, e)
	assert_true(r["success"])
	assert_eq(e.status, Unit.Status.OUT, "plongé dans le plat du jour")


func test_plongeon_impossible_loin_d_un_bac() -> void:
	var s := make_state(KITCHEN)
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(4, 3))
	var e := s.add_student("Bigleux", 0, Vector2i(5, 3))
	assert_false(SpecialActions.attempt_plunge(s, cook, e)["ok"])


func test_projection_a_trois_eleves() -> void:
	var s := make_state(KITCHEN, [4])
	var victim := s.add_student("Ledur", 1, Vector2i(2, 2))
	var a := s.add_student("Grobill", 0, Vector2i(3, 2))
	var b := s.add_student("Dudugenoux", 0, Vector2i(3, 3))
	var c := s.add_student("Bigleux", 0, Vector2i(2, 3))
	s.start_team_turn(0)
	assert_eq(SpecialActions.cannot_project_reason(s, [a, b], victim), "pas_assez_nombreux")
	var r := SpecialActions.attempt_projection(s, [a, b, c], victim)
	assert_true(r["success"])
	assert_eq(victim.status, Unit.Status.OUT)
	assert_eq(a.ap, 8, "4 PA par participant")


func test_projeter_un_prof_demande_cinq_eleves() -> void:
	var s := make_state(KITCHEN)
	var prof := s.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(2, 2))
	assert_eq(SpecialActions.required_attackers(s, prof), 5)
	var cook := s.add_unit(Unit.Kind.COOK, "cuisinier", Vector2i(4, 2))
	assert_eq(SpecialActions.required_attackers(s, cook), 7)
