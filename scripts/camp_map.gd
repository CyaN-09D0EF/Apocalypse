extends Control
## Scalable code-native map; no external artwork or generated bitmap required.
signal destination_selected(id: String)
const WORLD = Vector2(1000, 600)
const POINTS = {
	"quarters": Vector2(180,470), "warehouse": Vector2(178,225),
	"training": Vector2(465,225), "workshop": Vector2(770,460),
	"lily": Vector2(835,225), "yard": Vector2(480,340),
	"gate": Vector2(490,535), "armory": Vector2(650,225),
	"water": Vector2(175,340), "clinic": Vector2(335,470),
	"boss": Vector2(830,125)}
const NAMES = {"quarters":"공동 숙소 · 취사장", "warehouse":"식량창고 · 배급소",
	"training":"훈련장", "workshop":"차량정비소", "lily":"안쪽 거처",
	"yard":"중앙 공터", "gate":"정문 · 망루", "armory":"무기고",
	"water":"급수장", "clinic":"의무실", "boss":"보스 관리동"}
# Each door joins the same open road. The boss and Lily share a guarded spur.
const JOIN = {"quarters":Vector2(280,340), "warehouse":Vector2(178,340),
	"training":Vector2(465,340), "workshop":Vector2(890,340),
	"lily":Vector2(920,340), "yard":Vector2(480,340),
	"gate":Vector2(490,340), "armory":Vector2(650,340),
	"water":Vector2(175,340), "clinic":Vector2(390,340), "boss":Vector2(920,340)}
var current := "quarters"
var player: Vector2 = POINTS.quarters
var selected := "quarters"
var busy := false
var font: Font
var hovered := ""
var route: Array[Vector2] = []
var walk_phase := 0.0

func _ready() -> void:
	font = load("res://assets/NotoSansKR.ttf")
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): hovered = ""; queue_redraw())

func map_scale() -> float:
	return minf(size.x / WORLD.x, size.y / WORLD.y)

func map_offset() -> Vector2:
	return (size - WORLD * map_scale()) / 2

func to_world(p: Vector2) -> Vector2:
	return (p - map_offset()) / maxf(map_scale(), 0.001)

func _process(delta: float) -> void:
	if not busy:
		return
	walk_phase += delta * 11
	var budget := delta * 490.0
	while not route.is_empty() and budget > 0:
		var distance := player.distance_to(route[0])
		if distance <= budget:
			player = route.pop_front()
			budget -= distance
		else:
			player = player.move_toward(route[0], budget)
			budget = 0
	if route.is_empty():
		busy = false
		current = selected
		destination_selected.emit(current)
	queue_redraw()

func jump_to(id: String) -> void:
	if not POINTS.has(id):
		return
	current = id
	selected = id
	player = POINTS[id]
	route.clear()
	busy = false
	queue_redraw()

func door_path(id: String) -> Array[Vector2]:
	var path: Array[Vector2] = [POINTS[id]]
	if id in ["quarters", "clinic", "workshop"]:
		var side_x: float = JOIN[id].x
		path.append(Vector2(side_x,POINTS[id].y))
		path.append(Vector2(side_x,365))
	elif id == "boss":
		path.append(Vector2(920,125))
	elif id == "lily":
		path.append(Vector2(920,225))
	path.append(JOIN[id])
	return path

