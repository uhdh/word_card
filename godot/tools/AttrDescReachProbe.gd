extends Node
# `ATTR_INFO.desc` — **네 문장이 화면에 도달하지 않는다** (§2.19 의 세 번째 조각).
#
# ── 왜 `CounterThresholdProbe` 에서 갈라져 나왔나 ────────────────────────────
# `tools/CounterThresholdProbe` 는 §2.19 의 세 조각을 함께 쟀다:
#   ① 예고와 피해 숫자의 임계가 **두 벌**이다            → **2026-09-26 고쳤다** (S1·S2·S3)
#   ② 손으로 적은 `splitter` 목록이 **항목을 빠뜨렸다**   → **같은 날 고쳤다** (S4)
#   ③ `ATTR_INFO.desc` 가 **플레이어에게 도달하지 않는다** → **이 파일** (S5)
# ①②는 "표 대 표" 의 문제라 코드만 맞추면 끝났다. ③은 **화면에 무엇을 어디에 그릴지** 의
# 문제라 **설계 결정**이었고, 그래서 감사 §5.2 31 의 선택지 **(B)** 로 남아 있었다.
#
# ## ✅ 고침 — §5.2 31 (B), 2026-10-01
#
# 감독이 (B) 를 골라 **멈춰 있는 표면 두 곳**에 붙였다:
#   · 상단 `btn_stage` **툴팁**  (`_refresh_stage_tooltip`)
#   · **라운드 정보 모달**        (`_on_stage_btn_pressed`)
# 둘 다 문구는 `DefenseField.next_round_attr_desc()` → `MonsterRoster.attr_desc_text(act)`
# **한 함수**가 만든다 — 손으로 두 번 적으면 §2.18 의 드리프트가 그대로 재발한다.
#
# ## 왜 배지 툴팁이 아닌가 (기각된 안)
#   · 배지는 **적 머리 위**라 `MOUSE_FILTER_IGNORE` 다 — 풀면 적 클릭을 가로챈다.
#   · 풀더라도 **움직이는 10px 배지에 호버**를 요구하는 것은 신뢰할 수 없는 UX 다.
#
# ## ⚠️ 이 프로브가 이제 재는 것 — `mouse_filter` 까지 본다
#   첫 판은 `tooltip_text` **문자열**만 봤다. 그러면 *"문자열만 넣고 `IGNORE` 로 둔"* 상태를
#   **초록으로 통과시킨다** — 프로브는 통과인데 플레이어는 아무것도 못 본다.
#   지금은 툴팁을 단 노드의 `mouse_filter` 가 `IGNORE` 면 **`tooltip-dead`** 로 찍고
#   도달로 세지 않는다. 헤드리스에 마우스가 없어도 *"호버가 가능한가"* 는 이렇게 잰다.
#
# 실행: godot --headless --path . res://tools/AttrDescReachProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

var failures := 0

## 절 태그를 함께 찍는다 — 주입 표의 "걸린 절" 이 기계로 구분되어야 한다(§2.17).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

