class_name Board
extends RefCounted
## Grille du plateau : terrain seulement (les pions sont dans GameState).
## Coordonnées : x vers la droite, y vers le bas.

## PUDDLE : flaque d'eau sur le sol de la salle (ajout vidéo, niveau « Repas de Noël ») : on y marche, plus lentement.
enum Terrain { FLOOR, KITCHEN, WALL, TABLE, DOOR, TAP, TUB, DISH_TUB, PUDDLE }

## Légende des plans en texte (niveaux et tests).
const SYMBOLS := {
	".": Terrain.FLOOR,
	",": Terrain.KITCHEN,
	"#": Terrain.WALL,
	"T": Terrain.TABLE,
	"D": Terrain.DOOR,
	"R": Terrain.TAP,
	"B": Terrain.TUB,
	"V": Terrain.DISH_TUB,
	"~": Terrain.PUDDLE,
}

## Les 8 directions dans l'ordre de rotation vers la gauche (haut, haut-gauche, gauche…).
## Sert à l'ordre de retombée d'un tir raté (figure 1 du livret).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1),
]

var width := 0
var height := 0
var _cells := PackedInt32Array()
var _wall_sums := PackedInt32Array()  # sommes cumulées des murs, pour walls_in_rect


static func from_ascii(rows: Array) -> Board:
	var b := Board.new()
	b.height = rows.size()
	for r in rows:
		b.width = maxi(b.width, String(r).length())
	b._cells.resize(b.width * b.height)
	b._cells.fill(Terrain.WALL)
	for y in b.height:
		var row: String = rows[y]
		for x in row.length():
			var s := row[x]
			assert(SYMBOLS.has(s), "Symbole de plan inconnu : " + s)
			b._cells[y * b.width + x] = SYMBOLS[s]
	return b


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func terrain(c: Vector2i) -> Terrain:
	if not in_bounds(c):
		return Terrain.WALL
	return _cells[c.y * width + c.x] as Terrain


## Case de sol où l'on marche (salle, cuisine, porte).
func is_ground(c: Vector2i) -> bool:
	var t := terrain(c)
	return t == Terrain.FLOOR or t == Terrain.KITCHEN or t == Terrain.DOOR or t == Terrain.PUDDLE


func is_puddle(c: Vector2i) -> bool:
	return terrain(c) == Terrain.PUDDLE


func is_table(c: Vector2i) -> bool:
	return terrain(c) == Terrain.TABLE


func is_door(c: Vector2i) -> bool:
	return terrain(c) == Terrain.DOOR


func is_kitchen(c: Vector2i) -> bool:
	return terrain(c) == Terrain.KITCHEN


func is_tap(c: Vector2i) -> bool:
	return terrain(c) == Terrain.TAP


## Bacs fixes (le bac à vaisselle compte : on peut y être projeté).
func is_tub(c: Vector2i) -> bool:
	var t := terrain(c)
	return t == Terrain.TUB or t == Terrain.DISH_TUB


## Seuls les murs arrêtent un projectile (livret).
func blocks_shot(c: Vector2i) -> bool:
	return terrain(c) == Terrain.WALL


## Obstacle pour le passage en diagonale entre deux cases.
func is_obstacle(c: Vector2i) -> bool:
	return not is_ground(c)


## Nombre de murs dans le rectangle englobant deux cases (réponse immédiate grâce aux sommes cumulées).
## Sert à écarter d'emblée les lignes de tir qui ne peuvent croiser aucun mur.
func walls_in_rect(a: Vector2i, b: Vector2i) -> int:
	if _wall_sums.is_empty():
		_build_wall_sums()
	var x0 := clampi(mini(a.x, b.x), 0, width - 1)
	var x1 := clampi(maxi(a.x, b.x), 0, width - 1) + 1
	var y0 := clampi(mini(a.y, b.y), 0, height - 1)
	var y1 := clampi(maxi(a.y, b.y), 0, height - 1) + 1
	var w := width + 1
	return _wall_sums[y1 * w + x1] - _wall_sums[y0 * w + x1] - _wall_sums[y1 * w + x0] + _wall_sums[y0 * w + x0]


func _build_wall_sums() -> void:
	var w := width + 1
	_wall_sums.resize(w * (height + 1))
	_wall_sums.fill(0)
	for y in height:
		for x in width:
			var wall := 1 if _cells[y * width + x] == Terrain.WALL else 0
			_wall_sums[(y + 1) * w + x + 1] = wall + _wall_sums[y * w + x + 1] + _wall_sums[(y + 1) * w + x] - _wall_sums[y * w + x]


func cells_of(kind: Terrain) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			if _cells[y * width + x] == kind:
				out.append(Vector2i(x, y))
	return out


func doors() -> Array[Vector2i]:
	return cells_of(Terrain.DOOR)


static func neighbors8(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(c + d)
	return out


## Distance du livret : nombre de cases en se déplaçant dans les 8 directions.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and distance(a, b) == 1
