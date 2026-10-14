# JamoBelt.gd
# 하단 자모 타일 벨트: 실시간 자모 순서 배치, 정밀 드래그 앤 드롭 삽입(타일 사이 / 맨 끝), 회전(🔄), 클릭-스왑 및 자동 스트림 파싱
class_name JamoBelt
extends PanelContainer

const HangulEngine = preload("res://scripts/core/HangulEngine.gd")

const AutoArrange = preload("res://scripts/core/AutoArrange.gd")
const Palette = preload("res://scripts/ui/Palette.gd")

signal parsed_towers_updated(parsed_list: Array)
signal jamo_changed()
signal tile_purchase_requested(is_vowel: bool)
signal tile_removal_requested(index: int)
## 활자 교체. 골드를 내고 벨트의 활자 한 장을 같은 종류의 다른 활자로 바꾼다.
## 벨트가 꽉 차면(30장) 구매가 막히므로, 후반 골드의 유일한 출구가 된다.
signal tile_swap_requested(index: int)
## 밀어내기. 고른 타일을 영구히 소모해 경로 위의 적을 뒤로 민다.
signal tile_ability_requested(index: int)
signal strategy_recommendations_requested()

const TILE_PRICE := 10
## 타일을 하나 살 때마다 다음 타일 값이 이만큼 오른다.
const TILE_PRICE_STEP := 1
const TILE_REMOVE_PRICE := 10
const TILE_SWAP_PRICE := 10
const MAX_SLOTS := 3
## 벨트가 담을 수 있는 타일 수. 이 값이 곧 **구매 게이트**다 — 넘으면 자음/모음 구매가
## 막히고, 그래서 후반 골드의 출구가 '활자 교체' 로 바뀐다(위 `tile_swap_requested` 주석).
## ⚠️ 예전에는 `30` 이 **세 곳에 흩어져** 있었다 — `_update_buy_buttons()`(비활성 판정) ·
## `add_jamo()`(실제 삽입) · `TowerDefenseMain._on_tile_purchase_requested()`(구매 게이트).
## 용량을 바꾸면 한 곳을 놓쳐 **버튼이 거짓말을 한다**(눌리는데 안 담기거나, 담기는데 안 눌린다).
## 한 곳에서만 정의한다.
const MAX_BELT_TILES := 30

const STARTER_JAMO_SETS := [
	["ㄱ", "ㅜ", "ㅅ"], ["ㄱ", "ㅏ", "ㅅ"], ["ㅂ", "ㅜ", "ㅅ"], ["ㅅ", "ㅜ", "ㄹ"], ["ㄱ", "ㅗ", "ㅂ"],
	["ㅂ", "ㅏ", "ㅁ"], ["ㅂ", "ㅗ", "ㅁ"], ["ㄱ", "ㅣ", "ㅁ"], ["ㄱ", "ㅡ", "ㅁ"], ["ㅂ", "ㅗ", "ㄹ"],
	["ㅂ", "ㅏ", "ㄹ"], ["ㄱ", "ㅏ", "ㅁ"], ["ㄱ", "ㅏ", "ㅂ"], ["ㄱ", "ㅓ", "ㅁ"], ["ㄱ", "ㅗ", "ㄱ"],
	["ㄱ", "ㅗ", "ㄹ"], ["ㄱ", "ㅗ", "ㅁ"], ["ㄱ", "ㅜ", "ㅇ"], ["ㄱ", "ㅡ", "ㄱ"], ["ㄴ", "ㅏ", "ㄹ"],
	["ㄴ", "ㅏ", "ㅅ"], ["ㄴ", "ㅏ", "ㅈ"], ["ㄴ", "ㅜ", "ㄴ"], ["ㄷ", "ㅏ", "ㄹ"], ["ㄷ", "ㅗ", "ㄱ"],
	["ㄷ", "ㅗ", "ㄹ"], ["ㅁ", "ㅏ", "ㄱ"], ["ㅁ", "ㅏ", "ㄹ"], ["ㅁ", "ㅏ", "ㅇ"], ["ㅁ", "ㅗ", "ㅅ"],
	["ㅁ", "ㅜ", "ㄱ"], ["ㅁ", "ㅜ", "ㄴ"], ["ㅁ", "ㅜ", "ㄹ"], ["ㅂ", "ㅏ", "ㅇ"], ["ㅂ", "ㅓ", "ㄹ"],
	["ㅂ", "ㅗ", "ㅇ"], ["ㅂ", "ㅜ", "ㄱ"], ["ㅂ", "ㅜ", "ㄹ"], ["ㅂ", "ㅣ", "ㅇ"], ["ㅅ", "ㅏ", "ㄱ"],
	["ㅅ", "ㅏ", "ㄴ"], ["ㅅ", "ㅓ", "ㅇ"], ["ㅅ", "ㅜ", "ㅁ"], ["ㅇ", "ㅣ", "ㄴ"], ["ㅇ", "ㅣ", "ㄹ"]
]

static func generate_starting_jamo() -> Array[String]:
	var choice: Array = STARTER_JAMO_SETS[randi() % STARTER_JAMO_SETS.size()]
	var arr: Array[String] = [str(choice[0]), str(choice[1]), str(choice[2])]
	return arr

var jamo_list: Array[String] = []

var selected_index_for_swap: int = -1
var relic_ids: Array = []
## 헤더의 '전체 힌트'. 훈민정음의 나침반을 사면 나타나, 세 슬롯을 한 번에 채점한다.
## (예전에는 이 자리에 '초성 힌트' 가 있었지만, 이제 힌트는 슬롯마다 붙는다)
var hint_button: Button
var optimize_button: Button
var consonant_buy_button: Button
var vowel_buy_button: Button
var remove_tile_button: Button
var swap_tile_button: Button
var ability_mode := false
## 웨이브 중에만, 웨이브당 한 번만 true 가 된다 (TowerDefenseMain 이 알려 준다).
var ability_available := false
var slot_assignments: Array[int] = []
var unlocked_slot_count := 3
var current_gold := 0
var removal_mode := false
## 활자 교체 모드. 켜 둔 상태에서 타일을 누르면 그 활자를 바꾼다.
var swap_mode := false
## 지금까지 실제로 결제된 타일 수. 자음·모음이 같은 시세를 공유한다.
## (버튼을 눌러도 구매가 성사되지 않으면 올라가지 않는다)
var tile_purchase_count := 0
# 단어 완성 셀레브레이션용 — 직전 렌더에서 완성된 **음절** 목록.
# 서식이 붙은 문구("[가 타워]")가 아니라 맨 음절("가")을 담는다 — 비교가 음절로 이루어진다.
var _last_parsed_words: Array = []
var _is_first_render: bool = true
## 세이브를 되돌려 놓는 한 번의 렌더 동안만 셀레브레이션을 끈다.
## `begin_restore()` 가 켜고, `render_belt()` 가 한 번 쓰고 스스로 푼다.
var _suppress_celebration: bool = false

## ── 슬롯별 목표 · 고정 · 채점 ────────────────────────────────────────────────
##
## 힌트를 누른 슬롯만 채점 결과를 들고 있다(나머지는 빈 Dictionary).
## 슬롯 위의 힌트 버튼이 '내 모든 타일로 만들 수 있는 최고의 조합' 을 계산해
## 그중 이 슬롯 몫을 목표로 삼고, 지금 배치를 자리별로 채점한다.
var slot_grades: Array = [{}, {}, {}]
## 슬롯별 목표 단어. 힌트가 정한다.
var slot_targets: Array[String] = ["", "", ""]
## 고정된 슬롯. 고정된 단어의 타일은 옆 슬롯의 힌트 조합에서 빠진다.
var slot_locked: Array[bool] = [false, false, false]
## 고정된 슬롯이 예약한 타일 인덱스(슬롯마다 따로 들고 있어야 해제가 정확하다).
var slot_reserved: Array = [[], [], []]
## 고정한 순서. 예약을 다시 잡을 때 이 순서를 지켜야 나중에 고정한 슬롯이
## 먼저 고정한 슬롯의 타일을 빼앗지 않는다(먼저 온 쪽이 우선).
var slot_lock_order: Array = []

## 채점 색. 타일 배경이 어두우므로(0.14, 0.12, 0.20) 어둡게만 칠하면 안 읽힌다.
## 자리 맞음 = 초록, 자리만 다름 = 금색, 돌려야 함 = 파랑, 안 씀 = 배경보다 살짝 어두운 회색.
const GRADE_POS_BG := Color("#1F6B3C")
const GRADE_POS_LINE := Color("#5BE08A")
const GRADE_NEAR_BG := Color("#7A5A10")
const GRADE_NEAR_LINE := Color("#F5C451")
## 회전하면 그 자모가 되는 타일. 금색과 **다른 색**이어야 한다.
##
## 금색('자리만 다름')과 회전('돌려야 그 자모')은 플레이어가 할 일이 다르다 — 전자는
## 끌어다 놓으면 되고, 후자는 ↻ 를 눌러야 한다. 한 색으로 묶어 두면 ㅏ 를 ㅗ 자리에
## 끌어다 놓고 "왜 안 되지" 를 반복한다. 실제로 ㄱ→ㄴ, ㅏ→ㅗ 처럼 회전으로 **다른
## 자모**가 되는 타일이 많다.
##
## 파랑인 이유: 초록(자리 맞음)·금색(자리만 다름)·회색(안 씀)과 색상환이 가장 멀어서
## 작은 타일에서도 구분된다.
const GRADE_ROTATE_BG := Color("#173A5E")
const GRADE_ROTATE_LINE := Color("#6FA8FF")
const GRADE_OFF_BG := Color("#2A2735")
const GRADE_OFF_LINE := Color("#5A5270")
## 아직 없는 자리(점선 유령 상자)의 테두리.
const GRADE_GHOST_LINE := Color("#8B93A8")

@onready var scroll_container: ScrollContainer = $VBox/Scroll
@onready var tiles_container: HFlowContainer = $VBox/Scroll/TilesContainer
@onready var parsed_preview_label: Label = $VBox/Header/PreviewLabel

# Draggable Tile Container Box (좌/우 정밀 사이 삽입 지원)
class JamoTileBox extends PanelContainer:
	var belt: JamoBelt
	var tile_index: int
	var char_str: String
	## 이 타일이 어느 슬롯의 몇 번째 칸인가. 채점 색을 다시 칠할 때 필요하다
	## (_refresh_tile_selection 은 인덱스만 들고 타일을 훑는다).
	var slot_index: int = -1
	var tile_pos: int = -1

	func _init(p_belt: JamoBelt, p_index: int, p_char: String) -> void:
		belt = p_belt
		tile_index = p_index
		char_str = p_char
		custom_minimum_size = Vector2(64, 62)
		mouse_filter = Control.MOUSE_FILTER_PASS
		# 기본 테마의 PanelContainer 테두리 + 버튼 테두리가 겹쳐 '이중 테두리'로 보였다.
		# 타일의 시각(배경/테두리)은 버튼 하나만 담당하고, 이 상자는 배치/드래그만 맡는다.
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview = PanelContainer.new()
		preview.custom_minimum_size = Vector2(58, 66)
		var style = StyleBoxFlat.new()
		style.bg_color = HangulEngine.get_rarity_bg_color(char_str)
		style.border_color = Palette.TX_GOLD
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		preview.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		lbl.text = char_str
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Palette.TX_GOLD)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.add_child(lbl)

		preview.set_rotation_degrees(5.0)
		set_drag_preview(preview)

		if is_instance_valid(belt):
			# 드래그 중 안내(어느 슬롯이 받는지 / 왜 못 받는지)는 벨트가 담당한다.
			# 여기서 시작을 알려 주지 않으면 벨트는 드래그가 시작된 줄도 모른다.
			belt.begin_drag(tile_index)
			if belt.selected_index_for_swap != -1:
				# 드래그가 시작되면 '교체 선택'은 의미가 없다 → 표시까지 되돌린다.
				belt.selected_index_for_swap = -1
				belt._refresh_tile_selection()

		return {
			"type": "jamo_tile",
			"from_index": tile_index,
			"char": char_str
		}

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		# 받을지 말지는 놓는 순간에 벨트가 판단하고 **이유까지 말한다**.
		# 여기서 false 를 돌려주면 엔진이 _drop_data 를 아예 안 불러서, 놓아도
		# 아무 일이 없고 아무 설명도 없다 — 고치려는 문제 그 자체다.
		if not (data is Dictionary and data.get("type") == "jamo_tile"):
			return false
		if not is_instance_valid(belt):
			return true
		# 좌/우 절반이 '어느 쪽에 끼워 넣을지' 를 정한다. 엔진이 주는 at_position 은
		# 입력 경로에 따라 로컬 범위를 한참 벗어난 값이 올 수 있어서(실측 (-1038, 799)),
		# 그때는 드래그 소스 위치로 방향을 추론한다 — 안 그러면 방향이 false 로 굳어
		# '한 칸 앞으로만' 옮겨진다.
		var right_half: bool
		if Rect2(Vector2.ZERO, size).has_point(at_position):
			right_half = at_position.x > (size.x * 0.5)
		else:
			right_half = data.get("from_index", -1) < tile_index
		belt.set_drag_target_on_tile(self, right_half)
		return true

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary and data.get("type") == "jamo_tile":
			var from_idx = data.get("from_index", -1)
			var slot := belt.slot_assignments[tile_index] if is_instance_valid(belt) else -1
			belt.commit_drag_drop(from_idx, slot, tile_index)

