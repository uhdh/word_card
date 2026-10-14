# RelicChipProbe.gd
# 유물에서 온 시너지 라벨이 **유물 아이콘**을 얻는지, 그리고 그 라벨이 사실을 말하는지 잰다.
#
# 왜 필요한가:
#   정보창(TowerInfoModal)의 유물 칩에는 아이콘이 없었다. `_synergy_style` 이 라벨을
#   **전체 문자열**로 찾았는데 라벨에는 수치가 붙기 때문이다("활자의 정수 (+20% 피해)").
#   그래서 `styles` 표에 이름을 아무리 적어도 안 잡히고 기본값(아이콘 없음)으로 떨어졌다.
#
# 재는 것:
#   S1  상점 표(`ShopModal.ALL_RELIC_POOL`)의 27개 유물이 **전부** 아이콘을 얻는가
#       — 맨 이름과 수치 붙은 이름 **둘 다**.
#   S2  양성 대조 — 유물이 아닌 라벨(`결:` · 인접 시너지 · 없는 라벨)은 아이콘을 얻으면 안 된다.
#   S3  **실제 게임 경로** — 유물을 전부 보유한 상태로 특성별 타워를 세우고, 실제로 만들어진
#       `synergy_labels` 를 그대로 스타일링한다. 22자 초과 라벨(=칩 행이 접히는 길이)도 센다.
#   S4  값 계약 — 라벨이 말하는 % 와 상점 설명이 일치하는가.
#
# 보고 전용. 판정하지 않는다(실패 목록만 찍는다).
## ⚠️ 루트는 반드시 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
extends Node

const TowerInfoModalScript = preload("res://scripts/ui/TowerInfoModal.gd")
const ShopModal = preload("res://scripts/ui/ShopModal.gd")
const AttackStyleScript = preload("res://scripts/core/AttackStyle.gd")

const OUT_PATH := "E:/project/word_card/tmp/relicchip_out.txt"
## **긴 라벨** 의 기준(칩 행이 접히기 시작하는 길이). 2026-10-05 이전에는
## `_render_synergy_badges` 가 이 길이를 넘으면 라벨을 **조용히 버려서** 그 유물의 효과가
## 정보창에서 통째로 사라졌다 — 이제 `HFlowContainer` 가 접어 준다(버리지 않는다).
const LONG_LABEL_LEN := 22

var _lines: PackedStringArray = []

