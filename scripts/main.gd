extends Control
const State = preload("res://scripts/state.gd")
const SaveMenu = preload("res://scripts/save_menu.gd")
const CampMap = preload("res://scripts/camp_map.gd")
const BG = Color("182b29")
const PANEL = Color("233733")
const TEXT = Color("eee7d5")
const MUTED = Color("a9b9a8")
const GOLD = Color("d6b67c")
var state = State.new()
var map: Control
var status: Label
var day_label: Label
var state_label: Label
var place_label: Label
var place_desc: Label
var action_box: VBoxContainer
var log_label: RichTextLabel
var notice: Label
var relation: Label
var tab_content: RichTextLabel
var bottom_tabs: TabContainer
var save_menu: ConfirmationDialog
var sleep_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var title_label: Label
var action_buttons: Array[Button] = []
const NAMES = CampMap.NAMES
const DESCS = {"quarters":"공동 숙소의 철판 지붕이 바람에 덜컹인다. 옆 취사장에서는 큰 솥에 배급 음식을 끓인다. 이곳에서 이번 주를 마무리한다.",
	"warehouse":"약탈과 거래로 들어온 식량이 쌓인 창고. 카르가 배급과 재고를 기록한다. 공동 물자는 허가 없이 가져갈 수 없다.",
	"training":"폐타이어를 넘는 발소리와 표적을 때리는 소리가 이어진다. 무리의 견습들이 싸움과 생존에 필요한 기술을 익힌다.",
	"workshop":"차고 앞에 고장 난 차량들이 늘어서 있다. 기름 냄새 속에서 공구가 부딪힌다. 차량정비를 도우며 손기술을 배울 수 있다.",
	"lily":"보스 관리동 옆의 작은 거처. 길목에는 감시가 붙어 있다. 잠깐 찾아온 이치를 흰 머리의 소년이 바라본다.",
	"yard":"차량이 모이고 전리품을 내리는 중앙 공터. 짐을 내리는 대원과 다음 출발을 준비하는 사람들이 뒤섞인다.",
	"gate":"철판으로 덧댄 정문 옆에 망루가 서 있다. 경계 대원들은 방문객과 출입 차량을 확인한다. 외부 지역은 아직 이동할 수 없다.",
	"armory":"문에 굵은 자물쇠가 채워져 있다. 탄약과 장비는 담당자의 허가를 받아야 지급된다. 지금은 바깥에서 둘러볼 수 있다.",
	"water":"낡은 물탱크에서 공동 세면대로 호스가 이어진다. 물통을 든 사람들이 차례를 기다린다. 물은 무리 전체가 나눠 쓰는 자원이다.",
	"clinic":"소독약 냄새가 옅게 남은 작은 의무실. 깨끗한 붕대와 약품이 부족하다. 치료 기능은 후속 단계에서 추가한다.",
	"boss":"옛 관리동의 온전한 방을 보스와 측근들이 차지했다. 견습은 호출 없이 안으로 들어갈 수 없다. 현재는 건물 앞까지 이동한다."}

