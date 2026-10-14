extends Node
# §2.45 — `defense`+`heal` 짝의 **기지 HP +1** 이 툴팁에 안 나온다 (보고 전용).
#
# ── 왜 결함인가 ──────────────────────────────────────────────────────────────
# `GAME_DESIGN.md` §4 는 이렇게 계약한다:
#   *"**시너지가 보이게 하는 3장치** … 2. 짝 특성 보너스 … 3. 같은 특성 밀집 …
#     적용된 시너지는 **타워 툴팁에 전부 나열된다 — 숨은 보너스는 없다.**"*
#
# 그런데 `DefenseField._grant_round_reward()` 안에 **네 번째 장치**가 숨어 있다:
#
#     for i in range(active_towers.size() - 1):
#         var pair = [active_towers[i].word_data.get("category"), active_towers[i + 1].word_data.get("category")]
#         if "defense" in pair and "heal" in pair:
#             base_hp = mini(max_base_hp, base_hp + 1)
#             ...
#
# 이 절은 `synergy_labels` 를 **건드리지 않는다** — 그래서 툴팁에 안 나온다.
#
# ── ⚠️ 두 번째 문제 — '인접' 의 뜻이 다르다 ─────────────────────────────────
# 툴팁에 나오는 `defense`+`heal` 시너지(`수호의 순환` · 피해 ×1.1)는 **물리 거리** 인접을 본다
# (`towers_are_adjacent` = `distance_to(...) <= 100`). 반면 HP +1 은 **배열 순서** 인접
# (`active_towers[i]`, `active_towers[i+1]`)을 본다. 같은 개념에 두 규칙이라, 플레이어는
# 툴팁에 `수호의 순환` 이 뜨는데 HP 는 안 오르거나, 그 반대를 겪을 수 있다.
#
# ── 무엇을 재는가 ────────────────────────────────────────────────────────────
# ① 두 카테고리 타워를 실제로 세우고 ② `base_hp` 를 최대치 아래로 둔 뒤 ③ 라운드 보상을
# 한 번 지급해 ④ `base_hp` 가 올랐는지, ⑤ 그 사실이 `synergy_labels` 에 적혔는지 본다.
#
# ⚠️ **보고 전용** — 미결 항목으로 빨강을 만들지 않는다(감사 §4.2). 전제가 깨질 때만 실패한다.
#
# 실행: godot --headless --path . res://tools/HiddenHealSynergyProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## `갓`(defense) = ㄱ+ㅏ+ㅅ · `봄`(heal) = ㅂ+ㅗ+ㅁ — 둘 다 1음절이라 배치가 단순하다.
const DEFENSE_JAMO: Array = ["ㄱ", "ㅏ", "ㅅ"]
const HEAL_JAMO: Array = ["ㅂ", "ㅗ", "ㅁ"]

var failures := 0

func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

## 타일을 슬롯별로 배치한다. `AutoPlayTowerDefense._assign_slot_jamo` 와 같은 방식이되
## **두 슬롯에 나눠** 담을 수 있게 확장했다(그쪽은 전부 한 슬롯에 넣는다).
func _place(belt, entries: Array) -> void:
	belt.jamo_list.clear()
	belt.slot_assignments.clear()
	for e in entries:
		belt.jamo_list.append(str(e[0]))
		belt.slot_assignments.append(int(e[1]))
	belt.render_belt()

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
	var belt = main.jamo_belt

	# ── S1 두 타워를 세운다 ────────────────────────────────────────────────
	var entries: Array = []
	for c in DEFENSE_JAMO: entries.append([c, 0])
	for c in HEAL_JAMO: entries.append([c, 1])
	_place(belt, entries)
	for i in 4:
		await get_tree().process_frame

	var cats: Array = []
	for t in field.active_towers:
		cats.append(str(t.word_data.get("category", "")))
	print("HIDDEN_HEAL towers=%d categories=%s" % [field.active_towers.size(), str(cats)])

	# ── S2 보상 전 상태 ────────────────────────────────────────────────────
	# ⚠️ `base_hp` 를 **최대치 아래**로 둬야 한다 — 가득 차 있으면 `mini()` 가 막아 변화가 안 보이고,
	#    그러면 "안 올랐다" 가 결함이 아니라 **천장 때문**이 된다.
	field.base_hp = 40
	var hp_before: int = field.base_hp
	var labels_before: Array = []
	for t in field.active_towers:
		labels_before.append_array(t.synergy_labels)
	print("HIDDEN_HEAL before hp=%d/%d labels=%s" % [hp_before, field.max_base_hp, str(labels_before)])

	# ── S3 라운드 보상 지급 ────────────────────────────────────────────────
	field._grant_round_reward(false)
	for i in 2:
		await get_tree().process_frame
	var hp_after: int = field.base_hp
	var labels_after: Array = []
	for t in field.active_towers:
		labels_after.append_array(t.synergy_labels)
	print("HIDDEN_HEAL after hp=%d labels=%s" % [hp_after, str(labels_after)])
	print("HIDDEN_HEAL hp_delta=%d" % (hp_after - hp_before))

	# ── S4 그 HP 증가가 툴팁에 적혔는가 ────────────────────────────────────
	# `synergy_labels` 는 툴팁이 읽는 **유일한** 목록이다. 새 라벨이 하나라도 붙었는지 본다.
	var new_labels: Array = []
	for l in labels_after:
		if not labels_before.has(l):
			new_labels.append(l)
	print("HIDDEN_HEAL new_labels=%s" % str(new_labels))
	var mentioned := false
	for l in labels_after:
		if str(l).contains("회복") or str(l).contains("HP") or str(l).contains("수호"):
			mentioned = true
	print("HIDDEN_HEAL hp_gain_listed=%s" % str(mentioned))

	# ── S5 비공허성 ────────────────────────────────────────────────────────
	# ① 타워가 둘 이상 ② 카테고리 짝이 정확히 `defense`+`heal` ③ HP 가 실제로 늘 여지가 있어야 한다.
	check(field.active_towers.size() >= 2,
		"타워가 둘 미만이다 — '짝' 자체가 없다", "S5")
	check(cats.has("defense") and cats.has("heal"),
		"카테고리 짝이 `defense`+`heal` 이 아니다(%s) — S3 이 공허하다" % str(cats), "S5")
	check(hp_before < field.max_base_hp,
		"`base_hp` 가 이미 최대라 HP 증가가 `mini()` 에 막힌다 — S3 이 공허하다", "S5")

	print("HIDDEN_HEAL summary towers=%d hp %d->%d delta=%d listed=%s new_labels=%s" % [
		field.active_towers.size(), hp_before, hp_after, hp_after - hp_before, str(mentioned), str(new_labels)])
	if failures == 0:
		print("HIDDEN_HEAL_PROBE_OK")
	get_tree().quit(failures)
