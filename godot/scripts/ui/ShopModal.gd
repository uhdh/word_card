# ShopModal.gd
# 방랑 상인 모로크: 한 화면(All-in-One) 통합 뷰 - [자모 진열대] + [신비한 에테르 유물] + [덱 압축]
extends Control

signal jamo_bought(char_str: String, cost: int)
signal jamo_removed(index: int, cost: int)
signal relic_bought(relic_data: Dictionary, cost: int)

@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var btn_close: Button = $Panel/VBox/Header/BtnClose

@onready var shop_items_grid: HBoxContainer = $Panel/VBox/Scroll/AllContentVBox/SectionJamo/ShopItemsGrid
@onready var relic_items_grid: HBoxContainer = $Panel/VBox/Scroll/AllContentVBox/SectionRelics/RelicItemsGrid
@onready var remove_tiles_grid: HBoxContainer = $Panel/VBox/Scroll/AllContentVBox/SectionRemove/RemoveTilesGrid

var current_gold: int = 0
var current_jamo_list: Array = []
var owned_relics: Array = []

var shop_stock: Array = []
var relic_stock: Array = []

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
		"desc": "모든 활자 타워 공격력 +20%",
		"icon": "res://assets/relics/relic_essence_power_32px_pastel.png"
	},
	{
		"id": "relic_fortress_rune",
		"name": "🛡️ 철옹성 룬",
		"cost": 30,
		"desc": "기지 최대 체력 +10 및 즉시 10 회복",
		"icon": "res://assets/relics/relic_fortress_rune_32px_pastel.png"
	},
	{
		"id": "relic_haste_compass",
		"name": "⏱️ 신속의 나침반",
		"cost": 35,
		"desc": "모든 활자 타워 공격 속도 +20%",
		"icon": "res://assets/relics/relic_haste_compass_32px_pastel.png"
	},
	{
		"id": "relic_merchant_pouch",
		"name": "💰 상인의 보물주머니",
		"cost": 30,
		"desc": "웨이브 클리어 골드 보상 +50%",
		"icon": "res://assets/relics/relic_merchant_pouch_32px_pastel.png"
	},
	{
		"id": "relic_crit_lens",
		"name": "🎯 예리한 렌즈",
		"cost": 35,
		"desc": "타워 공격 시 25% 확률로 2배 치명타",
		"icon": "res://assets/relics/relic_crit_lens_32px_pastel.png"
	}
]

func setup(p_gold: int, p_jamo_list: Array, p_owned_relics: Array) -> void:
	current_gold = p_gold
	current_jamo_list = p_jamo_list.duplicate()
	owned_relics = p_owned_relics.duplicate()
	_generate_stock()
	_generate_relic_stock()
	_update_ui()

func _ready() -> void:
	btn_close.pressed.connect(_on_close_pressed)

func _generate_stock() -> void:
	shop_stock.clear()
	for i in range(4):
		var pick = HangulEngine.get_weighted_random_jamo()
		var r = HangulEngine.get_rarity(pick)
		var cost = 10
		if r == "super_rare": cost = 25
		elif r == "rare": cost = 18

		shop_stock.append({
			"char": pick,
			"rarity": r,
			"cost": cost,
			"sold": false
		})

func _generate_relic_stock() -> void:
	relic_stock.clear()
	var available = []
	for r in ALL_RELIC_POOL:
		var already_owned = false
		for o in owned_relics:
			if o.get("id") == r["id"]:
				already_owned = true
				break
		if not already_owned:
			available.append(r)

	available.shuffle()
	for i in range(mini(3, available.size())):
		var r_copy = available[i].duplicate()
		r_copy["sold"] = false
		relic_stock.append(r_copy)

