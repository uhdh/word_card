# ShopModal.gd
# 상점 모달: NPC 상인 에셋, 자모 타일 구매(진열 상품/새로고침), 자모 타일 영구 제거(덱 압축)
extends Control

signal shop_closed()
signal jamo_bought(char_str: String, cost: int)
signal jamo_removed(index: int, cost: int)

@onready var npc_icon: TextureRect = $Panel/VBox/Header/NpcIcon
@onready var npc_dialog: Label = $Panel/VBox/Header/DialogBox/DialogLabel
@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var btn_close: Button = $Panel/VBox/Header/BtnClose

# Tabs
@onready var tab_buy_btn: Button = $Panel/VBox/TabButtons/BtnTabBuy
@onready var tab_remove_btn: Button = $Panel/VBox/TabButtons/BtnTabRemove

@onready var buy_container: VBoxContainer = $Panel/VBox/TabBuyContainer
@onready var shop_items_grid: HBoxContainer = $Panel/VBox/TabBuyContainer/ItemsGrid
@onready var btn_reroll: Button = $Panel/VBox/TabBuyContainer/RerollRow/BtnReroll

@onready var remove_container: VBoxContainer = $Panel/VBox/TabRemoveContainer
@onready var remove_tiles_container: HBoxContainer = $Panel/VBox/TabRemoveContainer/Scroll/TilesContainer
@onready var btn_confirm_remove: Button = $Panel/VBox/TabRemoveContainer/BtnConfirmRemove
@onready var remove_info_label: Label = $Panel/VBox/TabRemoveContainer/RemoveInfoLabel

var current_gold: int = 40
var current_jamo_list: Array[String] = []
var selected_remove_index: int = -1

const REMOVE_COST: int = 10
const REROLL_COST: int = 5

var shop_stock = [] # [{ "char": "ㄱ", "cost": 10, "sold": false }]

const ALL_JAMO_POOL = [
	"ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
	"ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ", "ㅑ", "ㅕ", "ㅛ", "ㅠ"
]

