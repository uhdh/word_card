extends Node
# 예고 문구와 피해 숫자가 **같은 판정**을 내리는가 (§2.19, 2026-09-26 신규 · 같은 날 고침).
#
# ── 무엇을 재는가 ───────────────────────────────────────────────────────────
# 상성은 **하나의 수**(`EnemyUnit.damage_multiplier_for`)인데 두 곳이 **다른 임계**로 판정했다.
# 그 수를 설명하는 문장(`ATTR_INFO.counter`)은 손으로 적혀 있어 표와 어긋났다. 둘 다 "표 대 표"
# 의 문제라 코드만 맞추면 끝난다 — **2026-09-26 에 둘 다 고쳤고, 이 프로브가 그 고침을 지킨다.**
#
#   S1·S2·S3 — 예고 문구와 피해 숫자가 같은 판정을 내리는가
#     예고  `MonsterRoster.type_counter_text()` → COUNTER_WEAK_MULT 1.25 / COUNTER_RESIST_MULT 0.75
#     숫자  `EnemyUnit._hit_kind()`            → WEAK_MULT 1.25 / RESIST_MULT 0.75
#     ⚠️ 2026-09-26 까지 숫자 쪽이 **1.35 / 0.72** 였다 — `MonsterRoster.gd` 의 주석
#        (*"EnemyUnit 의 WEAK_MULT / RESIST_MULT 와 같은 경계다"*)이 **거짓**이었고, 그 차이만큼
#        표 22쌍 중 8쌍이 틈에 걸렸다. 플레이어가 보는 결과: 예고가 "중갑→…유성"(1.25)이라 적어
#        주는데 유성으로 때려도 피해 숫자가 **평범한 흰색**이다 → "예고가 거짓말한다" 로 배운다.
#        ⚠️ `_hit_kind` 는 **표시 전용**이라(피해량·HP·골드 어디에도 안 흐른다) 이 정렬은
#           **밸런스 변경이 아니다** — 감사 §2.19 가 그렇게 판정했고, 이 프로브가 그 경로를 탄다.
#
#   S4 — 손으로 적은 속성 상성 문구가 표와 같은 말을 하는가
#     타입 상성은 표에서 유도되는데(`type_counter_text`), **속성 상성만 `ATTR_INFO.counter` 에
#     손으로 적혀 있다**(§2.18 과 같은 부류). `splitter` 한 줄이 표의 항목
#     (`3연속 바운스` · 표에는 4개가 있는데 문구에는 3개)을 빠뜨리고 있었다 — 같은 날 고쳤다.
#
# ⚠️ **§2.19 의 세 번째 조각(`ATTR_INFO.desc` 가 화면에 도달하지 않는다)은 여기 없다.**
#    그건 "표 대 표" 가 아니라 **화면 배치 결정**(감사 §5.2 31 의 **(B)**)이라
#    `tools/AttrDescReachProbe.gd` 로 분리했다 — 한 파일에 두 극성(고침 수호 / 결정 대기)을
#    섞으면 이 프로브가 **등록 불가**가 된다(등록은 `_OK` 를 찍는 판정형 프로브만).
#
# ⚠️ **S1~S4 는 어긋남이 0건이어야 통과한다** — 2026-09-26 이후 **초록**이다.
#    `tools/TraitCounterTruthProbe.gd` 와 같은 방식이다.
#
# 실행: godot --headless --path . res://tools/CounterThresholdProbe.tscn

const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")

var failures := 0

## 절 태그를 함께 찍는다 — 주입 표의 "걸린 절" 이 기계로 구분되어야 한다(§2.17).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

func _label(trait_id: String) -> String:
	return str(WordTower.TRAIT_NAMES.get(trait_id, trait_id))

## 상성 판정을 **실제 함수**로 낸다 — 상수를 비교하는 게 아니라 플레이어가 보는 경로를 탄다.
## `dealt = 1.0` 인 이유: 60 이상이면 폴백이 '치명타' 가 되어 'normal' 판정이 가려진다.
func _kind_of(type_id: String, attrs: Array, trait_id: String) -> String:
	var e = EnemyUnitScene.instantiate() as EnemyUnit
	e.enemy_type = type_id
	e.attrs = attrs
	e.weakness_trait = ""
	var mult: float = e.damage_multiplier_for(trait_id)
	var kind: String = e._hit_kind(1.0, mult)
	e.free()
	return kind

