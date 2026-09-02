# WaveRewardModal.gd
# 웨이브 클리어 시 자모 3택 1 보상 팝업 및 🎲 주사위 리롤(새로고침) 모달
class_name WaveRewardModal
extends Control

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var gold_label: Label = $Panel/VBox/GoldLabel
@onready var choices_container: HBoxContainer = $Panel/VBox/ChoicesContainer
@onready var btn_reroll: Button = $Panel/VBox/RerollRow/BtnReroll
@onready var dice_label: Label = $Panel/VBox/RerollRow/DiceLabel

var on_jamo_chosen_cb: Callable
var on_dice_changed_cb: Callable
var remaining_dice: int = 3

func setup(wave: int, bonus_gold: int, dice_count: int, on_chosen: Callable, on_dice_changed: Callable = Callable()) -> void:
	on_jamo_chosen_cb = on_chosen
	on_dice_changed_cb = on_dice_changed
	remaining_dice = dice_count

	title_label.text = "🏆 제 %d 웨이브 클리어!" % wave
	gold_label.text = "🪙 클리어 보너스: +%d G" % bonus_gold

	if btn_reroll:
		btn_reroll.pressed.connect(_on_reroll_pressed)

	generate_choices()
	update_dice_ui()
	SoundEngine.play_victory()

func update_dice_ui() -> void:
	if btn_reroll:
		btn_reroll.text = "🎲 보상 새로고침" if remaining_dice > 0 else "🎲 주사위 소진"
		btn_reroll.disabled = (remaining_dice <= 0)
	if dice_label:
		dice_label.text = "남은 주사위: %d개" % remaining_dice

func generate_choices() -> void:
	for c in choices_container.get_children():
		c.queue_free()

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

		var type_hint = "기본 자음"
		if is_rare: type_hint = "🌟 희귀 자모"
		elif HangulEngine.JUNGSUNG.has(char_str): type_hint = "중성 (모음)"

		btn.tooltip_text = "[%s] (%s) 활자 획득\n타일 벨트에 추가됩니다." % [char_str, type_hint]
		btn.pressed.connect(_on_choice_selected.bind(char_str))
		choices_container.add_child(btn)

func _on_reroll_pressed() -> void:
	if remaining_dice <= 0: return
	remaining_dice -= 1
	SoundEngine.play_tile_rotate()
	generate_choices()
	update_dice_ui()

	if on_dice_changed_cb.is_valid():
		on_dice_changed_cb.call(remaining_dice)

func _on_choice_selected(chosen_char: String) -> void:
	SoundEngine.play_word_crafted()
	if on_jamo_chosen_cb.is_valid():
		on_jamo_chosen_cb.call(chosen_char)
	queue_free()
