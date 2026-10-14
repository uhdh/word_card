# DifficultyPlaytest.gd
# 3막 60라운드를 '치트 없이' 실제로 플레이해서 난이도를 잰다.
#
# EconomyPlaytest 와의 차이 (중요):
#   - EconomyPlaytest 는 타워 피해를 500배로 고정한다. 수입만 깨끗하게 보려고 적을
#     전부 죽이는 상태를 만든 것이고, 그래서 **난이도는 전혀 재지 못한다.**
#   - 이쪽은 아무 보정 없이 진짜로 막아 본다. 기지 HP 가 언제 얼마나 깎이는지가 곧 난이도다.
#
# 봇 정책 (실제 플레이어와 같은 경로만 쓴다):
#   1. 웨이브 보상을 받는다        → TowerDefenseMain._on_wave_reward_chosen()
#   2. 골드가 되면 활자를 산다      → _on_tile_purchase_requested()
#   3. 벨트에서 최선의 단어 3개를 골라 타워를 세운다 → AutoArrange + slot_assignments
#
#   cd godot && godot --headless --path . res://tools/DifficultyPlaytest.tscn

extends Node

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const AutoArrange = preload("res://scripts/core/AutoArrange.gd")

## 타일 구매 시 남겨 두는 골드. 벨트가 어느 정도 차면 유물 값(최소 25G)을 남긴다.
## 초반에 타워 3개를 세울 활자가 없으면 유물이 있어도 막을 수 없으므로,
## "먼저 방어선을 만들고 그다음 유물에 투자한다" 는 순서를 정책으로 굳힌 것.
const RELIC_RESERVE := 25
const RELIC_RESERVE_FROM_BELT := 15

## 유물·비상용으로 남겨 두는 골드. 0 으로 두면 타일만 사다가 유물을 못 산다.
## 봇이 골드를 너무 많이 쥐고 있으면 타워가 약해져서 '난이도' 가 아니라
## '봇의 경제 정책' 을 재게 된다. 그래서 사용자 인자로 바꿀 수 있게 열어 둔다.
##   godot --headless --path . res://tools/DifficultyPlaytest.tscn -- slots=3 buffer=0
const DEFAULT_BUY_BUFFER := 25
var buy_buffer := DEFAULT_BUY_BUFFER
const TILE_CAP := 30
const SPEED := 10.0
const TIMEOUT_MS := 300000

## ── 난이도 게이트 ──────────────────────────────────────────────────────────
## `gate=1` 이면 측정 결과가 밴드를 벗어났을 때 종료 코드 1 로 끝난다.
##   하한: 최소 GATE_MIN_ROUND 라운드까지 도달해야 한다 — 못 가면 게임이 불가능해진 것.
##   상한: 클리어했다면 남은 HP 비율이 GATE_MAX_HP_RATIO 이하여야 한다 —
##         아무 저항 없이 이기면 게임이 자명해진 것.
##
## 왜 필요한가: `early_wave_playtest` 는 첫 몇 라운드만 본다. 그래서 60라운드 전체를
## 자명하게 만드는 변경도 CI 를 그대로 통과한다. 2026-09-18 에 실제로 그렇게
## 난이도가 뒤집혔다 (봇이 3막 5R 사망 → 60라운드 완주). 그때를 잡아 줄 게이트가 없었다.
##
## 2026-09-18 실측 기준값: 60라운드 클리어, 기지 24/60 (남은 비율 40%).
## 상한 75% 는 여유가 크지만 '자명하게 이기는' 변화는 확실히 잡는다.
const GATE_MIN_ROUND: int = 45
const GATE_MAX_HP_RATIO: float = 0.75

