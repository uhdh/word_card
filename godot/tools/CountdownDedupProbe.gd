extends Node
# 같은 숫자가 화면에 **두 번** 보이는가 — 카운트다운과 다음 라운드 예고의 중복.
# (감사 §5.2 항목 21, 2026-09-23)
#
# 왜 문제였나:
# `_process()` 가 **같은 값**을 두 라벨에 쓴다. 두 라벨의 분기는 네 상태가 완전히 동일하다:
#
#   상단 바 `SpawnTimerLabel`      | 텔레그래프 바 `TelegraphTimer`
#   ------------------------------ | ------------------------------
#   "다음 젠: 대기 중"              | "대기 중"
#   "배치 준비 %d초"                | "배치 %d초"
#   "마지막 라운드"                 | "마지막 라운드"
#   "다음 젠: %d초"                 | "다음 웨이브 %d초"
#
# 둘 다 `ROUND_INTERVAL - round_timer` 에 `ceili` 를 쓴다 — **같은 숫자, 다른 문구.**
# 두 문구가 다르면 플레이어는 **서로 다른 타이머**로 읽는다. 정보가 두 배가 아니라 **혼란이 두 배**다.
#
# ⚠️ 이 도구가 재는 것 넷 (한쪽만 재면 반쪽짜리 검사다):
#   1) 웨이브 중 카운트다운이 화면에 **정확히 하나** (§1)
#   2) 배치 단계에서도 **정확히 하나** (§2 — 다른 분기라 따로 재야 한다)
#   3) 다음 라운드 예고도 **정확히 하나** (§3 — 예고는 중복이 아니었지만, 같이 재야
#      '예고를 실수로 지우는' 고침이 통과하지 못한다)
#   4) 대기 중에는 카운트다운이 **없다** (§0 — 이게 없으면 "라벨을 전부 지우는" 고침이 통과한다)
#
# ⚠️ 왜 노드 경로가 아니라 **화면을 세는가**: 경로로 재면 "노드는 지웠는데 다른 라벨에 같은 값을
#    쓰는" 고침이 통과한다. 이 결함의 본질은 **노드가 아니라 보이는 문구**다.
#    그래서 트리를 훑어 **보이는 라벨의 텍스트**를 센다(`is_visible_in_tree()`).
#
# 실행: godot --headless --path . res://tools/CountdownDedupProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 카운트다운 문구의 표식 — **"초" 로 끝난다**.
## ⚠️ `contains("초")` 로 하면 안 된다(2026-09-23 실측): `WaveLabel` 이
## `"제 1막 [초원의 문자]"` 라서 **"초" 를 포함**한다 → 멀쩡한 라벨이 카운트다운으로 세어져
## 첫 실행이 RC=4 로 실패했다. 네 분기 중 초를 세는 둘은 **둘 다 "초" 로 끝난다**
## ("배치 5초" · "다음 웨이브 15초"). 표식은 **문구의 구조**에서 와야 한다.
const COUNTDOWN_SUFFIX := "초"
## 다음 라운드 예고의 표식 — `DefenseField.next_round_preview()` 가 "다음 %d막 %dR: …" 를 준다.
const PREVIEW_MARK := "R:"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _is_countdown(text: String) -> bool:
	return text.ends_with(COUNTDOWN_SUFFIX)

## 화면에 **보이는** 라벨 중 조건을 만족하는 것들의 (경로, 문구) 목록.
## ⚠️ `is_visible_in_tree()` 를 쓴다 — `visible` 만 보면 부모가 숨은 경우를 놓친다
##    (`NextRoundLabel` 이 정확히 그 경우였다: 자기 `visible=false`).
func _visible_labels(root: Node, predicate: Callable) -> Array:
	var out: Array = []
	for l in _all_labels(root):
		if l.is_visible_in_tree() and predicate.call(l.text):
			out.append([str(root.get_path_to(l)), l.text])
	return out

func _visible_countdowns(root: Node) -> Array:
	return _visible_labels(root, _is_countdown)

func _visible_previews(root: Node) -> Array:
	return _visible_labels(root, func(t: String) -> bool: return t.contains(PREVIEW_MARK))

func _all_labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_labels(c))
	return out

func _report(label: String, found: Array) -> void:
	print("  %s: %d개" % [label, found.size()])
	for row in found:
		print("      %s = %s" % [row[0], row[1]])

