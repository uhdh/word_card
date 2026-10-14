# SynergySurfaceProbe.gd
# 타워 정보 모달의 시너지 목록이 **몇 번 그려지고, 그중 무엇이 화면에 닿는가** 를 잰다.
#
# 왜 재는가 (2026-10-06):
#   §2.30-4 는 "`neodgm.ttf` 에 `→`(U+2192) 가 없다" 를 **표본 둘**(`→` · `←`)로 적었다.
#   그 문장을 **모집단**으로 넓히려고 플레이어 문구를 전수로 훑었더니 **48종**이 없었다
#   (§2.32 → §2.35 와 같은 교훈 — 표본이 최악을 안 뽑는다).
#   그 48종 중 19종이 **시너지 텍스트 표면**(`SynergyLabel`)에만 있었는데, 그 노드는
#   씬에서 `visible = false` 이고 `visible = true` 대입이 **0건**이다 — 영영 안 보인다.
#   그런데 `_render_synergy_badges()` 는 매번 그 표면의 문구를 만들고, `tests/test_tower_traits.gd`
#   는 **그 안 보이는 표면의 내용**을 단언한다. ⇒ **코드와 테스트가 도달 불가능한 표면을 지킨다**
#   (§2.36 이 프로브에서 찾은 것과 같은 부류 — 거기서는 프로브, 여기서는 테스트).
#
# 고침 (§2.38 대안 A · 2026-10-06 · 감독 결정):
#   정보는 **안 잃고 있었다** — 배지가 같은 것을 나르고 있었다. 결함은 **낭비와 거짓 제약**이다:
#   매번 만들면서 아무도 안 보고, 두 글리프 표(19종)가 이 표면 하나 때문에 존재하고,
#   **테스트가 그 안 보이는 내용을 지킨다**(정당한 정리를 회귀로 보이게 만든다).
#   그래서 표면과 글리프 표를 **지웠다.** 표시 문구는 **0자 변경**이다.
#   ⚠️ 그래서 **S1 의 계약이 뒤집혔다** — "화면에 있는가" → **"있으면 안 된다"**.
#      (기준을 안 바꾸면 고침 뒤에도 빨강이 남아 "고쳤는데 왜 빨갛나" 가 된다.)
#
# 재는 것:
#   S0  실 게임 문으로 타워를 세우고 정보 모달을 연다(`tower_info_requested` → `modal_layer`)
#   S1  판정 — 도달 불가능한 텍스트 표면이 **사라졌는가** (코드·씬 둘 다)
#   S2  판정 — 배지 표면은 보이고 배지가 붙었는가 (정보가 실제로 도달하는가)
#   S3  판정 — 배지마다 툴팁이 있는가 (숨은 표면이 나르던 정보의 보존)
#   S4  판정 — 글리프 표(`TraitStyle.GLYPHS` · `MonsterRoster.GLYPHS`)가 **사라졌는가**
#   S5  양성 대조 — **보이는** 표면에는 같은 글리프가 실제로 있는가(공허한 판정 방지)
#   S6  런타임 글리프 전수 — 보이는 텍스트에서 1차 폰트에 없는 코드포인트
#   S7  스크린샷
#
# ⚠️ 루트는 반드시 `Node` — `Node2D` 면 `TowerDefenseMain`(Control) 앵커가 안 잡힌다.
# ⚠️ **"안 보임" 자체를 결함으로 단정하지 않는다** — 유물 게이트로 숨는 표면이 있다(§2.36).
#    이 절의 판정은 **"내용을 만들면서 안 보인다"** 는 조합 하나뿐이다.
# ⚠️ **정적 문자열 스캔은 보임/숨김을 못 가른다** — 그래서 S4(정적)와 S6(런타임)을 나란히 낸다.
extends Node

