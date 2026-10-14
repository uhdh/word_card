# tools/HintValueProbe.gd
# 힌트가 고르는 단어와 **실제 타워의 세기**가 같은 순서인지 잰다.
#
# 왜 필요한가: 슬롯 힌트는 `AutoArrange._word_score` 로 목표 단어를 고른다. 그 점수는
# `tier * 1000 + data.damage` 다. 그런데 타워의 실제 발당 피해는
# `BASE_DAMAGE_BY_LENGTH[음절수-1] * 특성배율` 이고 **`data.damage` 를 읽지 않는다**
# (길이와 특성만 본다 — tests/test_tower_traits.gd 의
# `_test_damage_uses_only_length_and_completion` 이 그 계약을 잠그고 있다).
#
# 그래서 같은 음절 수의 두 단어는 힌트 점수에서 `data.damage` 로 갈리는데, 그 값은
# 게임에서 아무 일도 하지 않는다. 힌트가 **더 약한 타워를 목표로 세울 수 있다** —
# 실제로 디렉터가 "현재 바늘인데 목표가 가루" 를 잡았다(가루 damage 44 > 바늘 22,
# 그런데 실제 타워는 바늘이 더 세다).
#
# 이 도구는 DB 전체를 돌면서 같은 음절 수 안에서 순위가 뒤집히는 쌍을 센다.
# 실행: godot --path . res://tools/HintValueProbe.tscn   (--headless 로도 돈다)
extends Node

const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const AutoArrange = preload("res://scripts/core/AutoArrange.gd")

## 타워가 field_ref 에서 읽는 것만 갖춘 최소 스텁.
class StubField extends Node:
	var relic_ids: Array = []

	func has_relic(_id: String) -> bool:
		return false

	func get_enemies() -> Array:
		return []


## 특성별 '한 대의 값어치' 를 단순 DPS 로만 재면 안 되는 것들.
## 제어·광역·지속피해는 숫자가 낮게 나오는 대신 다른 값을 한다 — 뒤집힘을 셀 때
## 이들을 '더 약한 타워' 로 단정하면 측정이 거짓말을 한다. 그래서 따로 표시한다.
const UTILITY_TRAITS: Array[String] = ["control", "splash", "damage_over_time", "orbit", "chain"]


func _ready() -> void:
	var field := StubField.new()
	add_child(field)
	var rows := _measure_all(field)
	_report(rows)
	field.free()
	get_tree().quit(0)


func _measure_all(field: Node) -> Array:
	var rows: Array = []
	for data in WordDatabase.get_all_words():
		var word := str(data.get("word", ""))
		if word == "":
			continue
		# 씬을 인스턴스화한다. `WordTowerScript.new()` 는 @onready 노드들을 못 찾아
		# _ready 에서 에러를 쏟고, 그 뒤 값은 우연히 맞지만 로그가 못 읽게 된다.
		var tower = WordTowerScene.instantiate()
		add_child(tower)
		tower.setup_tower(word, data, field)
		var interval: float = maxf(tower.attack_interval, 0.001)
		# 발수(volley)를 빼면 값을 크게 틀린다. 2·3음절 타워는 한 번의 공격에
		# **각각 만피 피해**로 여러 발을 쏜다(`attack_target`: volley > 1 이면
		# damage_shares 로 나누지 않는다). 상수 주석의 실측치 12.5 / 34.9 / 73.7 이
		# 정확히 이 식의 값이다 — 이 항을 빼면 2음절을 1.4배가 아니라 0.7배로 잰다.
		var volley: int = tower.volley_count()
		var per_hit: float = tower.damage_per_attack()
		rows.append({
			"word": word,
			"len": word.length(),
			"score": AutoArrange._word_score(data),
			"tier": int(data.get("tier", 0)),
			"db_damage": int(data.get("damage", 0)),
			"per_hit": per_hit,
			"volley": volley,
			"interval": interval,
			"dps": per_hit * float(volley) / interval,
			"trait": tower.trait_id,
			"utility": tower.trait_id in UTILITY_TRAITS,
		})
		tower.free()
	return rows


