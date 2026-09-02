# TowerInfoModal.gd
# 필드 상의 타워 클릭 시 팝업되는 타워 상세 스펙 및 특수 효과 인스펙터 모달
class_name TowerInfoModal
extends Control

@onready var icon_rect: TextureRect = $Panel/VBox/Header/IconContainer/IconRect
@onready var title_label: Label = $Panel/VBox/Header/VBoxTitle/TitleLabel
@onready var tier_label: Label = $Panel/VBox/Header/VBoxTitle/TierLabel
@onready var stats_label: Label = $Panel/VBox/StatsContainer/StatsLabel
@onready var desc_label: Label = $Panel/VBox/DescContainer/DescLabel
@onready var recipe_label: Label = $Panel/VBox/RecipeContainer/RecipeLabel
@onready var btn_close: Button = $Panel/VBox/BtnClose
@onready var dim_rect: ColorRect = $Dim

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(func(): queue_free())
	if dim_rect:
		dim_rect.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				queue_free()
		)
	SoundEngine.play_tile_click()

func setup(data: Dictionary, word_str: String, p_range: float, p_interval: float) -> void:
	var word_len = word_str.length()
	var tier_name = "⭐ 1글자 기본 타워"
	if word_len == 2: tier_name = "⭐⭐ 2글자 상위 타워"
	elif word_len >= 3: tier_name = "⭐⭐⭐ 3글자 신화 타워"

	title_label.text = "🏛️ %s 타워" % word_str
	tier_label.text = "%s (%s)" % [tier_name, data.get("name", "")]

	if word_len >= 3:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.9))
		tier_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.9))
	elif word_len == 2:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		tier_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	else:
		title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		tier_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))

	if ResourceLoader.exists(data.get("icon", "")) and icon_rect:
		icon_rect.texture = load(data["icon"])

	# Stats
	var dmg = data.get("damage", 4)
	stats_label.text = "💥 공격력: %d  |  🎯 사거리: %d px  |  ⏱️ 쿨타임: %.2f초" % [
		dmg, int(p_range), p_interval
	]

	# Description
	desc_label.text = data.get("desc", "기본 활자 탄환을 발사합니다.")

	# Recipe
	var recipe_str = get_jamo_recipe(word_str)
	recipe_label.text = "🧩 조합 레시피: %s" % recipe_str

func get_jamo_recipe(word: String) -> String:
	var syllables = []
	for i in range(word.length()):
		var ch = word.substr(i, 1)
		var decomp = HangulEngine.decompose_syllable(ch)
		if decomp.is_empty():
			syllables.append(ch)
		else:
			var parts = []
			if decomp.get("cho", "") != "": parts.append(decomp["cho"])
			if decomp.get("jung", "") != "": parts.append(decomp["jung"])
			if decomp.get("jong", "") != "": parts.append(decomp["jong"])
			syllables.append("[%s]" % "".join(parts))
	return " ➔ ".join(syllables)
