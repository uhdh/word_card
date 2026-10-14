# tools/HintSurfaceProbe.gd
# 슬롯 힌트의 **플레이어 표면** 계약 — 실제 문(door)에서 눈에 보이는 라벨까지.
#
# 왜 따로 필요한가: `tools/HintPickProbe.gd` 는 `AutoArrange.buildable_words_for()` 를
# **직접** 불러 규칙을 잠갔다. 그런데 플레이어는 그 함수를 부르지 않는다 — 슬롯의
# [힌트] 버튼을 누른다. §2.40 의 교훈 그대로다: **로직은 검증됐는데 입구는 안 봤다.**
# 이 프로브는 실제 문 `JamoBelt._show_slot_hint()` 를 두드려
#
#     [힌트] 버튼 → slot_targets[] → 트레이의 TargetLabel("목표 N음절")
#
# 사슬이 끊기지 않는지 본다. 규칙 자체(바닥·결정성·다양성)는 HintPickProbe 가 잠근다.
# 여기서 잠그는 것은 **그 규칙이 화면까지 도달하는가** 하나다.
#
# §5 는 예외로 **판정이 아니라 기록**이다 — 나침반(`_show_all_hints`)은 조합 최적화라
# 슬롯 버튼과 다른 답을 내는 것이 정상이고, 그 경계는 감독 결정 사항이다. 다만 §2.41
# 고침이 그 경계를 0% → 72.7% 로 벌려 놓았으므로, 크기와 빈도를 숫자로 남겨 둔다.
#
# 실행: godot --headless --path . res://tools/HintSurfaceProbe.tscn
extends Node

const AutoArrange = preload("res://scripts/core/AutoArrange.gd")
const JamoBeltScene = preload("res://scenes/tower/JamoBelt.tscn")

## 표본: 크기 1..10 마다 '만들 수 있는 것' 을 12개씩. 시드 고정 → 같은 표본.
## 상한이 10인 이유: 벨트 최대가 10장이고, 나침반은 **조합**이라 슬롯이 많을수록
## 슬롯 버튼과 갈라지기 쉽다. 작은 봉지만 재면 '갈라져도 1음절 이내' 를 과대 주장하게 된다.
const SEED := 20261002
const PER_SIZE := 12
const MAX_SIZE := 10

var failures := 0


