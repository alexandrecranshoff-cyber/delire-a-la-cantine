class_name Cursors
## Curseurs de visée dessinés à la volée, au trait BD (contour noir épais), sans fichier image :
## ils servent tels quels aux versions web et PC.
## Chaque curseur prend la place d'une forme système (CROSS, FORBIDDEN, CAN_DROP) : on change de
## curseur en changeant la forme par défaut de la fenêtre, et les boutons de l'interface gardent la flèche.

enum Kind { DEFAULT, AIM, WATER, BLOCKED }

const SIZE := 48
const SAMPLES := 4      # suréchantillonnage par côté de pixel : bords adoucis
const OUTLINE := 2.0    # épaisseur du contour noir, en pixels

const INK := Color("1a1410")
const AIM_COLOR := Color("e8321e")
const WATER_COLOR := Color("2f7fe6")
const BLOCKED_COLOR := Color("9a9a9a")
const SLASH_COLOR := Color("b3261e")

const SHAPES := {
	Kind.AIM: Input.CURSOR_CROSS,
	Kind.WATER: Input.CURSOR_CAN_DROP,
	Kind.BLOCKED: Input.CURSOR_FORBIDDEN,
}

static var _installed := false


## Enregistre les trois curseurs auprès du système (une fois suffit).
static func install() -> void:
	if _installed:
		return
	var hotspot := Vector2(SIZE, SIZE) / 2.0
	for kind in SHAPES.keys():
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(make_image(kind)), SHAPES[kind], hotspot)
	_installed = true


## Rend la flèche normale et retire les curseurs (sortie de partie).
static func uninstall() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not _installed:
		return
	for kind in SHAPES.keys():
		Input.set_custom_mouse_cursor(null, SHAPES[kind])
	_installed = false


static func apply(kind: Kind) -> void:
	Input.set_default_cursor_shape(SHAPES.get(kind, Input.CURSOR_ARROW))


## Image du curseur : un viseur (cercle, quatre traits, point central), ou un viseur barré.
static func make_image(kind: Kind) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var main := AIM_COLOR
	if kind == Kind.WATER:
		main = WATER_COLOR
	elif kind == Kind.BLOCKED:
		main = BLOCKED_COLOR
	var step := 1.0 / SAMPLES
	for y in SIZE:
		for x in SIZE:
			var ink := 0.0
			var fill := 0.0
			var accent := 0.0
			for sy in SAMPLES:
				for sx in SAMPLES:
					var p := Vector2(x + (sx + 0.5) * step, y + (sy + 0.5) * step) - Vector2(SIZE, SIZE) / 2.0
					var d_main := _sight(p, kind)
					var d_accent := _slash(p) if kind == Kind.BLOCKED else INF
					var d_all := minf(d_main, d_accent)
					if d_all <= OUTLINE:
						ink += 1.0
					if d_main <= 0.0:
						fill += 1.0
					if d_accent <= 0.0:
						accent += 1.0
			var n := float(SAMPLES * SAMPLES)
			var c := Color(INK, ink / n)
			c = _over(c, Color(main, fill / n))
			c = _over(c, Color(SLASH_COLOR, accent / n))
			img.set_pixel(x, y, c)
	return img


## Distance signée au viseur (négative à l'intérieur du trait).
static func _sight(p: Vector2, kind: Kind) -> float:
	var r := 13.0
	var d := absf(p.length() - r) - 2.0
	# Quatre traits qui débordent du cercle, avec un vide au centre pour bien voir la cible.
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		d = minf(d, _segment(p, dir * 6.0, dir * 19.0) - 1.6)
	if kind != Kind.BLOCKED:
		d = minf(d, p.length() - 2.2)
	return d


static func _slash(p: Vector2) -> float:
	return _segment(p, Vector2(-11, -11), Vector2(11, 11)) - 2.4


static func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Superpose « top » sur « base » (alpha non prémultiplié).
static func _over(base: Color, top: Color) -> Color:
	var a := top.a + base.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(top.r, top.g, top.b) * top.a + Vector3(base.r, base.g, base.b) * base.a * (1.0 - top.a)) / a
	return Color(rgb.x, rgb.y, rgb.z, a)
