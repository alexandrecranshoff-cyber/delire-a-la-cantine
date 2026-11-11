class_name Level
extends RefCounted
## Niveau lu dans data/niveaux/*.json et mise en place d'une partie (livret, « mise en place »).

const STUDENTS_PER_TABLE := 3

var name := ""
var raw: Dictionary = {}


static func load_file(path: String) -> Level:
	var lv := Level.new()
	lv.raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	lv.name = lv.raw["nom"]
	return lv


## Plats du menu du jour (remplacent des lignes de la table des projectiles), vide si menu du livret.
func menu() -> Dictionary:
	return raw.get("menu", {}).get("plats", {})


func menu_name() -> String:
	return str(raw.get("menu", {}).get("nom", ""))


## Habillage du niveau : nom d'image pour un élément du décor (sol, murs, nappe), ou `fallback`.
func decor(part: String, fallback: String) -> String:
	return str(raw.get("decor", {}).get(part, fallback))


## Cuisine chaotique : le décor ajoute épluchures, marmites renversées et cagettes.
func kitchen_mess() -> bool:
	return bool(raw.get("cuisine_en_desordre", false))


## Réglages propres au niveau qui remplacent ceux de regles_video.json (voir GameState.options).
func options() -> Dictionary:
	return raw.get("options", {})


func board() -> Board:
	return Board.from_ascii(raw["plan"])


static func _cell(v) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1]))


func seats(table: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in raw["places"][table]:
		out.append(_cell(v))
	return out


func door_cells(door: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in raw["portes"][door]:
		out.append(_cell(v))
	return out


## Tables de chaque bande selon le nombre de joueurs (2, 3 ou 4).
func tables_for(players: int) -> Array:
	return raw["repartition"][str(players)]


## Crée la partie : élèves autour de leurs tables (3 par table), neutres sur les cases N,
## les élèves des tables libres deviennent des neutres, cuisinier et chariots à leur place.
func build_state(data: GameData, dice: DiceRoller, players: int) -> GameState:
	var state := GameState.new(board(), data, dice)
	var names: Array = data.student_names()
	var assignment := tables_for(players)
	var used_tables: Array[String] = []
	for team in assignment.size():
		var tables: Array = assignment[team]
		var i := 0
		for t in tables:
			var key := str(int(t))
			used_tables.append(key)
			var places := seats(key)
			for k in STUDENTS_PER_TABLE:
				state.add_student(names[i % names.size()], team, places[k])
				i += 1
	for key in raw["places"].keys():
		if used_tables.has(key):
			continue
		var places := seats(key)
		for k in STUDENTS_PER_TABLE:
			state.add_unit(Unit.Kind.NEUTRAL, "neutre", places[k])
	for v in raw["places_neutres"]:
		state.add_unit(Unit.Kind.NEUTRAL, "neutre", _cell(v))
	state.add_unit(Unit.Kind.COOK, "cuisinier", _cell(raw["cuisinier"]))
	for cart_name in raw["chariots"].keys():
		state.add_unit(Unit.Kind.CART, "chariot", _cell(raw["chariots"][cart_name]), Unit.NO_TEAM, cart_name)
	for u in state.units:
		u.loaded = u.kind == Unit.Kind.STUDENT
	state.team_count = assignment.size()
	for key in raw["portes"].keys():
		state.doors[key] = door_cells(key)
	return state
