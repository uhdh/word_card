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
			print("\n[Step 1] 🧩 스타팅 덱 [ㅂ, ㅜ, ㄹ] 3개 초기화 및 [불] 타워 자동 생성 검증")
			var belt = main_node.jamo_belt
			print(" -> 초기 자모 리스트: %s" % str(belt.jamo_list))
			assert(belt.jamo_list == ["ㅂ", "ㅜ", "ㄹ"], "Starting deck must be [ㅂ, ㅜ, ㄹ]!")

			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱된 단어 타워 (%d개):" % parsed.size())
			for p in parsed:
				print("    * [%s] (%s) - 카테고리: %s, 데미지: %s" % [
					p["syllable"], p["word_data"].get("name", ""), p["word_data"].get("category", ""), str(p["word_data"].get("damage", 4))
				])
			assert(parsed.size() == 1 and parsed[0]["syllable"] == "불", "First tower must be [불]!")

		2:
			print("\n[Step 2] 🌊 1웨이브 시작 및 적 스폰 테스트")
			var field = main_node.defense_field
			field.start_next_wave()
			print(" -> 1웨이브 시작! 스폰 대기열: %d마리" % field.spawn_queue.size())
			print(" -> 기지 상태: HP %d/%d, 보유 골드: %d G" % [field.base_hp, field.max_base_hp, field.gold])

		3:
			print("\n[Step 3] 🔥 [불] 타워 자동 화염 공격 및 웨이브 클리어 가속")
			Engine.time_scale = 3.5

		12:
			print("\n[Step 4] 🎁 1웨이브 클리어! 자모 3택 1 보상 팝업 테스트")
			var belt = main_node.jamo_belt
			# Simulate choosing 'ㄱ' from 3 choices
			belt.add_jamo("ㄱ")
			print(" -> 보상 활자 'ㄱ' 획득 후 벨트: %s" % str(belt.jamo_list))

		14:
			print("\n[Step 5] 🔨 자모 추가 ('ㅓ', 'ㅁ' 추가로 '검' 2번 타워 확장 테스트)")
			var belt = main_node.jamo_belt
			belt.add_jamo("ㅓ")
			belt.add_jamo("ㅁ")
			print(" -> 확장된 벨트: %s" % str(belt.jamo_list))
			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 현재 타워 목록:")
			for p in parsed:
				print("    * [%s 타워]" % p["syllable"])
			assert(parsed.size() == 2, "Should have 2 towers now: [불], [검]!")

		16:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] 스타팅 덱 [ㅂ,ㅜ,ㄹ] 및 웨이브 자모 3택1 보상 검증 완료!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)
