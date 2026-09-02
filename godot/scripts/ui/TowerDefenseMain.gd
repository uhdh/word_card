# TowerDefenseMain.gd
# 한글 자모 결합 타워 디펜스 메인 컨트롤러 (자동 로드 및 세이브 덮어쓰기 방지 완벽 패치)
extends Control

const SaveManager = preload("res://scripts/core/SaveManager.gd")

@onready var hp_label: Label = $TopBar/Info/HpBox/HpLabel
@onready var gold_label: Label = $TopBar/Info/GoldBox/GoldLabel
@onready var wave_label: Label = $TopBar/Info/WaveBox/WaveLabel

@onready var btn_start_wave: Button = $TopBar/Actions/BtnStartWave
@onready var btn_save: Button = $TopBar/Actions/BtnSave
@onready var btn_load: Button = $TopBar/Actions/BtnLoad
@onready var btn_speed: Button = $TopBar/Actions/BtnSpeed
@onready var btn_lexicon: Button = $TopBar/Actions/BtnLexicon
@onready var btn_mute: Button = $TopBar/Actions/BtnMute

@onready var defense_field: DefenseField = $VBox/FieldContainer/DefenseField
@onready var jamo_belt: JamoBelt = $VBox/JamoBelt
@onready var modal_layer: Control = $ModalLayer

var current_speed_scale: float = 1.0
var reroll_dice: int = 3
var owned_relics: Array = []
var _is_loading_state: bool = true # 게임 시작 시 기존 세이브 덮어쓰기 방지 플래그

func _ready() -> void:
	_is_loading_state = true

	btn_start_wave.pressed.connect(_on_start_wave_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_lexicon.pressed.connect(_on_lexicon_pressed)
	btn_mute.pressed.connect(_on_mute_pressed)

	btn_load.disabled = not SaveManager.has_save_file()

	if defense_field:
		defense_field.gold = 30 # 시작 기본 골드
		defense_field.base_hp_changed.connect(_on_base_hp_changed)
		defense_field.gold_changed.connect(_on_gold_changed)
		defense_field.wave_status_changed.connect(_on_wave_status_changed)
		defense_field.wave_cleared.connect(_on_wave_cleared)
		defense_field.tower_info_requested.connect(_on_tower_info_requested)
		defense_field.game_over.connect(_on_game_over)

	if jamo_belt:
		jamo_belt.parsed_towers_updated.connect(_on_parsed_towers_updated)
		jamo_belt.jamo_changed.connect(_on_jamo_changed)

	# Setup button tooltips / shortcut hints
	btn_start_wave.tooltip_text = "단축키: [SPACE]"
	btn_save.tooltip_text = "단축키: [Ctrl + S] 또는 [S]"
	btn_load.tooltip_text = "단축키: [L]"
	btn_speed.tooltip_text = "단축키: [1] / [2] / [3] / [4]"
	btn_lexicon.tooltip_text = "단축키: [TAB] 또는 [D]"
	btn_mute.tooltip_text = "단축키: [M]"

	# 기존 세이브 파일이 있다면 자동으로 직전 게임 상태를 복원
	if SaveManager.has_save_file():
		_on_load_pressed()
	else:
		jamo_belt.render_belt()

	_is_loading_state = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_SPACE:
			if not defense_field.is_wave_running:
				_on_start_wave_pressed()
		KEY_1:
			set_speed_scale(1.0)
		KEY_2:
			set_speed_scale(2.0)
		KEY_3, KEY_4:
			set_speed_scale(4.0)
		KEY_TAB, KEY_D:
			_on_lexicon_pressed()
		KEY_S:
			if event.ctrl_pressed or not event.alt_pressed:
				_on_save_pressed()
		KEY_L:
			if not btn_load.disabled:
				_on_load_pressed()
		KEY_M:
			_on_mute_pressed()

func _on_save_pressed() -> void:
	save_game_state()
	btn_save.text = "✅ 저장됨!"
	SoundEngine.play_buff()
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func(): btn_save.text = "💾 저장")

func _on_load_pressed() -> void:
	var data = SaveManager.load_game()
	if data.is_empty():
		return

	_is_loading_state = true

	if data.has("jamo_list"):
		jamo_belt.jamo_list.clear()
		for c in data["jamo_list"]:
			jamo_belt.jamo_list.append(str(c))

	if data.has("base_hp"):
		defense_field.base_hp = int(data["base_hp"])
		defense_field.base_hp_changed.emit(defense_field.base_hp, defense_field.max_base_hp)

	if data.has("gold"):
		defense_field.gold = int(data["gold"])
		defense_field.gold_changed.emit(defense_field.gold)

	if data.has("current_wave"):
		defense_field.current_wave = int(data["current_wave"])
		wave_label.text = "🌊 %d / %d 웨이브" % [defense_field.current_wave, defense_field.MAX_WAVES]

	if data.has("reroll_dice"):
		reroll_dice = int(data["reroll_dice"])

	if data.has("relics"):
		owned_relics = data["relics"].duplicate()

	jamo_belt.render_belt()
	SoundEngine.play_victory()
	btn_load.disabled = false
	print("📂 Game state successfully restored from save! (Wave: %d, Gold: %d, Dice: %d, Relics: %d)" % [
		defense_field.current_wave, defense_field.gold, reroll_dice, owned_relics.size()
	])

	_is_loading_state = false

