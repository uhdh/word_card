# tools/HintVarietyProbe.gd
# 힌트 선택 규칙을 **"가장 타일을 많이 쓰는 것 중 랜덤"** 으로 바꾸면 실제로 무슨 일이
# 일어나는지 잰다. 감독 지시(2026-10-02)의 근거 자료다.
#
# 왜 필요한가: 지금 힌트는 `AutoArrange._word_score`(= 실제 DPS x100 + tier) 내림차순의
# 1위를 고른다. 그래서 같은 봉지에서 "만들 수 있는 여러 타워" 중 **항상 가장 센 하나**만
# 나온다 — 감독이 "하던것만 하니까" 라고 본 그 현상이다.
#
# 새 규칙은 **타일을 가장 많이 쓰는 그룹**으로 후보를 좁힌 뒤 그 안에서 하나를 뽑는다.
# 그러니 세 가지를 재야 한다:
#   (1) 그 그룹이 실제로 **여러 개**인가 — 하나뿐이면 규칙이 아무것도 안 바꾼다.
#   (2) 그 그룹 안에 **약한 단어**가 있는가 — 있으면 힌트가 다시 약한 것을 가리킨다.
#       그것은 감독이 두 번 보고한 버그다(가루 vs 바늘 · 1음절 목표). 두 계약이
#       `tests/test_tower_traits.gd` 에 잠겨 있다:
#         `_test_hint_never_prefers_a_weaker_word` (DPS 순위가 실제와 어긋나면 실패)
#         `_test_slot_hint_never_aims_lower_than_the_slot_can_build`
#   (3) **"타일을 많이 쓴다" 가 "센 타워" 와 같은 말인가** — 다르면 규칙의 이름과
#       결과가 어긋난다. (측정: 같지 않다. 1음절+겹모음+받침도 4장을 쓴다)
#
# §7·§8 은 대안이다. 규칙을 그대로 넣을지, 안전판을 둘지 정할 근거를 만든다.
#
# 인구: 봉지 1~3장은 **전수**, 4~7장은 시드 고정 표본. 15503개 전수는 `can_fill` 의
# 회전 루프가 6.8억 회라 5분을 넘겼다 — 호환표를 미리 계산하고 표본으로 줄인다.
#
# 실행: godot --headless --path . res://tools/HintVarietyProbe.tscn
extends Node

const AutoArrange = preload("res://scripts/core/AutoArrange.gd")

## 1~3장은 전수(15+120+680 = 815). 4장부터는 표본.
const EXHAUSTIVE_MAX := 3

## 4~7장 표본 수와 시드. 시드 고정은 프로브 결정성 규칙이다.
const SAMPLE_COUNT := 1500
const SAMPLE_SEED := 20261002
const SAMPLE_MIN := 4
const SAMPLE_MAX := 7

## 이 비율 아래로 내려가면 "힌트가 절반도 안 되는 것을 가리킬 수 있다" 로 읽는다.
const WEAK_RATIO := 0.5

## 이 아래는 사실상 다른 타워다(1/10).
const VERY_WEAK_RATIO := 0.10

## 대안 A 의 안전판 — 최대 타일 그룹 중 **그룹 최강의 이 비율 이상**인 것만 남긴다.
const ALT_A_FLOOR := 0.8

## 대안 B — DPS 상위 이 개수 중에서 랜덤.
const ALT_B_TOP := 3

## 대안 C — DPS 1위의 이 비율 이상인 후보 중에서 랜덤.
const ALT_C_FLOOR := 0.8


