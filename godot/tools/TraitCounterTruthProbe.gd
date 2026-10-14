extends Node
# 특성 **툴팁의 상성**이 배율 표에서 **유도**되는가 (§2.18 · §5.2 29 (C), 2026-10-01).
#
# ── 왜 이 프로브가 존재하는가 ───────────────────────────────────────────────
# `MonsterRoster.type_counter_text()` 의 주석:
#
#   ## 표(TYPE_MULTIPLIERS)에서 바로 뽑는다 — 문구를 손으로 적어 두면 표를 고칠 때
#   ## 조용히 어긋나고, 그게 바로 이 정보가 화면에 없었던 이유다.
#
# 그런데 **특성**의 상성은 `TraitStyle.DESCRIPTIONS` 안에 **손으로** 적혀 있었다 —
# 11개 중 **4개만** 괄호를 달았고, 그중 `rapid` 는 **거짓**이었다:
#
#   "연사: … (민첩/고속형에 효과적)" 인데 표에서 `rapid` 는 질풍에 **1.00(중립)** 이고
#   오히려 **중갑 0.65 · 재생 0.70** 으로 깎인다. 게다가 `민첩`·`고속형`·`방어형` 은
#   배지 라벨이 아니라서(배지는 8개) 플레이어가 머릿속에서 번역해야 했다.
#
# ⚠️ 이 문구는 `TowerInfoModal.gd:89·181·201` 과 `WordTower._build_tooltip()` 이
#    그대로 읽어 화면에 띄운다 — **플레이어가 보는 문장**이었다.
#
# ## ✅ 고침 — 감독이 (C) 를 골랐다 (2026-10-01)
# 상성을 **표에서 뽑는다**: `MonsterRoster.trait_counter_text()` 가 강점·약점을
# `TYPE_MULTIPLIERS`/`ATTR_MULTIPLIERS` 에서 읽고 **배지 라벨**로 말한다.
# `DESCRIPTIONS` 는 **행동 설명만** 담는다(`orbit` 의 조작 안내는 남는다 — 상성이 아니다).
# 손으로 적은 사본이 없으므로 **드리프트가 원리적으로 불가능**하다.
#
# ## 이 프로브가 재는 것
#   S1 손 사본   — `DESCRIPTIONS` 에 상성 주장이 **하나도** 남아 있지 않은가 (구조)
#   S2 유도 정확 — 11개 특성 전부, 유도 문구의 강점·약점 집합 == 표에서 센 집합
#   S3 어휘      — 유도 문구에 쓰인 말이 **전부 배지 라벨**인가
#   S4 배선      — 문구를 내보내는 UI 소비처가 `trait_full_desc()` 를 쓰는가 (형태 검사)
#   S5 상호일치  — `trait_counter_text` 와 `type_counter_text` 가 **같은 표**에 대해 같은 말을 하는가
#   S6 비공허성  — 훑은 특성 수 · 유도가 실제로 문장을 만드는가
#
# ⚠️ **`trait` 은 GDScript 4 의 예약어다**(`namespace`·`when`·`yield` 와 같이 '미래 사용을
#    위해 예약' 된 목록). `var trait := ...` 는 `Expected variable name after "var"` 라는
#    **엉뚱한 메시지**로 실패한다. 그래서 지역 변수 이름은 `tid_s` 다.
# ⚠️ 파스 오류가 나면 `_ready()` 가 아예 안 돌아 `get_tree().quit()` 도 안 불린다 →
#    헤드리스 Godot 이 **영원히 돈다**. 파스 오류는 "실패" 가 아니라 **"아무것도 안 재고
#    안 끝남"** 이다.
#
# 실행: godot --headless --path . res://tools/TraitCounterTruthProbe.tscn

## `TraitStyle` 은 `class_name` 이 없다 — `WordTower.gd:47` 과 **같은 방식**으로 가져온다.
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
const SOURCE_ROOT := "res://scripts"

var failures := 0

## 절 태그를 함께 찍는다 — 주입 표의 "걸린 절" 이 기계로 구분되어야 한다(§2.17).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

## 라벨 → [종류, id]. 배지에 실제로 찍히는 말만 담는다.
## `TYPE_INFO` 의 'normal' 은 라벨이 빈 문자열이라 자연히 빠진다(그게 맞다 — 배지가 없다).
func _label_index() -> Dictionary:
	var idx: Dictionary = {}
	for tid in MonsterRoster.TYPE_INFO:
		var lbl := str(MonsterRoster.TYPE_INFO[tid].get("label", ""))
		if lbl != "":
			idx[lbl] = ["type", str(tid)]
	for aid in MonsterRoster.ATTR_INFO:
		var albl := str(MonsterRoster.ATTR_INFO[aid].get("label", ""))
		if albl != "":
			idx[albl] = ["attr", str(aid)]
	return idx

