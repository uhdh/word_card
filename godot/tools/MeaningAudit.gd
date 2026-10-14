extends Node
# MeaningAudit.gd
# AttackStyle(단어 뜻 → 공격 형태) 가 실제 단어 DB 전체를 얼마나 덮는지 감사한다.
#
# 왜 필요한가:
#   AttackStyle 은 세 단계로 동작한다 — EXACT(1음절 통짜) → RULES(키워드 스캔) →
#   CATEGORY_FALLBACK(옛 동작). 폴백으로 떨어진 단어는 '뜻과 무관한 옛 특성' 을 그대로
#   쓰므로, 폴백 비율이 높으면 "단어 뜻과 공격 형태를 연관시켜줘" 라는 요청이
#   절반만 이행된 것이다.
#
#   더 중요한 구분: RULES 는 이름+설명까지 훑는다. 설명에서만 걸린 단어는
#   **플레이어가 예측할 수 없다** — 단어를 보고 형태를 짐작할 수 없기 때문이다.
#   그래서 '단어 자체로 결정되는가' 를 따로 센다.
#
#   cd godot && godot --headless --path . res://tools/MeaningAudit.tscn

## 단어 자체로 결정되는 비율이 이 아래로 떨어지면 경고한다.
const WARN_WORD_ONLY_RATIO := 0.30
## 폴백 비율이 이 위로 올라가면 경고한다.
const WARN_FALLBACK_RATIO := 0.40

## dump=1 이면 폴백된 단어를 카테고리별로 전부 나열한다.
## (AttackStyle.RULES 에 어떤 키워드를 보강해야 하는지 판단하는 용도)
var _dump := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dump="):
			_dump = int(a.split("=")[1]) != 0
	var words: Array = WordDatabase.get_all_words()
	if words.is_empty():
		print("AUDIT no words in database")
		get_tree().quit()
		return

	var total := 0
	var exact := 0
	var by_word := 0        # RULES 가 단어 텍스트에서 걸림
	var by_desc := 0        # 이름/설명에서만 걸림 (플레이어가 예측 불가)
	var fallback := 0
	var trait_counts := {}
	var fallback_by_category := {}
	var fallback_words := {}
	var desc_only_words: Array = []

	# 주의: get_all_words() 는 단어 '문자열' 목록이 아니라 단어 데이터 '딕셔너리' 목록이다.
	# (WordDatabase.get_all_words() == WORD_DATABASE.values())
	for entry in words:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = entry
		var word := str(data.get("word", ""))
		if word == "":
			continue
		total += 1

		var category := str(data.get("category", ""))
		# 이름/설명을 비운 사본으로 한 번 더 물어보면 '단어 자체' 의 판정이 나온다.
		var stripped := {"category": category, "name": "", "desc": ""}
		var verdict: Dictionary = AttackStyle.style_for(word, stripped)

		var trait_id := str(verdict.get("trait", "balanced"))
		trait_counts[trait_id] = int(trait_counts.get(trait_id, 0)) + 1

		if AttackStyle.EXACT.has(word):
			exact += 1
			by_word += 1
		elif bool(verdict.get("matched", false)):
			by_word += 1
		else:
			# 단어만으로는 못 정한다 → 실제 게임에서는 이름/설명이 대신 정해 줄 수도 있다.
			var full: Dictionary = AttackStyle.style_for(word, data)
			if bool(full.get("matched", false)):
				by_desc += 1
				desc_only_words.append(word)
			else:
				fallback += 1
				fallback_by_category[category] = int(fallback_by_category.get(category, 0)) + 1
				if not fallback_words.has(category):
					fallback_words[category] = []
				fallback_words[category].append(word)

	var word_only_ratio := float(by_word) / float(total)
	var fallback_ratio := float(fallback) / float(total)

	print("=== 단어 뜻 → 공격 형태 커버리지 ===")
	print("전체 단어: %d" % total)
	print("  EXACT (1음절 통짜 사전): %d (%.1f%%)" % [exact, 100.0 * float(exact) / float(total)])
	print("  RULES — 단어 자체에서:   %d (%.1f%%)" % [by_word - exact, 100.0 * float(by_word - exact) / float(total)])
	print("  RULES — 설명에서만:      %d (%.1f%%)  ← 플레이어가 예측 불가" % [by_desc, 100.0 * float(by_desc) / float(total)])
	print("  FALLBACK (카테고리):     %d (%.1f%%)  ← 뜻과 무관한 옛 특성" % [fallback, 100.0 * fallback_ratio])
	print()
	print("단어 자체로 결정되는 비율: %.1f%%" % [100.0 * word_only_ratio])
	print()

	print("특성 분포:")
	var traits: Array = trait_counts.keys()
	traits.sort_custom(func(a, b): return int(trait_counts[a]) > int(trait_counts[b]))
	for trait_id in traits:
		print("  %-18s %3d (%.1f%%)" % [trait_id, int(trait_counts[trait_id]),
			100.0 * float(trait_counts[trait_id]) / float(total)])

	if not fallback_by_category.is_empty():
		print()
		print("폴백된 단어의 카테고리 분포:")
		var cats: Array = fallback_by_category.keys()
		cats.sort_custom(func(a, b): return int(fallback_by_category[a]) > int(fallback_by_category[b]))
		for category in cats:
			print("  %-14s %3d" % [category, int(fallback_by_category[category])])

	if not desc_only_words.is_empty():
		print()
		print("설명에서만 결정된 단어 (앞 25개): %s" % ", ".join(desc_only_words.slice(0, 25)))

	if _dump and not fallback_words.is_empty():
		print()
		print("=== 폴백된 단어 전체 (카테고리별) ===")
		for category in fallback_words:
			var list: Array = fallback_words[category]
			print("[%s] %d개: %s" % [category, list.size(), ", ".join(list)])

	if _dump:
		# 1음절 단어는 구조적으로 키워드 스캔이 불가능하다 — keys 가 2글자 이상이라
		# 한 글자 단어는 '단어 자체' 로는 절대 걸리지 않는다 (설명에만 기댈 수 있다).
		# 그래서 EXACT 사전이 유일한 수단이고, 여기 목록이 그 작업 대상이다.
		print()
		print("=== 1음절 단어 전체 (EXACT 사전 대상) ===")
		var singles: Array = []
		for entry in words:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var data: Dictionary = entry
			var word := str(data.get("word", ""))
			if word.length() != 1:
				continue
			var verdict: Dictionary = AttackStyle.style_for(word, {"category": str(data.get("category", "")), "name": "", "desc": ""})
			var full: Dictionary = AttackStyle.style_for(word, data)
			var tag := "EXACT" if AttackStyle.EXACT.has(word) else ("단어" if bool(verdict.get("matched", false)) else ("설명" if bool(full.get("matched", false)) else "폴백"))
			singles.append("%s=%s(%s)" % [word, str(full.get("trait", "?")), tag])
		singles.sort()
		print("총 %d개" % singles.size())
		for i in range(0, singles.size(), 6):
			print("  " + "  ".join(singles.slice(i, mini(i + 6, singles.size()))))

	print()
	if word_only_ratio < WARN_WORD_ONLY_RATIO:
		print("⚠ 단어 자체 결정 비율이 %.0f%% 미만입니다 — 뜻과 형태의 연결이 약합니다."
			% [WARN_WORD_ONLY_RATIO * 100.0])
	if fallback_ratio > WARN_FALLBACK_RATIO:
		print("⚠ 폴백 비율이 %.0f%% 를 넘습니다 — AttackStyle.RULES 에 키워드를 보강하세요."
			% [WARN_FALLBACK_RATIO * 100.0])

	get_tree().quit()
