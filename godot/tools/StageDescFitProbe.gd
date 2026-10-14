# StageDescFitProbe.gd
# 스테이지 버튼을 눌러 뜨는 **라운드 정보 모달**의 글이 화면 안에 들어가는가.
#
# 왜 재는가 (2026-10-05, 감독 보고 "스테이지 설명 짤림"):
#   `_on_stage_btn_pressed()` 는 `Label` 을 만들면서 `autowrap_mode` 를 **안 준다**.
#   그 라벨은 `HBoxContainer` → `VBoxContainer` → `PanelContainer` 안에 들어가므로,
#   줄바꿈이 없으면 **패널의 최소 폭이 글자 폭만큼 자란다.** `PanelContainer` 는
#   `custom_minimum_size(760, 230)` 보다 **큰** 최소 크기를 이긴다 — 즉 상한이 없다.
#   `_show_modal()` 은 `(host - panel.size) * 0.5` 로 중앙을 잡으므로 패널이 화면보다
#   넓어지면 **오른쪽으로 삐져나가고 끝이 잘린다**(가운데 정렬이라 시작점은 보이지만
#   끝점을 못 본다).
#
# ⚠️ §2.13-2 는 **바(`TelegraphLabel`)만** 고쳤다. 그때 정보를 지우지 않으려고 전체 문구를
#    툴팁과 **이 모달**에 남겼는데, 그 두 표면의 폭은 **아무도 안 쟀다.** 바에는
#    `clip_text = true` + 1104px 이라는 명시적 계약이 있었지만 여기엔 없다.
#
# 재는 것:
#   S1  도달 가능한 (막, 라운드) 조합에서 모달 패널이 화면 안에 있는가
#   S2  패널 안 **모든 라벨**이 안 잘리는가 (`size ≥ 최소크기`) — 잘리는 글자가 무엇인가
#   S3  툴팁도 같은 문구를 쓴다 — 가장 긴 줄이 화면 폭을 넘는가(⚠️ 팝업 자체는 못 잰다)
#   S4  양성 대조 — 문구가 실제로 생성되는가 (재는 대상이 비어 있지 않나)
#
# ⚠️ 루트는 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
extends Node

const OUT_PATH := "E:/project/word_card/tmp/stagedescfit_out.txt"
const SHOT_PATH := "E:/project/word_card/tmp/stagedescfit.png"

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


