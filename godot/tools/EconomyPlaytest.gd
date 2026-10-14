# EconomyPlaytest.gd
# 3막 60라운드를 실제로 완주하면서 골드가 어떻게 흐르는지 잰다.
#
# EconomyProbe 가 '수입 공식' 을 계산하는 것과 달리, 이쪽은 진짜 게임 루프를 돌린다.
#   - 실제 웨이브 스폰 → 처치 → 라운드 보상 → 구매 → 다음 라운드
#   - 구매는 실제 경로(JamoBelt 의 모음 즉시구매 버튼 핸들러)를 그대로 탄다.
#
# 두 가지 의도적 단순화 (수치 해석할 때 감안할 것):
#   1. 타워 피해를 크게 올려 적이 새지 않게 한다. 난이도가 아니라 '골드 흐름' 을
#      재는 것이 목적이라, 적이 전부 죽어 수입이 100% 들어오는 상태가 기준이다.
#   2. 웨이브 보상 활자는 건너뛴다. '골드 → 타일' 경로만 깨끗하게 보기 위해서다.
#      (실제 플레이에서는 무료 활자가 섞여 구매 수요가 이보다 조금 줄어든다)
#
#   cd godot && godot --headless --path . res://tools/EconomyPlaytest.tscn

extends Node

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

const RELIC_BUFFER := 40
const TILE_CAP := 30
const SPEED := 10.0
const TIMEOUT_MS := 240000

var game: Node
var bought := 0
var spent := 0
var swaps := 0
var swap_spent := 0
var gold_log: Array = []
var finished := false
var started_at := 0


func _ready() -> void:
	game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_new_game()
	game.jamo_belt.slot_assignments.assign([0, 0, 0])
	game.jamo_belt.render_belt()
	game.set_speed_scale(SPEED)
	game.defense_field.wave_cleared.connect(_on_wave_cleared)
	game.defense_field.act_cleared.connect(_on_act_cleared)
	game.defense_field.game_over.connect(_on_game_over)
	started_at = Time.get_ticks_msec()
	game._on_start_wave_pressed()


func _process(_delta: float) -> void:
	if finished:
		return
	# 주의: _process 의 delta 는 Engine.time_scale 에 곱해져 들어온다.
	# 그대로 누적하면 배속이 높을수록 타임아웃이 일찍 걸린다. 실제 시계를 쓴다.
	if Time.get_ticks_msec() - started_at > TIMEOUT_MS:
		finished = true
		print("\n⏱️ 타임아웃 — %d라운드까지 진행" % _round_index())
		_report(false)
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	# 적이 길을 빠져나가면 처치 골드가 덜 들어와 측정이 흔들린다.
	# 이건 난이도 측정이 아니라 수입 측정이므로, 전량 처치되는 상태로 고정한다.
	for tower in game.defense_field.active_towers:
		tower.damage_multiplier = 500.0


func _round_index() -> int:
	return (game.defense_field.current_act - 1) * 20 + game.defense_field.current_wave


func _on_wave_cleared(act: int, wave: int, _bonus: int) -> void:
	_log(act, wave)
	call_deferred("_settle_round")


func _on_act_cleared(act: int, _bonus: int) -> void:
	_log(act, 20)
	call_deferred("_advance_act", act)


func _on_game_over(victory: bool) -> void:
	if finished:
		return
	finished = true
	_log(game.defense_field.current_act, game.defense_field.current_wave)
	_settle()
	_report(victory)
	Engine.time_scale = 1.0
	get_tree().quit(0 if victory else 1)


func _settle_round() -> void:
	if finished:
		return
	_settle()


func _advance_act(act: int) -> void:
	if finished:
		return
	_settle()
	print("  ▶ %d막 클리어 — 골드 %dG, 누적 구매 %d장" % [act, game.defense_field.gold, bought])
	game._on_start_wave_pressed()


func _settle() -> void:
	_clear_modals()
	_buy_tiles()
	_swap_tiles()


## 웨이브 보상 모달을 치운다. 활자는 받지 않는다 (위 주석 참고).
## queue_free 로 바로 지우면 모달이 걸어 둔 트윈 람다가 살아 있는 채로 사라져
## "Lambda capture was freed" 에러가 난다. 모달 자신의 _close() 를 태워야 깔끔하다.
func _clear_modals() -> void:
	for child in game.modal_layer.get_children():
		if child.has_method("_close"):
			child._close()
		else:
			child.queue_free()


## (골드 - 소액 버퍼) 으로 살 수 있으면 산다. 실제 구매 핸들러를 그대로 탄다.
## 버퍼를 크게 잡으면(예: 유물값 300G) 초반에 한 장도 못 사서 측정이 무의미해진다.
## 유물 예산은 '다 사고 남은 골드' 로 사후에 읽는 편이 정확하다.
func _buy_tiles() -> void:
	var belt = game.jamo_belt
	var field = game.defense_field
	while bought < TILE_CAP:
		var price: int = belt.current_tile_price()
		if field.gold - RELIC_BUFFER < price:
			break
		var before: int = field.gold
		game._on_tile_purchase_requested(true)
		var paid: int = before - field.gold
		if paid <= 0:
			break  # 벨트가 꽉 찼거나 구매가 거부됐다
		bought += 1
		spent += paid


