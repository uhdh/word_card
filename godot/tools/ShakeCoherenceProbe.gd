extends Node
# 한 사건이 두 노드를 흔들 때, 둘이 **같은 방향으로** 움직이는가.
# (감사 §2.4 문제 2 / §4.5 불일치 "보스 등장 흔들림 — Juice.shake 를 2개 노드에 동시 호출")
#
# 왜 문제인가:
#   `DefenseField` 는 보스 등장(`:910`)과 기지 피격(`:1136`)에서 **두 노드**를 흔든다.
#
#       Juice.shake(self, 9.0, 0.35)                  # 필드
#       Juice.shake(tower_slots_container, 6.0, 0.3)  # $TowerSlots — **self 의 자식**
#
#   그런데 `Juice.shake()` 는 호출마다 **자기만의 RNG** 를 만든다(`Juice.gd:27-28`).
#   그래서 두 노드는 **서로 무관한 방향**으로 흔들린다. 한 사건인데 화면에서는
#   두 물체가 따로 흔들리는 것으로 읽힌다 — "충격" 이 아니라 "떨림" 이다.
#
#   게다가 자식이라 **오프셋이 합성된다**: 자식의 화면상 변위 = 부모 변위 + 자기 변위.
#   최악의 경우 9 + 6 = 15 로, **부모(9)보다 크게** 흔들린다. "컨테이너는 약하게(6)"
#   라는 의도와 **반대**다.
#
# ⚠️ 감사 문서의 주장은 **가설**이다 — 여기서 실측한다. 재는 것:
#   §0 기준선 — 흔들림이 실제로 일어났는가 (아니면 아래 수치는 전부 무의미하다)
#   §1 두 노드가 **반대 방향**으로 간 프레임이 있는가 (독립 RNG 의 결정적 증거)
#   §2 평균 방향 일치도 (cosine) — 한 충격이면 1.0 에 가깝다
#   §3 자식이 부모보다 **크게** 흔들리는가 (합성으로 의도가 뒤집혔는지)
#   §4 실제 진입점 두 곳(보스 등장·기지 피격)이 **같은 패턴**인가
#
# 실행: godot --headless --path . res://tools/ShakeCoherenceProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 이보다 작은 변위는 방향을 논하지 않는다 — 0 에 가까운 벡터의 각도는 잡음이다.
const MIN_MAG := 0.6
## 한 충격이면 방향이 **완전히 같다**(같은 오프셋 × 다른 배율). 여유를 조금 둔다.
const MIN_AGREEMENT := 0.95
## 흔들림이 끝나기를 기다리는 프레임 상한(헤드리스는 프레임이 아주 짧을 수 있다).
const MAX_FRAMES := 4000
## 한 충격이면 두 노드의 오프셋은 **평행**하다(같은 오프셋 × 다른 배율). 각도로 환산한 상한.
const MAX_WORST_DEG := 8.0

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 두 노드의 위치를 흔들림이 끝날 때까지 매 프레임 모은다.
## 돌려주는 것: {"p": [Vector2…], "c": [Vector2…]} — 기준 위치에서의 **오프셋**.
func _sample_shake(parent: Node, child: Node, trigger: Callable) -> Dictionary:
	var p_base: Vector2 = parent.position
	var c_base: Vector2 = child.position
	trigger.call()
	var p_off: Array = []
	var c_off: Array = []
	var frames := 0
	while frames < MAX_FRAMES:
		await get_tree().process_frame
		p_off.append(parent.position - p_base)
		c_off.append(child.position - c_base)
		frames += 1
		# 두 노드 모두 메타가 풀리면 끝난 것이다(되돌림 트윈까지 끝난 시점).
		if not parent.has_meta("_juice_shaking") and not child.has_meta("_juice_shaking"):
			break
	return {"p": p_off, "c": c_off, "frames": frames}

## 방향 일치도·반대 프레임·**최악 각도**. 둘 다 MIN_MAG 위일 때만 판정한다.
##
## ⚠️ 왜 평균(§2)만으로 부족한가: 평균 cosine 은 **한 프레임이 90° 로 어긋난 것**을 가린다.
##   한 충격이라면 **모든** 프레임이 같은 방향이어야 하므로 **최악 프레임**을 따로 잰다(§3).
##
## ⚠️ `absf(dot)` 를 쓰면 **안 된다**(첫 판이 그랬다): 정반대(180°)가 0° 로 계산돼
##   **가장 나쁜 경우가 가장 좋은 것처럼** 보인다. `acos(dot)` 그대로 써야
##   평행 0° · 직각 90° · 정반대 180° 가 된다.
func _coherence(p_off: Array, c_off: Array) -> Dictionary:
	var opposed := 0
	var judged := 0
	var total := 0.0
	var worst_deg := 0.0
	var max_p := 0.0
	var max_c := 0.0
	for i in range(mini(p_off.size(), c_off.size())):
		var p: Vector2 = p_off[i]
		var c: Vector2 = c_off[i]
		max_p = maxf(max_p, p.length())
		max_c = maxf(max_c, c.length())
		if p.length() < MIN_MAG or c.length() < MIN_MAG:
			continue
		judged += 1
		var dot: float = p.normalized().dot(c.normalized())
		total += dot
		if dot < -0.1:
			opposed += 1
		worst_deg = maxf(worst_deg, rad_to_deg(acos(clampf(dot, -1.0, 1.0))))
	return {
		"judged": judged,
		"opposed": opposed,
		"agreement": (total / float(judged)) if judged > 0 else 0.0,
		"worst_deg": worst_deg,
		"max_p": max_p,
		"max_c": max_c,
	}

