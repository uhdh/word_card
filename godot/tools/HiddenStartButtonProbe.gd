extends Node
# §2.27 — `BtnStartWave` 를 **지웠다**(2026-10-06, 선택지 (B)). 이 프로브가 그 계약을 지킨다.
#
# ── 무엇이 문제였나 (고치기 전) ──────────────────────────────────────────────
#   ① 버튼은 씬에서 `visible = false` + 코드 `.hide()` 라 **영영 안 보였다**(`.show()` 0건).
#   ② 그런데 그 **툴팁이 `[SPACE]` 단축키를 알리는 유일한 문장**이었다 — 볼 수 없는 표면에만 안내.
#   ③ 코드 주석 두 곳이 *"상단 [웨이브 시작]"* 을 **있는 것처럼** 말했다(설명이 계약 위반).
#   ④ 문구를 **세 곳**이 서로 다르게 관리했다(`"진행 중"/"웨이브 시작"` · `"▶ 웨이브"` · 씬 `"웨이브"`).
#
# ── ⚠️ 이 프로브가 (고치기 전에) **반증한 것** ────────────────────────────────
# 처음엔 *"다음 웨이브를 시작할 문이 화면에 없다"* 를 의심했다 — `start_next_wave()` 의 호출부가
# `_on_start_wave_pressed()` 하나뿐이고, 그 문이 ①숨은 버튼 ②키보드 `[SPACE]` 인데 ②를 알리는
# 문장이 ①의 툴팁에만 있기 때문이다. **그러나 실측은 반대였다**: 라운드는 `DefenseField._process`
# 가 스스로 굴린다(30x 로 180 게임초에 `wave_cleared` **10회** · 플레이어 입력 0회).
# ⇒ **기능 손실은 없었다.** 손실은 *단축키를 모른다* + *거짓 주석* + *안 보이는 노동* 뿐이었다.
#
# ── 고친 것 ────────────────────────────────────────────────────────────────
#   · 두 씬에서 노드를 지우고, `TowerDefenseMain.gd` 의 대입 7곳을 지웠다.
#   · `[SPACE]` 안내를 **막 클리어 모달의 본문**으로 옮겼다 — Space 가 실제로 일하는
#     **유일한 순간**이기 때문이다(`_on_start_wave_pressed` 가 그 모달을 닫고 다음 막을 시작한다).
#   · 거짓 주석 둘을 고쳤다.
#
# ── 재는 것 (고침 뒤 계약) ──────────────────────────────────────────────────
#   S1 두 씬 어디에도 `BtnStartWave` 노드가 **없다**
#   S2 `TowerDefenseMain.gd` 에 `btn_start_wave` 참조가 **0건**이다 (노드 없는 대입 = 런타임 오류)
#   S3 *"상단 [웨이브 시작]"* 주장이 **0건**이다
#   S4 ⭐ `[SPACE]` 안내가 **보이는 표면**(막 클리어 모달)에 있고 `is_visible_in_tree()` 가 참이다
#   S5 양성 대조 — 안내 탐지기가 **일부러 숨긴 라벨**은 세지 않는가
#
# ⚠️ S4 만이 '도달' 을 잰다. S1~S3 은 *"지웠다"* 를 잴 뿐이고, 안내를 아무 데도 안 옮겼다면
#    S1~S3 은 전부 초록인 채로 **안내가 사라진다** — 그래서 S4 가 본체다.
#
# 실행: godot --headless --path . res://tools/HiddenStartButtonProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const BOT_SCENE := "res://scenes/tower/AutoPlayTDTest.tscn"
const SRC := "res://scripts/ui/TowerDefenseMain.gd"

## 플레이어에게 `[SPACE]` 를 알리는 문구. **보이는** 표면이 하나는 있어야 한다.
const SPACE_GUIDE := "[SPACE]"
## 코드가 *"이 버튼이 있다"* 고 주장하던 문구(주석). 이제 0건이어야 한다.
const CLAIM := "상단 [웨이브 시작]"
## 지운 노드의 이름.
const NODE_NAME := "BtnStartWave"

var failures := 0

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

## 트리 전체에서 **보이는** `Label` 중 `needle` 을 담은 것의 수.
## ⚠️ `is_visible_in_tree()` 로 잰다 — `visible` 필드만 보면 **숨은 부모 밑의 자식**을
##    '보인다' 로 잘못 센다(§2.38 이 정확히 그 함정이었다).
func _count_visible_labels(root: Node, needle: String) -> int:
	var n := 0
	for node in root.find_children("*", "Label", true, false):
		var l := node as Label
		if l != null and l.text.contains(needle) and l.is_visible_in_tree():
			n += 1
	return n

