# 조준 "강적 우선" 의 **동점 처리**가 계약을 깨지 않는지 재는 판정형 프로브.
#
#   godot --headless --path . res://tools/TargetingTieBreakProbe.tscn
#
# 배경:
#   `WordTower._targeting_score()` 의 `strong` 은 `e.hp + e.progress * 0.001` 이고 주석은
#   *"체력이 같으면 기지에 가까운 쪽을 고른다 — 0.001 은 그 **동점 처리**용이다"* 라고 적는다.
#   그런데 `e.progress` 는 `PathFollow2D.progress` = **경로 위의 픽셀**이다(0~1 비율이 아니다).
#   그래서 `0.001` 은 epsilon 이 아니라 **경로길이 × 0.001 만큼의 HP 가산**이다(실측 1.2~1.7 HP).
#
#   그 가산이 **타입 사이 최소 HP 격차**(실측 4.2 HP, 제1막 1웨이브)보다 커지면
#   `strong` 이 *"체력이 가장 높은 적"* 대신 *"기지에 가까운 적"* 을 뽑기 시작한다 —
#   즉 라벨이 거짓이 된다. 지금은 **0.40배**로 안전하지만, `0.001` 을 `0.01` 로 바꾸면
#   곧바로 뒤집힌다(4배 초과). 그래서 이 여유를 **계약으로 잠근다**.
#
# ⚠️ 상수를 손으로 적지 않는다 — `WordTower.gd` **소스에서 읽는다.** 손으로 적으면
#    그 상수를 바꿨을 때 프로브만 옛 값을 보고 **영원히 초록**이 된다.
extends Node2D

const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const DefenseFieldScene = preload("res://scenes/tower/DefenseField.tscn")
const MonsterRosterScript = preload("res://scripts/tower/MonsterRoster.gd")

const WORD_TOWER_SRC := "res://scripts/tower/WordTower.gd"
## 소스에서 찾을 조각. `strong` 가지는 `e.progress * <상수>` 꼴이다.
const TIE_MARKER := "progress * "

## 타입 순서(HP 오름차순) — 인접 격차의 최소값이 곧 '타입 사이 최소 격차' 다.
const TYPE_ORDER: Array[String] = ["swarm", "fast", "normal", "armored", "boss"]

var failures := 0


class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []

	func has_relic(_id: String) -> bool:
		return false

	func get_enemies() -> Array:
		return enemies


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   %s" % msg)
	else:
		failures += 1
		print("  FAIL %s" % msg)


## `WordTower.gd` 소스에서 `progress * <숫자>` 의 숫자를 뽑는다. 못 찾으면 -1.
## ⚠️ 못 찾은 것을 '통과' 로 넘기면 안 된다 — 상수 이름이 바뀌는 순간 프로브가 눈이 먼다.
func _read_tie_break() -> float:
	var src := FileAccess.get_file_as_string(WORD_TOWER_SRC)
	if src == "":
		return -1.0
	var at := src.find(TIE_MARKER)
	if at < 0:
		return -1.0
	var i := at + TIE_MARKER.length()
	var num := ""
	while i < src.length():
		var c := src[i]
		if (c >= "0" and c <= "9") or c == ".":
			num += c
			i += 1
		else:
			break
	return num.to_float() if num != "" else -1.0


func _ready() -> void:
	await _run()
	get_tree().quit(failures)