## 재현용 시드. 0 이 아니면 **봇이 뽑기를 하는 지점마다** 전역 난수를 다시 고정한다.
##
## 왜 필요한가 (2026-09-23 실측): 이 봇의 벨트 구성은 판마다 달라지고, **벨트 구성이 곧
## 전력**이다. 그래서 지금까지 이 도구가 재던 것은 난이도가 아니라 **타일 운**이었다.
## 시드 없는 두 실행 —
##   타워 [도깨비, 절대자, 이마] → 남은 HP 98% (밴드 이탈)
##   타워 [절대자, 이마, 수비]   → 남은 HP 36% (밴드 안)
##
## ⚠️ **실행 시작에 `seed()` 를 한 번 거는 것으로는 재현되지 않는다.** 같은 시드로 3회
## 돌려 봤더니 타워가 매번 달랐고 남은 HP 가 120% / 56% / 88% 였다. 이유는 전역 난수를
## **게임 내부가 소비하는 양이 매판 다르기** 때문이다 — 지도 생성, 타워의 크리티컬 판정이
## 전부 같은 흐름을 나눠 쓰고, 그 횟수는 프레임 타이밍에 좌우된다. 그래서 흐름을 앞에서
## 한 번 고정해도 시작 자모를 뽑을 때는 이미 어긋나 있다.
##
## 해결: 봇이 **입력을 정하는 바로 그 지점**에서 시드를 다시 건다. 그러면 게임 내부의
## 난수 소비와 분리되어, '봇이 받는 타일' 이 재현된다. 게임 내부의 크리티컬은 여전히
## 매판 다르지만, 그건 난이도에 주는 영향이 훨씬 작다.
##
## ⚠️ **그 '훨씬 작다' 는 2026-10-03 에 반증됐다 — 판정 자체가 뒤집힌다.**
##    같은 명령·같은 시드로 7회 돌린 남은 HP: **60 · 76 · 86 · 96 · 108 · 118 · 120 %**
##    (문턱 75%). 위반 6회 · **통과 1회.** 즉 *"판정만 믿어라"* 는 지침도 성립하지 않는다 —
##    한 번 돌려 '위반' 이 나왔다고 게임이 어렵다고, '통과' 가 나왔다고 적당하다고 말할 수 없다.
##
##    원인(코드 추적): 크리티컬 판정과 `Juice.shake()` 가 **프레임 타이밍에 따라 소비 횟수가
##    달라지는** 전역 난수를 쓴다 → 그 소비량이 **골드**를 흔든다 → 골드가 `_buy_tiles()` 의
##    **while 루프 횟수**를 정하고, 루프 한 바퀴마다 타일 난수를 한 번 뽑으므로 **봇의 난수
##    흐름이 어긋난다** → 다른 타일 → 다른 타워 → 다른 판정.
##    (실측: 4회 중 3회는 타워가 `[진지, 보루, 마루]` 로 같았고, 1회만 달라서 그 회차가 통과했다.)
##
##    → **한 번의 실행을 판정으로 쓰지 마라. 여러 번 돌려 분포로 읽어라.**
##      좋은 예: 5회 중 중앙값, 그리고 '위반 횟수'. 나쁜 예: 1회의 RC.
##
##    그 '여러 번' 을 **도구가 직접** 하도록 `runs=N` 을 두었다(아래). 회차마다 봇 시드를
##    바꾸고, 판정은 **중앙값**으로 내린다. `gate=1` 이면 기본 3회다.
##
##   godot --headless --path . res://tools/DifficultyPlaytest.tscn -- gate=1 seed=20260923
const DEFAULT_GATE_SEED := 20260923
var gate_enabled := false
var gate_failed := false
## 0 이면 시드를 쓰지 않는다(기존 동작). gate=1 이면 기본 시드가 들어간다.
var bot_seed := 0

## ── 회차(runs) — 2026-10-03 신설 ───────────────────────────────────────────
## 60라운드를 **N번** 돌리고 **중앙값**으로 판정한다. 회차마다 봇 시드를 바꾼다.
##
## 왜 필요한가 (측정): 같은 명령·같은 시드로 7회 돌린 남은 HP 가
##   **60 · 76 · 86 · 96 · 108 · 118 · 120 %** (문턱 75%) 였다 — **위반 6, 통과 1.**
##   즉 **한 번의 RC 는 판정이 아니다.** 3회만 돌려 *"3/3 위반"* 이라고 적었던 것이
##   이 도구가 감춘 거짓이었다(그 3회가 우연히 위쪽에 몰렸다).
##   원인은 게임이 아니라 이 도구다 — 위 헤더의 ⚠️ 항목 참조.
##
## 그래서 판정은 **분포의 중앙값**으로 한다. 단일 회차의 통과/위반은 인쇄만 하고
## 판정에 쓰지 않는다. (중앙값은 위반 '횟수' 가 아니라 '가운데' 다 — 일부 회차가
## 위반이어도 중앙값이 밴드 안이면 통과로 본다. 정상적인 흩어짐까지 실패로 만들면
## 게이트가 영구히 빨개진다.)
##   godot --headless --path . res://tools/DifficultyPlaytest.tscn -- gate=1 buffer=0 runs=5
## 비용: 1회 ≈2분 → 3회 ≈6분. `runs=1` 로 명시하면 옛 동작(빠른 확인용).
var runs := 1
var run_index := 0
## 회차별 결과: {"victory", "hp", "reference", "ratio", "reached", "ok", "reason"}
var run_results: Array = []
## 이번 회차의 봇 시드(회차마다 달라진다).
var run_seed := 0

var game: Node
var finished := false
var started_at := 0
var round_log: Array = []
var rewards_taken := 0
var bought := 0
## 봇이 상인 상점에서 실제로 산 유물 수와 지출. 유물은 피해/공속 배수라
## 이게 0 이면 측정값이 실제 난이도보다 훨씬 어렵게 나온다.
var relics_bought := 0
var relic_gold := 0
## 마지막으로 세운 타워의 단어들. 난이도 결과를 해석할 때 근거가 된다.
var last_towers: Array = []
## 봇이 실제로 세우는 타워 수. 난이도 감도를 재려고 줄여 본다.
##   godot --headless --path . res://tools/DifficultyPlaytest.tscn -- slots=1
var slot_limit := 3
## 기지 HP 를 바꿔서 측정하기 위한 실험 변수. 0 이면 게임 기본값.
##   godot --headless --path . res://tools/DifficultyPlaytest.tscn -- hp=40
var start_hp := 0


