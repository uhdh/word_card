extends Node
# 런의 마지막 문장(승리 / 기지 함락)에 소리가 있는가 — 그리고 그 소리가 **전용**인가.
# (감사 §2.8 / §5.2 항목 10, 2026-09-23 소리 / 2026-09-24 여운)
#
# ⚠️ 2026-09-24 추가 — §6~§8 은 **여운**(결과 패널이 0.4초 뒤에 등장)을 잰다.
# 감사는 이 항목을 "헤드리스로 검증할 수 없다" 고 적었지만, 그건 "0.4초가 사람에게
# 적절한가" 와 "메커니즘" 을 구분하지 않은 말이었다. 메커니즘은 헤드리스로 잰다:
#   · 모달이 **즉시 트리에 들어가되 투명하다**(고아 노드·`_is_terminal_modal_open()`)
#   · 여운이 `Engine.time_scale` 을 **따르지 않는다**(4배속·정지에서도 0.4초 실시간)
#
# 왜 문제였나:
# `TowerDefenseMain._on_game_over()` 에 `SoundEngine` 호출이 **0건**이었다. 60라운드를
# 끝낸 순간도, 기지가 함락된 순간도 무음이라 감정적 마침표가 없었다(런당 1회뿐인 최상위
# 사건인데). 반대로 `play_victory()`(0.4초 4음)는 `DefenseField._grant_round_reward()` 에서
# **라운드가 끝날 때마다**(런당 수십 번) 울리고 있었다 — 연출이 **거꾸로** 배분돼 있었다.
#
# ⚠️ 이 도구가 재는 것 셋 (한쪽만 재면 반쪽짜리 검사다):
#   1) 승리·함락에 소리가 **난다** (§1 함락 · §2 승리)
#   2) 그 소리가 **전용**이다 — 3막에서 기존 승리음이 **겹쳐 울리지 않는다** (§3),
#      반대로 1·2막 클리어는 기존 승리음을 **그대로 쓴다** (§4)
#   3) 세트 안에서 **강도 순서**가 맞다 — 런 승리 > 함락 > 기존 승리 (§5 길이)
#   §2 만 있으면 "승리에 아무 소리나 붙이는" 고침이 통과한다.
#   §3 이 없으면 "런 승리에서 두 소리가 동시에 나는" 고침이 통과한다.
#   §4 가 없으면 "기존 승리음을 아예 없애는" 고침이 통과한다.
#   §5 가 없으면 "함락이 승리보다 화려한" 고침이 통과한다.
#
# ⚠️ `SaveManager` 는 커맨드라인에 `/tools/` 가 있으면 **테스트 경로**를 쓴다
# (`SaveManager._is_test_run()`). 이 프로브는 `_on_game_over` 를 실제로 태우므로
# 그 보호가 없으면 플레이어의 **실제 랭킹 파일**에 런이 기록된다.
#
# 실행: godot --headless --path . res://tools/GameOverProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

const FINAL := "final_victory"
const DEFEAT := "defeat"
const VICTORY := "victory"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 이 스트림이 **지금 재생 중인** 플레이어 수.
func _playing(stream_name: String) -> int:
	var s = SoundEngine._cached_streams.get(stream_name)
	if s == null:
		return 0
	var n := 0
	for p in SoundEngine._players:
		if p.playing and p.stream == s:
			n += 1
	return n

func _has(stream_name: String) -> bool:
	return SoundEngine._cached_streams.has(stream_name)

## 8비트 WAV 의 길이(초). 합성 파라미터가 아니라 **데이터에서** 잰다.
func _dur(stream_name: String) -> float:
	var w: AudioStreamWAV = SoundEngine._cached_streams.get(stream_name)
	if w == null:
		return -1.0
	return float(w.data.size()) / float(w.mix_rate)

## 영교차율 — 피치 대리 지표(난수 없는 합성이라 결정론적).
func _zcr(stream_name: String) -> float:
	var w: AudioStreamWAV = SoundEngine._cached_streams.get(stream_name)
	if w == null:
		return -1.0
	var d: PackedByteArray = w.data
	var cross := 0
	for i in range(1, d.size()):
		if (d[i - 1] < 128) != (d[i] < 128):
			cross += 1
	return float(cross) * float(w.mix_rate) / float(d.size())

