extends TestCase
## Année scolaire : services, expérience, améliorations, élèves collés (data/campagne.json).


func _year(difficulty: String = "normal") -> Campaign:
	return Campaign.new_year(difficulty, GameData.load_default().student_names())


func _results(fin: String = "a_table", touches: int = 0, satures: int = 0) -> Dictionary:
	var out := {}
	for n in GameData.load_default().student_names():
		out[n] = {"touches": touches, "satures": satures, "fin": fin}
	return out


func test_annee_commence_en_septembre() -> void:
	var c := _year()
	assert_eq(c.current_service()["id"], "septembre")
	assert_eq(c.progress["eleves"].size(), 6, "la bande du livret")
	var playable := c.services().filter(func(s): return Campaign.is_playable(s))
	assert_eq(playable.size(), 3, "septembre, novembre, décembre construits")
	for s in playable:
		assert_true(FileAccess.file_exists(Campaign.level_path(s)), s["id"])


func test_points_d_experience() -> void:
	var c := _year()
	var xp: Dictionary = c.data["experience"]
	var r := _results("a_table", 3, 1)
	r["Bigleux"] = {"touches": 0, "satures": 0, "fin": "sature"}
	var gains := c.finish_service("septembre", r, true)
	assert_eq(gains["Grobill"]["xp"], 3 * int(xp["touche"]) + int(xp["sature"]) + int(xp["reste_a_table"]) + int(xp["victoire"]))
	assert_eq(gains["Bigleux"]["xp"], int(xp["victoire"]), "saturé : seulement la victoire de la bande")
	assert_eq(c.student("Grobill")["xp"], gains["Grobill"]["xp"])


func test_victoire_ouvre_le_service_suivant() -> void:
	var c := _year()
	c.finish_service("septembre", _results(), false)
	assert_eq(c.current_service()["id"], "septembre", "perdu : on refait le service")
	c.finish_service("septembre", _results(), true)
	assert_eq(c.current_service()["id"], "novembre")
	c.finish_service("novembre", _results(), true)
	c.finish_service("decembre", _results(), true)
	assert_true(c.progress["termine"], "bulletin du premier trimestre")
	assert_eq(c.current_service()["id"], "decembre", "les services suivants ne sont pas encore construits")


func test_ameliorations() -> void:
	var c := _year()
	var base: Dictionary = GameData.load_default().characters["Bigleux"]
	assert_false(c.can_upgrade("Bigleux", "adresse"), "pas assez de points")
	c.student("Bigleux")["xp"] = 100
	assert_true(c.upgrade("Bigleux", "adresse"))
	var s := c.sheet("Bigleux", base)
	assert_eq(s["dex_bonus"], int(base["dexterite"]["bonus"]) + 1, "1er achat : +1")
	assert_eq(s["dex_d6"], int(base["dexterite"]["d6"]))
	assert_true(c.upgrade("Bigleux", "adresse"))
	s = c.sheet("Bigleux", base)
	assert_eq(s["dex_d6"], int(base["dexterite"]["d6"]) + 1, "2e achat : un dé de plus")
	assert_false(c.upgrade("Bigleux", "adresse"), "maximum atteint")
	assert_true(c.upgrade("Bigleux", "moral"))
	assert_true(c.upgrade("Bigleux", "pa"))
	s = c.sheet("Bigleux", base)
	assert_eq(s["moral"], int(base["moral"]) + int(c.data["ameliorations"]["moral"]["gain"]))
	assert_eq(s["ap_bonus"], 1)
	assert_eq(c.student("Bigleux")["xp"], 100 - 2 * c.upgrade_cost("adresse") - c.upgrade_cost("moral") - c.upgrade_cost("pa"))


func test_partie_preparee_avec_les_fiches_ameliorees() -> void:
	var c := _year("normal")
	c.student("Grobill")["xp"] = 100
	c.upgrade("Grobill", "pa")
	c.upgrade("Grobill", "moral")
	c.student("Ledur")["colle"] = true
	var data := GameData.load_default()
	var service := c.service_by_id("decembre")
	var level := Level.load_file(Campaign.level_path(service))
	var s := GameSetup.new_game(level, data, 5, 2, [1], c.difficulty())
	var ia_before := 0
	for u in s.units:
		if u.team == 1 and u.name == "Grobill":
			ia_before = u.max_moral
	c.prepare_state(s, 0, service)
	var pct := int(GameSetup.difficulties()["normal"]["moral_joueur_pct"])
	for u in s.units:
		if u.kind != Unit.Kind.STUDENT:
			continue
		if u.team == 0 and u.name == "Grobill":
			assert_eq(u.ap_bonus, 1)
			assert_eq(u.ap, data.ap_per_turn() + 1, "PA en plus dès le premier tour")
			assert_eq(u.max_moral, int(round((90 + 10) * pct / 100.0)))
		if u.team == 0 and u.name == "Ledur":
			assert_eq(u.moral, int(round(u.max_moral * int(c.data["colle"]["moral_pct"]) / 100.0)), "collé : moral réduit")
		if u.team == 1 and u.name == "Grobill":
			assert_eq(u.max_moral, ia_before + int(round(90 * 20 / 100.0)), "pression de décembre : +20 % de moral")
	var normal := int(GameSetup.difficulties()["normal"]["prof_periode"])
	assert_eq(s.option("prof_periode"), maxi(1, normal - 1))
	assert_eq(s.option("tours_munitions_tables"), 3)


func test_eleve_colle_au_service_suivant() -> void:
	var c := _year()
	var r := _results()
	r["Delamensa"]["fin"] = "colle"
	c.finish_service("septembre", r, true)
	assert_true(c.student("Delamensa")["colle"])
	assert_false(c.student("Grobill")["colle"])
	c.finish_service("novembre", _results(), true)
	assert_false(c.student("Delamensa")["colle"], "la colle ne dure qu'un service")


func test_fin_d_un_eleve() -> void:
	var u := Unit.new()
	u.status = Unit.Status.ACTIVE
	u.moral = 10
	assert_eq(Campaign.end_status(u), "a_table")
	u.status = Unit.Status.OUT
	assert_eq(Campaign.end_status(u), "colle", "emmené ou plongé")
	u.moral = 0
	assert_eq(Campaign.end_status(u), "sature")


func test_progression_relue() -> void:
	var c := _year("difficile")
	c.student("Grobill")["xp"] = 9
	c.finish_service("septembre", _results(), true)
	var back := Campaign.from_progress(JSON.parse_string(JSON.stringify(c.progress)))
	assert_true(back != null)
	assert_eq(back.current_service()["id"], "novembre")
	assert_eq(back.student("Grobill")["xp"], c.student("Grobill")["xp"])
	assert_eq(back.difficulty(), "difficile")
	assert_true(Campaign.from_progress({"version": 99}) == null)


func test_bulletin() -> void:
	var c := _year()
	c.finish_service("septembre", _results("a_table", 5, 2), true)
	assert_true(c.appreciation("Grobill") != "")
	var g := c.grade("Grobill")
	assert_true(g >= 2 and g <= 19)
