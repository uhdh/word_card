# RelicTraitIconProbe.gd
# 상점 유물 카드의 설명이 **타워 특성을 아이콘으로 보여 주는가**, 그리고 그 아이콘이
# 문구를 **한 글자도 바꾸지 않는가** 를 잰다.
#
# 왜 필요한가 (2026-10-05):
#   유물 27종 중 다섯(폭발의 뇌관 · 연쇄의 베틀 · 선회의 톱니 · 관통 송곳 · 발화 기름)은
#   "폭발 타워 피해 +25%" 처럼 **어느 공격 형태에 걸리는지**를 설명 첫머리에 적는다.
#   카드 넷이 나란히 서고 문구가 전부 같은 회색이라, 어느 카드가 내 타워에 걸리는지
#   알려면 **네 문장을 다 읽어야** 했다. 로직은 이미 있었지만 표현이 없던 사건이다.
#
# 재는 것:
#   S0  기준선 — 아이콘이 **없는** 설명은 예전과 똑같이 라벨 하나인가 (구조가 갈라지지 않았나)
#   S1  문구가 말하는 특성 == **게임 로직이 말하는 특성** (독립 채널 대조)
#   S2  아이콘이 실제로 카드에 붙고, 문구가 **글자까지 그대로**인가
#   S3  아이콘이 **줄 수를 늘리지 않는가** — 아이콘을 숨긴 기준선과 맞댄다
#   S4  표 계약 — `KEYWORDS` 에 순서 사고(앞 키워드가 뒤 키워드에 포함)가 없는가
#   S5  양성 대조 — 특성 없는 문구는 아이콘을 얻지 않는다
#
# ⚠️ 루트는 반드시 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
extends Node

const ShopModal = preload("res://scripts/ui/ShopModal.gd")
const ShopModalScene = preload("res://scenes/tower/ShopModal.tscn")
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
const TraitIcon = preload("res://scripts/ui/TraitIcon.gd")
const AttackStyleScript = preload("res://scripts/core/AttackStyle.gd")

const OUT_PATH := "E:/project/word_card/tmp/relictraiticon_out.txt"
const SHOT_PATH := "E:/project/word_card/tmp/relictraiticon.png"
## 아이콘이 차지해야 하는 최소 한 변(px). 이보다 작으면 배지로 안 보인다.
const MIN_ICON_PX := 14.0
## 카드 설명 라벨의 글자 크기. 카드에서 이 크기의 라벨이 곧 설명이다.
const DESC_FONT_PX := 10

var failures := 0
var _lines: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		_emit("★실패 %s" % message)


