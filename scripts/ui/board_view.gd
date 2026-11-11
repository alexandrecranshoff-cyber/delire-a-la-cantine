class_name BoardView
extends Node3D
## Décor du niveau : carrelage en damier, murs décorés (hauts au fond, abaissés côté caméra),
## tables garnies de plateaux-repas, comptoir du self, portes battantes numérotées, bacs et
## lavabos. Une case = 1 m. Tout est construit à partir du plan (Board) et du niveau (tables,
## portes, bacs) : aucune position de jeu n'est écrite en dur ici.

const TABLE_HEIGHT := 0.75
const WALL_HEIGHT := 2.6       # murs du fond, avec leur décor
const WALL_LOW := 0.45         # murs entre la caméra et la salle : on voit par-dessus
const COUNTER_HEIGHT := 1.05   # cloison salle / cuisine : le comptoir du self
const DOOR_HEIGHT := 2.1
const SIDES := {"N": Vector2(0, -1), "S": Vector2(0, 1), "W": Vector2(-1, 0), "E": Vector2(1, 0)}

var board: Board
var level: Level
var _sides := {}               # "N" -> {"tall": Node3D, "low": Node3D, "lowered": bool}
var _door_plates: Array = []   # [Label3D, côté]
var _table_sets: Array[MultiMeshInstance3D] = []   # couverts : disparaissent quand les tables sont vides
var _cam_angle := 45.0
var _rng := RandomNumberGenerator.new()


func build(p_board: Board, p_level: Level) -> void:
	board = p_board
	level = p_level
	_rng.seed = 1984
	for key in SIDES.keys():
		var tall := Node3D.new()
		var low := Node3D.new()
		add_child(tall)
		add_child(low)
		_sides[key] = {"tall": tall, "low": low, "lowered": false}
	_build_backdrop()
	_build_floor()
	_build_walls()
	_build_wall_decor()
	_build_tables()
	_build_doors()
	_build_fixtures()
	_build_fog()
	face_camera(_cam_angle)


