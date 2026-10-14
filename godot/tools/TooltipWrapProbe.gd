# TooltipWrapProbe.gd
# **Godot 의 기본 툴팁 팝업은 접히는가** — §2.32 S3 가 *"미검증"* 으로 남긴 한 줄을 닫는다.
#
# 왜 재는가 (2026-10-05):
#   §2.13-2 는 상단 바 예고를 **짧은 형태**로 줄이고, 전체 문구를 **툴팁과 라운드 모달**에
#   넘겼다("정보 손실 0"). 그런데 §2.32 가 재 보니 툴팁의 **가장 긴 줄이 1418 px** 로
#   화면(1280)보다 길다. 그때는 *글자 폭*만 쟀고 **팝업이 접히는지는 안 쟀다** —
#   접히면 결함이 아니고, 안 접히면 **전체 문구가 잘리는 유일한 표면**이 된다.
#
#   ⚠️ 이건 **엔진 동작**이라 코드를 읽어 판정할 수 없다(`Viewport._gui_show_tooltip` 은
#      내 코드가 아니다). 실제로 호버해서 **팝업을 띄우고 재는** 수밖에 없다.
#
# 고침 (§2.35 대안 A · 2026-10-06 · 감독 결정):
#   결론은 **"접히지 않는다"** 였고, 그래서 문구가 화면보다 넓은 만큼 **잘렸다.**
#   고친 것은 문구가 아니라 **그릇**이다 — `BtnStage` 에 `WrappingTooltipButton.gd` 를 붙여
#   `_make_custom_tooltip()` 이 **접히는 라벨**을 돌려주게 했다(§2.32 의 "자동 줄바꿈" 과
#   같은 판단). 문구는 **0자 변경**이다.
#   ⚠️ 그래서 이 프로브의 **판정 기준도 함께 바뀌었다** — 자세한 이유는 S0c 주석에 있다.
#      (기준을 안 바꾸면 고침 뒤에도 빨강이 남아 "고쳤는데 왜 빨갛나" 가 된다.)
#
# 재는 것:
#   S0c 도달 가능한 (막, 라운드) **전수** 스윕 — **접은 결과**가 화면 밖으로 나가는가(=범위)
#   S0  그 최악 상태의 툴팁 문구(가장 긴 줄 · 길이)
#   S0b 버튼이 실제로 거기 있는가(rect·가시성·mouse_filter) — 안 뜰 때 **원인을 가른다**
#   S1  호버 → 팝업이 실제로 떴는가(안 뜨면 나머지가 공허하다) · **전략 2개 × 재시도**
#   S2  팝업 rect 가 화면 안인가 · 라벨이 접혔는가(`autowrap_mode` · 줄 수)
#   S3  스크린샷
#
# ⚠️ **창 모드 전용** — 헤드리스에는 호버도 팝업도 없다(RC=2 로 알린다). 단 S0c/S0 는
#    폰트 계측이라 헤드리스에서도 나온다(그래서 headless 조기 반환을 **뒤로** 미룬다).
# ⚠️ 툴팁 지연 기본값은 0.5초(`gui/timers/tooltip_delay_sec`) → **실시간**으로 기다린다.
# ⚠️ **"팝업이 안 떴다" 는 두 가지 뜻이다** — (a) 엔진이 안 띄웠다 (b) **내 호버가 안 먹었다**.
#    구별 없이 결론 내면 후자를 전자로 오독한다. 그래서 S0b 와 `gui_get_hovered_control()`
#    로 **호버가 먹었는지**를 따로 본다.
#
# ⚠️ 2026-10-05 에 이 프로브가 **두 번 스스로를 속였다** — 둘 다 내 실수였고, 고칠 때마다
#    결론이 바뀌었다. 같은 함정을 다시 밟지 않도록 여기에 적어 둔다:
#      1) `get_children()` 은 **내부 자식(internal)을 뺀다** → 엔진이 띄운 팝업을 못 찾고
#         "엔진이 안 띄웠다" 로 **6회 보고**했다. 실제로는 첫 시도에 떠 있었다.
#      2) **`Popup extends Window` — `Control` 이 아니다.** `get_global_rect()` 를 부르면
#         런타임 오류로 **코루틴이 죽고** 프로브가 조용히 멈춘다(워치독 RC=124).
#         창은 `position`/`size` 로 잰다.
extends Node

