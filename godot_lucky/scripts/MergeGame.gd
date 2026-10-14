class_name MergeGame
extends Node
## 『언어의 조각 : 무한 병합』의 **규칙과 상태 전부**. 화면(그리기)은 여기 없다.
##
## 무대 = 참고 영상(그리드 병합 랜덤 디펜스) · 자모→단어 = 기존 게임에서 **그대로** 가져왔다.
##   · 뽑기        → 자모 1장이 빈 칸에 놓인다 (`HangulEngine.get_weighted_random_jamo`)
##   · 병합        → 같은 자모·같은 등급 3장이 모이면 1장이 되고 등급 +1
##   · 단어        → 안쪽 가로 5줄·세로 5열을 **한 줄씩** `HangulStreamParser` 로 파싱.
##                   사전에 있는 단어면 그 뜻이 공격 형태를 정한다(`AttackStyle`).
##   · 그 줄이 곧 **단어 타워**다 — 사거리 안의 적을 쏜다.
##
## ⚠️ 좌표 규약: 셀은 `Vector2i(행, 열)` (x=행, y=열). 화면 좌표는 `cell_center()` 로 바꾼다.

signal changed                      ## 다시 그려야 한다
signal message(text: String)        ## 화면에 한 줄 알림
signal base_hit()                   ## 기지가 맞았다
signal game_over()                  ## 기지 HP 0

const INNER := MergeRules.INNER

# ── 자원 ────────────────────────────────────────────────
var gold := MergeRules.START_GOLD
var base_hp := MergeRules.START_HP
var wave := 0
var phase := "planning"             ## planning | wave | over
var pull_count := 0

# ── 보드 ────────────────────────────────────────────────
## 키: Vector2i(행, 열) — 안쪽 1..5. 값: {"jamo": String, "tier": int}
var tiles: Dictionary = {}
var selected := Vector2i(-1, -1)

# ── 경로 ────────────────────────────────────────────────
## 링 24칸, (0,0) 스폰 → … → (1,0) 기지.
var path: Array = []

# ── 전투 ────────────────────────────────────────────────
var towers: Array = []      ## _recompute_towers() 가 채운다
var enemies: Array = []
var shots: Array = []       ## {"a","b","t","color","r"} — 연출용 궤적
var pending := 0            ## 이번 웨이브에서 아직 안 나온 적 수
var spawn_timer := 0.0


func _ready() -> void:
	_build_path()
	reset()


func reset() -> void:
	gold = MergeRules.START_GOLD
	base_hp = MergeRules.START_HP
	wave = 0
	phase = "planning"
	pull_count = 0
	tiles.clear()
	selected = Vector2i(-1, -1)
	towers.clear()
	enemies.clear()
	shots.clear()
	pending = 0
	spawn_timer = 0.0
	_recompute_towers()
	changed.emit()


func _build_path() -> void:
	path.clear()
	var n := MergeRules.GRID
	for c in range(n):
		path.append(Vector2i(0, c))                      # 위 (0,0) → (0,6)
	for r in range(1, n):
		path.append(Vector2i(r, n - 1))                  # 오른쪽 (1,6) → (6,6)
	for c in range(n - 2, -1, -1):
		path.append(Vector2i(n - 1, c))                  # 아래 (6,5) → (6,0)
	for r in range(n - 2, 0, -1):
		path.append(Vector2i(r, 0))                      # 왼쪽 (5,0) → (1,0) = 기지


# ══ 좌표 ═════════════════════════════════════════════════
## 셀 → 보드 좌표(칸 단위). (0,0) 칸의 중심이 (0.5, 0.5).
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.y) + 0.5, float(cell.x) + 0.5)


## 경로를 따라 d 만큼 간 위치(칸 단위).
func path_pos(d: float) -> Vector2:
	var last := path.size() - 1
	if last < 1:
		return Vector2.ZERO
	var i := clampi(int(floor(d)), 0, last - 1)
	var f := clampf(d - float(i), 0.0, 1.0)
	return cell_center(path[i]).lerp(cell_center(path[i + 1]), f)


func path_length() -> float:
	return float(maxi(path.size() - 1, 0))


