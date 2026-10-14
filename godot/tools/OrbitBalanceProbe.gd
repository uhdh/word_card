# tools/OrbitBalanceProbe.gd — 선회(orbit) 특성의 실제 기여도를 측정한다.
#
# 왜 필요한가: "선회가 너무 안좋다" 는 판단은 지금까지 코드를 읽고 내린 추정이었다.
# TRAIT_INTERVAL["orbit"] = 0.9 가 표에 있지만 선회는 그 값을 **쓰지 않는다**
# (TowerOrbit 이 PER_ENEMY_COOLDOWN 으로 스스로 때린다). 즉 다른 특성과 같은
# 자로 잴 수 없고, 재 보지 않으면 얼마나 약한지도 모른다.
#
# 재는 방법: 실제 맵의 경로 점과 발판 좌표를 그대로 쓰고, 적 한 마리가
# 발판 앞을 **걸어서 지나가는 동안** 각 특성이 넣는 총 피해를 계산한다.
#   - 투사체형: (사거리 안에 머문 시간 / 발사 간격) × 발수 × 발당 피해
#   - 선회: 궤도를 실제로 돌려서 닿은 횟수를 센다 (같은 경로·같은 속도)
#
# 주의 — 평균을 낼 때 '사거리 안에 드는 발판' 만 세면 안 된다. 그러면 사거리가
# 긴 특성은 '별로 안 좋은 발판' 까지 평균에 넣고, 짧은 특성은 '잘 맞는 발판' 만
# 넣어서 서로 다른 표본을 비교하게 된다. 그래서 **33개 발판 전부**를 같은
# 표본으로 쓰고, 커버리지가 0 인 발판은 0 으로 센다.
extends Node

const WordTowerScript = preload("res://scripts/tower/WordTower.gd")
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const TowerOrbitScript = preload("res://scripts/tower/TowerOrbit.gd")

## 적이 지나가는 속도(px/s). EnemyUnit.speed 기본값.
const ENEMY_SPEED := 80.0
## 시뮬레이션 한 스텝(초). 60fps 와 같게 둔다.
const STEP := 1.0 / 60.0
## 선회 시작 각도가 무작위라 한 번 재면 운이 섞인다. 여러 번 돌려 평균낸다.
const ORBIT_TRIALS := 16

const TRAITS := [
	"orbit", "sniper", "rapid", "pierce", "chain",
	"splash", "damage_over_time", "control", "meteor", "bounce",
]


## 피해만 세는 적. **진짜 EnemyUnit 을 상속한다** — TowerOrbit._hit 이 인자를
## EnemyUnit 으로 타입 검사하기 때문이다. 상속하지 않으면 매 타격마다 타입 에러가
## 나고 피해가 0 으로 기록된다(처음에 그렇게 재서 '선회 피해 0.0' 이 나왔다).
##
## take_damage 만 갈아끼운다: 원본은 피격 연출·사운드·피해 숫자를 부르는데,
## 트리에 없는 노드로 그걸 돌리면 측정이 아니라 잡음이 된다.
## damage_multiplier_for 는 **원본을 그대로 쓴다** — 속성 상성표까지 반영해야 한다.
class DummyEnemy extends EnemyUnit:
	var taken := 0.0
	var hits := 0

	# ⚠️ **부모 시그니처와 정확히 같아야 한다.** 2026-10-01 에 `EnemyUnit.take_damage()` 가
	#    `is_crit: bool = false` 를 얻었고(§2.21-7), 이 오버라이드만 4개인 채로 남아
	#    **파스 오류**가 났다 — *"The function signature doesn't match the parent"*.
	#    ⚠️ 파스 오류는 프로브를 **매단다**(rc=124, stdout 무출력 · 진단은 stderr).
	#    이 프로브는 `run_all.sh` 에 없어서 **아무도 몰랐다**(2026-10-01 전수 스윕이 잡았다).
	#    **부모가 인자를 얻으면 오버라이드도 같은 커밋에서 고쳐라.**
	func take_damage(amount: float, _show_hit_sound: bool = true, _mult: float = 1.0,
			_pool: bool = false, _is_crit: bool = false) -> float:
		taken += amount
		hits += 1
		return amount


class StubField extends Node:
	var enemies: Array = []
	var relic_ids: Array = []

	func has_relic(_id: String) -> bool:
		return false

	func get_enemies() -> Array:
		return enemies

	func record_tower_damage(_name: String, _amount: float) -> void:
		pass


