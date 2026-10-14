# ControlSplashProbe.gd — '둔화(control)' 의 착탄 반경 피해가 실제로 있는지 잰다.
#
#   godot --headless --path . res://tools/ControlSplashProbe.tscn
#
# ── 왜 이 프로브가 필요한가 ──────────────────────────────────────────────────
# 감사 §2.7 (B) 는 이렇게 적혀 있었다.
#
#     "현재 로직: `splash`/`control` 은 **스폰 순서**로 대상을 고른다."
#
# 그런데 그것은 `_trait_targets()` 가 고르는 **발사 대상 목록**의 이야기다. `control` 은
# 거기에 **더해서** 착탄점 48px 안의 적에게 둔화 + 40% 피해를 준다 — `Projectile.hit_target()`
# 안의 `if slow_duration > 0.0:` 블록이다. 즉 **설명이 control 에서는 구현돼 있고 splash
# 에서는 구현돼 있지 않다.** 두 특성을 한 줄로 묶으면 그 차이가 사라지고, 감독이 "둘 다
# 고쳐야 한다" 는 잘못된 크기의 결정을 내리게 된다.
#
# 이 프로브가 그 차이를 **실측**으로 만든다. 재는 것은 '착탄점 기준 거리' 하나다.
#   S1 `control` — 착탄점 48px **안**: 피해 + 둔화를 받는다
#   S2 `control` — 착탄점 48px **밖**: 아무것도 안 받는다
#   S3 `control` — 주 타깃: 온전한 피해 + 둔화
#   S4 `splash`  — 같은 배치·같은 거리: **반경 피해가 없다** (두 특성이 다르다는 증거)
#
# S2·S4 가 없으면 S1 은 **공짜 통과**다 — 아무 적이나 맞은 것을 보고도 "반경 피해가 있다" 고
# 말할 수 있다. S4 가 없으면 이 프로브는 감사의 문장(*"둘 다 스폰 순서다"*)을 **반증하지 못한다**.
#
# ── 무엇을 재지 않는가 ──────────────────────────────────────────────────────
# · `splash` 가 48px 반경 피해를 **받아야 하는지**는 판정하지 않는다 — 밸런스이고 감독 결정이다.
#   이 프로브는 *"두 특성이 지금 다르다"* 만 사실로 고정한다.
# · 충격 연출(`Juice.blast` 고리)은 재지 않는다 — 반경은 `Juice.trait_impact` 의 **인자**라
#   코드 읽기로 확인한다(splash 38px · control 28px, 둘 다 ×1.5 로 커진다).
# · 투사체를 트리에 붙였다가 **떼어낸 뒤** `hit_target()` 을 부른다. 그래야 `_process` 가
#   같은 프레임에 한 번 더 명중시키지 않는다(피해가 2배로 재인다). 부작용으로
#   `_spawn_impact()` 는 부모가 없어 즉시 return 한다 — 연출은 이 프로브의 대상이 아니다.
#
# 주의: `tools/` 아래라 `SaveManager._is_test_run()` 이 자동으로 참이다(`SaveManager.gd:26`).
extends Node2D

const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")

## `Projectile.hit_target()` 의 반경. 여기서 다시 적는 것이 아니라 **계약을 재는 기준**이다.
const IMPACT_RADIUS := 48.0
const DAMAGE := 100.0
const HP := 1000.0
## 착탄점 기준 20 · 36.1 · 44 px — 셋 다 48 안이다.
const INSIDE_OFFSETS: Array = [Vector2(20.0, 0.0), Vector2(-30.0, 20.0), Vector2(0.0, 44.0)]
## 52 · 80 px — 둘 다 48 밖이다.
const OUTSIDE_OFFSETS: Array = [Vector2(52.0, 0.0), Vector2(0.0, 80.0)]

var _failures := 0


class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []
	var damage_log: Array = []

	func has_relic(id: String) -> bool:
		return relic_ids.has(id)

	func get_enemies() -> Array:
		return enemies

	func record_tower_damage(tower_name: String, amount: float) -> void:
		damage_log.append([tower_name, amount])


## 실패하면 세고, 이유를 콘솔에 찍는다. (push_error 는 'ERROR:' 로 찍힌다 — 정상이다)
func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _ready() -> void:
	print("")
	print("=== 착탄 반경 피해 — `control` vs `splash` ===")
	_case("둔화(control)", "얼", "heal", "ice", true)
	_case("폭발(splash)", "산", "nature", "fire", false)
	print("")
	if _failures == 0:
		print("CONTROL_SPLASH_PROBE_OK")
	else:
		print("CONTROL_SPLASH_PROBE_FAIL %d" % _failures)
	get_tree().quit(_failures)


func _spawn(field: StubField, pos: Vector2):
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.init_enemy("probe", HP, 0.0, 0, "")
	field.enemies.append(enemy)
	return enemy


