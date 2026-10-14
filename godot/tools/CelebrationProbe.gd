extends Node
# 단어 완성 셀레브레이션이 **정말 '완성' 순간에만** 터지는지 재는 도구.
#
# 왜 필요한가 (2026-09-23):
# `JamoBelt.render_belt()` 의 '새 단어' 판정은 이렇다.
#
#     if not _last_parsed_words.has(syl):              # syl 은 맨 음절 ("가")
#         new_words.append(syl)
#     _last_parsed_words = preview_words.duplicate()   # 여기엔 "[가 타워]" 가 들어간다
#
# `_last_parsed_words` 에는 **서식이 붙은** 문자열이 들어가는데 비교는 **맨 음절**로 한다.
# 그래서 이 비교는 언제나 false 이고, `new_words` 는 매 렌더마다 **현재 완성된 단어 전부**가 된다.
# 결과: 타일을 드래그·회전·구매·교체할 때마다(= render_belt 가 불릴 때마다) "단어 완성"
# 배너가 다시 뜬다. 완성이 아닌데도.
#
# 2026-09-23 이전에는 배너만 다시 떠서 눈에 덜 띄었지만, 이 자리에 완성음을 연결하면서
# **소리까지 매 렌더마다** 울릴 뻔했다. 그래서 도구를 남긴다.
#
# 재는 것 (양방향이다 — 한쪽만 재면 반쪽짜리 검사다):
#   1) 단어를 실제로 완성하면 "단어 완성" 배너가 **나와야 한다**
#      (이게 없으면 셀레브레이션을 통째로 죽여도 이 도구는 통과한다)
#   2) 벨트에 단어가 파싱된 상태에서 **상태를 바꾸지 않고** render_belt() 를 다시 부르면
#      배너가 **나오면 안 된다**  ← 이 도구의 본체
#
# ⚠️ 이 도구를 쓸 때의 교훈 (첫 판이 헛통과했다):
#   첫 판은 '단어가 파싱됐는가' 를 `parsed_preview_label.text.contains("타워")` 로 봤다.
#   그 라벨의 **고정 접두사가 "자동 완성 타워: "** 라서, 아무 단어도 파싱되지 않은
#   "자동 완성 타워: 단어 조합 없음" 에서도 참이 나왔다 → 아무것도 재지 않고 통과했다.
#   지금은 `parsed_slots()` 로 '실제로 파싱된 슬롯 수' 를 센다.
#
# 실행: godot --path . res://tools/CelebrationProbe.tscn
#       (--headless 로도 돈다. GUI 입력이 필요 없다)

