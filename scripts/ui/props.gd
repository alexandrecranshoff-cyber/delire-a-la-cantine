class_name Props
extends RefCounted
## Petits objets 3D du décor, modelés par le code : couverts, pichets, chariots, lavabos…
## Style BD : aplats de couleur (couleur par sommet), ombrage en deux tons et contour à l'encre
## obtenu par une coque retournée, un peu plus grande que la forme.

const INK := Color("1d1d1d")
const INOX := Color("c3ccd3")
const INOX_DARK := Color("8f9aa3")
const WHITE := Color("f6f2e6")
const WOOD := Color("9a643a")

static var _material: StandardMaterial3D
static var _cache := {}


## Assemble des formes simples dans un seul maillage coloré par sommet.
class Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var origin := Transform3D()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, outward: Vector3, flip: bool = false, na = null, nb = null, nc = null) -> void:
		# Godot attend des triangles dans le sens horaire vus de face.
		var n := (c - a).cross(b - a)
		if n.dot(outward) < 0.0:
			var t := b
			b = c
			c = t
			var tn = nb
			nb = nc
			nc = tn
			n = -n
		n = n.normalized()
		if flip:
			var t2 := b
			b = c
			c = t2
			var tn2 = nb
			nb = nc
			nc = tn2
		for i in 3:
			var p: Vector3 = [a, b, c][i]
			var pn = [na, nb, nc][i]
			verts.append(origin * p)
			normals.append(origin.basis * (n if pn == null else pn))
			colors.append(col)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3, flip: bool = false, smooth: Array = []) -> void:
		if smooth.is_empty():
			tri(a, b, c, col, outward, flip)
			tri(a, c, d, col, outward, flip)
		else:
			tri(a, b, c, col, outward, flip, smooth[0], smooth[1], smooth[2])
			tri(a, c, d, col, outward, flip, smooth[0], smooth[2], smooth[3])

	func _raw_box(center: Vector3, size: Vector3, col: Color, flip: bool) -> void:
		var h := size / 2.0
		for axis in 3:
			for s in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = s
				var u := Vector3.ZERO
				var v := Vector3.ZERO
				u[(axis + 1) % 3] = 1.0
				v[(axis + 2) % 3] = 1.0
				var o := center + n * h
				var du := u * h
				var dv := v * h
				quad(o - du - dv, o + du - dv, o + du + dv, o - du + dv, col, n, flip)

	## Boîte, avec son contour à l'encre si `ink` > 0.
	func box(center: Vector3, size: Vector3, col: Color, ink: float = 0.0) -> void:
		_raw_box(center, size, col, false)
		if ink > 0.0:
			_raw_box(center, size + Vector3.ONE * ink * 2.0, Props.INK, true)

	func _raw_cyl(base: Vector3, r0: float, r1: float, h: float, col: Color, seg: int, flip: bool) -> void:
		var top := base + Vector3(0, h, 0)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			quad(base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1, col, d0 + d1, flip, [d0, d1, d1, d0])
			tri(top, top + d0 * r1, top + d1 * r1, col, Vector3.UP, flip)
			tri(base, base + d0 * r0, base + d1 * r0, col, Vector3.DOWN, flip)

	## Cylindre ou tronc de cône debout, posé sur `base`.
	func cyl(base: Vector3, r0: float, r1: float, h: float, col: Color, ink: float = 0.0, seg: int = 12) -> void:
		_raw_cyl(base, r0, r1, h, col, seg, false)
		if ink > 0.0:
			_raw_cyl(base - Vector3(0, ink, 0), r0 + ink, r1 + ink, h + ink * 2.0, Props.INK, seg, true)

	## Petit tas arrondi (purée, pain…).
	func mound(base: Vector3, r: float, h: float, col: Color, ink: float = 0.0, seg: int = 10) -> void:
		cyl(base, r, r * 0.8, h * 0.55, col, ink, seg)
		cyl(base + Vector3(0, h * 0.55, 0), r * 0.8, r * 0.35, h * 0.45, col, 0.0, seg)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, Props.material())
		return mesh


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return _material


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var b := Builder.new()
		build.call(b)
		_cache[key] = b.commit()
	return _cache[key]


