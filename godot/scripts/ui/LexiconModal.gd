# LexiconModal.gd
# 100개 단어 도감 모달 및 실시간 검색/필터
extends Control

@onready var search_edit: LineEdit = $Panel/VBox/Header/SearchEdit
@onready var tabs_container: HBoxContainer = $Panel/VBox/TabsContainer
@onready var cards_grid: GridContainer = $Panel/VBox/Scroll/CardsGrid
@onready var btn_close: Button = $Panel/VBox/Footer/BtnClose
@onready var count_label: Label = $Panel/VBox/Footer/CountLabel

var current_category: String = "all"
var search_query: String = ""
var all_words: Array = []

func _ready() -> void:
	all_words = WordDatabase.get_all_words()
	btn_close.pressed.connect(func(): queue_free())
	search_edit.text_changed.connect(_on_search_changed)

	var categories = [
		{"id": "all", "name": "전체 (100)"},
		{"id": "weapon", "name": "⚔️ 무기"},
		{"id": "defense", "name": "🛡️ 방어"},
		{"id": "element", "name": "🔮 원소"},
		{"id": "summon", "name": "🐾 생물"},
		{"id": "heal", "name": "💖 회복"},
		{"id": "skill", "name": "✨ 버프"}
	]

	for cat in categories:
		var btn = Button.new()
		btn.text = cat["name"]
		btn.pressed.connect(func():
			current_category = cat["id"]
			SoundEngine.play_tile_click()
			render_cards()
		)
		tabs_container.add_child(btn)

	SoundEngine.play_word_crafted()
	render_cards()

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	render_cards()

func render_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()

	var filtered = all_words.filter(func(w):
		var match_cat = current_category == "all" or w.get("category", "") == current_category
		var match_search = search_query == "" or \
			w.get("word", "").contains(search_query) or \
			w.get("name", "").contains(search_query) or \
			w.get("desc", "").contains(search_query)
		return match_cat and match_search
	)

	count_label.text = "표시 중: %d / %d개" % [filtered.size(), all_words.size()]

	for w in filtered:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(280, 70)
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)

		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(w.get("icon", "")):
			icon_rect.texture = load(w["icon"])
		hbox.add_child(icon_rect)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)

		var title_hbox = HBoxContainer.new()
		vbox.add_child(title_hbox)

		var lbl_title = Label.new()
		lbl_title.text = "%s %s" % [w.get("word", ""), w.get("name", "")]
		lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_hbox.add_child(lbl_title)

		var lbl_cost = Label.new()
		lbl_cost.text = "%d AP" % w.get("cost", 0)
		lbl_cost.modulate = Color(1.0, 0.85, 0.4)
		title_hbox.add_child(lbl_cost)

		var lbl_desc = Label.new()
		lbl_desc.text = w.get("desc", "")
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.modulate = Color(0.85, 0.85, 0.9)
		vbox.add_child(lbl_desc)

		cards_grid.add_child(panel)
