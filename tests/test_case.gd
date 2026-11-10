class_name TestCase
extends RefCounted
## Base minimale des tests : chaque méthode `test_*` est exécutée par tests/run_tests.gd.

var failures: Array[String] = []
var _current := ""


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s : attendu vrai. %s" % [_current, msg])


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		failures.append("%s : attendu faux. %s" % [_current, msg])


func assert_eq(actual, expected, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s : obtenu %s, attendu %s. %s" % [_current, var_to_str(actual), var_to_str(expected), msg])


## Petit utilitaire : une partie sur un plan texte, dés imposés ou à graine.
func make_state(rows: Array, forced_dice: Array = [], seed_value: int = 1) -> GameState:
	var dice := DiceRoller.new(seed_value)
	dice.force(forced_dice)
	return GameState.new(Board.from_ascii(rows), GameData.load_default(), dice)
