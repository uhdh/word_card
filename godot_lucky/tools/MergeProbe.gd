extends Node
## 『언어의 조각 : 무한 병합』 규칙 프로브 — 헤드리스로 돈다.
##
##   godot --headless --path godot_lucky res://tools/MergeProbe.tscn
##
## 계약(무엇을 지켜야 하는가):
##   · 경로 = 링 24칸, (0,0) 스폰 → (1,0) 기지, 중복 없음 / 안쪽 5×5 = 배치 슬롯
##   · 가로 한 줄 / 세로 한 열이 **한 줄씩** 파싱돼 단어 타워가 선다 (사전 단어는 matched=true)
##   · 같은 자모·같은 등급 3장 → 1장, 등급 +1
##   · 뽑기 값 = 20 + 5n · 3번째마다 모음 확정 · 골드/빈칸 부족이면 **아무 일도 안 일어난다**
##   · 강화 = 등급×40 · 조합 = 30 (상대 1장 소모) · 판매 = 등급×15
##   · 적이 기지에 닿으면 HP -1, 웨이브를 다 막으면 wave_gold 지급, HP 0 이면 phase="over"
##   · 단어 타워가 사거리 안의 적을 실제로 깎는다
##
## ⚠️ `_after_change()` 를 직접 부른다 — 보드를 손으로 채운 뒤 재계산을 돌리기 위해서다.
##    이 함수는 pull/upgrade/combine/sell/이동 **모두가 지나는 단 하나의 입구**라
##    여기서 부르는 것이 곧 "플레이어가 그 수를 뒀다" 와 같다.

var fails := 0
var checks := 0