# --- Couverts ---------------------------------------------------------------------

const TRAY_COLORS := [Color("d9503c"), Color("3f7fd0"), Color("e9b93b")]
const FOOD_COLORS := [Color("a5c94f"), Color("cf7a33"), Color("f0d27a")]
const FOOD_EXTRA := [Color("8a4b2d"), Color("7fb04a"), Color("c9432f")]

## Plateau-repas complet : assiette garnie, verre, yaourt, pain, couverts. Origine au centre du
## plateau, posé sur la table ; +Z vers le convive.
static func tray(variant: int) -> ArrayMesh:
	variant = posmod(variant, 3)
	return _cached("tray%d" % variant, func(b: Builder):
		var col: Color = TRAY_COLORS[variant]
		b.box(Vector3(0, 0.02, 0), Vector3(0.82, 0.04, 0.56), col, 0.016)
		b.box(Vector3(0, 0.042, 0), Vector3(0.74, 0.006, 0.48), col.lightened(0.22))
		# Assiette et plat du jour.
		var p := Vector3(-0.15, 0.045, 0.03)
		b.cyl(p, 0.15, 0.2, 0.03, Props.WHITE, 0.014, 14)
		b.cyl(p + Vector3(0, 0.03, 0), 0.165, 0.165, 0.004, Color("e4dfd0"), 0.0, 14)
		b.mound(p + Vector3(-0.03, 0.03, 0.01), 0.11, 0.075, FOOD_COLORS[variant], 0.0)
		b.box(p + Vector3(0.09, 0.05, -0.04), Vector3(0.05, 0.04, 0.13), FOOD_EXTRA[variant], 0.006)
		# Verre d'eau.
		var g := Vector3(0.27, 0.045, -0.15)
		b.cyl(g, 0.05, 0.065, 0.17, Color("d6f0f7"), 0.012, 10)
		b.cyl(g + Vector3(0, 0.17, 0), 0.052, 0.052, 0.004, Color("6fc3ea"), 0.0, 10)
		# Yaourt.
		var y := Vector3(0.28, 0.045, 0.13)
		b.cyl(y, 0.045, 0.055, 0.08, Props.WHITE, 0.01, 10)
		b.cyl(y + Vector3(0, 0.08, 0), 0.058, 0.058, 0.008, [Color("e87aa0"), Color("7ab8e8"), Color("f0a020")][variant], 0.0, 10)
		# Pain.
		b.box(Vector3(0.05, 0.075, -0.2), Vector3(0.2, 0.06, 0.085), Color("dba85c"), 0.012)
		b.box(Vector3(0.05, 0.107, -0.2), Vector3(0.15, 0.006, 0.05), Color("f0cf8e"))
		# Fourchette et couteau.
		b.box(Vector3(0.09, 0.05, 0.08), Vector3(0.022, 0.008, 0.27), Props.INOX, 0.006)
		b.box(Vector3(0.14, 0.05, 0.08), Vector3(0.028, 0.008, 0.27), Props.INOX, 0.006)
	)


## Pichet d'eau.
static func pitcher() -> ArrayMesh:
	return _cached("pitcher", func(b: Builder):
		b.cyl(Vector3.ZERO, 0.12, 0.1, 0.32, Color("cfe9f2"), 0.014, 12)
		b.cyl(Vector3(0, 0.32, 0), 0.085, 0.085, 0.005, Color("6fc3ea"), 0.0, 12)
		b.box(Vector3(0.15, 0.2, 0), Vector3(0.05, 0.2, 0.04), Color("cfe9f2"), 0.01)
		b.box(Vector3(-0.115, 0.31, 0), Vector3(0.06, 0.03, 0.06), Color("cfe9f2"), 0.008)
	)