func _report(rows: Array) -> void:
	print("=== 힌트 점수 vs 실제 타워 ===")
	print("단어 %d개" % rows.size())

	# 같은 음절 수 안에서만 비교한다. 길이가 다르면 힌트 점수의 tier 항이 먼저 갈리고,
	# 그 방향(긴 단어가 세다)은 실제 게임과 일치한다 — 그건 뒤집힘이 아니다.
	var by_len := {}
	for row in rows:
		by_len.get_or_add(row["len"], []).append(row)

	var total_pairs := 0
	var inversions := 0
	var worst: Array = []
	for length in by_len:
		var group: Array = by_len[length]
		for i in range(group.size()):
			for j in range(i + 1, group.size()):
				var a: Dictionary = group[i]
				var b: Dictionary = group[j]
				if a["score"] == b["score"]:
					continue
				total_pairs += 1
				var hint_prefers: Dictionary = a if a["score"] > b["score"] else b
				var game_prefers: Dictionary = a if a["dps"] > b["dps"] else b
				if hint_prefers["word"] == game_prefers["word"]:
					continue
				inversions += 1
				worst.append({
					"hint": hint_prefers, "game": game_prefers,
					"ratio": game_prefers["dps"] / maxf(hint_prefers["dps"], 0.001),
				})

	worst.sort_custom(func(x, y): return x["ratio"] > y["ratio"])

	print("\n같은 음절 수 쌍 %d개 중 힌트와 실제가 **반대**를 고른 쌍: %d개 (%.1f%%)"
		% [total_pairs, inversions, 100.0 * float(inversions) / maxf(1.0, float(total_pairs))])

	# 유틸 특성(제어·광역·지속피해·선회·연쇄)은 DPS 가 낮게 나오는 대신 다른 일을 한다.
	# 그것까지 '뒤집힘' 으로 세면 측정이 과장된다 — 빼고 다시 센다.
	var pure_pairs := 0
	var pure_inversions := 0
	for length in by_len:
		var group: Array = by_len[length]
		for i in range(group.size()):
			for j in range(i + 1, group.size()):
				var a: Dictionary = group[i]
				var b: Dictionary = group[j]
				if a["utility"] or b["utility"] or a["score"] == b["score"]:
					continue
				pure_pairs += 1
				var hint_prefers: Dictionary = a if a["score"] > b["score"] else b
				var game_prefers: Dictionary = a if a["dps"] > b["dps"] else b
				if hint_prefers["word"] != game_prefers["word"]:
					pure_inversions += 1
	print("유틸 특성을 뺀 쌍 %d개 중 반대: %d개 (%.1f%%)"
		% [pure_pairs, pure_inversions,
		   100.0 * float(pure_inversions) / maxf(1.0, float(pure_pairs))])

	_report_lengths(by_len)
	_report_extremes(rows)
	_report_worst(worst)
	_report_reported_case(rows)
	_report_profiles()


## '전략 추천' 세 프로필이 서로 다른 답을 내는가.
##
## 순위 눈금을 DPS 로 바꾸면서 프로필 가산점(PROFILE_BONUS)의 **상대적 무게**가
## 달라졌다. 예전 눈금(damage 10~50)에서 +700 은 사실상 전부를 눌렀고, 지금 눈금
## (DPS x100, 460~11200)에서는 비슷한 것들 사이의 방향만 정한다. 가산점이 너무
## 약해지면 세 프로필이 같은 답을 내서 '전략 추천' 이라는 기능 자체가 죽는다 —
## 그래서 세 답이 실제로 갈라지는지 눈으로 확인한다.
func _report_profiles() -> void:
	var words := WordDatabase.get_all_words()
	# 게임에서 실제로 나올 법한 벨트 두 가지.
	var belts := {
		"수정구 벨트": ["ㅅ", "ㅜ", "ㅈ", "ㅓ", "ㅇ", "ㄱ", "ㅜ"],
		"바늘 벨트": ["ㅂ", "ㅏ", "ㄴ", "ㅡ", "ㄹ", "ㄱ", "ㅏ", "ㄹ", "ㅜ"],
		"넉넉한 벨트": ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"],
	}
	print("\n--- 전략 추천 3프로필 ---")
	for label in belts:
		var owned: Array[String] = []
		for jamo in belts[label]:
			owned.append(str(jamo))
		var sets := AutoArrange.strategic_sets_for(owned, words, 3)
		var lines: Array = []
		var signatures: Array = []
		for profile in sets:
			var picked: Array = []
			var signature: Array = []
			for data in profile["words"]:
				var word := str(data.get("word", ""))
				picked.append("%s(%.0f)" % [word, WordTower.preview_stats(word, data)["dps"]])
				signature.append(word)
			lines.append("    %-8s %s" % [profile["name"], " ".join(picked)])
			signatures.append(str(signature))
		print("  [%s]" % label)
		for line in lines:
			print(line)
		var distinct := 0
		for k in range(signatures.size()):
			var is_new := true
			for m in range(k):
				if signatures[k] == signatures[m]:
					is_new = false
			if is_new:
				distinct += 1
		print("    → 서로 다른 조합 %d / %d" % [distinct, signatures.size()])


