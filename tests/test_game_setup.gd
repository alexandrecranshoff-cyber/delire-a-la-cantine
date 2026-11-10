extends TestCase
## Mise en place d'une partie, difficultés et adversaire joué par l'ordinateur.


func _level() -> Level:
	return Level.load_file("res://data/niveaux/niveau_1.json")


func test_trois_difficultes() -> void:
	var d := GameSetup.difficulties()
	assert_eq(d["ordre"].size(), 3)
	for key in d["ordre"]:
		assert_true(d[key].has("ia") and d[key].has("prof_periode") and d[key].has("nom"), key)


func test_la_difficulte_regle_le_moral_et_les_profs() -> void:
	var data := GameData.load_default()
	var d := GameSetup.difficulties()
	for key in d["ordre"]:
		var s := GameSetup.new_game(_level(), data, 7, 2, [1], key)
		assert_eq(s.option("prof_periode"), int(d[key]["prof_periode"]))
		for u in s.units:
			if u.kind == Unit.Kind.STUDENT and u.name == "Grobill":
				var pct := int(d[key]["moral_ia_pct"]) if u.team == 1 else int(d[key]["moral_joueur_pct"])
				assert_eq(u.max_moral, int(round(int(data.characters["Grobill"]["moral"]) * pct / 100.0)), key)


func test_meme_graine_meme_partie() -> void:
	var a := _play(11, 40)
	var b := _play(11, 40)
	assert_eq(a, b, "une partie se rejoue à l'identique avec la même graine")


func test_l_ordinateur_joue_une_partie_entiere() -> void:
	var data := GameData.load_default()
	var s := GameSetup.new_game(_level(), data, 3, 2, [0, 1], "normal")
	var profile: Dictionary = GameSetup.difficulties()["normal"]["ia"]
	var bots := [Opponent.new(0, profile, 1), Opponent.new(1, profile, 2)]
	var guard := 0
	while not s.outcome()["over"] and guard < 4000:
		guard += 1
		var ev: Array = bots[s.current_team].play_next(s)
		if ev.is_empty():
			TurnFlow.end_team_turn(s)
	assert_true(s.outcome()["over"], "la partie se termine sans blocage")
	assert_true(s.turn <= s.max_turns() + 1)


func _play(seed_value: int, actions: int) -> String:
	var data := GameData.load_default()
	var s := GameSetup.new_game(_level(), data, seed_value, 2, [0, 1], "normal")
	var profile: Dictionary = GameSetup.difficulties()["normal"]["ia"]
	var bots := [Opponent.new(0, profile, 1), Opponent.new(1, profile, 2)]
	for i in actions:
		if s.outcome()["over"]:
			break
		var ev: Array = bots[s.current_team].play_next(s)
		if ev.is_empty():
			TurnFlow.end_team_turn(s)
	var out := ""
	for u in s.units:
		out += "%d:%d,%d,%d,%d;" % [u.id, u.pos.x, u.pos.y, u.moral, u.status]
	return out
