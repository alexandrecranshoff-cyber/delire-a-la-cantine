class_name SpecialActions
extends RefCounted
## Captures par les profs, plongeon du cuisinier, projection dans un bac ou un chariot.


## Capture simple : prof au contact, 1D6 de 1 à 4.
static func attempt_capture(state: GameState, teacher: Unit, student: Unit) -> Dictionary:
	if not _can_be_grabbed(teacher, student):
		return {"ok": false, "reason": "impossible"}
	var r := state.dice.roll(1, 0, "capture")
	var success: bool = r["total"] <= state.data.roll_threshold("capture_max")
	if success:
		_capture(teacher, student)
	return {"ok": true, "roll": r, "success": success}


## Double prise : deux élèves au contact, 1D6 de 1 à 2. Échec : aucun n'est pris.
static func attempt_double_capture(state: GameState, teacher: Unit, a: Unit, b: Unit) -> Dictionary:
	if a == b or not _can_be_grabbed(teacher, a) or not _can_be_grabbed(teacher, b):
		return {"ok": false, "reason": "impossible"}
	var r := state.dice.roll(1, 0, "double_capture")
	var success: bool = r["total"] <= state.data.roll_threshold("double_capture_max")
	if success:
		_capture(teacher, a)
		_capture(teacher, b)
	return {"ok": true, "roll": r, "success": success}


static func _can_be_grabbed(teacher: Unit, student: Unit) -> bool:
	return (teacher.kind == Unit.Kind.TEACHER and teacher.status == Unit.Status.ACTIVE
		and student.kind in [Unit.Kind.STUDENT, Unit.Kind.NEUTRAL]
		and student.team != Unit.NO_TEAM
		and student.status == Unit.Status.ACTIVE
		and Board.adjacent(teacher.pos, student.pos))


static func _capture(teacher: Unit, student: Unit) -> void:
	student.status = Unit.Status.CAPTURED
	student.captor_id = teacher.id
	student.pos = teacher.pos
	student.on_table = false
	teacher.captive_ids.append(student.id)


## Plongeon par le cuisinier : au contact de l'élève et à une ou deux cases d'un bac ou d'un chariot.
static func attempt_plunge(state: GameState, cook: Unit, student: Unit) -> Dictionary:
	var max_dist := int(state.data.rules["distance_max_bac"])
	if (cook.kind != Unit.Kind.COOK or cook.status != Unit.Status.ACTIVE
			or not Board.adjacent(cook.pos, student.pos)
			or student.status != Unit.Status.ACTIVE
			or state.distance_to_nearest_container(cook.pos) > max_dist):
		return {"ok": false, "reason": "impossible"}
	var r := state.dice.roll(1, 0, "plongeon")
	var success: bool = r["total"] <= state.data.roll_threshold("plongeon_max")
	if success:
		state.remove_from_board(student)
	return {"ok": true, "roll": r, "success": success}


## Nombre d'élèves requis pour projeter cette victime.
static func required_attackers(state: GameState, victim: Unit) -> int:
	return int(state.data.rules["projection_eleves_requis"].get(victim.kind_key(), 1 << 20))


## Projection : assez d'élèves d'une même bande au contact de la victime,
## la victime à une case au plus d'un bac ou d'un chariot. 1D6 de 1 à 4.
static func cannot_project_reason(state: GameState, attackers: Array, victim: Unit) -> String:
	if attackers.is_empty():
		return "pas_d_attaquants"
	var team: int = attackers[0].team
	var cost := state.data.ap_cost("projection")
	for a in attackers:
		if a.team != team or a.status != Unit.Status.ACTIVE or a.kind == Unit.Kind.CART:
			return "attaquant_invalide"
		if not Board.adjacent(a.pos, victim.pos):
			return "pas_au_contact"
		if a.ap < cost:
			return "pas_assez_de_pa"
	if victim.team == team and victim.team != Unit.NO_TEAM:
		return "meme_camp"
	if attackers.size() < required_attackers(state, victim):
		return "pas_assez_nombreux"
	if state.distance_to_nearest_container(victim.pos) > int(state.data.rules["distance_max_bac"]):
		return "trop_loin_du_bac"
	return ""


static func attempt_projection(state: GameState, attackers: Array, victim: Unit) -> Dictionary:
	var reason := cannot_project_reason(state, attackers, victim)
	if reason != "":
		return {"ok": false, "reason": reason}
	for a in attackers:
		a.ap -= state.data.ap_cost("projection")
	var r := state.dice.roll(1, 0, "projection")
	var success: bool = r["total"] <= state.data.roll_threshold("projection_max")
	if success:
		state.remove_from_board(victim)
	return {"ok": true, "roll": r, "success": success}
