extends TestCase

## Salle sans table : le seul moyen de tirer est le robinet du mur de gauche.
const ROOM := [
	"#.......",
	"R.......",
	"#.......",
]


func _bot(team: int) -> Opponent:
	var profile: Dictionary = GameSetup.difficulties()["difficile"]["ia"]
	return Opponent.new(team, profile, 7)


func test_ia_arrose_au_robinet_sans_munition() -> void:
	# Livret : un personnage au contact d'un robinet peut tirer en arrosant (portée 5, CX 0).
	var s := make_state(ROOM, [6, 6, 6, 6])
	var tireur := s.add_student("Grobill", 1, Vector2i(1, 1))
	var cible := s.add_student("Bigleux", 0, Vector2i(4, 1))
	s.start_team_turn(1)
	var events := _bot(1).play_next(s)
	var shot := {}
	for e in events:
		if e["type"] == "shot":
			shot = e
	assert_true(not shot.is_empty(), "l'ordinateur tire depuis le robinet")
	if shot.is_empty():
		return
	assert_true(shot["report"]["watering"], "le tir est un arrosage")
	assert_eq(shot["report"]["target_id"], cible.id)
	assert_true(tireur.has_shot)


func test_ia_n_arrose_pas_hors_de_portee() -> void:
	var s := make_state(ROOM, [6, 6, 6, 6])
	s.add_student("Grobill", 1, Vector2i(1, 1))
	s.add_student("Bigleux", 0, Vector2i(7, 1))
	s.start_team_turn(1)
	var bot := _bot(1)
	for i in 6:
		for e in bot.play_next(s):
			assert_true(e["type"] != "shot", "pas de tir à plus de 5 cases du robinet")
