extends Node
# 임시 스크린샷 도구: 실제 게임 화면을 캡처해서 PNG 로 저장한다.
#   godot --path godot res://tools/Shot.tscn -- act=3 wait=45 clean=1
#     act   : 캡처할 막 (저장 파일이 로드돼도 이 막으로 맞춘다)
#     wait  : 캡처 전 대기 프레임 수
#     clean : 1 이면 첫 실행 코치마크/모달을 닫고 게임 화면만 찍는다
#     fresh : 1 이면 세이브를 지우고 새 게임 상태에서 찍는다 (테스트 세이브만 지운다)
#     monsters / boss : 그 막 명단의 몬스터 N마리 / 보스를 경로에 세운다
#     tiles / slots   : 벨트 자모를 채우고(예: ㄱ,ㅏ,ㄴ,ㅏ) 슬롯에 배정한다(예: 0,0,1,1)
#     hint / allhint / lock : 슬롯 힌트(0부터) / 전체 힌트 / 슬롯 고정을 눌러 채점 화면을 만든다
#     target          : 슬롯의 목표 단어를 직접 세운다 (예: target=0:고기). 채점 등급 조합 재현용.
#     recommend       : 1 이면 '조합 추천' 패널을 연다 (힌트와 같은 질문에 답하는 두 번째 화면).
#     info / dmg : N번 슬롯 타워의 정보창을 열고, 타워별 누적 피해를 미리 넣는다(예: dmg=4200,1900,700)
#     over / burn : 런 요약(게임오버)을 열고, 세운 적에게 화상을 건다(예: burn=1 → 첫 마리는 2겹)
#     shop    : 1 이면 상점을 열고 진열을 고정한다(무작위 shuffle 을 덮어씀 → 설명 문구 재현용)
#     out   : 저장 경로 (기본 E:/project/word_card/_shot_actN.png)
# 주의: --headless 로는 동작하지 않는다 (frame_post_draw 가 오지 않는다).
# 캡처 후 스스로 종료한다.

