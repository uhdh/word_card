class_name MergeBoard
extends Control
## 보드를 그리는 **뷰**. 규칙은 `MergeGame` 에 있고 여기서는 그리기와 클릭만 한다.
##
## 7×7 — **바깥 한 줄 = 적이 걷는 경로**, **안쪽 5×5 = 배치 슬롯**.
## 참고 영상 실측(884×1400): 보드 728×728 · 타일 89px · 간격 15px · 피치 104px → 비율로 옮긴다.

const FONT := preload("res://fonts/neodgm.ttf")

var game: MergeGame

var _cell := 0.0
var _origin := Vector2.ZERO
var _gap := 0.0
var _tile := 0.0
var _board_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_compute()


func _on_resized() -> void:
	_compute()
	queue_redraw()


func _compute() -> void:
	var n := float(MergeRules.GRID)
	_cell = minf(size.x, size.y) / n
	_origin = Vector2((size.x - _cell * n) * 0.5, (size.y - _cell * n) * 0.5)
	_gap = _cell * 0.14
	_tile = _cell - _gap


func tile_rect(cell: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(float(cell.y), float(cell.x)) * _cell + Vector2(_gap, _gap) * 0.5,
		Vector2(_tile, _tile))


## 보드 좌표(칸 단위) → 픽셀
func board_px(p: Vector2) -> Vector2:
	return _origin + p * _cell


# ══ 입력 ═════════════════════════════════════════════════
func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		var col := int(floor((p.x - _origin.x) / _cell))
		var row := int(floor((p.y - _origin.y) / _cell))
		if row >= 0 and row < MergeRules.GRID and col >= 0 and col < MergeRules.GRID:
			game.click_slot(Vector2i(row, col))
		else:
			game.click_slot(Vector2i(-1, -1))
		accept_event()


# ══ 그리기 ═══════════════════════════════════════════════
func _draw() -> void:
	if game == null:
		return
	_compute()
	if _cell < 4.0:
		return
	var n := MergeRules.GRID
	var board_rect := Rect2(_origin, Vector2(_cell * n, _cell * n))
	_board_rect = board_rect

	_ring(board_rect.grow(5.0), _cell * 0.26, 3.0, MergePalette.RING_CYAN)

	# ── 칸 ──
	for r in n:
		for c in n:
			var cell := Vector2i(r, c)
			var rect := tile_rect(cell)
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(int(_tile * 0.16))
			sb.set_border_width_all(2)
			if MergeGame.is_inner_cell(cell):
				sb.bg_color = MergePalette.SLOT_EMPTY
				sb.border_color = MergePalette.SLOT_EMPTY_EDGE
			else:
				sb.bg_color = MergePalette.PATH_TILE
				sb.border_color = MergePalette.PATH_EDGE
			draw_style_box(sb, rect)

	# ── 경로 장식 ──
	for d in MergeData.PATH_DECOR:
		var cell := Vector2i(int(d["row"]), int(d["col"]))
		draw_circle(tile_rect(cell).get_center(), _tile * 0.15, Color(d["color"]))

	# ── 안쪽 금색 고리 ──
	var inner := Rect2(_origin + Vector2(_cell, _cell), Vector2(_cell * (n - 2), _cell * (n - 2)))
	_ring(inner.grow(4.0), _cell * 0.22, 3.0, MergePalette.RING_GOLD)

	_draw_portal_and_base()
	_draw_towers()
	_draw_tiles()
	# ⚠️ 단어 라벨은 **타일 뒤에** 그린다. 타워와 같이 그리면 위 칸 타일이 라벨을 덮어
	#    '나무' 처럼 아래쪽 행의 단어가 반쯤 가려진다 (실측 스크린샷).
	_draw_tower_labels()
	_draw_enemies()
	_draw_shots()


func _draw_portal_and_base() -> void:
	if game.path.is_empty():
		return
	# 스폰 = 보라 소용돌이 자리
	var spawn: Vector2i = game.path[0]
	var sc := tile_rect(spawn).get_center()
	draw_circle(sc, _tile * 0.30, Color("7b5cff"))
	draw_circle(sc, _tile * 0.16, Color("d9ccff"))
	# 기지 = 붉은 핵
	var base: Vector2i = game.path[game.path.size() - 1]
	var bc := tile_rect(base).get_center()
	draw_circle(bc, _tile * 0.34, Color("8f1f2e"))
	draw_circle(bc, _tile * 0.22, MergePalette.HP_RED)
	draw_circle(bc, _tile * 0.10, Color("ffe0e0"))


## 단어 타워 — 칸 묶음을 특성색 고리로 두르고, 고른 타워는 사거리 원을 그린다.
## (단어 라벨은 `_draw_tower_labels()` 가 **타일 뒤에** 그린다)
func _draw_towers() -> void:
	for t in game.towers:
		var cells: Array = t["cells"]
		var color := MergePalette.trait_color(str(t["trait"]))
		var box := tile_rect(cells[0])
		for cell in cells:
			box = box.merge(tile_rect(cell))
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(color.r, color.g, color.b, 0.10)
		glow.set_corner_radius_all(int(_tile * 0.22))
		glow.set_border_width_all(3)
		glow.border_color = color
		draw_style_box(glow, box.grow(2.0))

		# 사거리 원 (고른 타워만)
		if _tower_selected(t):
			_draw_range(board_px(Vector2(t["pos"])), float(t["range"]) * _cell,
				Color(color.r, color.g, color.b, 0.35))


