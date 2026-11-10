class_name Pathing
extends RefCounted
## Chemins des pions automatiques et de l'IA : champs de distance sur le sol et avancée vers un but
## malgré les pions qui bouchent le passage.


## Distance au sol (en pas, 8 directions) depuis un ensemble de cases, en ignorant les pions.
## `only_kitchen` limite le champ aux cases de cuisine (le cuisinier ne quitte pas sa cuisine).
static func field(board: Board, sources: Array, only_kitchen: bool = false) -> Dictionary:
	var dist := {}
	var frontier: Array[Vector2i] = []
	for s in sources:
		if board.is_ground(s) and not dist.has(s):
			dist[s] = 0
			frontier.append(s)
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			var d: int = dist[c] + 1
			for n in Board.neighbors8(c):
				if dist.has(n) or not board.is_ground(n):
					continue
				if only_kitchen and not board.is_kitchen(n):
					continue
				var step := n - c
				if step.x != 0 and step.y != 0 and board.is_obstacle(Vector2i(n.x, c.y)) and board.is_obstacle(Vector2i(c.x, n.y)):
					continue
				dist[n] = d
				next.append(n)
		frontier = next
	return dist


## Cases de sol au contact d'une case (pour approcher un pion ou un meuble).
static func ground_around(board: Board, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in Board.neighbors8(c):
		if board.is_ground(n):
			out.append(n)
	return out


## Fait avancer le pion d'au plus `steps` cases vers le but décrit par `goal_field` (champ de distance
## nul sur les cases visées). Renvoie le chemin suivi (vide si le pion ne peut pas se rapprocher).
## `stop_on_door` : le pion s'arrête sur la première porte rencontrée (il sort).
static func advance(state: GameState, unit: Unit, goal_field: Dictionary, steps: int, stop_on_door: bool = false, only_kitchen: bool = false) -> Array[Vector2i]:
	var came := {unit.pos: unit.pos}
	var cost := {unit.pos: 0}
	var frontier: Array[Vector2i] = [unit.pos]
	var best := unit.pos
	var best_value: int = goal_field.get(unit.pos, 1 << 20)
	var depth := 0
	while not frontier.is_empty() and depth < steps and best_value > 0:
		depth += 1
		var next: Array[Vector2i] = []
		for c in frontier:
			if stop_on_door and state.board.is_door(c) and c != unit.pos:
				continue
			for n in Board.neighbors8(c):
				if came.has(n) or not Movement.can_step(state, unit, c, n):
					continue
				if only_kitchen and not state.board.is_kitchen(n):
					continue
				came[n] = c
				cost[n] = depth
				next.append(n)
				var v: int = goal_field.get(n, 1 << 20)
				if v < best_value:
					best_value = v
					best = n
		frontier = next
	var path: Array[Vector2i] = []
	var cur := best
	while cur != unit.pos:
		path.push_front(cur)
		cur = came[cur]
	if not path.is_empty():
		unit.pos = best
	return path