## Corbeille à pain.
static func basket() -> ArrayMesh:
	return _cached("basket", func(b: Builder):
		b.cyl(Vector3.ZERO, 0.17, 0.24, 0.12, Color("c58a45"), 0.014, 12)
		b.cyl(Vector3(0, 0.12, 0), 0.21, 0.21, 0.004, Color("8a5a2a"), 0.0, 12)
		b.box(Vector3(-0.06, 0.15, 0.02), Vector3(0.22, 0.07, 0.09), Color("dba85c"), 0.01)
		b.box(Vector3(0.07, 0.16, -0.05), Vector3(0.09, 0.07, 0.2), Color("e2b56c"), 0.01)
		b.box(Vector3(0.04, 0.2, 0.06), Vector3(0.18, 0.06, 0.08), Color("cf9a4e"), 0.01)
	)


## Pile d'assiettes propres (comptoir, chariot).
static func plates() -> ArrayMesh:
	return _cached("plates", func(b: Builder):
		for i in 5:
			b.cyl(Vector3(0, i * 0.035, 0), 0.15, 0.2, 0.028, Props.WHITE, 0.012 if i % 2 == 0 else 0.0, 14)
	)


## Bac gastro en inox rempli d'un plat, posé sur le comptoir du self. Origine au fond du bac.
static func gastro(food: Color) -> ArrayMesh:
	return _cached("gastro" + food.to_html(), func(b: Builder):
		b.box(Vector3(0, 0.07, 0), Vector3(0.62, 0.14, 0.46), Props.INOX, 0.012)
		b.box(Vector3(0, 0.145, 0), Vector3(0.54, 0.02, 0.38), food)
		for i in 3:
			b.mound(Vector3(-0.16 + i * 0.16, 0.15, 0.04 * (i % 2)), 0.1, 0.06, food.lightened(0.12))
		# Louche plantée dans le plat.
		b.box(Vector3(0.18, 0.3, -0.1), Vector3(0.03, 0.34, 0.03), Props.INOX_DARK, 0.006)
	)


## Grande marmite à couvercle. Origine au sol.
static func stockpot(color: Color) -> ArrayMesh:
	return _cached("marmite" + color.to_html(), func(b: Builder):
		b.cyl(Vector3.ZERO, 0.26, 0.26, 0.42, color, 0.014, 14)
		b.cyl(Vector3(0, 0.42, 0), 0.28, 0.2, 0.05, color.darkened(0.25), 0.012, 14)
		b.cyl(Vector3(0, 0.47, 0), 0.05, 0.05, 0.05, Color("2b2b33"), 0.0, 8)
		for sx in [-1.0, 1.0]:
			b.box(Vector3(sx * 0.3, 0.33, 0), Vector3(0.08, 0.04, 0.12), Color("2b2b33"))
	)


## Pile de plateaux vides.
static func tray_stack() -> ArrayMesh:
	return _cached("tray_stack", func(b: Builder):
		for i in 5:
			b.box(Vector3(0.01 * (i % 2), 0.025 + i * 0.05, 0), Vector3(0.8, 0.04, 0.54), TRAY_COLORS[i % 3], 0.012)
	)


# --- Chariot ----------------------------------------------------------------------

