# tools/HintPickProbe.gd
# 힌트 선택 규칙(감독 결정 2026-10-02 · 대안 C)의 계약을 잠근다.
#
# 규칙: `AutoArrange.buildable_words_for()` 가 돌려주는 **첫 원소**는
#       **DPS 1위의 `HINT_KEEP_RATIO`(0.8) 이상인 후보 중에서 봉지 시드로 고른 하나**다.
#       나머지 원소는 세기 순서 그대로 — 조합 추천 패널이 여섯 줄을 유지해야 한다.
#
# 왜 판정형이 따로 필요한가: `tests/test_tower_traits.gd` 의 슬롯 힌트 테스트 첫 단언은
# **자기 참조**다 — `belt.slot_targets[2]` 를 **같은 함수의 출력**과 비교하므로 그 함수가
# 무엇을 고르든 초록이다. 그래서 **바닥 · 결정성 · 다양성 · 패널 줄 수**를 여기서 잠근다.
#
# 실행: godot --headless --path . res://tools/HintPickProbe.tscn
extends Node

const AutoArrange = preload("res://scripts/core/AutoArrange.gd")

## 1~3장 전수(815). 전수 15503 은 `_tiles_for_word` 가 매번 음절을 분해해 너무 느리다.
const MAX_BELT := 3
const SEED := 20261002
const SAMPLE := 220

var failures := 0


