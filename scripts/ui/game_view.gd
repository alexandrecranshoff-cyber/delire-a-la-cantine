class_name GameView
extends Node3D
## Scène de partie : affiche l'état (GameState) et traduit la souris en actions du moteur de règles.
## Aucune règle ici : tout passe par scripts/rules/.

const LEVEL_PATH := "res://data/niveaux/niveau_1.json"
const STEP_TIME := 0.09

@export var players := 2
@export var seed_value := 0

var state: GameState
var level: Level
var hud: Hud
var board_view: BoardView
var camera: Camera3D
var pawns := {}  # id -> PawnView

var selected: Unit
var watering := false
var push_cart: Unit
var busy := false

var _overlay := MultiMeshInstance3D.new()
var _overlay_mesh := MultiMesh.new()
var _cam_target := Vector3.ZERO
var _cam_angle := 45.0
var _cam_zoom := 26.0
var _dragging := false


func _ready() -> void:
	var data := GameData.load_default()
	level = Level.load_file(LEVEL_PATH)
	var s := seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	state = level.build_state(data, DiceRoller.new(s), players)

	_setup_environment()
	board_view = BoardView.new()
	add_child(board_view)
	board_view.build(state.board)
	for u in state.units:
		var p := PawnView.new()
		add_child(p)
		p.setup(u)
		pawns[u.id] = p
	_update_camera()
	_setup_overlay()

	hud = Hud.new()
	add_child(hud)
	hud.end_turn_pressed.connect(_end_turn)
	hud.watering_toggled.connect(func(on): watering = on)
	hud.log_line("Partie à %d bandes. Graine des dés : %d." % [players, s])
	state.start_team_turn(0)
	_refresh_all()


