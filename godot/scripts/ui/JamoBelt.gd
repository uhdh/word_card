# JamoBelt.gd
# 하단 자모 타일 벨트: 실시간 자모 순서 배치, 정밀 드래그 앤 드롭 삽입(타일 사이 / 맨 끝), 회전(🔄), 클릭-스왑 및 자동 스트림 파싱
class_name JamoBelt
extends PanelContainer

signal parsed_towers_updated(parsed_list: Array)
signal jamo_changed()

var jamo_list: Array[String] = [
	"ㅂ", "ㅜ", "ㄹ"  # -> 불 (첫 번째 시작 타워)
]

var selected_index_for_swap: int = -1

@onready var scroll_container: ScrollContainer = $VBox/Scroll
@onready var tiles_container: HBoxContainer = $VBox/Scroll/TilesContainer
@onready var parsed_preview_label: Label = $VBox/Header/PreviewLabel

# Draggable Tile Container Box (좌/우 정밀 사이 삽입 지원)
class JamoTileBox extends PanelContainer:
	var belt: JamoBelt
	var tile_index: int
	var char_str: String

	func _init(p_belt: JamoBelt, p_index: int, p_char: String) -> void:
		belt = p_belt
		tile_index = p_index
		char_str = p_char
		custom_minimum_size = Vector2(58, 96)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview = PanelContainer.new()
		preview.custom_minimum_size = Vector2(58, 66)
		var style = StyleBoxFlat.new()
		style.bg_color = HangulEngine.get_rarity_bg_color(char_str)
		style.border_color = Color(1.0, 0.9, 0.4, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		preview.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		lbl.text = char_str
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.add_child(lbl)

		preview.set_rotation_degrees(5.0)
		set_drag_preview(preview)

		if is_instance_valid(belt):
			belt.selected_index_for_swap = -1

		return {
			"type": "jamo_tile",
			"from_index": tile_index,
			"char": char_str
		}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("type") == "jamo_tile"

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if data is Dictionary and data.get("type") == "jamo_tile":
			var from_idx = data.get("from_index", -1)
			var is_right_half = at_position.x > (size.x * 0.5)
			var target_insert_idx = tile_index + (1 if is_right_half else 0)
			if is_instance_valid(belt):
				belt.handle_insert_drag_drop(from_idx, target_insert_idx)

func _ready() -> void:
	render_belt()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "jamo_tile"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "jamo_tile":
		var from_idx = data.get("from_index", -1)
		# 빈 공간이나 맨 끝에 드롭하면 맨 뒤로 이동
		handle_insert_drag_drop(from_idx, jamo_list.size())

func add_jamo(c: String) -> void:
	if jamo_list.size() < 15:
		jamo_list.append(c)
		render_belt()

func rotate_first_available() -> void:
	for i in range(jamo_list.size()):
		if HangulEngine.is_rotatable(jamo_list[i]):
			jamo_list[i] = HangulEngine.rotate(jamo_list[i])
			SoundEngine.play_tile_rotate()
			render_belt()
			break

func handle_insert_drag_drop(from_idx: int, target_insert_idx: int) -> void:
	if from_idx < 0 or from_idx >= jamo_list.size():
		return

	var item = jamo_list[from_idx]
	jamo_list.remove_at(from_idx)

	# If moving from left to right, adjust index after removal
	var final_insert_idx = target_insert_idx
	if from_idx < target_insert_idx:
		final_insert_idx -= 1

	final_insert_idx = clampi(final_insert_idx, 0, jamo_list.size())
	jamo_list.insert(final_insert_idx, item)

	SoundEngine.play_tile_click()
	render_belt()

func handle_drag_drop(from_idx: int, to_idx: int) -> void:
	handle_insert_drag_drop(from_idx, to_idx)

func render_belt() -> void:
	for c in tiles_container.get_children():
		c.queue_free()

	# Parse current stream (with automatic sequence combination: ㄱ+ㄱ->ㄲ, ㅗ+ㅏ->ㅘ, etc.)
	var parsed = HangulStreamParser.parse_jamo_stream(jamo_list)

	# Build preview text & discover newly formed words
	var preview_words = []
	for p in parsed:
		var syl = p["syllable"]
		preview_words.append("[%s 타워]" % syl)
		SaveManager.discover_word(syl)
	if parsed_preview_label:
		parsed_preview_label.text = "🏰 자동 완성 타워: " + (" ➔ ".join(preview_words) if not preview_words.is_empty() else "단어 조합 없음")

	# Emit signals
	parsed_towers_updated.emit(parsed)
	jamo_changed.emit()

	# Render tile buttons with Drag & Drop Insertion support
	for idx in range(jamo_list.size()):
		var char_str = jamo_list[idx]
		var is_rotatable = HangulEngine.is_rotatable(char_str)

		var tile_box = JamoTileBox.new(self, idx, char_str)
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		tile_box.add_child(vbox)

		var rarity = HangulEngine.get_rarity(char_str)
		var bg_color = HangulEngine.get_rarity_bg_color(char_str)
		var border_color = HangulEngine.get_rarity_border_color(char_str)

		var style = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_color = border_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)

		var btn_tile = Button.new()
		btn_tile.text = char_str
		btn_tile.add_theme_stylebox_override("normal", style)
		btn_tile.add_theme_stylebox_override("hover", style)
		btn_tile.add_theme_stylebox_override("pressed", style)

		var rarity_name = "일반"
		if rarity == "super_rare": rarity_name = "🔥 초희귀 (4변환 만능)"
		elif rarity == "rare": rarity_name = "✨ 희귀 (2변환)"

		btn_tile.tooltip_text = "[%s 타일: %s]\n드래그하여 원하는 타일 사이나 맨 끝으로 자유롭게 배치하세요." % [rarity_name, char_str]
		btn_tile.custom_minimum_size = Vector2(58, 66)
		btn_tile.add_theme_font_size_override("font_size", 24)
		btn_tile.mouse_filter = Control.MOUSE_FILTER_PASS

		if selected_index_for_swap == idx:
			btn_tile.modulate = Color(1.0, 1.0, 0.4)
		else:
			btn_tile.modulate = Color(1.0, 1.0, 1.0)

		btn_tile.pressed.connect(_on_tile_clicked.bind(idx))
		vbox.add_child(btn_tile)

		# Actions row (Rotate only)
		if is_rotatable:
			var btn_rot = Button.new()
			btn_rot.text = "🔄"
			btn_rot.tooltip_text = "90도 회전 (예: ㅏ ➔ ㅗ, ㄱ ➔ ㄴ)"
			btn_rot.custom_minimum_size = Vector2(58, 24)
			btn_rot.add_theme_font_size_override("font_size", 11)
			btn_rot.mouse_filter = Control.MOUSE_FILTER_STOP
			btn_rot.pressed.connect(func():
				jamo_list[idx] = HangulEngine.rotate(jamo_list[idx])
				SoundEngine.play_tile_rotate()
				render_belt()
			)
			vbox.add_child(btn_rot)

		tiles_container.add_child(tile_box)

func _on_tile_clicked(idx: int) -> void:
	if selected_index_for_swap == -1:
		selected_index_for_swap = idx
		SoundEngine.play_tile_click()
		render_belt()
	elif selected_index_for_swap == idx:
		selected_index_for_swap = -1
		render_belt()
	else:
		var tmp = jamo_list[selected_index_for_swap]
		jamo_list[selected_index_for_swap] = jamo_list[idx]
		jamo_list[idx] = tmp
		selected_index_for_swap = -1
		SoundEngine.play_tile_click()
		render_belt()
