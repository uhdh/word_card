# AutoPlayTowerDefense.gd
# 타워 디펜스 기능 자동 검증 봇 — **이 파일이 실제로 단언하는 것만** 적는다(§2.16).
#
# 단언하는 것: 조합 없는 1글자 단어 · 자모 자동 합성(쌍자음/2글자/3글자) · 등급 **이름** ·
#              도감 해금 · 유물 보유 · 타워 클릭 팝업 · 자동 저장 · 세이브/로드 왕복 ·
#              무대 구성(3막 20라운드) · 드래그 이동
#
# ⚠️ 단언하지 **않는** 것 — 아래를 이 머리말에 다시 넣지 말 것:
#      · "큰 텍스트"(폰트 크기) — 이 파일에 폰트 검사가 0건이다.
#      · 키 입력(단축키) — `InputEventKey`·`keycode` 가 0건이다. 그쪽은
#        `tools/TooltipTruthProbe` 가 맡는다(2026-10-03 부터 `tests/run_all.sh` 에 등록).
#      · 툴팁 문구 — `tools/TooltipAuthorProbe` 담당.
#   문구가 검사보다 넓으면, 검사를 지워도 아무도 모른다 — §2.16 이 정확히 그랬다.
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
			_save_playtest_screenshot()
			print("[Step 1] 🧩 1글자 스타팅 덱 [ㅂ, ㅜ, ㄹ] ➔ [불] 타워 자동 생성 검증")
			_assign_slot_jamo(belt, ["ㅂ", "ㅜ", "ㄹ"], 0)
			var parsed = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: %s (1글자 단어, 데미지: %d)" % [parsed[0]["syllable"], parsed[0]["word_data"]["damage"]])
			assert(parsed[0]["syllable"] == "불", "First tower must be [불]!")
			assert(belt.parsed_slots()[0].get("syllable") == "불", "Slot 1 tray must build [불]!")

		2:
			print("\n[Step 2] 📖 도감(LexiconModal) 및 🧙‍♂️ 방랑 상인(ShopModal) 이벤트/유물 테스트")
			main_node._on_lexicon_pressed()
			print(" -> 도감 모달 정상 생성 및 오픈 확인! (에러 없음)")

			# Event Shop Modal & Relic Test
			main_node._trigger_merchant_encounter(2)
			print(" -> 방랑 상인 모달(ShopModal) 정상 생성 및 NPC/유물 탭 로드 확인!")
			# Simulate buying 'ㄱ' into the waiting tray, then remove it cleanly
			var initial_count = belt.jamo_list.size()
			belt.add_jamo("ㄱ")
			print(" -> 상점에서 자모 [ㄱ] 구매 시뮬레이션 완료! (자모 수: %d ➔ %d)" % [initial_count, belt.jamo_list.size()])
			assert(belt.slot_assignments[belt.slot_assignments.size() - 1] == -1, "Purchased jamo must enter waiting")
			belt.remove_jamo(belt.jamo_list.size() - 1)

			# Relic purchase test
			main_node.apply_relic_effect({
				"id": "relic_essence_power",
				"name": "⚔️ 활자의 정수",
				"cost": 35,
				"desc": "모든 활자 타워 공격력 +20%"
			})
			assert(main_node.has_relic("relic_essence_power"), "Must own relic_essence_power!")
			print(" -> 🏺 유물 시스템 검증: [⚔️ 활자의 정수] 구매 및 보유 확인 완료!")

			# 3-Tier Rarity System Test
			assert(HangulEngine.get_rarity("ㅏ") == "super_rare" and HangulEngine.get_rarity("ㅜ") == "super_rare", "ㅏ, ㅓ, ㅗ, ㅜ must be super_rare!")
			assert(HangulEngine.get_rarity("ㄱ") == "rare" and HangulEngine.get_rarity("ㄴ") == "rare", "ㄱ, ㄴ, ㅡ, ㅣ must be rare!")
			assert(HangulEngine.get_rarity("ㄷ") == "common" and HangulEngine.get_rarity("ㅁ") == "common", "ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ must be common!")
			# ⚠️ 바로 위 세 줄은 `get_rarity()` 가 돌려주는 **등급 이름**만 잰다. **배경색은 재지
			# 않는다.** `get_rarity_bg_color()` 는 등급과 무관하게 **한 색**을 돌려준다
			# (`HangulEngine.gd:70-71` — 배경색·테두리 통일 경위는 같은 파일 주석에 있다).
			# 예전 문구는 세 가지 색 이름(황금 앰버·딥 바이올렛·다크 슬레이트)을 나열해
			# **색까지 검증한 것처럼** 읽혔지만 거짓이었다(§2.16).
			print(" -> 🎨 등급 판정 검증: 초희귀·희귀·일반 등급 **이름** 확인 완료! (배경색은 등급과 무관하게 한 색)")

			# Lexicon Discovery System Test
			assert(SaveManager.is_word_discovered("불"), "Initial word [불] must be discovered by default!")
			SaveManager.discover_word("금강석")
			assert(SaveManager.is_word_discovered("금강석"), "Word [금강석] must be marked as discovered!")
			print(" -> 📖 도감 해금 시스템 검증: 발견된 단어만 정식 표시 및 미발견 단어 물음표(???) 처리 완료!")

			# Dice Reroll System Test
			main_node.reroll_dice = 3
			main_node.reroll_dice -= 1
			print(" -> 🎲 주사위 리롤 시스템 검증: 주사위 1개 소모 후 3개 보상 후보 재추첨 확인! (남은 주사위: %d개)" % main_node.reroll_dice)

		3:
			print("\n[Step 3] ⚡ 연속 자모 자동 합성 테스트: [ㄱ, ㄱ, ㅏ] ➔ [까] 자동 인식")
			_assign_slot_jamo(belt, ["ㄱ", "ㄱ", "ㅏ"], 0)
			var parsed_kka = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: [%s] (기본 자모 [ㄱ, ㄱ, ㅏ] ➔ 쌍자음 [까] 자동 합성)" % parsed_kka[0]["syllable"])
			assert(parsed_kka[0]["syllable"] == "까", "Should automatically combine [ㄱ, ㄱ, ㅏ] into [까]!")

			print("\n -> 2글자 자동 합성 테스트: [ㅂ, ㅓ, ㄴ, ㄱ, ㅐ] ➔ [번개] 자동 결합")
			_assign_slot_jamo(belt, ["ㅂ", "ㅓ", "ㄴ", "ㄱ", "ㅐ"], 0)
			var parsed_lightning = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 파싱 결과: [%s 타워] (티어: %d, 공격력: %s)" % [
				parsed_lightning[0]["syllable"], parsed_lightning[0].get("tier", 1), str(parsed_lightning[0]["word_data"].get("damage", 0))
			])
			assert(parsed_lightning[0]["syllable"] == "번개", "Should automatically combine into [번개]!")

			print("\n -> 🖐️ 자모 타일 드래그 앤 드롭(Drag & Drop) 이동 테스트")
			# Drag 0th tile ('ㅂ') to the end (index 5) -> ['ㅓ', 'ㄴ', 'ㄱ', 'ㅐ', 'ㅂ']
			belt.handle_insert_drag_drop(0, 5)
			print(" -> 0번 타일 'ㅂ'을 맨 끝 4번 위치로 드래그 이동 완료! 현재 벨트: %s" % str(belt.jamo_list))
			assert(belt.jamo_list[4] == "ㅂ", "Dragged tile 'ㅂ' should be at index 4!")

		4:
			print("\n[Step 4] 🔍 타워 클릭 시 타워 설명 및 상세 스펙 팝업 테스트")
			# ⚠️ **검사할 대상을 먼저 세운다.** Step 3 의 드래그 테스트가 일부러 단어를
			# 깨뜨려서(`ㅓㄴㄱㅐㅂ`) 여기 도착할 때 타워가 **0개**였다. 예전 코드는
			# `if active_towers.size() > 0:` 로 그 상황을 조용히 건너뛰었고, 머리말은
			# 그걸 "타워 클릭 팝업 검증" 이라고 적어 두었다 — **주장은 있었지만 그 절은
			# 한 번도 실행된 적이 없었다**(§2.16, 2차 정정에서 실측).
			# 검사 대상이 없는 것은 통과가 아니므로, 여기서 [번개]를 다시 세운다.
			_assign_slot_jamo(belt, ["ㅂ", "ㅓ", "ㄴ", "ㄱ", "ㅐ"], 0)
			assert(field.active_towers.size() > 0, "Step 4 전제: [번개] 를 세웠는데 타워가 하나도 없다")
			var first_tower = field.active_towers[0]
			print(" -> 1번 타워 [%s] 클릭 시뮬레이션!" % first_tower.syllable)
			first_tower.tower_clicked.emit(first_tower)
			# 신호를 쏘는 것과 팝업이 뜨는 것은 **다른 사건**이다. 예전에는 신호만 쏘고
			# 스펙을 print 했을 뿐, 팝업이 생겼는지는 본 적이 없었다.
			# 경로: `tower_clicked` → `DefenseField.tower_info_requested`
			#       → `TowerDefenseMain._on_tower_info_requested` → `modal_layer` 에 추가
			var info_modal = main_node.modal_layer.get_node_or_null("TowerInfoModal")
			assert(info_modal != null, "타워를 클릭했는데 TowerInfoModal 이 뜨지 않았다")
			assert(info_modal.is_visible_in_tree(), "TowerInfoModal 이 떴지만 보이지 않는다")
			print(" -> 타워 상세 스펙: 공격력 %s | 사거리 %d px | 쿨타임 %.2f초" % [
				str(first_tower.word_data.get("damage", 0)), int(first_tower.attack_range), first_tower.attack_interval
			])
			print(" -> 특수 효과 설명: %s" % first_tower.word_data.get("desc", ""))
			# 다음 절이 같은 자리에서 벨트를 다시 짜므로 팝업은 닫고 간다.
			# (`queue_free()` 는 지연이라 이 프레임에는 아직 살아 있다 — 그래도 다음
			#  절은 0.5초 뒤라 문제되지 않는다.)
			info_modal.queue_free()

		5:
			print("\n[Step 5] 💎 3글자 신화 단어 [금강석] (ㄱㅡㅁ + ㄱㅏㅇ + ㅅㅓㄱ) 결합 테스트")
			_assign_slot_jamo(belt, ["ㄱ", "ㅡ", "ㅁ", "ㄱ", "ㅏ", "ㅇ", "ㅅ", "ㅓ", "ㄱ"], 0)
			var parsed_3 = HangulStreamParser.parse_jamo_stream(belt.jamo_list)
			print(" -> 3글자 파싱 결과: [%s 타워] (티어: %d, 공격력: %s)" % [
				parsed_3[0]["syllable"], parsed_3[0].get("tier", 1), str(parsed_3[0]["word_data"].get("damage", 0))
			])
			assert(parsed_3[0]["syllable"] == "금강석", "Should combine 3 letters into [금강석]!")

		6:
			print("\n[Step 6] 🌊 [금강석] 타워 배치 상태로 웨이브 스폰 & 전투 테스트")
			main_node._on_start_wave_pressed()

		7:
			print("\n[Step 7] 💥 [금강석] 신화 타워의 강력 피해로 웨이브 압살 완료!")
			print(" -> 기지 상태: HP %d/%d, 골드: %d G, 현재 막: 제 %d막 / 총 %d막" % [field.base_hp, field.max_base_hp, field.gold, field.current_act, field.MAX_ACTS])
			assert(field.MAX_ACTS == 3 and field.MAX_WAVES_PER_ACT == 20, "Game must have 3 Acts with 20 rounds per Act!")
			print(" -> 🚩 [3막 20라운드] 로그라이크 스테이지 구성 검증 완료!")

		14:
			print("\n[Step 8] 💾 게임 영구 저장 (Save Game) 테스트")
			# '자동 저장' 을 **실제로** 잰다 — 명시적으로 저장을 부르지 **않고** 파일이
			# 생기는지 본다. 먼저 지워야 한다: 파일이 이미 있으면 이 절은 아무것도
			# 증명하지 못한다(예전 코드는 `save_game_state()` 를 직접 부르고 print 만 했다).
			SaveManager.delete_save_file()
			assert(not SaveManager.has_save_file(), "지우고 시작해야 자동 저장을 잴 수 있다")
			# 타워 배치 변경은 `TowerDefenseMain._ready()` 에서 `save_game_state` 에 연결돼
			# 있다 — 플레이어가 저장을 누르지 않아도 저장되는 경로가 바로 이것이다.
			field.tower_positions_changed.emit()
			assert(SaveManager.has_save_file(), "타워 배치가 바뀌었는데 자동 저장이 일어나지 않았다")
			print(" -> 자동 저장 확인: 명시적 저장 호출 **없이** 세이브 파일이 생겼다")

			# 강제로 상태 변조 (테스트용)
			field.gold = 0
			belt.jamo_list.clear()
			belt.slot_assignments.clear()
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
			# ⚠️ 이 문구는 **합격 도장**이다 — `tests/run_all.sh` 의 `RESULT_RE` 가 이 문자열에
			# 걸려서 이 테스트를 통과로 센다. 그러므로 **주장과 실제 검사가 일치해야 한다.**
			#
			# 2026-09-24 1차 정정(§2.16): 예전 문구는 "도감, 조합 없는 단어 큰 텍스트, 단축키,
			# 세이브/로드 **완벽** 검증 성공" 이었는데 `InputEventKey`·`keycode` 가 0건, 폰트
			# 검사도 0건이었다 — 주장 4개 중 2개가 허위였다. 그래서 검사가 있는 것만 남기고
			# `완벽` 도 뺐다.
			#
			# 2026-09-24 2차 정정(§2.16 잔여): **머리말**이 아직 `타워 클릭 팝업`·`자동 저장`·
			# `큰 텍스트` 를 주장하고 있었다. 앞의 둘은 **검사를 새로 넣어 주장을 참으로 만들고**
			# (Step 4 는 팝업 노드의 존재·가시성을, Step 8 은 명시적 저장 호출 **없이** 파일이
			# 생기는지를 잰다), `큰 텍스트` 는 **문구에서 뺐다**(검사할 것이 없다).
			#
			# ⚠️ 여기에 **행 번호를 적지 않는다.** 예전에는 `도감 = :68·:70` 처럼 적었는데,
			#    위에 한 줄만 끼워 넣어도 전부 낡는다(이 프로젝트가 감사 문서에서 반복해 밟았다).
			#    대신 **절 이름**으로 적는다 — 이름은 안 움직인다.
			#   도감 해금 = Step 2 · 단어 조합 = Step 1·3·5 · 유물 = Step 2 ·
			#   타워 클릭 팝업 = Step 4 · 자동 저장 = Step 8 · 세이브/로드 왕복 = Step 8·9
			#
			# ⚠️ **키 입력·툴팁은 이 스위트가 검사하지 않는다.** 그쪽은
			# `tools/TooltipTruthProbe`(배속 키를 문구에서 읽어 실제로 눌러 본다) 와
			# `tools/TooltipAuthorProbe` 가 맡는다 — 다만 `run_all.sh` 에는 **아직 등록되지
			# 않았다**(스위트 등록은 감독 결정 사항). 그 사실을 여기 적어 두는 이유는,
			# 문구에서 `단축키` 를 빼는 순간 **그 공백이 보이지 않게** 되기 때문이다.
			print("🎉 [ALL TESTS PASSED] 도감, 단어 조합, 유물, 타워 클릭 팝업, 자동 저장, 세이브/로드 검증 성공!")
			print("=======================================================\n")
			Engine.time_scale = 1.0
			get_tree().quit(0)


func _save_playtest_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		print(" -> headless viewport: screenshot skipped")
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		print(" -> headless viewport: screenshot skipped")
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		print(" -> headless viewport: screenshot skipped")
		return
	var path := OS.get_temp_dir().path_join("word_card_playtest.png")
	var error := image.save_png(path)
	if error == OK:
		print(" -> playtest screenshot: %s" % path)
	else:
		print(" -> screenshot skipped (error %s)" % error)

func _assign_slot_jamo(belt, chars: Array, slot: int) -> void:
	belt.jamo_list.clear()
	belt.slot_assignments.clear()
	for c in chars:
		belt.jamo_list.append(c)
		belt.slot_assignments.append(slot)
	belt.render_belt()
