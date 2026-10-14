# EconomyProbe.gd
# 한 런(3막 60웨이브)의 골드 수입/지출을 실측한다.
#
# 전투를 시뮬레이션하지 않고 **실제 DefenseField 함수**에서 직접 뽑는다:
#   - 수입: _build_wave_monsters() 가 만든 spawn_queue 의 gold 합 + _wave_clear_bonus()
#   - 지출: JamoBelt 의 누진 시세를 그대로 재현
# 이래야 "적을 몇 마리 잡았는가" 같은 추정 없이 실제 수치가 나온다.
#
# 실행 (headless 가능):
#   cd godot && godot --headless --path . res://tools/EconomyProbe.tscn

extends Node

const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const ShopModalScript = preload("res://scripts/ui/ShopModal.gd")

const MAX_ACTS := 3
const MAX_WAVES := 20
const START_GOLD := 40
const BELT_CAP := 30

# JamoBelt 와 같은 값이어야 한다. 바뀌면 여기도 바꾼다.
const BASE_TILE_PRICE := 10
const PRICE_STEP := 1


func _ready() -> void:
	var rows := _collect_income()
	_report_income(rows)
	_report_policies(rows)
	_report_relics()
	_report_sweep(rows)
	get_tree().quit(0)


## 웨이브별 수입을 실제 함수에서 뽑아 온다.
func _collect_income() -> Array:
	var field = DefenseFieldScript.new()
	var rows: Array = []
	for act in range(1, MAX_ACTS + 1):
		for wave in range(1, MAX_WAVES + 1):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			var enemy_gold := 0
			for enemy in field.spawn_queue:
				enemy_gold += int(enemy["gold"])
			field.current_act = act
			field.current_wave = wave
			rows.append({
				"act": act,
				"wave": wave,
				"enemy": enemy_gold,
				"bonus": field._wave_clear_bonus(),
				"count": field.spawn_queue.size()
			})
	field.free()
	return rows


func _report_income(rows: Array) -> void:
	var total := 0
	var per_act := {}
	for row in rows:
		var gain: int = int(row["enemy"]) + int(row["bonus"])
		total += gain
		per_act[int(row["act"])] = int(per_act.get(int(row["act"]), 0)) + gain

	print("\n=== 웨이브 수입 (적 처치 + 라운드 보상) ===")
	print("시작 골드 %dG" % START_GOLD)
	for act in range(1, MAX_ACTS + 1):
		print("  %d막: %4dG  (웨이브당 평균 %.1fG)" % [act, per_act[act], float(per_act[act]) / MAX_WAVES])
	print("  한 런 총수입: %dG  (시작 골드 포함 %dG)" % [total, total + START_GOLD])

	var head := rows.slice(0, 5)
	var tail := rows.slice(rows.size() - 5, rows.size())
	var line := ""
	for row in head:
		line += " %d막%d웨이브:%dG" % [int(row["act"]), int(row["wave"]), int(row["enemy"]) + int(row["bonus"])]
	print("  초반:%s" % line)
	line = ""
	for row in tail:
		line += " %d막%d웨이브:%dG" % [int(row["act"]), int(row["wave"]), int(row["enemy"]) + int(row["bonus"])]
	print("  후반:%s" % line)


## 정책별로 타일을 몇 장 사고 얼마가 남는지.
func _report_policies(rows: Array) -> void:
	print("\n=== 구매 정책별 결과 (타일 상한 %d장) ===" % BELT_CAP)
	print("%-26s %6s %8s %9s %9s %7s" % ["정책", "타일", "타일지출", "남은골드", "상한도달", "남은비율"])

	var policies := [
		{"name": "누진 · 라운드당 1장", "reserve": 0, "per_round": 1, "escalating": true},
		{"name": "누진 · 매 라운드 최대", "reserve": 0, "per_round": 99, "escalating": true},
		{"name": "고정가 10G · 라운드당 1장", "reserve": 0, "per_round": 1, "escalating": false},
		{"name": "고정가 10G · 매 라운드 최대", "reserve": 0, "per_round": 99, "escalating": false},
	]
	for policy in policies:
		var result := _simulate(rows, int(policy["reserve"]), int(policy["per_round"]), bool(policy["escalating"]))
		var income: int = int(result["gold"]) + int(result["spent"])
		print("%-26s %6d %7dG %8dG %9s %6.0f%%" % [
			policy["name"], int(result["tiles"]), int(result["spent"]),
			int(result["gold"]),
			("없음" if int(result["cap_round"]) < 0 else "%d라운드" % int(result["cap_round"])),
			100.0 * float(result["gold"]) / maxf(1.0, float(income))
		])

	# 병목이 '가격' 인지 '상한' 인지 구분한다. 상한을 없애면 누진 가격이
	# 실제로 얼마나 더 빨아들이는지 볼 수 있다.
	var uncapped := _simulate(rows, 0, 1, true, 999)
	print("\n  타일 상한이 없고 누진 가격이면: %d장 구매 / %dG 지출 / %dG 잔여"
		% [int(uncapped["tiles"]), int(uncapped["spent"]), int(uncapped["gold"])])
	print("  → 지출을 막는 건 가격이 아니라 %d장 상한이다." % BELT_CAP)


