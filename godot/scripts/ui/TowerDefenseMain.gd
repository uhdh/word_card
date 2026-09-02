# TowerDefenseMain.gd
# 한글 자모 결합 타워 디펜스 메인 컨트롤러
extends Control

@onready var hp_label: Label = $TopBar/Info/HpLabel
@onready var gold_label: Label = $TopBar/Info/GoldLabel
@onready var wave_label: Label = $TopBar/Info/WaveLabel

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

func _ready() -> void:
	btn_start_wave.pressed.connect(_on_start_wave_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_lexicon.pressed.connect(_on_lexicon_pressed)
	btn_mute.pressed.connect(_on_mute_pressed)

	btn_load.disabled = not SaveManager.has_save_file()

	if defense_field:
		defense_field.base_hp_changed.connect(_on_base_hp_changed)
		defense_field.gold_changed.connect(_on_gold_changed)
		defense_field.wave_status_changed.connect(_on_wave_status_changed)
		defense_field.wave_cleared.connect(_on_wave_cleared)
		defense_field.game_over.connect(_on_game_over)

	if jamo_belt:
		jamo_belt.parsed_towers_updated.connect(_on_parsed_towers_updated)
		jamo_belt.request_buy_jamo.connect(_on_buy_jamo_requested)

	# Initial sync
	jamo_belt.render_belt()

func _on_save_pressed() -> void:
	save_game_state()
	btn_save.text = "✅ 저장됨!"
	SoundEngine.play_buff()
	btn_load.disabled = false
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): if is_instance_valid(btn_save): btn_save.text = "💾 저장")

func _on_load_pressed() -> void:
	if not SaveManager.has_save_file():
		return
	var data = SaveManager.load_game()
	if data.is_empty():
		return

	# Restore state
	if data.has("jamo_list"):
		jamo_belt.jamo_list.clear()
		for c in data["jamo_list"]:
			jamo_belt.jamo_list.append(c)

	if data.has("base_hp"):
		defense_field.base_hp = int(data["base_hp"])
		defense_field.base_hp_changed.emit(defense_field.base_hp, defense_field.max_base_hp)

	if data.has("gold"):
		defense_field.gold = int(data["gold"])
		defense_field.gold_changed.emit(defense_field.gold)

	if data.has("current_wave"):
		defense_field.current_wave = int(data["current_wave"])
		wave_label.text = "🌊 %d / %d 웨이브" % [defense_field.current_wave, defense_field.MAX_WAVES]

	jamo_belt.render_belt()
	SoundEngine.play_victory()
	print("📂 Game state successfully restored from save!")

func save_game_state() -> void:
	if defense_field == null or jamo_belt == null:
		return
	SaveManager.save_game(
		jamo_belt.jamo_list,
		defense_field.base_hp,
		defense_field.max_base_hp,
		defense_field.gold,
		defense_field.current_wave
	)

func _on_base_hp_changed(current: int, max_hp: int) -> void:
	hp_label.text = "❤️ 기지 HP: %d / %d" % [current, max_hp]

func _on_gold_changed(current: int) -> void:
	gold_label.text = "🪙 %d G" % current

func _on_wave_status_changed(wave: int, max_wave: int, is_running: bool) -> void:
	wave_label.text = "🌊 %d / %d 웨이브" % [wave, max_wave]
	btn_start_wave.disabled = is_running
	btn_start_wave.text = "⚔️ 웨이브 진행 중..." if is_running else "▶ 다음 웨이브 시작"

func _on_wave_cleared(wave: int, bonus_gold: int) -> void:
	var modal_scene = load("res://scenes/tower/WaveRewardModal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		modal_layer.add_child(modal)
		modal.setup(wave, bonus_gold, func(chosen_char: String):
			jamo_belt.add_jamo(chosen_char)
			save_game_state()
		)

func _on_parsed_towers_updated(parsed_list: Array) -> void:
	if defense_field:
		defense_field.update_towers_from_parsed_list(parsed_list)

func _on_buy_jamo_requested() -> void:
	if defense_field.gold >= 10:
		defense_field.gold -= 10
		defense_field.gold_changed.emit(defense_field.gold)
		
		var pool = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ", "ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"]
		var pick = pool.pick_random()
		jamo_belt.add_jamo(pick)
		SoundEngine.play_coin()

func _on_start_wave_pressed() -> void:
	defense_field.start_next_wave()

func _on_speed_pressed() -> void:
	if current_speed_scale == 1.0:
		current_speed_scale = 2.0
		Engine.time_scale = 2.0
		btn_speed.text = "⏩ 2x 배속"
	else:
		current_speed_scale = 1.0
		Engine.time_scale = 1.0
		btn_speed.text = "▶ 1x 배속"

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
	title.theme_override_font_sizes.font_size = 22
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_victory:
		title.text = "🏆 타워 디펜스 승리!\n모든 활자 웨이브를 성공적으로 방어했습니다!"
		title.modulate = Color(1.0, 0.85, 0.3)
		SoundEngine.play_victory()
	else:
		title.text = "💀 기지가 파괴되었습니다...\n활자의 힘이 흩어졌습니다."
		title.modulate = Color(1.0, 0.4, 0.4)
		SoundEngine.play_hit()
	vbox.add_child(title)

	var btn = Button.new()
	btn.text = "다시 플레이하기"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn)

	modal_layer.add_child(modal)
