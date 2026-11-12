class_name GameView
extends Node3D
## Scène de partie : affiche l'état (GameState), traduit la souris en actions (GameActions) et met en
## scène les événements renvoyés par les règles. Aucune règle ici : tout passe par scripts/rules/ et scripts/ai/.

signal back_to_menu
signal replay
signal campaign_next   # fin d'un service de l'année scolaire : retour à l'écran de l'année

const STEP_TIME := 0.085
const ROTATE_STEP := 45.0
const ROTATE_DRAG_SPEED := 0.4  # degrés par pixel
## Hauteur de la caméra pour 1 m de recul : 0.85 donne une vue plongeante d'environ 40°, qui laisse voir les personnages de trois quarts.
const CAM_HEIGHT := 0.85          # inclinaison de départ (hauteur relative de la caméra)
const CAM_TILT_MIN := 0.45        # vue rasante
const CAM_TILT_MAX := 2.6         # presque à la verticale
const TILT_DRAG_SPEED := 0.006    # par pixel de glissé vertical au clic droit

var state: GameState
var level: Level
var hud: Hud
var board_view: BoardView
var fx: Effects
var camera: Camera3D
var pawns := {}  # id -> PawnView

var selected: Unit
var watering := false
var push_cart: Unit
var busy := true
var over := false
var viewer_team := 0          # bande dont on montre le point de vue (brouillard)
var human_teams: Array[int] = []
var opponents := {}           # bande -> Opponent

var _overlay := MultiMeshInstance3D.new()
var _overlay_mesh := MultiMesh.new()
var _cam_target := Vector3.ZERO
var _cam_angle := 45.0
var _cam_fixed := false           # contrôle visuel : la caméra reste sur la cible demandée
var _cam_tilt := CAM_HEIGHT
var _cam_zoom := 17.0   # assez près pour reconnaître les personnages ; molette jusqu'à 46
var _panning := false
var _rotating := false
var _rotate_tween: Tween
var _cam_goal := 45.0
var _hovered: PawnView
var _shake := 0.0
var _stats := {}
var hud_auto := false
var _last_turn_shown := 0
var _tables_stocked := true
var _odds: Odds
var _pushed_this_turn := {}       # id -> pourquoi cet élève ne tire plus ce tour (chariot, table)
var _end_queued := false          # Entrée appuyée pendant une animation : fin du tour dès qu'elle s'achève
var _resume := {}                 # sauvegarde reprise au lancement (vide : nouvelle partie)
var _seed := 0
var _save_panel: SavePanel
var _skipping := false            # tour de l'ordinateur accéléré par le joueur
var _advancing := false           # entre la fin du tour du joueur et son tour suivant
var _year: Campaign               # année scolaire en cours (partie lancée depuis l'écran de l'année)
var _service := {}                # service de l'année joué
var _level_path := ""
var _unit_stats := {}             # id -> {"touches", "satures"} : expérience de fin de service
const FAST_SPEED := 3.0
const SKIP_SPEED := 8.0
const OTHERS_SPEED := 1.5


func _ready() -> void:
	var data := GameData.load_default()
	var s := GameConfig.seed_value if GameConfig.seed_value != 0 else int(Time.get_unix_time_from_system())
	_resume = GameConfig.pending_load
	GameConfig.pending_load = {}
	if not _resume.is_empty():
		var cfg: Dictionary = _resume["config"]
		GameConfig.solo = bool(cfg["solo"])
		GameConfig.difficulty = str(cfg["difficulty"])
		GameConfig.players = int(cfg["players"])
		GameConfig.level_path = str(cfg.get("level", "res://data/niveaux/niveau_1.json"))
		GameConfig.campaign = bool(cfg.get("campaign", false))
		s = int(str(cfg["seed"]))
	_seed = s
	var level_path := GameConfig.level_path
	if GameConfig.campaign:
		_year = CampaignStore.load_year()
		if _year == null:
			GameConfig.campaign = false
		else:
			_service = _year.current_service()
			if not _resume.is_empty():
				_service = _year.service_by_id(str(_resume["config"].get("service", _service["id"])))
			level_path = Campaign.level_path(_service)
			GameConfig.solo = true
			GameConfig.players = 2
			GameConfig.difficulty = _year.difficulty()
	level = Level.load_file(level_path)
	_level_path = level_path
	var ai: Array = [1] if GameConfig.solo else []
	state = GameSetup.new_game(level, data, s, GameConfig.players, ai, GameConfig.difficulty if GameConfig.solo else "")
	if _year != null:
		_year.prepare_state(state, 0, _service)
	_odds = Odds.new(data)
	if not GameConfig.solo:
		state.options["prof_periode"] = int(GameSetup.difficulties()["normal"]["prof_periode"])
	if not _resume.is_empty() and not SaveGame.apply(state, _resume["state"]):
		_resume = {}  # sauvegarde illisible : nouvelle partie
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tours="):
			state.options["tours_max"] = int(a.split("=")[1])  # essais : partie courte
	hud_auto = OS.get_cmdline_user_args().has("auto")
	for t in state.team_count:
		if state.ai_teams.has(t):
			var profile: Dictionary = GameSetup.difficulties()[GameConfig.difficulty]["ia"]
			opponents[t] = Opponent.new(t, profile, s + 77 * (t + 1))
		else:
			human_teams.append(t)
		_stats[t] = {"tirs": 0, "touches": 0, "satures": 0, "emmenes": 0, "plonges": 0}
		var saved_stats: Dictionary = _resume.get("stats", {})
		if saved_stats.has(str(t)):
			for k in _stats[t].keys():
				_stats[t][k] = int(saved_stats[str(t)].get(k, 0))
	var saved_units: Dictionary = _resume.get("unit_stats", {})
	for k in saved_units.keys():
		_unit_stats[int(k)] = {"touches": int(saved_units[k]["touches"]), "satures": int(saved_units[k]["satures"])}
	viewer_team = human_teams[0] if not human_teams.is_empty() else 0
	if not _resume.is_empty() and human_teams.has(state.current_team):
		viewer_team = state.current_team

	_setup_environment()
	board_view = BoardView.new()
	add_child(board_view)
	board_view.build(state.board, level)
	fx = Effects.new()
	add_child(fx)
	for u in state.units:
		_add_pawn(u)
	_setup_overlay()

	hud = Hud.new()
	hud.auto_pass = hud_auto
	add_child(hud)
	hud.end_turn_pressed.connect(_end_turn)
	hud.watering_toggled.connect(func(on): watering = on)
	hud.rotate_pressed.connect(func(direction): rotate_camera(direction * ROTATE_STEP))
	hud.project_pressed.connect(_project)
	hud.unit_picked.connect(func(id): _pick(state.get_unit(id)))
	hud.menu_pressed.connect(func(): back_to_menu.emit())
	hud.replay_pressed.connect(func(): replay.emit())
	hud.campaign_pressed.connect(func(): campaign_next.emit())
	hud.speed_toggled.connect(_set_fast)
	hud.save_pressed.connect(_open_save_panel)
	hud.set_fast(GameConfig.fast)
	_set_fast(GameConfig.fast)
	var where := ("%s, « %s »" % [_service["mois"], _service["titre"]]) if _year != null else level.name
	hud.log_line("[b]Service de midi : %s.[/b] Graine des dés : %d." % [where, s])
	if level.menu_name() != "":
		hud.log_line("Menu du jour : %s." % level.menu_name().to_lower())
	if not state.board.cells_of(Board.Terrain.PUDDLE).is_empty():
		hud.log_line("Le toit fuit : une case de flaque coûte %d PA." % int(state.data.rules["points_action"]["flaque"]))
	Sound.music("musique_partie")
	Sound.ambience(true)
	_update_camera()
	_refresh_all()
	_intro()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _intro() -> void:
	_last_turn_shown = state.turn
	if _resume.is_empty():
		await hud.show_banner("À TABLE !", BD.YELLOW, "Tour 1 : %s" % BD.team_name(state.current_team).to_lower(), 1.0)
	else:
		if not state.tables_have_ammo():
			_tables_stocked = false
			board_view.set_tables_stocked(false)
		hud.log_line("[b]Partie reprise[/b] au tour %d." % state.turn)
		await hud.show_banner("REPRISE !", BD.YELLOW, "Tour %d : %s" % [state.turn, BD.team_name(state.current_team).to_lower()], 1.0)
	_end_skip()
	if human_teams.size() > 1:
		await hud.show_pass_screen(state.current_team)
	busy = false
	_autosave()
	_select_first()
	if selected != null and not _cam_fixed:
		_focus(pawns[selected.id].global_position)
	for a in OS.get_cmdline_user_args():
		if a == "rapide":
			_set_fast(true)
			hud.set_fast(true)
		elif a.begins_with("prof="):
			# Contrôle visuel : pose un prof sur une case.
			var pxy := a.split("=")[1].split(",")
			_add_pawn(state.add_unit(Unit.Kind.TEACHER, "prof", Vector2i(int(pxy[0]), int(pxy[1])), Unit.NO_TEAM, "Prof"))
			_refresh_all()
		elif a.begins_with("survol="):
			# Contrôle visuel : simule le survol d'une case.
			var xy := a.split("=")[1].split(",")
			_hover(Vector2i(int(xy[0]), int(xy[1])))
	if OS.get_cmdline_user_args().has("auto"):
		_autoplay()


