extends SceneTree
## Parties simulées, ordinateur contre ordinateur, pour régler la difficulté et la durée.
## godot --headless --path . -s tools/simuler_parties.gd -- [parties=20] [difficulte=normal] [joueur=normal] [niveau=1] [service=decembre]
## « service » : applique la pression d'un service de l'année scolaire (data/campagne.json), sans expérience.
## « joueur » : niveau de l'IA qui tient la place du joueur humain (bande 0).

func _init() -> void:
	var args := {"parties": "20", "difficulte": "normal", "joueur": "normal", "niveau": "1", "service": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var data := GameData.load_default()
	var level := Level.load_file("res://data/niveaux/niveau_%s.json" % args["niveau"])
	var year := Campaign.new_year(args["difficulte"], data.student_names())
	var service := year.service_by_id(args["service"]) if args["service"] != "" else {}
	var diffs := GameSetup.difficulties()
	var n := int(args["parties"])
	var wins := [0, 0, 0]  # joueur, IA, personne
	var turns := 0
	var reasons := {}
	var stats := {"captures": 0, "plongeons": 0, "tirs": 0, "touches": 0, "profs": 0, "actions": 0}
	var t0 := Time.get_ticks_msec()
	for g in n:
		var state := GameSetup.new_game(level, data, 1000 + g, 2, [1], args["difficulte"])
		if not service.is_empty():
			year.prepare_state(state, 0, service)
		var bots := [Opponent.new(0, diffs[args["joueur"]]["ia"], g * 2 + 1), Opponent.new(1, diffs[args["difficulte"]]["ia"], g * 2 + 2)]
		var guard := 0
		while not state.outcome()["over"] and guard < 5000:
			guard += 1
			var ev: Array = bots[state.current_team].play_next(state)
			if ev.is_empty():
				ev = TurnFlow.end_team_turn(state)
			for e in ev:
				stats["actions"] += 1
				match e["type"]:
					"shot":
						stats["tirs"] += 1
						if e["report"]["hit"]: stats["touches"] += 1
					"capture":
						if e["success"]:
							stats["captures"] += 1
							var k := "captures_bande_%d" % state.get_unit(e["victim_id"]).team
							stats[k] = stats.get(k, 0) + 1
					"plunge":
						if e["success"]:
							stats["plongeons"] += 1
							var k := "plongeons_bande_%d" % state.get_unit(e["victim_id"]).team
							stats[k] = stats.get(k, 0) + 1
					"spawn": stats["profs"] += 1
		for u in state.units:
			if u.kind == Unit.Kind.STUDENT and u.team != Unit.NO_TEAM:
				var k := "eleves_restants" if u.status in [Unit.Status.ACTIVE, Unit.Status.CAPTURED] else ("eleves_satures" if u.moral <= 0 else "eleves_emmenes_ou_plonges")
				stats[k] = stats.get(k, 0) + 1
				if u.kind == Unit.Kind.STUDENT and u.moral <= 0:
					var k2 := "satures_bande_%d" % u.team
					stats[k2] = stats.get(k2, 0) + 1
		var o := state.outcome()
		wins[2 if o["winner"] < 0 else o["winner"]] += 1
		reasons[o["reason"]] = reasons.get(o["reason"], 0) + 1
		turns += state.turn
	print("%d parties, niveau %s %s, difficulté %s, joueur simulé %s (%.1f s)" % [n, args["niveau"], args["service"], args["difficulte"], args["joueur"], (Time.get_ticks_msec() - t0) / 1000.0])
	print("  victoires joueur %d, ordinateur %d, personne %d" % wins)
	print("  tours en moyenne %.1f, fins : %s" % [float(turns) / n, reasons])
	for k in stats.keys():
		print("  %s par partie : %.1f" % [k, float(stats[k]) / n])
	quit(0)
