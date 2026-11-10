class_name DiceRoller
extends RefCounted
## Générateur de dés à graine : tout tirage aléatoire du jeu passe par ici,
## pour pouvoir rejouer une partie et écrire des tests déterministes.

var history: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _forced: Array[int] = []


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Impose les prochaines faces (tests, rejeu). Elles sont consommées dans l'ordre.
func force(values: Array) -> void:
	for v in values:
		_forced.append(int(v))


func d6() -> int:
	if not _forced.is_empty():
		return _forced.pop_front()
	return _rng.randi_range(1, 6)


## Lance `count` D6 et ajoute `bonus`. Le résultat est gardé dans l'historique
## pour que l'interface puisse afficher les dés.
func roll(count: int, bonus: int = 0, label: String = "") -> Dictionary:
	var faces: Array[int] = []
	var total := bonus
	for i in count:
		var f := d6()
		faces.append(f)
		total += f
	var result := {"label": label, "faces": faces, "bonus": bonus, "total": total}
	history.append(result)
	return result


## Dégâts selon la table des projectiles : {"d6": n}, {"demi": n} ou {"fixe": n}.
## « Demi-dé » : 1-2 = 1, 3-4 = 2, 5-6 = 3.
func roll_damage(spec: Dictionary, label: String = "degats") -> Dictionary:
	if spec.has("fixe"):
		var fixed := {"label": label, "faces": [] as Array[int], "bonus": int(spec["fixe"]), "total": int(spec["fixe"])}
		history.append(fixed)
		return fixed
	if spec.has("demi"):
		var r := roll(int(spec["demi"]), 0, label)
		var total := 0
		for f in r["faces"]:
			total += ceili(f / 2.0)
		r["total"] = total
		return r
	return roll(int(spec.get("d6", 0)), 0, label)
