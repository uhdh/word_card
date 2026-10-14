# RuntimeTextFitProbe.gd
# **런타임에 문구가 바뀌는 컨트롤이 자기 그릇을 넘는가.**
#
# 왜 재는가 (2026-10-06):
#   §2.35 는 *툴팁 팝업* 이 문구를 못 담아 **56/60 상태가 잘린다** 를 실측했다(§2.30-4 의 `→` 와
#   같은 뿌리 — 글자 폭을 아무도 안 쟀다). §2.32·§2.34 는 *모달* 이 화면을 넘는 것을 잡았다.
#   그런데 **세 번째 축**이 안 재졌다 — **컨트롤 *자신* 의 폭**이다.
#
#   이 프로젝트에는 **런타임에 문구가 길어지는 컨트롤**이 여럿 있다:
#       `BtnSpeed`  `1x 배속` → `2x 배속` → `⚡ 4x 초고속` → `⏸ 정지`
#       `GoldLabel` `🪙 40 G` → `🪙 1,234,567 G`
#       `consonant_buy_button` `자음 구매 %dG`
#   씬이 준 폭(`custom_minimum_size`)은 **한 상태만** 보고 정해졌을 수 있다.
#   ⚠️ `BtnSpeed` 는 `Actions`(HBox · `size_flags_horizontal = 8` = 오른쪽 정렬) 안에 있어서,
#      **자기 폭이 변하면 형제 전부가 밀린다**(`새 게임`·`저장`·`이어하기` 가 좌우로 흔들린다).
#
# 재는 것:
#   S0  부팅 · 안정화 · 모달 정리
#   S1  ⭐ **일반 불변식** — 보이는 모든 텍스트 컨트롤: `문구 폭 > 가용 폭` 이면 ★실패
#       (`autowrap` 이 켜진 라벨과 `clip_text` 라벨은 **계약**이므로 따로 보고)
#   S2  ⭐ **런타임 4단** — `set_speed_scale()` 실 게임 문으로 4상태를 태우고
#       ① 자기 폭 ② **형제 x** 가 **불변인가** 판정
#   S3  같은 부류 확장 — `GoldLabel`·`EnemyLabel` 을 큰 값으로 태워 폭이 버티는가
#   S4  스크린샷(최악 단)
#
# ⚠️ **`clip_text` 는 결함이 아니다** — `JamoBelt.PreviewLabel` 은 씬에 말줄임 계약이 있다(§2.33).
#    그래서 S1 은 그것을 **보고**로만 내고 판정에서 뺀다.
# ⚠️ 루트는 반드시 `Node`.
extends Node

const OUT_PATH := "E:/project/word_card/tmp/runtimetextfit.txt"
const SHOT_PATH := "E:/project/word_card/tmp/runtimetextfit.png"

## 폭 비교 허용 오차(px). 서브픽셀 반올림을 실패로 세지 않는다.
const EPS := 1.0

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
	for i in 9000:
		await get_tree().process_frame
	_emit("WATCHDOG — 못 끝났다")
	get_tree().quit(124)


## 컨트롤의 문구와, 그 문구가 실제로 차지하는 폭.
func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	return ""


func _font_of(c: Control) -> Font:
	return c.get_theme_font("font")


func _font_size_of(c: Control) -> int:
	return c.get_theme_font_size("font_size")


## 문구가 실제로 그려지는 폭(px). 폰트 폴백까지 반영된다(`get_string_size` 가 그렇게 한다).
func _text_px(c: Control, s: String) -> float:
	var fnt := _font_of(c)
	if fnt == null or s == "":
		return 0.0
	return fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size_of(c)).x


## 컨트롤이 문구에 내주는 폭(px). 버튼은 스타일박스 안쪽 여백을 빼야 한다.
func _inner_px(c: Control) -> float:
	var w := c.size.x
	if c is Button:
		var sb := c.get_theme_stylebox("normal")
		if sb != null:
			w -= sb.content_margin_left + sb.content_margin_right
	return w


