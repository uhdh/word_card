# ShopModal.gd
# 방랑 상인 모로크: 유물만 파는 상점.
#
# 예전에는 [자모 진열대] + [유물] + [덱 압축] 세 칸을 한 화면에 담는 'All-in-One' 이었다.
# 그런데 자모 진열대와 덱 압축은 씬에서 `visible = false` 로 시작했고 **어디서도 켜지
# 않았다** — 매 갱신마다 아무도 볼 수 없는 위젯 13개를 만들었고, NPC 대사와 칸 제목은
# 없는 기능을 광고했다. 자모 구매·제거는 이미 벨트 헤더(자음 구매 / 모음 구매 / 타일 제거)가
# 하고 있으므로, 이 화면은 유물만 남긴다.
extends Control

const Palette = preload("res://scripts/ui/Palette.gd")
## 특성 배지 — 설명이 말하는 특성(폭발·연쇄·선회·관통·지속 피해)을 **아이콘으로** 보여 준다.
## 키워드 표는 `TraitStyle` 하나만 읽는다(사본을 만들면 두 화면이 다른 특성을 가리킨다).
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
const TraitIcon = preload("res://scripts/ui/TraitIcon.gd")

## 진열대를 새로 뽑는 값.
## ⚠️ 예전에는 `10` 이 **네 곳에 흩어져** 있었다 — 비활성 판정(`_update_ui`) · 차감
## (`_on_refresh_pressed`) · 시그널 emit(`refresh_bought`) · 그리고 **씬 문구**
## (`BtnRefresh.text = "🔄 갱신 10G"`). 값을 바꾸면 한 곳을 놓쳐 **버튼이 거짓말을 한다**
## (10G 라고 적혀 있는데 15G 가 빠지거나, 15G 인데 10G 일 때만 눌린다).
## 씬 문구도 이제 코드가 덮어쓴다 — 씬에는 가격을 적지 않는다(`tools/ShopReasonProbe.gd` 가 지킨다).
const REFRESH_PRICE := 10

signal relic_bought(relic_data: Dictionary, cost: int)
signal refresh_bought(cost: int)

@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var btn_close: Button = $Panel/VBox/Header/BtnClose
@onready var btn_refresh: Button = $Panel/VBox/Header/BtnRefresh

@onready var relic_items_grid: HBoxContainer = $Panel/VBox/Scroll/AllContentVBox/SectionRelics/RelicItemsGrid

var current_gold: int = 0
var owned_relics: Array = []

var relic_stock: Array = []