func _ready() -> void:
	slot_limit = _read_slot_limit()
	buy_buffer = _read_int_arg("buffer", DEFAULT_BUY_BUFFER)
	start_hp = _read_int_arg("hp", 0)
	gate_enabled = _read_int_arg("gate", 0) != 0
	bot_seed = _read_int_arg("seed", 0)
	# gate=1 인데 시드를 안 주면 기본 시드를 쓴다 — 게이트는 재현돼야 게이트다.
	if bot_seed == 0 and gate_enabled:
		bot_seed = DEFAULT_GATE_SEED
	# 게이트는 기본 3회. 1회는 2분이라 빠르지만 **판정으로 쓸 수 없다**(위 ⚠️).
	runs = _read_int_arg("runs", 3 if gate_enabled else 1, 1, 9)
	await _begin_run()


## 한 회차를 시작한다. 회차 사이에는 **게임을 새로 만든다.**
##
## 왜 인스턴스를 재사용하지 않는가: `start_new_game()` 은 기지 HP·골드·유물·벨트를
## 되돌리지만 **`active_towers` 는 건드리지 않는다**(`reset_combat_state()` 도 안 지운다).
## 즉 재사용하면 지난 회차의 타워가 남아 '난이도' 가 아니라 '누적 전력' 을 재게 된다.
## 새로 만들면 그 위험이 원리적으로 0 이다.
func _begin_run() -> void:
	finished = false
	gate_failed = false
	round_log.clear()
	rewards_taken = 0
	bought = 0
	relics_bought = 0
	relic_gold = 0
	last_towers = []
	if game != null and is_instance_valid(game):
		# ⚠️ **버리기 전에 신호를 끊는다.** `finished` 를 false 로 되돌린 직후라, 해제
		#    프레임에 옛 게임이 신호를 내면 `_log()` 가 죽은 노드를 만진다.
		var old_field = game.defense_field
		if old_field != null and is_instance_valid(old_field):
			if old_field.wave_cleared.is_connected(_on_round_end):
				old_field.wave_cleared.disconnect(_on_round_end)
			if old_field.act_cleared.is_connected(_on_act_end):
				old_field.act_cleared.disconnect(_on_act_end)
			if old_field.game_over.is_connected(_on_game_over):
				old_field.game_over.disconnect(_on_game_over)
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_new_game()
	# 회차마다 시드를 바꾼다. 같은 시드로도 결과가 흔들리지만(프레임 타이밍),
	# 시드까지 고정하면 '운' 의 한 점만 반복해서 재게 된다.
	run_seed = 0 if bot_seed == 0 else bot_seed + run_index
	# 시작 자모도 고정한다. 게임이 뽑은 세트를, 우리 시드로 다시 뽑은 것으로 덮는다.
	# (start_new_game 안의 뽑기는 지도 생성 등이 이미 흐름을 소비한 뒤라 재현되지 않는다)
	if run_seed != 0:
		seed(run_seed)
		game.jamo_belt.jamo_list = game.jamo_belt.generate_starting_jamo()
		game.jamo_belt.render_belt()
		print("🎲 %d/%d회차 · 봇 입력 고정 seed=%d · 시작 자모 %s" % [
			run_index + 1, runs, run_seed, str(game.jamo_belt.jamo_list)])
	# 기지 HP 를 실험 변수로 연다. '봇이 60라운드를 버티려면 HP 가 얼마나 필요한가' 를
	# 재는 것이 목적이다. (0 이면 게임 기본값을 그대로 쓴다)
	if start_hp > 0:
		game.defense_field.max_base_hp = start_hp
		game.defense_field.base_hp = start_hp
		game.defense_field.base_hp_changed.emit(start_hp, start_hp)
	game.jamo_belt.slot_assignments.assign([0, 0, 0])
	game.jamo_belt.render_belt()
	# ⚠️ `start_new_game()` 이 배속을 1.0 으로 되돌리므로 **그 뒤에** 걸어야 한다.
	game.set_speed_scale(SPEED)
	game.defense_field.wave_cleared.connect(_on_round_end)
	game.defense_field.act_cleared.connect(_on_act_end)
	game.defense_field.game_over.connect(_on_game_over)
	started_at = Time.get_ticks_msec()
	game._on_start_wave_pressed()


## 사용자 인자는 `OS.get_cmdline_user_args()` 로 읽는다 (`--` 뒤의 값).
## `OS.get_cmdline_args()` 에는 들어오지 않아서, 그걸로 읽으면 조용히 기본값이 된다.
func _read_slot_limit() -> int:
	return _read_int_arg("slots", 3, 1, 3)


