# Main.gd
# 게임 전체 뷰 오케스트레이터 및 모달 관리
extends Control

var player: PlayerState
var battle_manager: BattleManager
var map_manager: MapManager

@onready var hp_bar_fill: ProgressBar = $TopBar/PlayerInfo/HpBox/HpBar
@onready var hp_text: Label = $TopBar/PlayerInfo/HpBox/HpText
@onready var gold_text: Label = $TopBar/PlayerInfo/GoldBox/GoldText
@onready var floor_text: Label = $TopBar/PlayerInfo/FloorBox/FloorText
@onready var relics_container: HBoxContainer = $TopBar/PlayerInfo/RelicsContainer

@onready var btn_deck: Button = $TopBar/TopActions/BtnDeck
@onready var btn_map: Button = $TopBar/TopActions/BtnMap
@onready var btn_lexicon: Button = $TopBar/TopActions/BtnLexicon
@onready var btn_mute: Button = $TopBar/TopActions/BtnMute

@onready var view_container: Control = $ViewContainer
@onready var modal_layer: Control = $ModalLayer

var current_view_node: Node = null

func _ready() -> void:
	player = PlayerState.new()
	battle_manager = BattleManager.new(player)
	map_manager = MapManager.new()

	btn_mute.pressed.connect(_on_mute_pressed)
	btn_deck.pressed.connect(_on_deck_pressed)
	btn_map.pressed.connect(_on_map_pressed)
	btn_lexicon.pressed.connect(_on_lexicon_pressed)

	battle_manager.state_changed.connect(_on_battle_state_changed)

	update_top_bar()
	show_map()

func update_top_bar() -> void:
	hp_bar_fill.max_value = player.max_hp
	hp_bar_fill.value = player.hp
	hp_text.text = "%d/%d" % [player.hp, player.max_hp]
	gold_text.text = str(player.gold)
	
	var f = map_manager.current_floor
	floor_text.text = "1막 시작" if f == -1 else "1막 %d층" % (f + 1)
	btn_deck.text = "🎴 덱 (%d)" % player.deck.size()

	# Render Relics
	for c in relics_container.get_children():
		c.queue_free()
	for r in player.relic_manager.relics:
		var lbl = Label.new()
		lbl.text = r["icon"]
		lbl.tooltip_text = "[%s]\n%s" % [r["name"], r["desc"]]
		relics_container.add_child(lbl)

func clear_view() -> void:
	if current_view_node != null:
		current_view_node.queue_free()
		current_view_node = null

func show_map() -> void:
	clear_view()
	var scene = load("res://scenes/MapView.tscn").instantiate()
	view_container.add_child(scene)
	current_view_node = scene
	scene.setup(map_manager, self)
	update_top_bar()

func show_battle(enemy_id: String = "letter_slime") -> void:
	clear_view()
	battle_manager.start_battle(enemy_id)
	var scene = load("res://scenes/BattleView.tscn").instantiate()
	view_container.add_child(scene)
	current_view_node = scene
	scene.setup(battle_manager, self)
	update_top_bar()

func show_rest() -> void:
	clear_view()
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "🔥 휴식처 (모닥불)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var btn_heal = Button.new()
	btn_heal.text = "💧 휴식: HP 24 회복 (최대 체력의 30%)"
	btn_heal.pressed.connect(func():
		player.heal(int(player.max_hp * 0.3))
		SoundEngine.play_heal()
		update_top_bar()
		show_map()
	)
	vbox.add_child(btn_heal)

	view_container.add_child(panel)
	current_view_node = panel

func show_shop() -> void:
	clear_view()
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "🛒 활자 상점"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var btn_leave = Button.new()
	btn_leave.text = "상점 떠나기 (지도 복귀)"
	btn_leave.pressed.connect(func(): show_map())
	vbox.add_child(btn_leave)

	view_container.add_child(panel)
	current_view_node = panel

func show_event() -> void:
	clear_view()
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📜 신비한 비석"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var btn_gold = Button.new()
	btn_gold.text = "🪙 고대 금화 습득 (+40 골드)"
	btn_gold.pressed.connect(func():
		player.gold += 40
		SoundEngine.play_coin()
		update_top_bar()
		show_map()
	)
	vbox.add_child(btn_gold)

	view_container.add_child(panel)
	current_view_node = panel

func handle_node_select(node_data: Dictionary) -> void:
	map_manager.select_node(node_data["id"])
	update_top_bar()
	
	match node_data["type"]:
		"battle":
			show_battle("letter_slime" if randf() < 0.5 else "wild_boar")
		"elite":
			show_battle("ink_spirit")
		"boss":
			show_battle("ink_golem")
		"rest":
			show_rest()
		"shop":
			show_shop()
		"event":
			show_event()

func _on_battle_state_changed() -> void:
	update_top_bar()
	if battle_manager.state == "victory":
		show_reward_modal(battle_manager.rewards)
	elif battle_manager.state == "defeat":
		show_defeat_modal()

func show_reward_modal(rewards: Dictionary) -> void:
	var modal = load("res://scenes/RewardModal.tscn").instantiate()
	modal_layer.add_child(modal)
	modal.setup(rewards, player, func():
		if map_manager.current_floor >= MapManager.MAX_FLOORS - 1:
			show_act_clear_modal()
		else:
			show_map()
	)

func show_defeat_modal() -> void:
	var modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "💀 활자가 흩어졌습니다...\n여정이 여기서 끝났습니다."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var btn = Button.new()
	btn.text = "처음부터 다시 시작"
	btn.pressed.connect(func():
		modal.queue_free()
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn)
	modal_layer.add_child(modal)

func show_act_clear_modal() -> void:
	var modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "🏆 제 1막 클리어!\n『먹물에 잠식된 서예 골렘』을 쓰러뜨렸습니다!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var btn = Button.new()
	btn.text = "다시 플레이하기"
	btn.pressed.connect(func():
		modal.queue_free()
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn)
	modal_layer.add_child(modal)

func _on_mute_pressed() -> void:
	var is_muted = SoundEngine.toggle_mute()
	btn_mute.text = "🔇" if is_muted else "🔊"

func _on_deck_pressed() -> void:
	var modal = load("res://scenes/DeckModal.tscn").instantiate()
	modal_layer.add_child(modal)
	modal.setup(player.deck)

func _on_map_pressed() -> void:
	if battle_manager.state != "player_turn" and battle_manager.state != "enemy_turn":
		show_map()
	else:
		# Preview map in battle
		var modal = load("res://scenes/MapView.tscn").instantiate()
		modal_layer.add_child(modal)
		modal.setup(map_manager, self, true)

func _on_lexicon_pressed() -> void:
	var modal = load("res://scenes/LexiconModal.tscn").instantiate()
	modal_layer.add_child(modal)
