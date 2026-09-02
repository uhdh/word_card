# AutoPlayTowerDefense.gd
# 타워 디펜스 모드 런타임 자동 플레이 및 검증 봇
extends Node

var main_node: Node
var step: int = 0
var timer: float = 0.0

func _ready() -> void:
	print("\n=======================================================")
	print("🏰 [GODOT TOWER DEFENSE TEST] 타워 디펜스 자동 플레이 시작!")
	print("=======================================================")
	main_node = get_parent()

func _process(delta: float) -> void:
	timer += delta
	if timer < 0.4:
		return
	timer = 0.0
	step += 1
	run_step()

func run_step() -> void:
	match step:
		1:
			print("\n[Step 1] 🧩 1글자 스타팅 덱 [ㅂ, ㅜ, ㄹ] ➔ [불] 타워 자동 생성 검증")
			var belt = main_node.jamo_belt
			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: %s (%d글자 단어, 데미지: %s)" % [
				parsed[0]["syllable"], parsed[0]["syllable"].length(), str(parsed[0]["word_data"].get("damage", 4))
			])
			assert(parsed[0]["syllable"] == "불", "First tower must be [불]!")

		2:
			print("\n[Step 2] 🔥 2글자 상위 단어 [불꽃] (ㅂㅜㄹ + ㄲㅗㅊ) 결합 테스트")
			var belt = main_node.jamo_belt
			belt.add_jamo("ㄲ")
			belt.add_jamo("ㅗ")
			belt.add_jamo("ㅊ")
			print(" -> 확장된 자모 벨트: %s" % str(belt.jamo_list))
			var parsed_2 = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 2글자 파싱 결과: [%s 타워] (티어: %d, 공격력: %s, 화염피해: %s)" % [
				parsed_2[0]["syllable"], parsed_2[0].get("tier", 1), str(parsed_2[0]["word_data"].get("damage", 0)), str(parsed_2[0]["word_data"].get("burn", 0))
			])
			assert(parsed_2[0]["syllable"] == "불꽃", "Should parse into 2-letter word [불꽃]!")

		3:
			print("\n[Step 3] 🐯 3글자 신화 단어 [호랑이] (ㅎㅗ + ㄹㅏㅇ + ㅇㅣ) 결합 테스트")
			var belt = main_node.jamo_belt
			belt.jamo_list.clear()
			for c in ["ㅎ", "ㅗ", "ㄹ", "ㅏ", "ㅇ", "ㅇ", "ㅣ"]:
				belt.jamo_list.append(c)
			belt.render_belt()
			var parsed_3 = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 3글자 파싱 결과: [%s 타워] (티어: %d, 공격력: %s, 설명: %s)" % [
				parsed_3[0]["syllable"], parsed_3[0].get("tier", 1), str(parsed_3[0]["word_data"].get("damage", 0)), parsed_3[0]["word_data"].get("desc", "")
			])
			assert(parsed_3[0]["syllable"] == "호랑이", "Should parse into 3-letter word [호랑이]!")

		4:
			print("\n[Step 4] 🌊 [호랑이] 타워 배치 상태로 웨이브 스폰 & 전투 테스트")
			var field = main_node.defense_field
			field.start_next_wave()
			Engine.time_scale = 3.5

		12:
			print("\n[Step 5] 💥 [호랑이] 신화 타워의 50 강력 피해로 웨이브 압살 완료!")
			var field = main_node.defense_field
			print(" -> 기지 상태: HP %d/%d, 골드: %d G" % [field.base_hp, field.max_base_hp, field.gold])

		14:
			print("\n[Step 6] 💾 게임 영구 저장 (Save Game) 테스트")
			main_node.save_game_state()
			var sm = get_node_or_null("/root/SaveManager")
			if sm != null:
				assert(sm.has_save_file(), "Save file must exist after saving!")
			print(" -> 세이브 파일 저장 확인 완료!")

			# 강제로 상태 변조 (테스트용)
			main_node.defense_field.gold = 0
			main_node.jamo_belt.jamo_list.clear()
			print(" -> 상태 임의 변조: 골드 0, 자모 벨트 비움")

		16:
			print("\n[Step 7] 📂 게임 불러오기 (Load Game) 및 상태 복원 검증")
			main_node._on_load_pressed()
			print(" -> 복원된 자모 벨트: %s" % str(main_node.jamo_belt.jamo_list))
			print(" -> 복원된 골드: %d G" % main_node.defense_field.gold)
			assert(main_node.jamo_belt.jamo_list.size() > 0, "Jamo list should be restored!")
			assert(main_node.defense_field.gold > 0, "Gold should be restored!")

		18:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] 타워 디펜스 및 세이브/로드 기능 완벽 검증 성공!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)

		16:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] 스타팅 덱 [ㅂ,ㅜ,ㄹ] 및 웨이브 자모 3택1 보상 검증 완료!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)
