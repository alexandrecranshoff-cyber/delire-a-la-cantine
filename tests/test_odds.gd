extends TestCase
## Probabilités des jets (pour l'IA), vérifiées sur l'exemple du livret.


func test_repartition_de_deux_des() -> void:
	var o := Odds.new(GameData.load_default())
	var d := o.sum_distribution(2)
	assert_true(absf(d[7] - 6.0 / 36.0) < 0.0001)
	assert_true(absf(d[2] - 1.0 / 36.0) < 0.0001)


func test_exemple_du_livret_grobill_a_9_cases() -> void:
	# Tripes (2D6 = 8) : CX 3, seuil 9 + 3 = 12. Dextérité 3D : 81 chances sur 216 d'atteindre 12.
	var data := GameData.load_default()
	var o := Odds.new(data)
	var tripes: Dictionary = data.projectile("8")
	assert_eq(int(tripes["cx"]), 3)
	assert_true(absf(o.chance_at_least(3, 0, 9 + int(tripes["cx"])) - 81.0 / 216.0) < 0.0001)
	assert_true(absf(Odds.mean_damage(tripes["degats"]) - 14.0) < 0.0001, "4D : 14 en moyenne")


func test_plus_loin_c_est_moins_bon() -> void:
	var o := Odds.new(GameData.load_default())
	assert_true(o.hit_chance(2, 0, 2) > o.hit_chance(2, 0, 8))
	assert_true(o.expected_damage(4, 0, 5) > o.expected_damage(1, 1, 5), "Dudugenoux vise mieux que Bigleux")
