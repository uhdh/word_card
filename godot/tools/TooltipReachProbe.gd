# TooltipReachProbe.gd
# **툴팁 문구가 플레이어에게 *도달* 하는가** — §5.2 의 네 항목이 똑같이 적어 둔 한 줄을 닫는다.
#
# 왜 재는가 (2026-10-05):
#   `TooltipAuthorProbe`(§2.17)는 **작성자**를 잰다 — "어느 문자열이 이겼는가". 그런데 그것은
#   **문자열이 노드에 들어 있다**는 것까지만 말한다. §5.2 의 네 항목은 전부 이렇게 끝난다:
#
#       **호버 시 툴팁이 실제로 뜨는지는 미검증**(헤드리스)
#
#   — `BeltBlockReasonProbe`(§2.10-a) · `ShopReasonProbe`(§2.10-c) · `TooltipTruthProbe`(§2.15) ·
#   `TooltipAuthorProbe`(§2.17). 즉 **"무엇을 말하는가" 는 넷 다 쟀고 "플레이어가 들을 수 있는가"
#   는 아무도 안 쟀다.**
#
#   ⚠️ 그리고 그 구멍은 **가설이 아니라 한 번 실현됐다** — §2.27: `BtnStartWave` 는
#      `.hide()` 만 있고 `.show()` 가 0건이라 **영영 안 보이는데**, 그 툴팁이 `[SPACE]` 단축키를
#      알리는 **유일한 문장**이었다. 그런데 `TooltipAuthorProbe` §1b 는 그 버튼을 목록에 넣고
#      **초록으로 통과했다**(문자열은 노드에 들어 있으니까). ⇒ **프로브가 도달 불가능한 문자열의
#      내용을 지키고 있었다.**
#      ✅ 2026-10-06 고침 — 그 노드와 대입을 지우고 `[SPACE]` 안내를 **막 클리어 모달**(보이는
#      본문)로 옮겼다. 도달은 `ActClearModalProbe` §2b 가 잰다. `TooltipAuthorProbe` 목록에서도
#      뺐다. 아래 S0b 는 이제 *"숨은 툴팁"* 표본을 **갖지 않는다**(그 표본 자체를 지웠으므로).
#
# ⚠️ §2.35 가 확립한 기법을 그대로 쓴다(그 절 §2.35-6):
#   호버는 `Input.warp_mouse` + `InputEventMouseMotion` → `push_input` 으로 재현되고,
#   팝업은 뷰포트의 **내부 자식**이라 `get_children(true)` 로 찾아야 하며, `Popup` 은 `Window` 라
#   `Control` 의 rect API 가 없다. 지연 0.5초는 **실시간**이다.
#
# 재는 것:
#   S0  툴팁을 가진 `Control` 전수 — 보이는 것 / 안 보이는 것 / 마우스를 못 받는 것
#   S0b 보고 — **도달 불가 후보**(안 보이거나 `MOUSE_FILTER_IGNORE`)와 그 문구
#   S1  ⭐ **판정** — 보이는 툴팁마다 실제로 호버해서 팝업이 뜨고 **문구가 글자까지 같은가**
#   S1b 판정이 공허하지 않은가(양성 대조 — 호버가 실제로 팝업을 띄우는가)
#   S2  스크린샷
#
# ⚠️ **창 모드 전용 판정** — 헤드는 호버도 팝업도 없다. S0/S0b 는 헤드리스로도 나온다.
# ⚠️ **`MOUSE_FILTER_IGNORE` 를 결함으로 단정하지 않는다** — 적 머리 위 배지처럼 *일부러*
#    IGNORE 인 표면이 있다(§2.19·§2.31). 그래서 S0b 는 **보고**이고, 판정은 S1(호버 실측)뿐이다.
# ⚠️ **§2.27 은 2026-10-06 에 (B) 로 고쳐졌다** — 숨은 버튼이 사라졌으므로 이 프로브의 S0b 에서
#    *"숨은 툴팁"* 표본은 더 이상 나오지 않는다. 남는 것은 `IGNORE` 표본이다.
extends Node

const OUT_PATH := "E:/project/word_card/tmp/tooltipreach.txt"
const SHOT_PATH := "E:/project/word_card/tmp/tooltipreach.png"

## 호버 후 팝업을 기다리는 실시간 시간(초). 툴팁 지연 기본값은 0.5초다.
const HOVER_WAIT := 0.75

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
	for i in 6000:
		await get_tree().process_frame
	_emit("WATCHDOG — 못 끝났다")
	get_tree().quit(124)