func _ready() -> void:
	var g: MergeGame = MergeGame.new()
	g.name = "Game"
	add_child(g)

	_t_path(g)
	_t_coords()
	_t_view(g)
	_t_word_row(g)
	_t_word_col(g)
	_t_word_cross(g)
	_t_auto_merge(g)
	_t_pull_cost(g)
	_t_pull_vowel(g)
	_t_pull_blocked(g)
	_t_upgrade(g)
	_t_combine(g)
	_t_sell(g)
	_t_wave_clear(g)
	_t_tower_kills(g)
	_t_game_over(g)
	_t_reset(g)

	print("PROBE_DONE checks=%d fails=%d" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ══ 도구 ═════════════════════════════════════════════════
func _ck(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   " + label)
	else:
		fails += 1
		print("  FAIL " + label)


func _eq(got: Variant, want: Variant, label: String) -> void:
	_ck(got == want, "%s (want %s, got %s)" % [label, str(want), str(got)])


## 보드를 손으로 채운다. 키 = Vector2i(행, 열).
func _put(g: MergeGame, cell: Vector2i, jamo: String, tier := 1) -> void:
	g.tiles[cell] = {"jamo": jamo, "tier": tier}


func _tower_words(g: MergeGame) -> Array:
	var out: Array = []
	for t in g.towers:
		out.append(str(t["word"]))
	return out


func _find_tower(g: MergeGame, word: String) -> Dictionary:
	for t in g.towers:
		if str(t["word"]) == word:
			return t
	return {}


func _run(g: MergeGame, seconds: float, step := 0.05) -> void:
	var n := int(seconds / step)
	for _i in range(n):
		g.tick(step)


## 가로 4칸짜리 '나무'를 (row, col) 부터 깐다. 나무 = ㄴㅏ / ㅁㅜ (사전어, damage 19).
func _lay_namu_h(g: MergeGame, row: int, col: int) -> void:
	_put(g, Vector2i(row, col), "ㄴ")
	_put(g, Vector2i(row, col + 1), "ㅏ")
	_put(g, Vector2i(row, col + 2), "ㅁ")
	_put(g, Vector2i(row, col + 3), "ㅜ")


# ══ 1. 경로 ══════════════════════════════════════════════
func _t_path(g: MergeGame) -> void:
	print("[경로]")
	_eq(g.path.size(), 24, "링 24칸")
	_eq(g.path[0], Vector2i(0, 0), "path[0] = 스폰 (0,0)")
	_eq(g.path[g.path.size() - 1], Vector2i(1, 0), "path[-1] = 기지 (1,0)")
	_eq(g.path_length(), 23.0, "path_length = 23")
	var uniq := {}
	for c in g.path:
		uniq[c] = true
	_eq(uniq.size(), g.path.size(), "경로 칸 중복 없음")

	var ring_ok := true
	for c in g.path:
		if g.is_inner(c):
			ring_ok = false
	_ck(ring_ok, "경로 칸이 안쪽 슬롯과 겹치지 않음")

	var inner_count := 0
	for r in range(MergeRules.GRID):
		for c in range(MergeRules.GRID):
			if g.is_inner(Vector2i(r, c)):
				inner_count += 1
	_eq(inner_count, 25, "안쪽 슬롯 25칸")
	_eq(MergeRules.GRID * MergeRules.GRID - inner_count, g.path.size(), "49 - 25 = 경로 24칸")


func _t_coords() -> void:
	print("[좌표]")
	_eq(MergeGame.cell_center(Vector2i(0, 0)), Vector2(0.5, 0.5), "cell_center(0,0)")
	_eq(MergeGame.cell_center(Vector2i(6, 6)), Vector2(6.5, 6.5), "cell_center(6,6)")
	_ck(MergeGame.is_inner_cell(Vector2i(3, 3)), "is_inner_cell(3,3) 참")
	_ck(not MergeGame.is_inner_cell(Vector2i(0, 3)), "is_inner_cell(0,3) 거짓")


## 뷰(보드) 좌표계 — 타일·경로·적·타워가 **같은 원점/칸 크기**를 쓰는지.
## 여기가 어긋나면 "적은 경로 위에 있는데 타일은 다른 자리에" 그려진다.
## 픽셀을 눈으로 재는 대신 코드로 잰다 (`tile_rect` 와 `board_px` 를 맞대어 본다).
func _t_view(g: MergeGame) -> void:
	print("[뷰 좌표]")
	var board: MergeBoard = MergeBoard.new()
	add_child(board)
	board.size = Vector2(700.0, 700.0)
	board.call("_compute")
	board.game = g

	var worst := 0.0
	for r in range(MergeRules.GRID):
		for c in range(MergeRules.GRID):
			var cell := Vector2i(r, c)
			var d := board.tile_rect(cell).get_center().distance_to(
				board.board_px(MergeGame.cell_center(cell)))
			worst = maxf(worst, d)
	_ck(worst < 0.01, "tile_rect 중심 == board_px(cell_center) (최대 오차 %.4f px)" % worst)

	var path_ok := true
	for i in range(g.path.size()):
		if not board.tile_rect(g.path[i]).has_point(board.board_px(g.path_pos(float(i)))):
			path_ok = false
	_ck(path_ok, "경로 위치가 경로 칸 안에 있다")

	g.reset()
	_lay_namu_h(g, 5, 1)
	g._after_change()
	var t := _find_tower(g, "나무")
	if not t.is_empty():
		var cells: Array = t["cells"]
		var box: Rect2 = board.tile_rect(cells[0])
		for cell in cells:
			box = box.merge(board.tile_rect(cell))
		_ck(box.has_point(board.board_px(Vector2(t["pos"]))),
			"타워 중심이 자기 칸 묶음 안에 있다")

	# 보드(7×7)가 뷰 크기를 넘지 않는다 — 넘으면 시안 고리 밖으로 그려진다.
	var span := board.board_px(Vector2(0.0, 0.0)) + Vector2(700.0, 700.0)
	_ck(span.x <= board.size.x + 0.01 and span.y <= board.size.y + 0.01,
		"보드 7×7 이 뷰 안에 들어간다")
	board.queue_free()
	g.reset()


# ══ 2. 단어 판정 ═════════════════════════════════════════
func _t_word_row(g: MergeGame) -> void:
	print("[단어 — 가로]")
	g.reset()
	_lay_namu_h(g, 1, 1)
	g._after_change()

	_eq(_tower_words(g), ["나무"], "ㄴㅏㅁㅜ 한 줄 → 나무 타워 하나")
	var t := _find_tower(g, "나무")
	if t.is_empty():
		return
	_ck(bool(t["matched"]), "사전 단어라 matched=true")
	_eq(str(t["source"]), "rule", "형태 출처 = rule (이름의 '대지' 키워드)")
	_eq(str(t["trait"]), "splash", "trait = splash (대지)")
	_eq(str(t["label"]), "대지", "라벨 = 대지")
	_eq(float(t["damage"]), 19.0, "피해 = 사전값 19 (등급 1 → 배수 1.0)")
	_eq((t["cells"] as Array).size(), 4, "타워가 4칸을 차지")
	_eq(t["pos"], Vector2(3.0, 1.5), "타워 중심 = 4칸 평균")


func _t_word_col(g: MergeGame) -> void:
	print("[단어 — 세로]")
	g.reset()
	_put(g, Vector2i(1, 1), "ㄴ")
	_put(g, Vector2i(2, 1), "ㅏ")
	_put(g, Vector2i(3, 1), "ㅁ")
	_put(g, Vector2i(4, 1), "ㅜ")
	g._after_change()
	_eq(_tower_words(g), ["나무"], "세로 한 열도 같은 단어")


func _t_word_cross(g: MergeGame) -> void:
	print("[단어 — 교차]")
	g.reset()
	_lay_namu_h(g, 1, 1)                 # 가로: (1,1)~(1,4)
	_put(g, Vector2i(2, 4), "ㄴ")        # 세로: (2,4)~(5,4)
	_put(g, Vector2i(3, 4), "ㅏ")
	_put(g, Vector2i(4, 4), "ㅁ")
	_put(g, Vector2i(5, 4), "ㅜ")
	g._after_change()
	_eq(_tower_words(g).size(), 2, "가로·세로가 각각 타워 → 2개")
	_eq(_tower_words(g).count("나무"), 2, "둘 다 나무")

	# 한 칸짜리는 타워가 되지 않는다
	g.reset()
	_put(g, Vector2i(3, 3), "ㄱ")
	g._after_change()
	_eq(g.towers.size(), 0, "한 칸짜리 자모는 타워가 아니다")


# ══ 3. 자동 병합 ═════════════════════════════════════════
func _t_auto_merge(g: MergeGame) -> void:
	print("[자동 병합]")
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ")
	_put(g, Vector2i(1, 2), "ㄱ")
	_put(g, Vector2i(1, 3), "ㄱ")
	g._after_change()
	_eq(g.tile_count(), 1, "같은 자모·등급 3장 → 1장")
	_eq(int(g.tiles[Vector2i(1, 1)]["tier"]), 2, "남은 타일 등급 2")
	_eq(str(g.tiles[Vector2i(1, 1)]["jamo"]), "ㄱ", "자모는 그대로")

	# 등급이 다르면 안 합쳐진다
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 1)
	_put(g, Vector2i(1, 2), "ㄱ", 1)
	_put(g, Vector2i(1, 3), "ㄱ", 2)
	g._after_change()
	_eq(g.tile_count(), 3, "등급이 다르면 병합 없음")

	# 자모가 다르면 안 합쳐진다
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ")
	_put(g, Vector2i(1, 2), "ㄴ")
	_put(g, Vector2i(1, 3), "ㄷ")
	g._after_change()
	_eq(g.tile_count(), 3, "자모가 다르면 병합 없음")

	# 9장 → 연쇄 병합으로 1장 등급 3
	g.reset()
	var nine := [
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
		Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
		Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3),
	]
	for c in nine:
		_put(g, c, "ㄱ")
	g._after_change()
	_eq(g.tile_count(), 1, "9장 → 연쇄 병합 1장")
	_eq(int(g.tiles[Vector2i(1, 1)]["tier"]), 3, "연쇄 병합 등급 3")


