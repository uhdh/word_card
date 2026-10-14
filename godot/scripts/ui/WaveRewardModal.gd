# WaveRewardModal.gd
# 웨이브 클리어 시 자모 3택 1 보상 팝업 및 주사위 리롤(새로고침) 모달
# - Phase 3: 디자인 토큰(Palette) + theme_type_variation 기반으로 전면 재구성
# - 희귀도별 카드 색상/문양 차등, 카드 호버 리프트, 등장 스태거 애니메이션
class_name WaveRewardModal
extends Control

const Palette = preload("res://scripts/ui/Palette.gd")

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var gold_label: Label = $Panel/VBox/GoldLabel
@onready var subtitle_label: Label = $Panel/VBox/Subtitle
@onready var choices_container: HBoxContainer = $Panel/VBox/ChoicesContainer
@onready var btn_reroll: Button = $Panel/VBox/RerollRow/BtnReroll
@onready var dice_label: Label = $Panel/VBox/RerollRow/DiceLabel
@onready var btn_skip: Button = $Panel/VBox/SkipRow/BtnSkip

## 활자를 골랐을 때 불린다. **인자 2개**: `(고른 활자, 고른 카드의 화면 좌표)`.
## 건너뛰기면 `("", Vector2.ZERO)` — 출발점이 없다는 뜻이다.
## 좌표를 넘기는 이유: 벨트로 날아가는 연출은 **모달이 사라진 뒤에도 살아 있어야** 하는데,
## 모달은 `_close()` 에서 `queue_free` 되므로 자기 자식으로 만들 수 없다.
var on_jamo_chosen_cb: Callable
var on_dice_changed_cb: Callable
var remaining_dice: int = 3
var _wave: int = 1
var _bonus_gold: int = 0

func setup(wave: int, bonus_gold: int, dice_count: int, on_chosen: Callable, on_dice_changed: Callable = Callable()) -> void:
	on_jamo_chosen_cb = on_chosen
	on_dice_changed_cb = on_dice_changed
	remaining_dice = dice_count
	_wave = wave
	_bonus_gold = bonus_gold

	title_label.text = "제 %d 웨이브 클리어" % wave
	title_label.theme_type_variation = &"TitleLabel"
	gold_label.text = "클리어 보너스  +%d G" % bonus_gold
	if subtitle_label:
		subtitle_label.text = "다음 웨이브를 대비해 활자 1개를 고르세요"
		subtitle_label.theme_type_variation = &"MutedLabel"

	if btn_reroll:
		if not btn_reroll.pressed.is_connected(_on_reroll_pressed):
			btn_reroll.pressed.connect(_on_reroll_pressed)
		btn_reroll.theme_type_variation = &"GhostButton"
	if btn_skip:
		if not btn_skip.pressed.is_connected(_on_skip_pressed):
			btn_skip.pressed.connect(_on_skip_pressed)
		btn_skip.theme_type_variation = &"GhostButton"

	generate_choices()
	update_dice_ui()
	# 승리 팡파레는 여기서 울리지 않는다 — 라운드 클리어 흐름의
	# `DefenseField._grant_round_reward` 가 같은 프레임에 이미 울렸고, 두 호출이
	# 12개 풀의 **서로 다른 플레이어**로 가서 같은 팡파레가 겹쳐 +6 dB 가 됐다.
	_play_intro()

## 모달 자체 등장 연출 (뒤에서부터 살짝 튀어 오르는 BACK_OUT)
func _play_intro() -> void:
	var panel: Control = $Panel
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)

func update_dice_ui() -> void:
	if btn_reroll:
		btn_reroll.text = "보상 새로고침" if remaining_dice > 0 else "주사위 소진"
		btn_reroll.disabled = (remaining_dice <= 0)
	if dice_label:
		dice_label.text = "남은 주사위 %d개" % remaining_dice
		dice_label.theme_type_variation = &"StatLabel" if remaining_dice > 0 else &"MutedLabel"

func generate_choices() -> void:
	for c in choices_container.get_children():
		c.queue_free()

	# 모음 1개 확정 보장 및 균형 잡힌 가중치 추첨
	var choices: Array = HangulEngine.generate_reward_choices(3)

	for i in range(choices.size()):
		var char_str: String = choices[i]
		var card := _build_choice_card(char_str)
		choices_container.add_child(card)
		# 스태거 등장
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(card, "modulate:a", 1.0, 0.16)