func _run() -> void:
	print("=== S1 상수 출처 — 소스에서 읽는다 ===")
	var tie := _read_tie_break()
	print("  `%s` 의 `%s<숫자>` = %s" % [WORD_TOWER_SRC, TIE_MARKER, str(tie)])
	_check(tie > 0.0, "`WordTower.gd` 에서 동점 상수를 읽었다(못 읽으면 프로브가 눈이 먼다)")
	if tie <= 0.0:
		print("")
		print("TARGETING_TIEBREAK_PROBE_FAILED")
		return

	print("")
	print("=== S2 실제 경로 길이 (= progress 의 최대값) ===")
	# ⚠️ 필드를 Node2D 밑에 그냥 붙이면 부모 rect 가 0x0 이라 `map_to_screen` 이 쓰는
	#    필드 크기가 0 이 되어 경로가 뭉개진다 — 뷰포트 크기의 Control 에 담는다.
	var holder := Control.new()
	holder.size = get_viewport_rect().size
	add_child(holder)
	var df = DefenseFieldScene.instantiate()
	holder.add_child(df)
	await get_tree().process_frame
	await get_tree().process_frame

	var adds: Dictionary = {}
	for act in [1, 2, 3]:
		df.current_act = act
		df._layout_sanctuary()
		await get_tree().process_frame
		var path_2d = df.get_node_or_null("Path2D")
		var length := 0.0
		if path_2d != null and path_2d.curve != null:
			length = path_2d.curve.get_baked_length()
		adds[act] = length * tie
		print("  제 %d막 — 경로 %.0f px · 동점가산 = **%.2f HP**" % [act, length, adds[act]])
		_check(length > 100.0, "제 %d막 경로 길이를 쟀다(>100px)" % act)

	print("")
	print("=== S3 HP 격차와 맞대기 (act × wave) ===")
	print("  act wave |  swarm   fast normal armored   boss | 최소격차 | 동점가산")
	var worst_ratio := 0.0
	var worst_at := ""
	for act in [1, 2, 3]:
		for wave in range(1, 21):
			var hp_scale: float = df.hp_compensation_for(act, wave)
			var base: float = (10.0 + float(act) * 4.0) * hp_scale
			var ws: float = (1.0 + float(wave - 1) * 0.08) * df.wave_curve_for(wave)
			var asc: float = 1.0 + float(act - 1) * 0.5
			var hps: Array[float] = []
			for t in TYPE_ORDER:
				hps.append(base * float(MonsterRosterScript.TYPE_STATS[t]["hp"]) * ws * asc)
			var min_gap := 1e30
			for i in range(1, hps.size()):
				min_gap = minf(min_gap, hps[i] - hps[i - 1])
			var add: float = float(adds[act])
			var ratio := add / maxf(min_gap, 0.0001)
			if ratio > worst_ratio:
				worst_ratio = ratio
				worst_at = "제 %d막 %d웨이브" % [act, wave]
			# 계약: 가산이 타입 사이 최소 격차보다 **작아야** 한다. 그래야
			#       '가장 센 타입' 을 절대 놓치지 않는다.
			if add >= min_gap:
				failures += 1
				print("  ★위반 %d막 %d웨이브 — 가산 %.2f ≥ 최소격차 %.2f" % [act, wave, add, min_gap])
			if wave <= 1 or wave == 20:
				print("  %3d %4d | %6.1f %6.1f %6.1f %7.1f %6.1f | %8.2f | %8.2f%s" % [
					act, wave, hps[0], hps[1], hps[2], hps[3], hps[4], min_gap, add,
					"  ★" if add >= min_gap else ""])
	print("  ⭐ 최악 비율(가산 ÷ 최소 HP격차) = **%.2f** (%s)" % [worst_ratio, worst_at])
	_check(worst_ratio < 1.0, "동점가산이 타입간 최소 HP격차보다 작다 (실측 %.2f < 1.0)" % worst_ratio)

	print("")
	print("=== S4 실제로 뒤집히는가 — 두 적을 세워 `find_target()` 을 부른다 ===")
	var field := StubField.new()
	add_child(field)
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	tower.attack_range = 100000.0
	tower.set_targeting_mode("strong")

	# 제 1막 길이를 다시 잰다 — 위 루프가 3막으로 끝났기 때문이다.
	df.current_act = 1
	df._layout_sanctuary()
	await get_tree().process_frame
	var path_2d1 = df.get_node_or_null("Path2D")
	var length1 := 0.0
	if path_2d1 != null and path_2d1.curve != null:
		length1 = path_2d1.curve.get_baked_length()
	var add1: float = length1 * tie

	for label in ["가산의 0.5배", "가산의 2배"]:
		var gap: float = add1 * (0.5 if label.contains("0.5") else 2.0)
		var a = EnemyUnitScene.instantiate()
		add_child(a)
		a.init_enemy("A", 100.0, 0.0, 0, "")
		a.progress = length1
		a.hp = 50.0
		a.global_position = Vector2(500, 500)

		var b = EnemyUnitScene.instantiate()
		add_child(b)
		b.init_enemy("B", 100.0, 0.0, 0, "")
		b.progress = 0.0
		b.hp = 50.0 + gap
		b.global_position = Vector2(500, 500)

		field.enemies = [a, b]
		var picked = tower.find_target()
		var picked_hp: float = -1.0 if picked == null else float(picked.hp)
		var max_hp: float = float(b.hp)
		print("  HP격차 %.2f (%s) — 뽑힌 적 HP %.2f / 최대 %.2f → %s" % [
			gap, label, picked_hp, max_hp,
			"최대 HP" if picked_hp >= max_hp - 0.0001 else "더 약한 적"])
		if label.contains("2배"):
			# 가산보다 큰 격차에서는 **반드시** 최대 HP 를 뽑아야 한다 = 라벨이 참인 구간.
			_check(picked_hp >= max_hp - 0.0001, "격차가 가산보다 크면 최대 HP 를 뽑는다")
		else:
			# 가산보다 작은 격차에서는 뒤집힌다 — **설계상 그렇다**(0.83 HP 차이는
			# 실제 타입간 최소격차 4.2 HP 안쪽이라 게임에서는 도달하지 않는다).
			print("       (이 구간의 뒤집힘은 설계상 정상 — 실제 최소 타입격차 %.2f HP 안쪽)" % 4.2)
		a.free()
		b.free()

	print("")
	print("=== S5 기존 테스트가 이걸 볼 수 있는가 ===")
	print("  `test_tower_traits._test_targeting_modes_pick_different_enemies` 는")
	print("  `heavy.hp = 80` vs `ahead.hp = 10`(격차 70) · progress 900 → 가산 0.9.")
	print("  → 격차가 가산의 **78배**라 동점 처리는 그 테스트로 절대 안 잡힌다.")
	print("  → 그래서 이 프로브가 따로 필요하다.")

	print("")
	if failures == 0:
		print("TARGETING_TIEBREAK_PROBE_OK")
	else:
		print("TARGETING_TIEBREAK_PROBE_FAILED — 위반 %d" % failures)
