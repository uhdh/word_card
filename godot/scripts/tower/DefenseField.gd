# DefenseField.gd
# 타워 디펜스 맵 필드, 적 이동 경로(Path2D), 타워 슬롯 및 20라운드 관리
class_name DefenseField
extends Control

const Palette = preload("res://scripts/ui/Palette.gd")
const Juice = preload("res://scripts/ui/Juice.gd")

signal base_hp_changed(current: int, max: int)
signal enemy_count_changed(current: int)
signal gold_changed(current: int)
signal wave_status_changed(act: int, max_act: int, wave: int, max_wave: int, is_running: bool)
signal wave_cleared(act: int, wave: int, bonus_gold: int)
signal act_cleared(act: int, bonus_gold: int)
signal tower_info_requested(tower: WordTower)
signal game_over(is_victory: bool)
signal tower_positions_changed()

## 기지가 버틸 수 있는 '적 통과' 횟수. 적이 기지에 닿을 때마다 1씩 줄고 0 이 되면 패배한다.
##
## 왜 50 인가 — 실측(tools/DifficultyPlaytest)에서 누출 속도가 라운드당 1.2~1.7마리였다.
## 20 이면 60라운드 예산이 라운드당 0.33마리라 구조적으로 완주가 불가능했다
## (HP 를 60으로 올려도 36라운드에서 끝났다 — 누출 속도는 HP 와 무관하게 일정하다).
## 50 이면 라운드당 0.83마리까지 허용된다.
##
## 참고: `MAX_ENEMIES`(50) 는 '동시 생존 적 수' 안전밸브이고 이 값과 무관하다.
## 그쪽은 웨이브당 13~17마리 × 경로 통과 시간 때문에 실제로는 26~34마리까지만 차서
## 패배 조건으로 쓸 수 없다(과거 `loop = true` 버그로 적이 무한 누적될 때만 발동했다).
const MAX_BASE_HP: int = 50
@export var max_base_hp: int = MAX_BASE_HP
var base_hp: int = MAX_BASE_HP
## 왜 졌는가 — `"overload"`(안전밸브 초과) 또는 `"breach"`(기지 함락).
##
## 두 패배는 원인이 전혀 다른데 `game_over(false)` 하나로 나간다. 결과 화면이 문구를
## 하나만 쓰면, 적 50마리 과부하로 끝난 런도 "활자의 빛이 꺼졌습니다…" 로만 보인다 —
## 그 경우 기지 HP 는 가득 차 있을 수 있어서, 플레이어가 화면 어디에서도 이유를 찾을 수 없다.
var last_defeat_reason: String = ""
var gold: int = 40

var current_act: int = 1
const MAX_ACTS: int = 3

var current_wave: int = 0
const MAX_WAVES_PER_ACT: int = 20
const SPAWN_INTERVAL := 0.8
const ROUND_INTERVAL := 15.0
const PLANNING_INTERVAL := 3.0
const BOSS_ROUND_INTERVAL: int = 5
const MAX_ENEMIES: int = 50

var is_wave_running: bool = false
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var round_timer: float = 0.0
var planning_timer: float = 0.0
var is_planning_phase := false

## 보스 배너의 y 위치. 체력바 아래에 두어야 약점 문구가 가려지지 않는다.
##
## ⚠️ **§5.2 28 (A), 2026-10-01 — 54 → 80 으로 내렸다.** 체력바에 '약점' 행이 하나 늘어
##    (2행 → 3행) 높이가 약 67px 가 됐기 때문이다. 54 로 두면 배너가 체력바 **위에 겹쳐**
##    정작 약점 문구가 가려진다 — 고치려던 것을 고치면서 가리는 셈이 된다.
##    실측은 `tools/BossWeaknessProbe.gd` §6 이 한다(겹침도 함께 단언한다).
const BOSS_BANNER_TOP: float = 80.0
## 보스 체력바의 y 위치.
const BOSS_BAR_TOP: float = 2.0
## 현재 표시 중인 보스 체력바와 그 대상. 보스가 죽으면 자동으로 치운다.
var _boss_bar: Control = null
var _boss_target: EnemyUnit = null

@onready var path_2d: Path2D = $Path2D
@onready var tower_slots_container: Node2D = $TowerSlots
@onready var projectiles_layer: Node2D = $ProjectilesLayer
@onready var background: TextureRect = $Background
@onready var road_glow: Line2D = $RoadGlow
@onready var road_dash: Line2D = $RoadDash

var enemy_unit_scene = preload("res://scenes/tower/EnemyUnit.tscn")
var word_tower_scene = preload("res://scenes/tower/WordTower.tscn")

var tower_slots: Array[Node2D] = []
var active_towers: Array[WordTower] = []
var first_magic_circle_pending := true
var relic_ids: Array = []
var tower_damage: Dictionary = {}
## 슬롯(논리 인덱스) → 선회 방향(bool, true = 시계 방향).
##
## 타워 노드가 아니라 슬롯이 기억한다. 자모를 고치면 update_towers_from_parsed_list 가
## 타워를 통째로 다시 세우기 때문에, 타워에만 담아 두면 방향 선택이 매번 사라진다.
## (조준 우선순위 target_modes 도 같은 이유·같은 방식이다)
##
## 키는 처음부터 '문자열' 로 쓴다. 세이브는 JSON 이고, JSON 은 정수 키를 문자열로
## 바꿔 버린다 — 정수로 넣으면 불러온 뒤 has(0) 이 false 가 되어 조용히 사라진다.
var orbit_directions: Dictionary = {}
## 슬롯별 조준 우선순위. 키 규칙은 orbit_directions 와 같다(문자열).
var target_modes: Dictionary = {}
var tower_positions: Array[int] = [0, 1, 2]

const MAX_UNLOCKED_SLOTS: int = 3
## 밀어내기가 경로 길이의 몇 %를 되돌리는가.
## 비율인 이유: 경로 길이는 막마다 다르다. 고정 픽셀로 밀면 1막에서는 크게,
## 3막에서는 거의 안 보인다.
const PUSH_BACK_RATIO: float = 0.10
var unlocked_slot_count: int = 3

## 무받침 풍경이 인접한 무받침 타워 **양쪽**에 올리는 공격속도 증가율(%).
## 상점 설명 "양쪽 공격속도 +12%" 와 같은 숫자다. 공격속도는 '초당 공격 횟수' 이므로
## 간격에는 역수를 곱한다 — `interval *= 0.88` 은 +13.6% 이지 +12% 가 아니다.
const OPEN_CHIME_SPEED_PCT := 12

## 천리안의 룬이 모든 타워의 사거리에 올리는 증가율(%). 상점 설명 "공격 범위 +15%" 와 같다.
## ⚠️ 배수를 `1.15` 로 직접 적지 않는다 — 라벨이 `int((MULT - 1.0) * 100.0)` 로 퍼센트를
## 만들면 `(1.15 - 1.0) * 100.0 = 14.999…` 이고 `int()` 가 **14 로 잘라** 라벨이 상점과
## 갈라졌다(2026-10-05 까지 `+14%` 로 표시됐다). 퍼센트를 상수로 두면 `int()` 를 아예
## 쓰지 않는다 — `OPEN_CHIME_SPEED_PCT` 와 같은 방식이고, `1.0 + 15/100.0` 은 `1.15` 와
## **비트 단위로 같다**(밸런스 변화 0).
const RANGE_RUNE_RANGE_PCT := 15
const RANGE_RUNE_RANGE_MULT := 1.0 + RANGE_RUNE_RANGE_PCT / 100.0

## **슬롯(배열) 순서**로 인접한 `defense`+`heal` 짝이 라운드마다 올리는 기지 HP.
##
## ⚠️ 이 효과는 **툴팁에 반드시 나와야 한다.** `GAME_DESIGN.md` §4 가
## *"적용된 시너지는 타워 툴팁에 전부 나열된다 — 숨은 보너스는 없다"* 고 계약하는데,
## 이 절만 `synergy_labels` 를 안 건드려서 **일어나는지조차 알 수 없었다**(§2.45).
const HP_SYNERGY_LABEL := "생명의 순환 (라운드마다 +1 HP)"

func has_relic(id: String) -> bool:
	return id in relic_ids

func record_tower_damage(tower_name: String, amount: float) -> void:
	tower_damage[tower_name] = float(tower_damage.get(tower_name, 0.0)) + amount

func damage_ranking() -> Array:
	var ranking := []
	for tower_name in tower_damage:
		ranking.append({"tower": tower_name, "damage": float(tower_damage[tower_name])})
	ranking.sort_custom(func(a, b): return a.damage > b.damage)
	return ranking

## 전체 누적 피해의 합.
func total_tower_damage() -> float:
	var total := 0.0
	for key in tower_damage:
		total += float(tower_damage[key])
	return total


## 타워 하나가 런 전체에서 차지하는 몫.
##
## tower_damage 는 처음부터 쌓이고 있었는데, 화면에는 **게임오버 요약에서만**
## 나왔다. 그래서 플레이 중에는 "지금 어느 단어가 실제로 일하고 있는가" 를
## 알 방법이 없었고, 다음 골드를 어디에 넣을지가 감이 됐다.
## (강화 대상을 고르는 것이 이 게임의 핵심 결정인데, 그 근거가 안 보였다)
##
## 정보창은 그 타워를 눌러서 여는 화면이라 시점도 맞는다 — 결정 직전에 근거가 뜬다.
## damage 가 0 이라는 것도 정보다: 아직 한 발도 못 맞춘 타워는 사거리 밖일 가능성이 크다.
func tower_damage_share(tower_name: String) -> Dictionary:
	var mine := float(tower_damage.get(tower_name, 0.0))
	var total := total_tower_damage()
	var rank := 1
	for key in tower_damage:
		if float(tower_damage[key]) > mine:
			rank += 1
	return {"damage": mine, "total": total, "rank": rank, "count": tower_damage.size()}