const OUT_PATH := "E:/project/word_card/tmp/tooltipwrap.txt"
const SHOT_PATH := "E:/project/word_card/tmp/tooltipwrap.png"

## 실측된 툴팁 팝업 여백 — 라벨 최소폭 1418 → 팝업 폭 1438 (2026-10-05).
## S0c 의 "잘림" 판정은 이 **하나의 실측값**에서 유도한 것이지, 60개를 다 띄워 본 것이 아니다.
const POPUP_PAD := 20.0

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
	for i in 3600:
		await get_tree().process_frame
	_emit("WATCHDOG — 못 끝났다")
	get_tree().quit(124)


## 뷰포트에 붙은 **보이는** `Popup` 을 찾는다. 엔진 툴팁은 `PopupPanel` 로 뷰포트에 직접 붙는다.
##
## ⚠️ **`get_children()` 은 내부 자식(internal)을 빼놓는다** — 기본값이 `include_internal=false` 다.
##    엔진이 만든 노드는 보통 내부 자식으로 붙으므로, 이걸 `false` 로 두면 **팝업이 떠 있어도
##    못 찾는다** → "엔진이 안 띄웠다" 는 **거짓 결론**이 된다(2026-10-05 실측: hovered 는
##    `BtnStage` 인데 팝업 0개로 6회 보고했다). 그래서 **`get_children(true)` 로 훑는다.**
func _find_popup() -> Popup:
	var stack: Array = [get_viewport()]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Popup and (n as Popup).visible:
			return n
		for k in n.get_children(true):
			stack.append(k)
	return null


func _hovered_desc() -> String:
	var vp := get_viewport()
	if not vp.has_method("gui_get_hovered_control"):
		return "?"
	var h = vp.gui_get_hovered_control()
	if h == null:
		return "null"
	return String(h.get_path())


func _nudge(pos: Vector2, via_parse: bool) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(1, 0)
	if via_parse:
		Input.parse_input_event(ev)
	else:
		get_viewport().push_input(ev)


## 문구에서 **가장 긴 줄의 폭(px)**. **접히지 않는** 팝업에서는 이 값이 곧 팝업의 최소 폭이다.
## ⚠️ 2026-10-06 부터 `BtnStage` 는 접히므로, 이 값은 **판정이 아니라 보고**다 —
##    "접기 전에 얼마나 넓었나" 를 남겨야 고침의 크기를 나중에 확인할 수 있다.
func _longest_line_px(text: String, font: Font, fsize: int) -> float:
	var w := 0.0
	for line in text.split("\n"):
		var lw: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		if lw > w:
			w = lw
	return w


## 문구를 `width` 폭으로 **접었을 때의 크기**.
##
## `Font.get_multiline_string_size()` 가 접힌 결과를 그대로 돌려주므로, 팝업이 접히는지를
## **headless 에서도** 판정할 수 있다(호버가 필요한 S1·S2 와 달리 폰트 계측만 쓴다).
func _wrapped_size(text: String, font: Font, fsize: int, width: float) -> Vector2:
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, fsize)


## 버튼에 붙은 스크립트에서 **툴팁 최대 폭 상수**를 읽는다.
##
## ⚠️ 프로브에 숫자를 **복사해 두지 않는다.** 사본은 조용히 어긋나고, 그러면 프로브가
##    통과해도 실제 팝업은 다른 폭이 된다. 상수가 사라지면 `0` 을 돌려주고 S0c 가 실패한다
##    (조용히 화면 폭으로 대체하면 **공짜 통과**가 된다).
func _tooltip_max_width(btn: Button) -> float:
	var scr = btn.get_script()
	if scr == null:
		return 0.0
	var cmap: Dictionary = scr.get_script_constant_map()
	return float(cmap.get("MAX_WIDTH", 0.0))


