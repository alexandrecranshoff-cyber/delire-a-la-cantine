class_name SaveSlots
extends RefCounted
## Emplacements de sauvegarde, rangés dans un seul fichier du dossier utilisateur
## (sur PC : le dossier de données de Godot ; dans le navigateur : son stockage local).
## « auto » est réécrit au début de chaque tour du joueur ; « 1 » à « 3 » sont au choix du joueur.

const PATH := "user://sauvegardes.json"
const KEYS := ["auto", "1", "2", "3"]


static func all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


static func has_any() -> bool:
	return not all().is_empty()


static func write(key: String, entry: Dictionary) -> bool:
	var slots := all()
	slots[key] = entry
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(slots))
	f.close()
	return true


static func erase(key: String) -> void:
	var slots := all()
	if not slots.has(key):
		return
	slots.erase(key)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(slots))
		f.close()


static func title(key: String) -> String:
	return "REPRISE AUTO" if key == "auto" else "EMPLACEMENT %s" % key


## Résumé d'une sauvegarde : mode, difficulté, tour, date.
static func describe(entry: Dictionary) -> String:
	if entry.is_empty():
		return "vide"
	var cfg: Dictionary = entry.get("config", {})
	var mode := "2 joueurs"
	if bool(cfg.get("campaign", false)):
		mode = "Année scolaire"
	elif bool(cfg.get("solo", true)):
		var diffs := GameSetup.difficulties()
		var key := str(cfg.get("difficulty", "normal"))
		mode = "Solo, %s" % (diffs[key]["nom"] if diffs.has(key) else key)
	mode += ", %s" % str(cfg.get("level_name", "Cantine du collège")).to_lower()
	var st: Dictionary = entry.get("state", {})
	return "%s · tour %d · %s" % [mode, int(st.get("turn", 1)), str(entry.get("date", ""))]
