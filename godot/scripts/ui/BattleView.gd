# BattleView.gd
# 전투 아레나, 슬롯 장착, 단어 완성 프리뷰 및 턴 제어
extends Control

var battle_manager: BattleManager
var main_controller: Node

@onready var player_shield_label: Label = $VBox/Arena/PlayerBox/StatusBox/ShieldLabel
@onready var player_power_label: Label = $VBox/Arena/PlayerBox/StatusBox/PowerLabel
@onready var player_thorns_label: Label = $VBox/Arena/PlayerBox/StatusBox/ThornsLabel
@onready var player_regen_label: Label = $VBox/Arena/PlayerBox/StatusBox/RegenLabel

@onready var enemy_name_label: Label = $VBox/Arena/EnemyBox/EnemyName
@onready var enemy_hp_bar: ProgressBar = $VBox/Arena/EnemyBox/HpBar
@onready var enemy_hp_label: Label = $VBox/Arena/EnemyBox/HpBar/HpLabel
@onready var enemy_intent_label: Label = $VBox/Arena/EnemyBox/IntentLabel
@onready var enemy_sprite: TextureRect = $VBox/Arena/EnemyBox/SpriteBox/EnemySprite
@onready var enemy_status_label: Label = $VBox/Arena/EnemyBox/StatusLabel

@onready var slots_container: HBoxContainer = $VBox/CraftingArea/SlotsWrapper/SlotsContainer
@onready var card_box: PanelContainer = $VBox/CraftingArea/CardBox
@onready var card_title: Label = $VBox/CraftingArea/CardBox/VBox/HeaderHBox/CardTitle
@onready var card_cost: Label = $VBox/CraftingArea/CardBox/VBox/HeaderHBox/CardCost
@onready var card_desc: Label = $VBox/CraftingArea/CardBox/VBox/CardDesc
@onready var card_icon: TextureRect = $VBox/CraftingArea/CardBox/VBox/IconCenter/CardIcon
@onready var btn_play_card: Button = $VBox/CraftingArea/CardBox/VBox/BtnPlay

@onready var energy_label: Label = $VBox/BottomPanel/EnergyBox/EnergyLabel
@onready var hand_container: HBoxContainer = $VBox/BottomPanel/HandContainer
@onready var btn_end_turn: Button = $VBox/BottomPanel/DeckInfo/BtnEndTurn
@onready var deck_info_label: Label = $VBox/BottomPanel/DeckInfo/DeckCountLabel
@onready var log_label: Label = $VBox/LogScroll/CombatLogLabel

var selected_tile_id_for_combine: int = -1

func setup(bm: BattleManager, main_ctrl: Node) -> void:
	battle_manager = bm
	main_controller = main_ctrl

	battle_manager.state_changed.connect(update_ui)
	battle_manager.combat_log_added.connect(_on_log_added)

	btn_play_card.pressed.connect(_on_play_card_pressed)
	btn_end_turn.pressed.connect(_on_end_turn_pressed)

	update_ui()

