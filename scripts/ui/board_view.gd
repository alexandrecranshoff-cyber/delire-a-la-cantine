class_name BoardView
extends Node3D
## Décor du niveau : carrelage en damier, murs bas (vue en coupe), tables roses garnies, portes
## battantes numérotées, bacs et lavabos. Une case = 1 m. Tout est construit à partir du plan (Board)
## et du niveau (tables, portes, bacs) : aucune position n'est écrite en dur ici.

const TABLE_HEIGHT := 0.75
const WALL_HEIGHT := 1.25
const DOOR_HEIGHT := 2.1

var board: Board
var level: Level
var _billboards: Array[Node3D] = []    # dessins plats tournés vers la caméra
var _table_items: Array[Node3D] = []   # plateaux et pichets : disparaissent quand les tables sont vides
var _fog := MultiMeshInstance3D.new()
var _fog_mesh := MultiMesh.new()
var _cam_angle := 45.0


func build(p_board: Board, p_level: Level) -> void:
	board = p_board
	level = p_level
	_build_floor()
	_build_walls()
	_build_tables()
	_build_doors()
	_build_fixtures()
	_build_fog()


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
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if GameAssets.is_hd() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _multimesh(mesh: Mesh, transforms: Array, shadows: bool = true) -> MultiMeshInstance3D:
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
	add_child(inst)
	return inst


func _box(size: Vector3, material: Material) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = material
	return b


# --- Sol ------------------------------------------------------------------------

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

func _build_walls() -> void:
	var room := []
	var kitchen := []
	var caps := []
	for y in board.height:
		for x in board.width:
			var c := Vector2i(x, y)
			var t := board.terrain(c)
			if t != Board.Terrain.WALL and t != Board.Terrain.TAP:
				continue
			var tr := Transform3D(Basis(), cell_to_world(c, WALL_HEIGHT / 2.0))
			if _near_kitchen(c) and not _near_room(c):
				kitchen.append(tr)
			else:
				room.append(tr)
			caps.append(Transform3D(Basis(), cell_to_world(c, WALL_HEIGHT + 0.02)))
	# La texture de mur fait 2 m de large et toute la hauteur du mur.
	var scale := Vector3(0.5, 1.0 / WALL_HEIGHT, 0.5)
	_multimesh(_box(Vector3(1, WALL_HEIGHT, 1), _tiled("mur_salle.png", scale)), room)
	_multimesh(_box(Vector3(1, WALL_HEIGHT, 1), _tiled("mur_cuisine.png", scale)), kitchen)
	# Dessus des murs : trait d'encre épais, comme une coupe de BD.
	_multimesh(_box(Vector3(1.05, 0.05, 1.05), _flat(BD.INK, true)), caps, false)
	var tops := []
	for t in caps:
		tops.append(t.translated(Vector3(0, 0.03, 0)))
	_multimesh(_box(Vector3(1.0, 0.03, 1.0), _flat(Color("8a6a2c"), true)), tops, false)


# --- Tables -----------------------------------------------------------------------

func _build_tables() -> void:
	var legs := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_texture = GameAssets.texture("textures", "table.png")
	top_mat.roughness = 1.0
	var edge_mat := _flat(Color("d9718d"))
	var ink := _flat(BD.INK, true)
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
		add_child(top)
		# Ombre de la table sur le carrelage.
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
		# Couverts : tant que les tables sont garnies, on y trouve des munitions.
		var count := 7
		for i in count:
			var kind: String = ["plateau_rouge", "plateau_bleu", "pichet", "assiettes", "plateau_rouge", "verre", "plateau_bleu"][i]
			var px := x0 - 0.2 + (w - 0.6) * (i + 0.5) / count + rng.randf_range(-0.2, 0.2)
			var pz := center.z + rng.randf_range(-0.7, 0.7)
			var size := 0.95 if kind.begins_with("plateau") else (0.34 if kind == "verre" else 0.56)
			var item := _standee("accessoires", kind + ".png", size, Vector3(px, TABLE_HEIGHT + 0.01, pz), kind.begins_with("plateau"))
			_table_items.append(item)
	_multimesh(_box(Vector3(0.09, TABLE_HEIGHT - 0.1, 0.09), _tiled("inox.png", Vector3(1, 1, 1))), legs)


## Dessin plat debout, tourné vers la caméra. `flat` : posé à plat (plateaux), il ne se redresse pas.
func _standee(family: String, name: String, height: float, pos: Vector3, flat: bool = false) -> Node3D:
	var tex := GameAssets.texture(family, name)
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	if tex == null:
		return holder
	var s := Sprite3D.new()
	s.texture = tex
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if flat:
		# Les plateaux sont dessinés vus de trois quarts : on les couche presque à plat.
		s.pixel_size = height / float(tex.get_width())
		s.rotation.x = -1.1
		s.position.y = 0.04
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		s.pixel_size = height / float(tex.get_height())
		s.position.y = height / 2.0
		s.rotation.x = -0.2
	holder.add_child(s)
	_billboards.append(holder)
	holder.rotation.y = deg_to_rad(_cam_angle)
	return holder