## Démonstration et essais : l'ordinateur joue aussi la bande du joueur, en passant par l'interface.
func _autoplay() -> void:
	var bots := {}
	for t in human_teams:
		bots[t] = Opponent.new(t, GameSetup.difficulties()["normal"]["ia"], 4242 + t)
	while not over:
		if not _can_act():
			await _wait(0.2)
			continue
		var bot: Opponent = bots[state.current_team]
		var events := bot.play_next(state)
		if events.is_empty():
			await _end_turn()
		else:
			if not events.is_empty() and events[0].has("id") and pawns.has(events[0]["id"]):
				_select(state.get_unit(events[0]["id"]))
			await _run(events)
			await _wait(0.1)


func _add_pawn(u: Unit) -> PawnView:
	var p := PawnView.new()
	add_child(p)
	p.setup(u)
	# Au départ, chacun regarde sa table (ou la salle).
	var look := Vector2(0, -1)
	for n in Board.neighbors8(u.pos):
		if state.board.is_table(n):
			look = Vector2(n - u.pos)
			break
	if u.kind == Unit.Kind.TEACHER:
		look = Vector2(state.board.width / 2.0 - u.pos.x, state.board.height / 2.0 - u.pos.y)
	p.set_facing(look, true)
	p.face_camera(_cam_angle)
	p.set_zoom(_cam_zoom)
	pawns[u.id] = p
	return p


func _setup_environment() -> void:
	var hd := GameAssets.is_hd()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("3b2f4a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.86, 0.84, 0.9)
	env.environment.ambient_light_energy = 0.62
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 32, 0)
	sun.light_energy = 0.46
	sun.light_color = Color(1.0, 0.97, 0.9)
	# Pas d'ombres calculées : celles des pions, des tables et des murs sont dessinées, comme
	# en BD, et le rendu reste identique sur le web et sur PC. Anticrénelage 2x sur le web, 4x sur PC.
	get_viewport().msaa_3d = Viewport.MSAA_4X if hd else Viewport.MSAA_2X
	for a in OS.get_cmdline_user_args():
		if a.begins_with("amb="):
			env.environment.ambient_light_energy = float(a.split("=")[1])
		elif a.begins_with("sun="):
			sun.light_energy = float(a.split("=")[1])
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 200.0
	add_child(camera)
	_cam_target = Vector3(state.board.width / 2.0 + 1.5, 0, state.board.height / 2.0 + 1.5)
	# Réglages de contrôle visuel : zoom=12 angle=90 inclinaison=1.5 cible=10,8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			_cam_zoom = float(a.split("=")[1])
		elif a.begins_with("angle="):
			_cam_angle = float(a.split("=")[1])
		elif a.begins_with("inclinaison="):
			_cam_tilt = clampf(float(a.split("=")[1]), CAM_TILT_MIN, CAM_TILT_MAX)
		elif a.begins_with("cible="):
			var xy := a.split("=")[1].split(",")
			_cam_target = Vector3(float(xy[0]), 0, float(xy[1]))
			_cam_fixed = true


func _update_camera() -> void:
	camera.size = _cam_zoom
	var dir := Vector3(sin(deg_to_rad(_cam_angle)), _cam_tilt, cos(deg_to_rad(_cam_angle))).normalized()
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
	camera.position = _cam_target + dir * 60.0 + shake
	camera.look_at(_cam_target + shake, Vector3.UP)
	for p in pawns.values():
		p.face_camera(_cam_angle)
		p.set_zoom(_cam_zoom)
	if board_view != null:
		board_view.face_camera(_cam_angle)
	if fx != null:
		fx.cam_angle = _cam_angle


func _setup_overlay() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.92, 0.92)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _cell_texture()
	quad.material = mat
	_overlay_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_overlay_mesh.use_colors = true
	_overlay_mesh.mesh = quad
	_overlay.multimesh = _overlay_mesh
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay)


## Case surlignée : carré arrondi, bord plus marqué que le fond.
func _cell_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := maxf(absf(x - size / 2.0 + 0.5) - (size / 2.0 - 10.0), 0.0)
			var dy := maxf(absf(y - size / 2.0 + 0.5) - (size / 2.0 - 10.0), 0.0)
			var dist := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if dist <= 8.0:
				a = 1.0 if dist >= 4.5 else 0.55
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Surligne des cases : liste de [Vector2i, Color].
func _show_cells(cells: Array) -> void:
	_overlay_mesh.instance_count = cells.size()
	for i in cells.size():
		var c: Vector2i = cells[i][0]
		var h := BoardView.TABLE_HEIGHT + 0.025 if state.board.is_table(c) else 0.03
		_overlay_mesh.set_instance_transform(i, Transform3D(Basis(), BoardView.cell_to_world(c, h)))
		_overlay_mesh.set_instance_color(i, cells[i][1])


func _t(seconds: float) -> float:
	return seconds


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout


func _set_fast(on: bool) -> void:
	GameConfig.fast = on
	_apply_speed()


func _apply_speed() -> void:
	var base := FAST_SPEED if GameConfig.fast else 1.0
	# Le tour des autres (ordinateur, profs, neutres) se joue un peu plus vite que le sien.
	if _advancing:
		base *= OTHERS_SPEED
	Engine.time_scale = SKIP_SPEED if _skipping else base