func _ready() -> void:
	var field = DefenseFieldScript.new()
	var pads := _all_pads()

	print("=== 발판 %d개 전부를 같은 표본으로 쓴다 (적 속도 %.0f px/s) ===" % [pads.size(), ENEMY_SPEED])
	print("")

	for length in [1, 2, 3]:
		print("── %d음절 ────────────────────────────────────────────────────────" % length)
		var rows: Array = []
		for trait_id in TRAITS:
			rows.append(_measure_trait(field, pads, trait_id, length))
		rows.sort_custom(func(a, b): return float(a["mean"]) > float(b["mean"]))
		var best_mean := float(rows[0]["mean"])
		for r in rows:
			print("  %-14s 사거리 %5.0f | 평균 %7.1f (%4.0f%%) | 최고발판 %7.1f | 머문시간(평균) %4.2fs %s" % [
				r["label"], r["range"], r["mean"], float(r["mean"]) / maxf(best_mean, 0.001) * 100.0,
				r["max"], r["time"], r["note"]])
		print("")

	print("=== 선회가 가장 잘 맞는 발판 vs 그 발판에서의 다른 특성 ===")
	var best_pad := _best_orbit_pad(field, pads)
	print("  발판: 제%d막 %d번 (좌표 %s)" % [best_pad["act"], best_pad["pad"] + 1, str(best_pad["center"])])
	print("  선회 머문시간 %.2fs" % best_pad["time"])
	var on_pad: Array = []
	for trait_id in TRAITS:
		var d := _damage_on_pad(field, best_pad["act"], best_pad["pad"], trait_id, 1, 1)
		on_pad.append({"trait": trait_id, "damage": d,
			"label": str(WordTowerScript.TRAIT_NAMES.get(trait_id, trait_id))})
	on_pad.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))
	for r in on_pad:
		print("    %-14s %7.1f" % [r["label"], r["damage"]])
	print("")

	print("=== 선회의 다중 대상 (1막 최고 발판, 적이 줄지어 통과) ===")
	for count in [1, 2, 4, 6]:
		var total := 0.0
		for trial in range(ORBIT_TRIALS):
			total += _orbit_run(field, best_pad["act"], best_pad["pad"], 1, count, "")["damage"]
		print("  적 %d마리 → 총 피해 %6.1f (마리당 %5.1f)" % [
			count, total / float(ORBIT_TRIALS), total / float(ORBIT_TRIALS) / float(count)])

	print("")
	print("=== 속성 배율 (1음절, 최고 발판, 적 1마리) ===")
	for type_id in ["", "armored", "swarm"]:
		var total := 0.0
		for trial in range(ORBIT_TRIALS):
			total += _orbit_run(field, best_pad["act"], best_pad["pad"], 1, 1, str(type_id))["damage"]
		var label: String = "보통(1.0)" if type_id == "" else str(type_id)
		print("  %-12s → %6.1f" % [label, total / float(ORBIT_TRIALS)])

	print("")
	print("=== 제자리에 서 있는 적을 3초 동안 때린 횟수 (궤도가 한 바퀴라도 도는가) ===")
	print("   적이 궤도 위에 정지해 있을 때. '지나가는' 적보다 훨씬 유리한 조건이다.")
	for length in [1, 2, 3]:
		var r := _stationary_hits(length, 3.0)
		print("  %d음절(오브 %d개) → 3.0초에 %5.1f대, 피해 %6.1f" % [
			length, r["orbs"], r["hits"], r["damage"]])

	print("")
	print("=== 궤도 반지름을 바꿔 보면 (선회 최고 발판, 1음절, 적 1마리) ===")
	print("   오브는 '반지름 r 인 원 위' 를 돈다. 적이 그 원에서 멀면 영영 못 맞는다.")
	print("   적이 타워에 가까이 붙을수록 원 **안쪽**으로 들어가므로, 원이 크면")
	print("   코앞을 지나는 적을 못 때리는 역전이 생긴다.")
	for r in [40, 48, 56, 64, 76, 92, 110]:
		var total := 0.0
		for trial in range(ORBIT_TRIALS):
			total += _orbit_run(field, best_pad["act"], best_pad["pad"], 1, 1, "", float(r))["damage"]
		print("    반지름 %5.1f → 피해 %6.1f" % [float(r), total / float(ORBIT_TRIALS)])

	print("")
	print("=== 적이 타워 바로 옆(경로 최근접)을 지날 때 ===")
	var near := _nearest_path_distance(field, best_pad["act"], best_pad["pad"])
	print("   이 발판에서 경로가 타워에 가장 가까운 거리: %.1fpx (궤도 반지름 76)" % near)
	print("   → 오브와 적의 최소 거리 %.1fpx (판정 한계 %.1fpx)" % [
		absf(76.0 - near), float(TowerOrbitScript.HIT_RADIUS) + float(TowerOrbitScript.HIT_SLACK)])
	for r in [40, 48, 56, 64, 76]:
		var gap := absf(float(r) - near)
		print("     반지름 %5.1f → 최소 거리 %5.1f %s" % [
			float(r), gap,
			"닿음" if gap <= float(TowerOrbitScript.HIT_RADIUS) + float(TowerOrbitScript.HIT_SLACK) else "**영영 못 맞음**"])

	field.free()
	print("")
	print("PROBE DONE")
	get_tree().quit(0)


