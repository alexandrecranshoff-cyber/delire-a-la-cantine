class_name AutoPawns
extends RefCounted
## Pions automatiques du livret, joués à la fin du tour de chaque bande : saturés et neutres en fuite
## vers la sortie, berserks, profs (poursuite, capture, sortie), entrée d'un prof, cuisinier.
## Chaque fonction modifie l'état et ajoute les événements à afficher.


## `adults` : les profs et le cuisinier agissent aussi (voir `adultes_par_manche` dans regles_video.json).
static func run(state: GameState, adults: bool = true) -> Array:
	var events := []
	_leave_tables(state, events)
	_neutrals_leave(state, events)
	_runaways(state, events)
	_berserks(state, events)
	if adults:
		_teachers(state, events)
	_spawn_teacher(state, events)
	if adults:
		_cook(state, events)
	return events


static func _speed(state: GameState, u: Unit) -> int:
	return int(state.data.movement[u.kind_key()])


static func _door_field(state: GameState) -> Dictionary:
	return Pathing.field(state.board, state.board.doors())


## Temps maximum sur une table écoulé : l'élève redescend de force.
static func _leave_tables(state: GameState, events: Array) -> void:
	for u in state.units:
		if u.is_on_board() and u.on_table and (state.must_leave_table(u) or u.status != Unit.Status.ACTIVE):
			var from := u.pos
			var spot := _free_ground_near(state, u.pos)
			if spot == u.pos:
				continue
			u.pos = spot
			u.on_table = false
			u.turns_on_table = 0
			events.append({"type": "descend", "id": u.id, "from": from, "to": spot, "forced": true})


static func _free_ground_near(state: GameState, c: Vector2i) -> Vector2i:
	# Sur une table large, la case de sol libre la plus proche peut être à deux ou trois cases.
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n := c + Vector2i(dx, dy)
				if state.board.is_ground(n) and not state.is_occupied(n):
					return n
	return c


## À partir du tour 5 : les neutres restés à table s'en vont (livret, « tour d'un joueur »).
static func _neutrals_leave(state: GameState, events: Array) -> void:
	if state.tables_have_ammo():
		return
	var ids := []
	for u in state.units:
		if u.kind == Unit.Kind.NEUTRAL and u.status == Unit.Status.ACTIVE and not u.rallied and u.is_on_board():
			u.status = Unit.Status.FLEEING
			ids.append(u.id)
	if not ids.is_empty():
		events.append({"type": "neutrals_leave", "ids": ids})


## Saturés et neutres en fuite : au plus vite vers la porte la plus proche.
static func _runaways(state: GameState, events: Array) -> void:
	var field := {}
	var moves := []
	# Les plus proches de la sortie d'abord, pour ne pas se bloquer en file.
	var runners: Array[Unit] = []
	for u in state.units:
		if u.is_on_board() and u.kind != Unit.Kind.CART and (u.status == Unit.Status.SATURATED or u.status == Unit.Status.FLEEING):
			runners.append(u)
	if runners.is_empty():
		return
	field = _door_field(state)
	runners.sort_custom(func(a, b): return field.get(a.pos, 1 << 20) < field.get(b.pos, 1 << 20))
	for u in runners:
		var from := u.pos
		var path := Pathing.advance(state, u, field, _speed(state, u), true)
		if not path.is_empty():
			moves.append({"type": "move", "id": u.id, "from": from, "path": path, "parallel": true})
		if state.board.is_door(u.pos):
			state.exit_board(u)
			moves.append({"type": "exit", "id": u.id, "cell": u.pos, "captives": [], "reason": "fuite"})
	events.append_array(moves)


## Berserk : tire sur le pion le plus proche, quel qu'il soit, puis se rapproche.
static func _berserks(state: GameState, events: Array) -> void:
	for u in state.units:
		if u.status != Unit.Status.BERSERK or not u.is_on_board():
			continue
		var target := _nearest_target(state, u)
		if target == null:
			continue
		u.loaded = true
		u.has_shot = false
		u.ap = state.data.ap_cost("tir")
		events.append_array(GameActions.shoot(state, u, target))
		if u.status == Unit.Status.BERSERK and target.is_on_board() and Board.distance(u.pos, target.pos) > 3:
			var from := u.pos
			var path := Pathing.advance(state, u, Pathing.field(state.board, Pathing.ground_around(state.board, target.pos)), _speed(state, u))
			if not path.is_empty():
				events.append({"type": "move", "id": u.id, "from": from, "path": path})


static func _nearest_target(state: GameState, shooter: Unit) -> Unit:
	var best: Unit = null
	var best_d := 1 << 20
	for t in state.units:
		if t == shooter or t.kind == Unit.Kind.CART or not t.is_on_board() or t.status == Unit.Status.CAPTURED:
			continue
		var d := Board.distance(shooter.pos, t.pos)
		if d < best_d and not Trajectory.blocked_by_wall(state.board, shooter.pos, t.pos):
			best = t
			best_d = d
	return best


## Élèves qu'un prof peut attraper : actifs et non neutres (les neutres ralliés comptent).
static func _catchable(state: GameState) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in state.units:
		if u.team != Unit.NO_TEAM and u.status == Unit.Status.ACTIVE and u.kind in [Unit.Kind.STUDENT, Unit.Kind.NEUTRAL]:
			out.append(u)
	return out


