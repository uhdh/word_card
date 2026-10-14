extends Node
# 배너의 **위치 계약**을 잰다 — 어디에 뜨기로 약속했는가.
#
# 왜 문제인가:
#   `JamoBelt._celebrate_new_words()` 의 문서 주석이 계약을 이렇게 적어 두었다(`:1314`):
#
#       ## 새로 완성된 단어를 화면 중앙에 잠깐 띄워 보여준다.
#
#   그런데 배치는 이렇다(`:1345-1348`):
#
#       banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
#       banner.position += Vector2(-180.0, 64.0)
#
#   `PRESET_CENTER_TOP` 은 **이미** 가로 중앙 정렬을 한다. 그 위에 `+=` 로 -180 을 또 더하면
#   **중심이 화면 중앙에서 왼쪽으로 밀린다**(실측 93.5px). 문서는 '중앙' 이라 약속했는데
#   코드는 왼쪽에 세운다 — 설명이 계약인 게임에서 이건 결함이다.
#
#   게다가 `:1340` 의 주석은 "보스 배너와 같은 관례를 쓴다" 고 적었는데, 실제로는 다르다:
#   보스 배너는 `position = Vector2(-160.0, 54.0)` — `=` 로 **앵커 기준 절대값**을 준다
#   (`160 = size.x/2`). 그래서 보스 배너만 정확히 중앙이다(실측 0.0px).
#
# ⚠️ 감사 문서의 주장은 **가설**이다 — 재는 것:
#   §0 전제 — 두 배너를 같은 좌표계에서 재고 있는가 (아니면 아래 수치는 무의미하다)
#   §1 단어 완성 배너가 실제로 떴는가 (비공허성)
#   §2 그 배너의 **중심이 화면 중앙**인가  ← 문서가 약속한 것
#   §3 보스 배너도 중앙인가 (비교 기준 — 이게 중앙이면 §2 의 어긋남은 단어 배너 고유의 산수다)
#   §4 두 배너가 **겹치는가**  ← 감사 §2.5 의 주장
#   §5 **단어가 길어져도** 중앙인가 (짧은 단어만 재면 폭 고정이 숨는다)
#
# 실행: godot --headless --path . res://tools/BannerLayoutProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 배너 중심이 화면 중심에서 이만큼까지 벗어나면 '중앙' 이라고 부르지 않는다.
## 93.5px 를 잡으려는 값이지, 픽셀 정밀도를 요구하는 값이 아니다.
const MAX_CENTER_OFFSET := 12.0
## 적 스폰을 기다리는 상한(ms).
const SPAWN_DEADLINE_MS := 3000
## 등장 연출(페이드·팝)이 끝나기를 기다리는 시간(초).
## ⚠️ 연출 도중에 재면 안 된다 — `get_global_rect()` 는 **scale 을 반영**하므로
##   '레이아웃' 이 아니라 '지금 얼마나 커 보이는가' 를 재게 된다.
const SETTLE_SEC := 0.45

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _new_children(parent: Node, before: Array) -> Array:
	var out: Array = []
	for c in parent.get_children():
		if not before.has(c):
			out.append(c)
	return out

func _center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

