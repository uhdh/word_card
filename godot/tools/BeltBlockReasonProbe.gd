extends Node
# 비활성 버튼이 **사유를 말하는가** (감사 §5.2 18, 2026-09-23).
#
# 왜 문제였나:
# `disabled` 는 bool 하나라 **이유가 사라진다.** 자음/모음 구매 버튼은 '골드 부족' 과
# '벨트 가득' 이라는 **서로 다른 두 이유**로 막히는데, 플레이어에게는 둘 다 그냥 회색
# 버튼이다 — **코드가 아는 것을 화면이 안 보여 주는** 전형이다. 게다가 그 이유를 아는
# 코드(`current_gold < price or jamo_list.size() >= 30`)는 판정과 함께 계산되고
# 곧바로 버려진다.
#
# ⚠️ 이 도구가 재는 것 (한쪽만 재면 반쪽짜리 검사다):
#   §1 골드 부족  → 사유가 '골드' 다
#   §2 벨트 가득  → 사유가 '가득' 이다 — **골드가 아니다**(두 이유를 구별하는가)
#   §3 벨트 비어 있음 → 제거·교체의 사유가 '타일 없음' 이다
#   §4 **판정과 사유가 어긋나지 않는다** — 네 버튼 전부 `disabled == 사유 있음`.
#      ⚠️ 이게 핵심이다. 사유만 재면 "버튼은 눌리는데 툴팁은 '골드 부족' 이라고 쓰여 있는"
#      거짓말이 통과한다. 그래서 **모든 상태에서** 확인한다.
#   §5 용량 상수가 **한 곳**에서 온다 — `MAX_BELT_TILES` 를 넘겨 담을 수 없고,
#      구매 게이트도 같은 값을 쓴다
#
# ⚠️ 재지 못하는 것: 툴팁이 **마우스 호버에서 실제로 뜨는지**는 헤드리스로 확인할 수 없다.
#   여기서 재는 것은 '버튼이 무슨 말을 하는가' 이지 '플레이어가 그 말을 보는가' 가 아니다.
#
# 실행: godot --headless --path . res://tools/BeltBlockReasonProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 사유 문구의 표식. 사유가 없으면 툴팁에 이게 없어야 한다(본문에는 안 쓴다).
const MARK := "⚠️"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 네 버튼과 그 이름. 사유 검사가 **전부**를 훑게 하려고 한 곳에 모은다.
func _buttons(belt) -> Array:
	return [
		["자음 구매", belt.consonant_buy_button],
		["모음 구매", belt.vowel_buy_button],
		["타일 제거", belt.remove_tile_button],
		["활자 교체", belt.swap_tile_button],
	]

