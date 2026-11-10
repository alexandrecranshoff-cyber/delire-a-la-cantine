extends SceneTree
## Lance tous les tests : godot --headless --path . -s tests/run_tests.gd

func _init() -> void:
	var total := 0
	var failed: Array[String] = []
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t._current = f.get_basename() + "." + mname
			t.call(mname)
			total += 1
			if t.failures.is_empty():
				print("  ok   ", t._current)
			else:
				for msg in t.failures:
					print("  ÉCHEC ", msg)
				failed.append(t._current)
	print("\n%d tests, %d échec(s)" % [total, failed.size()])
	quit(1 if not failed.is_empty() else 0)