const AttackStyleScript = preload("res://scripts/core/AttackStyle.gd")
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
const MonsterRoster = preload("res://scripts/tower/MonsterRoster.gd")
# ⚠️ §2.38 (2026-10-06) — 여기 있던 `MODAL_SCENE` 을 지웠다. 옛 S4b 가 특성 11종을
#    태우려고 정보 모달을 직접 만들었는데, 그 절이 재던 **숨은 표면**이 사라졌다.

const OUT_PATH := "E:/project/word_card/tmp/synergysurface.txt"
const SHOT_PATH := "E:/project/word_card/tmp/synergysurface.png"
const FONT_PATH := "res://fonts/neodgm.ttf"

var failures := 0
var _lines: PackedStringArray = []
var _font: Font = null


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


## 1차 폰트(테마가 쓰는 `neodgm.ttf`)에 없는 코드포인트만 돌려준다.
## ⚠️ `FontFile.has_char()` 는 **그 파일의 cmap** 만 본다 — 폴백은 안 본다. 우리가 원하는 것이 그것이다.
func _missing(text: String) -> Array:
	var out: Array = []
	if _font == null:
		return out
	var seen: Dictionary = {}
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp < 0x20:
			continue
		if seen.has(cp):
			continue
		seen[cp] = true
		if not _font.has_char(cp):
			out.append(cp)
	return out


func _cp_name(cp: int) -> String:
	return "U+%04X %s" % [cp, String.chr(cp)]


