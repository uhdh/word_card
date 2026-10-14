# tools/WordShapeProbe.gd
# 단어의 **모양**(연음·겹받침·된소리·자모 균형 …)이 실제 단어 DB에서 얼마나 흔한지,
# 그리고 그것에 네이티브 효과를 주면 총 전력이 얼마나 움직이는지 잰다.
#
# 왜 필요한가: `WordSynergy.analyze()` 는 형태 특징 8종을 이미 계산하는데,
# 그 값을 읽는 곳은 `WordSynergy.bonuses()` 뿐이고 그건 전부 `relic_*` 로 막혀 있다.
# 즉 **유물이 없으면 형태는 아무 일도 하지 않는다** — 로직은 있는데 표현이 없는 상태다.
# 그래서 "유물 없이도 형태가 작게 작동하게" 만들려는데, 그 전에 두 가지를 알아야 한다.
#
#   1. 흔한 특징에 보너스를 주면 그건 '선택' 이 아니라 '상시 버프' 다.
#      95% 의 단어가 받침을 가진다면 "받침 단어를 고른다" 는 결정은 존재하지 않는다.
#      희귀한 특징일수록 플레이어의 선택을 만든다 — 그래서 빈도를 먼저 잰다.
#   2. 난이도 게이트(`DifficultyPlaytest -- gate=1`)는 **이미 '게임이 너무 쉬워졌다'**
#      로 실패 중이다(120% > 상한 75%). 형태 보너스가 총 전력을 올리면 그 실패를
#      악화시킨다. 그래서 총 전력 변화를 **숫자로** 확인한 뒤 크기를 정한다.
#
# 실행: cd godot && godot --headless --path . res://tools/WordShapeProbe.tscn
extends Node

const SHAPE_LABELS := {
	"has_final": "받침", "has_tense": "된소리", "has_cluster": "겹받침",
	"has_compound_vowel": "겹모음", "repeated_initial": "첫소리 반복",
	"repeated_vowel": "모음 반복", "linked": "연음", "balanced": "자모 균형",
}

## 단어 하나의 형태 효과를 **실제 구현에서** 가져온다.
##
## 여기에 표를 베껴 두면 구현이 바뀌어도 측정이 옛날 값을 계속 보고한다 —
## 이 프로젝트에서 이미 여러 번 난 '같은 사실을 두 곳에서 따로 계산하는' 문제다.
## 그래서 이 프로브는 이제 `WordSynergy` 만 본다.
func apply_rules(word: String) -> Dictionary:
	return WordSynergy.native_shape_bonuses(word)


func _ready() -> void:
	var words := WordDatabase.get_all_words()
	if words.is_empty():
		print("SHAPE PROBE FAILED: WordDatabase 가 비었다")
		get_tree().quit(1)
		return
	_report_frequency(words)
	_report_aggregate(words)
	_report_labels(words)
	_report_examples(words)
	print("WORD_SHAPE_PROBE_OK")
	get_tree().quit(0)