static func cell_to_world(c: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(c.x, height, c.y)


# --- Matériaux ------------------------------------------------------------------

func _tiled(texture_name: String, scale: Vector3, offset: Vector3 = Vector3.ZERO) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = GameAssets.texture("textures", texture_name)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = scale
	m.uv1_offset = offset
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if GameAssets.is_hd() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _multimesh(mesh: Mesh, transforms: Array, shadows: bool = true, parent: Node3D = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(inst)
	return inst


func _box(size: Vector3, material: Material) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = material
	return b


func _mesh_at(mesh: Mesh, pos: Vector3, yaw: float = 0.0, parent: Node3D = null, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


func _plate(text: String, pos: Vector3, color: Color, size: int = 64) -> Label3D:
	var plate := Label3D.new()
	plate.text = text
	plate.font = BD.title_font()
	plate.font_size = size
	plate.outline_size = int(size * 0.28)
	plate.pixel_size = 0.006
	plate.modulate = color
	plate.outline_modulate = BD.INK
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 3
	plate.outline_render_priority = 2
	plate.position = pos
	add_child(plate)
	return plate


# --- Sol ------------------------------------------------------------------------

## Grand plan sous la salle, pour que le plateau ne flotte pas dans un aplat uni.
func _build_backdrop() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(board.width + 120, board.height + 120)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fond.gdshader")
	var c := Vector3(board.width / 2.0 - 0.5, 0, board.height / 2.0 - 0.5)
	mat.set_shader_parameter("center", c)
	mat.set_shader_parameter("half_size", Vector2(board.width / 2.0 + 0.5, board.height / 2.0 + 0.5))
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = c + Vector3(0, -0.06, 0)
	add_child(mi)


func _build_floor() -> void:
	var room := []
	var kitchen := []
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			var t := board.terrain(c)
			if t == Board.Terrain.WALL:
				continue
			var tr := Transform3D(Basis(), cell_to_world(c))
			if t == Board.Terrain.KITCHEN or (t in [Board.Terrain.TUB, Board.Terrain.DISH_TUB]) or (t == Board.Terrain.DOOR and _near_kitchen(c)):
				kitchen.append(tr)
			else:
				room.append(tr)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	# La texture couvre 8 × 8 cases ; le décalage aligne les joints sur les bords des cases.
	plane.material = _tiled("sol_salle.png", Vector3(0.125, 0.125, 0.125), Vector3(0.0625, 0, 0.0625))
	_multimesh(plane, room, false)
	var plane_k := PlaneMesh.new()
	plane_k.size = Vector2.ONE
	plane_k.material = _tiled("sol_cuisine.png", Vector3(0.125, 0.125, 0.125), Vector3(0.0625, 0, 0.0625))
	_multimesh(plane_k, kitchen, false)
	# Socle sombre sous le plateau, comme l'épaisseur d'un plateau de jeu.
	var slab := MeshInstance3D.new()
	slab.mesh = _box(Vector3(board.width + 0.6, 0.5, board.height + 0.6), _flat(Color("2a2136")))
	slab.position = Vector3((board.width - 1) / 2.0, -0.26, (board.height - 1) / 2.0)
	add_child(slab)


func _near_kitchen(c: Vector2i) -> bool:
	for n in Board.neighbors8(c):
		if board.is_kitchen(n):
			return true
	return false


func _near_room(c: Vector2i) -> bool:
	for n in Board.neighbors8(c):
		if board.terrain(n) == Board.Terrain.FLOOR:
			return true
	return false


# --- Murs -----------------------------------------------------------------------

## Côtés du plateau auxquels appartient une case (deux pour un coin, aucun à l'intérieur).
func _sides_of(c: Vector2i) -> Array:
	var out := []
	if c.y == 0:
		out.append("N")
	if c.y == board.height - 1:
		out.append("S")
	if c.x == 0:
		out.append("W")
	if c.x == board.width - 1:
		out.append("E")
	return out


func _inward(side: String) -> Vector3:
	var n: Vector2 = SIDES[side]
	return Vector3(-n.x, 0, -n.y)


func _build_walls() -> void:
	# La texture de mur fait 2 m de large et toute la hauteur du mur : un mur abaissé n'en montre
	# que le bas (la plinthe et le soubassement turquoise).
	var scale := Vector3(0.5, 1.0 / WALL_HEIGHT, 0.5)
	var mats := {false: _tiled("mur_salle.png", scale), true: _tiled("mur_cuisine.png", scale)}
	var ink := _flat(BD.INK, true)
	var top := _flat(Color("8a6a2c"), true)
	var lists := {}
	for key in SIDES.keys():
		lists[key] = {false: [], true: [], "lintel": {false: [], true: []}}
	var counters := []
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			var t := board.terrain(c)
			var sides := _sides_of(c)
			if sides.is_empty():
				if t == Board.Terrain.WALL:
					counters.append(Transform3D(Basis(), cell_to_world(c)))
				continue
			var kitchen := _near_kitchen(c) and not _near_room(c)
			for side in sides:
				match t:
					Board.Terrain.WALL:
						lists[side][kitchen].append(c)
					Board.Terrain.TAP:
						_build_tap_wall(c, side, mats[false], ink, top)
					Board.Terrain.DOOR, Board.Terrain.TUB, Board.Terrain.DISH_TUB:
						lists[side]["lintel"][kitchen].append(c)
	for side in SIDES.keys():
		var tall: Node3D = _sides[side]["tall"]
		var low: Node3D = _sides[side]["low"]
		var caps_tall := []
		var caps_low := []
		for kitchen in [false, true]:
			var tr_tall := []
			var tr_low := []
			for c in lists[side][kitchen]:
				tr_tall.append(Transform3D(Basis(), cell_to_world(c, WALL_HEIGHT / 2.0)))
				tr_low.append(Transform3D(Basis(), cell_to_world(c, WALL_LOW / 2.0)))
				caps_tall.append(Transform3D(Basis(), cell_to_world(c, WALL_HEIGHT + 0.02)))
				caps_low.append(Transform3D(Basis(), cell_to_world(c, WALL_LOW + 0.02)))
			_multimesh(_box(Vector3(1, WALL_HEIGHT, 1), mats[kitchen]), tr_tall, true, tall)
			_multimesh(_box(Vector3(1, WALL_LOW, 1), mats[kitchen]), tr_low, false, low)
			# Au-dessus des portes et des bacs, le mur continue : linteau.
			var lintels := []
			var bottom := DOOR_HEIGHT + 0.12
			for c in lists[side]["lintel"][kitchen]:
				lintels.append(Transform3D(Basis(), cell_to_world(c, (bottom + WALL_HEIGHT) / 2.0)))
				caps_tall.append(Transform3D(Basis(), cell_to_world(c, WALL_HEIGHT + 0.02)))
			_multimesh(_box(Vector3(1, WALL_HEIGHT - bottom, 1), mats[kitchen]), lintels, true, tall)
		# Ombre dessinée au pied du mur haut : elle détache le mur du carrelage.
		var inward := _inward(side)
		var shade_tr := []
		for kitchen in [false, true]:
			for c in lists[side][kitchen]:
				var inner: Vector2i = c + Vector2i(int(inward.x), int(inward.z))
				if board.in_bounds(inner) and not _sides_of(inner).is_empty():
					continue  # coin : la case voisine est elle-même un mur
				shade_tr.append(Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.z)), cell_to_world(c, 0.014) + inward * 0.95))
		_multimesh(_wall_shade_mesh(), shade_tr, false, tall)
		# Dessus des murs : trait d'encre épais, comme une coupe de BD.
		for pair in [[caps_tall, tall], [caps_low, low]]:
			_multimesh(_box(Vector3(1.05, 0.05, 1.05), ink), pair[0], false, pair[1])
			var tops := []
			for tr in pair[0]:
				tops.append(tr.translated(Vector3(0, 0.03, 0)))
			_multimesh(_box(Vector3(1.0, 0.03, 1.0), top), tops, false, pair[1])
	# Cloison entre la salle et la cuisine : le comptoir du self, garni de vaisselle propre.
	_multimesh(Props.counter(COUNTER_HEIGHT), counters)
	# Le self est garni sur toute sa longueur : bacs de plats du jour, piles d'assiettes et de plateaux.
	var deco := [Props.gastro(Color("a5c94f")), Props.plates(), Props.gastro(Color("e08a3a")), Props.tray_stack(),
		Props.gastro(Color("f2e2b0")), Props.pitcher(), Props.gastro(Color("c9452f")), Props.basket()]
	for i in counters.size():
		var pos: Vector3 = counters[i].origin
		if i % 6 == 5:
			continue  # un vide de temps en temps, pour ne pas faire un mur d'objets
		_mesh_at(deco[i % deco.size()], pos + Vector3(0, COUNTER_HEIGHT + 0.06, 0), _rng.randf_range(-0.15, 0.15))
	_build_kitchen_clutter(lists)