func _ready() -> void:
	var words: Array = WordDatabase.get_all_words()
	print("=== 힌트 다양성: '가장 타일 많은 것 중 랜덤' 이 실제로 무엇을 하는가 ===")

	# 단어별 요구 자모를 한 번만 편다. 봉지 수 x 단어 366개를 도는 동안 매번 음절을
	# 분해하면 프로브가 분 단위로 느려진다.
	var req: Dictionary = {}
	var targets: Dictionary = {}
	for data in words:
		var w := str(data.get("word", ""))
		if w == "":
			continue
		var r: Array = AutoArrange.required_jamo(w)
		req[w] = r
		for t in r:
			targets[str(t)] = true
	print("단어 %d개 · 서로 다른 목표 자모 %d개" % [req.size(), targets.size()])

	# 호환표: 봉지에 나오는 타일 15종 x 목표 자모. `can_fill` 은 회전을 최대 4번 돌므로
	# 안쪽 루프에서 부르면 6.8억 회가 된다 — 여기서 한 번만 계산한다.
	var compat := _build_compat(HangulEngine.ALL_DRAW_POOL, targets)

	var belts := _population()
	print("봉지 %d개 (1~%d장 전수 + %d~%d장 시드 %d 표본 %d개)"
		% [belts.size(), EXHAUSTIVE_MAX, SAMPLE_MIN, SAMPLE_MAX, SAMPLE_SEED, SAMPLE_COUNT])

	var rows := _measure(belts, words, req, compat)
	_report(rows, words)
	# ⚠️ quit() 을 안 부르면 작업이 끝나고도 Godot 이 영원히 안 끝난다 — 러너가
	#    RC=124("무한 대기 — 파싱 에러를 의심할 것")로 **거짓 진단**한다. 실제로 그렇게
	#    16초짜리 프로브를 4분 동안 기다렸다.
	print("\nHINT_VARIETY_PROBE_OK")
	get_tree().quit(0)


func _build_compat(pool: Array, targets: Dictionary) -> Dictionary:
	var compat: Dictionary = {}
	for tile in pool:
		var row: Dictionary = {}
		for target in targets:
			if AutoArrange.can_fill(str(tile), str(target)):
				row[str(target)] = true
		compat[str(tile)] = row
	return compat


func _population() -> Array:
	var belts := _multisets(HangulEngine.ALL_DRAW_POOL, EXHAUSTIVE_MAX)
	var rng := RandomNumberGenerator.new()
	rng.seed = SAMPLE_SEED
	for _i in range(SAMPLE_COUNT):
		var size := rng.randi_range(SAMPLE_MIN, SAMPLE_MAX)
		var belt: Array = []
		for _k in range(size):
			belt.append(HangulEngine.ALL_DRAW_POOL[rng.randi_range(0, HangulEngine.ALL_DRAW_POOL.size() - 1)])
		belts.append(belt)
	return belts


## 봉지 하나하나를 돈다. 각 봉지에서 "지금 규칙" 과 "새 규칙" 이 무엇을 내는지 담는다.
func _measure(belts: Array, words: Array, req: Dictionary, compat: Dictionary) -> Array:
	var rows: Array = []
	for owned in belts:
		var cands: Array = []
		for data in words:
			var word := str(data.get("word", ""))
			if word == "" or not req.has(word):
				continue
			var used: int = _greedy_tiles(req[word], owned, compat)
			if used <= 0:
				continue
			cands.append({
				"word": word,
				"used": used,
				"value": AutoArrange.word_value(word, data),
			})
		if cands.is_empty():
			rows.append({"empty": true, "belt": owned})
			continue

		# 지금 규칙이 뽑는 것 = DPS 1위.
		var best: Dictionary = cands[0]
		for c in cands:
			if int(c["value"]) > int(best["value"]):
				best = c

		# 새 규칙의 후보군 = 타일을 가장 많이 쓰는 것들.
		var max_used := 0
		for c in cands:
			if int(c["used"]) > max_used:
				max_used = int(c["used"])
		var group: Array = []
		for c in cands:
			if int(c["used"]) == max_used:
				group.append(c)
		var group_min: Dictionary = group[0]
		var group_max: Dictionary = group[0]
		var syl: Dictionary = {}
		var group_values: Array = []
		for c in group:
			if int(c["value"]) < int(group_min["value"]):
				group_min = c
			if int(c["value"]) > int(group_max["value"]):
				group_max = c
			var n: int = str(c["word"]).length()
			syl[n] = int(syl.get(n, 0)) + 1
			group_values.append(int(c["value"]))
		group_values.sort()
		group_values.reverse()

		var all_values: Array = []
		for c in cands:
			all_values.append(int(c["value"]))
		all_values.sort()
		all_values.reverse()

		rows.append({
			"empty": false,
			"belt": owned,
			"belt_size": owned.size(),
			"cand_count": cands.size(),
			"best": best,
			"best_used": int(best["used"]),
			"max_used": max_used,
			"group_size": group.size(),
			"group_min": group_min,
			"group_max": group_max,
			"group_values": group_values,
			"all_values": all_values,
			"group_syl": syl,
			"best_in_group": int(best["used"]) == max_used,
		})

	_check_premise(belts, words)
	return rows


