# TraitBlastProbe.gd — 다중 타격 특성 5종이 **실제로 무엇을 때리는지** 를 그대로 뽑는다.
#
#   godot --headless --path . res://tools/TraitBlastProbe.tscn
#
# 왜 필요한가: 특성 설명은 플레이어에게 주는 계약서인데, 문장이 코드와 어긋나도
# 테스트는 잡지 못한다 — 테스트는 "그 문구를 포함하는가" 만 본다.
# (TargetingProbe 와 같은 이유. 실제로 그 도구가 대시가 두 번 겹친 결함을 잡았다.)
#
# 여기서 재는 세 가지:
#   1. 위치 — 설명이 말한 자리(착탄 지점 주변 / 적중한 적 주변)에서 고르는가?
#   2. 수   — 설명이 말한 수(모든 적 / 최대 3체)와 맞는가?
#   3. 피해 — 설명이 말한 '폭발 피해' 인가, 총량을 나눠 주는 것인가?
#
# 표를 베껴 두지 않는다. `attack_target()` 이 실제로 부르는 `_trait_targets()` 와
# `damage_shares()` 를 그대로 부른다 — 여기에 규칙을 다시 적으면 구현이 바뀌어도
# 이 도구만 옛날 값을 보고하게 된다(이 프로젝트에서 이미 여러 번 난 문제다).
#
# 주의: 이 스크립트 이름은 SaveManager._is_test_run() 에 있어야 한다.
#
# ⚠️ **판정 정책 (2026-10-03).** 이 프로브는 이제 **실패할 수 있다** — `quit(실패 수)`.
#    세는 것: ① 측정 시나리오가 안 만들어짐(특성이 안 맞음) ② 툴팁의 동시 타격 수가
#    실제 대상 수와 다름(§2.7 (A) 계약).
#    ③ splash 의 추가 대상이 착탄점(주 타깃) `SPLASH_RADIUS` 밖에 있음(2026-10-14 §4.2 결정).
#    **세지 않는 것**: control 의 목록 위치 — 반경 피해는 `Projectile` 이 따로 맡는다.
#    (그 전에는 `quit()` 인자 없이 늘 0 이라, 어긋남을 찍어도 **초록**이었다.)
extends Node2D

const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")

## 다중 타격을 하는 5종 — `_trait_targets()` 가 이 목록으로 분기한다.
## word 는 그 특성이 실제로 나오는 단어(AttackStyle 의 EXACT/폴백), category 는 폴백용.
## 전부 1음절이라 `volley_count()` 가 1 → `_trait_targets()` 경로를 탄다.
const CASES: Array = [
	{"trait": "splash",  "word": "산", "category": "nature"},
	{"trait": "pierce",  "word": "가나", "category": "defense"},
	{"trait": "chain",   "word": "번", "category": "skill"},
	{"trait": "bounce",  "word": "돌", "category": "nature"},
	{"trait": "control", "word": "얼", "category": "heal"},
]

## '주 타깃 주변' 이라고 부를 반경. splash 의 착탄 연출 고리는 38px 이고
## control 의 실제 스플래쉬는 48px 이다 — 그 사이값으로 잡았다.
const IMPACT_RADIUS := 40.0

## 계약 위반 수. `quit(_failures)` 로 끝난다 — 0 이 아니면 이 프로브는 **실패**다.
var _failures := 0


class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []

	func has_relic(id: String) -> bool:
		return relic_ids.has(id)

	func get_enemies() -> Array:
		return enemies


func _ready() -> void:
	print("")
	print("=== 다중 타격 특성 5종 — 설명(계약) vs 실제 ===")
	for case in CASES:
		_measure(case)
	_measure_two_syllable()
	_measure_relic_on_long_word()
	print("")
	print("=== 계약 위반 %d ===" % _failures)
	print("=== 끝 ===")
	if _failures == 0:
		print("TRAIT_BLAST_PROBE_OK")
	get_tree().quit(_failures)


