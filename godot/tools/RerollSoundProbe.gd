extends Node
# 리롤(주사위)에 **제 소리**가 있는가 — 그리고 그 소리가 회전음과 구별되는가.
# (감사 §2.6 문제 3 / §5.2 항목 19, 2026-09-23)
#
# 왜 문제였나:
# `WaveRewardModal._on_reroll_pressed()` 가 `play_tile_rotate()` 를 썼다. 그런데 두 사건의
# **빈도가 정반대**다 — 타일 회전은 웨이브마다 수십 번 나는 미세 조작이고, 리롤은
# **런 전체에 3~8번뿐인** 자원 소비 결정이다(`reroll_dice`: 시작 3 · 막 클리어 +1 · 유물 +2).
# 가장 드문 결정이 가장 흔한 조작과 같은 소리를 내면, 그 결정에는 고유한 정체성이 없다.
# §2.8 에서 고친 '클라이맥스에 소리가 없다' 와 **같은 종류의 배분 오류**다.
#
# ⚠️ 이 도구가 재는 것 여섯 (한쪽만 재면 반쪽짜리 검사다):
#   1) 리롤에 소리가 **난다** (§1 — `reroll` 이 합성된다)
#   2) 그 소리가 **회전음이 아니다** (§2 — `tile_rotate` 가 합성되지 **않는다**)
#   3) 두 파형이 실제로 **다르다** (§3 — 길이와 영교차율)
#   4) 리롤음이 **다른 소리의 별칭이 아니다** (§4 — 바이트 동일성 검사)
#   5) **주사위가 없으면 무음** (§5 — 0개로 누르면 소리가 나면 안 된다)
#   6) **강도 순서** — 리롤음 > 회전음 (§6)
#   §1 만 있으면 "아무 소리나 붙이는" 고침이 통과한다.
#   §2 가 없으면 "회전음을 그대로 두고 소리만 하나 더 우는" 고침이 통과한다.
#   §3·§4 가 없으면 "`play_reroll()` = `play_tile_rotate()`" 라는 **별칭 고침**이 통과한다
#     — 이건 §5.2 항목 20(`play_buff`/`play_freeze` 가 순수 별칭)과 **같은 결함 부류**다.
#   §5 가 없으면 "0개일 때도 소리 나는" 고침이 통과한다.
#   §6 이 없으면 "회전음보다 짧은 리롤음" 이 통과한다 — 가장 드문 결정이 가장 작게 들린다.
#
# ⚠️ `muted` 를 **먼저** 끈다. `_play_synth_stream()` 첫 줄이 `if muted: return` 이라
#    합성 자체가 안 되어 아무것도 못 잰다.
# ⚠️ 이 프로브는 모달만 띄운다 — `_on_game_over` 같은 저장 경로를 태우지 않는다.
#    그래도 `SaveManager._is_test_run()` 의 `/tools/` 경로 규칙이 지켜 준다.
#
# 실행: godot --headless --path . res://tools/RerollSoundProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 이 고침이 만든 소리 / 이 고침이 **빼앗은** 소리. 둘 다 이름으로 잰다.
const REROLL := "reroll"
const ROTATE := "tile_rotate"
const COIN := "coin"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _has(stream_name: String) -> bool:
	return SoundEngine._cached_streams.has(stream_name)

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

## 8비트 WAV 의 길이(초). 합성 파라미터가 아니라 **데이터에서** 잰다.
func _dur(stream_name: String) -> float:
	var w: AudioStreamWAV = SoundEngine._cached_streams.get(stream_name)
	if w == null:
		return -1.0
	return float(w.data.size()) / float(w.mix_rate)

## 영교차율 — 피치 대리 지표. 잡음이 섞인 리롤음은 회전음보다 훨씬 높게 나온다.
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

## 두 스트림이 **같은 파형**인가 — 별칭 검출의 핵심이다.
## 이름이 다르면 `_cached_streams` 키도 다르므로 **이름만 보면 별칭을 못 잡는다.**
## `play_reroll(): play_tile_rotate()` 처럼 쓰면 키는 `tile_rotate` 하나뿐이라 §1 이 잡지만,
## `_play_synth_stream("reroll", ...)` 안에서 회전음 생성기를 그대로 부르는 형태는
## **키만 다르고 소리는 같다** — 그건 §3(길이·영교차율)과 여기서만 잡힌다.
func _same_wave(a: String, b: String) -> bool:
	var wa: AudioStreamWAV = SoundEngine._cached_streams.get(a)
	var wb: AudioStreamWAV = SoundEngine._cached_streams.get(b)
	if wa == null or wb == null:
		return false
	if wa.data.size() != wb.data.size():
		return false
	return wa.data == wb.data

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

