extends Node
# §2.44 — 웨이브 보상 드래프트가 **게임에서 발동하지 않는다** (보고 전용).
#
# ── 무엇을 재는가 ────────────────────────────────────────────────────────────
# `GAME_DESIGN.md:86` 은 *"클리어 보상: 자모 선택(모음 1장 보장) · 리롤 주사위 · 스킵"* 을
# 설계로 명시한다. 그런데 `TowerDefenseMain._on_wave_cleared` 의 마지막 줄은
#
#     if not defense_field.is_wave_running and not _is_terminal_modal_open():
#         _show_wave_reward(wave, bonus_gold)
#
# 이고, `wave_cleared` 는 **라운드마다** `DefenseField._process` **안에서** 발화하므로 그 시점에
# `is_wave_running` 은 **참**이다 → `not true` = **매번 거짓**. `_show_wave_reward` 의
# 게임플레이 호출부는 그 가드 **하나뿐**(`:793`).
#
# ── ⚠️ 왜 코드를 읽는 것으로 끝내지 않는가 ───────────────────────────────────
# *"실제 실행에서는 값이 다를 수도"* 를 배제해야 한다. 그래서 **계측이 아니라 관측**으로 잰다:
# 게임을 실제로 굴려 `wave_cleared` 가 N회 나는 동안 `modal_layer` 에 `WaveRewardModal` 이
# **한 번이라도** 들어오는지 본다. 계측(소스 편집)이 필요 없어 **원복 사고가 없다.**
#
# ── 파급도 함께 잰다 ────────────────────────────────────────────────────────
# 보상 모달이 죽으면 `reroll_dice` 의 **소비자가 사라진다**. 그런데 그 주사위는
#   · 막 클리어마다 +1 로 **지급**되고,
#   · 상점이 **25G 유료 유물**(`relic_golden_dice` · "보상 리롤 주사위를 +2개 즉시 지급")로 **팔며**,
#   · 상단 `BtnStage` 툴팁이 *"남은 주사위: N개 (웨이브 보상 새로고침)"* 이라며 **안내**한다.
# 지급·판매·광고는 살아 있는데 **쓸 곳이 없다.**
#
# ── ✅ 2026-10-06 — 판정을 **켰다** ──────────────────────────────────────────
# §2.44 가 (B) 로 고쳐졌다(가드에서 `not is_wave_running` 절 제거 + 모달이 뜨는 동안 필드 정지).
# 그래서 S1 이 이제 **"게임플레이가 보상 모달을 연다"** 를 단언한다. 양성 대조(직접 호출)는
# 그대로 두되 **단언보다 뒤**로 옮겼다 — 대조가 먼저면 단언이 공짜로 통과한다.
#
# 실행: godot --headless --path . res://tools/_RewardTrigInject.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const MAIN_SRC := "res://scripts/ui/TowerDefenseMain.gd"
const MODAL_SRC := "res://scripts/ui/WaveRewardModal.gd"
const SHOP_SRC := "res://scripts/ui/ShopModal.gd"

## 보상 모달의 씬 루트 이름. `_show_wave_reward` 가 `WAVE_REWARD_SCENE` 을 인스턴스화하면
## `modal_layer` 에 이 이름으로 들어온다.
const REWARD_NODE := "WaveRewardModal"
## 주사위를 안내하는 문구(상단 툴팁).
const DICE_HINT := "남은 주사위"

var failures := 0

## ⚠️ **멤버**여야 한다 — 2026-10-06 실측. 첫 판은 `_ready()` 의 **지역** 변수를 람다에서
## `cleared += 1` 했고, GDScript 람다는 **지역을 값으로 캡처**하므로 바깥 변수가 0 으로 남았다.
## `wave_cleared` 는 실제로 발화하고 있었는데 프로브가 "게임을 못 굴렸다" 고 **거짓 보고**했다
## (전제 단언이 그 거짓을 잡아 줬다 — 없었으면 '안 떴다' 는 결론이 통과했을 것이다).
var cleared_count := 0

func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

## 소스에서 `needle` 을 포함하는 줄을 `번호: 내용` 으로 모은다(주석 포함 — 사실만 적는다).
func _lines_with(text: String, needle: String) -> Array:
	var out: Array = []
	var i := 0
	for raw in text.split("\n"):
		i += 1
		if str(raw).contains(needle):
			out.append("%d:%s" % [i, str(raw).strip_edges()])
	return out

## 트리에서 **보이는** Control 중 툴팁에 `needle` 을 담은 것을 모은다.
## ⚠️ `is_visible_in_tree()` 를 본다 — 숨은 노드의 툴팁은 플레이어에게 도달하지 않는다
##    (같은 날 `HiddenStartButtonProbe` 가 그 함정을 실측했다).
func _visible_tooltips(root: Node, needle: String, out: Array, path: String = "") -> void:
	var here := path + "/" + str(root.name)
	if root is Control:
		var ctl := root as Control
		if ctl.is_visible_in_tree() and str(ctl.tooltip_text).contains(needle):
			out.append(here)
	for c in root.get_children():
		_visible_tooltips(c, needle, out, here)