## 예고 문구가 내리는 판정. `MonsterRoster` 의 두 임계를 그대로 쓴다.
##
## ⚠️ **반환 어휘를 `_shown()` 과 똑같이 맞춰야 한다.** 처음에 이 함수가
## `"preview_weak"` 를 돌려주게 썼더니 `preview != shown` 가 **항상 참**이 되어,
## 일치하는 8건까지 '어긋남' 으로 찍혔다 — 두 어휘를 맞대는 비교에서
## **어휘가 다르면 비교 자체가 무의미해진다**(거짓 양성).
func _preview_verdict(value: float, cw: float, cr: float) -> String:
	if value >= cw:
		return "weak"
	if value <= cr:
		return "resist"
	return "none"

func _shown(kind: String) -> String:
	return kind if kind == "weak" or kind == "resist" else "none"

func _ready() -> void:
	var cw: float = MonsterRoster.COUNTER_WEAK_MULT
	var cr: float = MonsterRoster.COUNTER_RESIST_MULT
	var hw: float = EnemyUnit.WEAK_MULT
	var hr: float = EnemyUnit.RESIST_MULT

	# ── S1 두 임계 쌍 ────────────────────────────────────────────────────────
	print("COUNTER_THRESHOLD thresholds preview weak>=%.2f resist<=%.2f | number weak>=%.2f resist<=%.2f" % [cw, cr, hw, hr])
	check(is_equal_approx(cw, hw),
		"예고의 '약함' 임계 %.2f 와 피해 숫자의 '약점' 임계 %.2f 가 다르다 — `MonsterRoster.gd:83` 의 주석(\"같은 경계다\")이 거짓이다" % [cw, hw], "S1")
	check(is_equal_approx(cr, hr),
		"예고의 '약함'(내성) 임계 %.2f 와 피해 숫자의 '내성' 임계 %.2f 가 다르다 — 같은 주석이 거짓이다" % [cr, hr], "S1")

	# ── S2 갭 밴드 — 어긋날 수 있는 표 항목을 전수 열거 ──────────────────────
	var band_weak: Array = []
	var band_resist: Array = []
	var scanned := 0
	for pair in [["TYPE", MonsterRoster.TYPE_MULTIPLIERS], ["ATTR", MonsterRoster.ATTR_MULTIPLIERS]]:
		var axis := str(pair[0])
		var tables: Dictionary = pair[1]
		for owner_id in tables:
			var table: Dictionary = tables[owner_id]
			for trait_id in table:
				scanned += 1
				var v := float(table[trait_id])
				if v >= cw and v < hw:
					band_weak.append("%s %s×%s=%.2f" % [axis, owner_id, trait_id, v])
				elif v <= cr and v > hr:
					band_resist.append("%s %s×%s=%.2f" % [axis, owner_id, trait_id, v])
	print("COUNTER_THRESHOLD band scanned=%d weak=%s" % [scanned, str(band_weak)])
	print("COUNTER_THRESHOLD band resist=%s" % str(band_resist))
	check(band_weak.is_empty(),
		"예고는 '약함' 이라 적는데 피해 숫자는 아무 표시도 안 하는 표 항목이 %d개다: %s" % [band_weak.size(), str(band_weak)], "S2")
	check(band_resist.is_empty(),
		"예고는 '(…에 약함)' 이라 적는데 피해 숫자는 아무 표시도 안 하는 표 항목이 %d개다: %s" % [band_resist.size(), str(band_resist)], "S2")

	# ── S3 타입 축 — 실제 경로로 예고와 숫자를 맞대어 본다 ───────────────────
	# 적에게 속성을 주지 않는다 — 그러면 배율이 타입 축 **하나**만 타서, 예고 문구가 말하는
	# 대상(타입 상성)과 정확히 같은 것을 잰다.
	var type_mismatch: Array = []
	var type_scanned := 0
	for type_id in MonsterRoster.TYPE_MULTIPLIERS:
		var table: Dictionary = MonsterRoster.TYPE_MULTIPLIERS[type_id]
		for trait_id in table:
			type_scanned += 1
			var v := float(table[trait_id])
			var preview := _preview_verdict(v, cw, cr)
			var shown := _shown(_kind_of(str(type_id), [], str(trait_id)))
			if preview != shown:
				type_mismatch.append("%s×%s=%.2f 예고=%s 숫자=%s" % [type_id, trait_id, v, preview, shown])
	print("COUNTER_THRESHOLD type scanned=%d mismatch=%s" % [type_scanned, str(type_mismatch)])
	check(type_mismatch.is_empty(),
		"타입 축에서 예고와 피해 숫자가 %d건 어긋난다: %s" % [type_mismatch.size(), str(type_mismatch)], "S3")

	# ── S4 속성 축 — 손으로 적은 문구 vs 표 ─────────────────────────────────
	var attr_mismatch: Array = []
	var attr_unknown: Array = []
	var attr_omitted: Array = []
	var attr_scanned := 0
	var attr_list_count := 0
	for attr_id in MonsterRoster.ATTR_MULTIPLIERS:
		var table: Dictionary = MonsterRoster.ATTR_MULTIPLIERS[attr_id]
		var from_table: Array = []
		for trait_id in table:
			attr_scanned += 1
			if float(table[trait_id]) >= cw:
				from_table.append(_label(str(trait_id)))
		from_table.sort()

		# ⚠️ 문구가 **목록**인가 **산문**인가를 먼저 가른다. `·` 로 이어진 것만 목록이다.
		# "둔화 외 아무거나" 같은 문장은 이름 목록이 아니므로 토큰을 특성 이름과 맞대면
		# **정상 문구가 실패로 찍힌다**(§2.13-1 의 `contains("초")` 와 같은 부류의 함정).
		var text := str(MonsterRoster.ATTR_INFO.get(attr_id, {}).get("counter", ""))
		var is_list := text.contains("·")
		var from_text: Array = []
		var prose: Array = []
		if is_list:
			for token in text.split("·"):
				var t := str(token).strip_edges()
				if t == "":
					continue
				var known := false
				for trait_id in WordTower.TRAIT_NAMES:
					if str(WordTower.TRAIT_NAMES[trait_id]) == t:
						from_text.append(t)
						known = true
						break
				if not known:
					prose.append(t)
		else:
			prose.append(text)
		from_text.sort()
		print("COUNTER_THRESHOLD attr=%s list=%s table=%s text=%s prose=%s" % [
			attr_id, str(is_list), str(from_table), str(from_text), str(prose)])
		if is_list:
			# 목록형 문구만 이 두 검사를 받는다 — 산문에는 '빠진 항목' 이라는 개념이 없다.
			attr_list_count += 1
			attr_unknown.append_array(prose)
			# 표와 **집합이 같아야** 한다.
			for name in from_table:
				if not from_text.has(name):
					attr_omitted.append("%s: 표에 있으나 문구에 없다 → %s" % [attr_id, name])
			for name in from_text:
				if not from_table.has(name):
					attr_omitted.append("%s: 문구에 있으나 표에 없다 → %s" % [attr_id, name])

		# 그리고 그 문구가 주장한 상성을 **실제 배율**로 확인한다(적 속성만, 타입은 normal).
		for trait_id in table:
			var claims := from_text.has(_label(str(trait_id)))
			var shown := _shown(_kind_of("normal", [str(attr_id)], str(trait_id)))
			if claims and shown != "weak":
				attr_mismatch.append("%s×%s=%.2f 문구=상성 숫자=%s" % [
					attr_id, trait_id, float(table[trait_id]), shown])
	check(attr_scanned > 0, "속성 표가 비었다 — S4 가 공허하다", "S6")
	check(attr_list_count > 0,
		"`·` 로 이어진 상성 문구가 하나도 없다 — S4 의 집합 비교가 공허하다", "S6")
	check(attr_unknown.is_empty(),
		"속성 상성 문구에 **표에도 특성 이름표에도 없는 말**이 있다: %s" % str(attr_unknown), "S4")
	check(attr_omitted.is_empty(),
		"손으로 적은 속성 상성 목록이 표와 다르다 — %d건: %s" % [attr_omitted.size(), str(attr_omitted)], "S4")
	check(attr_mismatch.is_empty(),
		"문구가 상성이라 적었는데 피해 숫자가 확인해 주지 않는 항목이 %d건이다: %s" % [attr_mismatch.size(), str(attr_mismatch)], "S4")

	# ── S5 는 없다 — `ATTR_INFO.desc` 의 도달 가능성은 `tools/AttrDescReachProbe.gd` 로 갔다. ────
	#    (그 조각은 화면 배치 결정이라 이 프로브의 극성과 섞이면 이쪽이 등록 불가가 된다.)

	# ── S6 비공허성 ──────────────────────────────────────────────────────────
	check(scanned > 0, "배율 표를 하나도 훑지 않았다 — S2 가 공허하다", "S6")
	check(type_scanned > 0, "타입 표를 하나도 훑지 않았다 — S3 이 공허하다", "S6")
	check(not MonsterRoster.TYPE_MULTIPLIERS.is_empty() and not MonsterRoster.ATTR_MULTIPLIERS.is_empty(),
		"배율 표가 비었다 — 이 프로브는 아무것도 재지 않는다", "S6")

	if failures == 0:
		print("COUNTER_THRESHOLD_PROBE_OK")
	get_tree().quit(failures)