## 보상 모달을 띄우고 그 모달을 돌려준다. 주사위 수는 인자로 정한다.
func _open_modal(main: Node, wave: int, dice: int) -> Node:
	main._show_wave_reward(wave, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	if modal != null:
		modal.remaining_dice = dice
		modal.update_dice_ui()
	return modal

func _ready() -> void:
	# ⚠️ 첫 줄 — `muted` 면 `_play_synth_stream()` 이 즉시 return 해서 합성이 안 된다.
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

	# ── 0. 기준선 ────────────────────────────────────────────────────────────
	# ⚠️ 낡은 캐시가 통과를 위조한다. 두 이름 다 **아직 없어야** 한다.
	#    특히 `tile_rotate` 는 이 게임에서 흔한 소리라, 기준선에서 이미 있으면
	#    §2 가 무엇을 재는지 알 수 없게 된다.
	await _drain()
	print("REROLL_PROBE baseline reroll=%s rotate=%s" % [_has(REROLL), _has(ROTATE)])
	check(not _has(REROLL), "기준선에 이미 reroll 이 합성돼 있다 — 낡은 캐시가 통과를 위조한다")
	check(not _has(ROTATE), "기준선에 이미 tile_rotate 가 합성돼 있다 — §2 를 잴 수 없다")

	# ── 1. 리롤에 소리가 난다 (실제 버튼 신호) ───────────────────────────────
	# 버튼을 직접 누른다 — 함수를 직접 부르면 **연결이 끊긴 것**을 못 잡는다.
	await _past_throttle_window()
	var modal = await _open_modal(main, 1, 3)
	check(modal != null, "보상 모달이 뜨지 않았다")
	if modal == null:
		get_tree().quit(failures + 1)
		return
	check(modal.remaining_dice == 3, "주사위를 3개로 맞추지 못했다 (%d)" % modal.remaining_dice)

	modal.btn_reroll.pressed.emit()
	await get_tree().process_frame
	var r_playing := _playing(REROLL)
	print("REROLL_PROBE reroll_pressed playing=%d cached=%s dice=%d" % [
		r_playing, _has(REROLL), modal.remaining_dice])
	check(_has(REROLL), "리롤에 소리가 없다 — `_on_reroll_pressed()` 가 무음이다")
	check(r_playing == 1, "리롤음이 %d개 플레이어에서 났다 (1이어야 한다)" % r_playing)
	check(modal.remaining_dice == 2, "주사위가 줄지 않았다 (%d)" % modal.remaining_dice)

	# ── 2. 그 소리는 **회전음이 아니다** (이 고침의 본체) ────────────────────
	# ⚠️ 여기가 §5.2 19 의 핵심 단언이다. 리롤이 회전음을 계속 쓰면 여기서 걸린다.
	var rotate_playing := _playing(ROTATE)
	print("REROLL_PROBE reroll_is_not_rotate rotate_cached=%s rotate_playing=%d" % [
		_has(ROTATE), rotate_playing])
	check(not _has(ROTATE),
		"리롤이 회전음(tile_rotate)을 합성했다 — 리롤이 타일 회전음을 빌려 쓰고 있다")
	check(rotate_playing == 0, "리롤 순간에 회전음이 %d개 플레이어에서 울렸다" % rotate_playing)

	# ── 3. 두 파형이 실제로 **다르다** ───────────────────────────────────────
	# §2 는 '이름' 만 잰다. `_play_synth_stream("reroll", <회전음 생성기>)` 형태는
	# 이름만 다르고 소리가 같다 — 그건 여기서만 잡힌다.
	await _drain()
	await _past_throttle_window()
	SoundEngine.play_tile_rotate()
	await get_tree().process_frame
	check(_has(ROTATE), "회전음을 직접 불렀는데 합성되지 않았다 — 비교 대상이 없다")
	await _drain()

	var dur_reroll := _dur(REROLL)
	var dur_rotate := _dur(ROTATE)
	var zcr_reroll := _zcr(REROLL)
	var zcr_rotate := _zcr(ROTATE)
	print("REROLL_PROBE shape reroll=%.3fs zcr=%.0f | rotate=%.3fs zcr=%.0f" % [
		dur_reroll, zcr_reroll, dur_rotate, zcr_rotate])
	check(absf(dur_reroll - dur_rotate) > 0.01,
		"리롤음(%.3fs)과 회전음(%.3fs)의 길이가 사실상 같다" % [dur_reroll, dur_rotate])
	check(absf(zcr_reroll - zcr_rotate) > 200.0,
		"리롤음(zcr=%.0f)과 회전음(zcr=%.0f)의 음색이 사실상 같다 — 같은 파형을 의심할 것" % [
			zcr_reroll, zcr_rotate])

	# ── 4. 리롤음이 **다른 소리의 별칭이 아니다** ────────────────────────────
	# §5.2 항목 20 이 지적한 부류(`play_buff() = play_heal()`)를 이 소리에는 만들지 않는다.
	# 같은 모달에서 바로 옆에 울리는 코인음과도 달라야 한다 — 아니면 '받았다' 와 '골랐다' 가
	# 같은 소리가 되어, 소리로 사건을 구분할 수 없다.
	await _drain()
	await _past_throttle_window()
	SoundEngine.play_coin()
	await get_tree().process_frame
	await _drain()
	print("REROLL_PROBE alias reroll==rotate:%s reroll==coin:%s" % [
		_same_wave(REROLL, ROTATE), _same_wave(REROLL, COIN)])
	check(not _same_wave(REROLL, ROTATE), "리롤음이 회전음과 **바이트 단위로 같다** (별칭)")
	check(not _same_wave(REROLL, COIN), "리롤음이 코인음과 **바이트 단위로 같다** (별칭)")

	# ── 5. 주사위가 없으면 무음 ─────────────────────────────────────────────
	# 버튼은 `disabled` 지만 `pressed.emit()` 은 그 플래그를 지나지 않는다 — 즉 이 절은
	# **함수 안의 가드**를 잰다(플래그가 아니라 계약). 주사위 0개는 '아무 일도 안 일어남' 인데
	# 소리가 나면 거짓 신호다.
	var modal2 = await _open_modal(main, 2, 0)
	check(modal2 != null, "2번째 보상 모달이 뜨지 않았다")
	if modal2 == null:
		get_tree().quit(failures + 1)
		return
	# 캐시를 비워 '이번 호출이 소리를 냈는가' 를 새로 잰다. 낡은 캐시는 `_has` 를 참으로 만든다.
	SoundEngine._cached_streams.erase(REROLL)
	SoundEngine._last_played_msec.erase(REROLL)
	await _past_throttle_window()
	modal2.btn_reroll.pressed.emit()
	await get_tree().process_frame
	var zero_playing := _playing(REROLL)
	print("REROLL_PROBE zero_dice cached=%s playing=%d dice=%d" % [
		_has(REROLL), zero_playing, modal2.remaining_dice])
	check(modal2.remaining_dice == 0, "주사위가 음수로 갔다 (%d)" % modal2.remaining_dice)
	check(zero_playing == 0, "주사위 0개인데 리롤음이 울렸다 (무음이어야 한다)")
	check(not _has(REROLL), "주사위 0개인데 리롤음이 합성됐다 — 가드가 없다")

	# ── 6. 강도 순서 — 리롤음 > 회전음 ──────────────────────────────────────
	# 가장 드문 결정(런당 3~8회)이 가장 흔한 조작(웨이브당 수십 회)보다 작게 들리면 안 된다.
	# §3 이 '다르다' 를 재는데, '다르기만 하고 더 짧은' 고침이 통과한다 — 방향을 따로 잰다.
	check(dur_reroll > dur_rotate,
		"리롤음(%.3fs)이 회전음(%.3fs)보다 길지 않다 — 드문 결정이 더 작게 들린다" % [
			dur_reroll, dur_rotate])

	if failures == 0:
		print("REROLL_SOUND_PROBE_OK")
	get_tree().quit(failures)
