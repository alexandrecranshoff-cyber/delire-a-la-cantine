extends TestCase
## Sauvegarde et reprise d'une partie.


func _level() -> Level:
	return Level.load_file("res://data/niveaux/niveau_1.json")


func _advance(s: GameState, bots: Array, actions: int) -> void:
	for i in actions:
		if s.outcome()["over"]:
			break
		var ev: Array = bots[s.current_team].play_next(s)
		if ev.is_empty():
			TurnFlow.end_team_turn(s)


func _bots(seed_value: int) -> Array:
	var profile: Dictionary = GameSetup.difficulties()["normal"]["ia"]
	return [Opponent.new(0, profile, seed_value), Opponent.new(1, profile, seed_value + 1)]


func test_une_partie_reprise_continue_a_l_identique() -> void:
	var data := GameData.load_default()
	var a := GameSetup.new_game(_level(), data, 21, 2, [0, 1], "difficile")
	_advance(a, _bots(5), 60)
	# Aller-retour par du texte JSON, comme sur le disque.
	var saved = JSON.parse_string(JSON.stringify(SaveGame.to_dict(a)))
	var b := GameSetup.new_game(_level(), data, 999, 2, [0, 1], "difficile")
	assert_true(SaveGame.apply(b, saved), "sauvegarde lisible")
	assert_eq(JSON.stringify(SaveGame.to_dict(b)), JSON.stringify(SaveGame.to_dict(a)), "même état après reprise")
	# La suite, dés compris, est la même dans les deux parties.
	_advance(a, _bots(9), 80)
	_advance(b, _bots(9), 80)
	assert_eq(JSON.stringify(SaveGame.to_dict(b)), JSON.stringify(SaveGame.to_dict(a)), "même suite de partie")


func test_sauvegarde_d_une_autre_version_refusee() -> void:
	var data := GameData.load_default()
	var s := GameSetup.new_game(_level(), data, 3, 2, [1], "normal")
	var d := SaveGame.to_dict(s)
	d["version"] = 0
	assert_false(SaveGame.apply(s, d))
