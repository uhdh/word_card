extends Node
# 보스 **약점**은 규칙인데, 전투가 벌어지는 동안 화면에 있는가 (§2.4 잔여 · §5.3 25 관련).
#
# 왜 이 도구가 필요한가 — 코드를 읽다가 발견했다. `_show_boss_banner()` 의 머리말은
# 이렇게 약속한다:
#
#     ## 보스 등장 배너. 약점을 함께 알려줘서 '무엇으로 때려야 하는지' 를 **즉시 전달한다.**
#
# 그리고 `MonsterRoster.gd:61` 은 보스에게 **타입 배지를 달지 않는 이유**를 이렇게 적는다:
#
#     ## 'boss' 도 배지를 달지 않는다: 보스는 등장 배너가 약점까지 크게 알려 준다.
#
# 즉 **배너가 약점의 유일한 채널**이다. 그런데 그 배너는 트윈으로 떴다가 사라진다.
# 그러면 질문이 하나 남는다 — **배너가 사라진 뒤, 전투가 계속되는 동안 그 규칙은
# 화면 어디에 있는가?** 이 도구가 그걸 잰다.
#
# ⚠️ **감사에 이 항목은 없다.** §2.4 문제 4 는 "예고(Anticipation)가 없다"(보스가 이미
# 걸어오는 중에 연출이 터진다)였고, §5.3 25 는 "게임 진행을 멈춰야 함" 이라 보류됐다.
# 둘 다 **등장 전** 이야기다. 여기서 재는 것은 **등장 후**다 — 다른 질문이다.
#
# ⚠️ **"약점을 모른다" 고 주장하지 않는다.** 정보는 두 번 나온다:
#   (1) 웨이브 전 — 텔레그래프 바 `next_round_preview()` 가 "…보스 · 약점 관통" 을 담는다
#   (2) 등장 순간 — 배너 2.15초
# 재는 것은 그 다음이다: **보스가 살아 있는 동안** 화면에 남아 있는가.
# 그래서 §4 는 "정보가 없는가" 가 아니라 **"배너가 사라진 뒤에도 남아 있는가"** 를 잰다.
#
# 재는 것:
#   §1  약점의 무게 — 실제 보스에서 약점/비약점 배율을 재고 비율을 낸다
#   §2  등장 전: 예고 문구가 약점을 담고 있는가 (+ 그 부분이 잘리지 않는가)
#   §3  등장 순간: 배너가 약점을 담고 있는가
#   §4  배너의 수명 — 게임시간과 실시간을 **둘 다** 잰다 (1배속 / 4배속)
#   §5  ✅ 배너가 사라진 뒤에도 **보이는 '약점' 문구가 남아 있는가** (보스는 아직 살아 있다)
#   §6  그동안 남아 있는 것 — 보스 체력바. **행 셋**(이름·체력·약점)이고 배너와 겹치지 않는가
#   §7  ⚠️ 전투 중 대체 신호가 없는 이유 — 비약점 타격은 **라벨이 안 붙는다**
#
# ## ✅ 고침 — 감독이 §5.2 28 의 **(A)** 를 골랐다 (2026-10-01)
# 보스 체력바에 **`약점: X` 상시 한 줄**을 붙였다(행 2 → 3). 문구는 **등장 배너와 같은 출처**
# (`enemy.weakness_trait` + `BOSS_WEAKNESS_LABELS`)를 읽는다 — 손으로 적으면 §2.18 의 드리프트다.
# **새 정보를 만들지 않았다** — 이미 배너가 말하던 것을 **오래 남기는** 것뿐이다.
# ⚠️ 행이 늘어 `BOSS_BANNER_TOP` 을 54 → 80 으로 내렸다. §6 이 **겹침까지** 단언한다 —
#    약점을 보이자고 만든 행이 배너의 약점 문구를 덮으면 아무것도 못 한 것이다.
# ⚠️ §5·§6 은 이 고침으로 **극성이 뒤집혔다**(예전에는 결함을 *기록*했다). 되돌리면 빨개진다.
#
# 실행: godot --headless --path . res://tools/BossWeaknessProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const BOSS_WAVE := 5          # BOSS_ROUND_INTERVAL = 5 → 5의 배수가 보스 라운드

var failures := 0

## 절 태그를 함께 찍는다 — 주입 표의 "걸린 절" 이 기계로 구분되어야 한다(§2.17).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