## `-- 이름=값` 형태의 정수 인자. 없으면 기본값.
## 앞의 대시는 있어도 없어도 된다 — `gate=1` 과 `--gate=1` 이 둘 다 먹는다.
## 2026-09-18 실수: 대시를 붙여 넘겼더니 `begins_with("gate=")` 가 실패해서
## **게이트가 켜지지 않은 채 초록으로 통과**했다. 게이트를 검증하려던 실행이
## 게이트를 끄고 돌아간 것이다. 그래서 파서가 대시를 흡수하게 바꿨다.
func _read_int_arg(name: String, fallback: int, low := 0, high := 99999) -> int:
	for arg in OS.get_cmdline_user_args():
		var stripped := arg.lstrip("-")
		if stripped.begins_with(name + "="):
			return clampi(int(stripped.split("=")[1]), low, high)
	return fallback


func _process(_delta: float) -> void:
	if finished:
		return
	# _process 의 delta 는 Engine.time_scale 에 곱해져 들어온다. 실제 시계를 쓴다.
	if Time.get_ticks_msec() - started_at > TIMEOUT_MS:
		finished = true
		print("\n⏱️ 타임아웃 — %d/%d회차, %d라운드까지 진행" % [run_index + 1, runs, _round_index()])
		_report(false)
		Engine.time_scale = 1.0
		get_tree().quit(1)


func _round_index() -> int:
	return (game.defense_field.current_act - 1) * 20 + game.defense_field.current_wave


func _on_round_end(act: int, wave: int, _bonus: int) -> void:
	_log(act, wave)
	call_deferred("_play_policy")


func _on_act_end(act: int, _bonus: int) -> void:
	_log(act, 20)
	call_deferred("_advance_act", act)


func _on_game_over(victory: bool) -> void:
	if finished:
		return
	finished = true
	_log(game.defense_field.current_act, game.defense_field.current_wave)
	# 라운드 표·누출 표는 **첫 회차만** 인쇄한다 — 진단에는 한 벌이면 충분하고,
	# 3벌을 쏟으면 정작 봐야 할 요약이 로그 아래로 묻힌다.
	# (판정 기록은 `_report` 안의 `_evaluate_gate` 가 하므로 건너뛰어도 결과는 남는다)
	if run_index == 0:
		_report(victory)
	else:
		_evaluate_gate(victory, game.defense_field.max_base_hp)
	Engine.time_scale = 1.0
	if run_index + 1 < runs:
		run_index += 1
		call_deferred("_begin_run")
		return
	_summarize()
	# ⚠️ 게이트가 켜져 있으면 **판정은 중앙값**(`_summarize`)이 내린다. 마지막 회차의
	#    승패를 종료 코드에 쓰면, 중앙값이 밴드 안이어도 그 한 회차가 코드를 뒤집는다 —
	#    그게 바로 이 모드를 만든 이유다.
	if gate_enabled:
		get_tree().quit(1 if gate_failed else 0)
	else:
		get_tree().quit(0 if victory else 1)


func _advance_act(_act: int) -> void:
	if finished:
		return
	_play_policy()
	game._on_start_wave_pressed()


func _play_policy() -> void:
	# 봇이 **입력을 정하는 지점**에서 난수를 다시 고정한다. 게임 내부(지도 생성·크리티컬)가
	# 같은 흐름을 소비한 양이 매판 다르므로, 여기서 리셋해야 '봇이 받는 타일' 이 재현된다.
	# 라운드마다 다른 시드를 주는 이유: 같은 타일만 반복 수령하면 측정이 무의미해진다.
	if run_seed != 0:
		seed(run_seed + _round_index())
	_clear_modals()
	_take_reward()
	_buy_tiles()
	_shop_for_relics()
	_build_towers()


## 상인 상점을 열어 유물을 산다 (플레이어가 상단 [상인 모르그] 를 누르는 것과 같다).
##
## ⚠️ 상점은 게임이 자동으로 띄우지 않는다. `TowerDefenseMain._trigger_merchant_encounter`
## 는 정의만 되어 있고 게임 로직에서 호출되지 않는다(테스트에서만 부른다). 그래서
## 이걸 넣기 전까지 봇은 유물을 **평생 하나도 못 샀고**, 피해/공속 배수가 빠진 채로
## 난이도를 재고 있었다.
func _shop_for_relics() -> void:
	if game.defense_field.gold < RELIC_RESERVE:
		return
	game._open_relic_shop()
	_clear_modals()


## 모달을 치운다. 상인 상점이 떠 있으면 **닫기 전에 유물을 산다.**
## 그냥 닫아버리면 봇은 유물을 평생 하나도 못 사고, 실제 플레이어와 조건이 달라진다
## (유물은 피해 +20% / 공속 +20% 같은 배수라 난이도 판단이 통째로 어긋난다).
## 모달이 걸어 둔 트윈 람다가 살아 있는 채 사라지면 "Lambda capture was freed" 가 나므로
## queue_free 대신 모달 자신의 _close() 를 태운다.
func _clear_modals() -> void:
	for child in game.modal_layer.get_children():
		if child.has_method("_on_buy_relic_pressed") and child.has_method("_on_close_pressed"):
			_buy_relics(child)
			# 상점은 '영속 모달' 이다(shop_modal 을 재사용한다). queue_free 로 지우면
			# shop_modal 참조가 무효가 되고, queue_free 는 지연이라 곧바로 다시 열면
			# 아직 살아 있는 옛 모달을 잡아 화면에 안 뜬다. 모달의 닫기 경로를 태운다.
			child._on_close_pressed()
			continue
		if child.has_method("_close"):
			child._close()
		else:
			child.queue_free()