## Cuisine : taches de graisse au sol et marmites posées sur les murets abaissés, pour qu'elle
## reste habitée vue de l'angle par défaut (ses murs côté caméra sont abaissés).
func _build_kitchen_clutter(lists: Dictionary) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.32, 0.24, 0.1, 0.42))
	gradient.set_color(1, Color(0.32, 0.24, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = mat
	var stains := []
	for c in board.cells_of(Board.Terrain.KITCHEN):
		if _rng.randf() < 0.22:
			var s := _rng.randf_range(0.7, 1.6)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, 1, s * _rng.randf_range(0.6, 1.0)))
			stains.append(Transform3D(basis, cell_to_world(c, 0.012) + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))))
	_multimesh(plane, stains, false)
	var pots := [Props.stockpot(Props.INOX), Props.stockpot(Color("b9482f")), Props.plates(), Props.stockpot(Props.INOX_DARK)]
	var k := 0
	for side in SIDES.keys():
		for c in lists[side][true]:
			k += 1
			if k % 3 != 0:
				continue
			_mesh_at(pots[(k / 3) % pots.size()], cell_to_world(c, WALL_LOW + 0.05), _rng.randf_range(0, TAU), _sides[side]["low"])


## Bande d'ombre en dégradé, posée au sol le long d'un mur (le mur est du côté -Z).
func _wall_shade_mesh() -> PlaneMesh:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.06, 0.04, 0.12, 0.36))
	gradient.set_color(1, Color(0.06, 0.04, 0.12, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 0.9)
	plane.material = mat
	return plane


## Case de robinet : le mur y est plus mince, le lavabo tient dans la niche.
func _build_tap_wall(c: Vector2i, side: String, mat: Material, ink: Material, top: Material) -> void:
	var inward := _inward(side)
	var across := Vector3(absf(inward.z), 0, absf(inward.x))
	var size_xz := across * 1.0 + Vector3(absf(inward.x), 0, absf(inward.z)) * 0.36
	for pair in [[WALL_HEIGHT, _sides[side]["tall"]], [WALL_LOW, _sides[side]["low"]]]:
		var h: float = pair[0]
		var pos := cell_to_world(c) - inward * 0.32
		_mesh_at(_box(size_xz + Vector3(0, h, 0), mat), pos + Vector3(0, h / 2.0, 0), 0.0, pair[1])
		_mesh_at(_box(size_xz + Vector3(0.05, 0.05, 0.05), ink), pos + Vector3(0, h + 0.02, 0), 0.0, pair[1], false)
		_mesh_at(_box(size_xz + Vector3(0, 0.03, 0), top), pos + Vector3(0, h + 0.05, 0), 0.0, pair[1], false)


# --- Décor des murs -----------------------------------------------------------------

## Point du mur `side`, sur sa face intérieure : `along` suit le mur (x ou y du plan).
func _wall_point(side: String, along: float, height: float, out: float = 0.02) -> Vector3:
	var inward := _inward(side)
	var base: Vector3
	match side:
		"N":
			base = Vector3(along, height, 0)
		"S":
			base = Vector3(along, height, board.height - 1)
		"W":
			base = Vector3(0, height, along)
		_:
			base = Vector3(board.width - 1, height, along)
	return base + inward * (0.5 + out)


func _wall_yaw(side: String) -> float:
	var inward := _inward(side)
	return atan2(inward.x, inward.z)


## Une portion de mur est libre si toutes ses cases sont du mur plein.
func _wall_free(side: String, from: float, to: float) -> bool:
	for i in range(int(floor(from + 0.5)), int(floor(to + 0.5)) + 1):
		var c := Vector2i(i, 0)
		match side:
			"S":
				c = Vector2i(i, board.height - 1)
			"W":
				c = Vector2i(0, i)
			"E":
				c = Vector2i(board.width - 1, i)
		if not board.in_bounds(c) or board.terrain(c) != Board.Terrain.WALL:
			return false
	return true


## Dessin plat accroché au mur (fenêtre, manteau, affiche…). Renvoie faux si la place manque.
func _wall_sprite(side: String, name: String, along: float, center_y: float, height: float, out: float = 0.02) -> bool:
	var tex := GameAssets.texture("decor", name + ".png")
	if tex == null:
		return false
	var width := height * tex.get_width() / float(tex.get_height())
	if not _wall_free(side, along - width / 2.0, along + width / 2.0):
		return false
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if GameAssets.is_hd() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material = mat
	_mesh_at(quad, _wall_point(side, along, center_y, out), _wall_yaw(side), _sides[side]["tall"], false)
	return true


func _build_wall_decor() -> void:
	var w := board.width
	var h := board.height
	# Limite entre la salle et la cuisine le long des murs latéraux.
	var split := h
	for y in h:
		if board.is_kitchen(Vector2i(1, y)):
			split = y
			break
	# Mur du fond : les portemanteaux du plateau d'origine, garnis, et l'horloge.
	var doors_n := []
	for x in w:
		if board.terrain(Vector2i(x, 0)) == Board.Terrain.DOOR:
			doors_n.append(x)
	var coats := range(10)
	var coat := 0
	var mid := (w - 1) / 2.0
	for dir: float in [-1.0, 1.0]:
		var length := 9.0
		var center: float = mid + dir * (length / 2.0 + 1.5)
		if not _wall_free("N", center - length / 2.0, center + length / 2.0):
			continue
		var pegs := 8
		_mesh_at(Props.coat_rail(length, pegs), _wall_point("N", center, 1.66, 0.03), _wall_yaw("N"), _sides["N"]["tall"])
		for i in pegs:
			if (i + int(dir)) % 4 == 2:
				continue  # quelques patères restent vides
			var x: float = center - length / 2.0 + length * (i + 0.5) / pegs
			var name := "manteau_%d" % coats[coat % coats.size()]
			coat += 3
			var small := name in ["manteau_6", "manteau_7"]
			var ch := 0.78 if small else _rng.randf_range(0.86, 0.98)
			_wall_sprite("N", name, x, 1.7 - ch / 2.0, ch, 0.09)
	_wall_sprite("N", "horloge", mid, 2.08, 0.62)
	_wall_sprite("N", "panneau_liege", mid, 1.2, 0.8)
	# Murs latéraux : fenêtres, radiateurs dessous, affiche près du robinet.
	for side in ["W", "E"]:
		var x_cell := 0 if side == "W" else w - 1
		var windows := 0
		for z in [3.5, 8.5, 17.5, 21.0]:
			if z < split - 2 and _wall_sprite(side, "fenetre", z, 1.62, 1.5):
				if windows % 2 == 1:
					_wall_sprite(side, "radiateur", z, 0.45, 0.62, 0.06)
				windows += 1
		for y in h:
			if board.terrain(Vector2i(x_cell, y)) == Board.Terrain.TAP:
				_wall_sprite(side, "affiche_mains", y - 1.6, 1.55, 0.78)
		if side == "E":
			_wall_sprite(side, "menu", split - 5.8, 1.55, 0.95)
			_wall_sprite(side, "photo_classe", 1.3, 1.6, 0.6)
		else:
			_wall_sprite(side, "extincteur", split - 5.6, 0.95, 0.72, 0.05)
		# Cuisine : des étagères de casseroles, une sur deux plus haute, sans boucher les portes.
		var k := 0
		for kz: float in range(split + 1, h - 1, 3):
			if _wall_free(side, kz - 0.8, kz + 0.8):
				_mesh_at(Props.shelf(1.8), _wall_point(side, kz, 1.5 if k % 2 == 0 else 1.95, 0.0), _wall_yaw(side), _sides[side]["tall"])
			# Entre deux étagères : louches et poêles pendues à une barre.
			if kz + 1.5 < h - 1 and _wall_free(side, kz + 0.9, kz + 2.1):
				_mesh_at(Props.utensil_rail(1.1), _wall_point(side, kz + 1.5, 1.95 if k % 2 == 0 else 1.55, 0.0), _wall_yaw(side), _sides[side]["tall"])
			k += 1
	for x in [5.0, 10.0, w - 11.0, w - 6.0]:
		if _wall_free("S", x - 1.5, x + 1.5):
			_mesh_at(Props.shelf(3.0), _wall_point("S", x, 1.5, 0.0), _wall_yaw("S"), _sides["S"]["tall"])
			_mesh_at(Props.shelf(3.0), _wall_point("S", x, 2.05, 0.0), _wall_yaw("S"), _sides["S"]["tall"])
	for x in [7.5, w - 8.5, mid]:
		if _wall_free("S", x - 0.7, x + 0.7):
			_mesh_at(Props.utensil_rail(1.3), _wall_point("S", x, 1.8, 0.0), _wall_yaw("S"), _sides["S"]["tall"])



# --- Tables -----------------------------------------------------------------------

func _build_tables() -> void:
	var legs := []
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_texture = GameAssets.texture("textures", "table.png")
	top_mat.roughness = 1.0
	top_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if GameAssets.is_hd() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var edge_mat := _flat(Color("d9718d"))
	var ink := _flat(BD.INK, true)
	var trays := [[], [], []]
	var pitchers := []
	var baskets := []
	var index := 0
	for key in level.raw["tables"].keys():
		var cells: Array = level.raw["tables"][key]
		var x0 := 1 << 20
		var y0 := 1 << 20
		var x1 := -1
		var y1 := -1
		for v in cells:
			x0 = mini(x0, int(v[0]))
			x1 = maxi(x1, int(v[0]))
			y0 = mini(y0, int(v[1]))
			y1 = maxi(y1, int(v[1]))
		var w := float(x1 - x0 + 1)
		var d := float(y1 - y0 + 1)
		var center := Vector3((x0 + x1) / 2.0, 0, (y0 + y1) / 2.0)
		# Plateau : tranche rose foncé, dessus texturé, filet d'encre dessous.
		var slab := MeshInstance3D.new()
		slab.mesh = _box(Vector3(w - 0.08, 0.1, d - 0.08), edge_mat)
		slab.position = center + Vector3(0, TABLE_HEIGHT - 0.05, 0)
		add_child(slab)
		var under := MeshInstance3D.new()
		under.mesh = _box(Vector3(w - 0.02, 0.04, d - 0.02), ink)
		under.position = center + Vector3(0, TABLE_HEIGHT - 0.11, 0)
		add_child(under)
		var top := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(w - 0.08, d - 0.08)
		plane.material = top_mat
		top.mesh = plane
		top.position = center + Vector3(0, TABLE_HEIGHT + 0.002, 0)
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if d > w:
			top.rotation.y = PI / 2.0
			plane.size = Vector2(d - 0.08, w - 0.08)
		add_child(top)
		# Ombre de la table dessinée sur le carrelage.
		var shade := MeshInstance3D.new()
		var shade_plane := PlaneMesh.new()
		shade_plane.size = Vector2(w, d)
		var shade_mat := _flat(Color(0.06, 0.04, 0.12, 0.26), true)
		shade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shade_plane.material = shade_mat
		shade.mesh = shade_plane
		shade.position = center + PawnView.SHADOW_DIR * 0.45 + Vector3(0, 0.012, 0)
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shade)
		for lx in [x0 - 0.3, (x0 + x1) / 2.0, x1 + 0.3]:
			for lz in [y0 - 0.3, y1 + 0.3]:
				legs.append(Transform3D(Basis(), Vector3(lx, (TABLE_HEIGHT - 0.1) / 2.0, lz)))
		# Couverts : un plateau-repas devant chaque place des deux grands côtés, pichets et
		# corbeilles au milieu. Tant que les tables sont garnies, on y trouve des munitions.
		var along_x := w >= d
		var length := int(w if along_x else d)
		var half := (d if along_x else w) / 2.0
		var surface := TABLE_HEIGHT + 0.004
		for i in length:
			for s: float in [-1.0, 1.0]:
				var off: float = s * (half - 0.4)
				var pos: Vector3 = Vector3(x0 + i, surface, center.z + off) if along_x else Vector3(center.x + off, surface, y0 + i)
				var yaw: float = (0.0 if s > 0.0 else PI) if along_x else (PI / 2.0 if s > 0.0 else -PI / 2.0)
				yaw += _rng.randf_range(-0.07, 0.07)
				pos += Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.03, 0.03))
				trays[(i * 2 + index + int(s > 0.0)) % 3].append(Transform3D(Basis(Vector3.UP, yaw), pos))
		var n := 0
		var t := 1.5
		while t < length - 1.0:
			var pos := Vector3(x0 - 0.5 + t, surface, center.z) if along_x else Vector3(center.x, surface, y0 - 0.5 + t)
			var tr := Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)), pos)
			if n % 2 == 0:
				pitchers.append(tr)
			else:
				baskets.append(tr)
			n += 1
			t += 1.75
		index += 1
	_multimesh(_box(Vector3(0.09, TABLE_HEIGHT - 0.1, 0.09), _tiled("inox.png", Vector3(1, 1, 1))), legs)
	for v in 3:
		# Ordre mélangé : les plateaux qui restent après le tour 4 se répartissent sur toutes les tables.
		_shuffle(trays[v])
		_table_sets.append(_multimesh(Props.tray(v), trays[v], false))
	_shuffle(pitchers)
	_table_sets.append(_multimesh(Props.pitcher(), pitchers, false))
	_table_sets.append(_multimesh(Props.basket(), baskets, false))


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t


