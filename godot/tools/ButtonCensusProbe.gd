extends Node
# 버튼 전수 조사 — **어느 상태에서 무엇이 막히고, 그 이유를 말하는가.**
# (감사 §2.40 의 *전수* 판, 2026-10-06)
#
# §2.40 은 밀어내기 버튼 **하나**를 팠다. 그 절의 §2 교훈은 *"같은 사실을 두 표면이 다르게
# 말할 수 있다"* 였고, §4 는 *"막힌 사유를 말하지 않는다"* 였다. 이 도구는 그 둘을
# **전체 버튼**으로 넓혀 **모집단을 센다** — 표본 하나로 "고립된 결함" 이라 부르지 않기 위해서다.
#
# ⚠️ 이 도구가 재는 것:
#   §0 모집단 — 보이는 Button 이 몇 개이고, 그중 몇 개가 **조건부로** 막히는가
#      (조건부 = 어떤 상태에서는 눌리고 어떤 상태에서는 막힌다. 영구 비활성은 다른 문제다)
#   §1 상태별 (text · disabled · 사유 표식) 전문
#   §2 판정 — **조건부로 막히는 버튼은 막힌 상태에서 사유를 말해야 한다**
#      ⚠️ 사유의 채널은 둘 다 인정한다: 툴팁의 `⚠️`(벨트·상점 규칙) **또는** 글자 자체가
#      상태를 말하는 것(`주사위 소진` 처럼 — 그건 라벨이 곧 사유다).
#   §3 보고 — 영구 비활성 · 영구 활성 (판정 아님)
#
# ⚠️ 판정하지 않는 것: *"이 버튼이 이 상태에서 눌려야 하는가"*. 그건 설계이고 감독 몫이다.
#   여기서 재는 것은 **막혔는데 말을 안 하는가** 하나뿐이다.
#
# 실행: godot --headless --path . res://tools/ButtonCensusProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 사유 표식 — `BeltBlockReasonProbe`/`ShopReasonProbe` 와 같은 규칙.
const MARK := "⚠️"

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


## 화면에 보이는 Button 을 전부 모은다. 내부 자식은 뺀다(엔진 팝업 등).
func _visible_buttons(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).is_visible_in_tree():
			out.append(n)
		for c in n.get_children(false):
			stack.append(c)
	return out


## 버튼 하나를 **상태와 무관한** 키로 식별한다. 경로는 재건축되면 사라지고
## (`@Button@86`→`@91`), 글자는 상태에 따라 바뀐다(`주사위 소진`).
## 그래서 부모 경로의 꼬리 + 노드 이름을 쓴다.
func _key(b: Button) -> String:
	var p: Node = b.get_parent()
	var pn: String = str(p.name) if p != null else "?"
	return "%s/%s" % [pn, str(b.name)]


## 상태를 만들고 그때 보이는 버튼의 (text, disabled, 사유) 를 기록한다.
func _census(main, label: String, states: Dictionary) -> Dictionary:
	var rec := {}
	for b in _visible_buttons(main):
		var tip := str(b.tooltip_text)
		rec[_key(b)] = {
			"text": str(b.text),
			"disabled": b.disabled,
			"mark": tip.contains(MARK),
			"tip": tip,
		}
	print("BUTTON_CENSUS [%s] visible_buttons=%d disabled=%d" % [
		label, rec.size(), rec.values().filter(func(v): return v["disabled"]).size()])
	for k in rec:
		var v: Dictionary = rec[k]
		if v["disabled"]:
			print("    DISABLED %-38s text='%s' mark=%s" % [k, v["text"], v["mark"]])
	states[label] = rec
	return rec


