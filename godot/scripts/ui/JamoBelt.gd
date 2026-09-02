# JamoBelt.gd
# 하단 자모 타일 벨트: 실시간 자모 순서 배치, 드래그 앤 드롭(Drag & Drop), 회전(🔄), 클릭-스왑 및 자동 스트림 파싱
class_name JamoBelt
extends PanelContainer

signal parsed_towers_updated(parsed_list: Array)
signal request_buy_jamo()
signal jamo_changed()

var jamo_list: Array[String] = [
	"ㅂ", "ㅜ", "ㄹ"  # -> 불 (첫 번째 시작 타워)
]

var selected_index_for_swap: int = -1

@onready var tiles_container: HBoxContainer = $VBox/Scroll/TilesContainer
@onready var parsed_preview_label: Label = $VBox/Header/PreviewLabel
@onready var btn_buy_jamo: Button = $VBox/Header/BtnBuyJamo

# Draggable Tile Container Box
class JamoTileBox extends PanelContainer:
	var belt: JamoBelt
	var tile_index: int
	var char_str: String

	func _init(p_belt: JamoBelt, p_idx: int, p_char: String):
		belt = p_belt
		tile_index = p_idx
		char_str = p_char
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_drag_data(_at_position: Vector2) -> Variant:
		# Create visual drag preview following mouse cursor
		var preview = PanelContainer.new()
		preview.custom_minimum_size = Vector2(60, 68)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.16, 0.3, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.9, 0.8, 0.3, 1.0)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
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

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary and data.get("type") == "jamo_tile":
			var from_idx = data.get("from_index", -1)
			if is_instance_valid(belt):
				belt.handle_drag_drop(from_idx, tile_index)

func _ready() -> void:
	if btn_buy_jamo:
		btn_buy_jamo.pressed.connect(func(): request_buy_jamo.emit())
	render_belt()

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

func handle_drag_drop(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= jamo_list.size() or to_idx < 0 or to_idx >= jamo_list.size() or from_idx == to_idx:
		return

	# Reorder / Move the tile to the target position
	var item = jamo_list[from_idx]
	jamo_list.remove_at(from_idx)
	jamo_list.insert(to_idx, item)

	SoundEngine.play_tile_click()
	render_belt()

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

	# Render tile buttons with Drag & Drop support
	for idx in range(jamo_list.size()):
		var char_str = jamo_list[idx]
		var is_rotatable = HangulEngine.is_rotatable(char_str)

		var tile_box = JamoTileBox.new(self, idx, char_str)
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		tile_box.add_child(vbox)

		var is_rare = HangulEngine.is_rare(char_str)

		var btn_tile = Button.new()
		btn_tile.text = ("🌟 " + char_str) if is_rare else char_str
		btn_tile.tooltip_text = "[🌟 희귀 타일] " if is_rare else ""
		btn_tile.tooltip_text += "마우스로 끌어서(드래그) 순서를 바꾸거나, 클릭하여 다른 타일과 교환하세요."
		btn_tile.custom_minimum_size = Vector2(58, 66)
		btn_tile.add_theme_font_size_override("font_size", 20 if is_rare else 22)
		btn_tile.mouse_filter = Control.MOUSE_FILTER_PASS

		if selected_index_for_swap == idx:
			btn_tile.modulate = Color(1.0, 0.9, 0.3)
		elif is_rare:
			btn_tile.modulate = Color(1.0, 0.85, 0.25, 1.0) # Golden Rare highlight
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
		# Swap positions
		var tmp = jamo_list[selected_index_for_swap]
		jamo_list[selected_index_for_swap] = jamo_list[idx]
		jamo_list[idx] = tmp
		selected_index_for_swap = -1
		SoundEngine.play_tile_click()
		render_belt()
