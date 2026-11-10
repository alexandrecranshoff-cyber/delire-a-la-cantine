class_name Visibility
extends RefCounted
## Ligne de vue et brouillard de guerre : une bande voit ce que voient ses élèves.
## Seuls les murs cachent (comme ils arrêtent les tirs dans le livret).


## Pions dont la bande profite du regard : ses élèves et neutres ralliés encore sur le terrain.
static func watchers(state: GameState, team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in state.units:
		if u.team == team and u.is_on_board() and u.kind != Unit.Kind.CART:
			out.append(u)
	return out


static func can_see(state: GameState, team: int, cell: Vector2i) -> bool:
	for w in watchers(state, team):
		if not Trajectory.blocked_by_wall(state.board, w.pos, cell):
			return true
	return false


## Un pion est-il visible pour cette bande ? Ses propres pions le sont toujours.
static func unit_visible(state: GameState, team: int, u: Unit) -> bool:
	if u.team == team:
		return true
	return can_see(state, team, u.pos)


## Cases de sol cachées à la bande (pour griser le décor).
static func hidden_cells(state: GameState, team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var ws := watchers(state, team)
	for y in state.board.height:
		for x in state.board.width:
			var c := Vector2i(x, y)
			if state.board.terrain(c) == Board.Terrain.WALL:
				continue
			var seen := false
			for w in ws:
				if not Trajectory.blocked_by_wall(state.board, w.pos, c):
					seen = true
					break
			if not seen:
				out.append(c)
	return out