## 궤도 위에 정지한 적 하나를 sec 초 동안 때린 횟수.
## '오브가 적을 지나가는가' 라는 단 하나의 성질만 본다 — 경로·발판과 무관하다.
func _stationary_hits(length: int, sec: float) -> Dictionary:
	var field_stub = StubField.new()
	var tower = WordTowerScript.new()
	tower.position = Vector2.ZERO
	# 음절은 **setup_tower 에 통째로** 넘긴다. 나중에 syllable 만 바꾸고
	# _setup_attack_style() 을 다시 부르면, 예전 궤도 노드가 queue_free 로
	# 아직 살아 있어 get_node_or_null("Orbit") 이 **낡은 노드** 를 돌려준다.
	# (그래서 한동안 모든 음절이 '오브 1개' 로 측정됐다 — 긴 단어 보상이
	#  통째로 안 보였고, 그걸 선회의 문제로 오해할 뻔했다)
	tower.setup_tower("가".repeat(length),
		{"category": "summon", "damage": 4, "is_unknown": true}, field_stub)
	var orbit = tower.get_node_or_null("Orbit")
	if orbit == null:
		tower.free()
		field_stub.free()
		return {"hits": 0.0, "damage": 0.0, "orbs": 0}

	# 적을 궤도 위(각도 0)에 정확히 세운다 — 오브가 반드시 스쳐 가는 자리다.
	var e = DummyEnemy.new()
	e.enemy_type = ""
	e.hp = 100000.0
	e.global_position = Vector2(orbit.orbit_radius, 0.0)
	field_stub.enemies = [e]

	var steps := int(sec / STEP)
	for i in range(steps):
		orbit._process(STEP)

	var out := {"hits": float(e.hits), "damage": e.taken, "orbs": orbit.orb_count}
	tower.free()
	field_stub.free()
	return out


## 3개 막 × 11개 발판 = 33개. 순서는 고정이다(모든 특성이 같은 순서를 쓴다).
func _all_pads() -> Array:
	var out: Array = []
	for act in [1, 2, 3]:
		var slots: Array = DefenseFieldScript.ACT_SLOTS[act]
		for pad in range(slots.size()):
			out.append({"act": act, "pad": pad, "center": slots[pad]})
	return out


func _measure_trait(field, pads: Array, trait_id: String, length: int) -> Dictionary:
	var range_px := float(WordTowerScript.TRAIT_RANGE.get(trait_id, 150.0))
	var damage_sum := 0.0
	var time_sum := 0.0
	var best := 0.0
	for p in pads:
		var covered := float(field.pad_coverage(int(p["act"]), int(p["pad"]), range_px))
		time_sum += covered / ENEMY_SPEED
		var d := _damage_on_pad(field, int(p["act"]), int(p["pad"]), trait_id, length, 1)
		damage_sum += d
		best = maxf(best, d)
	var note := ""
	if trait_id == "orbit":
		note = "(궤도 시뮬레이션 %d회 평균)" % ORBIT_TRIALS
	return {
		"trait": trait_id,
		"label": str(WordTowerScript.TRAIT_NAMES.get(trait_id, trait_id)),
		"range": range_px,
		"mean": damage_sum / float(pads.size()),
		"max": best,
		"time": time_sum / float(pads.size()),
		"note": note,
	}


## 발판 하나에서 적 1마리가 지나가는 동안의 총 피해.
func _damage_on_pad(field, act: int, pad: int, trait_id: String, length: int, count: int) -> float:
	if trait_id == "orbit":
		var total := 0.0
		for trial in range(ORBIT_TRIALS):
			total += _orbit_run(field, act, pad, length, count, "")["damage"]
		return total / float(ORBIT_TRIALS)

	var range_px := float(WordTowerScript.TRAIT_RANGE.get(trait_id, 150.0))
	var interval := float(WordTowerScript.TRAIT_INTERVAL.get(trait_id, 0.8))
	var interval_mult: float = float(WordTowerScript.INTERVAL_MULT_BY_LENGTH[length - 1])
	var volley: int = int(WordTowerScript.VOLLEY_BY_LENGTH[length - 1])
	var base: float = float(WordTowerScript.BASE_DAMAGE_BY_LENGTH[length - 1])
	var covered := float(field.pad_coverage(act, pad, range_px))
	var time_in_range := covered / ENEMY_SPEED
	var shots := time_in_range / (interval * interval_mult)
	return shots * float(volley) * base * _trait_mult(trait_id) * float(count)


