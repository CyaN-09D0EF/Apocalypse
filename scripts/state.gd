extends RefCounted
## All simulation rules live here; UI and save files contain no game logic.
signal changed
const SAVE_PATH = "user://apprentice_v1.json"
const PLACES = ["quarters", "warehouse", "training", "workshop", "lily", "yard", "gate", "armory", "water", "clinic", "boss"]
var d: Dictionary
var message := ""

func _init() -> void:
	reset()

func reset() -> void:
	d = {"version":3, "day":1, "minute":480, "location":"quarters", "energy":85, "hunger":20,
		"food":2, "money":4, "combat":1, "craft":1, "social":1,
		"lily_affection":0, "lily_trust":0, "lily_health":40, "lily_food":0, "kar_trust":0,
		"daily":{}, "flags":{}, "pending":false,
		"journal":["1주차 · 견습 이치의 생활이 시작되었다. 창고에서 일거리를 알아보자."]}
	message = "이번 주 자유활동 14시간을 배분하고, 다음 주로 넘어가자. 식량 1꾸러미는 일주일치 보충식이다."
	changed.emit()

func week() -> int:
	return (int(d.day)-1) / 7 + 1

func age() -> int:
	return 15 + (week()-1) / 52

func weeks_to_transfer() -> int:
	return maxi(0,260-(week()-1))

func clock() -> String:
	var left := maxi(0,1320-int(d.minute))
	return "활동 잔여 %d시간 %02d분" % [left/60,left%60]

func record(line: String) -> void:
	d.journal.append("%d주차 · %s · %s" % [week(), clock(), line])
	if d.journal.size() > 120:
		d.journal.pop_front()
	message = line
	changed.emit()

func visit(place: String) -> bool:
	if not place in PLACES or place == d.location:
		return false
	if int(d.minute) + 10 > 1320:
		message = "이번 주 자유활동 시간이 끝났다. 숙소에서 다음 주로 넘어가자."
		changed.emit()
		return false
	d.minute += 10
	d.location = place
	changed.emit()
	return true

func can_act(id: String) -> String:
	var place = {"work":"warehouse", "kar":"warehouse", "delegate":"warehouse", "train":"training",
		"repair":"workshop", "talk":"lily", "give":"lily", "give_stock":"lily", "flower":"lily", "sleep":"quarters"}
	if place.has(id) and d.location != place[id]:
		return "먼저 해당 장소로 이동해야 한다."
	if id == "sleep":
		return ""
	if id == "eat":
		return "음식이 없다." if d.food < 1 else ("지금은 충분히 배부르다." if d.hunger == 0 else "")
	if id in ["give", "give_stock"] and d.food < (3 if id == "give_stock" else 1):
		return "건넬 음식이 없다."
	if id in ["give", "give_stock"] and d.daily.has("give"):
		return "이번 주 식량은 이미 건넸다. 남겨둔 식량은 다음 주에도 먹을 수 있다."
	if id == "flower" and (not d.flags.has("flower_found") or d.flags.has("flower_given")):
		return "작업장에서 작은 흰 꽃을 발견하면 건넬 수 있다."
	if id == "delegate":
		if d.kar_trust < 2:
			return "카르의 신뢰가 2 이상 필요하다."
		if d.pending:
			return "카르가 이미 다음 주에 식량을 구해 주기로 했다."
		if d.money < 2:
			return "구입비 2가 필요하다."
	if id in ["work", "train", "repair", "talk", "kar"] and d.daily.has(id):
		return "이번 주에는 이미 마쳤다. 다음 주에 다시 할 수 있다."
	var costs: Dictionary = cost(id)
	if costs.is_empty():
		return "알 수 없는 행동이다."
	if d.minute + costs.time > 1320:
		return "이번 주에 남은 자유활동 시간이 부족하다."
	if d.energy < costs.energy:
		return "기력이 부족하다. 식사하거나 숙소에서 쉬자."
	return ""

func cost(id: String) -> Dictionary:
	return {"work":{"time":120,"energy":22}, "kar":{"time":30,"energy":3},
		"delegate":{"time":10,"energy":0}, "train":{"time":90,"energy":24},
		"repair":{"time":90,"energy":18}, "talk":{"time":40,"energy":4},
		"give":{"time":15,"energy":0}, "give_stock":{"time":15,"energy":0}, "flower":{"time":15,"energy":0}}.get(id, {})