## 뷰포트에 붙은 **보이는** `Popup`. 엔진 툴팁은 내부 자식으로 붙는다 → `get_children(true)`.
func _find_popup() -> Popup:
	var stack: Array = [get_viewport()]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Popup and (n as Popup).visible:
			return n
		for k in n.get_children(true):
			stack.append(k)
	return null


## `Popup` 은 `Window` 라 `Control` 의 rect API 가 없다 — 창 API 로 잰다.
func _popup_rect(p: Popup) -> Rect2:
	return Rect2(Vector2(p.position), Vector2(p.size))


func _hovered_desc() -> String:
	var vp := get_viewport()
	if not vp.has_method("gui_get_hovered_control"):
		return "?"
	var h = vp.gui_get_hovered_control()
	return "null" if h == null else String(h.get_path())


func _nudge(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(1, 0)
	get_viewport().push_input(ev)


## 팝업 안의 첫 `Label`(엔진이 만든 툴팁 본문).
func _first_label(root: Node) -> Label:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Label:
			return n
		for k in n.get_children(true):
			stack.append(k)
	return null


## 트리 전체에서 툴팁이 있는 `Control` 을 모은다. `{path, node, text, visible, filter, size}`.
func _collect(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).tooltip_text != "":
			var c: Control = n
			out.append({
				"path": String(root.get_path_to(c)),
				"node": c,
				"text": c.tooltip_text,
				"visible": c.is_visible_in_tree(),
				"filter": c.mouse_filter,
				"size": c.size,
			})
		for k in n.get_children():
			stack.append(k)
	return out


## 지금 트리에서 `text` 를 툴팁으로 가진 **살아 있는** `Control` 을 찾는다.
##
## ⚠️ **경로로 붙잡으면 안 된다** — 벨트 타일 띠와 다음 웨이브 아이콘은 골드/라운드가 변할 때마다
##    재건축되고 자동 이름이 바뀌므로(`@PanelContainer@86` → `@91`) 경로가 사라진다. 그래서
##    호버 **직전에** 문구로 다시 찾는다. 이게 없으면 매 회차 *다른* 노드가 실패로 찍힌다.
func _find_live_by_text(root: Node, text: String) -> Control:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Control:
			var c: Control = n
			if c.tooltip_text == text and c.is_visible_in_tree():
				return c
		for k in n.get_children():
			stack.append(k)
	return null


## 게임이 자동으로 웨이브를 시작하므로 보상·막클리어 모달이 끼어들어 상단 바를 가릴 수 있다.
## 측정 전에 걷어낸다(§2.34 의 `_free_modals` 와 같은 이유).
func _clear_modals(main: Node) -> void:
	var layer = main.get("modal_layer")
	if layer == null:
		return
	for ch in (layer as Node).get_children():
		ch.queue_free()


func _ready() -> void:
	_watchdog()
	_emit("TOOLTIP_REACH_START")

	# ⚠️ 세이브가 있으면 그 상태(예: 2막 11R)로 이어서 시작한다 — 초기 상태를 고정한다.
	SaveManager.delete_save_file()
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_modals(main)
	await get_tree().process_frame
	# ⚠️ **벨트는 시작할 때 타일을 나눠 주며 여러 번 재건축한다** — 그 창에 호버하면 노드가
	#    교체돼 `hovered=null`(아무것도 안 맞음)이 나오고, 그건 **엔진 결함이 아니라 내 타이밍**이다.
	#    (2026-10-05 실측: 1차 실행은 `LockButton`, 2차는 `HintButton` 이 실패 — 매번 다른 노드.)
	#    그래서 재기 전에 **실시간으로** 가라앉힌다.
	await get_tree().create_timer(1.5, true, false, true).timeout
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_emit("S0 뷰포트 %s" % str(vp))

	# ── S0. 전수 ───────────────────────────────────────────────────────────
	var all := _collect(main)
	var visible_list: Array = []
	var hidden: Array = []
	var ignore: Array = []
	for d in all:
		if not bool(d["visible"]):
			hidden.append(d)
			continue
		if int(d["filter"]) == Control.MOUSE_FILTER_IGNORE:
			ignore.append(d)
			continue
		visible_list.append(d)
	_emit("S0 툴팁 가진 Control %d개 — 보임 %d · 숨김 %d · MOUSE_FILTER_IGNORE %d" % [
		all.size(), visible_list.size(), hidden.size(), ignore.size()])
	check(all.size() > 0, "툴팁을 가진 Control 이 0개다 — 재는 대상이 틀렸다")
	check(visible_list.size() > 0, "보이는 툴팁이 0개다 — S1 이 공허해진다")

	# ── S0b. 보고 — 도달 불가 후보 (판정 아님) ──────────────────────────────
	# ⚠️ IGNORE 는 **일부러** 그런 표면이 있다(적 머리 위 배지 — §2.19·§2.31).
	#    그래서 여기서는 **보고만** 한다. 결함 판정은 S1 의 호버 실측뿐이다.
	for d in hidden:
		_emit("S0b 숨김 %s | %s" % [d["path"], str(d["text"]).substr(0, 60)])
	for d in ignore:
		_emit("S0b IGNORE %s | %s" % [d["path"], str(d["text"]).substr(0, 60)])

	# ── S0c. 판정 — 툴팁을 가진 **버튼**이 마우스를 못 받으면 안 된다 ─────────
	# ⚠️ `MOUSE_FILTER_IGNORE` **자체는 결함이 아니다** — 적 머리 위 배지처럼 *일부러* 그런 표면이
	#    있다(§2.19·§2.31 · §2.31 의 저자는 "10px 움직이는 표적에 호버를 요구하는 것은 신뢰할 수
	#    없는 UX" 라고 적어 두었다). 그래서 S0b 는 **보고**다.
	#    그런데 **버튼**이 IGNORE 면 이야기가 다르다 — 누를 수도 없고 툴팁도 못 띄운다.
	#    버튼의 존재 이유가 클릭이므로 **그건 실수일 수밖에 없다.** 이 절이 그 경계를 잠근다.
	#    (IGNORE 를 전부 실패로 세면 배지가 걸려 거짓 양성이 난다 — 그래서 **버튼만** 잰다.)
	var buttons_seen := 0
	var dead_buttons: Array = []
	for d in all:
		if not ((d["node"] as Node) is BaseButton):
			continue
		buttons_seen += 1
		if int(d["filter"]) == Control.MOUSE_FILTER_IGNORE:
			dead_buttons.append(d["path"])
	check(buttons_seen > 0, "툴팁을 가진 버튼이 0개다 — S0c 가 공허하다")
	check(dead_buttons.is_empty(),
		"툴팁을 가진 버튼 %d개가 `MOUSE_FILTER_IGNORE` 라 **누를 수도 툴팁을 띄울 수도 없다** (%s)"
			% [dead_buttons.size(), str(dead_buttons)])
	_emit("S0c 툴팁 가진 버튼 %d개 · IGNORE(도달 불가) %d개" % [buttons_seen, dead_buttons.size()])

	if DisplayServer.get_name() == "headless":
		_emit("S1 생략(headless) — 호버·팝업은 창 모드 전용. **S0/S0b 는 유효하다.**")
		if failures == 0:
			_emit("TOOLTIP_REACH_PROBE_OK")
		else:
			_emit("TOOLTIP_REACH_PROBE_FAIL %d" % failures)
		get_tree().quit(failures)
		return

	# ── S1. ⭐ 판정 — 보이는 툴팁마다 실제로 호버한다 ────────────────────────
	#
	# ⚠️ **판정 단위는 노드가 아니라 *문구* 다.** 이유(2026-10-05 실측): 벨트 타일 띠와 다음 웨이브
	#    아이콘은 **골드가 변할 때마다 재건축**되고, 자동 이름(`@PanelContainer@86` → `@91`)이
	#    바뀌므로 **경로가 사라진다**. 노드를 붙잡아 두면 매 회차 *다른* 노드가 실패로 찍힌다
	#    (1차 `LockButton` · 2차 `HintButton` · 3차 `LockButton`). 그건 엔진 결함이 아니라 내 타이밍이다.
	#    계약은 *"이 문구가 플레이어에게 도달하는가"* 이므로 **문구로 세고**, 호버 직전에
	#    **살아 있는 노드를 다시 찾는다**(`_find_live_by_text`).
	var texts: Array = []
	for d in visible_list:
		if not texts.has(String(d["text"])):
			texts.append(String(d["text"]))
	var delivered := 0
	var wrong_text: Array = []
	var not_hit: Array = []
	var offscreen: Array = []
	var freed: Array = []
	var view := Rect2(Vector2.ZERO, vp)
	for t in texts:
		var text: String = t
		var c: Control = _find_live_by_text(main, text)
		_clear_modals(main)
		await get_tree().process_frame          # `queue_free()` 는 지연이다
		if c == null or not is_instance_valid(c):
			c = _find_live_by_text(main, text)   # 모달을 걷어낸 뒤 다시 찾는다
		if c == null:
			freed.append(text)
			continue
		var rect: Rect2 = c.get_global_rect()
		if rect.size.x < 1.0 or rect.size.y < 1.0:
			not_hit.append([text, "크기 0 (%s)" % str(rect.size)])
			continue
		# ⚠️ **화면 밖은 '도달 불가' 가 아니다** — 벨트 타일 띠는 `ScrollContainer` 안이라
		#    스크롤하지 않으면 밖에 있는 타일이 있다(플레이어는 스크롤해서 닿는다).
		#    여기서 실패로 세면 **레이아웃이 정상인데 빨개진다**. 따로 보고한다.
		var centre: Vector2 = rect.get_center()
		if not view.has_point(centre):
			offscreen.append([text, str(centre)])
			continue
		Input.warp_mouse(centre)
		_nudge(centre)
		await get_tree().create_timer(HOVER_WAIT, true, false, true).timeout
		var popup := _find_popup()
		var hov := _hovered_desc()
		# ⚠️ **한 번 더 시도한다** — 컨테이너가 한 프레임 사이에 자리를 옮기면 rect 가 낡는다.
		#    재시도는 **노드와 rect 를 다시 읽는다**(같은 좌표로 두 번 밀면 아무것도 안 변한다).
		if popup == null:
			var again := _find_live_by_text(main, text)
			if again != null:
				var r2: Rect2 = again.get_global_rect()
				if r2.size.x >= 1.0 and r2.size.y >= 1.0 and view.has_point(r2.get_center()):
					Input.warp_mouse(r2.get_center())
					_nudge(r2.get_center())
					await get_tree().create_timer(HOVER_WAIT, true, false, true).timeout
					popup = _find_popup()
					hov = "%s (재시도)" % _hovered_desc()
		if popup == null:
			# ⚠️ **원인을 가른다** — 내 호버가 안 먹었는가, 엔진이 안 띄웠는가, 노드가 교체됐는가.
			if _find_live_by_text(main, text) == null:
				freed.append(text)
			else:
				not_hit.append([text, "팝업 없음 · rect=%s · hovered=%s" % [str(rect), hov]])
			continue
		var lbl := _first_label(popup)
		var got := "" if lbl == null else lbl.text
		if got == text:
			delivered += 1
		else:
			wrong_text.append([text, got])
		# 다음 표적을 위해 팝업을 닫는다(마우스를 밖으로 보내면 엔진이 닫는다).
		_nudge(centre + Vector2(0.0, 200.0))

	_emit("S1 보이는 툴팁 **문구 %d종** 중 **%d종이 그대로 도달** · 팝업없음 %d · 문구다름 %d · 화면밖 %d · 도중에 사라짐 %d" % [
		texts.size(), delivered, not_hit.size(), wrong_text.size(), offscreen.size(), freed.size()])
	for w in wrong_text:
		_emit("S1 문구다름\n    기대=%s\n    실제=%s" % [JSON.stringify(w[0]), JSON.stringify(w[1])])
	for n in not_hit:
		_emit("S1 팝업없음 %s · %s" % [JSON.stringify(n[0]), n[1]])
	for o in offscreen:
		_emit("S1 화면밖 %s · 중심 %s (스크롤하면 닿는다 — 결함 아님)" % [JSON.stringify(o[0]), o[1]])
	for f in freed:
		_emit("S1 도중에 사라짐 %s (게임이 계속 돌아 노드가 교체됐다 — 결함 아님)" % JSON.stringify(f))
	check(wrong_text.is_empty(), "툴팁 %d종이 화면에 **다른 문구**로 뜬다" % wrong_text.size())
	check(not_hit.is_empty(), "툴팁 %d종이 호버해도 **뜨지 않는다**" % not_hit.size())

	# ── S1b. 양성 대조 — 이 절이 공허하지 않은가 ────────────────────────────
	# ⚠️ 위 루프가 **한 번도 팝업을 못 띄웠다면** "도달했다" 도 "안 됐다" 도 아무 뜻이 없다.
	#    (호버 기법 자체가 깨지면 전부 `팝업없음` 으로 보이는데, 그건 엔진 결함이 아니다.)
	check(delivered > 0, "S1b 양성 대조 실패 — 보이는 툴팁 **하나도** 팝업을 못 띄웠다. 호버 기법을 의심하라")

	# ── S2. 스크린샷 ──────────────────────────────────────────────────────
	var vtex: ViewportTexture = get_viewport().get_texture()
	var shot: Image = vtex.get_image() if vtex != null else null
	if shot != null:
		_emit("S2 스크린샷 err=%d %dx%d" % [shot.save_png(SHOT_PATH), shot.get_width(), shot.get_height()])
	else:
		_emit("S2 스크린샷 실패 — get_image() 가 null")

	if failures == 0:
		_emit("TOOLTIP_REACH_PROBE_OK")
	else:
		_emit("TOOLTIP_REACH_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
