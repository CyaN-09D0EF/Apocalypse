extends ConfirmationDialog
## Slot list reads metadata without changing the running game.
signal game_loaded
const SLOT_COUNT = 6
const DIRECTORY = "user://saves"
const PLACES = preload("res://scripts/camp_map.gd").NAMES
var state
var saving := false
var entries: Array[Dictionary] = []
var slots: ItemList
var details: Label
var name_field: LineEdit
var name_label: Label
var confirm: ConfirmationDialog
var selected := -1
var pending_path := ""
var pending_title := ""

func _ready() -> void:
	title = "저장 목록"
	size = Vector2i(720,590)
	min_size = Vector2i(660,540)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	add_child(content)
	var hint := Label.new()
	hint.text = "저장 슬롯을 선택하면 진행 상황을 확인할 수 있습니다."
	content.add_child(hint)
	slots = ItemList.new()
	slots.custom_minimum_size = Vector2(620,265)
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("v_separation",12)
	slots.item_selected.connect(select_slot)
	content.add_child(slots)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(620,90)
	content.add_child(details)
	name_label = Label.new()
	name_label.text = "저장 이름"
	content.add_child(name_label)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = "예: 백합에게 가기 전"
	content.add_child(name_field)
	cancel_button_text = "닫기"
	confirmed.connect(request_action)
	get_ok_button().disabled = true
	# Keep list open until the disk operation actually succeeds.
	dialog_hide_on_ok = false
	confirm = ConfirmationDialog.new()
	confirm.cancel_button_text = "취소"
	confirm.confirmed.connect(commit_action)
	add_child(confirm)

func open_menu(game_state, for_save: bool) -> void:
	state = game_state
	saving = for_save
	title = "게임 저장 · 슬롯 선택" if saving else "게임 불러오기 · 저장 목록"
	ok_button_text = "선택한 슬롯에 저장" if saving else "선택한 저장 불러오기"
	name_field.visible = saving
	name_label.visible = saving
	rebuild()
	popup_centered(Vector2i(720,590))

func rebuild() -> void:
	slots.clear()
	entries.clear()
	selected = -1
	get_ok_button().disabled = true
	details.text = "슬롯을 선택하세요. 불러오기는 선택 후 아래 버튼을 눌러 진행합니다."
	for i in range(SLOT_COUNT):
		append_entry("%s/slot_%02d.json" % [DIRECTORY,i+1],"슬롯 %02d" % [i+1],false)
	if FileAccess.file_exists(state.SAVE_PATH):
		append_entry(state.SAVE_PATH,"이전 버전 저장",true)
	if saving:
		for i in range(entries.size()):
			if not entries[i].exists:
				slots.select(i)
				select_slot(i)
				break

func append_entry(path: String, caption: String, legacy: bool) -> void:
	var exists := FileAccess.file_exists(path)
	var info: Dictionary = state.inspect_save(path) if exists else {"valid":false,"title":"빈 슬롯"}
	var item := {"path":path,"exists":exists,"legacy":legacy,"info":info,"caption":caption}
	entries.append(item)
	var text := caption + "  ·  "
	if not exists:
		text += "빈 슬롯"
	elif info.valid:
		var d: Dictionary = info.data
		var week_number := (int(d.day)-1)/7+1
		text += "%s\n%d주차 · %d세 · %s" % [info.title,week_number,15+(week_number-1)/52,PLACES.get(d.location,d.location)]
	else:
		text += "읽을 수 없는 저장"
	slots.add_item(text)
	slots.set_item_disabled(slots.item_count-1,legacy and saving or not saving and not info.valid)

func select_slot(index: int) -> void:
	selected = index
	var e := entries[index]
	get_ok_button().disabled = (e.legacy and saving) or (not saving and not e.info.valid)
	if not e.exists:
		details.text = "빈 슬롯입니다. 현재 진행을 새로 저장할 수 있습니다."
		name_field.text = "%d주차 · %s" % [state.week(),PLACES.get(state.d.location,state.d.location)]
	elif not e.info.valid:
		details.text = "저장 내용을 읽을 수 없습니다. 저장 모드에서는 이 슬롯에 새 진행을 덮어쓸 수 있습니다."
		name_field.text = "%d주차 저장" % state.week()
	else:
		var d: Dictionary = e.info.data
		var date := Time.get_datetime_dict_from_unix_time(int(e.info.modified)+int(Time.get_time_zone_from_system().bias)*60)
		details.text = "저장 시각: %04d-%02d-%02d %02d:%02d (컴퓨터 현지 시각)\n이치 · 기력 %d / 허기 %d · 음식 %d / 돈 %d\n백합 · 신뢰 %d / 건강 %d / 보충식 %d꾸러미" % [date.year,date.month,date.day,date.hour,date.minute,d.energy,d.hunger,d.food,d.money,d.lily_trust,d.lily_health,d.lily_food]
		name_field.text = e.info.title

func request_action() -> void:
	if selected < 0 or get_ok_button().disabled:
		return
	var e := entries[selected]
	pending_path = e.path
	pending_title = name_field.text.strip_edges()
	if pending_title.is_empty(): pending_title = "%d주차 저장" % state.week()
	if saving and e.exists:
		confirm.title = "저장 덮어쓰기"
		confirm.dialog_text = "%s의 기존 저장을 현재 진행으로 바꿀까요?" % e.caption
		confirm.ok_button_text = "덮어쓰기"
		confirm.popup_centered(Vector2i(480,170))
	elif not saving:
		confirm.title = "게임 불러오기"
		confirm.dialog_text = "선택한 저장으로 돌아갈까요?\n현재 저장하지 않은 진행은 사라집니다."
		confirm.ok_button_text = "불러오기"
		confirm.popup_centered(Vector2i(480,170))
	else:
		commit_action()

func commit_action() -> void:
	var ok: bool
	if saving:
		var error := DirAccess.make_dir_recursive_absolute(DIRECTORY)
		if error != OK:
			details.text = "저장 폴더를 만들 수 없습니다. 기존 저장은 유지됩니다."
			return
		ok = state.save_game(pending_path,pending_title)
	else:
		ok = state.load_game(pending_path)
	if ok:
		hide()
		if not saving: game_loaded.emit()
	else:
		details.text = state.message