## Clic ou Espace pendant le tour des autres : on joue la suite en accéléré.
func _skip_others() -> void:
	if _skipping or not _advancing or over:
		return
	_skipping = true
	_apply_speed()
	hud.set_hint("Accéléré jusqu'à ton tour…")


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_save_panel):
		return
	if _advancing and ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)):
		_skip_others()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_zoom = maxf(8.0, _cam_zoom - 1.5)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_zoom = minf(46.0, _cam_zoom + 1.5)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _can_act():
			var c = _mouse_cell(mb.position)
			if c != null:
				_click(c)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rotating:
			_set_cam_angle(_cam_angle - mm.relative.x * ROTATE_DRAG_SPEED)
			# Glissé vertical : on incline la caméra, de la vue rasante à la vue de dessus.
			_set_cam_tilt(_cam_tilt + mm.relative.y * TILT_DRAG_SPEED)
		elif _panning:
			var right := camera.global_transform.basis.x
			var fwd := Vector3(right.z, 0, -right.x)
			_cam_target -= (right * mm.relative.x - fwd * mm.relative.y) * _cam_zoom / 600.0
			_clamp_target()
			_update_camera()
		elif _can_act():
			var c = _mouse_cell(mm.position)
			if c != null:
				_hover(c)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER: _end_turn()
			KEY_Q, KEY_A: rotate_camera(-ROTATE_STEP)
			KEY_E: rotate_camera(ROTATE_STEP)
			KEY_PAGEUP: _set_cam_tilt(_cam_tilt + 0.25)
			KEY_PAGEDOWN: _set_cam_tilt(_cam_tilt - 0.25)
			KEY_M:
				GameConfig.music_on = not GameConfig.music_on
				Sound.refresh_settings()
				hud.set_music(GameConfig.music_on)
			KEY_R:
				if _can_act():
					watering = not watering
					hud.set_watering(watering)
			KEY_P: _project()
			KEY_TAB: _select_next()
			KEY_V:
				_set_fast(not GameConfig.fast)
				hud.set_fast(GameConfig.fast)
			KEY_F1, KEY_H: hud.toggle_help()
			KEY_F5: _open_save_panel()
			KEY_ESCAPE:
				if hud.help_open():
					hud.toggle_help()
				else:
					_select(null)


func _can_act() -> bool:
	return not busy and not over and human_teams.has(state.current_team)


## Tourne la vue autour du point regardé, en douceur (boutons de l'interface, touches Q et E).
func rotate_camera(deg: float) -> void:
	var from := _cam_angle
	if _rotate_tween != null and _rotate_tween.is_valid():
		from = _cam_goal
		_rotate_tween.kill()
	var goal := roundf((from + deg) / ROTATE_STEP) * ROTATE_STEP
	_cam_goal = goal
	_rotate_tween = create_tween()
	_rotate_tween.tween_method(_set_cam_angle, _cam_angle, goal, 0.25).set_trans(Tween.TRANS_SINE)


func _set_cam_tilt(t: float) -> void:
	_cam_tilt = clampf(t, CAM_TILT_MIN, CAM_TILT_MAX)
	_update_camera()


func _set_cam_angle(deg: float) -> void:
	_cam_angle = deg
	_update_camera()


func _clamp_target() -> void:
	_cam_target.x = clampf(_cam_target.x, -2.0, state.board.width + 2.0)
	_cam_target.z = clampf(_cam_target.z, -2.0, state.board.height + 2.0)


func _process(delta: float) -> void:
	var move := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	var real_delta := delta / maxf(0.01, Engine.time_scale)
	if move != Vector2.ZERO:
		var right := camera.global_transform.basis.x
		var fwd := Vector3(right.z, 0, -right.x)
		_cam_target += (right * move.x - fwd * move.y) * real_delta * 18.0
		_clamp_target()
		_update_camera()
	elif _shake > 0.0:
		_shake = maxf(0.0, _shake - real_delta * 0.6)
		_update_camera()


func _mouse_cell(screen: Vector2):
	# Un personnage sous le curseur passe avant le décor : on vise son corps, pas ses pieds.
	var pawn_cell = _pawn_under(screen)
	if pawn_cell != null:
		return pawn_cell
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


## Case du pion dont la silhouette (des pieds à la tête, projetée à l'écran) est sous le curseur.
## Le plus proche de la caméra gagne quand deux silhouettes se recouvrent.
func _pawn_under(screen: Vector2):
	var best = null
	var best_depth := INF
	for p: PawnView in pawns.values():
		if not p.visible or not p.unit.is_on_board():
			continue
		var feet := camera.unproject_position(p.global_position)
		var head := camera.unproject_position(p.head_position())
		var half_w := maxf(10.0, absf(feet.y - head.y) * 0.28)
		if screen.y < head.y - 4.0 or screen.y > feet.y + 6.0 or absf(screen.x - lerpf(feet.x, head.x, 0.5)) > half_w:
			continue
		var depth := camera.global_position.distance_to(p.global_position)
		if depth < best_depth:
			best_depth = depth
			best = p.unit.pos
	return best


## Amène la caméra sur un point s'il est hors du centre de l'écran (actions de l'ordinateur).
func _focus(world: Vector3, force: bool = false) -> void:
	var screen := camera.unproject_position(world)
	var size := get_viewport().get_visible_rect().size
	var inner := Rect2(size * Vector2(0.14, 0.14), size * Vector2(0.72, 0.56))
	if inner.has_point(screen) and not force:
		return
	# Le bas de l'écran est pris par l'interface : on vise un peu plus bas que le point à montrer.
	var toward := Vector3(sin(deg_to_rad(_cam_angle)), 0, cos(deg_to_rad(_cam_angle)))
	var goal := Vector3(world.x, 0, world.z) + toward * _cam_zoom * 0.1
	# On garde la cible dans le plateau pour ne pas montrer surtout du vide.
	goal.x = clampf(goal.x, 8.0, state.board.width - 9.0)
	goal.z = clampf(goal.z, 8.0, state.board.height - 9.0)
	var tw := create_tween()
	tw.tween_method(func(v: Vector3):
		_cam_target = v
		_update_camera()
	, _cam_target, goal, 0.35).set_trans(Tween.TRANS_SINE)
	await tw.finished


# --- Sélection et survol ---------------------------------------------------------

func _is_mine(u: Unit) -> bool:
	return u != null and u.team == state.current_team and u.is_controllable() and u.kind != Unit.Kind.CART


func _visible_unit_at(c: Vector2i) -> Unit:
	var u := state.unit_at(c)
	if u != null and pawns.has(u.id) and not pawns[u.id].shown:
		return null
	return u


func _select(u: Unit) -> void:
	if selected != null and pawns.has(selected.id):
		pawns[selected.id].set_selected(false)
	selected = u
	push_cart = null
	if u != null:
		pawns[u.id].set_selected(true)
	_refresh_all()


func _pick(u: Unit) -> void:
	if u == null or not _can_act() or not _is_mine(u):
		return
	_select(u)
	_focus(pawns[u.id].global_position)


func _select_first() -> void:
	if not human_teams.has(state.current_team):
		return
	for u in state.units:
		if _is_mine(u):
			_select(u)
			return
	_select(null)


## Tab : élève suivant qui peut encore agir.
func _select_next() -> void:
	if not _can_act():
		return
	var mine: Array[Unit] = []
	for u in state.units:
		if _is_mine(u):
			mine.append(u)
	if mine.is_empty():
		return
	var start := mine.find(selected)
	for i in range(1, mine.size() + 1):
		var u: Unit = mine[(start + i) % mine.size()]
		if u.ap > 0 or not u.has_shot:
			_pick(u)
			return


func _set_hovered(p: PawnView, text: String = "") -> void:
	if _hovered != null and is_instance_valid(_hovered) and _hovered != p:
		_hovered.set_hover(false)
	_hovered = p
	if p != null:
		p.set_hover(true, text)


func _hover_text(u: Unit) -> String:
	return "%s  %d" % [u.name if u.kind == Unit.Kind.STUDENT else _who(u), u.moral]


