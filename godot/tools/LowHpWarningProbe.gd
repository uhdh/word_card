extends Node
# 저체력 맥동(`_update_low_hp_warning`)이 **위험 구간을 벗어나면 정말 멈추는지** 잰다 (§2.11, 2026-09-23).
#
# 왜 필요한가:
# 그 함수는 위험 구간에 들어갈 때 `set_loops()` 트윈을 만들어 `modulate` 를 계속 흔든다.
# 문제는 **나가는 쪽**이다.
#
#     else:
#         hp_box.remove_meta("_low_hp_pulsing")   # 메타만 지운다
#         hp_box.modulate = Color.WHITE           # ← 트윈을 죽이지 않는다
#
# `set_loops()` 트윈은 `kill()` 하기 전까지 **영원히** 돈다. 그래서 위험 구간을 벗어나도
# 트윈이 계속 `modulate` 를 덮어쓴다 → **체력이 회복됐는데도 계속 맥동한다.**
# 게다가 메타를 지웠으므로 다시 위험 구간에 들어가면 트윈을 **또 만든다** → 트윈이 쌓여
# 서로 다른 위상으로 같은 속성을 밀어 맥동이 불규칙해진다.
#
# 이건 이론이 아니라 실재한다 — 위험 구간을 **나가는** 경로가 넷이다:
#   · `DefenseField.gd:1179` 회복의 향로 (웨이브 종료 시 기지 HP +1)
#   · `DefenseField.gd:1184` 방어+회복 인접 (+1)
#   · `TowerDefenseMain.gd:1014` 철옹성 룬 (+10 최대, +10 현재)
#   · `TowerDefenseMain.gd:359` 불러오기 (세이브의 '뚫린 횟수'를 50 기준으로 환산)
#
# 재는 것 (양방향이다 — 한쪽만 재면 반쪽짜리 검사다):
#   0) 기준선: 트윈이 하나도 없고 맥동도 없다
#   1) 위험 구간에 들어가면 **맥동 트윈이 생기고 정말 흔들려야 한다**
#      (이게 없으면 맥동을 통째로 지워도 이 도구는 통과한다)
#   2) 위험 구간을 벗어나면 **그 트윈이 죽어야 한다**  ← 이 도구의 본체
#   3) 다시 들어가도 살아 있는 맥동 트윈이 **정확히 하나**여야 한다 (쌓이면 안 된다)
#   3b) 위험 구간에 **머무는 동안** 신호가 반복돼도 트윈은 **하나**여야 한다
#       (실전에서 가장 흔한 경로 — 적이 새어 나갈 때마다 신호가 온다)
#   4) `ratio == 0`(전멸)은 위험 구간이 아니다 — 게임오버 뒤에 흔들 이유가 없다
#
# ⚠️ 이 도구를 쓸 때의 교훈 둘 (둘 다 실제로 헛짓을 했다):
#   (1) 맥동을 '메타가 있는가' 로 재면 안 된다. 메타는 `else` 에서 **지워지므로** 누수
#       상태에서도 깨끗해 보인다 — 정작 문제인 트윈은 살아 있다. **상태 플래그가 아니라
#       트윈의 생사를 재야 한다.**
#   (2) 여러 트윈이 같은 속성을 밀면 `modulate` 는 **합성값**이 되어, 0.5초 동안 값이
#       붙박이인 것처럼 보인다(실측: `lo=0.7500 hi=0.7526` 인데 바로 다음 창은 0.2444).
#       그래서 누수 판정을 `modulate` 의 시간축 측정으로 하면 **거짓 통과**가 난다.
#       시간축 측정은 트윈이 **하나뿐인** 구간(§1·§2)에서만 쓴다.
#
# 실행: godot --headless --path . res://tools/LowHpWarningProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const MAX_HP := DefenseField.MAX_BASE_HP