## WordTower.damage_per_attack() 의 배율만 뽑는다 — 단일 출처는 저기다.
## 표를 여기 베껴 두면 밸런스를 고칠 때마다 프로브가 조용히 거짓말을 한다.
## base_damage 를 1.0 으로 두면 반환값이 곧 배율이다.
func _trait_mult(trait_id: String) -> float:
	var tower = WordTowerScript.new()
	tower.trait_id = trait_id
	tower.base_damage = 1.0
	var mult: float = tower.damage_per_attack()
	tower.free()
	return mult


## 경로가 발판 중심에 가장 가까이 오는 거리(px).
## '궤도 원이 적의 통행선과 겹치는가' 를 판단하는 값이다.
func _nearest_path_distance(field, act: int, pad: int) -> float:
	var slots: Array = DefenseFieldScript.ACT_SLOTS[act]
	var center: Vector2 = slots[pad]
	var path_data: Dictionary = field._densified_path(act)
	var pts: Array = path_data["pts"]
	var best := 99999.0
	for p in pts:
		best = minf(best, center.distance_to(p))
	return best


## 선회가 가장 잘 맞는 발판을 고른다 (커버리지가 아니라 실제 피해 기준).
func _best_orbit_pad(field, pads: Array) -> Dictionary:
	var best := {"act": 1, "pad": 0, "center": Vector2.ZERO, "damage": -1.0, "time": 0.0}
	for p in pads:
		var d := _damage_on_pad(field, int(p["act"]), int(p["pad"]), "orbit", 1, 1)
		if d > float(best["damage"]):
			best = {
				"act": int(p["act"]), "pad": int(p["pad"]), "center": p["center"],
				"damage": d,
				"time": float(field.pad_coverage(int(p["act"]), int(p["pad"]),
					float(WordTowerScript.TRAIT_RANGE["orbit"]))) / ENEMY_SPEED,
			}
	return best


## 선회 하나를 실제 경로 위에서 돌려 본다.
## 적 count 마리를 경로 방향으로 gap px 간격으로 세우고, 발판 앞 구간을 걸어 지나간다.
## enemy_type 은 ""(보통) / "armored" / "swarm" — 배율은 진짜 표를 그대로 쓴다.
func _orbit_run(field, act: int, pad: int, length: int, count: int, enemy_type: String,
		radius_override := 0.0) -> Dictionary:
	var slots: Array = DefenseFieldScript.ACT_SLOTS[act]
	var center: Vector2 = slots[pad]
	var path_data: Dictionary = field._densified_path(act)
	var pts: Array = path_data["pts"]
	var range_px := float(WordTowerScript.TRAIT_RANGE["orbit"])

	# 사거리 안에 드는 첫/마지막 경로 지점.
	var first := -1
	var last := -1
	for i in range(pts.size()):
		if center.distance_to(pts[i]) <= range_px:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return {"damage": 0.0, "hits": 0}

	var field_stub = StubField.new()
	var tower = WordTowerScript.new()
	tower.position = center
	# 음절은 setup_tower 에 통째로 넘긴다 (위 _stationary_hits 의 주석 참고).
	tower.setup_tower("가".repeat(length),
		{"category": "summon", "damage": 4, "is_unknown": true}, field_stub)
	var orbit = tower.get_node_or_null("Orbit")
	if orbit == null:
		tower.free()
		field_stub.free()
		return {"damage": 0.0, "hits": 0}
	if radius_override > 0.0:
		orbit.orbit_radius = radius_override

	var enemies: Array = []
	for i in range(count):
		var e = DummyEnemy.new()
		e.enemy_type = enemy_type
		e.hp = 100000.0
		enemies.append(e)
	field_stub.enemies = enemies

	# 경로를 1px 간격으로 훑는다. 적은 각자 gap 만큼 뒤에서 출발한다.
	var gap := 26.0
	var cursor := float(first)
	var end := float(last) + gap * float(count)
	while cursor <= end:
		for i in range(count):
			var c := cursor - gap * float(i)
			if c < 0.0 or c > float(pts.size() - 1):
				continue
			var idx := int(floor(c))
			var frac := c - float(idx)
			var a: Vector2 = pts[idx]
			var b: Vector2 = pts[mini(idx + 1, pts.size() - 1)]
			enemies[i].global_position = a.lerp(b, frac)
		orbit._process(STEP)
		cursor += ENEMY_SPEED * STEP

	var damage := 0.0
	var hits := 0
	for e in enemies:
		damage += e.taken
		hits += e.hits
	tower.free()
	field_stub.free()
	return {"damage": damage, "hits": hits}