## 보이는 텍스트 표면을 전부 모은다 — `{path, kind, text, missing}`.
## 정적 스캔과 달리 **화면에 있는 것만** 센다.
func _visible_text(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var c: Control = null
		if n is Label or n is RichTextLabel or n is BaseButton:
			c = n
		if c != null and c.is_visible_in_tree():
			var t := ""
			if n is Label:
				t = (n as Label).text
			elif n is RichTextLabel:
				t = (n as RichTextLabel).text
			elif n is BaseButton:
				t = (n as BaseButton).text
			if t != "":
				var miss := _missing(t)
				if miss.size() > 0:
					out.append({
						"path": String(root.get_path_to(n)),
						"kind": n.get_class(),
						"text": t,
						"missing": miss,
					})
		for k in n.get_children():
			stack.append(k)
	return out


## 트리 **어디에든**(보이든 안 보이든) 붙어 있는 문구를 전부 이어 붙인다.
## ⚠️ 표가 만드는 글리프가 **정말 아무 데도 안 쓰이는지** 를 호출자 세기가 아니라
##    **트리 실측**으로 확인하기 위한 것이다(그렙이 못 잡는 동적 대입을 잡는다).
func _all_text(root: Node) -> String:
	var buf := ""
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Label:
			buf += (n as Label).text
		elif n is RichTextLabel:
			buf += (n as RichTextLabel).text
		elif n is BaseButton:
			buf += (n as BaseButton).text
		if n is Control:
			buf += (n as Control).tooltip_text
		for k in n.get_children():
			stack.append(k)
	return buf


## 배지 컨트롤 안의 문구(라벨들)를 한 줄로 — 보고용.
func _badge_text(ch: Node) -> String:
	var parts: Array = []
	var stack: Array = [ch]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Label:
			parts.append((n as Label).text)
		elif n is RichTextLabel:
			parts.append((n as RichTextLabel).text)
		elif n is BaseButton:
			parts.append((n as BaseButton).text)
		for k in n.get_children():
			stack.append(k)
	return "/".join(parts)


func _clear_modals(main: Node) -> void:
	var layer = main.get("modal_layer")
	if layer == null:
		return
	for ch in (layer as Node).get_children():
		ch.queue_free()


## 특성 시너지를 가진 타워를 실 게임 문으로 세운다. `저격` 을 우선 고른다(`🎯` 가 붙는다).
func _place_tower_with_trait(field: Node) -> WordTower:
	var sniper: Array = []
	var other: Array = []
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
		var entry := {"syllable": ws, "word_data": WordDatabase.get_word_data(ws)}
		if tid == "sniper":
			sniper.append(entry)
		else:
			other.append(entry)
	var parsed: Array = sniper.slice(0, 2) + other.slice(0, 1)
	if parsed.is_empty():
		return null
	_emit("S0 세울 타워 %d개 (특성 보유 단어에서 고름)" % parsed.size())
	field.update_towers_from_parsed_list(parsed)
	for i in 60:
		await get_tree().process_frame
	for t in field.active_towers:
		if t == null:
			continue
		for lbl in t.synergy_labels:
			if str(lbl).begins_with("특성: "):
				return t
	return null


func _ready() -> void:
	_watchdog()
	_emit("SYNERGY_SURFACE_START")

	_font = load(FONT_PATH)
	if _font == null:
		_emit("폰트를 못 열었다: %s" % FONT_PATH)
		get_tree().quit(3)
		return
	check(_font.has_method("has_char"), "`Font.has_char()` 가 없다 — 이 프로브의 전제가 틀렸다")

	# ⚠️ 세이브가 있으면 그 상태로 이어서 시작한다 — 초기 상태를 고정한다.
	SaveManager.delete_save_file()
	var main: Node = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_modals(main)
	var field: Node = main.find_child("DefenseField", true, false)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return

	# ── S0. 실 게임 문으로 모달을 연다 ──────────────────────────────────────
	var tower: WordTower = await _place_tower_with_trait(field)
	if tower == null:
		_emit("S0 특성 시너지를 가진 타워를 못 세웠다 — 재는 대상이 틀렸다")
		get_tree().quit(3)
		return
	_clear_modals(main)
	await get_tree().process_frame
	_emit("S0 타워 특성=%s · 시너지 %d줄: %s" % [
		tower.trait_id, tower.synergy_labels.size(), str(tower.synergy_labels)])
	field.tower_info_requested.emit(tower)
	await get_tree().process_frame
	await get_tree().process_frame

	var layer = main.get("modal_layer")
	if layer == null:
		_emit("modal_layer 가 없다")
		get_tree().quit(3)
		return
	var modal: Node = null
	for ch in (layer as Node).get_children():
		if ch.get("synergy_row") != null:
			modal = ch
	if modal == null:
		_emit("S0 정보 모달이 안 열렸다 — 문이 바뀌었나?")
		get_tree().quit(3)
		return
	_emit("S0 정보 모달 열림 (%s)" % modal.get_class())

	var sr: HFlowContainer = modal.get("synergy_row")
	var st: Label = modal.get("stats_label")
	check(sr != null, "`synergy_row` 를 못 얻었다 — 씬 구조가 바뀌었나?")

	# ── S1. 판정 — 도달 불가능한 텍스트 표면이 **사라졌는가** ────────────────
	# ⚠️ **판정 기준이 2026-10-06 에 뒤집혔다** (§2.38 대안 A · 감독 결정).
	#    고치기 전 이 자리는 *"텍스트 표면이 화면에 있는가"* 를 물었고 **빨강**이었다.
	#    고침은 그 표면을 **켜는 것이 아니라 지우는 것**이었으므로, 계약도
	#    *"있으면 안 된다"* 로 바뀐다 — 기준을 안 바꾸면 고침 뒤에도 빨강이 남는다.
	# ⚠️ 그리고 **지우는 쪽을 골랐다는 사실 자체를 잠가야** 한다: 누군가 표면을 되살리면
	#    (켜든 숨기든) 다시 빨개진다 — *"안 보이는 표면을 그리지 않는다"* 가 계약이다.
	# ⚠️ 씬 노드는 **트리에서** 찾는다(파일을 읽지 않는다) — 인스턴스에 있으면 보이는 것이다.
	var dead_var: Variant = modal.get("synergy_label")
	var dead_node := modal.find_child("SynergyLabel", true, false) != null
	_emit("S1 도달 불가능한 텍스트 표면 — 코드 %s · 씬 노드 %s" % [
		"없음" if dead_var == null else "있음", "없음" if not dead_node else "있음"])
	check(dead_var == null,
		"`synergy_label` 이 코드에 아직 있다 — 아무도 못 보는 표면을 매번 그리게 된다")
	check(not dead_node,
		"`SynergyLabel` 노드가 씬에 아직 있다 — 켜지도 못하는 표면을 지킨다")

	# ── S2. 판정 — 배지 표면이 정보를 실제로 나르는가 ───────────────────────
	var badge_count := 0
	var badge_visible := false
	if sr != null:
		badge_count = sr.get_child_count()
		badge_visible = sr.is_visible_in_tree()
	_emit("S2 시너지 배지 표면 — 배지 %d개 · 화면에 보임=%s" % [badge_count, str(badge_visible)])
	check(badge_count > 0, "배지가 0개다 — 그러면 S1 의 '안 보임' 이 곧 **정보 손실**이 된다")
	check(badge_visible, "배지 표면이 화면에 없다 — 시너지가 어디에도 안 보인다")

	# ── S3. 판정 — 숨은 표면이 나르던 정보가 배지에 남았는가 ────────────────
	# ⚠️ **같은 것끼리 맞댄다.** 숨은 표면의 `[hint=]` 는 **특성 배지에만** 붙었다
	#    (`결: ` 모양 시너지와 인접 시너지는 **양쪽 다** 설명 출처가 없다 — `_synergy_style`).
	#    "모든 배지에 툴팁이 있어야 한다" 로 재면 **없던 정보를 요구**하게 된다(첫 판이 그랬다).
	var trait_labels := 0
	for lbl in tower.synergy_labels:
		if str(lbl).begins_with("특성: "):
			trait_labels += 1
	var tipped := 0
	var tips: Array = []
	var bare: Array = []
	if sr != null:
		for ch in sr.get_children():
			if not (ch is Control):
				continue
			var tip := str((ch as Control).tooltip_text)
			if tip != "":
				tipped += 1
				tips.append(tip.substr(0, 34))
			else:
				bare.append(_badge_text(ch))
	_emit("S3 특성 배지 %d개 · 툴팁 가진 배지 %d개 · 툴팁 없는 배지 %s" % [
		trait_labels, tipped, str(bare)])
	_emit("S3 툴팁 문구 %s" % str(tips))
	check(tipped >= trait_labels,
		"특성 배지 %d개 중 툴팁이 붙은 것이 %d개다 — 숨은 표면이 `[hint=]` 로 나르던 특성 설명이 배지에서 사라졌다" % [trait_labels, tipped])

	# ── S4. 판정 — 글리프 표가 **사라졌는가** (§2.38-2 ②) ────────────────────
	# ⚠️ 두 표(`TraitStyle.GLYPHS` 11종 · `MonsterRoster.GLYPHS` 8종)는 **이 표면 하나**
	#    때문에 존재했다. 표면을 지웠으니 표도 함께 사라져야 한다 — 남아 있으면
	#    "소비자 0건인 죽은 표" 가 그대로 남는다(§2.38-2 ② 가 지적한 그 낭비).
	#    옛 S4c 는 트리 실측으로 *"표의 글리프가 트리에 0종/1종"* 을 재 그 주장을 뒷받침했다.
	#    이제 표 자체가 없으므로, 재는 것은 **표의 부재**다.
	# ⚠️ **양성 대조를 먼저 둔다** — `get_script_constant_map()`·`has_method()` 가 살아 있는
	#    것도 못 잡으면 "지워졌다" 가 **공짜 통과**가 된다(§2.34-3-(b) 와 같은 부류).
	# ⚠️ **클래스에 인스턴스 메서드를 직접 부를 수 없다** — `TraitStyle.get_script_constant_map()`
	#    은 파서가 거부한다(*"Cannot call non-static function ... on the class ... directly"*).
	#    `Script` 로 받아야 한다(`preload` 상수는 런타임에는 GDScript **리소스**다).
	var ts_script: Script = TraitStyle
	var mr_script: Script = MonsterRoster
	var ts_cmap: Dictionary = ts_script.get_script_constant_map()
	var mr_cmap: Dictionary = mr_script.get_script_constant_map()
	check(ts_cmap.has("NAMES") and ts_cmap.has("COLORS"),
		"양성 대조 실패 — 상수 맵이 살아 있는 상수(`NAMES`/`COLORS`)도 못 잡는다")
	check(ts_script.has_method("color_for") and mr_script.has_method("draw_icon"),
		"양성 대조 실패 — `has_method` 가 살아 있는 메서드도 못 잡는다")
	_emit("S4 양성 대조 — TraitStyle 상수 %d종 · color_for=%s · MonsterRoster.draw_icon=%s" % [
		ts_cmap.size(), str(ts_script.has_method("color_for")),
		str(mr_script.has_method("draw_icon"))])

	var ts_has := ts_cmap.has("GLYPHS")
	var mr_has := mr_cmap.has("GLYPHS")
	var ts_fn := ts_script.has_method("glyph_for")
	var mr_fn := mr_script.has_method("glyph_for")
	_emit("S4 글리프 표 — TraitStyle.GLYPHS=%s · MonsterRoster.GLYPHS=%s · glyph_for=%s / %s" % [
		str(ts_has), str(mr_has), str(ts_fn), str(mr_fn)])
	check(not ts_has, "`TraitStyle.GLYPHS` 가 아직 있다 — 소비자가 사라진 죽은 표다")
	check(not mr_has, "`MonsterRoster.GLYPHS` 가 아직 있다 — 소비자가 **0건**이던 표다")
	check(not ts_fn, "`TraitStyle.glyph_for()` 가 아직 있다 — 부르는 곳이 없다")
	check(not mr_fn, "`MonsterRoster.glyph_for()` 가 아직 있다 — 부르는 곳이 없다")

	# ── S5. 양성 대조 — 보이는 표면에도 같은 글리프가 있는가 ────────────────
	# ⚠️ 이게 없으면 "글리프가 어디에도 안 간다" 와 구별되지 않는다.
	var stat_shown := st != null and st.is_visible_in_tree()
	var stat_missing: Array = []
	if st != null:
		stat_missing = _missing(st.text)
	_emit("S5 양성 대조 — 통계 라벨 보임=%s · 폰트 밖 글리프 %d종 %s | 문구 %s" % [
		str(stat_shown), stat_missing.size(), str(stat_missing.map(_cp_name)), st.text if st != null else ""])
	check(stat_shown, "통계 라벨이 안 보인다 — 양성 대조가 성립하지 않는다")
	check(stat_missing.size() > 0,
		"보이는 표면에서 폰트 밖 글리프를 못 찾았다 — 그러면 이 절이 재는 것이 없다")

	# ── S6. 런타임 글리프 전수 — 화면에 있는 텍스트만 ──────────────────────
	var vis := _visible_text(main)
	var cp_set: Dictionary = {}
	for d in vis:
		for cp in d["missing"]:
			var bucket: Array = cp_set.get(cp, [])
			bucket.append(str(d["path"]))
			cp_set[cp] = bucket
	_emit("S6 화면에 있는 텍스트 표면 %d개가 폰트 밖 글리프 %d종을 쓴다" % [vis.size(), cp_set.size()])
	for cp in cp_set:
		_emit("    %s  ← %s" % [_cp_name(cp), str(cp_set[cp][0])])

	# ── S7. 스크린샷 ───────────────────────────────────────────────────────
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(SHOT_PATH)
			_emit("S7 스크린샷 %s" % SHOT_PATH)
	else:
		_emit("S7 헤드리스 — 스크린샷 생략")

	if failures == 0:
		_emit("SYNERGY_SURFACE_PROBE_OK")
	else:
		_emit("SYNERGY_SURFACE_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
