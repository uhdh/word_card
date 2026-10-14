# ModalFitProbe.gd
# **모든 모달이 화면 안에 들어오는가** — §2.32 의 결함 *부류* 를 전수로 지킨다.
#
# 왜 재는가 (2026-10-05):
#   §2.32 에서 라운드 정보 모달이 화면 밖으로 나갔다. 원인은 **둘** 이었고 둘 다 재사용 가능한
#   기구다:
#     ① `Label` 에 `autowrap_mode` 가 없으면 **최소 폭 = 글자 폭** 이다.
#     ② 그 라벨이 `HBoxContainer` 에 들어가면 세로로 안 쌓이고 **가로로 선다**.
#   `PanelContainer` 는 `custom_minimum_size` 보다 **큰** 자식 최소 크기를 이기므로 상한이
#   없고, `_show_modal()` 의 `(host − size)*0.5` 중앙 정렬이 **양쪽으로** 삐져나간다.
#
#   ⚠️ 그때 고친 것은 `_on_stage_btn_pressed()` **하나** 였다. 같은 기구를 쓰는 모달이
#      더 있는데 **아무도 안 쟀다.** 이 프로브가 그 자리를 닫는다.
#   ⚠️ **첫 판은 여섯만 쟀다** — 헤더가 "모든 모달" 이라 주장했는데 `modal_layer` 에
#      붙는 표면은 **열**이다. S1b 가 빠진 넷을 잰다:
#      코치마크(첫 실행, 3단계) · 볼륨 설정 · 타워 정보 · 게임오버.
#      ⚠️ 목록의 출처는 `_show_modal(` 와 `modal_layer.add_child` **호출부 전부** 다 —
#         **감독이 준 표면만 재면 '전수' 가 아니다.**
#
# 재는 것:
#   S1  모달마다 **패널이 화면 안**인가 (네 변 전부)
#   S2  모달 안에서 **잘린 라벨**이 있는가 (`size < 최소크기`, 단 `clip_text` 는 의도된 계약)
#   S3  양성 대조 — 재는 함수가 **일부러 만든 화면 밖 패널**을 실제로 잡는가
#   S4  스크린샷 (창 모드 전용)
#
# ⚠️ **첫 판이 공짜로 통과했다** (2026-10-05). 최상위 자식만 쟀더니 셋이 `(0,0)` 으로 보고됐다:
#    `LexiconModal`·`ShopModal`·`WaveRewardModal` 의 루트는 **화면 전체(`1280x720`) `Control`**
#    이고 진짜 패널은 그 **안**에 있다. 게다가 크기 0 패널은 `_fit` 이 초과 0 을 돌려준다 —
#    **배치가 안 끝난 것을 '화면 안' 으로 세면** 검사가 통째로 공허해진다.
#    → `_outer_panels()` 로 **가장 바깥 `PanelContainer`** 까지 내려가고, 크기 > 1 을 단언한다.
# ⚠️ 루트는 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
# ⚠️ `Node` 에는 `get_viewport_rect()` 이 없다(그건 `CanvasItem` 메서드다).
extends Node

const ShopModal = preload("res://scripts/ui/ShopModal.gd")
const AttackStyleScript = preload("res://scripts/core/AttackStyle.gd")

const OUT_PATH := "E:/project/word_card/tmp/modalfit_out.txt"
const SHOT_PATH := "E:/project/word_card/tmp/modalfit.png"
const GO_SHOT_PATH := "E:/project/word_card/tmp/modalfit_gameover.png"

var failures := 0
var _lines: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		_emit("★실패 %s" % message)


