# TowerRebuildProbe.gd — 타워 '재건설' 에 등장 팝이 실제로 도는지 잰다.
#
#   godot --headless --path . res://tools/TowerRebuildProbe.tscn
#
# ── 왜 이 프로브가 필요한가 ──────────────────────────────────────────────────
# 감사 §2.9 는 오랫동안 이렇게 적혀 있었다.
#
#     "그런데 그 재건설도 0.8→1.0 팝을 다시 재생한다(트윈이 매번 새로 걸린다)"
#
# 2026-10-03 에 코드를 읽어 보니 **재배치에는 거짓**이었다. 팝은
# `DefenseField.update_towers_from_parsed_list` 의 가드
#     `if previous_words.get(i, "") != item["syllable"]:`
# **안에** 있어서, 음절이 그대로인 재배치는 팝을 돌리지 않는다.
# 그런데 그 정정의 근거는 **코드 읽기뿐**이었고, 그 문장이 §5.2 13(재건설 전용음)
# 이라는 **미결 결정의 전제**를 이루고 있었다. 이 프로브가 전제를 실측으로 바꾼다.
#
# ── 네 가지를 잰다 ───────────────────────────────────────────────────────────
#   A1 양성 대조 — 빈 슬롯에 처음 세우면 팝이 **돈다**     (scale 0.8 에서 시작)
#   A2 주장      — 같은 음절로 다시 세우면 팝이 **안 돈다** (scale 1.0 그대로)
#   A3 교체      — 음절이 바뀌면 팝이 **돈다**
#   A4 실경로    — `move_tower()` → `refresh_tower_synergies()` 를 지나도 **안 돈다**
#
# A1·A3 이 없으면 A2·A4 는 **공짜 통과**다 — 팝을 아예 못 보는 프로브도 "안 돌았다" 고
# 말하기 때문이다. 그래서 양성 대조를 먼저 세운다.
#
# ── 재는 순간이 계약이다 ─────────────────────────────────────────────────────
# `update_towers_from_parsed_list` 는 매 호출마다 타워를 **전부 파괴하고 다시 만든다**.
# 팝 트윈은 `tween_property` 를 건 직후라 **아직 한 프레임도 진행하지 않았다** — 그래서
# 호출 **직후 동기적으로** 읽으면 트윈의 시작값(0.8)이 그대로 보인다. 프레임을 넘기고
# 읽으면 0.22초 트윈이 이미 진행돼 0.8 과 1.0 사이의 값이 나오고, 판정이 흔들린다.
#
# ── 재지 않는 것 ─────────────────────────────────────────────────────────────
# '소리가 없다' 는 여기서 재지 않는다. `move_tower` 의 호출 그래프에 `SoundEngine`
# 호출이 없다는 것은 grep 으로 확인한 **정적 사실**이고(§2.9 정정), 소리를 재려면
# 풀 계수라는 다른 기구가 필요하다. 이 프로브의 주장은 **scale 하나**다.
#
# ── 이 프로브가 기대는 사실 (틀리면 판정이 흔들린다) ─────────────────────────
# 타워 **루트** `scale` 에 쓰는 곳은 프로젝트 전체에서 `DefenseField.gd:1446` 하나뿐이다
# (`grep -rn "\.scale = " scripts/` — 나머지는 `sprite.scale`·`label.scale`·UI 노드).
# 그래서 `active_towers[k].scale.x` 를 읽으면 등장 트윈만 보인다.
#
# 주의: `tools/` 아래라 `SaveManager._is_test_run()` 이 자동으로 참이다(`SaveManager.gd:26`).
extends Node2D

const POP_SCALE := 0.8
const POP_EPS := 0.02
const SETTLE_SEC := 0.30   # 0.22초 트윈이 끝나고도 남는 여유

var failures := 0


## 실패하면 세고, 이유를 콘솔에 찍는다. (push_error 는 'ERROR:' 로 찍힌다 — 정상이다)
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


## 슬롯 순서 `slot` 번째 타워의 루트 scale.x. 없으면 -1.
## `active_towers` 는 `update_towers_from_parsed_list` 의 루프가 **논리 슬롯 순서**로
## append 하므로, 인덱스가 곧 논리 슬롯이다(재배치해도 순서가 안 바뀐다).
func _scale_of(field, slot: int) -> float:
	if slot >= field.active_towers.size():
		return -1.0
	return field.active_towers[slot].scale.x


func _is_pop(v: float) -> bool:
	return absf(v - POP_SCALE) < POP_EPS


func _is_rest(v: float) -> bool:
	return absf(v - 1.0) < POP_EPS


func _unknown(syllable: String) -> Dictionary:
	return {"syllable": syllable, "word_data": {"category": "element", "is_unknown": true}}