func _ready() -> void:
	if btn_close: btn_close.pressed.connect(_on_close_pressed)
	if tab_buy_btn: tab_buy_btn.pressed.connect(func(): _switch_tab(true))
	if tab_remove_btn: tab_remove_btn.pressed.connect(func(): _switch_tab(false))
	if btn_reroll: btn_reroll.pressed.connect(_on_reroll_pressed)
	if btn_confirm_remove: btn_confirm_remove.pressed.connect(_on_confirm_remove_pressed)

	generate_shop_stock()
	_switch_tab(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			_on_close_pressed()

func setup(p_gold: int, p_jamo_list: Array) -> void:
	current_gold = p_gold
	current_jamo_list.clear()
	for c in p_jamo_list:
		current_jamo_list.append(str(c))
	update_ui()

func generate_shop_stock() -> void:
	shop_stock.clear()
	var selected = []

	for i in range(4):
		var pick = HangulEngine.get_weighted_random_jamo()
		# Avoid duplicate in same shop refresh if possible
		if selected.has(pick) and selected.size() < 10:
			pick = HangulEngine.get_weighted_random_jamo()
		selected.append(pick)

		var is_rare = HangulEngine.is_rare(pick)
		var cost = 15 if is_rare else (8 if HangulEngine.JUNGSUNG.has(pick) else 10)
		shop_stock.append({
			"char": pick,
			"cost": cost,
			"is_rare": is_rare,
			"sold": false
		})

func _switch_tab(is_buy: bool) -> void:
	buy_container.visible = is_buy
	remove_container.visible = not is_buy

	tab_buy_btn.modulate = Color(1, 1, 1, 1) if is_buy else Color(0.7, 0.7, 0.7, 1)
	tab_remove_btn.modulate = Color(1, 1, 1, 1) if not is_buy else Color(0.7, 0.7, 0.7, 1)

	if is_buy:
		npc_dialog.text = "“어서오게! 희귀 자모(ㄱ, ㅡ, ㅜ)는 귀하지만 강력한 단어의 열쇠라네.”"
	else:
		selected_remove_index = -1
		npc_dialog.text = "“필요 없는 자모를 버려 덱을 압축하면 원하는 단어가 훨씬 잘 완성되지!”"

	update_ui()

func update_ui() -> void:
	gold_label.text = "🪙 보유 골드: %d G" % current_gold
	btn_reroll.text = "🔄 상품 새로고침 (%d G)" % REROLL_COST
	btn_reroll.disabled = (current_gold < REROLL_COST)

	# Render Buy Items
	for c in shop_items_grid.get_children():
		c.queue_free()

	for idx in range(shop_stock.size()):
		var item = shop_stock[idx]
		var item_card = PanelContainer.new()
		item_card.custom_minimum_size = Vector2(110, 120)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_card.add_child(vbox)

		var is_rare = item.get("is_rare", false)
		var lbl_char = Label.new()
		lbl_char.text = ("🌟 " + item["char"]) if is_rare else item["char"]
		lbl_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_char.add_theme_font_size_override("font_size", 24 if is_rare else 28)
		if is_rare:
			lbl_char.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		if item["sold"]:
			lbl_char.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		vbox.add_child(lbl_char)

		var btn_buy = Button.new()
		btn_buy.text = "품절" if item["sold"] else ("%d G 구매" % item["cost"])
		if is_rare and not item["sold"]:
			btn_buy.modulate = Color(1.0, 0.9, 0.4)
		btn_buy.disabled = item["sold"] or (current_gold < item["cost"]) or (current_jamo_list.size() >= 15)
		btn_buy.pressed.connect(_on_buy_item_pressed.bind(idx))
		vbox.add_child(btn_buy)

		shop_items_grid.add_child(item_card)

	# Render Remove Items
	for c in remove_tiles_container.get_children():
		c.queue_free()

	for idx in range(current_jamo_list.size()):
		var ch = current_jamo_list[idx]
		var btn = Button.new()
		btn.text = ch
		btn.custom_minimum_size = Vector2(54, 62)
		btn.add_theme_font_size_override("font_size", 22)

		if selected_remove_index == idx:
			btn.modulate = Color(1.0, 0.3, 0.3, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

		btn.pressed.connect(func():
			selected_remove_index = idx
			update_ui()
		)
		remove_tiles_container.add_child(btn)

	if selected_remove_index != -1:
		var target_char = current_jamo_list[selected_remove_index]
		remove_info_label.text = "선택된 자모: [%s] (제거 비용: %d G)" % [target_char, REMOVE_COST]
		btn_confirm_remove.disabled = (current_gold < REMOVE_COST)
		btn_confirm_remove.text = "✂️ [%s] 타일 영구 제거 (%d G)" % [target_char, REMOVE_COST]
	else:
		remove_info_label.text = "제거할 자모 타일을 위 목록에서 선택하세요."
		btn_confirm_remove.disabled = true
		btn_confirm_remove.text = "✂️ 자모 타일 제거 (%d G)" % REMOVE_COST

func _on_buy_item_pressed(idx: int) -> void:
	if idx < 0 or idx >= shop_stock.size(): return
	var item = shop_stock[idx]
	if item["sold"] or current_gold < item["cost"]: return

	current_gold -= item["cost"]
	item["sold"] = true
	current_jamo_list.append(item["char"])

	SoundEngine.play_coin()
	jamo_bought.emit(item["char"], item["cost"])
	npc_dialog.text = "“탁월한 선택이네! 자모 [%s](을)를 벨트에 추가했네.”" % item["char"]
	update_ui()

func _on_confirm_remove_pressed() -> void:
	if selected_remove_index < 0 or selected_remove_index >= current_jamo_list.size(): return
	if current_gold < REMOVE_COST: return

	var removed_char = current_jamo_list[selected_remove_index]
	var removed_idx = selected_remove_index
	current_gold -= REMOVE_COST
	current_jamo_list.remove_at(selected_remove_index)

	SoundEngine.play_tile_click()
	jamo_removed.emit(removed_idx, REMOVE_COST)
	npc_dialog.text = "“자모 [%s](을)를 말끔하게 제거했네! 덱이 훨씬 가벼워졌군.”" % removed_char
	selected_remove_index = -1
	update_ui()

func _on_reroll_pressed() -> void:
	if current_gold < REROLL_COST: return
	current_gold -= REROLL_COST
	SoundEngine.play_coin()
	generate_shop_stock()
	npc_dialog.text = "“새로운 자모 상품들을 들여왔네! 천천히 둘러보게.”"
	update_ui()

func _on_close_pressed() -> void:
	shop_closed.emit()
	queue_free()