class JamoTray extends PanelContainer:
	var belt: JamoBelt
	var slot_index: int
	## 드롭 안내 상태. 0=보통, 1=받는다, 2=안 받는다.
	##
	## 드래그하는 동안 화면이 **아무것도** 말해 주지 않던 자리다. 놓기 전에 결과를
	## 알 수 없으면 플레이어는 놓고 나서야 알게 되고, 실패하면 아무 설명도 못 듣는다.
	## 실측으로 다섯 번 중 세 번이 '아무 일도 안 일어남' 이었다.
	var drop_state := 0
	## 원래 색. 강조를 풀 때 되돌린다(고정된 슬롯은 테두리가 금색이라 그대로 복원해야 한다).
	var base_border_color: Color = Color.WHITE
	var base_bg_color: Color = Color.BLACK
	var panel_style: StyleBoxFlat

	func _init(p_belt: JamoBelt, p_slot_index: int) -> void:
		belt = p_belt
		slot_index = p_slot_index
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(148, 92)

	## 드롭 상태를 색으로만 칠한다.
	##
	## 테두리 **굵기는 건드리지 않는다** — 굵기가 바뀌면 트레이 최소 크기가 바뀌어
	## 드래그 도중 벨트 전체가 흔들린다. 색만 바꾸면 배치가 절대 안 움직인다.
	func set_drop_state(state: int) -> void:
		if state == drop_state:
			return
		drop_state = state
		if panel_style == null:
			return
		match state:
			1:
				panel_style.border_color = Palette.TX_GOLD
				panel_style.bg_color = base_bg_color.lerp(Palette.TX_GOLD, 0.22)
			2:
				panel_style.border_color = Palette.HP_DANGER
				panel_style.bg_color = base_bg_color.lerp(Palette.HP_DANGER, 0.22)
			_:
				panel_style.border_color = base_border_color
				panel_style.bg_color = base_bg_color

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.get("type") == "jamo_tile"):
			return false
		if slot_index >= 0 and slot_index >= belt.unlocked_slot_count:
			return false
		belt.set_drag_target_on_tray(self)
		return true

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		# at_position 을 쓰지 않는다. 놓을 자리는 드래그 중 미리보기가 정하고,
		# 여기서는 그 미리보기와 **같은 계산**을 다시 돌린다 — 엔진이 주는
		# at_position 은 로컬 범위를 한참 벗어난 값이 올 수 있어서(실측 (-1038, 799))
		# 그걸로 자리를 정하면 '보여 준 것과 다른 곳에 놓이는' 일이 생긴다.
		belt.commit_drag_drop(data.get("from_index", -1), slot_index)

func _ready() -> void:
	if jamo_list.is_empty():
		jamo_list = generate_starting_jamo()
	consonant_buy_button = Button.new()
	consonant_buy_button.theme_type_variation = "PrimaryButton"
	consonant_buy_button.pressed.connect(func(): tile_purchase_requested.emit(false))
	$VBox/Header.add_child(consonant_buy_button)
	vowel_buy_button = Button.new()
	vowel_buy_button.theme_type_variation = "PrimaryButton"
	vowel_buy_button.pressed.connect(func(): tile_purchase_requested.emit(true))
	$VBox/Header.add_child(vowel_buy_button)
	remove_tile_button = Button.new()
	remove_tile_button.theme_type_variation = "GhostButton"
	# 툴팁은 `_update_buy_buttons()` 가 단독으로 소유한다(사유를 덧붙여야 하므로).
	# 여기서도 넣으면 본문이 두 곳에 생겨 한쪽만 고치는 사고가 난다.
	remove_tile_button.pressed.connect(_toggle_removal_mode)
	$VBox/Header.add_child(remove_tile_button)
	swap_tile_button = Button.new()
	swap_tile_button.theme_type_variation = "GhostButton"
	swap_tile_button.pressed.connect(_toggle_swap_mode)
	$VBox/Header.add_child(swap_tile_button)
	optimize_button = Button.new()
	optimize_button.theme_type_variation = "GhostButton"
	optimize_button.text = "조합 추천"
	optimize_button.tooltip_text = "남은 타일로 만들 수 있는 단어를 추천합니다"
	optimize_button.pressed.connect(func(): strategy_recommendations_requested.emit())
	$VBox/Header.add_child(optimize_button)
	hint_button = Button.new()
	hint_button.theme_type_variation = "GhostButton"
	hint_button.text = "전체 힌트"
	hint_button.tooltip_text = "세 슬롯의 최적 조합을 한 번에 채점합니다"
	hint_button.pressed.connect(_show_all_hints)
	$VBox/Header.add_child(hint_button)
	_update_buy_buttons()
	render_belt()

## 현재 자음/모음 타일 한 장의 값. 살 때마다 TILE_PRICE_STEP 만큼 오른다.
func current_tile_price() -> int:
	return TILE_PRICE + tile_purchase_count * TILE_PRICE_STEP

## 결제가 실제로 끝난 뒤에만 호출한다. 초안을 열었다 닫거나 골드가 모자라
## 구매가 무산된 경우에는 시세가 오르면 안 된다.
func register_tile_purchase() -> void:
	tile_purchase_count += 1
	_update_buy_buttons()

func set_tile_purchase_count(value: int) -> void:
	tile_purchase_count = maxi(0, value)
	_update_buy_buttons()

func reset_tile_purchase_price() -> void:
	set_tile_purchase_count(0)

## 활자 교체 가격: 자음/모음 구매 가격 및 시세 상승(1G)과 별개로 10G 고정 유지.
func current_swap_price() -> int:
	return TILE_SWAP_PRICE

func set_gold(value: int) -> void:
	current_gold = value
	if current_gold < TILE_REMOVE_PRICE: removal_mode = false
	if current_gold < current_swap_price() or jamo_list.is_empty(): swap_mode = false
	_update_buy_buttons()

func _toggle_removal_mode() -> void:
	removal_mode = not removal_mode
	# 두 모드가 동시에 켜지면 타일 클릭의 의미가 모호해진다. 서로 끈다.
	if removal_mode: swap_mode = false
	selected_index_for_swap = -1
	render_belt()

func _toggle_swap_mode() -> void:
	swap_mode = not swap_mode
	if swap_mode: removal_mode = false
	selected_index_for_swap = -1
	render_belt()

## 밀어내기 모드. 타일을 한 장 고르면 그 타일을 영구히 소모해 적을 뒤로 민다.
## 제거·교체와 같은 규칙으로 서로를 끈다 — 셋이 겹치면 타일 클릭의 뜻이 사라진다.
func _toggle_ability_mode() -> void:
	ability_mode = not ability_mode
	if ability_mode:
		removal_mode = false
		swap_mode = false
	selected_index_for_swap = -1
	render_belt()

## 밀어내기를 지금 쓸 수 있는지. 웨이브가 끝나거나 이미 썼으면 꺼진다.
func set_ability_available(available: bool) -> void:
	ability_available = available
	if not ability_available:
		ability_mode = false
	_update_buy_buttons()

## 버튼 하나의 (비활성 여부, 사유) 를 **한 곳에서** 만든다.
##
## ⚠️ 왜 판정과 사유를 묶는가: `disabled` 를 따로 계산하고 사유를 따로 만들면 **둘이 어긋난다.**
## 사유가 곧 판정이 되게 해서 툴팁이 거짓말할 수 없게 만든다.
## ⚠️ 왜 사유가 필요한가: `disabled` 는 bool 하나라 **이유가 사라진다.** 구매 버튼은
## '골드 부족' 과 '벨트 가득' 이라는 **서로 다른 두 이유**로 막히는데, 플레이어에게는
## 둘 다 그냥 회색 버튼이다 — **코드가 아는 것을 화면이 안 보여 주는** 전형이다.
##
## `empty_belt_blocks` = 이 버튼이 '벨트가 비어서' 막히는가. 제거·교체는 그렇고(지울 게 없다),
## 구매는 반대로 '벨트가 가득 차서' 막힌다(담을 자리가 없다). 두 조건은 서로 배타적이다.
func _button_state(price: int, empty_belt_blocks: bool) -> Dictionary:
	var reason := ""
	if current_gold < price:
		reason = "！ 골드가 부족합니다 (필요 %dG · 보유 %dG)" % [price, current_gold]
	elif empty_belt_blocks and jamo_list.is_empty():
		reason = "！ 벨트에 타일이 없습니다"
	elif not empty_belt_blocks and jamo_list.size() >= MAX_BELT_TILES:
		reason = "！ 벨트가 가득 찼습니다 (%d/%d장)" % [jamo_list.size(), MAX_BELT_TILES]
	return {"disabled": reason != "", "reason": reason}

## 툴팁 본문에 막힌 사유를 덧붙인다. 사유가 없으면 본문 그대로.
## 버튼 **글자**를 늘리지 않는 이유: 벨트 헤더는 폭이 빠듯해 넘치면 조용히 잘린다
## (`tools/BeltTextWidth.tscn`). 툴팁은 레이아웃을 건드리지 않는다.
func _with_reason(base: String, reason: String) -> String:
	if reason == "":
		return base
	return "%s\n\n%s" % [base, reason]

func _update_buy_buttons() -> void:
	var price := current_tile_price()
	var market_note := "구매할 때마다 값이 %dG씩 오릅니다 (현재 %dG)" % [TILE_PRICE_STEP, price]
	# 구매 두 버튼은 **같은 조건**이다(가격도 같다) — 한 번만 계산한다.
	var buy := _button_state(price, false)
	if consonant_buy_button:
		consonant_buy_button.text = "자음 구매 %dG" % price
		consonant_buy_button.disabled = buy["disabled"]
		consonant_buy_button.tooltip_text = _with_reason(
			"자음 타일 3장 중 하나를 고릅니다\n%s" % market_note, buy["reason"])
	if vowel_buy_button:
		vowel_buy_button.text = "모음 구매 %dG" % price
		vowel_buy_button.disabled = buy["disabled"]
		vowel_buy_button.tooltip_text = _with_reason(
			"모음 타일을 즉시 받습니다\n%s" % market_note, buy["reason"])
	if remove_tile_button:
		var remove_state := _button_state(TILE_REMOVE_PRICE, true)
		remove_tile_button.text = "제거할 타일 선택" if removal_mode else "타일 제거 %dG" % TILE_REMOVE_PRICE
		remove_tile_button.disabled = remove_state["disabled"]
		remove_tile_button.tooltip_text = _with_reason(
			"타일을 제거합니다 (%d G)" % TILE_REMOVE_PRICE, remove_state["reason"])
	if swap_tile_button:
		var swap_price := current_swap_price()
		var swap_state := _button_state(swap_price, true)
		swap_tile_button.text = "바꿀 활자 선택" if swap_mode else "활자 교체 %dG" % swap_price
		swap_tile_button.disabled = swap_state["disabled"]
		swap_tile_button.tooltip_text = _with_reason(
			"같은 종류(자음/모음)의 다른 활자로 바꿉니다 (%dG 고정)\n벨트가 꽉 차도 계속 쓸 수 있습니다" % TILE_SWAP_PRICE,
			swap_state["reason"])

func set_relics(ids: Array) -> void:
	relic_ids = ids
	if hint_button:
		# 슬롯 힌트는 이제 누구나 쓴다. 나침반은 '한 번에 세 슬롯' 이라는
		# 편의를 더한다 — 예전처럼 '완성 단어를 알려 주는' 유물이 아니다.
		hint_button.visible = relic_ids.has("relic_initial_compass")

## ── 슬롯 힌트 · 고정 · 채점 ─────────────────────────────────────────────────
##
## 예전에는 헤더에 '초성 힌트' 버튼 하나가 있었고, 가장 긴 후보의 초성만 알려 줬다.
## 그건 답을 알려 주는 조회였고, 정작 플레이어가 막히는 '배치' 는 돕지 않았다.
## 이제 슬롯마다 힌트 버튼이 붙어, 그 슬롯의 배치를 자리별로 채점한다.
## (게임은 일부러 배치를 대신 해 주지 않는다 — optimize_tiles 는 추천만 열고
##  slot_assignments 는 건드리지 않는다. 그래서 이 채점이 비어 있던 자리를 채운다)

## 이 슬롯이 쓸 수 있는 타일 인덱스 = 전체 − 다른 슬롯이 고정한 타일.
func _slot_available_indices(slot_index: int) -> Array:
	var blocked := _reserved_except(slot_index)
	var out: Array = []
	for i in range(jamo_list.size()):
		if not blocked.has(i): out.append(i)
	return out