## 판정과 사유가 어긋나지 않는가 — **모든 상태에서** 부른다.
## 사유만 재면 "눌리는데 '골드 부족' 이라고 쓰여 있는" 거짓말이 통과한다.
func _check_consistency(belt, label: String) -> void:
	var bad: Array = []
	for pair in _buttons(belt):
		var btn: Button = pair[1]
		var says: bool = str(btn.tooltip_text).contains(MARK)
		if btn.disabled != says:
			bad.append("%s(disabled=%s·사유표시=%s)" % [pair[0], btn.disabled, says])
	print("BELT_BLOCK_PROBE consistent[%s] mismatched=%d %s" % [label, bad.size(), str(bad)])
	check(bad.is_empty(), "[%s] 판정과 사유가 어긋난다: %s" % [label, str(bad)])

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true

	var belt = main.jamo_belt
	var capacity: int = JamoBelt.MAX_BELT_TILES
	print("BELT_BLOCK_PROBE baseline gold=%d belt=%d capacity=%d" % [
		belt.current_gold, belt.jamo_list.size(), capacity])
	check(capacity == 30, "용량 상수가 %d 다 (30 이어야 한다)" % capacity)
	check(belt.jamo_list.size() > 0, "시작 벨트가 비어 있다 — 아래 검사가 성립하지 않는다")

	# ── 0. 기준선: 돈이 충분하고 벨트가 비어 있지 않다 → 넷 다 눌린다 ────────
	main.defense_field.gold = 999
	main._on_gold_changed(999)
	await get_tree().process_frame
	print("BELT_BLOCK_PROBE ok_state buy_disabled=%s remove_disabled=%s swap_disabled=%s" % [
		belt.consonant_buy_button.disabled, belt.remove_tile_button.disabled,
		belt.swap_tile_button.disabled])
	for pair in _buttons(belt):
		check(not pair[1].disabled, "[기준선] %s 가 막혀 있다 (돈·타일 다 있는데)" % pair[0])
	_check_consistency(belt, "기준선")

	# ── 1. 골드 부족 → 사유가 '골드' ────────────────────────────────────────
	main.defense_field.gold = 0
	main._on_gold_changed(0)
	await get_tree().process_frame
	print("BELT_BLOCK_PROBE gold0 buy_disabled=%s tooltip=%s" % [
		belt.consonant_buy_button.disabled,
		str(belt.consonant_buy_button.tooltip_text).replace("\n", " / ")])
	for pair in _buttons(belt):
		check(pair[1].disabled, "[골드 0] %s 가 눌린다 (골드가 없는데)" % pair[0])
		check(str(pair[1].tooltip_text).contains("골드가 부족"),
			"[골드 0] %s 의 사유에 '골드가 부족' 이 없다" % pair[0])
	# 보유/필요 숫자가 사유에 들어 있어야 '얼마나 모자란가' 를 안다.
	check(str(belt.consonant_buy_button.tooltip_text).contains("보유 0G"),
		"사유에 보유 골드가 없다 — 얼마나 모자란지 알 수 없다")
	_check_consistency(belt, "골드0")

	# ── 2. 벨트 가득 → 사유가 '가득' (골드가 아니다) ─────────────────────────
	main.defense_field.gold = 999
	main._on_gold_changed(999)
	while belt.jamo_list.size() < capacity:
		belt.add_jamo("ㄱ")
	belt.set_gold(999)  # add_jamo 는 set_gold 를 안 부른다 → 버튼을 강제로 갱신
	await get_tree().process_frame
	print("BELT_BLOCK_PROBE full belt=%d buy_disabled=%s tooltip=%s" % [
		belt.jamo_list.size(), belt.consonant_buy_button.disabled,
		str(belt.consonant_buy_button.tooltip_text).replace("\n", " / ")])
	check(belt.jamo_list.size() == capacity, "벨트를 %d장까지 못 채웠다" % capacity)
	check(belt.consonant_buy_button.disabled, "[가득] 구매가 눌린다 (담을 자리가 없는데)")
	check(str(belt.consonant_buy_button.tooltip_text).contains("가득"),
		"[가득] 사유에 '가득' 이 없다 — 두 이유를 구별하지 못한다")
	# ⚠️ 두 이유를 **구별**하는가. 골드가 충분한데 골드 탓을 하면 거짓말이다.
	check(not str(belt.consonant_buy_button.tooltip_text).contains("골드가 부족"),
		"[가득] 골드가 충분한데 '골드가 부족' 이라고 말한다 (사유가 틀렸다)")
	# 제거·교체는 가득과 무관하다 — 제거는 자리를 만들고, 교체는 자리를 안 늘린다.
	check(not belt.remove_tile_button.disabled,
		"[가득] 타일 제거가 막혔다 — 제거는 자리를 만든다")
	check(not belt.swap_tile_button.disabled,
		"[가득] 활자 교체가 막혔다 — 교체는 자리를 늘리지 않는다")
	_check_consistency(belt, "가득")

	# ── 3. 벨트 비어 있음 → 제거·교체의 사유가 '타일 없음' ──────────────────
	belt.jamo_list.clear()
	belt.slot_assignments.clear()
	belt.set_gold(999)
	await get_tree().process_frame
	print("BELT_BLOCK_PROBE empty remove_disabled=%s tooltip=%s" % [
		belt.remove_tile_button.disabled,
		str(belt.remove_tile_button.tooltip_text).replace("\n", " / ")])
	check(belt.remove_tile_button.disabled, "[빈 벨트] 타일 제거가 눌린다 (지울 타일이 없는데)")
	check(str(belt.remove_tile_button.tooltip_text).contains("타일이 없습니다"),
		"[빈 벨트] 사유에 '타일이 없습니다' 가 없다")
	check(str(belt.swap_tile_button.tooltip_text).contains("타일이 없습니다"),
		"[빈 벨트] 교체의 사유에 '타일이 없습니다' 가 없다")
	# 빈 벨트는 **구매를 막지 않는다** — 막으면 사유가 반대가 된다.
	check(not belt.consonant_buy_button.disabled,
		"[빈 벨트] 구매가 막혔다 — 빈 벨트는 구매를 막는 이유가 아니다")
	_check_consistency(belt, "빈벨트")

	# ── 4. 용량 상수가 **한 곳**에서 온다 ────────────────────────────────────
	# 넘겨 담을 수 없고(삽입), 구매 게이트도 같은 값을 쓴다(요청).
	main.defense_field.gold = 999
	main._on_gold_changed(999)
	while belt.jamo_list.size() < capacity:
		belt.add_jamo("ㄱ")
	var before: int = belt.jamo_list.size()
	belt.add_jamo("ㄴ")
	print("BELT_BLOCK_PROBE capacity fill=%d add_over=%d" % [before, belt.jamo_list.size()])
	check(belt.jamo_list.size() == before,
		"가득 찼는데 더 담겼다 (%d -> %d)" % [before, belt.jamo_list.size()])
	main.defense_field.gold = 999
	before = belt.jamo_list.size()
	main._on_tile_purchase_requested(false)
	print("BELT_BLOCK_PROBE capacity buy_gate=%d -> %d" % [before, belt.jamo_list.size()])
	check(belt.jamo_list.size() == before,
		"구매 게이트가 상수와 어긋난다 — 가득인데 구매가 됐다 (%d -> %d)" % [
			before, belt.jamo_list.size()])

	if failures == 0:
		print("BELT_BLOCK_PROBE_OK")
	get_tree().quit(failures)