## 경로를 촘촘한 점열로 펴고 각 점의 누적 길이를 함께 돌려준다.
## 발판 커버리지는 '사거리 원 안에 들어오는 경로 길이' 로 재야 한다. 점 몇 개로 재면
## 곡선 구간을 놓쳐 값이 튄다. ACT_PATHS 를 직접 쓰는 이유는 _layout_sanctuary 가
## 실제로 걷는 경로와 같은 원본을 봐야 값이 어긋나지 않기 때문이다.
func _densified_path(act: int) -> Dictionary:
	var points: Array = ACT_PATHS.get(act, ACT_PATHS[1])
	var pts: Array = []
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := maxi(1, int(a.distance_to(b)))
		for k in range(steps):
			pts.append(a.lerp(b, float(k) / float(steps)))
	if points.size() > 0:
		pts.append(points[points.size() - 1])
	var cum: Array = []
	if pts.is_empty():
		return {"pts": pts, "cum": cum}
	cum.append(0.0)
	for i in range(1, pts.size()):
		cum.append(float(cum[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
	return {"pts": pts, "cum": cum}


## 발판 하나가 덮는 경로 길이(px). 사거리 원 안에 들어오는 경로 구간 길이의 합이다.
func pad_coverage(act: int, pad_index: int, range_px: float) -> float:
	var slots: Array = ACT_SLOTS.get(act, ACT_SLOTS[1])
	if pad_index < 0 or pad_index >= slots.size():
		return 0.0
	var path_data := _densified_path(act)
	var pts: Array = path_data["pts"]
	var cum: Array = path_data["cum"]
	if pts.is_empty():
		return 0.0
	var center: Vector2 = slots[pad_index]
	var total := 0.0
	var run_start := -1
	for i in range(pts.size()):
		if center.distance_to(pts[i]) <= range_px:
			if run_start < 0:
				run_start = i
		elif run_start >= 0:
			total += float(cum[i - 1]) - float(cum[run_start])
			run_start = -1
	if run_start >= 0:
		total += float(cum[pts.size() - 1]) - float(cum[run_start])
	return total


## 주어진 발판들이 '함께' 덮는 경로 길이(합집합). 겹치는 구간은 한 번만 센다.
func covered_path_length(act: int, pads: Array, range_px: float) -> float:
	var path_data := _densified_path(act)
	var pts: Array = path_data["pts"]
	var cum: Array = path_data["cum"]
	if pts.is_empty():
		return 0.0
	var slots: Array = ACT_SLOTS.get(act, ACT_SLOTS[1])
	var inside: Array = []
	inside.resize(pts.size())
	inside.fill(false)
	for pad in pads:
		var index := int(pad)
		if index < 0 or index >= slots.size():
			continue
		var center: Vector2 = slots[index]
		for i in range(pts.size()):
			if center.distance_to(pts[i]) <= range_px:
				inside[i] = true
	var total := 0.0
	var run_start := -1
	for i in range(pts.size()):
		if inside[i]:
			if run_start < 0:
				run_start = i
		elif run_start >= 0:
			total += float(cum[i - 1]) - float(cum[run_start])
			run_start = -1
	if run_start >= 0:
		total += float(cum[pts.size() - 1]) - float(cum[run_start])
	return total


## 그 막 경로의 총 길이(px).
func path_length(act: int) -> float:
	var cum: Array = _densified_path(act)["cum"]
	return float(cum[cum.size() - 1]) if not cum.is_empty() else 0.0


## 기본 타워 배치를 고른다.
##
## [0, 1, 2] 로 고정하면 안 된다 — 실측(사거리 150px, 합집합 커버리지):
##   1막: 기본 414px / 경로 1318px = 31.4%  vs 최적 [1,3,8]  1119px = 84.9%
##   2막: 기본 474px / 경로 1206px = 39.3%  vs 최적 [1,5,10] 1116px = 92.5%
##   3막: 기본 412px / 경로  955px = 43.1%  vs 최적 [2,6,9]   841px = 88.1%
## 즉 기본값이 경로의 3~4할만 덮었다. 예전 1막 pad 2 는 경로에서 148px 떨어져
## 사거리에 겨우 걸려 커버가 43px(3.2%) 뿐이었다 — 타워 하나가 사실상 놀았다.
##
## 개별 커버리지 상위 3개를 뽑으면 서로 겹치는 발판만 나온다(3막에서 실제로 그랬다).
## 그래서 '합집합 커버리지' 를 목적함수로 둔다.
##
## ── 반환값은 '집합' 이 아니라 '수열' 이다 ──────────────────────────────────
## 플레이어는 타워를 하나씩 짓고, k 번째 타워는 positions[k-1] 발판에 놓인다.
## 그래서 합집합만 최대화하면 첫 자리가 나쁜 발판이 될 수 있다. 실측 1막:
##   합집합 최적 집합 [1,3,8] (1130.8px) 의 첫 자리 pad1 = 단독 354.9px → 1라운드 1마리 누출
##   그리디가 고른 [5,1,8] (1116.9px) 의 첫 자리 pad5 = 단독 461.7px → 누출 0
## 합집합 차이는 13.9px(1.2%) 뿐인데 체감은 정반대였다. 커버리지 총량은 '누출 없음' 의
## 좋은 대리 지표가 아니다 — 적이 죽는 '시점' 이 더 중요하기 때문이다.
##
## 그래서 순열 전수조사로 (합집합, 접두사 커버리지들) 을 함께 모으고,
## 합집합이 최대에서 PLACEMENT_COVERAGE_EPSILON 이내인 배치 중에서
## '앞 자리가 가장 강한' 수열을 고른다 (첫 타워 → 둘째 타워 순으로 사전식 비교).
## 3막은 그리디가 합집합에서 7.6% 뒤지므로 이 문턱을 넘지 못하고,
## 합집합 최적이 그대로 유지된다 — 막별로 알아서 알맞은 쪽이 뽑힌다.
func default_tower_positions(act: int, count: int, range_px: float) -> Array[int]:
	var slots: Array = ACT_SLOTS.get(act, ACT_SLOTS[1])
	if slots.is_empty():
		return []
	var want := mini(count, slots.size())
	if want > 0 and slots.size() <= BRUTE_FORCE_SLOT_LIMIT and want <= 3:
		return _best_position_sequence(act, want, range_px)
	# 슬롯이 아주 많아지면(맵 확장 등) 전수조사가 비싸진다 → 그리디로 물러선다.
	var chosen: Array[int] = []
	for _n in range(want):
		var best_index := -1
		var best_total := -1.0
		for pad in range(slots.size()):
			if chosen.has(pad):
				continue
			var trial: Array = []
			trial.assign(chosen)
			trial.append(pad)
			var total := covered_path_length(act, trial, range_px)
			if total > best_total:
				best_total = total
				best_index = pad
		if best_index < 0:
			break
		chosen.append(best_index)
	return chosen


## 전수조사 상한. 순열 11P3 = 990 이면 충분히 싸다.
const BRUTE_FORCE_SLOT_LIMIT: int = 16

## 합집합 커버리지가 '사실상 같은' 배치로 볼 허용 오차(비율).
## 이 안에서는 첫 타워가 가장 강한 자리를 고른다. 1.5% 로 잡은 이유:
## 1막에서 최적 집합과 그리디 집합의 합집합 차이가 13.9px = 1.2% 였는데
## 1라운드 누출이 1 ↔ 0 으로 갈렸다. 반대로 3막은 그리디가 7.6% 뒤져서
## 이 문턱을 넘지 못한다 — 그래서 3막은 합집합 최적이 그대로 유지된다.
const PLACEMENT_COVERAGE_EPSILON: float = 0.015


## count 개 발판을 '순서까지' 전수조사한다.
##
## 1단계: 집합 전수조사(C(11,3)=165)로 합집합 커버리지의 최대값을 찾는다.
##        합집합은 순서와 무관하므로 순열(990)을 다 돌 필요가 없다.
## 2단계: 최대값에서 PLACEMENT_COVERAGE_EPSILON 이내인 '동급' 집합들만 골라,
##        각 집합을 '앞 자리가 가장 강한' 순서로 정렬한 뒤 사전식으로 최선을 고른다.
##        (같은 집합의 최적 순서는 남은 발판 중 합집합을 가장 많이 늘리는 것을
##         앞에 놓는 그리디로 얻는다 — 사전식 비교에서는 이게 최적이다)
## 실측 소요: 집합만 훑는 990순열 방식이 막당 254~343ms 였는데 이 방식은 그 1/6 이다.
func _best_position_sequence(act: int, count: int, range_px: float) -> Array[int]:
	var slots: Array = ACT_SLOTS.get(act, ACT_SLOTS[1])
	var slot_count := slots.size()
	if count <= 0 or slot_count < count:
		return []
	var sets: Array = []
	var best_union := -1.0
	var combo: Array[int] = []
	for i in range(count):
		combo.append(i)
	while true:
		var total := covered_path_length(act, combo, range_px)
		if total > best_union:
			best_union = total
		sets.append({"pads": combo.duplicate(), "union": total})
		# 다음 조합으로 (사전순 증가)
		var cursor := count - 1
		while cursor >= 0 and combo[cursor] == slot_count - count + cursor:
			cursor -= 1
		if cursor < 0:
			break
		combo[cursor] += 1
		for j in range(cursor + 1, count):
			combo[j] = combo[j - 1] + 1
	var floor := best_union * (1.0 - PLACEMENT_COVERAGE_EPSILON)
	var best_seq: Array[int] = []
	var best_prefix: Array = []
	for entry in sets:
		if float(entry["union"]) < floor:
			continue
		var ordered := _strongest_prefix_order(act, entry["pads"], range_px)
		if best_seq.is_empty() or _prefix_beats(ordered["prefix"], best_prefix):
			best_seq = ordered["seq"]
			best_prefix = ordered["prefix"]
	return best_seq


## 집합 하나를 '앞 자리부터 가장 강한' 순서로 정렬한다.
## 남은 발판 중 '지금까지 고른 것과 합쳤을 때 커버리지가 가장 큰' 것을 앞에 놓는다.
func _strongest_prefix_order(act: int, pads: Array, range_px: float) -> Dictionary:
	var remaining: Array = pads.duplicate()
	var seq: Array[int] = []
	var prefix: Array = []
	while not remaining.is_empty():
		var best_pad := -1
		var best_total := -1.0
		for pad in remaining:
			var trial: Array = []
			trial.assign(seq)
			trial.append(pad)
			var total := covered_path_length(act, trial, range_px)
			if total > best_total:
				best_total = total
				best_pad = int(pad)
		seq.append(best_pad)
		prefix.append(best_total)
		remaining.erase(best_pad)
	return {"seq": seq, "prefix": prefix}


## 접두사 커버리지 배열을 사전식으로 비교한다 — 앞 자리부터 강한 쪽이 이긴다.
func _prefix_beats(a: Array, b: Array) -> bool:
	for i in range(mini(a.size(), b.size())):
		if not is_equal_approx(float(a[i]), float(b[i])):
			return float(a[i]) > float(b[i])
	return false


## 기본 배치를 잡아 둔 막. 막이 바뀌면 배치를 다시 계산해야 한다.
## set_act 안에서 '바뀌었나' 를 판단할 수 없어서(호출 전에 current_act 가 이미 새 값이다)
## 마지막으로 배치를 계산한 막을 따로 기억한다.
var _pad_layout_act: int = 0


## 현재 막의 기본 배치를 적용한다.
func apply_default_tower_positions() -> void:
	var picked := default_tower_positions(current_act, MAX_UNLOCKED_SLOTS, WordTower.BASE_ATTACK_RANGE)
	if picked.is_empty():
		return
	tower_positions.assign(picked)
	_pad_layout_act = current_act


## 타워를 현재 tower_positions 가 가리키는 발판으로 다시 옮긴다 (재생성 없이).
func _refresh_tower_pads() -> void:
	for tower in active_towers:
		if not is_instance_valid(tower):
			continue
		var logical: int = tower.logical_slot_index
		if logical < 0 or logical >= tower_positions.size():
			continue
		var pad: int = tower_positions[logical]
		if pad < 0 or pad >= tower_slots.size():
			continue
		if tower.get_parent() != tower_slots[pad]:
			tower.reparent(tower_slots[pad])
			tower.position = Vector2.ZERO


func restore_tower_positions(saved: Array) -> void:
	apply_default_tower_positions()
	var slot_count: int = (ACT_SLOTS.get(current_act, ACT_SLOTS[1]) as Array).size()
	for i in range(mini(saved.size(), tower_positions.size())):
		var position_index := int(saved[i])
		if position_index >= 0 and position_index < slot_count and not tower_positions.slice(0, i).has(position_index):
			tower_positions[i] = position_index

func move_tower_to_nearest(logical_slot: int, global_drop_position: Vector2) -> bool:
	if logical_slot < 0 or logical_slot >= tower_positions.size(): return false
	var target_position := 0
	var nearest_distance := INF
	for i in range(tower_slots.size()):
		var distance := tower_slots[i].global_position.distance_squared_to(global_drop_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target_position = i
	return move_tower(logical_slot, target_position)

func move_tower(logical_slot: int, target_position: int) -> bool:
	# 웨이브 중에도 재배치를 허용한다. 예전에는 라운드 사이(정확히는 15초마다
	# 잠깐 열리는 planning 구간)에만 움직일 수 있어서 "타워 이동이 안 된다"고
	# 느껴졌다. 현대 TD 처럼 언제든 자리를 바꿀 수 있게 한다.
	if logical_slot < 0 or logical_slot >= tower_positions.size() or target_position < 0 or target_position >= tower_slots.size(): return false
	var old_position := tower_positions[logical_slot]
	var other_logical := tower_positions.find(target_position)
	tower_positions[logical_slot] = target_position
	if other_logical >= 0: tower_positions[other_logical] = old_position
	for tower in active_towers:
		if tower.logical_slot_index == logical_slot:
			tower.reparent(tower_slots[target_position])
			tower.position = Vector2.ZERO
		elif tower.logical_slot_index == other_logical:
			tower.reparent(tower_slots[old_position])
			tower.position = Vector2.ZERO
	tower_positions_changed.emit()
	call_deferred("refresh_tower_synergies")
	return true

func refresh_tower_synergies() -> void:
	var parsed: Array = [{}, {}, {}]
	for tower in active_towers:
		if is_instance_valid(tower) and tower.logical_slot_index >= 0:
			parsed[tower.logical_slot_index] = {"syllable": tower.syllable, "word_data": tower.word_data}
	update_towers_from_parsed_list(parsed)

## 다음 라운드가 **어느 막**인가.
##
## ⚠️ `next_round_preview()` 와 `next_round_attr_desc()` 가 **같은 답을 써야** 한다.
##    막 판정을 두 곳에 적으면 §2.18 이 지적한 드리프트(문구가 표와 조용히 어긋남)가
##    여기서도 생긴다 — 예고는 2막이라는데 속성 설명은 1막 것을 보여주는 식으로.
func next_round_act() -> int:
	if current_wave >= MAX_WAVES_PER_ACT and current_act < MAX_ACTS:
		return current_act + 1
	return current_act


## 다음 라운드에 등장하는 속성들의 **설명**. §5.2 31 (B) — `ATTR_INFO.desc` 의 유일한 출구다.
func next_round_attr_desc() -> String:
	return MonsterRoster.attr_desc_text(next_round_act())


## 예고 문구. `compact=true` 면 **바에 들어가는 형태**를 돌려준다(§2.13-2).
##
## ⚠️ 왜 두 함수가 아니라 인자인가: 예고를 조립하는 곳이 둘이 되면 한쪽만 고쳐도
##    조용히 갈라진다(§2.18 드리프트와 같은 뿌리). **작성자는 여기 하나다.**
##
## ⚠️ `compact` 가 필요한 이유(실측 2026-10-03, `tools/TelegraphOptionMeasure.tscn`):
##    바의 라벨은 `clip_text = true` 이고 폭이 **1104 px** 뿐인데 상성 절은 **혼자서
##    1322 px** 다 — 도달 가능한 60개 문구가 **전부** 잘린다(최장 2막 10R = 1777 px).
##    로스터만 남기면 최장 **475 px**(여유 629 px)라 전부 들어간다.
## ⚠️ **정보를 지우지 않는다** — 전체 문구는 `btn_stage` 툴팁(`_refresh_stage_tooltip`)과
##    라운드 정보 모달(`_on_stage_btn_pressed`)에 그대로 남는다. 바는 '무엇이 오는가' 를,
##    나머지 둘은 '무엇으로 잡는가' 를 맡는다.
func next_round_preview(compact := false) -> String:
	var next_wave := mini(current_wave + 1, MAX_WAVES_PER_ACT)
	var next_act := next_round_act()
	if next_act != current_act:
		next_wave = 1
	# 막마다 명단이 다르다 — '새 몬스터가 온다' 는 것을 이름으로 보여준다.
	var roster := MonsterRoster.roster_text(next_act)
	var counters := MonsterRoster.counters_text(next_act)
	# 상성은 **막마다 고정인 참조표**라 웨이브마다 바뀌지 않는다 — 매 프레임 갱신되는
	# 상태 바가 아니라 툴팁·모달이 맡을 몫이다. 바에서는 뺀다(아래 주석의 실측 근거).
	if compact:
		counters = ""
	if next_wave % BOSS_ROUND_INTERVAL == 0:
		var weakness := MonsterRoster.weakness_for(next_wave, BOSS_ROUND_INTERVAL)
		var label: String = str(MonsterRoster.BOSS_WEAKNESS_LABELS.get(weakness, weakness))
		var tail := " | %s" % counters if counters != "" else ""
		return "다음 %d막 %dR: 보스 · 약점 %s%s" % [next_act, next_wave, label, tail]
	var tail := " | %s" % counters if counters != "" else ""
	return "다음 %d막 %dR: %s%s" % [next_act, next_wave, roster, tail]

# ── 막별 맵/경로/타워 슬롯 ───────────────────────────────────────────────
# 좌표계는 원본 맵 이미지 기준 (1024 x 352). 화면 크기에 맞춰 균등 스케일 후
# 레터박스 오프셋을 적용한다. 슬롯은 경로에서 법선 방향으로 띄운 지점이라
# 길과 절대 겹치지 않는다.
const MAP_W := 1024.0
const MAP_H := 352.0

const ACT_MAP_TEXTURES: Dictionary = {
	1: preload("res://assets/map/map_act1_garden_td_1024x352.png"),
	2: preload("res://assets/map/map_act2_rock_mine_td_1024x352.png"),
	3: preload("res://assets/map/map_act3_sky_citadel_td_1024x352.png"),
}

const ACT_PATHS: Dictionary = {
	1: [
		Vector2(18, 78), Vector2(120, 74), Vector2(215, 75), Vector2(265, 84),
		Vector2(300, 100), Vector2(320, 126), Vector2(331, 160), Vector2(333, 205),
		Vector2(343, 245), Vector2(372, 270), Vector2(415, 277), Vector2(455, 270),
		Vector2(481, 252), Vector2(495, 226), Vector2(500, 180), Vector2(505, 138),
		Vector2(526, 108), Vector2(560, 91), Vector2(600, 87), Vector2(638, 103),
		Vector2(664, 130), Vector2(676, 165), Vector2(678, 210), Vector2(690, 255),
		Vector2(712, 287), Vector2(748, 303), Vector2(786, 300), Vector2(813, 286),
		Vector2(832, 260), Vector2(842, 226), Vector2(847, 190), Vector2(858, 168),
		Vector2(874, 158),
	],
	2: [
		Vector2(55, 140), Vector2(150, 138), Vector2(250, 138), Vector2(335, 140),
		Vector2(372, 152), Vector2(400, 182), Vector2(432, 224), Vector2(452, 262),
		Vector2(470, 277), Vector2(520, 280), Vector2(560, 272), Vector2(592, 248),
		Vector2(616, 212), Vector2(640, 172), Vector2(664, 146), Vector2(700, 133),
		Vector2(755, 130), Vector2(805, 133), Vector2(845, 139), Vector2(872, 152),
		Vector2(890, 180), Vector2(897, 214), Vector2(893, 248), Vector2(876, 270),
		Vector2(845, 287), Vector2(808, 292), Vector2(770, 292), Vector2(745, 290),
	],
	3: [
		Vector2(18, 92), Vector2(48, 74), Vector2(75, 74), Vector2(92, 92),
		Vector2(125, 107), Vector2(155, 125), Vector2(180, 142), Vector2(207, 168),
		Vector2(240, 173), Vector2(300, 173), Vector2(334, 166),
		Vector2(344, 150), Vector2(362, 142), Vector2(382, 158),
		Vector2(396, 172), Vector2(436, 222), Vector2(468, 258), Vector2(495, 275),
		Vector2(540, 275), Vector2(578, 262), Vector2(612, 228), Vector2(635, 190),
		Vector2(652, 162), Vector2(668, 150), Vector2(690, 140), Vector2(715, 138),
		Vector2(730, 152), Vector2(748, 164), Vector2(778, 172), Vector2(809, 177),
	],
}

const ACT_SLOTS: Dictionary = {
	1: [
		Vector2(80.9, 138.6), Vector2(198.6, 137.8), Vector2(359.6, 74.1), Vector2(409.4, 209.8),
		Vector2(499.5, 315.8), Vector2(565.4, 163.6), Vector2(603.3, 242.4), Vector2(733.3, 137.9),
		Vector2(762.7, 232), Vector2(879.5, 301.7), Vector2(938, 106),
	],
	2: [
		Vector2(111.7, 209.8), Vector2(220.7, 67), Vector2(329.2, 220.9),
		Vector2(472.6, 160.1), Vector2(499.2, 89.4), Vector2(541.4, 184.7),
		Vector2(704.4, 206.9), Vector2(750.9, 59.1), Vector2(893.5, 83.5),
		Vector2(963.8, 254.2), Vector2(800.1, 221),
	],
	3: [
		Vector2(344.1, 227.2), Vector2(445.3, 134.4), Vector2(406.4, 282), Vector2(527.9, 213),
		Vector2(647, 280.7), Vector2(598.1, 131.4), Vector2(710.8, 213.7), Vector2(114, 274),
		Vector2(882, 106), Vector2(178, 226), Vector2(522, 114),
	],
}

const ACT_ROAD_TINT: Dictionary = {
	1: Color(1.0, 0.82, 0.50),
	2: Color(1.0, 0.80, 0.52),
	3: Color(0.48, 0.90, 1.0),
}

var map_fit_scale := 1.0
var map_fit_offset := Vector2.ZERO

const ACT_NAMES = {
	1: "초원의 문자",
	2: "고대 유적의 어둠",
	3: "차원의 심연"
}

func _ready() -> void:
	base_hp = max_base_hp
	base_hp_changed.emit(base_hp, max_base_hp)
	enemy_count_changed.emit(0)
	gold_changed.emit(gold)

	_build_slots()
	# 기본 타워 배치를 경로 커버리지 기준으로 잡는다 (고정 [0,1,2] 는 1막에서 30% 만 덮었다).
	apply_default_tower_positions()

	resized.connect(_layout_sanctuary)
	_layout_sanctuary()
	_update_slot_lock_visuals()
	_build_flow_arrows()
	_background_act = current_act
	if ACT_MAP_TEXTURES.has(current_act) and background:
		background.texture = ACT_MAP_TEXTURES[current_act]

const MAX_SLOT_COUNT: int = 11

## 타워 카드(WordTower.tscn)의 반지름(px). 발판도 이 크기에 맞춘다.
## 카드가 길 위로 삐져나오면 안 되므로 겹침 검증의 기준이 된다.
const PAD_RADIUS: float = 32.0
const PAD_DIAMETER: float = PAD_RADIUS * 2.0
## 발판 가장자리와 '칠해진 길' 가장자리 사이 최소 여유(px).
const PAD_ROAD_GAP: float = 8.0
## 막별로 맵 아트에 칠해진 길의 반폭(px).
## tools/mapgen/build_pads.py 가 측정/사용하는 값과 반드시 같아야 한다.
const ACT_ROAD_HALF: Dictionary = { 1: 23.0, 2: 31.0, 3: 22.0 }

## 타워 건설 패드: 길 위가 아니라 길 옆 빈 터에 놓이는 원형 발판.
## 모든 막이 같은 개수를 쓰므로 노드는 한 번만 만들고 위치만 옮긴다.
func _build_slots() -> void:
	for i in range(MAX_SLOT_COUNT):
		var slot := Node2D.new()
		slot.name = "Slot%d" % i
		var pad := Panel.new()
		pad.name = "SlotBg"
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.custom_minimum_size = Vector2(PAD_DIAMETER, PAD_DIAMETER)
		pad.size = Vector2(PAD_DIAMETER, PAD_DIAMETER)
		pad.position = Vector2(-PAD_RADIUS, -PAD_RADIUS)
		var lbl := Label.new()
		lbl.name = "SlotLabel"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		lbl.add_theme_constant_override("outline_size", 4)
		pad.add_child(lbl)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(pad)
		tower_slots_container.add_child(slot)
		tower_slots.append(slot)

func _slot_pad_style() -> StyleBoxFlat:
	# 밝은 정원 맵과 어두운 광산/천공성 맵 모두에서 보이도록
	# 반투명 보라 채움 + 밝은 링 + 검은 그림자(밝은 배경 대비)를 함께 쓴다.
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.MANA_INK.r, Palette.MANA_INK.g, Palette.MANA_INK.b, 0.22)
	s.border_color = Color(0.86, 0.80, 1.0, 0.95)
	s.set_border_width_all(2)
	s.set_corner_radius_all(int(PAD_RADIUS))
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	s.shadow_size = 4
	return s

func _update_slot_lock_visuals() -> void:
	# 11개의 발판은 모두 사용 가능한 건설 위치다(논리적 타워 슬롯 3개와는 별개).
	# 빈 발판은 "+" 로 "여기에 세울 수 있다"를 알리고, 점유되면 숨긴다.
	for i in range(tower_slots.size()):
		var pad := tower_slots[i].get_node_or_null("SlotBg") as Panel
		var lbl := tower_slots[i].get_node_or_null("SlotBg/SlotLabel") as Label
		if pad:
			pad.add_theme_stylebox_override("panel", _slot_pad_style())
		if lbl:
			lbl.text = "+"
			lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 1.0, 0.95))

## 원본 맵(1024x352)을 필드에 레터박스로 맞춘다. 모든 좌표가 같은 변환을 쓴다.
func _compute_map_fit() -> void:
	var s: float = minf(size.x / MAP_W, size.y / MAP_H)
	map_fit_scale = s
	map_fit_offset = (size - Vector2(MAP_W, MAP_H) * s) * 0.5

func map_to_screen(p: Vector2) -> Vector2:
	return p * map_fit_scale + map_fit_offset

## 막이 바뀔 때 배경과 경로/슬롯을 통째로 교체한다.
func set_act(act: int) -> void:
	current_act = clampi(act, 1, MAX_ACTS)
	if ACT_MAP_TEXTURES.has(current_act) and background:
		background.texture = ACT_MAP_TEXTURES[current_act]
	_layout_sanctuary()
	_update_slot_lock_visuals()
	_build_flow_arrows()
	# 발판 배치는 막마다 다르다. 1막에서 좋은 자리가 2막에서는 죽은 자리일 수 있으므로
	# (1막 pad 2 = 커버 3.2%, 2막 pad 4 = 커버 8.5%) 막이 바뀌면 새 막 기준으로 다시 잡는다.
	if _pad_layout_act != current_act:
		apply_default_tower_positions()
		_refresh_tower_pads()

func _layout_sanctuary() -> void:
	_compute_map_fit()
	var path_points: Array = ACT_PATHS.get(current_act, ACT_PATHS[1])
	if path_2d:
		var curve := Curve2D.new()
		for point in path_points:
			curve.add_point(map_to_screen(point))
		path_2d.curve = curve

	var slot_points: Array = ACT_SLOTS.get(current_act, ACT_SLOTS[1])
	for i in range(mini(tower_slots.size(), slot_points.size())):
		tower_slots[i].position = map_to_screen(slot_points[i])

	# 차원문(스폰) = 경로 시작, 현자의 핵(베이스) = 경로 끝.
	var spawn_spot = get_node_or_null("SpawnSpot") as Control
	if spawn_spot:
		spawn_spot.visible = true
		var spawn_pt := map_to_screen(path_points[0])
		spawn_spot.position = spawn_pt - Vector2(28, 66)
	var base_spot = get_node_or_null("BaseSpot") as Control
	if base_spot:
		base_spot.visible = true
		var base_pt := map_to_screen(path_points[path_points.size() - 1])
		base_spot.position = base_pt - Vector2(28, 24)

	# 길 안내 색은 막의 아트 톤에 맞춘다 (정원/광산 = 따뜻한 흙빛, 천공성 = 청록 룬빛)
	var tint: Color = ACT_ROAD_TINT.get(current_act, Color(1.0, 0.82, 0.5))
	if road_glow:
		road_glow.default_color = Color(tint.r, tint.g, tint.b, 0.10)
	if road_dash:
		road_dash.default_color = Color(tint.r, tint.g, tint.b, 0.30)

	if path_2d and path_2d.curve:
		var pts := path_2d.curve.get_baked_points()
		if road_glow: road_glow.points = pts
		if road_dash: road_dash.points = pts
		# 새 곡선 길이에 맞춰 화살표 진행도를 다시 고르게 편다.
		if not flow_arrows.is_empty():
			var total := path_2d.curve.get_baked_length()
			for i in range(flow_arrows.size()):
				if is_instance_valid(flow_arrows[i]):
					flow_arrows[i].progress = total * float(i) / float(flow_arrows.size())

## 경로를 따라 흐르는 방향 화살표 — "적이 이쪽으로 온다"를 시각적으로 알린다.
const FLOW_ARROW_COUNT: int = 14
var flow_arrows: Array[PathFollow2D] = []
var flow_speed: float = 90.0

func _build_flow_arrows() -> void:
	for a in flow_arrows:
		if is_instance_valid(a):
			a.queue_free()
	flow_arrows.clear()
	if path_2d == null:
		return
	for i in range(FLOW_ARROW_COUNT):
		var follow := PathFollow2D.new()
		follow.name = "FlowArrow%d" % i
		follow.loop = true
		follow.rotates = true
		var tint: Color = ACT_ROAD_TINT.get(current_act, Color(1.0, 0.82, 0.5))
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(9, 0), Vector2(-7, -7), Vector2(-3, 0), Vector2(-7, 7)
		])
		arrow.color = Color(tint.r, tint.g, tint.b, 0.55)
		follow.add_child(arrow)
		path_2d.add_child(follow)
		flow_arrows.append(follow)
		if path_2d.curve:
			follow.progress = path_2d.curve.get_baked_length() * float(i) / float(FLOW_ARROW_COUNT)

