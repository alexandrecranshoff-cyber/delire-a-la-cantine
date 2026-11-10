class_name TurnFlow
extends RefCounted
## Enchaînement des tours : bande active, puis pions automatiques, puis bande suivante.


static func start_game(state: GameState) -> void:
	state.turn = 1
	state.start_team_turn(_first_playing_team(state, 0))


## Termine le tour de la bande active. Renvoie les événements des pions automatiques.
## Si la partie continue, la bande suivante commence son tour (state.current_team).
static func end_team_turn(state: GameState) -> Array:
	state.team_turns_done += 1
	var events := AutoPawns.run(state)
	if state.outcome()["over"]:
		return events
	var next := state.current_team
	for i in state.team_count:
		next = (next + 1) % state.team_count
		if not state.students_left(next).is_empty():
			break
	if next <= state.current_team:
		state.turn += 1
	if state.outcome()["over"]:
		return events
	state.start_team_turn(next)
	events.append({"type": "turn", "team": next, "turn": state.turn})
	return events


static func _first_playing_team(state: GameState, from: int) -> int:
	for i in state.team_count:
		var t := (from + i) % state.team_count
		if not state.students_left(t).is_empty():
			return t
	return from