## 실제 함수(`_celebrate_new_words`)로 배너를 만들고, **새로 생긴 Label** 을 돌려준다.
## ⚠️ 문구로 찾지 않는다 — 그러면 프로브에 기대 문구의 사본이 하나 더 생긴다.
##   자식 집합의 차이로 찾으면 문구를 바꿔도 프로브가 따라간다.
func _make_word_banner(host: Node, belt, words: Array[String]) -> Control:
	var before: Array = host.get_children()
	belt._celebrate_new_words(words)
	var found: Array = []
	for c in _new_children(host, before):
		if c is Label:
			found.append(c)
	check(found.size() == 1,
		"새로 생긴 Label 이 %d개다(1개여야 한다) — 무엇을 재는지 알 수 없다" % found.size())
	if found.size() != 1:
		return null
	return found[0]

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
	await get_tree().process_frame

	var vp: Rect2 = get_viewport().get_visible_rect()
	var vp_center: Vector2 = vp.get_center()

	# ── 0. 전제 — 같은 좌표계에서 재고 있는가 ───────────────────────────────
	# 단어 배너는 `get_tree().current_scene` 에 붙는다. 이 프로브에서는 그게 프로브 루트
	# (평범한 Node)이고, 실제 게임에서는 `TowerDefenseMain`(Control)이다.
	# 둘의 좌표계가 같으려면 **TowerDefenseMain 이 뷰포트를 꽉 채워야** 한다.
	# (Control 의 앵커는 Control 부모의 rect 를, Control 아닌 부모에서는 뷰포트를 쓴다)
	check(main is Control, "TowerDefenseMain 이 Control 이 아니다 — 좌표계 전제가 틀렸다")
	check(main.global_position == Vector2.ZERO,
		"TowerDefenseMain 의 원점이 %s 다 — 화면 기준으로 잰 값이 게임과 어긋난다" % main.global_position)
	check(main.size == vp.size,
		"TowerDefenseMain 이 %s 인데 뷰포트는 %s 다 — 두 좌표계가 다르다" % [main.size, vp.size])

	var belt = main.jamo_belt
	var field = main.defense_field
	check(belt != null, "jamo_belt 가 없다 — 단어 완성 배너를 만들 수 없다")
	check(field != null, "defense_field 가 없다 — 보스 배너를 만들 수 없다")
	if belt == null or field == null:
		get_tree().quit(failures)
		return

	# ── 보스 배너를 먼저 띄운다(두 배너를 동시에 재야 §4 가 성립한다) ─────────
	# ⚠️ `EnemyUnit.new()` 로 만든 적은 못 쓴다 — 실제 경로로 띄운 **진짜 적**을 쓴다.
	# ⚠️ `_juice_boss_entrance()` 가 아니라 `_show_boss_banner()` 를 부른다.
	#   전자는 흔들림까지 일으켜 필드를 움직이므로 **배너의 좌표가 흔들림만큼 오염된다**.
	#   배너 자체의 배치는 후자가 만든다 — 재려는 것은 그 배치다.
	field.start_next_wave()
	var deadline := Time.get_ticks_msec() + SPAWN_DEADLINE_MS
	while field.get_enemies().is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var enemies: Array = field.get_enemies()
	check(not enemies.is_empty(), "적이 스폰되지 않았다 — 보스 배너를 잴 수 없다")
	if enemies.is_empty():
		get_tree().quit(failures)
		return
	field.is_wave_running = false
	await get_tree().process_frame
	await get_tree().process_frame
	field._show_boss_banner(enemies[0])
	# 보스 **체력바** 도 함께 띄운다 — 배너보다 오래 살아 있는(보스가 죽을 때까지) 상단 UI 라
	# 겹침을 따질 대상이 배너만이 아니다.
	field._attach_boss_bar(enemies[0])

	var host: Node = get_tree().current_scene
	var words: Array[String] = ["가나다"]
	var word_banner := _make_word_banner(host, belt, words)
	if word_banner == null:
		get_tree().quit(failures)
		return
	# 등장 연출이 끝난 뒤에 잰다(그 전에는 scale 이 rect 에 섞인다).
	await get_tree().create_timer(SETTLE_SEC).timeout

	var boss_banner: Control = field.get_node_or_null("BossBanner")
	check(boss_banner != null, "BossBanner 가 없다 — 보스 배너를 잴 수 없다")
	if boss_banner == null:
		get_tree().quit(failures)
		return

	# ── 1. 단어 배너가 실제로 떴는가 ────────────────────────────────────────
	check(word_banner.is_visible_in_tree(), "단어 완성 배너가 보이지 않는다")
	check(word_banner.size.x > 0.0 and word_banner.size.y > 0.0,
		"단어 완성 배너의 크기가 %s 다 — 0 크기는 '겹치지 않는다' 를 공짜로 통과시킨다" % word_banner.size)
	check(boss_banner.is_visible_in_tree(), "보스 배너가 보이지 않는다")
	check(boss_banner.size.x > 0.0 and boss_banner.size.y > 0.0,
		"보스 배너의 크기가 %s 다" % boss_banner.size)

	var word_rect: Rect2 = word_banner.get_global_rect()
	var boss_rect: Rect2 = boss_banner.get_global_rect()
	# 상단 띠에 무엇이 얼마나 차 있는지 — '겹치지 않게 두려면 어디로 가야 하는가' 의 근거.
	print("BANNER ctx field=%s telegraph=%s belt=%s"
		% [main.get_node("VBox/FieldContainer").get_global_rect(),
			main.get_node("VBox/TelegraphBar").get_global_rect(),
			belt.get_global_rect()])
	print("BANNER word_rect=%s center=%s scale=%s | boss_rect=%s center=%s scale=%s | vp_center=%s"
		% [word_rect, _center_of(word_banner), word_banner.scale,
			boss_rect, _center_of(boss_banner), boss_banner.scale, vp_center])

	# ── 2. 단어 완성 배너의 중심이 화면 중앙인가 (문서가 약속한 것) ────────────
	var word_off: float = absf(_center_of(word_banner).x - vp_center.x)
	print("BANNER word_center_offset_x=%.1f (<=%.1f 이어야 한다)" % [word_off, MAX_CENTER_OFFSET])
	check(word_off <= MAX_CENTER_OFFSET,
		"단어 완성 배너의 중심이 화면 중앙에서 %.1fpx 벗어났다 — 주석은 '화면 중앙' 이라 약속했다"
		% word_off)

	# ── 2b. 글자 자체가 가운데인가 (사각형만 보면 이걸 놓친다) ───────────────
	# ⚠️ 폭을 화면 전체로 잡았으므로 **사각형 중심은 정렬과 무관하게 항상 화면 중앙**이다.
	#   그래서 §2 만으로는 `horizontal_alignment` 가 LEFT 로 바뀌어도 통과한다 —
	#   정렬 속성을 함께 단언해야 '글자가 가운데' 가 지켜진다.
	#   (헤드리스라 픽셀을 못 보므로 이 둘의 조합이 텍스트 위치의 계약이다)
	check(word_banner.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"배너 정렬이 %d 다(CENTER=%d 여야 한다) — 사각형은 화면 폭이라 중심이 항상 중앙이고 글자만 왼쪽으로 간다"
		% [word_banner.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER])

	# ── 3. 보스 배너도 중앙인가 (비교 기준) ─────────────────────────────────
	# 이쪽이 중앙이면 §2 의 어긋남은 '전역 관례' 가 아니라 단어 배너 고유의 산수 문제다.
	var boss_off: float = absf(_center_of(boss_banner).x - vp_center.x)
	print("BANNER boss_center_offset_x=%.1f" % boss_off)
	check(boss_off <= MAX_CENTER_OFFSET,
		"보스 배너의 중심이 화면 중앙에서 %.1fpx 벗어났다 — 두 배너의 기준이 서로 다르다" % boss_off)

	# ── 4. 보스 UI 와 겹치는가 (감사 §2.5 의 주장) ───────────────────────────
	# 감사: "보스 라운드에서 단어를 완성하면 두 배너가 겹친다".
	# ⚠️ 그런데 상단에는 배너만 있는 게 아니다 — 보스 **체력바**(`_attach_boss_bar`)는
	#   보스가 사는 동안 **계속** 떠 있다. 배너는 1.2초짜리지만 체력바는 상시라
	#   겹치면 더 나쁘다. 그래서 둘 다 잰다.
	print("BANNER word_y=%.1f..%.1f boss_banner_y=%.1f..%.1f overlap_banner=%s"
		% [word_rect.position.y, word_rect.end.y, boss_rect.position.y, boss_rect.end.y,
			str(word_rect.intersects(boss_rect))])
	check(not word_rect.intersects(boss_rect),
		"단어 배너가 보스 배너와 겹친다 (단어 %s / 보스 %s) — 보스 라운드에서 단어를 완성하면 서로를 가린다"
		% [word_rect, boss_rect])

	var bar: Control = field.get_node_or_null("BossBar")
	check(bar != null, "BossBar 가 없다 — 보스 체력바와의 겹침을 잴 수 없다")
	if bar != null:
		var bar_rect: Rect2 = bar.get_global_rect()
		check(bar_rect.size.x > 0.0 and bar_rect.size.y > 0.0,
			"보스 체력바의 크기가 %s 다" % bar_rect.size)
		print("BANNER boss_bar_rect=%s | overlap_with_word=%s"
			% [bar_rect, str(word_rect.intersects(bar_rect))])
		# ⚠️ 여기는 **단언하지 않는다**. 상단 띠(58~118)가 이미 꽉 차 있어(상단 바 0~58 ·
		#   보스 체력바 76~118 · 보스 배너 128~170) '아무것도 안 겹치는 y' 가 없다.
		#   그래서 y 를 어디로 둘지는 **설계 판단**이고, 프로브는 근거가 될 수치만 남긴다.
		#   (y=64 를 유지하면 이 겹침은 남는다 — 감독 결정 대기 항목)
		if word_rect.intersects(bar_rect):
			var ov: Rect2 = word_rect.intersection(bar_rect)
			print("BANNER OPEN_ITEM 단어 배너가 보스 체력바를 세로 %.1fpx 덮는다 (겹침 %s) — y 위치는 감독 결정 대기"
				% [ov.size.y, ov])
		else:
			print("BANNER 보스 체력바와 겹치지 않는다")

	# ── 5. 단어가 길어져도 중앙인가 ─────────────────────────────────────────
	# ⚠️ 짧은 단어만 재면 '폭을 360 으로 고정' 한 구현이 숨는다. 실제로는 한 번에
	#   여러 단어가 완성될 수 있고, 그러면 글자가 360px 를 넘어 라벨이 **자란다**.
	#   자라는 방향이 한쪽이면 중심이 그쪽으로 밀린다 — 그래서 길이를 바꿔 다시 잰다.
	var long_words: Array[String] = ["가나다", "라마바", "사아자"]
	var long_banner := _make_word_banner(host, belt, long_words)
	if long_banner == null:
		get_tree().quit(failures)
		return
	await get_tree().create_timer(SETTLE_SEC).timeout
	check(long_banner.is_visible_in_tree(), "긴 단어 배너가 보이지 않는다")
	var long_off: float = absf(_center_of(long_banner).x - vp_center.x)
	print("BANNER long_rect=%s size=%s long_center_offset_x=%.1f (<=%.1f 이어야 한다)"
		% [long_banner.get_global_rect(), long_banner.size, long_off, MAX_CENTER_OFFSET])
	check(long_off <= MAX_CENTER_OFFSET,
		"단어가 길어지면 중심이 %.1fpx 벗어난다 — 폭이 고정이 아니라 글자 길이를 따라가서다"
		% long_off)

	# ── 6. 팝이 **중심**에서 자라는가 (pivot 계약) ──────────────────────────
	# 배너 주석이 요구를 적어 두었다: "pivot 은 레이아웃 뒤에 확정된다. 지금 size 가 0 이면
	# (0,0) 이 되어 BACK_OUT 팝이 가운데가 아니라 좌상단에서 자란다."
	# scale 은 pivot 을 중심으로 커지므로, pivot 이 노드 중심이 아니면 한쪽 구석에서 자란다.
	var want_pivot: Vector2 = word_banner.size * 0.5
	print("BANNER word_pivot=%s want=%s" % [word_banner.pivot_offset, want_pivot])
	check(word_banner.pivot_offset.is_equal_approx(want_pivot),
		"배너의 pivot 이 %s 인데 중심은 %s 다 — 팝이 중심이 아니라 구석에서 자란다"
		% [word_banner.pivot_offset, want_pivot])

	if failures == 0:
		print("BANNER_LAYOUT_PROBE_OK")
	get_tree().quit(failures)