func save_game_state() -> void:
	if _is_loading_state or defense_field == null or jamo_belt == null:
		return
	SaveManager.save_game(
		jamo_belt.jamo_list,
		defense_field.base_hp,
		defense_field.max_base_hp,
		defense_field.gold,
		defense_field.current_wave,
		reroll_dice,
		owned_relics
	)
	btn_load.disabled = false

func _on_base_hp_changed(current: int, max_hp: int) -> void:
	hp_label.text = "❤️ 기지 HP: %d / %d" % [current, max_hp]

func _on_gold_changed(current: int) -> void:
	gold_label.text = "🪙 %d G" % current

func _on_wave_status_changed(wave: int, max_wave: int, is_running: bool) -> void:
	wave_label.text = "🌊 %d / %d 웨이브" % [wave, max_wave]
	btn_start_wave.disabled = is_running
	btn_start_wave.text = "⚔️ 웨이브 진행 중..." if is_running else "▶ 다음 웨이브 시작"

func _on_wave_cleared(wave: int, bonus_gold: int) -> void:
	var final_bonus = bonus_gold
	if has_relic("relic_merchant_pouch"):
		final_bonus = int(bonus_gold * 1.5)

	var modal_scene = load("res://scenes/tower/WaveRewardModal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal_layer.add_child(modal)
		modal.setup(
			wave,
			final_bonus,
			reroll_dice,
			func(chosen_char: String):
				jamo_belt.add_jamo(chosen_char)
				save_game_state()
				if wave == 2 or wave == 4:
					_trigger_merchant_encounter(wave),
			func(new_dice_count: int):
				reroll_dice = new_dice_count
				save_game_state()
		)

func _trigger_merchant_encounter(wave: int) -> void:
	var modal_scene = load("res://scenes/tower/ShopModal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal_layer.add_child(modal)
		modal.setup(defense_field.gold, jamo_belt.jamo_list, owned_relics)

		modal.jamo_bought.connect(func(char_str: String, cost: int):
			defense_field.gold -= cost
			defense_field.gold_changed.emit(defense_field.gold)
			jamo_belt.add_jamo(char_str)
			save_game_state()
		)

		modal.jamo_removed.connect(func(idx: int, cost: int):
			defense_field.gold -= cost
			defense_field.gold_changed.emit(defense_field.gold)
			if idx >= 0 and idx < jamo_belt.jamo_list.size():
				jamo_belt.jamo_list.remove_at(idx)
				jamo_belt.render_belt()
			save_game_state()
		)

		modal.relic_bought.connect(func(relic_data: Dictionary, cost: int):
			defense_field.gold -= cost
			defense_field.gold_changed.emit(defense_field.gold)
			apply_relic_effect(relic_data)
			save_game_state()
		)

func apply_relic_effect(relic_data: Dictionary) -> void:
	owned_relics.append(relic_data)
	var r_id = relic_data.get("id", "")

	if r_id == "relic_golden_dice":
		reroll_dice += 2
	elif r_id == "relic_fortress_rune":
		defense_field.max_base_hp += 10
		defense_field.base_hp = mini(defense_field.base_hp + 10, defense_field.max_base_hp)
		defense_field.base_hp_changed.emit(defense_field.base_hp, defense_field.max_base_hp)

func has_relic(r_id: String) -> bool:
	for r in owned_relics:
		if r.get("id") == r_id: return true
	return false

func _on_tower_info_requested(tower: WordTower) -> void:
	if tower == null or tower.word_data.is_empty():
		return
	var modal_scene = load("res://scenes/tower/TowerInfoModal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal_layer.add_child(modal)
		modal.setup(tower.word_data, tower.syllable, tower.attack_range, tower.attack_interval)

func _on_jamo_changed() -> void:
	if not _is_loading_state:
		save_game_state()

func _on_parsed_towers_updated(parsed_list: Array) -> void:
	if defense_field:
		defense_field.update_towers_from_parsed_list(parsed_list)

func _on_start_wave_pressed() -> void:
	if defense_field:
		defense_field.start_next_wave()
		btn_start_wave.disabled = true
		btn_start_wave.text = "⚔️ 웨이브 진행 중..."
		SoundEngine.play_wave_start()

func _on_speed_pressed() -> void:
	if current_speed_scale == 1.0:
		set_speed_scale(2.0)
	elif current_speed_scale == 2.0:
		set_speed_scale(4.0)
	else:
		set_speed_scale(1.0)

func set_speed_scale(speed: float) -> void:
	current_speed_scale = speed
	Engine.time_scale = speed
	if speed == 1.0:
		btn_speed.text = "▶ 1x 배속"
	elif speed == 2.0:
		btn_speed.text = "⏩ 2x 배속"
	elif speed >= 4.0:
		btn_speed.text = "⚡ 4x 초고속"

func _on_lexicon_pressed() -> void:
	var modal = load("res://scenes/LexiconModal.tscn").instantiate()
	modal_layer.add_child(modal)

func _on_mute_pressed() -> void:
	var is_muted = SoundEngine.toggle_mute()
	btn_mute.text = "🔇" if is_muted else "🔊"

func _on_game_over(is_victory: bool) -> void:
	var modal = PanelContainer.new()
	modal.custom_minimum_size = Vector2(400, 240)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal.add_child(vbox)

	var title = Label.new()
	title.text = "🎉 디펜스 승리!" if is_victory else "💀 기지 함락 (패배)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var btn_retry = Button.new()
	btn_retry.text = "처음부터 다시하기"
	btn_retry.pressed.connect(func():
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn_retry)
	modal_layer.add_child(modal)
