class_name Combat
extends RefCounted
## Tirs : table des projectiles (2D6), seuil = distance + CX, jet de dextérité, dégâts,
## retombée d'un tir raté, réaction d'un neutre touché, arrosage au robinet.

enum NeutralReaction { NONE, RALLIED, FLEEING, BERSERK }


## Raison du refus (texte vide si le tir est possible).
static func cannot_shoot_reason(state: GameState, shooter: Unit, target: Unit, watering: bool = false) -> String:
	var cost := state.data.ap_cost("arrosage" if watering else "tir")
	if shooter.status != Unit.Status.ACTIVE and shooter.status != Unit.Status.BERSERK:
		return "tireur_hors_jeu"
	if shooter.dex_d6 == 0 and shooter.dex_bonus == 0:
		return "ne_tire_pas"
	if shooter.has_shot:
		return "deja_tire"
	if shooter.ap < cost:
		return "pas_assez_de_pa"
	if target == shooter or not target.is_on_board() or target.kind == Unit.Kind.CART:
		return "cible_invalide"
	if target.status == Unit.Status.CAPTURED:
		return "cible_invalide"
	if watering:
		if not state.is_near_tap(shooter):
			return "pas_de_robinet"
		if Board.distance(shooter.pos, target.pos) > int(state.data.projectile("robinet")["portee_max"]):
			return "trop_loin"
	elif not (shooter.loaded or state.at_ammo_source(shooter)):
		return "pas_de_munitions"
	if Trajectory.blocked_by_wall(state.board, shooter.pos, target.pos):
		return "mur"
	return ""


static func shot_threshold(distance: int, cx: int) -> int:
	return distance + cx


## Résout un tir. Renvoie un compte rendu complet pour l'affichage (dés, seuil, victime).
static func resolve_shot(state: GameState, shooter: Unit, target: Unit, watering: bool = false) -> Dictionary:
	var reason := cannot_shoot_reason(state, shooter, target, watering)
	if reason != "":
		return {"ok": false, "reason": reason}

	var report := {"ok": true, "watering": watering, "shooter_id": shooter.id, "target_id": target.id}
	var key := "robinet"
	if not watering:
		var pick := state.dice.roll(2, 0, "projectile")
		report["projectile_roll"] = pick
		key = str(pick["total"])
	var proj := state.data.projectile(key)
	var distance := Board.distance(shooter.pos, target.pos)
	report["projectile"] = key
	report["projectile_name"] = proj["nom"]
	report["distance"] = distance
	report["cx"] = int(proj["cx"])
	report["threshold"] = shot_threshold(distance, int(proj["cx"]))
	report["trajectory"] = Trajectory.cells(shooter.pos, target.pos)

	var dex := state.dice.roll(shooter.dex_d6, shooter.dex_bonus, "dexterite")
	report["dex_roll"] = dex
	report["hit"] = dex["total"] >= report["threshold"]

	_pay_shot(state, shooter, watering)

	var victim: Unit = target
	if not report["hit"]:
		victim = _miss_victim(state, shooter, target)
		report["landing_cell"] = Trajectory.landing_cell(shooter.pos, target.pos)
	if victim == null:
		report["victim_id"] = -1
		return report

	report["victim_id"] = victim.id
	var dmg := state.dice.roll_damage(proj["degats"])
	report["damage_roll"] = dmg
	report["damage"] = dmg["total"]
	report["saturated"] = state.apply_damage(victim, dmg["total"])
	report["neutral_reaction"] = NeutralReaction.NONE
	if victim.kind == Unit.Kind.NEUTRAL and not report["saturated"] and victim.status == Unit.Status.ACTIVE:
		report["neutral_reaction"] = neutral_hit(state, victim, shooter)
	return report


static func _pay_shot(state: GameState, shooter: Unit, watering: bool) -> void:
	shooter.ap -= state.data.ap_cost("arrosage" if watering else "tir")
	shooter.has_shot = true
	if not watering and not state.at_ammo_source(shooter):
		shooter.loaded = false


## Premier pion touché par la retombée, dans l'ordre de la figure 1 (ni la cible, ni le tireur).
static func _miss_victim(state: GameState, shooter: Unit, target: Unit) -> Unit:
	for c in Trajectory.miss_candidates(shooter.pos, target.pos):
		var u := state.unit_at(c)
		if u != null and u != target and u != shooter and u.kind != Unit.Kind.CART:
			return u
	return null


## Neutre touché : 1 il rejoint le camp du tireur, 2 à 5 il fuit, 6 il devient berserk.
static func neutral_hit(state: GameState, neutral: Unit, shooter: Unit) -> NeutralReaction:
	var r: int = state.dice.roll(1, 0, "neutre_touche")["total"]
	if r <= state.data.roll_threshold("neutre_rallie_max") and shooter.team != Unit.NO_TEAM:
		neutral.team = shooter.team
		neutral.rallied = true
		return NeutralReaction.RALLIED
	if r >= state.data.roll_threshold("neutre_berserk_min"):
		neutral.status = Unit.Status.BERSERK
		neutral.loaded = true
		return NeutralReaction.BERSERK
	neutral.status = Unit.Status.FLEEING
	return NeutralReaction.FLEEING
