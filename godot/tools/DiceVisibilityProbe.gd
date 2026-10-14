extends Node
# 남은 주사위(리롤) 수가 **보이는가** — 그리고 그 표시가 **덮어써지지 않는가**.
# (감사 §5.2 항목 22 의 이웃 / §2.13-1 의 재발, 2026-09-24)
#
# 왜 문제였나 — **두 함수가 같은 문자열 채널에 각자 썼다**:
#
#   `_update_next_round_preview()`  → "다음 라운드 적 예고\n<예고>"          (웨이브마다 불린다)
#   `_update_dice_display()`        → "<예고>\n\n남은 주사위 N개 (…)"        (리롤했을 때만)
#
# 둘 다 `btn_stage.tooltip_text` 를 **통째로 대입**한다. 나중에 부르는 쪽이 이긴다.
# 그래서 주사위 줄은 **웨이브가 시작될 때마다 사라졌다.**
#
# ⚠️ 고치기 전 실측 (`coverage 1/4`):
#     run_start          주사위 3개 · 툴팁에 없음     ← 런 시작에도 안 보였다
#     after_wave_start   주사위 3개 · 툴팁에 없음
#     after_reroll       주사위 2개 · 툴팁에 2개      ← 유일하게 보이는 상태
#     after_wave_change  주사위 2개 · 툴팁에 없음     ← 덮어써짐
#
# 런 시작조차 안 보인 이유: `_update_next_round_preview()` 가 `_ready` 경로(`:165`)에서
# 먼저 불려 툴팁을 예고만으로 채운다. 즉 **한 개도 안 쓴 상태** — 잔량이 가장 중요한 순간이다.
#
# 이것은 §2.13-1(카운트다운이 두 라벨에 중복 표기)과 **같은 결함 부류**이고, 바로 옆 코드 주석이
# 스스로 "코드는 보여준다고 믿는데 화면에는 없었다" 라고 적어 둔 그 실패 모드다.
#
# 그리고 주사위는 **런 지속 자원**이다 — 시작 3 · 막 클리어 +1 · 유물 +2, 웨이브마다 안 채워진다.
# §2.6-b 가 리롤 전용음을 만들 수 있었던 근거가 그 희소성인데, 그 잔량을 **툴팁 채널에서** 잃고 있었다.
#
# ⚠️ 2026-09-24 정정 — **잔량은 화면에 이미 있었다.** 보상 모달의 `RerollRow` 에 `DiceLabel` 이
#   항상 보이고, 주사위는 그 모달에서만 소비된다(`TowerDefenseMain.gd:_on_wave_reward_dice_changed`).
#   즉 플레이어는 **결정하는 그 순간 화면에서** 잔량을 본다. 이 파일은 오랫동안 "보여주는 곳이
#   툴팁 하나뿐" 이라고 보고했는데, 그건 **툴팁 채널 하나만 재고 '화면 전체' 를 판정한** 결론이었다.
#   → §7 이 모달 채널을 직접 재고, §6 은 그 결과에 따라 문구가 갈린다.
#
# ⚠️ 이 도구가 재는 것 (한쪽만 재면 반쪽짜리 검사다):
#   §0 전제 — 툴팁을 가진 노드와 주사위 수를 읽을 수 있는가
#   §1 비공허성 — 툴팁이 비어 있지 않고 **예고를 포함**한다 (모든 상태에서).
#      이게 없으면 "툴팁을 비우는" 고침이 통과한다.
#   §1b 모양이 **상태에 따라 달라지지 않는가** — 머리말(`다음 라운드 적 예고`)의 유무가
#      상태마다 갈리면 같은 채널이 두 모양을 갖는 것이다(고치기 전: 4개 중 3개만 머리말).
#   §2 런 시작 — 주사위 3개인데 툴팁이 그 수를 말하는가
#   §3 웨이브 시작 뒤 — 그 수가 **살아남았는가** (덮어쓰기 결함의 본체)
#   §4 리롤 뒤 — 수가 있는가 (고치기 전 유일하게 통과하던 경로 — 그래서 회귀 감시가 필요하다)
#   §5 수가 `main.reroll_dice` 와 **같은가** — 낡은 수를 보여주는 고침을 막는다
#   §7 모달 채널 — 잔량이 **화면에** 나오는 곳이 따로 있는가 (`DiceLabel` 의 존재·가시성·값)
#   §6 보고 — 몇 개 상태가 툴팁에 수를 보여주는가 + 화면 채널의 유무
#
# ⚠️ 단언하는 것은 **일관성**이지 '어디에 보여야 하는가' 가 아니다. 툴팁에 쓴다는 결정은
#   코드가 이미 했다(`_update_dice_display` 가 그랬다). 이 프로브는 **그 결정이 지켜지는가**만 잰다.
#   같은 이유로 §1b 는 "머리말이 있어야 한다" 가 아니라 "**상태마다 같아야 한다**" 를 잰다 —
#   머리말을 통째로 빼는 것도 감독이 고를 수 있는 모양이기 때문이다.
# ⚠️ 다만 §7 은 **단언한다** — 모달의 `DiceLabel` 이 사라지거나 숨겨지면 잔량을 볼 수 있는
#   **화면** 채널이 없어지기 때문이다(툴팁은 마우스를 올려야 보인다). §6 의 `OPEN_ITEM` 은
#   그 채널이 **정말 없을 때만** 찍힌다 — 있으면 `RESOLVED` 다.
#
# 실행: godot --headless --path . res://tools/DiceVisibilityProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 주사위 줄의 표식 — `_refresh_stage_tooltip()` 이 쓰는 문구 그대로.
const DICE_MARK := "남은 주사위"
## 다음 라운드 예고의 표식 — `DefenseField.next_round_preview()` 가 "다음 %d막 %dR: …" 를 준다.
const PREVIEW_MARK := "R:"
## 툴팁 첫 줄의 머리말 — 이게 붙었다 떨어졌다 하면 같은 채널이 두 모양을 갖는 것이다.
const HEADER_MARK := "다음 라운드 적 예고"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 툴팁에서 주사위 수를 뽑는다. 없으면 -1.
## ⚠️ `contains()` 만으로는 **낡은 수**를 못 잡는다 — §5 가 값까지 비교하려고 뽑아 둔다.
## ⚠️ 표식과 수 사이에 `": "` 가 있다(`"남은 주사위: 2개"`). 첫 판은 숫자가 아닌 문자를 만나면
##   바로 끊어서 **2 를 못 읽고 '없음' 으로 보고했다** — 즉 §4 가 거짓 실패했다.
##   §2.13-1 이 `contains("초")` 로 거짓 양성을 낸 것과 같은 부류다: **표식은 문구의 구조에서
##   와야 하고, 파서는 그 구조를 따라가야 한다.**
func _dice_in(text: String) -> int:
	var i := text.find(DICE_MARK)
	if i < 0:
		return -1
	var tail := text.substr(i + DICE_MARK.length())
	var digits := ""
	for ch in tail:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break          # 수가 시작된 뒤 끊기면 끝("2개" → "2")
		# 수가 시작되기 전의 문자(`:` · 공백)는 건너뛴다.
	return int(digits) if digits != "" else -1