const ALL_RELIC_POOL = [
	{
		"id": "relic_golden_dice",
		"name": "황금 주사위",
		"cost": 25,
		"desc": "보상 리롤 주사위를 +2개 즉시 지급합니다.",
		"icon": "res://assets/relics/relic_golden_dice_32px_pastel.png"
	},
	{
		"id": "relic_essence_power",
		"name": "활자의 정수",
		"cost": 35,
		"desc": "모든 활자 타워 공격력 +20%",
		"icon": "res://assets/relics/relic_essence_power_32px_pastel.png"
	},
	{
		"id": "relic_fortress_rune",
		"name": "철옹성 룬",
		"cost": 30,
		"desc": "기지 최대 체력 +10 및 즉시 10 회복",
		"icon": "res://assets/relics/relic_fortress_rune_32px_pastel.png"
	},
	{
		"id": "relic_haste_compass",
		"name": "신속의 나침반",
		"cost": 35,
		"desc": "모든 활자 타워 공격 속도 +20%",
		"icon": "res://assets/relics/relic_haste_compass_32px_pastel.png"
	},
	{
		"id": "relic_merchant_pouch",
		"name": "상인의 보물주머니",
		"cost": 30,
		"desc": "웨이브 클리어 골드 보상 +50%",
		"icon": "res://assets/relics/relic_merchant_pouch_32px_pastel.png"
	},
	{
		"id": "relic_crit_lens",
		"name": "예리한 렌즈",
		"cost": 35,
		"desc": "타워 공격 시 25% 확률로 2배 치명타",
		"icon": "res://assets/relics/relic_crit_lens_32px_pastel.png"
	},
	{
		"id": "relic_range_rune", "name": "천리안의 룬", "cost": 30,
		# 한때 무기 타워에 치명타 +10% 를 **몰래** 더 줬다. 설명은 범위만 말하고 있었으므로
		# 설명에 맞춰 그 효과를 지웠다(디렉터 지시: "설명과 코드를 일치시켜줘. 설명에 맞춰").
		# 설명이 계약이다 — 설명에 없는 효과를 코드에 다시 넣지 말 것.
		"desc": "모든 타워의 공격 범위 +15%", "icon": "res://assets/relics/relic_range_rune_32px_pastel.png"
	},
	{
		"id": "relic_bounty_coin", "name": "현상금 동전", "cost": 35,
		"desc": "라운드 보너스 골드 +5", "icon": "res://assets/relics/relic_bounty_coin_32px_pastel.png"
	},
	{
		"id": "relic_healing_incense", "name": "회복의 향로", "cost": 30,
		"desc": "웨이브 종료 시 기지 HP 1 회복", "icon": "res://assets/relics/relic_healing_incense_32px_pastel.png"
	},
	{
		"id": "relic_first_strike", "name": "선봉의 깃털", "cost": 35,
		# 한때 소환 타워에 3배를 **몰래** 줬다. 설명은 2배라고 적혀 있었으므로 설명에 맞춰
		# 예외를 지웠다(WordTower.first_strike_multiplier). 설명이 계약이다.
		"desc": "각 타워의 첫 공격 피해 2배", "icon": "res://assets/relics/relic_first_strike_32px_pastel.png"
	},
	{
		"id": "relic_three_syllable_seal", "name": "삼문자 인장", "cost": 40,
		"desc": "3글자 타워 피해 +25%", "icon": "res://assets/relics/relic_three_syllable_seal_32px_pastel.png"
	},
	{"id":"relic_initial_compass","name":"훈민정음의 나침반","cost":35,"desc":"힌트가 슬롯 하나씩이 아니라 세 슬롯의 최적 조합을 한 번에 채점합니다","icon":"res://assets/relics/relic_initial_compass_32px_pastel.png"},
	{"id":"relic_tense_hammer","name":"된소리 망치","cost":35,"desc":"된소리 초성 타워 피해 +25%","icon":"res://assets/relics/relic_tense_hammer_32px_pastel.png"},
	{"id":"relic_final_weight","name":"종성의 무게추","cost":30,"desc":"받침 있는 타워 피해 +20%","icon":"res://assets/relics/relic_final_weight_32px_pastel.png"},
	{"id":"relic_open_feather","name":"민소리 깃털","cost":30,"desc":"받침 없는 타워 공격속도 +18%","icon":"res://assets/relics/relic_open_feather_32px_pastel.png"},
	{"id":"relic_cluster_anvil","name":"겹받침 모루","cost":40,"desc":"겹받침 타워 피해 +35%","icon":"res://assets/relics/relic_cluster_anvil_32px_pastel.png"},
	{"id":"relic_vowel_crystal","name":"겹모음 수정","cost":35,"desc":"겹모음 타워 사거리 +20%","icon":"res://assets/relics/relic_vowel_crystal_32px_pastel.png"},
	{"id":"relic_initial_drum","name":"첫소리 북","cost":40,"desc":"모든 음절의 초성이 같으면 피해 +25%","icon":"res://assets/relics/relic_initial_drum_32px_pastel.png"},
	{"id":"relic_vowel_resonance","name":"모음 공명석","cost":35,"desc":"같은 모음이 반복되면 공격속도 +20%","icon":"res://assets/relics/relic_vowel_resonance_32px_pastel.png"},
	{"id":"relic_consonant_ring","name":"자음 고리","cost":40,"desc":"받침과 다음 초성이 같으면 치명타 +20%","icon":"res://assets/relics/relic_consonant_ring_32px_pastel.png"},
	{"id":"relic_balance_ink","name":"균형의 먹","cost":35,"desc":"자음과 모음 수가 같으면 피해·사거리 +10%","icon":"res://assets/relics/relic_balance_ink_32px_pastel.png"},
	{"id":"relic_open_chime","name":"무받침 풍경","cost":35,"desc":"무받침 타워가 연속 배치되면 양쪽 공격속도 +12%","icon":"res://assets/relics/relic_open_chime_32px_pastel.png"},
	# ── 공격 특성 전용 유물 ────────────────────────────────────────────────
	# 위 유물들이 '글자 모양' 이나 '전역' 에 걸리는 것과 달리, 이 다섯은
	# 특정 공격 형태에만 걸린다. 단어의 뜻이 공격 형태를 정하게 되면서
	# (AttackStyle) "내 타워가 무슨 형태인지" 가 구매 기준이 됐기 때문에,
	# 그 형태를 직접 강화하는 유물이 있어야 상점이 전략이 된다.
	{"id":"relic_blast_charge","name":"폭발의 뇌관","cost":35,"desc":"폭발 타워 피해 +25%, 함께 맞는 대상 +1","icon":"res://assets/relics/relic_gourd_32px_pastel.png"},
	{"id":"relic_chain_loom","name":"연쇄의 베틀","cost":35,"desc":"연쇄 타워 피해 +15%, 튀는 대상 +1","icon":"res://assets/relics/relic_bell_32px_pastel.png"},
	{"id":"relic_orbit_gear","name":"선회의 톱니","cost":40,"desc":"선회 타워의 궤도 오브 +1개","icon":"res://assets/relics/relic_crystal_32px_pastel.png"},
	{"id":"relic_pierce_auger","name":"관통 송곳","cost":30,"desc":"관통 타워 사거리 +10%, 꿰뚫는 대상 +1","icon":"res://assets/relics/relic_magnifier_32px_pastel.png"},
	{"id":"relic_burn_oil","name":"발화 기름","cost":30,"desc":"지속 피해 타워의 화상 지속시간 +50%","icon":"res://assets/relics/relic_ink_stone_32px_pastel.png"}
]

