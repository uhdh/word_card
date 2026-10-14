extends Node
# 보상 카드가 벨트로 **날아가는** 연출이 실제로 있는가 (감사 §2.6 문제 2, 2026-09-23).
#
# 왜 문제였나:
# 카드를 고르면 `add_jamo` 가 즉시 벨트를 다시 그려서 활자가 벨트에 **툭 나타난다.**
# 클릭과 결과 사이에 시각적 연결이 없다 — 사용자 지적 "아이템은 얻지만 획득감을 못 느낌".
# 로직(활자를 받는다)은 완전한데 **표현**이 없어서 전달되지 않는 사건이다.
#
# ⚠️ 이 도구가 재는 것 여섯 (한쪽만 재면 반쪽짜리 검사다):
#   1) 고스트가 **생긴다** (§1) — 그리고 벨트에 활자가 실제로 들어간다
#   2) 고스트가 **카드에서** 출발한다 (§1 출발점이 카드 중심 근처)
#   3) 고스트가 **벨트 타일 쪽으로** 이동한다 (§2 멀어지면 안 된다)
#   4) 고스트가 **해제된다** (§3 — 누수 없음). 연출은 매 웨이브마다 도므로
#      해제되지 않으면 런당 60개가 쌓인다
#   5) 출발점이 **없으면** 아예 뜨지 않는다 (§4 건너뛰기 · §5 1인자 호출)
#   6) 활자가 **비면** 좌표가 있어도 뜨지 않는다 (§6)
#   §3 이 없으면 "고스트를 만들고 안 지우는" 고침이 통과한다.
#   §4(건너뛰기)가 없으면 "건너뛰기에도 글자가 날아가는" 고침이 통과한다.
#   ⚠️ §5·§6 이 왜 **따로** 필요한가 — 2026-09-23 에 실제로 물렸다:
#      가드는 두 절인데 건너뛰기는 활자도 좌표도 0 이라 **한 절만으로도** 막힌다.
#      그래서 앞 절(활자)을 지운 주입이 §4 를 통과했고(RC=0), 뒤 절(좌표)을 지운
#      주입은 §5 가 없어 못 잡았다. **절 하나에 절 하나씩** 재야 한다.
#      §5 = 좌표 절 · §6 = 활자 절. (§6 은 함수의 계약을 직접 잰다 — 경로 흉내가 아니다.)
#
# 실행: godot --headless --path . res://tools/RewardFlightProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

const GHOST_PREFIX := "RewardFlightGhost"
## 고스트의 크기(`_fly_jamo_to_belt` 와 같아야 한다). 중심을 계산하는 데 쓴다.
const GHOST_HALF := Vector2(20, 20)

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## `TowerDefenseMain` 의 직계 자식 중 고스트를 모은다.
func _ghosts(main: Node) -> Array:
	var out: Array = []
	for c in main.get_children():
		if str(c.name).begins_with(GHOST_PREFIX):
			out.append(c)
	return out

## 고스트의 **중심**. `global_position` 은 좌상단이라 그대로 비교하면 20px 어긋난다.
func _center_of(node: Control) -> Vector2:
	return node.global_position + GHOST_HALF

## 고스트가 모두 사라질 때까지 기다린다 — **절 사이의 오염**을 막는다.
## ⚠️ 왜 필요한가(2026-09-23 실측): 고스트는 0.28초 산다. 앞 절이 (주입 때문에)
## 고스트를 만들면 그게 뒤 절의 측정 시점까지 살아 있어, **뒤 절이 자기 절 때문에
## 걸린 것인지 앞 절의 잔재 때문인지 구별할 수 없다** — 주입 D1 에서 실제로 §6 이
## 엉뚱하게 같이 걸렸다. 절마다 자기 효과만 재려면 사이를 비워야 한다.
func _drain_ghosts(main: Node, timeout_s := 1.0) -> void:
	var waited := 0.0
	while not _ghosts(main).is_empty() and waited < timeout_s:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05

