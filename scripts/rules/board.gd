class_name Board
extends RefCounted
## Grille du plateau : terrain seulement (les pions sont dans GameState).
## Coordonnées : x vers la droite, y vers le bas.

enum Terrain { FLOOR, KITCHEN, WALL, TABLE, DOOR, TAP, TUB, DISH_TUB }

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
	return t == Terrain.FLOOR or t == Terrain.KITCHEN or t == Terrain.DOOR


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