func _emit(s: String) -> void:
	_lines.append(s)
	print(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null


func _watchdog() -> void:
	for i in 2400:
		await get_tree().process_frame
	_emit("WATCHDOG — 2400 프레임 안에 못 끝났다")
	get_tree().quit(124)


## 패널 하나가 화면을 얼마나 넘는가. `over` 가 0 보다 크면 화면 밖이다.
## ⚠️ **네 변을 다 본다** — 오른쪽만 보면 왼쪽으로 삐져나간 패널을 놓친다
##    (§2.32 의 패널은 가운데 정렬이라 **양쪽**으로 나갔다).
func _fit(panel: Control, vp: Vector2) -> Dictionary:
	var r: Rect2 = panel.get_global_rect()
	var over_l: float = maxf(-r.position.x, 0.0)
	var over_r: float = maxf(r.position.x + r.size.x - vp.x, 0.0)
	var over_t: float = maxf(-r.position.y, 0.0)
	var over_b: float = maxf(r.position.y + r.size.y - vp.y, 0.0)
	var worst: float = maxf(maxf(over_l, over_r), maxf(over_t, over_b))
	var side := ""
	if worst > 0.5:
		if over_r >= over_l and over_r >= over_t and over_r >= over_b:
			side = "오른쪽"
		elif over_l >= over_t and over_l >= over_b:
			side = "왼쪽"
		elif over_b >= over_t:
			side = "아래"
		else:
			side = "위"
	return {"over": worst, "side": side, "rect": r,
		"l": over_l, "r": over_r, "t": over_t, "b": over_b}


## 패널 안에서 **잘린** 라벨. `clip_text` 는 작성자가 의도한 계약이라 제외한다
## (`JamoBelt` 의 `PreviewLabel` 이 그렇다 — 말줄임으로 넘긴다).
func _clipped_labels(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n is Label:
			var l: Label = n
			if l.clip_text:
				continue
			var mn: Vector2 = l.get_minimum_size()
			if l.size.x + 0.5 < mn.x or l.size.y + 0.5 < mn.y:
				out.append("%dpx (필요 %.0f · 실제 %.0f) '%s'" % [
					l.get_theme_font_size("font_size"), mn.x, l.size.x,
					l.text.substr(0, 24)])
	return out


## 모달의 **가장 바깥쪽 `PanelContainer`** 들. 딤 오버레이·전체화면 `Control` 은 패널이 아니다.
##
## ⚠️ 최상위 자식만 재면 **`LexiconModal`·`ShopModal`·`WaveRewardModal` 은 항상 통과**한다 —
##    그 셋의 루트는 화면 전체(`1280x720`) `Control` 이고 진짜 패널은 그 **안**에 있다.
##    실측(2026-10-05): 최상위만 재던 첫 판이 그 셋을 `(0,0)` 으로 보고하며 **공짜 통과**했다.
## ⚠️ 안쪽 `PanelContainer`(스크롤 안의 카드 등)는 안 센다 — 바깥 패널이 잡히면 충분하다.
func _outer_panels(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is PanelContainer:
			out.append(n)
			continue          # 더 안으로 안 내려간다
		for k in n.get_children():
			stack.append(k)
	return out


## 도감의 **최악 상태** — 모든 단어를 발견 처리한다. 카드 그리드가 가장 넓어진다.
## ⚠️ 내용에 따라 커지는 모달을 **한 상태만** 재면 그 상태가 최악이라는 보장이 없다.
func _discover_all_words() -> int:
	var n := 0
	for d in WordDatabase.get_all_words():
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var w := str((d as Dictionary).get("word", ""))
		if w == "":
			continue
		SaveManager.discover_word(w)
		n += 1
	return n


## 상점의 **최악 상태** — 설명이 가장 긴 유물 넷으로 재고를 바꾼다(실제 상한은 4장).
func _stock_worst_relics(main: Node) -> int:
	var shop: Node = main.modal_layer.find_child("ShopModal", true, false)
	if shop == null:
		return -1
	var pool: Array = []
	for r in ShopModal.ALL_RELIC_POOL:
		pool.append(r)
	pool.sort_custom(func(a, b):
		return str((a as Dictionary)["desc"]).length() > str((b as Dictionary)["desc"]).length())
	var stock: Array = []
	for i in range(mini(4, pool.size())):
		var c: Dictionary = (pool[i] as Dictionary).duplicate()
		c["sold"] = false
		stock.append(c)
	shop.relic_stock = stock
	shop.current_gold = 9999
	shop._update_ui()
	return stock.size()

## 등장 트윈이 끝날 때까지 **실시간**으로 기다린다.
##
## ⚠️ 왜 프레임 몇 개로는 안 되나 — `_show_modal()` 은 `scale = 0.92` 로 시작해 0.18초에
##    걸쳐 1 로 키우는데 그 트윈은 `Engine.time_scale` 을 따른다. 헤드리스는 프레임이 매우
##    빠르므로 `await process_frame` 네 번은 **수 마이크로초**다 — 그 시점의 패널은 아직
##    0.92 배이고, 그 상태로 재면 초과가 8% 작게 잡혀 **화면 밖을 놓친다.**
##    (§1.1 아홉 번째 — 근거가 계측이면 **계측 조건도 계약**이다.)
func _settle(wait_sec: float = 0.30) -> void:
	await get_tree().create_timer(wait_sec, true, false, true).timeout


## `modal_layer` 의 Control 자식을 전부 치운다. `queue_free()` 는 **지연**이라 프레임을
## 넘겨야 실제로 사라진다 — 안 그러면 다음 측정이 **딤 위에서** 이뤄진다.
func _free_modals(main: Node) -> void:
	for ch in main.modal_layer.get_children():
		if ch is Control:
			ch.queue_free()
	for f in 2:
		await get_tree().process_frame


## 트리 안에서 글자가 `texts` 중 하나인 버튼을 찾는다(코치마크의 `다음`/`알겠습니다`).
func _find_button(root: Node, texts: Array) -> Button:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n is Button and texts.has((n as Button).text):
			return n
	return null


## 지금 `modal_layer` 에 떠 있는 모달들의 패널을 재고 보고한다(S1/S2 공용).
## ⚠️ 부르기 전에 `_settle()` 로 **등장 트윈을 끝내 둬야** 한다.
func _measure(main: Node, vp: Vector2, name: String) -> Dictionary:
	var panels: Array = []
	for ch in main.modal_layer.get_children():
		if ch is Control and (ch as Control).is_visible_in_tree():
			for p in _outer_panels(ch):
				panels.append(p)
	if panels.is_empty():
		_emit("S1 %-10s — 모달이 안 떴다" % name)
		check(false, "%s 모달이 안 떴다 — 재는 대상이 없다" % name)
		return {"ok": false, "worst": 0.0, "clipped": 0, "panels": panels}
	var worst := 0.0
	var worst_side := ""
	var biggest := Vector2.ZERO
	var clipped := 0
	var sizes: Array[String] = []
	for p in panels:
		var pc: Control = p
		sizes.append("%s%s" % [pc.name, str(pc.size)])
		# ⚠️ **비공허성** — 크기 0 패널은 `_fit` 이 초과 0 을 돌려줘 **공짜로 통과**한다.
		check(pc.size.x > 1.0 and pc.size.y > 1.0,
			"%s 의 패널 '%s' 크기가 %s 다 — 배치가 안 끝난 것을 '화면 안' 으로 세면 안 된다"
			% [name, pc.name, str(pc.size)])
		if pc.size.x > biggest.x:
			biggest = pc.size
		var fit := _fit(pc, vp)
		if float(fit["over"]) > worst:
			worst = float(fit["over"])
			worst_side = str(fit["side"])
		var cl := _clipped_labels(pc)
		clipped += cl.size()
		if cl.size() > 0:
			for c in cl:
				_emit("S2 %-10s 잘린 라벨: %s" % [name, c])
	_emit("S1 %-10s 패널 %d개 %s · 최대폭 %5.0f · 초과 %6.1f %s · 잘린라벨 %d %s" % [
		name, panels.size(), ", ".join(sizes), biggest.x, worst,
		("(" + worst_side + ")") if worst_side != "" else "",
		clipped, "★화면밖" if worst > 0.5 else "OK"])
	return {"ok": true, "worst": worst, "clipped": clipped, "panels": panels,
		"size": biggest}


## 타워 정보 모달의 **최악 후보** 단어들.
##
## ⚠️ `TowerInfoModal` 의 `stats_label` 은 `autowrap` 이 **없는** 순수 `Label` 이라
##    최소 폭 = 글자 폭이다(§2.32 의 기구 그대로). 그 폭을 키우는 것은 **연발(volley)**
##    ·**치명타**·**큰 수치**다 → 그런 단어를 우선 고른다.
## ⚠️ 한 단어만 재면 "그게 최악" 이라는 보장이 없다(§2.33-2 와 같은 원칙). 특성마다
##    하나씩 + 연발/3글자 단어를 모아 **상한 안에서** 최대한 넓게 훑는다.
func _tower_candidates(limit: int) -> Array:
	var by_trait: Dictionary = {}
	var extra: Array = []
	for d in WordDatabase.get_all_words():
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var wd: Dictionary = d
		var ws := str(wd.get("word", ""))
		if ws == "":
			continue
		var st: Dictionary = AttackStyleScript.style_for(ws, wd)
		var tid := str(st.get("trait", ""))
		if tid == "":
			continue
		if not by_trait.has(tid):
			by_trait[tid] = ws
		var volley := int(WordTower.preview_stats(ws, wd).get("volley", 1))
		if volley > 1 or ws.length() >= 3:
			extra.append(ws)
	var out: Array = []
	var seen := {}
	for ws in by_trait.values():
		var s := str(ws)
		if not seen.has(s):
			seen[s] = true
			out.append(s)
	for ws in extra:
		var s2 := str(ws)
		if not seen.has(s2):
			seen[s2] = true
			out.append(s2)
	var parsed: Array = []
	for ws in out:
		parsed.append({"syllable": ws, "word_data": WordDatabase.get_word_data(ws)})
	if parsed.size() > limit:
		parsed = parsed.slice(0, limit)
	return parsed


func _ready() -> void:
	_watchdog()
	_emit("MODAL_FIT_START")
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_emit("S0 뷰포트 %s" % str(vp))

	# ⚠️ **초기 상태를 고정한다.** `_ready` 는 세이브가 **없으면** 코치마크를
	#    `call_deferred` 로 띄운다. 그러면 첫 측정(`라운드 정보`)에 **남의 패널이 섞여**
	#    두 개로 보고된다 — 실측(2026-10-05): `@PanelContainer@121(440,145)` 가 함께
	#    잡혔다. 프로브가 세이브 유무에 따라 **다른 것**을 재면 그건 계측이 아니라 운이다
	#    (§1.1 — 근거가 계측이면 계측 조건도 계약이다).
	SaveManager.delete_save_file()
	await _free_modals(main)

	# ⚠️ **실제로 플레이어가 여는 문**을 쓴다 — 모달을 직접 만들면 배선(씬·setup 인자)을
	#    건너뛰어 **진짜 레이아웃이 아닌 것**을 재게 된다.
	# (막, 라운드) 는 **가장 긴 문구**가 나오는 쪽으로 고른다(§2.32 실측: 2막 10R).
	field.set_act(2)
	field.current_wave = 9
	await get_tree().process_frame

	# ⚠️ **내용에 따라 커지는 모달은 *최악 상태* 로 열어야 한다** — 한 상태만 재면 그게
	#    최악이라는 보장이 없다. `before` 는 열기 전 준비, `after` 는 연 뒤 재고 교체.
	var openers: Array = [
		["라운드 정보", func(): main._on_stage_btn_pressed(), Callable(), Callable()],
		["활자 도감", func(): main._on_lexicon_pressed(),
			func(): _emit("  (도감 최악 상태 — 단어 %d개 발견 처리)" % _discover_all_words()),
			Callable()],
		["유물 상점", func(): main._open_relic_shop(), Callable(),
			func(): _emit("  (상점 최악 상태 — 설명 긴 유물 %d장)" % _stock_worst_relics(main))],
		["세계관", func(): main._on_lore_pressed(), Callable(), Callable()],
		["웨이브 보상", func(): main._show_wave_reward(3, 40), Callable(), Callable()],
		["막 클리어", func(): main._on_act_cleared(1, 120), Callable(), Callable()],
	]

	var bad := 0
	var clipped_total := 0
	for entry in openers:
		var name: String = entry[0]
		var open_fn: Callable = entry[1]
		var before_fn: Callable = entry[2]
		var after_fn: Callable = entry[3]
		if before_fn.is_valid():
			before_fn.call()
		open_fn.call()
		# ⚠️ 등장 트윈이 끝날 때까지 **실시간**으로 기다린다 — `_settle()` 주석 참고.
		await _settle()
		if after_fn.is_valid():
			after_fn.call()
			await _settle()
		var m := _measure(main, vp, name)
		if bool(m["ok"]):
			if float(m["worst"]) > 0.5:
				bad += 1
			clipped_total += int(m["clipped"])
		for p in m["panels"]:
			p.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	# ── S1b. §2.33 이 **놓친** 네 표면 ───────────────────────────────────────
	# ⚠️ 이 절의 목록 출처는 `_show_modal(` 와 `modal_layer.add_child` **호출부 전부** 다.
	#    **감독이 준 표면만 재면 '전수' 가 아니다.** 헤더는 "모든 모달" 이라 주장했는데
	#    첫 판은 여섯만 쟀다 — 실제로 `modal_layer` 에 붙는 표면은 **열**이고, 빠진 넷은
	#    코치마크(첫 실행) · 볼륨 설정 · 타워 정보 · 게임오버다.
	_emit("S1b ── §2.33 이 놓친 표면 (호출부 전수 대조) ──")

	# (1) 코치마크 3단계 — 첫 실행에만 뜬다(세이브가 있으면 즉시 반환한다).
	# ⚠️ `steps` 는 `_show_first_run_coachmark()` 의 **지역 변수**라 밖에서 못 만든다.
	#    표를 여기 복사하면 둘이 갈라진다 → **실제 문**을 부르고 `다음` 을 눌러 3단계를 잰다.
	SaveManager.delete_save_file()
	await _free_modals(main)
	main._show_first_run_coachmark()
	for step_i in 3:
		await _settle()
		var mc := _measure(main, vp, "코치마크%d" % (step_i + 1))
		if bool(mc["ok"]):
			if float(mc["worst"]) > 0.5:
				bad += 1
			clipped_total += int(mc["clipped"])
		var nxt: Button = _find_button(main.modal_layer, ["다음", "알겠습니다"])
		if nxt == null:
			check(false, "코치마크 %d단계에서 '다음' 버튼을 못 찾았다" % (step_i + 1))
			break
		nxt.pressed.emit()
		for f in 3:
			await get_tree().process_frame
	await _free_modals(main)

	# (2) 볼륨 설정 (`_show_volume_settings`)
	main._show_volume_settings()
	await _settle()
	var mv := _measure(main, vp, "볼륨설정")
	if bool(mv["ok"]):
		if float(mv["worst"]) > 0.5:
			bad += 1
		clipped_total += int(mv["clipped"])
	await _free_modals(main)

	# (3) 타워 정보 (`_on_tower_info_requested`) — 최악 후보를 **전부** 잰다.
	#     ⚠️ `update_towers_from_parsed_list` 는 **갈아 끼운다**(`active_towers.clear()`) —
	#     한 번에 `unlocked_slot_count`(3)개까지다. 그래서 묶음마다 바로 재야 한다.
	#     ⚠️ 유물을 전부 쥐여 **수치를 최대로** 만든다 — 큰 수가 글자를 길게 만든다.
	var all_ids: Array = []
	for r in ShopModal.ALL_RELIC_POOL:
		all_ids.append(str(r["id"]))
	field.relic_ids = all_ids
	field.set_act(2)
	var cand := _tower_candidates(36)
	_emit("S1b 타워 정보용 후보 단어 %d개" % cand.size())
	var ti_worst := 0.0
	var ti_count := 0
	for i in range(0, cand.size(), 3):
		field.update_towers_from_parsed_list(cand.slice(i, i + 3))
		for f in 30:
			await get_tree().process_frame
		for t in field.active_towers:
			if t == null:
				continue
			main._on_tower_info_requested(t)
			await _settle()
			var mt := _measure(main, vp, "타워정보")
			if bool(mt["ok"]):
				ti_count += 1
				ti_worst = maxf(ti_worst, float(mt["worst"]))
				clipped_total += int(mt["clipped"])
			await _free_modals(main)
	check(ti_count > 0, "타워 정보 모달을 한 번도 못 열었다")
	if ti_worst > 0.5:
		bad += 1
	_emit("S1b 타워 정보 — 후보 %d개 중 %d개 측정 · 최악 초과 %.1f %s" % [
		cand.size(), ti_count, ti_worst, "★화면밖" if ti_worst > 0.5 else "OK"])

	# (4) 게임오버 — **내용이 자라는 모달**인데 상한도 스크롤도 없다.
	#     높이를 키우는 것은 **역대 기록 줄 수**(`RANKING_LIMIT` = 10)와 **타워별 순위
	#     줄 수**(서로 다른 타워 단어마다 한 줄)다. 그래서 "한 번 열어 보고" 끝내면 안 되고
	#     **어디서 화면을 넘는지** 줄 수를 늘려가며 잰다(§2.33-2 와 같은 원칙).
	# ⚠️ `_on_game_over` 는 `_run_recorded` 로 **한 번만** 만들어진다 → 매 회차 되돌린다.
	# ⚠️ 기록은 `submit_run`(실제 문)으로 채운다 — 표를 사본으로 만들지 않는다.
	#     (이번 런도 스스로 한 줄을 넣으므로 실제 줄 수는 채운 수 + 1, 상한 10 이다.)
	# ⚠️ **어느 축이 자라는지 먼저 확인했다** — 기록(≤10줄)은 336→480 이지만
	#    **타워별 순위 줄은 서로 다른 타워 단어마다 한 줄**이고 상한이 없다. 그래서
	#    기록은 **상한(10)으로 고정**하고 타워 줄 수를 늘려 **어디서 720 을 넘는지** 잰다.
	# ⚠️ 이름은 **실제 단어**를 쓴다 — 이름 길이가 표 폭에 영향을 준다(사본 아님).
	# ⚠️ `record_tower_damage` 는 `WordTower` 가 피해를 줄 때 부르는 **그 문**이다.
	var go_log: Array = []
	var name_pool: Array = []
	for d in WordDatabase.get_all_words():
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var w := str((d as Dictionary).get("word", ""))
		if w != "" and not name_pool.has(w):
			name_pool.append(w)
	var lim: int = SaveManager.RANKING_LIMIT
	_emit("S1b 게임오버 — 기록 상한 %d줄 · 이름 후보 %d개" % [lim, name_pool.size()])
	for tower_n in [0, 6, 12, 20, 30]:
		SaveManager.clear_run_ranking()
		for k in lim:
			SaveManager.submit_run({
				"victory": k % 2 == 0, "act": 2, "wave": 8 + k,
				"total_damage": 1000.0 * (k + 1), "base_hp": 10, "max_base_hp": 30,
				"towers": 3, "top_tower": "가나",
			})
		field.tower_damage.clear()
		for k in mini(tower_n, name_pool.size()):
			field.record_tower_damage(str(name_pool[k]), 100.0 * (k + 1))
		main._run_recorded = false
		main._on_game_over(true)
		await _settle(0.80)
		var mg := _measure(main, vp, "게임오버t%d" % tower_n)
		if bool(mg["ok"]):
			var sz: Vector2 = mg["size"]
			go_log.append("기록%d·타워%2d → 높이 %5.0f · 초과 %6.1f %s" % [
				lim, tower_n, sz.y, float(mg["worst"]),
				"★화면밖" if float(mg["worst"]) > 0.5 else "OK"])
			if float(mg["worst"]) > 0.5:
				bad += 1
			clipped_total += int(mg["clipped"])
		await _free_modals(main)
	for line in go_log:
		_emit("S1b 게임오버 %s" % line)



	# ⚠️ **단언은 여기 있어야 한다.** 예전에는 이 둘이 S1b **앞**에 있었는데,
	#    그러면 S1b 가 올린 `bad`/`clipped_total` 이 **한 번도 안 읽힌다** —
	#    `★화면밖` 을 찍어 놓고도 `MODAL_FIT_PROBE_OK` 로 끝난다(실측 2026-10-05:
	#    게임오버가 8px 넘었는데 RC=0 이었다). 보고와 판정은 **같은 자리**에 있어야 한다.
	check(bad == 0, "모달 %d종이 화면 밖으로 나간다" % bad)
	check(clipped_total == 0, "모달 안에서 잘린 라벨이 %d개다" % clipped_total)

	# ── S3. 양성 대조 — 재는 함수가 **화면 밖을 잡는가** ──────────────────────
	# ⚠️ 이 절이 없으면 `_fit` 이 항상 0 을 돌려줘도 "전부 통과" 가 된다(공짜 통과).
	#    일부러 넘치는 패널을 만들어 **같은 함수**로 재고, 잡히는지 본다.
	var probe_panel := PanelContainer.new()
	probe_panel.custom_minimum_size = Vector2(40, 40)
	var probe_lbl := Label.new()
	# 줄바꿈 없이 아주 긴 한 줄 → 최소 폭이 글자 폭만큼 자란다(§2.32 의 기구 그대로).
	probe_lbl.text = "가".repeat(400)
	probe_panel.add_child(probe_lbl)
	main.modal_layer.add_child(probe_panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var ctl := _fit(probe_panel, vp)
	_emit("S3 양성 대조 — 일부러 만든 긴 라벨 패널: 폭 %.0f · 초과 %s %.0f" % [
		probe_panel.size.x, str(ctl["side"]), float(ctl["over"])])
	check(float(ctl["over"]) > 0.5,
		"재는 함수가 화면 밖 패널을 못 잡았다 — 이 프로브는 아무것도 안 재고 있다")
	check(probe_lbl.get_minimum_size().x > vp.x,
		"양성 대조 라벨이 화면보다 좁다 — 대조가 너무 약하다")
	probe_panel.queue_free()
	await get_tree().process_frame

	# ── S4. 스크린샷 (창 모드 전용) ───────────────────────────────────────────
	if DisplayServer.get_name() == "headless":
		_emit("S4 스크린샷 생략(headless) — 창 모드에서만 얻어진다")
	else:
		# (a) **최악 결산 화면** — §2.34 의 결함을 눈으로 남긴다(타워 단어 30 = 944px).
		field.tower_damage.clear()
		for k in 30:
			field.record_tower_damage(str(name_pool[k % name_pool.size()]), 100.0 * (k + 1))
		main._run_recorded = false
		main._on_game_over(true)
		await _settle(0.80)
		var gtex: ViewportTexture = get_viewport().get_texture()
		var gshot: Image = gtex.get_image() if gtex != null else null
		if gshot != null:
			_emit("S4 게임오버 스크린샷 err=%d %dx%d" % [
				gshot.save_png(GO_SHOT_PATH), gshot.get_width(), gshot.get_height()])
		else:
			_emit("S4 게임오버 스크린샷 실패 — get_image() 가 null")
		await _free_modals(main)
		# (b) 기존 라운드 정보
		main._on_stage_btn_pressed()
		for f in 10:
			await get_tree().process_frame
		var vtex: ViewportTexture = get_viewport().get_texture()
		var shot: Image = vtex.get_image() if vtex != null else null
		if shot != null:
			_emit("S4 스크린샷 err=%d %dx%d" % [
				shot.save_png(SHOT_PATH), shot.get_width(), shot.get_height()])
		else:
			_emit("S4 스크린샷 실패 — get_image() 가 null")

	if failures == 0:
		_emit("MODAL_FIT_PROBE_OK")
	else:
		_emit("MODAL_FIT_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
