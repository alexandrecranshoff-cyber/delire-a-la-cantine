class_name Opponent
extends RefCounted
## Adversaire joué par l'ordinateur. Il joue une bande avec les mêmes actions qu'un joueur
## (GameActions), une action à la fois pour que l'écran puisse les montrer.
## Son niveau vient de data/difficulte.json (clé "ia").

var team: int
var profile: Dictionary
var _rng := RandomNumberGenerator.new()
var _odds: Odds
var _done := {}          # pions qui ont fini leur tour
var _ammo_field := {}
var _turn_key := -1


func _init(p_team: int, p_profile: Dictionary, seed_value: int = 0) -> void:
	team = p_team
	profile = p_profile
	# Hasard de décision séparé des dés du jeu : il ne change pas les jets, seulement les choix.
	_rng.seed = seed_value


func _w(key: String) -> float:
	return float(profile.get(key, 0.0))


## Joue une action de la bande. Renvoie ses événements ; liste vide quand la bande a fini.
func play_next(state: GameState) -> Array:
	if _odds == null:
		_odds = Odds.new(state.data)
	var key := state.team_turns_done
	if key != _turn_key:
		_turn_key = key
		_done.clear()
	_ammo_field = _build_ammo_field(state)
	for guard in 64:
		var unit := _next_unit(state)
		if unit == null:
			return []
		var events := _act(state, unit)
		if not events.is_empty():
			return events
	return []


func _next_unit(state: GameState) -> Unit:
	var best: Unit = null
	for u in state.units:
		if u.team != team or not u.is_controllable() or u.kind == Unit.Kind.CART or _done.has(u.id):
			continue
		# Ceux qui peuvent encore tirer d'abord.
		if best == null or (not u.has_shot and best.has_shot):
			best = u
	return best


func _act(state: GameState, u: Unit) -> Array:
	if u.on_table:
		_done[u.id] = true
		if u.ap == state.max_ap(u):
			for n in Board.neighbors8(u.pos):
				if Movement.can_descend(state, u, n):
					return GameActions.descend(state, u, n)
		return []
	if _rng.randf() < _w("distraction") and not u.has_shot:
		# L'étourdi oublie de viser : il traîne un peu et laisse passer son tour.
		_done[u.id] = true
		return _wander(state, u)
	var shot_cost := state.data.ap_cost("tir")
	if not u.has_shot and u.ap >= shot_cost and (u.dex_d6 > 0 or u.dex_bonus > 0):
		var plan := _best_shot(state, u, u.ap - shot_cost)
		if not plan.is_empty():
			if plan["cell"] != u.pos:
				return GameActions.move(state, u, plan["cell"])
			var target: Unit = plan["target"]
			var events := GameActions.shoot(state, u, target)
			if not events.is_empty():
				return events
	# Sans munition mais au contact d'un robinet : on arrose (livret : portée 5, CX 0, dégâts 1D).
	if not u.has_shot and u.ap >= state.data.ap_cost("arrosage") and state.is_near_tap(u):
		var wet := _water_target(state, u)
		if wet != null:
			var events := GameActions.shoot(state, u, wet, true)
			if not events.is_empty():
				return events
	_done[u.id] = true
	return _reposition(state, u)


## Cible à arroser depuis le robinet : la plus intéressante à portée, de préférence la plus proche.
func _water_target(state: GameState, u: Unit) -> Unit:
	var best: Unit = null
	var best_score := 0.0
	for t in _targets(state):
		var unit: Unit = t["unit"]
		if Combat.cannot_shoot_reason(state, u, unit, true) != "":
			continue
		var score: float = float(t["weight"]) / float(maxi(1, Board.distance(u.pos, unit.pos)))
		if score > best_score:
			best_score = score
			best = unit
	return best


## Meilleur couple (case de tir, cible) atteignable avec `budget` PA de déplacement.
func _best_shot(state: GameState, u: Unit, budget: int) -> Dictionary:
	var reach := Movement.reachable(state, u, budget)
	var targets := _targets(state)
	var best := {}
	var best_score := _w("tir_minimum")
	for cell in reach.keys():
		var has_source := _source_at(state, cell)
		if not (u.loaded or has_source):
			continue
		var cell_bonus := _position_value(state, u, cell, true) * 0.25 - float(reach[cell]) * 0.05
		for t in targets:
			var weight: float = t["weight"]
			var unit: Unit = t["unit"]
			if cell == unit.pos:
				continue
			var d := Board.distance(cell, unit.pos)
			if d > 14 or Trajectory.blocked_by_wall(state.board, cell, unit.pos):
				continue
			var ev := _odds.expected_damage(u.dex_d6, u.dex_bonus, d)
			var score := ev * weight
			if ev * 1.5 >= float(unit.moral):
				score += 4.0 * weight * _w("concentration")
			score += cell_bonus + _rng.randf() * _w("bruit")
			if score > best_score:
				best_score = score
				best = {"cell": cell, "target": unit}
	return best


