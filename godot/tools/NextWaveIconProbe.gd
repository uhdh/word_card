# NextWaveIconProbe.gd
# 다음 웨이브 예고의 **그림 채널**이 실제로 오는 적과 같은 말을 하는지 잰다.
#
#   godot --headless --path . res://tools/NextWaveIconProbe.tscn   # 글자 보고
#   godot --path . res://tools/NextWaveIconProbe.tscn              # + 스크린샷
#
# 왜 필요한가:
#   `NextWaveIcons` 는 **동결 파일을 안 고치려고** '다음 라운드가 몇 막 몇 R 인가' 를
#   스스로 계산한다(`_next_round()`). 그 3줄은 `DefenseField.next_round_preview()` 와
#   같은 규칙이어야 하는데, **눈으로는 못 잡는다** — 조용히 갈라지면 아이콘은 옛 막의
#   몬스터를 계속 보여 주고 아무도 모른다(§2.18 드리프트와 같은 뿌리).
#   그래서 여기서 **실제 스포너(`_build_wave_monsters`)와 맞댄다** — 아이콘의 약속과
#   실제 `spawn_queue` 의 구성이 한 마리라도 다르면 빨개진다.
#
# 재는 것:
#   S1  배선 — 실제 게임 씬의 예고 바 안에 노드가 있고 `DefenseField` 를 찾았는가
#   S2  **구성 계약** — 60개 (막, R) 전부에서 아이콘 = 실제 `spawn_queue` (아이콘·마릿수)
#   S3  실제 렌더 — 라이브 바의 자식 수·텍스처 경로가 그 구성과 같은가
#   S4  툴팁 — 빈 툴팁 0개 · 이름이 `MonsterRoster` 표에서 온 것인가
#   S5  레이아웃 — 아이콘이 예고 바(최소 높이 34)를 **자라게 하지 않았는가**
#   S6  양성 대조 — 일부러 한 종류를 빼면 S2 비교가 **달라져야** 한다(검출력 증명)
#   S7  보고 전용 — 예고 문구에 쓰이는 `→` 가 이 폰트에 있는가(fontTools 로 확인:
#       `neodgm.ttf` 에 **U+2192 없음**). 화면에 상자로 뜨는지 눈으로 보려고 찍는다.
#
# 판정형이다 — 실패 수를 종료 코드로 돌려준다. ⚠️ **등록은 감독 결정**(§4.3).
## ⚠️ 루트는 반드시 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
extends Node

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const MonsterRoster = preload("res://scripts/tower/MonsterRoster.gd")

const OUT_PATH := "E:/project/word_card/tmp/nextwave_out.txt"
const SHOT_DIR := "E:/project/word_card/tmp/"

var failures := 0
var _lines: PackedStringArray = []