static func _teachers(state: GameState, events: Array) -> void:
	var door_field := {}
	for t in state.units:
		if t.kind != Unit.Kind.TEACHER or t.status != Unit.Status.ACTIVE:
			continue
		if not t.captive_ids.is_empty():
			# Il emmène sa victime à vitesse maximale vers la sortie la plus proche.
			if door_field.is_empty():
				door_field = _door_field(state)
			var from := t.pos
			var path := Pathing.advance(state, t, door_field, _speed(state, t), true)
			_drag_captives(state, t)
			if not path.is_empty():
				events.append({"type": "move", "id": t.id, "from": from, "path": path, "captives": t.captive_ids.duplicate()})
			if state.board.is_door(t.pos):
				var captives := t.captive_ids.duplicate()
				state.exit_board(t)
				events.append({"type": "exit", "id": t.id, "cell": t.pos, "captives": captives, "reason": "prof"})
			continue
		var prey := _nearest_prey(state, t)
		if prey == null:
			continue
		if not Board.adjacent(t.pos, prey.pos):
			var from := t.pos
			var path := Pathing.advance(state, t, Pathing.field(state.board, Pathing.ground_around(state.board, prey.pos)), _speed(state, t))
			if not path.is_empty():
				events.append({"type": "move", "id": t.id, "from": from, "path": path})
		var grab := _adjacent_prey(state, t, prey)
		if grab != null:
			var cell := grab.pos
			var result := SpecialActions.attempt_capture(state, t, grab)
			if result["ok"]:
				events.append({"type": "capture", "id": t.id, "victim_id": grab.id, "cell": cell, "roll": result["roll"], "success": result["success"]})


static func _drag_captives(state: GameState, teacher: Unit) -> void:
	for cid in teacher.captive_ids:
		var v := state.get_unit(cid)
		if v != null:
			v.pos = teacher.pos


## Élève actif le plus proche du prof, en pas de marche jusqu'à une case à son contact.
static func _nearest_prey(state: GameState, teacher: Unit) -> Unit:
	var field := Pathing.field(state.board, [teacher.pos])
	var best: Unit = null
	var best_d := 1 << 20
	for u in _catchable(state):
		var d := 1 << 20
		for n in Pathing.ground_around(state.board, u.pos):
			d = mini(d, field.get(n, 1 << 20))
		if u.pos == teacher.pos:
			d = 0
		if d < best_d:
			best_d = d
			best = u
	return best


static func _adjacent_prey(state: GameState, teacher: Unit, preferred: Unit) -> Unit:
	if preferred.status == Unit.Status.ACTIVE and Board.adjacent(teacher.pos, preferred.pos):
		return preferred
	for u in _catchable(state):
		if Board.adjacent(teacher.pos, u.pos):
			return u
	return null


## Un prof entre par une porte tirée au dé (1D6), tous les `prof_periode` tours de bande.
static func _spawn_teacher(state: GameState, events: Array) -> void:
	if state.doors.is_empty() or state.teachers_spawned >= int(state.data.staffing["profs"]):
		return
	if state.team_turns_done % maxi(1, state.option("prof_periode")) != 0:
		return
	var roll := state.dice.roll(1, 0, "porte_prof")
	var key := str(roll["total"])
	if not state.doors.has(key):
		return
	for c in state.doors[key]:
		if not state.is_occupied(c):
			state.teachers_spawned += 1
			var t := state.add_unit(Unit.Kind.TEACHER, "prof", c, Unit.NO_TEAM, "Prof")
			events.append({"type": "spawn", "id": t.id, "cell": c, "door": key, "roll": roll})
			return


static func _cook(state: GameState, events: Array) -> void:
	var cook: Unit = null
	for u in state.units:
		if u.kind == Unit.Kind.COOK and u.status == Unit.Status.ACTIVE:
			cook = u
	if cook == null:
		return
	var in_kitchen: Array[Unit] = []
	var all: Array[Unit] = []
	for u in state.units:
		if u.team != Unit.NO_TEAM and u.status == Unit.Status.ACTIVE and u.kind in [Unit.Kind.STUDENT, Unit.Kind.NEUTRAL]:
			all.append(u)
			if state.board.is_kitchen(u.pos):
				in_kitchen.append(u)
	if not state.cook_awake:
		if in_kitchen.is_empty():
			return
		state.cook_awake = true
		events.append({"type": "cook_wakes", "id": cook.id, "by": in_kitchen[0].id})
	var target: Unit = null
	if not in_kitchen.is_empty():
		var field := Pathing.field(state.board, [cook.pos], true)
		var best_d := 1 << 20
		for u in in_kitchen:
			var d := 1 << 20
			for n in Pathing.ground_around(state.board, u.pos):
				d = mini(d, field.get(n, 1 << 20))
			if d < best_d:
				best_d = d
				target = u
		if target != null and not Board.adjacent(cook.pos, target.pos):
			var from := cook.pos
			var goal := Pathing.field(state.board, Pathing.ground_around(state.board, target.pos), true)
			var path := Pathing.advance(state, cook, goal, _speed(state, cook), false, true)
			if not path.is_empty():
				events.append({"type": "move", "id": cook.id, "from": from, "path": path})
		if target != null and Board.adjacent(cook.pos, target.pos):
			var cell := target.pos
			var result := SpecialActions.attempt_plunge(state, cook, target)
			if result["ok"]:
				events.append({"type": "plunge", "id": cook.id, "victim_id": target.id, "cell": cell, "roll": result["roll"], "success": result["success"]})
				return
	# Sinon il tire comme un élève, s'il a des projectiles sous la main.
	state.refresh_loaded(cook)
	if not cook.loaded:
		return
	var prey: Unit = target
	if prey == null or Trajectory.blocked_by_wall(state.board, cook.pos, prey.pos):
		prey = null
		var best := 1 << 20
		for u in all:
			var d := Board.distance(cook.pos, u.pos)
			if d < best and not Trajectory.blocked_by_wall(state.board, cook.pos, u.pos):
				best = d
				prey = u
	if prey == null:
		return
	cook.has_shot = false
	cook.ap = state.data.ap_cost("tir")
	events.append_array(GameActions.shoot(state, cook, prey))
