extends Node
# 붉은 섬광의 **계약**을 잰다 — 두 진입점(기지 피격 · 보스 등장)이 같은 모양을 쓰는가.
#
# 왜 문제인가:
#   같은 코드가 두 곳에 **복사**돼 있고 숫자만 다르다.
#     보스 등장 `DefenseField._juice_boss_entrance` → 0.22 / 0.12 / 0.5
#     기지 피격 `DefenseField._juice_base_hit`    → 0.18 / 0.08 / 0.28
#   복사본이 둘이면 한쪽만 고쳐도 다른 쪽은 옛 모양으로 남는다 — 이 프로젝트가 §2.4-a(흔들림)와
#   §2.10-c(사유 문구)에서 이미 두 번 밟은 함정이다. (감사 §5.2 15)
#
# ⚠️ **2026-10-03 §2.11-a 고침 — 계약이 하나 늘었다.**
#   예전 주석은 "**전체 화면** 붉은 비네트" 라고 적었는데, 플래시가 `self`(DefenseField)의
#   자식이라 **필드(화면의 48.3%)만** 덮었다. 이제 `_flash_screen_node()` 가 화면 크기 노드를
#   찾아 넘기고, 이 도구가 **그 비율을 단언한다**(§7). 고치기 전 값은 48.3% 였다.
#   ⚠️ 그래서 섬광은 이제 **필드의 자식이 아니다** — 트리 전체에서 찾아야 한다(아래 `_sample_flash`).
#
# 재는 것:
#   §0 전제 — 필드·뷰포트 크기를 알 수 있는가
#   §1 기지 피격: 플래시가 **정확히 1개** 생기고, 보이며, 크기가 0 이 아니다 (비공허성)
#   §2 기지 피격: 최대 불투명도 = 0.18
#   §3 기지 피격: 총 수명 = 0.08 + 0.28 = 0.36초
#   §4 끝나면 **사라진다** (누수 없음)
#   §5 마우스를 먹지 않는다 (`MOUSE_FILTER_IGNORE`)
#   §6 보스 등장: 같은 항목이 0.22 / 0.62초인가 (두 진입점이 같은 모양인가)
#   §7 **무엇을 덮는가 — 화면 전체여야 한다** (고치기 전 48.3%)
#
# ⚠️ 수명은 **게임 시간 누적**(`get_process_delta_time()`)으로 잰다. 트윈도 그 delta 로
#   진행하므로 이게 맞는 자다. 프레임 수로 재면 안 된다 — 헤드리스는 프레임이 아주 짧다.
#
# 실행: godot --headless --path . res://tools/FlashProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

# ── 계약: 두 사건의 '맛' 수치. 코드가 아니라 **여기가 원본**이다(감사 §2.5/§2.4 표). ──
const BASE_HIT_PEAK := 0.18
const BASE_HIT_FADE_IN := 0.08
const BASE_HIT_FADE_OUT := 0.28
const BOSS_PEAK := 0.22
const BOSS_FADE_IN := 0.12
const BOSS_FADE_OUT := 0.5