## 다른 슬롯들이 고정으로 잡아 둔 타일 인덱스.
func _reserved_except(slot_index: int) -> Array:
	var blocked: Array = []
	for k in range(MAX_SLOTS):
		if k == slot_index or not slot_locked[k]: continue
		blocked.append_array(slot_reserved[k])
	return blocked

## 아직 고정되지 않은 슬롯들(오름차순).
func _open_slots() -> Array:
	var out: Array = []
	for k in range(unlocked_slot_count):
		if not slot_locked[k]: out.append(k)
	return out

## '내 모든 타일로 만들 수 있는 최고의 조합'.
##
## 조합을 통째로 보는 이유: 슬롯들은 타일을 나눠 쓴다. 한 슬롯만 최적으로 고르면
## 남은 슬롯이 쓸 타일이 망가진다. 고정된 슬롯의 타일은 후보에서 아예 빠진다.
func _best_set_for(slot_count: int) -> Array:
	var blocked := _reserved_except(-1)
	var owned: Array[String] = []
	for i in range(jamo_list.size()):
		if not blocked.has(i): owned.append(jamo_list[i])
	return AutoArrange.best_word_set_for(owned, WordDatabase.get_all_words(), maxi(1, slot_count))

## 슬롯 위 힌트 버튼. **토글**이다 — 이미 채점된 슬롯에서 다시 누르면 취소한다.
##
## 취소 수단이 없으면 한 번 누른 힌트가 목표를 영원히 붙잡는다. 고정을 풀어도 목표와
## 채점 색은 남아서, 화면이 계속 '이 단어를 만들어라' 라고 말한다. 플레이어가 마음을
## 바꾸는 일은 정상이므로 되돌릴 수 있어야 한다.
##
## **목표는 이 슬롯이 쓸 수 있는 타일 중 가장 센 것 *근처* 에서 하나다.** 감독 결정
## (2026-10-02): 늘 1위 하나만 가리키면 플레이어가 "하던 것" 만 하게 된다. 그래서
## **DPS 1위의 `AutoArrange.HINT_KEEP_RATIO`(0.8) 이상**인 후보 중에서 봉지 시드로 하나를
## 고른다(`AutoArrange.buildable_words_for`). 나침반(전체 힌트)이 벨트 전체의 조합을 세우고,
## 이 버튼은 '여기에 무엇을 세울 수 있나' 하나를 답한다 — 두 버튼의 역할이 다르다.
func _show_slot_hint(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= unlocked_slot_count:
		return
	if slot_locked[slot_index]:
		# 조용히 아무 일도 안 일어나면 버튼이 고장 난 것처럼 보인다.
		parsed_preview_label.text = "%d번 슬롯은 고정되어 있어요 — 고정을 풀면 다시 채점합니다" % (slot_index + 1)
		return
	if _slot_has_hint(slot_index):
		_clear_slot_hint(slot_index)
		parsed_preview_label.text = "%d번 슬롯 힌트를 지웠습니다 — 다시 누르면 새로 채점합니다" % (slot_index + 1)
		return
	# 목표는 **이 슬롯이 쓸 수 있는 타일 중 가장 센 것 근처에서 하나**다. 조합에서 이 슬롯의
	# 자리를 가져오면 안 된다. ('근처' 의 폭 = `AutoArrange.HINT_KEEP_RATIO` = DPS 1위의 80%.)
	#
	# 예전에는 `_best_set_for(열린 슬롯 수)` 가 돌려주는 '조합' 의 같은 순번을 목표로 썼다.
	# 조합은 **총합**을 키우는 계산이라, 한 슬롯에 1음절 잔여를 떼어 주는 것이 정상 동작이다.
	# 그래서 타일 7장을 들고 있는 슬롯이 '목표 1음절' 을 받았다 — 같은 벨트로 2음절
	# 53.1 DPS 를 세울 수 있는데도. **디렉터 보고가 정확히 이 형태로 두 번 들어왔다**
	# (한 번은 가루 vs 바늘, 이번은 슬롯 힌트의 1음절 목표). 같은 계약이 이미 테스트로
	# 잠겨 있다: `_test_hint_never_prefers_a_weaker_word`.
	#
	# 조합 전체를 한 번에 보는 일은 나침반(_show_all_hints)이 맡는다. 슬롯 버튼은
	# '여기에 무엇을 세울 수 있나' 하나만 답한다. 순위 함수는 패널과 같은 것을 쓴다 —
	# 두 화면이 같은 질문에 다른 답을 하지 않도록.
	var available: Array[String] = []
	for i in _slot_available_indices(slot_index): available.append(jamo_list[i])
	var ranked := AutoArrange.buildable_words_for(available, WordDatabase.get_all_words(), 1)
	var target := str(ranked[0].get("word", "")) if not ranked.is_empty() else ""
	slot_targets[slot_index] = target
	slot_grades[slot_index] = _grade_slot(slot_index, target)
	render_belt()
	parsed_preview_label.text = _slot_hint_text(slot_index)

## 이 슬롯에 지울 힌트가 있는가.
func _slot_has_hint(slot_index: int) -> bool:
	return slot_targets[slot_index] != "" or not slot_grades[slot_index].is_empty()

## 목표와 채점을 지운다. 남은 타일은 그대로 둔다 — 취소는 계획을 지우는 일이지
## 배치를 되돌리는 일이 아니다.
func _clear_slot_hint(slot_index: int) -> void:
	slot_targets[slot_index] = ""
	slot_grades[slot_index] = {}
	render_belt()

## 헤더의 '전체 힌트' — 훈민정음의 나침반.
##
## 슬롯을 하나씩 누르면 '지금 누른 슬롯' 만 보인다. 세 슬롯이 타일을 나눠 쓰므로
## 조합 전체를 한 번에 봐야 계획이 선다. 나침반이 파는 것이 바로 그 '한 눈에' 다.
##
## **나침반만 아는 것을 말한다 — 지금보다 센가, 얼마나 센가.**
##
## 예전에는 '1번 1음절  2번 1음절  3번 1음절' 만 적었다. 그 모양은 트레이 머리가
## 슬롯마다 '목표 N음절' 로 이미 말하고 있어 중복이었고, 정작 나침반만 아는 것 —
## '지금 배치보다 세다' 는 사실과 그 크기 — 은 어디에도 없었다.
##
## 실측(감·날·굴을 세워 둔 벨트): 나침반은 문·골·날을 찾아냈다. 현재 41.0 DPS →
## 최적 54.3 DPS, **32% 더 세다.** 그런데 화면은 '목표 1음절' 이라고만 말했고,
## 플레이어는 이미 1음절 단어를 세워 뒀으므로 "바뀌는 게 없다" 고 읽었다.
## 35G 를 주고 산 힌트의 결론을 화면이 표현하지 못한 것이다.
##
## 그래서 줄은 **비교**를 말한다. 모양(음절 수)은 트레이 머리가 슬롯마다 말하므로
## 여기서 다시 쓰지 않는다. 단어는 여기서도 쓰지 않는다 — 숫자와 '해야 할 일' 의
## 개수만 말한다.
##
## 이 줄은 **판정**이라 한 번 읽히면 역할이 끝난다. 실행 중에 지워져도 계획은 남는다 —
## 색·유령 상자·'목표 N음절' 이 트레이에 그대로 있기 때문이다.
func _show_all_hints() -> void:
	var open_slots := _open_slots()
	if open_slots.is_empty():
		parsed_preview_label.text = "채점할 슬롯이 없어요 (모두 고정됨)"
		return
	var best_set := _best_set_for(open_slots.size())
	for k in range(open_slots.size()):
		var slot_index: int = open_slots[k]
		var target := str(best_set[k].get("word", "")) if k < best_set.size() else ""
		slot_targets[slot_index] = target
		slot_grades[slot_index] = _grade_slot(slot_index, target)
	render_belt()
	parsed_preview_label.text = _all_hint_text(open_slots)

## 전체 힌트의 한 줄. 지금 배치와 최적 조합을 **같은 자로** 견준다.
##
## 자는 `AutoArrange.word_value` 하나뿐이다 — 단어 하나의 값어치는 실제 타워가 내는
## 초당 피해(x100)이고, 조합의 값어치는 그 합이다. 지어낸 가중 점수가 아니다.
##
## 세 경우를 구분한다. 셋 다 '최적 조합의 총 세기' 를 말한다 — 그건 나침반만 아는 값이다.
##   - 지금 배치가 곧 최적      → "지금 배치 그대로 완성 (54.3 DPS)"
##   - 더 센 조합이 있다        → "지금 41.0 → 54.3 DPS  (회전 6 · 이동 1)"
##   - 아직 슬롯이 단어를 못 이룸 → "최고 54.3 DPS  (회전 6 · 이동 1)"
##     (이때는 비교할 '지금' 이 없다. 0 으로 세면 없는 상승분을 지어내는 셈이다)
##
## 목표 단어는 절대 쓰지 않는다. 힌트가 답을 적어 주면 플레이어가 할 일이
## '단어를 찾는 것' 에서 '받아쓰기' 로 바뀐다.
func _all_hint_text(open_slots: Array) -> String:
	var best_value := 0
	for slot_index in open_slots:
		var target := slot_targets[slot_index]
		if target == "":
			continue
		best_value += AutoArrange.word_value(target, WordDatabase.get_word_data(target))
	var suffix := _work_suffix(open_slots)

	# 지금 열린 슬롯에 서 있는 단어들. 하나라도 단어를 못 이루면 비교를 삼간다.
	var now_words: Array = []
	var parsed := parsed_slots()
	for slot_index in open_slots:
		var item: Dictionary = parsed[slot_index] if slot_index < parsed.size() else {}
		var word := str(item.get("syllable", ""))
		if word == "":
			return "최적 조합: 최고 %.1f DPS%s" % [float(best_value) / 100.0, suffix]
		now_words.append(word)

	# 값이 같아도 구성이 다르면 '그대로' 라고 말할 수 없다. 단어를 그대로 견준다.
	var same := true
	for k in range(open_slots.size()):
		if str(now_words[k]) != slot_targets[open_slots[k]]:
			same = false
			break
	if same:
		return "최적 조합: 지금 배치 그대로 완성 (%.1f DPS)" % [float(best_value) / 100.0]

	var now_value := 0
	for w in now_words:
		now_value += AutoArrange.word_value(str(w), WordDatabase.get_word_data(str(w)))
	return "최적 조합: 지금 %.1f ▸ %.1f DPS%s" % [
		float(now_value) / 100.0, float(best_value) / 100.0, suffix]

## '해야 할 일' 의 개수. 색이 타일마다 말하는 것을 한 덩어리로 접는다.
##
## 색만 보고는 규모를 모른다 — '타일 한 장만 밀면 된다' 와 '여섯 장을 부숴야 한다' 는
## 전혀 다른 결정인데, 화면은 둘 다 파란 타일 몇 개로 보인다.
func _work_suffix(open_slots: Array) -> String:
	var rotate := 0
	var move := 0
	var unused := 0
	for slot_index in open_slots:
		var grade: Dictionary = slot_grades[slot_index]
		rotate += _count_grade(grade, "rotate")
		move += _count_grade(grade, "near")
		unused += _count_grade(grade, "off")
	var parts: Array = []
	if rotate > 0: parts.append("회전 %d" % rotate)
	if move > 0: parts.append("이동 %d" % move)
	if unused > 0: parts.append("제외 %d" % unused)
	if parts.is_empty():
		return ""
	return "  (" + " · ".join(parts) + ")"


## 채점 결과를 한 줄로. 목표의 **모양**과 부족한 양, 그리고 **다음에 할 일**을 말한다.
##
## **목표 단어 자체는 절대 쓰지 않는다.** 힌트가 답을 적어 주면 플레이어가 할 일이
## '단어를 찾는 것' 에서 '받아쓰기' 로 바뀐다 — 자모를 모아 단어를 만드는 것이 이 게임의
## 핵심 고리인데, 힌트가 그 고리를 대신 풀어 버리면 힌트가 아니라 건너뛰기다.
## (예전에는 "2번 슬롯 목표 [수정구]" 처럼 단어를 그대로 적었다.)
##
## 대신 **음절 수**를 말한다. '몇 글자짜리를 노려야 하는지' 만으로도 목표의 크기는
## 정해지고, 어떤 단어인지는 플레이어가 자기 타일에서 찾는다.
##
## 색만 칠해 두면 '왜 이 타일이 금색인지' 를 알 길이 없다. 초록/금색/파랑/회색의 뜻은
## 머릿속에 없고, 힌트를 처음 누른 사람은 특히 그렇다. 그래서 범례를 나열하는 대신
## 색이 뜻하는 **행동**을 문장으로 쓴다.
##
## 문장이 짧은 이유: 이 라벨은 벨트 헤더 한 줄이고 오른쪽은 구매 버튼이 먹는다.
## clip_text 라 넘치면 조용히 잘린다 — 실제로 긴 문장이 '회색 1개는 이 단어에 안 쓰임'
## 을 화면 밖으로 밀어냈다. 그래서 여기서는 **행동만** 쓰고(색 + 동작), 왜 그런지는
## 타일 툴팁(_grade_label)이 문장으로 설명한다. 줄은 행동, 툴팁은 이유다.
##
## 빠진 활자의 **개수**를 말해 주는 이유: 목표가 정해졌어도 이 슬롯에 아직 자리가
## 남았다는 것을 모르면 플레이어는 '다 됐다' 고 착각한다. 어떤 활자인지는 유령 상자가
## 가나다순으로 보여 준다 — 순서까지 알려 주면 그건 답이다.
##
## 파랑(돌려야 함)을 금색(옮겨야 함)보다 먼저 말하는 이유: 파랑은 화면에 보이는 글자가
## 쓸 글자와 **다르다**. 끌어다 놓아도 안 되는 유일한 색이라, 모르고 지나치면 헛수고를
## 반복한다. 회색(안 쓰임)도 말해 준다. 금색만 알려 주면 화면은 [ㄱ][ㅣ][필요][ㅇ][ㅂ]
## 처럼 보이고, 플레이어는 ㄱ 을 맨 앞에 둔 채 ㅇ ㅂ 을 뒤에 붙여 없는 단어를 상상한다.
## 이 타일들은 **빼야** 목표가 된다 — 안 쓰인 타일은 옮겨서 되는 게 아니라 나가야 한다.
func _slot_hint_text(slot_index: int) -> String:
	var target := slot_targets[slot_index]
	if target == "":
		return _no_target_text(slot_index)
	var grade: Dictionary = slot_grades[slot_index]
	var missing: Array = grade.get("missing", [])
	var parts: Array = ["%d번 목표 %d음절" % [slot_index + 1, target.length()]]
	if not missing.is_empty():
		parts.append("빠진 활자 %d개" % missing.size())
	var to_rotate := _count_grade(grade, "rotate")
	if to_rotate > 0:
		parts.append("파랑 %d개 회전" % to_rotate)
	var to_move := _count_grade(grade, "near")
	if to_move > 0:
		parts.append("금색 %d개 이동" % to_move)
	var unused := _count_grade(grade, "off")
	if unused > 0:
		parts.append("회색 %d개 제외" % unused)
	if to_move == 0 and to_rotate == 0 and unused == 0 and missing.is_empty():
		parts.append("지금 배치 그대로 완성")
	return "  ·  ".join(parts)


## 채점 결과에서 특정 등급의 타일 수. 상태 배열은 '타일 순서' 그대로다.
func _count_grade(grade: Dictionary, want: String) -> int:
	var count := 0
	for state in grade.get("states", []):
		if str(state) == want:
			count += 1
	return count


## 사전 단어를 하나도 못 세울 때의 한 줄.
##
## 예전에는 두 상태를 **같은 문장**으로 뭉갰다 — 슬롯이 비어 있는 경우와, 슬롯이
## '미지의 활자'(사전에 없는 음절)를 세우고 있는 경우다. 후자는 **일하고 있는 타워**다:
## 기본 탄환을 쏘고 있고 화면에도 서 있다. 그런데 문장은 "만들 수 있는 단어가 없어요"
## 라고만 말해 '이 슬롯은 아무것도 아니다' 로 읽혔다. 플레이어는 그 타워를 지워야 하는지
## 남겨야 하는지 판단할 근거를 못 얻는다.
##
## 실측(봉지 15종 = ALL_DRAW_POOL, 1~5장 전수 15503개): 이 줄이 뜨는 경우 3924건(25.3%).
## 그중 2462건은 슬롯이 비어 있었고, **1462건(37%)은 미지의 활자를 세우고 있었다.**
## (등록어를 세우고 있는데 이 줄이 뜨는 경우는 0건 — 그런 모순은 없다)
##
## 서 있는 음절을 그대로 적는 것은 답을 흘리는 게 아니다 — 화면에 이미 서 있는 글자다.
## '미지의 활자' 도 이 게임이 이미 쓰는 말이다(`HangulStreamParser.make_unknown_word_data`,
## `LexiconModal`). 벨트 헤더만 그 말을 안 쓰고 있었다.
func _no_target_text(slot_index: int) -> String:
	var parsed := parsed_slots()
	var item: Dictionary = parsed[slot_index] if slot_index < parsed.size() else {}
	var standing := str(item.get("syllable", ""))
	if standing == "":
		return "%d번 슬롯: 지금 타일로 만들 수 있는 단어가 없어요" % (slot_index + 1)
	return "%d번 슬롯: %s (미지의 활자) — 기본 탄환만 나가요" % [slot_index + 1, standing]


## 슬롯 고정 토글.
##
## 고정된 단어의 타일은 옆 슬롯에서 힌트를 눌러도 조합에 포함되지 않는다.
## 이게 있어야 '1번은 이걸로 간다' 를 정하고 2번을 볼 수 있다 — 없으면 세 슬롯이
## 같은 최고 단어를 놓고 서로 타일을 뺏는다.
func _toggle_slot_lock(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= unlocked_slot_count:
		return
	if slot_locked[slot_index]:
		slot_locked[slot_index] = false
		slot_reserved[slot_index] = []
		slot_lock_order.erase(slot_index)
		slot_targets[slot_index] = ""
		slot_grades[slot_index] = {}
		SoundEngine.play_tile_click()
		render_belt()
		parsed_preview_label.text = "%d번 슬롯 고정 및 힌트 해제" % (slot_index + 1)
		return
	var word := slot_targets[slot_index]
	if word == "":
		# 힌트를 안 눌렀으면 지금 슬롯에 완성된 단어를 고정한다.
		var parsed := _slot_parse(slot_index)
		if parsed.size() == 1: word = str(parsed[0].get("syllable", ""))
	if word == "":
		parsed_preview_label.text = "%d번 슬롯: 고정할 단어가 없어요 (힌트를 먼저 누르세요)" % (slot_index + 1)
		return
	var idx := AutoArrange.tile_indices_for(word, jamo_list, _reserved_except(slot_index))
	if idx.is_empty():
		# 어떤 단어인지는 적지 않는다. 힌트가 고른 목표였다면 그대로 답이 된다.
		parsed_preview_label.text = "%d번 슬롯: 이 단어는 지금 타일로 만들 수 없어 고정할 수 없어요" % (slot_index + 1)
		return
	slot_targets[slot_index] = word
	slot_reserved[slot_index] = idx
	slot_locked[slot_index] = true
	slot_lock_order.append(slot_index)
	# 고정하면 그 단어를 목표로 채점해 둔다. 그래야 '무엇을 어디로 옮겨야 하는지' 가
	# 남는다 — 고정은 계획을 잠그는 일이지, 배치를 대신 해 주는 일이 아니다.
	slot_grades[slot_index] = _grade_slot(slot_index, word)
	SoundEngine.play_tile_click()
	render_belt()
	parsed_preview_label.text = "%d번 슬롯 고정 — 이 타일은 옆 슬롯 조합에서 빠집니다" % (slot_index + 1)

## 지금 슬롯 배치를 목표 단어와 자리별로 채점한다.
##
## Wordle 과 같은 단계로 나간다. 먼저 '같은 자리'(초록)를 확정하고, 그다음 남은 자리에서
## '이미 그 자모인데 자리만 다른' 타일(금색), 그다음 '돌려야 그 자모가 되는' 타일(파랑),
## 어느 쪽도 아니면 '안 씀'(회색).
##
## 금색과 파랑을 가르는 이유: 둘 다 '쓰이긴 하지만 손봐야 함' 이지만 플레이어가 할 일이
## 다르다. 금색은 끌어다 놓으면 되고, 파랑은 ↻ 를 눌러야 한다. 한 색으로 묶어 두면
## ㅏ 를 ㅗ 자리에 끌어다 놓고 "왜 안 되지" 를 반복한다.
##
## 금색을 파랑보다 **먼저** 집는다. 옮기는 것이 돌리는 것보다 싸고, 화면에 보이는 글자가
## 곧 쓸 글자라 헷갈리지 않는다. 이 순서 덕분에 3단계에 남는 타일은 '같은 자모가 아직
## 안 쓰인 자리에 남아 있지 않은' 타일뿐이라, 회전 여부만 보면 된다.
##
## 회전 판정을 합자(ㄲ)에 걸지 않는 이유: 회전은 **타일 한 장**에 걸리는 동작이고 합자는
## ROTATABLE_TILES 에 없다. 펼친 조각 ㄱ 이 회전 가능하다는 이유로 합자에 파랑을 칠하면
## 화면에 ↻ 배지조차 없는 타일을 돌리라고 시키는 셈이다. 같은 이유로 합자는 '펼친 조각이
## 목표 자모와 같을 때' 만 쓰인 것으로 본다 — ㄲ 한 장으로 ㄴ 을 채울 수는 없다.
func _grade_slot(slot_index: int, target: String) -> Dictionary:
	if target == "":
		return {}
	var req: Array = AutoArrange.required_jamo(target)
	var tiles: Array = []
	for i in _slot_indices(slot_index):
		tiles.append(jamo_list[i])
	# 합자 타일(ㄲ)은 자리 두 개를 채우므로 양쪽을 같은 방식으로 펼쳐 자리를 맞춘다.
	# owner 는 그 자리가 어느 타일에서 나왔는지다 — 회전 가능 여부가 타일에 걸려 있다.
	var flat: Array = []
	var spans: Array = []
	var owner: Array = []
	for t in tiles:
		var parts: Array = WordSynergy.EXPAND.get(t, [t])
		spans.append([flat.size(), flat.size() + parts.size()])
		for part in parts:
			flat.append(part)
			owner.append(t)

	var mark: Array = []
	mark.resize(flat.size())
	mark.fill("off")
	var used: Array = []
	used.resize(req.size())
	used.fill(false)
	# 1단계: 같은 자리.
	for i in range(mini(flat.size(), req.size())):
		if flat[i] == req[i]:
			mark[i] = "pos"
			used[i] = true
	# 2단계: 이미 그 자모인데 자리만 다른 타일.
	for i in range(flat.size()):
		if mark[i] != "off": continue
		for j in range(req.size()):
			if used[j]: continue
			if flat[i] == req[j]:
				mark[i] = "near"
				used[j] = true
				break
	# 3단계: 돌려야 그 자모가 되는 타일. 여기 남은 타일에는 '같은 자모' 가 안 남아 있으므로
	# (2단계가 전부 훑었다) 회전만 보면 된다.
	for i in range(flat.size()):
		if mark[i] != "off": continue
		if WordSynergy.EXPAND.has(owner[i]): continue
		for j in range(req.size()):
			if used[j]: continue
			if AutoArrange.can_fill(flat[i], req[j]):
				mark[i] = "rotate"
				used[j] = true
				break

	var states: Array = []
	for k in range(tiles.size()):
		var all_pos := true
		var any_used := false
		var any_rot := false
		for i in range(int(spans[k][0]), int(spans[k][1])):
			if mark[i] != "pos": all_pos = false
			if mark[i] == "rotate": any_rot = true
			if mark[i] != "off": any_used = true
		if all_pos:
			states.append("pos")
		elif any_rot:
			states.append("rotate")
		elif any_used:
			states.append("near")
		else:
			states.append("off")
	var missing: Array = []
	for j in range(req.size()):
		if not used[j]: missing.append(req[j])
	return {"states": states, "missing": missing, "target": target}

## 벨트가 바뀌면(추가·제거·교체·회전) 예약이 가리키던 타일이 사라지거나 밀린다.
## 고정한 순서대로 다시 잡아 보고, 못 잡으면 그 슬롯의 고정을 푼다.
##
## 순서가 중요하다: 나중에 고정한 슬롯이 먼저 고정한 슬롯의 타일을 빼앗으면
## '고정' 이라는 약속이 깨진다. 그래서 슬롯 번호가 아니라 고정한 순서로 돈다.
func _refresh_locks() -> void:
	var blocked: Array = []
	var kept_order: Array = []
	for k in slot_lock_order:
		if not slot_locked[k] or k >= unlocked_slot_count:
			slot_locked[k] = false
			continue
		var idx := AutoArrange.tile_indices_for(slot_targets[k], jamo_list, blocked)
		if idx.is_empty():
			slot_locked[k] = false
			slot_grades[k] = {}
			continue
		slot_reserved[k] = idx
		blocked.append_array(idx)
		kept_order.append(k)
	slot_lock_order = kept_order
	for k in range(MAX_SLOTS):
		if not slot_locked[k]:
			slot_reserved[k] = []

## 벨트가 바뀔 때마다 '지금 배치가 목표에 얼마나 맞는지' 를 다시 그린다.
##
## 목표 자체는 플레이어가 힌트로 정한 계획이라 함부로 바꾸지 않는다. 하지만
## 색과 유령 상자를 그대로 두면 거짓말이 된다 — 타일을 1번 슬롯으로 옮겨도
## '부족한 활자' 에 그 타일이 계속 남아 있게 된다.
##
## 목표를 아예 만들 수 없게 됐으면(타일을 팔았다) 채점을 지운다. 만들 수 없는
## 단어를 목표로 세워 두면 모든 타일이 회색인 화면만 남는다.
##
## 판정은 **벨트 전체**로 한다. 목표는 '이 슬롯에 지금 있는 타일' 의 채점표가 아니라
## **이 슬롯이 도달해야 할 단어**다 — 타일을 끌어다 넣어 채우는 것이 정상 흐름이므로,
## 아직 안 넣은 활자가 있어도(유령 상자) 목표는 살아 있어야 한다.
## 벨트 어디에도 그 단어가 없어졌을 때만 목표가 죽는다.
func _regrade_slots() -> void:
	for k in range(MAX_SLOTS):
		if slot_targets[k] == "":
			slot_grades[k] = {}
			continue
		if AutoArrange.tile_indices_for(slot_targets[k], jamo_list, []).is_empty():
			slot_targets[k] = ""
			slot_grades[k] = {}
			continue
		slot_grades[k] = _grade_slot(k, slot_targets[k])

## 새 게임·불러오기에 쓴다. 고정은 지금 벨트에 대한 계획이라 저장하지 않는다.
func clear_slot_locks() -> void:
	slot_locked = [false, false, false]
	slot_reserved = [[], [], []]
	slot_targets = ["", "", ""]
	slot_grades = [{}, {}, {}]
	slot_lock_order = []

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "jamo_tile"):
		return false
	# 벨트 배경(어느 트레이도 아닌 곳)은 '대기 타일로 내려보내기' 다.
	set_drag_target(null, -1, -1)
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# 벨트 배경(어느 트레이도 아닌 곳)에 놓으면 대기 타일로 내려보낸다.
	if data is Dictionary and data.get("type") == "jamo_tile":
		commit_drag_drop(data.get("from_index", -1), -1)

func _tile_boxes(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is JamoTileBox: result.append(child)
		else: result.append_array(_tile_boxes(child))
	return result

func add_jamo(c: String) -> void:
	if jamo_list.size() < MAX_BELT_TILES:
		jamo_list.append(c)
		slot_assignments.append(-1)
		render_belt()

func remove_jamo(index: int) -> void:
	_normalize_assignments()
	if index < 0 or index >= jamo_list.size(): return
	jamo_list.remove_at(index)
	slot_assignments.remove_at(index)
	selected_index_for_swap = -1
	removal_mode = false
	swap_mode = false
	render_belt()

## index 번째 활자의 **타일 노드**. 없으면 null.
##
## 보상 카드가 벨트로 '날아가는' 연출(§2.6 문제 2)의 **도착점**이다. 벨트 전체가 아니라
## **그 칸**을 가리켜야 "어디로 들어갔는가" 가 정보가 된다.
##
## ⚠️ 타일은 `tiles_container` 의 **직계 자식이 아니다.** `tiles_container` 에는 트레이
## (`_make_tray`)가 들어가고, 타일은 그 안쪽 `row` 에 있다. 그래서 직계만 훑으면
## **언제나 null** 이 나온다(실제로 그렇게 짰다가 잡았다 — `tools/RewardFlightProbe.gd`).
## 이미 있는 재귀 수집기 `_tile_boxes` 를 쓴다.
##
## ⚠️ `render_belt()` 직후에는 좌표가 아직 확정되지 않았다 — `HFlowContainer` 가 자식을
## 배치하는 것은 **다음 프레임**이다. 호출부는 한 프레임 기다린 뒤에 이 함수를 부른다.
## (그래서 노드를 미리 잡아 두면 안 된다: 기다리는 동안 다시 렌더되면 해제된다.)
func tile_node_at(index: int) -> Control:
	if index < 0 or index >= jamo_list.size():
		return null
	for c in _tile_boxes(tiles_container):
		if c.tile_index == index:
			return c
	return null

## 활자 한 장을 다른 활자로 갈아 끼운다. 벨트 크기와 슬롯 배치는 그대로 둔다.
func swap_jamo(index: int, new_char: String) -> void:
	if index < 0 or index >= jamo_list.size(): return
	jamo_list[index] = new_char
	selected_index_for_swap = -1
	swap_mode = false
	render_belt()

func set_unlocked_slot_count(count: int) -> void:
	unlocked_slot_count = clampi(count, 0, MAX_SLOTS)
	_normalize_assignments()
	for i in range(slot_assignments.size()):
		if slot_assignments[i] >= unlocked_slot_count: slot_assignments[i] = -1

## 세이브를 되돌려 놓기 **직전**에 부른다 — 다음 `render_belt()` 한 번만 셀레브레이션을 끈다.
##
## 불러오기는 완성이 아니다. 벨트가 통째로 교체되므로(자모 목록 → 슬롯 배치 순서)
## 이 가드가 없으면 세이브에 타워가 하나라도 있을 때마다 "단어 완성" 배너와 소리가 터진다 —
## 아무것도 만들지 않았는데. `_is_first_render` 는 **최초 1회**만 막아 주므로 이 자리를 못 막는다.
func begin_restore() -> void:
	_suppress_celebration = true

func restore_assignments(saved: Array) -> void:
	slot_assignments.clear()
	for value in saved: slot_assignments.append(int(value))
	_normalize_assignments()
	set_unlocked_slot_count(unlocked_slot_count)

func _normalize_assignments() -> void:
	while slot_assignments.size() < jamo_list.size(): slot_assignments.append(-1)
	while slot_assignments.size() > jamo_list.size(): slot_assignments.pop_back()

func rotate_first_available() -> void:
	for i in range(jamo_list.size()):
		if HangulEngine.is_rotatable(jamo_list[i]):
			jamo_list[i] = HangulEngine.rotate(jamo_list[i])
			SoundEngine.play_tile_rotate()
			render_belt()
			break

func handle_insert_drag_drop(from_idx: int, target_insert_idx: int, target_slot_override := -2) -> void:
	var result := _apply_insert(from_idx, target_insert_idx, target_slot_override, true)
	if result.get("ok", false):
		SoundEngine.play_tile_click()
		render_belt()
	else:
		_announce_reject(result)

func handle_drag_drop(from_idx: int, to_idx: int) -> void:
	handle_insert_drag_drop(from_idx, to_idx)


## ── 드래그 중 안내 ────────────────────────────────────────────────────────────
##
## 예전에는 드래그하는 동안 화면이 **아무것도** 바뀌지 않았다. 그래서 놓기 전에는
## 어디로 들어갈지 알 수 없었고, 놓은 뒤에는 조용히 되돌아갔다. 실측으로 다섯 번
## 중 세 번이 '아무 일도 안 일어남' 이었다 — 플레이어는 안 되는 것인지, 자기가
## 잘못 놓은 것인지 구분할 수가 없다.
##
## 그래서 드래그가 시작되면 매 프레임 **놓으면 어떻게 되는지**를 계산해 트레이
## 색으로 보여 주고, 실패하면 이유를 한 줄로 말한다.
##
## 계산은 `_apply_*(…, commit=false)` 로 한다. 미리보기와 실제 놓기가 **같은
## 함수**를 써야 "금색으로 보였는데 안 놓인다" 가 안 생긴다.
var _drag_from_index := -1
var _drag_tray: JamoTray = null
var _drag_slot := -2
var _drag_insert := -1
var _drag_ok := false
var _preview_before_drag := ""

## 드래그 시작. JamoTileBox._get_drag_data 가 부른다.
func begin_drag(from_idx: int) -> void:
	_drag_from_index = from_idx
	_preview_before_drag = parsed_preview_label.text if parsed_preview_label != null else ""
	_drag_tray = null
	_drag_slot = -2
	_drag_insert = -1
	_drag_ok = false

## 드래그 종료. 강조를 풀고 드래그 전 문구로 되돌린다.
func end_drag(restore_text := true) -> void:
	_set_drag_highlight(null)
	if restore_text and parsed_preview_label != null:
		parsed_preview_label.text = _preview_before_drag
	_drag_from_index = -1
	_drag_tray = null
	_drag_slot = -2
	_drag_insert = -1
	_drag_ok = false

## 마우스 아래의 드롭 대상을 확인하고, 대상 밖으로 나갔으면 강조를 지운다.
##
## 엔진의 `_can_drop_data` 에 지우기를 맡길 수 없다: 그건 마우스가 **움직일 때만**
## 불려서, 대상이 아닌 곳으로 나가면 아무도 불리지 않아 강조가 거짓으로 남는다.
## 반대로 위치 계산(좌/우 절반)을 여기서 하면 안 된다 — `Viewport.get_mouse_position()`
## 은 OS 커서를 돌려주는 것이라 합성 입력에서도, 창이 비활성일 때도 엉뚱한 값이 온다
## (실측: 이벤트는 (957, 87) 로 보냈는데 -307 이 돌아왔다). 그래서 위치는 엔진이
## `_can_drop_data` 로 넘겨주는 값만 믿는다.
func _process(_delta: float) -> void:
	# 드래그 중에만 의미가 있다. 평소에는 이 한 줄로 끝난다.
	if _drag_from_index == -1:
		return
	var viewport := get_viewport()
	if not viewport.gui_is_dragging():
		end_drag()
		return
	if _tray_under(viewport.gui_get_hovered_control()) == null:
		_set_drag_highlight(null)

## 타일 위로 드래그가 들어왔다. 좌/우 절반이 '어느 쪽에 끼워 넣을지' 를 정한다.
func set_drag_target_on_tile(tile: JamoTileBox, right_half: bool) -> void:
	set_drag_target(_tray_under(tile), slot_assignments[tile.tile_index],
		tile.tile_index + (1 if right_half else 0))

## 트레이(타일이 아닌 빈 공간) 위로 드래그가 들어왔다. 슬롯 끝에 붙는다.
func set_drag_target_on_tray(tray: JamoTray) -> void:
	set_drag_target(tray, tray.slot_index, -1)

## 드롭 대상을 확정하고 그 결과를 화면에 칠한다.
##
## **놓을 자리를 여기서 정해 두고, 놓는 순간에는 이 값을 그대로 쓴다.** 미리보기와
## 실제 놓기가 같은 계산(`_resolve_drop(..., commit=false)`)을 타므로 "금색으로
## 보였는데 안 놓인다" 가 구조적으로 불가능하다.
func set_drag_target(tray: JamoTray, slot: int, insert: int) -> void:
	if _drag_from_index == -1:
		return
	if tray == null:
		_set_drag_highlight(null)
		return
	var result := _resolve_drop(_drag_from_index, slot, insert, false)
	_drag_slot = slot
	_drag_insert = insert
	_drag_ok = result.get("ok", false)
	_set_drag_highlight(tray, result)

## 트레이 하나만 색으로 강조하고, 그 이유를 헤더 한 줄에 쓴다.
func _set_drag_highlight(tray: JamoTray, result: Dictionary = {}) -> void:
	if _drag_tray != null and _drag_tray != tray and is_instance_valid(_drag_tray):
		_drag_tray.set_drop_state(0)
	_drag_tray = tray
	if tray == null:
		# 대상 밖 — 확정된 자리를 지운다. 안 지우면 벨트 배경에 놓았을 때
		# 직전에 강조했던 슬롯으로 들어간다.
		_drag_slot = -2
		_drag_insert = -1
		_drag_ok = false
		if parsed_preview_label != null:
			parsed_preview_label.text = _preview_before_drag
		return
	if is_instance_valid(tray):
		tray.set_drop_state(1 if result.get("ok", false) else 2)
	if parsed_preview_label != null:
		parsed_preview_label.text = str(result.get("note", ""))

## 컨트롤에서 위로 올라가며 트레이/타일을 찾는다.
## 엔진도 드롭 대상을 같은 방식으로(Control::can_drop_data 가 부모로 올라가며)
## 고르므로, 여기서 찾은 대상이 곧 엔진이 고를 대상이다.
func _tray_under(control: Control) -> JamoTray:
	var node: Node = control
	while node != null:
		if node is JamoTray:
			return node
		node = node.get_parent()
	return null

func _tile_under(control: Control) -> JamoTileBox:
	var node: Node = control
	while node != null:
		if node is JamoTileBox:
			return node
		node = node.get_parent()
	return null

## 놓으면 어떻게 되는가. insert >= 0 이면 '그 자리에 끼워 넣기', 아니면 '슬롯에 붙이기'.
##
## **판정하지 않는다.** 예전에는 "한 슬롯에 한 단어" 규칙에 안 맞으면 드롭을 거부했고,
## 그래서 ㅅ ㅣ ㅜ ㅏ 처럼 아직 단어가 아닌 배치를 **시도조차** 할 수 없었다. 배치를
## 자유롭게 하려는 플레이어에게 그게 가장 답답한 지점이었다.
##
## 이제 놓는 것은 자유롭고, 그 슬롯이 단어가 되는지는 `parsed_slots()` 가 따로 판단한다.
## 단어가 안 되면 타워가 안 생길 뿐이다 — 배치 자체를 막을 이유는 없다.
func _resolve_drop(from_idx: int, slot: int, insert: int, commit: bool) -> Dictionary:
	_normalize_assignments()
	if from_idx < 0 or from_idx >= jamo_list.size():
		return {"ok": false, "note": ""}
	if slot >= unlocked_slot_count:
		return {"ok": false, "note": "%s은(는) 아직 잠겨 있습니다" % _slot_name(slot)}
	if insert >= 0:
		var position := _slot_position_after_insert(from_idx, slot, insert)
		if commit:
			_insert_tile(from_idx, insert, slot)
		return {"ok": true, "note": "%s %d번째 자리에 놓습니다" % [_slot_name(slot), position]}
	# 슬롯에 붙이기 — 순서는 지금 벨트 순서 그대로다.
	if commit:
		slot_assignments[from_idx] = slot
	return {"ok": true, "note": "%s에 놓습니다" % _slot_name(slot)}

## 타일을 뽑아낸 뒤의 최종 인덱스. 왼쪽에서 오른쪽으로 옮기면 하나 당겨진다.
## 실제 삽입과 미리보기가 이 함수를 공유해야 "N번째 자리" 안내가 거짓말이 안 된다.
func _insert_position(from_idx: int, target_insert_idx: int) -> int:
	var final_idx := target_insert_idx
	if from_idx < target_insert_idx:
		final_idx -= 1
	return clampi(final_idx, 0, maxi(0, jamo_list.size() - 1))

func _insert_tile(from_idx: int, target_insert_idx: int, target_slot: int) -> void:
	var final_idx := _insert_position(from_idx, target_insert_idx)
	var item = jamo_list[from_idx]
	var assignment = slot_assignments[from_idx]
	jamo_list.remove_at(from_idx)
	slot_assignments.remove_at(from_idx)
	jamo_list.insert(final_idx, item)
	slot_assignments.insert(final_idx, target_slot)

## 끼워 넣은 뒤 그 슬롯에서 몇 번째가 되는가(1부터). 벨트를 건드리지 않고 센다.
func _slot_position_after_insert(from_idx: int, slot: int, insert: int) -> int:
	var final_idx := _insert_position(from_idx, insert)
	var before := 0
	for i in _slot_indices(slot):
		if i != from_idx and i < final_idx: before += 1
	return before + 1

func _slot_name(slot_index: int) -> String:
	return "대기 타일" if slot_index < 0 else "%d번 슬롯" % (slot_index + 1)

## 드래그를 지금 위치에 놓는다. 미리보기가 계산해 둔 결과를 그대로 다시 돌린다.
##
## `_drop_data` 가 부른다. 미리보기가 한 번도 안 돌았으면(합성 호출/테스트)
## 넘겨받은 값으로 계산한다.
func commit_drag_drop(fallback_from := -1, fallback_slot := -2, fallback_insert := -1) -> bool:
	var from_idx := _drag_from_index if _drag_from_index != -1 else fallback_from
	if from_idx < 0 or from_idx >= jamo_list.size():
		end_drag()
		return false
	var slot := _drag_slot if _drag_slot != -2 else fallback_slot
	var insert := _drag_insert if _drag_slot != -2 else fallback_insert
	if insert < 0 and slot == -2:
		slot = -1
	var result := _resolve_drop(from_idx, slot, insert, true)
	end_drag(false)
	if result.get("ok", false):
		SoundEngine.play_tile_click()
		render_belt()
		return true
	_announce_reject(result)
	return false

## 놓지 못했을 때 이유를 말한다. 조용히 되돌아가면 플레이어는 자기가 뭘 잘못했는지
## 알 수 없고, 같은 시도를 반복한다.
func _announce_reject(result: Dictionary) -> void:
	if parsed_preview_label == null:
		return
	var note := str(result.get("note", ""))
	parsed_preview_label.text = note if note != "" else "거기에는 놓을 수 없습니다"

## 슬롯 하나에 이 타일이 들어가면 어떻게 되는지. commit=false 면 계산만 한다.
##
## 되돌리기가 필요 없어진 이유: 이제 놓기를 거부하지 않으므로(자유 배치) 계산과
## 실행이 갈라질 여지 자체가 없다. 남은 거부는 '잠긴 슬롯' 뿐이고, 그건 놓기 전에
## 슬롯 번호만 보면 알 수 있다.
func _apply_insert(from_idx: int, target_insert_idx: int, target_slot_override: int, commit: bool) -> Dictionary:
	return _resolve_drop(from_idx,
		target_slot_override if target_slot_override != -2 \
			else (slot_assignments[target_insert_idx] if target_insert_idx < slot_assignments.size() else -1),
		target_insert_idx, commit)

func move_jamo_to_slot(from_idx: int, slot_index: int) -> bool:
	var result := _resolve_drop(from_idx, slot_index, -1, true)
	if result.get("ok", false):
		render_belt()
		return true
	return false

func _slot_chars(slot_index: int) -> Array:
	var chars := []
	for index in _slot_indices(slot_index): chars.append(jamo_list[index])
	return chars

func _slot_indices(slot_index: int) -> Array:
	var result := []
	for i in range(slot_assignments.size()):
		if slot_assignments[i] == slot_index: result.append(i)
	return result

func _slot_parse(slot_index: int) -> Array:
	return HangulStreamParser.parse_jamo_stream(_slot_chars(slot_index))

func parsed_slots() -> Array:
	var parsed: Array = [{}, {}, {}]
	for slot_index in range(unlocked_slot_count):
		var slot_parsed = _slot_parse(slot_index)
		if slot_parsed.size() == 1 and slot_parsed[0]["indices"].size() == _slot_indices(slot_index).size():
			var item = slot_parsed[0].duplicate(true)
			item["indices"] = _slot_indices(slot_index)
			parsed[slot_index] = item
	return parsed

func recommendation_tiles() -> Array[String]:
	_normalize_assignments()
	var parsed := parsed_slots()
	var result: Array[String] = []
	for index in range(jamo_list.size()):
		var slot := slot_assignments[index]
		var slot_data: Dictionary = parsed[slot] if slot >= 0 and slot < parsed.size() else {}
		if slot < 0 or slot_data.is_empty() or slot_data.get("word_data", {}).get("is_unknown", false):
			result.append(jamo_list[index])
	return result

func render_belt() -> void:
	_normalize_assignments()
	# 고정은 인덱스가 아니라 '단어' 를 잡아 두지만, 벨트가 바뀌면 그 단어를 이루던
	# 타일이 사라지거나 밀린다. 렌더 직전에 한 번 다시 잡아 주는 것이 유일한 갱신점이다
	# (추가·제거·교체·회전·드래그가 모두 여기로 모인다).
	_refresh_locks()
	_regrade_slots()
	set_relics(relic_ids)
	_update_buy_buttons()
	for c in tiles_container.get_children():
		tiles_container.remove_child(c)
		c.queue_free()

	var parsed = parsed_slots()

	# Build preview text & discover newly formed words
	var preview_words = []
	var parsed_syllables: Array = []
	var new_words: Array[String] = []
	for p in parsed:
		if p.is_empty(): continue
		var syl = p["syllable"]
		preview_words.append("[%s 타워]" % syl)
		parsed_syllables.append(syl)
		SaveManager.discover_word(syl)
		if not _last_parsed_words.has(syl):
			new_words.append(syl)
	# ⚠️ 여기에는 **음절**을 담는다. 예전에는 서식이 붙은 `preview_words` 를 담아 두고
	# 위에서 맨 음절로 `has()` 를 물었다 — 두 목록의 원소가 절대 같을 수 없어서 비교가
	# 항상 false 였고, `new_words` 가 매 렌더마다 '지금 완성된 단어 전부' 가 됐다.
	# 그래서 타일을 드래그·회전·구매·교체할 때마다 "단어 완성" 배너가 다시 떴다.
	# (실측: tools/CelebrationProbe.gd — 상태를 바꾸지 않고 다시 렌더해도 배너가 떴다)
	_last_parsed_words = parsed_syllables
	if parsed_preview_label:
		parsed_preview_label.text = "자동 완성 타워: " + ("  >  ".join(preview_words) if not preview_words.is_empty() else "단어 조합 없음")

	# Emit signals
	parsed_towers_updated.emit(parsed)
	jamo_changed.emit()

	# 새 단어가 완성된 순간은 이 게임의 핵심 쾌감 지점 → 강조 연출
	# 단, 불러오기 중에는 내지 않는다 — 그때의 단어는 방금 만든 것이 아니라 되돌린 것이다.
	if not new_words.is_empty() and not _is_first_render and not _suppress_celebration:
		_celebrate_new_words(new_words)
	_is_first_render = false
	_suppress_celebration = false

	for slot_index in range(MAX_SLOTS):
		_add_tile_group("%d번 슬롯%s" % [slot_index + 1, " (잠김)" if slot_index >= unlocked_slot_count else ""], _slot_indices(slot_index), slot_index, slot_index >= unlocked_slot_count)
	_add_tile_group("대기 타일", _slot_indices(-1), -1)

## 새로 완성된 단어를 **화면 가로 중앙** 상단에 잠깐 띄워 보여준다.
##
## ⚠️ 세로 위치는 상단 고정(y=64)이다. 상단 띠(58~118)가 보스 체력바·배너로 차 있어
## '아무것도 안 겹치는 y' 가 없다 — 어디에 둘지는 **감독 결정 사항**이고,
## `tools/BannerLayoutProbe.tscn` 이 무엇과 얼마나 겹치는지 측정해 보고한다.
##
## 소리는 `SoundEngine.play_word_crafted()` 를 쓴다 — 그 소리의 **제 이름의 사건**이 여기다.
## 2026-09-23 이전에는 이 자리에 소리가 **아예 없었고**, 정작 `play_word_crafted` 는
## 모음 타일 구매 · 드래프트 구매 · 새 게임 · 도감 열기 · 타이틀 버튼에서 울렸다.
## 이름이 계약인데 계약이 지켜지지 않던 자리라, 새 효과를 만든 것이 아니라
## **이미 있는 소리를 제 사건에 연결**한 것이다.
func _celebrate_new_words(words: Array[String]) -> void:
	if parsed_preview_label == null or not is_inside_tree():
		return
	SoundEngine.play_word_crafted()
	var banner := Label.new()
	banner.text = "단어 완성  " + " · ".join(words)
	banner.z_index = 120
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", Palette.TX_GOLD)
	banner.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	banner.add_theme_constant_override("outline_size", 5)
	# 주의: JamoBelt(PanelContainer)의 자식으로 두면 안 된다.
	# PanelContainer 는 모든 Control 자식을 자기 내용 영역에 꽉 채우도록 배치하므로
	# 아래에서 정한 위치가 통째로 무시되고, 배너가 **자모 타일 위에 겹쳐** 그려진다.
	# (실측: 타일 y≈515 에 겹쳐서 글자가 타일을 가렸다)
	# 그래서 화면 루트에 붙이고 화면 기준으로 배치한다.
	var host: Node = get_tree().current_scene
	if host == null:
		host = self
	host.add_child(banner)
	# 폭을 **화면 전체**로 잡고 글자를 가운데 정렬한다 — 중심이 어떤 단어 길이에도 안 흔들린다.
	# ⚠️ 예전에는 `PRESET_CENTER_TOP` 을 쓴 뒤 `position += Vector2(-180.0, 64.0)` 을 했다.
	#   `PRESET_CENTER_TOP` 은 **이미** 가로 중앙 정렬을 하므로, 거기에 -180 을 또 더한 만큼
	#   중심이 왼쪽으로 밀렸다(실측 tools/BannerLayoutProbe.tscn: 단어 1개 **93.5px** ·
	#   3개 **180.0px**). 폭도 `custom_minimum_size`(360) 가 아니라 글자 길이를 따라가서(385)
	#   밀리는 양까지 단어마다 달라졌다.
	#   보스 배너(`DefenseField._show_boss_banner`)는 `position = Vector2(-160.0, 54.0)` 처럼
	#   `=` 로 앵커 기준값을 주므로 정확히 중앙이다(실측 0.0px). 두 배너의 관례가 서로
	#   달랐던 것이 원인이라, 폭 고정을 버리고 앵커로 중앙을 잡는 쪽으로 맞췄다.
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# 상단 바(높이 약 58px) 바로 아래, 플레이 필드의 맨 위.
	# ⚠️ 보스 배너(화면 y≈128)와는 겹치지 않는다. 다만 보스 **체력바**(화면 y≈76~118)의
	#   위 10px 를 덮는다 — 상단 띠에 자리가 없어서다(위 문서 주석 참고).
	banner.position.y = 64.0
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.85, 0.85)
	# pivot 은 레이아웃 뒤에 확정된다. size 가 0 이면 (0,0) 이 되어 BACK_OUT 팝이
	# 가운데가 아니라 좌상단에서 자란다.
	# ⚠️ 이 줄을 `custom_minimum_size * 0.5` 로 '고치지' 말 것 — 감사 §6.2-3 이 그렇게 적어
	#   두었지만 그건 `PRESET_TOP_WIDE` 이전의 이야기다. 그때는 앵커 preset 이 **글자
	#   최소폭**(187)으로 크기를 잡아 두어 세로 pivot 이 0 이었고, 그래서 팝이 **위쪽
	#   모서리**에서 자랐다(실측 pivot (180, 0) vs 중심 (180, 11)). `PRESET_TOP_WIDE` 는
	#   폭이 앵커에서 바로 나오므로 지금 size 가 곧바로 화면 폭이다.
	banner.pivot_offset = banner.size * 0.5
	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.16)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 주의: 트윈을 **두 개** 만들면 안 된다.
	# 예전 코드는 `out := banner.create_tween()` 을 따로 만들어 곧바로 시작시켰는데,
	# 그 시점의 alpha 는 방금 0.0 으로 둔 값이라 out 트윈은 '0 → 0' 을 0.3초 동안
	# 고정한다. tw 가 alpha 를 올리려 해도 매 프레임 out 이 0 으로 되돌려서
	# **배너가 화면에 전혀 나타나지 않았다.** (10프레임 연속 캡처에서 금색 픽셀 증가 0)
	# 보스 배너(_show_boss_banner)처럼 트윈 하나로 순차 처리한다.
	tw.chain().set_parallel(false)
	tw.tween_interval(0.75)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(banner.queue_free)