func _ready() -> void:
	print("")
	print("=== 버튼 전수 — 막힌 버튼이 사유를 말하는가 ===")
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	# ⚠️ 여기서 `_is_loading_state = true` 로 **되돌리지 않는다.** `start_new_game()` 이
	#    `:1479` 에서 이미 false 로 풀어 놓았고, 다시 얼리면 `save_game_state()` 가
	#    `:614` 에서 즉시 return 해 **자동 저장이 아예 안 일어난다** — 그러면 `btn_load` 가
	#    영구 비활성으로 보인다. 첫 판이 정확히 그렇게 새서 *"이어하기가 영영 막혀 있다"* 로
	#    읽을 뻔했다(프로브가 만든 상태를 결함으로 셀 뻔한 §2.36·§2.39 부류).

	var belt = main.jamo_belt
	var states := {}

	# ── 상태 여섯을 **진짜 문**으로 만든다 ──────────────────────────────────
	main.defense_field.gold = 999
	main._on_gold_changed(999)
	await get_tree().process_frame
	_census(main, "웨이브 중 · 골드 충분", states)

	main.defense_field.gold = 0
	main._on_gold_changed(0)
	await get_tree().process_frame
	_census(main, "골드 0", states)

	main.defense_field.gold = 999
	main._on_gold_changed(999)
	while belt.jamo_list.size() < JamoBelt.MAX_BELT_TILES:
		belt.add_jamo("ㄱ")
	belt.set_gold(999)
	await get_tree().process_frame
	_census(main, "벨트 가득", states)

	# 웨이브 밖 — 시그널의 **진짜 문**으로 만든다.
	main.defense_field.is_wave_running = false
	main._on_wave_status_changed(1, 3, 1, 20, false)
	await get_tree().process_frame
	_census(main, "웨이브 밖", states)

	# 정지
	main.set_speed_scale(0.0)
	await get_tree().process_frame
	_census(main, "정지", states)
	main.set_speed_scale(1.0)

	# ── §2 판정: *가졌다가 잃은* 버튼은 막힌 상태에서 사유를 말해야 한다 ────
	#
	# ⚠️ 계약을 **"조건부면 무조건 사유"** 로 잡으면 정상이 빨개진다 — 첫 판이 그랬다.
	#    `BtnLoad`(이어하기)는 **아직 세이브가 없는** 두 상태에서 막히는데, 그건
	#    "네가 쓴 걸 거절한다" 가 아니라 **"아직 줄 게 없다"** 다. 설명할 사유가 없다.
	#    사유가 필요한 순간은 §2.40-3 이 지목한 그 순간이다 — **다 쓴 뒤의 회색 버튼**,
	#    즉 *어느 상태에서는 눌렸는데 그 뒤 상태에서 막히는* 경우.
	#    ⇒ 그래서 **처음 눌릴 수 있게 된 상태 이후의 비활성만** 판정한다.
	#    (상태 순서는 삽입 순서 = 내가 만든 순서다. Dictionary 가 순서를 지킨다.)
	var order: Array = states.keys()
	var keys := {}
	for label in order:
		for k in states[label]:
			keys[k] = true
	print("BUTTON_CENSUS keys_seen=%d states=%d" % [keys.size(), order.size()])

	var offenders: Array = []
	var conditional: Array = []
	var always_disabled: Array = []
	var always_enabled: Array = []
	var not_yet: Array = []
	for k in keys:
		var seen := []
		var first_enabled := -1
		for i in range(order.size()):
			var label: String = order[i]
			if states[label].has(k):
				seen.append(label)
				if first_enabled < 0 and not states[label][k]["disabled"]:
					first_enabled = i
		if seen.size() < 2:
			continue
		var disabled_count := 0
		for label in seen:
			if states[label][k]["disabled"]:
				disabled_count += 1
		if disabled_count == 0:
			always_enabled.append(k)
		elif disabled_count == seen.size():
			always_disabled.append(k)
		else:
			conditional.append(k)
			for i in range(order.size()):
				var label: String = order[i]
				if not states[label].has(k) or not states[label][k]["disabled"]:
					continue
				var v: Dictionary = states[label][k]
				if first_enabled < 0 or i < first_enabled:
					not_yet.append("%s @ %s" % [k, label])
					continue
				# 사유의 두 채널: 툴팁의 표식, 또는 글자 자체가 상태를 말하는 것.
				var says_state: bool = bool(v["mark"]) or str(v["text"]) != str(states[order[first_enabled]][k]["text"])
				if not says_state:
					offenders.append("%s @ %s (text='%s')" % [k, label, v["text"]])

	print("BUTTON_CENSUS conditional=%d always_disabled=%d always_enabled=%d" % [
		conditional.size(), always_disabled.size(), always_enabled.size()])
	print("BUTTON_CENSUS always_disabled_list=%s" % str(always_disabled))
	print("BUTTON_CENSUS not_yet_available(보고·판정아님)=%d %s" % [not_yet.size(), str(not_yet)])
	print("BUTTON_CENSUS offenders=%d" % offenders.size())
	for o in offenders:
		print("    OFFENDER %s" % o)

	check(not conditional.is_empty(),
		"§2 조건부로 막히는 버튼이 하나도 없다 — 이 프로브의 전제가 성립하지 않는다(상태를 못 만들었다)")
	check(offenders.is_empty(),
		"§2 가졌다가 잃은 버튼인데 사유를 안 말한다 (%d개): %s" % [offenders.size(), str(offenders)])

	if failures == 0:
		print("BUTTON_CENSUS_PROBE_OK")
	else:
		print("BUTTON_CENSUS_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
