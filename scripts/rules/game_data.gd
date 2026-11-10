class_name GameData
extends RefCounted
## Valeurs chiffrées lues dans data/*.json. Aucun chiffre de règle n'est écrit en dur ailleurs.

const DATA_DIR := "res://data/"

var characters: Dictionary = {}   # nom -> {dexterite: {d6, bonus}, moral}
var movement: Dictionary = {}     # type de pion -> cases par tour (pions automatiques)
var staffing: Dictionary = {}
var projectiles: Dictionary = {}  # "2".."12", "robinet" -> {nom, degats, cx}
var rules: Dictionary = {}        # regles_video.json


static func load_default() -> GameData:
	var d := GameData.new()
	var perso: Dictionary = _read_json(DATA_DIR + "personnages.json")
	d.characters = perso["eleves"].duplicate()
	d.characters.merge(perso["autres"])
	d.movement = perso["deplacement"]
	d.staffing = perso["effectifs"]
	d.projectiles = _read_json(DATA_DIR + "projectiles.json")
	d.projectiles.erase("_note")
	d.rules = _read_json(DATA_DIR + "regles_video.json")
	return d


static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON invalide : " + path)
	return parsed


func student_names() -> Array:
	var perso: Dictionary = _read_json(DATA_DIR + "personnages.json")
	return perso["eleves"].keys()


func ap_cost(action: String) -> int:
	return int(rules["points_action"][action])


func ap_per_turn() -> int:
	return int(rules["points_action"]["par_tour"])


func roll_threshold(key: String) -> int:
	return int(rules["jets"][key])


func projectile(key: String) -> Dictionary:
	return projectiles[key]