func optimize_tiles() -> bool:
	strategy_recommendations_requested.emit()
	return true

func _add_tile_group(title_text: String, indices: Array, slot_index := -1, locked := false) -> void:
	var tray = JamoTray.new(self, slot_index)
	tray.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
	var style = StyleBoxFlat.new()
	var is_waiting = title_text == "대기 타일"
	style.bg_color = Palette.BG_INSET if is_waiting else Palette.BG_PANEL
	style.border_color = Palette.LINE_SUBTLE if is_waiting else Palette.LINE_NORMAL
	# 고정된 슬롯은 테두리만 금색으로 바뀐다. 슬롯을 옮겨 다니며 비교할 때
	# '어느 슬롯이 이미 잠겼는지' 를 버튼 글자보다 테두리가 먼저 알려 준다.
	if slot_index >= 0 and slot_locked[slot_index]:
		style.border_color = Palette.TX_GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	# 머리 줄이 왼쪽으로 붙으면서 제목 첫 글자가 트레이 테두리에 닿았다.
	# 타일도 같은 만큼 안으로 들여보내, 제목과 첫 타일의 왼쪽 끝을 맞춘다.
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	tray.add_theme_stylebox_override("panel", style)
	# 드롭 강조가 끝나면 되돌릴 색. 고정된 슬롯은 테두리가 금색이라, '금색으로
	# 되돌리기' 로는 복원이 안 된다 — 원래 색을 들고 있어야 정확히 돌아온다.
	tray.base_border_color = style.border_color
	tray.base_bg_color = style.bg_color
	tray.panel_style = style
	var group = VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", 3)
	tray.add_child(group)
	# 제목 줄에 힌트/고정을 나란히 붙인다. 타일 위에 따로 줄을 만들면
	# 트레이가 세로로 24px 씩 자라 벨트(210px)가 두 줄에서 넘친다.
	var head = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 3)
	group.add_child(head)
	var title = Label.new()
	title.name = "SlotTitle"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 제목은 늘어나지 않는다. 예전에는 EXPAND_FILL 이라 남는 폭을 혼자 다 먹었고,
	# 그 결과 [목표 …][힌트][고정] 이 트레이 오른쪽 끝 63px 안에 뭉쳐 붙었다 —
	# '목표 입' 과 버튼이 한 덩어리로 읽혀서, 무엇이 정보이고 무엇이 버튼인지
	# 구분이 안 됐다. 남는 폭은 아래 스페이서가 먹고 버튼만 오른쪽에 붙인다.
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color",
		Palette.TX_MUTED if is_waiting else Palette.MANA_INK)
	head.add_child(title)
	# 목표의 **모양**을 트레이 안에 세운다 — 음절 수만.
	#
	# 채점 색과 유령 상자는 '무엇을 향해 채점되는지' 를 알아야 읽히는데, 목표는 벨트
	# 헤더 한 줄에만 있었다. 트레이만 보면 초록·금색·회색이 무슨 뜻인지 알 수 없다.
	#
	# 하지만 목표 단어를 그대로 적어 주면 힌트가 게임을 대신한다 — 플레이어가 할 일이
	# '단어를 찾기' 에서 '받아쓰기' 로 바뀐다. 그래서 **크기만** 말한다. 몇 글자짜리를
	# 노려야 하는지는 알려 주고, 어떤 단어인지는 플레이어가 자기 타일에서 찾는다.
	if slot_index >= 0 and slot_index < unlocked_slot_count and slot_targets[slot_index] != "":
		var target_label = Label.new()
		target_label.name = "TargetLabel"
		target_label.text = "목표 %d음절" % slot_targets[slot_index].length()
		target_label.add_theme_font_size_override("font_size", 11)
		target_label.add_theme_color_override("font_color", Palette.TX_GOLD)
		target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(target_label)
	if slot_index >= 0 and slot_index < unlocked_slot_count:
		# 남는 폭을 먹는 칸. 제목·목표는 왼쪽에 붙어 한 문장으로 읽히고,
		# 버튼만 오른쪽 끝으로 밀려난다.
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(spacer)
		head.add_child(_make_slot_button("취소" if _slot_has_hint(slot_index) else "힌트", slot_index, false))
		head.add_child(_make_slot_button("고정됨" if slot_locked[slot_index] else "고정", slot_index, true))
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	group.add_child(row)
	tiles_container.add_child(tray)
	for pos in range(indices.size()):
		row.add_child(_build_tile(indices[pos], slot_index, pos))
	# 목표 단어에 필요한데 이 슬롯에 아직 없는 활자를 유령 상자로 세워 둔다.
	# 색만으로는 '몇 칸이 더 필요한지' 가 안 보인다 — 채점의 절반은 모양이다.
	#
	# **가나다순으로 흩어 세운다.** 목표 순서대로 세우면 [내 타일…][빠진 자모…] 가
	# 그대로 이어져 화면에 목표 단어가 적힌다 — 힌트가 답을 말해 버린다.
	# 흩으면 플레이어는 '무엇이 더 필요한지' 는 알지만 '어디에 놓을지' 는 스스로
	# 찾아야 한다. 힌트가 도와야 하는 지점이 정확히 그 '배치' 다.
	if slot_index >= 0 and slot_index < unlocked_slot_count:
		var missing: Array = slot_grades[slot_index].get("missing", [])
		if not missing.is_empty():
			row.add_child(_build_need_label())
		var bag: Array = missing.duplicate()
		bag.sort()
		for ghost_pos in range(bag.size()):
			row.add_child(_build_ghost(String(bag[ghost_pos]), slot_index, ghost_pos))