## 음절 수별 실제 DPS 분포. `tier` 가 곧 '길면 세다' 라는 주장인데, 그 주장이
## 특성 배율·간격 앞에서 실제로 성립하는지 본다.
func _report_lengths(by_len: Dictionary) -> void:
	print("\n--- 음절 수별 실제 DPS ---")
	var lengths: Array = by_len.keys()
	lengths.sort()
	for length in lengths:
		var group: Array = by_len[length]
		var dps: Array = []
		var tier_mismatch := 0
		for row in group:
			dps.append(row["dps"])
			if int(row["tier"]) != int(row["len"]):
				tier_mismatch += 1
		dps.sort()
		var best: Dictionary = group[0]
		for row in group:
			if row["dps"] > best["dps"]:
				best = row
		var worst_row: Dictionary = group[0]
		for row in group:
			if row["dps"] < worst_row["dps"]:
				worst_row = row
		print("  %d음절 %3d개: DPS 최소 %.1f / 중간 %.1f / 최대 %.1f  (tier 불일치 %d)"
			% [length, group.size(), dps[0], dps[dps.size() / 2], dps[dps.size() - 1], tier_mismatch])
		print("      최강 %s %.1f DPS (%s) · 최약 %s %.1f DPS (%s)"
			% [best["word"], best["dps"], best["trait"],
			   worst_row["word"], worst_row["dps"], worst_row["trait"]])


## 힌트 점수 상위와 실제 DPS 상위를 나란히 놓는다. 한눈에 어긋남이 보인다.
func _report_extremes(rows: Array) -> void:
	var by_hint: Array = rows.duplicate()
	by_hint.sort_custom(func(a, b): return a["score"] > b["score"])
	var by_dps: Array = rows.duplicate()
	by_dps.sort_custom(func(a, b): return a["dps"] > b["dps"])
	print("\n--- 전체 1위 ---")
	print("  힌트가 뽑는 1위: %s (score %d, 실제 %.1f DPS)" % [by_hint[0]["word"], by_hint[0]["score"], by_hint[0]["dps"]])
	print("  실제 1위       : %s (score %d, 실제 %.1f DPS)" % [by_dps[0]["word"], by_dps[0]["score"], by_dps[0]["dps"]])
	print("  힌트 상위 5: %s" % str(by_hint.slice(0, 5).map(func(r): return "%s(%.0f)" % [r["word"], r["dps"]])))
	print("  실제 상위 5: %s" % str(by_dps.slice(0, 5).map(func(r): return "%s(%.0f)" % [r["word"], r["dps"]])))


func _report_worst(worst: Array) -> void:
	print("\n--- 가장 심한 뒤집힘 10개 (실제 타워가 더 센데 힌트는 다른 쪽을 고름) ---")
	for k in range(mini(10, worst.size())):
		var w: Dictionary = worst[k]
		var h: Dictionary = w["hint"]
		var g: Dictionary = w["game"]
		print("  힌트: %s (score %d, db_damage %d, 실제 %.1f DPS, %s%s)"
			% [h["word"], h["score"], h["db_damage"], h["dps"], h["trait"],
			   "·유틸" if h["utility"] else ""])
		print("  실제: %s (score %d, db_damage %d, 실제 %.1f DPS, %s%s)  → %.1f배"
			% [g["word"], g["score"], g["db_damage"], g["dps"], g["trait"],
			   "·유틸" if g["utility"] else "", w["ratio"]])


## 디렉터가 잡은 그 쌍. 회귀하면 여기서 바로 보인다.
func _report_reported_case(rows: Array) -> void:
	print("\n--- 보고된 사례 ---")
	for word in ["가루", "바늘"]:
		var row := _find(rows, word)
		if row.is_empty():
			print("  %s: DB 에 없음" % word)
			continue
		print("  %s: 힌트점수 %d (tier %d + db_damage %d) · 실제 발당 %.1f x %d발 / %.2f초 = %.1f DPS · 특성 %s"
			% [word, row["score"], row["tier"], row["db_damage"],
			   row["per_hit"], row["volley"], row["interval"], row["dps"], row["trait"]])


func _find(rows: Array, word: String) -> Dictionary:
	for row in rows:
		if row["word"] == word:
			return row
	return {}