func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("3b2f4a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.9
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	_cam_target = Vector3(state.board.width / 2.0, 0, state.board.height / 2.0 - 4)
	_update_camera()


func _update_camera() -> void:
	camera.size = _cam_zoom
	var dir := Vector3(sin(deg_to_rad(_cam_angle)), 1.1, cos(deg_to_rad(_cam_angle))).normalized()
	camera.position = _cam_target + dir * 40.0
	camera.look_at(_cam_target, Vector3.UP)
	for p in pawns.values():
		p.face_camera(_cam_angle)


func _setup_overlay() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	_overlay_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_overlay_mesh.use_colors = true
	_overlay_mesh.mesh = quad
	_overlay.multimesh = _overlay_mesh
	add_child(_overlay)


## Surligne des cases : liste de [Vector2i, Color].
func _show_cells(cells: Array) -> void:
	_overlay_mesh.instance_count = cells.size()
	for i in cells.size():
		var c: Vector2i = cells[i][0]
		var h := BoardView.TABLE_HEIGHT + 0.02 if state.board.is_table(c) else 0.07
		_overlay_mesh.set_instance_transform(i, Transform3D(Basis(), BoardView.cell_to_world(c, h)))
		_overlay_mesh.set_instance_color(i, cells[i][1])


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_zoom = maxf(8.0, _cam_zoom - 1.5)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_zoom = minf(45.0, _cam_zoom + 1.5)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not busy:
			var c = _mouse_cell(mb.position)
			if c != null:
				_click(c)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			var right := camera.global_transform.basis.x
			var fwd := Vector3(right.z, 0, -right.x)
			_cam_target -= (right * mm.relative.x - fwd * mm.relative.y) * _cam_zoom / 600.0
			_update_camera()
		elif not busy:
			var c = _mouse_cell(mm.position)
			if c != null:
				_hover(c)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER: _end_turn()
			KEY_Q: _rotate(-90)
			KEY_E: _rotate(90)
			KEY_R:
				watering = not watering
				hud.set_watering(watering)
			KEY_ESCAPE: _select(null)


func _rotate(deg: float) -> void:
	_cam_angle += deg
	_update_camera()


func _process(delta: float) -> void:
	var move := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if move != Vector2.ZERO:
		var right := camera.global_transform.basis.x
		var fwd := Vector3(right.z, 0, -right.x)
		_cam_target += (right * move.x - fwd * move.y) * delta * 15.0
		_update_camera()


func _mouse_cell(screen: Vector2):
	var origin := camera.project_ray_origin(screen)
	var normal := camera.project_ray_normal(screen)
	if absf(normal.y) < 0.001:
		return null
	# On vise d'abord le dessus des tables, puis le sol.
	for h in [BoardView.TABLE_HEIGHT, 0.0]:
		var t: float = (h - origin.y) / normal.y
		var p: Vector3 = origin + normal * t
		var c := Vector2i(roundi(p.x), roundi(p.z))
		if h > 0.0 and not state.board.is_table(c):
			continue
		if state.board.in_bounds(c):
			return c
	return null


# --- Actions ------------------------------------------------------------------

func _is_mine(u: Unit) -> bool:
	return u != null and u.team == state.current_team and u.is_controllable()


func _select(u: Unit) -> void:
	if selected != null:
		pawns[selected.id].set_selected(false)
	selected = u
	push_cart = null
	if u != null:
		pawns[u.id].set_selected(true)
	_refresh_all()


func _hover(c: Vector2i) -> void:
	if selected == null:
		_show_cells([])
		hud.set_hint("")
		return
	var target := state.unit_at(c)
	if push_cart != null:
		var path := Movement.path_to(state, push_cart, c)
		var ok := not path.is_empty() and path.size() <= int(state.data.rules["chariot_cases_max"])
		_show_cells(path.map(func(p): return [p, Color(1, 0.8, 0.2, 0.6) if ok else Color(1, 0.2, 0.2, 0.5)]))
		hud.set_hint("Pousser le chariot ici (%d PA, pas de tir ce tour)" % state.data.ap_cost("pousser_chariot") if ok else "Trop loin pour le chariot (3 cases max)")
		return
	if target != null and target != selected and target.kind != Unit.Kind.CART:
		var reason := Combat.cannot_shoot_reason(state, selected, target, watering)
		var traj := Trajectory.cells(selected.pos, target.pos)
		var color := Color(1, 0.3, 0.2, 0.55) if reason == "" else Color(0.4, 0.4, 0.4, 0.45)
		_show_cells(traj.map(func(p): return [p, color]))
		var dist := Board.distance(selected.pos, target.pos)
		if reason == "":
			var what := "Arroser" if watering else "Lancer"
			hud.set_hint("%s sur %s : distance %d, seuil %d + CX du projectile (%d PA)" % [what, _who(target), dist, dist, state.data.ap_cost("arrosage" if watering else "tir")])
		else:
			hud.set_hint(_reason_text(reason))
		return
	if target != null and target.kind == Unit.Kind.CART and Board.adjacent(selected.pos, target.pos):
		hud.set_hint("Cliquer pour pousser ce chariot")
		_show_cells([[c, Color(1, 0.8, 0.2, 0.6)]])
		return
	if Movement.can_climb(state, selected, c):
		_show_cells([[c, Color(0.6, 0.3, 1, 0.6)]])
		hud.set_hint("Monter sur la table : tout le tour, pas de tir")
		return
	if Movement.can_descend(state, selected, c):
		_show_cells([[c, Color(0.6, 0.3, 1, 0.6)]])
		hud.set_hint("Descendre de la table : tout le tour")
		return
	var reach := Movement.reachable(state, selected)
	var cells := []
	for k in reach.keys():
		if k != selected.pos:
			cells.append([k, Color(0.2, 0.9, 0.4, 0.28)])
	if reach.has(c) and c != selected.pos:
		for p in Movement.path_to(state, selected, c):
			cells.append([p, Color(0.1, 0.7, 1.0, 0.6)])
		hud.set_hint("Aller ici : %d PA (reste %d)" % [reach[c], selected.ap - reach[c]])
	else:
		hud.set_hint("%d PA restants" % selected.ap)
	_show_cells(cells)


func _click(c: Vector2i) -> void:
	var target := state.unit_at(c)
	if _is_mine(target) and target.kind != Unit.Kind.CART:
		_select(target)
		return
	if selected == null:
		return
	if push_cart != null:
		if Movement.push_cart(state, selected, push_cart, c):
			hud.log_line("%s pousse le %s." % [selected.name, push_cart.name])
		push_cart = null
		_refresh_all()
		return
	if target != null and target.kind == Unit.Kind.CART and Board.adjacent(selected.pos, target.pos):
		push_cart = target
		hud.set_hint("Choisis où pousser le chariot (3 cases max)")
		return
	if target != null and target != selected:
		await _shoot(target)
		return
	if Movement.can_climb(state, selected, c):
		Movement.climb(state, selected, c)
		hud.log_line("%s grimpe sur la table !" % selected.name)
		_refresh_all()
		return
	if Movement.can_descend(state, selected, c):
		Movement.descend(state, selected, c)
		hud.log_line("%s redescend." % selected.name)
		_refresh_all()
		return
	var from := selected.pos
	var path := Movement.move(state, selected, c)
	if not path.is_empty():
		busy = true
		_show_cells([])
		var pawn: PawnView = pawns[selected.id]
		pawn.position = BoardView.cell_to_world(from)
		var tw := create_tween()
		for p in path:
			tw.tween_property(pawn, "position", BoardView.cell_to_world(p), STEP_TIME)
		await tw.finished
		busy = false
		_refresh_all()


func _shoot(target: Unit) -> void:
	var report := Combat.resolve_shot(state, selected, target, watering)
	if not report["ok"]:
		hud.log_line(_reason_text(report["reason"]))
		return
	busy = true
	_show_cells([])
	var victim := state.get_unit(report["victim_id"]) if report["victim_id"] >= 0 else null
	await hud.show_shot(report, selected, victim)
	if victim != null:
		_bubble(victim, "SPLATCH !" if report["hit"] else "BEURK !")
		hud.log_line("%s → %s : %d pt (%s)" % [selected.name, _who(victim), report["damage"], report["projectile_name"]])
		match report.get("neutral_reaction", Combat.NeutralReaction.NONE):
			Combat.NeutralReaction.RALLIED: hud.log_line("Le neutre rejoint la %s !" % Hud.team_name(selected.team))
			Combat.NeutralReaction.FLEEING: hud.log_line("Le neutre s'enfuit vers la sortie.")
			Combat.NeutralReaction.BERSERK: hud.log_line("Le neutre devient BERSERK !")
	else:
		hud.log_line("%s rate sa cible, ça tombe par terre." % selected.name)
	if watering:
		watering = false
		hud.set_watering(false)
	busy = false
	_refresh_all()
	var w := state.winner()
	if w >= 0:
		hud.show_banner("%s gagne !" % Hud.team_name(w))


func _bubble(u: Unit, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.outline_size = 18
	l.modulate = Color("fff35c")
	l.pixel_size = 0.01
	l.position = BoardView.cell_to_world(u.pos, 2.6)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", 3.4, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func _end_turn() -> void:
	if busy or state.winner() >= 0:
		return
	_select(null)
	var next := (state.current_team + 1) % state.team_count
	if next == 0:
		state.turn += 1
	state.start_team_turn(next)
	hud.log_line("— Tour %d : %s —" % [state.turn, Hud.team_name(next)])
	_refresh_all()


func _refresh_all() -> void:
	for p in pawns.values():
		p.refresh()
	hud.set_status(state)
	hud.set_unit(selected, state.data.ap_per_turn())
	hud.set_hint("")
	_show_cells([])


func _who(u: Unit) -> String:
	return "un neutre" if u.kind == Unit.Kind.NEUTRAL and not u.rallied else u.name


func _reason_text(reason: String) -> String:
	match reason:
		"deja_tire": return "Déjà tiré ce tour."
		"pas_assez_de_pa": return "Pas assez de PA."
		"pas_de_munitions": return "Pas de munition : va au contact d'une table (tours 1 à 4), d'un bac ou d'un chariot."
		"mur": return "Un mur bloque la trajectoire."
		"trop_loin": return "Trop loin pour arroser (5 cases max)."
		"pas_de_robinet": return "Il faut être au contact d'un robinet pour arroser."
		"ne_tire_pas": return "Ce personnage ne tire pas."
		"cible_invalide": return "Cible impossible."
		_: return reason