## 적 7마리 배치로 한 특성을 잰다.
##
## 밀집 3마리를 **주 타깃에서 18~34px** 에 두고, 먼쪽 3마리를 타워 쪽에 둔다.
## `get_enemies()` 순서는 '먼쪽이 먼저' 다 — 설명이 옳다면 순서와 무관하게
## 주 타깃 주변의 적이 뽑혀야 한다.
func _measure(case: Dictionary) -> void:
	var field := StubField.new()
	add_child(field)
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower(str(case["word"]),
		{"category": str(case["category"]), "is_unknown": true}, field)

	if tower.trait_id != str(case["trait"]):
		print("!! %s 는 %s 특성이 아니다 (실제: %s) — 측정 무효" % [
			str(case["word"]), str(case["trait"]), tower.trait_id])
		_failures += 1
		tower.free()
		field.free()
		return

	var r: float = tower.attack_range
	var primary = _spawn(field, Vector2(0.0, -r * 0.85))
	var cluster: Array = []
	for d in [18.0, 26.0, 34.0]:
		cluster.append(_spawn(field, Vector2(0.0, -r * 0.85) + Vector2(float(d), 0.0)))
	var far: Array = []
	for f in [0.25, 0.45, 0.65]:
		far.append(_spawn(field, Vector2(0.0, r * float(f))))

	field.enemies = [far[0], far[1], far[2], primary, cluster[0], cluster[1], cluster[2]]

	var targets: Array = tower.call("_trait_targets", primary)
	var damage: float = tower.damage_per_attack() * tower.damage_multiplier
	var shares: Array = tower.call("damage_shares", targets.size(), damage)

	print("")
	print("── %s (%s) ── 사거리 %.0f" % [
		TraitStyle.name_for(tower.trait_id), tower.trait_id, r])
	print("   계약: %s" % TraitStyle.desc_for(tower.trait_id))
	print("   배치: 사거리 안 7마리 — 먼쪽 3 (타워 %.0f~%.0fpx) · 주 타깃 %.0fpx · 밀집 3 (주 타깃에서 18~34px)" % [
		r * 0.25, r * 0.65, r * 0.85])

	var near_impact := 0
	var total := 0.0
	for i in targets.size():
		var t = targets[i]
		var from_tower: float = tower.global_position.distance_to(t.global_position)
		var from_primary: float = primary.global_position.distance_to(t.global_position)
		var kind := "주 타깃"
		if t != primary:
			if from_primary <= IMPACT_RADIUS:
				kind = "밀집"
				near_impact += 1
			else:
				kind = "먼쪽"
		total += float(shares[i])
		print("   %d. %-5s 타워 %5.0fpx · 주 타깃 %5.0fpx · 피해 %6.2f" % [
			i + 1, kind, from_tower, from_primary, float(shares[i])])

	print("   선택 %d마리 · 주 타깃 40px 안에서 뽑힌 적 %d마리 · 총 피해 %.2f (발당 %.2f)" % [
		targets.size(), near_impact, total, damage])
	# ⚠️ **위치 판정은 아직 계약이 아니다** — 설명과 로직이 어긋나는 §2.7 의 미결 항목이라
	#    기대값이 없다. 실패로 세면 프로브가 영원히 빨개지므로 눈에 띄게 표시만 한다.
	#
	# ⚠️ **그런데 두 특성은 같은 상태가 아니다 (2026-10-03 정정).** 여기서 재는 것은
	#    `_trait_targets()` 가 고르는 **발사 대상 목록**의 위치뿐이다. `control` 은 그 목록과
	#    **별개로** 착탄점 48px 반경 피해를 이미 갖고 있다(`Projectile.hit_target` 의
	#    `if slow_duration > 0.0:` 블록). 그래서 `control` 의 `near_impact == 0` 은 **정상**이고,
	#    이 줄이 둘 다 *"미결"* 로 찍으면 감독이 **잘못된 크기의 결정**을 내린다.
	#    실측은 `tools/ControlSplashProbe` 에 있다.
	# ✅ **splash 는 2026-10-14 계약이 됐다**(§4.2 감독 결정: 착탄점 기준). 추가 대상은
	#    전부 주 타깃 `SPLASH_RADIUS` 안이어야 하고, 밀집이 넉넉하니 상한(3+bonus)까지 채워야 한다.
	if tower.trait_id == "splash":
		var outside := 0
		for t in targets:
			if t != primary and primary.global_position.distance_to(t.global_position) > tower.SPLASH_RADIUS:
				outside += 1
		var cap: int = 3 + tower.bonus_targets
		if outside > 0 or targets.size() != cap:
			print("   !! 계약 위반 — 착탄점 밖 %d마리 · 선택 %d/%d" % [outside, targets.size(), cap])
			_failures += 1
	elif near_impact == 0 and tower.trait_id == "control":
		print("   참고 — 목록은 스폰 순서지만 `control` 은 **착탄점 48px 반경 피해를 따로 갖는다**")
		print("          (`tools/ControlSplashProbe` 실측: 반경 안 3/3 피해+둔화 · 밖 0)")

	tower.free()
	field.free()