func _simulate(rows: Array, reserve: int, per_round: int, escalating: bool, cap: int = BELT_CAP) -> Dictionary:
	var gold := START_GOLD
	var tiles := 0
	var spent := 0
	var cap_round := -1
	var act_end := {}
	for row in rows:
		gold += int(row["enemy"]) + int(row["bonus"])
		var bought := 0
		while bought < per_round and tiles < cap:
			var price := (BASE_TILE_PRICE + tiles * PRICE_STEP) if escalating else BASE_TILE_PRICE
			if gold - reserve < price:
				break
			gold -= price
			spent += price
			tiles += 1
			bought += 1
		if cap_round < 0 and tiles >= cap:
			cap_round = int(row["act"] - 1) * MAX_WAVES + int(row["wave"])
		if int(row["wave"]) == MAX_WAVES:
			act_end[int(row["act"])] = gold
	return {
		"gold": gold, "tiles": tiles, "spent": spent,
		"cap_round": cap_round, "act_end": act_end
	}


func _report_relics() -> void:
	var pool := ShopModalScript.ALL_RELIC_POOL
	var cheapest := 9999
	var dearest := 0
	var sum := 0
	for relic in pool:
		var cost: int = int(relic["cost"])
		cheapest = mini(cheapest, cost)
		dearest = maxi(dearest, cost)
		sum += cost
	print("\n=== 유물 (%d종, %d~%dG, 전부 사면 %dG) ===" % [pool.size(), cheapest, dearest, sum])
	print("  한 런에 유물 6개를 산다면 약 %dG" % (sum / pool.size() * 6))


## 타일 한 장씩 값을 올려 가며 n장 사는 총액.
func _tile_cost(step: int, count: int) -> int:
	var total := 0
	for i in range(count):
		total += BASE_TILE_PRICE + i * step
	return total


## 주어진 예산으로 상한까지 몇 장 살 수 있는지.
func _affordable(step: int, cap: int, budget: int) -> Dictionary:
	var gold := budget
	var n := 0
	while n < cap:
		var price := BASE_TILE_PRICE + n * step
		if gold < price:
			break
		gold -= price
		n += 1
	return {"tiles": n, "spent": budget - gold, "left": gold}


## 인상 폭(step)과 타일 상한(cap)을 바꿔 보며 병목을 찾는다.
func _report_sweep(rows: Array) -> void:
	var income := START_GOLD
	for row in rows:
		income += int(row["enemy"]) + int(row["bonus"])

	const RELIC_BUDGET := 300
	var budget := income - RELIC_BUDGET

	print("\n=== 인상 폭 / 상한 스윕 ===")
	print("수입 %dG · 유물 예산 %dG 를 떼고 타일에 쓸 수 있는 돈 %dG" % [income, RELIC_BUDGET, budget])
	print("%-7s %-7s %8s %9s %9s %9s" % ["인상폭", "상한", "구매가능", "타일지출", "남는돈", "장당평균"])
	for step in [1, 2, 3]:
		for cap in [30, 45]:
			var result := _affordable(step, cap, budget)
			var tiles: int = int(result["tiles"])
			print("%-7s %-7s %7d장 %8dG %8dG %8.1f" % [
				"+%dG" % step, "%d장" % cap, tiles, int(result["spent"]),
				int(result["left"]), float(result["spent"]) / maxf(1.0, float(tiles))
			])
	print("\n  30장 기준 총액: +1G=%dG / +2G=%dG / +3G=%dG"
		% [_tile_cost(1, 30), _tile_cost(2, 30), _tile_cost(3, 30)])
	print("  참고: 타일 상한은 %d장이고, 누진 +1G 로 30장을 채우면 34라운드에 상한이 찬다." % BELT_CAP)
	print("        남은 26라운드 동안에는 타일로 골드를 쓸 곳이 아예 없다.")