func is_inner(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= INNER and cell.y >= 1 and cell.y <= INNER


## 정적 판정 — 보드(뷰)가 인스턴스 없이 쓴다.
static func is_inner_cell(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= MergeRules.INNER and cell.y >= 1 and cell.y <= MergeRules.INNER


# ══ 조작 ═════════════════════════════════════════════════
## 칸을 눌렀다. 빈 칸을 누르면 고른 타일이 그리로 **옮겨진다**(단어 배치가 퍼즐이 되게).
func click_slot(cell: Vector2i) -> void:
	if not is_inner(cell):
		selected = Vector2i(-1, -1)
		changed.emit()
		return
	if tiles.has(cell):
		selected = cell
	elif selected.x >= 0 and tiles.has(selected):
		tiles[cell] = tiles[selected]
		tiles.erase(selected)
		selected = cell
		_after_change()
		return
	else:
		selected = Vector2i(-1, -1)
	changed.emit()


func pull() -> String:
	if phase == "over":
		return "게임이 끝났습니다"
	var cost := MergeRules.pull_cost(pull_count)
	if gold < cost:
		return "골드가 부족합니다 (%d G)" % cost
	var empty := _empty_cells()
	if empty.is_empty():
		return "빈 칸이 없습니다 — 팔거나 합치세요"
	pull_count += 1
	gold -= cost
	# ⚠️ 모음이 안 나오면 자음만 쌓여 단어가 영영 안 선다 → 주기적으로 확정 지급.
	var jamo: String
	if pull_count % MergeRules.PULL_VOWEL_EVERY == 0:
		jamo = HangulEngine.get_weighted_random_jamo(HangulEngine.VOWEL_POOL)
	else:
		jamo = HangulEngine.get_weighted_random_jamo()
	var cell: Vector2i = empty[randi() % empty.size()]
	tiles[cell] = {"jamo": jamo, "tier": 1}
	_after_change()
	return ""


func upgrade() -> String:
	var t := _selected_tile()
	if t.is_empty():
		return "타일을 먼저 고르세요"
	var tier := int(t["tier"])
	if tier >= MergeRules.MAX_TIER:
		return "최고 등급입니다"
	var cost := tier * MergeRules.UPGRADE_COST_PER_TIER
	if gold < cost:
		return "골드가 부족합니다 (%d G)" % cost
	gold -= cost
	t["tier"] = tier + 1
	_after_change()
	return ""


func combine() -> String:
	var t := _selected_tile()
	if t.is_empty():
		return "타일을 먼저 고르세요"
	var tier := int(t["tier"])
	if tier >= MergeRules.MAX_TIER:
		return "최고 등급입니다"
	var partner := Vector2i(-1, -1)
	for cell in tiles:
		if cell == selected:
			continue
		var o: Dictionary = tiles[cell]
		if str(o["jamo"]) == str(t["jamo"]) and int(o["tier"]) == tier:
			partner = cell
			break
	if partner.x < 0:
		return "같은 자모·같은 등급이 한 장 더 필요합니다"
	if gold < MergeRules.COMBINE_COST:
		return "골드가 부족합니다 (%d G)" % MergeRules.COMBINE_COST
	gold -= MergeRules.COMBINE_COST
	tiles.erase(partner)
	t["tier"] = tier + 1
	_after_change()
	return ""


func sell() -> String:
	var t := _selected_tile()
	if t.is_empty():
		return "타일을 먼저 고르세요"
	var gain := int(t["tier"]) * MergeRules.SELL_GOLD_PER_TIER
	gold += gain
	tiles.erase(selected)
	selected = Vector2i(-1, -1)
	_after_change()
	return ""


func start_wave() -> void:
	if phase != "planning":
		return
	wave += 1
	phase = "wave"
	pending = MergeRules.enemy_count(wave)
	spawn_timer = 0.0
	changed.emit()


# ══ 진행 ═════════════════════════════════════════════════
func tick(delta: float) -> void:
	if phase == "over":
		return
	_tick_shots(delta)
	if phase != "wave":
		return
	_tick_spawn(delta)
	_tick_enemies(delta)
	if phase != "wave":          ## _tick_enemies 가 게임을 끝냈을 수 있다
		return
	_tick_towers(delta)
	if pending <= 0 and enemies.is_empty():
		_end_wave()


func _tick_spawn(delta: float) -> void:
	if pending <= 0:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = MergeRules.SPAWN_INTERVAL
	pending -= 1
	var is_boss := MergeRules.is_boss_wave(wave) and pending <= 0
	var hp := MergeRules.enemy_hp(wave) * (MergeRules.BOSS_HP_MULT if is_boss else 1.0)
	enemies.append({
		"d": 0.0, "hp": hp, "max_hp": hp,
		"speed": MergeRules.ENEMY_SPEED_CELLS * (MergeRules.BOSS_SPEED_MULT if is_boss else 1.0),
		"is_boss": is_boss,
		"slow_t": 0.0, "burn_dps": 0.0, "burn_t": 0.0,
		"dead": false, "reached": false,
	})


func _tick_enemies(delta: float) -> void:
	var last := path_length()
	for e in enemies:
		if bool(e["dead"]):
			continue
		var bt := float(e["burn_t"])
		if bt > 0.0:
			var step := minf(delta, bt)
			e["hp"] = float(e["hp"]) - float(e["burn_dps"]) * step
			e["burn_t"] = bt - delta
			if float(e["hp"]) <= 0.0:
				e["dead"] = true
				continue
		var mult := 1.0
		var st := float(e["slow_t"])
		if st > 0.0:
			mult = MergeRules.SLOW_MULT
			e["slow_t"] = st - delta
		e["d"] = float(e["d"]) + float(e["speed"]) * mult * delta
		if float(e["d"]) >= last:
			e["dead"] = true
			e["reached"] = true
			base_hp -= MergeRules.BOSS_DAMAGE if bool(e["is_boss"]) else MergeRules.ENEMY_DAMAGE
			base_hit.emit()
	_cleanup_dead()
	if base_hp <= 0:
		base_hp = 0
		phase = "over"
		game_over.emit()
		changed.emit()


func _tick_towers(delta: float) -> void:
	for t in towers:
		t["cd"] = float(t["cd"]) - delta
		if float(t["cd"]) > 0.0:
			continue
		var target := _find_target(Vector2(t["pos"]), float(t["range"]))
		if target.is_empty():
			t["cd"] = 0.0
			continue
		t["cd"] = float(t["interval"])
		_fire(t, target)


func _tick_shots(delta: float) -> void:
	if shots.is_empty():
		return
	var alive: Array = []
	for s in shots:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) < MergeRules.SHOT_LIFE:
			alive.append(s)
	shots = alive


func _end_wave() -> void:
	var g := MergeRules.wave_gold(wave)
	gold += g
	phase = "planning"
	message.emit("%d라운드 클리어  +%d G" % [wave, g])
	changed.emit()


# ══ 타워 ═════════════════════════════════════════════════
func _find_target(pos: Vector2, rng: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := -1.0
	for e in enemies:
		if bool(e["dead"]):
			continue
		var d := float(e["d"])
		if d <= best_d:
			continue
		if path_pos(d).distance_to(pos) <= rng:
			best_d = d
			best = e
	return best


func _fire(t: Dictionary, target: Dictionary) -> void:
	var a: Vector2 = t["pos"]
	var b := path_pos(float(target["d"]))
	var dmg := float(t["damage"])
	var tr := str(t["trait"])
	var color := MergePalette.trait_color(tr)
	var radius := 0.0

	match tr:
		"splash":
			radius = MergeRules.SPLASH_RADIUS
			for e in enemies:
				if bool(e["dead"]):
					continue
				if path_pos(float(e["d"])).distance_to(b) <= radius:
					_hit(e, dmg)
		"chain":
			_hit(target, dmg)
			var second := _find_target_excluding(b, MergeRules.CHAIN_RADIUS, target)
			if not second.is_empty():
				_hit(second, dmg * MergeRules.CHAIN_RATIO)
		"control":
			_hit(target, dmg)
			target["slow_t"] = maxf(float(target["slow_t"]), MergeRules.SLOW_TIME)
		"damage_over_time":
			_hit(target, dmg * 0.5)
			target["burn_dps"] = maxf(float(target["burn_dps"]), dmg * MergeRules.BURN_DPS_RATIO)
			target["burn_t"] = MergeRules.BURN_TIME
		_:
			_hit(target, dmg)

	shots.append({"a": a, "b": b, "t": 0.0, "color": color, "r": radius})


func _find_target_excluding(pos: Vector2, rng: float, skip: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for e in enemies:
		if bool(e["dead"]) or e == skip:
			continue
		var d := path_pos(float(e["d"])).distance_to(pos)
		if d <= rng and d < best_d:
			best_d = d
			best = e
	return best


func _hit(e: Dictionary, dmg: float) -> void:
	if bool(e["dead"]):
		return
	e["hp"] = float(e["hp"]) - dmg
	if float(e["hp"]) <= 0.0:
		e["dead"] = true


func _cleanup_dead() -> void:
	var alive: Array = []
	for e in enemies:
		if bool(e["dead"]):
			if not bool(e["reached"]):
				gold += MergeRules.GOLD_PER_KILL * (5 if bool(e["is_boss"]) else 1)
		else:
			alive.append(e)
	enemies = alive


# ══ 단어 판정 ════════════════════════════════════════════
## 보드가 바뀔 때마다: 자동 병합 → 타워 재계산.
func _after_change() -> void:
	if MergeRules.AUTO_MERGE:
		_auto_merge()
	_recompute_towers()
	changed.emit()


## 같은 자모·같은 등급 3장 → 1장, 등급 +1. 더 안 합쳐질 때까지 돈다.
func _auto_merge() -> bool:
	var merged := false
	while true:
		var groups: Dictionary = {}
		for cell in tiles:
			var t: Dictionary = tiles[cell]
			var k := "%s|%d" % [str(t["jamo"]), int(t["tier"])]
			if not groups.has(k):
				groups[k] = []
			groups[k].append(cell)
		var did := false
		for k in groups:
			var list: Array = groups[k]
			if list.size() < MergeRules.MERGE_COUNT:
				continue
			list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.x * 100 + a.y < b.x * 100 + b.y)
			var keep: Vector2i = list[0]
			for i in range(1, MergeRules.MERGE_COUNT):
				tiles.erase(list[i])
			tiles[keep]["tier"] = mini(int(tiles[keep]["tier"]) + 1, MergeRules.MAX_TIER)
			did = true
			merged = true
			break
		if not did:
			break
	return merged


## 안쪽 가로 5줄 + 세로 5열을 한 줄씩 파싱해 단어 타워를 다시 만든다.
func _recompute_towers() -> void:
	var prev: Dictionary = {}
	for t in towers:
		prev[str(t["key"])] = float(t["cd"])
	towers.clear()
	for r in range(1, INNER + 1):
		var row: Array = []
		for c in range(1, INNER + 1):
			row.append(Vector2i(r, c))
		_scan_line(row, prev)
	for c in range(1, INNER + 1):
		var col: Array = []
		for r in range(1, INNER + 1):
			col.append(Vector2i(r, c))
		_scan_line(col, prev)


func _scan_line(cells: Array, prev: Dictionary) -> void:
	var start := -1
	for i in range(cells.size() + 1):
		var has := i < cells.size() and tiles.has(cells[i])
		if has and start < 0:
			start = i
		elif not has and start >= 0:
			_parse_run(cells.slice(start, i), prev)
			start = -1


func _parse_run(run: Array, prev: Dictionary) -> void:
	if run.size() < 2:
		return
	var jamo: Array = []
	for cell in run:
		jamo.append(str(tiles[cell]["jamo"]))
	var parsed: Array = HangulStreamParser.parse_jamo_stream(jamo)
	for p in parsed:
		var idx: Array = p.get("indices", [])
		if idx.is_empty():
			continue
		var used: Array = []
		for i in idx:
			if i >= 0 and i < run.size():
				used.append(run[i])
		if used.is_empty():
			continue
		var word := str(p.get("syllable", ""))
		var data: Dictionary = p.get("word_data", {})
		var style := AttackStyle.style_for(word, data)
		var tier_sum := 0.0
		var pos := Vector2.ZERO
		for cell in used:
			tier_sum += float(tiles[cell]["tier"])
			pos += cell_center(cell)
		pos /= float(used.size())
		var avg_tier := tier_sum / float(used.size())
		var dmg := float(data.get("damage", 8)) * (1.0 + MergeRules.DAMAGE_PER_TIER * (avg_tier - 1.0))
		var key := "%s@%d,%d" % [word, used[0].x, used[0].y]
		towers.append({
			"key": key,
			"cells": used,
			"word": word,
			"data": data,
			"trait": str(style.get("trait", "balanced")),
			"label": str(style.get("label", "")),
			"matched": bool(style.get("matched", false)),
			"source": str(style.get("source", "")),
			"damage": dmg,
			"pos": pos,
			"range": MergeRules.TOWER_RANGE_CELLS,
			"interval": MergeRules.TOWER_INTERVAL,
			"cd": float(prev.get(key, 0.0)),
		})


# ══ 잔손질 ═══════════════════════════════════════════════
func _selected_tile() -> Dictionary:
	if selected.x < 0 or not tiles.has(selected):
		return {}
	return tiles[selected]


func _empty_cells() -> Array:
	var out: Array = []
	for r in range(1, INNER + 1):
		for c in range(1, INNER + 1):
			var cell := Vector2i(r, c)
			if not tiles.has(cell):
				out.append(cell)
	return out


func tile_count() -> int:
	return tiles.size()