## 표에서 직접 센 강점·약점. 라벨로 돌려준다 — 문구와 **같은 어휘**로 맞대기 위해서다.
func _table_sets(trait_id: String) -> Dictionary:
	var strong: Array = []
	var weak: Array = []
	for type_id in MonsterRoster.TYPE_MULTIPLIERS:
		var v := float(MonsterRoster.TYPE_MULTIPLIERS[type_id].get(trait_id, 1.0))
		if v >= MonsterRoster.COUNTER_WEAK_MULT:
			strong.append(MonsterRoster.type_label(str(type_id)))
		elif v <= MonsterRoster.COUNTER_RESIST_MULT:
			weak.append(MonsterRoster.type_label(str(type_id)))
	for attr_id in MonsterRoster.ATTR_MULTIPLIERS:
		var v := float(MonsterRoster.ATTR_MULTIPLIERS[attr_id].get(trait_id, 1.0))
		if v >= MonsterRoster.COUNTER_WEAK_MULT:
			strong.append(MonsterRoster.attr_label(str(attr_id)))
		elif v <= MonsterRoster.COUNTER_RESIST_MULT:
			weak.append(MonsterRoster.attr_label(str(attr_id)))
	return {"strong": strong, "weak": weak}

## 유도 문구 `"(A·B에 효과적, C에 약함)"` 를 집합으로 되돌린다.
## ⚠️ 문구를 만드는 쪽과 **같은 어휘**로 읽어야 한다 — 다르면 항상 '다르다' 가 된다(§2.19).
func _parse_counter(text: String) -> Dictionary:
	var strong: Array = []
	var weak: Array = []
	var re := RegEx.new()
	re.compile("\\(([^)]*)\\)")
	var m := re.search(text)
	if m == null:
		return {"strong": strong, "weak": weak}
	for part in m.get_string(1).split(",", false):
		var seg := str(part).strip_edges()
		var into: Array = []
		if seg.ends_with("에 효과적"):
			into = strong
			seg = seg.substr(0, seg.length() - "에 효과적".length())
		elif seg.ends_with("에 약함"):
			into = weak
			seg = seg.substr(0, seg.length() - "에 약함".length())
		else:
			continue
		for w in seg.split("·", false):
			into.append(str(w).strip_edges())
	return {"strong": strong, "weak": weak}

func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true

## 소스 파일에서 `needle` 을 몇 번 찾는가. **주석은 세지 않는다**(§2.20 K6 의 교훈).
func _scan_source(root: String, needle: String, hits: Dictionary) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := root.path_join(name)
		if dir.current_is_dir():
			_scan_source(full, needle, hits)
		elif name.ends_with(".gd"):
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				var n := 0
				while not f.eof_reached():
					if _code_part(f.get_line()).contains(needle):
						n += 1
				if n > 0:
					hits[name] = n
		name = dir.get_next()
	dir.list_dir_end()

## 줄에서 **문자열 밖** 첫 `#` 부터를 잘라낸다. 색 문자열 `"#A6B8F2"` 는 자르지 않는다.
func _code_part(line: String) -> String:
	var in_str := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\"":
			in_str = not in_str
		elif c == "#" and not in_str:
			return line.substr(0, i)
		i += 1
	return line