func _ready() -> void:
	SoundEngine.muted = true
	var main = MainScene.instantiate()
	add_child(main)
	for i in 4:
		await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	for i in 8:
		await get_tree().process_frame

	var field = main.defense_field
	field.wave_cleared.connect(func(_a, _w, _b): cleared_count += 1)
	print("REWARD_TRIGGER boot running=%s wave=%d act=%d" % [
		str(field.is_wave_running), field.current_wave, field.current_act])

	# ── S1 게임을 실제로 굴려 **보상 모달이 뜨는가** ─────────────────────────
	# 계측(소스 편집) 없이 관측만 한다 — 원복 사고가 날 여지를 없앤다.
	var seen := {}
	Engine.time_scale = 40.0
	var elapsed := 0.0
	while elapsed < 4.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time() / 40.0
		for c in main.modal_layer.get_children():
			seen[str(c.name)] = true
	Engine.time_scale = 1.0
	# ⚠️ **여기서 먼저 판정한다** — 아래 양성 대조(직접 호출)가 `seen` 에 이름을 넣으므로,
	# 그 뒤에 보면 "게임이 열었다" 와 "내가 열었다" 가 구분되지 않는다(공짜 통과).
	var shown_by_play := seen.has(REWARD_NODE)
	check(shown_by_play,
		"게임플레이가 보상 드래프트를 **한 번도** 열지 않았다 — §2.44 의 가드가 되돌아왔다", "S1")
	main._show_wave_reward(1, 5)  # INJECT — 양성 대조: 직접 부르면 탐지기가 봐야 한다
	for i in 4:
		await get_tree().process_frame
	for c in main.modal_layer.get_children():
		seen[str(c.name)] = true
	var reward_shown := seen.has(REWARD_NODE)
	check(reward_shown, "직접 호출해도 탐지기가 모달을 못 봤다 — 탐지기가 고장났다", "S1")
	print("REWARD_TRIGGER wave_cleared=%d modal_seen=%s by_play=%s reward_modal_appeared=%s" % [
		cleared_count, str(seen.keys()), str(shown_by_play), str(reward_shown)])

	# ── S2 `reroll_dice` 의 소비자 — 지급·저장 말고 **쓰는 곳**이 있는가 ─────
	var main_src := _read(MAIN_SRC)
	var modal_src := _read(MODAL_SRC)
	check(main_src != "" and modal_src != "", "소스를 못 읽었다 — S2·S3 이 공허하다", "S2")
	var dice_lines := _lines_with(main_src, "reroll_dice")
	print("REWARD_TRIGGER reroll_refs=%d" % dice_lines.size())
	for l in dice_lines:
		print("REWARD_TRIGGER reroll %s" % str(l))
	var modal_dice := _lines_with(modal_src, "remaining_dice")
	print("REWARD_TRIGGER modal_dice_refs=%d" % modal_dice.size())

	# ── S3 그 주사위를 플레이어에게 **광고하는가** ──────────────────────────
	var tips: Array = []
	_visible_tooltips(main, DICE_HINT, tips)
	print("REWARD_TRIGGER dice_hint_surfaces=%d %s" % [tips.size(), str(tips)])

	# ── S4 상점이 그 주사위를 **파는가** ────────────────────────────────────
	var shop_src := _read(SHOP_SRC)
	var golden := _lines_with(shop_src, "golden_dice")
	print("REWARD_TRIGGER shop_golden_refs=%d %s" % [golden.size(), str(golden)])
	var cost_line := _lines_with(shop_src, "\"cost\"")
	var price := -1
	var idx := shop_src.find("relic_golden_dice")
	if idx >= 0:
		var tail := shop_src.substr(idx, 200)
		var ci := tail.find("\"cost\":")
		if ci >= 0:
			var after := tail.substr(ci + 7, 6).strip_edges()
			var digits := ""
			for ch in after:
				if ch >= "0" and ch <= "9":
					digits += ch
				else:
					break
			if digits != "":
				price = int(digits)
	print("REWARD_TRIGGER shop_golden_cost=%d" % price)

	# ── S5 비공허성 ────────────────────────────────────────────────────────
	# ① 라운드가 실제로 끝나야 하고 ② 보상 모달 씬이 실재해야 하며 ③ 주사위 참조가 있어야 한다.
	# ①이 없으면 "안 떴다" 가 아니라 "게임을 못 굴렸다" 이다.
	check(cleared_count > 0, "`wave_cleared` 가 한 번도 안 났다 — S1 이 공허하다(게임을 못 굴렸다)", "S5")
	check(ResourceLoader.exists("res://scenes/tower/WaveRewardModal.tscn"),
		"보상 모달 씬이 없다 — '안 떴다' 의 대상이 사라졌다", "S5")
	check(not dice_lines.is_empty(), "`reroll_dice` 참조가 0 — S2 가 공허하다", "S5")

	print("REWARD_TRIGGER summary cleared=%d reward_appeared=%s dice_refs=%d hint_surfaces=%d golden_cost=%d" % [
		cleared_count, str(reward_shown), dice_lines.size(), tips.size(), price])
	if failures == 0:
		print("REWARD_TRIGGER_PROBE_OK")
	get_tree().quit(failures)