func _update_flow_arrows(delta: float) -> void:
	if path_2d == null or path_2d.curve == null or flow_arrows.is_empty():
		return
	var total := path_2d.curve.get_baked_length()
	if total <= 0.0:
		return
	for f in flow_arrows:
		if is_instance_valid(f):
			f.progress = fposmod(f.progress + flow_speed * delta, total)

func _process(delta: float) -> void:
	# 방향 화살표는 웨이브와 무관하게 항상 흐른다 (경로 안내)
	_update_flow_arrows(delta)
	# 보스 체력바는 웨이브가 끝나도(보스가 죽어도) 스스로 정리된다.
	_update_boss_bar(delta)

	if is_wave_running and get_enemies().size() >= MAX_ENEMIES:
		is_wave_running = false
		spawn_queue.clear()
		for enemy in get_enemies(): enemy.queue_free()
		enemy_count_changed.emit(0)
		last_defeat_reason = "overload"
		game_over.emit(false)
		return

	if not is_wave_running:
		return

	if is_planning_phase:
		planning_timer -= delta
		if planning_timer <= 0.0:
			is_planning_phase = false
			round_timer = 0.0
			_start_round(current_wave + 1)
	else:
		round_timer += delta
		if round_timer >= ROUND_INTERVAL and current_wave < MAX_WAVES_PER_ACT:
			is_planning_phase = true
			planning_timer = PLANNING_INTERVAL
			_grant_round_reward(false)

	if not spawn_queue.is_empty():
		spawn_timer += delta
		if spawn_timer >= SPAWN_INTERVAL:
			spawn_timer = 0.0
			var next_enemy_data = spawn_queue.pop_front()
			_spawn_enemy(next_enemy_data)

	elif current_wave >= MAX_WAVES_PER_ACT:
		var alive_enemies = get_enemies()
		if alive_enemies.is_empty():
			_on_wave_cleared()