func _case(label: String, word: String, category: String, proj_type: String, expect_radius: bool) -> void:
	var field := StubField.new()
	add_child(field)
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower(word, {"category": category, "is_unknown": true}, field)

	print("")
	print("── %s (%s) ── 사거리 %.0f · 투사체 %s" % [
		label, tower.trait_id, tower.attack_range, proj_type])
	print("   설명: %s" % TraitStyle.desc_for(tower.trait_id))

	var impact := Vector2.ZERO
	var target = _spawn(field, impact)
	var inside: Array = []
	for o in INSIDE_OFFSETS:
		inside.append(_spawn(field, impact + o))
	var outside: Array = []
	for o in OUTSIDE_OFFSETS:
		outside.append(_spawn(field, impact + o))

	# 배치 자체를 먼저 검사한다 — 안/밖이 뒤바뀌면 아래 판정이 통째로 거짓이 된다.
	for e in inside:
		var d: float = impact.distance_to(e.global_position)
		check(d <= IMPACT_RADIUS,
			"%s — '안' 에 둔 적이 %.1fpx 다(반경 %.0f)" % [label, d, IMPACT_RADIUS])
	for e in outside:
		var d: float = impact.distance_to(e.global_position)
		check(d > IMPACT_RADIUS,
			"%s — '밖' 에 둔 적이 %.1fpx 다(반경 %.0f)" % [label, d, IMPACT_RADIUS])

	var before: Dictionary = {}
	for e in ([target] as Array) + inside + outside:
		before[e] = e.hp

	var proj = ProjectileScene.instantiate()
	add_child(proj)
	proj.setup(target, DAMAGE, proj_type, tower.trait_id, tower, 1.0)
	proj.position = impact
	remove_child(proj)
	proj.hit_target()

	var primary_dealt: float = float(before[target]) - target.hp
	print("   주 타깃 피해 %.1f · 둔화 %.2f초" % [primary_dealt, target.slow_timer])
	check(primary_dealt > 0.0, "%s — 주 타깃이 피해를 안 받았다. 측정이 성립하지 않는다" % label)
	# 둔화는 `control` 에만 있다. `splash` 에 이 단언을 걸면 **프로브가 거짓으로 빨개진다**
	# (실제로 첫 실행에서 그랬다 — 대조군에는 대조군의 기대값을 써야 한다).
	if expect_radius:
		check(target.slow_timer > 0.0, "%s — 주 타깃이 둔화되지 않았다" % label)

	var inside_hits := 0
	for e in inside:
		var dealt: float = float(before[e]) - e.hp
		var d: float = impact.distance_to(e.global_position)
		print("   안  %5.1fpx · 피해 %6.1f · 둔화 %.2f초" % [d, dealt, e.slow_timer])
		if dealt > 0.0:
			inside_hits += 1
			# 둔화·40% 비율은 **반경 피해가 있는 특성에만** 기대값이다. 대조군에 걸면
			# 실패 이유가 엉뚱한 문장으로 찍힌다(주입 E 실측: 대조군이 빨개질 때
			# *"반경 안인데 둔화가 안 걸렸다"* 가 세 번 나와 진짜 원인을 가렸다).
			if expect_radius:
				check(absf(dealt - primary_dealt * 0.4) <= 0.05,
					"%s — 반경 피해가 주 타깃의 40%% 가 아니다: %.1f (기대 %.1f)" % [
						label, dealt, primary_dealt * 0.4])
				check(e.slow_timer > 0.0, "%s — 반경 안인데 둔화가 안 걸렸다" % label)

	var outside_hits := 0
	for e in outside:
		var dealt: float = float(before[e]) - e.hp
		var d: float = impact.distance_to(e.global_position)
		print("   밖  %5.1fpx · 피해 %6.1f · 둔화 %.2f초" % [d, dealt, e.slow_timer])
		if dealt > 0.0 or e.slow_timer > 0.0:
			outside_hits += 1

	check(outside_hits == 0,
		"%s — 반경 **밖**의 적 %d마리가 맞았다. 그러면 반경 판정 자체가 무의미하다" % [label, outside_hits])

	if expect_radius:
		check(inside_hits == inside.size(),
			"%s — 반경 안 %d마리 중 %d마리만 맞았다 (설명은 '착탄 지점 주변의 적들' 이다)" % [
				label, inside.size(), inside_hits])
		print("   → 반경 안 %d/%d 피해 · 반경 밖 %d 피해" % [inside_hits, inside.size(), outside_hits])
	else:
		check(inside_hits == 0,
			"%s — 반경 피해가 **없어야** 하는데 %d마리가 맞았다" % [label, inside_hits])
		print("   → 반경 안 %d/%d 피해 (대조군: 이 특성에는 착탄 반경 피해가 없다)" % [
			inside_hits, inside.size()])

	tower.free()
	field.free()