## 살 수 있는 유물을 살 수 있는 만큼 산다. 싼 것부터 사서 개수를 최대화한다.
func _buy_relics(shop) -> void:
	var bought_any := true
	while bought_any:
		bought_any = false
		var best := -1
		var best_cost := 1 << 30
		for i in range(shop.relic_stock.size()):
			var relic: Dictionary = shop.relic_stock[i]
			if bool(relic.get("sold", false)):
				continue
			var cost := int(relic["cost"])
			if cost <= shop.current_gold and cost < best_cost:
				best_cost = cost
				best = i
		if best >= 0:
			shop._on_buy_relic_pressed(best)
			relics_bought += 1
			relic_gold += best_cost
			bought_any = true


## 보상을 '받는' 것까지 해야 실제 플레이어와 조건이 맞는다.
## 모달만 닫으면 활자를 못 받아 실제보다 어렵게 측정된다.
func _take_reward() -> void:
	if game.jamo_belt.jamo_list.size() >= TILE_CAP:
		return
	var choices := HangulEngine.generate_reward_choices(1)
	if choices.is_empty():
		return
	game._on_wave_reward_chosen(str(choices[0]))
	rewards_taken += 1


func _buy_tiles() -> void:
	var belt = game.jamo_belt
	var field = game.defense_field
	# 방어선이 어느 정도 갖춰지면 유물 값을 남긴다.
	var reserve: int = buy_buffer
	if belt.jamo_list.size() >= RELIC_RESERVE_FROM_BELT:
		reserve = maxi(reserve, RELIC_RESERVE)
	while belt.jamo_list.size() < TILE_CAP:
		var price: int = belt.current_tile_price()
		if field.gold - reserve < price:
			break
		var before: int = field.gold
		# 실제 구매 경로를 그대로 탄다 (모음 즉시 구매).
		game._on_tile_purchase_requested(true)
		if before - field.gold <= 0:
			break
		bought += 1


## 벨트에서 가장 좋은 단어 3개를 골라 타워를 세운다.
##
## 슬롯 안의 활자 '순서' 가 파싱에 영향을 주므로, 단어별 활자를 앞쪽에 몰아 넣고
## 벨트 자체를 재배열한다 (플레이어가 드래그로 정렬하는 것과 같은 결과).
func _build_towers() -> void:
	var belt = game.jamo_belt
	var words = WordDatabase.get_all_words().filter(
		func(data): return str(data.get("word", "")).length() <= 3
	)
	var chosen: Array = AutoArrange.best_word_set_for(
		belt.jamo_list, words, mini(slot_limit, belt.unlocked_slot_count)
	)

	var pool: Array = belt.jamo_list.duplicate()
	var new_list: Array = []
	var new_assign: Array = []
	for slot in range(mini(slot_limit, belt.unlocked_slot_count)):
		if slot >= chosen.size():
			break
		var chars := _chars_for_word(str(chosen[slot].get("word", "")), pool)
		if chars.is_empty():
			continue
		for c in chars:
			new_list.append(c)
			new_assign.append(slot)
	for leftover in pool:
		new_list.append(leftover)
		new_assign.append(-1)

	belt.jamo_list.assign(new_list)
	belt.slot_assignments.assign(new_assign)
	belt.render_belt()

	# 어떤 단어를 세웠는지 남긴다. 결과를 해석할 때 이게 없으면 판단할 수 없다.
	var built: Array = []
	for i in range(mini(chosen.size(), mini(slot_limit, belt.unlocked_slot_count))):
		built.append(str(chosen[i].get("word", "")))
	last_towers = built


## 단어 하나를 만들 활자들을 벨트에서 집어 온다. 하나라도 못 구하면 빈 배열.
## 회전으로 맞출 수 있으면 맞춘다 (플레이어가 회전 버튼으로 공짜로 하는 것과 같다).
func _chars_for_word(word: String, pool: Array) -> Array:
	var trial: Array = pool.duplicate()
	var out: Array = []
	for syllable in AutoArrange.get_word_syllable_slots(word):
		for options in syllable:
			var found := ""
			for target in options:
				var at := _find_rotatable(trial, str(target))
				if at >= 0:
					trial.remove_at(at)
					found = str(target)
					break
			if found == "":
				return []          # 이 단어는 지금 벨트로 못 만든다
			out.append(found)
	# 성공이 확정된 뒤에만 실제 pool 을 소비한다.
	for c in out:
		var at := _find_rotatable(pool, c)
		if at >= 0:
			pool.remove_at(at)
	return out


## target 으로 회전시킬 수 있는 타일의 인덱스. 없으면 -1.
func _find_rotatable(pool: Array, target: String) -> int:
	for i in range(pool.size()):
		var tile: String = pool[i]
		for _turn in range(4):
			if tile == target:
				return i
			tile = HangulEngine.rotate(tile)
	return -1