## 타일과 '아직 없는 활자' 사이의 칸막이.
##
## 이게 없으면 트레이가 [내 타일…][빠진 자모…] 를 이어 붙여 **한 단어처럼** 읽힌다.
## 유령을 가나다순으로 흩어 세운 것도 같은 이유의 다른 절반이다 — 자모를 순서대로
## 세우면 칸막이가 있어도 ㅅㅜ + ㅈㅓㅇㄱㅜ = 수정구 로 읽힌다.
func _build_need_label() -> Control:
	var lbl := Label.new()
	lbl.name = "NeedLabel"
	lbl.text = "필요"
	lbl.custom_minimum_size = Vector2(0, 62)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", GRADE_GHOST_LINE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

## 슬롯 머리의 힌트/고정 버튼. 트레이(148px) 안에 제목과 함께 들어가야 하므로
## GhostButton 기본 여백(10/5)보다 좁게 잡는다.
func _slot_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 5.0
	s.content_margin_right = 5.0
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	return s

func _make_slot_button(label_text: String, slot_index: int, is_lock: bool) -> Button:
	var active: bool = is_lock and slot_locked[slot_index]
	var btn := Button.new()
	btn.name = "LockButton" if is_lock else "HintButton"
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 18)
	btn.add_theme_font_size_override("font_size", 10)
	var bg := Palette.TX_GOLD if active else Color(0, 0, 0, 0)
	btn.add_theme_color_override("font_color", Palette.BG_VOID if active else Palette.TX_SECONDARY)
	btn.add_theme_color_override("font_hover_color", Palette.BG_VOID if active else Palette.TX_PRIMARY)
	btn.add_theme_stylebox_override("normal", _slot_button_style(bg, Palette.TX_GOLD if active else Palette.LINE_NORMAL))
	btn.add_theme_stylebox_override("hover", _slot_button_style(bg, Palette.TX_GOLD))
	# ⚠️ 누른 순간은 호버와 달라야 한다(타일과 같은 이유). 비활성일 때 `bg` 가 **투명**이라
	# `darkened()` 로는 아무 변화가 없다 → 테마의 `GhostButton` 처럼 **함몰색으로 채운다**
	# (GhostButton/pressed 의 bg 는 `BG_VOID` 계열이고 normal 은 투명이다 — 같은 관례).
	var pressed_bg := bg.darkened(0.30) if active else Palette.BG_INSET
	btn.add_theme_stylebox_override("pressed", _slot_button_style(pressed_bg, Palette.TX_GOLD))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if is_lock:
		btn.tooltip_text = (
			"고정을 풉니다 — 이 슬롯의 타일이 다시 다른 슬롯 후보에 들어갑니다" if active
			else "이 슬롯의 단어를 고정합니다\n고정된 타일은 옆 슬롯의 힌트 조합에서 빠집니다")
		btn.pressed.connect(func(): _toggle_slot_lock(slot_index))
	else:
		btn.tooltip_text = (
			"이 슬롯의 힌트를 지웁니다 — 목표 단어와 채점 색이 사라집니다" if _slot_has_hint(slot_index)
			else "내 모든 타일로 만들 수 있는 최고 조합 중 이 슬롯 몫을 채점합니다")
		btn.pressed.connect(func(): _show_slot_hint(slot_index))
	return btn

