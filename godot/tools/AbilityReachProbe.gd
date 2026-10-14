extends Node
# 밀어내기 버튼이 **도달 가능한가**, 그리고 **왜 막혔는지 말하는가**.
# (감사 §2.40 신설, 2026-10-06)
#
# ── 왜 문제인가 (두 겹이다) ───────────────────────────────────────────────
#
# (1) **재충전이 버튼에 도달하지 않는다.**
#     `_refresh_ability_button()` 은 버튼의 `disabled`·`text` 를 정하는 **유일한 곳**이다.
#     호출처는 넷뿐이다 — 새 게임(`:1451`) · 불러오기(`:479`) · 능력 사용(`:1177`) ·
#     버튼 누름(`:1191`). **웨이브 시작/종료가 없다.**
#     웨이브 상태는 `_on_wave_status_changed()`(`:755`)로 오는데, 거기서는
#     `ability_uses_left` 를 채우고 **벨트에게만** 알린다(`:763`) — 버튼은 안 고친다.
#     새 게임 직후 버튼은 `is_wave_running == false` 로 계산되어 **disabled** 이고,
#     그 뒤 웨이브가 시작돼도 다시 계산되지 않는다. 즉 **화면에서 능력을 쓸 수 없다.**
#
#     ⚠️ 왜 아무도 못 봤나 — 이 결함을 잡을 수 있는 자동 플레이어가 **없다**:
#       · 봇 스크립트(`scripts/test/AutoPlayBot.gd`)에 `ability` 참조가 **0건**이라 이 버튼을
#         **누르지 않는다**. ⚠️ 예전엔 여기 *"`AutoPlayTDTest` 씬에는 `BtnAbility` 노드가 아예
#         없다"* 고 적혀 있었는데 **거짓이다**(2026-10-06 실측 — 씬에 **있다** · `:127` 주석도 같은
#         거짓을 말하고 있었다). 그 거짓이 *"봇 씬은 확인할 필요 없다"* 는 판단을 만들었다.
#       · `PauseAbilityProbe` 는 `_on_tile_ability_requested()` 를 **직접** 부른다
#         → 버튼의 `disabled` 를 거치지 않는다.
#       둘 다 "로직은 옳다" 를 확인하지만, **플레이어가 거기 도달하는지**는 안 잰다.
#
# (2) **막힌 사유를 말하지 않는다.**
#     이 프로젝트는 규칙을 이미 세웠다 — `disabled` 는 bool 하나라 이유가 사라지므로
#     막힌 사유를 **툴팁**에 적는다(`_with_reason`). 벨트 4버튼(`BeltBlockReasonProbe`)과
#     상점 2버튼(`ShopReasonProbe`)이 그 규칙을 따르고, 두 헤더가 이유까지 적어 두었다:
#       "두 화면이 같은 규칙을 써야 플레이어가 '막힌 이유는 툴팁에 있다' 를 한 번만 배운다."
#     **밀어내기 버튼은 세 번째 화면인데 규칙 밖이다.** 툴팁은 씬에 박힌 한 문장
#     (`TowerDefenseMain.tscn` `BtnAbility.tooltip_text`)이고 **코드가 한 번도 고치지 않는다.**
#     그런데 이 버튼은 서로 다른 **세** 이유로 막힌다:
#       (a) 이미 이번 웨이브에 썼다   → `ability_uses_left <= 0`
#       (b) 웨이브 중이 아니다        → `not is_wave_running`
#       (c) 밀어낼 타일이 없다        → `jamo_list.is_empty()`
#     (a) 는 이 능력의 **설계 그 자체**다(자모 1장을 영구히 태워 웨이브당 한 번).
#     다 쓴 뒤의 회색 버튼은 그래서 **가장 설명이 필요한** 순간인데, 셋 다 같은 문장을 말한다.
#
# ⚠️ 이 도구가 재는 것 (한쪽만 재면 반쪽짜리다):
#   §0 전제 — 버튼이 있고, 새 게임이 실제로 돌고, 벨트가 비어 있지 않다
#   §1 재충전 도달 — 웨이브가 시작되면 버튼이 **눌릴 수 있어야** 한다  ← 판정
#   §2 두 표면의 불일치 — 벨트는 '쓸 수 있다' 고 아는데 버튼은 막혀 있는가 (보고 + 판정)
#   §3 양성 대조 — `_refresh_ability_button()` 한 번이면 켜지는가 (누락이 전부임을 증명)
#   §4 사유 도달 — 사유가 서로 다른 상태에서 툴팁이 **달라지는가**  ← 판정
#   §5 양성 대조 — 벨트 구매 버튼은 사유가 바뀌면 툴팁이 바뀐다 (기구가 살아 있다)
#   §6 보고 — 잔여 횟수가 **글자**에 있는가, 네 상태의 (disabled·text·tooltip) 전문
#
# ⚠️ 단언하는 것은 "쓸 수 있어야 한다" 와 "사유가 다르면 말도 달라야 한다" 이지
#   "어떤 문구여야 한다" 가 아니다. 문구 선택은 감독 몫이다.
#
# ⚠️ 헤드리스로 재는 것은 **버튼의 상태**이지 '실제 클릭이 먹는가' 가 아니다.
#   다만 Godot 의 Button 은 `disabled` 면 실제 입력에 `pressed` 를 내지 않으므로,
#   `disabled == true` 는 곧 '플레이어가 누를 수 없다' 이다.
#
# 실행: godot --headless --path . res://tools/AbilityReachProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 사유 문구의 표식 — `BeltBlockReasonProbe` 와 같은 규칙을 쓴다.
const MARK := "⚠️"