## 2음절은 **다른 경로** 를 탄다: `_volley_targets()` + 발당 피해를 나누지 않는다.
## 같은 splash 인데 1음절과 2음절의 총 피해가 어떻게 달라지는지 확인한다.
func _measure_two_syllable() -> void:
	var field := StubField.new()
	add_child(field)
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	# "산가" 는 EXACT 도 키워드도 아니라 카테고리 폴백으로 splash 가 된다.
	tower.setup_tower("산가", {"category": "nature", "is_unknown": true}, field)

	print("")
	print("── 2음절 (%s) ── 발수 %d · 사거리 %.0f" % [
		tower.syllable, tower.volley_count(), tower.attack_range])
	if tower.trait_id != "splash":
		print("!! 2음절 측정용 단어가 splash 가 아니다 (실제: %s)" % tower.trait_id)
		_failures += 1
		tower.free()
		field.free()
		return

	var r: float = tower.attack_range
	var primary = _spawn(field, Vector2(0.0, -r * 0.85))
	var cluster: Array = []
	for d in [18.0, 26.0, 34.0]:
		cluster.append(_spawn(field, Vector2(0.0, -r * 0.85) + Vector2(float(d), 0.0)))
	var far: Array = []
	for f in [0.25, 0.45, 0.65]:
		far.append(_spawn(field, Vector2(0.0, r * float(f))))
	# 1음절 측정과 같은 배치·같은 순서를 쓴다 — 그래야 두 표를 나란히 놓을 수 있다.
	field.enemies = [far[0], far[1], far[2], primary, cluster[0], cluster[1], cluster[2]]

	var volley: int = tower.volley_count()
	var targets: Array = tower.call("_volley_targets", primary, volley)
	var damage: float = tower.damage_per_attack() * tower.damage_multiplier
	print("   계약: %s" % TraitStyle.desc_for(tower.trait_id))
	print("   발수 %d → 대상 %d마리, **발당 피해를 나누지 않는다** → 총 피해 %.2f" % [
		volley, targets.size(), damage * float(targets.size())])
	print("   (1음절은 3마리를 때려도 총 피해가 발당 피해와 같다 — 위 표의 총 피해 참고)")

	tower.free()
	field.free()


## 특성 전용 유물의 '대상 +1' 이 **긴 단어에도 걸리는지** 확인한다.
##
## 유물은 `bonus_targets` 를 올리고, 그 값은 `_trait_targets()` 의 상한에서만 읽힌다.
## 그런데 2음절 이상은 `attack_target()` 이 `_volley_targets()` 로 빠진다 —
## 유물이 올린 값이 그 경로에서는 아무 데도 안 쓰인다. 툴팁은 그 사실을 모른다.
func _measure_relic_on_long_word() -> void:
	print("")
	print("── 유물 '대상 +1' 이 긴 단어에도 걸리는가 (폭발의 뇌관) ──")
	for word in ["산", "산가", "산가나"]:
		var field := StubField.new()
		add_child(field)
		field.relic_ids = ["relic_blast_charge"]
		var tower = WordTowerScene.instantiate()
		add_child(tower)
		tower.setup_tower(str(word), {"category": "nature", "is_unknown": true}, field)
		if tower.trait_id != "splash":
			print("   !! %s 는 splash 가 아니다 (%s)" % [word, tower.trait_id])
			_failures += 1
			tower.free()
			field.free()
			continue

		tower.btn_select.mouse_entered.emit()
		var tooltip: String = tower.btn_select.tooltip_text
		var claimed := "(툴팁에 '동시 타격' 줄 없음)"
		for line in tooltip.split("\n"):
			if str(line).contains("동시 타격"):
				claimed = str(line)
		var claimed_num := _claimed_multi_hit(claimed)

		# 실제 경로를 태운다 — 사거리 안에 적 7마리를 두고 몇 마리를 고르는지 본다.
		var r: float = tower.attack_range
		var spawned: Array = []
		for i in 7:
			spawned.append(_spawn(field, Vector2(0.0, -r * 0.5) + Vector2(float(i) * 6.0, 0.0)))
		var primary = spawned[3]
		field.enemies = spawned

		var volley: int = tower.volley_count()
		var targets: Array
		if volley <= 1:
			targets = tower.call("_trait_targets", primary)
		else:
			targets = tower.call("_volley_targets", primary, volley)
		print("   %-4s (%d음절) bonus_targets=%d · 툴팁: \"%s\" · 실제 동시 타격 %d마리 %s" % [
			word, word.length(), tower.bonus_targets, claimed, targets.size(),
			"" if claimed_num == targets.size() else "  <-- 어긋남"])
		if claimed_num != targets.size():
			_failures += 1

		tower.free()
		field.free()


func _spawn(field: Node, pos: Vector2):
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.init_enemy("probe", 99999.0, 0.0, 0, "")
	field.enemies.append(enemy)
	return enemy

## 툴팁 줄(*"동시 타격 N마리"*)에서 **N 만** 뽑는다. 그런 줄이 없으면 -1.
##
## ⚠️ **`claimed.contains(str(n))` 로 대신하면 안 된다 (2026-10-03 고침).**
##    그것은 *"동시 타격 12마리"* 가 *"2"* 를 포함하므로 **참**이 된다 — 지금은
##    상한이 4라 안 걸리지만, 대상 수를 늘리는 기구가 생기면 **거짓 '일치'** 가 조용히 생긴다.
##    줄이 **아예 없으면** -1 이라 `targets.size()`(항상 ≥1)와 절대 같아지지 않는다 —
##    *"계약이 사라진 것"* 도 어긋남으로 잡힌다.
func _claimed_multi_hit(line: String) -> int:
	if not line.contains("동시 타격"):
		return -1
	var digits := line.get_slice("동시 타격 ", 1).get_slice("마리", 0).strip_edges()
	return digits.to_int() if digits.is_valid_int() else -1