## 아직 이 슬롯에 놓이지 않은 활자 자리. 드래그 대상이 아니므로 JamoTileBox 가 아니다.
##
## 이름을 자리마다 다르게 준다. 같은 이름의 형제를 add_child 하면 엔진이 조용히
## @PanelContainer@NNN 으로 바꿔 버려서, 테스트가 유령 상자를 찾지 못한다.
func _build_ghost(jamo: String, slot_index: int, ghost_pos: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "GhostTile_%d_%d" % [slot_index, ghost_pos]
	box.custom_minimum_size = Vector2(64, 62)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost_style := StyleBoxFlat.new()
	ghost_style.bg_color = Color(Palette.BG_INSET.r, Palette.BG_INSET.g, Palette.BG_INSET.b, 0.55)
	ghost_style.border_color = Color(GRADE_GHOST_LINE.r, GRADE_GHOST_LINE.g, GRADE_GHOST_LINE.b, 0.55)
	ghost_style.set_border_width_all(1)
	ghost_style.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", ghost_style)
	var glyph := Label.new()
	glyph.text = jamo
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 24)
	glyph.add_theme_color_override("font_color", Color(GRADE_GHOST_LINE.r, GRADE_GHOST_LINE.g, GRADE_GHOST_LINE.b, 0.5))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glyph)
	# 툴팁은 상자에 붙인다. 유령은 드래그 대상이 아니라 마우스를 받아도 안전하다.
	# 여기에도 목표 단어를 적지 않는다 — 상자의 활자와 순서가 이미 '무엇이 필요한지' 다.
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = "이 슬롯에 아직 없는 활자입니다\n이 활자를 채워 넣어야 목표 단어가 됩니다"
	return box