func setup(p_gold: int, p_owned_relics: Array) -> void:
	current_gold = p_gold
	owned_relics = p_owned_relics.duplicate()
	_generate_relic_stock()
	_update_ui()

func _ready() -> void:
	btn_close.pressed.connect(_on_close_pressed)
	btn_refresh.pressed.connect(_on_refresh_pressed)

func sync_state(p_gold: int, p_owned_relics: Array) -> void:
	current_gold = p_gold
	owned_relics = p_owned_relics.duplicate()
	_update_ui()

func refresh_stock() -> void:
	_generate_relic_stock()
	_update_ui()

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
	for i in range(mini(4, available.size())):
		var r_copy = available[i].duplicate()
		r_copy["sold"] = false
		relic_stock.append(r_copy)

## 버튼 하나의 (비활성 여부, 사유) 를 **한 곳에서** 만든다.
##
## ⚠️ 왜 판정과 사유를 묶는가: `disabled` 를 따로 계산하고 사유를 따로 만들면 **둘이 어긋난다.**
## 사유가 곧 판정이 되게 해서 툴팁이 거짓말할 수 없게 만든다
## (벨트 헤더의 `JamoBelt._button_state()` 와 **같은 규칙** — 두 화면이 달라 보이면 안 된다).
## ⚠️ 왜 사유가 필요한가: `disabled` 는 bool 하나라 **이유가 사라진다.** 유물 버튼은
## '이미 삼' 과 '골드 부족' 이라는 **서로 다른 두 이유**로 막히는데, 플레이어에게는 둘 다 회색 버튼이다.
## 예전 코드가 정확히 그랬다 — `r["sold"] or (current_gold < r["cost"])` 는 **bool 하나**다.
##
## ⚠️ 순서가 중요하다: 이미 산 유물은 골드가 모자라도 사유가 **'보유'** 다.
## 사유는 **결정적인 제약**이어야 한다 — 이미 산 유물은 골드가 아무리 많아도 살 수 없으므로
## 그 상황의 '골드 부족' 은 **거짓 정보**다(골드를 모으면 살 수 있다는 뜻이 되므로).
## 반대로 아직 안 산 유물이면 골드가 유일한 제약이므로 그걸 말한다.
func _relic_button_state(r: Dictionary) -> Dictionary:
	var reason := ""
	if r["sold"]:
		# ⚠️ 표식(`⚠️`)을 빠뜨리면 안 된다 — 벨트·밀어내기와 **같은 계약**이다
		#    (`BeltBlockReasonProbe.MARK` · `ShopReasonProbe` §3b 가 잰다).
		#    사유가 여섯 개는 표식을 달고 하나만 안 달면, 그 하나만 *경고* 로 안 읽힌다.
		reason = "！ 이미 보유한 유물입니다"
	elif current_gold < r["cost"]:
		reason = "！ 골드가 부족합니다 (필요 %dG · 보유 %dG)" % [r["cost"], current_gold]
	return {"disabled": reason != "", "reason": reason}

## 갱신(진열대 리롤) 버튼의 (비활성 여부, 사유).
##
## ⚠️ '진열할 유물이 없다' 는 사유를 **넣지 않았다** — 재고가 비려면 유물 27종을 전부 사야 하고
## 그 값은 **920G** 다(2026-09-23 실측). 도달하지 않는 상태에 분기를 두면 코드만 늘어난다.
## 도달 가능해지면 그때 `relic_stock.is_empty()` 분기를 여기에 추가할 것.
func _refresh_button_state() -> Dictionary:
	var reason := ""
	if current_gold < REFRESH_PRICE:
		reason = "！ 골드가 부족합니다 (필요 %dG · 보유 %dG)" % [REFRESH_PRICE, current_gold]
	return {"disabled": reason != "", "reason": reason}

## 툴팁 본문에 막힌 사유를 덧붙인다. 사유가 없으면 본문 그대로.
## ⚠️ 사유를 버튼 **글자**에 넣지 않는 이유: 유물 카드는 160px, 상단 헤더는 더 좁다.
## 넘치면 조용히 잘린다(벨트 헤더와 같은 이유 — `tools/BeltTextWidth.tscn`).
## 툴팁은 레이아웃을 건드리지 않는다.
func _with_reason(base: String, reason: String) -> String:
	if reason == "":
		return base
	return "%s\n\n%s" % [base, reason]

