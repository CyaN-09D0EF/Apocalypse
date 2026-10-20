extends SceneTree
const State = preload("res://scripts/state.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		push_error(text)
		failures += 1
func _initialize() -> void:
	var s = State.new()
	check(s.d.lily_health == 40,"initial health")
	s.new_week()
	check(s.d.lily_health == 38,"daily decline")
	for i in range(40): s.new_week()
	check(s.d.lily_health == 30,"base rations hold health at floor")
	s.reset()
	s.visit("lily")
	s.act("give")
	check(s.d.lily_health == 40 and s.d.lily_food == 1,"gift stored rather than instant healing")
	check(not s.act("give_stock"),"one delivery per day across gift types")
	s.new_week()
	check(s.d.lily_health == 40 and s.d.lily_food == 0,"one meal prevents decline")
	s.new_week()
	check(s.d.lily_health == 38,"decline resumes when stock exhausted")
	s.visit("lily")
	s.d.food = 3
	check(s.act("give_stock") and s.d.food == 0 and s.d.lily_food == 3,"bulk supply consumes three units")
	s.new_week()
	check(s.d.lily_health == 41 and s.d.lily_food == 1,"two meals heal at day end")
	s.new_week()
	check(s.d.lily_health == 41 and s.d.lily_food == 0,"stored food used without visit")
	s.d.lily_health = 99
	s.d.lily_food = 8
	s.new_week()
	check(s.d.lily_health == 100 and s.d.lily_food == 6,"health cap and consumption cap")
	s.d.lily_food = 0
	s.new_week()
	check(s.d.lily_health == 98,"recovered health declines when feeding stops")
	var legacy: Dictionary = s.d.duplicate(true)
	legacy.version = 1
	legacy.erase("lily_food")
	legacy.lily_health = 25
	var f = FileAccess.open("user://test_health_old.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	check(s.load_game("user://test_health_old.json"),"original version save migrates")
	check(s.d.version == 3 and s.d.lily_food == 0 and s.d.lily_health == 30,"legacy upgrade initializes nutrition and health floor")
	s.d.lily_food = 7
	check(s.save_game("user://test_health_new.json","회복 중"),"nutrition save")
	s.reset()
	check(s.load_game("user://test_health_new.json") and s.d.lily_food == 7,"nutrition restored")
	for path in ["user://test_health_old.json","user://test_health_new.json"]: DirAccess.remove_absolute(path)
	print("HEALTH_CHECKS: %d / FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
