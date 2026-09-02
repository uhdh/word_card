# JamoBelt.gd
# 하단 자모 타일 벨트: 실시간 자모 순서 배치, 회전(🔄), 합성(⚡), 스왑 및 자동 타워 파싱
class_name JamoBelt
extends PanelContainer

signal parsed_towers_updated(parsed_list: Array)
signal request_buy_jamo()
signal jamo_changed()

var jamo_list: Array[String] = [
	"ㅂ", "ㅜ", "ㄹ"  # -> 불 (첫 번째 시작 타워)
]

var selected_index_for_swap: int = -1
var selected_index_for_combine: int = -1

@onready var tiles_container: HBoxContainer = $VBox/Scroll/TilesContainer
@onready var parsed_preview_label: Label = $VBox/Header/PreviewLabel
@onready var btn_buy_jamo: Button = $VBox/Header/BtnBuyJamo

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

func render_belt() -> void:
	for c in tiles_container.get_children():
		c.queue_free()

	# Parse current stream
	var parsed = HangulStreamParser.parse_jamo_stream(jamo_list)

	# Build preview text
	var preview_words = []
	for p in parsed:
		preview_words.append("[%s 타워]" % p["syllable"])
	if parsed_preview_label:
		parsed_preview_label.text = "🏰 자동 완성 타워: " + (" ➔ ".join(preview_words) if not preview_words.is_empty() else "단어 조합 없음")

	# Emit signals
	parsed_towers_updated.emit(parsed)
	jamo_changed.emit()

	# Render tile buttons
	for idx in range(jamo_list.size()):
		var char_str = jamo_list[idx]
		var is_rotatable = HangulEngine.is_rotatable(char_str)

		var tile_box = PanelContainer.new()
		var vbox = VBoxContainer.new()
		tile_box.add_child(vbox)

		var btn_tile = Button.new()
		btn_tile.text = char_str
		btn_tile.custom_minimum_size = Vector2(58, 66)
		btn_tile.add_theme_font_size_override("font_size", 22)

		if selected_index_for_swap == idx:
			btn_tile.modulate = Color(1.0, 0.9, 0.3)
		elif selected_index_for_combine == idx:
			btn_tile.modulate = Color(0.4, 0.9, 1.0)
		else:
			btn_tile.modulate = Color(1.0, 1.0, 1.0)

		btn_tile.pressed.connect(_on_tile_clicked.bind(idx))
		vbox.add_child(btn_tile)

		# Actions row (Rotate & Combine)
		var hbox_act = HBoxContainer.new()
		vbox.add_child(hbox_act)

		if is_rotatable:
			var btn_rot = Button.new()
			btn_rot.text = "🔄"
			btn_rot.custom_minimum_size = Vector2(26, 24)
			btn_rot.add_theme_font_size_override("font_size", 11)
			btn_rot.pressed.connect(func():
				jamo_list[idx] = HangulEngine.rotate(jamo_list[idx])
				SoundEngine.play_tile_rotate()
				render_belt()
			)
			hbox_act.add_child(btn_rot)

		var btn_comb = Button.new()
		btn_comb.text = "⚡"
		btn_comb.custom_minimum_size = Vector2(26, 24)
		btn_comb.add_theme_font_size_override("font_size", 11)
		btn_comb.pressed.connect(func():
			if selected_index_for_combine == -1:
				selected_index_for_combine = idx
				selected_index_for_swap = -1
				SoundEngine.play_tile_click()
			elif selected_index_for_combine == idx:
				selected_index_for_combine = -1
			else:
				var c1 = jamo_list[selected_index_for_combine]
				var c2 = jamo_list[idx]
				if HangulEngine.can_combine(c1, c2):
					var res = HangulEngine.combine(c1, c2)
					var idx1 = selected_index_for_combine
					var idx2 = idx
					if idx1 > idx2:
						jamo_list.remove_at(idx1)
						jamo_list.remove_at(idx2)
					else:
						jamo_list.remove_at(idx2)
						jamo_list.remove_at(idx1)
					jamo_list.insert(mini(idx1, idx2), res)
					SoundEngine.play_tile_combine()
				selected_index_for_combine = -1
			render_belt()
		)
		hbox_act.add_child(btn_comb)

		tiles_container.add_child(tile_box)

func _on_tile_clicked(idx: int) -> void:
	if selected_index_for_combine != -1:
		var c1 = jamo_list[selected_index_for_combine]
		var c2 = jamo_list[idx]
		if HangulEngine.can_combine(c1, c2):
			var res = HangulEngine.combine(c1, c2)
			var idx1 = selected_index_for_combine
			var idx2 = idx
			if idx1 > idx2:
				jamo_list.remove_at(idx1)
				jamo_list.remove_at(idx2)
			else:
				jamo_list.remove_at(idx2)
				jamo_list.remove_at(idx1)
			jamo_list.insert(mini(idx1, idx2), res)
			SoundEngine.play_tile_combine()
		selected_index_for_combine = -1
		render_belt()
		return

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
