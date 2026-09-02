# WaveRewardModal.gd
# 웨이브 클리어 시 자모 3개 중 1개를 선택하여 벨트에 추가하는 보상 팝업 모달
class_name WaveRewardModal
extends Control

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var gold_label: Label = $Panel/VBox/GoldLabel
@onready var choices_container: HBoxContainer = $Panel/VBox/ChoicesContainer

var on_jamo_chosen_cb: Callable

func setup(wave: int, bonus_gold: int, on_chosen: Callable) -> void:
	on_jamo_chosen_cb = on_chosen
	title_label.text = "🏆 제 %d 웨이브 클리어!" % wave
	gold_label.text = "🪙 클리어 보너스: +%d G" % bonus_gold

	# 3개의 무작위 자모 후보 생성
	var cho_pool = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
	var jung_pool = ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"]
	var jong_pool = ["ㄱ", "ㄴ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ"]

	var choices = []
	for i in range(3):
		var pick = HangulEngine.get_weighted_random_jamo()
		if choices.has(pick) and choices.size() < 10:
			pick = HangulEngine.get_weighted_random_jamo()
		choices.append(pick)

	# Render choices with rare tile styling
	for i in range(choices.size()):
		var char_str = choices[i]
		var is_rare = HangulEngine.is_rare(char_str)

		var btn = Button.new()
		btn.text = ("🌟\n" + char_str) if is_rare else char_str
		btn.custom_minimum_size = Vector2(90, 110)
		btn.add_theme_font_size_override("font_size", 28 if is_rare else 32)
		if is_rare:
			btn.modulate = Color(1.0, 0.85, 0.25, 1.0) # Golden Rare
		else:
			btn.modulate = Color(1.0, 0.9, 0.4)

		# Subtitle hint
		var type_hint = "초성 자음"
		if is_rare: type_hint = "🌟 희귀 자모"
		elif HangulEngine.JUNGSUNG.has(char_str): type_hint = "중성 (모음)"
		elif HangulEngine.JONGSUNG.has(char_str): type_hint = "자음/받침"

		btn.tooltip_text = "[%s] (%s) 활자 획득\n타일 벨트에 추가됩니다." % [char_str, type_hint]
		btn.pressed.connect(_on_choice_selected.bind(char_str))
		choices_container.add_child(btn)

	SoundEngine.play_victory()

func _on_choice_selected(chosen_char: String) -> void:
	SoundEngine.play_word_crafted()
	if on_jamo_chosen_cb.is_valid():
		on_jamo_chosen_cb.call(chosen_char)
	queue_free()
