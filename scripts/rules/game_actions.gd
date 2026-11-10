class_name GameActions
extends RefCounted
## Actions d'un pion contrôlé (joueur ou IA). Chaque fonction applique la règle et renvoie la liste
## des événements à afficher ; liste vide si l'action est refusée.


static func move(state: GameState, unit: Unit, dest: Vector2i) -> Array:
	var from := unit.pos
	var path := Movement.move(state, unit, dest)
	if path.is_empty():
		return []
	var events := [{"type": "move", "id": unit.id, "from": from, "path": path}]
	_check_kitchen(state, unit, events)
	return events


static func shoot(state: GameState, shooter: Unit, target: Unit, watering: bool = false) -> Array:
	var from := shooter.pos
	var target_cell := target.pos
	var report := Combat.resolve_shot(state, shooter, target, watering)
	if not report["ok"]:
		return []
	var victim := state.get_unit(report["victim_id"]) if report["victim_id"] >= 0 else null
	return [{
		"type": "shot", "report": report, "id": shooter.id, "from": from,
		"target_cell": target_cell, "victim_cell": victim.pos if victim != null else report.get("landing_cell", target_cell),
	}]


static func climb(state: GameState, unit: Unit, cell: Vector2i) -> Array:
	var from := unit.pos
	if not Movement.climb(state, unit, cell):
		return []
	return [{"type": "climb", "id": unit.id, "from": from, "to": cell}]


static func descend(state: GameState, unit: Unit, cell: Vector2i) -> Array:
	var from := unit.pos
	if not Movement.descend(state, unit, cell):
		return []
	var events := [{"type": "descend", "id": unit.id, "from": from, "to": cell}]
	_check_kitchen(state, unit, events)
	return events


static func push_cart(state: GameState, pusher: Unit, cart: Unit, dest: Vector2i) -> Array:
	var from := cart.pos
	var path := Movement.path_to(state, cart, dest)
	if not Movement.push_cart(state, pusher, cart, dest):
		return []
	return [{"type": "push", "id": pusher.id, "cart_id": cart.id, "from": from, "path": path}]


## Élèves de la bande au contact de la victime et capables de participer à une projection.
static func projection_team(state: GameState, team: int, victim: Unit) -> Array:
	var out := []
	var cost := state.data.ap_cost("projection")
	for u in state.units:
		if u.team == team and u.is_controllable() and u.kind != Unit.Kind.CART and u.ap >= cost and Board.adjacent(u.pos, victim.pos):
			out.append(u)
	return out


static func project(state: GameState, team: int, victim: Unit) -> Array:
	var attackers := projection_team(state, team, victim)
	var cell := victim.pos
	var result := SpecialActions.attempt_projection(state, attackers, victim)
	if not result["ok"]:
		return []
	var ids := []
	for a in attackers:
		ids.append(a.id)
	return [{"type": "project", "ids": ids, "victim_id": victim.id, "cell": cell, "roll": result["roll"], "success": result["success"]}]


## Un élève qui franchit le seuil de la cuisine réveille le cuisinier (livret).
static func _check_kitchen(state: GameState, unit: Unit, events: Array) -> void:
	if state.cook_awake or unit.team == Unit.NO_TEAM or not state.board.is_kitchen(unit.pos):
		return
	for u in state.units:
		if u.kind == Unit.Kind.COOK and u.status == Unit.Status.ACTIVE:
			state.cook_awake = true
			events.append({"type": "cook_wakes", "id": u.id, "by": unit.id})
			return
