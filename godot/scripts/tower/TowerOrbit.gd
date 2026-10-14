# TowerOrbit.gd
# 주위를 맴도는 소환물(성경책). 뱀파이어 서바이버의 '킹 바이블' 오마주.
#
# 투사체를 쏘지 않는다 — 궤도를 도는 오브가 '닿은 적'을 직접 때린다.
# 그래서 사거리 개념이 궤도 반지름으로 바뀌고, 적이 타워 가까이 붙을수록 강해진다.
# 같은 적을 매 프레임 때리면 순삭되므로 적별로 재타격 대기시간을 둔다.
class_name TowerOrbit
extends Node2D

const Palette = preload("res://scripts/ui/Palette.gd")

## 오브가 궤도를 한 바퀴 도는 데 걸리는 시간(초).
##
## **2.6 은 '연출' 이 아니라 '전투' 값이다 — 함부로 줄이면 안 된다.**
## 도는 방향(우클릭으로 뒤집는 그 기능)이 의미를 가지려면 오브의 선속도가 적의
## 이동 속도와 비슷한 자릿수여야 한다. 76px 반지름에 2.6초면 183.6 px/s 이고,
## 적은 60~80 px/s 다. 같은 쪽으로 돌면 상대속도가 100~124, 마주 돌면 244~264 라
## **접촉 시간이 2배 이상 차이 난다** — 그래서 방향이 실제로 타격 수를 바꾼다.
##
## 실측(probe_orbit.gd): 1.0초로 줄이면 477 px/s 가 되어 상대속도 차이가 1.4배로
## 줄고, 방향을 바꿔도 타격 수가 2 vs 3 으로 뒤집혔다(원래 3 vs 2). 즉 방향 기능이
## 죽는다. 그래서 이 값은 그대로 두고, 부족한 타격 수는 재타격 대기로 벌었다.
const TURN_SECONDS := 2.6
## 궤도 반지름의 기본값(px). 실제 값은 타워의 attack_range 를 따라간다
## (사거리 유물/시너지가 궤도 크기에도 그대로 적용되게 하려고).
const DEFAULT_ORBIT_RADIUS := 64.0
const MIN_ORBIT_RADIUS := 40.0
const MAX_ORBIT_RADIUS := 120.0
## 오브의 판정 반지름(px). 그려지는 책은 14x20 이라 반지름 24 면 '스친 것' 이
## 아니라 '지나간 것' 으로 읽힌다. 예전 15 는 책보다 겨우 5px 큰 수준이라
## 눈으로는 닿아 보이는데 안 맞는 일이 많았다.
## 이 값으로 발광 원도 그린다 — 판정과 그림이 어긋나면 못 맞은 것처럼 보인다.
const HIT_RADIUS := 24.0
## 판정 여유(px). 스프라이트가 32px 라 '닿아 보였는데 안 맞는' 일을 줄인다.
## 이 여유가 '한 번 스칠 때 몇 대 맞는가' 를 직접 정한다 — 넓힐수록 오브가
## 적과 함께 있는 시간이 길어져 같은 통과에 더 여러 대 들어간다.
## 실측: 23 → 34 로 넓히면 스치는 시간이 0.23초 → 0.38초가 되어, 같은 통과에
## 들어가는 대수가 1~2대에서 4대로 늘어난다.
const HIT_SLACK := 10.0
## 같은 적을 연속으로 때릴 때의 최소 간격(초).
##
## **선회가 죽어 있던 진짜 원인은 이 값이었다.** 실측(probe_orbit.gd, 2026-09-19):
## 적 한 마리가 선회 발판 앞에 머무는 시간은 평균 0.80초, 가장 잘 맞는 발판에서도
## 2.50초. 그런데 한 바퀴가 2.6초라 **오브는 적이 지나가는 동안 한 번밖에
## 스치지 못했고**, 스치는 시간(0.23초)이 0.3초 대기보다 짧아서 그 한 번이
## 한 대로 끝났다. 결과: 1음절 선회가 적 한 마리에게 넣는 총 피해 4.5 —
## 가장 약한 다른 특성(유성 31.0)의 15%, 최강(저격 84.3)의 5%.
##
## 스치는 시간은 그대로 두고 대기만 줄이면, 한 번 스칠 때 여러 대가 들어간다.
## 0.3 → 0.12 로 4대. 궤도가 빨라지지 않으므로 방향 기능도 그대로 산다.
## 더 줄이면 한 번 스칠 때 피해 숫자가 우수수 뜬다 — 그건 연출이 아니라 소음이다.
const PER_ENEMY_COOLDOWN := 0.12
## 궤도 위 오브의 최대 개수.
##
## 3 이면 '선회의 톱니' 유물(+1개)이 **3음절 타워에서 아무 일도 안 했다**
## (3 + 1 = 4 → 3 으로 잘림). 유물값 40G 를 내고 아무 변화가 없으면 그건 버그다.
const MAX_ORBS := 4
## 피격 시 오브가 반짝이는 시간(초).
const FLASH_TIME := 0.16