## 자모 타일의 단일 테두리 스타일. 타일마다 하나만 쓴다(이중 테두리 방지).
func _tile_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	return s

## 이 타일이 지금 어떤 색이어야 하는가. [배경, 테두리].
##
## 채점 결과가 있으면 채점 색이 등급색을 이긴다 — 힌트를 누른 순간부터
## 타일의 색은 '희귀도' 가 아니라 '목표 단어와의 관계' 를 말해야 한다.
func _tile_colors(tile: JamoTileBox) -> Array:
	match _tile_grade(tile.slot_index, tile.tile_pos):
		"pos": return [GRADE_POS_BG, GRADE_POS_LINE]
		"near": return [GRADE_NEAR_BG, GRADE_NEAR_LINE]
		"rotate": return [GRADE_ROTATE_BG, GRADE_ROTATE_LINE]
		"off": return [GRADE_OFF_BG, GRADE_OFF_LINE]
	return [HangulEngine.get_rarity_bg_color(tile.char_str), HangulEngine.get_rarity_border_color(tile.char_str)]

func _tile_grade(slot_index: int, tile_pos: int) -> String:
	if slot_index < 0 or slot_index >= MAX_SLOTS or tile_pos < 0:
		return ""
	var grade: Dictionary = slot_grades[slot_index]
	if grade.is_empty():
		return ""
	var states: Array = grade.get("states", [])
	return str(states[tile_pos]) if tile_pos < states.size() else ""