## 단일 보상 카드 생성 — 희귀도에 따라 테두리/문양/색을 차등 적용
func _build_choice_card(char_str: String) -> Button:
	var rarity: String = HangulEngine.get_rarity(char_str)
	var rarity_col: Color = Palette.rarity_color(rarity)

	var card := Button.new()
	card.custom_minimum_size = Vector2(96, 120)
	card.focus_mode = Control.FOCUS_NONE

	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.BG_PANEL_HI
	bg.border_color = rarity_col
	bg.set_border_width_all(2 if rarity == "common" else 3)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 6.0
	bg.content_margin_right = 6.0

	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.BG_PANEL_HI.lightened(0.10)
	hover.border_color = rarity_col.lightened(0.2)
	hover.shadow_color = Palette.with_alpha(rarity_col, 0.45)
	hover.shadow_size = 10

	var pressed := bg.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.BG_INSET

	card.add_theme_stylebox_override("normal", bg)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)
	card.add_theme_stylebox_override("focus", hover)

	# 카드 내부 레이아웃: 문양 / 글자 / 등급 / 설명
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vb)

	var glyph := Label.new()
	glyph.text = Palette.rarity_glyph(rarity)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 12)
	glyph.add_theme_color_override("font_color", rarity_col)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(glyph)

	var big := Label.new()
	big.text = char_str
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 36)
	big.add_theme_color_override("font_color", Palette.TX_PRIMARY)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(big)

	var tier := Label.new()
	tier.text = _rarity_label(rarity)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier.add_theme_font_size_override("font_size", 11)
	tier.add_theme_color_override("font_color", rarity_col)
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tier)

	card.tooltip_text = "[%s] %s\n%s\n타일 벨트에 추가됩니다." % [char_str, _rarity_label(rarity), _rarity_hint(rarity)]
	# 카드 자신을 함께 넘긴다 — 고른 카드의 **화면 좌표**가 벨트로 날아가는 연출의
	# 출발점이다(§2.6 문제 2). 문자열만 넘기면 그 연출이 시작할 자리를 알 수 없다.
	card.pressed.connect(_on_choice_selected.bind(char_str, card))
	return card

func _rarity_label(rarity: String) -> String:
	match rarity:
		"super_rare": return "초희귀"
		"rare": return "희귀"
		_: return "일반"

func _rarity_hint(rarity: String) -> String:
	match rarity:
		"super_rare": return "4변환 만능 활자"
		"rare": return "2변환 활자"
		_: return "기본 자모"

func _on_reroll_pressed() -> void:
	if remaining_dice <= 0: return
	remaining_dice -= 1
	# 주사위를 **쓴다** — 타일 회전음(`play_tile_rotate`)을 빌려 쓰지 않는다.
	# 회전은 웨이브마다 수십 번, 리롤은 런 전체에 3~8번이다. 드문 결정에는 제 소리가 있어야 한다.
	SoundEngine.play_reroll()
	generate_choices()
	update_dice_ui()

	if on_dice_changed_cb.is_valid():
		on_dice_changed_cb.call(remaining_dice)

func _on_choice_selected(chosen_char: String, card: Control) -> void:
	# 활자를 '받는' 순간이다 — word_crafted 는 단어 완성 전용이다.
	SoundEngine.play_coin()
	if on_jamo_chosen_cb.is_valid():
		# 고른 카드의 화면 좌표를 함께 넘긴다. **모달은 곧 사라지므로** 날아가는 연출을
		# 여기서 만들 수 없다(모달과 함께 해제된다) — 그래서 좌표만 넘기고 연출은
		# 호출부(`TowerDefenseMain`)가 만든다.
		on_jamo_chosen_cb.call(chosen_char, card.get_global_rect().get_center())
	_close()

func _on_skip_pressed() -> void:
	SoundEngine.play_tile_click()
	if on_jamo_chosen_cb.is_valid():
		# 건너뛰기는 받는 활자가 없다 — 출발점도 없다(ZERO 면 연출을 만들지 않는다).
		on_jamo_chosen_cb.call("", Vector2.ZERO)
	_close()

## 페이드아웃 후 제거 (즉시 queue_free 하면 사라지는 느낌이 툭 끊김)
func _close() -> void:
	var panel: Control = $Panel
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.14)
	tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