func go(id: String) -> void:
	if busy or id == current or not POINTS.has(id):
		return
	selected = id
	route = door_path(current)
	var arriving := door_path(id)
	arriving.reverse()
	route.append_array(arriving)
	busy = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = hit(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered != "" else Control.CURSOR_ARROW
		tooltip_text = NAMES.get(hovered, "") + (" · 클릭하여 이동" if hovered != "" else "")
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := hit(event.position)
		if id != "":
			go(id)

func place_rect(id: String) -> Rect2:
	var p: Vector2 = POINTS[id]
	match id:
		"warehouse": return Rect2(80,125,195,118)
		"training": return Rect2(365,120,195,128)
		"workshop": return Rect2(645,391,230,99)
		"quarters": return Rect2(78,398,210,100)
		"boss": return Rect2(740,60,172,84)
		"lily": return Rect2(785,163,103,84)
		"armory": return Rect2(592,145,115,100)
		"clinic": return Rect2(299,407,75,85)
		"gate": return Rect2(413,506,155,57)
		"water": return Rect2(87,280,190,94)
	return Rect2(p-Vector2(66,35),Vector2(132,65))

func hit(at: Vector2) -> String:
	var p := to_world(at)
	for id in POINTS:
		if place_rect(id).grow(4).has_point(p) or label_rect(id).has_point(p):
			return id
	return ""

func label_rect(id: String) -> Rect2:
	var p: Vector2 = POINTS[id]
	var width := font.get_string_size(NAMES[id],HORIZONTAL_ALIGNMENT_LEFT,-1,18).x + 22 if font != null else 130.0
	var y := p.y + 21
	if id == "water": y = 368
	if id == "yard": y = 352
	if id == "gate": y = 555
	return Rect2(Vector2(p.x-width/2,y),Vector2(width,29))

func rect(at: Vector2, dimensions: Vector2, color: String) -> void:
	draw_rect(Rect2(at,dimensions),Color(color))

func line(a: Vector2, b: Vector2, color: String, width: float = 2) -> void:
	draw_line(a,b,Color(color),width,true)

func words(at: Vector2, text: String, color: String = "e7dcc4", pixels: int = 17) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(color))

func roof(r: Rect2, color: String) -> void:
	draw_rect(Rect2(r.position+Vector2(7,8),r.size),Color(0.08,0.08,0.05,0.25))
	draw_rect(r,Color(color))
	draw_rect(r,Color("3d3e34"),false,2)
	for x in range(int(r.position.x)+9,int(r.end.x),12):
		line(Vector2(x,r.position.y+3),Vector2(x,r.end.y-3),"ffffff18",1)
	line(Vector2(r.position.x,r.position.y+r.size.y/2),Vector2(r.end.x,r.position.y+r.size.y/2),"454a40",3)

func crate(p: Vector2) -> void:
	rect(p,Vector2(20,17),"68513a")
	draw_rect(Rect2(p,Vector2(20,17)),Color("b09161"),false,2)
	line(p,p+Vector2(20,17),"a08256",1)

func barrel(p: Vector2, color: String = "796a4b") -> void:
	draw_circle(p+Vector2(2,3),10,Color("554c3a"))
	draw_circle(p,9,Color(color))
	draw_arc(p,6,0,TAU,16,Color("3d463e"),2,true)

func vehicle(p: Vector2, color: String, truck: bool = false) -> void:
	var length := 74.0 if truck else 52.0
	for dx in [-3,25]:
		for dy in [8,length-18]:
			rect(p+Vector2(dx,dy),Vector2(9,14),"262b28")
	rect(p+Vector2(0,3),Vector2(32,length),"3b3930")
	rect(p,Vector2(32,length),color)
	rect(p+Vector2(4,9),Vector2(24,13),"344c4c")
	rect(p+Vector2(4,25),Vector2(24,length-30),"4d5042" if truck else color)
	line(p+Vector2(3,3),p+Vector2(29,3),"c4b58a",2)

func figure(p: Vector2, color: String) -> void:
	draw_circle(p+Vector2(2,5),7,Color(0,0,0,0.22))
	draw_circle(p,6,Color(color))
	draw_circle(p+Vector2(0,-5),4,Color("c29c74"))