func act(id: String) -> bool:
	var reason = can_act(id)
	if reason != "":
		message = reason
		changed.emit()
		return false
	if id == "sleep":
		new_week()
		return true
	if id == "eat":
		d.food -= 1
		d.hunger = maxi(0, int(d.hunger) - 45)
		d.energy = mini(100, int(d.energy) + 15)
		record("비축 식량으로 이번 주 식사를 보충했다. 허기가 가라앉고 기력이 조금 돌아왔다.")
		return true
	var c = cost(id)
	d.minute += c.time
	d.energy -= c.energy
	d.hunger = mini(100, int(d.hunger) + maxi(2, int(c.time) / 12))
	d.daily[id] = true
	match id:
		"work":
			d.food += 2
			d.money += 2
			d.kar_trust += 1
			d.flags["worked"] = true
			record("카르와 창고를 정리했다. 음식 2와 품삯 2를 받고, 카르의 신뢰가 1 올랐다.")
		"kar":
			d.social += 1
			d.kar_trust += 1
			record("카르는 약속을 지키는 사람에게 일을 맡긴다고 했다. 교섭 경험과 신뢰가 1 올랐다.")
		"delegate":
			d.money -= 2
			d.pending = true
			record("카르에게 구입비 2를 맡겼다. 다음 주에 식량 3꾸러미를 받아 두기로 약속했다.")
		"train":
			d.combat += 1
			record("훈련장에서 발놀림과 방어를 연습했다. 전투 숙련이 1 올랐다.")
		"repair":
			d.craft += 1
			d.flags["repaired"] = true
			if not d.flags.has("flower_found"):
				d.flags["flower_found"] = true
				record("정비를 돕고 작업 숙련을 쌓았다. 돌아오는 길에 작은 흰 야생화를 발견했다.")
			else:
				record("낡은 수레의 축을 손봤다. 작업 숙련이 1 올랐다.")
		"talk":
			d.lily_affection += 1
			d.lily_trust += 1
			d.flags["met"] = true
			if not d.flags.has("named") and d.lily_trust >= 3:
				d.flags["named"] = true
				record("이치: ‘백합이라고 불러도 돼?’\n그는 한참 바라보다 대꾸했다. ‘마음대로 해. 밖에서 떠들지는 말고.’")
			elif d.flags.has("repaired"):
				record("수레 이야기를 꺼내자 그가 말했다. ‘축만 갈면 또 부러져. 하중이 어디 몰리는지부터 봐.’ 신뢰가 1 올랐다.")
			else:
				record("‘오늘도 온 거냐.’ 날카로운 목소리에 이치는 조금 떨어져 앉아 이번 주 있었던 일을 들려주었다.")
		"give", "give_stock":
			var amount := 3 if id == "give_stock" else 1
			d.food -= amount
			d.lily_food += amount
			d.daily["give"] = true
			d.lily_trust += 1
			d.flags["fed"] = true
			record("보충식 %d꾸러미를 조용히 건넸다. 그는 문 쪽을 살피고 나서 보관했다. 이번 주를 마감할 때 먹는다. 신뢰 +1." % amount)
		"flower":
			d.flags["flower_given"] = true
			d.lily_affection += 2
			record("작은 흰 꽃을 건넸다. ‘먹지도 못하는 걸.’ 그렇게 말하면서도 그는 꽃이 꺾이지 않게 곁에 놓았다.")
	return true

func lily_condition() -> String:
	if d.lily_health <= 30:
		return "기운이 없어 자주 쉬며, 짧은 대화에도 쉽게 지친다."
	if d.lily_health < 50:
		return "몸이 쇠약해 움직임을 아끼지만, 이야기를 들을 여유는 있다."
	if d.lily_health < 75:
		return "안색이 조금 나아졌고, 한결 오래 이야기를 나눈다."
	return "기운이 돌아와 먼저 다가와 말을 건네기도 한다."

func settle_lily_meals() -> String:
	var before: int = d.lily_health
	var eaten := mini(2,int(d.lily_food))
	d.lily_food -= eaten
	if eaten == 0:
		d.lily_health = maxi(30,int(d.lily_health)-2)
	elif eaten == 2:
		d.lily_health = mini(100,int(d.lily_health)+3)
	var change: int = d.lily_health-before
	var result := "백합은 기본 배급만 받았다. 건강 %d → %d. 최소 배급은 건강 30을 유지할 뿐이다." % [before,d.lily_health]
	if eaten == 1:
		result = "백합이 남겨둔 보충식 1꾸러미를 먹어 이번 주의 건강 감소를 막았다. 건강 %d." % d.lily_health
	elif eaten == 2:
		result = "백합이 보충식 2꾸러미를 충분히 먹었다. 건강 %d → %d (+%d)." % [before,d.lily_health,change]
	return result + " 남은 보충식 %d꾸러미." % d.lily_food

