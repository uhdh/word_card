# HangulStreamParser.gd
# 하단 자모 타일 벨트의 순서를 읽어 유효한 한글 음절 및 단어 타워 목록으로 자동 파싱
extends Node

func parse_jamo_stream(jamo_list: Array) -> Array:
	var parsed_towers = []
	var i = 0
	var n = jamo_list.size()

	while i < n:
		var c1 = jamo_list[i]
		if not HangulEngine.CHOSUNG.has(c1):
			# 초성이 아니면 한 칸 넘김
			i += 1
			continue

		# 초성 찾음, 다음이 중성인지 확인
		if i + 1 < n:
			var c2 = jamo_list[i + 1]
			if HangulEngine.JUNGSUNG.has(c2):
				# 초성 + 중성 가능!
				# 이제 3번째가 종성(받침)이 될 수 있는지 확인
				var has_jong = false
				var c3 = ""
				if i + 2 < n:
					var cand_c3 = jamo_list[i + 2]
					if HangulEngine.JONGSUNG.has(cand_c3) and cand_c3 != "":
						# 만약 4번째 글자가 모음(중성)이라면, 3번째 글자는 다음 음절의 초성으로 양보해야 할 수도 있음
						# 하지만 독립된 타일 벨트에서는 3글자 완성 우선 또는 유효 단어 우선으로 판정
						var try_syl_3 = HangulEngine.compose_syllable(c1, c2, cand_c3)
						var try_syl_2 = HangulEngine.compose_syllable(c1, c2, "")
						
						# 3글자 합성 단어가 DB에 있다면 3글자 우선 채택
						if WordDatabase.WORD_DATABASE.has(try_syl_3):
							has_jong = true
							c3 = cand_c3
						elif i + 3 < n and HangulEngine.JUNGSUNG.has(jamo_list[i + 3]):
							# 다음이 모음이면 2글자로 끊음
							has_jong = false
						elif HangulEngine.JONGSUNG.has(cand_c3):
							# DB에 없더라도 3글자로 결합
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

				var data = WordDatabase.get_word_data(syllable)
				if data.is_empty():
					# 미지의 단어 타워 기본값
					data = {
						"word": syllable,
						"name": syllable + " (미지의 활자)",
						"category": "weapon",
						"cost": 1,
						"damage": 3,
						"desc": "기본 활자 탄환을 발사합니다.",
						"icon": "res://assets/01_무기_공격/sword_검/sword_1_32px_pastel.png",
						"sound": "playAttack"
					}

				parsed_towers.append({
					"syllable": syllable,
					"word_data": data,
					"indices": used_indices
				})
				continue

		i += 1

	return parsed_towers
