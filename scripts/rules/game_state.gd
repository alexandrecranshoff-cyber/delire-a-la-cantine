class_name GameState
extends RefCounted
## État complet d'une partie : plateau, pions, tour, dés. Aucune dépendance aux scènes.

var board: Board
var data: GameData
var dice: DiceRoller
var units: Array[Unit] = []
var turn := 1
var current_team := 0
var team_count := 2

var _next_id := 1


func _init(p_board: Board, p_data: GameData, p_dice: DiceRoller) -> void:
	board = p_board
	data = p_data
	dice = p_dice


func add_unit(kind: Unit.Kind, char_key: String, pos: Vector2i, team: int = Unit.NO_TEAM, display_name: String = "") -> Unit:
	var u := Unit.new()
	u.id = _next_id
	_next_id += 1
	u.kind = kind
	u.name = display_name if display_name != "" else char_key
	u.team = team
	u.pos = pos
	if kind != Unit.Kind.CART:
		var c: Dictionary = data.characters[char_key]
		u.max_moral = int(c["moral"])
		u.moral = u.max_moral
		u.dex_d6 = int(c["dexterite"]["d6"])
		u.dex_bonus = int(c["dexterite"]["bonus"])
	units.append(u)
	return u


func add_student(char_key: String, team: int, pos: Vector2i) -> Unit:
	return add_unit(Unit.Kind.STUDENT, char_key, pos, team)


func get_unit(id: int) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null


## Pion qui occupe la case (l'élève capturé, placé sous le prof, ne compte pas).
func unit_at(c: Vector2i) -> Unit:
	for u in units:
		if u.is_on_board() and u.status != Unit.Status.CAPTURED and u.pos == c:
			return u
	return null


func is_occupied(c: Vector2i) -> bool:
	return unit_at(c) != null


func team_units(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.team == team and u.is_on_board():
			out.append(u)
	return out


func tables_have_ammo() -> bool:
	return turn <= int(data.rules["tours_munitions_tables"])


## Cases où l'on prend des munitions : bacs (sauf vaisselle) et chariots.
func is_ammo_container_at(c: Vector2i) -> bool:
	if board.terrain(c) == Board.Terrain.TUB:
		return true
	var u := unit_at(c)
	return u != null and u.kind == Unit.Kind.CART


## Bacs et chariots dans lesquels on peut plonger quelqu'un.
func container_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = board.cells_of(Board.Terrain.TUB)
	out.append_array(board.cells_of(Board.Terrain.DISH_TUB))
	for u in units:
		if u.kind == Unit.Kind.CART and u.is_on_board():
			out.append(u.pos)
	return out


func distance_to_nearest_container(c: Vector2i) -> int:
	var best := 1 << 30
	for k in container_cells():
		best = mini(best, Board.distance(c, k))
	return best


## Le pion a-t-il une source de munitions à portée de main ?
func at_ammo_source(u: Unit) -> bool:
	if u.on_table:
		return tables_have_ammo()
	for n in Board.neighbors8(u.pos):
		if tables_have_ammo() and board.is_table(n):
			return true
		if is_ammo_container_at(n):
			return true
	return false


func is_near_tap(u: Unit) -> bool:
	for n in Board.neighbors8(u.pos):
		if board.is_tap(n):
			return true
	return false


func refresh_loaded(u: Unit) -> void:
	if at_ammo_source(u):
		u.loaded = true


## Début du tour d'une bande : PA rendus, compteur de tours sur table.
func start_team_turn(team: int) -> void:
	current_team = team
	for u in units:
		if u.team != team or not u.is_on_board():
			continue
		u.ap = data.ap_per_turn()
		u.has_shot = false
		if u.on_table:
			u.turns_on_table += 1
		refresh_loaded(u)


## Élève obligé de descendre (temps maximum sur une table écoulé).
func must_leave_table(u: Unit) -> bool:
	return u.on_table and u.turns_on_table >= int(data.rules["tours_max_sur_table"])


## Retire du moral ; à 0, le pion est saturé et un prof relâche ses victimes.
func apply_damage(u: Unit, amount: int) -> bool:
	u.moral = maxi(0, u.moral - amount)
	if u.moral > 0:
		return false
	u.status = Unit.Status.SATURATED
	release_captives(u)
	return true


func release_captives(captor: Unit) -> void:
	for cid in captor.captive_ids:
		var v := get_unit(cid)
		if v == null:
			continue
		v.status = Unit.Status.ACTIVE
		v.captor_id = -1
		v.pos = free_cell_near(captor.pos)
	captor.captive_ids.clear()


func free_cell_near(c: Vector2i) -> Vector2i:
	for n in Board.neighbors8(c):
		if board.is_ground(n) and not is_occupied(n):
			return n
	return c


func remove_from_board(u: Unit) -> void:
	u.status = Unit.Status.OUT
	release_captives(u)


## Bandes qui ont encore un élève « à elles » sur le terrain (neutres ralliés exclus).
func teams_alive() -> Array[int]:
	var out: Array[int] = []
	for u in units:
		if u.kind != Unit.Kind.STUDENT or u.rallied or u.team == Unit.NO_TEAM:
			continue
		if u.status == Unit.Status.ACTIVE or u.status == Unit.Status.CAPTURED:
			if not out.has(u.team):
				out.append(u.team)
	return out


## Numéro de la bande gagnante, ou -1 si la partie continue.
func winner() -> int:
	var alive := teams_alive()
	return alive[0] if alive.size() == 1 else -1