## 한 상태를 재서 보고한다. `require` 가 참이면 '수가 있어야 한다' 를 단언한다.
## ⚠️ §5 는 `require` 와 무관하게, **수가 있을 때만** 값을 비교한다(없는 것과 틀린 것은 다른 결함).
func _sample(tag: String, main, require: bool) -> Dictionary:
	var tip: String = main.btn_stage.tooltip_text
	var got := _dice_in(tip)
	var want: int = main.reroll_dice
	var has_preview := tip.contains(PREVIEW_MARK)
	var has_header := tip.contains(HEADER_MARK)
	print("DICE_PROBE %-17s dice=%s want=%d preview=%s header=%s tooltip=%s"
		% [tag, ("%d" % got) if got >= 0 else "없음", want, has_preview, has_header,
			JSON.stringify(tip)])

	# §1 비공허성 — 툴팁이 살아 있고 예고를 담고 있어야 한다.
	check(tip.strip_edges() != "", "%s: 툴팁이 비어 있다 — 정보 채널이 사라졌다" % tag)
	check(has_preview, "%s: 툴팁에서 다음 라운드 예고가 사라졌다 — 주사위를 넣다 예고를 지웠다" % tag)

	if require:
		check(got >= 0, "%s: 툴팁에 남은 주사위 수가 없다 — 주사위 %d개인데 화면 어디에도 안 보인다"
			% [tag, want])
	if got >= 0:
		check(got == want, "%s: 툴팁의 주사위가 %d 인데 실제는 %d 다 — 낡은 수를 보여준다"
			% [tag, got, want])
	return {"tag": tag, "got": got, "want": want, "preview": has_preview, "header": has_header}

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	# `start_new_game` 끝의 `call_deferred("_start_wave_automatically")` 를 멈춘다.
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	await get_tree().process_frame

	# ── §0 전제 ────────────────────────────────────────────────────────────
	check(main.btn_stage != null, "btn_stage 가 없다 — 툴팁을 잴 대상이 없다")
	check(main.telegraph_label != null, "telegraph_label 이 없다 — 예고가 화면에 나오는 곳을 못 잰다")
	if main.btn_stage == null:
		get_tree().quit(failures + 1)
		return
	# ⚠️ `wave_running` 을 함께 찍는다. `reset_combat_state()` 는 `_refresh_stage_tooltip()` 을
	#   부르지 않으므로, 이 시점의 툴팁은 **직전에 쓰인 값**(웨이브가 시작될 때 쓴 것)이다.
	#   즉 `run_start` 는 "런을 막 시작한 직후의 툴팁" 이지 "이 상태에서 방금 다시 쓴 툴팁" 이 아니다.
	#   이걸 모르면 주입 조건을 `is_wave_running` 으로 잡는 실수를 한다(하네스 I5 첫 판이 그랬다).
	print("DICE_PROBE ctx start_dice=%d wave_running=%s tooltip=%s"
		% [main.reroll_dice, main.defense_field.is_wave_running,
			JSON.stringify(main.btn_stage.tooltip_text)])

	var states: Array = []

	# ── §2 런 시작 — 주사위 3개. 화면이 그걸 말하는가? ───────────────────────
	# 여기가 첫 번째 결함이다: `_update_next_round_preview()` 가 `_ready` 경로에서
	# 먼저 불려 툴팁을 예고만으로 채운다. **한 개도 안 쓴 상태**가 가장 중요한데 안 보인다.
	check(main.reroll_dice == 3, "런 시작 주사위가 %d 다 (3이어야 한다) — 기준선이 다르다" % main.reroll_dice)
	states.append(_sample("run_start", main, true))

	# ── §3 웨이브 시작 — 그 수가 살아남았는가 ───────────────────────────────
	# 실제 경로로 웨이브를 시작한다(`start_next_wave()` 가 `wave_status_changed` 를 emit).
	main._on_start_wave_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	check(main.defense_field.is_wave_running, "웨이브가 시작되지 않았다 — 덮어쓰기를 잴 수 없다")
	states.append(_sample("after_wave_start", main, true))

	# ── §4 리롤 뒤 — 지금 유일하게 통과하는 경로 ────────────────────────────
	# ⚠️ 실제 버튼 신호로 태운다 — 함수를 직접 부르면 **연결이 끊긴 것**을 못 잡는다.
	main._show_wave_reward(1, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal = main.modal_layer.get_child(main.modal_layer.get_child_count() - 1)
	check(modal != null, "보상 모달이 뜨지 않았다")
	if modal == null:
		get_tree().quit(failures + 1)
		return
	modal.btn_reroll.pressed.emit()
	await get_tree().process_frame
	check(main.reroll_dice == 2, "리롤로 주사위가 줄지 않았다 (%d)" % main.reroll_dice)
	states.append(_sample("after_reroll", main, true))

	# ── §3b 리롤 뒤 웨이브 상태 변경 — 다시 덮이는가 ────────────────────────
	# ⚠️ 여기서는 **핸들러를 다시 태우는 것**이 목적이라 신호를 직접 emit 한다.
	#   신호 **연결** 자체는 §3 이 실제 경로(`_on_start_wave_pressed`)로 이미 증명했다.
	main.defense_field.wave_status_changed.emit(
		main.defense_field.current_act, 3, main.defense_field.current_wave, 20, false)
	await get_tree().process_frame
	states.append(_sample("after_wave_change", main, true))

	# ── §1b 모양이 상태에 따라 달라지지 않는가 ──────────────────────────────
	# ⚠️ "머리말이 있어야 한다" 가 아니라 "**상태마다 같아야 한다**" 를 잰다. 머리말을 통째로
	#   빼는 것도 감독이 고를 수 있는 모양이지만, 같은 채널이 상태에 따라 두 모양을 갖는 것은
	#   고를 수 있는 모양이 아니다(고치기 전: 리롤 뒤에만 머리말이 사라졌다).
	var header_off: Array = []
	for s in states:
		if not s["header"]:
			header_off.append(s["tag"])
	print("DICE_PROBE shape header_off=%s" % str(header_off))
	check(header_off.is_empty() or header_off.size() == states.size(),
		"툴팁 모양이 상태에 따라 갈린다 — 머리말이 없는 상태: %s (전부 있거나 전부 없어야 한다)"
			% str(header_off))

	# ── §7 모달 채널 — 잔량이 '화면에' 나오는 곳이 따로 있는가 ──────────────
	# ⚠️ 이 절이 없어서 오랫동안 **틀린 결론**이 보고됐다: "보여주는 곳은 툴팁 하나뿐".
	#   툴팁 채널만 재고 '화면 전체' 를 판정한 것이다. 실제로는 리롤을 결정하는 바로 그
	#   화면(보상 모달의 `RerollRow`)에 `DiceLabel` 이 붙어 있다. §2.3·§2.7 과 같은 부류 —
	#   낡는 것은 근거가 아니라 **결론**이고, 채널 하나를 재서 다른 채널의 부재를 주장하면
	#   그 결론이 틀린다.
	var mtext := ""
	var modal_visible := false
	if is_instance_valid(modal) and modal.dice_label != null:
		mtext = modal.dice_label.text
		modal_visible = modal.dice_label.is_visible_in_tree()
		check(mtext.strip_edges() != "",
			"보상 모달의 DiceLabel 이 비어 있다 — 리롤을 결정하는 화면에서 잔량이 사라졌다")
		check(modal_visible,
			"보상 모달의 DiceLabel 이 **보이지 않는다**(is_visible_in_tree=false) — 리롤 버튼 옆에 보여야 한다")
		check(_dice_in(mtext) == main.reroll_dice,
			"보상 모달의 주사위가 %d 인데 실제는 %d 다 — 결정 화면이 낡은 수를 보여준다"
				% [_dice_in(mtext), main.reroll_dice])
	else:
		# ⚠️ 조용히 건너뛰면 §7 이 '아무것도 안 재는 절' 이 된다. 전제가 깨지면 실패시킨다.
		check(false, "보상 모달의 DiceLabel 을 못 봤다 — §7 의 전제가 깨졌다(모달이 해제됐거나 라벨이 없다)")
	print("DICE_PROBE modal_channel visible=%s text=%s" % [modal_visible, JSON.stringify(mtext)])

	# ── §6 보고 — 몇 개 상태가 툴팁에 수를 보여주는가 + 화면 채널의 유무 ────
	var shown := 0
	for s in states:
		if s["got"] >= 0:
			shown += 1
	print("DICE_PROBE coverage %d/%d 상태가 툴팁에 남은 주사위 수를 보여준다" % [shown, states.size()])
	# ⚠️ 결론을 **재고 나서** 말한다. 예전엔 채널 하나만 보고 '화면에 없다' 고 단정했다.
	if modal_visible:
		print("DICE_PROBE RESOLVED 잔량은 리롤을 결정하는 화면(보상 모달의 RerollRow)에 이미 보인다 — 툴팁은 그 바깥에서의 미리보기다")
	else:
		print("DICE_PROBE OPEN_ITEM 잔량을 보여주는 화면 채널이 없다 — 화면에 따로 낼지는 감독 결정이다")

	if failures == 0:
		print("DICE_VISIBILITY_PROBE_OK")
	get_tree().quit(failures)