func _hover(c: Vector2i) -> void:
	var target := _visible_unit_at(c)
	if target != null and target.kind != Unit.Kind.CART:
		_set_hovered(pawns[target.id], _hover_text(target))
	else:
		_set_hovered(null)
	if selected == null:
		_show_cells([])
		hud.set_hint("Clique sur un de tes élèves" if target == null or not _is_mine(target) else "Clic : choisir %s" % target.name)
		return
	if push_cart != null:
		var path := Movement.path_to(state, push_cart, c)
		var ok := not path.is_empty() and path.size() <= int(state.data.rules["chariot_cases_max"])
		_show_cells(path.map(func(p): return [p, Color(1, 0.8, 0.2, 0.8) if ok else Color(1, 0.2, 0.2, 0.7)]))
		hud.set_hint("Pousser le chariot ici (%d PA, pas de tir ce tour)" % state.data.ap_cost("pousser_chariot") if ok else "Trop loin pour le chariot (3 cases max)")
		return
	if target != null and _is_mine(target) and target != selected:
		_show_cells([[c, Color(1, 1, 1, 0.7)]])
		hud.set_hint("Clic : choisir %s" % target.name)
		return
	if target != null and target != selected and target.kind != Unit.Kind.CART:
		var reason := Combat.cannot_shoot_reason(state, selected, target, watering)
		var traj := Trajectory.cells(selected.pos, target.pos)
		var color := Color(1, 0.3, 0.2, 0.85) if reason == "" else Color(0.5, 0.5, 0.5, 0.6)
		_show_cells(traj.map(func(p): return [p, color]))
		var dist := Board.distance(selected.pos, target.pos)
		if reason == "":
			var what := "Arroser" if watering else "Lancer sur"
			var need := ("à battre %d" % (dist + Combat.min_cx(state, true))) if watering else ("à battre %d + CX du projectile" % dist)
			hud.set_hint("%s %s : distance %d, %s (%d PA). Chances : %s" % [what, _who(target), dist, need, state.data.ap_cost("arrosage" if watering else "tir"), _chance_word(selected, dist)])
		else:
			hud.set_hint(_reason_text(reason))
		return
	if target != null and target.kind == Unit.Kind.CART and Board.adjacent(selected.pos, target.pos):
		hud.set_hint("Clic : pousser ce chariot (3 cases max)")
		_show_cells([[c, Color(1, 0.8, 0.2, 0.8)]])
		return
	if Movement.can_climb(state, selected, c):
		_show_cells([[c, Color(0.7, 0.4, 1, 0.85)]])
		hud.set_hint("Monter sur la table : tout le tour, pas de tir")
		return
	if Movement.can_descend(state, selected, c):
		_show_cells([[c, Color(0.7, 0.4, 1, 0.85)]])
		hud.set_hint("Descendre de la table : tout le tour")
		return
	var reach := Movement.reachable(state, selected)
	var cells := []
	var shot_cost := state.data.ap_cost("tir")
	var threat := AutoPawns.threat_cells(state, viewer_team)
	for k in reach.keys():
		if k != selected.pos:
			# Vert : il restera de quoi tirer ; jaune : déplacement seul ; rouge : à portée d'un prof ou du cuisinier.
			var keeps_shot: bool = not selected.has_shot and selected.ap - int(reach[k]) >= shot_cost
			var color := Color(0.25, 0.95, 0.4, 0.46) if keeps_shot else Color(1.0, 0.85, 0.2, 0.44)
			if threat.has(k):
				color = Color(1.0, 0.25, 0.2, 0.5)
			cells.append([k, color])
	if reach.has(c) and c != selected.pos:
		for p in Movement.path_to(state, selected, c):
			cells.append([p, Color(0.1, 0.6, 1.0, 0.95)])
		var warn := "  Attention : à portée d'un prof ou du cuisinier !" if threat.has(c) else ""
		if state.board.is_puddle(c):
			warn = "  Flaque : %d PA la case." % int(state.data.rules["points_action"]["flaque"]) + warn
		hud.set_hint("Aller ici : %d PA (il en restera %d).%s" % [reach[c], selected.ap - reach[c], warn])
	else:
		hud.set_hint("%s : %d PA" % [selected.name, selected.ap])
	_show_cells(cells)


# --- Actions du joueur -----------------------------------------------------------

func _click(c: Vector2i) -> void:
	var target := _visible_unit_at(c)
	if _is_mine(target):
		_select(target)
		return
	if selected == null:
		return
	var events := []
	if push_cart != null:
		events = GameActions.push_cart(state, selected, push_cart, c)
		push_cart = null
		if not events.is_empty():
			_pushed_this_turn[selected.id] = "Pas de tir après avoir poussé un chariot."
		if events.is_empty():
			_refresh_all()
			return
	elif target != null and target.kind == Unit.Kind.CART and Board.adjacent(selected.pos, target.pos):
		push_cart = target
		hud.set_hint("Choisis où pousser le chariot (3 cases max)")
		return
	elif target != null and target != selected:
		var reason := Combat.cannot_shoot_reason(state, selected, target, watering)
		if reason != "":
			hud.set_hint(_reason_text(reason))
			return
		events = GameActions.shoot(state, selected, target, watering)
	elif Movement.can_climb(state, selected, c):
		events = GameActions.climb(state, selected, c)
		_pushed_this_turn[selected.id] = "Monter sur une table prend tout le tour : pas de tir."
	elif Movement.can_descend(state, selected, c):
		events = GameActions.descend(state, selected, c)
		_pushed_this_turn[selected.id] = "Descendre d'une table prend tout le tour : pas de tir."
	else:
		events = GameActions.move(state, selected, c)
	if events.is_empty():
		return
	await _run(events)


## Joue des événements puis rend la main (ou termine la partie).
func _run(events: Array) -> void:
	busy = true
	_show_cells([])
	hud.set_hint("")
	await _play(events)
	if watering:
		watering = false
		hud.set_watering(false)
	if _check_over():
		return
	busy = false
	_refresh_all()
	if _end_queued:
		_end_queued = false
		_end_turn()


## Victimes que la bande active peut projeter dans un bac ou un chariot.
func _projection_targets() -> Array:
	var out := []
	for v in state.units:
		if not v.is_on_board() or v.kind == Unit.Kind.CART or v.team == state.current_team or v.status == Unit.Status.CAPTURED:
			continue
		var team := GameActions.projection_team(state, state.current_team, v)
		if not team.is_empty() and SpecialActions.cannot_project_reason(state, team, v) == "":
			out.append(v)
	return out


func _project() -> void:
	if not _can_act():
		return
	var targets := _projection_targets()
	if targets.is_empty():
		hud.set_hint("Projeter : il faut être 3 au contact d'un élève (5 pour un prof, 7 pour le cuisinier), près d'un bac ou d'un chariot.")
		return
	var victim: Unit = targets[0]
	if selected != null:
		for v in targets:
			if Board.adjacent(selected.pos, v.pos):
				victim = v
	await _run(GameActions.project(state, state.current_team, victim))


func _end_turn() -> void:
	if not _can_act():
		# Pendant l'animation d'une action du joueur, on garde l'appui pour la fin de l'animation.
		if busy and not over and not _advancing and human_teams.has(state.current_team):
			_end_queued = true
		return
	busy = true
	_select(null)
	await _advance()


## Termine le tour de la bande active puis enchaîne jusqu'au prochain joueur humain.
func _advance() -> void:
	busy = true
	_advancing = true
	_apply_speed()
	_end_queued = false
	_pushed_this_turn.clear()
	_set_hovered(null)
	hud.set_hint("Clic ou Espace : accélérer" if not opponents.is_empty() else "")
	while true:
		var events := TurnFlow.end_team_turn(state)
		await _play(events)
		if _check_over():
			return
		if opponents.has(state.current_team):
			await _ai_turn(opponents[state.current_team])
			if _check_over():
				return
			continue
		break
	# Le tour des autres est fini : on rend la main à vitesse normale, sinon les clics restent avalés.
	_end_skip()
	if human_teams.size() > 1:
		await hud.show_pass_screen(state.current_team)
	viewer_team = state.current_team if human_teams.has(state.current_team) else viewer_team
	busy = false
	_autosave()
	_select_first()
	if selected != null:
		_focus(pawns[selected.id].global_position)


