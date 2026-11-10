class_name Movement
extends RefCounted
## Déplacements : 8 directions, 1 PA par case, jamais par-dessus un pion,
## pas de passage en diagonale entre deux obstacles. Monter ou descendre d'une table coûte le tour.


## Une case est-elle praticable pour ce pion, compte tenu de sa position (sol ou table) ?
static func _can_stand(state: GameState, unit: Unit, c: Vector2i, on_table: bool) -> bool:
	if on_table:
		if not state.board.is_table(c):
			return false
	elif not state.board.is_ground(c):
		return false
	var other := state.unit_at(c)
	return other == null or other == unit


## Pas élémentaire d'une case à une case voisine.
static func can_step(state: GameState, unit: Unit, from: Vector2i, to: Vector2i) -> bool:
	if not Board.adjacent(from, to):
		return false
	if not _can_stand(state, unit, to, unit.on_table):
		return false
	var d := to - from
	if d.x != 0 and d.y != 0 and not unit.on_table:
		# On ne se faufile pas en diagonale entre deux obstacles (tables, murs, bacs).
		var side_a := Vector2i(to.x, from.y)
		var side_b := Vector2i(from.x, to.y)
		if state.board.is_obstacle(side_a) and state.board.is_obstacle(side_b):
			return false
	return true


## Cases atteignables avec `budget` PA (par défaut les PA du pion) : case -> coût.
static func reachable(state: GameState, unit: Unit, budget: int = -1) -> Dictionary:
	if budget < 0:
		budget = unit.ap
	var step_cost := state.data.ap_cost("deplacement")
	var costs := {unit.pos: 0}
	var frontier: Array[Vector2i] = [unit.pos]
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			var cost: int = costs[c] + step_cost
			if cost > budget:
				continue
			for n in Board.neighbors8(c):
				if costs.has(n) or not can_step(state, unit, c, n):
					continue
				costs[n] = cost
				next.append(n)
		frontier = next
	return costs


## Plus court chemin (cases après le départ, arrivée comprise). Vide si inaccessible.
static func path_to(state: GameState, unit: Unit, dest: Vector2i, budget: int = 1 << 20) -> Array[Vector2i]:
	var came := {unit.pos: unit.pos}
	var frontier: Array[Vector2i] = [unit.pos]
	var steps := 0
	while not frontier.is_empty() and not came.has(dest) and steps < budget:
		steps += 1
		var next: Array[Vector2i] = []
		for c in frontier:
			for n in Board.neighbors8(c):
				if came.has(n) or not can_step(state, unit, c, n):
					continue
				came[n] = c
				next.append(n)
		frontier = next
	var path: Array[Vector2i] = []
	if not came.has(dest) or dest == unit.pos:
		return path
	var cur := dest
	while cur != unit.pos:
		path.push_front(cur)
		cur = came[cur]
	return path


## Déplace le pion et retire les PA. Renvoie le chemin suivi (vide si refusé).
static func move(state: GameState, unit: Unit, dest: Vector2i) -> Array[Vector2i]:
	var path := path_to(state, unit, dest)
	var cost := path.size() * state.data.ap_cost("deplacement")
	if path.is_empty() or cost > unit.ap:
		return [] as Array[Vector2i]
	unit.ap -= cost
	unit.pos = dest
	state.refresh_loaded(unit)
	return path


## Monter sur une table : depuis une case au contact, avec tous ses PA. Pas de tir ce tour.
static func can_climb(state: GameState, unit: Unit, table_cell: Vector2i) -> bool:
	return (not unit.on_table
		and unit.ap == state.data.ap_per_turn()
		and Board.adjacent(unit.pos, table_cell)
		and state.board.is_table(table_cell)
		and not state.is_occupied(table_cell))


static func climb(state: GameState, unit: Unit, table_cell: Vector2i) -> bool:
	if not can_climb(state, unit, table_cell):
		return false
	_spend_whole_turn(unit)
	unit.pos = table_cell
	unit.on_table = true
	unit.turns_on_table = 0
	state.refresh_loaded(unit)
	return true


## Descendre : un tour complet, vers une case de sol au contact.
static func can_descend(state: GameState, unit: Unit, floor_cell: Vector2i) -> bool:
	return (unit.on_table
		and unit.ap == state.data.ap_per_turn()
		and Board.adjacent(unit.pos, floor_cell)
		and state.board.is_ground(floor_cell)
		and not state.is_occupied(floor_cell))


static func descend(state: GameState, unit: Unit, floor_cell: Vector2i) -> bool:
	if not can_descend(state, unit, floor_cell):
		return false
	_spend_whole_turn(unit)
	unit.pos = floor_cell
	unit.on_table = false
	unit.turns_on_table = 0
	state.refresh_loaded(unit)
	return true


static func _spend_whole_turn(unit: Unit) -> void:
	unit.ap = 0
	unit.has_shot = true


## Pousser un chariot au contact, de 3 cases au plus. Pas de tir pour le pousseur ce tour.
static func push_cart(state: GameState, pusher: Unit, cart: Unit, dest: Vector2i) -> bool:
	var cost := state.data.ap_cost("pousser_chariot")
	if cart.kind != Unit.Kind.CART or pusher.has_shot or pusher.ap < cost:
		return false
	if not Board.adjacent(pusher.pos, cart.pos):
		return false
	var path := path_to(state, cart, dest)
	if path.is_empty() or path.size() > int(state.data.rules["chariot_cases_max"]):
		return false
	cart.pos = dest
	pusher.ap -= cost
	pusher.has_shot = true
	return true