const JamoBeltScene = preload("res://scenes/tower/JamoBelt.tscn")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 300)
	add_child(host)
	var belt = JamoBeltScene.instantiate()
	host.add_child(belt)
	belt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame

	# ── 1. 실제로 파싱되는 단어를 하나 찾는다 ────────────────────────────────
	# `AutoArrange.required_jamo` 가 그 단어를 만드는 데 필요한 활자를 순서대로 펼쳐 준다
	# (합자는 구성 자모로 펼쳐진다). 그 활자를 전부 슬롯 0 에 넣고 정말 파싱되는지 본다 —
	# 파싱되지 않는 후보는 버린다. 그래야 '아무것도 못 재는 실행' 이 통과하지 못한다.
	var word := ""
	var chars: Array = []
	for data in WordDatabase.get_all_words():
		var w := str(data.get("word", ""))
		if w.length() != 2:
			continue
		var req: Array = AutoArrange.required_jamo(w)
		if req.size() < 2:
			continue
		var assign: Array = []
		for _i in range(req.size()):
			assign.append(0)
		belt.jamo_list.assign(req)
		belt.slot_assignments.assign(assign)
		belt.set_unlocked_slot_count(3)
		belt.render_belt()
		await get_tree().process_frame
		# ⚠️ 슬롯 수만 세면 **부분 파싱**을 '완성' 으로 받아들인다 — 예를 들어 `가속` 을
		# 노렸는데 `가` 만 나와도 통과해 버린다. 그러면 이 도구는 자기가 이름 붙인 단어가
		# 아니라 다른 사건을 재게 된다. 파싱 결과를 이어 붙여 **단어 전체**와 같을 때만 잡는다.
		if _parsed_text(belt) == w:
			word = w
			chars = req
			break

	var towers := _tower_count(belt)
	print("CELEBRATION_PROBE word=%s chars=%s parsed_slots=%d" % [word, str(chars), towers])

	# ── 2. 빈 상태로 되돌린다. 이 렌더가 `_last_parsed_words` 를 비운다 ──────
	# 활자 한 장(자음만)은 음절이 되지 않으므로 파싱 결과가 비어 있다.
	belt.jamo_list.assign(["ㄱ"])
	belt.slot_assignments.assign([0])
	belt.render_belt()
	await get_tree().process_frame
	var empty_towers := _tower_count(belt)
	_clear_banners()

	# ── 3. 진짜 '완성' — 배너가 **나와야 한다** ─────────────────────────────
	# 이 검사가 없으면, 셀레브레이션을 통째로 죽여도 이 도구는 통과한다.
	var assign: Array = []
	for _i in range(chars.size()):
		assign.append(0)
	belt.jamo_list.assign(chars)
	belt.slot_assignments.assign(assign)
	belt.render_belt()
	await get_tree().process_frame
	var on_completion := _banner_count()
	_clear_banners()

	# ── 4. 상태를 바꾸지 않고 한 번 더 — 배너가 **나오면 안 된다** ───────────
	belt.render_belt()
	await get_tree().process_frame
	var on_rerender := _banner_count()

	print("CELEBRATION_PROBE empty_state_slots=%d parsed_text=\"%s\"" % [empty_towers, _parsed_text(belt)])
	print("CELEBRATION_PROBE banners — on_completion=%d  unchanged_rerender=%d" % [on_completion, on_rerender])

	check(towers > 0, "단어를 파싱하는 조합을 찾지 못했습니다 — 이 실행은 아무것도 재지 못합니다")
	check(empty_towers == 0, "자음 한 장만 둔 상태에서 슬롯이 %d개 파싱됐습니다 — '빈 상태' 가 성립하지 않아 아래 검사가 무의미해집니다" % empty_towers)
	check(on_completion == 1, "단어를 실제로 완성했는데 '단어 완성' 배너가 %d개 떴습니다 (1개여야 한다) — 완성 연출이 죽었다" % on_completion)
	check(on_rerender == 0, "상태를 바꾸지 않고 다시 렌더했는데 '단어 완성' 배너가 %d개 떴습니다 — 완성이 아닌 렌더에서 셀레브레이션이 터진다" % on_rerender)

	if failures == 0:
		print("CELEBRATION_PROBE_OK")
	get_tree().quit(failures)

## 슬롯별 파싱 결과를 이어 붙인 것. **이게 의도한 단어와 같아야** '그 단어를 완성했다' 고
## 말할 수 있다 — 슬롯 수만 세면 부분 파싱(예: `가속` 을 노렸는데 `가` 만 나온 경우)을
## '완성' 으로 오인한다.
func _parsed_text(belt) -> String:
	var s := ""
	for p in belt.parsed_slots():
		if not p.is_empty():
			s += str(p["syllable"])
	return s

## 실제로 단어가 완성된 슬롯 수. 라벨 문구가 아니라 파싱 결과를 본다.
func _tower_count(belt) -> int:
	var n := 0
	for p in belt.parsed_slots():
		if not p.is_empty():
			n += 1
	return n

## 셀레브레이션 배너는 `get_tree().current_scene` 의 자식으로 붙는다
## (`_celebrate_new_words` 참고 — JamoBelt 의 자식으로 두면 레이아웃에 먹혀서 화면 루트에 붙인다).
## 이 도구를 단독 씬으로 돌리면 current_scene 이 이 노드다.
## queue_free 만으로는 이번 프레임에 자식으로 남아 다시 세어지므로 remove_child 를 먼저 한다.
func _clear_banners() -> void:
	for child in get_children():
		if child is Label and str(child.text).begins_with("단어 완성"):
			remove_child(child)
			child.queue_free()

func _banner_count() -> int:
	var n := 0
	for child in get_children():
		if child is Label and str(child.text).begins_with("단어 완성"):
			n += 1
	return n