## 유물 카드의 **설명 한 줄**. 문구가 타워 특성을 말하면 그 특성의 배지를 앞에 붙인다.
##
## 왜 필요한가: 유물 27종 중 다섯은 "폭발 타워 피해 +25%" 처럼 **어느 공격 형태에 걸리는지**를
## 설명 첫머리에 적는다. 그런데 카드 넷이 나란히 서 있고 문구가 전부 같은 회색이라, 어느
## 카드가 내 타워에 걸리는지 알려면 **네 문장을 다 읽어야** 했다. 배지는 읽지 않고 보이게 한다.
##
## ⚠️ **문구는 한 글자도 바꾸지 않는다.** 설명이 계약이고(§1 감독 원칙), 배지는 '무엇에
##    걸리는가' 를 보이게 하는 **표시**지 문장의 일부가 아니다. 아이콘이 단어를 **대신하면**
##    "◉ 타워의 궤도 오브 +1개" 처럼 주어가 사라진다 — 그래서 대체가 아니라 **앞에 붙인다**.
##
## 실측(2026-10-05 · neodgm 10px = 한글 10.0px/자 · 카드 안쪽 폭 156px):
##   배지 14 + 간격 3 = 17px 를 떼고도 다섯 문구의 **줄 수가 하나도 안 늘어난다** —
##   가장 빠듯한 '선회 타워의 궤도 오브 +1개'(130px)가 139px 안에 그대로 들어간다.
##   나머지 넷은 이미 두 줄이라 폭이 17px 줄어도 두 줄이다.
func _desc_row(r: Dictionary) -> Control:
	var desc := str(r["desc"])
	var lbl := Label.new()
	lbl.text = desc
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Palette.TX_SECONDARY)

	var trait_id := TraitStyle.trait_id_in_text(desc)
	if trait_id == "":
		# 특성과 무관한 유물은 예전과 **똑같은** 라벨 하나다 — 카드 구조가 갈라지지 않는다.
		return lbl

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.add_child(TraitIcon.new(trait_id, TraitStyle.color_for(trait_id)))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row

func _update_ui() -> void:
	gold_label.text = "%d G" % current_gold

	# 갱신 버튼 — 글자도 **여기서** 쓴다(씬 문구에 가격을 두지 않는다: 위 `REFRESH_PRICE` 주석).
	var refresh_state := _refresh_button_state()
	btn_refresh.text = "갱신 %dG" % REFRESH_PRICE
	btn_refresh.disabled = refresh_state["disabled"]
	btn_refresh.tooltip_text = _with_reason(
		"진열대의 유물을 새로 뽑습니다 (최대 4종)", refresh_state["reason"])

	# 유물 진열대
	for c in relic_items_grid.get_children():
		c.queue_free()

	for idx in range(relic_stock.size()):
		var r = relic_stock[idx]
		var r_card = PanelContainer.new()
		r_card.custom_minimum_size = Vector2(160, 120)

		var style = StyleBoxFlat.new()
		style.bg_color = Palette.BG_PANEL_HI
		style.border_color = Palette.MANA_INK
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
		lbl_name.add_theme_color_override("font_color", Palette.TX_PRIMARY)
		hbox_top.add_child(lbl_name)

		vbox.add_child(_desc_row(r))

		var btn_buy_relic = Button.new()
		btn_buy_relic.text = "보유 중" if r["sold"] else ("%d G" % r["cost"])
		var buy_state := _relic_button_state(r)
		btn_buy_relic.disabled = buy_state["disabled"]
		btn_buy_relic.tooltip_text = _with_reason("이 유물을 삽니다", buy_state["reason"])
		btn_buy_relic.pressed.connect(_on_buy_relic_pressed.bind(idx))
		vbox.add_child(btn_buy_relic)

		relic_items_grid.add_child(r_card)

func _on_buy_relic_pressed(idx: int) -> void:
	var r = relic_stock[idx]
	if not r["sold"] and current_gold >= r["cost"]:
		current_gold -= r["cost"]
		r["sold"] = true
		owned_relics.append(r)
		relic_bought.emit(r, r["cost"])
		SoundEngine.play_buff()
		_update_ui()

func _on_close_pressed() -> void:
	SoundEngine.play_tile_click()
	# 여기엔 `closed` 시그널이 있었다. 구독자가 하나도 없어서 지웠다 —
	# 상점이 닫힐 때 반응할 것이 없다는 뜻이다(골드는 열 때 `sync_state` 로 맞춘다).
	hide()

func _on_refresh_pressed() -> void:
	if current_gold < REFRESH_PRICE: return
	current_gold -= REFRESH_PRICE
	refresh_bought.emit(REFRESH_PRICE)
	refresh_stock()