func _report(tag: String, r: Dictionary, frames: int) -> void:
	print("SHAKE_PROBE %s frames=%d judged=%d opposed=%d agreement=%.3f worst_angle=%.1fdeg max_parent=%.1f max_child=%.1f"
		% [tag, frames, r["judged"], r["opposed"], r["agreement"], r["worst_deg"], r["max_p"], r["max_c"]])

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
	await get_tree().process_frame

	var field = main.defense_field
	var slots = field.tower_slots_container
	check(slots != null, "tower_slots_container 가 없다 — 재는 대상이 다르다")
	if slots == null:
		get_tree().quit(failures)
		return
	check(slots.get_parent() == field,
		"$TowerSlots 가 DefenseField 의 자식이 아니다 — 오프셋이 합성되지 않는다는 전제가 틀렸다")

	# ── 0·1·2·3. 기지 피격 — 실제 진입점이다 ────────────────────────────────
	var r1 := await _sample_shake(field, slots, func(): field._juice_base_hit())
	var coh := _coherence(r1["p"], r1["c"])
	_report("base_hit", coh, r1["frames"])

	# §0 기준선 — 흔들리지도 않았으면 나머지 수치는 무의미하다.
	check(coh["max_p"] > MIN_MAG,
		"필드가 흔들리지 않았다(max=%.2f) — 흔들림이 사라진 고침이면 여기서 걸려야 한다" % coh["max_p"])
	check(coh["max_c"] > MIN_MAG,
		"컨테이너가 흔들리지 않았다(max=%.2f) — 두 노드를 재는 의미가 없다" % coh["max_c"])
	check(coh["judged"] >= 3,
		"방향을 판정할 프레임이 %d개뿐이다 — 표본이 부족해 아무것도 못 잰다" % coh["judged"])

	# §1 반대 방향 — 독립 RNG 의 결정적 증거. 한 충격이면 **한 번도** 없어야 한다.
	check(coh["opposed"] == 0,
		"두 노드가 **반대 방향**으로 간 프레임이 %d개다 — 한 사건인데 두 물체가 따로 흔들린다"
		% coh["opposed"])

	# §2 방향 일치도 — 같은 오프셋에 다른 배율이면 정확히 1.0 이다.
	check(coh["agreement"] >= MIN_AGREEMENT,
		"방향 일치도가 %.3f 다 (%.2f 이상이어야 한다) — 두 흔들림이 서로 무관하다"
		% [coh["agreement"], MIN_AGREEMENT])

	# §3 최악 프레임의 각도 — 평균이 가리는 한 프레임짜리 어긋남을 잡는다.
	# ⚠️ 크기 비(자식/부모)는 **단언하지 않는다**. 오프셋이 합성되므로 자식의 화면상 변위는
	#   부모보다 크지만, '컨테이너가 더 흔들려야 하는가' 는 **설계 판단**이다. 수치만 보고한다.
	check(coh["worst_deg"] <= MAX_WORST_DEG,
		"가장 어긋난 프레임이 %.1f° 다 (%.1f° 이하여야 한다) — 한 충격이면 모든 프레임이 같은 방향이다"
		% [coh["worst_deg"], MAX_WORST_DEG])

	# ── 4. 보스 등장 — 같은 패턴인가 (진입점이 둘이면 둘 다 재야 한다) ──────────
	# ⚠️ `EnemyUnit.new()` 로 만들면 안 된다 — `_attach_boss_bar()` 가 `$Sprite`·`$HpBar` 를
	#   직접 찾으므로 **씬에서 인스턴스된 진짜 적**이어야 한다(첫 판이 `Node not found` 2줄을 냈다).
	#   그래서 실제 경로(`start_next_wave()`)로 적을 띄운다.
	field.start_next_wave()
	var deadline := Time.get_ticks_msec() + 3000
	while field.get_enemies().is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var enemies: Array = field.get_enemies()
	check(not enemies.is_empty(), "적이 스폰되지 않았다 — 보스 등장 연출을 잴 수 없다")
	if enemies.is_empty():
		if failures == 0:
			print("SHAKE_COHERENCE_PROBE_OK")
		get_tree().quit(failures)
		return
	var real_enemy = enemies[0]
	# 흔들림만 재도록 웨이브를 멈춘다(적 이동이 필드 위치에 영향을 주진 않지만,
	# 진행 중이면 다른 연출이 끼어들 수 있다).
	field.is_wave_running = false
	await get_tree().process_frame

	var r2 := await _sample_shake(field, slots, func(): field._juice_boss_entrance(real_enemy))
	var coh2 := _coherence(r2["p"], r2["c"])
	_report("boss_entrance", coh2, r2["frames"])
	check(coh2["max_p"] > MIN_MAG and coh2["max_c"] > MIN_MAG,
		"보스 등장 흔들림이 일어나지 않았다 (p=%.2f c=%.2f)" % [coh2["max_p"], coh2["max_c"]])
	check(coh2["opposed"] == 0,
		"보스 등장에서 두 노드가 반대 방향으로 간 프레임이 %d개다" % coh2["opposed"])
	check(coh2["agreement"] >= MIN_AGREEMENT,
		"보스 등장 방향 일치도가 %.3f 다 (%.2f 이상 필요)" % [coh2["agreement"], MIN_AGREEMENT])
	check(coh2["worst_deg"] <= MAX_WORST_DEG,
		"보스 등장에서 가장 어긋난 프레임이 %.1f° 다 (%.1f° 이하여야 한다)"
		% [coh2["worst_deg"], MAX_WORST_DEG])

	if failures == 0:
		print("SHAKE_COHERENCE_PROBE_OK")
	get_tree().quit(failures)