## 이보다 크면 맥동이 살아 있다 / 작으면 죽어 있다.
const PULSE_SPAN := 0.05

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## `hp_box.modulate` 의 초록 채널이 `seconds` 동안 얼마나 움직였는지(최대-최소)를 잰다.
## 살아 있는 맥동 트윈은 1.0 ↔ 0.75 를 오가므로 span ≈ 0.25, 죽은 트윈은 0 이다.
## 프레임 수가 아니라 **실제 시간**을 재는 이유: 헤드리스에서는 프레임이 아주 빠르게 돌아
## 프레임 수가 시간을 대표하지 못한다.
## ⚠️ 트윈이 둘 이상이면 합성값이 되어 신뢰할 수 없다 — 하나뿐인 구간에서만 쓴다.
func _modulate_span(hp_box: Control, seconds: float) -> float:
	var lo := 99.0
	var hi := -99.0
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var g := hp_box.modulate.g
		lo = minf(lo, g)
		hi = maxf(hi, g)
		await get_tree().process_frame
	return hi - lo

## `before` 에 없던 트윈 = 방금 만들어진 트윈. 누수 판정의 주인공이다.
func _new_tween(before: Array) -> Tween:
	for t in get_tree().get_processed_tweens():
		if not before.has(t):
			return t
	return null

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	# `_ready` 끝에 `call_deferred("_start_wave_automatically")` 가 있다 — 두 프레임 기다린다.
	await get_tree().process_frame
	await get_tree().process_frame

	# 이 도구는 세이브를 건드리지 않는다. `save_game_state()` 는 `_is_loading_state` 면 즉시
	# 반환한다. (게다가 `SaveManager._is_test_run()` 이 `/tools/` 경로를 보고 테스트 경로로
	# 보내므로, 설령 저장해도 플레이어의 실제 세이브는 아니다.)
	main._is_loading_state = true
	# ⚠️ **남아 있는 세이브에 기대지 않는다.** 게이트를 돌린 뒤 테스트 세이브가 낮은 HP 로
	# 남아 있으면 기준선이 흔들린다. 알려진 상태로 직접 되돌린다.
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true          # `start_new_game` 이 끝에서 false 로 되돌린다
	main.defense_field.reset_combat_state()
	await get_tree().process_frame

	var hp_box: Control = main.base_hp_label.get_parent() if main.base_hp_label else null
	check(hp_box != null, "기지 HP 박스를 찾지 못했다 — 이 실행은 아무것도 재지 못한다")
	if hp_box == null:
		get_tree().quit(failures)
		return

	# ── 0. 기준선: 만땅이면 트윈도 맥동도 없다 ───────────────────────────────
	main.defense_field.base_hp_changed.emit(MAX_HP, MAX_HP)
	await get_tree().process_frame
	var n_base: int = get_tree().get_processed_tweens().size()
	var span_healthy := await _modulate_span(hp_box, 0.4)
	print("LOW_HP_PROBE baseline tweens=%d span=%.3f" % [n_base, span_healthy])
	check(n_base == 0,
		"기준선에 이미 트윈이 %d개 있다 — 이 실행은 남의 트윈을 재고 있다" % n_base)
	check(span_healthy < PULSE_SPAN,
		"만땅인데 기지 표시가 맥동하고 있다 (span %.3f) — 기준선이 깨졌다" % span_healthy)

	# ── 1. 위험 구간에 들어가면 맥동 트윈이 생기고 정말 흔들린다 ─────────────
	# (양방향 검사의 앞쪽 — 이게 없으면 맥동을 통째로 지워도 통과한다)
	var before_danger := get_tree().get_processed_tweens()
	main.defense_field.base_hp_changed.emit(10, MAX_HP)   # 20%
	await get_tree().process_frame
	var pulse1: Tween = _new_tween(before_danger)
	var span_danger := await _modulate_span(hp_box, 0.7)
	print("LOW_HP_PROBE danger tween=%s span=%.3f" % [
		"yes" if pulse1 != null else "NO", span_danger])
	check(pulse1 != null, "위험 구간(20%%)에 들어갔는데 맥동 트윈이 생기지 않았다")
	check(span_danger > PULSE_SPAN,
		"위험 구간(20%%)인데 맥동이 없다 (span %.3f) — 경고가 아예 죽어 있다" % span_danger)

	# ── 2. 위험 구간을 벗어나면 그 트윈이 죽어야 한다 ← 이 도구의 본체 ────────
	# 회복의 향로가 실제로 보내는 것과 **같은 신호**를 보낸다 (핸들러를 직접 부르지 않는다).
	# 이 시점의 트윈은 `pulse1` 하나뿐이므로 아래 span 측정이 신뢰할 수 있다.
	main.defense_field.base_hp_changed.emit(MAX_HP, MAX_HP)
	await get_tree().process_frame
	var leaked: bool = pulse1 != null and pulse1.is_valid()
	var span_after_heal := await _modulate_span(hp_box, 0.7)
	print("LOW_HP_PROBE healed tween_alive=%s span=%.3f" % [str(leaked), span_after_heal])
	check(not leaked,
		"체력이 회복됐는데도 위험 구간에서 만든 맥동 트윈이 살아 있다 — `kill()` 되지 않았다")
	check(span_after_heal < PULSE_SPAN,
		"체력이 회복됐는데 기지 표시가 계속 맥동한다 (span %.3f) — 트윈이 죽지 않았다" % span_after_heal)

	# ── 3. 재진입·반복 신호에서도 살아 있는 맥동 트윈이 정확히 하나 ───────────
	# 누수 구현에서는 이탈이 트윈을 놓아주지 않으므로 재진입마다 하나씩 쌓인다.
	var before_second := get_tree().get_processed_tweens()
	main.defense_field.base_hp_changed.emit(10, MAX_HP)
	await get_tree().process_frame
	var pulse2: Tween = _new_tween(before_second)
	var n_reentry: int = get_tree().get_processed_tweens().size()
	print("LOW_HP_PROBE reentry new_tween=%s live_tweens=%d" % [
		"yes" if pulse2 != null else "NO", n_reentry])
	check(pulse2 != null, "위험 구간 재진입에서 맥동 트윈이 생기지 않았다")
	check(n_reentry == 1,
		"살아 있는 맥동 트윈이 %d개다 — 쌓였다 (1개여야 한다)" % n_reentry)

	# ── 3b. 위험 구간에 **머무는 동안** 신호가 반복돼도 트윈은 하나 ───────────
	# 실전에서 가장 흔한 경로다 — 기지가 위험할 때 적이 새어 나갈 때마다 이 신호가 온다.
	# 가드가 없으면 그때마다 `set_loops()` 트윈이 하나씩 생겨 서로 다른 위상으로 민다.
	for i in range(5):
		main.defense_field.base_hp_changed.emit(10 - i, MAX_HP)   # 20% → 12%, 계속 위험 구간
		await get_tree().process_frame
	var n_repeat: int = get_tree().get_processed_tweens().size()
	print("LOW_HP_PROBE repeat_signals live_tweens=%d" % n_repeat)
	check(n_repeat == 1,
		"위험 구간에 머무는 동안 신호가 5번 반복되니 맥동 트윈이 %d개가 됐다 (1개여야 한다)" % n_repeat)

	# ── 4. 전멸(ratio 0)은 위험 구간이 아니다 ────────────────────────────────
	main.defense_field.base_hp_changed.emit(MAX_HP, MAX_HP)   # 먼저 위험 구간에서 나온다
	await get_tree().process_frame
	var before_zero := get_tree().get_processed_tweens()
	main.defense_field.base_hp_changed.emit(0, MAX_HP)
	await get_tree().process_frame
	var started := _new_tween(before_zero)
	print("LOW_HP_PROBE dead new_tween=%s modulate=%s" % [
		"yes" if started != null else "NO", str(hp_box.modulate)])
	check(started == null,
		"전멸(ratio 0)이 맥동 트윈을 만들었다 — 게임오버 뒤에 흔들 이유가 없다")
	check(hp_box.modulate.is_equal_approx(Color.WHITE),
		"전멸 상태인데 기지 표시가 흰색이 아니다 (%s)" % str(hp_box.modulate))

	if failures == 0:
		print("LOW_HP_WARNING_PROBE_OK")
	get_tree().quit(failures)
