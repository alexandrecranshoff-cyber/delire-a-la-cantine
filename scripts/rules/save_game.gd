class_name SaveGame
extends RefCounted
## Sauvegarde d'une partie : l'état de règles en dictionnaire (JSON), et retour.
## Le plateau ne change pas en cours de partie : on le reconstruit à partir du niveau, puis on
## réapplique les pions, le tour et l'état du générateur de dés. La partie reprend donc à
## l'identique, mêmes dés compris.

const VERSION := 1

const UNIT_FIELDS := ["id", "kind", "name", "team", "status", "moral", "max_moral", "dex_d6", "dex_bonus",
	"ap", "ap_bonus", "has_shot", "on_table", "turns_on_table", "loaded", "rallied", "captor_id"]


static func to_dict(state: GameState) -> Dictionary:
	var units := []
	for u in state.units:
		var d := {}
		for f in UNIT_FIELDS:
			d[f] = u.get(f)
		d["pos"] = [u.pos.x, u.pos.y]
		d["captive_ids"] = Array(u.captive_ids)
		units.append(d)
	var chahut := {}
	for k in state.chahut.keys():
		chahut[str(k)] = int(state.chahut[k])
	return {
		"version": VERSION,
		"turn": state.turn,
		"current_team": state.current_team,
		"team_count": state.team_count,
		"team_turns_done": state.team_turns_done,
		"teachers_spawned": state.teachers_spawned,
		"cook_awake": state.cook_awake,
		"options": state.options.duplicate(true),
		"ai_teams": Array(state.ai_teams),
		"chahut": chahut,
		"next_id": state.next_unit_id(),
		"dice_seed": str(state.dice.rng_seed()),
		"dice_state": str(state.dice.rng_state()),
		"units": units,
	}


## Remplace l'état de `state` (fraîchement construit sur le même niveau) par celui sauvegardé.
## Renvoie false si la sauvegarde est illisible ou d'une autre version.
static func apply(state: GameState, d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION or not d.has("units"):
		return false
	state.turn = int(d["turn"])
	state.current_team = int(d["current_team"])
	state.team_count = int(d["team_count"])
	state.team_turns_done = int(d["team_turns_done"])
	state.teachers_spawned = int(d["teachers_spawned"])
	state.cook_awake = bool(d["cook_awake"])
	state.options = {}
	for k in d["options"].keys():
		var v = d["options"][k]
		# JSON rend les entiers en flottants : on les remet en entiers.
		state.options[k] = int(v) if v is float and v == floorf(v) else v
	state.ai_teams.clear()
	for t in d["ai_teams"]:
		state.ai_teams.append(int(t))
	state.chahut = {}
	for k in d["chahut"].keys():
		state.chahut[int(k)] = int(d["chahut"][k])
	state.units.clear()
	for ud in d["units"]:
		var u := Unit.new()
		for f in UNIT_FIELDS:
			var v = ud.get(f, u.get(f))  # champ absent des anciennes sauvegardes : valeur par défaut
			if f == "name":
				u.set(f, str(v))
			elif typeof(u.get(f)) == TYPE_BOOL:
				u.set(f, bool(v))
			else:
				u.set(f, int(v))
		u.pos = Vector2i(int(ud["pos"][0]), int(ud["pos"][1]))
		for c in ud["captive_ids"]:
			u.captive_ids.append(int(c))
		state.units.append(u)
	state.set_next_unit_id(int(d["next_id"]))
	state.dice.restore(int(d["dice_seed"]), int(d["dice_state"]))
	return true
