# TitleScreen.gd
# 게임 실행 시 가장 먼저 보이는 타이틀 화면.
# - 게임 로고 + 부제 + 세계관 한 줄 소개
# - 시작 / 이어하기 / 세계관 / 도감 / 종료
# - 첫 실행 시에만 짧은 인트로 연출(페이드 인 + 로고 슬라이드)을 재생
extends Control

const Palette = preload("res://scripts/ui/Palette.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

const GAME_SCENE := "res://scenes/TowerDefenseMain.tscn"

@onready var root_box: VBoxContainer = $Center
@onready var title_label: Label = $Center/TitleLabel
@onready var subtitle_label: Label = $Center/SubtitleLabel
@onready var tagline_label: Label = $Center/TaglineLabel
@onready var btn_row: VBoxContainer = $Center/ButtonRow
@onready var footer_label: Label = $Footer

func _ready() -> void:
	_build_ui()
	_play_intro()

func _build_ui() -> void:
	title_label.text = "언어의 조각"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 58)
	title_label.add_theme_color_override("font_color", Palette.TX_GOLD)
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	title_label.add_theme_constant_override("outline_size", 8)

	subtitle_label.text = "말의 심연"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 26)
	subtitle_label.add_theme_color_override("font_color", Palette.TX_PRIMARY)

	tagline_label.text = "흩어진 자모를 엮어 단어를 만들고,\n그 단어로 심연의 어둠을 막아내세요."
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.add_theme_font_size_override("font_size", 14)
	tagline_label.add_theme_color_override("font_color", Palette.TX_SECONDARY)

	var has_save := SaveManager.has_save_file()

	if has_save:
		_add_button("이어하기", "PrimaryButton", _on_continue_pressed, 260, 50)
		_add_button("새로 시작", "GhostButton", _on_new_game_pressed, 260, 44)
	else:
		_add_button("게임 시작", "PrimaryButton", _on_new_game_pressed, 260, 50)

	_add_button("세계관", "GhostButton", func(): _open_text_modal("세계관", LORE_TEXT), 260, 40)
	_add_button("용어 도감", "GhostButton", _on_lexicon_pressed, 260, 40)
	_add_button("종료", "GhostButton", func(): get_tree().quit(), 260, 40)

	footer_label.text = "자모를 모으고 · 단어를 세우고 · 기지를 지켜라"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 12)
	footer_label.add_theme_color_override("font_color", Palette.TX_MUTED)

func _add_button(text: String, variation: String, cb: Callable, w: int, h: int) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 17 if variation == "PrimaryButton" else 15)
	b.pressed.connect(cb)
	btn_row.add_child(b)

func _play_intro() -> void:
	var center: Control = $Center
	center.modulate.a = 0.0
	center.position.y += 24.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(center, "modulate:a", 1.0, 0.7)
	tw.tween_property(center, "position:y", center.position.y - 24.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_continue_pressed() -> void:
	SoundEngine.play_tile_click()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_new_game_pressed() -> void:
	# 타이틀의 버튼은 단어 완성이 아니다 — 나머지 타이틀 버튼과 같은 클릭음으로 맞춘다.
	# (여기 남겨 두면 플레이어 귀에는 word_crafted 가 '새 게임 소리' 로 먼저 각인된다)
	SoundEngine.play_tile_click()
	SaveManager.delete_save_file()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_lexicon_pressed() -> void:
	SoundEngine.play_tile_click()
	var scene = load("res://scenes/LexiconModal.tscn")
	if scene == null:
		return
	var modal = scene.instantiate()
	add_child(modal)

func _open_text_modal(title_text: String, body_text: String) -> void:
	SoundEngine.play_tile_click()
	var modal := PanelContainer.new()
	modal.theme_type_variation = "ModalPanel"
	modal.custom_minimum_size = Vector2(560, 0)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.z_index = 80

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	modal.add_child(vb)

	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(520, 0)
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Palette.TX_SECONDARY)
	body.text = body_text
	vb.add_child(body)

	var close := Button.new()
	close.theme_type_variation = "GhostButton"
	close.text = "닫기"
	close.custom_minimum_size = Vector2(140, 38)
	close.pressed.connect(func():
		modal.queue_free()
		SoundEngine.play_tile_click()
	)
	vb.add_child(close)
	add_child(modal)

	modal.pivot_offset = modal.size * 0.5
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.94, 0.94)
	var tw := modal.create_tween()
	tw.set_parallel(true)
	tw.tween_property(modal, "modulate:a", 1.0, 0.18)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

const LORE_TEXT := """[b]아주 먼 옛날, 세상의 모든 낱말이 하나의 강이 되어 흐르던 시절이 있었습니다.[/b]

어느 날 심연에서 무언가가 기어올라와 강줄기를 끊어버렸고,
낱말들은 산산조각 난 [color=#F5C451]자모[/color]로 흩어져 버렸습니다.

말을 잃은 것들은 형체를 감추고, 밤마다 기지로 다가옵니다.

[b]당신은 흩어진 조각을 다시 엮는 '엮는 자'입니다.[/b]

자모를 모아 단어를 완성하는 순간, 그 단어는 빛나는 탑이 되어 길을 지킵니다.
단단한 단어일수록 강한 탑이 되고, 서로 어울리는 단어들은 더 큰 힘을 냅니다.

[color=#A78BFA]세 막[/color]에 걸친 여정 끝에서, 끊어진 강줄기를 다시 이으십시오."""
