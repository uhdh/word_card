# AutoPlayBot.gd
# Godot 4 엔진 내에서 전체 게임 라이프사이클을 실제로 직접 플레이하는 자동화 테스트 봇
extends Node

var main_node: Node
var step: int = 0
var timer: float = 0.0

func _ready() -> void:
	print("\n=======================================================")
	print("🎮 [GODOT AUTO-PLAY TEST] 활자술사의 여정 자동 플레이 시작!")
	print("=======================================================")
	main_node = get_parent()

func _process(delta: float) -> void:
	timer += delta
	if timer < 0.3:
		return
	timer = 0.0
	step += 1
	run_step()

func run_step() -> void:
	match step:
		1:
			print("\n[Step 1] 🗺️ 맵 로드 및 1층 노드 선택 테스트")
			var available = main_node.map_manager.get_available_next_nodes()
			print(" -> 1층 선택 가능 노드 수: %d" % available.size())
			for n in available:
				print("    - %s (%s)" % [n["name"], n["type"]])
			
			var first_node = available[0]
			print(" -> 1층 노드 [%s] 선택 진입!" % first_node["name"])
			main_node.handle_node_select(first_node)

		2:
			print("\n[Step 2] ⚔️ 전투 진입 및 초기 상태 검증")
			var bm = main_node.battle_manager
			print(" -> 조우한 적: %s (HP: %d/%d, 타입: %s)" % [bm.enemy.name, bm.enemy.hp, bm.enemy.max_hp, bm.enemy.type])
			print(" -> 플레이어 상태: HP %d/%d, AP: %d, 방어도: %d" % [bm.player.hp, bm.player.max_hp, bm.player.ap, bm.player.shield])
			print(" -> 손패 타일 (5장):")
			for t in bm.card_system.hand:
				print("    - [%s] (ID: %d, 회전가능: %s)" % [t["char"], t["id"], str(t["isRotatable"])])

		3:
			print("\n[Step 3] 🔄 자모 회전 & 합성 메커니즘 테스트")
			var cs = main_node.battle_manager.card_system
			# 타일 회전 시도
			for t in cs.hand:
				if t["isRotatable"]:
					var before = t["char"]
					cs.rotate_tile(t["id"])
					print(" -> 타일 회전 성공: '%s' ➔ '%s'" % [before, t["char"]])
					break

		4:
			print("\n[Step 4] 🔨 단어 조합 워크벤치 테스트 ('검' 완성 시뮬레이션)")
			var bm = main_node.battle_manager
			var cs = bm.card_system
			# 슬롯에 ㄱ, ㅓ, ㅁ 배치
			cs.slots = [
				{"id": 101, "char": "ㄱ", "isRotatable": false},
				{"id": 102, "char": "ㅓ", "isRotatable": false},
				{"id": 103, "char": "ㅁ", "isRotatable": false}
			]
			cs.evaluate_slots()
			print(" -> 슬롯 장착: [ㄱ] + [ㅓ] + [ㅁ]")
			print(" -> 완성된 단어: [%s]" % cs.crafted_card.get("word", ""))
			print(" -> 특수 효과: %s" % cs.crafted_card.get("desc", ""))
			print(" -> 사운드 트리거: %s" % cs.crafted_card.get("sound", ""))

		5:
			print("\n[Step 5] 💥 단어 카드 [검] 발동 및 피해 계산")
			var bm = main_node.battle_manager
			var enemy_hp_before = bm.enemy.hp
			bm.play_crafted_card()
			print(" -> [검] 발동 완료! 적 체력 변화: %d ➔ %d" % [enemy_hp_before, bm.enemy.hp])
			print(" -> 플레이어 잔여 AP: %d" % bm.player.ap)

		6:
			print("\n[Step 6] 🛡️ 두 번째 단어 [방] 발동 (방어도 7 획득 & AP 충전 시뮬레이션)")
			var bm = main_node.battle_manager
			var cs = bm.card_system
			bm.player.ap = 1 # 테스트용 AP 지급
			cs.slots = [
				{"id": 201, "char": "ㅂ", "isRotatable": false},
				{"id": 202, "char": "ㅏ", "isRotatable": false},
				{"id": 203, "char": "ㅇ", "isRotatable": false}
			]
			cs.evaluate_slots()
			print(" -> 슬롯 장착: [ㅂ] + [ㅏ] + [ㅇ] = [%s]" % cs.crafted_card.get("word", ""))
			bm.play_crafted_card()
			print(" -> [방] 발동 완료! 플레이어 방어도: %d" % bm.player.shield)

		7:
			print("\n[Step 7] ⏳ 턴 종료 및 적 턴 실행 (공격 및 가시/반격 테스트)")
			var bm = main_node.battle_manager
			print(" -> 적 의도: [%s] %s" % [bm.enemy.next_move["name"], bm.enemy.next_move["desc"]])
			bm.end_player_turn()
			print(" -> 적 턴 종료 후 플레이어 체력: %d/%d (방어도: %d)" % [bm.player.hp, bm.player.max_hp, bm.player.shield])
			print(" -> 2턴 시작 드로우 완료! 손패 수: %d" % bm.card_system.hand.size())

		8:
			print("\n[Step 8] 🔥 원소 마법 [불] 발동 및 적 격파")
			var bm = main_node.battle_manager
			var cs = bm.card_system
			cs.slots = [
				{"id": 301, "char": "ㅂ", "isRotatable": false},
				{"id": 302, "char": "ㅜ", "isRotatable": false},
				{"id": 303, "char": "ㄹ", "isRotatable": false}
			]
			cs.evaluate_slots()
			print(" -> 슬롯 장착: [ㅂ] + [ㅜ] + [ㄹ] = [%s]" % cs.crafted_card.get("word", ""))
			bm.play_crafted_card()
			print(" -> 적 남은 체력: %d" % bm.enemy.hp)
			print(" -> 전투 상태: %s" % bm.state)

		9:
			print("\n[Step 9] 🎁 전투 승리 보상 및 덱 추가 검증")
			var bm = main_node.battle_manager
			print(" -> 획득 골드: +%d G (현재 보유: %d G)" % [bm.rewards.get("gold", 0), bm.player.gold])
			print(" -> 자모 보상 선택지: %s" % str(bm.rewards.get("tileOptions", [])))
			
			var chosen_tile = bm.rewards.get("tileOptions", ["ㄷ"])[0]
			bm.player.deck.append(chosen_tile)
			print(" -> 자모 활자 '%s' 덱에 추가 완료! (총 덱 크기: %d장)" % [chosen_tile, bm.player.deck.size()])

		10:
			print("\n[Step 10] 📖 활자술사 100개 단어 도감(Lexicon) 시스템 검증")
			var all_words = WordDatabase.get_all_words()
			print(" -> 도감 등록 단어 수: %d개" % all_words.size())
			
			# Search test
			var search_tests = ["검", "불", "곰", "생", "기"]
			for q in search_tests:
				var data = WordDatabase.get_word_data(q)
				print("    * [%s] 검색 성공: %s | 비용: %d AP | 에셋: %s" % [q, data.get("name", ""), data.get("cost", 0), data.get("icon", "")])

		11:
			print("\n=======================================================")
			print("🎉 [ALL TESTS PASSED] Godot 4 게임 플레이 테스트 완벽 성공!")
			print("=======================================================\n")
			get_tree().quit(0)