## §0 자체 검증 — "지금 규칙 = DPS 1위" 라는 전제가 코드에서 참인가.
## 전수로 돌리면 무겁다(`_tiles_for_word` 가 음절을 매번 분해한다) — 60개만 본다.
func _check_premise(belts: Array, words: Array) -> void:
	var sample: int = mini(60, belts.size())
	var mismatches := 0
	var first := ""
	for i in range(sample):
		# `buildable_words_for` 는 Array[String] 을 받는다 — 안 맞추면 런타임 오류로
		# 이 함수만 죽고 나머지 측정은 조용히 계속된다(그래서 처음엔 §0 만 비어 있었다).
		var owned: Array[String] = []
		for t in belts[i]:
			owned.append(str(t))
		var pick: Array = AutoArrange.buildable_words_for(owned, words, 1)
		if pick.is_empty():
			continue
		var pick_word := str(pick[0].get("word", ""))
		var best_word := ""
		var best_value := -1
		for data in words:
			var w := str(data.get("word", ""))
			if AutoArrange.tile_indices_for(w, owned, []).is_empty():
				continue
			var v := AutoArrange.word_value(w, data)
			if v > best_value:
				best_value = v
				best_word = w
		if pick_word != best_word:
			mismatches += 1
			if first == "":
				first = "봉지 %s — 규칙=%s, DPS 1위=%s" % [str(owned), pick_word, best_word]
	print("\n§0 자체 검증 (표본 %d개) — 지금 규칙은 정말 DPS 1위를 뽑는가" % sample)
	print("  불일치: %d개" % mismatches)
	if first != "":
		print("  첫 불일치: %s" % first)


## 그 자모 열을 이 봉지로 채울 때 쓰는 타일 수. 못 채우면 0.
## `AutoArrange.tile_indices_for` 와 같은 greedy 이지만 호환표를 받는다.
##
## ⚠️ `compat.get(k, {})` 로 쓰면 안 된다 — 기본값 `{}` 가 **호출마다** 새로 만들어져
##    수천만 개를 할당한다. 봉지 타일은 전부 ALL_DRAW_POOL 출신이라 행이 반드시 있다.
func _greedy_tiles(targets: Array, owned: Array, compat: Dictionary) -> int:
	var n := owned.size()
	var taken: Array = []
	taken.resize(n)
	taken.fill(false)
	for target in targets:
		var found := false
		for i in range(n):
			if taken[i]:
				continue
			if compat[owned[i]].has(target):
				taken[i] = true
				found = true
				break
		if not found:
			return 0
	return targets.size()