## 벨트가 꽉 차 구매가 막힌 뒤의 정책: 남은 골드로 활자를 계속 교체한다.
## 이게 '구매 불가 이후 골드가 쌓이는 문제'를 실제로 흡수하는지 재는 부분이다.
## 같은 활자가 나오면 결제가 안 되므로(게임이 돈을 안 받는다) 시도 횟수에 상한을 둔다.
func _swap_tiles() -> void:
	var belt = game.jamo_belt
	var field = game.defense_field
	var attempts := 0
	while attempts < 200 and not belt.jamo_list.is_empty():
		attempts += 1
		var price: int = belt.current_swap_price()
		if field.gold - RELIC_BUFFER < price:
			break
		var before: int = field.gold
		game._on_tile_swap_requested(0)
		var paid: int = before - field.gold
		if paid > 0:
			swaps += 1
			swap_spent += paid


func _log(act: int, wave: int) -> void:
	gold_log.append({
		"act": act,
		"wave": wave,
		"round": (act - 1) * 20 + wave,
		"gold": game.defense_field.gold,
		"hp": game.defense_field.base_hp,
		"bought": bought,
		"price": game.jamo_belt.current_tile_price(),
		"belt": game.jamo_belt.jamo_list.size()
	})


func _report(victory: bool) -> void:
	var field = game.defense_field
	var belt = game.jamo_belt
	print("\n=== 3막 완주 자동 플레이 결과 ===")
	print("완주: %s | 도달: %d막 %d라운드 | 기지 HP %d/%d" % [
		"성공" if victory else "실패",
		field.current_act, field.current_wave, field.base_hp, field.max_base_hp
	])
	print("타일 구매: %d장 | 지출 %dG | 장당 평균 %.1fG" % [
		bought, spent, float(spent) / maxf(1.0, float(bought))
	])
	print("활자 교체: %d회 | 지출 %dG | 회당 평균 %.1fG" % [
		swaps, swap_spent, float(swap_spent) / maxf(1.0, float(swaps))
	])
	print("총 지출: %dG (타일 %dG + 교체 %dG)" % [spent + swap_spent, spent, swap_spent])
	print("최종 골드: %dG — 이게 곧 '유물에 쓸 수 있는 돈' 이다 (유물 25~40G 기준 약 %d개분)" % [
		field.gold, int(float(field.gold) / 32.0)
	])
	print("최종 타일가 %dG | 벨트 %d장" % [belt.current_tile_price(), belt.jamo_list.size()])

	# 같은 라운드가 두 번 기록될 수 있다(막 클리어와 웨이브 클리어가 겹치는 경로).
	# 표를 믿을 수 있게 라운드 기준으로 중복을 제거하고 시간순으로 정렬한다.
	var rows := _deduped_log()

	# 벨트가 꽉 차면 골드가 있어도 더 못 산다. 그 시점이 곧 '골드가 쌓이기 시작하는 지점'.
	var capped := -1
	var gold_then := 0
	for entry in rows:
		if int(entry["belt"]) >= TILE_CAP:
			capped = int(entry["round"])
			gold_then = int(entry["gold"])
			break
	if capped > 0:
		var gold_end := int(rows[-1]["gold"]) if not rows.is_empty() else 0
		print("벨트 포화: %d라운드 (이후 구매 불가) — 그때 골드 %dG → 최종 %dG, %dG 가 쌓였다"
			% [capped, gold_then, gold_end, gold_end - gold_then])
	else:
		print("벨트 포화: 없음 — 끝까지 타일을 살 여지가 있었다")

	print("\n라운드별 골드 (5라운드 간격):")
	for entry in rows:
		if int(entry["round"]) % 5 == 0:
			print("  %2dR (%d막 %2d) | 골드 %4dG | 구매 %2d장 | 다음 타일 %2dG | 벨트 %2d장 | HP %d" % [
				int(entry["round"]), int(entry["act"]), int(entry["wave"]), int(entry["gold"]),
				int(entry["bought"]), int(entry["price"]), int(entry["belt"]), int(entry["hp"])
			])


## 라운드 번호 기준 중복 제거 + 오름차순 정렬. 같은 라운드가 여러 번 찍히면
## 가장 마지막(그 라운드가 완전히 끝난 시점) 기록을 남긴다.
func _deduped_log() -> Array:
	var by_round := {}
	for entry in gold_log:
		by_round[int(entry["round"])] = entry
	var rounds := by_round.keys()
	rounds.sort()
	var out: Array = []
	for r in rounds:
		out.append(by_round[r])
	return out