## Les tables se vident à la fin du tour 4 (livret) : plus de couverts, plus de munitions.
func set_tables_stocked(stocked: bool) -> void:
	for inst in _table_sets:
		var mm := inst.multimesh
		if stocked:
			mm.visible_instance_count = -1
		elif mm.visible_instance_count == -1:
			# Tables vidées : il reste quelques plateaux abandonnés, pas de grands aplats nus.
			var left := int(mm.instance_count * 0.35)
			var tw := create_tween()
			tw.tween_method(func(v: int): mm.visible_instance_count = v, mm.instance_count, left, 0.7)


# --- Portes -----------------------------------------------------------------------

func _build_doors() -> void:
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_texture = GameAssets.texture("textures", "porte.png")
	door_mat.roughness = 1.0
	door_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	door_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame_mat := _flat(Color("3f6b45"))
	var ink := _flat(BD.INK, true)
	for key in level.raw["portes"].keys():
		var cells := level.door_cells(key)
		var mid := Vector3.ZERO
		for c in cells:
			mid += cell_to_world(c)
		mid /= float(cells.size())
		var sides := _sides_of(cells[0])
		var side: String = sides[0] if not sides.is_empty() else "N"
		# La porte regarde vers l'intérieur de la pièce.
		var inward := _inward(side)
		var width := float(cells.size())
		for tall in [true, false]:
			var holder := Node3D.new()
			holder.position = mid - inward * 0.42
			holder.rotation.y = atan2(inward.x, inward.z)
			_sides[side]["tall" if tall else "low"].add_child(holder)
			if not tall:
				# Mur abaissé : il reste le seuil et les deux montants coupés.
				var sill := MeshInstance3D.new()
				sill.mesh = _box(Vector3(width, 0.04, 0.3), frame_mat)
				sill.position = Vector3(0, 0.02, 0.1)
				holder.add_child(sill)
				for sx in [-1.0, 1.0]:
					var post := MeshInstance3D.new()
					post.mesh = _box(Vector3(0.14, WALL_LOW + 0.12, 0.2), frame_mat)
					post.position = Vector3(sx * (width / 2.0 + 0.01), (WALL_LOW + 0.12) / 2.0, 0)
					holder.add_child(post)
				continue
			var frame := MeshInstance3D.new()
			frame.mesh = _box(Vector3(width + 0.16, DOOR_HEIGHT + 0.1, 0.16), frame_mat)
			frame.position.y = (DOOR_HEIGHT + 0.1) / 2.0
			holder.add_child(frame)
			var back := MeshInstance3D.new()
			back.mesh = _box(Vector3(width + 0.26, DOOR_HEIGHT + 0.2, 0.1), ink)
			back.position = Vector3(0, (DOOR_HEIGHT + 0.2) / 2.0, -0.02)
			holder.add_child(back)
			for face in [1.0, -1.0]:
				var leaf := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(width, DOOR_HEIGHT)
				quad.material = door_mat
				leaf.mesh = quad
				leaf.position = Vector3(0, DOOR_HEIGHT / 2.0, 0.085 * face)
				leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if face < 0.0:
					leaf.rotation.y = PI
				holder.add_child(leaf)
		# Numéro de la porte : les profs entrent par la porte tirée au dé.
		var plate := _plate(key, mid - inward * 0.3, BD.YELLOW, 96)
		_door_plates.append([plate, side])