func start_next_wave() -> void:
	if is_wave_running:
		return

	current_wave += 1
	if current_wave > MAX_WAVES_PER_ACT:
		# Next Act Transition
		if current_act < MAX_ACTS:
			current_act += 1
			current_wave = 1
		else:
			game_over.emit(true)
			return

	is_wave_running = true
	is_planning_phase = false
	spawn_timer = 0.0
	round_timer = 0.0
	planning_timer = 0.0
	spawn_queue.clear()
	_start_round(current_wave)
	SoundEngine.play_summon()

func reset_combat_state() -> void:
	# ⚠️ 보상 드래프트가 전투를 멈춰 둔 채(§2.44) 새 게임·불러오기가 오면 필드가
	# **영구 정지**한다. 리셋은 '정지 해제' 까지 포함한다.
	process_mode = Node.PROCESS_MODE_INHERIT
	is_wave_running = false
	is_planning_phase = false
	last_defeat_reason = ""
	spawn_queue.clear()
	spawn_timer = 0.0
	round_timer = 0.0
	planning_timer = 0.0
	for enemy in get_enemies():
		enemy.queue_free()
	if projectiles_layer:
		for projectile in projectiles_layer.get_children():
			projectile.queue_free()
	for number in get_tree().get_nodes_in_group("damage_numbers"):
		number.queue_free()
	enemy_count_changed.emit(0)

var _background_act: int = 0

func _start_round(round_number: int) -> void:
	current_wave = round_number
	if _background_act != current_act:
		_background_act = current_act
		set_act(current_act)
	_build_wave_monsters(current_act, current_wave)
	wave_status_changed.emit(current_act, MAX_ACTS, current_wave, MAX_WAVES_PER_ACT, true)

## 한 웨이브에 나오는 적 수.
## 예전(8 + wave)은 후반에 30마리 가까이 몰려와 화면이 막히고
## '처치 골드' 가 인플레이션을 일으켰다(사용자 신고: 골드가 너무 많아).
## 적은 수 + 묵직한 적(현대 TD 감각)으로 바꾼다.
const ENEMY_COUNT_BASE: int = 6
const ENEMY_COUNT_PER_WAVE: float = 0.35
const ENEMY_COUNT_PER_ACT: int = 2
## 예전 공식의 계수. 웨이브 총 HP 를 그대로 보존하는 기준선으로만 쓴다.
const LEGACY_COUNT_BASE: float = 8.0
const LEGACY_COUNT_PER_WAVE: float = 1.0

