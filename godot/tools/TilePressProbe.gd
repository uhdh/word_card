extends Node
# 타일을 **누른 순간**이 호버와 구별되는가 (감사 §2.10 문제 1 / §5.2 17, 2026-09-23).
#
# 왜 문제였나 — 디렉터 지적 그대로다: "버튼은 작동하지만 눌렀다는 반응이 없음".
# 원인은 `pressed` 스타일박스에 `hover_style` 을 **그대로** 넘긴 것이었다:
#
#     btn_tile.add_theme_stylebox_override("hover",   hover_style)
#     btn_tile.add_theme_stylebox_override("pressed", hover_style)   # ← 같은 객체
#
# 그래서 마우스를 누르고 있는 동안 화면은 **호버와 완전히 동일**했다.
#
# ⚠️ 이 도구가 재는 것 — 한쪽만 재면 반쪽짜리다:
#   §1~§3 (모든 버튼) 누름≠호버 · 호버≠평소 · 누름≠평소 — **어떤 축에서든**
#   §4 눌림의 **방향** — 호버 배경이 불투명하면 더 어두워야 하고, 투명하면 채워져야 한다
#
# ⚠️ 왜 '어떤 축에서든' 인가 — **실제로 여기서 물렸다.** 처음엔 배경색만 비교했는데
#   슬롯 버튼(고정/힌트)은 비활성일 때 배경이 **투명**해서 호버 신호를 **테두리**로 낸다
#   (`LINE_NORMAL` → `TX_GOLD`). 그래서 배경 휘도가 `0.000 → 0.000` 이 되어 **멀쩡한
#   버튼 6개가 전부 실패**했다(RC=12). **채널을 고정하면 안 된다** — 같은 상태 변화를
#   위젯마다 다른 축으로 표현한다.
#
# ⚠️ §4 가 필요한 이유: §1~§3 만 있으면 "호버를 어둡게, 누름을 밝게" **뒤집은** 고침이
#   통과한다. 그러면 눌림은 생기지만 호버 감각이 반대로 되어 더 나빠진다.
#
# ⚠️ 재지 못하는 것: "사람이 눌렸다고 느끼는가". 여기서 재는 것은 색·테두리의 방향과 차이다.
#
# 실행: godot --headless --path . res://tools/TilePressProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 상대 휘도. "어둡다/밝다" 를 채널 평균이 아니라 눈이 느끼는 가중치로 잰다.
func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## 버튼의 상태별 StyleBoxFlat. 없으면 null.
func _sb(btn: Button, state: String) -> StyleBoxFlat:
	return btn.get_theme_stylebox(state) as StyleBoxFlat

## 두 스타일박스가 **어떤 축에서든** 다른가 — 배경색 · 테두리색 · 테두리 두께.
## ⚠️ 배경색만 보면 안 된다(위 머리말). 이 셋 중 하나라도 다르면 플레이어는 변화를 본다.
func _differs(a: StyleBoxFlat, b: StyleBoxFlat) -> bool:
	if a.bg_color != b.bg_color:
		return true
	if a.border_color != b.border_color:
		return true
	if a.border_width_left != b.border_width_left:
		return true
	return false