func _report(rows: Array, words: Array) -> void:
	var live: Array = rows.filter(func(r): return not r["empty"])
	print("\n§1 후보가 있는 봉지 %d개 / 전체 %d개 (%.1f%%)"
		% [live.size(), rows.size(), 100.0 * float(live.size()) / maxf(1.0, float(rows.size()))])
	if live.is_empty():
		return

	# (1) 그룹 크기 = 새 규칙이 주는 선택지 수.
	var size_hist: Dictionary = {}
	var size_sum := 0
	for r in live:
		var g := int(r["group_size"])
		size_hist[g] = int(size_hist.get(g, 0)) + 1
		size_sum += g
	print("\n§2 최대 타일 그룹의 크기 (= 새 규칙이 주는 선택지 수)")
	var keys: Array = size_hist.keys()
	keys.sort()
	for k in keys:
		print("  크기 %d: %6d개 (%.1f%%)"
			% [k, size_hist[k], 100.0 * float(size_hist[k]) / float(live.size())])
	print("  평균 %.2f개" % [float(size_sum) / float(live.size())])
	var singleton := int(size_hist.get(1, 0))
	print("  ⚠️ 크기 1 = 규칙이 아무것도 안 바꾸는 봉지: %d개 (%.1f%%)"
		% [singleton, 100.0 * float(singleton) / float(live.size())])

	# 그룹이 여럿일 때, 그 그룹이 몇 음절짜리인가.
	var syl_hist: Dictionary = {}
	var multi: Array = live.filter(func(r): return int(r["group_size"]) > 1)
	for r in multi:
		var key := _dominant_syllable(r["group_syl"])
		syl_hist[key] = int(syl_hist.get(key, 0)) + 1
	print("\n§2b 그룹이 2개 이상인 봉지 %d개 — 그 그룹의 주된 음절 수" % multi.size())
	var skeys: Array = syl_hist.keys()
	skeys.sort()
	for k in skeys:
		print("  %s: %d개 (%.1f%%)"
			% [k, syl_hist[k], 100.0 * float(syl_hist[k]) / maxf(1.0, float(multi.size()))])
	print("  ⚠️ 1음절이 다수라는 것은 **'타일을 많이 쓴다' ≠ '큰 타워'** 라는 뜻이다 —")
	print("     겹모음+받침이면 1음절도 자모 4개다(생 = ㅅㅏㅣㅇ).")

	# (2) DPS 1위가 그룹 안에 있는가.
	var in_group := 0
	for r in live:
		if bool(r["best_in_group"]):
			in_group += 1
	print("\n§3 DPS 1위가 최대 타일 그룹 안에 있는가")
	print("  안에 있음: %6d개 (%.1f%%)  ← 새 규칙이 지금과 **같은 답**을 낼 수 있다"
		% [in_group, 100.0 * float(in_group) / float(live.size())])
	print("  밖에 있음: %6d개 (%.1f%%)  ← 새 규칙은 지금과 **다른 답**을 낸다"
		% [live.size() - in_group, 100.0 * float(live.size() - in_group) / float(live.size())])

	# (3) 그룹 안 최약 후보 vs DPS 1위.
	var ratios: Array = []
	var weak := 0
	var very_weak := 0
	var worst: Array = []
	for r in live:
		var best_v := int(r["best"]["value"])
		if best_v <= 0:
			continue
		var ratio := float(int(r["group_min"]["value"])) / float(best_v)
		ratios.append(ratio)
		if ratio < WEAK_RATIO:
			weak += 1
		if ratio < VERY_WEAK_RATIO:
			very_weak += 1
		worst.append({"r": r, "ratio": ratio})
	ratios.sort()
	worst.sort_custom(func(a, b): return float(a["ratio"]) < float(b["ratio"]))
	print("\n§4 새 규칙이 고를 수 있는 **가장 약한** 후보 ÷ DPS 1위")
	print("  비율 최소 %.3f · 중간 %.3f · 최대 %.3f"
		% [ratios[0], ratios[ratios.size() / 2], ratios[ratios.size() - 1]])
	print("  비율 < %.2f (절반 이하로 약함): %6d개 (%.1f%%)"
		% [WEAK_RATIO, weak, 100.0 * float(weak) / float(live.size())])
	print("  비율 < %.2f (사실상 다른 타워): %6d개 (%.1f%%)"
		% [VERY_WEAK_RATIO, very_weak, 100.0 * float(very_weak) / float(live.size())])

	print("\n§5 최악 사례 12개 (새 규칙이 가장 크게 낮출 수 있는 봉지)")
	var shown := 0
	for w in worst:
		if shown >= 12:
			break
		var r: Dictionary = w["r"]
		print("  봉지 %s" % str(r["belt"]))
		print("    지금(DPS 1위) : %s %.1f DPS · 타일 %d장"
			% [str(r["best"]["word"]), float(int(r["best"]["value"])) / 100.0, int(r["best_used"])])
		print("    그룹 최약      : %s %.1f DPS · 타일 %d장  → 비율 %.3f"
			% [str(r["group_min"]["word"]), float(int(r["group_min"]["value"])) / 100.0,
			   int(r["group_min"]["used"]), float(w["ratio"])])
		print("    그룹 %d개 · 음절 구성 %s"
			% [int(r["group_size"]), str(r["group_syl"])])
		shown += 1

	_report_alternatives(live)
	_report_expected(live)
	_report_syllable_mix(live)
	_report_examples(live, words, _build_compat(HangulEngine.ALL_DRAW_POOL, _all_targets(words)))


