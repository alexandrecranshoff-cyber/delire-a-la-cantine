extends TestCase


func test_meme_graine_meme_suite() -> void:
	var a := DiceRoller.new(42)
	var b := DiceRoller.new(42)
	for i in 20:
		assert_eq(a.d6(), b.d6())


func test_faces_entre_1_et_6() -> void:
	var d := DiceRoller.new(7)
	for i in 500:
		var f := d.d6()
		assert_true(f >= 1 and f <= 6, str(f))


func test_des_imposes_et_bonus() -> void:
	var d := DiceRoller.new()
	d.force([6, 2])
	var r := d.roll(2, 3, "dexterite")
	assert_eq(r["total"], 11)
	assert_eq(d.history.size(), 1)


func test_demi_de() -> void:
	# 1-2 = 1, 3-4 = 2, 5-6 = 3 (renvoi du tableau 2).
	var d := DiceRoller.new()
	d.force([1, 2, 3, 4, 5, 6])
	var got: Array[int] = []
	for i in 6:
		got.append(d.roll_damage({"demi": 1})["total"])
	assert_eq(got, [1, 1, 2, 2, 3, 3] as Array[int])


func test_degats_fixes() -> void:
	assert_eq(DiceRoller.new().roll_damage({"fixe": 1})["total"], 1)