# --- Sauvegarde ------------------------------------------------------------------

func _save_entry() -> Dictionary:
	var stats := {}
	for t in _stats.keys():
		stats[str(t)] = _stats[t].duplicate()
	var now := Time.get_datetime_dict_from_system()
	return {
		"date": "%02d/%02d à %02dh%02d" % [now["day"], now["month"], now["hour"], now["minute"]],
		"config": {"solo": GameConfig.solo, "difficulty": GameConfig.difficulty, "players": GameConfig.players, "seed": str(_seed),
			"level": _level_path,
			"campaign": _year != null, "service": str(_service.get("id", "")), "level_name": level.name},
		"stats": stats,
		"unit_stats": _unit_stats_dict(),
		"state": SaveGame.to_dict(state),
	}


func _unit_stats_dict() -> Dictionary:
	var out := {}
	for id in _unit_stats.keys():
		out[str(id)] = _unit_stats[id].duplicate()
	return out


## Début de chaque tour du joueur : la reprise automatique suit la partie.
func _autosave() -> void:
	if not over and human_teams.has(state.current_team) and not hud_auto:
		SaveSlots.write("auto", _save_entry())


func _open_save_panel() -> void:
	if not _can_act():
		hud.set_hint("On sauvegarde pendant son tour, quand rien ne bouge.")
		return
	_save_panel = SavePanel.new(true)
	_save_panel.chosen.connect(func(key: String):
		var ok := SaveSlots.write(key, _save_entry())
		_save_panel.queue_free()
		hud.set_hint("Partie sauvegardée : %s." % SaveSlots.title(key).to_lower() if ok else "La sauvegarde a échoué.")
		if ok:
			hud.log_line("Partie sauvegardée (%s)." % SaveSlots.title(key).to_lower()))
	hud.add_child(_save_panel)


func _end_skip() -> void:
	_advancing = false
	_skipping = false
	_apply_speed()
	hud.set_hint("")


func _ai_turn(bot: Opponent) -> void:
	_refresh_all()
	for guard in 200:
		var events := bot.play_next(state)
		if events.is_empty():
			break
		await _play(events)
		if state.outcome()["over"]:
			break
		await _wait(0.12)


func _check_over() -> bool:
	var o := state.outcome()
	if not o["over"]:
		return false
	over = true
	busy = true
	_end_skip()
	_select(null)
	_show_game_over(o)
	return true


func _show_game_over(o: Dictionary) -> void:
	var winner: int = o["winner"]
	var title := "PERSONNE NE GAGNE"
	var color := Color("9a9a9a")
	var won := false
	if winner >= 0:
		if GameConfig.solo:
			won = human_teams.has(winner)
			title = "VICTOIRE !" if won else "COLLÉ JUSQU'À JUIN !"
			color = Color("3fb950") if won else BD.RED
		else:
			won = true
			title = BD.team_name(winner).to_upper() + " GAGNE !"
			color = BD.team_color(winner)
	var intro := ""
	match o["reason"]:
		"dernier": intro = "La %s est la dernière dans la cantine." % BD.team_name(winner).to_lower()
		"sonnerie": intro = "La sonnerie a retenti. La bande qui a le plus chahuté les autres l'emporte." if winner >= 0 else "La sonnerie a retenti sur une égalité parfaite."
		"personne": intro = "Plus un seul élève dans la cantine : les profs ont gagné."
	var teams := []
	var rows := [["Chahut (moral fait perdre)"], ["Élèves encore à table"], ["Moral restant"], ["Tirs réussis"], ["Adversaires saturés"], ["Emmenés par un prof"], ["Plongés dans le plat du jour"]]
	for t in state.team_count:
		var st: Dictionary = _stats[t]
		teams.append(t)
		rows[0].append(str(int(state.chahut.get(t, 0))))
		rows[1].append(str(state.students_left(t).size()))
		rows[2].append(str(state.team_moral(t)))
		rows[3].append("%d sur %d" % [st["touches"], st["tirs"]])
		rows[4].append(str(st["satures"]))
		rows[5].append(str(st["emmenes"]))
		rows[6].append(str(st["plonges"]))
	var comment := ""
	if GameConfig.solo:
		comment = "Difficulté « %s ». Appréciation : %s" % [GameSetup.difficulties()[GameConfig.difficulty]["nom"], _appreciation(won)]
	if _year != null:
		comment = _finish_service(won) + "  " + comment
	Sound.ambience(false)
	if o["reason"] == "sonnerie":
		Sound.play("sonnerie")
		await hud.show_banner("DRIIIING !", BD.YELLOW, "Fin du service", 1.2)
	Sound.play("victoire" if won else "defaite")
	hud.show_game_over(title, color, intro, teams, rows, comment, _year != null)


## Fin d'un service de l'année : expérience de chaque élève de la bande, colles, mois suivant.
func _finish_service(won: bool) -> String:
	var team: int = human_teams[0]
	var results := {}
	for u in state.units:
		if u.kind == Unit.Kind.STUDENT and u.team == team and not u.rallied:
			var st: Dictionary = _unit_stats.get(u.id, {"touches": 0, "satures": 0})
			results[u.name] = {"touches": int(st["touches"]), "satures": int(st["satures"]), "fin": Campaign.end_status(u)}
	var was_done: bool = _year.progress["termine"]
	var gains := _year.finish_service(str(_service["id"]), results, won, int(state.chahut.get(team, 0)))
	CampaignStore.save_year(_year)
	SaveSlots.erase("auto")  # le service est fini : plus rien à reprendre
	GameConfig.last_gains = {"gagne": won, "eleves": gains}
	GameConfig.show_bulletin = won and not was_done and _year.progress["termine"]
	var total := 0
	var colles := 0
	for k in gains.keys():
		total += int(gains[k]["xp"])
		colles += 1 if gains[k]["colle"] else 0
	var text := "Année scolaire : %d points d'expérience pour la bande" % total
	if colles > 0:
		text += ", %d élève%s collé%s pour le prochain service" % [colles, "s" if colles > 1 else "", "s" if colles > 1 else ""]
	return text + "."


func _appreciation(won: bool) -> String:
	var mine: Dictionary = _stats[human_teams[0]]
	if won and mine["satures"] >= 3:
		return "« Élément perturbateur d'une redoutable efficacité. »"
	if won:
		return "« A su rester à table plus longtemps que les autres. »"
	if mine["touches"] >= 10:
		return "« Vise bien, mais se fait toujours prendre. »"
	return "« Peut mieux faire. Doit apprendre à courir. »"


# --- Mise en scène des événements -----------------------------------------------------

func _play(events: Array) -> void:
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		if _is_parallel(e):
			var group := []
			while i < events.size() and _is_parallel(events[i]):
				group.append(events[i])
				i += 1
			await _play_group(group)
			continue
		await _play_one(e)
		i += 1
	_refresh_all()


func _is_parallel(e: Dictionary) -> bool:
	return e.get("parallel", false) or (e["type"] == "exit" and e.get("reason", "") == "fuite")