var _act := 1
var _wait := 90
var _clean := false
var _tiles := ""
var _select := -1
## 타일을 어느 슬롯에 둘지 (예: slots=0,0,1,1). tiles= 와 함께 쓴다.
var _slots := ""
## hint=N 이면 N번 슬롯의 힌트를 눌러 채점 색을 입힌다. allhint=1 이면 세 슬롯 한 번에.
var _hint := -1
var _all_hint := false
## lock=N 이면 N번 슬롯을 고정한다 (힌트 채점 뒤에 실행된다).
var _lock := -1
## relic=id1,id2 처럼 유물을 쥐여 준다.
##
## 유물은 헤더의 버튼을 **추가**한다(예: 훈민정음의 나침반 → '전체 힌트'). 버튼이 늘면
## 미리보기 라벨의 폭이 줄어드는데, 그 좁아진 폭에서 문장이 잘리는지 확인하려면
## 유물을 쥐여 준 캡처가 필요하다. 없으면 실제 화면보다 넓은 자리에서 검사하게 된다.
var _relics := ""
## target=0:고기 처럼 슬롯의 목표 단어를 직접 세운다.
##
## hint= 는 목표를 스스로 고르므로 '돌려야 하는 타일 + 옮겨야 하는 타일' 같은 특정
## 등급 조합을 재현할 수 없다(그때그때 다른 단어가 뽑힌다). 채점 색을 확인하려면
## 목표를 고정해야 화면이 매번 같아진다.
var _targets := ""
## recommend=1 이면 '조합 추천' 패널을 연다 (힌트와 같은 질문에 답하는 두 번째 화면).
var _recommend := false
var _towers := ""
## info=N 이면 N번 슬롯 타워의 정보창을 연다 (towers= 와 함께 쓴다).
## dmg=4200,1900,700 처럼 타워별 누적 피해를 미리 넣어 '성과 줄' 을 실제 값으로 찍는다.
var _info := -1
var _dmg := ""
## over=1 이면 런 요약(게임오버) 화면을 연다. dmg= 와 함께 쓰면 랭킹을 실제 값으로 볼 수 있다.
var _over := false
## burn=N 이면 세운 적 N마리에게 화상을 건다(겹수 확인용). 실제 API(apply_burn)로 넣는다.
var _burn := 0
## 보스/몬스터 연출 확인용. monsters=N 은 그 막 명단에서 N마리를, boss=1 은 보스를 세운다.
var _boss := false
var _monsters := 0
## breakshield=N 이면 방어도(shield)를 가진 적의 방어도를 N번의 타격으로 **정확히** 벗긴다.
## 마지막 한 대가 방어도를 딱 0 으로 만들므로 HP 는 한 대도 안 깎인다 —
## '방어도가 방금 벗겨진' 순간을 HP 손실 없이 찍기 위한 것이다.
## burn= 과 같은 원칙으로 실제 입구(`take_damage`)를 지난다.
var _break_shield := 0
## shop=1 이면 상점(유물 진열대)을 열고 **진열 품목을 고정**한다.
##
## 상점의 기본 진열은 `available.shuffle()` 로 27개 중 4개를 무작위로 뽑는다. 그래서
## 특정 유물의 **설명 문구**를 찍으려면 운에 기대야 하고, 같은 화면을 다시 만들 수 없다.
## 여기서는 진열을 바꿔 끼워 넣어 '설명이 바뀐 그 카드' 만 결정적으로 찍는다.
## (`_open_relic_shop` 이 `refresh_stock()` 을 부르므로 **그 뒤에** 덮어써야 한다)
var _shop := false
var _out := ""
## 1 이면 저장 파일을 지우고 '새 게임' 상태에서 찍는다.
## (세이브를 두면 저장된 막/웨이브/타워가 화면에 섞여 들어와 캡처가 거짓말을 한다)
var _fresh := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("act="):
			_act = int(a.split("=")[1])
		elif a.begins_with("wait="):
			_wait = int(a.split("=")[1])
		elif a.begins_with("clean="):
			_clean = int(a.split("=")[1]) != 0
		elif a.begins_with("tiles="):
			_tiles = a.split("=")[1]
		elif a.begins_with("select="):
			_select = int(a.split("=")[1])
		elif a.begins_with("slots="):
			_slots = a.split("=")[1]
		elif a.begins_with("hint="):
			_hint = int(a.split("=")[1])
		elif a.begins_with("allhint="):
			_all_hint = int(a.split("=")[1]) != 0
		elif a.begins_with("lock="):
			_lock = int(a.split("=")[1])
		elif a.begins_with("relic="):
			_relics = a.split("=")[1]
		elif a.begins_with("target="):
			_targets = a.split("=")[1]
		elif a.begins_with("recommend="):
			_recommend = int(a.split("=")[1]) != 0
		elif a.begins_with("towers="):
			_towers = a.split("=")[1]
		elif a.begins_with("info="):
			_info = int(a.split("=")[1])
		elif a.begins_with("dmg="):
			_dmg = a.split("=")[1]
		elif a.begins_with("over="):
			_over = int(a.split("=")[1]) != 0
		elif a.begins_with("burn="):
			_burn = int(a.split("=")[1])
		elif a.begins_with("boss="):
			_boss = int(a.split("=")[1]) != 0
		elif a.begins_with("monsters="):
			_monsters = int(a.split("=")[1])
		elif a.begins_with("breakshield="):
			_break_shield = int(a.split("=")[1])
		elif a.begins_with("shop="):
			_shop = int(a.split("=")[1]) != 0
		elif a.begins_with("out="):
			_out = a.split("=")[1]
		elif a.begins_with("fresh="):
			_fresh = int(a.split("=")[1]) != 0
	# fresh=1 이면 세이브를 지운다. SaveManager 는 tools/Shot 을 '테스트 실행' 으로
	# 분류하므로(실제 세이브를 건드리지 않는다) 여기서 지우는 건 테스트 세이브뿐이다.
	if _fresh and SaveManager.has_save_file():
		SaveManager.delete_save_file()
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.get_node_or_null("VBox/FieldContainer/DefenseField")
	if field == null:
		field = main.find_child("DefenseField", true, false)
	# 저장 파일이 자동 로드되므로 현재 막이 무엇이든 항상 원하는 막으로 맞춘다.
	# 주의: set_act 는 지도·경로·발판만 바꾼다. 상단 바 글자와 '다음 라운드' 안내는
	# TowerDefenseMain 이 따로 그리므로, 둘 다 여기서 함께 맞춰 주지 않으면
	# 1막 지도를 찍었는데 상단 바가 "제 3막" 이라고 나오는 일이 생긴다.
	if field:
		field.set_act(_act)
		main._update_topbar_wave_label(_act, field.current_wave)
		main._update_next_round_preview()
	_run(main, field)


