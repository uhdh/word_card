extends Node
# 상점 버튼이 **왜** 막혔는지 말하는가 — `disabled` bool 하나에 사유가 사라지는 결함.
# (감사 §5.2 항목 18 의 잔여분 = §2.10-a 와 **같은 결함**, 2026-09-23)
#
# 왜 문제인가:
#   `btn_buy_relic.disabled = r["sold"] or (current_gold < r["cost"])`
#   유물 버튼은 **서로 다른 두 이유**로 막힌다 — '이미 삼' 과 '골드 부족'.
#   플레이어에게는 둘 다 그냥 회색 버튼이다. **코드가 아는 것을 화면이 안 보여 준다.**
#   리롤(갱신) 버튼은 더 심하다 — 사유를 말하지 않는 건 물론이고 가격 `10` 이
#   코드 3곳(`:157, :232, :233`)과 **씬 문구**까지 네 곳에 흩어져 있었다.
#
# ⚠️ 이 도구가 재는 것 (한쪽만 재면 반쪽짜리다):
#   §0 기준선 — 리롤에 골드가 모자랄 때 **사유가 없다** (고치기 전에는 여기서 실패해야 한다)
#   §1 사유 ↔ 판정 일치 — `disabled == (사유 != "")`. 사유만 만들고 판정을 안 고치면 거짓말이 된다
#   §2 사유가 **실제 상태**를 말하는가 — 골드 부족인데 '보유' 라고 하면 그것도 거짓말이다
#   §3 이미 산 유물 — 사유가 '보유' 이고, 골드가 모자라도 **'보유' 가 먼저**다
#   §4 가격 단일 출처 — 임계·차감·emit 셋이 모두 같은 상수를 쓰는가 (+ 씬 문구에 가격이 없는가)
#   §5 사유는 **툴팁**에 있다 (카드가 160px 라 버튼 글자에 넣으면 넘친다)
#
# ⚠️ 왜 사유를 `tooltip_text` 에서 읽는가: JamoBelt 가 그렇게 정했다(§2.10-a).
#   벨트 헤더도 상점 카드도 폭이 빠듯해 글자를 늘릴 수 없다. 두 화면이 같은 규칙을 써야
#   플레이어가 '막힌 이유는 툴팁에 있다' 를 한 번만 배운다.
#
# 실행: godot --headless --path . res://tools/ShopReasonProbe.tscn

const ShopModalScript = preload("res://scripts/ui/ShopModal.gd")
const ShopModalScene = preload("res://scenes/tower/ShopModal.tscn")
const SHOP_SCENE_PATH := "res://scenes/tower/ShopModal.tscn"

## 사유가 툴팁 본문과 구분되는 구분자 — `JamoBelt._with_reason()` 과 같은 규칙.
const REASON_SEP := "\n\n"

## 사유 문구의 표식 — 벨트(`BeltBlockReasonProbe.MARK`)·밀어내기(`AbilityReachProbe`,
## "같은 규칙을 쓴다")와 **같은 계약**이다. `disabled` 면 툴팁에 이게 있어야 하고,
## 막히지 않았으면 없어야 한다(본문에는 안 쓴다).
const MARK := "⚠️"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _all_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_buttons(c))
	return out

## 카드 하나에 버튼 하나. `relic_stock` 순서가 곧 화면 순서다.
func _card_buttons(shop) -> Array:
	var out: Array = []
	for card in shop.relic_items_grid.get_children():
		out.append_array(_all_buttons(card))
	return out

## 툴팁에서 **사유만** 뽑는다. 구분자가 없으면 사유가 없는 것이다.
func _reason_of(btn: Button) -> String:
	var tip: String = btn.tooltip_text
	if tip == "" or not tip.contains(REASON_SEP):
		return ""
	var parts: PackedStringArray = tip.split(REASON_SEP)
	return parts[parts.size() - 1]