## 모든 플레이어가 멈출 때까지 기다린다 — 다음 절이 앞 절 소리를 세지 않도록.
func _drain() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		var busy := false
		for p in SoundEngine._players:
			if p.playing:
				busy = true
				break
		if not busy:
			return
		await get_tree().process_frame

## 잠금 창(50ms)보다 확실히 긴 시간. `_drain()` 도 보통은 넘기지만 그건 소리 길이에
## 기댄 우연이라, 보장이 필요한 자리에서는 명시적으로 번다.
func _past_throttle_window() -> void:
	await get_tree().create_timer(0.08).timeout

func _ready() -> void:
	# ⚠️ 먼저 — `muted` 면 합성조차 안 되어 아무것도 못 잰다.
	# 필드 직접 대입이라 `_save_config()` 를 지나지 않는다(설정 파일 안전).
	SoundEngine.muted = false

	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	var field = main.defense_field

	# ── 0. 기준선 ────────────────────────────────────────────────────────────
	await _drain()
	print("GAMEOVER_PROBE baseline final=%s defeat=%s victory=%s" % [
		_has(FINAL), _has(DEFEAT), _has(VICTORY)])
	check(not _has(FINAL), "기준선에 이미 final_victory 가 합성돼 있다 — 낡은 캐시가 통과를 위조한다")
	check(not _has(DEFEAT), "기준선에 이미 defeat 가 합성돼 있다")

	# ── 1. 기지 함락 (실제 신호) ─────────────────────────────────────────────
	await _drain()
	await _past_throttle_window()
	field.game_over.emit(false)
	await get_tree().process_frame
	var d_playing := _playing(DEFEAT)
	print("GAMEOVER_PROBE defeat_path playing=%d cached=%s" % [d_playing, _has(DEFEAT)])
	check(_has(DEFEAT), "함락에 소리가 없다 — `_on_game_over(false)` 가 무음이다")
	check(d_playing == 1, "함락음이 %d개 플레이어에서 났다 (1이어야 한다)" % d_playing)
	check(not _has(FINAL), "함락인데 승리음이 함께 났다")

	# ── 2. 런 승리 (실제 신호) ───────────────────────────────────────────────
	await _drain()
	await _past_throttle_window()
	main._run_recorded = false          # 프로브가 두 경로를 다 태우려고 푸는 가드
	field.game_over.emit(true)
	await get_tree().process_frame
	var v_playing := _playing(FINAL)
	print("GAMEOVER_PROBE victory_path playing=%d cached=%s victory_playing=%d" % [
		v_playing, _has(FINAL), _playing(VICTORY)])
	check(_has(FINAL), "런 승리에 소리가 없다 — `_on_game_over(true)` 가 무음이다")
	check(v_playing == 1, "런 승리음이 %d개 플레이어에서 났다 (1이어야 한다)" % v_playing)
	check(_playing(VICTORY) == 0,
		"런 승리 순간에 기존 승리음이 함께 울렸다 — 두 소리가 합산된다")

	# ── 3. 3막 마지막 웨이브 — 기존 승리음이 **겹치면 안 된다** ──────────────
	# 여기가 이 고침의 핵심이다. `_grant_round_reward(true)` 는 `play_victory()` 를
	# 무조건 울리던 자리이고, 3막에서는 곧바로 `game_over.emit(true)` 로 간다.
	# 가드가 없으면 두 소리가 같은 순간에 난다(이름이 달라 스로틀도 못 막는다).
	await _drain()
	await _past_throttle_window()
	main._run_recorded = false
	field.current_act = DefenseField.MAX_ACTS
	field._grant_round_reward(true)
	await get_tree().process_frame
	var g_victory := _playing(VICTORY)
	var g_final := _playing(FINAL)
	print("GAMEOVER_PROBE act3_guard victory_playing=%d final_playing=%d" % [g_victory, g_final])
	check(g_victory == 0,
		"3막 클리어에서 기존 승리음이 울렸다 (%d개) — 런 승리음과 겹친다" % g_victory)
	check(g_final == 1,
		"3막 클리어가 런 승리음으로 이어지지 않았다 (%d개)" % g_final)

	# ── 4. 1·2막 클리어는 기존 승리음을 **그대로 쓴다** (양방향 검사의 뒤쪽) ──
	await _drain()
	await _past_throttle_window()
	field.current_act = 1
	field._grant_round_reward(true)
	await get_tree().process_frame
	var a_victory := _playing(VICTORY)
	var a_final := _playing(FINAL)
	print("GAMEOVER_PROBE act1_clear victory_playing=%d final_playing=%d" % [a_victory, a_final])
	check(a_victory == 1,
		"1막 클리어에서 기존 승리음이 %d개만 울렸다 (1이어야 한다) — 가드가 너무 넓다" % a_victory)
	check(a_final == 0, "1막 클리어에서 런 승리음이 울렸다 — 가드가 너무 넓다")

	# ── 5. 강도 순서 — 런 승리 > 함락 > 기존 승리 ───────────────────────────
	# 강도는 게임 중요도에 비례해야 한다(이 프로젝트의 연출 예산 규칙). 길이는 그 대리 지표다.
	var dur_final := _dur(FINAL)
	var dur_defeat := _dur(DEFEAT)
	var dur_victory := _dur(VICTORY)
	var zcr_final := _zcr(FINAL)
	var zcr_defeat := _zcr(DEFEAT)
	var zcr_victory := _zcr(VICTORY)
	print("GAMEOVER_PROBE shape final=%.2fs zcr=%.0f | defeat=%.2fs zcr=%.0f | victory=%.2fs zcr=%.0f" % [
		dur_final, zcr_final, dur_defeat, zcr_defeat, dur_victory, zcr_victory])
	check(dur_final > dur_victory,
		"런 승리음(%.2fs)이 기존 승리음(%.2fs)보다 길지 않다 — 가장 큰 사건이 가장 작게 들린다" % [
			dur_final, dur_victory])
	check(dur_defeat > dur_victory,
		"함락음(%.2fs)이 기존 승리음(%.2fs)보다 길지 않다" % [dur_defeat, dur_victory])
	check(zcr_defeat < zcr_victory,
		"함락음의 영교차율(%.0f/s)이 기존 승리음(%.0f/s)보다 높다 — 내려가는 소리가 아니다" % [
			zcr_defeat, zcr_victory])

	# ── 6. 여운 — 결과 패널이 **0.4초 실시간** 뒤에 등장한다 (§2.8 / §5.2 10) ──
	# 감사는 이 항목을 "헤드리스로 검증할 수 없다" 고 적었는데, 그건 틀렸다. 잴 수 없는 것은
	# "0.4초가 사람에게 적절한가" 이고 **메커니즘**은 여기서 잰다. §6~§8 이 각각 다른 것을
	# 지킨다 — 하나라도 없으면 아래 '주입' 표의 고침이 조용히 통과한다.
	#
	#   §6 모달이 **즉시 트리에 들어가되 투명하다** — 그래야 (a) 고아 노드가 안 생기고
	#      (b) `_is_terminal_modal_open()` 이 여운 동안에도 참이라 보상 드래프트가
	#      결과 화면 위에 겹치지 않는다. **모달을 나중에 만드는 고침**이 여기서 걸린다.
	#   §7 4배속에서도 여운이 **0.4초 실시간**이다 — `create_timer` 의 기본값(배속을 따름)으로
	#      되돌리면 4배속에서 100ms 가 되어 여기서 걸린다.
	#   §8 정지 중에도 여운이 **끝난다** — 기본 타이머는 `time_scale = 0` 에서 영원히 오지 않는다.
	await _clear_modals(main)
	# ⚠️ `main` 이 untyped 라 `main.modal_layer.get_child_count()` 는 Variant 다 —
	# `:=` 로 받으면 "Cannot infer the type" 파싱 에러로 **프로브가 통째로 안 돈다**
	# (그러면 실패가 아니라 '결과 줄 없음' 이 되어 조용히 넘어간다). 명시 타입을 쓴다.
	var before: int = main.modal_layer.get_child_count()
	main._run_recorded = false
	field.game_over.emit(false)
	await get_tree().process_frame
	var panel = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	var n_immediate: int = main.modal_layer.get_child_count()
	var alpha_immediate: float = panel.modulate.a if panel != null else -1.0
	var terminal_now: bool = main._is_terminal_modal_open()
	print("GAMEOVER_PROBE hold_immediate count=%d→%d alpha=%.2f terminal=%s" % [
		before, n_immediate, alpha_immediate, terminal_now])
	check(n_immediate == before + 1,
		"결과 모달이 즉시 트리에 들어가지 않았다 (%d → %d) — 나중에 만들면 그동안 고아 노드가 되고, `_is_terminal_modal_open()` 이 여운 동안 거짓이 되어 보상 드래프트가 겹쳐 뜬다" % [before, n_immediate])
	check(alpha_immediate < 0.01,
		"결과 모달이 여운 없이 즉시 보인다 (alpha=%.2f) — 여운이 사라졌다" % alpha_immediate)
	check(terminal_now,
		"여운 동안 `_is_terminal_modal_open()` 이 거짓이다 — 보상 드래프트가 결과 화면 위에 겹칠 수 있다")

	# 여운의 절반 시점 — 아직 투명해야 한다. (대기와 등장이 '평행' 으로 걸린 고침이 여기서 걸린다.)
	await get_tree().create_timer(0.2, true, false, true).timeout
	var alpha_mid: float = panel.modulate.a if is_instance_valid(panel) else -1.0
	print("GAMEOVER_PROBE hold_mid t=0.20 alpha=%.2f" % alpha_mid)
	check(alpha_mid < 0.01,
		"여운이 0.2초 만에 끝났다 (alpha=%.2f) — 대기가 등장과 평행하게 걸렸다" % alpha_mid)

	# 0.7초 — 등장(0.4 대기 + 0.18 팝)이 끝나 있어야 한다.
	await get_tree().create_timer(0.5, true, false, true).timeout
	var alpha_after: float = panel.modulate.a if is_instance_valid(panel) else -1.0
	print("GAMEOVER_PROBE hold_after t=0.70 alpha=%.2f" % alpha_after)
	check(alpha_after > 0.99,
		"여운 뒤에도 결과 모달이 나타나지 않았다 (alpha=%.2f) — 패널이 영영 안 뜬다" % alpha_after)

	# ── 7. 4배속에서도 여운은 실시간 0.4초 ────────────────────────────────────
	await _clear_modals(main)
	main._run_recorded = false
	Engine.time_scale = 4.0
	field.game_over.emit(false)
	await get_tree().create_timer(0.25, true, false, true).timeout
	var p4 = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	var a4: float = p4.modulate.a if p4 != null else -1.0
	print("GAMEOVER_PROBE hold_speed4x t=0.25 alpha=%.2f" % a4)
	check(a4 < 0.01,
		"4배속에서 여운이 0.1초로 줄었다 (t=0.25 에 alpha=%.2f) — 대기가 `Engine.time_scale` 을 따른다" % a4)
	await get_tree().create_timer(0.45, true, false, true).timeout
	var a4b: float = p4.modulate.a if is_instance_valid(p4) else -1.0
	print("GAMEOVER_PROBE hold_speed4x t=0.70 alpha=%.2f" % a4b)
	check(a4b > 0.99,
		"4배속에서 여운 뒤에도 모달이 나타나지 않았다 (alpha=%.2f)" % a4b)
	Engine.time_scale = 1.0

	# ── 8. 정지 중에도 여운은 **끝난다** ─────────────────────────────────────
	# `time_scale = 0` 이면 기본 타이머도 기본 트윈도 영원히 오지 않는다. 게임오버 패널은
	# 반드시 나타나야 하는 것이므로 대기·등장이 **둘 다** 실시간이어야 한다 —
	# 등장만 배속을 따르면 여기서 alpha 가 0 에 머문다(패널이 영영 안 뜬다).
	await _clear_modals(main)
	main._run_recorded = false
	Engine.time_scale = 0.0
	field.game_over.emit(false)
	await get_tree().create_timer(0.7, true, false, true).timeout
	var p0 = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	var a0: float = p0.modulate.a if p0 != null else -1.0
	print("GAMEOVER_PROBE hold_paused t=0.70 alpha=%.2f" % a0)
	check(a0 > 0.99,
		"정지 중에는 결과 모달이 나타나지 않는다 (alpha=%.2f) — 게임오버 패널이 시간축에 기대고 있다" % a0)
	Engine.time_scale = 1.0

	if failures == 0:
		print("GAME_OVER_PROBE_OK")
	get_tree().quit(failures)

## 여운 절들이 서로의 모달을 세지 않도록 레이아웃을 비운다. `_act_clear_modal` 참조도
## 함께 버린다 — 남겨 두면 죽은 노드를 가리킨다.
func _clear_modals(main) -> void:
	for c in main.modal_layer.get_children():
		main.modal_layer.remove_child(c)
		c.queue_free()
	main._act_clear_modal = null
	await get_tree().process_frame
