class_name GameAssets
extends RefCounted
## Accès aux images et aux sons. Deux qualités : assets/hd (version PC) et assets/sd (version web).
## L'export ne garde qu'un des deux dossiers ; dans l'éditeur, la HD est prise si elle existe.

static var _quality := ""
static var _cache := {}
static var _look := {}
static var _pawn_meta := {}


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
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]


static func music(name: String) -> AudioStream:
	var p := path("musique", name + ".ogg")
	if not _cache.has(p):
		var s = load(p) if ResourceLoader.exists(p) else null
		if s is AudioStreamOggVorbis:
			s.loop = true
		_cache[p] = s
	return _cache[p]


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
