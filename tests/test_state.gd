extends SceneTree
const State = preload("res://scripts/state.gd")
var checks := 0
var failures := 0

func check(ok: bool, desc: String) -> void:
	checks += 1
	if not ok:
		push_error("FAIL: " + desc)
		failures += 1

func _initialize() -> void:
	var s = State.new()
	check(not s.act("work"),"work requires warehouse")
	s.visit("warehouse")
	check(s.act("work"),"first work succeeds")
	check(s.d.food == 4 and s.d.money == 6 and s.d.kar_trust == 1,"work rewards")
	check(not s.act("work"),"daily work limit")
	check(s.act("kar") and s.act("delegate"),"trust enables delegation")
	check(s.d.pending and s.d.money == 4,"delegation reserves money")
	check(not s.act("delegate"),"no duplicate order")
	s.visit("lily")
	check(s.act("talk") and s.act("give"),"visit and gift")
	check(not s.act("give"),"no repeated food farming")
	check(s.d.lily_health == 40 and s.d.lily_food == 1 and s.d.food == 3,"gift consumes food")
	s.return_home()
	s.act("sleep")
	check(s.d.day == 8 and s.d.minute == 480,"day rolls over")
	check(s.d.food == 6 and not s.d.pending,"delivery arrives")
	s.visit("workshop")
	s.act("repair")
	s.visit("lily")
	s.act("talk")
	check(s.d.flags.has("named"),"name event gated by trust")
	check(s.act("flower") and not s.act("flower"),"flower is unique")
	var before = s.d.duplicate(true)
	check(s.save_game("user://test_save.json"),"save")
	s.reset()
	check(s.load_game("user://test_save.json"),"load")
	check(s.d == before,"save round trip")
	var f = FileAccess.open("user://test_invalid.json",FileAccess.WRITE)
	f.store_string('{"version":1,"day":-1}')
	f.close()
	check(not s.load_game("user://test_invalid.json") and s.d == before,"bad save does not mutate current game")
	s.d.minute = 1320
	check(not s.visit("warehouse"),"late travel blocked")
	s.return_home()
	check(s.d.location == "quarters" and s.act("sleep"),"always can return and sleep")
	s.d.food = 0
	check(not s.act("eat"),"food cannot become negative")
	s.d.hunger = 100
	s.act("sleep")
	check(s.d.energy == 70,"hunger affects overnight recovery")
	while s.d.day < 8:
		s.act("sleep")
	check(s.d.flags.has("week_complete"),"week summary")
	DirAccess.remove_absolute("user://test_save.json")
	DirAccess.remove_absolute("user://test_invalid.json")
	print("CHECKS: %d / FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