## 사거리 원을 **보드 안쪽만** 그린다.
## ⚠️ `draw_arc` 로 통째로 그리면 사거리 3.4칸짜리 타워의 원이 보드 밖(시안 고리 바깥)까지
##    나가 "보드가 잘린 것처럼" 보인다. 원을 잘게 나눠 보드 rect 안에 있는 조각만 잇는다.
func _draw_range(center_px: Vector2, radius_px: float, color: Color) -> void:
	var steps := 128
	var prev := Vector2.ZERO
	var prev_in := false
	for i in range(steps + 1):
		var a := TAU * float(i) / float(steps)
		var p := center_px + Vector2(cos(a), sin(a)) * radius_px
		var inside := _board_rect.has_point(p)
		if inside and prev_in:
			draw_line(prev, p, color, 2.0)
		prev = p
		prev_in = inside


func _draw_tower_labels() -> void:
	for t in game.towers:
		var cells: Array = t["cells"]
		var color := MergePalette.trait_color(str(t["trait"]))
		var box := tile_rect(cells[0])
		for cell in cells:
			box = box.merge(tile_rect(cell))

		var fs := int(maxf(12.0, _tile * 0.30))
		var word := str(t["word"])
		var tw := FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pad := fs * 0.35
		var lr := Rect2(box.get_center().x - tw * 0.5 - pad, box.position.y - fs * 1.9,
			tw + pad * 2.0, fs + pad * 1.2)
		# 보드 위로 삐져나가면(맨 윗줄 타워) 칸 안쪽으로 내린다.
		if lr.position.y < _board_rect.position.y + 2.0:
			lr.position.y = box.position.y + fs * 0.35
		var lb := StyleBoxFlat.new()
		lb.bg_color = Color(0.04, 0.05, 0.11, 0.92)
		lb.set_corner_radius_all(int(fs * 0.5))
		lb.set_border_width_all(1)
		lb.border_color = color
		draw_style_box(lb, lr)
		draw_string(FONT, Vector2(lr.position.x + pad, lr.position.y + fs * 1.05), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _tower_selected(t: Dictionary) -> bool:
	for cell in t["cells"]:
		if cell == game.selected:
			return true
	return false


func _draw_tiles() -> void:
	var in_tower: Dictionary = {}
	for t in game.towers:
		for cell in t["cells"]:
			in_tower[cell] = true
	for cell in game.tiles:
		var d: Dictionary = game.tiles[cell]
		MergeTile.draw_tile(self, tile_rect(cell), str(d["jamo"]), int(d["tier"]),
			cell == game.selected, not in_tower.has(cell))


func _draw_enemies() -> void:
	for e in game.enemies:
		var p := board_px(game.path_pos(float(e["d"])))
		var is_boss := bool(e["is_boss"])
		var rad := _tile * (0.42 if is_boss else 0.26)
		var body := MergePalette.ENEMY
		if float(e["burn_t"]) > 0.0:
			body = body.lerp(MergePalette.ENEMY_BURN, 0.5)
		if float(e["slow_t"]) > 0.0:
			body = body.lerp(MergePalette.ENEMY_SLOW, 0.45)
		draw_circle(p, rad, body)
		draw_arc(p, rad, 0.0, TAU, 24, MergePalette.ENEMY_EDGE, 2.0)
		if is_boss:
			draw_arc(p, rad * 1.45, 0.0, TAU, 32, MergePalette.BOSS_RED, 3.0)
		# HP 바
		var w := rad * 2.4
		var h := maxf(3.0, _tile * 0.055)
		var top := p.y - rad - h * 2.2
		draw_rect(Rect2(p.x - w * 0.5, top, w, h), Color(0, 0, 0, 0.65), true)
		var frac := clampf(float(e["hp"]) / maxf(float(e["max_hp"]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(p.x - w * 0.5, top, w * frac, h), MergePalette.ENEMY_HP, true)


func _draw_shots() -> void:
	for s in game.shots:
		var a := board_px(Vector2(s["a"]))
		var b := board_px(Vector2(s["b"]))
		var f := clampf(float(s["t"]) / MergeRules.SHOT_LIFE, 0.0, 1.0)
		var c: Color = s["color"]
		draw_line(a, b, Color(c.r, c.g, c.b, 1.0 - f), maxf(2.0, _tile * 0.06))
		var r := float(s["r"])
		if r > 0.0:
			draw_arc(b, r * _cell, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.5 * (1.0 - f)), 2.0)
		else:
			draw_circle(b, maxf(3.0, _tile * 0.09), Color(c.r, c.g, c.b, 1.0 - f))


func _ring(rect: Rect2, radius: float, width: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(int(width))
	sb.border_color = color
	draw_style_box(sb, rect)
