# HangulStreamParser.gd
# 하단 자모 타일 벨트를 분석하여 연속 자모 자동 합성 (예: ㄱㄱㅏ ➔ 까, ㅗㅏ ➔ ㅘ, ㄹㄱ ➔ ㄺ) 및
# 1글자 / 2글자 / 3글자 복합 단어 타워를 최장 일치(Greedy)로 자동 파싱
extends Node

static func parse_jamo_stream(jamo_list: Array) -> Array:
	var raw_syllables = []
	var i = 0
	var n = jamo_list.size()

	while i < n:
		# 1. 초성 (Chosung) 결정 (쌍자음 자동 합성: ㄱ+ㄱ -> ㄲ, ㅂ+ㅂ -> ㅃ, ㅅ+ㅅ -> ㅆ, ㅈ+ㅈ -> ㅉ, ㄷ+ㄷ -> ㄸ)
		var cho = ""
		var cho_indices = []

		if i + 1 < n:
			var double_key = jamo_list[i] + "+" + jamo_list[i + 1]
			if HangulEngine.CONSONANT_COMBINATIONS.has(double_key):
				var combined_cho = HangulEngine.CONSONANT_COMBINATIONS[double_key]
				if HangulEngine.CHOSUNG.has(combined_cho) and i + 2 < n and (HangulEngine.JUNGSUNG.has(jamo_list[i + 2]) or is_vowel(jamo_list[i + 2])):
					cho = combined_cho
					cho_indices = [i, i + 1]
					i += 2

		if cho == "":
			var single_c = jamo_list[i]
			if HangulEngine.CHOSUNG.has(single_c):
				cho = single_c
				cho_indices = [i]
				i += 1
			else:
				i += 1
				continue

		# 2. 중성 (Jungsung) 결정 (이중모음 자동 합성: ㅗ+ㅏ -> ㅘ, ㅡ+ㅣ -> ㅢ, ㅏ+ㅣ -> ㅐ, ㅓ+ㅣ -> ㅔ 등)
		var jung = ""
		var jung_indices = []

		if i < n:
			if i + 1 < n:
				var double_v_key = jamo_list[i] + "+" + jamo_list[i + 1]
				if HangulEngine.VOWEL_COMBINATIONS.has(double_v_key):
					var combined_v = HangulEngine.VOWEL_COMBINATIONS[double_v_key]
					if HangulEngine.JUNGSUNG.has(combined_v):
						jung = combined_v
						jung_indices = [i, i + 1]
						i += 2

			if jung == "":
				var single_v = jamo_list[i]
				if HangulEngine.JUNGSUNG.has(single_v):
					jung = single_v
					jung_indices = [i]
					i += 1

		# 초성은 있는데 모음(중성)이 없으면 음절 불성립
		if jung == "":
			continue

		# 3. 종성 (Jongsung) 결정 (겹받침 자동 합성: ㄹ+ㄱ -> ㄺ, ㅂ+ㅅ -> ㅄ 등)
		var jong = ""
		var jong_indices = []

		if i < n:
			# 현재 자음(jamo_list[i])이 다음 음절의 시작이 아닌 경우에만 종성 후보가 됨
			if not can_be_next_syllable_start(jamo_list, i):
				# 겹받침 확인 (예: ㄹ + ㄱ)
				var try_double_jong = false
				if i + 1 < n:
					# 두 번째 자음도 다음 음절의 시작이 아닌 경우에만 겹받침으로 묶음
					if not can_be_next_syllable_start(jamo_list, i + 1):
						var double_j_key = jamo_list[i] + "+" + jamo_list[i + 1]
						if HangulEngine.CONSONANT_COMBINATIONS.has(double_j_key):
							var combined_j = HangulEngine.CONSONANT_COMBINATIONS[double_j_key]
							if HangulEngine.JONGSUNG.has(combined_j):
								jong = combined_j
								jong_indices = [i, i + 1]
								i += 2
								try_double_jong = true

				if not try_double_jong:
					# 홑받침 채택
					var single_j = jamo_list[i]
					if HangulEngine.JONGSUNG.has(single_j) and single_j != "":
						jong = single_j
						jong_indices = [i]
						i += 1

		# 음절 완성
		var syllable = HangulEngine.compose_syllable(cho, jung, jong)
		if syllable != "":
			var all_indices = []
			all_indices.append_array(cho_indices)
			all_indices.append_array(jung_indices)
			all_indices.append_array(jong_indices)
			raw_syllables.append({
				"syllable": syllable,
				"indices": all_indices
			})

	# 2단계: 남은 음절을 앞에서부터 최대 3글자씩 그리디하게 묶어 타워 하나로 구성.
	# 사전에 있는 조합이면 실제 단어 데이터를, 없으면 글자 수에 비례한 "미지의 활자" 데이터를 사용.
	var final_towers = []
	var s_idx = 0
	var total_s = raw_syllables.size()

	while s_idx < total_s:
		var take = mini(3, total_s - s_idx)
		var combo = ""
		var combined_indices = []
		for k in range(take):
			combo += raw_syllables[s_idx + k]["syllable"]
			combined_indices.append_array(raw_syllables[s_idx + k]["indices"])

		var data = WordDatabase.get_word_data(combo)
		if data.is_empty():
			data = make_unknown_word_data(combo, take)

		final_towers.append({
			"syllable": combo,
			"word_data": data,
			"indices": combined_indices,
			"tier": take
		})
		s_idx += take

	return final_towers

# 사전에 없는 조합의 "미지의 활자" 데이터 생성. 실제 사전 단어 평균 데미지(1글자 11, 2글자 26, 3글자 39)보다
# 낮게, 그리고 한 단계 아래 글자 수의 사전 단어보다는 높게 잡아 글자 수를 늘릴 유인은 남기되 사전 단어보다 약하게 함.
static func make_unknown_word_data(combo: String, length: int) -> Dictionary:
	var damage_by_length = {1: 4, 2: 15, 3: 28}
	return {
		"word": combo,
		"name": combo + " (미지의 활자)",
		"category": "basic",
		"is_unknown": true,
		"cost": length,
		"damage": damage_by_length.get(length, 4),
		"desc": "사전에 등록되지 않은 미지의 활자 조합입니다. 같은 글자 수의 사전 단어보다는 약한 기본 탄환을 발사합니다.",
		"icon": "",
		"sound": "playAttack"
	}

static func can_be_next_syllable_start(jamo_list: Array, idx: int) -> bool:
	var n = jamo_list.size()
	if idx >= n:
		return false
	var c1 = jamo_list[idx]
	if not HangulEngine.CHOSUNG.has(c1):
		return false
	# 1) c1 바로 뒤에 모음이 오는 경우 (예: ㄱ + ㅏ)
	if idx + 1 < n and is_vowel(jamo_list[idx + 1]):
		return true
	# 2) c1 + c2가 쌍자음이고 그 뒤에 모음이 오는 경우 (예: ㄱ + ㄱ + ㅗ)
	if idx + 2 < n:
		var double_key = c1 + "+" + jamo_list[idx + 1]
		if HangulEngine.CONSONANT_COMBINATIONS.has(double_key):
			var comb = HangulEngine.CONSONANT_COMBINATIONS[double_key]
			if HangulEngine.CHOSUNG.has(comb) and is_vowel(jamo_list[idx + 2]):
				return true
	return false

static func is_vowel(c: String) -> bool:
	return HangulEngine.JUNGSUNG.has(c) or HangulEngine.VOWEL_COMBINATIONS.has(c)