# ══ 4. 뽑기 ══════════════════════════════════════════════
func _t_pull_cost(g: MergeGame) -> void:
	print("[뽑기 — 값]")
	g.reset()
	_eq(g.gold, 120, "시작 골드 120")
	var want := MergeRules.START_GOLD
	for i in range(3):
		var before := g.tile_count()
		var err := g.pull()
		_eq(err, "", "%d번째 뽑기 성공" % (i + 1))
		want -= MergeRules.pull_cost(i)
		_eq(g.gold, want, "%d번째 뽑기 뒤 골드" % (i + 1))
		_ck(g.tile_count() >= before, "타일이 줄지는 않음")
	_eq(g.pull_count, 3, "pull_count 3")
	_eq(MergeRules.pull_cost(0), 20, "첫 뽑기 20 G")
	_eq(MergeRules.pull_cost(3), 35, "네 번째 뽑기 35 G")


func _t_pull_vowel(g: MergeGame) -> void:
	print("[뽑기 — 모음 확정]")
	g.reset()
	# 3번째 뽑기가 되도록 맞춰 두고 보드를 비워 병합 변수를 없앤다.
	g.pull_count = MergeRules.PULL_VOWEL_EVERY - 1
	g.tiles.clear()
	var err := g.pull()
	_eq(err, "", "3번째 뽑기 성공")
	_eq(g.tile_count(), 1, "타일 1장")
	if g.tile_count() == 1:
		var only: Dictionary = g.tiles.values()[0]
		_ck(HangulEngine.VOWEL_POOL.has(str(only["jamo"])),
			"3번째 뽑기는 모음 (got %s)" % str(only["jamo"]))


