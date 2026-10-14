extends Node
# 텔레그래프 예고가 **잘리지 않게** 하려면 무엇을 포기해야 하는가 — 선택지별 폭을 잰다.
#
#   godot --path . res://tools/TelegraphOptionMeasure.tscn
#
# 왜 필요한가: `tools/TelegraphTextWidth.gd` 가 "60/60 잘림" 을 보고하지만
# **고칠 방법의 값은 재지 않는다.** 이 도구는 같은 60개 문구에 대해
# '무엇을 빼면 몇 px 이 되는가' 를 전부 재서, 감독이 숫자로 고르게 한다.
#
# ⚠️ 손으로 만든 최악값을 쓰지 않는다 — 도달 가능한 (막, 라운드) 전수를 훑는다.
# ⚠️ 판정 도구가 아니다: `quit(0)` 으로 끝난다(보고 전용). 시나리오가 없으면 quit(2).

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const Roster = preload("res://scripts/tower/MonsterRoster.gd")

var _field = null

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
	main.defense_field.reset_combat_state()
	await get_tree().process_frame

	var label: Label = main.telegraph_label
	if label == null:
		push_error("telegraph_label 을 찾지 못했다 — 이 도구는 씬 구조에 의존한다")
		get_tree().quit(2)
		return
	_field = main.defense_field

	# 라벨이 가장 좁아지는 상태로 고정한다(웨이브 중 · 타이머 최장).
	_field.is_wave_running = true
	_field.is_planning_phase = false
	_field.round_timer = 0.0
	await get_tree().process_frame
	await get_tree().process_frame

	var font: Font = label.get_theme_font("font")
	var fsize: int = label.get_theme_font_size("font_size")
	var limit: float = label.size.x
	print("── 기준 ──")
	print("   폰트 %s %d · 라벨 폭 %.1f px · 바 높이 %.0f px (clip=%s)" % [
		font.get_font_name(), fsize, limit,
		main.get_node("VBox/TelegraphBar").custom_minimum_size.y, str(label.clip_text)])
	print("   상수: MAX_ACTS=%d · MAX_WAVES_PER_ACT=%d · BOSS_ROUND_INTERVAL=%d" % [
		_field.MAX_ACTS, _field.MAX_WAVES_PER_ACT, _field.BOSS_ROUND_INTERVAL])

	var variants: Array = [
		["V0 현재 (전부)", func(a: int, w: int) -> String: return _field.next_round_preview()],
		["V1 로스터만", func(a: int, w: int) -> String: return _roster_only(a, w)],
		["V2 상성 괄호 제거", func(a: int, w: int) -> String: return _with_counters(a, w, _strip_parens(Roster.counters_text(a)), 0)],
		["V3 상성 앞 3개", func(a: int, w: int) -> String: return _with_counters(a, w, Roster.counters_text(a), 3)],
		["V4 상성 앞 4개", func(a: int, w: int) -> String: return _with_counters(a, w, Roster.counters_text(a), 4)],
		["V5 상성만 (로스터 없음)", func(a: int, w: int) -> String: return _head(a, w) + Roster.counters_text(a)],
		["V6 되는만큼 (그리디)", func(a: int, w: int) -> String: return _greedy_fit(a, w, font, fsize, limit)],
	]

	var acts: Array = []
	for a in range(1, _field.MAX_ACTS + 1):
		acts.append(a)
	var waves: Array = []
	for w in range(1, _field.MAX_WAVES_PER_ACT + 1):
		waves.append(w)

	print("")
	print("── 전수 %d개 (막 %d × 라운드 %d) ──" % [acts.size() * waves.size(), acts.size(), waves.size()])
	print("%-24s %9s %8s %8s   %s" % ["선택지", "맞는수", "최장", "여유", "판정"])
	var results: Array = []
	for v in variants:
		var vname: String = v[0]
		var maker: Callable = v[1]
		var fit := 0
		var total := 0
		var worst_w := -1.0
		var worst_txt := ""
		var worst_at := Vector2i.ZERO
		for a in acts:
			for w in waves:
				# ⚠️ V0 은 `_field.next_round_preview()` 를 그대로 부르므로 **필드 상태를
				#    실제로 옮겨 줘야** 한다. 안 그러면 60번 같은 문구를 재고 "60개 훑었다"
				#    고 착각한다(이 도구의 첫 판이 실제로 그랬다 — 최장이 1434 px 로 나왔다).
				_field.current_act = a
				_field.current_wave = w
				var text: String = maker.call(a, w)
				var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
				total += 1
				if tw <= limit:
					fit += 1
				if tw > worst_w:
					worst_w = tw
					worst_txt = text
					worst_at = Vector2i(a, w)
		var margin := limit - worst_w
		var verdict := "전부 들어감" if fit == total else ("일부 잘림" if fit > 0 else "**전부 잘림**")
		print("%-24s %6d/%d %8.0f %8.0f   %s" % [vname, fit, total, worst_w, margin, verdict])
		results.append([vname, worst_w, margin, worst_txt, worst_at])

	print("")
	print("── 선택지별 최장 문구 ──")
	for r in results:
		print("")
		print("   %s  (최장 %d막 %dR · %.0f px · %s%.0f px)" % [
			r[0], r[4].x, r[4].y, r[1],
			"여유 " if r[2] >= 0.0 else "초과 ", absf(r[2])])
		print("   %s" % r[3])

	print("TELEGRAPH_OPTION_PROBE_OK")
	get_tree().quit(0)