## Les tables se vident à la fin du tour 4 (livret) : plus de couverts, plus de munitions.
func set_tables_stocked(stocked: bool) -> void:
	for item in _table_items:
		if item.visible == stocked:
			continue
		if stocked:
			item.visible = true
			item.scale = Vector3.ONE
		else:
			var tw := create_tween()
			tw.tween_interval(randf_range(0.0, 0.5))
			tw.tween_property(item, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): item.visible = false)


# --- Portes -----------------------------------------------------------------------

func _build_doors() -> void:
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_texture = GameAssets.texture("textures", "porte.png")
	door_mat.roughness = 1.0
	door_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame_mat := _flat(Color("3f6b45"))
	for key in level.raw["portes"].keys():
		var cells := level.door_cells(key)
		var mid := Vector3.ZERO
		for c in cells:
			mid += cell_to_world(c)
		mid /= float(cells.size())
		# La porte regarde vers l'intérieur de la pièce.
		var inward := Vector3.ZERO
		var c0: Vector2i = cells[0]
		if c0.x == 0:
			inward = Vector3(1, 0, 0)
		elif c0.x == board.width - 1:
			inward = Vector3(-1, 0, 0)
		elif c0.y == 0:
			inward = Vector3(0, 0, 1)
		else:
			inward = Vector3(0, 0, -1)
		var width := float(cells.size())
		var holder := Node3D.new()
		holder.position = mid - inward * 0.42
		holder.rotation.y = atan2(inward.x, inward.z)
		add_child(holder)
		var frame := MeshInstance3D.new()
		frame.mesh = _box(Vector3(width + 0.16, DOOR_HEIGHT + 0.1, 0.16), frame_mat)
		frame.position.y = (DOOR_HEIGHT + 0.1) / 2.0
		holder.add_child(frame)
		var back := MeshInstance3D.new()
		back.mesh = _box(Vector3(width + 0.26, DOOR_HEIGHT + 0.2, 0.1), _flat(BD.INK, true))
		back.position = Vector3(0, (DOOR_HEIGHT + 0.2) / 2.0, -0.02)
		holder.add_child(back)
		for side in [1.0, -1.0]:
			var leaf := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(width, DOOR_HEIGHT)
			quad.material = door_mat
			leaf.mesh = quad
			leaf.position = Vector3(0, DOOR_HEIGHT / 2.0, 0.085 * side)
			if side < 0.0:
				leaf.rotation.y = PI
			holder.add_child(leaf)
		# Numéro de la porte : les profs entrent par la porte tirée au dé.
		var plate := Label3D.new()
		plate.text = key
		plate.font = BD.title_font()
		plate.font_size = 96
		plate.outline_size = 24
		plate.pixel_size = 0.006
		plate.modulate = BD.YELLOW
		plate.outline_modulate = BD.INK
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = mid + Vector3(0, DOOR_HEIGHT + 0.45, 0) - inward * 0.42
		add_child(plate)


# --- Bacs, lavabos ------------------------------------------------------------------

func _build_fixtures() -> void:
	for c in board.cells_of(Board.Terrain.TAP):
		var inward := Vector3(1, 0, 0) if c.x == 0 else Vector3(-1, 0, 0)
		_standee("accessoires", "lavabo.png", 1.5, cell_to_world(c) + inward * 0.25 + Vector3(0, 0.1, 0))
	var names := {"bac_puree": "PURÉE", "bac_tripes": "TRIPES", "bac_vaisselle": "VAISSELLE"}
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
		var colors := {"bac_puree": Color("9cc04a"), "bac_tripes": Color("c9772f"), "bac_vaisselle": Color("9fd0e6")}
		food.mesh = _box(Vector3(cells.size() - 0.24, 0.05, 0.76), _flat(colors.get(key, Color.WHITE), true))
		food.position = mid + Vector3(0, 0.96, 0)
		add_child(food)
		if key == "bac_vaisselle":
			_standee("accessoires", "assiettes.png", 0.6, mid + Vector3(0.3, 0.98, 0))
		var plate := Label3D.new()
		plate.text = names.get(key, key)
		plate.font = BD.title_font()
		plate.font_size = 64
		plate.outline_size = 18
		plate.pixel_size = 0.006
		plate.modulate = Color.WHITE
		plate.outline_modulate = BD.INK
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.position = mid + Vector3(0, 1.75, 0)
		add_child(plate)


func face_camera(angle_deg: float) -> void:
	_cam_angle = angle_deg
	var r := deg_to_rad(angle_deg)
	for b in _billboards:
		b.rotation.y = r


# --- Brouillard -------------------------------------------------------------------

func _build_fog() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.08, 0.06, 0.14, 0.62)
	quad.material = mat
	_fog_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_fog_mesh.mesh = quad
	_fog.multimesh = _fog_mesh
	_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog)


## Grise les cases que la bande ne voit pas.
func set_fog(cells: Array) -> void:
	_fog_mesh.instance_count = cells.size()
	for i in cells.size():
		var c: Vector2i = cells[i]
		var h := 0.03
		if board.is_table(c):
			h = TABLE_HEIGHT + 0.03
		elif board.is_tub(c):
			h = 1.0
		_fog_mesh.set_instance_transform(i, Transform3D(Basis(), cell_to_world(c, h)))