## ── 라운드 난이도 곡선 (2026-10-03, §2.7/G8) ───────────────────────────────
## 같은 막 안에서도 **뒤로 갈수록 가팔라진다.**
##
## 왜 필요했나 (측정): `wave_scale` 이 순수 선형(`1 + (wave-1)*0.08`)이라 1~20라운드가
## **같은 기울기**로 늘었고, 그래서 20라운드에 판이 굳은 뒤로는 위험이 사실상 0 이었다.
## 실측 7회에서 봇은 45라운드에 **기지 60/60(만땅)** 이었고, 위험은 55~60라운드에만 몰렸다.
##
## 왜 '선형을 더 가파르게' 가 아니라 '무릎(knee) 뒤 제곱' 인가:
## 앞 8라운드는 **손대지 않는다.** 그 구간은 빌드를 세우는 시간이고, 여기서 죽으면
## 실력이 아니라 운이다. 무릎 뒤에서만 가속하므로 *"세울 시간은 주고, 세운 뒤에 시험한다"*
## 가 된다. (1라운드 누출 10 은 봇 편향이다 — 사람은 계획 구간에 세울 수 있다.)
##
## ⚠️ **신규 콘텐츠 0.** 적 종류·특성·연출을 하나도 안 만들고 **곡선 항 하나만** 얹는다.
## ⚠️ `enemy_count_for()`·`hp_compensation_for()` 는 **건드리지 않는다** —
##    `tests/test_wave_balance._test_enemy_count_keeps_wave_hp()` 가
##    *"적 수를 줄인 만큼 HP 를 올려 웨이브 총 HP 는 그대로"* 를 계약으로 고정한다.
##    이 곡선은 그 계약 **위에 곱해지는 별도 항**이므로 그 테스트는 그대로 통과한다.
## ⚠️ 이 값을 바꾸면 `DifficultyPlaytest._wave_hp()` 도 같이 읽어야 한다(같은 항을 곱한다).
const WAVE_CURVE_KNEE: int = 8
## 무릎 이후 제곱 계수. wave 20 → 1 + 12² × 0.0025 = **1.36배**.
## 실측 근거·전후 분포는 `docs/design/05_COLD_EVALUATION_2026-10-03.md` §7.
const WAVE_CURVE_SLOPE: float = 0.0025


func enemy_count_for(act: int, wave: int) -> int:
	return ENEMY_COUNT_BASE + int(wave * ENEMY_COUNT_PER_WAVE) + (act - 1) * ENEMY_COUNT_PER_ACT


## 적 수를 줄인 만큼 1마리당 HP 를 올려 '웨이브 총 HP' 를 정확히 보존한다.
## 이래야 골드만 줄고 난이도는 그대로다.
func hp_compensation_for(act: int, wave: int) -> float:
	var legacy := LEGACY_COUNT_BASE + wave * LEGACY_COUNT_PER_WAVE + (act - 1) * ENEMY_COUNT_PER_ACT
	return legacy / float(enemy_count_for(act, wave))


## 라운드 난이도 배수. 무릎(`WAVE_CURVE_KNEE`)까지는 1.0 이고, 그 뒤로는 **제곱**으로 커진다.
## wave 12 → 1.06 · wave 16 → 1.16 · wave 20 → **1.36**.
##
## ⚠️ `hp_compensation_for()` 와 **다른 일을 한다.** 저쪽은 '적 수를 줄인 만큼 HP 를 올려
##    총 HP 를 보존' 하는 **상쇄항**이고, 이쪽은 보존된 총 HP 를 **일부러 늘리는** 항이다.
##    둘을 한 함수에 섞으면 `test_wave_balance` 의 계약이 깨진다 — 그래서 분리했다.
func wave_curve_for(wave: int) -> float:
	var over := maxf(0.0, float(wave - WAVE_CURVE_KNEE))
	return 1.0 + over * over * WAVE_CURVE_SLOPE


func _build_wave_monsters(act: int, wave: int) -> void:
	# 밸런스 개선: 점진적 난이도 곡선, 의미 있는 골드 보상
	# 누구를 보낼지는 MonsterRoster 가 정한다 (막마다 다른 명단 + 속성).
	# 여기서는 '얼마나 강한가' 만 정한다.
	var hp_scale := hp_compensation_for(act, wave)
	var base_hp := (10.0 + act * 4.0) * hp_scale
	var wave_scale := (1.0 + (wave - 1) * 0.08) * wave_curve_for(wave)
	var act_scale := 1.0 + (act - 1) * 0.5

	var enemy_count := enemy_count_for(act, wave)
	if wave % BOSS_ROUND_INTERVAL == 0:
		# 보스는 '제대로 된 보상' 을 준다 — 잡몹을 줄인 만큼 여기에 실어 준다.
		spawn_queue.append(MonsterRoster.boss_entry(act, wave, base_hp, wave_scale, act_scale, BOSS_ROUND_INTERVAL))
	for i in range(enemy_count):
		spawn_queue.append(MonsterRoster.regular_entry(act, i, base_hp, wave_scale, act_scale))


func _spawn_enemy(enemy_data: Dictionary) -> void:
	if enemy_unit_scene == null or path_2d == null:
		return
	var enemy = enemy_unit_scene.instantiate() as EnemyUnit
	path_2d.add_child(enemy)
	enemy.init_enemy(enemy_data["name"], enemy_data["hp"], enemy_data["speed"], enemy_data["gold"], enemy_data["icon"], enemy_data.get("shield", 0.0))
	enemy.enemy_type = enemy_data.get("type", "normal")
	enemy.weakness_trait = enemy_data.get("weakness", "")
	enemy.base_damage = int(enemy_data.get("base_damage", 1))
	# 분열로 태어난 개체는 경로 중간에서 시작한다 (progress 를 미리 밀어 둔다).
	enemy.progress = float(enemy_data.get("progress", 0.0))
	enemy.apply_attrs(enemy_data.get("attrs", []))
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)
	if enemy.enemy_type == "boss":
		_juice_boss_entrance(enemy)
	enemy_count_changed.emit(get_enemies().size())


## 보스 등장 연출 — "보스가 등장했으면 좋겠어" 에 대한 답.
## 전용 등장음 + 화면 흔들림 + 붉은 섬광 + 상단 배너 + 확대된 실루엣 + 전용 체력바.
##
## 소리는 **보스 전용음**이다(`play_boss_entrance`). 웨이브 시작음을 재사용하지 않는 이유는
## 그 소리가 매 웨이브 울려서 "보스 등장" 과 "다음 웨이브 시작" 이 구별되지 않기 때문이다.
## 이 연출이 **라운드당 한 번**인 것은 `_build_wave_monsters()` 가 보스를 한 번만 큐에 넣기
## 때문이고(`:862-864`), 그래서 중복 방지 가드를 두지 않는다 — `tools/BossEntranceProbe.gd`
## 가 보스 1마리·배너 1개를 실측으로 확인한다(도달 불가능한 가드는 죽은 코드다).
func _juice_boss_entrance(enemy: EnemyUnit) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	# 0) 소리 — 시각과 같은 순간에 터진다. 이게 없으면 연출이 절반으로 깎인다.
	SoundEngine.play_boss_entrance()
	# 1) 실루엣을 키우고 튀어나오게 한다 — 잡몹과 한눈에 구분된다.
	#
	# 배율은 EnemyUnit 이 소유한다(`EnemyUnit.BOSS_SPRITE_SCALE`). 여기서 sprite.scale 을
	# 직접 만지면 안 된다 — 체력바·배지 위치가 그 배율에서 파생되므로, 배율만 바꾸면
	# 장식이 커진 몸통 안쪽에 남는다.
	if enemy.sprite:
		enemy.set_sprite_scale(EnemyUnit.BOSS_SPRITE_SCALE)
		enemy.sprite.modulate = Color(1.15, 0.95, 0.95)
	# 2) 화면 흔들림 + 붉은 섬광
	# ⚠️ `Juice.shake()` 를 **두 번 부르지 말 것** — 호출마다 RNG 가 달라 두 노드가
	# 서로 무관한 방향으로 흔들린다(실측: 최악 89°, 평균 일치도 0.57). 한 사건은 한 방향이다.
	# `shake_together` 는 같은 오프셋 열에 각자의 배율만 곱하므로 변위가 **평행**하다.
	# 길이도 하나로 모았다(예전 0.35/0.3 → 0.35) — 한 사건이 두 길이를 가질 이유가 없다.
	Juice.shake_together([
		{"node": self, "intensity": 9.0},
		{"node": tower_slots_container, "intensity": 6.0},
	], 0.35)
	# 섬광 — 세기 0.22, 0.12초에 걸쳐 오르고 0.5초에 걸쳐 사라진다(보스 등장은 크고 길게).
	# 모양(부모를 꽉 채움 · 마우스 무시 · 끝나면 소멸)은 `Juice.flash` 가 단일 소유한다.
	Juice.flash(_flash_screen_node(), Palette.HP_DANGER, 0.22, 0.12, 0.5)
	# 3) 상단 배너 + 전용 체력바
	_show_boss_banner(enemy)
	_attach_boss_bar(enemy)


## 보스 등장 배너. 약점을 함께 알려줘서 '무엇으로 때려야 하는지' 를 즉시 전달한다.
func _show_boss_banner(enemy: EnemyUnit) -> void:
	var banner := VBoxContainer.new()
	banner.name = "BossBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	# PRESET_CENTER_TOP 은 앵커가 '상단 가운데' 다 — position 은 그 기준 상대값이다.
	# (size.x 를 더하면 리사이즈 때마다 두 배로 밀린다)
	# y 는 보스 체력바(y=2, 높이 약 44) 아래여야 한다 — 겹치면 약점 문구가 가려진다.
	banner.position = Vector2(-160.0, BOSS_BANNER_TOP)
	banner.custom_minimum_size = Vector2(320.0, 0.0)
	banner.z_index = 120
	add_child(banner)

	var title := Label.new()
	title.text = "⚠ %s 등장" % enemy.enemy_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.HP_DANGER)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	title.add_theme_constant_override("outline_size", 6)
	banner.add_child(title)

	var weakness_label := Label.new()
	weakness_label.text = "약점: %s" % str(MonsterRoster.BOSS_WEAKNESS_LABELS.get(enemy.weakness_trait, enemy.weakness_trait))
	weakness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weakness_label.add_theme_font_size_override("font_size", 15)
	weakness_label.add_theme_color_override("font_color", Palette.TX_GOLD)
	weakness_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	weakness_label.add_theme_constant_override("outline_size", 4)
	banner.add_child(weakness_label)

	# 잠깐 크게 보였다가 위로 사라진다.
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)