var tower: WordTower = null
var orb_count := 2
var orbit_radius := DEFAULT_ORBIT_RADIUS

## 궤도를 도는 방향. true = 화면상 시계 방향(기본), false = 반시계 방향.
##
## Godot 2D 는 y 축이 아래로 향한다. 그래서 각도가 커지는 쪽이 화면에서는
## 시계 방향으로 보인다 — 예전 코드는 이 방향으로 고정돼 있었다.
##
## 방향은 '어느 쪽에서 적을 만나느냐' 를 바꾼다. 오브가 적과 같은 쪽으로 돌면
## 스치는 동안 상대속도가 느려져 접촉 시간이 길어지고, 같은 적을 두 번 때린다.
## 반대쪽으로 돌면 스쳐 지나가 한 대로 끝난다. 그래서 이건 연출이 아니라 배치다.
var clockwise := true

var _angle := 0.0
var _cooldowns: Dictionary = {}
var _hit_flash: Dictionary = {}


func setup(p_tower: WordTower, p_orb_count: int, p_clockwise := true) -> void:
	tower = p_tower
	orb_count = clampi(p_orb_count, 1, MAX_ORBS)
	clockwise = p_clockwise
	orbit_radius = clampf(p_tower.attack_range, MIN_ORBIT_RADIUS, MAX_ORBIT_RADIUS)
	# 시작 각도를 무작위로 둬서 타워마다 다른 박자로 돌게 한다.
	_angle = randf() * TAU
	queue_redraw()


## 도는 방향을 바꾼다.
## 각도는 그대로 두고 진행 방향만 뒤집는다 — 오브가 제자리에서 부드럽게 돌아
## 플레이어가 '방금 뒤집혔다' 를 눈으로 확인할 수 있다.
func set_clockwise(value: bool) -> void:
	if clockwise == value:
		return
	clockwise = value
	queue_redraw()


## 지금 각도에서 한 프레임 진행시킨 뒤의 각도.
## _process 안에 두면 검증할 수가 없어서 분리했다.
func _advance(angle: float, delta: float) -> float:
	var dir := 1.0 if clockwise else -1.0
	return fposmod(angle + dir * (TAU / TURN_SECONDS) * delta, TAU)


func _process(delta: float) -> void:
	if not is_instance_valid(tower):
		queue_free()
		return
	_angle = _advance(_angle, delta)
	_tick_timers(_cooldowns, delta, true)
	_tick_timers(_hit_flash, delta, false)
	_apply_hits()
	queue_redraw()


func _tick_timers(bag: Dictionary, delta: float, erase: bool) -> void:
	for key in bag.keys():
		var left := float(bag[key]) - delta
		if erase and left <= 0.0:
			bag.erase(key)
		else:
			bag[key] = left


## 궤도 위 오브들의 현재 위치(타워 기준 로컬 좌표).
func orb_positions() -> Array:
	var out: Array = []
	for i in range(orb_count):
		out.append(Vector2.RIGHT.rotated(_angle + TAU * float(i) / float(orb_count)) * orbit_radius)
	return out


