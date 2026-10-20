extends SceneTree
const State = preload("res://scripts/state.gd")
const SaveMenu = preload("res://scripts/save_menu.gd")
const ONE = "user://test_slot_one.json"
const TWO = "user://test_slot_two.json"
const OLD = "user://test_slot_legacy.json"
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var s = State.new()
	var menu = SaveMenu.new()
	root.add_child(menu)
	menu.open_menu(s,true)
	check(menu.entries.size() >= 6,"six manual slots")
	menu.entries[0] = {"path":ONE,"exists":false,"legacy":false,"info":{"valid":false},"caption":"시험 슬롯"}
	menu.select_slot(0)
	menu.name_field.text = "백합에게 가기 전 · 한글"
	menu.request_action()
	check(not menu.visible and s.inspect_save(ONE).valid,"empty slot saves immediately")
	check(s.inspect_save(ONE).title == "백합에게 가기 전 · 한글","custom Korean title")
	var first: Dictionary = s.d.duplicate(true)
	s.visit("boss")
	s.d.day = 3
	check(s.save_game(TWO,"세 번째 날"),"second slot save")
	check(s.inspect_save(ONE).data == first,"second slot does not replace first")
	check(s.save_game(OLD),"legacy format save")
	check(s.load_game(OLD) and s.d.location == "boss","legacy format load")
	menu.open_menu(s,false)
	var before: Dictionary = s.d.duplicate(true)
	menu.entries[0] = {"path":ONE,"exists":true,"legacy":false,"info":s.inspect_save(ONE),"caption":"시험 슬롯"}
	menu.select_slot(0)
	check(s.d == before,"list selection does not load")
	menu.request_action()
	check(menu.confirm.visible and s.d == before,"loading waits for game confirmation")
	menu.confirm.confirmed.emit()
	menu.confirm.hide()
	check(s.d == first and not menu.visible,"confirmed load restores exact state")
	menu.open_menu(s,true)
	menu.entries[0] = {"path":ONE,"exists":true,"legacy":false,"info":s.inspect_save(ONE),"caption":"시험 슬롯"}
	menu.select_slot(0)
	s.d.money = 777
	menu.request_action()
	check(menu.confirm.visible and s.inspect_save(ONE).data.money != 777,"overwrite waits for game confirmation")
	menu.confirm.hide()
	check(s.inspect_save(ONE).data == first,"cancelled overwrite keeps save")
	menu.request_action()
	menu.confirm.confirmed.emit()
	menu.confirm.hide()
	check(s.inspect_save(ONE).data.money == 777,"confirmed overwrite updates chosen slot")
	check(s.inspect_save(TWO).data.day == 3,"other slot preserved after overwrite")
	var f := FileAccess.open(ONE,FileAccess.WRITE)
	f.store_string('{"format":"ichi_slot_v1","title":"broken","state":{}}')
	f.close()
	before = s.d.duplicate(true)
	check(not s.inspect_save(ONE).valid,"corrupt slot identified")
	check(not s.load_game(ONE) and s.d == before,"corrupt slot cannot replace running state")
	for path in [ONE,TWO,OLD]: DirAccess.remove_absolute(path)
	menu.queue_free()
	await process_frame
	print("SAVE_CHECKS: %d / FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
