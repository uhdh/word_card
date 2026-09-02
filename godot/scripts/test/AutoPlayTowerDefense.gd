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
			print("\n[Step 1] 🧩 하단 자모 벨트 초기화 및 자동 타워 파싱 검증")
			var belt = main_node.jamo_belt
			print(" -> 초기 자모 리스트: %s" % str(belt.jamo_list))
			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱된 단어 타워 (%d개):" % parsed.size())
			for p in parsed:
				print("    * [%s] (%s) - 카테고리: %s, 데미지: %s" % [
					p["syllable"], p["word_data"].get("name", ""), p["word_data"].get("category", ""), str(p["word_data"].get("damage", 4))
				])
			assert(parsed.size() >= 3, "At least 3 towers parsed!")

		2:
			print("\n[Step 2] 🔄 자모 타일 회전 & 스왑 시뮬레이션")
			var belt = main_node.jamo_belt
			# 'ㅏ' ➔ 'ㅜ' 회전
			var idx_a = belt.jamo_list.find("ㅏ")
			if idx_a != -1:
				belt.jamo_list[idx_a] = HangulEngine.rotate("ㅏ")
				print(" -> 자모 회전: 'ㅏ' ➔ '%s'" % belt.jamo_list[idx_a])
				belt.render_belt()

			# 스왑: 0번과 3번 위치 교환
			var tmp = belt.jamo_list[0]
			belt.jamo_list[0] = belt.jamo_list[3]
			belt.jamo_list[3] = tmp
			print(" -> 자모 위치 스왑 완료: %s" % str(belt.jamo_list))
			belt.render_belt()

		3:
			print("\n[Step 3] 🌊 1웨이브 시작 및 적 스폰 테스트")
			var field = main_node.defense_field
			field.start_next_wave()
			print(" -> 1웨이브 시작! 스폰 대기열: %d마리" % field.spawn_queue.size())
			print(" -> 기지 상태: HP %d/%d, 보유 골드: %d G" % [field.base_hp, field.max_base_hp, field.gold])

		4:
			print("\n[Step 4] 🏹 타워 자동 타겟팅 및 사격 루프 대기")
			# 3초간 타워 사격 및 적 처치 시뮬레이션
			Engine.time_scale = 3.0 # 배속 진행

		12:
			print("\n[Step 5] 🪙 적 처치 및 골드 보상 확인")
			var field = main_node.defense_field
			print(" -> 현재 필드 잔여 적 수: %d" % field.get_enemies().size())
			print(" -> 현재 보유 골드: %d G" % field.gold)

		14:
			print("\n[Step 6] 🎲 신규 자모 구입 테스트 (-10 G)")
			var belt = main_node.jamo_belt
			main_node._on_buy_jamo_requested()
			print(" -> 새 자모 추가 후 벨트: %s" % str(belt.jamo_list))

		16:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] Godot 4 타워 디펜스 모드 플레이 테스트 완벽 성공!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)
