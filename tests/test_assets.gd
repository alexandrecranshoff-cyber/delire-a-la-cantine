extends TestCase
## Garde-fous sur les fichiers du jeu : un bruitage vide fait planter le navigateur.


func test_aucun_bruitage_vide() -> void:
	var dir := DirAccess.open("res://assets/audio/sfx")
	assert_true(dir != null, "dossier des bruitages")
	if dir == null:
		return
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".wav"):
			continue
		var bytes := FileAccess.get_file_as_bytes("res://assets/audio/sfx/" + f)
		# Sans Git LFS (tests sur GitHub), le fichier n'est qu'un pointeur : rien à vérifier.
		if bytes.slice(0, 7).get_string_from_ascii() == "version":
			continue
		count += 1
		assert_true(bytes.size() > 2000, "%s est vide (%d octets)" % [f, bytes.size()])
	assert_true(count == 0 or count >= 12, "les 12 bruitages sont là")