## 트리 전체에서 `needle` 을 포함하는 텍스트를 찾는다.
## **도달 가능성**을 구분해 보고한다 — 보이는 라벨 / 숨은 라벨 / 툴팁(호버해야 보인다).
##
## ⚠️ 툴팁은 `mouse_filter` 까지 본다 — `IGNORE` 면 마우스가 지나가 버려 **영영 안 뜬다**.
func _find_text(root: Node, needle: String, hits: Array, path: String = "") -> void:
	var here := path + "/" + str(root.name)
	if root is Label and str((root as Label).text).contains(needle):
		hits.append(("label-visible" if (root as Label).is_visible_in_tree() else "label-hidden") + here)
	if root is Control and str((root as Control).tooltip_text).contains(needle):
		var dead := (root as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
		hits.append(("tooltip-dead" if dead else "tooltip") + here)
	for c in root.get_children():
		_find_text(c, needle, hits, here)

## 그 막에 실제로 등장하는 속성 id 목록(중복 제거 · `warded:control` → `warded`).
func _attrs_of(act: int) -> Array:
	var out: Array = []
	for entry in MonsterRoster.entries_for(act):
		for attr in entry.get("attrs", []):
			var text := str(attr)
			var base := text.substr(0, text.find(":")) if text.find(":") >= 0 else text
			if not out.has(base):
				out.append(base)
	return out

func _ready() -> void:
	# 이 프로브는 소리를 재지 않는다 — 소음만 막는다. (설정 파일은 안 건드린다: 필드 대입.)
	SoundEngine.muted = true
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
	var field = main.defense_field
	# 속성을 전부 단 적을 하나 만든다 — 배지가 생길 기회를 준다(배지 자체는 이제 채널이 아니지만,
	# `attrs` 가 실린 적이 화면에 있어야 "표본이 없어서 못 찾았다" 와 구별된다).
	field.current_wave = 0
	field.start_next_wave()
	await get_tree().process_frame
	var sample: Dictionary = MonsterRoster.regular_entry(1, 0, 10.0, 1.0, 1.0)
	sample["name"] = "속성 표본"
	sample["attrs"] = ["regen", "splitter", "swift", "warded:pierce"]
	field._spawn_enemy(sample)
	await get_tree().process_frame
	await get_tree().process_frame

	# ── S5 `ATTR_INFO.desc` 가 플레이어에게 도달하는가 ───────────────────────
	# 코드를 읽는 게 아니라 **화면을 뒤진다** — 소비 코드가 0건이라는 사실과
	# 화면에 없다는 사실은 다른 주장이고, 플레이어에게 중요한 것은 후자다.
	#
	# ⚠️ **그 막에 실제로 오는 속성만** 잰다. 1막에는 `swift`·`regen` 둘뿐이고
	#    `splitter`·`warded` 는 2막에 처음 나온다 — 아직 안 나온 속성의 설명은 예고가 아니다.
	var act: int = field.next_round_act()
	var wanted := _attrs_of(act)
	print("ATTR_DESC act=%d attrs=%s" % [act, str(wanted)])
	var desc_hits: Dictionary = {}
	var unreached: Array = []
	for attr_id in wanted:
		var desc := str(MonsterRoster.ATTR_INFO.get(attr_id, {}).get("desc", ""))
		if desc == "":
			continue
		var hits: Array = []
		_find_text(main, desc, hits)
		desc_hits[str(attr_id)] = hits
		print("ATTR_DESC attr=%s len=%d hits=%s" % [attr_id, desc.length(), str(hits)])
		var ok := false
		for h in hits:
			var s := str(h)
			# ⚠️ `begins_with("tooltip")` 로 쓰면 **`tooltip-dead` 도 통과**한다 — 죽은 툴팁을
			#    살아 있는 것으로 세게 된다. 구분자는 `/` 다(첫 판이 이걸로 주입 I3 을 놓쳤다).
			if s.begins_with("label-visible") or s.begins_with("tooltip/"):
				ok = true
		if not ok:
			unreached.append(str(attr_id))
	print("ATTR_DESC summary descs=%d unreached=%s" % [desc_hits.size(), str(unreached)])
	check(not desc_hits.is_empty(),
		"그 막에 설명 문장이 달린 속성이 하나도 없다 — S5 가 공허하다", "S5")
	check(unreached.is_empty(),
		"`ATTR_INFO` 설명 %d개 중 %s 가 **플레이어에게 도달하지 않는다** — 배지 이름과 상성 목록은 보이는데 '그게 무슨 뜻인지' 는 못 본다 (감사 §2.19-3 · §5.2 31 (B))" % [
			desc_hits.size(), str(unreached)], "S5")

	# ── S6 비공허성 ──────────────────────────────────────────────────────────
	# 이 프로브의 전제 셋: ① 표에 설명 문장이 있어야 하고 ② 표본 적이 실제로 화면에 있어야 하고
	# ③ 그 막에 속성이 실제로 등장해야 한다.
	# ②가 없으면 '배지가 없어서 못 찾았다' 와 '설명이 배선되지 않아서 못 찾았다' 가 구별되지 않는다.
	check(not desc_hits.is_empty(), "`ATTR_INFO` 에 설명 문장이 하나도 없다 — S5 가 공허하다", "S6")
	var alive: Array = field.get_enemies()
	print("ATTR_DESC sample enemies=%d attrs=%s" % [alive.size(), str(sample.get("attrs", []))])
	check(alive.size() > 0, "표본 적이 화면에 없다 — 트리 탐색이 공허하다(속성을 실은 적이 안 생겼다)", "S6")
	check(not (sample.get("attrs", []) as Array).is_empty(), "표본에 속성을 안 실었다 — 배지가 생길 기회 자체가 없다", "S6")
	# ③ — 표에 `desc` 가 있는데 그 막에 안 오는 속성이 있으면, 위 S5 는 그 속성을 **안 잰다**.
	#    그 사실을 숨기지 않는다(감사 §2.19-3 이 "네 문장" 이라 적었으므로 수를 밝힌다).
	var all_desc: Array = []
	for attr_id in MonsterRoster.ATTR_INFO:
		if str(MonsterRoster.ATTR_INFO[attr_id].get("desc", "")) != "":
			all_desc.append(str(attr_id))
	print("ATTR_DESC coverage act_attrs=%d table_descs=%s measured=%s"
		% [wanted.size(), str(all_desc), str(desc_hits.keys())])
	# ④ — 표의 모든 `desc` 가 **어떤 막에서는** 나오는가. 어떤 속성이 어느 막에도 없으면
	#    그 문장은 영원히 도달 불가인데, 위 S5 는 **그 막만** 재므로 그걸 못 잡는다.
	#    (표에 속성을 추가하고 어느 막에도 안 넣는 실수 — §2.18 의 드리프트와 같은 부류.)
	var never: Array = []
	for attr_id in all_desc:
		var found := false
		for a in MonsterRoster.ACTS:
			if _attrs_of(int(a)).has(attr_id):
				found = true
		if not found:
			never.append(attr_id)
	check(never.is_empty(),
		"표에 설명이 있는데 **어느 막에도 안 나오는** 속성: %s — 그 문장은 영원히 도달 불가다" % str(never), "S6")

	# ── S7 두 번째 채널 — 라운드 정보 모달 ──────────────────────────────────
	# 툴팁은 **호버해야** 보이고, 모달은 클릭 한 번으로 **읽을 자리**다. 둘 다 있으므로 둘 다
	# 잰다 — 하나만 지키면 나머지 하나가 조용히 죽어도 초록이다(§2.13-1 의 교훈).
	main._on_stage_btn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	var modal_unreached: Array = []
	for attr_id in desc_hits.keys():
		var desc2 := str(MonsterRoster.ATTR_INFO[attr_id].get("desc", ""))
		var hits2: Array = []
		_find_text(main, desc2, hits2)
		var ok2 := false
		for h in hits2:
			if str(h).begins_with("label-visible"):
				ok2 = true
		if not ok2:
			modal_unreached.append(str(attr_id))
	print("ATTR_DESC modal unreached=%s" % str(modal_unreached))
	check(modal_unreached.is_empty(),
		"라운드 정보 모달에 속성 설명이 안 뜬다: %s — 툴팁만으로는 호버해야 보인다" % str(modal_unreached), "S7")

	if failures == 0:
		print("ATTR_DESC_PROBE_OK")
	get_tree().quit(failures)