func _ready() -> void:
	var t := Theme.new()
	t.default_font = load("res://assets/NotoSansKR.ttf")
	t.default_font_size = 17
	t.set_color("font_color","Label",TEXT)
	t.set_color("default_color","RichTextLabel",TEXT)
	t.set_color("font_color","Button",TEXT)
	t.set_color("font_disabled_color","Button",Color("8a9385"))
	for typ in ["normal","hover","pressed","disabled"]:
		var col = Color("354b42")
		if typ == "hover": col = Color("476452")
		if typ == "pressed": col = Color("61775a")
		if typ == "disabled": col = Color("293a34")
		var sty = style(col,7)
		sty.content_margin_left = 12
		sty.content_margin_right = 12
		sty.content_margin_top = 9
		sty.content_margin_bottom = 9
		t.set_stylebox(typ,"Button",sty)
	t.set_stylebox("panel","TabContainer",style(PANEL,9))
	t.set_stylebox("tab_selected","TabContainer",style(Color("3b5144"),5,9))
	t.set_stylebox("tab_unselected","TabContainer",style(BG,5,9))
	t.set_color("font_selected_color","TabContainer",GOLD)
	t.set_color("font_unselected_color","TabContainer",MUTED)
	theme = t
	var background = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation",14)
	margin.add_child(root)
	var header = HBoxContainer.new()
	root.add_child(header)
	var heading = VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(label("W A S T E L A N D   /   P R O T O T Y P E   0 . 4",12,GOLD))
	title_label = label("황무지의 백합",30,TEXT)
	heading.add_child(title_label)
	heading.add_child(label("견습의 생활  ·  일주일 단위 진행",15,MUTED))
	var meta = VBoxContainer.new()
	header.add_child(meta)
	day_label = label("",21,GOLD)
	meta.add_child(day_label)
	meta.add_child(label("주간 자유활동 14시간 · 선택 중에는 정지",14,MUTED))
	var save_row = HBoxContainer.new()
	header.add_child(save_row)
	save_row.add_child(button("저장",func(): map.jump_to(state.d.location); save_menu.open_menu(state,true)))
	save_row.add_child(button("불러오기",func(): map.jump_to(state.d.location); save_menu.open_menu(state,false)))
	save_row.add_child(button("새 시작",func(): reset_dialog.popup_centered(Vector2i(480,180))))
	status = label("",17,TEXT)
	var strip = panel(Color("30453b"),12)
	strip.add_child(status)
	root.add_child(strip)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	root.add_child(body)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",12)
	body.add_child(left)
	map = CampMap.new()
	map.custom_minimum_size = Vector2(0,390)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.destination_selected.connect(on_arrive)
	left.add_child(map)
	bottom_tabs = TabContainer.new()
	bottom_tabs.custom_minimum_size.y = 135
	left.add_child(bottom_tabs)
	for tab_name in ["기록", "인물", "소지품", "목표 · 안내"]:
		var text = RichTextLabel.new()
		text.name = tab_name
		text.bbcode_enabled = true
		text.add_theme_constant_override("normal_font_size",15)
		text.add_theme_stylebox_override("normal",style(PANEL,8,14))
		bottom_tabs.add_child(text)
	var right = VBoxContainer.new()
	right.custom_minimum_size.x = 368
	right.add_theme_constant_override("separation",12)
	body.add_child(right)
	var detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation",12)
	var detail_panel = panel(PANEL,18)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	detail_panel.add_child(detail_scroll)
	right.add_child(detail_panel)
	detail.add_child(label("CURRENT LOCATION",12,GOLD))
	place_label = label("",25,TEXT)
	detail.add_child(place_label)
	place_desc = label("",16,MUTED)
	place_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_desc.custom_minimum_size.y = 74
	detail.add_child(place_desc)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation",9)
	detail.add_child(action_box)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	relation = label("",15,MUTED)
	relation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(relation)
	var personal = VBoxContainer.new()
	personal.add_theme_constant_override("separation",8)
	var personal_panel = panel(Color("2c4036"),14)
	personal_panel.add_child(personal)
	right.add_child(personal_panel)
	state_label = label("",16,TEXT)
	personal.add_child(state_label)
	personal.add_child(button("식사 보충  ·  식량 1 / 기력 +15",func(): state.act("eat")))
	personal.add_child(button("숙소로 귀환  ·  10분",func(): state.return_home(); map.jump_to(state.d.location)))
	notice = label("",17,TEXT)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 59
	var notice_panel = panel(Color("30443a"),14)
	notice_panel.add_child(notice)
	root.add_child(notice_panel)
	sleep_dialog = ConfirmationDialog.new()
	sleep_dialog.title = "이번 주 마무리"
	sleep_dialog.dialog_text = "남은 자유활동 시간을 마감하고 일주일을 넘길까요?\n백합의 식사·건강, 식량 구입과 기력 회복을 한 번 정산합니다."
	sleep_dialog.ok_button_text = "다음 주로"
	sleep_dialog.cancel_button_text = "돌아가기"
	sleep_dialog.confirmed.connect(func(): state.act("sleep"))
	add_child(sleep_dialog)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "새로운 일주일"
	reset_dialog.dialog_text = "현재 화면의 진행을 초기화합니다. 직접 저장한 파일은 유지됩니다."
	reset_dialog.ok_button_text = "새로 시작"
	reset_dialog.cancel_button_text = "취소"
	reset_dialog.confirmed.connect(func(): state.reset(); map.jump_to("quarters"))
	add_child(reset_dialog)
	save_menu = SaveMenu.new()
	add_child(save_menu)
	save_menu.game_loaded.connect(func(): map.jump_to(state.d.location))
	state.changed.connect(refresh)
	refresh()
	if "--smoke-ui" in OS.get_cmdline_user_args():
		call_deferred("smoke_ui")