func _ready() -> void:
	var labels := _label_index()
	print("TRAIT_COUNTER labels=%d %s" % [labels.size(), str(labels.keys())])

	# ── §0 기준선 ─────────────────────────────────────────────────────────────
	check(MonsterRoster.TYPE_MULTIPLIERS.size() >= 3,
		"타입 배율 표가 %d줄뿐이다 — 이 실행은 표를 재고 있지 않다" % MonsterRoster.TYPE_MULTIPLIERS.size(), "S6")
	check(MonsterRoster.ATTR_MULTIPLIERS.size() >= 3,
		"속성 배율 표가 %d줄뿐이다" % MonsterRoster.ATTR_MULTIPLIERS.size(), "S6")
	check(TraitStyle.DESCRIPTIONS.size() >= 11,
		"특성 설명이 %d개뿐이다" % TraitStyle.DESCRIPTIONS.size(), "S6")

	# ── S1 손 사본 — 설명 표에 상성 주장이 남아 있는가 ────────────────────────
	# 이것이 (C) 의 **구조적** 부분이다. 사본이 하나라도 있으면 표를 고칠 때 어긋날 수 있다.
	var leftover: Array = []
	var re_claim := RegEx.new()
	re_claim.compile("\\([^)]*에\\s*(효과적|약함)\\)")
	for tid in TraitStyle.DESCRIPTIONS:
		for m in re_claim.search_all(str(TraitStyle.DESCRIPTIONS[tid])):
			leftover.append("%s: \"%s\"" % [str(tid), m.get_string(0)])
	print("TRAIT_COUNTER leftover_claims=%d %s" % [leftover.size(), str(leftover)])
	check(leftover.is_empty(),
		"`DESCRIPTIONS` 에 **손으로 적은 상성 주장**이 %d개 남아 있다 — 표를 고치면 조용히 어긋난다: %s" % [
			leftover.size(), str(leftover)], "S1")

	# ── S2 유도 정확 + S3 어휘 ───────────────────────────────────────────────
	var mismatch: Array = []
	var bad_words: Array = []
	var with_counter := 0
	var produced := 0
	for tid in TraitStyle.DESCRIPTIONS:
		var tid_s := str(tid)
		var text := MonsterRoster.trait_counter_text(tid_s)
		var want := _table_sets(tid_s)
		var got := _parse_counter(text)
		if text != "":
			produced += 1
		if not (want["strong"] as Array).is_empty() or not (want["weak"] as Array).is_empty():
			with_counter += 1
		if not _same_set(got["strong"], want["strong"]) or not _same_set(got["weak"], want["weak"]):
			mismatch.append("%s: 문구 %s (강점 %s / 약점 %s) vs 표 (강점 %s / 약점 %s)" % [
				tid_s, text, str(got["strong"]), str(got["weak"]),
				str(want["strong"]), str(want["weak"])])
		for grp in ["strong", "weak"]:
			for w in got[grp]:
				if not labels.has(str(w)):
					bad_words.append("%s:\"%s\"" % [tid_s, str(w)])
		print("TRAIT_COUNTER trait=%-18s counter=%-34s table_strong=%s table_weak=%s" % [
			tid_s, text, str(want["strong"]), str(want["weak"])])

	print("TRAIT_COUNTER summary traits=%d produced=%d with_counter=%d mismatch=%d bad_words=%d" % [
		TraitStyle.DESCRIPTIONS.size(), produced, with_counter, mismatch.size(), bad_words.size()])
	check(mismatch.is_empty(),
		"유도 문구가 표와 **다르다** — %d건: %s" % [mismatch.size(), str(mismatch)], "S2")
	check(bad_words.is_empty(),
		"유도 문구에 **배지 라벨이 아닌** 말이 %d개 쓰였다 — 화면 어디에도 없는 말이다: %s" % [
			bad_words.size(), str(bad_words)], "S3")

	# ── S4 배선 — 문구를 내보내는 UI 가 `trait_full_desc()` 를 쓰는가 ─────────
	# ⚠️ **개수가 아니라 형태를 잰다**(§2.16). `desc_for` 를 직접 부르면 상성이 빠진 문구가
	#    나가고, 표를 직접 읽어 괄호를 만들면 손으로 적는 것과 같은 드리프트가 돌아온다.
	var full_hits: Dictionary = {}
	var direct_hits: Dictionary = {}
	_scan_source(SOURCE_ROOT, "trait_full_desc(", full_hits)
	_scan_source(SOURCE_ROOT, "TraitStyle.desc_for(", direct_hits)
	print("TRAIT_COUNTER wiring full_desc=%s direct_desc_for=%s" % [str(full_hits), str(direct_hits)])
	#   `MonsterRoster.gd` 안의 `desc_for` 는 **구현 자체**다 — 배선 위반이 아니다.
	check(full_hits.has("TowerInfoModal.gd"),
		"정보 모달이 `trait_full_desc()` 를 안 쓴다 — 툴팁에서 상성이 빠진다", "S4")
	check(full_hits.has("WordTower.gd"),
		"타워 툴팁이 `trait_full_desc()` 를 안 쓴다 — 호버에서 상성이 빠진다", "S4")
	check(not direct_hits.has("TowerInfoModal.gd") and not direct_hits.has("WordTower.gd"),
		"UI 가 `TraitStyle.desc_for()` 를 **직접** 부른다(%s) — 상성이 빠진 문구가 나간다" % str(direct_hits), "S4")

	# ── S5 상호일치 — 두 유도 함수가 같은 표에 대해 같은 말을 하는가 ─────────
	# `type_counter_text` 는 '중갑→관통·유성 (연사·선회에 약함)' 이라 말하고,
	# `trait_counter_text` 는 '연사 … (중갑에 약함)' 이라 말한다. **같은 표**를 읽으므로
	# 한쪽에만 있는 사실이 있으면 구현이 틀린 것이다.
	var asymmetric: Array = []
	for type_id in MonsterRoster.TYPE_MULTIPLIERS:
		var line := MonsterRoster.type_counter_text(str(type_id))
		var tlabel := MonsterRoster.type_label(str(type_id))
		for trait_id in MonsterRoster.TYPE_MULTIPLIERS[type_id]:
			var v := float(MonsterRoster.TYPE_MULTIPLIERS[type_id][trait_id])
			var tname := str(WordTower.TRAIT_NAMES.get(str(trait_id), str(trait_id)))
			var in_type_line := line.contains(tname)
			var in_trait_line := MonsterRoster.trait_counter_text(str(trait_id)).contains(tlabel)
			# 문구에 이름이 나오면 그 방향의 배율이 임계를 넘어야 한다.
			if in_type_line != in_trait_line:
				asymmetric.append("%s×%s (배율 %.2f): type_line=%s trait_line=%s" % [
					str(type_id), str(trait_id), v, str(in_type_line), str(in_trait_line)])
	print("TRAIT_COUNTER cross_check asymmetric=%d %s" % [asymmetric.size(), str(asymmetric)])
	check(asymmetric.is_empty(),
		"두 유도 함수가 **같은 표**에 대해 다른 말을 한다 — %d건: %s" % [asymmetric.size(), str(asymmetric)], "S5")

	# ── S6 비공허성 ───────────────────────────────────────────────────────────
	# 사본을 지우기만 하고 유도를 안 붙이면 S1 은 **공짜로** 통과한다. 그 상태를 막는다.
	check(with_counter >= 5,
		"표에 상성이 있는 특성이 %d개뿐이다 — 이 프로브의 전제가 바뀌었다" % with_counter, "S6")
	check(produced >= 5,
		"유도 문구가 %d개 특성에서만 나왔다 — 상성이 화면에서 사라졌을 수 있다" % produced, "S6")
	# 표에 있는 특성 id 는 **전부 이름이 있어야** 한다 — 없으면 문구에 날것의 id 가 나간다.
	# (`type_counter_text` 는 `TRAIT_NAMES.get(id, id)` 로 떨어지므로 조용히 id 가 새어 나간다.)
	var unnamed: Array = []
	for type_id in MonsterRoster.TYPE_MULTIPLIERS:
		for trait_id in MonsterRoster.TYPE_MULTIPLIERS[type_id]:
			if not WordTower.TRAIT_NAMES.has(str(trait_id)) and not unnamed.has(str(trait_id)):
				unnamed.append(str(trait_id))
	for attr_id in MonsterRoster.ATTR_MULTIPLIERS:
		for trait_id in MonsterRoster.ATTR_MULTIPLIERS[attr_id]:
			if not WordTower.TRAIT_NAMES.has(str(trait_id)) and not unnamed.has(str(trait_id)):
				unnamed.append(str(trait_id))
	print("TRAIT_COUNTER unnamed_traits=%s" % str(unnamed))
	check(unnamed.is_empty(),
		"표에 있지만 **이름이 없는** 특성 %s — 유도 문구에 날것의 id 가 나간다" % str(unnamed), "S6")
	# `rapid` 는 이 결함의 **역사적 증거**다 — 강점 0 · 약점 2 여야 한다.
	var rapid := MonsterRoster.trait_counter_text("rapid")
	print("TRAIT_COUNTER rapid=\"%s\"" % rapid)
	check(rapid.contains("약함") and not rapid.contains("효과적"),
		"`rapid` 가 다시 없는 상성을 광고한다: \"%s\" — §2.18 의 거짓 주장이 돌아왔다" % rapid, "S6")

	# ── ⚠️ 이 프로브가 **일부러 안 잡는 것** 둘 (주입 J3·J6 으로 확인) ────────
	#   ① **임계값 자체**(`COUNTER_WEAK_MULT` 를 1.25→1.10) — 유도와 검사가 **같은 상수**를
	#      읽으므로 양쪽이 함께 움직여 일치한다. 그 값은 `tools/CounterThresholdProbe` S1 이
	#      `EnemyUnit.WEAK_MULT` 와 **같은지**로 지킨다(소유자가 다르다).
	#   ② **표 자체를 흔드는 것**(중갑×관통 1.6→1.0) — 유도 문구가 **따라 움직이는 것이 정답**이다.
	#      (C) 의 목적이 그것이라 여기서 빨개지면 오히려 잘못된 검사다.
	#   ⚠️ 상수를 프로브에 **하드코딩하면** ①은 잡히지만 그건 §2.21 K2 의 실패다 —
	#      재는 대상이 상수가 아니라 '내가 적어 넣은 수' 가 된다. 그래서 하드코딩하지 않는다.

	if failures == 0:
		print("TRAIT_COUNTER_PROBE_OK")
	get_tree().quit(failures)