## 결정적 재고 — `setup()` 의 셔플에 기대지 않는다.
func _stock(costs: Array) -> Array:
	var out: Array = []
	for i in range(costs.size()):
		out.append({
			"id": "probe_relic_%d" % i,
			"name": "탐침 유물 %d" % i,
			"cost": int(costs[i]),
			"desc": "탐침",
			"icon": "res://nonexistent_probe_icon.png",
			"sold": false,
		})
	return out

## 상태를 세팅하고 **한 프레임 기다린다**.
## ⚠️ `_update_ui()` 는 옛 카드를 `queue_free()` 하는데 그건 **지연**된다. 기다리지 않으면
##   옛 버튼이 아직 자식으로 남아 있어서 "카드가 22개다" 같은 헛수가 나온다(첫 실행 RC=7).
##   화면이 실제로 정착한 뒤에 세야 한다.
func _apply(shop, gold: int, costs: Array, sold: Array = []) -> void:
	shop.relic_stock = _stock(costs)
	for i in range(sold.size()):
		if sold[i]:
			shop.relic_stock[i]["sold"] = true
	shop.current_gold = gold
	shop._update_ui()
	await get_tree().process_frame

func _ready() -> void:
	var shop = ShopModalScene.instantiate()
	add_child(shop)
	await get_tree().process_frame

	# ⚠️ `get_script_constant_map()` 은 **인스턴스 메서드**다(2026-09-23 실측:
	#   클래스에 직접 부르면 `Parse Error: Cannot call non-static function ... directly`).
	#   그래서 인스턴스를 먼저 만들고 그 스크립트에서 읽는다.
	var constants: Dictionary = shop.get_script().get_script_constant_map()
	var price: int = int(constants["REFRESH_PRICE"]) if constants.has("REFRESH_PRICE") else -1
	print("SHOP_PROBE refresh_price=%d" % price)
	check(price > 0,
		"ShopModal 에 REFRESH_PRICE 상수가 없다 — 가격이 여러 곳에 흩어져 있다는 뜻이다")

	# ── 0. 기준선 — 골드가 모자란 리롤 버튼이 **사유를 말하는가** ──────────────
	# 고치기 전에는 툴팁이 비어 있어 여기서 실패한다. 이 절이 없으면
	# "상수만 뽑고 사유는 안 붙인" 고침이 통과한다.
	await _apply(shop, 0, [20, 30])
	var refresh_reason := _reason_of(shop.btn_refresh)
	print("SHOP_PROBE baseline refresh disabled=%s reason=%s"
		% [str(shop.btn_refresh.disabled), refresh_reason])
	check(shop.btn_refresh.disabled,
		"골드 0 인데 리롤 버튼이 눌린다 — 기준선이 틀렸다")
	check(refresh_reason != "",
		"리롤 버튼이 막혔는데 **이유를 말하지 않는다** (툴팁이 비었다) — §5.2 18 의 잔여 결함")
	var base_relic := _card_buttons(shop)
	check(base_relic.size() == 2,
		"유물 카드 버튼이 %d개다 (2여야 한다) — 재는 대상이 다르다" % base_relic.size())
	if base_relic.size() == 2:
		check(_reason_of(base_relic[0]) != "",
			"골드 0 인데 유물 버튼이 막힌 이유를 말하지 않는다")

	# ── 1. 사유 ↔ 판정 일치 — 사유가 곧 판정이어야 거짓말을 못 한다 ────────────
	# ⚠️ 이 절이 없으면 "사유는 만들었는데 disabled 는 따로 계산하는" 고침이 통과한다.
	#   그게 정확히 원래 결함의 구조다(둘을 따로 만들면 어긋난다).
	var mismatch: Array = []
	for gold in [0, 5, 9, 10, 11, 20, 30, 40, 200]:
		await _apply(shop, gold, [20, 30])
		for btn in _card_buttons(shop):
			var has_reason: bool = _reason_of(btn) != ""
			if btn.disabled != has_reason:
				mismatch.append("gold=%d disabled=%s reason=%s"
					% [gold, str(btn.disabled), _reason_of(btn)])
		var r_has: bool = _reason_of(shop.btn_refresh) != ""
		if shop.btn_refresh.disabled != r_has:
			mismatch.append("gold=%d refresh disabled=%s reason=%s"
				% [gold, str(shop.btn_refresh.disabled), _reason_of(shop.btn_refresh)])
	print("SHOP_PROBE invariant mismatches=%d" % mismatch.size())
	for m in mismatch:
		print("      %s" % m)
	check(mismatch.is_empty(),
		"`disabled` 와 사유가 %d건 어긋난다 — 버튼이 거짓말을 한다: %s" % [mismatch.size(), str(mismatch)])

	# ── 2. 사유가 **실제 상태**를 말하는가 ────────────────────────────────────
	# ⚠️ §1 만 있으면 "무조건 '보유' 라고 쓰는" 고침이 통과한다(판정과 일치하니까).
	#   판정↔사유와 **사유↔실제상태**는 다른 검사다.
	await _apply(shop, 10, [20, 30])   # 둘 다 못 산다
	var poor := _card_buttons(shop)
	check(poor.size() == 2, "골드 10 재고에서 카드가 %d개다" % poor.size())
	if poor.size() == 2:
		check(poor[0].disabled and poor[1].disabled, "골드 10 인데 20/30G 유물이 눌린다")
		check(_reason_of(poor[0]).contains("골드"),
			"골드가 모자란데 사유가 골드를 말하지 않는다: '%s'" % _reason_of(poor[0]))
		check(_reason_of(poor[0]).contains("20"),
			"사유가 필요한 금액을 말하지 않는다: '%s'" % _reason_of(poor[0]))
		check(_reason_of(poor[0]).contains("10"),
			"사유가 보유 금액을 말하지 않는다: '%s'" % _reason_of(poor[0]))

	# ── 3. 이미 산 유물 — 골드가 모자라도 사유는 '보유' ───────────────────────
	# ⚠️ 순서가 중요하다. 살 수 없는 이유 중 플레이어가 **바꿀 수 있는 것은 골드뿐**이다.
	#   '보유' 는 바꿀 수 없는 상태이므로 그쪽을 먼저 말해야 행동으로 이어진다.
	await _apply(shop, 10, [20, 30], [true, false])
	var sold_btns := _card_buttons(shop)
	check(sold_btns.size() == 2, "sold 재고에서 카드가 %d개다" % sold_btns.size())
	if sold_btns.size() == 2:
		var sold_reason := _reason_of(sold_btns[0])
		print("SHOP_PROBE sold reason='%s'" % sold_reason)
		check(sold_btns[0].disabled, "이미 산 유물 버튼이 눌린다 — 두 번 살 수 있다")
		check(sold_reason.contains("보유"),
			"이미 산 유물의 사유가 '보유' 를 말하지 않는다: '%s'" % sold_reason)
		check(not sold_reason.contains("골드가 부족"),
			"이미 산 유물인데 '골드 부족' 이라고 한다 — 순서가 뒤집혔다: '%s'" % sold_reason)

	# ── 3b. 사유 **표식** — `disabled` 면 툴팁에 `⚠️` 가 있어야 한다 ─────────────
	# ⚠️ 이 계약은 벨트(`BeltBlockReasonProbe.MARK` · "사유가 없으면 툴팁에 이게 없어야
	#   한다")와 밀어내기(`AbilityReachProbe` · "같은 규칙을 쓴다")가 세운 것이다.
	#   ⚠️ 그런데 **상점만 그 계약 밖**이었다 — §1·§2·§3 은 사유의 *내용*만 재고
	#   표식은 안 봤다. 그래서 '이미 보유한 유물' 사유만 표식이 빠져 있었고,
	#   아무 프로브도 그걸 못 잡았다(2026-10-06 실측).
	#   표식이 없으면 그 줄이 *경고* 인지 *덧붙인 설명* 인지 구분할 단서가 없다.
	var mark_bad: Array = []
	for gold in [0, 10, 40]:
		for sold in [[], [true, false]]:
			await _apply(shop, gold, [20, 30], sold)
			for btn in _card_buttons(shop):
				if btn.disabled != str(btn.tooltip_text).contains(MARK):
					mark_bad.append("gold=%d sold=%s disabled=%s 사유='%s'"
						% [gold, str(sold), str(btn.disabled), _reason_of(btn)])
			var r_dis: bool = shop.btn_refresh.disabled
			if r_dis != str(shop.btn_refresh.tooltip_text).contains(MARK):
				mark_bad.append("gold=%d refresh disabled=%s 사유='%s'"
					% [gold, str(r_dis), _reason_of(shop.btn_refresh)])
	print("SHOP_PROBE mark contract mismatches=%d" % mark_bad.size())
	for m in mark_bad:
		print("      %s" % m)
	check(mark_bad.is_empty(),
		"`disabled` 와 사유 표식(%s)이 %d건 어긋난다 — 막힌 이유가 경고로 안 보인다: %s"
		% [MARK, mark_bad.size(), str(mark_bad)])

	# ── 4. 가격 단일 출처 — 임계·차감·emit 셋이 같은 상수를 쓰는가 ────────────
	# ⚠️ 리터럴 `10` 이 세 곳에 있으면 하나만 고쳐도 나머지가 조용히 어긋난다.
	#   셋을 **각각** 재야 한다 — 임계만 맞고 차감이 틀리면 골드가 새어 나간다.
	if price > 0:
		await _apply(shop, price - 1, [20])
		check(shop.btn_refresh.disabled,
			"골드 %d(<%d) 인데 리롤이 눌린다 — 임계가 상수를 안 쓴다" % [price - 1, price])
		await _apply(shop, price, [20])
		check(not shop.btn_refresh.disabled,
			"골드 %d(=%d) 인데 리롤이 막혔다 — 임계가 상수를 안 쓴다" % [price, price])

		var costs: Array = []
		shop.refresh_bought.connect(func(c): costs.append(c))
		shop.current_gold = price + 5
		shop.btn_refresh.pressed.emit()
		print("SHOP_PROBE refresh after press gold=%d emitted=%s" % [shop.current_gold, str(costs)])
		check(shop.current_gold == 5,
			"리롤 차감이 %d 가 아니다 (남은 골드 %d, 5여야 한다) — 차감이 상수를 안 쓴다"
			% [price, shop.current_gold])
		check(costs == [price],
			"리롤이 emit 한 값이 %s 다 ([%d] 여야 한다) — emit 이 상수를 안 쓴다"
			% [str(costs), price])

		# ── 4b. 골드가 모자를 때 **직접 눌러도** 새지 않는가 ──────────────────
		# ⚠️ `disabled` 는 클릭을 막을 뿐이다 — `pressed.emit()` 은 그대로 통과한다.
		#   `_on_refresh_pressed()` 의 가드가 **두 번째 방어선**이고, 그 안의 임계도
		#   상수를 써야 한다. 첫 판은 여기를 안 재서 **임계만 `9` 로 바꾼 주입(I4)이
		#   그냥 통과했다** — 버튼이 막혀 있으니 정상 경로로는 안 보이는 결함이다.
		await _apply(shop, price - 1, [20])
		costs.clear()
		shop.btn_refresh.pressed.emit()
		print("SHOP_PROBE forced-press at gold=%d -> gold=%d emitted=%s"
			% [price - 1, shop.current_gold, str(costs)])
		check(shop.current_gold == price - 1,
			"골드 %d 인데 리롤을 강제로 누르니 %d 가 됐다 — 가드가 상수를 안 쓴다"
			% [price - 1, shop.current_gold])
		check(costs.is_empty(),
			"골드가 모자란데 리롤이 %s 를 emit 했다 — 가드가 상수를 안 쓴다" % str(costs))

	# 씬 문구에 가격이 박혀 있으면 그게 네 번째 출처다.
	# ⚠️ 노드 경로가 아니라 **씬 파일의 BtnRefresh 블록**을 읽는다 — 문구가 코드로
	#   덮어써지므로 화면을 봐서는 알 수 없다(덮어쓰는 순간 씬 값은 안 보인다).
	var scene_text := FileAccess.get_file_as_string(SHOP_SCENE_PATH)
	var first_text := ""
	if scene_text.contains("BtnRefresh"):
		var node_block := scene_text.substr(scene_text.find("BtnRefresh"))
		for line in node_block.split("\n"):
			if line.strip_edges().begins_with("text ="):
				first_text = line
				break
	print("SHOP_PROBE scene refresh text=%s" % first_text.strip_edges())
	check(first_text != "",
		"씬에서 BtnRefresh 의 text 줄을 못 찾았다 — 이 검사가 조용히 통과했다")
	check(not first_text.contains("10"),
		"씬 문구에 리롤 가격이 박혀 있다: %s — 상수가 네 번째 출처를 갖게 된다" % first_text.strip_edges())

	# ── 5. 사유는 **툴팁**에 있고 버튼 **글자**에는 없다 ─────────────────────
	# 카드가 160px 다. 사유를 글자에 넣으면 넘친다(벨트 헤더와 같은 이유).
	await _apply(shop, 10, [20])
	var narrow := _card_buttons(shop)
	if narrow.size() == 1:
		check(_reason_of(narrow[0]) != "", "사유가 툴팁에 없다")
		check(not narrow[0].text.contains("부족"),
			"사유가 버튼 글자에 들어갔다: '%s' — 카드는 160px 라 넘친다" % narrow[0].text)

	# ── 6. 두 화면의 문구가 **글자까지 같은가** ──────────────────────────────
	# 감사 §2.10-a 가 남긴 숙제다: "두 화면이 같은 문구를 쓰게 되므로 서식의 단일 출처를
	# 정할 것". 지금은 벨트와 상점이 **같은 문장을 각자 들고 있다** — 한쪽만 고치면
	# 플레이어는 같은 상태를 두 화면에서 다르게 읽는다(NumText.gd 가 세운 규칙).
	#
	# ⚠️ 기대 문구를 여기 **적지 않는다** — 그러면 사본이 셋이 된다. 두 파일에서 각각
	#   뽑아 **서로 같은지**만 본다. 그래서 이 검사는 문구를 바꿔도 안 깨지고,
	#   **한쪽만 바꿀 때만** 깨진다.
	var belt_fmt := _reason_format_in("res://scripts/ui/JamoBelt.gd")
	var shop_fmt := _reason_format_in("res://scripts/ui/ShopModal.gd")
	print("SHOP_PROBE reason format belt='%s' shop='%s'" % [belt_fmt, shop_fmt])
	check(belt_fmt != "", "JamoBelt 에서 골드 부족 문구를 못 찾았다 — 이 검사가 조용히 통과했다")
	check(shop_fmt != "", "ShopModal 에서 골드 부족 문구를 못 찾았다")
	check(belt_fmt == shop_fmt,
		"벨트와 상점이 같은 상태를 다르게 말한다 — 벨트='%s' 상점='%s'" % [belt_fmt, shop_fmt])

	if failures == 0:
		print("SHOP_REASON_PROBE_OK")
	get_tree().quit(failures)


## 파일 안에서 `골드가 부족합니다` 가 들어 있는 **문자열 리터럴**만 뽑는다.
## ⚠️ 줄 전체를 비교하지 않는 이유: 두 파일의 줄이 `[price, current_gold]` 와
##   `[r["cost"], current_gold]` 로 다르다. 비교해야 하는 건 **문구**지 코드가 아니다.
func _reason_format_in(path: String) -> String:
	var src := FileAccess.get_file_as_string(path)
	for line in src.split("\n"):
		if not line.contains("골드가 부족합니다"):
			continue
		var a := line.find("\"")
		if a < 0:
			continue
		var b := line.find("\"", a + 1)
		if b < 0:
			continue
		return line.substr(a + 1, b - a - 1)
	return ""