## 웨이브가 실제로 돌아가고 있는가 — 아니면 재는 대상이 없다.
func _wave_is_live(main) -> bool:
	return main.defense_field.is_wave_running

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	# `start_new_game` 끝의 `call_deferred("_start_wave_automatically")` 를 멈춘다.
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not _wave_is_live(main), "기준선에서 이미 웨이브가 돌고 있다 — 재는 대상이 다르다")

	# ── 0. 대기 중 — 카운트다운이 없어야 한다 ────────────────────────────────
	# 이 절이 없으면 "카운트다운 라벨을 전부 지우는" 고침이 통과한다.
	var idle_cd := _visible_countdowns(main)
	var idle_pv := _visible_previews(main)
	print("COUNTDOWN_PROBE idle countdown=%d preview=%d" % [idle_cd.size(), idle_pv.size()])
	_report("idle 카운트다운", idle_cd)
	_report("idle 예고", idle_pv)
	check(idle_cd.is_empty(),
		"대기 중인데 카운트다운이 %d개 보인다 — 웨이브가 없으면 셀 것이 없다" % idle_cd.size())
	check(idle_pv.size() == 1,
		"대기 중 예고가 %d개다 (1이어야 한다) — 예고는 웨이브 전에 보여야 의미가 있다" % idle_pv.size())

	# ── 1. 웨이브 중 — 카운트다운은 **하나** ────────────────────────────────
	main._on_start_wave_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	check(_wave_is_live(main), "웨이브 시작이 안 됐다 — 카운트다운을 잴 수 없다")
	var live_cd := _visible_countdowns(main)
	print("COUNTDOWN_PROBE live countdown=%d" % live_cd.size())
	_report("live 카운트다운", live_cd)
	check(not live_cd.is_empty(),
		"웨이브가 도는데 카운트다운이 하나도 안 보인다 — 정보가 사라졌다")
	check(live_cd.size() == 1,
		"카운트다운이 화면에 %d개 동시에 보인다 (1이어야 한다) — 같은 숫자가 두 문구로 두 번 보인다" % live_cd.size())

	# ── 2. 배치 단계 — 다른 분기다. 따로 재야 한다 ──────────────────────────
	# ⚠️ 분기가 넷이면 절도 넷이어야 한다. §1 만 있으면 "배치 단계만 중복" 인 고침이 통과한다.
	main.defense_field.is_planning_phase = true
	main.defense_field.planning_timer = 5.0
	await get_tree().process_frame
	var plan_cd := _visible_countdowns(main)
	print("COUNTDOWN_PROBE planning countdown=%d" % plan_cd.size())
	_report("planning 카운트다운", plan_cd)
	check(plan_cd.size() == 1,
		"배치 단계 카운트다운이 %d개다 (1이어야 한다)" % plan_cd.size())
	main.defense_field.is_planning_phase = false

	# ── 3. 다음 라운드 예고도 **하나** ──────────────────────────────────────
	# 예고는 원래 중복이 아니었다(`NextRoundLabel` 은 숨은 채로 갱신만 되고 있었다).
	# 그래도 같이 재는 이유: 중복을 정리하다 **예고까지 지우는** 고침을 막아야 한다.
	var live_pv := _visible_previews(main)
	print("COUNTDOWN_PROBE live preview=%d" % live_pv.size())
	_report("live 예고", live_pv)
	check(live_pv.size() == 1,
		"다음 라운드 예고가 화면에 %d개다 (1이어야 한다)" % live_pv.size())

	# ── 4. 죽은 표시가 남아 있지 않은가 ─────────────────────────────────────
	# ⚠️ `NextRoundLabel` 은 씬에서 `visible=false` 인데 코드는 계속 갱신하고 있었다 —
	#    **코드는 보여준다고 믿는데 화면에는 없는** 상태다. 숨은 라벨이 남아 있으면
	#    다음 사람이 "여기에도 쓰면 되겠네" 하고 되살린다.
	var hidden_pv: Array = []
	for l in _all_labels(main):
		if not l.is_visible_in_tree() and l.text.contains(PREVIEW_MARK):
			hidden_pv.append(str(main.get_path_to(l)))
	var hidden_cd: Array = []
	for l in _all_labels(main):
		if not l.is_visible_in_tree() and _is_countdown(l.text):
			hidden_cd.append(str(main.get_path_to(l)))
	print("COUNTDOWN_PROBE hidden preview=%s countdown=%s" % [str(hidden_pv), str(hidden_cd)])
	check(hidden_pv.is_empty(),
		"숨은 라벨에 예고가 남아 있다 %s — 코드가 갱신하는데 화면엔 없는 죽은 표시다" % str(hidden_pv))
	check(hidden_cd.is_empty(),
		"숨은 라벨에 카운트다운이 남아 있다 %s" % str(hidden_cd))

	if failures == 0:
		print("COUNTDOWN_DEDUP_PROBE_OK")
	get_tree().quit(failures)