func _ready() -> void:
	var words: Array = WordDatabase.get_all_words()
	var belts := _multisets(HangulEngine.ALL_DRAW_POOL, MAX_BELT)
	print("=== 힌트 선택 규칙 (대안 C) 계약 ===")
	print("봉지 %d개 (ALL_DRAW_POOL %d종 · 1~%d장 전수)"
		% [belts.size(), HangulEngine.ALL_DRAW_POOL.size(), MAX_BELT])

	_s1_floor(belts, words)
	_s2_determinism(belts, words)
	_s3_variety(belts, words)
	_s4_panel_keeps_the_list(belts, words)

	if failures == 0:
		print("\nHINT_PICK_PROBE_OK")
	else:
		print("\nHINT_PICK_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)


## §1 바닥 — 뽑힌 것이 DPS 1위의 `HINT_KEEP_RATIO` 이상인가. 그리고 만들 수 있는 것인가.
func _s1_floor(belts: Array, words: Array) -> void:
	var checked := 0
	var worst_ratio := 1.0
	var worst_note := ""
	var below := 0
	var first_below := ""
	for belt in belts:
		var owned: Array[String] = []
		for t in belt:
			owned.append(str(t))
		var pick: Array = AutoArrange.buildable_words_for(owned, words, 1)
		if pick.is_empty():
			continue
		checked += 1
		var picked := str(pick[0].get("word", ""))
		# 봉지 전체에서 만들 수 있는 **가장 센** 것을 따로 구한다(힌트와 다른 경로로).
		var best_value := 0
		var best_word := ""
		for data in words:
			var w := str(data.get("word", ""))
			if AutoArrange.tile_indices_for(w, owned, []).is_empty():
				continue
			var v := AutoArrange.word_value(w, data)
			if v > best_value:
				best_value = v
				best_word = w
		if best_value <= 0:
			continue
		check(not AutoArrange.tile_indices_for(picked, owned, []).is_empty(),
			"The hint must pick something the belt can actually build (picked '%s', belt %s)"
				% [picked, str(owned)])
		var picked_value := AutoArrange.word_value(picked, WordDatabase.get_word_data(picked))
		var ratio := float(picked_value) / float(best_value)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst_note = "봉지 %s — 뽑힘 %s %d vs 최강 %s %d" % [str(owned), picked, picked_value, best_word, best_value]
		var floor_value := int(round(float(best_value) * AutoArrange.HINT_KEEP_RATIO))
		if picked_value < floor_value:
			below += 1
			if first_below == "":
				first_below = "봉지 %s — 뽑힘 %s %d < 바닥 %d (최강 %s %d)" % [
					str(owned), picked, picked_value, floor_value, best_word, best_value]
	print("\n§1 바닥 (HINT_KEEP_RATIO = %.2f)" % AutoArrange.HINT_KEEP_RATIO)
	print("  확인한 봉지 %d개 · 바닥 아래로 내려간 봉지 %d개" % [checked, below])
	print("  최악 비율 %.3f — %s" % [worst_ratio, worst_note])
	check(below == 0, "The hint must never pick below the keep ratio (%d belts, first: %s)"
		% [below, first_below])
	check(checked >= 300, "The floor must actually be checked over the population (checked %d)" % checked)


## §2 결정성 — 같은 봉지는 같은 답. 타일 **순서**가 달라도 같은 답.
func _s2_determinism(belts: Array, words: Array) -> void:
	var unstable := 0
	var order_unstable := 0
	var first_unstable := ""
	var checked := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(mini(SAMPLE, belts.size())):
		var owned: Array[String] = []
		for t in belts[i]:
			owned.append(str(t))
		var a: Array = AutoArrange.buildable_words_for(owned, words, 1)
		var b: Array = AutoArrange.buildable_words_for(owned, words, 1)
		if a.is_empty() or b.is_empty():
			continue
		checked += 1
		if str(a[0].get("word", "")) != str(b[0].get("word", "")):
			unstable += 1
			if first_unstable == "":
				first_unstable = "%s → %s / %s" % [str(owned), str(a[0].get("word", "")), str(b[0].get("word", ""))]
		# 순서를 섞어 다시 — 시드가 봉지 **내용**에서 나오므로 답이 같아야 한다.
		var shuffled: Array[String] = owned.duplicate()
		for k in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp := shuffled[k]
			shuffled[k] = shuffled[j]
			shuffled[j] = tmp
		var c: Array = AutoArrange.buildable_words_for(shuffled, words, 1)
		if c.is_empty() or str(c[0].get("word", "")) != str(a[0].get("word", "")):
			order_unstable += 1
	print("\n§2 결정성 (표본 %d)" % checked)
	print("  같은 봉지 두 번 호출에서 답이 바뀐 경우: %d" % unstable)
	print("  타일 순서를 섞었을 때 답이 바뀐 경우: %d" % order_unstable)
	check(unstable == 0, "The same belt must give the same hint (%d unstable, first: %s)"
		% [unstable, first_unstable])
	check(order_unstable == 0, "Tile order must not change the hint (%d unstable)" % order_unstable)


## §3 다양성 — 감독이 원한 것. 같은 봉지에서 1위만 나오지 않는가.
func _s3_variety(belts: Array, words: Array) -> void:
	var picks := {}
	var multi := 0
	var not_best := 0
	for belt in belts:
		var owned: Array[String] = []
		for t in belt:
			owned.append(str(t))
		var pick: Array = AutoArrange.buildable_words_for(owned, words, 1)
		if pick.is_empty():
			continue
		var picked := str(pick[0].get("word", ""))
		picks[picked] = int(picks.get(picked, 0)) + 1
		# 이 봉지에서 만들 수 있는 것이 둘 이상인가, 그리고 그중 1위가 아닌 것을 골랐는가.
		var buildable := 0
		var best_word := ""
		var best_value := -1
		for data in words:
			var w := str(data.get("word", ""))
			if AutoArrange.tile_indices_for(w, owned, []).is_empty():
				continue
			buildable += 1
			var v := AutoArrange.word_value(w, data)
			if v > best_value:
				best_value = v
				best_word = w
		if buildable >= 2:
			multi += 1
			if picked != best_word:
				not_best += 1
	print("\n§3 다양성")
	print("  서로 다른 목표 단어 %d개" % picks.size())
	print("  만들 수 있는 것이 2개 이상인 봉지 %d개 · 그중 **1위가 아닌 것**을 고른 봉지 %d개 (%.1f%%)"
		% [multi, not_best, 100.0 * float(not_best) / maxf(1.0, float(multi))])
	check(picks.size() > 1, "The hint must not always name the same word (distinct %d)" % picks.size())
	check(not_best > 0, "The hint must sometimes pick something other than the single best tower")


## §4 패널 — 조합 추천 모달이 여섯 줄을 그대로 받는가(후보가 여섯 이상일 때).
func _s4_panel_keeps_the_list(belts: Array, words: Array) -> void:
	var checked := 0
	var short := 0
	var dup := 0
	var head_mismatch := 0
	var first_short := ""
	for belt in belts:
		var owned: Array[String] = []
		for t in belt:
			owned.append(str(t))
		var full: Array = AutoArrange.buildable_words_for(owned, words, 999)
		if full.size() < 6:
			continue
		checked += 1
		var six: Array = AutoArrange.buildable_words_for(owned, words, 6)
		if six.size() != 6:
			short += 1
			if first_short == "":
				first_short = "%s — %d줄" % [str(owned), six.size()]
		var seen := {}
		for data in six:
			var w := str(data.get("word", ""))
			if seen.has(w):
				dup += 1
			seen[w] = true
		var one: Array = AutoArrange.buildable_words_for(owned, words, 1)
		if str(six[0].get("word", "")) != str(one[0].get("word", "")):
			head_mismatch += 1
	print("\n§4 조합 추천 패널 (후보 6개 이상인 봉지 %d개)" % checked)
	print("  여섯 줄을 못 채운 봉지: %d개 — %s" % [short, first_short])
	print("  중복 단어가 들어간 경우: %d" % dup)
	print("  패널 첫 줄 ≠ 슬롯 힌트의 목표: %d" % head_mismatch)
	check(short == 0, "The panel must still get six lines (%d short, first: %s)" % [short, first_short])
	check(dup == 0, "The panel must not repeat a word (%d)" % dup)
	check(head_mismatch == 0, "Both screens must agree on the pick (%d disagreed)" % head_mismatch)


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	print("  ✗ %s" % message)


## ALL_DRAW_POOL 에서 크기 1..n 의 멀티셋(중복 허용)을 전부 만든다.
func _multisets(pool: Array, n: int) -> Array:
	var out: Array = []
	for size in range(1, n + 1):
		_multisets_rec(pool, size, 0, [], out)
	return out


func _multisets_rec(pool: Array, n: int, start: int, acc: Array, out: Array) -> void:
	if acc.size() == n:
		out.append(acc.duplicate())
		return
	for i in range(start, pool.size()):
		acc.append(pool[i])
		_multisets_rec(pool, n, i, acc, out)
		acc.pop_back()