func _t_pull_blocked(g: MergeGame) -> void:
	print("[뽑기 — 거절]")
	g.reset()
	g.gold = 0
	var before := g.tile_count()
	var err := g.pull()
	_ck(err != "", "골드 0 이면 거절: %s" % err)
	_eq(g.tile_count(), before, "거절되면 타일이 안 생긴다")
	_eq(g.gold, 0, "거절되면 골드가 안 빠진다")
	_eq(g.pull_count, 0, "거절되면 pull_count 가 안 오른다")

	g.reset()
	for r in range(1, MergeRules.INNER + 1):
		for c in range(1, MergeRules.INNER + 1):
			_put(g, Vector2i(r, c), "ㄱ")
	g.gold = 9999
	err = g.pull()
	_ck(err != "", "빈 칸이 없으면 거절: %s" % err)
	_eq(g.gold, 9999, "거절되면 골드가 안 빠진다")


# ══ 5. 강화 / 조합 / 판매 ════════════════════════════════
func _t_upgrade(g: MergeGame) -> void:
	print("[강화]")
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 1)
	g.selected = Vector2i(1, 1)
	var gold0 := g.gold
	var err := g.upgrade()
	_eq(err, "", "강화 성공")
	_eq(int(g.tiles[Vector2i(1, 1)]["tier"]), 2, "등급 1 → 2")
	_eq(g.gold, gold0 - MergeRules.UPGRADE_COST_PER_TIER, "값 = 등급×40 = 40")

	g.selected = Vector2i(-1, -1)
	err = g.upgrade()
	_ck(err != "", "선택 없으면 거절: %s" % err)

	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", MergeRules.MAX_TIER)
	g.selected = Vector2i(1, 1)
	err = g.upgrade()
	_ck(err != "", "최고 등급이면 거절: %s" % err)

	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 3)
	g.selected = Vector2i(1, 1)
	g.gold = 10
	err = g.upgrade()
	_ck(err != "", "골드 부족이면 거절: %s" % err)
	_eq(int(g.tiles[Vector2i(1, 1)]["tier"]), 3, "거절되면 등급이 안 오른다")
	_eq(g.gold, 10, "거절되면 골드가 안 빠진다")


func _t_combine(g: MergeGame) -> void:
	print("[조합]")
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 1)
	_put(g, Vector2i(1, 2), "ㄱ", 1)
	g.selected = Vector2i(1, 1)
	var gold0 := g.gold
	var err := g.combine()
	_eq(err, "", "조합 성공")
	_eq(g.tile_count(), 1, "상대 1장 소모 → 1장")
	_eq(int(g.tiles[Vector2i(1, 1)]["tier"]), 2, "등급 1 → 2")
	_eq(g.gold, gold0 - MergeRules.COMBINE_COST, "값 = 30")

	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 1)
	g.selected = Vector2i(1, 1)
	gold0 = g.gold
	err = g.combine()
	_ck(err != "", "짝이 없으면 거절: %s" % err)
	_eq(g.gold, gold0, "거절되면 골드가 안 빠진다")

	# 등급이 다르면 짝이 아니다
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 1)
	_put(g, Vector2i(1, 2), "ㄱ", 2)
	g.selected = Vector2i(1, 1)
	err = g.combine()
	_ck(err != "", "등급이 다른 같은 자모는 짝이 아니다: %s" % err)


func _t_sell(g: MergeGame) -> void:
	print("[판매]")
	g.reset()
	_put(g, Vector2i(1, 1), "ㄱ", 3)
	g.selected = Vector2i(1, 1)
	var gold0 := g.gold
	var err := g.sell()
	_eq(err, "", "판매 성공")
	_eq(g.tile_count(), 0, "타일이 사라진다")
	_eq(g.gold, gold0 + 3 * MergeRules.SELL_GOLD_PER_TIER, "환급 = 등급×15 = 45")
	_eq(g.selected, Vector2i(-1, -1), "판매 뒤 선택 해제")