func _emit(s: String) -> void:
	_lines.append(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null

func _watchdog() -> void:
	for i in 1200:
		await get_tree().process_frame
	_emit("WATCHDOG — 1200 프레임 안에 못 끝났다")
	get_tree().quit(2)

func _ready() -> void:
	_watchdog()
	_emit("RELICCHIP_START")
	var modal: Control = TowerInfoModalScript.new()

	# ── S1. 상점 표의 모든 유물이 아이콘을 얻는가 ─────────────────────────────
	var s1_fail: Array[String] = []
	var s1_n := 0
	for r in ShopModal.ALL_RELIC_POOL:
		var core: String = modal._relic_core_name(str(r["name"]))
		var forms: Array[String] = [core, "%s (+20%% 피해)" % core]
		for lbl in forms:
			s1_n += 1
			var st: Dictionary = modal._synergy_style(lbl)
			var tex := str(st.get("texture", ""))
			var ok: bool = tex != "" and ResourceLoader.exists(tex)
			if not ok:
				s1_fail.append(lbl)
			_emit("S1 %-30s -> %s %s" % [lbl, tex.get_file() if tex != "" else "(없음)",
				"OK" if ok else "★실패"])
	_emit("S1 합계: %d개 라벨 중 실패 %d" % [s1_n, s1_fail.size()])
	if s1_fail.size() > 0:
		_emit("S1 실패 목록: %s" % ", ".join(s1_fail))

	# ── S2. 양성 대조 ────────────────────────────────────────────────────────
	var controls: Array[String] = [
		"결: 받침 (피해+5%, 속도-4%)", "결: 모음 반복 (속도+4%)",
		"원소 공명", "전술 연계", "수호의 순환",
		"듣도보도못한라벨", "특성: 지속 피해",
	]
	var s2_bad := 0
	for lbl in controls:
		var st: Dictionary = modal._synergy_style(lbl)
		var tex := str(st.get("texture", ""))
		var gl := str(st.get("icon", ""))
		if tex != "":
			s2_bad += 1
		_emit("S2 %-30s -> glyph=%-3s texture=%-22s %s" % [lbl, gl,
			tex.get_file() if tex != "" else "(없음)", "★오검출" if tex != "" else "OK"])
	_emit("S2 양성 대조: %d개 중 오검출 %d" % [controls.size(), s2_bad])

	# ── S3. 실제 게임 경로 ───────────────────────────────────────────────────
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return

	# 유물을 전부 보유 → 라벨 생성 분기가 전부 열린다.
	var all_ids: Array = []
	for r in ShopModal.ALL_RELIC_POOL:
		all_ids.append(str(r["id"]))
	field.relic_ids = all_ids
	field.set_act(2)

	# 특성별로 단어를 최대 2개씩 골라 **모든 특성**을 덮는다 — 특성 전용 유물 라벨이
	# 그 특성의 타워에서만 나오기 때문이다.
	# ⚠️ `WordDatabase.get_all_words()` 는 **이름과 달리 단어 문자열이 아니라 데이터
	# 딕셔너리**를 돌려준다(`WORD_DATABASE.values()`). `str()` 로 감싸면 딕셔너리 repr 이
	# 단어가 되어 전부 걸러진다(1차 실행이 정확히 그렇게 실패했다 — 커버리지 0종).
	var by_trait: Dictionary = {}
	for d in WordDatabase.get_all_words():
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var wd: Dictionary = d
		var ws := str(wd.get("word", ""))
		if ws == "":
			continue
		var st: Dictionary = AttackStyleScript.style_for(ws, wd)
		var tid := str(st.get("trait", ""))
		if tid == "":
			continue
		var bucket: Array = by_trait.get(tid, [])
		if bucket.size() < 2:
			bucket.append(ws)
			by_trait[tid] = bucket
	var parsed: Array = []
	var used: Array[String] = []
	for tid in by_trait:
		for ws in by_trait[tid]:
			parsed.append({"syllable": ws, "word_data": WordDatabase.get_word_data(ws)})
			used.append("%s=%s" % [tid, ws])
	_emit("S3 특성 커버리지 %d종 · 타워 %d개: %s" % [by_trait.size(), parsed.size(), ", ".join(used)])
	if parsed.is_empty():
		_emit("S3 단어를 못 골랐다 — WordDatabase 가 비었나?")
		get_tree().quit(4)
		return
	# 슬롯이 3개뿐이라 한 번에 3개만 선다 — **배치로 나눠** 모든 특성을 덮는다.
	var collected: Dictionary = {}   # 라벨 -> 처음 만들어진 trait
	var towers_seen := 0
	for i in range(0, parsed.size(), 3):
		var chunk: Array = parsed.slice(i, i + 3)
		field.update_towers_from_parsed_list(chunk)
		for f in 40:
			await get_tree().process_frame
		for t in field.active_towers:
			if t == null:
				continue
			towers_seen += 1
			for lbl in t.synergy_labels:
				var l := str(lbl)
				if not collected.has(l):
					collected[l] = str(t.trait_id)
	_emit("S3 타워 %d개를 %d배치로 세웠다 · 서로 다른 라벨 %d종" % [
		towers_seen, int(ceil(float(parsed.size()) / 3.0)), collected.size()])

	var s3_missing := 0
	var s3_long := 0
	var s3_relic := 0
	for l in collected:
		var ls := str(l)
		var st: Dictionary = modal._synergy_style(ls)
		var tex := str(st.get("texture", ""))
		var is_relic: bool = not modal._match_relic(ls).is_empty()
		var over: bool = ls.length() > LONG_LABEL_LEN
		if is_relic:
			s3_relic += 1
		if over:
			s3_long += 1
		var missing: bool = is_relic and tex == ""
		if missing:
			s3_missing += 1
		_emit("     %-36s trait=%-16s len=%-3d %-24s%s%s" % [ls, str(collected[l]), ls.length(),
			tex.get_file() if tex != "" else ("(유물아님)" if not is_relic else "(아이콘없음)"),
			"★유물인데아이콘없음" if missing else "",
			"  긴 라벨(%d자↑)" % LONG_LABEL_LEN if over else ""])
	_emit("S3 유물 라벨 %d종 · 아이콘 없는 유물 라벨 %d종 · 긴 라벨(%d자↑) %d종 — 이제 **버리지 않고 접는다**" % [
		s3_relic, s3_missing, LONG_LABEL_LEN, s3_long])

	# ── S4. 값 계약 — **모든** 유물 라벨의 % vs 상점 설명 ─────────────────────
	# 라벨은 요약이고 상점 설명은 계약이다. 둘이 다른 % 를 말하면 **라벨이 거짓말**이다.
	# 2026-10-05 까지 `천리안의 룬` 하나만 눈으로 봤다 — 전수로 넓힌다.
	var s4_seen := 0
	var s4_bare := 0
	var s4_bad := 0
	for l in collected:
		var ls := str(l)
		var relic: Dictionary = modal._match_relic(ls)
		if relic.is_empty():
			continue
		var lp := _pcts(ls)
		if lp.is_empty():
			s4_bare += 1          # 맨 이름 라벨(모양 유물) — 수치를 안 말하므로 맞댈 것이 없다
			continue
		var dp := _pcts(str(relic.get("desc", "")))
		s4_seen += 1
		var same := lp == dp
		if not same:
			s4_bad += 1
		_emit("S4 %-32s 라벨%s 상점%s %s" % [ls, str(lp), str(dp), "OK" if same else "★불일치"])
	_emit("S4 수치를 말하는 유물 라벨 %d종 · **%% 불일치 %d종** · 맨 이름 %d종" % [s4_seen, s4_bad, s4_bare])
	# 옛 표기를 **일부러 계산해 보여준다** — `int()` 였다면 14 로 잘렸다는 사실이 이 결함의
	# 지문이었다(2026-10-05 고침). 지금은 라벨이 PCT 상수를 그대로 읽으므로 잘림이 없다.
	_emit("S4 상수  = PCT=%d → MULT=%s · (옛 int((m-1)*100) 였다면 %d 로 잘렸다)" % [
		_range_pct(), str(_range_mult()), int((_range_mult() - 1.0) * 100.0)])

	# ── S5. 실제 정보창을 띄워 칩이 아이콘을 **그리는지** 센다 ────────────────
	# `_synergy_style` 이 텍스처를 돌려주는 것과 화면에 그려지는 것은 다르다 —
	# TextureRect 가 크기 0 으로 눌리거나 컨테이너에 안 붙으면 아무것도 안 보인다.
	field.update_towers_from_parsed_list(parsed.slice(0, 3))
	for i in 40:
		await get_tree().process_frame
	# 긴 라벨(22자↑)을 가진 타워를 **먼저** 고른다 — 예전에 칩에서 조용히 사라지던 그 라벨이
	# 지금 실제로 그려지는지 화면으로 확인하기 위해서다(고치기 전에는 이 타워를 골라도
	# 그 칩이 없어서 '없다' 는 것밖에 못 봤다).
	var target = null
	for t in field.active_towers:
		if t == null:
			continue
		for l in t.synergy_labels:
			if str(l).length() > LONG_LABEL_LEN:
				target = t
				break
		if target != null:
			break
	if target == null:
		for t in field.active_towers:
			if t != null:
				target = t
				break
	if target == null:
		_emit("S5 타워가 없다")
		_emit("RELICCHIP_DONE")
		get_tree().quit(0)
		return
	field.tower_info_requested.emit(target)
	for i in 30:
		await get_tree().process_frame
	var modal_node: Node = main.modal_layer.get_node_or_null("TowerInfoModal")
	if modal_node == null:
		_emit("S5 정보창이 안 떴다")
		_emit("RELICCHIP_DONE")
		get_tree().quit(0)
		return
	var row: Node = modal_node.get_node_or_null("Panel/VBox/SynergyRow")
	var chip_n := -1
	if row != null:
		chip_n = row.get_child_count()
	_emit("S5 정보창 visible=%s · SynergyRow=%s · 칩 %d개" % [
		str(modal_node.is_visible_in_tree()), str(row != null), chip_n])
	var tex_chips := 0
	var drawn_chips := 0
	var glyph_chips := 0
	var bare_chips := 0
	var zero_size := 0
	if row != null:
		for chip in row.get_children():
			var n_tex := 0
			var n_lbl := 0
			var n_draw := 0
			var info: Array[String] = []
			var stack: Array = [chip]
			while stack.size() > 0:
				var n: Node = stack.pop_back()
				for k in n.get_children():
					stack.append(k)
				if n is TextureRect:
					var tr: TextureRect = n
					n_tex += 1
					if tr.size.x <= 0.0 or tr.size.y <= 0.0:
						zero_size += 1
					# 텍스처 **정체**까지 찍는다 — 14px 아이콘은 눈으로 구분이 안 되므로,
					# 서로 다른 PNG 를 쓰는지는 경로로만 확인된다.
					var tpath := "(null)"
					var tsz := "(?)"
					if tr.texture != null:
						tpath = tr.texture.resource_path
						tsz = str(tr.texture.get_size())
					info.append("tex=%s src=%s native=%s size=%s" % [
						"있음" if tr.texture != null else "없음", tpath.get_file(), tsz, str(tr.size)])
				elif n is Label:
					n_lbl += 1
					info.append("label=%s" % (n as Label).text)
				elif not (n is Container):
					# Label 도 TextureRect 도 아닌 **그려서 만든 아이콘**(특성 배지의
					# `TraitIconControl`). 컨테이너는 아이콘이 아니므로 제외한다 — 이 구분이
					# 없으면 특성 칩이 "아이콘없음" 으로 잘못 세어진다(2026-10-05 발견).
					n_draw += 1
					info.append("draw=%s" % n.get_class())
			if n_tex > 0:
				tex_chips += 1
			elif n_draw > 0:
				drawn_chips += 1
			elif n_lbl >= 2:
				glyph_chips += 1
			else:
				bare_chips += 1
			_emit("   칩 tex=%d label=%d draw=%d | %s" % [n_tex, n_lbl, n_draw, " / ".join(info)])
	_emit("S5 텍스처아이콘칩 %d · 그려진아이콘칩 %d · 글리프칩 %d · 아이콘없음칩 %d · 크기0텍스처 %d" % [
		tex_chips, drawn_chips, glyph_chips, bare_chips, zero_size])
	# 칩 행이 **접히는지** — `HFlowContainer` 로 바꾼 뒤 실제 높이를 잰다. 넘치면 버리지 않고
	# 접히므로 행 높이가 최소(24)를 넘는다. 행 하단이 패널 하단을 넘으면 레이아웃이 깨진 것이다.
	if row != null:
		var rowc: Control = row as Control
		var panelc: Control = modal_node.get_node_or_null("Panel") as Control
		var row_bottom: float = rowc.global_position.y + rowc.size.y
		var panel_bottom := -1.0
		if panelc != null:
			panel_bottom = panelc.global_position.y + panelc.size.y
		var fits: bool = panel_bottom < 0.0 or row_bottom <= panel_bottom
		_emit("S5 행높이=%.0f · 행하단=%.0f · 패널하단=%.0f · %s" % [
			rowc.size.y, row_bottom, panel_bottom, "OK" if fits else "★행이 패널 밖으로"])
	# ⚠️ headless 더미 렌더러는 이미지를 못 만든다 — `get_image()` 가 null 을 돌려주고,
	# 그 위에 바로 `save_png` 를 부르면 런타임 오류로 **코루틴이 죽어** quit 에 도달하지
	# 못한다(1차 실행이 정확히 그렇게 RC=2 워치독으로 끝났다). 게다가 더미 렌더러는
	# `texture_2d_get` ERROR 줄을 찍어 **'프로브 실패' 처럼 보인다** → headless 에서는
	# 아예 시도하지 않는다. 스크린샷은 창 모드에서만 얻어진다.
	if DisplayServer.get_name() == "headless":
		_emit("S5 스크린샷 생략(headless) — 창 모드에서만 얻어진다")
	else:
		var vtex: ViewportTexture = get_viewport().get_texture()
		_emit("S5 뷰포트텍스처=%s" % str(vtex != null))
		var shot: Image = vtex.get_image() if vtex != null else null
		_emit("S5 이미지=%s" % str(shot != null))
		if shot != null:
			var err: int = shot.save_png("E:/project/word_card/tmp/relicchip.png")
			_emit("S5 스크린샷 저장 err=%d" % err)

	_emit("RELICCHIP_DONE")
	get_tree().quit(0)

func _shop_desc(id: String) -> String:
	for r in ShopModal.ALL_RELIC_POOL:
		if str(r["id"]) == id:
			return str(r["desc"])
	return "(없음)"

func _range_mult() -> float:
	var df = load("res://scripts/tower/DefenseField.gd")
	return float(df.RANGE_RUNE_RANGE_MULT)

func _range_pct() -> int:
	var df = load("res://scripts/tower/DefenseField.gd")
	return int(df.RANGE_RUNE_RANGE_PCT)

## 문자열에 나오는 `N%` 의 N 을 전부 뽑아 정렬해 돌려준다.
## 라벨("활자의 정수 (+20% 피해)")과 상점 설명("... +20% ...")의 수치를 맞대기 위한 것.
func _pcts(s: String) -> Array:
	var out: Array = []
	for i in s.length():
		if s[i] != "%":
			continue
		var j := i - 1
		var digits := ""
		while j >= 0 and s[j] >= "0" and s[j] <= "9":
			digits = s[j] + digits
			j -= 1
		if digits != "":
			out.append(int(digits))
	out.sort()
	return out