func _count_named(node: Node, target: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.name == target:
			n += 1
	return n

func _find_named(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for c in node.get_children():
		var hit := _find_named(c, target)
		if hit != null:
			return hit
	return null

## 화면에 **보이는** 라벨 중 `needle` 을 담은 것들의 문구. `is_visible_in_tree()` 로 센다 —
## 개수는 '보이는 것' 으로 세야 한다(숨은 노드는 정보가 아니다).
func _visible_texts_containing(root: Node, needle: String) -> Array:
	var out: Array = []
	if root is Label:
		var lbl := root as Label
		if lbl.is_visible_in_tree() and lbl.text.contains(needle):
			out.append(lbl.text)
	elif root is Control:
		var ctl := root as Control
		if ctl.is_visible_in_tree() and ctl.tooltip_text.contains(needle):
			out.append("[툴팁] " + ctl.tooltip_text)
	for c in root.get_children():
		out.append_array(_visible_texts_containing(c, needle))
	return out

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
	# `start_new_game()` 끝의 `call_deferred("_start_wave_automatically")` 가 늦게 도착하면
	# 다시 멈춘다. 안 멈추면 아래 `start_next_wave()` 가 `is_wave_running` 에 막혀 조용히 실패한다.
	if main.defense_field.is_wave_running:
		main.defense_field.reset_combat_state()
		await get_tree().process_frame

	var field = main.defense_field
	check(field.current_act == 1, "기준선이 1막이 아니다 (제 %d막)" % field.current_act)
	check(not field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다")

	# ── §0 기준선 ─────────────────────────────────────────────────────────────
	var base_hits := _visible_texts_containing(main, "약점")
	print("BOSS_WEAKNESS baseline visible_약점=%d banners=%d" % [
		base_hits.size(), _count_named(field, "BossBanner")])
	check(base_hits.is_empty(),
		"기준선에 이미 '약점' 문구가 %d건 보인다 — §5 의 0건 주장이 무의미해진다: %s" % [
			base_hits.size(), str(base_hits)])

	# ── §2 등장 전: 예고 문구 ─────────────────────────────────────────────────
	# `next_round_preview()` 는 `current_wave + 1` 을 말한다. 그래서 5R 보스를 보려면
	# `current_wave` 를 4 로 둔 채로 불러야 한다(아직 웨이브를 열지 않은 시점).
	field.current_wave = BOSS_WAVE - 1
	var preview: String = field.next_round_preview()
	var want: String = str(MonsterRoster.BOSS_WEAKNESS_LABELS.get(
		MonsterRoster.weakness_for(BOSS_WAVE, field.BOSS_ROUND_INTERVAL), ""))
	print("BOSS_WEAKNESS preview=\"%s\"" % preview)
	print("BOSS_WEAKNESS preview_want=\"%s\"" % want)
	check(preview.contains("약점"),
		"보스 예고 문구에 '약점' 이 없다 — 등장 전 채널이 비었다: \"%s\"" % preview)
	check(want != "" and preview.contains(want),
		"예고 문구가 약점 이름(%s)을 담지 않았다: \"%s\"" % [want, preview])

	# 그 부분이 잘리지 않는가 — 라벨은 `clip_text = true` 라 넘치면 조용히 잘린다(§2.13-2).
	# 잘림은 **문자열 끝**에서 일어나므로, "약점 X" 까지의 폭이 라벨 폭보다 작으면 살아남는다.
	var label: Label = main.telegraph_label
	if label != null:
		var font: Font = label.get_theme_font("font")
		var fsize: int = label.get_theme_font_size("font_size")
		var label_w: float = label.size.x
		var full_w: float = font.get_string_size(preview, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var cut := preview.find(want) + want.length()
		var prefix_w: float = font.get_string_size(preview.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		print("BOSS_WEAKNESS preview_width label=%.0fpx full=%.0fpx prefix_to_weakness=%.0fpx" % [
			label_w, full_w, prefix_w])
		check(prefix_w <= label_w,
			"'약점 %s' 부분이 잘린다 — 예고 채널마저 죽는다 (%.0fpx > 라벨 %.0fpx)" % [want, prefix_w, label_w])

	# ── §1 약점의 무게 — 실제 보스에서 잰다 ───────────────────────────────────
	# 스폰 뒤에 재야 하므로 §1 의 출력은 §3 뒤에 나온다. 여기서는 값만 기억해 둘 변수를 만든다.
	var mult_weak := 0.0
	var mult_other := 0.0

	# ── §3 보스 라운드를 실제 경로로 연다 ─────────────────────────────────────
	field.start_next_wave()
	check(field.current_wave == BOSS_WAVE,
		"보스 라운드로 가지 못했다 (wave=%d)" % field.current_wave)
	check(field.spawn_queue.size() > 0, "스폰 큐가 비었다 — 보스가 예약되지 않았다")

	var deadline := Time.get_ticks_msec() + 2500
	while field.get_enemies().filter(func(e): return e.enemy_type == "boss").is_empty() \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	var boss: EnemyUnit = null
	for e in field.get_enemies():
		if e.enemy_type == "boss":
			boss = e
			break
	check(boss != null, "보스가 스폰되지 않았다 — 이 실행은 다른 것을 재고 있다")
	if boss == null:
		print("BOSS_WEAKNESS_ABORT")
		get_tree().quit(failures + 1)
		return

	# ── §1 (계속) 약점의 무게 ────────────────────────────────────────────────
	mult_weak = boss.damage_multiplier_for(boss.weakness_trait)
	# 약점이 아닌 특성 하나를 고른다. `rapid` 는 어떤 보스 약점도 아니다(순환은 관통→폭발→제어→지속 피해).
	mult_other = boss.damage_multiplier_for("rapid")
	print("BOSS_WEAKNESS stakes weakness=%s mult_weak=%.2f mult_rapid=%.2f ratio=%.2f" % [
		boss.weakness_trait, mult_weak, mult_other, mult_weak / maxf(0.01, mult_other)])
	check(mult_weak > mult_other,
		"약점 배율(%.2f)이 비약점(%.2f)보다 크지 않다 — 이 규칙은 무게가 없다" % [mult_weak, mult_other])
	check(mult_weak / maxf(0.01, mult_other) >= 1.3,
		"약점/비약점 비율이 %.2f 뿐이다 — '약점을 찔러야 한다' 가 성립하지 않는다" % (mult_weak / maxf(0.01, mult_other)))

	# ── §7 전투 중 대체 신호가 있는가 — 피해 숫자의 라벨 ───────────────────────
	# `_hit_kind()` 는 `mult >= WEAK_MULT(1.35)` 면 '약점', `mult <= RESIST_MULT(0.72)` 면 '내성'.
	# 그 사이는 아무 표시도 없다 — 즉 **비약점 타격은 평범한 흰 숫자로 뜬다.**
	var kind_weak: String = boss._hit_kind(50.0, mult_weak)
	var kind_other: String = boss._hit_kind(50.0, mult_other)
	print("BOSS_WEAKNESS hit_kind weak=%s other=%s (WEAK_MULT=%.2f RESIST_MULT=%.2f)" % [
		kind_weak, kind_other, EnemyUnit.WEAK_MULT, EnemyUnit.RESIST_MULT])
	check(kind_weak == "weak",
		"약점 타격인데 피해 숫자가 '약점' 으로 분류되지 않는다 (%s)" % kind_weak)
	check(kind_other == "normal",
		"비약점 타격이 '%s' 로 분류된다 — 이 절은 '표시가 없다' 를 전제로 한다" % kind_other)

	# ── §3 (계속) 등장 배너가 약점을 담고 있는가 ──────────────────────────────
	var banner := _find_named(field, "BossBanner")
	check(banner != null, "보스 등장 배너가 없다 — 약점의 유일한 등장 채널이 사라졌다")
	var banner_hits := _visible_texts_containing(main, "약점")
	print("BOSS_WEAKNESS at_spawn banners=%d visible_약점=%d texts=%s" % [
		_count_named(field, "BossBanner"), banner_hits.size(), str(banner_hits)])
	check(not banner_hits.is_empty(),
		"등장 배너가 떴는데 '약점' 문구가 화면에 없다 — 배너 머리말의 약속이 거짓이다")

	# ── §4 배너의 수명 — 게임시간과 실시간을 **둘 다** 잰다 ───────────────────
	# ⚠️ 트윈은 `Engine.time_scale` 을 따른다. 그래서 '게임시간' 수명은 배속과 무관하게
	#    같지만 '실시간' 수명은 4배속에서 1/4 이 된다. 두 축을 나눠 재지 않으면
	#    "2.15초" 라는 숫자가 배속에서 무엇을 뜻하는지 알 수 없다.
	#
	# 게임시간 = Σ(delta) — ⚠️ **`get_process_delta_time()` 은 이미 `time_scale` 이 곱해진
	#   값이다.** 여기에 `* Engine.time_scale` 을 또 하면 4배속에서 16배로 세어
	#   `game=8.82s` 라는 값이 나온다(첫 판이 그렇게 나왔고, 그건 내 계산 오류였다).
	# 실시간 = `Time.get_ticks_msec()` 차이.
	var game_t := 0.0
	var real_start := Time.get_ticks_msec()
	var guard := Time.get_ticks_msec() + 8000
	while _count_named(field, "BossBanner") > 0 and Time.get_ticks_msec() < guard:
		game_t += get_process_delta_time()
		await get_tree().process_frame
	var real_t := float(Time.get_ticks_msec() - real_start) / 1000.0
	print("BOSS_WEAKNESS banner_life@1x game=%.2fs real=%.2fs" % [game_t, real_t])
	check(_count_named(field, "BossBanner") == 0,
		"배너가 8초(실시간) 안에 사라지지 않았다 — 수명 가정이 틀렸다")
	check(game_t > 1.0 and game_t < 4.0,
		"배너의 게임시간 수명이 %.2fs 다 — 예상(약 2.15s) 밖이다" % game_t)

	# ── §5 ⚠️ 배너가 사라진 뒤 — 보이는 '약점' 문구가 0건인가 ─────────────────
	# 보스가 아직 살아 있어야 이 0건이 의미를 갖는다. 다 죽은 뒤라면 "화면이 비었다" 와
	# 구별되지 않는다.
	check(is_instance_valid(boss) and not boss.is_dead,
		"배너가 사라지기 전에 보스가 죽었다 — 이 실행은 전투 중을 재지 못한다")
	var after_hits := _visible_texts_containing(main, "약점")
	print("BOSS_WEAKNESS after_banner visible_약점=%d boss_alive=%s texts=%s" % [
		after_hits.size(), str(is_instance_valid(boss) and not boss.is_dead), str(after_hits)])
	# ✅ **§5.2 28 (A) 고침 (2026-10-01)** — 예전에는 이 단언이 `is_empty()` 였고 그것이
	#    **결함의 기록**이었다(*"배너가 사라지면 약점이 화면에서 증발한다"*). 이제 체력바에
	#    붙은 '약점' 행이 계속 말하므로 **뒤집는다** — 되돌리면 빨개진다.
	check(not after_hits.is_empty(),
		"배너가 사라진 뒤 '약점' 문구가 화면에서 **사라졌다**(%d건) — §5.2 28 (A) 의 체력바 행이 죽었다" % after_hits.size(), "S5")

	# ── §6 그동안 남아 있는 것 — 보스 체력바 ─────────────────────────────────
	# ✅ **§5.2 28 (A) 고침 (2026-10-01)** — 체력바에 '약점' 행이 붙어 **전투 내내** 남는다.
	#    예전 이 절은 `rows == 2` 를 단언하며 *"셋째 행이 들어갈 자리"* 라고 적어 두었다.
	#    그 자리가 채워졌으므로 단언을 **뒤집는다** — 되돌리면 빨개진다.
	var bar := _find_named(field, "BossBar")
	check(bar != null, "보스 체력바가 없다")
	if bar != null:
		var column := _find_named(bar, "BossColumn")
		var rows := column.get_child_count() if column != null else -1
		var weak_node := _find_named(bar, "BossWeak")
		var want_weak := "약점: %s" % str(MonsterRoster.BOSS_WEAKNESS_LABELS.get(
			boss.weakness_trait, boss.weakness_trait))
		print("BOSS_WEAKNESS persistent_bar visible=%s rows=%d name_text=\"%s\" weak_text=\"%s\"" % [
			str((bar as Control).is_visible_in_tree()), rows,
			(_find_named(bar, "BossName") as Label).text if _find_named(bar, "BossName") != null else "?",
			(weak_node as Label).text if weak_node != null else "?"])
		check((bar as Control).is_visible_in_tree(),
			"보스 체력바가 보이지 않는다 — 전투 내내 남는 요소가 없다", "S6")
		check(rows == 3,
			"보스 체력바 행이 %d개다 — '이름 + 체력 + 약점' 셋을 전제로 한다(§5.2 28 (A))" % rows, "S6")
		# ⚠️ 문구가 **등장 배너와 같은 출처**를 읽는가 — 다르면 화면 두 곳이 다른 말을 한다(§2.18).
		check(weak_node != null and (weak_node as Label).text == want_weak,
			"체력바의 약점 문구가 \"%s\" 가 아니다(기대 \"%s\") — 배너와 어긋나면 드리프트다" % [
				(weak_node as Label).text if weak_node != null else "(없음)", want_weak], "S6")
		# ⚠️ 행이 하나 늘면 **배너와 겹칠 수 있다.** 고치면서 가리는 것을 막는다 —
		#    약점을 보이자고 만든 행이 배너의 약점 문구를 덮으면 아무것도 못 한 것이다.
		# ⚠️ `field` 는 `var field = main.defense_field` 로 **타입 없이** 선언됐다(Variant).
		#    그래서 `:=` 로 받으면 *"Cannot infer the type … value doesn't have a set type"* 로
		#    **파스 오류**가 난다 — 그리고 파스 오류는 프로브를 **매단다**(rc=124, 무출력).
		#    실측 2026-10-01: 이 두 줄이 `--headless` 실행을 200초 타임아웃까지 끌고 갔다.
		var bar_rect: Rect2 = (bar as Control).get_global_rect()
		var field_rect: Rect2 = field.get_global_rect()
		var bar_bottom: float = bar_rect.position.y - field_rect.position.y + bar_rect.size.y
		print("BOSS_WEAKNESS layout bar_bottom=%.1f banner_top=%.1f (여유 %.1f)" % [
			bar_bottom, DefenseField.BOSS_BANNER_TOP, DefenseField.BOSS_BANNER_TOP - bar_bottom])
		check(bar_bottom <= DefenseField.BOSS_BANNER_TOP,
			"체력바(아래 %.1f)가 배너(y=%.1f)를 **가린다** — 약점 문구끼리 서로를 지운다" % [
				bar_bottom, DefenseField.BOSS_BANNER_TOP], "S6")

	# ── §4 (계속) 4배속에서 실시간 수명이 줄어드는가 ─────────────────────────
	# 같은 보스를 두 번 잴 수는 없다(배너는 등장 때 한 번뿐). 그래서 배너의 수명 계약을
	# **트윈 자체**로 확인한다: 같은 시간 파라미터(0.15 + 1.6 + 0.4)를 4배속에서 재면
	# 실시간은 1/4 이어야 한다. 이 절은 "배너가 시간축을 따른다" 만 주장한다.
	# ⚠️ 첫 판은 `while probe.modulate.a > 0.0` 으로 돌렸는데, 트윈이 **0 에서 1 로** 올리는
	#    중이라 진입 조건이 처음부터 거짓이었다 → 루프를 한 번도 안 돌아 `game=0.00s` 가 나왔고
	#    그게 실패로 찍혔다. 조건을 **트윈의 생사**(`is_running()`)로 바꾼다 —
	#    재려는 것은 알파 값이 아니라 **트윈이 시간축을 따르는가** 다.
	var probe := Label.new()
	probe.modulate.a = 0.0
	add_child(probe)
	Engine.time_scale = 4.0
	var g4 := 0.0
	var r4_start := Time.get_ticks_msec()
	var tw := probe.create_tween()
	tw.tween_property(probe, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(probe, "modulate:a", 0.0, 0.4)
	var guard4 := Time.get_ticks_msec() + 4000
	while tw.is_valid() and tw.is_running() and Time.get_ticks_msec() < guard4:
		g4 += get_process_delta_time()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	probe.queue_free()
	var r4 := float(Time.get_ticks_msec() - r4_start) / 1000.0
	print("BOSS_WEAKNESS banner_life@4x game=%.2fs real=%.2fs (게임시간의 %.0f%%)" % [
		g4, r4, 100.0 * r4 / maxf(0.001, g4)])
	check(absf(g4 - 2.15) < 0.6,
		"4배속에서 게임시간 수명이 %.2fs 다 — 같은 트윈이므로 2.15s 근처여야 한다" % g4)
	# ⚠️ 비교 대상을 **자기 자신의 게임시간**으로 잡는다. 첫 판은 배너의 실시간(`real_t`)과
	#    비교했는데, I2 주입(배너 홀드를 1.6→0.1)에서 `real_t` 자체가 작아지자 이 절도 같이
	#    실패했다 — 즉 **독립적이지 않았다**. 한 절이 다른 절의 측정값에 기대면, 그 값이
	#    변할 때 두 절이 같이 무너져 "어느 절이 무엇을 잡았는가" 가 흐려진다.
	check(r4 < g4 / 2.0,
		"4배속인데 실시간 수명(%.2fs)이 게임시간(%.2fs)의 절반 이상이다 — 트윈이 시간축을 따르지 않는다" % [r4, g4])

	if failures == 0:
		print("BOSS_WEAKNESS_PROBE_OK")
	get_tree().quit(failures)
