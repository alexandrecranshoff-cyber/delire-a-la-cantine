class_name Campaign
extends RefCounted
## Année scolaire (campagne solo) : suite de services, expérience des élèves, améliorations et
## élèves « collés ». Pure donnée : la progression est un dictionnaire (sauvegardé en JSON par
## l'interface) et les chiffres viennent de data/campagne.json.

const DATA_PATH := "res://data/campagne.json"
const VERSION := 1
const UPGRADES := ["moral", "adresse", "pa"]

var data: Dictionary = {}
## Progression : {"version", "difficulte", "service" (indice du service à jouer), "gagnes" (ids),
## "termine", "eleves": nom -> {"xp", "moral", "adresse", "pa", "colle", "touches", "satures", "services"},
## "historique": [{"service", "gagne", "chahut"}]}.
var progress: Dictionary = {}


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## Nouvelle année : la bande des six élèves du livret, sans expérience.
static func new_year(difficulty: String, names: Array) -> Campaign:
	var c := Campaign.new()
	c.data = load_data()
	var students := {}
	for n in names:
		students[str(n)] = {"xp": 0, "moral": 0, "adresse": 0, "pa": 0, "colle": false, "touches": 0, "satures": 0, "services": 0}
	c.progress = {"version": VERSION, "difficulte": difficulty, "service": 0, "gagnes": [], "termine": false,
		"eleves": students, "historique": []}
	return c


## Reprend une progression sauvegardée ; null si elle est illisible.
static func from_progress(p: Dictionary) -> Campaign:
	if int(p.get("version", 0)) != VERSION or not p.has("eleves"):
		return null
	var c := Campaign.new()
	c.data = load_data()
	c.progress = p.duplicate(true)
	c.progress["service"] = int(c.progress["service"])
	for n in c.progress["eleves"].keys():
		var e: Dictionary = c.progress["eleves"][n]
		for k in e.keys():
			if k != "colle":
				e[k] = int(e[k])
	return c


func services() -> Array:
	return data["services"]


## Service construit (jouable) ?
static func is_playable(service: Dictionary) -> bool:
	return str(service.get("niveau", "")) != ""


func service_index() -> int:
	return int(progress["service"])


func current_service() -> Dictionary:
	return services()[mini(service_index(), services().size() - 1)]


func service_by_id(id: String) -> Dictionary:
	for s in services():
		if s["id"] == id:
			return s
	return {}


static func level_path(service: Dictionary) -> String:
	return "res://data/niveaux/%s.json" % service["niveau"]


func difficulty() -> String:
	return str(progress["difficulte"])


func is_won(id: String) -> bool:
	return progress["gagnes"].has(id)


func student(name: String) -> Dictionary:
	return progress["eleves"][name]


# --- Améliorations ---------------------------------------------------------------

func upgrade_cost(kind: String) -> int:
	return int(data["ameliorations"][kind]["cout"])


func upgrade_max(kind: String) -> int:
	return int(data["ameliorations"][kind]["max"])


func can_upgrade(name: String, kind: String) -> bool:
	var e := student(name)
	return int(e[kind]) < upgrade_max(kind) and int(e["xp"]) >= upgrade_cost(kind)


func upgrade(name: String, kind: String) -> bool:
	if not can_upgrade(name, kind):
		return false
	var e := student(name)
	e["xp"] = int(e["xp"]) - upgrade_cost(kind)
	e[kind] = int(e[kind]) + 1
	return true


## Fiche de l'élève après ses améliorations : {"moral", "dex_d6", "dex_bonus", "ap_bonus"}.
## `base` : fiche du livret ({"moral", "dexterite": {"d6", "bonus"}}).
func sheet(name: String, base: Dictionary) -> Dictionary:
	var e := student(name)
	var up: Dictionary = data["ameliorations"]
	var d6 := int(base["dexterite"]["d6"])
	var bonus := int(base["dexterite"]["bonus"])
	var adresse := int(e["adresse"])
	if adresse >= 1:
		bonus += 1
	if adresse >= 2:
		d6 += 1
	return {
		"moral": int(base["moral"]) + int(e["moral"]) * int(up["moral"]["gain"]),
		"dex_d6": d6,
		"dex_bonus": bonus,
		"ap_bonus": int(e["pa"]) * int(up["pa"]["gain"]),
	}


# --- Mise en place d'un service -----------------------------------------------------