func _log(act: int, wave: int) -> void:
	# 타워 누적 피해도 같이 찍는다. 라운드 간 차분이 곧 '그 라운드에 실제로 넣은 피해'다.
	# 필요 피해(웨이브 총 HP)보다 크면 딜 부족이 아니라 과잉/배분 문제다.
	var dealt := 0.0
	for tower_name in game.defense_field.tower_damage:
		dealt += float(game.defense_field.tower_damage[tower_name])
	# 타워가 '실제로 몇 번 쐈는지'. 피해량만 보면 딜이 약한 건지 안 쏘는 건지 갈리지 않는다.
	# (attack_count 는 타워가 재생성될 때 0 으로 돌아가므로 라운드 간 차분으로 읽는다)
	var shots := 0
	for tower in game.defense_field.active_towers:
		if is_instance_valid(tower):
			shots += int(tower.attack_count)
	round_log.append({
		"act": act,
		"wave": wave,
		"round": (act - 1) * 20 + wave,
		"hp": game.defense_field.base_hp,
		"towers": game.defense_field.active_towers.size(),
		"belt": game.jamo_belt.jamo_list.size(),
		"gold": game.defense_field.gold,
		"dealt": dealt,
		"shots": shots,
		"words": last_towers.duplicate(),
	})


func _report(victory: bool) -> void:
	var field = game.defense_field
	var max_hp: int = field.max_base_hp
	var lowest := max_hp
	var lowest_round := 0
	for entry in round_log:
		if int(entry["hp"]) < lowest:
			lowest = int(entry["hp"])
			lowest_round = int(entry["round"])

	print("\n=== 3막 완주 난이도 측정 (치트 없음, 타워 %d개, 골드 보유 %dG, 기지 HP %d) ===" % [slot_limit, buy_buffer, max_hp])
	print("결과: %s | 도달: %d막 %d라운드 | 기지 HP %d/%d" % [
		"클리어" if victory else "패배",
		field.current_act, field.current_wave, field.base_hp, max_hp
	])
	print("최저 기지 HP: %d/%d (%d라운드)" % [lowest, max_hp, lowest_round])
	print("잃은 HP: %d | 타일 구매 %d장 | 보상 활자 %d장 | 유물 %d개 (%dG)" % [
		max_hp - lowest, bought, rewards_taken, relics_bought, relic_gold
	])

	# 타워가 실제로 딜을 넣고 있는지. 이게 0 이면 난이도가 아니라 배치/공격 문제다.
	var total_damage := 0.0
	for tower_name in field.tower_damage:
		total_damage += float(field.tower_damage[tower_name])
	print("타워 누적 피해: %.0f | 타워별: %s" % [total_damage, str(field.damage_ranking())])

	print("\n라운드별 상태 (5라운드 간격):")
	for entry in _deduped_log():
		if int(entry["round"]) % 5 == 0:
			var words: Array = entry.get("words", [])
			print("  %2dR (%d막 %2d) | 기지 %2d/%d | 벨트 %2d장 | 골드 %4dG | 타워 %s" % [
				int(entry["round"]), int(entry["act"]), int(entry["wave"]),
				int(entry["hp"]), max_hp,
				int(entry["belt"]), int(entry["gold"]),
				"[" + ", ".join(words) + "]" if not words.is_empty() else "없음"
			])

	# 누출이 '어느 라운드'에서 나는지. 총량만 보면 어디를 손대야 할지 알 수 없다.
	# 웨이브 총 HP(필요 피해)와 나란히 놓아야 딜 부족인지 배치 문제인지 갈린다.
	print("\n누출 라운드 (기지 HP 가 줄어든 곳):")
	var prev_hp := max_hp
	var prev_dealt := 0.0
	for entry in _deduped_log():
		var hp := int(entry["hp"])
		var leaked := prev_hp - hp
		prev_hp = hp
		var dealt := float(entry.get("dealt", 0.0)) - prev_dealt
		prev_dealt = float(entry.get("dealt", 0.0))
		# 발사 수는 차분이 아니라 그 라운드의 값 자체다. 봇이 매 라운드 타워를 다시 세워서
		# attack_count 가 0 으로 돌아가므로, 차분으로 읽으면 음수가 나온다.
		# _log 는 웨이브가 끝난 직후(타워 재건설 전)에 찍히므로 이 값이 곧 그 라운드 발사 수다.
		var shots := int(entry.get("shots", 0))
		if leaked <= 0:
			continue
		var act := int(entry["act"])
		var wave := int(entry["wave"])
		print("  %2dR (%d막 %2d) | 누출 %d | 기지 %2d/%d | 필요 %4.0f | 피해 %4.0f (%3.0f%%) | 발사 %3d | 타워 %s" % [
			int(entry["round"]), act, wave, leaked, hp, max_hp, _wave_hp(act, wave), dealt,
			(100.0 * dealt / maxf(1.0, _wave_hp(act, wave))), shots,
			"[" + ", ".join(entry.get("words", [])) + "]"
		])

	_evaluate_gate(victory, max_hp)