func _ready() -> void:
	print("")
	print("=== 타워 재건설 · 등장 팝 실측 ===")
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.defense_field
	if field == null:
		print("TOWER_REBUILD_PROBE_FAIL DefenseField 없음")
		get_tree().quit(1)
		return
	main.set_speed_scale(1.0)
	field.is_wave_running = false
	for i in range(6):
		await get_tree().process_frame

	# ── 무대 정리 ────────────────────────────────────────────────────────────
	# 저장된 진행이 섞이면 '최초 건설' 과 '같은 음절' 을 구분할 수 없다. 슬롯을 비우고
	# 물리 배치를 항등으로 되돌린다(재배치 계약을 재려면 배치가 항등이어야 한다).
	field.update_towers_from_parsed_list([])
	field.unlocked_slot_count = maxi(field.unlocked_slot_count, 2)
	for i in range(field.tower_positions.size()):
		field.tower_positions[i] = i
	check(field.active_towers.is_empty(),
		"무대 정리에 실패했다 — 타워 %d개가 남았다" % field.active_towers.size())
	check(field.tower_positions.size() >= 2,
		"슬롯이 %d개뿐이라 재배치를 잴 수 없다" % field.tower_positions.size())

	# ── A1 양성 대조: 빈 슬롯에 처음 세우면 팝이 돈다 ─────────────────────────
	# 이 단언이 없으면 아래 A2·A4 는 **공짜 통과**다. 팝을 못 보는 프로브도 "안 돌았다" 고 한다.
	field.update_towers_from_parsed_list([_unknown("불")])
	var a1 := _scale_of(field, 0)
	check(field.active_towers.size() == 1,
		"A1 — 타워가 1개 세워지지 않았다: %d" % field.active_towers.size())
	check(_is_pop(a1),
		"A1(양성 대조) — 빈 슬롯에 처음 세웠는데 팝이 안 돌았다 (scale=%.3f, 기대 %.1f). 이 프로브의 탐지기가 고장 났다" % [a1, POP_SCALE])

	# ── A2 주장: 같은 음절로 다시 세우면 팝이 안 돈다 (= 재배치가 지나는 길) ──
	field.update_towers_from_parsed_list([_unknown("불")])
	var a2 := _scale_of(field, 0)
	check(_is_rest(a2),
		"A2 — 같은 음절인데 팝이 돌았다 (scale=%.3f, 기대 1.0). §2.9 정정이 틀렸다 — 재배치도 팝을 낸다" % a2)

	# ── A3 교체: 음절이 바뀌면 팝이 돈다 ─────────────────────────────────────
	field.update_towers_from_parsed_list([_unknown("물")])
	var a3 := _scale_of(field, 0)
	check(_is_pop(a3),
		"A3 — 음절을 바꿨는데 팝이 안 돌았다 (scale=%.3f, 기대 %.1f)" % [a3, POP_SCALE])

	# ── A4 실경로: move_tower() 가 지나는 길 ─────────────────────────────────
	# 두 칸을 서로 다른 음절로 채우고, 트윈이 끝나기를 기다린 뒤 재배치한다.
	field.update_towers_from_parsed_list([_unknown("불"), _unknown("물")])
	check(field.active_towers.size() == 2,
		"A4 준비 — 타워가 2개가 아니다: %d" % field.active_towers.size())
	await get_tree().create_timer(SETTLE_SEC).timeout
	var rest_before := [_scale_of(field, 0), _scale_of(field, 1)]
	check(_is_rest(rest_before[0]) and _is_rest(rest_before[1]),
		"A4 준비 — 트윈이 %.2f초 안에 끝나지 않았다: %s. 기준값이 흔들리면 '팝 없음' 을 판정할 수 없다" % [SETTLE_SEC, str(rest_before)])

	var node_before = field.active_towers[0]
	var moved: bool = field.move_tower(0, 1)
	check(moved, "A4 — move_tower(0,1) 이 false 를 돌려줬다")
	check(field.tower_positions[0] == 1,
		"A4 — 재배치가 실제로 일어나지 않았다 (tower_positions=%s)" % str(field.tower_positions))

	# 실제 경로는 `call_deferred("refresh_tower_synergies")` 다. 직접 부르면 **동기**로
	# 읽을 수 있고, 이어서 프레임을 넘기면 그 deferred 호출이 한 번 더 돈다. 둘 다 재서
	# '동기로만 조용한' 경우를 잡는다.
	field.refresh_tower_synergies()
	var node_after = field.active_towers[0]
	check(node_before != node_after,
		"A4 — 타워가 다시 세워지지 않았다. 그러면 '팝 없음' 은 공짜 통과다")
	var a4_sync := [_scale_of(field, 0), _scale_of(field, 1)]
	check(_is_rest(a4_sync[0]) and _is_rest(a4_sync[1]),
		"A4(동기) — 재배치인데 팝이 돌았다: %s" % str(a4_sync))

	await get_tree().process_frame
	var a4_deferred := [_scale_of(field, 0), _scale_of(field, 1)]
	check(_is_rest(a4_deferred[0]) and _is_rest(a4_deferred[1]),
		"A4(deferred) — 재배치인데 팝이 돌았다: %s" % str(a4_deferred))

	# 재배치가 **음절을 보존했는지** 확인한다 — 음절까지 바뀌면 그건 '교체' 라서 팝이
	# 도는 게 맞고, 이 단언이 없으면 무엇을 쟀는지 알 수 없다.
	var syllables := []
	for t in field.active_towers:
		syllables.append(t.syllable)
	check(syllables == ["불", "물"],
		"A4 — 재배치가 음절을 바꿨다: %s (재배치는 음절을 보존해야 한다)" % str(syllables))

	print("   [실측] A1 최초 건설=%.3f · A2 같은 음절=%.3f · A3 교체=%.3f" % [a1, a2, a3])
	print("   [실측] A4 재배치 동기=%s · deferred=%s" % [str(a4_sync), str(a4_deferred)])
	print("")
	if failures == 0:
		print("TOWER_REBUILD_PROBE_OK")
	else:
		print("TOWER_REBUILD_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
