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
	# 1개 초성, 1개 모음, 1개 종성 or 랜덤 조합
	choices.append(cho_pool.pick_random())
	choices.append(jung_pool.pick_random())
	choices.append(cho_pool.pick_random() if randf() < 0.5 else jong_pool.pick_random())

	# Ensure 3 unique choices if possible
	for i in range(choices.size()):
		var char_str = choices[i]
		var btn = Button.new()
		btn.text = char_str
		btn.custom_minimum_size = Vector2(80, 100)
		btn.add_theme_font_size_override("font_size", 32)
		btn.modulate = Color(1.0, 0.9, 0.4)

		# Subtitle hint
		var type_hint = "초성"
		if HangulEngine.JUNGSUNG.has(char_str): type_hint = "중성 (모음)"
		elif HangulEngine.JONGSUNG.has(char_str): type_hint = "자음/받침"

		btn.tooltip_text = "[%s] 활자 획득\n타일 벨트에 추가됩니다." % char_str
		btn.pressed.connect(_on_choice_selected.bind(char_str))
		choices_container.add_child(btn)

	SoundEngine.play_victory()

func _on_choice_selected(chosen_char: String) -> void:
	SoundEngine.play_word_crafted()
	if on_jamo_chosen_cb.is_valid():
		on_jamo_chosen_cb.call(chosen_char)
	queue_free()