## Chariot de service en inox avec son bac plein. Origine au sol, au centre de la case ;
## la poignée est du côté -X.
static func cart(food: Color) -> ArrayMesh:
	return _cached("cart" + food.to_html(), func(b: Builder):
		var w := 0.92
		var d := 0.62
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := Vector3(sx * (w / 2.0 - 0.05), 0, sz * (d / 2.0 - 0.05))
				b.cyl(corner + Vector3(0, 0.0, 0), 0.07, 0.07, 0.1, Color("2b2b33"), 0.0, 8)
				b.box(corner + Vector3(0, 0.5, 0), Vector3(0.055, 0.8, 0.055), Props.INOX_DARK, 0.012)
		# Étagère basse avec des assiettes.
		b.box(Vector3(0, 0.3, 0), Vector3(w, 0.05, d), Props.INOX, 0.014)
		for i in 3:
			b.cyl(Vector3(-0.2 + 0.3 * (i % 2), 0.325 + i * 0.0, -0.08 + 0.16 * (i / 2)), 0.12, 0.15, 0.1, Props.WHITE, 0.01, 10)
		# Bac du haut.
		b.box(Vector3(0, 0.82, 0), Vector3(w + 0.04, 0.26, d + 0.04), Props.INOX, 0.018)
		b.box(Vector3(0, 0.955, 0), Vector3(w - 0.08, 0.012, d - 0.08), food)
		b.mound(Vector3(-0.18, 0.955, 0.05), 0.17, 0.12, food.lightened(0.12), 0.0)
		b.mound(Vector3(0.18, 0.955, -0.06), 0.14, 0.1, food.lightened(0.06), 0.0)
		b.mound(Vector3(0.05, 0.955, 0.14), 0.09, 0.07, food.darkened(0.08), 0.0)
		# Bandeau de couleur sur les grands côtés : on reconnaît le plat de loin.
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0, 0.82, sz * (d / 2.0 + 0.025)), Vector3(w - 0.2, 0.14, 0.012), food.darkened(0.12), 0.008)
		# Louche plantée dans le bac.
		b.cyl(Vector3(0.3, 0.95, 0.12), 0.018, 0.018, 0.34, Props.INOX_DARK, 0.008, 6)
		b.cyl(Vector3(0.3, 1.29, 0.12), 0.035, 0.035, 0.03, Color("2b2b33"), 0.0, 6)
		# Poignée.
		b.box(Vector3(-w / 2.0 - 0.1, 1.0, 0), Vector3(0.05, 0.05, d), Props.INOX_DARK, 0.012)
		for sz in [-1.0, 1.0]:
			b.box(Vector3(-w / 2.0 - 0.05, 0.96, sz * (d / 2.0 - 0.04)), Vector3(0.14, 0.04, 0.04), Props.INOX_DARK, 0.008)
	)


# --- Lavabo -----------------------------------------------------------------------

## Panneau de faïence verte derrière le lavabo. Origine au sol, au centre de la case du mur ;
## +Z vers la salle.
static func sink_panel(height: float) -> ArrayMesh:
	return _cached("sink_panel%.2f" % height, func(b: Builder):
		b.box(Vector3(0, 0.15 + height / 2.0, -0.12), Vector3(0.98, height, 0.06), Color("3f9a6a"), 0.016)
		var rows := int(height / 0.45)
		for i in rows:
			b.box(Vector3(0, 0.15 + height * (i + 1) / (rows + 1), -0.088), Vector3(0.94, 0.012, 0.008), Color("2f7a52"))
		for i in 2:
			b.box(Vector3(-0.16 + i * 0.32, 0.15 + height / 2.0, -0.088), Vector3(0.012, height - 0.1, 0.008), Color("2f7a52"))
	)


## Lavabo avec son robinet. Origine au sol, au centre de la case du mur ; +Z vers la salle.
static func sink() -> ArrayMesh:
	return _cached("sink", func(b: Builder):
		# Vasque et colonne.
		b.box(Vector3(0, 0.36, 0.1), Vector3(0.24, 0.72, 0.24), Props.WHITE, 0.014)
		b.box(Vector3(0, 0.8, 0.14), Vector3(0.84, 0.2, 0.52), Props.WHITE, 0.018)
		b.box(Vector3(0, 0.903, 0.16), Vector3(0.7, 0.008, 0.36), Color("6fc3ea"))
		# Robinet : col de cygne et deux poignées.
		b.cyl(Vector3(0, 0.9, -0.04), 0.04, 0.04, 0.34, Props.INOX, 0.012, 8)
		b.box(Vector3(0, 1.24, 0.07), Vector3(0.07, 0.06, 0.28), Props.INOX, 0.012)
		b.box(Vector3(0, 1.17, 0.18), Vector3(0.06, 0.1, 0.06), Props.INOX, 0.01)
		b.cyl(Vector3(-0.2, 0.9, -0.04), 0.045, 0.045, 0.09, Color("e23b30"), 0.01, 8)
		b.cyl(Vector3(0.2, 0.9, -0.04), 0.045, 0.045, 0.09, Color("2f7fe6"), 0.01, 8)
		# Filet d'eau.
		b.box(Vector3(0, 1.02, 0.18), Vector3(0.03, 0.22, 0.03), Color("9fdcf5"))
	)