func _emit(s: String) -> void:
	_lines.append(s)
	print(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		_emit("  ✗ %s" % what)


func _watchdog() -> void:
	for i in 1800:
		await get_tree().process_frame
	_emit("WATCHDOG — 1800 프레임 안에 못 끝났다")
	get_tree().quit(2)


## 스폰 데이터 배열 → `{아이콘경로: 마릿수}`. **아이콘 경로**가 곧 '무엇인가' 다
## (이름은 막마다 바뀌지만 아이콘 파일은 종류를 가리킨다).
func _tally(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for e in entries:
		var key := str(e.get("icon", ""))
		out[key] = int(out.get(key, 0)) + 1
	return out


## `NextWaveIcons.composition_for()` 의 결과 → 같은 모양의 `{아이콘경로: 마릿수}`.
func _tally_from_composition(comps: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in comps:
		var key := str(c.get("icon", ""))
		out[key] = int(out.get(key, 0)) + int(c.get("count", 0))
	return out


func _ready() -> void:
	_watchdog()
	_emit("NEXTWAVE_ICON_START")
	await _run()
	if failures == 0:
		_emit("NEXTWAVE_ICON_PROBE_OK")
	else:
		_emit("NEXTWAVE_ICON_PROBE_FAILED (%d)" % failures)
	get_tree().quit(failures)


func _run() -> void:
	var main: Node = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# ── S1. 배선 ──────────────────────────────────────────────────────────────
	_emit("[S1] 배선")
	var panel: Control = main.get_node_or_null("VBox/TelegraphBar") as Control
	var row: Node = main.get_node_or_null("VBox/TelegraphBar/Row")
	var field: Node = main.get_node_or_null("VBox/FieldContainer/DefenseField")
	_check(panel != null, "예고 바(PanelContainer)를 못 찾았다")
	_check(row != null, "예고 바의 Row 를 못 찾았다")
	_check(field != null, "DefenseField 를 못 찾았다")
	if row == null or field == null:
		return
	var bar: Node = row.get_node_or_null("NextWaveIcons")
	_check(bar != null, "예고 바에 NextWaveIcons 노드가 없다")
	if bar == null:
		return
	_check(bar.get_script() != null, "NextWaveIcons 에 스크립트가 안 붙었다")
	_check(bar.get("_defense_field") != null, "export 경로가 DefenseField 를 못 찾았다")
	_check(bar.get_child_count() > 0, "아이콘이 하나도 안 그려졌다")
	_emit("  노드 %d개 · DefenseField 연결 %s" % [bar.get_child_count(), str(bar.get("_defense_field") != null)])

	# ── S2. 구성 계약 (60개 막·R) ─────────────────────────────────────────────
	# ⚠️ 라이브 필드를 건드리지 않는다 — 스포너를 **별도 인스턴스**에서 돌린다.
	_emit("[S2] 구성 계약 — 아이콘 vs 실제 spawn_queue")
	var df: Node = DefenseFieldScript.new()
	var bad: Array[String] = []
	var checked := 0
	for act in range(1, 4):
		for wave in range(1, 21):
			checked += 1
			df.spawn_queue.clear()
			df._build_wave_monsters(act, wave)
			var truth := _tally(df.spawn_queue)
			var shown := _tally_from_composition(bar.call("composition_for", act, wave))
			if truth != shown:
				bad.append("%d막 %dR 실제 %s ≠ 아이콘 %s" % [act, wave, str(truth), str(shown)])
	df.free()
	_check(checked == 60, "검사한 (막,R) 조합이 %d개다 — 60개여야 한다" % checked)
	_check(bad.is_empty(), "구성이 어긋난 조합 %d개: %s" % [bad.size(), str(bad.slice(0, 3))])
	_emit("  %d개 조합 · 불일치 %d개" % [checked, bad.size()])

	# ── S3. 실제 렌더 ─────────────────────────────────────────────────────────
	_emit("[S3] 라이브 바 렌더")
	var round: Vector2i = bar.call("_next_round")
	var comps: Array = bar.call("composition_for", round.x, round.y)
	_emit("  가리키는 라운드 = %d막 %dR · 종류 %d개" % [round.x, round.y, comps.size()])
	_check(bar.get_child_count() == comps.size(),
		"자식 %d개 ≠ 구성 %d개" % [bar.get_child_count(), comps.size()])
	var boxes: Array = bar.get_children()
	var tex_missing := 0
	var tex_wrong := 0
	for k in range(mini(boxes.size(), comps.size())):
		var tex: TextureRect = boxes[k].get_child(0) as TextureRect
		if tex == null or tex.texture == null:
			tex_missing += 1
			continue
		if tex.texture.resource_path != str(comps[k].get("icon", "")):
			tex_wrong += 1
			_emit("  ✗ %d번째 텍스처 %s ≠ %s" % [k, tex.texture.resource_path, str(comps[k].get("icon", ""))])
	_check(tex_missing == 0, "텍스처가 빈 칸 %d개" % tex_missing)
	_check(tex_wrong == 0, "다른 아이콘을 그린 칸 %d개" % tex_wrong)

	# ── S3b. 라운드 판정의 **독립** 대조 ─────────────────────────────────────
	# ⚠️ 이 검사가 이 프로브의 핵심이다. S2 는 `composition_for(act, wave)` 가 스포너와
	#    같은 말을 하는지만 본다 — `_next_round()` 가 **엉뚱한 (막,R)** 을 고르면
	#    S3 도 엉뚱한 답을 자기끼리 맞대므로 **초록으로 통과한다**(§2.19 부류).
	#    그래서 **생산 경로의 문자열**(`next_round_preview()`)에서 (막,R) 을 뽑아 맞댄다.
	_emit("[S3b] 라운드 판정 대조 — _next_round() vs next_round_preview()")
	var preview_text := str(field.next_round_preview())
	var re := RegEx.new()
	re.compile("^다음 (\\d+)막 (\\d+)R:")
	var m := re.search(preview_text)
	_check(m != null, "예고 문구에서 (막,R) 을 못 뽑았다 — %s" % preview_text)
	if m != null:
		var text_act := int(m.get_string(1))
		var text_wave := int(m.get_string(2))
		_check(text_act == round.x and text_wave == round.y,
			"_next_round() = %d막 %dR 인데 문구는 %d막 %dR" % [round.x, round.y, text_act, text_wave])
		_emit("  문구 %s … → %d막 %dR · 아이콘 %d막 %dR" % [preview_text.substr(0, 22), text_act, text_wave, round.x, round.y])

	# ── S4. 툴팁 ──────────────────────────────────────────────────────────────
	_emit("[S4] 툴팁")
	var empty_tip := 0
	var wrong_tip := 0
	for k in range(mini(boxes.size(), comps.size())):
		var tip := str(boxes[k].tooltip_text)
		if tip == "":
			empty_tip += 1
		elif not tip.begins_with(str(comps[k].get("name", ""))):
			wrong_tip += 1
			_emit("  ✗ 툴팁 %s 가 이름 %s 로 시작하지 않는다" % [tip, str(comps[k].get("name", ""))])
	_check(empty_tip == 0, "빈 툴팁 %d개" % empty_tip)
	_check(wrong_tip == 0, "이름이 안 맞는 툴팁 %d개" % wrong_tip)
	if boxes.size() > 0:
		_emit("  예: %s" % str(boxes[0].tooltip_text))

	# ── S5. 레이아웃 ──────────────────────────────────────────────────────────
	_emit("[S5] 레이아웃")
	if panel != null:
		var bar_h := panel.size.y
		_check(bar_h <= 34.5, "예고 바가 자랐다 — 높이 %.1f (최소 34)" % bar_h)
		var label: Control = row.get_node_or_null("TelegraphLabel") as Control
		var strip: Control = bar as Control
		if label != null and strip != null:
			_emit("  바 %.1f x %.1f · 라벨 %.1f · 아이콘띠 %.1f" % [panel.size.x, bar_h, label.size.x, strip.size.x])
			_check(strip.size.x > 0.0, "아이콘 띠의 폭이 0이다")
			_check(label.size.x + strip.size.x <= panel.size.x,
				"라벨+아이콘이 바 폭을 넘는다 — 잘린다")

	# ── S6. 양성 대조 ─────────────────────────────────────────────────────────
	_emit("[S6] 양성 대조 — 비교가 실제로 잡는가")
	var broken: Array = comps.duplicate(true)
	if broken.size() > 0:
		broken.pop_back()
	_check(_tally_from_composition(broken) != _tally_from_composition(comps),
		"양성 대조 실패 — 한 종류를 빼도 비교가 같다고 한다")
	# S3b 의 정규식·비교에도 검출력이 있어야 한다 — 다른 막을 말하는 문구를 넣으면 달라야 한다.
	var other_text := "다음 %d막 %dR: 대조용" % [round.x % 3 + 1, 1]
	var m2 := re.search(other_text)
	_check(m2 != null, "양성 대조 — 정규식이 예고 형식을 못 읽는다")
	if m2 != null:
		_check(not (int(m2.get_string(1)) == round.x and int(m2.get_string(2)) == round.y),
			"양성 대조 실패 — 다른 막을 넣어도 같다고 한다")

	# ── S7. 보고 전용 — 글리프 ────────────────────────────────────────────────
	# `counters_text()` 는 화면 문구에 `→` 를 쓴다. `neodgm.ttf` 에 U+2192 가 **없다**
	# (fontTools 로 확인). Godot 이 시스템 폰트로 대체하면 글자체가 섞이고, 아니면 상자가 뜬다.
	_emit("[S7] 글리프 (보고 전용)")
	var act1_counters := MonsterRoster.counters_text(1)
	_emit("  counters_text(1) = %s" % act1_counters)
	_emit("  여기에 → 가 있는가: %s · × 가 있는가: %s" % [
		str(act1_counters.contains("→")), str(act1_counters.contains("×"))])

	# ── S8. 보스 라운드 ───────────────────────────────────────────────────────
	# 보스 분기는 **5라운드에 한 번**만 온다 — 화면에서 눈으로 볼 기회가 드물어서 일부러 만든다.
	# 칸이 여섯 개(보스 + 잡몹 다섯)로 늘어날 때 띠가 넘치지 않는지도 여기서 함께 본다.
	_emit("[S8] 보스 라운드")
	var saved_wave: int = int(field.current_wave)
	field.current_wave = int(field.BOSS_ROUND_INTERVAL) - 1
	bar.call("_rebuild")
	var boss_round: Vector2i = bar.call("_next_round")
	var boss_comps: Array = bar.call("composition_for", boss_round.x, boss_round.y)
	_check(boss_round.y % int(field.BOSS_ROUND_INTERVAL) == 0,
		"보스 라운드로 못 만들었다 — %d막 %dR" % [boss_round.x, boss_round.y])
	_check(boss_comps.size() > 0 and str(boss_comps[0].get("type", "")) == "boss",
		"보스 라운드인데 첫 칸이 보스가 아니다")
	_check(bar.get_child_count() == boss_comps.size(),
		"보스 띠 자식 %d개 ≠ 구성 %d개" % [bar.get_child_count(), boss_comps.size()])
	_emit("  %d막 %dR · 종류 %d개 · 첫 칸 %s" % [boss_round.x, boss_round.y, boss_comps.size(),
		str(boss_comps[0].get("name", "")) if boss_comps.size() > 0 else "-"])
	# ⚠️ **여기서 되돌린다.** 안 그러면 아래 '평상시' 스크린샷이 보스 상태로 찍혀
	#    두 장이 같은 그림이 된다(첫 판에서 실제로 그럴 뻔했다).
	field.current_wave = saved_wave
	bar.call("_rebuild")

	# ── 스크린샷 (창 모드 전용) ───────────────────────────────────────────────
	if DisplayServer.get_name() == "headless":
		_emit("[shot] headless — 건너뛴다")
		return
	var glyph := Label.new()
	glyph.text = "×2  중갑→관통·유성  A→B  화살표"
	glyph.add_theme_font_size_override("font_size", 22)
	glyph.position = Vector2(20, 260)
	main.add_child(glyph)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_emit("[shot] 이미지를 못 얻었다")
		return
	img.save_png(SHOT_DIR + "nextwave_full.png")
	if panel != null:
		var r := Rect2i(Vector2i(panel.global_position), Vector2i(panel.size))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 0 and r.size.y > 0:
			var crop := img.get_region(r)
			crop.save_png(SHOT_DIR + "nextwave_bar.png")
			crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
			crop.save_png(SHOT_DIR + "nextwave_bar_zoom.png")
	# 보스 라운드도 한 장. 상태를 **여기서 다시** 만들고 찍은 뒤 되돌린다.
	field.current_wave = int(field.BOSS_ROUND_INTERVAL) - 1
	bar.call("_rebuild")
	# 문구도 같이 맞춘다 — 안 그러면 그림은 보스인데 글자는 3R 이라 **스크린샷이 스스로 모순**된다
	# (프로브가 얼려 둔 화면을 만드는 것뿐이고, 문구의 생산자는 여전히 저 함수 하나다).
	var label_node: Label = main.get_node_or_null("VBox/TelegraphBar/Row/TelegraphLabel") as Label
	if label_node != null:
		label_node.text = str(field.next_round_preview(true))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	if img2 != null and panel != null:
		var r2 := Rect2i(Vector2i(panel.global_position), Vector2i(panel.size))
		r2 = r2.intersection(Rect2i(Vector2i.ZERO, img2.get_size()))
		if r2.size.x > 0 and r2.size.y > 0:
			var crop2 := img2.get_region(r2)
			crop2.resize(crop2.get_width() * 3, crop2.get_height() * 3, Image.INTERPOLATE_NEAREST)
			crop2.save_png(SHOT_DIR + "nextwave_bar_boss.png")
	field.current_wave = saved_wave
	bar.call("_rebuild")
	_emit("[shot] nextwave_full.png · nextwave_bar.png · nextwave_bar_zoom.png · nextwave_bar_boss.png")
