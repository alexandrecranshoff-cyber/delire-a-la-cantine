class_name GameSetup
extends RefCounted
## Prépare une partie : niveau, nombre de bandes, bandes jouées par l'ordinateur, difficulté.

const DIFFICULTY_PATH := "res://data/difficulte.json"


static func difficulties() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIFFICULTY_PATH))


## `ai_teams` : numéros des bandes de l'ordinateur. `difficulty` : clé de difficulte.json ("" = règles du livret).
static func new_game(level: Level, data: GameData, seed_value: int, players: int, ai_teams: Array = [], difficulty: String = "") -> GameState:
	var state := level.build_state(data, DiceRoller.new(seed_value), players)
	for t in ai_teams:
		state.ai_teams.append(int(t))
	if difficulty != "":
		var d: Dictionary = difficulties()[difficulty]
		state.options["prof_periode"] = int(d["prof_periode"])
		state.options["difficulte"] = difficulty
		for u in state.units:
			if u.kind != Unit.Kind.STUDENT:
				continue
			var pct := int(d["moral_ia_pct"]) if state.ai_teams.has(u.team) else int(d["moral_joueur_pct"])
			u.max_moral = int(round(u.max_moral * pct / 100.0))
			u.moral = u.max_moral
	TurnFlow.start_game(state)
	return state