func _ready() -> void:
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
	var belt_before: int = main.jamo_belt.jamo_list.size()
	print("REWARD_FLIGHT_PROBE baseline belt=%d ghosts=%d" % [belt_before, _ghosts(main).size()])
	check(_ghosts(main).is_empty(), "기준선에 이미 고스트가 있다")

	# ── 1. 카드를 고른다 (실제 버튼 신호) ────────────────────────────────────
	main._show_wave_reward(1, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	check(modal != null, "보상 모달이 뜨지 않았다")
	var cards: Array = modal.choices_container.get_children()
	check(cards.size() == 3, "카드가 %d장이다 (3장이어야 한다)" % cards.size())

	var card: Button = cards[0]
	var card_center: Vector2 = card.get_global_rect().get_center()
	card.pressed.emit()
	# 고스트는 `_fly_jamo_to_belt` 의 `await process_frame` **뒤에** 만들어진다.
	await get_tree().process_frame
	await get_tree().process_frame

	var ghosts := _ghosts(main)
	print("REWARD_FLIGHT_PROBE picked belt=%d ghosts=%d" % [
		main.jamo_belt.jamo_list.size(), ghosts.size()])
	check(main.jamo_belt.jamo_list.size() == belt_before + 1,
		"벨트에 활자가 들어가지 않았다 (%d -> %d)" % [
			belt_before, main.jamo_belt.jamo_list.size()])
	check(ghosts.size() == 1, "고스트가 %d개다 (1개여야 한다)" % ghosts.size())
	if ghosts.is_empty():
		get_tree().quit(failures + 1)
		return

	var ghost: Control = ghosts[0]
	var p0 := _center_of(ghost)
	var d_card := p0.distance_to(card_center)
	print("REWARD_FLIGHT_PROBE start ghost=%s card=%s dist=%.1f" % [
		str(p0.round()), str(card_center.round()), d_card])
	# 출발점이 카드 중심이어야 "이 카드에서 나왔다" 로 읽힌다.
	check(d_card < 60.0, "고스트가 카드 중심에서 %.1fpx 떨어진 곳에서 시작했다 (60 이하여야 한다)" % d_card)

	# ── 2. 벨트 타일 쪽으로 **이동**하는가 ───────────────────────────────────
	var tile: Control = main.jamo_belt.tile_node_at(belt_before)
	check(tile != null, "새 활자의 타일 노드를 찾지 못했다 (도착점을 잴 수 없다)")
	if tile == null:
		get_tree().quit(failures + 1)
		return
	var tile_center: Vector2 = tile.get_global_rect().get_center()
	# ⚠️ 이동을 재는 기준은 **타일까지의 거리**다. 카드까지의 거리(`d_card`)와 섞으면
	#    서로 다른 기준점을 비교하게 되어 **의미 없는 단언**이 된다(실제로 그렇게 짰다가
	#    497px 를 436px 이동한 것을 '이동 부족' 으로 잘못 판정했다).
	var d_tile0 := p0.distance_to(tile_center)
	check(d_tile0 > 100.0,
		"카드와 벨트 타일이 %.1fpx 밖에 안 떨어져 있다 — 이동을 재려면 더 멀어야 한다" % d_tile0)

	await get_tree().create_timer(0.20).timeout
	var alive := is_instance_valid(ghost)
	var p1 := _center_of(ghost) if alive else Vector2.INF
	var d_tile1 := p1.distance_to(tile_center) if alive else -1.0
	print("REWARD_FLIGHT_PROBE move tile=%s tile_dist=%.1f -> %.1f" % [
		str(tile_center.round()), d_tile0, d_tile1])
	check(alive, "고스트가 0.20초 만에 사라졌다 (연출이 0.28초인데 너무 이르다)")
	if alive:
		check(d_tile1 < d_tile0 * 0.5,
			"고스트가 벨트 타일 쪽으로 충분히 이동하지 않았다 (%.1fpx -> %.1fpx)" % [d_tile0, d_tile1])

	# ── 3. 고스트가 **해제되는가** (누수 검사) ───────────────────────────────
	# 연출은 매 웨이브마다 돈다 — 해제되지 않으면 런당 60개가 쌓인다.
	await get_tree().create_timer(0.5).timeout
	var leaked := is_instance_valid(ghost)
	print("REWARD_FLIGHT_PROBE freed leaked=%s ghosts=%d" % [leaked, _ghosts(main).size()])
	check(not leaked, "고스트가 해제되지 않았다 — 연출마다 노드가 쌓인다")
	check(_ghosts(main).is_empty(), "고스트가 %d개 남아 있다" % _ghosts(main).size())

	# ── 4. 건너뛰기는 날아가지 않는다 (양방향 검사의 뒤쪽) ───────────────────
	# 건너뛰면 받는 활자가 없다 — 연출이 나오면 거짓 신호다.
	var belt_mid: int = main.jamo_belt.jamo_list.size()
	main._show_wave_reward(2, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal2 = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	check(modal2 != null, "2번째 보상 모달이 뜨지 않았다")
	if modal2 == null:
		get_tree().quit(failures + 1)
		return
	modal2.btn_skip.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("REWARD_FLIGHT_PROBE skip belt=%d ghosts=%d" % [
		main.jamo_belt.jamo_list.size(), _ghosts(main).size()])
	check(main.jamo_belt.jamo_list.size() == belt_mid,
		"건너뛰었는데 벨트가 바뀌었다 (%d -> %d)" % [belt_mid, main.jamo_belt.jamo_list.size()])
	check(_ghosts(main).is_empty(), "건너뛰기에 고스트가 %d개 생겼다" % _ghosts(main).size())
	await _drain_ghosts(main)

	# ── 5. 출발점 없는 호출은 날아가지 않는다 (가드의 **다른 절**) ────────────
	# ⚠️ 가드는 두 절이다: `char_str == ""` **또는** `from_global == Vector2.ZERO`.
	#    §4 는 앞 절만 잰다 — 건너뛰기는 활자가 비어서 걸리는 경로다.
	#    뒤 절은 **다른 호출자**를 지킨다: `DifficultyPlaytest.gd:272` 는
	#    `_on_wave_reward_chosen(str(choices[0]))` 로 **1인자**로 부른다 → 활자는 있고
	#    좌표만 없다. 이때 연출을 그냥 쏘면 활자가 **화면 좌상단 모서리에서** 날아온다
	#    (좌표 0,0 기준). 그건 "이 카드에서 나왔다" 는 정보를 거짓으로 만든다.
	#    §5 가 없으면 '뒤 절 삭제' 주입이 통과한다 — 절이 둘이면 프로브도 둘이다.
	var belt_tail: int = main.jamo_belt.jamo_list.size()
	main._on_wave_reward_chosen("가")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("REWARD_FLIGHT_PROBE no_origin belt=%d ghosts=%d" % [
		main.jamo_belt.jamo_list.size(), _ghosts(main).size()])
	check(main.jamo_belt.jamo_list.size() == belt_tail + 1,
		"1인자 호출이 활자를 넣지 않았다 — 호출이 아예 안 갔다 (%d -> %d)" % [
			belt_tail, main.jamo_belt.jamo_list.size()])
	check(_ghosts(main).is_empty(),
		"출발점 없는 호출에 고스트가 %d개 생겼다 (좌표 없이 날아가면 안 된다)" % _ghosts(main).size())
	await _drain_ghosts(main)

	# ── 6. 빈 활자는 좌표가 있어도 뜨지 않는다 (가드의 **앞 절**) ──────────────
	# ⚠️ 왜 §4 로는 부족한가 — **실측으로 확인한 함정**(2026-09-23):
	#    건너뛰기는 활자도 `""` 이고 좌표도 `Vector2.ZERO` 라 **어느 한 절만으로도** 막힌다.
	#    그래서 앞 절을 지운 주입이 §4 를 **그대로 통과했다**(RC=0) — §4 는 앞 절을
	#    재는 것처럼 보이지만 실제로는 뒤 절이 대신 막아 주고 있었다.
	#    앞 절만 재려면 **좌표가 있는데 활자가 빈** 호출을 직접 만들어야 한다.
	#    이건 함수의 계약이다(`_fly_jamo_to_belt` 주석) — 건너뛰기 경로를 흉내내는 게 아니다.
	var belt_last: int = main.jamo_belt.jamo_list.size()
	main._fly_jamo_to_belt("", Vector2(300.0, 300.0))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("REWARD_FLIGHT_PROBE empty_char belt=%d ghosts=%d" % [
		main.jamo_belt.jamo_list.size(), _ghosts(main).size()])
	check(main.jamo_belt.jamo_list.size() == belt_last,
		"연출만 부른 것인데 벨트가 바뀌었다 (%d -> %d)" % [
			belt_last, main.jamo_belt.jamo_list.size()])
	check(_ghosts(main).is_empty(),
		"빈 활자에 고스트가 %d개 생겼다 (좌표가 있어도 띄울 글자가 없으면 뜨면 안 된다)" % _ghosts(main).size())

	if failures == 0:
		print("REWARD_FLIGHT_PROBE_OK")
	get_tree().quit(failures)