## 한 버튼의 세 상태를 재서 단언한다.
func _check_button(btn: Button, label: String) -> void:
	var normal := _sb(btn, "normal")
	var hover := _sb(btn, "hover")
	var pressed := _sb(btn, "pressed")
	if normal == null or hover == null or pressed == null:
		check(false, "[%s] 상태 스타일박스가 StyleBoxFlat 이 아니다" % label)
		return
	print("TILE_PRESS_PROBE %s normal=%.3f hover=%.3f pressed=%.3f hover_a=%.2f press_a=%.2f" % [
		label, _lum(normal.bg_color), _lum(hover.bg_color), _lum(pressed.bg_color),
		hover.bg_color.a, pressed.bg_color.a])

	# §1 누름과 호버가 다르다 — **이것이 원래 결함이었다**(같은 객체를 넘겼다)
	check(_differs(pressed, hover),
		"[%s] 누름이 호버와 어떤 축에서도 다르지 않다 — 눌러도 화면이 안 바뀐다" % label)
	# §2 호버가 평소와 다르다 (호버 피드백 자체가 살아 있는가)
	check(_differs(hover, normal), "[%s] 호버가 평소와 같다 — 호버 피드백이 없다" % label)
	# §3 누름이 평소와 다르다 (누른 게 '평소' 처럼 보이면 안 된다)
	check(_differs(pressed, normal), "[%s] 누름이 평소와 같다 — 누른 게 평소처럼 보인다" % label)

	# §4 방향 — 채널에 따라 '더 들어간' 모습이 다르다
	if hover.bg_color.a == 0.0:
		# 배경이 투명한 버튼(고스트류)은 눌림이 **채워져야** 보인다.
		# `darkened()` 를 투명색에 걸면 아무 변화가 없다 — 실제로 그렇게 짤 뻔했다.
		check(pressed.bg_color.a > 0.0,
			"[%s] 호버 배경이 투명한데 눌림도 투명하다 — 눌림이 안 보인다" % label)
	else:
		check(_lum(pressed.bg_color) < _lum(hover.bg_color),
			"[%s] 눌림(%.3f)이 호버(%.3f)보다 어둡지 않다" % [
				label, _lum(pressed.bg_color), _lum(hover.bg_color)])

## 타일의 버튼. 이름으로 찾는다(`_build_tile` 이 `TileButton` 이라고 붙인다).
func _tile_button(belt, index: int) -> Button:
	var tile: Control = belt.tile_node_at(index)
	if tile == null:
		return null
	return tile.get_node_or_null("TileButton") as Button

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

	var belt = main.jamo_belt
	var tile_btn := _tile_button(belt, 0)
	print("TILE_PRESS_PROBE baseline belt=%d tile_button=%s" % [
		belt.jamo_list.size(), "있음" if tile_btn != null else "없음"])
	# ⚠️ 버튼을 못 찾으면 아래 단언은 **아무것도 재지 않는다.** 먼저 그걸 막는다.
	check(tile_btn != null, "타일 버튼(TileButton)을 찾지 못했다 — 아무것도 재지 못한다")
	if tile_btn == null:
		get_tree().quit(failures + 1)
		return

	# ── 1~4. 타일 버튼 ───────────────────────────────────────────────────────
	_check_button(tile_btn, "타일")
	# 타일은 **호버에서 밝아지고 누르면 어두워진다** — 테마 `Button` 의 관례
	# (normal 0.102 → hover 0.141 → pressed 0.055). 방향을 명시로 못박는다.
	var t_n := _sb(tile_btn, "normal")
	var t_h := _sb(tile_btn, "hover")
	var t_p := _sb(tile_btn, "pressed")
	check(_lum(t_h.bg_color) > _lum(t_n.bg_color),
		"[타일] 호버(%.3f)가 평소(%.3f)보다 밝지 않다" % [_lum(t_h.bg_color), _lum(t_n.bg_color)])
	check(_lum(t_p.bg_color) < _lum(t_h.bg_color),
		"[타일] 누름(%.3f)이 호버(%.3f)보다 어둡지 않다" % [_lum(t_p.bg_color), _lum(t_h.bg_color)])

	# ── 5. 슬롯 버튼(고정/힌트) — 비활성은 배경이 투명하다 ──────────────────
	var slots: Array = belt.find_children("LockButton", "Button", true, false)
	slots += belt.find_children("HintButton", "Button", true, false)
	print("TILE_PRESS_PROBE slots=%d" % slots.size())
	check(slots.size() > 0, "슬롯 버튼(고정/힌트)을 찾지 못했다")
	for i in range(slots.size()):
		_check_button(slots[i], "슬롯%d/%s" % [i, slots[i].name])

	# ── 6. 회전 배지는 **의도적으로** 비어 있다 (참고 출력만) ────────────────
	# 여기는 단언하지 않는다 — 배제가 결정 사항이고, 바뀌면 그때 다시 판단한다.
	var rot: Array = belt.find_children("RotateButton", "Button", true, false)
	if rot.size() > 0:
		var r: Button = rot[0]
		print("TILE_PRESS_PROBE rotate_badge pressed=%s (의도적 배제 — 배지 축소 이유와 충돌)" % [
			"비어 있음" if _sb(r, "pressed") == null else "스타일 있음"])

	if failures == 0:
		print("TILE_PRESS_PROBE_OK")
	get_tree().quit(failures)