func _ready() -> void:
	SoundEngine.muted = true

	# ── S1 두 씬 어디에도 노드가 없다 ────────────────────────────────────────
	# ⚠️ 씬 **텍스트**가 아니라 **인스턴스**를 본다 — 텍스트 검색은 이름이 주석에만 있어도
	#    걸리고, 노드가 다른 이름으로 남아 있으면 못 잡는다.
	for path in ["res://scenes/TowerDefenseMain.tscn", BOT_SCENE]:
		var scene: PackedScene = load(path)
		check(scene != null, "씬을 못 읽었다: %s — S1 이 공허하다" % path, "S1")
		if scene == null:
			continue
		var inst := scene.instantiate()
		var found := inst.find_child(NODE_NAME, true, false)
		check(found == null,
			"%s 에 `%s` 노드가 아직 있다 — 숨은 버튼이 남아 있다" % [path, NODE_NAME], "S1")
		inst.free()

	# ── S2 소스에 참조가 0건 ─────────────────────────────────────────────────
	var src := _read(SRC)
	check(src != "", "소스를 못 읽었다 — S2·S3 이 공허하다", "S2")
	var refs := 0
	for raw in src.split("\n"):
		if str(raw).contains("btn_start_wave"):
			refs += 1
	check(refs == 0,
		"`btn_start_wave` 참조가 %d줄 남아 있다 — 노드 없는 대입은 런타임 오류다" % refs, "S2")

	# ── S3 거짓 주장 0건 ────────────────────────────────────────────────────
	var claims := 0
	for raw in src.split("\n"):
		if str(raw).contains(CLAIM):
			claims += 1
	check(claims == 0,
		"*\"%s\"* 주장이 %d줄 남아 있다 — 없는 버튼을 있다고 말한다" % [CLAIM, claims], "S3")

	# ── S4 ⭐ 안내가 **보이는 표면**에 있는가 — 이 프로브의 본체 ──────────────
	var main = MainScene.instantiate()
	add_child(main)
	for i in 4:
		await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	for i in 4:
		await get_tree().process_frame
	# 라운드가 자동으로 굴러가므로 멈춰 세우고 막 클리어만 직접 일으킨다.
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	main._on_act_cleared(1, 100)
	for i in 4:
		await get_tree().process_frame

	var guide: Label = null
	for node in main.modal_layer.find_children("*", "Label", true, false):
		var l := node as Label
		if l != null and l.text.contains(SPACE_GUIDE):
			guide = l
			break
	check(guide != null,
		"막 클리어 모달이 `%s` 안내를 나르지 않는다 — §2.27 의 안내가 갈 곳이 없어졌다" % SPACE_GUIDE, "S4")
	if guide != null:
		check(guide.is_visible_in_tree(),
			"`%s` 안내를 가진 라벨이 **보이지 않는다** — 안내가 다시 도달 불가능해졌다" % SPACE_GUIDE, "S4")
		print("HIDDEN_START guide=%s visible=%s" % [
			JSON.stringify(guide.text.strip_edges()), str(guide.is_visible_in_tree())])

	# ── S5 양성 대조 — 탐지기가 **숨긴 라벨**을 세면 안 된다 ─────────────────
	# ⚠️ '개수 == 1' 로 단언하지 않는다 — 화면에 정당한 안내가 몇 개인지는 이 프로브의
	#    관심사가 아니다. **숨긴 표본을 더해도 수가 변하지 않는가** 만 잰다.
	var before := _count_visible_labels(main, SPACE_GUIDE)
	var bait := Label.new()
	bait.text = "양성 대조 " + SPACE_GUIDE
	bait.visible = false
	main.add_child(bait)
	await get_tree().process_frame
	var after := _count_visible_labels(main, SPACE_GUIDE)
	check(before >= 1, "보이는 `%s` 안내가 0개다 — S4 의 기준선이 서지 않았다" % SPACE_GUIDE, "S5")
	check(after == before,
		"숨긴 라벨을 세었다 (%d → %d) — 탐지기가 가시성을 안 본다" % [before, after], "S5")
	bait.queue_free()

	print("HIDDEN_START summary node_refs=%d claims=%d visible_guides=%d" % [refs, claims, before])
	if failures == 0:
		print("HIDDEN_START_PROBE_OK")
	get_tree().quit(failures)