func _emit(s: String) -> void:
	_lines.append(s)
	print(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null


func _watchdog() -> void:
	for i in 2400:
		await get_tree().process_frame
	_emit("WATCHDOG — 2400 프레임 안에 못 끝났다")
	get_tree().quit(124)


## 이름 앞 이모지를 뗀 한글만. `TowerInfoModal._relic_core_name` 과 같은 규칙이다.
func _core_name(raw: String) -> String:
	var i := 0
	while i < raw.length() and not _is_hangul(raw.unicode_at(i)):
		i += 1
	return raw.substr(i).strip_edges()


func _is_hangul(cp: int) -> bool:
	return cp >= 0xAC00 and cp <= 0xD7A3


## 라벨(`"선회의 톱니 (오브 +1)"`)이 어떤 유물에서 왔는지 접두어로 찾는다.
func _relic_of_label(label: String) -> Dictionary:
	for r in ShopModal.ALL_RELIC_POOL:
		var core := _core_name(str(r["name"]))
		if core != "" and label.begins_with(core):
			return r
	return {}


func _relic_by_id(id: String) -> Dictionary:
	for r in ShopModal.ALL_RELIC_POOL:
		if str(r["id"]) == id:
			return r
	return {}


## 카드 하나에서 **설명 라벨**(글자 크기 10)을 찾는다. 없으면 null.
func _desc_label(card: Node) -> Label:
	var stack: Array = [card]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n is Label and (n as Label).get_theme_font_size("font_size") == DESC_FONT_PX:
			return n
	return null


## 카드 하나에서 `TraitIcon` 을 찾는다. 없으면 null.
func _trait_icon(card: Node) -> Control:
	var stack: Array = [card]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n.get_script() == TraitIcon:
			return n as Control
	return null


## 결정적 재고 — 셔플에 기대지 않는다. 특성 유물 5종 + 특성 없는 유물 3종.
func _stock_for(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var r := _relic_by_id(str(id))
		if r.is_empty():
			continue
		var c := r.duplicate()
		c["sold"] = false
		out.append(c)
	return out


func _ready() -> void:
	_watchdog()
	_emit("RELIC_TRAIT_ICON_START")

	# ── S0·S2·S3·S5. 카드 구조 — 특성 유물과 아닌 것을 **한 재고에** 넣고 맞댄다 ──────
	# 기준선이 같은 화면 안에 있어야 "아이콘 때문에 달라졌다" 를 말할 수 있다.
	var trait_ids: Array = []
	var plain_ids: Array = []
	for r in ShopModal.ALL_RELIC_POOL:
		if TraitStyle.trait_id_in_text(str(r["desc"])) != "":
			trait_ids.append(str(r["id"]))
		elif plain_ids.size() < 3:
			plain_ids.append(str(r["id"]))
	_emit("S0 설명이 특성을 말하는 유물 %d종: %s" % [trait_ids.size(), ", ".join(trait_ids)])
	_emit("S0 대조용(특성 없음) %d종: %s" % [plain_ids.size(), ", ".join(plain_ids)])
	check(trait_ids.size() > 0,
		"설명이 특성을 말하는 유물이 하나도 없다 — 표가 끊겼거나 문구가 바뀌었다")

	var shop = ShopModalScene.instantiate()
	add_child(shop)
	await get_tree().process_frame
	shop.relic_stock = _stock_for(trait_ids + plain_ids)
	shop.current_gold = 9999
	shop._update_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var cards: Array = shop.relic_items_grid.get_children()
	_emit("S0 카드 %d장 (기대 %d장)" % [cards.size(), trait_ids.size() + plain_ids.size()])
	check(cards.size() == trait_ids.size() + plain_ids.size(),
		"카드 수가 재고와 다르다 — 재는 대상이 틀렸다")

	var seen_icon := 0
	var seen_plain := 0
	for i in range(cards.size()):
		var card: Node = cards[i]
		var lbl := _desc_label(card)
		var icon := _trait_icon(card)
		var desc := lbl.text if lbl != null else "(라벨없음)"
		var want := TraitStyle.trait_id_in_text(desc)
		var ctl: Control = card as Control

		if lbl == null:
			check(false, "설명 라벨을 못 찾았다 — 카드 구조가 바뀌었다")
			continue

		# ── S2. 문구 계약 — 아이콘은 문장을 **고치지 않는다** ────────────────────
		# 카드 순서 == 재고 순서다. 화면에 뜬 글자를 상점 표의 그 줄과 **글자까지** 맞댄다.
		var stock_desc := str(shop.relic_stock[i]["desc"])
		check(desc == stock_desc,
			"카드 문구가 상점 설명과 다르다 — 배지가 문장을 고쳤다: '%s' vs '%s'" % [desc, stock_desc])

		if want == "":
			# ── S5. 양성 대조 — 특성이 없으면 아이콘도 없어야 한다 ────────────────
			if icon != null:
				check(false, "특성이 없는 문구에 배지가 붙었다: '%s'" % desc)
			else:
				seen_plain += 1
			_emit("S5 [대조] %-28s 배지없음 OK · 라벨 %s" % [desc, str(lbl.get_class())])
			continue

		# ── S2. 아이콘이 실제로 붙었는가 ─────────────────────────────────────────
		if icon == null:
			check(false, "특성 '%s' 을 말하는데 배지가 없다: '%s'" % [want, desc])
			continue
		seen_icon += 1
		var ok_px: bool = icon.size.x >= MIN_ICON_PX and icon.size.y >= MIN_ICON_PX
		check(ok_px, "배지가 %s 로 눌렸다 (최소 %.0fpx)" % [str(icon.size), MIN_ICON_PX])
		check(icon.is_visible_in_tree(), "배지가 화면에 안 보인다: '%s'" % desc)
		# 그려서 만든 아이콘이어야 한다 — PNG 를 쓰면 특성 색·모양이 표와 갈라진다.
		check(not (icon is TextureRect) and not (icon is Label),
			"배지가 TextureRect/Label 이다 — `TraitStyle.draw_icon` 을 쓰는 Control 이어야 한다")
		# ⚠️ `icon` 은 `Control` 로 정적 타입이 잡혀 있다 — `icon.trait_id` 라고 쓰면
		#    파싱 단계에서 죽는다(`Control` 에 그 프로퍼티가 없다). 동적으로 읽는다.
		var icon_trait := str(icon.get("trait_id"))
		var icon_col: Color = icon.get("col")
		check(icon_trait == want,
			"배지가 '%s' 인데 문구는 '%s' 을 말한다" % [icon_trait, want])
		check(icon_col == TraitStyle.color_for(want),
			"배지 색이 표와 다르다: %s vs %s" % [str(icon_col), str(TraitStyle.color_for(want))])

		# ── S3. 줄 수 중립 — 아이콘을 숨긴 기준선과 맞댄다 ───────────────────────
		var lines_with: int = lbl.get_line_count()
		icon.visible = false
		await get_tree().process_frame
		var lines_without: int = lbl.get_line_count()
		var width_without: float = lbl.size.x
		icon.visible = true
		await get_tree().process_frame
		check(lines_with == lines_without,
			"배지가 줄 수를 늘렸다 (%d → %d줄): '%s'" % [lines_without, lines_with, desc])
		_emit("S3 %-30s 배지=%s(%s) · 줄 %d→%d(기준선) · 라벨폭 %.0f→%.0f · 카드 %.0f" % [
			desc, str(icon.size), want, lines_with, lines_without, lbl.size.x, width_without,
			ctl.size.x])
		check(lbl.size.x + MIN_ICON_PX + 3.0 <= ctl.size.x + 0.5,
			"배지+라벨이 카드 밖으로 나간다 (%.1f + %.0f > %.1f)"
			% [lbl.size.x, MIN_ICON_PX + 3.0, ctl.size.x])

	_emit("S2 배지 붙은 카드 %d장 · 배지 없는 대조 카드 %d장" % [seen_icon, seen_plain])
	check(seen_icon == trait_ids.size(),
		"배지가 붙은 카드가 %d장이다 (특성 유물 %d종이어야 한다)" % [seen_icon, trait_ids.size()])

	# ── S4. 표 계약 — 순서 사고 ────────────────────────────────────────────────
	# `trait_id_in_text` 는 표를 **앞에서부터** 훑는다. 앞 키워드가 뒤 키워드의 일부면
	# 뒤 키워드는 **영원히 안 잡힌다**("관통" 을 "지속 관통" 보다 앞에 두면 그 순간).
	# 그 사고는 문구를 하나도 안 고치고 표 한 줄만 옮겨서 난다 — 조용하다.
	var shadowed: Array[String] = []
	var dupes: Array[String] = []
	var seen_words: Dictionary = {}
	for i in range(TraitStyle.KEYWORDS.size()):
		var wi := str(TraitStyle.KEYWORDS[i]["word"])
		if seen_words.has(wi):
			dupes.append(wi)
		seen_words[wi] = true
		for j in range(i):
			var wj := str(TraitStyle.KEYWORDS[j]["word"])
			if wi.contains(wj):
				shadowed.append("%s 뒤의 %s" % [wj, wi])
	_emit("S4 키워드 %d개 · 중복 %d · 가려진 키워드 %d" % [
		TraitStyle.KEYWORDS.size(), dupes.size(), shadowed.size()])
	if not shadowed.is_empty():
		_emit("S4 가려진 목록: %s" % ", ".join(shadowed))
	check(shadowed.is_empty(),
		"앞 키워드가 뒤 키워드를 가린다 — 그 키워드는 영원히 안 잡힌다: %s" % str(shadowed))
	check(dupes.is_empty(), "키워드가 중복됐다: %s" % str(dupes))

	# ── S1. 독립 채널 — 게임 로직이 말하는 특성과 맞댄다 ──────────────────────
	# 문구에서 뽑은 특성(`trait_id_in_text`)은 **문구**를 읽은 것이고, `WordTower` 는
	# `has_relic(...) and trait_id == "..."` 로 **코드**가 정한 것이다. 둘이 다르면
	# 배지가 엉뚱한 특성을 가리킨다 — 이건 표를 아무리 봐도 안 보인다.
	var logic_trait := await _logic_trait_map()
	_emit("S1 로직이 밝힌 유물 %d종 (전역·모양 유물 포함)" % logic_trait.size())
	var multi := 0
	for rid in logic_trait:
		var traits: Array = logic_trait[rid]
		if traits.size() > 1:
			# 여러 특성의 타워에 붙는 유물 = 특정 형태 전용이 **아니다**(전역·글자 모양).
			# 이건 결함이 아니라 분류다 — 조용히 세기만 한다.
			multi += 1
			continue
		_emit("S1 [전용] %-22s → %s" % [rid, str(traits[0])])
	_emit("S1 한 특성에만 붙는 유물 %d종 · 여러 특성에 붙는(전역·모양) 유물 %d종" % [
		logic_trait.size() - multi, multi])

	var mismatched := 0
	for id in trait_ids:
		var r := _relic_by_id(str(id))
		var from_text := TraitStyle.trait_id_in_text(str(r["desc"]))
		var traits: Array = logic_trait.get(str(id), [])
		# ⭐ '같은 특성이 하나라도 있나' 가 아니라 **그 특성 하나뿐인가** 를 본다 —
		#    전용 유물이 다른 특성에도 붙으면 배지가 절반만 맞는 것이고, 그건 조용하다.
		var same: bool = traits.size() == 1 and str(traits[0]) == from_text
		if not same:
			mismatched += 1
		_emit("S1 %-14s 문구=%-16s 로직=%s %s" % [
			str(r["name"]), from_text, str(traits), "OK" if same else "★불일치"])
		check(same, "배지가 가리키는 특성('%s')과 게임 로직(%s)이 다르다: %s"
			% [from_text, str(traits), str(r["name"])])
	_emit("S1 특성 유물 %d종 · 문구↔로직 불일치 %d" % [trait_ids.size(), mismatched])

	# ── S6. 창 모드 스크린샷 ───────────────────────────────────────────────────
	if DisplayServer.get_name() == "headless":
		_emit("S6 스크린샷 생략(headless) — 창 모드에서만 얻어진다")
	else:
		# ⚠️ 위 검사는 카드 8장으로 했지만 실제 게임은 **최대 4장**이다
		#    (`_generate_relic_stock` 의 `mini(4, …)`). 8장을 그대로 찍으면 그리드가
		#    패널(740px) 밖으로 흘러넘쳐 그림이 게임 화면과 달라진다.
		#    배지 있는 카드 3장 + 없는 카드 1장 — 대조가 그림 안에 남게 고른다.
		shop.relic_stock = _stock_for([
			"relic_orbit_gear", "relic_blast_charge", "relic_burn_oil", "relic_range_rune"])
		shop._update_ui()
		for f in 5:
			await get_tree().process_frame
		_emit("S6 스크린샷용 재고 %d장" % shop.relic_stock.size())
		var vtex: ViewportTexture = get_viewport().get_texture()
		var shot: Image = vtex.get_image() if vtex != null else null
		if shot != null:
			_emit("S6 스크린샷 저장 err=%d (%dx%d)" % [shot.save_png(SHOT_PATH), shot.get_width(), shot.get_height()])
		else:
			_emit("S6 스크린샷 실패 — get_image() 가 null")

	if failures == 0:
		_emit("RELIC_TRAIT_ICON_PROBE_OK")
	else:
		_emit("RELIC_TRAIT_ICON_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)


## 게임 로직이 정한 `유물 → 특성` 표를 **실제 타워를 세워서** 얻는다.
##
## 값은 특성 id 의 **배열**이다 — 특정 형태 전용 유물이면 길이 1이고, 전역·글자 모양
## 유물이면 여러 특성에 붙어 길이가 2 이상이 된다. 길이를 보면 둘을 가릴 수 있다.
##
## `WordTower.gd` 의 `has_relic("relic_x") and trait_id == "y"` 가 유일한 출처다 —
## 그 문장을 여기에 다시 적지 않는다(사본이 되면 둘이 갈라진다). 대신 모든 특성의
## 타워를 세우고, 유물 라벨이 **어느 특성의 타워에 붙었는지**를 읽는다.
func _logic_trait_map() -> Dictionary:
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("S1 DefenseField 를 못 찾았다")
		return {}

	var all_ids: Array = []
	for r in ShopModal.ALL_RELIC_POOL:
		all_ids.append(str(r["id"]))
	field.relic_ids = all_ids
	field.set_act(2)

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
		if bucket.size() < 1:
			bucket.append(ws)
			by_trait[tid] = bucket
	var parsed: Array = []
	for tid in by_trait:
		for ws in by_trait[tid]:
			parsed.append({"syllable": ws, "word_data": WordDatabase.get_word_data(ws)})
	_emit("S1 특성 %d종 · 타워 %d개를 세운다" % [by_trait.size(), parsed.size()])
	if parsed.is_empty():
		_emit("S1 단어를 못 골랐다 — WordDatabase 가 비었나?")
		return {}

	var out: Dictionary = {}
	for i in range(0, parsed.size(), 3):
		field.update_towers_from_parsed_list(parsed.slice(i, i + 3))
		for f in 40:
			await get_tree().process_frame
		for t in field.active_towers:
			if t == null:
				continue
			for lbl in t.synergy_labels:
				var relic := _relic_of_label(str(lbl))
				if relic.is_empty():
					continue
				# ⚠️ **덮어쓰지 않고 모은다.** 덮어쓰면 "여러 특성에 붙는다" 는 사실이 사라지고,
				#    전용 유물이 다른 특성에도 붙는 결함이 마지막 값 하나로 가려진다.
				var rid := str(relic["id"])
				var bucket: Array = out.get(rid, [])
				if not bucket.has(str(t.trait_id)):
					bucket.append(str(t.trait_id))
				out[rid] = bucket
	# ⚠️ 스크린샷에 메인 씬이 겹치면 카드가 안 보인다 — 다 쓴 뒤 치운다.
	#    `queue_free()` 는 **지연**이라 프레임을 넘겨야 실제로 사라진다.
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return out