func _run(main: Node, field: Node) -> void:
	# 코치마크가 먼저 뜨는 경우가 있어 몇 프레임 뒤에 걷어낸다.
	for i in range(6):
		await get_tree().process_frame
	if _clean:
		var layer = main.get_node_or_null("ModalLayer")
		if layer:
			for child in layer.get_children():
				layer.remove_child(child)
				child.queue_free()
	# 유물은 타일을 채우기 **전에** 쥐여 준다. render_belt() 가 set_relics() 를 부르므로
	# 여기서 넣어 두면 헤더 버튼까지 한 번에 반영된다.
	if _relics != "" and field:
		field.relic_ids.clear()
		for r in _relics.split(","):
			field.relic_ids.append(r)
	# 벨트에 자모를 채워 타일 렌더링을 확인할 수 있게 한다.
	var belt = main.find_child("JamoBelt", true, false)
	if _relics != "" and belt:
		belt.set_relics(field.relic_ids if field else [])
	if _tiles != "" and belt:
		belt.jamo_list.clear()
		for c in _tiles.split(","):
			belt.jamo_list.append(c)
		if _slots != "":
			var want: Array[int] = []
			for s in _slots.split(","): want.append(int(s))
			belt.slot_assignments.assign(want)
		belt.render_belt()
		if _select >= 0:
			belt._on_tile_clicked(_select)
		# 채점 화면은 힌트를 눌러야 나온다 — 슬롯 힌트 → 고정 순서로 재현한다.
		if _all_hint:
			belt._show_all_hints()
		elif _hint >= 0:
			belt._show_slot_hint(_hint)
		if _lock >= 0:
			belt._toggle_slot_lock(_lock)
		# '조합 추천' 패널. 힌트와 같은 질문("무엇을 노릴까")에 답하는 두 번째 화면이라,
		# 둘의 숫자·순위가 어긋나는지 눈으로 대조하려면 이 캡처가 필요하다.
		if _recommend:
			belt.strategy_recommendations_requested.emit()
	# 목표를 직접 세운다. render_belt() 안의 _regrade_slots() 가 채점까지 다시 하므로
	# 게임과 같은 경로로 채점된다 — 여기서 등급을 손으로 넣으면 화면이 거짓말을 한다.
	# 채점 한 줄도 같은 함수(_slot_hint_text)로 뽑는다. 힌트 버튼을 안 누르면 비어 있다.
	if _targets != "" and belt:
		var last := -1
		for spec in _targets.split(","):
			var kv: PackedStringArray = spec.split(":")
			if kv.size() != 2: continue
			last = int(kv[0])
			belt.slot_targets[last] = kv[1]
		belt.render_belt()
		if last >= 0:
			belt.parsed_preview_label.text = belt._slot_hint_text(last)
	# 타워를 슬롯에 직접 세워 카드 렌더링을 확인한다 (예: towers=검,불,물)
	if _towers != "" and field:
		var parsed: Array = []
		for c in _towers.split(","):
			parsed.append({"syllable": c, "word_data": WordDatabase.get_word_data(c)})
		field.unlocked_slot_count = maxi(field.unlocked_slot_count, parsed.size())
		field.update_towers_from_parsed_list(parsed)
	# 정보창의 '누적 피해' 줄은 기록이 있어야 값이 나온다. 실제 런과 같은 경로
	# (record_tower_damage)로 넣어야 화면이 거짓말을 하지 않는다.
	if field and _dmg != "":
		var tower_names: Array = []
		for t in field.active_towers:
			tower_names.append(t.syllable)
		var parts: Array = _dmg.split(",")
		for i in range(mini(parts.size(), tower_names.size())):
			field.record_tower_damage(tower_names[i], float(parts[i]))
	if _info >= 0 and field:
		var built: Array = field.active_towers
		if _info < built.size():
			main._on_tower_info_requested(built[_info])
	if _over:
		main._on_game_over(false)
	# 상점 진열 — 무작위 진열(shuffle)을 **고정 진열**로 덮어써서 설명 문구를 결정적으로 찍는다.
	# 골드를 넉넉히 채워 버튼이 '살 수 있는' 상태로 보이게 한다(설명이 주인공인 화면이므로).
	if _shop:
		if field:
			field.gold = 100
		main._open_relic_shop()
		var shop = main.get("shop_modal")
		if shop != null:
			var shop_script = load("res://scripts/ui/ShopModal.gd")
			var pinned: Array = []
			for wanted in ["relic_range_rune", "relic_first_strike"]:
				for r in shop_script.ALL_RELIC_POOL:
					if str(r["id"]) == wanted:
						var copy: Dictionary = r.duplicate()
						copy["sold"] = false
						pinned.append(copy)
						break
			if not pinned.is_empty():
				shop.relic_stock = pinned
				shop._update_ui()
	# 보스/몬스터 연출 확인 — 필드에 직접 세우고 경로를 따라 흩어 놓는다.
	if field and (_boss or _monsters > 0):
		field.spawn_queue.clear()
		field.is_wave_running = true
		var act_scale := 1.0 + (_act - 1) * 0.5
		# field 는 untyped Node 라 동적 호출 결과가 Variant 다 → `:=` 로 받으면 추론 실패.
		var base_hp: float = (10.0 + _act * 4.0) * field.hp_compensation_for(_act, 5)
		for i in range(_monsters):
			field._spawn_enemy(MonsterRoster.regular_entry(_act, i, base_hp, 1.0, act_scale))
		if _boss:
			field._spawn_enemy(MonsterRoster.boss_entry(_act, 5, base_hp, 1.0, act_scale, 5))
		var curve = field.path_2d.curve if field.path_2d else null
		var curve_len: float = curve.get_baked_length() if curve != null else 0.0
		var enemies: Array = field.get_enemies()
		for i in range(enemies.size()):
			enemies[i].progress = curve_len * (0.08 + 0.55 * float(i) / maxf(1.0, float(enemies.size() - 1)))
		# 화상 칩 확인 — 게임과 같은 입구(apply_burn)로 넣어야 화면이 거짓말을 하지 않는다.
		# burn=N 이면 앞의 N마리에게 두 번 걸어 겹수 표시까지 함께 본다.
		if _burn > 0:
			for i in range(enemies.size()):
				var times: int = 2 if i < _burn else 1
				for k in range(times):
					enemies[i].apply_burn(2.0, 30.0)
		# 방어도 벗기기 — burn= 과 같은 원칙으로 실제 타격 입구(`take_damage`)를 지난다.
		# 마지막 한 대는 **남은 방어도와 정확히 같은 값**으로 때린다. `take_damage` 는
		# `shield -= minf(shield, amount)` 라서 amount == shield 면 0.0 이 정확히 나오고
		# HP 는 한 대도 안 깎인다. (shield/N 을 N번 때리면 부동소수 오차로 1e-16 이 남아
		# 바 색이 안 바뀔 수 있다)
		if _break_shield > 0:
			for e in field.get_enemies():
				var warded: float = e.shield
				if warded <= 0.0:
					continue
				var per: float = warded / float(_break_shield)
				for k in range(_break_shield - 1):
					e.take_damage(per, false)
				e.take_damage(e.shield, false)
	for i in range(_wait):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out if _out != "" else "E:/project/word_card/_shot_act%d.png" % _act
	var err := img.save_png(path)
	print("SHOT_SAVED ", path, " err=", err)
	get_tree().quit()