## Fuyards : tout le monde court en même temps.
func _play_group(group: Array) -> void:
	var longest := 0.0
	var by_unit := {}
	for e in group:
		if not by_unit.has(e["id"]):
			by_unit[e["id"]] = []
		by_unit[e["id"]].append(e)
	for id in by_unit.keys():
		var seen := false
		var time := 0.0
		for e in by_unit[id]:
			if e["type"] == "move":
				time += STEP_TIME * e["path"].size()
				seen = seen or _cell_seen(e["from"]) or _cell_seen(e["path"][-1])
			else:
				time += 0.25
				seen = seen or _cell_seen(e["cell"])
		if seen:
			longest = maxf(longest, time)
			_play_sequence(by_unit[id])
		else:
			pawns[id].refresh()
	if longest > 0.0:
		await _wait(longest + 0.05)


func _play_sequence(seq: Array) -> void:
	for e in seq:
		await _play_one(e)


func _cell_seen(c: Vector2i) -> bool:
	return Visibility.can_see(state, viewer_team, c)


func _play_one(e: Dictionary) -> void:
	_count_exits(e)
	match e["type"]:
		"move": await _play_move(e)
		"shot": await _play_shot(e)
		"climb", "descend": await _play_climb(e)
		"push": await _play_push(e)
		"project": await _play_project(e)
		"exit": await _play_exit(e)
		"spawn": await _play_spawn(e)
		"capture": await _play_capture(e)
		"plunge": await _play_plunge(e)
		"cook_wakes": await _play_cook_wakes(e)
		"neutrals_leave": await _play_neutrals_leave(e)
		"turn": await _play_turn(e)


## Pour le bulletin de fin : élèves emmenés par un prof ou plongés par le cuisinier.
func _count_exits(e: Dictionary) -> void:
	var victims := []
	var key := ""
	if e["type"] == "exit" and e.get("reason", "") == "prof":
		victims = e.get("captives", [])
		key = "emmenes"
	elif e["type"] == "plunge" and e["success"]:
		victims = [e["victim_id"]]
		key = "plonges"
	for id in victims:
		var v := state.get_unit(id)
		if v != null and v.kind == Unit.Kind.STUDENT and _stats.has(v.team):
			_stats[v.team][key] += 1


func _play_move(e: Dictionary) -> void:
	var pawn: PawnView = pawns[e["id"]]
	var path: Array = e["path"]
	var unit: Unit = pawn.unit
	if not (_cell_seen(e["from"]) or _cell_seen(path[-1])) and unit.team != viewer_team:
		pawn.refresh()
		return
	pawn.visible = true
	var height := BoardView.TABLE_HEIGHT if unit.on_table else 0.0
	pawn.position = BoardView.cell_to_world(e["from"], height)
	if not e.get("parallel", false) and not human_teams.has(unit.team):
		await _focus(pawn.position)
	var captives: Array = e.get("captives", [])
	pawn.walk(true)
	var tw := create_tween()
	var prev: Vector2i = e["from"]
	for p in path:
		var step := Vector2(p - prev)
		tw.tween_callback(pawn.set_facing.bind(step))
		tw.tween_property(pawn, "position", BoardView.cell_to_world(p, height), STEP_TIME)
		prev = p
	for cid in captives:
		if pawns.has(cid):
			var cp: PawnView = pawns[cid]
			cp.visible = true
			var ctw := create_tween()
			for p in path:
				ctw.tween_property(cp, "position", BoardView.cell_to_world(p, 0.0) + Vector3(0.45, 0, 0.2), STEP_TIME)
	await tw.finished
	pawn.walk(false)
	if unit.status == Unit.Status.SATURATED or unit.status == Unit.Status.FLEEING:
		fx.puff(pawn.position, 0.6)
	_refresh_fog()