## 규칙별 **기대 세기** — 무작위로 뽑았을 때 플레이어가 실제로 받는 값.
##
## §7 의 '최악 비율' 만 보면 과장된다. 힌트는 매번 뽑히므로 체감에 가까운 것은 기대값이다.
## (예: 최대 타일 그룹이 14개이고 그중 하나가 4.6 DPS 라도, 14분의 1로만 뽑힌다)
func _report_expected(live: Array) -> void:
	print("\n§7b 규칙별 **기대 세기** — 무작위로 뽑았을 때의 평균 ÷ DPS 1위")
	print("  %-28s %10s %10s %10s" % ["규칙", "기대 비율", "중간", "최악"])
	var kinds := [
		["지금 (DPS 1위 고정)", "now"],
		["새 규칙 (최대 타일 전부)", "max_tiles"],
		["대안 A (그룹 최강의 80%↑)", "a"],
		["대안 B (DPS 상위 %d 중 랜덤)" % ALT_B_TOP, "b"],
		["대안 C (DPS 1위의 80%↑)", "c"],
	]
	for kind in kinds:
		var per_belt: Array = []
		var worst := 1.0
		for r in live:
			var kept: Array = _kept_values(r, str(kind[1]))
			var best_v := int(r["best"]["value"])
			if best_v <= 0 or kept.is_empty():
				continue
			var sum := 0
			var lo := best_v
			for v in kept:
				sum += int(v)
				lo = mini(lo, int(v))
			per_belt.append(float(sum) / float(kept.size()) / float(best_v))
			worst = minf(worst, float(lo) / float(best_v))
		if per_belt.is_empty():
			continue
		per_belt.sort()
		print("  %-28s %10.3f %10.3f %10.3f" % [
			str(kind[0]), _mean(per_belt), float(per_belt[per_belt.size() / 2]), worst])


func _mean(values: Array) -> float:
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / maxf(1.0, float(values.size()))


## 그 규칙이 이 봉지에서 고를 수 있는 후보들의 값(x100) 목록.
func _kept_values(r: Dictionary, kind: String) -> Array:
	var best_v := int(r["best"]["value"])
	match kind:
		"now":
			return [best_v]
		"max_tiles":
			return r["group_values"]
		"a":
			var gv: Array = r["group_values"]
			return _floor_keep(gv, int(gv[0]), ALT_A_FLOOR)
		"b":
			var av: Array = r["all_values"]
			return av.slice(0, mini(ALT_B_TOP, av.size()))
		"c":
			return _floor_keep(r["all_values"], best_v, ALT_C_FLOOR)
	return []


## values 는 내림차순. top 의 floor_ratio 이상인 것만 남긴다.
func _floor_keep(values: Array, top: int, floor_ratio: float) -> Array:
	var limit := int(round(float(top) * floor_ratio))
	var out: Array = []
	for v in values:
		if int(v) >= limit:
			out.append(int(v))
	return out