## 채점 색의 뜻. 타일 툴팁에 한 줄로 붙인다.
func _grade_label(grade: String) -> String:
	match grade:
		"pos": return "이 자리 맞음"
		"near": return "이 단어에 쓰이지만 자리가 다름"
		"rotate": return "돌려야 이 자모가 됨"
		"off": return "이 단어에 안 쓰임"
	return ""

func _build_tile(idx: int, slot_index := -1, tile_pos := -1) -> JamoTileBox:
	if idx >= 0 and idx < jamo_list.size():
		var char_str = jamo_list[idx]
		var is_rotatable = HangulEngine.is_rotatable(char_str)

		var tile_box = JamoTileBox.new(self, idx, char_str)
		tile_box.slot_index = slot_index
		tile_box.tile_pos = tile_pos

		var rarity = HangulEngine.get_rarity(char_str)
		var colors := _tile_colors(tile_box)
		var bg_color: Color = colors[0]
		var border_color: Color = colors[1]

		var is_selected = (selected_index_for_swap == idx) and not removal_mode and not swap_mode
		# 테두리는 이 버튼 하나만 그린다 → 이중 테두리 제거.
		var style := _tile_style(bg_color, border_color, 2)
		var hover_style := _tile_style(bg_color.lightened(0.12), border_color.lightened(0.30), 2)
		# ⚠️ 누른 순간은 호버와 **달라야 한다.** 예전에는 `pressed` 에 `hover_style` 을
		# 그대로 넘겨 **같은 객체**였다 — 디렉터가 지적한 "버튼은 작동하지만 눌렀다는
		# 반응이 없음" 이 정확히 이것이다(누르고 있는 동안 호버와 구별되지 않는다).
		#
		# 방향은 이 프로젝트 테마의 관례를 따른다 — `Button` 은
		# normal(0.102) → hover(0.141) → pressed(0.055) 로 **호버에서 밝아졌다가 누르면
		# 어두워진다.** 그래서 여기서도 어둡게 간다(호버와 **반대 축**).
		# 테두리는 normal 값으로 되돌린다 → 호버와 **두 축**이 달라져 헷갈리지 않는다.
		# (선택 상태는 `lightened(0.18)` + 금색 테두리 3px 라 겹치지 않는다.)
		var pressed_style := _tile_style(bg_color.darkened(0.28), border_color, 2)
		var selected_style := _tile_style(bg_color.lightened(0.18), Palette.TX_GOLD, 3)

		var btn_tile = Button.new()
		btn_tile.name = "TileButton"
		btn_tile.text = char_str
		btn_tile.add_theme_stylebox_override("normal", selected_style if is_selected else style)
		btn_tile.add_theme_stylebox_override("hover", hover_style)
		btn_tile.add_theme_stylebox_override("pressed", pressed_style)
		# 기본 포커스 링이 테두리처럼 겹쳐 보이던 것도 제거한다.
		btn_tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var rarity_name = "일반"
		if rarity == "super_rare": rarity_name = "초희귀 (4변환 만능)"
		elif rarity == "rare": rarity_name = "희귀 (2변환)"

		var grade_note := _grade_label(_tile_grade(slot_index, tile_pos))
		# ⚠️ `90도 회전` 이라고 적지 마라 — 2순환 타일(`ㄱ`·`ㄴ`·`ㅡ`·`ㅣ`)은 한 번이 **180도**다.
		# 각도는 타일마다 다르므로 문구에 넣으면 절반에서 거짓이 된다(자세한 이유는 회전 배지
		# 툴팁 옆 주석에). `TooltipTruthProbe` §1c 가 이 계약을 지킨다.
		btn_tile.tooltip_text = "[%s 타일: %s]\n클릭=선택/교체, 드래그=순서 이동%s%s" % [
			rarity_name, char_str,
			", 우하단 배지=회전" if is_rotatable else "",
			"" if grade_note == "" else "\n채점: " + grade_note
		]
		btn_tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn_tile.add_theme_font_size_override("font_size", 24)
		# 반드시 PASS 여야 한다. STOP 으로 바꾸면 엔진이 드래그 소스로
		# 이 버튼만 보고(부모로 올라가지 않음) JamoTileBox._get_drag_data 가
		# 호출되지 않아 **타일 드래그&드롭이 통째로 죽는다**.
		# (tests/test_belt_drag_drop.gd 가 이 회귀를 잡는다)
		btn_tile.mouse_filter = Control.MOUSE_FILTER_PASS

		btn_tile.modulate = (
			Palette.HP_DANGER if removal_mode
			else Palette.WAVE if swap_mode
			else Palette.TX_GOLD if ability_mode
			else Color.WHITE
		)

		# pressed(놓을 때) 대신 button_down(누를 때) 로 처리한다.
		# 엔진의 드래그 판정(10px)이 먼저 걸리면 pressed 자체가 오지 않아
		# 클릭이 통째로 취소됐다 → 누르는 즉시 선택되게 한다.
		btn_tile.button_down.connect(_on_tile_clicked.bind(idx))
		tile_box.add_child(btn_tile)

		if is_rotatable:
			# 회전 배지가 보이지 않던 원인: overlay(Control)의 크기가 0 이라
			# PRESET_BOTTOM_RIGHT 가 타일 밖으로 앵커됐다. FULL_RECT 로 고정한다.
			var overlay = Control.new()
			overlay.name = "RotationOverlay"
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile_box.add_child(overlay)
			overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			var badge := Panel.new()
			badge.name = "RotateBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# z_index 를 **쓰지 않는다.** ModalLayer 는 CanvasLayer 가 아니라 그냥 Control
			# 이라 z_index 가 트리 전체에서 하나의 순서로 비교된다 — 여기서 10 을 잡으면
			# 배지가 자기 타일이 아니라 **모달 위에** 그려진다. 실제로 런 요약 패널 위에
			# ↻ 가 찍혀 '2위' 글자를 가렸다(디렉터 보고: "회전 아이콘이 위로 보인다").
			# 타일 위에 있어야 하는 것은 형제 순서로 충분하다 — 이 overlay 는 btn_tile
			# 뒤에 붙으므로 이미 타일 글자보다 위에 그려진다.
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = Palette.BG_VOID_96
			badge_style.border_color = Palette.TX_GOLD
			badge_style.set_border_width_all(1)
			badge_style.set_corner_radius_all(8)
			badge.add_theme_stylebox_override("panel", badge_style)
			overlay.add_child(badge)
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			# 배지/버튼이 타일 가운데를 덮어 클릭이 잘 안 먹혔다 → 진짜 모서리로 밀어 넣는다.
			badge.offset_left = -22.0
			badge.offset_top = -22.0
			badge.offset_right = -5.0
			badge.offset_bottom = -5.0

			var rot_icon := TextureRect.new()
			rot_icon.name = "RotateIcon"
			rot_icon.texture = load("res://assets/map_ui/ui_rotate_icon_32px_pastel.png")
			rot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(rot_icon)
			rot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			# 실제 클릭 영역은 배지보다 살짝 큰 투명 버튼.
			# 34px 는 64x62 타일의 28% 를 먹어 선택을 방해했다 → 26px 로 줄이고 모서리에 붙인다.
			var btn_rot = Button.new()
			btn_rot.name = "RotateButton"
			btn_rot.flat = true
			btn_rot.text = ""
			# ⚠️ 예시는 **한 번 누른 결과**여야 한다(안내 문구가 계약이다). 예전에는 `ㅏ → ㅗ`
			# 라고 적었는데, `HangulEngine.ROTATABLE_TILES` 는 `"ㅏ": "ㅜ"` 다 — `ㅗ` 는
			# 세 번 눌러야 나온다(ㅏ→ㅜ→ㅓ→ㅗ). 즉 예시가 90도가 아니라 **180도**였다.
			# 플레이어는 이 문구가 게임 안 유일한 조작 설명이라 잘못 배우면 고칠 데가 없다.
			# (`ㄱ → ㄴ` 은 2순환이라 한 번이 맞다. 등급 라벨 `4변환`/`2변환` 도 맵과 일치한다
			#  — 그러므로 **맵이 맞고 예시가 틀렸다.** tools/TooltipTruthProbe.gd §1 이 지킨다.)
			#
			# 2026-09-24 — **각도 주장("90도")을 뺐다.** 순환 길이가 타일마다 달라서 어떤 한
			# 각도도 전부에 맞지 않는다: `ㅏ→ㅜ`(4순환)는 한 번이 90도지만 `ㄱ↔ㄴ`(2순환)은
			# **180도**다. "90도 회전" 이라고 적으면 희귀 타일(`ㄱ`·`ㄴ`·`ㅡ`·`ㅣ`)에서 **거짓**이
			# 된다. 예시가 이미 "한 번에 무엇이 되는가" 를 보여 주므로 각도는 정보를 더하지도
			# 않는다. 같은 이유로 타일 툴팁의 `↻=90도 회전` 도 `↻=회전` 으로 바꿨다.
			# (`TooltipTruthProbe` §1c 가 지킨다 — 문구에 각도가 있으면 **모든** 회전 타일이
			#  실제로 그 각도여야 한다.)
			btn_rot.tooltip_text = "회전 (예: ㅏ ▸ ㅜ, ㄱ ▸ ㄴ)"
			btn_rot.custom_minimum_size = Vector2(26, 26)
			overlay.add_child(btn_rot)
			btn_rot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			btn_rot.offset_left = -26.0
			btn_rot.offset_top = -26.0
			btn_rot.offset_right = 0.0
			btn_rot.offset_bottom = 0.0
			btn_rot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			btn_rot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
			# ⚠️ 여기는 `pressed` 도 비어 있는 것이 **의도다** — 타일(`TileButton`)과 달리
			# 고치지 않는다. 이유 둘: (1) 회전은 **누르는 즉시 글자가 바뀌어** 결과 자체가
			# 피드백이다(타일은 선택이 화면에서 즉시 확정되지 않아 눌림 표현이 필요했다).
			# (2) 이 26x26 은 **투명 클릭 영역**이고 타일 면적의 17% 를 먹는다 — 눌림 상자를
			# 그리면 타일 모서리에 상자가 뜬다. 배지를 줄인 이유와 정면으로 충돌한다.
			btn_rot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
			# STOP 이면 이 26x26(타일 면적의 17%)이 **드래그 사각지대**가 된다.
			# 실측: 배지 위에서 드래그를 시작하면 타일이 꿈쩍도 안 했다.
			# PASS 로 두면 엔진이 부모로 올라가 JamoTileBox 를 드래그 소스로 잡는다
			# (btn_tile 이 PASS 인 것과 같은 이유). 클릭은 그대로 회전이다.
			btn_rot.mouse_filter = Control.MOUSE_FILTER_PASS
			btn_rot.pressed.connect(func():
				jamo_list[idx] = HangulEngine.rotate(jamo_list[idx])
				SoundEngine.play_tile_rotate()
				render_belt()
			)

		return tile_box
	return null

func _on_tile_clicked(idx: int) -> void:
	if removal_mode:
		tile_removal_requested.emit(idx)
		return
	if swap_mode:
		tile_swap_requested.emit(idx)
		return
	if ability_mode:
		tile_ability_requested.emit(idx)
		return
	if selected_index_for_swap == -1:
		selected_index_for_swap = idx
		SoundEngine.play_tile_click()
		_refresh_tile_selection()
	elif selected_index_for_swap == idx:
		selected_index_for_swap = -1
		_refresh_tile_selection()
	else:
		var tmp = jamo_list[selected_index_for_swap]
		jamo_list[selected_index_for_swap] = jamo_list[idx]
		jamo_list[idx] = tmp
		selected_index_for_swap = -1
		SoundEngine.play_tile_click()
		render_belt()

## 선택 표시만 다시 칠한다. 트리를 재생성하지 않는다.
##
## render_belt() 로 타일을 다시 만들면 '누르고 있던 버튼'이 트리에서 빠지면서
## 엔진의 드래그가 시작되지 않는다. 그래서 선택만 바뀔 때는 스타일만 갱신한다.
func _refresh_tile_selection() -> void:
	if not is_inside_tree():
		return
	for tile in _tile_boxes(tiles_container):
		if not is_instance_valid(tile) or tile.get_child_count() == 0:
			continue
		var btn := tile.get_child(0) as Button
		if btn == null:
			continue
		var colors := _tile_colors(tile)
		var bg: Color = colors[0]
		var border: Color = colors[1]
		var selected: bool = (tile.tile_index == selected_index_for_swap) and not removal_mode and not swap_mode
		btn.add_theme_stylebox_override("normal",
			_tile_style(bg.lightened(0.18), Palette.TX_GOLD, 3) if selected
			else _tile_style(bg, border, 2))
