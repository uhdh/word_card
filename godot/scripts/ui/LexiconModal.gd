# LexiconModal.gd
# 1/2/3글자 전체 단어 타워 도감 모달: 실시간 검색, 티어 필터, 자모 조합 공식 가이드 및 도감 해금(Discovery) 시스템
extends Control

@onready var search_edit: LineEdit = $Panel/VBox/Header/SearchEdit
@onready var tabs_container: HBoxContainer = $Panel/VBox/TabsContainer
@onready var cards_grid: GridContainer = $Panel/VBox/Scroll/CardsGrid
@onready var btn_close: Button = $Panel/VBox/Footer/BtnClose
@onready var count_label: Label = $Panel/VBox/Footer/CountLabel

var current_filter: String = "all"
var search_query: String = ""
var all_words: Array = []
var discovered_words: Array = []

const JAMO_RULES := "🧩 자모 합성 규칙\n회전: ㄱ ↔ ㄴ · ㅏ → ㅜ → ㅓ → ㅗ · ㅡ ↔ ㅣ\n쌍자음: ㄱ+ㄱ=ㄲ · ㄷ+ㄷ=ㄸ · ㅂ+ㅂ=ㅃ · ㅅ+ㅅ=ㅆ · ㅈ+ㅈ=ㅉ\n겹모음: ㅗ+ㅏ=ㅘ · ㅗ+ㅣ=ㅚ · ㅜ+ㅓ=ㅝ · ㅜ+ㅣ=ㅟ · ㅡ+ㅣ=ㅢ\n파싱: 3글자 → 2글자 → 1글자 순으로 가장 긴 연성식 우선"

