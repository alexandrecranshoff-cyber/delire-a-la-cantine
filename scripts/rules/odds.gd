class_name Odds
extends RefCounted
## Probabilités des jets du livret, calculées à partir des données (aucun chiffre en dur).
## Sert à l'IA pour estimer un tir ; le joueur, lui, ne voit jamais de pourcentage.

var _data: GameData
var _sum_cache := {}      # nombre de dés -> répartition des totaux
var _expected_cache := {}


func _init(data: GameData) -> void:
	_data = data


## Répartition du total de `count` D6 : total -> probabilité.
func sum_distribution(count: int) -> Dictionary:
	if _sum_cache.has(count):
		return _sum_cache[count]
	var dist := {0: 1.0}
	for i in count:
		var next := {}
		for total in dist.keys():
			for face in range(1, 7):
				next[total + face] = next.get(total + face, 0.0) + dist[total] / 6.0
		dist = next
	_sum_cache[count] = dist
	return dist


## Probabilité que `d6` dés + `bonus` atteignent le seuil.
func chance_at_least(d6: int, bonus: int, threshold: int) -> float:
	var p := 0.0
	var dist := sum_distribution(d6)
	for total in dist.keys():
		if total + bonus >= threshold:
			p += dist[total]
	return p


## Dégâts moyens d'un projectile ({"d6": n}, {"demi": n} ou {"fixe": n}).
static func mean_damage(spec: Dictionary) -> float:
	if spec.has("fixe"):
		return float(spec["fixe"])
	if spec.has("demi"):
		return 2.0 * float(spec["demi"])
	return 3.5 * float(spec.get("d6", 0))


## Dégâts moyens espérés d'un tir à cette distance, toutes munitions confondues (tirage 2D6).
func expected_damage(d6: int, bonus: int, distance: int) -> float:
	var key := Vector3i(d6, bonus, distance)
	if _expected_cache.has(key):
		return _expected_cache[key]
	var total := 0.0
	var pick := sum_distribution(2)
	for roll in pick.keys():
		var proj: Dictionary = _data.projectile(str(roll))
		total += pick[roll] * chance_at_least(d6, bonus, distance + int(proj["cx"])) * mean_damage(proj["degats"])
	_expected_cache[key] = total
	return total


## Chance de toucher à cette distance, toutes munitions confondues.
func hit_chance(d6: int, bonus: int, distance: int) -> float:
	var total := 0.0
	var pick := sum_distribution(2)
	for roll in pick.keys():
		total += pick[roll] * chance_at_least(d6, bonus, distance + int(_data.projectile(str(roll))["cx"]))
	return total
