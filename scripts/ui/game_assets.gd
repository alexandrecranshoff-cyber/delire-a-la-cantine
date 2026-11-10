class_name GameAssets
extends RefCounted
## Accès aux images et aux sons. Deux qualités : assets/hd (version PC) et assets/sd (version web).
## L'export ne garde qu'un des deux dossiers ; dans l'éditeur, la HD est prise si elle existe.

static var _quality := ""
static var _cache := {}
static var _look := {}
static var _pawn_meta := {}
## Clips d'animation des personnages : nom -> joué en boucle.
const ANIMATIONS := {"repos": true, "marche": true, "lancer": false, "touche": false}


static func quality() -> String:
	if _quality == "":
		var want_hd := not OS.has_feature("web") and ResourceLoader.exists("res://assets/hd/textures/papier.png")
		_quality = "hd" if want_hd else "sd"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("qualite="):
				_quality = a.split("=")[1]
		if not ResourceLoader.exists("res://assets/%s/textures/papier.png" % _quality):
			_quality = "hd" if _quality == "sd" else "sd"
	return _quality


static func is_hd() -> bool:
	return quality() == "hd"


static func path(family: String, name: String) -> String:
	return "res://assets/%s/%s/%s" % [quality(), family, name]


## Texture pour l'interface (telle quelle).
static func ui_texture(family: String, name: String) -> Texture2D:
	var p := path(family, name)
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]


## Texture pour la 3D : avec mipmaps, pour rester nette quand elle est petite à l'écran.
static func texture(family: String, name: String) -> Texture2D:
	var key := "3d:" + path(family, name)
	if not _cache.has(key):
		var src := ui_texture(family, name)
		if src == null:
			_cache[key] = null
		else:
			var img := src.get_image()
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func sound(name: String) -> AudioStream:
	var p := "res://assets/audio/sfx/%s.wav" % name
	if not _cache.has(p):
		var s: AudioStream = load(p) if ResourceLoader.exists(p) else null
		# Un son vide fait planter la lecture audio du navigateur : on l'ignore.
		if s != null and s.get_length() <= 0.01:
			push_warning("Bruitage vide ignoré : " + p)
			s = null
		_cache[p] = s
	return _cache[p]


static func music(name: String) -> AudioStream:
	var p := path("musique", name + ".ogg")
	if not _cache.has(p):
		var s = load(p) if ResourceLoader.exists(p) else null
		if s is AudioStreamOggVorbis:
			s.loop = true
		_cache[p] = s
	return _cache[p]


## Modèle 3D d'un personnage, ou null s'il manque (le pion en carton sert alors de repli).
## L'argument de lancement « carton » force les pions en carton.
static func model(image: String) -> PackedScene:
	if OS.get_cmdline_user_args().has("carton"):
		return null
	var p := path("personnages", image + ".glb")
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]


## Animations d'un personnage : les clips de référence (assets/animations, voir
## tools/extraire_animations.gd) appliqués à son squelette. Chaque clip donne, par os, la
## rotation par rapport à la pose de liaison dans le repère du squelette : on la recompose avec
## la pose de liaison du personnage, puis on revient en rotations locales.
static func animations_for(image: String, skeleton: Skeleton3D, skin: Skin, skeleton_path: NodePath) -> AnimationLibrary:
	var key := "anim:" + image
	if _cache.has(key):
		return _cache[key]
	var library := AnimationLibrary.new()
	_cache[key] = library
	var root := skeleton.get_parentless_bones()[0]
	var bind_rot := {}
	var root_pos := skeleton.get_bone_rest(root).origin
	for i in skin.get_bind_count():
		var bind_name := String(skin.get_bind_name(i))
		var bone := skeleton.find_bone(bind_name) if bind_name != "" else skin.get_bind_bone(i)
		if bone < 0:
			continue
		var bind := skin.get_bind_pose(i)
		var inv := bind.affine_inverse()
		bind_rot[bone] = inv.basis.orthonormalized().get_rotation_quaternion()
		if bone == root:
			root_pos = inv.origin * bind.basis.get_scale().x
	for clip in ANIMATIONS.keys():
		var p := "res://assets/animations/%s.res" % clip
		if not ResourceLoader.exists(p):
			continue
		var source: Animation = load(p)
		var tracks := {}
		var hips := -1
		for t in source.get_track_count():
			var bone := skeleton.find_bone(String(source.track_get_path(t).get_concatenated_subnames()))
			if source.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				if bone >= 0 and bind_rot.has(bone):
					tracks[bone] = t
			elif bone == root:
				hips = t
		if tracks.is_empty():
			continue
		var anim := Animation.new()
		anim.length = source.length
		anim.loop_mode = Animation.LOOP_LINEAR if ANIMATIONS[clip] else Animation.LOOP_NONE
		var out := {}
		for bone in tracks.keys():
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(bone)]))
			out[bone] = t
		var hips_out := -1
		if hips >= 0:
			hips_out = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(hips_out, NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(root)]))
		var first: int = tracks.values()[0]
		for k in source.track_get_key_count(first):
			var time := source.track_get_key_time(first, k)
			var globals := {}
			for b in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(b)
				var parent_g: Quaternion = globals[parent] if parent >= 0 else Quaternion.IDENTITY
				var g: Quaternion
				if out.has(b):
					var delta: Quaternion = source.track_get_key_value(tracks[b], k)
					g = delta * (bind_rot[b] as Quaternion)
					anim.rotation_track_insert_key(out[b], time, (parent_g.inverse() * g).normalized())
				else:
					g = parent_g * skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
				globals[b] = g
			if hips_out >= 0:
				var offset: Vector3 = source.track_get_key_value(hips, k)
				anim.position_track_insert_key(hips_out, time, root_pos + offset * root_pos.y)
		library.add_animation(clip, anim)
	return library


static func _json(p: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(p))


## Apparence d'un pion : {"image", "taille", "aspect", "marge", "vues"}.
static func look_for(unit: Unit) -> Dictionary:
	if _look.is_empty():
		_look = _json("res://data/apparence.json")
		_pawn_meta = _json("res://data/pions_images.json")["images"]
	var entry: Dictionary
	match unit.kind:
		Unit.Kind.STUDENT:
			entry = _look["eleves"].get(unit.name, _look["neutres"][0])
		Unit.Kind.TEACHER:
			entry = _look["autres"]["prof"]
		Unit.Kind.COOK:
			entry = _look["autres"]["cuisinier"]
		Unit.Kind.NEUTRAL:
			var variants: Array = _look["neutres"]
			entry = variants[unit.id % variants.size()]
		_:
			return {"image": _look["chariots"]["image"], "taille": float(_look["chariots"]["taille"]), "aspect": 0.8, "marge": 0.0, "vues": 1}
	var meta: Dictionary = _pawn_meta[entry["image"]]
	return {"image": entry["image"], "taille": float(entry["taille"]), "aspect": float(meta["aspect"]), "marge": float(meta["marge"]), "vues": 5}


static func portrait(unit: Unit) -> Texture2D:
	if unit.kind == Unit.Kind.CART:
		return ui_texture("accessoires", "chariot.png")
	return ui_texture("portraits", str(look_for(unit)["image"]) + ".png")