## Cibles possibles et leur intérêt.
func _targets(state: GameState) -> Array:
	var out := []
	var mine := state.team_units(team)
	for t in state.units:
		if not t.is_on_board() or t.kind == Unit.Kind.CART or t.team == team or t.status == Unit.Status.CAPTURED:
			continue
		var weight := 0.0
		match t.kind:
			Unit.Kind.STUDENT:
				if t.status == Unit.Status.ACTIVE:
					weight = 1.0 + _w("concentration") * (1.0 - float(t.moral) / maxf(1.0, float(t.max_moral))) * 0.6
			Unit.Kind.NEUTRAL:
				if t.status == Unit.Status.BERSERK:
					weight = 0.5
				elif t.rallied and t.status == Unit.Status.ACTIVE:
					weight = 0.7
				elif t.status == Unit.Status.ACTIVE:
					weight = _w("poids_neutre")
			Unit.Kind.TEACHER:
				if t.status == Unit.Status.ACTIVE:
					var holds_mine := false
					for cid in t.captive_ids:
						var v := state.get_unit(cid)
						holds_mine = holds_mine or (v != null and v.team == team)
					if holds_mine:
						weight = 2.5 * _w("poids_prof")
					elif t.captive_ids.is_empty():
						var near := 1 << 20
						for m in mine:
							near = mini(near, Board.distance(m.pos, t.pos))
						weight = _w("poids_prof") * (1.2 if near <= 6 else 0.3)
			Unit.Kind.COOK:
				if t.status == Unit.Status.ACTIVE and state.cook_awake:
					weight = 0.4 * _w("prudence_cuisine")
		if weight > 0.0:
			out.append({"unit": t, "weight": weight})
	return out


func _source_at(state: GameState, cell: Vector2i) -> bool:
	return _ammo_field.get(cell, 1) == 0


## Champ de distance vers les cases où l'on se ravitaille (contact d'une table tant qu'elles sont
## garnies, d'un bac ou d'un chariot).
func _build_ammo_field(state: GameState) -> Dictionary:
	var sources := []
	# Les tables se vident à la fin du tour 4 : inutile d'y retourner au dernier moment.
	var tables_ok := state.turn < int(state.data.rules["tours_munitions_tables"]) or (state.turn == int(state.data.rules["tours_munitions_tables"]) and _w("poids_munitions") < 1.0)
	if state.tables_have_ammo() and tables_ok:
		for c in state.board.cells_of(Board.Terrain.TABLE):
			sources.append_array(Pathing.ground_around(state.board, c))
	for c in state.board.cells_of(Board.Terrain.TUB):
		sources.append_array(Pathing.ground_around(state.board, c))
	for u in state.units:
		if u.kind == Unit.Kind.CART and u.is_on_board():
			sources.append_array(Pathing.ground_around(state.board, u.pos))
	return Pathing.field(state.board, sources)


## Intérêt d'une case pour y finir (ou y tirer) : munitions, profs, cuisinier.
func _position_value(state: GameState, u: Unit, cell: Vector2i, shooting: bool) -> float:
	var value := 0.0
	var ammo_d: int = _ammo_field.get(cell, 40)
	if ammo_d == 0:
		value += 3.0 * _w("poids_munitions")
	elif not shooting:
		value -= float(ammo_d) * 0.5 * _w("poids_munitions") * (1.0 if not u.loaded or u.has_shot else 0.4)
	for t in state.units:
		if not t.is_on_board() or t.status != Unit.Status.ACTIVE:
			continue
		if t.kind == Unit.Kind.TEACHER and t.captive_ids.is_empty():
			var d := Board.distance(cell, t.pos)
			if d <= 6:
				value -= float(7 - d) * 1.5 * _w("poids_prof")
		elif t.kind == Unit.Kind.COOK:
			var d := Board.distance(cell, t.pos)
			if state.cook_awake and d <= 5 and state.board.is_kitchen(cell):
				value -= float(6 - d) * 1.2 * _w("prudence_cuisine")
			elif not state.cook_awake and state.board.is_kitchen(cell) and state.tables_have_ammo():
				value -= 4.0 * _w("prudence_cuisine")
	return value


## Après le tir (ou faute de tir) : se replacer avec les PA restants.
func _reposition(state: GameState, u: Unit) -> Array:
	if u.ap <= 0:
		return []
	var reach := Movement.reachable(state, u)
	var best := u.pos
	var best_score := _position_value(state, u, u.pos, false) + _approach(state, u, u.pos)
	for cell in reach.keys():
		if cell == u.pos:
			continue
		var score := _position_value(state, u, cell, false) + _approach(state, u, cell) - float(reach[cell]) * 0.03 + _rng.randf() * _w("bruit") * 0.3
		if score > best_score + 0.2:
			best_score = score
			best = cell
	if best == u.pos:
		return []
	return GameActions.move(state, u, best)


## Envie de se rapprocher de l'adversaire pour le tour suivant (les tirs lointains ratent).
func _approach(state: GameState, u: Unit, cell: Vector2i) -> float:
	var near := 1 << 20
	for t in state.units:
		if t.kind == Unit.Kind.STUDENT and t.team != team and t.team != Unit.NO_TEAM and t.status == Unit.Status.ACTIVE:
			near = mini(near, Board.distance(cell, t.pos))
	if near == 1 << 20:
		return 0.0
	return -absf(float(near) - 6.0) * 0.25


func _wander(state: GameState, u: Unit) -> Array:
	var reach := Movement.reachable(state, u, mini(u.ap, 4))
	var cells := reach.keys()
	if cells.size() <= 1:
		return []
	var dest: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
	if dest == u.pos:
		return []
	return GameActions.move(state, u, dest)