## 로스터까지만. 보스 라운드는 로스터가 없으므로 약점 머리만.
func _roster_only(act: int, wave: int) -> String:
	var next_wave := mini(wave + 1, _field.MAX_WAVES_PER_ACT)
	var next_act := act
	if wave >= _field.MAX_WAVES_PER_ACT and act < _field.MAX_ACTS:
		next_act = act + 1
		next_wave = 1
	if next_wave % _field.BOSS_ROUND_INTERVAL == 0:
		return _head(act, wave)
	return "다음 %d막 %dR: %s" % [next_act, next_wave, Roster.roster_text(act)]


## 로스터는 **항상 남기고**, 상성 항목을 **들어가는 만큼만** 붙인다.
## 넘치는 순간 멈추므로 60/60 이 보장된다 — 정보 손실은 뒤쪽 항목뿐이다.
func _greedy_fit(act: int, wave: int, font: Font, fsize: int, limit: float) -> String:
	var base := _roster_only(act, wave)
	var counters := Roster.counters_text(act)
	if counters == "":
		return base
	var entries: PackedStringArray = counters.split("  ", false)
	var kept: Array = []
	for e in entries:
		var cand := base + " | " + "  ".join(kept + [e])
		var tw: float = font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		if tw <= limit:
			kept.append(e)
		else:
			break
	if kept.is_empty():
		return base
	return base + " | " + "  ".join(kept)


## "다음 N막 NR: " 또는 보스 라운드의 "다음 N막 NR: 보스 · 약점 X" 까지.
func _head(act: int, wave: int) -> String:
	var next_wave := mini(wave + 1, _field.MAX_WAVES_PER_ACT)
	var next_act := act
	if wave >= _field.MAX_WAVES_PER_ACT and act < _field.MAX_ACTS:
		next_act = act + 1
		next_wave = 1
	if next_wave % _field.BOSS_ROUND_INTERVAL == 0:
		var weakness := Roster.weakness_for(next_wave, _field.BOSS_ROUND_INTERVAL)
		var lbl: String = str(Roster.BOSS_WEAKNESS_LABELS.get(weakness, weakness))
		return "다음 %d막 %dR: 보스 · 약점 %s" % [next_act, next_wave, lbl]
	return "다음 %d막 %dR: " % [next_act, next_wave]


## _head 뒤에 상성을 붙인다. keep>0 이면 앞 keep 개만.
func _with_counters(act: int, wave: int, counters: String, keep: int) -> String:
	var c := counters
	if keep > 0:
		var entries: PackedStringArray = counters.split("  ", false)
		var picked: Array = []
		for i in range(mini(keep, entries.size())):
			picked.append(entries[i])
		c = "  ".join(picked)
	if c == "":
		return _head(act, wave)
	return "%s | %s" % [_head(act, wave), c]


## "  " 로 나눈 각 항목에서 " (…에 약함)" 꼬리를 자른다.
func _strip_parens(counters: String) -> String:
	var entries: PackedStringArray = counters.split("  ", false)
	var out: Array = []
	for e in entries:
		var idx := e.find(" (")
		out.append(e.substr(0, idx) if idx >= 0 else e)
	return "  ".join(out)
