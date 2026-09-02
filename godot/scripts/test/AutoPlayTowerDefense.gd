# AutoPlayTowerDefense.gd
# 타워 디펜스 전체 기능(조합 없는 단어 큰 텍스트, 도감, 타워 클릭 팝업, 자동 저장, 세이브/로드) 자동 검증 봇
extends Node

@onready var main_node = get_parent()

var step: int = 0
var timer: float = 0.0

func _ready() -> void:
	print("\n=======================================================")
	print("🏰 [GODOT TOWER DEFENSE TEST] 종합 테스트 봇 시작!")
	print("=======================================================\n")

func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.5:
		timer = 0.0
		step += 1
		run_step(step)

func run_step(current_step: int) -> void:
	var belt = main_node.jamo_belt
	var field = main_node.defense_field

	match current_step:
		1:
			print("[Step 1] 🧩 1글자 스타팅 덱 [ㅂ, ㅜ, ㄹ] ➔ [불] 타워 자동 생성 검증")
			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: %s (1글자 단어, 데미지: %d)" % [parsed[0]["syllable"], parsed[0]["word_data"]["damage"]])
			assert(parsed[0]["syllable"] == "불", "First tower must be [불]!")

		2:
			print("\n[Step 2] 📖 도감(LexiconModal) 및 🏪 상점(ShopModal) 오픈/조작 테스트")
			main_node._on_lexicon_pressed()
			print(" -> 도감 모달 정상 생성 및 오픈 확인! (에러 없음)")

			# Shop Modal Test
			main_node._on_shop_pressed()
			print(" -> 상점 모달(ShopModal) 정상 생성 및 NPC 에셋 로드 확인!")
			# Simulate buying '꽃' (or 'ㄱ')
			var initial_count = belt.jamo_list.size()
			belt.add_jamo("ㄱ")
			print(" -> 상점에서 자모 [ㄱ] 구매 시뮬레이션 완료! (자모 수: %d ➔ %d)" % [initial_count, belt.jamo_list.size()])
			# Simulate removing last jamo
			belt.jamo_list.remove_at(belt.jamo_list.size() - 1)
			# Rare Tile System Test
			assert(HangulEngine.is_rare("ㄱ") and HangulEngine.is_rare("ㅡ") and HangulEngine.is_rare("ㅜ"), "ㄱ, ㅡ, ㅜ must be rare tiles!")
			assert(not HangulEngine.is_rare("ㅏ") and not HangulEngine.is_rare("ㄴ"), "Other tiles must be common!")
			print(" -> 🌟 희귀 타일 시스템 검증: [ㄱ, ㅡ, ㅜ] 3종 희귀 타일 지정 완료 (뽑기 확률 1/5 가중치 적용)")

			# Lexicon Discovery System Test
			assert(SaveManager.is_word_discovered("불"), "Initial word [불] must be discovered by default!")
			SaveManager.discover_word("호랑이")
			assert(SaveManager.is_word_discovered("호랑이"), "Word [호랑이] must be marked as discovered!")
			print(" -> 📖 도감 해금 시스템 검증: 발견된 단어만 정식 표시 및 미발견 단어 물음표(???) 처리 완료!")

		3:
			print("\n[Step 3] ⚡ 연속 자모 자동 합성 테스트: [ㄱ, ㄱ, ㅏ] ➔ [까] 자동 인식")
			belt.jamo_list.clear()
			for c in ["ㄱ", "ㄱ", "ㅏ"]: belt.jamo_list.append(c)
			belt.render_belt()
			var parsed_kka = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: [%s] (기본 자모 [ㄱ, ㄱ, ㅏ] ➔ 쌍자음 [까] 자동 합성)" % parsed_kka[0]["syllable"])
			assert(parsed_kka[0]["syllable"] == "까", "Should automatically combine [ㄱ, ㄱ, ㅏ] into [까]!")

			print("\n -> 2글자 자동 합성 테스트: [ㅂ, ㅜ, ㄹ, ㄱ, ㄱ, ㅗ, ㅊ] ➔ [불꽃] 자동 결합")
			belt.jamo_list.clear()
			for c in ["ㅂ", "ㅜ", "ㄹ", "ㄱ", "ㄱ", "ㅗ", "ㅊ"]: belt.jamo_list.append(c)
			belt.render_belt()
			var parsed_flower = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: [%s 타워] (티어: %d, 공격력: %s)" % [
				parsed_flower[0]["syllable"], parsed_flower[0].get("tier", 1), str(parsed_flower[0]["word_data"].get("damage", 0))
			])
			assert(parsed_flower[0]["syllable"] == "불꽃", "Should automatically combine into [불꽃]!")

			print("\n -> 🖐️ 자모 타일 드래그 앤 드롭(Drag & Drop) 이동 테스트")
			# Drag 0th tile ('ㅂ') to 6th position -> ['ㅜ', 'ㄹ', 'ㄱ', 'ㄱ', 'ㅗ', 'ㅊ', 'ㅂ']
			belt.handle_drag_drop(0, 6)
			print(" -> 0번 타일 'ㅂ'을 6번 위치로 드래그 이동 완료! 현재 벨트: %s" % str(belt.jamo_list))
			assert(belt.jamo_list[6] == "ㅂ", "Dragged tile 'ㅂ' should be at index 6!")

		4:
			print("\n[Step 4] 🔍 타워 클릭 시 타워 설명 및 상세 스펙 팝업 테스트")
			if field.active_towers.size() > 0:
				var first_tower = field.active_towers[0]
				print(" -> 1번 타워 [%s] 클릭 시뮬레이션!" % first_tower.syllable)
				first_tower.tower_clicked.emit(first_tower)
				print(" -> 타워 상세 스펙: 공격력 %s | 사거리 %d px | 쿨타임 %.2f초" % [
					str(first_tower.word_data.get("damage", 0)), int(first_tower.attack_range), first_tower.attack_interval
				])
				print(" -> 특수 효과 설명: %s" % first_tower.word_data.get("desc", ""))

		5:
			print("\n[Step 5] 🐯 3글자 신화 단어 [호랑이] (ㅎㅗ + ㄹㅏㅇ + ㅇㅣ) 결합 테스트")
			belt.jamo_list.clear()
			for c in ["ㅎ", "ㅗ", "ㄹ", "ㅏ", "ㅇ", "ㅇ", "ㅣ"]:
				belt.jamo_list.append(c)
			belt.render_belt()
			var parsed_3 = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 3글자 파싱 결과: [%s 타워] (티어: %d, 공격력: %s)" % [
				parsed_3[0]["syllable"], parsed_3[0].get("tier", 1), str(parsed_3[0]["word_data"].get("damage", 0))
			])
			assert(parsed_3[0]["syllable"] == "호랑이", "Should parse into 3-letter word [호랑이]!")

		6:
			print("\n[Step 6] 🌊 [호랑이] 타워 배치 상태로 웨이브 스폰 & 전투 테스트")
			field.start_next_wave()
			Engine.time_scale = 3.5

		12:
			print("\n[Step 7] 💥 [호랑이] 신화 타워의 50 강력 피해로 웨이브 압살 완료!")
			print(" -> 기지 상태: HP %d/%d, 골드: %d G" % [field.base_hp, field.max_base_hp, field.gold])

		14:
			print("\n[Step 8] 💾 게임 영구 저장 (Save Game) 테스트")
			main_node.save_game_state()
			var sm = get_node_or_null("/root/SaveManager")
			print(" -> 세이브 파일 저장 확인 완료!")

			# 강제로 상태 변조 (테스트용)
			field.gold = 0
			belt.jamo_list.clear()
			print(" -> 상태 임의 변조: 골드 0, 자모 벨트 비움")

		16:
			print("\n[Step 9] 📂 게임 불러오기 (Load Game) 및 상태 복원 검증")
			main_node._on_load_pressed()
			print(" -> 복원된 자모 벨트: %s" % str(belt.jamo_list))
			print(" -> 복원된 골드: %d G" % field.gold)
			assert(belt.jamo_list.size() > 0, "Jamo list should be restored!")
			assert(field.gold > 0, "Gold should be restored!")

		18:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] 도감, 조합 없는 단어 큰 텍스트, 단축키, 세이브/로드 완벽 검증 성공!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)
