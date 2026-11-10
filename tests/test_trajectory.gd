extends TestCase


func test_distance_comptee_comme_un_deplacement() -> void:
	assert_eq(Board.distance(Vector2i(0, 6), Vector2i(8, 3)), 8)


func test_figure_2_diagonale_puis_tout_droit() -> void:
	# Figure 2 du livret : T en bas à gauche, C trois rangées plus haut et huit colonnes à droite.
	var got := Trajectory.cells(Vector2i(0, 6), Vector2i(8, 3))
	var expected: Array[Vector2i] = [
		Vector2i(1, 5), Vector2i(2, 4), Vector2i(3, 3),
		Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
	]
	assert_eq(got, expected)


func test_tir_aligne_en_ligne_directe() -> void:
	var got := Trajectory.cells(Vector2i(0, 0), Vector2i(3, 3))
	assert_eq(got, [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)] as Array[Vector2i])


func test_un_mur_arrete_le_tir() -> void:
	var b := Board.from_ascii([
		".....",
		"..#..",
		".....",
	])
	assert_true(Trajectory.blocked_by_wall(b, Vector2i(0, 1), Vector2i(4, 1)))
	assert_false(Trajectory.blocked_by_wall(b, Vector2i(0, 0), Vector2i(4, 0)))


func test_figure_1_ordre_tir_rate_orthogonal() -> void:
	# Tir vers le haut : a juste avant la cible, b derrière a, puis 1 à 6 autour de a.
	var got := Trajectory.miss_candidates(Vector2i(5, 8), Vector2i(5, 0))
	var expected: Array[Vector2i] = [
		Vector2i(5, 1),                   # a
		Vector2i(5, 2),                   # b
		Vector2i(4, 2), Vector2i(6, 2),   # 1, 2
		Vector2i(4, 1), Vector2i(6, 1),   # 3, 4
		Vector2i(4, 0), Vector2i(6, 0),   # 5, 6
	]
	assert_eq(got, expected)


func test_figure_1_ordre_tir_rate_diagonal() -> void:
	var got := Trajectory.miss_candidates(Vector2i(8, 8), Vector2i(2, 2))
	var expected: Array[Vector2i] = [
		Vector2i(3, 3), Vector2i(4, 4),   # a, b
		Vector2i(3, 4), Vector2i(4, 3),   # 1, 2
		Vector2i(2, 4), Vector2i(4, 2),   # 3, 4
		Vector2i(2, 3), Vector2i(3, 2),   # 5, 6
	]
	assert_eq(got, expected)