func new_week() -> void:
	var meal_report := settle_lily_meals()
	var penalty = 15 if d.hunger >= 80 else 0
	d.day += 7
	d.minute = 480
	d.location = "quarters"
	d.energy = 85 - penalty
	d.hunger = mini(100, int(d.hunger) + 15)
	d.daily = {}
	var note := "일주일이 지나 새로운 주가 시작되었다.\n" + meal_report
	if penalty:
		note += " 먹을 것이 부족했던 주라 회복이 덜 되었다."
	if d.pending:
		d.food += 3
		d.pending = false
		note += " 카르가 약속한 음식 3을 받아 두었다."
	if week() >= 2 and not d.flags.has("week_complete"):
		d.flags["week_complete"] = true
		note += " 첫 일주일이 끝났다. 기록 탭에서 결과를 확인할 수 있다. 계속 생활해도 된다."
	record(note)

func return_home() -> void:
	if d.location == "quarters":
		return
	# Always possible; no night-time soft lock.
	d.minute = mini(1320, int(d.minute) + 10)
	d.location = "quarters"
	record("이번 주 활동을 마무리하러 숙소로 돌아왔다.")

func save_game(path: String = SAVE_PATH, title: String = "") -> bool:
	var tmp = path + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		message = "저장 파일을 만들 수 없다. 기존 저장은 유지된다."
		changed.emit()
		return false
	var payload: Dictionary = d
	if not title.is_empty():
		payload = {"format":"ichi_slot_v1", "title":title, "saved_at":Time.get_unix_time_from_system(), "state":d}
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	var err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		message = "저장을 마무리하지 못했다."
		changed.emit()
		return false
	message = "현재 진행을 저장했다."
	changed.emit()
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		message = "저장된 진행이 없다."
		changed.emit()
		return false
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		message = "저장 파일을 읽을 수 없다."
		changed.emit()
		return false
	f.close()
	var entry := inspect_save(path)
	if not entry.valid:
		message = "지원하지 않거나 손상된 저장이다. 현재 진행은 유지된다."
		changed.emit()
		return false
	var parsed: Dictionary = entry.data

	for k in ["version", "day", "minute", "energy", "hunger", "food", "money", "combat", "craft", "social", "lily_affection", "lily_trust", "lily_health", "lily_food", "kar_trust"]:
		parsed[k] = int(parsed[k])
	d = parsed
	message = "저장한 주의 야영지로 돌아왔다."
	changed.emit()
	return true

func inspect_save(path: String) -> Dictionary:
	var invalid := {"valid":false, "title":"손상되었거나 지원하지 않는 저장", "data":{}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return invalid
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	var title := "이전 버전 저장"
	if parsed is Dictionary and parsed.has("format"):
		if parsed.format != "ichi_slot_v1" or not parsed.get("title") is String:
			return invalid
		title = parsed.title
		parsed = parsed.get("state")
	# Upgrade old saves without losing the rest of the player's progress.
	if parsed is Dictionary and parsed.get("version") == 1:
		parsed = parsed.duplicate(true)
		parsed["version"] = 2
		parsed["lily_food"] = 0
		if parsed.get("lily_health") is float or parsed.get("lily_health") is int:
			parsed["lily_health"] = maxf(30,parsed.lily_health)
	if parsed is Dictionary and parsed.get("version") == 2:
		parsed = parsed.duplicate(true)
		parsed["version"] = 3

	if not valid_save(parsed):
		return invalid
	for key in ["version", "day", "minute", "energy", "hunger", "food", "money", "combat", "craft", "social", "lily_affection", "lily_trust", "lily_health", "lily_food", "kar_trust"]:
		parsed[key] = int(parsed[key])
	return {"valid":true,"title":title,"data":parsed,"modified":FileAccess.get_modified_time(path)}

func valid_save(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for k in d.keys():
		if not v.has(k) or typeof(v[k]) != typeof(d[k]) and not (v[k] is float and d[k] is int):
			return false
	if v.version != 3 or not v.location in PLACES:
		return false
	for k in ["day", "minute", "energy", "hunger", "food", "money", "combat", "craft", "social", "lily_affection", "lily_trust", "lily_health", "lily_food", "kar_trust"]:
		if v[k] < 0 or v[k] != floor(v[k]) or v[k] > 1000000:
			return false
	if v.day < 1 or v.minute < 480 or v.minute > 1320:
		return false
	if v.energy > 100 or v.hunger > 100 or v.lily_health > 100:
		return false
	for x in v.journal:
		if not x is String:
			return false
	return true
