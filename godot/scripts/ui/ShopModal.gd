# ShopModal.gd
# 이벤트 방랑 상인 모달: 자모 타일 구매(12~20G), 신비한 유물 구매(25~35G), 자모 타일 영구 제거(덱 압축 15G)
extends Control

signal shop_closed()
signal jamo_bought(char_str: String, cost: int)
signal jamo_removed(index: int, cost: int)
signal relic_bought(relic_data: Dictionary, cost: int)

@onready var npc_icon: TextureRect = $Panel/VBox/Header/NpcIcon
@onready var npc_dialog: Label = $Panel/VBox/Header/DialogBox/DialogLabel
@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var btn_close: Button = $Panel/VBox/Header/BtnClose

# Tabs
@onready var tab_buy_btn: Button = $Panel/VBox/TabButtons/BtnTabBuy
@onready var tab_relic_btn: Button = $Panel/VBox/TabButtons/BtnTabRelic
@onready var tab_remove_btn: Button = $Panel/VBox/TabButtons/BtnTabRemove

@onready var buy_container: VBoxContainer = $Panel/VBox/TabBuyContainer
@onready var shop_items_grid: HBoxContainer = $Panel/VBox/TabBuyContainer/ItemsGrid
@onready var btn_reroll: Button = $Panel/VBox/TabBuyContainer/RerollRow/BtnReroll

@onready var relic_container: VBoxContainer = $Panel/VBox/TabRelicContainer
@onready var relic_items_grid: HBoxContainer = $Panel/VBox/TabRelicContainer/RelicGrid

@onready var remove_container: VBoxContainer = $Panel/VBox/TabRemoveContainer
@onready var remove_tiles_container: HBoxContainer = $Panel/VBox/TabRemoveContainer/Scroll/TilesContainer
@onready var btn_confirm_remove: Button = $Panel/VBox/TabRemoveContainer/BtnConfirmRemove
@onready var remove_info_label: Label = $Panel/VBox/TabRemoveContainer/RemoveInfoLabel

var current_gold: int = 30
var current_jamo_list: Array[String] = []
var owned_relics: Array = []
var selected_remove_index: int = -1
var current_tab: String = "buy"

const REMOVE_COST: int = 15 # 덱 압축 비용 15 G
const REROLL_COST: int = 8  # 새로고침 8 G

var shop_stock = [] # [{ "char": "ㄱ", "cost": 20, "is_rare": true, "sold": false }]
var relic_stock = [] # [{ "id": "relic_golden_dice", "name": "황금 주사위", "cost": 25, "desc": "...", "icon": "...", "sold": false }]

const ALL_RELIC_POOL = [
	{
		"id": "relic_golden_dice",
		"name": "🎲 황금 주사위",
		"cost": 25,
		"desc": "보상 리롤 주사위를 +2개 즉시 지급합니다.",
		"icon": "res://assets/relics/relic_golden_dice_32px_pastel.png"
	},
	{
		"id": "relic_essence_power",
		"name": "⚔️ 활자의 정수",
		"cost": 35,
		"desc": "모든 활자 타워의 공격력이 +20% 증가합니다.",
		"icon": "res://assets/relics/relic_essence_power_32px_pastel.png"
	},
	{
		"id": "relic_fortress_rune",
		"name": "🛡️ 철옹성 룬",
		"cost": 30,
		"desc": "기지 최대 체력이 +10 증가하고 즉시 10 회복합니다.",
		"icon": "res://assets/relics/relic_fortress_rune_32px_pastel.png"
	},
	{
		"id": "relic_haste_compass",
		"name": "⏱️ 신속의 나침반",
		"cost": 35,
		"desc": "모든 활자 타워의 공격 속도가 20% 빨라집니다.",
		"icon": "res://assets/relics/relic_haste_compass_32px_pastel.png"
	},
	{
		"id": "relic_merchant_pouch",
		"name": "💰 상인의 보물주머니",
		"cost": 30,
		"desc": "웨이브 클리어 골드 보상이 +50% 증가합니다.",
		"icon": "res://assets/relics/relic_merchant_pouch_32px_pastel.png"
	},
	{
		"id": "relic_crit_lens",
		"name": "🎯 예리한 렌즈",
		"cost": 35,
		"desc": "타워 공격 시 25% 확률로 2배 치명타 피해를 입힙니다.",
		"icon": "res://assets/relics/relic_crit_lens_32px_pastel.png"
	}
]

func _ready() -> void:
	if btn_close: btn_close.pressed.connect(_on_close_pressed)
	if tab_buy_btn: tab_buy_btn.pressed.connect(func(): _switch_tab("buy"))
	if tab_relic_btn: tab_relic_btn.pressed.connect(func(): _switch_tab("relic"))
	if tab_remove_btn: tab_remove_btn.pressed.connect(func(): _switch_tab("remove"))
	if btn_reroll: btn_reroll.pressed.connect(_on_reroll_pressed)
	if btn_confirm_remove: btn_confirm_remove.pressed.connect(_on_confirm_remove_pressed)

	generate_shop_stock()
	generate_relic_stock()
	_switch_tab("buy")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()