func update_ui() -> void:
	if battle_manager == null or battle_manager.enemy == null:
		return

	var p = battle_manager.player
	var e = battle_manager.enemy
	var cs = battle_manager.card_system

	# Player status
	player_shield_label.text = "🛡️ %d" % p.shield if p.shield > 0 else ""
	player_power_label.text = "⚔️ +%d" % p.power if p.power > 0 else ""
	player_thorns_label.text = "🌵 %d" % p.thorns if p.thorns > 0 else ""
	player_regen_label.text = "🌿 %d" % p.regen if p.regen > 0 else ""

	# Enemy UI
	enemy_name_label.text = e.name
	enemy_hp_bar.max_value = e.max_hp
	enemy_hp_bar.value = e.hp
	enemy_hp_label.text = "%d/%d" % [e.hp, e.max_hp]

	var move = e.next_move
	if not move.is_empty():
		enemy_intent_label.text = "⚡ 의도: [%s] %s" % [move.get("name", ""), move.get("desc", "")]

	var status_texts = []
	if e.shield > 0: status_texts.append("🛡️ %d" % e.shield)
	if e.power > 0: status_texts.append("⚔️ +%d" % e.power)
	if e.weak > 0: status_texts.append("💫 취약 %d" % e.weak)
	if e.stunned: status_texts.append("⛓️ 기절/빙결")
	if e.poison > 0: status_texts.append("🧪 %d" % e.poison)
	if e.bleed > 0: status_texts.append("🩸 %d" % e.bleed)
	enemy_status_label.text = " | ".join(status_texts)

	# Load enemy icon if exists
	if ResourceLoader.exists(e.icon):
		enemy_sprite.texture = load(e.icon)

	# Slots UI
	var slot_labels = ["초성 (자음)", "중성 (모음)", "종성 (받침)"]
	for i in range(3):
		var btn = slots_container.get_child(i) as Button
		var tile = cs.slots[i]
		if tile != null:
			btn.text = tile["char"]
			btn.modulate = Color(1.0, 0.9, 0.5)
		else:
			btn.text = "+"
			btn.modulate = Color(0.7, 0.7, 0.8)
		if not btn.pressed.is_connected(_on_slot_clicked):
			btn.pressed.connect(_on_slot_clicked.bind(i))

	# Crafted Card Box
	if not cs.crafted_card.is_empty():
		var card = cs.crafted_card
		card_box.visible = true
		card_title.text = "%s (%s)" % [card["word"], card.get("syllable", "")]
		card_cost.text = "%d AP" % card.get("cost", 0)
		card_desc.text = card.get("desc", "")
		if ResourceLoader.exists(card.get("icon", "")):
			card_icon.texture = load(card["icon"])
	else:
		card_box.visible = false

	# Energy & Deck
	energy_label.text = "%d / %d AP" % [p.ap, p.max_ap]
	deck_info_label.text = "뽑을 덱: %d | 버린 덱: %d" % [cs.draw_pile.size(), cs.discard_pile.size()]

	# Hand Tiles
	for c in hand_container.get_children():
		c.queue_free()

	for tile in cs.hand:
		var tile_box = PanelContainer.new()
		var vbox = VBoxContainer.new()
		tile_box.add_child(vbox)

		var btn_tile = Button.new()
		btn_tile.text = tile["char"]
		btn_tile.custom_minimum_size = Vector2(56, 64)
		if selected_tile_id_for_combine == tile["id"]:
			btn_tile.modulate = Color(0.4, 0.9, 1.0)
		btn_tile.pressed.connect(_on_hand_tile_clicked.bind(tile["id"]))
		vbox.add_child(btn_tile)

		var hbox_act = HBoxContainer.new()
		vbox.add_child(hbox_act)

		if tile["isRotatable"]:
			var btn_rot = Button.new()
			btn_rot.text = "🔄"
			btn_rot.custom_minimum_size = Vector2(26, 24)
			btn_rot.pressed.connect(func():
				cs.rotate_tile(tile["id"])
				update_ui()
			)
			hbox_act.add_child(btn_rot)

		var btn_comb = Button.new()
		btn_comb.text = "⚡"
		btn_comb.custom_minimum_size = Vector2(26, 24)
		btn_comb.pressed.connect(func():
			if selected_tile_id_for_combine == -1:
				selected_tile_id_for_combine = tile["id"]
				SoundEngine.play_tile_click()
			elif selected_tile_id_for_combine == tile["id"]:
				selected_tile_id_for_combine = -1
			else:
				cs.combine_tiles(selected_tile_id_for_combine, tile["id"])
				selected_tile_id_for_combine = -1
			update_ui()
		)
		hbox_act.add_child(btn_comb)

		hand_container.add_child(tile_box)

func _on_hand_tile_clicked(tile_id: int) -> void:
	if selected_tile_id_for_combine != -1:
		if selected_tile_id_for_combine != tile_id:
			battle_manager.card_system.combine_tiles(selected_tile_id_for_combine, tile_id)
			selected_tile_id_for_combine = -1
			update_ui()
			return
		else:
			selected_tile_id_for_combine = -1

	battle_manager.card_system.place_tile_in_slot(tile_id)
	update_ui()

func _on_slot_clicked(slot_idx: int) -> void:
	battle_manager.card_system.remove_tile_from_slot(slot_idx)
	update_ui()

func _on_play_card_pressed() -> void:
	battle_manager.play_crafted_card()
	update_ui()

func _on_end_turn_pressed() -> void:
	selected_tile_id_for_combine = -1
	battle_manager.end_player_turn()
	update_ui()

func _on_log_added(msg: String) -> void:
	var logs_text = []
	for l in battle_manager.combat_logs.slice(0, 8):
		logs_text.append("[T%d] %s" % [l["turn"], l["message"]])
	log_label.text = "\n".join(logs_text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if not battle_manager.card_system.crafted_card.is_empty():
			_on_play_card_pressed()