## ── 1. 빈도 ────────────────────────────────────────────────────────────────
## 흔하면 '상시 버프', 희귀하면 '선택' 이다. 이 표가 효과 크기를 정하는 근거다.
func _report_frequency(words: Array) -> void:
	var total := 0
	var by_feature := {}
	var by_len := {}
	var hit_count_dist := {}
	for data in words:
		var word := str(data.get("word", ""))
		if word == "":
			continue
		total += 1
		var a := WordSynergy.analyze(word)
		var length := word.length()
		by_len.get_or_add(length, {"n": 0, "hits": {}})
		by_len[length]["n"] += 1
		var hits := 0
		for key in SHAPE_LABELS:
			if a.get(key, false):
				by_feature[key] = int(by_feature.get(key, 0)) + 1
				by_len[length]["hits"][key] = int(by_len[length]["hits"].get(key, 0)) + 1
				hits += 1
		hit_count_dist[hits] = int(hit_count_dist.get(hits, 0)) + 1

	print("=== 형태 특징 빈도 (단어 %d개) ===" % total)
	var keys: Array = SHAPE_LABELS.keys()
	keys.sort_custom(func(x, y): return int(by_feature.get(x, 0)) > int(by_feature.get(y, 0)))
	for key in keys:
		var n := int(by_feature.get(key, 0))
		print("  %-14s %4d개  %5.1f%%   %s" % [
			SHAPE_LABELS[key], n, 100.0 * float(n) / float(total),
			"← 상시 버프에 가깝다(선택이 아님)" if n > total * 8 / 10 else ""])

	print("\n--- 음절 수별 ---")
	var lengths: Array = by_len.keys()
	lengths.sort()
	for length in lengths:
		var row: Dictionary = by_len[length]
		var parts: Array = []
		for key in keys:
			parts.append("%s %d" % [SHAPE_LABELS[key], int(row["hits"].get(key, 0))])
		print("  %d음절 %3d개: %s" % [length, row["n"], " · ".join(parts)])

	print("\n--- 단어당 걸리는 특징 개수 ---")
	var counts: Array = hit_count_dist.keys()
	counts.sort()
	for c in counts:
		print("  %d개: %d개 단어 (%.1f%%)" % [
			c, hit_count_dist[c], 100.0 * float(hit_count_dist[c]) / float(total)])


## ── 2. 총 전력 ────────────────────────────────────────────────────────────
## 난이도 게이트가 '너무 쉽다' 로 실패 중이므로 이 숫자가 크기를 정한다.
## 피해·간격·사거리 배수의 기하평균을 본다(배수라서 산술평균은 과대평가된다).
func _report_aggregate(words: Array) -> void:
	var n := 0
	var sum_dmg := 0.0
	var sum_int := 0.0
	var sum_rng := 0.0
	var dps_ratio_sum := 0.0
	var dps_ratio_max := 0.0
	var dps_ratio_min := 999.0
	var worst_word := ""
	var best_word := ""
	var by_len := {}
	for data in words:
		var word := str(data.get("word", ""))
		if word == "":
			continue
		n += 1
		var m := apply_rules(word)
		sum_dmg += log(float(m["damage"]))
		sum_int += log(float(m["interval"]))
		sum_rng += log(float(m["range"]))
		# 실제 DPS 변화. 간격이 줄면 DPS 는 는다.
		var ratio: float = float(m["damage"]) / float(m["interval"])
		dps_ratio_sum += ratio
		if ratio > dps_ratio_max:
			dps_ratio_max = ratio
			best_word = word
		if ratio < dps_ratio_min:
			dps_ratio_min = ratio
			worst_word = word
		by_len.get_or_add(word.length(), []).append(ratio)

	print("\n=== 총 전력 영향 (네이티브 형태 보너스만) ===")
	print("  피해  기하평균 x%.4f" % exp(sum_dmg / float(n)))
	print("  간격  기하평균 x%.4f" % exp(sum_int / float(n)))
	print("  사거리 기하평균 x%.4f" % exp(sum_rng / float(n)))
	print("  **DPS 비율 평균 x%.4f  (+%.2f%%)**" % [dps_ratio_sum / float(n),
		100.0 * (dps_ratio_sum / float(n) - 1.0)])
	print("  DPS 비율 최소 x%.4f (%s) · 최대 x%.4f (%s)" % [
		dps_ratio_min, worst_word, dps_ratio_max, best_word])

	# 테스트가 잠그는 상한을 **추측하지 않기 위해** 스탯별 실제 최소/최대를 찍는다.
	print("\n--- 스탯별 범위 (테스트 상한의 근거) ---")
	for stat in ["damage", "interval", "range"]:
		var lo := 999.0
		var hi := -999.0
		var lo_w := ""
		var hi_w := ""
		for data in words:
			var word := str(data.get("word", ""))
			if word == "":
				continue
			var v := float(apply_rules(word)[stat])
			if v < lo:
				lo = v
				lo_w = word
			if v > hi:
				hi = v
				hi_w = word
		print("  %-8s 최소 x%.4f (%s) · 최대 x%.4f (%s)" % [stat, lo, lo_w, hi, hi_w])

	print("\n--- 음절 수별 DPS 비율 ---")
	var lengths: Array = by_len.keys()
	lengths.sort()
	for length in lengths:
		var arr: Array = by_len[length]
		var s := 0.0
		for v in arr:
			s += float(v)
		print("  %d음절 %3d개: 평균 x%.4f" % [length, arr.size(), s / float(arr.size())])