## 한 회차의 밴드를 재서 **기록**하고 한 줄로 인쇄한다. 합격/불합격은 `_summarize()` 가
## 회차 전체의 **중앙값**으로 내린다 — 단일 회차의 통과/위반은 판정이 아니다(헤더 ⚠️).
## 게이트를 켜지 않으면 아무것도 주장하지 않는다 (기존 동작 보존).
##
## 분모는 **현재 max_hp 가 아니라 고정 기준값**이다. `철옹성 룬`(+10 최대 HP) 같은
## 유물이 max_hp 를 부풀리는데, 그걸 분모로 쓰면 같은 절대 손실이 매번 더 '여유 있는
## 클리어' 로 계산된다. 실측 예: 기준 50 에 30 남음(=60%)인데 최대 HP 가 70 이면 43%
## 가 되어, 게이트가 유물 구매만으로 조용히 느슨해진다.
func _evaluate_gate(victory: bool, max_hp: int) -> void:
	var field = game.defense_field
	var reached := _round_index()
	var reference: int = start_hp if start_hp > 0 else DefenseField.MAX_BASE_HP
	var hp_ratio := 0.0 if reference <= 0 else float(field.base_hp) / float(reference)
	var reason := ""
	if reached < GATE_MIN_ROUND:
		reason = "하한 위반: %d라운드에서 끝났다 (최소 %d라운드 필요) — 게임이 너무 어려워졌다" % [
			reached, GATE_MIN_ROUND]
	elif victory and hp_ratio > GATE_MAX_HP_RATIO:
		reason = "상한 위반: %d라운드를 남은 HP %.0f%% 로 클리어했다 (<= %.0f%% 필요) — 게임이 너무 쉬워졌다" % [
			reached, hp_ratio * 100.0, GATE_MAX_HP_RATIO * 100.0]
	run_results.append({
		"victory": victory, "hp": field.base_hp, "reference": reference,
		"ratio": hp_ratio, "reached": reached, "ok": reason == "", "reason": reason,
	})
	# gate=0 이면 '측정만 한다' 는 계약이 있으므로 판정 문구를 붙이지 않는다.
	var verdict := ""
	if not gate_enabled:
		verdict = "게이트 꺼짐 — 판정하지 않음"
	elif reason != "":
		verdict = "✗ " + reason
	elif victory:
		verdict = "✓ 밴드 안"
	else:
		# ⚠️ 패배는 **상한 판정 대상이 아니다**(남은 HP 가 0 이라 비율이 의미 없다). 하한은
		#    넘겼으므로 위반도 아니다. 그렇다고 '✓ 밴드 안' 을 찍으면 **죽은 회차를 통과로
		#    읽게 된다** — 실측(2026-10-03, runs=3)에서 실제로 그렇게 찍혔다.
		verdict = "— 패배(하한 %dR 는 넘김 · 상한 판정 대상 아님)" % GATE_MIN_ROUND
	print("  %d/%d회차 | %s | 도달 %dR | 기지 %d/%d (남은 %.0f%%) | %s" % [
		run_index + 1, runs, "클리어" if victory else "패배", reached,
		field.base_hp, max_hp, hp_ratio * 100.0, verdict])