func _play_climb(e: Dictionary) -> void:
	var pawn: PawnView = pawns[e["id"]]
	var up: bool = e["type"] == "climb"
	var target := BoardView.cell_to_world(e["to"], BoardView.TABLE_HEIGHT if up else 0.0)
	pawn.look_at_cell(e["to"])
	var tw := create_tween()
	tw.tween_property(pawn, "position", target + Vector3(0, 0.5, 0), 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(pawn, "position", target, 0.12).set_ease(Tween.EASE_IN)
	await tw.finished
	fx.puff(target, 0.5)
	if e.get("forced", false):
		fx.bubble("Ouille !", pawn.head_position(), "cri", 0.9)
		hud.log_line("%s redescend de la table." % pawn.unit.name)
	elif up:
		fx.bubble("Tous aux abris !", pawn.head_position(), "ovale", 1.0)
		hud.log_line("%s grimpe sur la table !" % pawn.unit.name)
	_refresh_fog()


func _play_push(e: Dictionary) -> void:
	var cart: PawnView = pawns[e["cart_id"]]
	var pusher: PawnView = pawns[e["id"]]
	pusher.look_at_cell(e["from"])
	pusher.hop(0.2)
	if not e["path"].is_empty():
		cart.set_facing(Vector2(e["path"][0] - e["from"]))
	var tw := create_tween()
	for p in e["path"]:
		tw.tween_property(cart, "position", BoardView.cell_to_world(p), 0.14)
	await tw.finished
	hud.log_line("%s pousse le %s." % [pusher.unit.name, cart.unit.name])


func _play_shot(e: Dictionary) -> void:
	var r: Dictionary = e["report"]
	var shooter: Unit = state.get_unit(e["id"])
	var pawn: PawnView = pawns[shooter.id]
	var victim: Unit = state.get_unit(r["victim_id"]) if r["victim_id"] >= 0 else null
	var by_human := human_teams.has(shooter.team)
	var seen: bool = _cell_seen(e["from"]) or _cell_seen(e["target_cell"])
	_stats_shot(shooter, r, victim)
	if not seen:
		for p in pawns.values():
			p.refresh()
		return
	pawn.visible = true
	if not by_human:
		await _focus(BoardView.cell_to_world(e["from"]).lerp(BoardView.cell_to_world(e["target_cell"]), 0.5))
	var target_unit := state.get_unit(r["target_id"])
	pawn.set_facing(Vector2(e["target_cell"] - e["from"]))
	var pace := 1.0 if by_human else 0.7
	hud.dice.clear()
	hud.dice.add_text("%s vise %s à %d case%s." % [_who(shooter), _who(target_unit), r["distance"], "s" if r["distance"] > 1 else ""], 22)
	var key: String = str(state.data.projectiles.get(r["projectile"], {}).get("image", r["projectile"]))
	if r.has("projectile_roll"):
		var pr: Dictionary = r["projectile_roll"]
		await hud.dice.roll("Projectile", pr, "= %d : %s (CX %d)" % [pr["total"], r["projectile_name"], r["cx"]], Color.WHITE, 0.4 * pace)
	else:
		hud.dice.add_text("Arrosage au robinet (CX 0)", 22)
	var dex: Dictionary = r["dex_roll"]
	await hud.dice.roll("Dextérité", dex, "= %d  contre  %d + %d = %d" % [dex["total"], r["distance"], r["cx"], r["threshold"]], BD.RED, 0.45 * pace)
	hud.dice.stamp("TOUCHÉ !" if r["hit"] else "RATÉ…", Color("2c9a3f") if r["hit"] else Color("8a8a8a"))
	await _wait(0.12 * pace)

	# Le projectile part en cloche.
	await pawn.throw_anim()
	Sound.play("robinet" if r.get("watering", false) else "lancer", -3.0)
	var from := pawn.body_position()
	var landing: Vector2i = e["victim_cell"]
	var dest := BoardView.cell_to_world(landing, 0.1)
	if victim != null and pawns.has(victim.id):
		dest = pawns[victim.id].body_position()
	elif state.board.is_table(landing):
		dest.y = BoardView.TABLE_HEIGHT
	await fx.throw_projectile(key, from, dest, clampf(0.4 + 0.05 * float(r["distance"]), 0.45, 1.0))
	var info := fx.impact_info(key)
	# Au-dessus de la tête de la victime, pour ne pas cacher son nom ni sa jauge.
	fx.onomatopoeia(info[0], dest + Vector3(0, 2.3 if victim != null else 0.9, 0), 1.5 if victim != null else 1.1)
	Sound.play("splat_sol", 0.0)
	if not state.board.is_table(landing):
		fx.floor_stain(info[1], BoardView.cell_to_world(landing), info[2])
	_shake = 0.12 if victim != null else 0.05

	if victim == null:
		fx.floating_text("RATÉ !", dest + Vector3(0, 1.0, 0), Color("d8d8e0"), 72)
		hud.dice.add_text("La nourriture s'écrase par terre.", 22)
		hud.log_line("%s rate %s." % [_who(shooter), _who(target_unit)])
		await _wait(0.35 * pace)
		return
	var vp: PawnView = pawns[victim.id]
	vp.hit_flash()
	vp.add_stain(GameAssets.texture("effets", str(info[1]) + ".png"), info[2], from, str(info[1]))
	var dmg: Dictionary = r["damage_roll"]
	var prefix := "Dégâts" if r["hit"] else "Retombée sur %s" % _who(victim)
	if dmg["faces"].is_empty():
		hud.dice.add_text("%s : %d point de moral" % [prefix, dmg["total"]], 22)
	else:
		await hud.dice.roll(prefix, dmg, "= %d de moral" % dmg["total"], BD.YELLOW, 0.35 * pace)
	fx.floating_text("-%d" % r["damage"], vp.head_position(), BD.YELLOW if r["damage"] < 10 else BD.RED, 84 if r["damage"] < 10 else 110)
	hud.log_line("%s touche %s : [b]-%d[/b] (%s)" % [_who(shooter), _who(victim), r["damage"], r["projectile_name"]])
	vp.refresh()
	if r.get("saturated", false):
		Sound.play("beurk")
		fx.bubble("BEURK !", vp.head_position(), "cri", 1.2, Color("3d8a1e"))
		hud.dice.add_text("%s est saturé et file vers la sortie !" % _who(victim), 22, BD.RED)
		hud.log_line("[b]%s est saturé ![/b]" % _who(victim))
	match r.get("neutral_reaction", Combat.NeutralReaction.NONE):
		Combat.NeutralReaction.RALLIED:
			fx.bubble("Je suis avec vous !", vp.head_position(), "ovale", 1.3)
			hud.log_line("Un neutre rejoint la %s !" % BD.team_name(shooter.team).to_lower())
		Combat.NeutralReaction.FLEEING:
			fx.bubble("Au secours !", vp.head_position(), "ovale", 1.0)
		Combat.NeutralReaction.BERSERK:
			fx.bubble("#@%&§!!", vp.head_position(), "cri", 1.4, BD.RED)
			Sound.play("rires", -6.0, 1.3)
			hud.log_line("[b]Un neutre devient BERSERK ![/b]")
	await _wait((0.55 if by_human else 0.4) * pace)
	_refresh_fog()


func _stats_shot(shooter: Unit, r: Dictionary, victim: Unit) -> void:
	if not _unit_stats.has(shooter.id):
		_unit_stats[shooter.id] = {"touches": 0, "satures": 0}
	if r["hit"] and victim != null and victim.team != shooter.team:
		_unit_stats[shooter.id]["touches"] += 1
	if victim != null and r.get("saturated", false) and victim.team != shooter.team:
		_unit_stats[shooter.id]["satures"] += 1
	if not _stats.has(shooter.team):
		return
	_stats[shooter.team]["tirs"] += 1
	if r["hit"]:
		_stats[shooter.team]["touches"] += 1
	if victim != null and r.get("saturated", false):
		_stats[shooter.team]["satures"] += 1


func _play_exit(e: Dictionary) -> void:
	var pawn: PawnView = pawns[e["id"]]
	if not _cell_seen(e["cell"]):
		pawn.refresh()
		for cid in e.get("captives", []):
			pawns[cid].refresh()
		return
	var names := []
	for cid in e.get("captives", []):
		var cu := state.get_unit(cid)
		names.append(cu.name)
		var cp: PawnView = pawns[cid]
		create_tween().tween_property(cp, "scale", Vector3.ONE * 0.01, 0.25)
	var tw := create_tween()
	tw.tween_property(pawn, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	await tw.finished
	pawn.scale = Vector3.ONE
	for cid in e.get("captives", []):
		pawns[cid].scale = Vector3.ONE
		pawns[cid].refresh()
	pawn.refresh()
	if e["reason"] == "prof" and not names.is_empty():
		fx.bubble("Chez le directeur !", BoardView.cell_to_world(e["cell"], 2.2), "cri", 1.2)
		hud.log_line("[b]Un prof emmène %s chez le directeur.[/b]" % ", ".join(names))
		await _wait(0.6)
	elif pawn.unit.kind == Unit.Kind.STUDENT:
		hud.log_line("%s quitte la cantine." % pawn.unit.name)


func _play_spawn(e: Dictionary) -> void:
	var u := state.get_unit(e["id"])
	var pawn := _add_pawn(u)
	_refresh_fog()
	hud.dice.clear()
	await hud.dice.roll("Un prof arrive ! Porte", e["roll"], "= porte %s" % e["door"], Color("6b6b6b"), 0.35)
	hud.log_line("Un prof entre par la porte %s." % e["door"])
	if not pawn.shown:
		return
	await _focus(pawn.position)
	Sound.play("sifflet", -4.0)
	pawn.scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(pawn, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fx.bubble(["SILENCE !", "ÇA SUFFIT !", "QUI A LANCÉ ÇA ?", "AU PIQUET !"][u.id % 4], pawn.head_position(), "cri", 1.1)
	await _wait(0.7)


func _play_capture(e: Dictionary) -> void:
	var teacher: PawnView = pawns[e["id"]]
	var victim: PawnView = pawns[e["victim_id"]]
	if not _cell_seen(e["cell"]) and victim.unit.team != viewer_team:
		victim.refresh()
		return
	await _focus(teacher.position)
	teacher.set_facing(Vector2(e["cell"] - teacher.unit.pos))
	teacher.hop(0.25)
	Sound.play("sifflet", -6.0, 1.15)
	hud.dice.clear()
	hud.dice.add_text("Un prof tente d'attraper %s (1 à %d : pris)." % [_who(victim.unit), state.data.roll_threshold("capture_max")], 22)
	await hud.dice.roll("Capture", e["roll"], "", Color("6b6b6b"), 0.4)
	if e["success"]:
		hud.dice.stamp("ATTRAPÉ PAR L'OREILLE !", BD.RED)
		fx.bubble("Aïe aïe aïe !", victim.head_position(), "ovale", 1.1)
		hud.log_line("[b]Un prof attrape %s ![/b]" % _who(victim.unit))
		_shake = 0.1
	else:
		hud.dice.stamp("ESQUIVÉ !", Color("2c9a3f"))
		fx.bubble("Raté !", victim.head_position(), "ovale", 0.9)
		victim.hop(0.4)
	victim.refresh()
	await _wait(0.75)


func _play_plunge(e: Dictionary) -> void:
	var cook: PawnView = pawns[e["id"]]
	var victim: PawnView = pawns[e["victim_id"]]
	if not _cell_seen(e["cell"]) and victim.unit.team != viewer_team:
		victim.refresh()
		return
	await _focus(cook.position)
	cook.set_facing(Vector2(e["cell"] - cook.unit.pos))
	hud.dice.clear()
	hud.dice.add_text("Le cuisinier empoigne %s (1 à %d : plongeon)." % [_who(victim.unit), state.data.roll_threshold("plongeon_max")], 22)
	await hud.dice.roll("Plongeon", e["roll"], "", Color.WHITE, 0.4)
	if e["success"]:
		hud.dice.stamp("DANS LE PLAT DU JOUR !", BD.RED)
		Sound.play("plongeon")
		victim.visible = true
		var tw := create_tween()
		tw.tween_property(victim, "position:y", 2.2, 0.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(victim, "scale", Vector3.ONE * 0.05, 0.25)
		await tw.finished
		fx.onomatopoeia("bloup", BoardView.cell_to_world(e["cell"], 1.6), 1.8)
		victim.scale = Vector3.ONE
		hud.log_line("[b]Le cuisinier plonge %s dans le plat du jour ![/b]" % _who(victim.unit))
		_shake = 0.15
	else:
		hud.dice.stamp("IL GLISSE DES MAINS !", Color("2c9a3f"))
		victim.hop(0.4)
	victim.refresh()
	await _wait(0.75)


func _play_project(e: Dictionary) -> void:
	var victim: PawnView = pawns[e["victim_id"]]
	for id in e["ids"]:
		pawns[id].look_at_cell(e["cell"])
		pawns[id].hop(0.3)
	hud.dice.clear()
	hud.dice.add_text("Tous ensemble sur %s (1 à %d : projeté)." % [_who(victim.unit), state.data.roll_threshold("projection_max")], 22)
	await hud.dice.roll("Projection", e["roll"], "", BD.YELLOW, 0.4)
	if e["success"]:
		hud.dice.stamp("ET HOP, DANS LE BAC !", Color("2c9a3f"))
		Sound.play("plongeon")
		var tw := create_tween()
		tw.tween_property(victim, "position:y", 2.4, 0.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(victim, "scale", Vector3.ONE * 0.05, 0.25)
		await tw.finished
		fx.onomatopoeia("bloup", BoardView.cell_to_world(e["cell"], 1.6), 1.8)
		victim.scale = Vector3.ONE
		hud.log_line("[b]%s finit dans le bac ![/b]" % _who(victim.unit))
		_shake = 0.15
	else:
		hud.dice.stamp("IL S'ACCROCHE !", Color("8a8a8a"))
	victim.refresh()
	await _wait(0.7)


func _play_cook_wakes(e: Dictionary) -> void:
	var cook: PawnView = pawns[e["id"]]
	hud.log_line("[b]Le cuisinier a vu quelqu'un entrer dans sa cuisine ![/b]")
	if not cook.shown:
		return
	await _focus(cook.position)
	cook.hop(0.5)
	_shake = 0.15
	fx.bubble("MA CUISINE !!!", cook.head_position(), "cri", 1.3, BD.RED)
	await _wait(0.9)


func _play_neutrals_leave(e: Dictionary) -> void:
	if _tables_stocked:
		_tables_stocked = false
		board_view.set_tables_stocked(false)
	hud.log_line("Les neutres ont fini de manger : ils sortent.")
	for id in e["ids"]:
		pawns[id].refresh()


func _play_turn(e: Dictionary) -> void:
	_refresh_all()
	var team: int = e["team"]
	if int(e["turn"]) != _last_turn_shown:
		_last_turn_shown = e["turn"]
		if not state.tables_have_ammo() and _tables_stocked:
			_tables_stocked = false
			board_view.set_tables_stocked(false)
			Sound.play("sonnerie", -4.0)
			await hud.show_banner("TABLES VIDES !", BD.RED, "Munitions : bacs et chariots de la cuisine", 1.5)
		await hud.show_banner("TOUR %d" % e["turn"], BD.YELLOW, BD.team_name(team), 0.7)
	else:
		await hud.show_banner(BD.team_name(team).to_upper(), BD.team_color(team).lightened(0.25), "", 0.5)
	hud.log_line("[b]— Tour %d : %s —[/b]" % [e["turn"], BD.team_name(team)])


# --- Rafraîchissement ---------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_fog()
	var human_turn := human_teams.has(state.current_team) and not over
	hud.set_status(state, human_turn)
	hud.set_unit(selected, state.max_ap(selected) if selected != null else state.data.ap_per_turn(), "" if human_turn or over else BD.team_name(state.current_team))
	var roster: Array = []
	for u in state.units:
		if u.team == viewer_team and u.kind != Unit.Kind.CART and (u.kind == Unit.Kind.STUDENT or u.is_on_board()):
			roster.append(u)
	hud.set_roster(roster, selected)
	var can_water := _can_act() and selected != null and state.is_near_tap(selected) and not selected.has_shot
	hud.set_actions(can_water, _can_act() and not _projection_targets().is_empty(), human_turn and not busy)
	if not can_water and watering:
		watering = false
		hud.set_watering(false)
	_show_cells([])


## Brouillard de guerre : on ne montre que ce que voit la bande du joueur.
func _refresh_fog() -> void:
	board_view.set_fog(Visibility.hidden_cells(state, viewer_team))
	for id in pawns.keys():
		var p: PawnView = pawns[id]
		p.shown = Visibility.unit_visible(state, viewer_team, p.unit)
		p.refresh()
		if p == _hovered:
			p.set_hover(true, _hover_text(p.unit))


func _who(u: Unit) -> String:
	if u == null:
		return "?"
	match u.kind:
		Unit.Kind.NEUTRAL:
			if u.status == Unit.Status.BERSERK:
				return "le berserk"
			return "un neutre rallié" if u.rallied else "un neutre"
		Unit.Kind.TEACHER: return "le prof"
		Unit.Kind.COOK: return "le cuisinier"
	# Les deux bandes ont les mêmes six élèves : on précise la couleur.
	return "%s (%s)" % [u.name, BD.TEAM_NAMES[u.team % BD.TEAM_NAMES.size()]] if u.team >= 0 else u.name


## Chance de toucher en mots (le joueur ne voit pas de pourcentage, seulement un ordre d'idée).
func _chance_word(shooter: Unit, dist: int) -> String:
	var p := 0.0
	var pick := _odds.sum_distribution(2)
	for roll in pick.keys():
		var cx := int(state.data.projectile(str(roll))["cx"])
		if watering:
			cx = Combat.min_cx(state, true)
		p += pick[roll] * _odds.chance_at_least(shooter.dex_d6, shooter.dex_bonus, dist + cx)
	if p >= 0.85:
		return "presque sûr"
	if p >= 0.55:
		return "bonnes"
	if p >= 0.25:
		return "moyennes"
	return "faibles"


func _reason_text(reason: String) -> String:
	match reason:
		"deja_tire":
			if selected != null and _pushed_this_turn.has(selected.id):
				return _pushed_this_turn[selected.id]
			return "Déjà tiré ce tour."
		"pas_assez_de_pa": return "Pas assez de PA pour tirer (%d)." % state.data.ap_cost("tir")
		"cible_saturee": return "Déjà saturé : il file vers la sortie."
		"hors_de_portee":
			return "Hors de portée : %d au plus aux dés de %s." % [Combat.max_roll(selected), selected.name] if selected != null else "Hors de portée."
		"pas_de_munitions": return "Pas de munition : va au contact d'une table garnie, d'un bac ou d'un chariot."
		"mur": return "Un mur bloque la trajectoire."
		"trop_loin": return "Trop loin pour arroser (%d cases max)." % int(state.data.projectile("robinet")["portee_max"])
		"pas_de_robinet": return "Il faut être au contact d'un robinet pour arroser."
		"ne_tire_pas": return "Ce personnage ne tire pas."
		"cible_invalide": return "Cible impossible."
		_: return reason