func _ready() -> void:
	all_words = WordDatabase.get_all_words()
	discovered_words = SaveManager.get_discovered_words()

	btn_close.pressed.connect(func(): queue_free())
	search_edit.text_changed.connect(_on_search_changed)
	var rules = Label.new()
	rules.text = JAMO_RULES
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 11)
	rules.add_theme_color_override("font_color", Color("d5f5ef"))
	$Panel/VBox.add_child(rules)
	$Panel/VBox.move_child(rules, tabs_container.get_index())

	var filters = [
		{"id": "all", "name": "전체 (%d/%d)" % [discovered_words.size(), all_words.size()]},
		{"id": "discovered", "name": "✅ 발견한 활자"},
		{"id": "tier1", "name": "⭐ 1글자"},
		{"id": "tier2", "name": "⭐⭐ 2글자 상위"},
		{"id": "tier3", "name": "⭐⭐⭐ 3글자 신화"},
		{"id": "weapon", "name": "무기"},
		{"id": "element", "name": "원소"},
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

	# 도감을 여는 것은 '단어 완성' 이 아니다 — 일반 UI 열기음으로 되돌린다.
	SoundEngine.play_tile_click()
	render_cards()

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	render_cards()

func get_jamo_recipe(word: String) -> String:
	var syllables = []
	for i in range(word.length()):
		var ch = word.substr(i, 1)
		var decomp = HangulEngine.decompose_syllable(ch)
		if decomp.is_empty():
			syllables.append(ch)
		else:
			var parts = []
			if decomp.get("chosung", "") != "": parts.append(decomp["chosung"])
			if decomp.get("jungsung", "") != "": parts.append(decomp["jungsung"])
			if decomp.get("jongsung", "") != "": parts.append(decomp["jongsung"])
			syllables.append("".join(parts))
	return " + ".join(syllables)

func render_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()

	var disc_set = {}
	for w_str in discovered_words:
		disc_set[w_str] = true

	var filtered = all_words.filter(func(w):
		var word_str = w.get("word", "")
		var w_len = word_str.length()
		var cat = w.get("category", "")
		var is_unlocked = disc_set.has(word_str)

		var match_filter = false
		if current_filter == "all":
			match_filter = true
		elif current_filter == "discovered" and is_unlocked:
			match_filter = true
		elif current_filter == "tier1" and w_len == 1:
			match_filter = true
		elif current_filter == "tier2" and w_len == 2:
			match_filter = true
		elif current_filter == "tier3" and w_len >= 3:
			match_filter = true
		elif current_filter == cat:
			match_filter = true

		var match_search = true
		if search_query != "":
			if is_unlocked:
				match_search = word_str.contains(search_query) or \
					w.get("name", "").contains(search_query) or \
					w.get("desc", "").contains(search_query)
			else:
				match_search = false

		return match_filter and match_search
	)

	var percentage = (float(discovered_words.size()) / float(maxi(1, all_words.size()))) * 100.0
	count_label.text = "📖 활자 도감 달성률: %d / %d개 (%.1f%%) | 표시 중: %d개" % [
		discovered_words.size(), all_words.size(), percentage, filtered.size()
	]

	for w in filtered:
		var word_str = w.get("word", "")
		var is_unlocked = disc_set.has(word_str)
		var word_len = word_str.length()

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 115)

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

		if is_unlocked and ResourceLoader.exists(w.get("icon", "")):
			icon.texture = load(w["icon"])
		hbox_top.add_child(icon)

		var tier_badge = "⭐ 1글자"
		if word_len == 2: tier_badge = "⭐⭐ 2글자 상위"
		elif word_len >= 3: tier_badge = "⭐⭐⭐ 3글자 신화"

		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)

		var dmg_lbl = Label.new()
		dmg_lbl.add_theme_font_size_override("font_size", 12)

		var recipe_lbl = Label.new()
		recipe_lbl.add_theme_font_size_override("font_size", 10)

		var desc_lbl = Label.new()
		desc_lbl.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if is_unlocked:
			name_lbl.text = " %s [%s]" % [word_str, tier_badge]
			if word_len >= 3:
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.9))
			elif word_len == 2:
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			else:
				name_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))

			# 도감의 숫자는 **실제 타워가 내는 값** 이어야 한다.
			#
			# 예전에는 DB 의 `damage` 필드를 그대로 찍었다. 그 필드는 게임이 읽지 않아서
			# 도감이 거짓말을 했다: 가루 44 · 바늘 22 로 보여 주지만 실제 타워는
			# 가루 9.5 DPS · 바늘 45.4 DPS 다 — 도감이 **4.8배 약한 쪽을 1위**로 보여 주고
			# 있었고, 디렉터가 바로 그 숫자를 믿고 "힌트가 더 약한 단어를 목표로 세운다" 를
			# 잡았다. 이제 힌트와 같은 식(WordTower.preview_stats)을 쓴다.
			#
			# 두 줄로 나눈 이유: 발당 피해만 보면 '빠른 대신 약한' 특성(질풍)이
			# 손해로 보이고, DPS 만 보면 '한 방 센' 특성(유성)이 손해로 보인다.
			# 카드 폭(250px)이 좁아 한 줄에 둘 다 넣으면 이름이 잘린다.
			var stats: Dictionary = WordTower.preview_stats(word_str, w)
			dmg_lbl.text = "💥 %.1f\nDPS %.1f" % [stats["per_hit"], stats["dps"]]
			dmg_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))

			var recipe_str = get_jamo_recipe(word_str)
			recipe_lbl.text = "🧩 조합: %s" % recipe_str
			recipe_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))

			desc_lbl.text = w.get("desc", "")
		else:
			panel.modulate = Color(0.65, 0.65, 0.75, 0.8)
			name_lbl.text = " ❓ ??? [%s]" % tier_badge
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

			dmg_lbl.text = "💥 ???"
			dmg_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

			var hidden_recipe = []
			for idx in range(word_len): hidden_recipe.append("[ ? ]")
			recipe_lbl.text = "🧩 미해금 조합: %s" % (" + ".join(hidden_recipe))
			recipe_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

			desc_lbl.text = "“아직 조합해보지 못한 미지의 활자입니다. 자모를 결합하여 도감을 해금하세요.”"
			desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

		hbox_top.add_child(name_lbl)
		hbox_top.add_child(dmg_lbl)
		vbox.add_child(recipe_lbl)
		vbox.add_child(desc_lbl)

		cards_grid.add_child(panel)