# --- Mobilier mural -----------------------------------------------------------------

## Rail de portemanteau en bois avec ses patères. Origine au milieu du rail, +Z vers la salle.
static func coat_rail(length: float, pegs: int) -> ArrayMesh:
	return _cached("rail%.1f_%d" % [length, pegs], func(b: Builder):
		b.box(Vector3.ZERO, Vector3(length, 0.12, 0.04), Props.WOOD, 0.014)
		for i in pegs:
			var x := -length / 2.0 + length * (i + 0.5) / pegs
			b.box(Vector3(x, -0.01, 0.06), Vector3(0.04, 0.04, 0.1), Props.INOX_DARK, 0.008)
	)


## Élément de comptoir de self : façade turquoise, dessus inox. Origine au sol.
static func counter(height: float) -> ArrayMesh:
	return _cached("counter%.2f" % height, func(b: Builder):
		b.box(Vector3(0, height / 2.0, 0), Vector3(1.0, height, 1.0), Color("4fb3ad"))
		b.box(Vector3(0, 0.09, 0), Vector3(1.02, 0.18, 1.02), Color("2f6f6e"))
		b.box(Vector3(0, height + 0.03, 0), Vector3(1.08, 0.06, 1.08), Props.INOX)
	)


## Barre murale de cuisine avec louches, écumoires et poêles pendues. Origine au milieu de la barre.
static func utensil_rail(length: float) -> ArrayMesh:
	return _cached("ustensiles%.1f" % length, func(b: Builder):
		b.box(Vector3(0, 0, 0.05), Vector3(length, 0.04, 0.04), Props.INOX_DARK, 0.01)
		var n := maxi(3, int(length / 0.22))
		for i in n:
			var x := -length / 2.0 + length * (i + 0.5) / n
			match i % 4:
				0, 2:  # louche ou écumoire : manche et cuilleron
					b.box(Vector3(x, -0.2, 0.07), Vector3(0.025, 0.38, 0.02), Props.INOX, 0.006)
					b.cyl(Vector3(x, -0.46, 0.11), 0.07, 0.08, 0.06, Props.INOX if i % 4 == 0 else Props.INOX_DARK, 0.01, 8)
				1:  # poêle noire
					b.box(Vector3(x, -0.14, 0.07), Vector3(0.03, 0.26, 0.02), Color("2b2b33"))
					b.cyl(Vector3(x, -0.46, 0.2), 0.15, 0.15, 0.04, Color("2b2b33"), 0.012, 12)
				_:  # casserole cuivrée
					b.box(Vector3(x, -0.12, 0.07), Vector3(0.03, 0.22, 0.02), Color("8a5a2b"))
					b.cyl(Vector3(x, -0.4, 0.17), 0.12, 0.12, 0.05, Color("c8763a"), 0.012, 12)
	)


## Étagère murale de cuisine avec casseroles. Origine au milieu, +Z vers la pièce.
static func shelf(length: float) -> ArrayMesh:
	return _cached("shelf%.1f" % length, func(b: Builder):
		b.box(Vector3(0, 0, 0.12), Vector3(length, 0.05, 0.3), Props.INOX, 0.012)
		var n := int(length / 0.6)
		for i in n:
			var x := -length / 2.0 + length * (i + 0.5) / n
			if i % 3 == 0:
				b.cyl(Vector3(x, 0.025, 0.12), 0.16, 0.16, 0.2, Color("b9482f"), 0.012, 10)
				b.box(Vector3(x, 0.24, 0.12), Vector3(0.36, 0.03, 0.06), Color("2b2b33"))
			elif i % 3 == 1:
				b.cyl(Vector3(x, 0.025, 0.12), 0.13, 0.15, 0.28, Props.INOX_DARK, 0.012, 10)
			else:
				for k in 3:
					b.cyl(Vector3(x, 0.025 + k * 0.035, 0.12), 0.12, 0.16, 0.028, Props.WHITE, 0.01 if k == 0 else 0.0, 10)
	)
