class_name CampaignStore
extends RefCounted
## Année scolaire en cours, rangée dans le dossier utilisateur (sur PC : le dossier de données de
## Godot ; dans le navigateur : son stockage local). Une seule année à la fois.

const PATH := "user://annee_scolaire.json"


static func load_year() -> Campaign:
	if not FileAccess.file_exists(PATH):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return Campaign.from_progress(parsed) if parsed is Dictionary else null


static func save_year(c: Campaign) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(c.progress))
	f.close()
	return true


static func has_year() -> bool:
	return load_year() != null