## 힌트가 화면에 **말하는** 것은 단어가 아니라 '목표 N음절' 이다(`_slot_hint_text`).
##
## 그래서 규칙을 바꾸면 플레이어가 읽는 **문장**이 바뀐다. 감독이 두 번째로 보고한 증상이
## 정확히 그 문장이었다 — "타일 7장을 들고 있는 슬롯이 '목표 1음절' 을 받았다".
## 새 규칙이 그 증상을 늘리는지 줄이는지 잰다. (줄이면 안 되면 규칙을 다시 봐야 한다)
func _report_syllable_mix(live: Array) -> void:
	var now := {1: 0, 2: 0, 3: 0}
	var fresh := {1: 0.0, 2: 0.0, 3: 0.0}
	for r in live:
		var n: int = str(r["best"]["word"]).length()
		now[n] = int(now.get(n, 0)) + 1
		var g := int(r["group_size"])
		if g <= 0:
			continue
		var counts := {1: 0, 2: 0, 3: 0}
		for k in r["group_syl"]:
			counts[int(k)] = int(r["group_syl"][k])
		for k in counts:
			fresh[k] = float(fresh[k]) + float(counts[k]) / float(g)
	print("\n§8 힌트가 화면에 말하는 것 — '목표 N음절' 의 분포")
	print("  %-8s %11s %14s" % ["음절", "지금", "새 규칙(기대)"])
	for k in [1, 2, 3]:
		print("  %-8s %10.1f%% %13.1f%%" % [
			"%d음절" % k,
			100.0 * float(now[k]) / float(live.size()),
			100.0 * float(fresh[k]) / float(live.size())])


## 대안 A·B 를 같은 자로 잰다. "다양성을 얼마나 남기고 약화를 얼마나 없애는가".
func _report_alternatives(live: Array) -> void:
	print("\n§7 대안 비교 — 선택지 수와 최악 비율")
	print("  (선택지 수 = 그 봉지에서 힌트가 낼 수 있는 서로 다른 단어의 수)")
	print("  %-28s %10s %10s %12s" % ["규칙", "평균 선택지", "≥2 선택지", "최악 비율"])

	# 지금: 항상 1개.
	print("  %-28s %10.2f %9.1f%% %12s" % ["지금 (DPS 1위 고정)", 1.0, 0.0, "1.000"])

	# 새 규칙 그대로: 최대 타일 그룹 전부.
	var raw_choices := 0.0
	var raw_multi := 0
	var raw_worst := 1.0
	for r in live:
		var g := int(r["group_size"])
		raw_choices += float(g)
		if g > 1:
			raw_multi += 1
		var best_v := int(r["best"]["value"])
		if best_v > 0:
			raw_worst = minf(raw_worst, float(int(r["group_min"]["value"])) / float(best_v))
	print("  %-28s %10.2f %9.1f%% %12.3f" % [
		"새 규칙 (최대 타일 전부)", raw_choices / float(live.size()),
		100.0 * float(raw_multi) / float(live.size()), raw_worst])

	# 대안 A: 그룹 중 그룹 최강의 ALT_A_FLOOR 이상만.
	var a_choices := 0.0
	var a_multi := 0
	var a_worst := 1.0
	for r in live:
		var gv: Array = r["group_values"]
		var floor_value := int(round(float(gv[0]) * ALT_A_FLOOR))
		var kept := 0
		var kept_min := int(gv[0])
		for v in gv:
			if int(v) >= floor_value:
				kept += 1
				kept_min = mini(kept_min, int(v))
		a_choices += float(kept)
		if kept > 1:
			a_multi += 1
		var best_v := int(r["best"]["value"])
		if best_v > 0:
			a_worst = minf(a_worst, float(kept_min) / float(best_v))
	print("  %-28s %10.2f %9.1f%% %12.3f" % [
		"대안 A (그룹 최강의 %.0f%%↑)" % (ALT_A_FLOOR * 100.0),
		a_choices / float(live.size()), 100.0 * float(a_multi) / float(live.size()), a_worst])

	# 대안 B: DPS 상위 ALT_B_TOP 개 중 랜덤.
	var b_choices := 0.0
	var b_multi := 0
	var b_worst := 1.0
	for r in live:
		var av: Array = r["all_values"]
		var kept := mini(ALT_B_TOP, av.size())
		b_choices += float(kept)
		if kept > 1:
			b_multi += 1
		var best_v := int(r["best"]["value"])
		if best_v > 0 and kept > 0:
			b_worst = minf(b_worst, float(int(av[kept - 1])) / float(best_v))
	print("  %-28s %10.2f %9.1f%% %12.3f" % [
		"대안 B (DPS 상위 %d 중 랜덤)" % ALT_B_TOP,
		b_choices / float(live.size()), 100.0 * float(b_multi) / float(live.size()), b_worst])

	# 대안 C: DPS 1위의 ALT_C_FLOOR 이상인 후보 중 랜덤.
	var c_choices := 0.0
	var c_multi := 0
	var c_worst := 1.0
	for r in live:
		var av: Array = r["all_values"]
		var best_v := int(r["best"]["value"])
		if best_v <= 0 or av.is_empty():
			continue
		var floor_value := int(round(float(best_v) * ALT_C_FLOOR))
		var kept := 0
		var kept_min := best_v
		for v in av:
			if int(v) >= floor_value:
				kept += 1
				kept_min = mini(kept_min, int(v))
		c_choices += float(kept)
		if kept > 1:
			c_multi += 1
		c_worst = minf(c_worst, float(kept_min) / float(best_v))
	print("  %-28s %10.2f %9.1f%% %12.3f" % [
		"대안 C (DPS 1위의 %.0f%%↑)" % (ALT_C_FLOOR * 100.0),
		c_choices / float(live.size()), 100.0 * float(c_multi) / float(live.size()), c_worst])
	print("  ⚠️ '최악 비율' 은 그 규칙이 **고를 수 있는 가장 약한 답** ÷ DPS 1위다.")