func _ready() -> void:
	_watchdog()
	_emit("TOOLTIP_WRAP_START")

	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_emit("S0 뷰포트 %s" % str(vp))

	var btn: Button = main.btn_stage
	if btn == null:
		_emit("btn_stage 가 없다")
		get_tree().quit(3)
		return
	var font: Font = btn.get_theme_font("font")
	var fsize: int = btn.get_theme_font_size("font_size")
	_emit("S0 폰트 %dpx" % fsize)

	# ── S0c. 전수 스윕 — 도달 가능한 (막, 라운드) ────────────────────────────
	# ⚠️ 툴팁은 **상태에 따라 문구가 달라진다.** 한 상태만 재면 "이 상태는 잘린다" 까지만
	#    말할 수 있다. 감독이 알아야 하는 것은 **범위**다 — 몇 개 중 몇 개가 잘리는가.
	#    §2.13-2 는 "60개 전부" 라고 적었지만 그건 **바(1104px) 기준**이었다. 툴팁은 안 쟀다.
	#
	# ⚠️ **판정 기준이 2026-10-06 에 바뀌었다** (§2.35 대안 A 적용). 예전에는 *문구의
	#    최장 줄*을 화면 폭과 비교했다 — 팝업이 **접히지 않던** 시절에는 그 값이 곧 팝업
	#    폭이었기 때문이다. 이제 `BtnStage` 는 `WrappingTooltipButton` 이라 팝업이 **접힌다.**
	#    접히면 최장 줄은 더 이상 팝업 폭이 아니므로, **접은 결과**가 화면에 들어가는지를
	#    잰다(가로·세로 둘 다 — 폭을 묶으면 높이가 자란다).
	#    ⚠️ 기준을 안 바꾸면 고침 뒤에도 빨강이 남아 "고쳤는데 왜 빨갛나" 가 된다.
	#    ⚠️ 대신 **약해지지 않았는지**를 확인해야 한다: 폭을 묶어도 높이가 화면을 넘으면
	#       여전히 실패한다(아래 check 가 둘 다 본다).
	var max_w: float = _tooltip_max_width(btn)
	check(max_w > 0.0,
		"BtnStage 에서 툴팁 최대 폭 상수를 못 읽었다 — 접히는지 판정할 기준이 사라진다")
	if max_w <= 0.0:
		max_w = vp.x
	_emit("S0c 툴팁 최대 폭 %.0fpx (스크립트 상수) · 화면 %.0f" % [max_w, vp.x])

	var sweep_total := 0
	var sweep_clip := 0
	var sweep_worst_w := 0.0
	var sweep_worst_h := 0.0
	var worst_act := 1
	var worst_wave := 0
	for act in [1, 2, 3]:
		var act_clip := 0
		var act_worst_h := 0.0
		for wave in range(int(field.MAX_WAVES_PER_ACT)):
			field.set_act(act)
			field.current_wave = wave
			await get_tree().process_frame
			main._refresh_stage_tooltip(field.next_round_preview())
			var wrapped: Vector2 = _wrapped_size(btn.tooltip_text, font, fsize, max_w)
			sweep_total += 1
			if wrapped.x + POPUP_PAD > vp.x or wrapped.y + POPUP_PAD > vp.y:
				sweep_clip += 1
				act_clip += 1
			if wrapped.y > sweep_worst_h:
				sweep_worst_h = wrapped.y
				sweep_worst_w = wrapped.x
				worst_act = act
				worst_wave = wave
			if wrapped.y > act_worst_h:
				act_worst_h = wrapped.y
		_emit("S0c %d막 — 접힌 최대 높이 %.0fpx · 잘림 %d/%d" % [
			act, act_worst_h, act_clip, int(field.MAX_WAVES_PER_ACT)])
	_emit("S0c 전수 %d개 중 **%d개가 잘린다** · 접힌 최대 %.0f×%.0f (%d막 %dR) · 화면 %.0f×%.0f" % [
		sweep_total, sweep_clip, sweep_worst_w, sweep_worst_h,
		worst_act, worst_wave + 1, vp.x, vp.y])
	check(sweep_total > 0, "스윕 표본이 0 — 재는 대상이 틀렸다")
	check(sweep_clip == 0,
		"툴팁을 접고도 %d/%d개가 화면 밖으로 나간다 (접힌 최대 %.0f×%.0f · 화면 %.0f×%.0f)"
		% [sweep_clip, sweep_total, sweep_worst_w, sweep_worst_h, vp.x, vp.y])

	# ── S0. 최악 상태의 문구로 되돌린다(창 모드 S1/S2 가 이 상태를 띄운다) ────
	field.set_act(worst_act)
	field.current_wave = worst_wave
	await get_tree().process_frame
	main._update_next_round_preview()
	await get_tree().process_frame
	var tip: String = btn.tooltip_text
	var rows: PackedStringArray = tip.split("\n")
	var longest := ""
	for r in rows:
		if r.length() > longest.length():
			longest = r
	_emit("S0 툴팁 %d자 · %d줄 · 최장 줄 %d자" % [tip.length(), rows.size(), longest.length()])
	_emit("S0 최장 줄: %s" % longest)
	# 접기 **전**의 폭을 남긴다 — 고침의 크기(380px 초과 → 0)를 나중에 대조할 수 있게.
	_emit("S0 접기 전 최장 줄 %.0fpx · 접은 뒤 %.0fpx (상한 %.0f)" % [
		_longest_line_px(tip, font, fsize),
		_wrapped_size(tip, font, fsize, max_w).x, max_w])

	# ── S0b. 버튼이 실제로 거기 있는가 ────────────────────────────────────
	# ⚠️ 팝업이 안 떴을 때 **원인을 가르는 절**이다. rect 가 0 이면 호버는 애초에 불가능하다.
	var rect: Rect2 = btn.get_global_rect()
	_emit("S0b 버튼 rect %s · 가시 %s · 트리내가시 %s · mouse_filter %d · tooltip %s" % [
		str(rect), str(btn.visible), str(btn.is_visible_in_tree()),
		btn.mouse_filter, str(btn.tooltip_text != "")])
	_emit("S0b 창 포커스 %s · DisplayServer %s · 창 %s" % [
		str(get_window().has_focus()), DisplayServer.get_name(), str(vp)])
	# ⚠️ 툴팁 타이머는 **`Timer` 노드**라 `Engine.time_scale` 을 따른다 — 0 이면 영영 안 뜬다.
	#    (이 게임의 '일시정지' 가 정확히 `time_scale = 0` 이다 — 그래서 확인한다.)
	_emit("S0b Engine.time_scale %.2f · tree.paused %s" % [
		Engine.time_scale, str(get_tree().paused)])

	if DisplayServer.get_name() == "headless":
		# ⚠️ 여기서 `quit(2)` 로 빠져나가면 **실패 수와 종료 코드가 충돌**한다.
		#    (고치기 전에는 실제로 실패 2개를 냈다 — S0c 56/60 · S2 초과 380px.)
		#    S0c/S0 는 **폰트 계측**이라 headless 로도 판정된다. 그러니 건너뛰는 것은
		#    호버가 필요한 S1~S3 뿐이고, **판정은 그대로 살려** 같은 코드로 끝낸다.
		_emit("S1~S3 생략(headless) — 호버·팝업·스크린샷은 창 모드 전용. **S0c/S0 판정은 유효하다.**")
	else:
		await _window_sections(main, field, btn, vp)

	if failures == 0:
		_emit("TOOLTIP_WRAP_PROBE_OK")
	else:
		_emit("TOOLTIP_WRAP_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)


## 창 모드 전용 — 실제로 호버해서 팝업을 띄우고 잰다.
func _window_sections(_main: Node, _field: Node, btn: Button, vp: Vector2) -> void:
	# ── S1. 실제로 호버한다 (전략 2개 × 재시도) ───────────────────────────
	var c: Vector2 = btn.get_global_rect().get_center()
	Input.warp_mouse(c)
	var popup: Popup = null
	for attempt in 6:
		# 위치를 1px 씩 흔들어 **진짜 '이동'** 으로 만든다(같은 좌표는 무시될 수 있다).
		_nudge(c + Vector2(float(attempt % 2), 0.0), attempt >= 3)
		await get_tree().create_timer(0.60, true, false, true).timeout
		popup = _find_popup()
		_emit("S1 시도 %d (parse=%s) — 팝업 %s · hovered %s" % [
			attempt, str(attempt >= 3), ("없음" if popup == null else popup.name), _hovered_desc()])
		if popup != null:
			break
	check(popup != null, "호버했는데 툴팁 팝업이 안 떴다 — 나머지 절이 공허해진다")
	if popup == null:
		_emit("S1 진단 — hovered 가 null 이면 **내 호버가 안 먹은 것**(엔진 결함 아님).")
		_emit("S1 진단 — hovered 가 BtnStage 인데 팝업이 없으면 **엔진이 안 띄운 것**.")
		return
	# ⚠️ **`Popup extends Window` — `Control` 이 아니다.** 그래서 `get_global_rect()` 가 **없다**
	#    (2026-10-05: 이걸 불러서 런타임 오류로 코루틴이 죽었고, 프로브가 조용히 멈춰
	#     워치독이 RC=124 로 잡았다). 창은 `position`/`size` 로 잰다.
	var r := Rect2(Vector2(popup.position), Vector2(popup.size))
	var cmin: Vector2 = popup.get_contents_minimum_size()
	_emit("S1 팝업이 떴다: %s (%s) · 내장 %s · rect %s · 내용최소 %s" % [
		popup.name, popup.get_class(), str(popup.is_embedded()), str(r), str(cmin)])

	# ── S2. 팝업이 화면 안인가 · 라벨이 접혔는가 ──────────────────────────
	var over_l: float = maxf(-r.position.x, 0.0)
	var over_r: float = maxf(r.position.x + r.size.x - vp.x, 0.0)
	var over_t: float = maxf(-r.position.y, 0.0)
	var over_b: float = maxf(r.position.y + r.size.y - vp.y, 0.0)
	var over: float = maxf(maxf(over_l, over_r), maxf(over_t, over_b))
	_emit("S2 팝업 폭 %.0f · 높이 %.0f · 화면 초과 %.1f" % [r.size.x, r.size.y, over])
	check(over <= 0.5, "툴팁 팝업이 화면 밖으로 나간다(초과 %.1f)" % over)

	var lbl: Label = _first_label(popup)
	if lbl == null:
		_emit("S2 팝업 안에 Label 이 없다 — 엔진 구현이 바뀌었나?")
	else:
		var wrap: int = lbl.autowrap_mode
		var nlines: int = lbl.get_line_count()
		var minw: float = lbl.get_minimum_size().x
		_emit("S2 라벨 autowrap=%d · 줄 수 %d · 최소폭 %.0f · 실제폭 %.0f" % [
			wrap, nlines, minw, lbl.size.x])
		# ⭐ 결론 — 팝업이 화면 안이면(위 check) **접혔거나 짧다**. 둘을 구분해 보고한다.
		if wrap != TextServer.AUTOWRAP_OFF:
			_emit("S2 판정 — **접힌다**(autowrap=%d) → §2.32 S3 의 '미검증' 은 **결함 아님**" % wrap)
		elif nlines > 1:
			_emit("S2 판정 — autowrap=OFF · 줄 %d개(문구의 \\n) · **접히지 않는다** → 넓은 문구는 잘린다" % nlines)
		else:
			_emit("S2 판정 — autowrap=OFF · 한 줄인데 화면 안이다 → 글자가 잘렸는지 확인 필요")

	# ── S3. 스크린샷 ──────────────────────────────────────────────────────
	var vtex: ViewportTexture = get_viewport().get_texture()
	var shot: Image = vtex.get_image() if vtex != null else null
	if shot != null:
		_emit("S3 스크린샷 err=%d %dx%d" % [shot.save_png(SHOT_PATH), shot.get_width(), shot.get_height()])
	else:
		_emit("S3 스크린샷 실패 — get_image() 가 null")


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