# --- Bacs, lavabos ------------------------------------------------------------------

func _build_fixtures() -> void:
	for c in board.cells_of(Board.Terrain.TAP):
		var sides := _sides_of(c)
		var side: String = sides[0] if not sides.is_empty() else "W"
		var inward := _inward(side)
		var yaw := atan2(inward.x, inward.z)
		_mesh_at(Props.sink(), cell_to_world(c), yaw)
		# Le panneau de faïence suit le mur : haut au fond, coupé côté caméra pour ne pas cacher la vasque.
		_mesh_at(Props.sink_panel(1.7), cell_to_world(c), yaw, _sides[side]["tall"])
		_mesh_at(Props.sink_panel(WALL_LOW + 0.1), cell_to_world(c), yaw, _sides[side]["low"])
		_plate("ROBINET", cell_to_world(c) + inward * 0.3 + Vector3(0, 2.2, 0), Color("8fdcff"), 56)
	var names := {"bac_puree": "BAC À PURÉE", "bac_tripes": "BAC À TRIPES", "bac_vaisselle": "VAISSELLE"}
	var colors := {"bac_puree": Color("a5c94f"), "bac_tripes": Color("cf7a33"), "bac_vaisselle": Color("9fd0e6")}
	for key in level.raw["bacs"].keys():
		var mid := Vector3.ZERO
		var cells: Array = level.raw["bacs"][key]
		for v in cells:
			mid += Vector3(float(v[0]), 0, float(v[1]))
		mid /= float(cells.size())
		var base := MeshInstance3D.new()
		base.mesh = _box(Vector3(cells.size(), 0.9, 1.0), _tiled("inox.png", Vector3(1, 1, 1)))
		base.position = mid + Vector3(0, 0.45, 0)
		add_child(base)
		var rim := MeshInstance3D.new()
		rim.mesh = _box(Vector3(cells.size() + 0.06, 0.06, 1.06), _flat(BD.INK, true))
		rim.position = mid + Vector3(0, 0.93, 0)
		add_child(rim)
		var food := MeshInstance3D.new()
		var col: Color = colors.get(key, Color.WHITE)
		food.mesh = _box(Vector3(cells.size() - 0.24, 0.05, 0.76), _flat(col, true))
		food.position = mid + Vector3(0, 0.96, 0)
		add_child(food)
		if key == "bac_vaisselle":
			for i in 3:
				_mesh_at(Props.plates(), mid + Vector3(-0.5 + i * 0.5, 0.98, 0.05 * (i % 2)))
		else:
			var b := Props.Builder.new()
			for i in 4:
				b.mound(Vector3(-0.6 + i * 0.4, 0, _rng.randf_range(-0.15, 0.15)), _rng.randf_range(0.16, 0.24), _rng.randf_range(0.1, 0.18), col.lightened(0.1 * (i % 2)))
			_mesh_at(b.commit(), mid + Vector3(0, 0.98, 0))
		_plate(names.get(key, key), mid + Vector3(0, 1.6, 0), Color.WHITE, 56)


