extends TestCase
## Ligne de vue : seuls les murs cachent.

const ROOMS := [
	"#########",
	"#...#...#",
	"#...#...#",
	"#.......#",
	"#########",
]


func test_un_mur_cache() -> void:
	var s := make_state(ROOMS)
	s.add_student("Ledur", 0, Vector2i(1, 1))
	assert_false(Visibility.can_see(s, 0, Vector2i(7, 1)), "derrière le mur")
	assert_true(Visibility.can_see(s, 0, Vector2i(3, 2)))


func test_la_bande_voit_par_tous_ses_eleves() -> void:
	var s := make_state(ROOMS)
	s.add_student("Ledur", 0, Vector2i(1, 1))
	var enemy := s.add_student("Grobill", 1, Vector2i(7, 1))
	assert_false(Visibility.unit_visible(s, 0, enemy))
	s.add_student("Bigleux", 0, Vector2i(6, 2))
	assert_true(Visibility.unit_visible(s, 0, enemy))
	assert_true(Visibility.hidden_cells(s, 0).is_empty() or not Visibility.hidden_cells(s, 0).has(Vector2i(7, 1)))


func test_ses_propres_pions_sont_toujours_visibles() -> void:
	var s := make_state(ROOMS)
	var a := s.add_student("Ledur", 0, Vector2i(1, 1))
	assert_true(Visibility.unit_visible(s, 0, a))
	assert_true(Visibility.hidden_cells(s, 0).has(Vector2i(7, 1)))