func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color("252d2a"))
	draw_set_transform(map_offset(),0,Vector2.ONE*map_scale())
	rect(Vector2.ZERO,WORLD,"aa9674")
	var rng := RandomNumberGenerator.new()
	rng.seed = 924
	for i in range(900):
		var p := Vector2(rng.randf_range(8,992),rng.randf_range(40,590))
		draw_circle(p,rng.randf_range(0.6,2.0),Color(0.24,0.24,0.18,0.15))
	# Weathered concrete pads and broad service lanes.
	rect(Vector2(60,55),Vector2(665,215),"9e947b")
	rect(Vector2(55,390),Vector2(840,110),"9c927b")
	line(Vector2(59,340),Vector2(944,340),"c2b18e",44)
	line(Vector2(490,252),Vector2(490,562),"c2b18e",43)
	line(Vector2(920,100),Vector2(920,340),"b3a07e",25)
	for id in POINTS:
		var path := door_path(id)
		for i in range(path.size()-1):
			line(path[i],path[i+1],"c2b18e",19)
	# Enclosure, patched sheet metal, south gate opening.
	for pair in [[Vector2(42,53),Vector2(958,53)],[Vector2(42,53),Vector2(42,550)],[Vector2(958,53),Vector2(958,550)],[Vector2(42,550),Vector2(430,550)],[Vector2(550,550),Vector2(958,550)]]:
		line(pair[0],pair[1],"4d5145",5)
	for x in range(48,950,21):
		line(Vector2(x,47),Vector2(x,60),"504b3b",3)
		if x < 427 or x > 554:
			rect(Vector2(x,543),Vector2(16,12),"756b51")
	for y in range(65,542,24):
		rect(Vector2(36,y),Vector2(11,18),"6d6651")
		rect(Vector2(953,y),Vector2(11,18),"6d6651")
	# Food warehouse, awning and a line of crates.
	roof(Rect2(82,111,194,80),"787f69")
	rect(Vector2(120,191),Vector2(96,20),"524e3e")
	for i in range(4): crate(Vector2(86+i*28,208))
	rect(Vector2(225,194),Vector2(47,23),"c0ab77")
	words(Vector2(109,145),"FOOD / 01","d7c9a1",20)
	# Fenced training area, target line and tire obstacles.
	rect(Vector2(365,115),Vector2(195,112),"947a58")
	draw_rect(Rect2(365,115,195,112),Color("665e47"),false,3)
	for x in [390,455,523]:
		line(Vector2(x,140),Vector2(x,177),"5c4d39",4)
		draw_circle(Vector2(x,143),13,Color("c6b086"))
		draw_circle(Vector2(x,143),8,Color("8a4d39"))
		draw_circle(Vector2(x,143),3,Color("d8c7a6"))
	for x in range(383,540,24):
		draw_arc(Vector2(x,202),8,0,TAU,16,Color("41453b"),5,true)
	# Armory, doors and supply cages.
	roof(Rect2(592,142,115,61),"626b61")
	rect(Vector2(630,203),Vector2(37,16),"333d37")
	for i in range(3): crate(Vector2(595+i*25,222))
	# Boss administration block: intact roof and separate guarded yard.
	rect(Vector2(728,58),Vector2(214,215),"887e67")
	roof(Rect2(745,65,164,42),"685c4d")
	for x in [757,793,858]: rect(Vector2(x,110),Vector2(19,8),"333d36")
	roof(Rect2(787,165,100,40),"8e8270")
	rect(Vector2(822,205),Vector2(20,12),"3d4137")
	line(Vector2(727,62),Vector2(727,270),"5f5745",3)
	line(Vector2(727,270),Vector2(907,270),"5f5745",3)
	figure(Vector2(918,280),"514c3d")
	words(Vector2(748,259),"출입 감시 구역","d1be97",14)
	# Water tank, hose, barrels and wash trough.
	draw_circle(Vector2(127,309),28,Color("455e5b"))
	draw_circle(Vector2(127,305),25,Color("718c80"))
	draw_arc(Vector2(127,305),19,0,TAU,32,Color("a2b3a0"),2,true)
	line(Vector2(150,315),Vector2(202,324),"425a51",5)
	rect(Vector2(201,304),Vector2(66,25),"666b5a")
	rect(Vector2(206,308),Vector2(56,15),"6e9187")
	for x in [104,127,150]: barrel(Vector2(x,354),"677b6b")
	# Accommodation with patched canvas and outdoor kitchen.
	roof(Rect2(80,399,169,46),"77715a")
	rect(Vector2(107,416),Vector2(36,15),"a19169")
	line(Vector2(107,416),Vector2(143,431),"625f4b",2)
	rect(Vector2(85,454),Vector2(55,12),"5c503b")
	for x in [92,124]: barrel(Vector2(x,483))
	draw_circle(Vector2(263,431),16,Color("595a4b"))
	draw_circle(Vector2(263,431),10,Color("343c34"))
	line(Vector2(250,425),Vector2(276,425),"b2a07c",3)
	# Clinic with a large recognizable cross.
	roof(Rect2(299,403,76,42),"a19b7f")
	rect(Vector2(329,411),Vector2(12,25),"d7d2b7")
	rect(Vector2(323,418),Vector2(24,11),"d7d2b7")
	# Workshop: two service bays, spare engine, fuel kept away from kitchen.
	roof(Rect2(646,394,230,37),"586c67")
	rect(Vector2(658,431),Vector2(85,50),"555c51")
	rect(Vector2(758,431),Vector2(85,50),"555c51")
	vehicle(Vector2(687,434),"8c7b55")
	vehicle(Vector2(784,437),"667c6c")
	for x in [892,917]: barrel(Vector2(x,430),"955e40")
	for x in [877,896,915]:
		draw_arc(Vector2(x,478),10,0,TAU,18,Color("343d35"),5,true)
	# Truck parking and salvage heap in the central service yard.
	vehicle(Vector2(304,264),"7f7757",true)
	vehicle(Vector2(353,269),"665f4a",true)
	for i in range(5):
		rect(Vector2(605+i*13,285+(i%2)*8),Vector2(22,12),"6b6e5b")
	for p in [Vector2(442,315),Vector2(523,362),Vector2(291,228),Vector2(740,476)]:
		figure(p,"5a6350")
	# Gate watchtower, portable barrier and outbound tracks.
	roof(Rect2(570,504,39,36),"6d614b")
	for x in [574,600]: line(Vector2(x,540),Vector2(x,551),"494d40",4)
	line(Vector2(436,525),Vector2(469,519),"4c5142",5)
	line(Vector2(511,519),Vector2(543,525),"4c5142",5)
	for x in [476,501]: line(Vector2(x,566),Vector2(x,592),"766f56",3)
	# Path preview and independently positioned player.
	if busy:
		var previous := player
		for next in route:
			line(previous,next,"e4c375",2)
			previous = next
	for id in POINTS:
		var chosen: bool = id == current or id == hovered or (busy and id == selected)
		if chosen:
			draw_rect(place_rect(id).grow(4),Color("dfbc77"),false,2)
		var r := label_rect(id)
		draw_rect(r,Color("273d35") if id == current else Color("4a4e40"))
		if id == hovered: draw_rect(r,Color("dfbc77"),false,2)
		words(r.position+Vector2(11,21),NAMES[id],"f0e3c7",18)
	var pp := player + Vector2(-13,-4)
	draw_circle(pp+Vector2(2,6),11,Color(0,0,0,0.28))
	var stride := sin(walk_phase)*4 if busy else 0.0
	line(pp+Vector2(-4,5),pp+Vector2(-4,13+stride),"233a37",4)
	line(pp+Vector2(4,5),pp+Vector2(4,13-stride),"233a37",4)
	draw_circle(pp,9,Color("326d65"))
	draw_circle(pp+Vector2(0,-8),6,Color("d8b48a"))
	draw_arc(pp,17,0,TAU,32,Color("f1d18a"),2,true)
	words(pp+Vector2(-15,-25),"이치","253a32",16)
	# Map header is part of the asset and survives resizing.
	rect(Vector2.ZERO,Vector2(1000,39),"303d35")
	words(Vector2(18,27),"01 / 폐차량기지 · 약탈무리 거점","f0dfba",19)
	words(Vector2(735,26),"장소 클릭 → 통로 따라 이동","c1c7ae",16)
	words(Vector2(962,82),"N","354338",18)
	line(Vector2(968,110),Vector2(968,89),"354338",2)
	line(Vector2(968,89),Vector2(964,96),"354338",2)
	draw_set_transform(Vector2.ZERO)