## 트윈은 프레임마다 목표로 다가가므로 마지막 프레임은 목표에 못 닿을 수 있다. 여유를 둔다.
const PEAK_TOL := 0.01
## 수명은 프레임 경계에서 재므로 한 프레임만큼 짧게 나온다.
const LIFE_TOL := 0.08
## 섬광 추적 상한. 가장 긴 섬광이 0.62초 ≈ 38프레임(60fps)이므로 600프레임(약 10초)이면 넉넉하다.
## ⚠️ 이 값을 크게 잡으면 '안 사라지는' 주입(§4 누수)에서 프로브가 10초×2 를 매달린다.
const MAX_FRAMES := 600
const SPAWN_DEADLINE_MS := 3000
## 화면을 덮었다고 인정할 하한. 레터박스·반올림 여유를 조금 둔다.
const COVER_MIN := 0.95

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 트리 전체의 `ColorRect` 를 모은다.
func _collect_color_rects(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is ColorRect:
			out.append(c)
		_collect_color_rects(c, out)

## 진입점을 한 번 호출하고, 생긴 붉은 섬광을 죽을 때까지 따라가며 잰다.
##
## ⚠️ 예전에는 `field.get_children()` 만 봤다. §2.11-a 고침으로 섬광의 부모가 필드에서
##   **화면 크기 노드**로 바뀌어서, 필드만 보면 "섬광이 생기지 않았다" 는 **거짓 실패**가 난다.
## ⚠️ 그래서 **트리 전체**를 훑고, 새로 생긴 것 중 **가장 큰** 것을 고른다 — 섬광은 화면을
##   덮으므로 같은 순간에 생기는 다른 Control(배너·체력바)보다 크다.
func _sample_flash(root: Node, trigger: Callable) -> Dictionary:
	var before: Array = []
	_collect_color_rects(root, before)
	trigger.call()
	var after: Array = []
	_collect_color_rects(root, after)

	var flash: ColorRect = null
	var best_area := -1.0
	var fresh := 0
	for c in after:
		if before.has(c):
			continue
		fresh += 1
		var a: float = (c as ColorRect).size.x * (c as ColorRect).size.y
		if a > best_area:
			best_area = a
			flash = c
	if flash == null:
		return {"found": false, "new_controls": fresh}

	var rect: Rect2 = flash.get_global_rect()
	var mouse: int = flash.mouse_filter
	var peak := 0.0
	var elapsed := 0.0
	var frames := 0
	while frames < MAX_FRAMES:
		await get_tree().process_frame
		if not is_instance_valid(flash):
			break
		peak = maxf(peak, flash.color.a)
		elapsed += get_process_delta_time()
		frames += 1
	return {
		"found": true,
		"new_controls": fresh,
		"peak": peak,
		"elapsed": elapsed,
		"frames": frames,
		"rect": rect,
		"mouse": mouse,
		"freed": not is_instance_valid(flash),
	}

## 한 진입점의 측정값을 계약과 비교한다.
func _judge(tag: String, r: Dictionary, peak: float, fade_in: float, fade_out: float) -> void:
	if not r.get("found", false):
		check(false, "%s: 붉은 섬광(ColorRect)이 생기지 않았다 — 새 Control %d개"
			% [tag, r.get("new_controls", 0)])
		return
	var want_life := fade_in + fade_out
	print("FLASH %s rect=%s mouse=%d peak=%.4f (want %.2f) life=%.3fs (want %.2fs) frames=%d freed=%s"
		% [tag, r["rect"], r["mouse"], r["peak"], peak, r["elapsed"], want_life, r["frames"], r["freed"]])

	# §1 비공허성 — 크기 0 이면 '겹치지 않는다' 같은 것이 공짜로 통과한다.
	check((r["rect"] as Rect2).size.x > 0.0 and (r["rect"] as Rect2).size.y > 0.0,
		"%s: 섬광의 크기가 %s 다" % [tag, r["rect"]])

	# §2 최대 불투명도
	check(absf(r["peak"] - peak) <= PEAK_TOL,
		"%s: 최대 불투명도가 %.4f 다(%.2f 여야 한다) — 세기가 계약과 다르다"
		% [tag, r["peak"], peak])

	# §3 총 수명
	check(absf(r["elapsed"] - want_life) <= LIFE_TOL,
		"%s: 수명이 %.3f초 다(%.2f초 여야 한다) — 길이가 계약과 다르다"
		% [tag, r["elapsed"], want_life])

	# §4 누수 없음 — 끝나면 반드시 사라져야 한다.
	check(r["freed"], "%s: 섬광이 끝난 뒤에도 살아 있다 — 매 피격마다 쌓인다" % tag)

	# §5 마우스를 먹지 않는다 — 화면을 덮는 판이라 클릭을 가로채면 조작이 죽는다.
	check(r["mouse"] == Control.MOUSE_FILTER_IGNORE,
		"%s: mouse_filter 가 %d 다(IGNORE=%d 여야 한다) — 전체를 덮는 판이 클릭을 먹는다"
		% [tag, r["mouse"], Control.MOUSE_FILTER_IGNORE])

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

	var field = main.defense_field
	check(field != null, "defense_field 가 없다 — 잴 대상이 없다")
	if field == null:
		get_tree().quit(failures)
		return

	var vp: Rect2 = get_viewport().get_visible_rect()
	var field_rect: Rect2 = field.get_global_rect()
	var field_area := field_rect.size.x * field_rect.size.y
	var vp_area := vp.size.x * vp.size.y

	# ── §0 전제 ────────────────────────────────────────────────────────────
	check(field_area > 0.0 and vp_area > 0.0, "필드나 뷰포트의 넓이가 0 이다 — 비율을 못 잰다")
	print("FLASH ctx field=%s (%.1f%%) viewport=%s"
		% [field_rect, 100.0 * field_area / maxf(1.0, vp_area), vp])

	# ── 1~5. 기지 피격 ─────────────────────────────────────────────────────
	# ⚠️ 탐색 뿌리는 `main`(트리 전체)이다 — 섬광이 이제 필드의 자식이 아니다.
	var base := await _sample_flash(main, func(): field._juice_base_hit())
	_judge("base_hit", base, BASE_HIT_PEAK, BASE_HIT_FADE_IN, BASE_HIT_FADE_OUT)

	# 흔들림(0.26+0.06)이 끝나기를 기다린다 — 다음 진입점을 깨끗한 상태에서 재려고.
	await get_tree().create_timer(0.4).timeout

	# ── 6. 보스 등장 ───────────────────────────────────────────────────────
	# ⚠️ `EnemyUnit.new()` 로 만든 적은 못 쓴다 — 실제 경로로 띄운 진짜 적을 쓴다.
	field.start_next_wave()
	var deadline := Time.get_ticks_msec() + SPAWN_DEADLINE_MS
	while field.get_enemies().is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var enemies: Array = field.get_enemies()
	check(not enemies.is_empty(), "적이 스폰되지 않았다 — 보스 등장 섬광을 잴 수 없다")
	if not enemies.is_empty():
		var real_enemy = enemies[0]
		field.is_wave_running = false
		await get_tree().process_frame
		var boss := await _sample_flash(main, func(): field._juice_boss_entrance(real_enemy))
		_judge("boss_entrance", boss, BOSS_PEAK, BOSS_FADE_IN, BOSS_FADE_OUT)

	# ── 7. 무엇을 덮는가 — **이제 단언한다**(§2.11-a) ────────────────────────
	# 고치기 전: 필드를 부모로 넘겨 **화면의 48.3%** 만 덮었고, 주석은 "전체 화면" 이라 적었다.
	# 고친 뒤: 화면 크기 노드를 넘겨 **화면 전체**를 덮는다. 그 비율이 계약이다.
	if base.get("found", false):
		var r: Rect2 = base["rect"]
		var covered := (r.size.x * r.size.y) / maxf(1.0, vp_area)
		print("FLASH COVER 섬광이 화면의 %.1f%% 를 덮는다 (필드는 %.1f%%) · 단색 판이지 비네트가 아니다"
			% [100.0 * covered, 100.0 * field_area / maxf(1.0, vp_area)])
		check(covered >= COVER_MIN,
			"섬광이 화면의 %.1f%% 만 덮는다 — 부분 노드를 부모로 넘기고 있다(§2.11-a)"
			% (100.0 * covered))

	if failures == 0:
		print("FLASH_PROBE_OK")
	get_tree().quit(failures)
