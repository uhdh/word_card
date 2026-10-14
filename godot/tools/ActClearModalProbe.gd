extends Node
# 막 클리어 모달의 **시작 시점 계약**을 직접 잰다 (§2.11, 2026-09-23).
#
# 왜 게이트로는 못 잡는가:
# §2.11 의 수정은 "모달이 떠 있는 동안에는 다음 막 웨이브를 시작하지 않는다" 인데,
# **난이도 게이트는 이 회귀에 눈이 멀어 있다.** 웨이브가 즉시 시작해도 봇은 그대로
# 60라운드를 돈다 — 봇이 `_advance_act()` 에서 `_on_start_wave_pressed()` 를 직접 부르고,
# 이미 돌고 있으면 그 호출이 no-op 이 될 뿐이기 때문이다. 그래서 따로 재야 한다.
#
# 재는 것:
#   1) `_on_act_cleared` 직후 — 모달이 떠 있고, **웨이브는 시작되지 않았다**
#   2) 닫기 버튼이 있고, 문구가 '다음 막 시작' 을 가리킨다
#   3) 모달에 `_close()` 가 있다 (봇의 `_clear_modals()` 가 같은 문을 지나야 한다)
#   4) **Space 경로(`_on_start_wave_pressed`)가 모달을 우회하지 못한다**
#      — 닫고 나서 시작한다. 우회하면 모달의 약속이 거짓이 되고 모달 버튼이 먹통이 된다.
#   5) 봇의 문(`_close()`)도 같은 계약을 지킨다 — 정확히 한 번 시작한다
#   6) 모달이 **스스로의 시작을 막지 않는다** (참조를 콜백 전에 비우지 않으면 여기서 걸린다)
#
# 실행: godot --headless --path . res://tools/ActClearModalProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 닫히지 않은 막 클리어 모달을 찾는다. 닫힌 모달은 페이드아웃(0.14초) 동안 트리에
## 남아 있으므로 `_closed` 로 걸러야 한다.
func _open_act_clear_modal(main) -> ActClearModal:
	for child in main.modal_layer.get_children():
		if child is ActClearModal and not child._closed:
			return child
	return null

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	# `_ready` 끝에 `call_deferred("_start_wave_automatically")` 가 있다 — 두 프레임 기다려
	# 그게 끝난 뒤에 우리가 기준선을 잡는다.
	await get_tree().process_frame
	await get_tree().process_frame

	# 이 도구는 세이브를 덮어쓰지 않는다. `save_game_state()` 는 `_is_loading_state` 면
	# 즉시 반환하므로, 그 플래그로 막는다(`_on_act_cleared` 가 저장을 부른다).
	main._is_loading_state = true

	# ⚠️ **남아 있는 세이브에 기대지 않는다.** 게이트(`DifficultyPlaytest`)를 돌린 뒤에는
	# 테스트 세이브가 `3막 20라운드` 로 남아 있을 수 있고, 그러면 `start_next_wave()` 가
	# 더 진행할 막이 없어 웨이브를 시작하지 않는다 → **거짓 실패**(실측: `wave_before=20`
	# 에서 RC=3). 그래서 외부 상태를 읽지 않고 **알려진 기준선으로 직접 되돌린다.**
	main.start_new_game()          # 1막 0라운드로 리셋 + 테스트 세이브 삭제
	await get_tree().process_frame
	await get_tree().process_frame
	# `start_new_game` 은 끝에서 `_is_loading_state = false` 로 되돌리므로 다시 잠근다.
	main._is_loading_state = true
	# 리셋 직후 `call_deferred("_start_wave_automatically")` 가 웨이브를 하나 시작한다 — 멈춘다.
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	var wave_before: int = main.defense_field.current_wave
	check(main.defense_field.current_act == 1,
		"기준선이 1막이 아니다 (제 %d막) — 이 실행은 다른 것을 재고 있다" % main.defense_field.current_act)
	check(not main.defense_field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다")

	# ── 1. 막 클리어를 직접 일으킨다 (보스 20라운드를 돌릴 필요 없이 그 경로만 태운다) ──
	main._on_act_cleared(1, 100)
	await get_tree().process_frame

	var modal: ActClearModal = _open_act_clear_modal(main)
	print("ACT_CLEAR_PROBE modal=%s wave_before=%d wave_after_show=%d running=%s" % [
		"yes" if modal != null else "NO", wave_before,
		main.defense_field.current_wave, str(main.defense_field.is_wave_running)])

	check(modal != null, "막 클리어 모달이 뜨지 않았다")
	check(not main.defense_field.is_wave_running,
		"모달이 떠 있는데 다음 막 웨이브가 **이미 시작됐다** — §2.11 이 고치려던 바로 그 상태다")
	check(main.defense_field.current_wave == wave_before,
		"모달이 뜨는 것만으로 웨이브가 진행했다 (%d → %d)" % [wave_before, main.defense_field.current_wave])

	# ── 2~3. 닫기 버튼과 `_close()` ─────────────────────────────────────────
	check(modal != null and modal.has_method("_close"),
		"모달에 `_close()` 가 없다 — `DifficultyPlaytest._clear_modals()` 가 queue_free 로 나가서 봇이 플레이어와 다른 문을 지난다")

	var button: Button = null
	if modal != null:
		for node in modal.find_children("*", "Button", true, false):
			button = node
			break
	check(button != null, "닫기 버튼이 없다 — 플레이어가 모달을 먼저 닫을 수단이 없다")
	if button != null:
		print("ACT_CLEAR_PROBE button=\"%s\"" % button.text)
		check(button.text.contains("제 2막"),
			"버튼 문구가 다음 막을 가리키지 않는다: \"%s\"" % button.text)

	# ── 2b. §2.27 — `[SPACE]` 안내가 **보이는 표면**에 있는가 ─────────────────
	# 예전에는 그 안내가 씬에서 `visible = false` 인 상단 `BtnStartWave` 의 툴팁 하나뿐이었고
	# (코드에 `.show()` 가 0건) → **영영 안 보였다.** 노드를 지우면서 안내를 이 모달로 옮겼다:
	# Space 가 실제로 일하는 **유일한 순간**이기 때문이다. 여기서 **도달**을 직접 잰다.
	if modal != null:
		var guide: Label = null
		for node in modal.find_children("*", "Label", true, false):
			if (node as Label).text.contains("[SPACE]"):
				guide = node
				break
		print("ACT_CLEAR_PROBE space_guide=%s" % ("yes" if guide != null else "NO"))
		check(guide != null,
			"막 클리어 모달이 `[SPACE]` 안내를 나르지 않는다 — §2.27 의 안내가 갈 곳이 없어졌다")
		if guide != null:
			check(guide.is_visible_in_tree(),
				"`[SPACE]` 안내를 가진 라벨이 **보이지 않는다** — 안내가 다시 도달 불가능해졌다")

	# ── 4. Space 는 모달을 우회하지 못한다 ─────────────────────────────────
	# 두 입력 모두 `_on_start_wave_pressed()` 를 지나므로, 그 함수를 직접 태워 잰다.
	# 예전에는 여기서 모달을 건너뛰고 웨이브가 시작됐다 — 그 결과 모달의 약속
	# ("닫으면 시작됩니다")이 거짓이 되고, 모달 버튼은 `is_wave_running` 에 걸려 먹통이 됐다.
	if modal != null:
		main._on_start_wave_pressed()
		await get_tree().process_frame
		print("ACT_CLEAR_PROBE start_key_path wave=%d running=%s modal_closed=%s" % [
			main.defense_field.current_wave, str(main.defense_field.is_wave_running),
			str(modal._closed)])
		check(modal._closed,
			"Space 경로가 모달을 우회했다 — 모달이 열린 채 웨이브가 시작됐다(모달 버튼이 먹통이 된다)")
		check(main.defense_field.is_wave_running,
			"Space 경로가 모달을 닫았지만 웨이브를 시작하지 않았다 — 모달이 스스로의 시작을 막았다")
		check(main.defense_field.current_wave == wave_before + 1,
			"Space 경로로 웨이브가 정확히 하나 진행하지 않았다 (%d → %d)" % [wave_before, main.defense_field.current_wave])

		var wave_after_key: int = main.defense_field.current_wave
		main._on_start_wave_pressed()
		await get_tree().process_frame
		check(main.defense_field.current_wave == wave_after_key,
			"Space 를 두 번 누르니 웨이브가 더 진행했다 (%d → %d)" % [wave_after_key, main.defense_field.current_wave])

	# ── 5~6. 봇의 문(`_close()`)도 같은 계약을 지키는가 ──────────────────────
	# 웨이브를 멈춰 세우고 두 번째 막 클리어를 일으킨다(첫 모달은 이미 닫혔다).
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	main._on_act_cleared(2, 150)
	await get_tree().process_frame

	var modal2: ActClearModal = _open_act_clear_modal(main)
	var wave_before_second: int = main.defense_field.current_wave
	print("ACT_CLEAR_PROBE second_modal=%s wave_before_second=%d running=%s" % [
		"yes" if modal2 != null else "NO", wave_before_second,
		str(main.defense_field.is_wave_running)])
	check(modal2 != null, "두 번째 막 클리어 모달이 뜨지 않았다")
	check(not main.defense_field.is_wave_running, "두 번째 모달이 떠 있는데 웨이브가 돌고 있다")

	if modal2 != null:
		modal2._close()
		await get_tree().process_frame
		print("ACT_CLEAR_PROBE close_path wave=%d running=%s" % [
			main.defense_field.current_wave, str(main.defense_field.is_wave_running)])
		check(main.defense_field.is_wave_running,
			"모달을 닫았는데 웨이브가 시작되지 않았다 — 모달이 스스로의 시작을 막았다")
		check(main.defense_field.current_wave == wave_before_second + 1,
			"닫은 뒤 웨이브가 정확히 하나 진행하지 않았다 (%d → %d)" % [wave_before_second, main.defense_field.current_wave])

		# 두 번 닫아도 한 번만 시작해야 한다 (버튼 더블클릭 · 봇 경로가 겹치는 경우).
		var wave_after_close: int = main.defense_field.current_wave
		modal2._close()
		await get_tree().process_frame
		check(main.defense_field.current_wave == wave_after_close,
			"`_close()` 를 두 번 부르니 웨이브가 더 진행했다 (%d → %d)" % [wave_after_close, main.defense_field.current_wave])

	# ── 7. 로드는 모달을 넘겨받지 않는다 ──────────────────────────────────────
	# 불러오기는 다른 막·다른 웨이브로 갈아끼우므로, 막 클리어 모달의 "다음 막" 주장이
	# 무효가 된다. 남겨 두면 그 버튼이 로드된 웨이브를 **하나 건너뛴다**.
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	main._on_act_cleared(3, 200)
	await get_tree().process_frame
	var modal3: ActClearModal = _open_act_clear_modal(main)
	check(modal3 != null, "세 번째 모달이 뜨지 않았다")
	# 세이브를 하나 만들어 둔다 — 없으면 `_on_load_pressed` 가 조기 반환해서 아무것도
	# 재지 못한다(거짓 통과). `SaveManager._is_test_run()` 이 `/tools/` 를 보고
	# **테스트 경로**로 보내므로 플레이어의 실제 세이브는 건드리지 않는다.
	main._is_loading_state = false
	main.save_game_state()
	main._is_loading_state = true
	check(SaveManager.has_save_file(),
		"테스트 세이브를 만들지 못했다 — 이 경우 로드 경로는 아무것도 재지 못한다")
	main._on_load_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	# 이 단언은 **세 번째 모달 하나만** 본다 — 앞 절이 남긴 모달이 있으면 그건 앞 절의
	# 실패이지 로드의 실패가 아니다. 실패 메시지가 거짓말하지 않게 대상을 좁힌다.
	check(not is_instance_valid(modal3),
		"불러오기 뒤에도 막 클리어 모달이 살아 있다 — 로드된 상태와 어긋난 '다음 막' 을 걸고 있다")
	check(main._act_clear_modal == null,
		"불러오기가 '다음 막 시작의 주인' 참조를 비우지 않았다 — 죽은 모달을 닫으려 든다")
	check(not main.defense_field.is_wave_running,
		"불러오기가 웨이브를 시작했다 — 로드는 '되돌리기' 지 '다음 막' 이 아니다")

	# 우리가 만든 테스트 세이브는 치운다 — 남겨 두면 다음 실행이 그걸 불러와
	# '이미 진행된 상태' 에서 시작해 기준선이 흔들린다.
	SaveManager.delete_save_file()

	if failures == 0:
		print("ACT_CLEAR_MODAL_PROBE_OK")
	get_tree().quit(failures)