## Les murs situés entre la caméra et la salle s'abaissent pour laisser voir le jeu.
func face_camera(angle_deg: float) -> void:
	_cam_angle = angle_deg
	var a := deg_to_rad(angle_deg)
	var toward := Vector2(sin(a), cos(a))
	for key in _sides.keys():
		var lowered := toward.dot(SIDES[key]) > 0.17
		_sides[key]["lowered"] = lowered
		_sides[key]["tall"].visible = not lowered
		_sides[key]["low"].visible = lowered
	for pair in _door_plates:
		var plate: Label3D = pair[0]
		plate.position.y = 1.0 if _sides[pair[1]]["lowered"] else DOOR_HEIGHT + 0.5


# --- Brouillard -------------------------------------------------------------------
## Deux voiles (sol et dessus des tables) lisent la même carte de visibilité, un texel par case :
## les bords sont adoucis par le filtrage au lieu de carrés durs.

const FOG_SHADER := preload("res://shaders/brouillard.gdshader")

var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_planes: Array[MeshInstance3D] = []


func _build_fog() -> void:
	_fog_image = Image.create(board.width, board.height, false, Image.FORMAT_RG8)
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	for layer in 2:
		var plane := PlaneMesh.new()
		plane.size = Vector2(board.width, board.height)
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("hidden_map", _fog_texture)
		mat.set_shader_parameter("channel", layer)
		mat.render_priority = 1
		plane.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h := 0.035 if layer == 0 else TABLE_HEIGHT + 0.3
		mi.position = Vector3(board.width / 2.0 - 0.5, h, board.height / 2.0 - 0.5)
		add_child(mi)
		_fog_planes.append(mi)


## Voile les cases que la bande ne voit pas.
func set_fog(cells: Array) -> void:
	_fog_image.fill(Color(0, 0, 0))
	for c in cells:
		var cell: Vector2i = c
		if not board.in_bounds(cell):
			continue
		if board.is_table(cell):
			_fog_image.set_pixel(cell.x, cell.y, Color(0, 1, 0))
		else:
			_fog_image.set_pixel(cell.x, cell.y, Color(1, 0, 0))
	_fog_texture.update(_fog_image)
