# HangulStreamParser.gd
# 하단 자모 타일 벨트를 분석하여 1글자 / 2글자 / 3글자 복합 단어 타워를 최장 일치(Greedy)로 자동 파싱
extends Node

func parse_jamo_stream(jamo_list: Array) -> Array:
	# 1단계: 자모 스트림에서 개별 1글자 음절 단위들을 순차 추출
	var raw_syllables = []
	var i = 0
	var n = jamo_list.size()

	while i < n:
		var c1 = jamo_list[i]
		if not HangulEngine.CHOSUNG.has(c1):
			i += 1
			continue

		if i + 1 < n:
			var c2 = jamo_list[i + 1]
			if HangulEngine.JUNGSUNG.has(c2):
				var has_jong = false
				var c3 = ""
				if i + 2 < n:
					var cand_c3 = jamo_list[i + 2]
					if HangulEngine.JONGSUNG.has(cand_c3) and cand_c3 != "":
						var try_syl_3 = HangulEngine.compose_syllable(c1, c2, cand_c3)
						if WordDatabase.WORD_DATABASE.has(try_syl_3):
							has_jong = true
							c3 = cand_c3
						elif i + 3 < n and HangulEngine.JUNGSUNG.has(jamo_list[i + 3]):
							has_jong = false
						elif HangulEngine.JONGSUNG.has(cand_c3):
							has_jong = true
							c3 = cand_c3

				var syllable = ""
				var used_indices = []
				if has_jong:
					syllable = HangulEngine.compose_syllable(c1, c2, c3)
					used_indices = [i, i + 1, i + 2]
					i += 3
				else:
					syllable = HangulEngine.compose_syllable(c1, c2, "")
					used_indices = [i, i + 1]
					i += 2

				raw_syllables.append({
					"syllable": syllable,
					"indices": used_indices
				})
				continue

		i += 1

	# 2단계: 추출된 음절들을 바탕으로 3글자 ➔ 2글자 ➔ 1글자 복합 단어 탐색 (Greedy Matching)
	var final_towers = []
	var s_idx = 0
	var total_s = raw_syllables.size()

	while s_idx < total_s:
		# 3글자 결합 확인
		if s_idx + 2 < total_s:
			var tri_word = raw_syllables[s_idx]["syllable"] + raw_syllables[s_idx + 1]["syllable"] + raw_syllables[s_idx + 2]["syllable"]
			if WordDatabase.WORD_DATABASE.has(tri_word):
				var data = WordDatabase.get_word_data(tri_word)
				var combined_indices = []
				combined_indices.append_array(raw_syllables[s_idx]["indices"])
				combined_indices.append_array(raw_syllables[s_idx + 1]["indices"])
				combined_indices.append_array(raw_syllables[s_idx + 2]["indices"])

				final_towers.append({
					"syllable": tri_word,
					"word_data": data,
					"indices": combined_indices,
					"tier": 3
				})
				s_idx += 3
				continue

		# 2글자 결합 확인
		if s_idx + 1 < total_s:
			var bi_word = raw_syllables[s_idx]["syllable"] + raw_syllables[s_idx + 1]["syllable"]
			if WordDatabase.WORD_DATABASE.has(bi_word):
				var data = WordDatabase.get_word_data(bi_word)
				var combined_indices = []
				combined_indices.append_array(raw_syllables[s_idx]["indices"])
				combined_indices.append_array(raw_syllables[s_idx + 1]["indices"])

				final_towers.append({
					"syllable": bi_word,
					"word_data": data,
					"indices": combined_indices,
					"tier": 2
				})
				s_idx += 2
				continue

		# 1글자 단어
		var mono_word = raw_syllables[s_idx]["syllable"]
		var data = WordDatabase.get_word_data(mono_word)
		if data.is_empty():
			data = {
				"word": mono_word,
				"name": mono_word + " (미지의 활자)",
				"category": "weapon",
				"cost": 1,
				"damage": 4,
				"desc": "기본 활자 탄환을 발사합니다.",
				"icon": "res://assets/01_무기_공격/sword_검/sword_1_32px_pastel.png",
				"sound": "playAttack"
			}

		final_towers.append({
			"syllable": mono_word,
			"word_data": data,
			"indices": raw_syllables[s_idx]["indices"],
			"tier": 1
		})
		s_idx += 1

	return final_towers