## 패널 안의 모든 `Label` 을 (글자크기, 최소폭, 실제폭, 높이, 문구) 로 돌려준다.
func _labels_in(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n is Label:
			var l: Label = n
			out.append({
				"node": l,
				"px": l.get_theme_font_size("font_size"),
				"min": l.get_minimum_size(),
				"size": l.size,
				"text": l.text,
				"wrap": l.autowrap_mode,
			})
	return out


## 패널 안에서 특정 글자 크기의 `Label` 을 찾는다.
func _label_of_size(root: Node, px: int) -> Label:
	for l in _labels_in(root):
		if int(l["px"]) == px:
			return l["node"]
	return null


## 패널 안에서 글자가 `text` 인 `Button`.
func _button_named(root: Node, text: String) -> Button:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
		if n is Button and (n as Button).text == text:
			return n
	return null


func _ready() -> void:
	_watchdog()
	_emit("STAGE_DESC_FIT_START")

	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return
	# ⚠️ 루트가 `Node` 라 `get_viewport_rect()` 이 없다(그건 `CanvasItem` 메서드다) —
	#    뷰포트에서 직접 읽는다. headless 에서도 창 크기는 설정값(1280x720)이 나온다.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_emit("S0 뷰포트 %s · MAX_WAVES=%d · BOSS_INTERVAL=%d" % [
		str(vp), int(field.MAX_WAVES_PER_ACT), int(field.BOSS_ROUND_INTERVAL)])

	var cases: Array = []
	for act in [1, 2, 3]:
		for wave in [1, 4, 5, 9, 10, 14, 15, 19, 20]:
			cases.append([act, wave])

	var outside := 0
	var clipped := 0
	var worst := 0.0
	var worst_at := ""
	var rows: Array[String] = []
	for c in cases:
		var act: int = c[0]
		var wave: int = c[1]
		field.set_act(act)
		field.current_wave = wave
		await get_tree().process_frame
		# 실제 경로 — 버튼을 누른 것과 같은 함수를 부른다.
		main._on_stage_btn_pressed()
		await get_tree().process_frame
		await get_tree().process_frame

		var layer: Node = main.modal_layer
		var panel: Control = null
		for ch in layer.get_children():
			if ch is PanelContainer:
				panel = ch
		if panel == null:
			rows.append("  %d막 %2dR — 모달이 안 떴다" % [act, wave])
			continue
		var psz := panel.size
		var ppos := panel.global_position
		var over: float = maxf(ppos.x + psz.x - vp.x, -ppos.x)
		var bad := 0
		var detail := ""
		for l in _labels_in(panel):
			var mn: Vector2 = l["min"]
			var sz: Vector2 = l["size"]
			# 최소 크기보다 작게 배치되면 글자가 잘린다(autowrap 이 없으면 이 값이 글자 폭이다).
			if sz.x + 0.5 < mn.x or sz.y + 0.5 < mn.y:
				bad += 1
				if detail == "":
					detail = "잘림 px=%d (필요 %.0f · 실제 %.0f) %s" % [
						int(l["px"]), mn.x, sz.x, str(l["text"]).substr(0, 24)]
		if over > 0.5:
			outside += 1
			if over > worst:
				worst = over
				worst_at = "%d막 %dR" % [act, wave]
		clipped += bad
		rows.append("  %d막 %2dR 패널 %5.0fx%-4.0f x=%-7.1f · 초과 %6.1f · 잘린라벨 %d %s | %s" % [
			act, wave, psz.x, psz.y, ppos.x, over, bad,
			"★화면밖" if over > 0.5 else "OK", detail])
		panel.queue_free()
		await get_tree().process_frame
	for r in rows:
		_emit("S1%s" % r)
	_emit("S1 %d개 상태 중 **%d개가 화면 밖** · 최악 %s +%.1fpx · 잘린 라벨 %d개" % [
		cases.size(), outside, worst_at, worst, clipped])
	check(outside == 0,
		"모달 패널이 %d/%d 상태에서 화면 밖으로 나간다 (최악 %s +%.0fpx)"
		% [outside, cases.size(), worst_at, worst])
	check(clipped == 0, "모달 안에서 잘린 라벨이 %d개다" % clipped)

	# ── S2. 구조 — 글이 **버튼 줄**에 있으면 안 된다 ──────────────────────────
	# ⚠️ 이 절이 없으면 *"autowrap 만 주고 `row`(HBoxContainer)에 그대로 둔"* 고침이 통과한다.
	#    그러면 본문·"속성 설명" 제목·설명이 **세 칸으로 갈라져** 서로 다른 열이 된다 —
	#    폭(패널 크기)만 보면 그 회귀가 안 보인다.
	field.set_act(1)
	field.current_wave = 4
	await get_tree().process_frame
	main._on_stage_btn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel2: Control = null
	for ch in main.modal_layer.get_children():
		if ch is PanelContainer:
			panel2 = ch
	check(panel2 != null, "S2 모달이 안 떴다 — 구조를 잴 대상이 없다")
	if panel2 != null:
		var body := _label_of_size(panel2, 16)
		var desc_title := _label_of_size(panel2, 13)
		var desc_lbl := _label_of_size(panel2, 12)
		var close_btn := _button_named(panel2, "닫기")
		var body_parent := body.get_parent().get_class() if body != null else "(본문없음)"
		var body_idx := body.get_index() if body != null else -1
		var close_idx := close_btn.get_index() if close_btn != null else -1
		_emit("S2 본문 부모=%s(본문 idx %d) · 속성설명 제목=%s · 설명=%s · 닫기 idx %d" % [
			body_parent, body_idx, str(desc_title != null), str(desc_lbl != null), close_idx])
		check(body != null, "본문 라벨(16px)을 못 찾았다")
		check(body != null and body.get_parent() is VBoxContainer,
			"본문이 버튼 줄(%s)에 있다 — 세 칸으로 갈라진다" % body_parent)
		check(desc_title != null, "'속성 설명' 제목이 모달에 없다 — 1막에는 속성이 있다")
		check(desc_lbl != null, "속성 설명 본문(12px)이 없다")
		check(body != null and close_btn != null
			and body.get_parent() == close_btn.get_parent() and body_idx < close_idx,
			"본문이 닫기 버튼보다 아래에 있다 (본문 %d · 닫기 %d)" % [body_idx, close_idx])
		# ⚠️ **화면 안**인가 — 있기만 하고 잘리면 소용없다. 이 모달의 존재 이유가 읽히는 것이다.
		if desc_lbl != null:
			var dr: Rect2 = desc_lbl.get_global_rect()
			var on: bool = dr.position.x >= -0.5 and dr.position.x + dr.size.x <= vp.x + 0.5
			_emit("S2 속성 설명 폭 %.0f (한줄 최소 %.0f) · 화면 x %.0f..%.0f %s" % [
				dr.size.x, desc_lbl.get_minimum_size().x, dr.position.x,
				dr.position.x + dr.size.x, "OK" if on else "★화면밖"])
			check(on, "속성 설명이 화면 밖이다 (x %.0f..%.0f · 화면 %.0f)" % [
				dr.position.x, dr.position.x + dr.size.x, vp.x])
		panel2.queue_free()
		await get_tree().process_frame

	# ── S3. 툴팁 — 같은 문구를 쓰는 다른 표면 ────────────────────────────────
	# ⚠️ 여기서 재는 것은 **글자 폭**이지 팝업 폭이 아니다. Godot 의 툴팁 팝업이 접히는지는
	#    마우스 호버가 필요해 headless 로는 못 잰다 — 이 줄은 **보고 전용**이고 판정하지 않는다.
	field.set_act(2)
	field.current_wave = 9
	await get_tree().process_frame
	main._refresh_stage_tooltip(field.next_round_preview())
	var tip: String = main.btn_stage.tooltip_text
	var font: Font = main.btn_stage.get_theme_font("font")
	var tip_size: int = main.btn_stage.get_theme_font_size("font_size")
	var longest := 0.0
	var longest_line := ""
	for line in tip.split("\n"):
		var w: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, tip_size).x
		if w > longest:
			longest = w
			longest_line = str(line)
	_emit("S3 [보고] 툴팁 폰트 %dpx · 가장 긴 줄 %.1fpx (화면 %.0f) · 팝업 접힘 여부는 **미검증**" % [
		tip_size, longest, vp.x])
	_emit("S3 [보고] 그 줄: %s" % longest_line)

	# ── S4. 양성 대조 — 문구가 실제로 생성되는가 ─────────────────────────────
	field.set_act(1)
	field.current_wave = 0
	await get_tree().process_frame
	var short_text: String = field.next_round_preview()
	_emit("S4 1막 1R 문구 (%d자): %s" % [short_text.length(), short_text])
	check(short_text.length() > 0, "1막 1R 예고가 비었다 — 재는 대상이 틀렸다")
	check(main.btn_stage != null, "btn_stage 가 없다 — 툴팁을 잴 대상이 없다")

	# ── S5. 스크린샷 (창 모드 전용) ───────────────────────────────────────────
	# ⚠️ 레이아웃은 **코드로 안 보인다** — 본문·"속성 설명" 제목·설명 라벨이 전부
	#    같은 `row`(HBoxContainer)에 들어가 있어서, 폭만 고치면 **세 칸으로 갈라질** 수 있다.
	if DisplayServer.get_name() == "headless":
		_emit("S5 스크린샷 생략(headless) — 창 모드에서만 얻어진다")
	else:
		field.set_act(1)
		field.current_wave = 4
		await get_tree().process_frame
		main._on_stage_btn_pressed()
		for f in 10:
			await get_tree().process_frame
		var vtex: ViewportTexture = get_viewport().get_texture()
		var shot: Image = vtex.get_image() if vtex != null else null
		if shot != null:
			_emit("S5 스크린샷 err=%d %dx%d" % [
				shot.save_png(SHOT_PATH), shot.get_width(), shot.get_height()])
		else:
			_emit("S5 스크린샷 실패 — get_image() 가 null")

	if failures == 0:
		_emit("STAGE_DESC_FIT_PROBE_OK")
	else:
		_emit("STAGE_DESC_FIT_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