## 회차 전체를 요약하고 **중앙값**으로 판정한다.
##
## 왜 중앙값인가: 같은 시드 7회가 60~120% 로 흩어졌다. 한 회차의 통과는 '쉽지 않다' 의
## 근거가 못 되고, 한 회차의 위반도 '어렵다' 의 근거가 못 된다. 분포의 가운데를 본다.
##
## ⚠️ **상한(너무 쉬움)은 '클리어한 회차' 만으로 잰다.** 패배한 회차의 남은 HP 는 0 에
##    가까워서, 그걸 섞으면 **패배가 '어렵다' 가 아니라 '적당하다' 로 계산된다.**
##    하한(너무 어려움)은 도달 라운드의 중앙값으로 따로 본다.
func _summarize() -> void:
	if run_results.is_empty():
		return
	var ratios: Array = []
	var reached_all: Array = []
	var cleared := 0
	var violations := 0
	for r in run_results:
		reached_all.append(float(r["reached"]))
		if not bool(r["ok"]):
			violations += 1
		if bool(r["victory"]):
			cleared += 1
			ratios.append(float(r["ratio"]))
	ratios.sort()
	reached_all.sort()
	var mid_reached: int = int(reached_all[reached_all.size() / 2])
	var mid_ratio: float = 0.0 if ratios.is_empty() else float(ratios[ratios.size() / 2])

	print("\n=== 난이도 게이트 요약 — %d회차 (하한 %dR, 클리어 시 남은 HP <= %.0f%%) ===" % [
		run_results.size(), GATE_MIN_ROUND, GATE_MAX_HP_RATIO * 100.0])
	print("  클리어 %d/%d회차 · 도달 라운드 중앙값 %dR · 위반 %d회차" % [
		cleared, run_results.size(), mid_reached, violations])
	if not ratios.is_empty():
		var labels: Array = []
		for v in ratios:
			labels.append("%.0f%%" % (float(v) * 100.0))
		print("  클리어한 회차의 남은 HP: %s (중앙값 %.0f%%)" % [
			", ".join(labels), mid_ratio * 100.0])
	if not gate_enabled:
		print("  (gate=0 — 측정만 하고 아무것도 주장하지 않는다)")
		return
	if mid_reached < GATE_MIN_ROUND:
		gate_failed = true
		print("  ✗ 하한 위반: 도달 라운드 중앙값이 %dR (최소 %dR 필요) — 게임이 너무 어려워졌다." % [
			mid_reached, GATE_MIN_ROUND])
	elif ratios.is_empty():
		gate_failed = true
		print("  ✗ 클리어한 회차가 없다 — 게임이 너무 어려워졌다.")
	elif mid_ratio > GATE_MAX_HP_RATIO:
		gate_failed = true
		print("  ✗ 상한 위반: 남은 HP 중앙값 %.0f%% (<= %.0f%% 필요) — 게임이 너무 쉬워졌다." % [
			mid_ratio * 100.0, GATE_MAX_HP_RATIO * 100.0])
	elif violations > 0:
		# 중앙값은 밴드 안인데 일부 회차가 위반. **실패로 만들지 않는다** — 흔들림이 크다는
		# 신호일 뿐이고, 그걸 실패로 처리하면 정상적인 흩어짐이 게이트를 영구히 빨갛게 만든다.
		print("  ✓ 중앙값은 밴드 안. ⚠️ 다만 %d회차가 위반 — 흩어짐이 크다(회차를 늘려 볼 것)." % violations)
	else:
		print("  ✓ 밴드 안: 클리어한 %d회차의 남은 HP 중앙값 %.0f%% · 위반 0회차." % [
			cleared, mid_ratio * 100.0])


## 한 웨이브의 총 HP (= 그 라운드를 통과하려면 넣어야 하는 총 피해).
## field 가 untyped 라 `field.hp_compensation_for()` 의 반환형이 Variant 다.
## `:=` 로 받으면 "Cannot infer the type" 파싱 에러가 나고, **스크립트가 로드되지 않아
## 씬이 quit() 에 도달하지 못한 채 영원히 멈춘다** (실측: 7분 넘게 행).
## 반드시 타입을 명시할 것.
func _wave_hp(act: int, wave: int) -> float:
	var field = game.defense_field
	var base: float = (10.0 + act * 4.0) * field.hp_compensation_for(act, wave)
	# ⚠️ 난이도 곡선을 **빠뜨리면 안 된다.** 안 곱하면 이 도구의 '필요 피해' 열이 실제
	#    웨이브 총 HP 보다 낮게 나오고, 그러면 *'딜 부족인지 배치 문제인지'* 를 가르려던
	#    이 표가 조용히 거짓말한다. 곡선은 `DefenseField` 가 소유한다 — 여기서 다시 적지 않는다.
	var ws := (1.0 + (wave - 1) * 0.08) * float(field.wave_curve_for(wave))
	var asc := 1.0 + (act - 1) * 0.5
	var n: float = base * ws * asc
	var need: float = 0.0
	# ⚠️ **타입 배수를 손으로 적지 않는다.** 예전에는 `[n, n*0.7, n*1.5+n*0.8, n*0.5][i % 4]`
	#    였는데, 그건 1막 로스터 순서(normal·fast·armored·swarm)에 맞춘 사본이었다.
	#    2막은 `armored·swarm·fast·normal·normal`, 3막은 `fast·normal·swarm·armored` 라서
	#    **이 열이 2·3막에서 조용히 틀렸다**(실측 오차 −8.6%~+2.2%). 로스터가 같은 타입
	#    *조합* 의 순열이라 오차가 작았을 뿐이다 — 구성을 바꾸면 크게 어긋난다.
	#    `MonsterRoster` 를 그대로 읽으면 로스터를 고쳐도 이 열이 따라온다(§2.18 과 같은 처방).
	var roster: Array = MonsterRoster.entries_for(act)
	for i in range(field.enemy_count_for(act, wave)):
		var entry: Dictionary = roster[i % roster.size()]
		var stats: Dictionary = MonsterRoster.TYPE_STATS[str(entry["type"])]
		need += n * (float(stats["hp"]) + float(stats["shield"]))
	if wave % 5 == 0:
		need += base * 8.0 * ws * asc
	return need


## 같은 라운드가 두 번 기록될 수 있다(막 클리어와 웨이브 클리어 경로).
## 라운드 기준 중복 제거 + 시간순 정렬.
func _deduped_log() -> Array:
	var by_round := {}
	for entry in round_log:
		by_round[int(entry["round"])] = entry
	var rounds := by_round.keys()
	rounds.sort()
	var out: Array = []
	for r in rounds:
		out.append(by_round[r])
	return out