func label(text: String, font_size: int, color: Color) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

func style(color: Color, radius: int, padding: int = 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func panel(color: Color, padding: int) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(color,10,padding))
	return p

func button(text: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func on_arrive(id: String) -> void:
	if not state.visit(id):
		map.jump_to(state.d.location)

func action(id: String, caption: String) -> void:
	var b = button(caption,func(): state.act(id))
	var reason = state.can_act(id)
	b.disabled = reason != ""
	b.tooltip_text = reason if reason != "" else "선택하면 표시된 시간과 물자가 소모됩니다."
	action_box.add_child(b)
	action_buttons.append(b)
	if reason != "":
		var hint = label(reason,12,MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_box.add_child(hint)

func refresh() -> void:
	var d = state.d
	day_label.text = "%d주차 · %d세  /  %s" % [state.week(),state.age(),state.clock()]
	status.text = "이치 %d세  ·  견습     |     기력 %d / 100     포만감 %d / 100     |     식량 %d꾸러미     돈 %d" % [state.age(),d.energy,100-d.hunger,d.food,d.money]
	state_label.text = "전투 %d    작업 %d    교섭 %d" % [d.combat,d.craft,d.social]
	var lily_name: String = "백합" if d.flags.has("named") else "흰 머리의 소년"
	place_label.text = lily_name+"의 거처" if d.location == "lily" else NAMES[d.location]
	place_desc.text = DESCS[d.location] + ("\n\n" + state.lily_condition() if d.location == "lily" else "")
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	action_buttons.clear()
	match d.location:
		"quarters":
			var b = button("이번 주 마무리  ·  다음 주 시작",func(): sleep_dialog.popup_centered(Vector2i(520,180)))
			action_box.add_child(b)
		"warehouse":
			action("work","창고 일 돕기  ·  2시간 / 기력 -22")
			action("kar","카르와 이야기  ·  30분 / 기력 -3")
			action("delegate","식량 구입 부탁  ·  10분 / 돈 -2")
		"training": action("train","방어 훈련  ·  90분 / 기력 -24")
		"workshop": action("repair","정비 보조  ·  90분 / 기력 -18")
		"lily":
			action("talk","이번 주 이야기 들려주기  ·  40분")
			action("give","보충식 1꾸러미 건네기  ·  15분 / 감소 방지")
			action("give_stock","보충식 3꾸러미 맡기기  ·  15분 / 회복·비축")
			action("flower","작은 흰 꽃 건네기  ·  15분")
		_:
			var observation = label("이 장소는 지도와 현장 설명까지 구현되어 있어. 전용 작업·경계·치료·출입 허가 기능은 이후에 추가할 예정이야.",15,MUTED)
			observation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action_box.add_child(observation)

	relation.text = "%s\n친밀 %d  ·  신뢰 %d  ·  건강 %d\n보충식 %d꾸러미 · 매주 최대 2꾸러미 섭취\n\n카르와의 신뢰  %d\n스무 살까지 %d주 · 이송 사건 미구현*" % [lily_name,d.lily_affection,d.lily_trust,d.lily_health,d.lily_food,d.kar_trust,state.weeks_to_transfer()]
	notice.text = state.message
	var records = PackedStringArray()
	for i in range(d.journal.size()-1,maxi(-1,d.journal.size()-12),-1):
		records.append(d.journal[i])
	var summary = ""
	if d.flags.has("week_complete"):
		summary = "[color=#d6b67c]첫 일주일 완료[/color] · 전투 %d / 작업 %d / 교섭 %d · %s 신뢰 %d\n계속 생활하거나 새 시작으로 다른 선택을 시험할 수 있습니다.\n\n" % [d.combat,d.craft,d.social,lily_name,d.lily_trust]
	(bottom_tabs.get_child(0) as RichTextLabel).text = summary+"\n\n".join(records)
	(bottom_tabs.get_child(1) as RichTextLabel).text = "[color=#d6b67c]%s[/color]  /  %d세 · 남성\n능력을 잃고 보스에게 붙잡혀 있다. 대화와 음식 전달로 관계를 쌓을 수 있다.\n친밀 %d · 신뢰 %d · 건강 %d\n\n[color=#d6b67c]카르[/color]  /  무리의 고참\n물자와 장부를 맡고 있다. 함께 일하고 약속을 지키는 경험을 중시한다. 신뢰 %d." % [lily_name,state.age(),d.lily_affection,d.lily_trust,d.lily_health,d.kar_trust]
	(bottom_tabs.get_child(2) as RichTextLabel).text = "[color=#d6b67c]개인 소지품[/color]\n음식 %d개 · 돈 %d\n흰 야생화: %s\n\n식사: 음식 1 → 허기 -45 / 기력 +15\n식량 1꾸러미 = 일주일치 보충식\n전달: 매주 한 번, 1 또는 3꾸러미 → 보관 / 신뢰 +1\n주간 정산: 보충식이 없으면 건강 -2 (하한 30),\n1꾸러미면 유지, 2꾸러미면 건강 +3 (상한 100)\n카르에게 부탁한 식량: %s" % [d.food,d.money,"전달함" if d.flags.has("flower_given") else ("보관 중" if d.flags.has("flower_found") else "없음"),"다음 주 도착" if d.pending else "없음"]
	var objectives = ""
	for pair in [["worked","창고에서 첫 품삯 받기"],["met","소년에게 이번 주 이야기 들려주기"],["fed","음식 나누기"],["flower_given","작은 흰 꽃 선물하기"],["named","백합이라는 이름으로 부르기"]]:
		objectives += ("● " if d.flags.has(pair[0]) else "○ ")+pair[1]+"\n"
	(bottom_tabs.get_child(3) as RichTextLabel).text = "[color=#d6b67c]이번 시험판의 작은 목표[/color]\n"+objectives+"\n지도에서 장소를 클릭해 이동하세요. 숙소에서 일주일을 넘깁니다. 52주를 1년으로 계산합니다.\n* 스무 살의 이송은 후속 개발용 설정이며 나이는 주차에 따라 변하지만 이송·보스 운영은 아직 구현되어 있지 않습니다. 수치와 주간 제한은 시험용입니다."

func smoke_ui() -> void:
	for place in State.PLACES:
		if place != state.d.location:
			var click = InputEventMouseButton.new()
			click.pressed = true
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = map.map_offset() + map.POINTS[place] * map.map_scale()
			map._gui_input(click)
			if not map.busy:
				push_error("Map click did not start travel: " + place)
				get_tree().quit(1)
				return
			map._process(10.0)
			if state.d.location != place or map.busy:
				push_error("Map arrival did not update state: " + place)
				get_tree().quit(1)
				return
		await get_tree().process_frame
		if place == "warehouse":
			action_buttons[0].pressed.emit()
			if state.d.food != 4:
				push_error("UI work button did not apply reward")
				get_tree().quit(1)
				return
			await get_tree().process_frame

	state.reset()
	map.jump_to("quarters")
	await get_tree().process_frame
	if "--capture-saves" in OS.get_cmdline_user_args():
		save_menu.open_menu(state,true)
		await get_tree().process_frame
		await get_tree().process_frame
	for n in ["--capture"]:
		if n in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/ichi-screen.png")
	print("LAYOUT: viewport=",size," notice_bottom=",notice.get_global_rect().end.y," map=",map.size)
	if notice.get_global_rect().end.y > size.y:
		push_error("Layout overflow")
		get_tree().quit(1)
		return
	print("UI_SMOKE_OK / 11 map destinations, click travel and actions")
	get_tree().quit()