## ── 3. 라벨 계약 ──────────────────────────────────────────────────────────
## 정보창 배지 행은 **22자를 넘는 라벨을 버린다**(`TowerInfoModal._render_synergy_badges`).
## 그래서 라벨이 길어지면 효과는 적용되는데 화면에서는 사라진다 — 조용한 거짓말이다.
## 여기서 길이를 세고, 초과가 있으면 크게 알린다.
const BADGE_MAX_LEN := 22

func _report_labels(words: Array) -> void:
	print("\n=== 라벨 길이 계약 (배지 상한 %d자) ===" % BADGE_MAX_LEN)
	var longest := 0
	var longest_label := ""
	var over: Array = []
	var no_label := 0
	var seen := {}
	for data in words:
		var word := str(data.get("word", ""))
		if word == "":
			continue
		var m := apply_rules(word)
		if m["labels"].is_empty():
			no_label += 1
		for lab in m["labels"]:
			var s := str(lab)
			seen[s] = true
			if s.length() > longest:
				longest = s.length()
				longest_label = s
			if s.length() > BADGE_MAX_LEN and not over.has(s):
				over.append(s)
	var all_labels: Array = seen.keys()
	all_labels.sort_custom(func(x, y): return str(x).length() > str(y).length())
	for s in all_labels:
		print("  %2d자  %s" % [str(s).length(), s])
	print("  최장 %d자: %s" % [longest, longest_label])
	print("  라벨이 하나도 안 붙는 단어: %d개" % no_label)
	if over.is_empty():
		print("  → OK: 모든 라벨이 상한 이하다")
	else:
		print("  → **실패**: 상한 초과 %d종 %s" % [over.size(), str(over)])


## ── 4. 실제 예시 ──────────────────────────────────────────────────────────
## 브리프의 기대값을 여기서 뽑는다. 숫자를 손으로 계산하면 반드시 틀린다.
func _report_examples(words: Array) -> void:
	print("\n=== 예시 (DPS 전/후) ===")
	var wanted: Array[String] = ["가", "나", "가나", "가루", "바늘", "수정구", "가나다"]
	# DB 에서 희귀 특징을 가진 단어도 하나씩 뽑아 본다 — 실제로 나오는지 확인용.
	var by_key := {}
	for data in words:
		var word := str(data.get("word", ""))
		if word == "":
			continue
		var a := WordSynergy.analyze(word)
		for key in SHAPE_LABELS:
			if a.get(key, false) and not by_key.has(key):
				by_key[key] = word
	for key in SHAPE_LABELS:
		if by_key.has(key) and not wanted.has(str(by_key[key])):
			wanted.append(str(by_key[key]))

	for word in wanted:
		var data := WordDatabase.get_word_data(word)
		if data.is_empty():
			print("  %-8s DB 에 없음" % word)
			continue
		var a := WordSynergy.analyze(word)
		var m := apply_rules(word)
		var before := WordTower.preview_stats(word, data)
		var after_dps: float = float(before["dps"]) * float(m["damage"]) / float(m["interval"])
		var flags: Array = []
		for key in SHAPE_LABELS:
			if a.get(key, false):
				flags.append(SHAPE_LABELS[key])
		var longest := 0
		for lab in m["labels"]:
			longest = maxi(longest, str(lab).length())
		print("  %-8s %d음절  DPS %6.1f → %6.1f (x%.3f)  [%s]  %s  (라벨 최장 %d자)" % [
			word, word.length(), float(before["dps"]), after_dps,
			after_dps / maxf(float(before["dps"]), 0.001),
			" · ".join(flags), " / ".join(m["labels"]), longest])