# ══ 6. 웨이브 ════════════════════════════════════════════
func _t_wave_clear(g: MergeGame) -> void:
	print("[웨이브 — 타워 없이]")
	g.reset()
	g.tiles.clear()
	g._after_change()
	g.start_wave()
	_eq(g.wave, 1, "wave = 1")
	_eq(g.phase, "wave", "phase = wave")
	_eq(g.pending, MergeRules.enemy_count(1), "pending = enemy_count(1) = 5")

	_run(g, 60.0)
	_eq(g.phase, "planning", "다 막으면 planning 으로")
	_eq(g.base_hp, MergeRules.START_HP - MergeRules.enemy_count(1), "적 수만큼 HP 감소 (50 → 45)")
	_eq(g.gold, MergeRules.START_GOLD + MergeRules.wave_gold(1), "웨이브 보상 지급 (120 → 151)")
	_eq(g.enemies.size(), 0, "적이 남지 않는다")

	# 진행 중에는 start_wave 가 무시된다
	g.start_wave()
	_eq(g.wave, 2, "2라운드 시작")
	g.start_wave()
	_eq(g.wave, 2, "진행 중에는 start_wave 가 무시된다")
	_run(g, 90.0)
	_eq(g.phase, "planning", "2라운드도 끝난다")
	g.start_wave()
	_eq(g.wave, 3, "끝난 뒤에는 다음 라운드가 열린다")
	_run(g, 90.0)

	_ck(MergeRules.is_boss_wave(5), "5라운드는 보스")
	_ck(not MergeRules.is_boss_wave(4), "4라운드는 보스 아님")
	_ck(MergeRules.enemy_hp(5) > MergeRules.enemy_hp(4), "HP 가 라운드마다 오른다")


func _t_tower_kills(g: MergeGame) -> void:
	print("[웨이브 — 타워 있음]")
	g.reset()
	_lay_namu_h(g, 1, 1)
	g._after_change()
	_eq(_tower_words(g), ["나무"], "나무 타워가 서 있다")
	var t := _find_tower(g, "나무")
	var rng := float(t.get("range", 0.0))
	_ck(g.path_pos(3.0).distance_to(Vector2(t["pos"])) <= rng, "위쪽 경로가 사거리 안")

	g.start_wave()
	_run(g, 60.0)
	_eq(g.phase, "planning", "웨이브 종료")
	var kill_gold := g.gold - MergeRules.START_GOLD - MergeRules.wave_gold(1)
	_ck(kill_gold > 0, "타워가 적을 잡아 처치 골드가 들어온다 (%d G)" % kill_gold)
	_eq(kill_gold % MergeRules.GOLD_PER_KILL, 0, "처치 골드가 3의 배수")
	_ck(g.base_hp > MergeRules.START_HP - MergeRules.enemy_count(1),
		"타워가 있으면 기지가 덜 맞는다 (HP %d/50)" % g.base_hp)


func _t_game_over(g: MergeGame) -> void:
	print("[게임 오버]")
	g.reset()
	var fired := [false]
	g.game_over.connect(func() -> void: fired[0] = true)
	g.tiles.clear()
	g._after_change()
	g.base_hp = 1
	g.start_wave()
	_run(g, 60.0)
	_eq(g.phase, "over", "기지 HP 0 → phase = over")
	_eq(g.base_hp, 0, "HP 는 0 으로 고정")
	_ck(fired[0], "game_over 시그널 발화")
	var hp := g.base_hp
	_run(g, 5.0)
	_eq(g.base_hp, hp, "끝난 뒤에는 더 안 깎인다")


# ══ 7. 초기화 ════════════════════════════════════════════
func _t_reset(g: MergeGame) -> void:
	print("[초기화]")
	g.reset()
	_eq(g.gold, MergeRules.START_GOLD, "골드 복구")
	_eq(g.base_hp, MergeRules.START_HP, "HP 복구")
	_eq(g.wave, 0, "wave 0")
	_eq(g.phase, "planning", "phase planning")
	_eq(g.pull_count, 0, "pull_count 0")
	_eq(g.tile_count(), 0, "타일 없음")
	_eq(g.towers.size(), 0, "타워 없음")
	_eq(g.enemies.size(), 0, "적 없음")
	_eq(g.selected, Vector2i(-1, -1), "선택 없음")
	_eq(g.path.size(), 24, "경로는 살아 있다")