## 보스 전용 체력바. 화면 상단에 남아 '얼마나 남았는지' 를 계속 보여준다.
func _attach_boss_bar(enemy: EnemyUnit) -> void:
	if _boss_bar != null and is_instance_valid(_boss_bar):
		_boss_bar.queue_free()
	var panel := PanelContainer.new()
	panel.name = "BossBar"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-190.0, BOSS_BAR_TOP)
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	panel.z_index = 110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.82)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Palette.HP_DANGER
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.name = "BossColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var title := Label.new()
	title.name = "BossName"
	title.text = enemy.enemy_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.HP_DANGER)
	column.add_child(title)

	var bar := ProgressBar.new()
	bar.name = "BossHp"
	bar.custom_minimum_size = Vector2(360.0, 12.0)
	bar.max_value = maxf(1.0, enemy.max_hp + enemy.max_shield)
	bar.value = enemy.hp + enemy.shield
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.HP_DANGER
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.10, 0.16, 0.9)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	column.add_child(bar)

	# §5.2 28 (A) — **약점을 전투 내내 보이게** 한다.
	#
	# 예전에는 등장 배너가 약점의 **유일한** 채널이었고, 그 배너는 트윈으로 떴다 사라진다
	# (게임시간 2.15초 · **4배속에서 실시간 0.56초**). 놓치면 되돌릴 방법이 없었다 —
	# 비약점 배율 0.90 은 `RESIST_MULT`(0.75) **위**라서 틀린 특성으로 때려도 피해 숫자가
	# 평범한 흰색이고, 즉 **맞는 타워를 이미 가진 사람만** 알 수 있었다.
	#
	# ⚠️ 문구는 **등장 배너와 같은 출처**를 읽는다(`enemy.weakness_trait` + `BOSS_WEAKNESS_LABELS`).
	#    손으로 적으면 배너와 체력바가 다른 말을 하게 된다(§2.18 의 드리프트 그대로).
	# ⚠️ **새 정보를 만들지 않는다** — 이미 배너가 말하던 것을 **오래 남기는** 것뿐이다.
	var weak_label := Label.new()
	weak_label.name = "BossWeak"
	weak_label.text = "약점: %s" % str(MonsterRoster.BOSS_WEAKNESS_LABELS.get(enemy.weakness_trait, enemy.weakness_trait))
	weak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weak_label.add_theme_font_size_override("font_size", 12)
	weak_label.add_theme_color_override("font_color", Palette.TX_GOLD)
	column.add_child(weak_label)

	_boss_bar = panel
	_boss_target = enemy


## 보스 체력바를 매 프레임 갱신하고, 보스가 죽으면 치운다.
func _update_boss_bar(delta: float) -> void:
	if _boss_bar == null or not is_instance_valid(_boss_bar):
		_boss_bar = null
		_boss_target = null
		return
	# is_dead 를 함께 보는 이유: queue_free() 는 프레임 끝에야 반영되므로
	# 그것만 믿으면 보스가 죽은 뒤에도 한 프레임 더 체력바가 남는다.
	if _boss_target == null or not is_instance_valid(_boss_target) or _boss_target.is_dead:
		_boss_bar.queue_free()
		_boss_bar = null
		_boss_target = null
		return
	var bar := _boss_bar.get_node_or_null("BossColumn/BossHp") as ProgressBar
	if bar:
		# 보스 바는 360px 로 크다. 즉시 튀면 보스가 한 방에 몇 % 를 잃었는지가
		# 안 읽힌다 — 부드럽게 따라가야 "깎였다"가 보인다.
		Juice.approach(bar, _boss_target.hp + _boss_target.shield, delta)

## 이 처치가 **웨이브를 끝내는가** — 끝낸다면 `_on_wave_cleared()` 가 곧 돌고, 그 안의
## `_grant_round_reward()` 가 **막 클리어 팡파르**(`play_victory` · 3막이면 런 승리음)를
## **같은 순간에** 낸다.
##
## ⚠️ `_grant_round_reward()` 의 `play_victory` 가드(`:1247`)와 **같은 사건**을 가리킨다.
##    저쪽은 "내가 낼 소리를 끈다", 이쪽은 "곧 올 소리와 겹칠 **내** 소리를 끈다" 다.
## ⚠️ **이름이 달라도 스로틀이 못 막는다** — `_last_played_msec` 는 이름별이라
##    `boss_death` 와 `victory` 는 서로를 막지 않고 **그냥 합산된다**(`SfxStackProbe` 가 잰 현상).
## ⚠️ **마지막 적일 때만** 참이다. 3막 마지막 웨이브에서 보스가 **먼저** 죽고 잡몹이 남아
##    있다면 웨이브는 아직 안 끝났고, 그 보스의 처치음은 울려야 한다.
##    (`get_enemies()` 는 `is_dead` 를 빼므로 죽는 순간 그 적은 이미 목록 밖이다.)
func _death_clears_wave() -> bool:
	if current_wave < MAX_WAVES_PER_ACT:
		return false
	return spawn_queue.is_empty() and get_enemies().is_empty()


func _on_enemy_died(enemy: EnemyUnit) -> void:
	gold += enemy.gold_reward
	gold_changed.emit(gold)
	# ── 처치음 (§5.2 30 (A), 2026-10-01) ────────────────────────────────────
	# 보스는 **제 소리**를 낸다. 예전에는 잡몹과 똑같이 `play_coin` 이었고, 그래서 보상이
	# 8~12배인데도 **귀로는 구별되지 않았다**(§2.4 문제점 6 · 계약은 `TowerDefenseMain.gd:297`
	# 의 **"5라운드마다 보스 등장 · 처치 시 대보상"**).
	# ⚠️ **얹지 않고 교체한다** — 둘 다 내면 이름이 달라 스로틀을 통과해 **합산**된다(§2.20-6).
	# ⚠️ **웨이브를 끝내는 보스 처치는 제 소리를 내지 않는다** — 곧 막 클리어 팡파르가 같은
	#    순간에 나서 `boss_death`(0.70초)가 그 위에 깔린다. `_grant_round_reward()` 가
	#    `play_victory()` 를 끄는 것과 **같은 판단**이다.
	#    ⚠️ 잡몹의 `coin`(0.20초)은 **그대로 둔다** — 짧은 장식음이라 팡파르를 덮지 않고,
	#       여기서까지 끄면 마지막 잡몹 처치가 *"골드는 올랐는데 소리는 없는"* 순간이 된다.
	if enemy.enemy_type == "boss":
		if not _death_clears_wave():
			SoundEngine.play_boss_death()
	else:
		SoundEngine.play_coin()
	# 처치 연출 — 골드 획득 텍스트 + 잔해 파편
	_juice_enemy_death(enemy)
	# 분열 속성: 죽은 자리에서 두 마리가 갈라져 나온다.
	# 기지에 닿아 사라진 경우(reached_base)는 died 를 쏘지 않으므로 여기 오지 않는다.
	if enemy.split_into > 0:
		_split_enemy(enemy)
	if is_instance_valid(enemy):
		enemy_count_changed.emit(get_enemies().size())


## 분열 — 부모가 죽은 '경로 위치' 에서 자식들을 즉시 만들어 낸다.
## (스폰 큐에 넣으면 0.8초 뒤에야 나와서 "갈라졌다" 는 인과가 안 읽힌다)
## 자식은 분열 속성을 잃는다(무한 분열 방지) 그리고 골드를 주지 않는다
## (분열이 골드 파밍 수단이 되면 경제가 무너진다).
func _split_enemy(parent: EnemyUnit) -> void:
	var at_progress := parent.progress
	var child_hp := parent.max_hp * MonsterRoster.SPLIT_HP_RATIO
	var child_shield := parent.max_shield * MonsterRoster.SPLIT_HP_RATIO
	var attrs: Array = parent.attrs.filter(func(attr): return str(attr) != "splitter")
	for i in range(parent.split_into):
		# 경로를 따라 앞뒤로 조금씩 벌려 놓아 겹쳐 보이지 않게 한다.
		var offset := 10.0 * (float(i) - (float(parent.split_into) - 1.0) * 0.5)
		_spawn_enemy({
			"name": "%s 조각" % parent.enemy_name,
			"type": parent.enemy_type,
			"hp": child_hp,
			"shield": child_shield,
			"speed": parent.speed,
			"gold": 0,
			"icon": parent.icon_path,
			"attrs": attrs,
			"base_damage": 1,
			"progress": maxf(0.0, at_progress + offset),
		})