## 스크린샷 경로. `disabled` 가 **화면에서** 회색 버튼인지 눈으로 남긴다.
const SHOT_FULL := "E:/project/word_card/tmp/abilityreach.png"
const SHOT_CROP := "E:/project/word_card/tmp/abilityreach_crop.png"
const SHOT_CROP_ON := "E:/project/word_card/tmp/abilityreach_crop_on.png"

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _snap(main) -> Dictionary:
	var b: Button = main.btn_ability
	return {
		"disabled": b.disabled,
		"text": b.text,
		"tooltip": str(b.tooltip_text),
	}


## 상태 하나를 세우고 버튼을 갱신한다. **진짜 문**만 쓴다 —
## `_refresh_ability_button()` 은 이 버튼의 상태를 정하는 유일한 곳이므로,
## 여기서 그 문을 직접 부르는 것은 '플레이어가 도달했을 때의 화면' 을 만드는 일이다.
func _state(main, running: bool, uses: int, tiles: Array) -> Dictionary:
	main.defense_field.is_wave_running = running
	main.ability_uses_left = uses
	main.jamo_belt.jamo_list.assign(tiles)
	main._refresh_ability_button()
	return _snap(main)


func _ready() -> void:
	print("")
	print("=== 밀어내기 버튼: 도달 가능성 · 사유 도달 ===")
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true

	var belt = main.jamo_belt

	# ── §0 전제 ─────────────────────────────────────────────────────────────
	if main.btn_ability == null:
		check(false, "§0 BtnAbility 노드가 없다 — 이 프로브의 전제가 성립하지 않는다")
		print("ABILITY_REACH_PROBE_FAIL %d" % failures)
		return
	check(str(main.btn_ability.tooltip_text) != "",
		"§0 툴팁이 비어 있다 — '달라지는가' 를 잴 수 없다")
	check(belt.jamo_list.size() > 0, "§0 시작 벨트가 비어 있다")
	print("ABILITY_REACH_PROBE s0 booted running=%s uses=%d belt=%d btn.disabled=%s" % [
		main.defense_field.is_wave_running, main.ability_uses_left,
		belt.jamo_list.size(), main.btn_ability.disabled])

	# ── §1 재충전이 버튼에 도달하는가 ───────────────────────────────────────
	# 새 게임 직후의 상태를 적어 두고, **진짜 문**(웨이브 시작)으로 웨이브를 연다.
	var before: Dictionary = _snap(main)
	print("ABILITY_REACH_PROBE s1 before_wave disabled=%s text='%s'" % [before["disabled"], before["text"]])

	main._on_start_wave_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	var running: bool = main.defense_field.is_wave_running
	var uses: int = main.ability_uses_left
	var after: Dictionary = _snap(main)
	print("ABILITY_REACH_PROBE s1 after_wave running=%s uses=%d belt_available=%s btn.disabled=%s belt_tiles=%d" % [
		running, uses, belt.ability_available, after["disabled"], belt.jamo_list.size()])

	check(running, "§1 웨이브가 시작되지 않았다 — 아래 판정이 성립하지 않는다")
	check(uses > 0, "§1 웨이브 시작 후 잔여 횟수가 %d 다 (재충전되지 않았다)" % uses)
	check(belt.jamo_list.size() > 0, "§1 시작 벨트가 비어 있다")

	# 판정 — 쓸 수 있는 조건이 전부 참인데 버튼이 막혀 있으면, 플레이어는 도달할 수 없다.
	check(not after["disabled"],
		"§1 웨이브가 돌고 있고(잔여 %d회·타일 %d장) 벨트는 '쓸 수 있다'(%s)고 아는데, 버튼은 **disabled** 다 — 플레이어가 능력을 쓸 수 없다. `_on_wave_status_changed()` 가 `jamo_belt.set_ability_available()` 만 부르고 `_refresh_ability_button()` 을 부르지 않는다" % [
			uses, belt.jamo_list.size(), belt.ability_available])

	# ── §2 두 표면의 불일치 (보고) ──────────────────────────────────────────
	var mismatch: bool = belt.ability_available and after["disabled"]
	print("ABILITY_REACH_PROBE s2 belt_available=%s btn_disabled=%s mismatch=%s" % [
		belt.ability_available, after["disabled"], mismatch])
	check(not mismatch,
		"§2 같은 사실을 두 표면이 다르게 말한다 — 벨트 `ability_available=%s` 인데 버튼 `disabled=%s`" % [
			belt.ability_available, after["disabled"]])

	# ── §2b 스크린샷: 플레이어가 보는 것 (결함이 만드는 상태 그대로) ──────────
	# ⚠️ 여기서 `_state()` 나 `_refresh_ability_button()` 을 부르면 **고쳐진** 화면이 찍힌다.
	#    첫 판이 정확히 그렇게 새서 두 그림이 **바이트까지 같았다**(md5 동일) — 캡처가
	#    틀린 것이 아니라, 두 번 다 '켜진' 버튼을 찍고 있었다. 그래서 지금은
	#    **아무것도 만지지 않고** 방금 잰 그 상태를 그대로 찍는다.
	if DisplayServer.get_name() != "headless":
		check(main.btn_ability.disabled,
			"§2b 찍으려는 순간 버튼이 disabled 가 아니다 — 결함 상태를 찍지 못한다")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var crop: Image = null
		if img != null:
			img.save_png(SHOT_FULL)
			var r: Rect2i = Rect2i(main.btn_ability.get_global_rect()).grow(18)
			r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			if r.size.x > 0 and r.size.y > 0:
				crop = img.get_region(r)
				crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
				crop.save_png(SHOT_CROP)
				print("ABILITY_REACH_PROBE s2b shot=%s crop=%s btn_rect=%s disabled=%s" % [
					SHOT_FULL, SHOT_CROP, str(main.btn_ability.get_global_rect()), main.btn_ability.disabled])
		# 대조 — 누락된 호출 **하나**를 채운 뒤 같은 자리를 다시 찍는다.
		# 두 그림이 같으면 `disabled` 는 화면에 **아무 흔적도 남기지 않는다**(그것도 결함이다).
		main._refresh_ability_button()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := get_viewport().get_texture().get_image()
		if img2 != null:
			var r2: Rect2i = Rect2i(main.btn_ability.get_global_rect()).grow(18)
			r2 = r2.intersection(Rect2i(Vector2i.ZERO, img2.get_size()))
			if r2.size.x > 0 and r2.size.y > 0:
				var crop2 := img2.get_region(r2)
				crop2.resize(crop2.get_width() * 3, crop2.get_height() * 3, Image.INTERPOLATE_NEAREST)
				crop2.save_png(SHOT_CROP_ON)
				var same: bool = crop != null and crop.get_data() == crop2.get_data()
				print("ABILITY_REACH_PROBE s2b crop_on=%s disabled_after=%s same_pixels=%s" % [
					SHOT_CROP_ON, main.btn_ability.disabled, same])
	else:
		print("ABILITY_REACH_PROBE s2b 헤드리스 — 스크린샷 생략")

	# ── §3 양성 대조: 누락된 호출 **하나**가 전부인가 ────────────────────────
	main._refresh_ability_button()
	var fixed: Dictionary = _snap(main)
	print("ABILITY_REACH_PROBE s3 after_manual_refresh disabled=%s text='%s'" % [fixed["disabled"], fixed["text"]])
	check(not fixed["disabled"],
		"§3 `_refresh_ability_button()` 을 한 번 불렀는데도 버튼이 막혀 있다 — 누락 하나로 설명되지 않는다(전제가 틀렸다)")

	# ── §4 사유가 서로 다르면 말도 달라야 한다 ──────────────────────────────
	var tiles: Array = ["ㄱ", "ㅏ", "ㅁ"]
	var st_usable: Dictionary = _state(main, true, 1, tiles)
	var st_spent: Dictionary = _state(main, true, 0, tiles)
	var st_idle: Dictionary = _state(main, false, 1, tiles)
	var st_empty: Dictionary = _state(main, true, 1, [])

	print("ABILITY_REACH_PROBE s4 usable  disabled=%s text='%s' tooltip='%s'" % [
		st_usable["disabled"], st_usable["text"], st_usable["tooltip"]])
	print("ABILITY_REACH_PROBE s4 spent   disabled=%s text='%s' tooltip='%s'" % [
		st_spent["disabled"], st_spent["text"], st_spent["tooltip"]])
	print("ABILITY_REACH_PROBE s4 idle    disabled=%s text='%s' tooltip='%s'" % [
		st_idle["disabled"], st_idle["text"], st_idle["tooltip"]])
	print("ABILITY_REACH_PROBE s4 empty   disabled=%s text='%s' tooltip='%s'" % [
		st_empty["disabled"], st_empty["text"], st_empty["tooltip"]])

	# 전제 — 네 상태가 정말로 서로 다른 사유인가 (아니면 '달라져야 한다' 가 공허하다)
	check(not st_usable["disabled"], "§4 [쓸 수 있음] 상태에서 버튼이 막혀 있다")
	check(st_spent["disabled"], "§4 [다 씀] 상태에서 버튼이 열려 있다")
	check(st_idle["disabled"], "§4 [웨이브 밖] 상태에서 버튼이 열려 있다")
	check(st_empty["disabled"], "§4 [타일 없음] 상태에서 버튼이 열려 있다")

	var tips := {
		"쓸 수 있음": st_usable["tooltip"],
		"다 씀": st_spent["tooltip"],
		"웨이브 밖": st_idle["tooltip"],
		"타일 없음": st_empty["tooltip"],
	}
	var distinct := {}
	for k in tips:
		distinct[tips[k]] = true
	print("ABILITY_REACH_PROBE s4 distinct_tooltips=%d of 4" % distinct.size())

	check(tips["쓸 수 있음"] != tips["다 씀"],
		"§4 다 쓰고 나서도 툴팁이 **같은 문장**이다 — '이번 웨이브에는 이미 썼다' 를 알 길이 없다. 툴팁='%s'" % tips["쓸 수 있음"])
	check(tips["쓸 수 있음"] != tips["웨이브 밖"],
		"§4 웨이브 밖에서도 툴팁이 **같은 문장**이다 — '웨이브 중에만 쓴다' 를 알 길이 없다")
	check(tips["쓸 수 있음"] != tips["타일 없음"],
		"§4 타일이 없어도 툴팁이 **같은 문장**이다 — '밀어낼 타일이 없다' 를 알 길이 없다")
	check(tips["다 씀"] != tips["웨이브 밖"],
		"§4 '다 씀' 과 '웨이브 밖' 이 **같은 문장**이다 — 두 사유를 구별하지 못한다(벨트·상점과 다른 규칙)")
	check(str(tips["쓸 수 있음"]).contains(MARK) == false,
		"§4 쓸 수 있는데 툴팁에 사유 표식(%s)이 있다" % MARK)
	# ⚠️ **반대 방향도** 잰다 — 표식은 `disabled` 의 *유일한* 단서다(§2.40).
	#    벨트(`BeltBlockReasonProbe`)와 상점(`ShopReasonProbe` §3b)이 양방향으로 재는데
	#    여기만 한 방향이면, 사유 문구를 고치다 표식을 빠뜨려도 아무도 안 잡는다.
	for k in ["다 씀", "웨이브 밖", "타일 없음"]:
		check(str(tips[k]).contains(MARK),
			"§4 '%s' 로 막혔는데 툴팁에 사유 표식(%s)이 없다 — 막힌 이유가 경고로 안 읽힌다" % [k, MARK])

	# ── §5 양성 대조: 기구가 살아 있는가 (벨트 구매 버튼) ────────────────────
	main.defense_field.gold = 999
	main._on_gold_changed(999)
	await get_tree().process_frame
	var belt_ok: String = str(belt.consonant_buy_button.tooltip_text)
	main.defense_field.gold = 0
	main._on_gold_changed(0)
	await get_tree().process_frame
	var belt_poor: String = str(belt.consonant_buy_button.tooltip_text)
	print("ABILITY_REACH_PROBE s5 belt_ok_has_mark=%s belt_poor_has_mark=%s" % [
		belt_ok.contains(MARK), belt_poor.contains(MARK)])
	check(belt_ok != belt_poor,
		"§5 벨트 구매 버튼의 툴팁이 골드에 따라 달라지지 않는다 — '달라지지 않음' 이 결함인지 판정할 기준이 사라진다")

	# ── §6 보고: 잔여 횟수가 글자에 있는가 ──────────────────────────────────
	var digits := false
	for ch in st_usable["text"]:
		if ch >= "0" and ch <= "9":
			digits = true
	print("ABILITY_REACH_PROBE s6 usable_text='%s' has_digit=%s uses_per_wave=%d" % [
		st_usable["text"], digits, main.ABILITY_USES_PER_WAVE])

	# ── §7 스크린샷은 §2b 로 옮겼다 ─────────────────────────────────────────
	# (결함이 만드는 상태를 찍어야 하는데, 여기까지 오면 §4·§5 가 상태를 바꿔 놓는다.
	#  첫 판은 여기서 `_state()` 를 불러 **켜진** 버튼을 찍었고, 그래서 '고치기 전/후'
	#  두 그림이 md5 까지 같았다 — 캡처 실패가 아니라 캡처 **대상**이 틀렸다.)

	if failures == 0:
		print("ABILITY_REACH_PROBE_OK")
	else:
		print("ABILITY_REACH_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