func _update_ui() -> void:
	gold_label.text = "🪙 %d G" % current_gold

	# 1. 자모 진열대 (4종)
	for c in shop_items_grid.get_children():
		c.queue_free()

	for idx in range(shop_stock.size()):
		var item = shop_stock[idx]
		var item_card = PanelContainer.new()
		item_card.custom_minimum_size = Vector2(100, 115)

		var style = StyleBoxFlat.new()
		style.bg_color = HangulEngine.get_rarity_bg_color(item["char"])
		style.border_color = HangulEngine.get_rarity_border_color(item["char"])
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		item_card.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		item_card.add_child(vbox)

		var lbl_char = Label.new()
		lbl_char.text = item["char"]
		lbl_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_char.add_theme_font_size_override("font_size", 28)
		if item["sold"]:
			lbl_char.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		vbox.add_child(lbl_char)

		var btn_buy = Button.new()
		btn_buy.text = "품절" if item["sold"] else ("%d G" % item["cost"])
		btn_buy.disabled = item["sold"] or (current_gold < item["cost"]) or (current_jamo_list.size() >= 15)
		btn_buy.pressed.connect(_on_buy_item_pressed.bind(idx))
		vbox.add_child(btn_buy)

		shop_items_grid.add_child(item_card)

	# 2. 신비한 에테르 유물 (3종)
	for c in relic_items_grid.get_children():
		c.queue_free()

	for idx in range(relic_stock.size()):
		var r = relic_stock[idx]
		var r_card = PanelContainer.new()
		r_card.custom_minimum_size = Vector2(160, 120)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.14, 0.28, 0.95)
		style.border_color = Color(0.68, 0.45, 0.98, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		r_card.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 3)
		r_card.add_child(vbox)

		var hbox_top = HBoxContainer.new()
		hbox_top.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox_top.add_theme_constant_override("separation", 6)
		vbox.add_child(hbox_top)

		if ResourceLoader.exists(r["icon"]):
			var icon_tex = TextureRect.new()
			icon_tex.texture = load(r["icon"])
			icon_tex.custom_minimum_size = Vector2(24, 24)
			icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox_top.add_child(icon_tex)

		var lbl_name = Label.new()
		lbl_name.text = r["name"]
		lbl_name.add_theme_font_size_override("font_size", 12)
		lbl_name.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
		hbox_top.add_child(lbl_name)

		var lbl_desc = Label.new()
		lbl_desc.text = r["desc"]
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 10)
		lbl_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
		vbox.add_child(lbl_desc)

		var btn_buy_relic = Button.new()
		btn_buy_relic.text = "보유 중" if r["sold"] else ("%d G" % r["cost"])
		btn_buy_relic.disabled = r["sold"] or (current_gold < r["cost"])
		btn_buy_relic.pressed.connect(_on_buy_relic_pressed.bind(idx))
		vbox.add_child(btn_buy_relic)

		relic_items_grid.add_child(r_card)

	# 3. 덱 압축 (타일 제거 15 G)
	for c in remove_tiles_grid.get_children():
		c.queue_free()

	for idx in range(current_jamo_list.size()):
		var char_str = current_jamo_list[idx]
		var btn_remove = Button.new()
		btn_remove.text = char_str
		btn_remove.tooltip_text = "클릭하여 [%s] 타일을 15 G에 영구 제거합니다." % char_str
		btn_remove.custom_minimum_size = Vector2(42, 42)
		btn_remove.add_theme_font_size_override("font_size", 18)
		btn_remove.disabled = (current_gold < 15) or (current_jamo_list.size() <= 1)
		btn_remove.pressed.connect(_on_remove_tile_pressed.bind(idx))
		remove_tiles_grid.add_child(btn_remove)

func _on_buy_item_pressed(idx: int) -> void:
	var item = shop_stock[idx]
	if not item["sold"] and current_gold >= item["cost"] and current_jamo_list.size() < 15:
		current_gold -= item["cost"]
		item["sold"] = true
		current_jamo_list.append(item["char"])
		jamo_bought.emit(item["char"], item["cost"])
		SoundEngine.play_word_crafted()
		_update_ui()

func _on_buy_relic_pressed(idx: int) -> void:
	var r = relic_stock[idx]
	if not r["sold"] and current_gold >= r["cost"]:
		current_gold -= r["cost"]
		r["sold"] = true
		owned_relics.append(r)
		relic_bought.emit(r, r["cost"])
		SoundEngine.play_buff()
		_update_ui()

func _on_remove_tile_pressed(idx: int) -> void:
	if current_gold >= 15 and current_jamo_list.size() > 1:
		current_gold -= 15
		current_jamo_list.remove_at(idx)
		jamo_removed.emit(idx, 15)
		SoundEngine.play_hit()
		_update_ui()

func _on_close_pressed() -> void:
	SoundEngine.play_tile_click()
	queue_free()