func _apply_hits() -> void:
	if not is_instance_valid(tower) or tower.field_ref == null:
		return
	var positions := orb_positions()
	for enemy in tower.field_ref.get_enemies():
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var local: Vector2 = enemy.global_position - global_position
		for i in range(positions.size()):
			var key := "%d:%d" % [enemy.get_instance_id(), i]
			if _cooldowns.has(key):
				continue
			if positions[i].distance_to(local) > HIT_RADIUS + HIT_SLACK:
				continue
			_hit(enemy, i)
			_cooldowns[key] = PER_ENEMY_COOLDOWN
			break


func _hit(enemy: EnemyUnit, orb_index: int) -> void:
	if not is_instance_valid(tower):
		return
	var mult: float = enemy.damage_multiplier_for("orbit")
	# ✅ **§2.21-6 고침 (2026-10-01)** — 선회도 **굴린다.** 예전에는 `attack_target()` 을
	#    안 타서 굴림에 도달하지 못했고, 유물 `예리한 렌즈`(35 G)의 *"타워 공격 시 25%
	#    확률로 2배 치명타"* 계약이 선회 타워에서 **거짓**이었다.
	#    ⚠️ 굴림은 **타워가 소유**한다(`WordTower.roll_crit()`). 여기서 `randf()` 를 부르면
	#       굴리는 곳이 둘이 되고, 그 순간 프로브의 *"작성자가 하나인가"* 단언이 무의미해진다.
	var is_crit: bool = tower.roll_crit()
	var damage := tower.crit_damage(tower.orbit_damage() * mult, is_crit)
	# 타격음은 오브마다 울리면 시끄러우니 피해 숫자만 띄운다.
	# 묶기(pool_numbers)는 켜지 않는다 — 선회는 지속피해가 아니라 '한 대씩' 때리는
	# 공격이라, 묶으면 주황색 지속피해 숫자로 보여 종류가 뒤바뀐다.
	var dealt := enemy.take_damage(damage, false, mult, false, is_crit)
	tower.record_damage(dealt)
	_hit_flash[orb_index] = FLASH_TIME


func _draw() -> void:
	var gold := Palette.TX_GOLD
	# 궤도 안내선 — 어디까지 때릴 수 있는지 보이게 한다.
	draw_arc(Vector2.ZERO, orbit_radius, 0, TAU, 48, Color(gold.r, gold.g, gold.b, 0.18), 1.0)
	var positions := orb_positions()
	for i in range(positions.size()):
		var p: Vector2 = positions[i]
		var flash := clampf(float(_hit_flash.get(i, 0.0)) / FLASH_TIME, 0.0, 1.0)
		# 발광 — 맞는 순간 부풀어 오른다.
		draw_circle(p, HIT_RADIUS + 3.0 + flash * 7.0,
			Color(gold.r, gold.g, gold.b, 0.10 + flash * 0.30))
		# 성경책: 크림색 표지 + 금색 테두리 + 책등. 오브마다 스스로 회전한다.
		# 책이 넘어가는 방향도 궤도와 같이 뒤집는다 — 궤도만 반대로 돌면
		# 책이 '따로 노는' 것처럼 보여 방향 전환이 읽히지 않는다.
		var spin := _angle * 3.0 if clockwise else -_angle * 3.0
		draw_set_transform(p, spin + TAU * float(i) / float(orb_count), Vector2.ONE)
		draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), Color(0.98, 0.94, 0.82, 0.96))
		draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), Color(0.86, 0.68, 0.26, 1.0), false, 1.5)
		draw_rect(Rect2(-7.0, -10.0, 3.5, 20.0), Color(0.86, 0.68, 0.26, 1.0))
		draw_line(Vector2(0.5, -6.0), Vector2(5.0, -6.0), Color(0.70, 0.55, 0.20, 0.85), 1.0)
		draw_line(Vector2(0.5, -2.0), Vector2(5.0, -2.0), Color(0.70, 0.55, 0.20, 0.85), 1.0)
		draw_line(Vector2(0.5, 2.0), Vector2(5.0, 2.0), Color(0.70, 0.55, 0.20, 0.85), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