## 적 처치 연출: 골드 획득 숫자와 사방으로 흩어지는 파편
func _juice_enemy_death(enemy: EnemyUnit) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos := enemy.global_position

	var gold_label := Label.new()
	gold_label.text = "+%d G" % enemy.gold_reward
	gold_label.z_index = 100
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_label.global_position = pos + Vector2(6.0, -30.0)
	gold_label.add_theme_font_size_override("font_size", 15)
	gold_label.add_theme_color_override("font_color", Palette.TX_GOLD)
	gold_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	gold_label.add_theme_constant_override("outline_size", 4)
	add_child(gold_label)
	var gtw := gold_label.create_tween()
	gtw.set_parallel(true)
	gtw.tween_property(gold_label, "global_position:y", gold_label.global_position.y - 26.0, 0.7)
	gtw.tween_property(gold_label, "modulate:a", 0.0, 0.7)
	gtw.chain().tween_callback(gold_label.queue_free)

	# 파편 4~6개를 사방으로 흩뿌린다
	# 파편 색은 **적 종류**를 반영한다(§2.2 문제점 3). 예전에는 전부 `TX_GOLD`
	# 하드코딩이라 무엇이 죽었든 파편이 같았다 — 파편이 '골드가 튀었다' 로만 읽혔다.
	# 배지와 **같은 출처**(`MonsterRoster.type_color`)를 읽어, 방금 본 배지 색과 파편 색이
	# 일치하게 한다. 색 표를 새로 만들지 않는다.
	# ⚠️ `normal` 은 타입 색이 **없다**(배지도 안 단다). 그때는 골드를 유지한다:
	#    대부분의 적이 일반이라 여기서 회색으로 떨어지면 초원 배경에 묻힌다.
	var shard_color := Palette.TX_GOLD
	if MonsterRoster.has_type_color(enemy.enemy_type):
		shard_color = MonsterRoster.type_color(enemy.enemy_type)

	var count := randi_range(4, 6)
	for i in range(count):
		var shard := ColorRect.new()
		shard.size = Vector2(randf_range(3.0, 6.0), randf_range(3.0, 6.0))
		shard.color = Palette.with_alpha(shard_color, 0.9)
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.z_index = 99
		shard.global_position = pos
		add_child(shard)
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := randf_range(18.0, 38.0)
		var target_pos := pos + Vector2(cos(angle), sin(angle)) * dist + Vector2(0, 12)
		var stw := shard.create_tween()
		stw.set_parallel(true)
		stw.tween_property(shard, "global_position", target_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.tween_property(shard, "modulate:a", 0.0, 0.42)
		stw.chain().tween_callback(shard.queue_free)

func _on_enemy_reached_base(enemy: EnemyUnit, dmg: int) -> void:
	base_hp = maxi(0, base_hp - dmg)
	base_hp_changed.emit(base_hp, max_base_hp)
	# ⚠️ `play_hit()` 이 아니다 — **전용 파형 `hit_base`**(90→28 Hz · 0.30초)다.
	# 예전에는 적 피격과 이름이 같아서, 적이 무더기로 맞는 프레임에 **이 소리가 통째로
	# 삼켜졌다**(실측 `before=8 after_enemy_hit=9 after_base_hit=9`). 두 사건의 극성은
	# 정반대인데(내가 잘 하고 있다 / 런이 끝나가고 있다) 소리가 같아서는 안 된다.
	# 2026-09-26 (B) 가 **스로틀 창**을 나눠 삼켜짐을 없앴고, 2026-10-03 (C)·(D) 가 **파형까지**
	# 갈랐다 — 적 피격(160→40 Hz · 0.12초)보다 **낮고 길다**(이 프로젝트의 '길이=강도' 규칙과
	# 같은 방향). ⚠️ 파형이 정말 다른지는 `tools/BaseHitSignalProbe` 가 **바이트 비교**로 잰다
	# (`waveform_same=false`) — **키만 다르고 소리가 같으면 그 프로브가 빨개진다.**
	SoundEngine.play_base_hit()
	# 기지 피격은 가장 강한 타격감이 필요한 순간 → 화면 흔들림 + 붉은 플래시
	_juice_base_hit()
	if base_hp <= 0:
		last_defeat_reason = "breach"
		game_over.emit(false)
	enemy_count_changed.emit(get_enemies().size())

## 섬광이 덮어야 할 **화면 크기 노드**를 찾는다(§2.11-a).
##
## ⚠️ `Juice.flash` 의 계약은 "부모를 꽉 채운다 — **부모가 곧 화면**" 이다. 그런데
##    여기서 `self`(필드)를 넘기고 있어서 섬광이 **화면의 48.3%** 만 덮었다 — 정작
##    주석은 "전체 화면 붉은 비네트" 라고 적고 있었다(실측 `tools/FlashProbe.tscn`).
##    그래서 최상위 Control 까지 올라가서 넘긴다.
## ⚠️ **컨테이너를 부모로 주면 안 된다** — `VBoxContainer` 같은 컨테이너는 자식을 자기
##    규칙으로 배치하므로 `PRESET_FULL_RECT` 가 무시되고 섬광이 한 칸에 끼어 버린다.
##    그래서 'Control 이면서 컨테이너가 아닌' 가장 위의 조상을 고른다.
## ⚠️ 그런 조상이 없으면(전부 컨테이너) `self` 로 떨어진다 — 예전 동작이되, 그때는
##    최소한 '필드만 덮인다' 는 사실이 이 주석으로 남는다.
func _flash_screen_node() -> Control:
	var node: Control = self
	var best: Control = self
	while node.get_parent() is Control:
		node = node.get_parent()
		if not (node is Container):
			best = node
	return best

## 기지 피격 연출: 컨테이너 흔들림 + 붉은 섬광 1회
##
## ⚠️ 흔들림은 `shake_together` 로 **한 방향**이어야 한다 — `shake()` 두 번은 독립 RNG 라
## 두 노드가 따로 떨린다(§2.4 문제 2). 길이도 0.26 하나로 모았다(예전 0.26/0.22).
##
## ⚠️ 예전 이 주석은 "**전체 화면** 붉은 비네트" 라고 적었지만 **거짓**이었다 — 섬광은
##   `self` 의 자식이라 **필드(화면의 48.3%)만** 덮고, 비네트가 아니라 **단색 판**이다
##   (실측 `tools/FlashProbe.tscn`). 문구를 고칠지 코드를 넓힐지(전체 화면으로)는
##   **감독 결정 사항**이라, 여기서는 사실만 적고 프로브가 비율을 보고한다.
func _juice_base_hit() -> void:
	Juice.shake_together([
		{"node": self, "intensity": 7.0},
		{"node": tower_slots_container, "intensity": 5.0},
	], 0.26)
	# 섬광 — 세기 0.18, 0.08초에 걸쳐 오르고 0.28초에 걸쳐 사라진다(피격은 보스 등장보다 짧게).
	Juice.flash(_flash_screen_node(), Palette.HP_DANGER, 0.18, 0.08, 0.28)

func _wave_clear_bonus() -> int:
	# 골드 밸런스 (사용자 신고: 골드가 너무 많아).
	# 1차 조정으로 2,808G → 1,523G 까지 줄였지만 여전히 잉여가 남았다.
	# 실측(tools/EconomyProbe) 결과 소비처 천장은 타일 735G + 유물 300G ≈ 1,035G 인데
	# 수입이 1,523G 라서 약 490G 가 쌓였다. 그래서 수입 자체를 ~1,050G 로 낮춘다.
	#   - 라운드 보상: 1 + 막*2 + 웨이브/8  →  1 + 막 + 웨이브/12
	#   - 보스 라운드 가산: +10 → +5
	#   - 적 처치 골드(중갑 2G→1G, 보스 10+4막 → 6+2막)는 _build_wave_monsters 에서 조정.
	# 적 수는 건드리지 않았다 — hp_compensation_for 가 웨이브 총 HP 를 보존하므로
	# 적 수를 줄여도 난이도는 그대로지만, 화면에 적이 줄면 광역 특성(splash/chain)의
	# 가치가 떨어져 전투 손맛이 달라진다. 골드 숫자만 손보는 쪽을 택했다.
	var base_bonus := 1 + current_act + int(current_wave / 12.0)
	if current_wave % BOSS_ROUND_INTERVAL == 0:
		base_bonus += 5
	if has_relic("relic_bounty_coin"):
		base_bonus += 5
	# 상인의 보물주머니: 웨이브 클리어 보상 +50%. 덧셈 유물을 먼저 다 더한 뒤 곱한다.
	if has_relic("relic_merchant_pouch"):
		base_bonus = ceili(base_bonus * 1.5)
	return base_bonus

func _on_wave_cleared() -> void:
	is_wave_running = false
	wave_status_changed.emit(current_act, MAX_ACTS, current_wave, MAX_WAVES_PER_ACT, false)
	_grant_round_reward(true)

func _grant_round_reward(is_act_final: bool) -> void:
	if unlocked_slot_count < mini(MAX_UNLOCKED_SLOTS, tower_slots.size()):
		unlocked_slot_count += 1
		_update_slot_lock_visuals()

	var bonus_gold = _wave_clear_bonus()
	gold += bonus_gold
	if has_relic("relic_healing_incense"):
		# 상점 설명은 "웨이브 종료 시 기지 HP 2 회복" 이다.
		# 예전에는 치유 타워가 하나라도 있으면 **조용히 3** 을 회복했다(`+ extra`).
		# 설명 어디에도 없는 조건부 보너스였으므로 설명에 맞춰 지웠다
		# (디렉터 규칙: "설명과 코드를 일치시켜줘. 설명에 맞춰").
		# 그 +1 을 설명하던 정보창 라벨(`치유 증폭`)도 함께 지웠다 — 이제 말할 것이 없다.
		base_hp = mini(max_base_hp, base_hp + 2)
		base_hp_changed.emit(base_hp, max_base_hp)
	# 슬롯 순서로 인접한 `defense`+`heal` 짝이면 라운드마다 기지 HP +1.
	#
	# ⚠️ **술어를 여기서 손으로 쓰지 않는다** — 같은 술어를 `_apply_tower_synergies` 가
	# 툴팁 라벨에 쓴다. 둘로 나누면 *"라벨은 붙었는데 회복은 안 된다"*(또는 반대)가 조용히
	# 생긴다. §2.45 의 결함이 정확히 그 모양이었다 — **지급만 있고 말이 없었다.**
	if not _array_adjacent_defense_heal_pair().is_empty():
		base_hp = mini(max_base_hp, base_hp + 1)
		base_hp_changed.emit(base_hp, max_base_hp)
	gold_changed.emit(gold)
	# ⚠️ 3막의 마지막 웨이브에서는 **울리지 않는다.** 그 경우 이 함수는 곧바로 아래에서
	# `game_over.emit(true)` 로 가고, 런 승리음(`play_final_victory`)이 같은 순간에 난다.
	# 여기서도 울리면 두 소리가 **동시에** 나서 런의 마지막 문장이 뭉개진다.
	# (이름이 달라 스로틀도 못 막는다 — 그냥 합산된다. `SfxStackProbe` 가 잰 그 현상이다.)
	if not (is_act_final and current_act >= MAX_ACTS):
		SoundEngine.play_victory()

	# 주의 — 시그널 인자를 '멤버 변수 그대로' 넘기면 emit 시점에 스냅샷되지 않는다.
	# GDScript 는 멤버 읽기를 인자로 넘길 때 그 값을 핸들러마다 다시 읽는다.
	# 그래서 앞선 핸들러가 current_act 를 바꾸면, 뒤 핸들러는 바뀐 값을 받는다.
	#   실측(Godot 4.7.2): emit(member) → 핸들러1이 member=2 로 바꿈 → 핸들러2 는 2 를 받음
	#   지역 변수에 담거나 식으로 만들면(예: member + 0) 정상적으로 1 이 전달된다.
	# TowerDefenseMain._on_act_cleared 는 첫 핸들러이고, 여기서 _start_wave_automatically()
	# 가 막을 진행시켜 current_act 를 올린다. 그 뒤에 붙은 핸들러(진단 도구 등)가
	# '1막 클리어' 를 '2막 클리어' 로 잘못 보던 원인이 정확히 이것이었다.
	# → 반드시 지역 변수로 스냅샷해서 넘긴다.
	if is_act_final:
		if current_act >= MAX_ACTS:
			game_over.emit(true)
		else:
			var cleared_act := current_act
			act_cleared.emit(cleared_act, bonus_gold)
	else:
		var wave_act := current_act
		var wave_index := current_wave
		wave_cleared.emit(wave_act, wave_index, bonus_gold)

## 선회 방향을 슬롯에 기억시킨다.
##
## '기억' 만 한다 — 지금 도는 오브를 뒤집는 일은 타워가 스스로 한다
## (WordTower.toggle_orbit_direction 참고). 필드가 타워 목록을 뒤져서 적용하는
## 방식이면, 목록에서 못 찾는 순간 플레이어의 클릭이 조용히 씹힌다.
## 기억이 필요한 이유는 하나뿐이다: 자모를 고치면 타워가 통째로 다시 세워진다.
func remember_orbit_direction(slot: int, clockwise: bool) -> void:
	orbit_directions[str(slot)] = clockwise


## 조준 우선순위도 '기억' 만 한다 — 실제 적용은 타워가 한다
## (WordTower.cycle_targeting_mode 참고). 기억이 필요한 이유는 하나뿐이다:
## 자모를 고치면 타워가 통째로 다시 세워지고, 그때 플레이어의 선택이 사라진다.
func remember_targeting_mode(slot: int, mode: String) -> void:
	target_modes[str(slot)] = mode


func update_towers_from_parsed_list(parsed_list: Array) -> void:
	var previous_words := {}
	for t in active_towers:
		if is_instance_valid(t):
			previous_words[t.logical_slot_index] = t.syllable
			t.queue_free()
	active_towers.clear()

	# 타워가 있는 슬롯은 마커를 숨기고, 빈 슬롯은 마커를 보여준다.
	for k in range(tower_slots.size()):
		var bg = tower_slots[k].get_node_or_null("SlotBg")
		if bg: bg.visible = true

	for i in range(mini(parsed_list.size(), unlocked_slot_count)):
		var item = parsed_list[i]
		if item.is_empty():
			continue
		var slot_node = tower_slots[tower_positions[i]]
		var bg = slot_node.get_node_or_null("SlotBg")
		if bg: bg.visible = false
		
		var tower = word_tower_scene.instantiate() as WordTower
		slot_node.add_child(tower)
		tower.setup_tower(item["syllable"], item["word_data"], self, first_magic_circle_pending, i)
		# 선회 방향은 슬롯이 기억한다 — 타워는 방금 새로 세워졌다.
		if orbit_directions.has(str(i)):
			tower.set_orbit_direction(bool(orbit_directions[str(i)]))
		# 조준 우선순위도 같은 이유로 슬롯이 기억한다.
		if target_modes.has(str(i)):
			tower.set_targeting_mode(str(target_modes[str(i)]))
		if has_relic("relic_range_rune"):
			tower.attack_range *= RANGE_RUNE_RANGE_MULT
			# 다른 전역 유물(활자의 정수 · 신속의 나침반)은 툴팁에 자기 이름을 남긴다.
			# 이 유물만 모든 타워의 사거리를 바꾸고도 아무 말을 안 해서, 정보창의 사거리
			# 숫자가 왜 달라졌는지 알 길이 없었다 — 상점 설명이 약속한 그 효과를 여기서도 말한다.
			tower.synergy_labels.append("천리안의 룬 (사거리 +%d%%)" % RANGE_RUNE_RANGE_PCT)
		first_magic_circle_pending = false
		tower.tower_clicked.connect(func(t): tower_info_requested.emit(t))
		active_towers.append(tower)
		# 새로 세워진 타워는 살짝 튀어오르는 등장 연출.
		#
		# ⚠️ 트윈은 Engine.time_scale 을 **따른다** (2026-09-23 실측: time_scale=0 에서
		# 0.5 → 1.0 트윈이 10프레임 뒤에도 0.500 그대로였다). 그래서 일시정지 중에
		# 벨트를 고쳐 타워를 다시 세우면 0.8 스케일에서 멈춘 채 **영구히** 남고,
		# 타워가 80% 크기로 보인다. 이 연출만 시간 배율을 무시하게 한다 —
		# 진행 중에 멈춰도 반드시 제 크기로 끝나야 하는 유일한 트윈이기 때문이다.
		# (배너·섬광·골드 라벨은 멈췄다 이어지면 그만이라 그대로 둔다)
		if previous_words.get(i, "") != item["syllable"]:
			tower.scale = Vector2(0.8, 0.8)
			var tw := tower.create_tween()
			tw.set_ignore_time_scale(true)
			tw.tween_property(tower, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_apply_tower_synergies()

## 슬롯(배열) 순서로 인접한 `defense`+`heal` 짝을 돌려준다. 없으면 빈 배열.
##
## ⚠️ **이 술어가 두 곳의 유일한 출처다** — `_grant_round_reward`(기지 HP +1)와
## `_apply_tower_synergies`(툴팁 라벨). 예전에는 지급만 있고 라벨이 없어서 플레이어가
## 이 회복이 일어나는지조차 알 수 없었다(§2.45).
##
## ⚠️ 여기서 보는 '인접' 은 **슬롯 순서**(`active_towers[i]`/`[i+1]`)다 — 툴팁의
## `수호의 순환`(피해 ×1.1)이 보는 **물리 거리**(`towers_are_adjacent` ≤100px)와 다르다.
## 그래서 두 규칙이 **다른 이름**을 쓴다: `수호의 순환` 대 `HP_SYNERGY_LABEL`.
func _array_adjacent_defense_heal_pair() -> Array:
	for i in range(active_towers.size() - 1):
		var left = active_towers[i]
		var right = active_towers[i + 1]
		if not (is_instance_valid(left) and is_instance_valid(right)):
			continue
		var pair = [left.word_data.get("category"), right.word_data.get("category")]
		if "defense" in pair and "heal" in pair:
			return [left, right]
	return []

## 인접한 타워끼리의 시너지.
##
## 예전에는 '카테고리 짝' 세 개(원소+원소 / 무기+기술 / 방어+회복)뿐이었고,
## 그마저도 툴팁에 나오지 않아서 있는지조차 알 수 없었다.
## 이제 세 가지 축을 본다:
##   (1) 카테고리 짝 — 기존 규칙
##   (2) 같은 공격 특성 2개 — 같은 형태를 겹쳐 '밀도' 를 만든다
##   (3) 1·2·3음절이 모두 모이면 — 음절 길이 사다리를 완성한 보상
## 그리고 모든 결과를 synergy_labels 에 적어 툴팁에 보이게 한다.
func _apply_tower_synergies() -> void:
	for i in range(active_towers.size()):
		for j in range(i + 1, active_towers.size()):
			var left = active_towers[i]
			var right = active_towers[j]
			if not towers_are_adjacent(left, right): continue
			var a = left.word_data.get("category", "")
			var b = right.word_data.get("category", "")
			if a == "element" and b == "element":
				left.damage_multiplier *= 1.15; right.damage_multiplier *= 1.15
				left.synergy_labels.append("원소 공명"); right.synergy_labels.append("원소 공명")
			if a == "weapon" and b in ["skill", "buff"]:
				left.attack_interval *= 0.85; left.synergy_labels.append("전술 연계")
			if b == "weapon" and a in ["skill", "buff"]:
				right.attack_interval *= 0.85; right.synergy_labels.append("전술 연계")
			if "defense" in [a, b] and "heal" in [a, b]:
				left.damage_multiplier *= 1.1; right.damage_multiplier *= 1.1
				left.synergy_labels.append("수호의 순환"); right.synergy_labels.append("수호의 순환")
			if has_relic("relic_open_chime") and not WordSynergy.analyze(left.syllable)["has_final"] and not WordSynergy.analyze(right.syllable)["has_final"]:
				# 상점 설명은 '양쪽 공격속도 +12%' 다. 간격에 0.88 을 곱하면 속도는 +13.6% 가
				# 되므로 역수를 쓴다(신속의 나침반과 같은 원칙 — 설명이 계약이다).
				left.attack_interval *= WordSynergy.speed_pct_to_interval(OPEN_CHIME_SPEED_PCT)
				right.attack_interval *= WordSynergy.speed_pct_to_interval(OPEN_CHIME_SPEED_PCT)
				left.synergy_labels.append("무받침 풍경"); right.synergy_labels.append("무받침 풍경")
			# (2) 같은 공격 특성을 인접 배치 — 같은 형태가 겹치면 밀도가 생긴다.
			if left.trait_id == right.trait_id:
				left.damage_multiplier *= 1.12; right.damage_multiplier *= 1.12
				var label := "%s 밀집" % str(WordTower.TRAIT_NAMES.get(left.trait_id, left.trait_id))
				left.synergy_labels.append(label); right.synergy_labels.append(label)
			# (2b) 서로를 보완하는 형태 조합 — 묶어 두면 화력이 배가된다.
			var pair_label := _complementary_pair_label(left.trait_id, right.trait_id)
			if pair_label != "":
				left.damage_multiplier *= 1.15; right.damage_multiplier *= 1.15
				left.synergy_labels.append(pair_label); right.synergy_labels.append(pair_label)
	# (3) 1·2·3음절이 모두 있으면 '사다리' 완성 — 길이 자체가 보상이 된다.
	_apply_syllable_ladder_synergy()
	# (4) **슬롯 순서**로 인접한 `defense`+`heal` 짝 — 라운드마다 기지 HP +1(§2.45).
	#
	# ⚠️ 위 (1) 의 `수호의 순환`(물리 인접 · 피해 ×1.1)과 **다른 규칙**이다. 여기서 보는
	#    '인접' 은 슬롯 순서라, 라벨 문구가 두 규칙을 구분해 말한다(`HP_SYNERGY_LABEL`).
	# ⚠️ **지급은 `_grant_round_reward` 가 한다 — 여기서는 말만 한다.** 같은 술어를 쓰므로
	#    "라벨은 있는데 효과가 없다"(또는 반대)가 생길 수 없다.
	var hp_pair := _array_adjacent_defense_heal_pair()
	if not hp_pair.is_empty():
		hp_pair[0].synergy_labels.append(HP_SYNERGY_LABEL)
		hp_pair[1].synergy_labels.append(HP_SYNERGY_LABEL)


## 서로를 보완하는 특성 조합의 이름. 없으면 빈 문자열.
func _complementary_pair_label(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	var key := "%s+%s" % [pair[0], pair[1]]
	return str(COMPLEMENTARY_TRAIT_PAIRS.get(key, ""))


## 특성 조합 시너지. 정렬된 "a+b" 키로 찾는다.
## 각 조합은 '한쪽이 발을 묶고 다른 쪽이 때리는' 관계라 실제 화력이 오른다.
## 키는 반드시 실제 trait_id 여야 한다 (WordTower.TRAIT_NAMES 의 키와 같은 집합).
const COMPLEMENTARY_TRAIT_PAIRS: Dictionary = {
	"control+damage_over_time": "동결 작열",   # 얼려 세워 두고 태운다
	"splash+chain": "파열 연쇄",               # 뭉친 무리를 함께 정리
	"pierce+sniper": "저격 관통",              # 앞뒤로 꿰뚫는다
	"meteor+control": "낙하 유도",             # 묶어 두면 유성이 다 맞는다
	"orbit+rapid": "회전 연격",                # 도는 오브 + 빠른 사격
	"bounce+splash": "연속 폭발",              # 튕기는 공이 터진다
}


## 1·2·3음절 타워가 모두 세워져 있으면 전체 피해 +15%.
## "긴 단어를 만들수록 강하다" 는 규칙에 '모으는 재미' 를 더한다.
func _apply_syllable_ladder_synergy() -> void:
	var lengths := {}
	for tower in active_towers:
		if is_instance_valid(tower):
			lengths[clampi(tower.syllable.length(), 1, 3)] = true
	if lengths.size() < 3:
		return
	for tower in active_towers:
		if not is_instance_valid(tower):
			continue
		tower.damage_multiplier *= 1.15
		tower.synergy_labels.append("음절 사다리 (1·2·3음절 완성)")

func towers_are_adjacent(left: WordTower, right: WordTower) -> bool:
	return left.global_position.distance_to(right.global_position) <= 100.0

func get_enemies() -> Array:
	var list = []
	if path_2d:
		for child in path_2d.get_children():
			if child is EnemyUnit and not child.is_dead:
				list.append(child)
	return list

## 경로 위의 모든 적을 뒤로 민다.
##
## progress 는 PathFollow2D 의 진행도라, 줄이는 것만으로 뒤로 간다 —
## 새 이동 로직도, 새 상태도 필요 없다. 그래서 이 능력은 새 시스템이 아니다.
## 반환값은 실제로 밀린 마릿수.
func push_back_enemies(ratio: float) -> int:
	if path_2d == null or path_2d.curve == null:
		return 0
	var amount := path_2d.curve.get_baked_length() * ratio
	var pushed := 0
	for enemy in get_enemies():
		enemy.progress = maxf(0.0, enemy.progress - amount)
		pushed += 1
	return pushed

func add_projectile(proj: Projectile) -> void:
	if projectiles_layer:
		projectiles_layer.add_child(proj)


## 유성/폭발처럼 투사체가 아닌 연출도 같은 레이어에 올려 맵 위에 뜨게 한다.
func add_effect(effect: Node2D) -> void:
	if projectiles_layer:
		projectiles_layer.add_child(effect)
	else:
		add_child(effect)
