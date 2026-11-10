extends TestCase

## Plan ouvert de 12 cases avec une table en haut à gauche (source de munitions).
const ROOM := [
	"T...........",
	"............",
	"............",
]


func test_exemple_du_livret_grobill() -> void:
	# Grobill tire à 9 cases. 2D6 = 8 : tripes à la mode de Caen, CX 3, seuil 12.
	# Dextérité 3D = 14 : touché. Dégâts 4D = 18 points de moral.
	var s := make_state(ROOM, [4, 4, 5, 5, 4, 5, 5, 4, 4])
	var grobill := s.add_student("Grobill", 0, Vector2i(0, 1))
	var cible := s.add_student("Dudugenoux", 1, Vector2i(9, 1))
	s.start_team_turn(0)
	var r := Combat.resolve_shot(s, grobill, cible)
	assert_true(r["ok"], str(r.get("reason", "")))
	assert_eq(r["projectile_name"], "tripes à la mode de Caen")
	assert_eq(r["distance"], 9)
	assert_eq(r["threshold"], 12)
	assert_eq(r["dex_roll"]["total"], 14)
	assert_true(r["hit"])
	assert_eq(r["damage"], 18)
	assert_eq(cible.moral, 82)
	assert_eq(grobill.ap, 8, "un tir coûte 4 PA")


func test_un_seul_tir_par_tour() -> void:
	var s := make_state(ROOM, [1, 1, 1])
	var a := s.add_student("Bigleux", 0, Vector2i(0, 1))
	var b := s.add_student("Ledur", 1, Vector2i(5, 1))
	s.start_team_turn(0)
	Combat.resolve_shot(s, a, b)
	assert_eq(Combat.cannot_shoot_reason(s, a, b), "deja_tire")


func test_tir_rate_retombe_sur_un_voisin() -> void:
	# Tir vers la droite raté : la nourriture tombe juste avant la cible (case a).
	var s := make_state(ROOM, [1, 1, 1, 2, 3])  # verre d'eau ; dex 1+1 = 2 < 5+1
	var tireur := s.add_student("Bigleux", 0, Vector2i(0, 1))
	var cible := s.add_student("Ledur", 1, Vector2i(5, 1))
	var voisin := s.add_student("Grobill", 1, Vector2i(4, 1))
	s.start_team_turn(0)
	var r := Combat.resolve_shot(s, tireur, cible)
	assert_false(r["hit"])
	assert_eq(r["victim_id"], voisin.id)
	assert_eq(cible.moral, cible.max_moral, "la cible n'est jamais touchée par un tir raté")
	assert_eq(voisin.moral, voisin.max_moral - 1, "verre d'eau : 1 point fixe")


func test_tir_rate_priorite_hors_trajectoire() -> void:
	# Personne en a ni en b : le pion en position 1 (derrière a, à gauche) est touché avant le 6.
	var s := make_state(ROOM, [1, 1, 1, 2, 4])
	var tireur := s.add_student("Bigleux", 0, Vector2i(0, 1))
	var cible := s.add_student("Ledur", 1, Vector2i(6, 1))
	var en_6 := s.add_student("Grobill", 1, Vector2i(6, 2))
	var en_1 := s.add_student("Zieuglôque", 1, Vector2i(4, 0))
	s.start_team_turn(0)
	var r := Combat.resolve_shot(s, tireur, cible)
	assert_eq(r["victim_id"], en_1.id)
	assert_eq(en_6.moral, en_6.max_moral)


func test_munitions_des_tables_jusqu_au_tour_4() -> void:
	var s := make_state(ROOM)
	var a := s.add_student("Ledur", 0, Vector2i(1, 1))
	var b := s.add_student("Grobill", 1, Vector2i(8, 1))
	s.turn = 5
	s.start_team_turn(0)
	assert_eq(Combat.cannot_shoot_reason(s, a, b), "pas_de_munitions")


func test_encore_un_tir_apres_avoir_quitte_la_table() -> void:
	var s := make_state(ROOM, [1, 1, 1, 1])
	var a := s.add_student("Ledur", 0, Vector2i(1, 1))
	var b := s.add_student("Grobill", 1, Vector2i(11, 2))
	s.start_team_turn(0)
	Movement.move(s, a, Vector2i(5, 1))
	assert_eq(Combat.cannot_shoot_reason(s, a, b), "", "garde sa munition")
	Combat.resolve_shot(s, a, b)
	s.start_team_turn(0)
	assert_eq(Combat.cannot_shoot_reason(s, a, b), "pas_de_munitions")


func test_arrosage_au_robinet() -> void:
	var s := make_state([
		"R.........",
		"..........",
	], [6, 3, 3])
	var a := s.add_student("Ledur", 0, Vector2i(1, 0))
	var loin := s.add_student("Grobill", 1, Vector2i(7, 0))
	var pres := s.add_student("Bigleux", 1, Vector2i(6, 1))
	s.start_team_turn(0)
	assert_eq(Combat.cannot_shoot_reason(s, a, loin, true), "trop_loin", "portée 5 cases")
	var r := Combat.resolve_shot(s, a, pres, true)
	assert_eq(r["threshold"], 5, "CX 0")
	assert_true(r["hit"])
	assert_eq(r["damage"], 3, "dégâts 1D")


func test_saturation_a_zero() -> void:
	var s := make_state(ROOM, [6, 6, 6, 6, 6, 6, 6, 6, 6])  # purée St-Germain, 3D de dégâts
	var a := s.add_student("Dudugenoux", 0, Vector2i(0, 1))
	var b := s.add_student("Bigleux", 1, Vector2i(3, 1))
	b.moral = 10
	s.start_team_turn(0)
	var r := Combat.resolve_shot(s, a, b)
	assert_true(r["saturated"])
	assert_eq(b.status, Unit.Status.SATURATED)


func _neutral_reaction(face: int) -> Unit:
	var s := make_state(ROOM, [1, 1, 6, 6, face])  # verre d'eau, touché, 1 point, puis 1D6
	var a := s.add_student("Ledur", 0, Vector2i(0, 1))
	var n := s.add_unit(Unit.Kind.NEUTRAL, "neutre", Vector2i(3, 1))
	s.start_team_turn(0)
	Combat.resolve_shot(s, a, n)
	return n


func test_neutre_touche_rallie_fuit_ou_berserk() -> void:
	var rallie := _neutral_reaction(1)
	assert_eq(rallie.team, 0)
	assert_true(rallie.rallied)
	assert_eq(_neutral_reaction(3).status, Unit.Status.FLEEING)
	assert_eq(_neutral_reaction(6).status, Unit.Status.BERSERK)


func test_neutre_rallie_ne_compte_pas_pour_la_victoire() -> void:
	var s := make_state(ROOM)
	s.add_student("Ledur", 0, Vector2i(0, 1))
	var n := s.add_unit(Unit.Kind.NEUTRAL, "neutre", Vector2i(3, 1))
	n.team = 1
	n.rallied = true
	assert_eq(s.winner(), 0)