func setup(p_gold: int, p_jamo_list: Array, p_relics: Array = []) -> void:
	current_gold = p_gold
	current_jamo_list.clear()
	for c in p_jamo_list: current_jamo_list.append(str(c))
	owned_relics = p_relics.duplicate()
	update_ui()

func generate_shop_stock() -> void:
	shop_stock.clear()
	var selected = []

	for i in range(4):
		var pick = HangulEngine.get_weighted_random_jamo()
		if selected.has(pick) and selected.size() < 10:
			pick = HangulEngine.get_weighted_random_jamo()
		selected.append(pick)

		var is_rare = HangulEngine.is_rare(pick)
		var cost = 20 if is_rare else 12 # 밸런스: 일반 12G, 희귀 20G
		shop_stock.append({
			"char": pick,
			"cost": cost,
			"is_rare": is_rare,
			"sold": false
		})

func generate_relic_stock() -> void:
	relic_stock.clear()
	var available = ALL_RELIC_POOL.duplicate()
	available.shuffle()

	for r in available:
		var is_already_owned = false
		for o in owned_relics:
			if o.get("id") == r["id"]:
				is_already_owned = true
				break
		if not is_already_owned:
			relic_stock.append({
				"id": r["id"],
				"name": r["name"],
				"cost": r["cost"],
				"desc": r["desc"],
				"icon": r["icon"],
				"sold": false
			})
			if relic_stock.size() >= 3: break

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	buy_container.visible = (tab_name == "buy")
	relic_container.visible = (tab_name == "relic")
	remove_container.visible = (tab_name == "remove")

	tab_buy_btn.modulate = Color(1, 1, 1, 1) if tab_name == "buy" else Color(0.6, 0.6, 0.6, 1)
	tab_relic_btn.modulate = Color(1, 1, 1, 1) if tab_name == "relic" else Color(0.6, 0.6, 0.6, 1)
	tab_remove_btn.modulate = Color(1, 1, 1, 1) if tab_name == "remove" else Color(0.6, 0.6, 0.6, 1)

	if tab_name == "buy":
		npc_dialog.text = "“어서오게! 희귀 자모(ㄱ, ㅡ, ㅜ)는 귀하지만 강력한 단어의 열쇠라네.”"
	elif tab_name == "relic":
		npc_dialog.text = "“고대 활자술사들이 남긴 신비한 유물이라네. 전투에 영구적인 축복을 내려주지!”"
	else:
		selected_remove_index = -1
		npc_dialog.text = "“불필요한 자모를 제거(15 G)하여 덱을 압축하면 원하는 상위 단어가 훨씬 잘 완성되지!”"

	update_ui()

func update_ui() -> void:
	gold_label.text = "🪙 보유 골드: %d G" % current_gold
	btn_reroll.text = "🔄 상품 새로고침 (%d G)" % REROLL_COST
	btn_reroll.disabled = (current_gold < REROLL_COST)

	# 1. Render Buy Jamo Items
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

	# 2. Render Relic Items
	for c in relic_items_grid.get_children():
		c.queue_free()

	for idx in range(relic_stock.size()):
		var r = relic_stock[idx]
		var r_card = PanelContainer.new()
		r_card.custom_minimum_size = Vector2(150, 130)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		r_card.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = r["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = r["desc"]
		desc_lbl.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		vbox.add_child(desc_lbl)

		var btn_buy_r = Button.new()
		btn_buy_r.text = "보유 중" if r["sold"] else ("%d G 구매" % r["cost"])
		btn_buy_r.disabled = r["sold"] or (current_gold < r["cost"])
		btn_buy_r.pressed.connect(_on_buy_relic_pressed.bind(idx))
		vbox.add_child(btn_buy_r)

		relic_items_grid.add_child(r_card)

	# 3. Render Remove Items
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
		btn_confirm_remove.disabled = (current_gold < REMOVE_COST) or (current_jamo_list.size() <= 1)
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

func _on_buy_relic_pressed(idx: int) -> void:
	if idx < 0 or idx >= relic_stock.size(): return
	var r = relic_stock[idx]
	if r["sold"] or current_gold < r["cost"]: return

	current_gold -= r["cost"]
	r["sold"] = true
	owned_relics.append(r)

	SoundEngine.play_coin()
	relic_bought.emit(r, r["cost"])
	npc_dialog.text = "“유물 [%s](을)를 획득했네! 놀라운 힘이 깃들었군.”" % r["name"]
	update_ui()

func _on_confirm_remove_pressed() -> void:
	if selected_remove_index < 0 or selected_remove_index >= current_jamo_list.size(): return
	if current_gold < REMOVE_COST or current_jamo_list.size() <= 1: return

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
