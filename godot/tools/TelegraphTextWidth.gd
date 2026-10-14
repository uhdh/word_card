extends Node
# 텔레그래프 바의 '다음 라운드 예고' 가 **실제로 몇 px 인지** 재고, 잘리는지 **판정한다.**
#
#   godot --headless --path . res://tools/TelegraphTextWidth.tscn
#   godot --path . res://tools/TelegraphTextWidth.tscn -- act=3 wave=20
#
# 왜 필요한가: `TelegraphLabel` 은 `clip_text = true` 라 넘치면 **조용히 잘린다.**
# 예외도 경고도 없다. 벨트 헤더에서 같은 함정을 이미 겪었다(`tools/BeltTextWidth.gd` —
# "눈으로 들어가 보인다" 는 판단이 두 번 틀렸다).
#
# ⚠️ **2026-10-03 §2.13-2 고침 — 이 도구의 계약이 바뀌었다.**
#    고침 전에는 바가 `next_round_preview()`(전체)를 그대로 받아 **60개가 전부** 잘렸다
#    (최장 2막 10R = 1777 px · 라벨 1104 px · 상성 절만 1322 px).
#    이제 바는 `next_round_preview(true)`(**compact**)를 받는다 → 최장 475 px.
#    그래서 이 도구는 **바가 실제로 쓰는 문자열**(`label.text`)을 재고, 넘치면 **실패한다**.
#    ⚠️ `next_round_preview()` 를 직접 부르면 **바가 안 쓰는 문구**를 재게 되어
#       "60/60 잘림" 이라는 **거짓 경보**를 계속 낸다(고침 직후 실제로 그럴 뻔했다).
#
# ⚠️ 손으로 만든 최악값을 넣지 않는다(BeltTextWidth 에서 그렇게 했다가 거짓 경보를 냈다).
#    **도달 가능한 모든 (막, 라운드)** 를 훑어 실제 최장을 찾는다.

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

