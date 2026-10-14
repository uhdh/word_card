extends Node
# 자모 타일 드래그&드롭 재현 테스트.
#
# 실제 엔진 입력 경로(get_viewport().push_input)로 마우스 이벤트를 흘려보내
# "타일을 슬롯으로 드래그" 가 정말 되는지 확인한다.
# 스크립트에서 _drop_data 를 직접 부르는 테스트로는 입력 라우팅 회귀를 못 잡는다.
#
# ⚠️ 반드시 창을 띄워서 실행할 것:
#     godot --path godot res://tests/test_belt_drag_drop.tscn
#    --headless 에서는 GUI 히트테스트가 동작하지 않아 자동으로 건너뛴다.
#
# 이 테스트가 잡는 회귀:
#   타일 버튼의 mouse_filter 를 STOP 으로 바꾸면 엔진이 드래그 소스를
#   버튼으로만 판단해 부모 JamoTileBox._get_drag_data 가 호출되지 않는다
#   → 드래그&드롭이 통째로 죽는다.

const JamoBeltScene = preload("res://scenes/tower/JamoBelt.tscn")

var failures := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("belt drag&drop tests SKIPPED (--headless 에서는 GUI 입력이 안 됨)")
		get_tree().quit(0)
		return
	await _test_tile_drag_into_slot()
	await _test_tile_drag_between_tiles_reorders()
	if failures == 0:
		print("belt drag&drop tests passed")
	get_tree().quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _make_belt(jamo: Array) -> JamoBelt:
	var host := Control.new()
	host.size = Vector2(1280, 260)
	add_child(host)
	var belt: JamoBelt = JamoBeltScene.instantiate()
	host.add_child(belt)
	belt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	belt.jamo_list.assign(jamo)
	belt.render_belt()
	await get_tree().process_frame
	await get_tree().process_frame
	return belt


func _push_click(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e)


func _push_move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	# 이걸 안 넣으면 엔진이 드래그 시도 자체를 하지 않는다.
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)


func _drag(from: Vector2, to: Vector2) -> void:
	_push_move(from - Vector2(4, 0), from)
	await get_tree().process_frame
	_push_click(from, true)
	await get_tree().process_frame
	var steps := 10
	for i in range(1, steps + 1):
		_push_move(from.lerp(to, float(i - 1) / steps), from.lerp(to, float(i) / steps))
		await get_tree().process_frame
	_push_click(to, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_tile_drag_into_slot() -> void:
	var belt = await _make_belt(["ㄱ", "ㅏ"])
	var boxes = belt._tile_boxes(belt.tiles_container)
	check(boxes.size() == 2, "Two tiles must be laid out")
	var tile = boxes.filter(func(b): return b.tile_index == 0)[0]
	var tray = belt.tiles_container.get_child(0)
	var from: Vector2 = tile.get_global_rect().get_center()
	var to: Vector2 = (tray as Control).get_global_rect().get_center()
	check(from != to, "Tile and slot must be at different positions")
	await _drag(from, to)
	check(belt.slot_assignments[0] == 0,
		"Dragging a tile onto slot 1 must assign it there (got %d)" % belt.slot_assignments[0])
	belt.get_parent().free()


func _test_tile_drag_between_tiles_reorders() -> void:
	var belt = await _make_belt(["ㄱ", "ㅏ", "ㄴ"])
	var boxes = belt._tile_boxes(belt.tiles_container)
	var first = boxes.filter(func(b): return b.tile_index == 0)[0]
	var third = boxes.filter(func(b): return b.tile_index == 2)[0]
	var from: Vector2 = first.get_global_rect().get_center()
	var rect: Rect2 = third.get_global_rect()
	# 세 번째 타일의 오른쪽 절반 위로 떨어뜨리면 맨 뒤로 밀려야 한다.
	var to := Vector2(rect.position.x + rect.size.x * 0.8, rect.get_center().y)
	await _drag(from, to)
	check(belt.jamo_list[0] == "ㅏ" and belt.jamo_list[2] == "ㄱ",
		"Dragging a tile past another must reorder the belt (got %s)" % str(belt.jamo_list))
	belt.get_parent().free()