## S1 후보 — 문구를 가진 **보이는** 라벨/버튼.
func _text_controls(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if (n is Label or n is Button) and (n as Control).is_visible_in_tree():
			out.append(n)
		for k in n.get_children():
			stack.append(k)
	return out


func _clear_modals(main: Node) -> void:
	var layer = main.get("modal_layer")
	if layer == null:
		return
	for ch in (layer as Node).get_children():
		ch.queue_free()


func _ready() -> void:
	_watchdog()
	_emit("RUNTIME_TEXT_FIT_START")

	SaveManager.delete_save_file()
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_modals(main)
	# ⚠️ 벨트가 시작하며 여러 번 재건축한다 — 재기 전에 **실시간으로** 가라앉힌다(§2.36).
	await get_tree().create_timer(1.5, true, false, true).timeout
	_clear_modals(main)
	await get_tree().process_frame

	var btn_speed: Button = main.get("btn_speed")
	if btn_speed == null:
		_emit("`btn_speed` 를 못 얻었다 — 씬 구조가 바뀌었나?")
		get_tree().quit(3)
		return

	# ── S1. 일반 불변식 — 문구가 그릇을 넘지 않는가 ─────────────────────────
	var over: Array = []
	var wrapped := 0
	var clipped := 0
	var clipped_list: Array = []
	for c in _text_controls(main):
		var txt := _text_of(c)
		if txt == "":
			continue
		if c is Label:
			var lb: Label = c
			if lb.autowrap_mode != TextServer.AUTOWRAP_OFF:
				wrapped += 1
				continue
			if lb.clip_text:
				clipped += 1
				clipped_list.append("%s «%s»" % [String(main.get_path_to(c)), txt])
				continue
		var need := _text_px(c, txt)
		var have := _inner_px(c)
		if need > have + EPS:
			over.append("%s «%s» 필요 %.1f > 가용 %.1f (+%.1f)" % [
				String(main.get_path_to(c)), txt, need, have, need - have])
	_emit("S1 문구 가진 보이는 컨트롤 — 넘침 %d개 · 줄바꿈 %d개(계약) · `clip_text` %d개(계약)" % [
		over.size(), wrapped, clipped])
	for s in over:
		_emit("S1 넘침 %s" % s)
	for s in clipped_list:
		_emit("S1 clip_text(계약 · 보고) %s" % s)
	check(over.is_empty(), "문구가 자기 그릇보다 넓은 컨트롤 %d개 — 글자가 밖으로 나간다" % over.size())

	# ── S2. 런타임 4단 — 자기 폭과 **형제 위치**가 불변인가 ──────────────────
	# ⚠️ `Actions` 는 오른쪽 정렬이라 이 버튼이 커지면 **왼쪽 형제들이 밀린다**.
	var siblings: Array = []
	var actions := btn_speed.get_parent()
	for ch in actions.get_children():
		if ch != btn_speed and ch is Control and (ch as Control).visible:
			siblings.append(ch)
	_emit("S2 형제 %d개: %s" % [siblings.size(), str(siblings.map(func(s): return (s as Button).text))])

	var states := [1.0, 2.0, 4.0, 0.0]
	var widths: Array = []
	var sibling_x: Dictionary = {}
	var rows: Array = []
	for sc in states:
		main.call("set_speed_scale", sc)
		await get_tree().process_frame
		await get_tree().process_frame
		widths.append(btn_speed.size.x)
		rows.append("%s → 자기폭 %.1f · 최소 %.1f" % [
			btn_speed.text, btn_speed.size.x, btn_speed.get_minimum_size().x])
		for i in siblings.size():
			var key := str(i)
			var x: float = (siblings[i] as Control).get_global_rect().position.x
			var bucket: Array = sibling_x.get(key, [])
			bucket.append(x)
			sibling_x[key] = bucket
	# 복구 — 시간축을 원래대로(다른 프로브·스위트에 영향 금지)
	main.call("set_speed_scale", 1.0)
	await get_tree().process_frame

	for r in rows:
		_emit("S2 %s" % r)
	var w_min: float = widths.min()
	var w_max: float = widths.max()
	_emit("S2 자기 폭 %s → 변동 %.1fpx" % [str(widths), w_max - w_min])
	check(w_max - w_min <= EPS,
		"속도 버튼의 폭이 문구에 따라 **%.1fpx 변한다**(%.1f→%.1f) — 씬의 `custom_minimum_size` 가 한 상태만 보고 정해졌다" % [w_max - w_min, w_min, w_max])

	var worst_shift := 0.0
	var worst_name := ""
	for i in siblings.size():
		var xs: Array = sibling_x[str(i)]
		var lo: float = xs.min()
		var hi: float = xs.max()
		if hi - lo > worst_shift:
			worst_shift = hi - lo
			worst_name = (siblings[i] as Button).text
	# ⚠️ **판정은 위(자기 폭) 하나뿐이다** — 형제 이동은 그 **결과**지 별개 결함이 아니다.
	#    (오른쪽 정렬 HBox 에서 폭이 19px 늘면 왼쪽 형제는 반드시 19px 밀린다.)
	_emit("S2 보고 — 형제 최대 이동 %.1fpx (`%s`)" % [worst_shift, worst_name])

	# ── S3. 진짜 불변식 — **상단 바가 최악 상태에서도 들어가는가** ───────────
	# ⚠️ "라벨이 내용에 따라 커진다" 는 **결함이 아니다**(그게 라벨의 일이다).
	#    결함은 **바가 안 들어가서** 무언가 화면 밖으로 나가거나 겹치는 것이다.
	#    그래서 자기 폭이 아니라 **`Row` 의 최소 폭 vs 실제 폭** 을 잰다.
	# ⚠️ `gold_label.text` 는 `_process` 가 매 프레임 `"🪙 %d G" % roundi(_gold_shown)` 로
	#    **되쓴다**(`:753`) → 대입하지 않고 **폰트 계측으로 증가분만** 예측한다.
	# ⚠️ 실제 문구에는 **천 단위 쉼표가 없다**(포맷이 `%d`) — 큰 값에서 더 넓다.
	var row: Control = btn_speed.get_parent().get_parent()
	var info: Control = row.get_node("Info")
	var actions_ctrl: Control = row.get_node("Actions")
	var sep: float = row.get_theme_constant("separation")
	var gold: Label = main.get("gold_label")
	var base_gold_px := 0.0
	if gold != null:
		base_gold_px = _text_px(gold, gold.text)
	_emit("S3 Row %.1fpx · Info 최소 %.1f · Actions 최소 %.1f · 간격 %.1f" % [
		row.size.x, info.get_minimum_size().x, actions_ctrl.get_minimum_size().x, sep])

	var row_rows: Array = []
	var row_bad := 0
	for v in [40, 12345, 1234567, 999999999]:
		var s := "🪙 %d G" % v
		var delta := _text_px(gold, s) - base_gold_px if gold != null else 0.0
		var need: float = info.get_minimum_size().x + delta + sep + actions_ctrl.get_minimum_size().x
		row_rows.append("%s (골드 +%.1f) → Row 최소 %.1f / 실제 %.1f → %s" % [
			s, delta, need, row.size.x, "OK" if need <= row.size.x + EPS else "★넘침 +%.1f" % (need - row.size.x)])
		if need > row.size.x + EPS:
			row_bad += 1
	for r in row_rows:
		_emit("S3 %s" % r)
	_emit("S3 상단 바가 안 들어가는 골드 값 %d/4" % row_bad)
	check(row_bad == 0,
		"골드가 커지면 상단 바가 안 들어간다(%d/4) — 오른쪽 버튼이 화면 밖으로 나간다" % row_bad)

	# ── S4. 같은 부류 — 벨트 헤더도 버티는가 ────────────────────────────────
	# ⚠️ 이 넷은 `custom_minimum_size` 가 **없다**(`Button.new()` + 텍스트만) — 내용에 따라
	#    커지는 것이 **설계**다. 그래서 "폭 불변" 은 계약이 **아니고**, **행이 들어가는가** 가 계약이다.
	#    (`BtnSpeed` 는 반대다 — 씬이 84 로 **고정 슬롯**을 선언했는데 자기 상태가 그걸 넘는다.)
	# ⚠️ 라벨은 코드에서 그대로 가져온다(`_update_buy_buttons()` · `:393-411`). 지어내지 않는다.
	var belt = main.get("jamo_belt")
	if belt == null:
		_emit("S4 `jamo_belt` 를 못 얻었다 — 건너뜀")
	else:
		var header: Control = belt.get_node("VBox/Header")
		var labels := {
			"consonant_buy_button": ["자음 구매 3G", "자음 구매 999G"],
			"vowel_buy_button": ["모음 구매 3G", "모음 구매 999G"],
			"remove_tile_button": ["타일 제거 12G", "제거할 타일 선택"],
			"swap_tile_button": ["활자 교체 15G", "바꿀 활자 선택"],
		}
		var max_min: float = header.get_minimum_size().x
		for key in labels:
			var btn: Button = belt.get(key)
			if btn == null:
				continue
			var orig: String = btn.text
			var ws: Array = []
			for lb in labels[key]:
				btn.text = lb
				await get_tree().process_frame
				ws.append("%s %.1f" % [lb, btn.size.x])
				max_min = maxf(max_min, header.get_minimum_size().x)
			btn.text = orig
			await get_tree().process_frame
			_emit("S4 %s — %s" % [key, str(ws)])
		_emit("S4 벨트 헤더 최소(최악) %.1f / 실제 %.1f · 복원 후 최소 %.1f" % [
			max_min, header.size.x, header.get_minimum_size().x])
		check(max_min <= header.size.x + EPS,
			"벨트 헤더가 최악 문구에서 최소 %.1fpx 인데 실제 %.1fpx 다 — 버튼이 밀려난다" % [max_min, header.size.x])

	# ── S5. 스크린샷(최악 단) ──────────────────────────────────────────────
	if DisplayServer.get_name() != "headless":
		main.call("set_speed_scale", 4.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(SHOT_PATH)
			_emit("S5 스크린샷 %s" % SHOT_PATH)
		main.call("set_speed_scale", 1.0)
	else:
		_emit("S5 헤드리스 — 스크린샷 생략")

	if failures == 0:
		_emit("RUNTIME_TEXT_FIT_PROBE_OK")
	else:
		_emit("RUNTIME_TEXT_FIT_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
