# LexiconModal.gd
# 1/2/3글자 전체 단어 타워 도감 모달, 실시간 검색, 티어 필터 및 자모 조합 공식 가이드
extends Control

@onready var search_edit: LineEdit = $Panel/VBox/Header/SearchEdit
@onready var tabs_container: HBoxContainer = $Panel/VBox/TabsContainer
@onready var cards_grid: GridContainer = $Panel/VBox/Scroll/CardsGrid
@onready var btn_close: Button = $Panel/VBox/Footer/BtnClose
@onready var count_label: Label = $Panel/VBox/Footer/CountLabel

var current_filter: String = "all"
var search_query: String = ""
var all_words: Array = []

func _ready() -> void:
	all_words = WordDatabase.get_all_words()
	btn_close.pressed.connect(func(): queue_free())
	search_edit.text_changed.connect(_on_search_changed)

	var filters = [
		{"id": "all", "name": "전체 (%d)" % all_words.size()},
		{"id": "tier1", "name": "⭐ 1글자"},
		{"id": "tier2", "name": "⭐⭐ 2글자 상위"},
		{"id": "tier3", "name": "⭐⭐⭐ 3글자 신화"},
		{"id": "weapon", "name": "⚔️ 무기"},
		{"id": "element", "name": "🔮 원소"},
		{"id": "defense", "name": "🛡️ 방어"},
		{"id": "summon", "name": "🐾 생물"},
		{"id": "heal", "name": "💖 회복"}
	]

	for f in filters:
		var btn = Button.new()
		btn.text = f["name"]
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			current_filter = f["id"]
			SoundEngine.play_tile_click()
			render_cards()
		)
		tabs_container.add_child(btn)

	SoundEngine.play_word_crafted()
	render_cards()

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	render_cards()

func get_jamo_recipe(word: String) -> String:
	var syllables = []
	for i in range(word.length()):
		var ch = word.substr(i, 1)
		var decomp = HangulEngine.decompose(ch)
		if decomp.is_empty():
			syllables.append(ch)
		else:
			var parts = []
			if decomp.get("cho", "") != "": parts.append(decomp["cho"])
			if decomp.get("jung", "") != "": parts.append(decomp["jung"])
			if decomp.get("jong", "") != "": parts.append(decomp["jong"])
			syllables.append("".join(parts))
	return " + ".join(syllables)

func render_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()

	var filtered = all_words.filter(func(w):
		var w_len = w.get("word", "").length()
		var cat = w.get("category", "")
		
		var match_filter = false
		if current_filter == "all":
			match_filter = true
		elif current_filter == "tier1" and w_len == 1:
			match_filter = true
		elif current_filter == "tier2" and w_len == 2:
			match_filter = true
		elif current_filter == "tier3" and w_len >= 3:
			match_filter = true
		elif current_filter == cat:
			match_filter = true

		var match_search = search_query == "" or \
			w.get("word", "").contains(search_query) or \
			w.get("name", "").contains(search_query) or \
			w.get("desc", "").contains(search_query)

		return match_filter and match_search
	)

	count_label.text = "표시 중: %d / %d개 단어 타워" % [filtered.size(), all_words.size()]

	for w in filtered:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 110)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		# Header: Word + Tier + Cost
		var hbox_top = HBoxContainer.new()
		vbox.add_child(hbox_top)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(w.get("icon", "")):
			icon.texture = load(w["icon"])
		hbox_top.add_child(icon)

		var word_len = w.get("word", "").length()
		var tier_badge = "⭐"
		if word_len == 2: tier_badge = "⭐⭐ 상위"
		elif word_len >= 3: tier_badge = "⭐⭐⭐ 신화"

		var name_lbl = Label.new()
		name_lbl.text = " %s [%s]" % [w.get("word", ""), tier_badge]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		if word_len >= 3:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.9))
		elif word_len == 2:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		hbox_top.add_child(name_lbl)

		var dmg_lbl = Label.new()
		dmg_lbl.text = "💥 %d" % w.get("damage", 4)
		dmg_lbl.add_theme_font_size_override("font_size", 12)
		dmg_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		hbox_top.add_child(dmg_lbl)

		# Recipe guide
		var recipe_str = get_jamo_recipe(w.get("word", ""))
		var recipe_lbl = Label.new()
		recipe_lbl.text = "🧩 조합: %s" % recipe_str
		recipe_lbl.add_theme_font_size_override("font_size", 10)
		recipe_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(recipe_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = w.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		cards_grid.add_child(panel)
