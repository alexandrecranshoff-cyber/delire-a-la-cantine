extends SceneTree
## Extrait les animations de référence (jouées par Grobill) sous une forme indépendante du
## personnage : pour chaque os et chaque image, la rotation « par rapport à la pose de liaison »,
## exprimée dans le repère du squelette. Le jeu les réapplique à n'importe quel personnage ayant
## les mêmes noms d'os (voir GameAssets.animations_for).
##
##   godot --headless --path . -s tools/extraire_animations.gd
##
## Sources : assets/reference/animations/grobill_<clip>.glb (sorties de Higgsfield allégées).
## Résultat : assets/animations/<clip>.res

const SOURCE_DIR := "res://assets/reference/animations/"
const TARGET_DIR := "res://assets/animations/"
const CLIPS := ["repos", "marche", "lancer", "touche"]
const FPS := 20.0
## Bras rabattus le long du corps (en degrés) : le repos de la bibliothèque garde les bras écartés
## comme un mannequin. Appliqué au bras, à l'avant-bras et à la main, côté gauche et droit.
const ARM_DROP := {"repos": 22.0}
const ARM_BONES := ["Arm", "ForeArm", "Hand"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET_DIR))
	for clip in CLIPS:
		var path := ProjectSettings.globalize_path(SOURCE_DIR + "grobill_%s.glb" % clip)
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if not FileAccess.file_exists(path) or doc.append_from_file(path, state) != OK:
			push_warning("Clip absent : " + path)
			continue
		var scene := doc.generate_scene(state)
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var mesh: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var source: Animation = player.get_animation(player.get_animation_list()[0])
		var anim := _extract(source, skeleton, mesh.skin, clip == "marche", float(ARM_DROP.get(clip, 0.0)))
		var err := ResourceSaver.save(anim, TARGET_DIR + clip + ".res", ResourceSaver.FLAG_COMPRESS)
		print("%s : %.2f s, %d pistes (%s)" % [clip, anim.length, anim.get_track_count(), error_string(err)])
		scene.free()
	quit()


## Pose de liaison de chaque os dans le repère du squelette, d'après la peau du maillage.
static func bind_globals(skeleton: Skeleton3D, skin: Skin) -> Dictionary:
	var out := {}
	for i in skin.get_bind_count():
		var name := String(skin.get_bind_name(i))
		if name == "":
			name = skeleton.get_bone_name(skin.get_bind_bone(i))
		var bind := skin.get_bind_pose(i)
		var inv := bind.affine_inverse()
		out[name] = {"rot": inv.basis.orthonormalized().get_rotation_quaternion(), "pos": inv.origin * bind.basis.get_scale().x}
	return out


func _extract(source: Animation, skeleton: Skeleton3D, skin: Skin, in_place: bool, arm_drop: float = 0.0) -> Animation:
	var binds := bind_globals(skeleton, skin)
	# Rotation qui rabat chaque bras vers le corps, autour de l'axe avant-arrière (Z) du squelette.
	var drops := {}
	if arm_drop != 0.0:
		for side in ["Left", "Right"]:
			var sign := -1.0 if side == "Left" else 1.0
			for b in ARM_BONES:
				drops[side + b] = Quaternion(Vector3(0, 0, 1), deg_to_rad(arm_drop) * sign)
	var rot_tracks := {}
	var pos_tracks := {}
	for t in source.get_track_count():
		var bone := String(source.track_get_path(t).get_concatenated_subnames())
		match source.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_tracks[bone] = t
			Animation.TYPE_POSITION_3D:
				pos_tracks[bone] = t
	var anim := Animation.new()
	anim.length = source.length
	var out_tracks := {}
	for b in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(b)
		if not binds.has(name):
			continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("S:" + name))
		out_tracks[name] = track
	var root := skeleton.get_bone_name(skeleton.get_parentless_bones()[0])
	var hips := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips, NodePath("S:" + root))
	var root_bind: Vector3 = binds[root]["pos"]
	var frames := int(ceil(source.length * FPS))
	var first := Vector3.ZERO
	var last := Vector3.ZERO
	if pos_tracks.has(root):
		first = source.position_track_interpolate(pos_tracks[root], 0.0)
		last = source.position_track_interpolate(pos_tracks[root], source.length)
	for f in frames + 1:
		var time := minf(f / FPS, source.length)
		var globals := {}
		for b in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(b)
			var local := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
			if rot_tracks.has(name):
				local = source.rotation_track_interpolate(rot_tracks[name], time)
			var parent := skeleton.get_bone_parent(b)
			var g: Quaternion = local if parent < 0 else globals[parent] * local
			globals[b] = g
			if out_tracks.has(name):
				var delta: Quaternion = (g * (binds[name]["rot"] as Quaternion).inverse()).normalized()
				if drops.has(name):
					delta = (drops[name] as Quaternion) * delta
				anim.rotation_track_insert_key(out_tracks[name], time, delta)
		var pos := root_bind
		if pos_tracks.has(root):
			pos = source.position_track_interpolate(pos_tracks[root], time)
			if in_place:
				# La marche se joue sur place : c'est le jeu qui déplace le pion.
				var drift := first.lerp(last, time / source.length) - first
				pos -= Vector3(drift.x, 0, drift.z)
		# Décalage des hanches en fraction de leur hauteur : il s'adapte à la taille du personnage.
		anim.position_track_insert_key(hips, time, (pos - root_bind) / root_bind.y)
	return anim