var _forced_act := -1
var _forced_wave := -1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("act="):
			_forced_act = int(a.split("=", true, 1)[1])
		elif a.begins_with("wave="):
			_forced_wave = int(a.split("=", true, 1)[1])

	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame

	var label: Label = main.telegraph_label
	var timer: Label = main.telegraph_timer
	if label == null:
		push_error("telegraph_label 을 찾지 못했다 — 이 도구는 씬 구조에 의존한다")
		get_tree().quit(2)
		return

	var font: Font = label.get_theme_font("font")
	var fsize: int = label.get_theme_font_size("font_size")
	print("── 텔레그래프 바 ──")
	print("   바 높이      %.0f px (custom_minimum_size)" % main.get_node("VBox/TelegraphBar").custom_minimum_size.y)
	print("   폰트         %s %d · clip=%s" % [font.get_font_name(), fsize, str(label.clip_text)])

	# ⚠️ 라벨 폭은 **타이머 폭에 따라 달라진다** — 같은 HBox 안에서 타이머가 넓어지면
	#    라벨이 좁아진다. 가장 좁아지는 순간은 **웨이브 중**이다("다음 웨이브 15초").
	#    "대기 중"(46 px)에서만 재면 실제보다 넓은 자리에서 재게 되어 **거짓 통과**가 난다
	#    (BeltTextWidth 가 유물 유무를 둘 다 잰 것과 같은 이유).
	#    그래서 **가장 좁아지는 상태로 고정한 뒤** 모든 측정을 한다.
	#
	# ⚠️ `timer.text` 를 직접 대입하면 안 된다 — `_process()` 가 매 프레임 덮어쓴다.
	#    (실측: 대입하고 두 프레임 기다렸더니 여전히 "대기 중" 46 px 였다.)
	#    상태를 만들어야 한다: 웨이브 진행 중 + `round_timer=0` → 타이머가 최장이 된다.
	print("   타이머 폭    %.1f px  (문구 \"%s\")" % [timer.size.x, timer.text])
	var field = main.defense_field
	field.is_wave_running = true
	field.is_planning_phase = false
	field.round_timer = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	print("   타이머 폭    %.1f px  (문구 \"%s\")  ← 최장, 이때 라벨이 가장 좁다" % [timer.size.x, timer.text])
	print("   예고 라벨 폭 %.1f px  ← **기준 폭**" % label.size.x)

	# ── 도달 가능한 (막, 라운드) 전수 ─────────────────────────────────────
	var acts := []
	if _forced_act > 0:
		acts = [_forced_act]
	else:
		for a in range(1, field.MAX_ACTS + 1):
			acts.append(a)
	var waves := []
	if _forced_wave > 0:
		waves = [_forced_wave]
	else:
		for w in range(1, field.MAX_WAVES_PER_ACT + 1):
			waves.append(w)

	# 바가 실제로 쓰는 문자열(compact)을 재는 것이 **계약**이다.
	# 전체 문구는 툴팁·라운드 모달이 받으므로 폭 제한이 없다 — 참고로만 센다.
	var worst := ""
	var worst_w := -1.0
	var worst_at := Vector2i.ZERO
	var over := 0
	var total := 0
	var full_over := 0
	var worst_full := ""
	var worst_full_w := -1.0
	for a in acts:
		for w in waves:
			field.current_act = a
			field.current_wave = w
			# ⚠️ 라벨을 **실제로 갱신**시킨 뒤 그 내용을 읽는다. 문자열을 따로 조립하면
			#    "바가 무엇을 쓰는가" 와 갈라질 수 있다(§2.13-2 가 바로 그런 결함이었다).
			main._update_next_round_preview()
			var text: String = label.text
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			total += 1
			if tw > label.size.x:
				over += 1
			if tw > worst_w:
				worst_w = tw
				worst = text
				worst_at = Vector2i(a, w)
			var full: String = field.next_round_preview()
			var fw: float = font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			if fw > label.size.x:
				full_over += 1
			if fw > worst_full_w:
				worst_full_w = fw
				worst_full = full

	print("")
	print("── 전수 %d개 (막 %d × 라운드 %d) ──" % [total, acts.size(), waves.size()])
	print("   **바가 쓰는 문구(compact) 중 잘리는 것: %d / %d**" % [over, total])
	print("   (참고) 전체 문구 중 라벨보다 넓은 것: %d / %d — 바는 이걸 안 쓴다" % [full_over, total])
	print("")
	print("   최장 바 문구 (%d막 %dR) = %.1f px  (라벨 %.1f px · 여유 %.1f px)" % [
		worst_at.x, worst_at.y, worst_w, label.size.x, label.size.x - worst_w])
	print("   %s" % worst)
	print("")
	print("   최장 전체 문구 = %.1f px (툴팁·모달용 — 폭 제한 없음)" % worst_full_w)

	# ── 잘리는 **부위**가 어디인가 — 선택지에 숫자를 붙이기 위해 ────────────────
	# 전체 문구는 "다음 N막 NR: <로스터>< | 상성>" 이다. 어느 쪽이 넘치는지 알아야
	# "무엇을 바에서 빼야 하는가" 를 정할 수 있다(§2.13-2 의 근거가 이 수치다).
	print("")
	print("── 최장 전체 문구의 부위별 폭 (라벨 %.1f px) ──" % label.size.x)
	var parts: PackedStringArray = worst_full.split(" | ", false)
	for i in range(parts.size()):
		var pw: float = font.get_string_size(parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var verdict := "OK" if pw <= label.size.x else "**혼자서도 넘침**"
		print("   부위 %d: %.1f px  %s" % [i + 1, pw, verdict])
		print("           %s" % parts[i])

	# ── 판정 ───────────────────────────────────────────────────────────────
	# 계약: **바에 들어가는 문구는 잘리지 않는다.**
	if over > 0:
		print("")
		print("!! 계약 위반 — 바 문구 %d개가 라벨(%.1f px)을 넘는다" % [over, label.size.x])
		get_tree().quit(1)
		return
	print("")
	print("== 바 문구는 전부 들어간다 (%d/%d) ==" % [total, total])
	print("TELEGRAPH_WIDTH_PROBE_OK")
	get_tree().quit(0)
