extends Node
# 코치마크가 떠 있는 동안 **웨이브가 시작되는가**를 직접 잰다 (2026-10-04).
#
# 왜 이걸 재는가:
# §2.7 은 "모달이 떠 있는 동안에는 다음 웨이브를 시작하지 않는다" 를 **막 클리어 모달**에 대해
# 세웠다(`_on_start_wave_pressed()` 가 `_act_clear_modal_open()` 을 본다). 그 술어는 **일부러
# 좁다** — 상점·보상 드래프트는 막지 않는다(`_is_terminal_modal_open()` 을 쓰면 전부 막힌다).
# 그런데 **첫 실행 코치마크**는 같은 `modal_layer` 에 붙는데(코드 `:279`), 좁은 술어에 안 걸린다.
# 그리고 `_ready()` 는 둘을 **이 순서로** 예약한다:
#     call_deferred("_show_first_run_coachmark")   (:197)
#     call_deferred("_start_wave_automatically")   (:201)
# → 첫 실행에서 **코치마크가 뜬 채로 웨이브 1이 시작**될 것으로 코드를 읽어 예상했다.
#   이 프로브는 그 예상을 **재는** 것이다(코드 읽기 ≠ 측정).
#
# **시나리오가 둘이고, 순서가 계약이다.**
#   B — **손대지 않은 첫 실행 경로.** 세이브를 지우고 씬을 실어 `_ready()` 의 두 deferral 만 돌린다.
#       감사가 주장하는 것은 *이* 경로다("첫 실행에서 코치마크가 뜬 채로 웨이브 1이 시작된다").
#   A — **통제된 재현.** `reset_combat_state()` 로 기준선을 만들고 `_start_wave_automatically()`
#       를 직접 불러, "모달이 떠 있는데 시작을 부르면 어떻게 되는가" 만 본다.
# ⚠️ **B 를 먼저 돌려야 한다.** A 는 세이브를 지우고 게임을 시작해 버리므로, A 뒤에는
#    "세이브 없는 첫 실행" 을 재현할 수 없다. 순서를 바꾸면 B 는 조용히 무의미해진다.
#
# ⚠️ **보고 전용이다.** "모달이 떠 있으면 웨이브를 멈춰야 한다" 는 **설계 결정**이지 이 프로젝트가
#    이미 정한 계약이 아니다(§2.7 의 술어가 좁은 것도 결정이다). 그래서 **측정값은 단언하지 않고
#    찍기만** 한다 — 판정은 감독 몫이다. 단언하는 것은 **양성 대조뿐**이다: 코치마크가 안 떴으면
#    우리는 아무것도 잰 게 아니다.
#
# 실행: godot --headless --path . res://tools/CoachmarkGateProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _settle(frames: int = 3) -> void:
	for i in frames:
		await get_tree().process_frame

func _ready() -> void:
	# ══ 시나리오 B — 손대지 않은 첫 실행 경로 ═══════════════════════════════════════
	# `tools/` 이므로 `SaveManager` 는 `user://*_test.json` 을 쓴다(플레이어 세이브가 아니다).
	SaveManager.delete_save_file()
	await _settle(1)
	check(not SaveManager.has_save_file(), "B 준비 실패 — 세이브가 아직 남아 있다(첫 실행 경로를 못 잰다)")

	var fresh = MainScene.instantiate()
	add_child(fresh)
	await _settle(3)

	var b_modal: int = fresh.modal_layer.get_child_count()
	var b_running: bool = fresh.defense_field.is_wave_running
	# 양성 대조 — 코치마크가 실제로 떴는가. 안 떴으면 아래 숫자는 아무 뜻이 없다.
	check(b_modal > 0, "B 양성 대조 실패 — 첫 실행 코치마크가 modal_layer 에 없다(잰 게 없다)")
	print("COACHMARK_GATE_B (손대지 않은 첫 실행) 모달 %d개 · wave_running=%s (wave=%d) · speed=%.1f" % [
		b_modal, str(b_running), fresh.defense_field.current_wave, Engine.time_scale])

	fresh.queue_free()
	await _settle(1)

	# ══ 시나리오 A — 통제된 재현 (기준선 → 코치마크 → 시작 호출) ═════════════════════
	var main = MainScene.instantiate()
	add_child(main)
	await _settle(2)

	# 이 도구는 세이브를 남기지 않는다(`tools/` 면 자동으로 `*_test.json` 을 쓴다).
	main._is_loading_state = true
	main.start_new_game()
	await _settle(2)
	main._is_loading_state = true
	# `_ready`/`start_new_game` 가 예약한 자동 시작을 멈추고 **기준선**을 만든다.
	main.defense_field.reset_combat_state()
	await _settle(1)

	var before_running: bool = main.defense_field.is_wave_running
	check(not before_running, "A 기준선 실패 — 웨이브가 이미 돌고 있다(이 상태로는 아무것도 못 잰다)")

	# ── 코치마크를 강제로 띄운다 — `FrameStrip.gd` 와 **같은 문**을 쓴다.
	#    (세이브가 있으면 `_show_first_run_coachmark()` 가 즉시 return 하므로 직접 부른다.)
	var belt = main.find_child("JamoBelt", true, false)
	main._run_coachmark([{
		"title": "1 / 3  ·  활자를 모으세요",
		"body": "벨트의 [자음 구매] / [모음 구매]로 활자를 얻어\n아래 3개 슬롯 중 한 곳에 끌어다 놓습니다.",
		"anchor": belt,
	}], 0)
	await _settle(1)

	var modal_count: int = main.modal_layer.get_child_count()
	check(modal_count > 0, "A 양성 대조 실패 — 코치마크가 modal_layer 에 없다(잰 게 없다)")

	# ── 측정: 모달이 떠 있는 채로 웨이브를 시작시켜 본다.
	main._start_wave_automatically()
	await _settle(2)

	var running: bool = main.defense_field.is_wave_running
	var wave: int = main.defense_field.current_wave
	print("COACHMARK_GATE_A (통제 재현) 모달 %d개(코치마크 떠 있음) · 시작 전 wave_running=%s · _start_wave_automatically() 뒤 wave_running=%s (wave=%d)" % [
		modal_count, str(before_running), str(running), wave])

	# ── 판정 문장은 B(실제 경로)를 기준으로 쓴다 — 감사의 주장이 B 에 대한 것이기 때문이다.
	if b_running:
		print("COACHMARK_GATE ⇒ **첫 실행에서 코치마크가 뜬 채로 웨이브가 시작된다** — 설계 결정 필요(보고 전용)")
	else:
		print("COACHMARK_GATE ⇒ 첫 실행에서 코치마크가 떠 있으면 웨이브가 시작되지 않는다")

	if failures == 0:
		print("COACHMARK_GATE_PROBE_OK")
	get_tree().quit(failures)
