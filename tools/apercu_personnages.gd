extends SceneTree
## Planche d'essai des personnages 3D : les élèves des deux bandes côte à côte, les neutres, le prof
## et le cuisinier, avec quelques taches de nourriture reçues. Sert à régler les habits de bande
## (data/habits.json) et le rendu des taches sans lancer une partie.
##
##   xvfb-run godot --path . --rendering-driver opengl3 -s tools/apercu_personnages.gd -- capture=planche.png [taches=3] [angle=30] [zoom=6] [gros=Ledur]

const KINDS := ["tache_creme", "tache_marron", "tache_verte", "tache_orange"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var out := str(args.get("capture", "user://planche.png"))
	var stains := int(args.get("taches", "3"))
	var angle := deg_to_rad(float(args.get("angle", "25")))
	seed(int(args.get("graine", "7")))
	await process_frame
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d9cfb8")
	root3d.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("6fb7ae")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = fm
	ground.mesh = plane
	root3d.add_child(ground)

	var names := ["Bigleux", "Grobill", "Zieuglôque", "Ledur", "Dudugenoux", "Delamensa"]
	var units: Array = []
	var id := 0
	for team in 2:
		for n in names:
			var u := Unit.new()
			u.id = id
			u.name = n
			u.team = team
			u.kind = Unit.Kind.STUDENT
			u.moral = 10
			u.max_moral = 10
			u.ap = 12
			u.pos = Vector2i(names.find(n), team * 2)
			units.append(u)
			id += 1
	for k in 3:
		var u := Unit.new()
		u.id = k
		u.name = "Neutre"
		u.kind = Unit.Kind.NEUTRAL
		u.team = -1
		u.pos = Vector2i(k, 4)
		units.append(u)
	var rallied := Unit.new()
	rallied.id = 1
	rallied.name = "Neutre rallié"
	rallied.kind = Unit.Kind.NEUTRAL
	rallied.rallied = true
	rallied.team = 1
	rallied.pos = Vector2i(3, 4)
	units.append(rallied)
	for k in [Unit.Kind.TEACHER, Unit.Kind.COOK]:
		var u := Unit.new()
		u.id = 20 + k
		u.name = "Adulte"
		u.kind = k
		u.moral = 10
		u.max_moral = 10
		u.pos = Vector2i(4 + int(k == Unit.Kind.COOK), 4)
		units.append(u)

	var only := str(args.get("gros", ""))
	var pawns: Array = []
	for u in units:
		if only != "" and u.name != only:
			continue
		var p := PawnView.new()
		root3d.add_child(p)
		p.setup(u)
		p.position = Vector3(u.pos.x * 1.25 - 3.1, 0, u.pos.y * 1.6 - 3.2)
		p.set_facing(Vector2(0, 1), true)
		p.face_camera(rad_to_deg(angle))
		pawns.append(p)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var zoom := float(args.get("zoom", "6.5" if only == "" else "1.3"))
	var target: Vector3 = Vector3(0, 0.8, 0) if only == "" else pawns[0].position + Vector3(0, 0.75, 0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom * 2.0
	var tilt := deg_to_rad(float(args.get("inclinaison", "35")))
	cam.position = target + Vector3(sin(angle) * cos(tilt), sin(tilt), cos(angle) * cos(tilt)) * 30.0
	cam.look_at(target)
	for p in pawns:
		p.set_zoom(zoom * 2.0)
	await process_frame
	await process_frame
	for p in pawns:
		for k in stains:
			var from: Vector3 = p.position + Vector3(randf_range(-4, 4), 1.0, randf_range(1, 5)).rotated(Vector3.UP, angle)
			var kind: String = KINDS[randi() % KINDS.size()]
			p.add_stain(null, Color.WHITE, from, kind)
	for i in 30:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("Planche : ", out)
	quit()
