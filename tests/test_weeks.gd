extends SceneTree
const State = preload("res://scripts/state.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void:
	var s = State.new()
	check(s.week() == 1 and s.age() == 15 and s.weeks_to_transfer() == 260,"start at 15 with 260 weeks remaining")
	s.visit("warehouse")
	s.act("work")
	check(not s.act("work"),"work limited within week")
	s.return_home()
	s.act("sleep")
	check(s.d.day == 8 and s.week() == 2,"advance exactly seven days")
	check(s.d.lily_health == 38,"health settles once per week, not seven times")
	s.visit("warehouse")
	check(s.act("work"),"work reopens next week")
	s.reset()
	for i in range(52): s.new_week()
	check(s.week() == 53 and s.age() == 16,"52 weekly turns age player by one year")
	for i in range(208): s.new_week()
	check(s.week() == 261 and s.age() == 20 and s.weeks_to_transfer() == 0,"five years take exactly 260 turns")
	var old: Dictionary = s.d.duplicate(true)
	old.version = 2
	old.day = 8
	old.lily_food = 3
	old.daily = {"give":true}
	var f = FileAccess.open("user://test_week_migration.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(s.load_game("user://test_week_migration.json"),"v0.3 saves load")
	check(s.week() == 2 and s.d.lily_food == 3 and s.d.daily.has("give"),"migration preserves elapsed days, supplies and used actions")
	check(s.save_game("user://test_week_roundtrip.json","2주차"),"weekly save")
	s.reset()
	check(s.load_game("user://test_week_roundtrip.json") and s.week() == 2,"week restored from save")
	for path in ["user://test_week_migration.json","user://test_week_roundtrip.json"]: DirAccess.remove_absolute(path)
	print("WEEK_CHECKS: %d / FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