func _dominant_syllable(syl: Dictionary) -> String:
	var best := ""
	var best_n := -1
	for k in syl:
		if int(syl[k]) > best_n:
			best_n = int(syl[k])
			best = "%d음절" % int(k)
	return best


## 감독이 보는 화면에 가까운 예 셋. 후보 전체를 나란히 놓는다.
func _report_examples(live: Array, words: Array, compat: Dictionary) -> void:
	print("\n§6 구체 예 — 후보 전체를 나란히")
	var picked := 0
	for r in live:
		if picked >= 3:
			break
		if int(r["cand_count"]) < 4 or int(r["group_size"]) < 2:
			continue
		if int(r["belt_size"]) != 5:
			continue
		var belt: Array = r["belt"]
		var cands: Array = []
		for data in words:
			var word := str(data.get("word", ""))
			var used: int = _greedy_tiles(AutoArrange.required_jamo(word), belt, compat)
			if used <= 0:
				continue
			cands.append({"w": word, "u": used,
				"d": float(AutoArrange.word_value(word, data)) / 100.0})
		cands.sort_custom(func(a, b):
			if int(a["u"]) != int(b["u"]):
				return int(a["u"]) > int(b["u"])
			return float(a["d"]) > float(b["d"])
		)
		print("  봉지 %s · 후보 %d개 · 최대 타일 %d장 · 그룹 %d개"
			% [str(belt), cands.size(), int(r["max_used"]), int(r["group_size"])])
		for c in cands:
			var mark := "  ← 최대 타일 그룹" if int(c["u"]) == int(r["max_used"]) else ""
			print("      %s  %5.1f DPS  타일 %d장%s"
				% [str(c["w"]), float(c["d"]), int(c["u"]), mark])
		picked += 1


func _all_targets(words: Array) -> Dictionary:
	var out: Dictionary = {}
	for data in words:
		for t in AutoArrange.required_jamo(str(data.get("word", ""))):
			out[str(t)] = true
	return out


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