func _ready() -> void:
	var words: Array = WordDatabase.get_all_words()
	var belts := _sample_belts(words)
	print("=== 슬롯 힌트의 플레이어 표면 계약 ===")
	print("표본 봉지 %d개 (1~%d장 · 시드 %d · 크기마다 만들 수 있는 것 %d개)"
		% [belts.size(), MAX_SIZE, SEED, PER_SIZE])

	_s1_door_to_label(belts, words)
	_s2_floor_on_slot_tiles(belts, words)
	_s3_determinism_through_the_door(belts)
	_s4_lock_narrows_the_pool(words)
	_s5_compass_boundary(belts)
	_s6_reported_belt()

	if failures == 0:
		print("\nHINT_SURFACE_PROBE_OK")
	else:
		print("\nHINT_SURFACE_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)


## §1 사슬 — [힌트] 문을 누르면 `slot_targets` 가 순위 함수의 답이고,
##    그 답이 트레이의 `TargetLabel` 로 그대로 도착하는가.
func _s1_door_to_label(belts: Array, words: Array) -> void:
	var slots := 0
	var door_mismatch := 0
	var label_missing := 0
	var label_wrong := 0
	var button_wrong := 0
	var stale_before := 0
	var unbuildable := 0
	var first := ""
	for belt_tiles in belts:
		var belt := _make_belt(belt_tiles)
		for slot in range(belt.unlocked_slot_count):
			# 누르기 **전** — 목표 라벨이 이미 있으면 안 된다.
			if _find_in_tray(_tray_for(belt, slot), "TargetLabel") != null:
				stale_before += 1
				if first == "":
					first = "슬롯 %d: 누르기 전에 이미 목표 라벨 — %s" % [slot, str(belt_tiles)]
			belt._show_slot_hint(slot)
			slots += 1

			var available: Array[String] = []
			for i in belt._slot_available_indices(slot):
				available.append(belt.jamo_list[i])
			var ranked: Array = AutoArrange.buildable_words_for(available, words, 1)
			var expected := str(ranked[0].get("word", "")) if not ranked.is_empty() else ""
			var target: String = belt.slot_targets[slot]

			if target != expected:
				door_mismatch += 1
				if first == "":
					first = "슬롯 %d: 문의 답 '%s' ≠ 순위 함수 '%s' (%s)" % [slot, target, expected, str(belt_tiles)]
			if target != "" and AutoArrange.tile_indices_for(target, available, []).is_empty():
				unbuildable += 1
				if first == "":
					first = "슬롯 %d: 목표 '%s' 를 이 슬롯 타일로 못 만든다" % [slot, target]

			var tray := _tray_for(belt, slot)
			var label := _find_in_tray(tray, "TargetLabel")
			if target == "":
				pass
			elif label == null:
				label_missing += 1
				if first == "":
					first = "슬롯 %d: 목표 '%s' 인데 트레이에 라벨이 없다" % [slot, target]
			elif str(label.text) != "목표 %d음절" % target.length():
				label_wrong += 1
				if first == "":
					first = "슬롯 %d: 라벨 '%s' ≠ '목표 %d음절'" % [slot, str(label.text), target.length()]

			# 토글의 '무장' 상태 — 힌트가 서 있으면 버튼은 취소여야 한다.
			var btn := _find_in_tray(tray, "HintButton")
			if btn != null and str(btn.text) != "취소":
				button_wrong += 1
				if first == "":
					first = "슬롯 %d: 힌트가 서 있는데 버튼이 '%s'" % [slot, str(btn.text)]
		belt.free()
	print("\n§1 실제 문 → 목표 → 라벨 (슬롯 %d개)" % slots)
	print("  문의 답 ≠ 순위 함수: %d" % door_mismatch)
	print("  목표가 있는데 라벨 없음: %d" % label_missing)
	print("  라벨 문구 틀림: %d" % label_wrong)
	print("  힌트 뒤 버튼이 '취소' 아님: %d" % button_wrong)
	print("  누르기 전에 이미 목표 라벨: %d" % stale_before)
	print("  이 슬롯 타일로 못 만드는 목표: %d" % unbuildable)
	check(slots >= 200, "The door must actually be pressed across the sample (pressed %d)" % slots)
	check(door_mismatch == 0, "The slot button must return the shared ranking function's pick (%d disagreed, first: %s)"
		% [door_mismatch, first])
	check(label_missing == 0, "A target must reach the tray as a TargetLabel (%d missing)" % label_missing)
	check(label_wrong == 0, "The TargetLabel must say the target's syllable count (%d wrong)" % label_wrong)
	check(button_wrong == 0, "The hint button must read '취소' while a hint stands (%d wrong)" % button_wrong)
	check(stale_before == 0, "The tray must not show a target before the hint is pressed (%d stale)" % stale_before)
	check(unbuildable == 0, "The target must be buildable from the slot's own tiles (%d not)" % unbuildable)


## §2 바닥 — **슬롯 버튼이 실제로 본 타일** 위에서도 지켜지는가.
##    HintPickProbe 는 봉지 전체로 쟀다. 여기서는 문이 쓰는 집합(`_slot_available_indices`)으로 잰다.
func _s2_floor_on_slot_tiles(belts: Array, words: Array) -> void:
	var checked := 0
	var below := 0
	var worst_ratio := 1.0
	var worst_note := ""
	for belt_tiles in belts:
		var belt := _make_belt(belt_tiles)
		belt._show_slot_hint(0)
		var target: String = belt.slot_targets[0]
		if target == "":
			belt.free()
			continue
		var available: Array[String] = []
		for i in belt._slot_available_indices(0):
			available.append(belt.jamo_list[i])
		var best_value := 0
		var best_word := ""
		for data in words:
			var w := str(data.get("word", ""))
			if AutoArrange.tile_indices_for(w, available, []).is_empty():
				continue
			var v := AutoArrange.word_value(w, data)
			if v > best_value:
				best_value = v
				best_word = w
		if best_value <= 0:
			belt.free()
			continue
		checked += 1
		var target_value := AutoArrange.word_value(target, WordDatabase.get_word_data(target))
		var ratio := float(target_value) / float(best_value)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst_note = "봉지 %s — 목표 %s %d vs 최강 %s %d" % [str(belt_tiles), target, target_value, best_word, best_value]
		if target_value < int(round(float(best_value) * AutoArrange.HINT_KEEP_RATIO)):
			below += 1
		belt.free()
	print("\n§2 바닥 — 슬롯 버튼이 본 타일 위에서 (HINT_KEEP_RATIO = %.2f)" % AutoArrange.HINT_KEEP_RATIO)
	print("  확인한 봉지 %d개 · 바닥 아래 %d개" % [checked, below])
	print("  최악 비율 %.3f — %s" % [worst_ratio, worst_note])
	check(checked >= 50, "The floor must be checked through the door (checked %d)" % checked)
	check(below == 0, "The slot button must never pick below the keep ratio (%d belts)" % below)


## §3 결정성 — 실제 문을 두 번 눌러도(지우고 다시) 같은 답인가.
##    그리고 '지우기' 가 목표와 라벨을 **실제로** 지우는가.
func _s3_determinism_through_the_door(belts: Array) -> void:
	var checked := 0
	var unstable := 0
	var value_not_cleared := 0
	var label_not_cleared := 0
	var first := ""
	for belt_tiles in belts:
		var belt := _make_belt(belt_tiles)
		belt._show_slot_hint(0)
		var a: String = belt.slot_targets[0]
		if a == "":
			belt.free()
			continue
		# 지우기 — 같은 문을 다시 눌러 토글한다.
		belt._show_slot_hint(0)
		if belt.slot_targets[0] != "":
			value_not_cleared += 1
		if _find_in_tray(_tray_for(belt, 0), "TargetLabel") != null:
			label_not_cleared += 1
		# 다시 세우기.
		belt._show_slot_hint(0)
		var b: String = belt.slot_targets[0]
		checked += 1
		if a != b:
			unstable += 1
			if first == "":
				first = "%s — %s / %s" % [str(belt_tiles), a, b]
		belt.free()
	print("\n§3 결정성 (문을 두 번 · 표본 %d)" % checked)
	print("  지웠는데 목표가 남음: %d · 지웠는데 라벨이 남음: %d" % [value_not_cleared, label_not_cleared])
	print("  다시 눌렀을 때 답이 바뀐 경우: %d — %s" % [unstable, first])
	check(checked >= 40, "Determinism must be checked through the door (checked %d)" % checked)
	check(value_not_cleared == 0, "Toggling the hint off must clear the target (%d left)" % value_not_cleared)
	check(label_not_cleared == 0, "Toggling the hint off must remove the TargetLabel (%d left)" % label_not_cleared)
	check(unstable == 0, "The same belt must give the same hint through the door (%d unstable, first: %s)"
		% [unstable, first])


## §4 잠금 — 고정이 실제로 **다른 슬롯의 후보를 좁히는가**.
##    이것이 슬롯별 힌트가 갈라지는 유일한 기구다(안 잠그면 모든 슬롯이 같은 답을 본다).
func _s4_lock_narrows_the_pool(words: Array) -> void:
	# 1번 슬롯이 '구름' 을 세울 수 있는 벨트를 하나 만든다.
	var tiles: Array[String] = ["ㄱ", "ㅜ", "ㄹ", "ㅡ", "ㅁ"]
	# 조합에 쓸 여분 둘 — 다른 슬롯 몫.
	tiles.append("ㅅ")
	tiles.append("ㅏ")
	var belt := _make_belt(tiles)
	var before: Array = belt._slot_available_indices(1).duplicate()
	belt._show_slot_hint(0)
	var first_target: String = belt.slot_targets[0]
	var locked_word := "구름"
	belt.slot_targets[0] = locked_word
	belt._toggle_slot_lock(0)
	var locked: bool = belt.slot_locked[0]
	var after: Array = belt._slot_available_indices(1)
	var reserved: Array = belt.slot_reserved[0]
	var overlap := 0
	for i in reserved:
		if after.has(i):
			overlap += 1
	var second_target := ""
	if locked:
		belt._show_slot_hint(1)
		second_target = belt.slot_targets[1]
	print("\n§4 잠금이 후보를 좁히는가")
	print("  벨트 %s · 1번 슬롯 목표 %s → 고정 '%s' (고정됨=%s)" % [str(tiles), first_target, locked_word, str(locked)])
	print("  2번 슬롯 후보 %d장 → 고정 후 %d장 (고정된 %d장 중 겹침 %d)"
		% [before.size(), after.size(), reserved.size(), overlap])
	print("  고정 후 2번 슬롯 목표: '%s'" % second_target)
	check(locked, "Locking slot 1 must actually lock it")
	check(reserved.size() > 0, "Locking must reserve the word's tiles (%d reserved)" % reserved.size())
	check(overlap == 0, "A locked slot's tiles must leave the other slot's candidates (%d overlap)" % overlap)
	check(after.size() < before.size(), "Locking must shrink the other slot's candidate set (%d → %d)"
		% [before.size(), after.size()])
	belt.free()


## §5 경계(보고 전용) — 나침반(`_show_all_hints`)은 **다른 함수**(`best_word_set_for`)를 쓴다.
##    그 함수는 `Σ(DPS + tier)` 를 최대화하는 **분할(partition)** 을 빔 서치로 찾는다 —
##    그래서 한 슬롯의 몫은 '그 슬롯 혼자 낼 수 있는 최강' 이 아니라 **계획의 지분**이다.
##    슬롯 버튼은 반대로 '이 슬롯 혼자' 를 답한다. 두 화면이 다른 질문에 답하므로 갈라진다.
##
##    ⚠️ **두 화면의 답을 합산해 비교하면 안 된다.** 슬롯 버튼은 저마다 벨트 **전체**에서
##    답하므로 같은 타일을 슬롯 수만큼 세게 된다 — 달성 불가능한 상한이라 어떤 계획도
##    이길 수 없다. 공정한 질문은 **그 계획을 동시에 세울 수 있는가** 하나뿐이다.
##
##    실측(표본 108봉지 · 시드 20261002): 슬롯 183개 중 **같은 답 50 · 다른 답 133(72.7%)**.
##    갈라진 133개 중 음절 수가 같은 것 28 · 2음절 이상 벌어진 것 **7**
##    (예: `ㄴㅁㅡㅂㅅㅜㅁㅅㅜ` 슬롯0 — 나침반 '막'(1음절) vs 슬롯버튼 '마그마'(3음절)).
##    나침반 계획은 **54/54 봉지에서 동시에 세울 수 있었다** — 계획 자체는 성립한다.
##
##    고침 **전에는 두 화면이 사실상 같은 답**을 냈다(슬롯 버튼이 곧 나침반의 같은 순번이었다).
##    이 갈라짐은 감독이 고른 대안 C 의 **값**이고, 남은 판단은 감독 몫이다 — 여기서는
##    얼마나 자주·얼마나 크게 갈라지는지 **기록만** 한다(단언 아님).
func _s5_compass_boundary(belts: Array) -> void:
	var checked := 0
	var agree := 0
	var differ := 0
	var differ_same_syl := 0
	var differ_big_gap := 0
	var button_stronger := 0
	var compass_stronger := 0
	var plans := 0
	var plans_buildable := 0
	var example := ""
	var example_gap := ""
	for belt_tiles in belts:
		var belt := _make_belt(belt_tiles)
		belt._show_all_hints()
		var compass: Array = []
		for slot in range(belt.unlocked_slot_count):
			compass.append(str(belt.slot_targets[slot]))
		# ⚠️ 나침반 계획의 **총합을 슬롯 버튼 합과 비교하면 안 된다** — 슬롯 버튼은 각자
		# 벨트 **전체**에서 답하므로 같은 타일을 세 번 세게 된다(달성 불가능한 상한).
		# 공정한 질문은 하나다: **그 계획을 동시에 세울 수 있는가**(타일을 두 번 안 쓰는가).
		var used: Array = []
		var plan_ok := true
		var plan_words := 0
		for slot in range(belt.unlocked_slot_count):
			if compass[slot] == "":
				continue
			plan_words += 1
			var idx: Array = AutoArrange.tile_indices_for(compass[slot], belt.jamo_list, used)
			if idx.is_empty():
				plan_ok = false
				break
			used.append_array(idx)
		if plan_words >= 2:
			plans += 1
			if plan_ok:
				plans_buildable += 1
		var button: Array = []
		for slot in range(belt.unlocked_slot_count):
			belt._clear_slot_hint(slot)
			belt._show_slot_hint(slot)
			button.append(str(belt.slot_targets[slot]))
		for slot in range(belt.unlocked_slot_count):
			if compass[slot] == "" or button[slot] == "":
				continue
			checked += 1
			if compass[slot] == button[slot]:
				agree += 1
				continue
			differ += 1
			var gap := absi(compass[slot].length() - button[slot].length())
			if gap == 0:
				differ_same_syl += 1
			if gap >= 2:
				differ_big_gap += 1
				if example_gap == "":
					example_gap = "%s 슬롯%d — 나침반 '%s'(%d음절) vs 슬롯버튼 '%s'(%d음절)" % [
						str(belt_tiles), slot, compass[slot], compass[slot].length(),
						button[slot], button[slot].length()]
			var cv := AutoArrange.word_value(compass[slot], WordDatabase.get_word_data(compass[slot]))
			var bv := AutoArrange.word_value(button[slot], WordDatabase.get_word_data(button[slot]))
			if bv > cv:
				button_stronger += 1
			elif cv > bv:
				compass_stronger += 1
			if example == "":
				example = "%s 슬롯%d — 나침반 '%s' vs 슬롯버튼 '%s'" % [str(belt_tiles), slot, compass[slot], button[slot]]
		belt.free()
	print("\n§5 나침반 vs 슬롯 버튼 (경계 · 보고 전용)")
	print("  같은 답 %d · 다른 답 %d (%.1f%% 일치)"
		% [agree, differ, 100.0 * float(agree) / maxf(1.0, float(checked))])
	print("  다른 답 중 **음절 수가 같은** 것 %d · 2음절 이상 벌어진 것 %d" % [differ_same_syl, differ_big_gap])
	print("  그 슬롯 하나만 보면 — 슬롯버튼이 더 셈 %d · 나침반이 더 셈 %d (나침반은 총합을 키우므로 낮은 것이 정상)"
		% [button_stronger, compass_stronger])
	print("  나침반 계획을 **동시에** 세울 수 있는 봉지 %d / %d (두 단어 이상인 계획만 셈)"
		% [plans_buildable, plans])
	if example != "":
		print("  예: %s" % example)
	if example_gap != "":
		print("  큰 격차 예: %s" % example_gap)


## §6 감독이 보고한 벨트 그대로 — 화면에 무엇이 도착하는지 한 줄로 남긴다.
func _s6_reported_belt() -> void:
	var belt: JamoBelt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([
		String.chr(0x3131), String.chr(0x3161),
		String.chr(0x3134), String.chr(0x315C), String.chr(0x3139),
		String.chr(0x3131), String.chr(0x315C), String.chr(0x3134),
		String.chr(0x3161), String.chr(0x3141)])
	belt.slot_assignments.assign([1, 1, 2, 2, 2, 2, 2, 2, 2, -1])
	belt.render_belt()
	belt._show_slot_hint(2)
	var target: String = belt.slot_targets[2]
	var tray := _tray_for(belt, 2)
	var label := _find_in_tray(tray, "TargetLabel")
	var label_text := str(label.text) if label != null else "(라벨 없음)"
	# 같은 벨트에 나침반은 무엇을 답하는가 — 두 화면의 경계를 이 벨트에서도 남긴다.
	belt._clear_slot_hint(2)
	belt._show_all_hints()
	var compass: Array = []
	for slot in range(belt.unlocked_slot_count):
		compass.append(str(belt.slot_targets[slot]))
	print("\n§6 감독 보고 벨트")
	print("  3번 슬롯 목표 '%s' (%d음절) · 트레이 라벨 '%s'" % [target, target.length(), label_text])
	print("  같은 벨트에 나침반은 %s" % str(compass))
	print("  (같은 벨트로 만들 수 있는 최강은 2음절 53.1 DPS — 예전엔 '목표 1음절' 이 나왔다)")
	check(target.length() >= 2, "The reported belt's third slot must not be aimed at a 1-syllable tower (got '%s')" % target)
	check(label != null and str(label.text) == "목표 %d음절" % target.length(),
		"The reported belt's tray must show the target's syllable count (got '%s')" % label_text)
	belt.free()


## 표본 봉지 — 크기마다 '만들 수 있는 것' 을 PER_SIZE 개. 시드 고정이라 매번 같다.
func _sample_belts(words: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pool: Array = HangulEngine.ALL_DRAW_POOL
	var out: Array = []
	for size in range(1, MAX_SIZE + 1):
		var kept := 0
		var guard := 0
		while kept < PER_SIZE and guard < 8000:
			guard += 1
			var bag: Array = []
			for _i in range(size):
				bag.append(pool[rng.randi_range(0, pool.size() - 1)])
			var owned: Array[String] = []
			for t in bag:
				owned.append(str(t))
			if AutoArrange.buildable_words_for(owned, words, 1).is_empty():
				continue
			out.append(bag)
			kept += 1
	return out


## 봉지 하나로 JamoBelt 를 세운다. 타일은 전부 1번 슬롯에 둔다 —
## 슬롯 힌트가 보는 집합은 '이 슬롯이 쓸 수 있는 타일'(= 아무것도 안 잠갔으면 전부)이라
## 배치와 무관하다. 배치가 답을 바꾸는 경우는 §4 가 따로 다룬다.
func _make_belt(tiles: Array) -> JamoBelt:
	var belt: JamoBelt = JamoBeltScene.instantiate()
	add_child(belt)
	var names: Array[String] = []
	for t in tiles:
		names.append(str(t))
	belt.jamo_list.assign(names)
	var assign: Array[int] = []
	for _i in range(names.size()):
		assign.append(0)
	belt.slot_assignments.assign(assign)
	belt.render_belt()
	return belt


## 트레이 하나를 슬롯 번호로 찾는다. `tiles_container` 의 직계 자식이 JamoTray 다.
func _tray_for(belt: JamoBelt, slot_index: int) -> Node:
	if belt.tiles_container == null:
		return null
	for c in belt.tiles_container.get_children():
		var s = c.get("slot_index")
		if s != null and int(s) == slot_index:
			return c
	return null


func _find_in_tray(tray: Node, node_name: String) -> Node:
	if tray == null:
		return null
	return tray.find_child(node_name, true, false)


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	print("  ✗ %s" % message)