## Applique le service à une partie fraîchement créée (GameSetup.new_game, difficulté de l'année) :
## fiches améliorées et élèves collés de la bande `team`, puis pression du service.
func prepare_state(state: GameState, team: int, service: Dictionary) -> void:
	var colle_pct := int(data["colle"]["moral_pct"])
	var pressure: Dictionary = service.get("pression", {})
	var ia_pct := int(pressure.get("moral_ia_pct", 0))
	var diffs := GameSetup.difficulties()
	var diff_key := str(state.options.get("difficulte", difficulty()))
	var player_pct := int(diffs[diff_key]["moral_joueur_pct"]) if diffs.has(diff_key) else 100
	for u in state.units:
		if u.kind != Unit.Kind.STUDENT:
			continue
		if u.team == team and progress["eleves"].has(u.name):
			# Le moral de départ suit la difficulté (moral_joueur_pct), appliquée à la fiche améliorée.
			var base: Dictionary = state.data.characters[u.name]
			var s := sheet(u.name, base)
			u.max_moral = int(round(s["moral"] * player_pct / 100.0))
			u.dex_d6 = s["dex_d6"]
			u.dex_bonus = s["dex_bonus"]
			u.ap_bonus = s["ap_bonus"]
			u.moral = u.max_moral
			if bool(student(u.name)["colle"]):
				u.moral = maxi(1, int(round(u.max_moral * colle_pct / 100.0)))
			if state.current_team == team:
				u.ap = state.max_ap(u)
		elif u.team != team and u.team != Unit.NO_TEAM and ia_pct != 0:
			var base_moral := int(state.data.characters[u.name]["moral"])
			u.max_moral += int(round(base_moral * ia_pct / 100.0))
			u.moral = u.max_moral
	var periode := state.option("prof_periode") - int(pressure.get("prof_periode_moins", 0))
	state.options["prof_periode"] = maxi(1, periode)
	if pressure.has("tours_munitions_tables"):
		state.options["tours_munitions_tables"] = int(pressure["tours_munitions_tables"])
	state.options["service"] = str(service["id"])


# --- Fin d'un service ----------------------------------------------------------------

## Enregistre la fin du service. `results` : nom -> {"touches", "satures", "fin"}, où « fin » vaut
## "a_table" (encore en jeu), "sature", "colle" (emmené par un prof ou plongé). Renvoie le détail
## des points gagnés : nom -> {"xp", "colle"}. Une victoire ouvre le service suivant ; sinon le
## service est à refaire (on garde l'expérience gagnée).
func finish_service(service_id: String, results: Dictionary, won: bool, chahut: int = 0) -> Dictionary:
	var xp: Dictionary = data["experience"]
	var out := {}
	for name in progress["eleves"].keys():
		var e: Dictionary = progress["eleves"][name]
		var r: Dictionary = results.get(name, {"touches": 0, "satures": 0, "fin": "a_table"})
		var gain := int(r["touches"]) * int(xp["touche"]) + int(r["satures"]) * int(xp["sature"])
		if r["fin"] == "a_table":
			gain += int(xp["reste_a_table"])
		if won:
			gain += int(xp["victoire"])
		e["xp"] = int(e["xp"]) + gain
		e["touches"] = int(e["touches"]) + int(r["touches"])
		e["satures"] = int(e["satures"]) + int(r["satures"])
		e["services"] = int(e["services"]) + 1
		e["colle"] = r["fin"] == "colle"
		out[name] = {"xp": gain, "colle": e["colle"]}
	progress["historique"].append({"service": service_id, "gagne": won, "chahut": chahut})
	if won:
		if not progress["gagnes"].has(service_id):
			progress["gagnes"].append(service_id)
		if service_id == str(data["bulletin_apres"]):
			progress["termine"] = true
		var idx := service_index()
		if idx + 1 < services().size() and is_playable(services()[idx + 1]):
			progress["service"] = idx + 1
	return out


## Fin d'un élève dans un service, d'après son pion à la sonnerie ou à la fin de la partie.
static func end_status(u: Unit) -> String:
	if u.status == Unit.Status.ACTIVE:
		return "a_table"
	if u.moral <= 0:
		return "sature"
	return "colle"  # capturé, emmené par un prof ou plongé dans un bac


# --- Bulletin -------------------------------------------------------------------------

## Appréciation d'un élève pour le bulletin, selon ses résultats sur l'année.
func appreciation(name: String) -> String:
	var e := student(name)
	var services_played := maxi(1, int(e["services"]))
	var per := float(e["touches"]) / services_played
	if int(e["satures"]) >= 4:
		return "Terreur du réfectoire. Les dames de service demandent sa mutation."
	if per >= 4.0:
		return "Excellent lanceur. Doit maintenant apprendre à manger ce qu'il y a dans son assiette."
	if bool(e["colle"]):
		return "Trop souvent surpris par les surveillants. Manque de discrétion."
	if per >= 2.0:
		return "Participe activement. Ensemble satisfaisant."
	return "Élève effacé. Peut mieux faire, et surtout plus fort."


## Note sur 20 de l'élève (pour rire) : tirs réussis et adversaires saturés.
func grade(name: String) -> int:
	var e := student(name)
	var services_played := maxi(1, int(e["services"]))
	var score := 6.0 + 2.0 * float(e["touches"]) / services_played + 3.0 * float(e["satures"]) / services_played
	if bool(e["colle"]):
		score -= 2.0
	return clampi(int(round(score)), 2, 19)
