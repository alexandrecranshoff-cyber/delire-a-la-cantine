class_name Trajectory
extends RefCounted
## Trajectoire d'un projectile (livret, figure 2) : en ligne directe si tireur et cible
## sont alignés, sinon en diagonale jusqu'à la rangée ou la colonne de la cible, puis tout droit.


## Cases parcourues après le tireur, cible comprise.
static func cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur := from
	while cur != to:
		cur += Vector2i(signi(to.x - cur.x), signi(to.y - cur.y))
		out.append(cur)
	return out


## La droite « réelle » entre les centres des deux cases traverse-t-elle un mur ?
## Sert aussi à la ligne de vue.
static func blocked_by_wall(board: Board, from: Vector2i, to: Vector2i) -> bool:
	var a := Vector2(from)
	var b := Vector2(to)
	var samples := maxi(1, ceili(a.distance_to(b) * 8.0))
	for i in range(1, samples):
		var p := a.lerp(b, float(i) / samples)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if c != from and c != to and board.blocks_shot(c):
			return true
	return false


## Case de chute d'un tir raté (« a » de la figure 1) : la dernière case avant la cible.
static func landing_cell(from: Vector2i, to: Vector2i) -> Vector2i:
	var path := cells(from, to)
	return path[path.size() - 2] if path.size() >= 2 else from


## Cases susceptibles d'être touchées par un tir raté, par ordre de priorité (figure 1) :
## a (case de chute), b (sur la trajectoire, juste avant a), puis 1 à 6 autour de a.
## La cible, juste après a, n'en fait pas partie.
static func miss_candidates(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var a := landing_cell(from, to)
	var forward := to - a
	var i := Board.DIRECTIONS.find(forward)
	var out: Array[Vector2i] = [a]
	if i < 0:
		return out
	# Décalages dans l'ordre b, 1, 2, 3, 4, 5, 6 (rotation de 45° par cran).
	for k in [4, 3, 5, 2, 6, 1, 7]:
		out.append(a + Board.DIRECTIONS[(i + k) % 8])
	return out
