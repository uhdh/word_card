# TowerDefenseMain.gd
# 한글 자모 결합 타워 디펜스 메인 컨트롤러 (막당 20라운드 구성)
extends Control

const SaveManager = preload("res://scripts/core/SaveManager.gd")
const Palette = preload("res://scripts/ui/Palette.gd")
const Juice = preload("res://scripts/ui/Juice.gd")
const NumText = preload("res://scripts/ui/NumText.gd")
## 동시 생존 적이 안전밸브의 이 비율에 닿으면 상단 카운터가 경고로 바뀐다.
## 1.0(밸브 자체)로 두면 경고를 보고 손쓸 시간이 없다 — 런이 그 자리에서 끝난다.
const ENEMY_OVERLOAD_WARN_RATIO := 0.8
const WAVE_REWARD_SCENE = preload("res://scenes/tower/WaveRewardModal.tscn")

## 결산 화면의 **타워별 순위 표**가 차지할 수 있는 최대 높이(px) — §2.34.
##
## ⚠️ 왜 상수가 필요한가: `Control` 에는 `max_size` 가 **없다.** `custom_minimum_size` 는
##    **하한**이라 상한처럼 쓰면 내용이 짧을 때도 그만큼 빈 칸이 생긴다(타워 0개인 결산이
##    480 → 560 이 된다). 그래서 그릇의 높이를 `min(내용, 상한)` 으로 **재서** 정한다.
## ⚠️ 값의 근거(실측 2026-10-06 · `tools/ModalFitProbe` S1b): 결산 모달에서 **표를 뺀**
##    고정 높이가 약 464px, 화면이 720px 이므로 표에 줄 수 있는 최대는 약 256px 다.
##    여유를 두고 220 으로 잡았다 — 12줄(192px)까지는 예전과 **똑같이** 보이고, 그 위만 묶인다.
##    ⚠️ 이 값을 키우면 결산 모달이 다시 화면 밖으로 나간다(`ModalFitProbe` S1b 가 잡는다).
const RANK_LIST_MAX_HEIGHT := 220.0

@onready var monster_count_label: Label = $TopBar/VBoxTop/Row/Info/EnemyBox/EnemyLabel
@onready var gold_label: Label = $TopBar/VBoxTop/Row/Info/GoldBox/GoldLabel
@onready var wave_label: Label = $TopBar/VBoxTop/Row/Info/WaveBox/WaveLabel
@onready var btn_stage: Button = $TopBar/VBoxTop/Row/Info/WaveBox/BtnStage

# 신규: 기지 HP 표시 + 예고 바
@onready var base_hp_label: Label = $TopBar/VBoxTop/Row/Info/HpBox/HpLabel
@onready var base_hp_bar: ProgressBar = $TopBar/VBoxTop/Row/Info/HpBox/BaseHpBar
# 예고 바가 **카운트다운과 다음 라운드 예고를 둘 다 소유한다** (§5.2 21).
# ⚠️ 상단 바에 있던 `SpawnTimerLabel`(`다음 젠: N초`)과 `NextRoundLabel`(숨김)은 제거했다 —
#    전자는 이 타이머와 **네 상태가 완전히 동일한 중복**이었고(같은 값, 다른 문구),
#    후자는 씬에서 `visible=false` 인데 코드가 계속 갱신하던 **죽은 표시**였다.
#    되살리지 말 것: 같은 숫자가 두 문구로 보이면 플레이어는 서로 다른 타이머로 읽는다.
#    (`tools/CountdownDedupProbe.tscn` 이 보이는 라벨을 세어 지킨다)
@onready var telegraph_label: Label = $VBox/TelegraphBar/Row/TelegraphLabel
@onready var telegraph_timer: Label = $VBox/TelegraphBar/Row/TelegraphTimer

@onready var btn_reset: Button = $TopBar/VBoxTop/Row/Actions/BtnReset
@onready var btn_save: Button = $TopBar/VBoxTop/Row/Actions/BtnSave
@onready var btn_load: Button = $TopBar/VBoxTop/Row/Actions/BtnLoad
@onready var btn_speed: Button = $TopBar/VBoxTop/Row/Actions/BtnSpeed
@onready var btn_lexicon: Button = $TopBar/VBoxTop/Row/Actions/BtnLexicon
@onready var btn_relic_shop: Button = $TopBar/VBoxTop/MonsterColumn/BtnRelicShop
@onready var btn_ability: Button = get_node_or_null("TopBar/VBoxTop/MonsterColumn/BtnAbility")
@onready var btn_lore: Button = $TopBar/VBoxTop/Row/Actions/BtnLore
@onready var btn_mute: Button = $TopBar/VBoxTop/Row/Actions/BtnMute
@onready var btn_settings: MenuButton = $TopBar/VBoxTop/Row/Actions/BtnSettings

@onready var defense_field: DefenseField = $VBox/FieldContainer/DefenseField
@onready var jamo_belt: JamoBelt = $VBox/JamoBelt
@onready var relic_items: HBoxContainer = get_node_or_null("TopBar/VBoxTop/MonsterColumn/RelicBar/Scroll/Items")
## 모달이 사는 레이어. **게임 트리 전체보다 위**여야 한다.
##
## ModalLayer 는 CanvasLayer 가 아니라 그냥 Control 이라, z_index 가 트리 전체에서 하나의
## 순서로 비교된다. 그래서 필드가 일시적 효과에 z_index 를 크게 주면 모달 **위로** 올라온다.
## 실제로 런 요약은 자기 z_index 를 잡지 않아 0 이었고, 그 위에 필드의 골드 라벨(100)과
## 골드 조각 6개(99)가 찍혀 요약을 덮었다(디렉터 보고: "결과 화면이 꽉차서 안보이고,
## 회전 아이콘이 위로 보인다").
##
## z 는 .tscn 에서 200 이다. 지금 게임 트리에서 가장 높은 값은 벨트·필드의 배너 120 이라
## 200 이면 충분히 위다. 이 천장은 `tests/test_tower_traits.gd` 의
## `_test_the_modal_layer_stays_above_everything_else` 가 지킨다 — 게임 트리의 어떤 노드도
## 여기에 닿으면 테스트가 실패한다. 모달 z 를 낮추거나 필드에 200 이상을 주면 거기서 걸린다.
@onready var modal_layer: Control = $ModalLayer

var current_speed_scale: float = 1.0
## 일시정지에서 재개할 때 돌아갈 배속. 멈추기 직전 값을 기억한다 —
## 1x 로 고정하면 4x 로 보던 플레이어가 매번 다시 4x 를 눌러야 한다.
var _speed_before_pause: float = 1.0
## 밀어내기(능력) 잔여 횟수. 웨이브가 시작될 때 충전된다.
const ABILITY_USES_PER_WAVE: int = 1
var ability_uses_left: int = ABILITY_USES_PER_WAVE
var reroll_dice: int = 3
var owned_relics: Array = []
## 이번 런을 역대 기록에 이미 넣었는가.
##
## `game_over` 는 한 번만 오지 않는다 — 기지 HP 가 0 이 되면 그 뒤로 기지에 닿는 적마다
## `_on_enemy_reached_base` 가 `maxi(0, 0 - dmg) == 0` 을 다시 보고 신호를 또 쏜다.
## 그대로 두면 결과 모달이 겹겹이 쌓이고, 랭킹에는 같은 런이 여러 번 들어간다.
var _run_recorded := false
var _is_loading_state: bool = true
var shop_modal: Control
## 떠 있는 막 클리어 모달. **다음 막 시작의 주인**이다 — 이 참조가 살아 있는 동안
## Space 는 웨이브를 시작하지 않고 이 모달을 닫는다. 그래야
## 시작이 한 곳에서만 일어나고, 모달의 약속("닫으면 시작됩니다")이 참이 된다.
##
## `_is_terminal_modal_open()` 을 쓰지 않는 이유: 그 함수는 이름과 달리
## `modal_layer.get_child_count() > 0` 이라 상점·보상 드래프트까지 전부 참으로 돌려준다.
var _act_clear_modal: ActClearModal = null
## 기지 침입 바가 따라갈 목표값. 실제 value 갱신은 _process 가 담당한다.
var _base_bar_target: float = 0.0
## 상단 바 골드 표시가 **굴러 올라가는** 값(§5.2 22). `-1` 은 '아직 한 번도 못 받았다'.
##
## ⚠️ 이 값은 **표시 전용**이다. 실제 골드는 `defense_field.gold` 이고, 구매 가능 여부를
##    판단하는 `jamo_belt.set_gold()` 는 언제나 **진짜 값**을 즉시 받는다. 굴러가는 수를
##    경제 판단에 쓰면 "왜 못 사는지 모르는" 상태가 생긴다.
var _gold_shown: float = -1.0
var _gold_target: int = 0
## 골드 카운트업이 목표에 닿는 속도. 16 이면 약 0.25초에 95% 도달한다(§5.2 22 의 제안값).
## 체력 바와 **같은 곡선**을 쓴다 — 화면 안에 두 개의 '시간' 이 있으면 안 된다.
const GOLD_COUNT_RATE: float = 16.0
## 런이 끝난 뒤 결과 패널이 **등장하기까지의 여운**(§2.8). 실시간 초이며
## `Engine.time_scale` 을 따르지 않는다 — 왜인지는 `_show_modal()` 의 `delay` 주석에 있다.
## 0.4 라는 숫자 자체는 감독 판단이다(이 상수 하나만 바꾸면 조절된다).
const GAME_OVER_HOLD_SEC: float = 0.4
## 저체력 맥동 트윈의 핸들. **반드시 보관해야 한다.**
## `set_loops()` 트윈은 `kill()` 하기 전까지 영원히 돌기 때문에, 핸들을 놓아버리면 위험
## 구간을 벗어난 뒤에도(회복의 향로 · 철옹성 룬 · 불러오기) 계속 `modulate` 를 덮어쓴다.
## 게다가 트윈을 놓아버리면 재진입 때마다 하나씩 쌓여 서로 다른 위상으로 같은 속성을 민다.
var _low_hp_tween: Tween = null

func _ready() -> void:
	_is_loading_state = true
	move_child($TopBar, $VBox.get_index())

	if btn_stage: btn_stage.pressed.connect(_on_stage_btn_pressed)
	var scroll = get_node_or_null("TopBar/VBoxTop/MonsterColumn/RelicBar/Scroll") as ScrollContainer
	if scroll:
		var h_bar = scroll.get_h_scroll_bar()
		if h_bar:
			h_bar.visible = false
			h_bar.custom_minimum_size = Vector2.ZERO
			h_bar.modulate.a = 0.0
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_lexicon.pressed.connect(_on_lexicon_pressed)
	btn_relic_shop.pressed.connect(_open_relic_shop)
	# ⚠️ 예전 주석은 *"AutoPlayTDTest 등 파생 씬은 BtnAbility 가 없다"* 고 적었는데 **거짓이었다**
	# (2026-10-06 실측 — 파생 씬에도 이 노드가 **있다**). 그 거짓이 *"봇 씬은 확인할 필요 없다"* 는
	# 판단을 만들어 **§2.40**(입구가 없어 능력을 런 내내 쓸 수 없었다)을 숨겼다.
	# 가드는 그래도 남긴다 — 손으로 만든 축소 씬이 들어와도 죽지 않게.
	if btn_ability:
		btn_ability.pressed.connect(_on_ability_pressed)
	btn_lore.pressed.connect(_on_lore_pressed)
	btn_mute.pressed.connect(_on_mute_pressed)
	var settings_menu := btn_settings.get_popup()
	settings_menu.id_pressed.connect(_on_settings_item_pressed)
	btn_load.disabled = not SaveManager.has_save_file()
	_update_settings_menu()

	if defense_field:
		defense_field.gold = 40
		defense_field.enemy_count_changed.connect(_on_enemy_count_changed)
		defense_field.gold_changed.connect(_on_gold_changed)
		defense_field.base_hp_changed.connect(_on_base_hp_changed)
		defense_field.wave_status_changed.connect(_on_wave_status_changed)
		defense_field.wave_cleared.connect(_on_wave_cleared)
		defense_field.act_cleared.connect(_on_act_cleared)
		defense_field.tower_info_requested.connect(_on_tower_info_requested)
		defense_field.game_over.connect(_on_game_over)
		defense_field.tower_positions_changed.connect(save_game_state)

	if jamo_belt:
		jamo_belt.parsed_towers_updated.connect(_on_parsed_towers_updated)
		jamo_belt.jamo_changed.connect(_on_jamo_changed)
		jamo_belt.tile_purchase_requested.connect(_on_tile_purchase_requested)
		jamo_belt.tile_removal_requested.connect(_on_tile_removal_requested)
		jamo_belt.tile_swap_requested.connect(_on_tile_swap_requested)
		jamo_belt.tile_ability_requested.connect(_on_tile_ability_requested)
		jamo_belt.strategy_recommendations_requested.connect(_on_strategy_recommendations_requested)
		jamo_belt.set_gold(defense_field.gold)
	_render_relic_bar()

	# ── 상단 바 툴팁의 **유일한 작성자** ────────────────────────────────────
	# ⚠️ 이 다섯 줄이 상단 바 툴팁을 쓰는 **유일한 곳**이다. 씬(`TowerDefenseMain.tscn` ·
	# `AutoPlayTDTest.tscn`)에 같은 툴팁을 다시 적지 마라 — 씬 값은 인스턴스화 시점에
	# 들어오지만 `_ready()` 가 여기서 덮어쓰므로 **아무에게도 보이지 않는다.**
	# 2026-09-24 실측(`tools/TooltipAuthorProbe.gd`): 다섯 버튼(BtnSave·BtnLoad·BtnSpeed·
	# BtnLexicon·BtnMute)의 씬 문구가 버려지고 있었다 — 씬에 적힌
	# `"현재 진행 상황을 저장합니다 [Ctrl+S]"` 같은 설명이 플레이어에게 도달하지 않았고,
	# 씬을 고쳐도 아무 일이 없었다. 그래서 씬 쪽 사본을 지웠다(작성자 하나).
	# 씬이 유일 작성자인 버튼도 있다(BtnReset·BtnLore·BtnSettings·BtnRelicShop·BtnAbility) —
	# 그쪽은 여기서 건드리지 않는다. **한 채널에 한 작성자**가 규칙이다.
	# ⚠️ 그리고 이 문구들은 `AutoPlayTDTest.tscn` 에도 같이 적용된다(루트 스크립트가 같다) —
	# 그래서 두 씬의 툴팁이 어긋날 수 없다.
	#
	# ⚠️ 2026-09-24 — **단축키만 말하지 마라.** §2.17 에서 씬의 중복 사본을 지웠더니 그 사본이
	# 갖고 있던 *기능 설명* 까지 함께 사라졌다. `BtnMute` 는 `단축키: [M]` 만 말해서
	# **"소리를 끄는 버튼" 이라는 말이 어디에도 없었다**(버튼이 아이콘이라 더 나빴다).
	# 지금은 다섯 전부 `무엇을 하는 버튼인가 — 단축키` 형태다. 버려진 옛 문구는 감사 §2.17 표에
	# 남아 있다. `tools/TooltipAuthorProbe.gd` §1c 가 "상단 바 툴팁은 단축키만 말하지 않는다" 를 지킨다.
	# ⚠️ 2026-10-06 — 여섯째였던 `BtnStartWave` 의 대입을 **지웠다**(§2.27). 그 버튼은 씬에서
	# `visible = false` 이고 코드에 `.show()` 가 0건이라 **영영 안 보였는데**, 그 툴팁이 `[SPACE]`
	# 안내의 **유일한 운반체**였다 — 아무도 못 읽는 문장을 여기서 관리하고 있었다.
	# 노드와 대입을 함께 지우고, 안내는 **실제로 쓸 수 있는 순간**(막 클리어 모달)으로 옮겼다.
	btn_save.tooltip_text = "현재 진행 상황을 저장합니다 — 단축키: [Ctrl + S] 또는 [S]"
	btn_load.tooltip_text = "저장된 게임을 불러옵니다 — 단축키: [L]"
	# ⚠️ 배속은 **3단(1x·2x·4x)** 이다. `[3]` 은 `[4]` 와 **같은 일을 한다**(둘 다 4x —
	# `_unhandled_input` 의 `KEY_3, KEY_4:`). 목록에 넷을 나열하면 "속도가 네 단계" 라는 잘못된
	# 인상을 준다 — 키 자체는 살려 두되(익숙한 사람이 계속 쓸 수 있게) **목록에서 뺐다.**
	# 3배속을 실제로 추가할지는 감독 결정이다(감사 §2.15).
	btn_speed.tooltip_text = "게임 속도를 조절합니다 — 단축키: [1] / [2] / [4] / [P] 일시정지"
	btn_lexicon.tooltip_text = "지금까지 발견한 단어 도감을 엽니다 — 단축키: [TAB] 또는 [D]"
	btn_mute.tooltip_text = "소리를 켜고 끕니다 — 단축키: [M]"

	if SaveManager.has_save_file():
		_on_load_pressed()
	else:
		if jamo_belt.jamo_list.is_empty():
			jamo_belt.jamo_list = JamoBelt.generate_starting_jamo()
		jamo_belt.render_belt()
		_update_topbar_wave_label(1, 0)
		# 첫 실행 시에는 서사 팝업을 강제로 띄우지 않고, 선택 가능한 온보딩 코치마크를 띄운다.
		call_deferred("_show_first_run_coachmark")

	_is_loading_state = false
	_update_next_round_preview()
	call_deferred("_start_wave_automatically")

## 첫 실행 온보딩 — 3단계 핵심 개념을 순서대로 안내한다.
## (서사 전문은 '세계관' 버튼으로 언제든 열람 가능)
func _show_first_run_coachmark() -> void:
	if SaveManager.has_save_file():
		return
	var steps := [
		{
			"title": "1 / 3  ·  활자를 모으세요",
			"body": "벨트의 [자음 구매] / [모음 구매]로 활자를 얻어\n아래 3개 슬롯 중 한 곳에 끌어다 놓습니다.",
			"anchor": jamo_belt,
		},
		{
			"title": "2 / 3  ·  단어가 곧 타워",
			"body": "슬롯에 활자를 조합하면 단어가 완성되고,\n그 단어가 그대로 공격 타워로 세워집니다.\n타워를 끌어 다른 발판으로 옮길 수 있습니다.",
			"anchor": defense_field,
		},
		{
			"title": "3 / 3  ·  기지를 지키세요",
			"body": "적이 길을 따라 기지에 닿으면 HP가 줄어듭니다.\n웨이브를 막아내고 5라운드마다 오는 보스를 잡으세요.",
			"anchor": base_hp_label,
		},
	]
	_run_coachmark(steps, 0)

func _run_coachmark(steps: Array, index: int) -> void:
	if index >= steps.size():
		_toast("언제든 상단 [세계관] 버튼에서 이야기를 다시 볼 수 있습니다")
		return
	var step: Dictionary = steps[index]
	var modal := PanelContainer.new()
	modal.theme_type_variation = "ModalPanel"
	modal.custom_minimum_size = Vector2(440, 0)
	modal.z_index = 60

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	modal.add_child(vb)

	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = str(step["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var body := Label.new()
	body.theme_type_variation = "MutedLabel"
	body.text = str(step["body"])
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)

	var btn_skip := Button.new()
	btn_skip.theme_type_variation = "GhostButton"
	btn_skip.text = "건너뛰기"
	btn_skip.pressed.connect(func():
		modal.queue_free()
		SoundEngine.play_tile_click()
	)
	row.add_child(btn_skip)

	var btn_next := Button.new()
	btn_next.theme_type_variation = "PrimaryButton"
	btn_next.text = "다음" if index < steps.size() - 1 else "시작하기"
	btn_next.custom_minimum_size = Vector2(120, 40)
	btn_next.pressed.connect(func():
		modal.queue_free()
		SoundEngine.play_tile_click()
		_run_coachmark(steps, index + 1)
	)
	row.add_child(btn_next)

	# 안내 대상 위치 근처에 띄운다 (없으면 중앙)
	modal_layer.add_child(modal)
	var anchor: Control = step.get("anchor")
	var centered := true
	if anchor != null and is_instance_valid(anchor):
		var anchor_pos := anchor.get_global_rect().position
		modal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		modal.position = Vector2(
			clampf(anchor_pos.x + 20.0, 20.0, size.x - 480.0),
			clampf(anchor_pos.y - 20.0, 70.0, size.y - 220.0)
		)
		centered = false
	_show_modal(modal, centered)

func _on_stage_btn_pressed() -> void:
	if not defense_field: return
	var info_text = defense_field.next_round_preview()
	var modal_data = _make_choice_modal("라운드 정보 · 다음 적 예고")
	# ⚠️ **긴 글은 `row`(버튼 줄)가 아니라 `box`(VBox)에 넣는다 — 2026-10-05 실측.**
	#    `row` 는 `HBoxContainer` 이고 `_make_choice_modal` 의 다른 호출부는 전부 **버튼만**
	#    넣는다. 긴 글을 거기 넣으면 세로로 쌓이지 않고 **가로로 나란히** 서고, 게다가
	#    줄바꿈이 없으니 `Label` 의 최소 폭 = 글자 폭 → `PanelContainer` 의 최소 폭이
	#    **상한 없이** 자란다(`custom_minimum_size(760)` 은 더 큰 최소 크기에 진다).
	#    실측(`tools/StageDescFitProbe`): 도달 가능한 **27/27 상태가 화면 밖** — 최악 2막 10R
	#    패널 **2724 px**(화면 1280 · x=270)이라 **오른쪽 +1714 px 가 잘렸다.** 본문이
	#    가운데 정렬이라 시작점만 보이고 끝을 못 봤다(감독 보고 "스테이지 설명 짤림").
	#    ⚠️ §2.13-2 가 *"정보 손실 0"* 이라며 전체 문구를 넘겨 둔 **바로 그 표면**이다 —
	#    바(1104 px)만 고치고 **목적지 둘의 폭은 아무도 안 쟀다.**
	var box: Container = modal_data.row.get_parent()
	var insert_at := 1        # 제목(0) 바로 아래 · 버튼 줄과 닫기 버튼 위
	var label = Label.new()
	label.text = "%s\n\n제 %d막 [%s] (총 %d라운드)\n5라운드마다 보스 등장 · 처치 시 대보상" % [
		info_text,
		defense_field.current_act,
		DefenseField.ACT_NAMES.get(defense_field.current_act, "미지의 영역"),
		defense_field.MAX_WAVES_PER_ACT
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 줄바꿈이 없으면 이 라벨의 최소 폭이 곧 글자 폭이라 패널이 그만큼 자란다.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	box.add_child(label)
	box.move_child(label, insert_at)
	insert_at += 1

	# §5.2 31 (B) — 속성 설명. 모달은 **멈춰 있는 표면**이라 여기가 읽을 자리다.
	# ⚠️ 문구는 상단 툴팁과 **같은 함수**가 만든다(`next_round_attr_desc()`) — 손으로 두 번
	#    적으면 §2.18 의 드리프트가 그대로 재발한다.
	# ⚠️ 본문 라벨과 **분리한다** — 본문은 16px 금색 가운데 정렬이고, 설명은 왼쪽 정렬 본문이다.
	var desc: String = defense_field.next_round_attr_desc()
	if desc != "":
		var desc_title := Label.new()
		desc_title.text = "속성 설명"
		desc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_title.add_theme_font_size_override("font_size", 13)
		desc_title.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92))
		box.add_child(desc_title)
		box.move_child(desc_title, insert_at)
		insert_at += 1
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
		# 위 본문과 **같은 이유**로 줄바꿈 — 이것만 없어도 이 라벨 혼자 패널을 화면 밖으로 민다.
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc_label)
		box.move_child(desc_label, insert_at)

func _start_wave_automatically() -> void:
	if defense_field and not defense_field.is_wave_running:
		_on_start_wave_pressed()

func _render_relic_bar() -> void:
	if not relic_items: return
	for child in relic_items.get_children(): child.queue_free()
	var title = Label.new()
	title.text = "보유 유물 : " if owned_relics.size() > 0 else "보유 유물 : 없음"
	title.add_theme_color_override("font_color", Color("f5d98b"))
	title.add_theme_font_size_override("font_size", 11)
	relic_items.add_child(title)
	for relic in owned_relics:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = "%s\n%s" % [relic.get("name", ""), relic.get("desc", "")]
		var path = relic.get("icon", "")
		if ResourceLoader.exists(path): icon.texture = load(path)
		relic_items.add_child(icon)

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
		KEY_P:
			toggle_pause()

func _update_topbar_wave_label(act: int, wave: int) -> void:
	var act_name = DefenseField.ACT_NAMES.get(act, "미지의 영역")
	if wave_label:
		wave_label.text = "제 %d막 [%s]" % [act, act_name]
	if btn_stage:
		btn_stage.text = "스테이지 %d / %d" % [wave, defense_field.MAX_WAVES_PER_ACT]

func _on_save_pressed() -> void:
	save_game_state()
	_update_settings_menu()
	btn_save.text = "✅ 저장됨!"
	# 저장은 **UI 동작**이다 — 게임 세계에서 좋은 일이 일어난 것이 아니다.
	# 2026-09-26 까지 여기는 `play_buff()`(=`play_heal()`) 였고, 그래서 이 게임에서 유일하게
	# '좋은 일' 을 뜻하는 파형(E5→A5→C6→E6 상행 아르페지오)이 *"저장했습니다"* 에 붙어 있었다(§2.22-4).
	# 버튼을 눌렀다는 사실만 알리면 되므로 UI 클릭음 하나로 충분하다 — 상점 닫기와 같은 소리다.
	SoundEngine.play_tile_click()
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func(): btn_save.text = "💾 저장")

func _on_load_pressed() -> void:
	var data = SaveManager.load_game()
	if data.is_empty():
		return

	_is_loading_state = true

	# 막 클리어 모달은 "다음 막" 의 주인이다. 불러오기는 그 주장을 무효로 만든다 —
	# 다른 막·다른 웨이브로 갈아끼우므로, 남겨 두면 로드된 상태와 어긋난 약속을 걸고
	# 있게 된다. 게다가 그 버튼을 누르면 `start_next_wave()` 가 로드된 웨이브를 **하나
	# 건너뛴다**(current_wave 를 증가시킨 뒤 시작하므로). 참조와 노드를 함께 버린다.
	# 웨이브는 시작하지 않는다 — 로드는 '되돌리기' 지 '다음 막' 이 아니다.
	if is_instance_valid(_act_clear_modal):
		_act_clear_modal.queue_free()
	_act_clear_modal = null

	if data.has("jamo_list"):
		jamo_belt.jamo_list.clear()
		for c in data["jamo_list"]:
			jamo_belt.jamo_list.append(str(c))
		# 고정은 '지금 벨트에 대한 계획' 이라 저장하지 않는다. 예전 세이브의 인덱스가
		# 남아 있으면 엉뚱한 타일을 잠그므로 불러올 때 반드시 비운다.
		jamo_belt.clear_slot_locks()

	if data.has("base_hp"):
		# 세이브는 '남은 HP' 를 저장한다. 최대치가 바뀌면(20 → 50) 그대로 대입할 때
		# 이미 30마리가 뚫린 것처럼 보인다. 그래서 **뚫린 횟수**를 보존해서 옮긴다.
		#   구 세이브: max 20, hp 18 → 뚫린 2  → 신 규격: 50 - 2 = 48
		var saved_max := int(data.get("max_base_hp", DefenseField.MAX_BASE_HP))
		var breached := maxi(0, saved_max - int(data["base_hp"]))
		defense_field.max_base_hp = DefenseField.MAX_BASE_HP
		defense_field.base_hp = maxi(0, DefenseField.MAX_BASE_HP - breached)
		defense_field.base_hp_changed.emit(defense_field.base_hp, defense_field.max_base_hp)

	if data.has("gold"):
		defense_field.gold = int(data["gold"])
		defense_field.gold_changed.emit(defense_field.gold)

	if data.has("current_act"):
		# current_act 를 직접 대입하면 숫자만 바뀌고 지도 텍스처·경로 곡선·발판 배치는
		# 1막 그대로 남는다 (DefenseField._ready 가 1막 기준으로 만들어 둔 상태).
		# 2막 세이브를 불러오면 2막 몬스터가 1막 길로 걸어오는 것이다.
		# set_act 가 그 셋을 모두 다시 만들므로 반드시 이쪽으로 전환해야 한다.
		# (아래 restore_tower_positions 가 저장된 발판을 덮어쓰므로 순서도 맞다)
		defense_field.set_act(int(data["current_act"]))

	if data.has("current_wave"):
		defense_field.current_wave = int(data["current_wave"])
	defense_field.tower_damage = data.get("tower_damage", {}).duplicate()
	# 키가 문자열인 채로 저장되므로 그대로 받으면 된다 (DefenseField.orbit_directions 참고).
	defense_field.orbit_directions = data.get("orbit_directions", {}).duplicate()
	defense_field.target_modes = data.get("target_modes", {}).duplicate()
	defense_field.restore_tower_positions(data.get("tower_positions", []))

	if data.has("unlocked_slots"):
		defense_field.unlocked_slot_count = mini(int(data["unlocked_slots"]), DefenseField.MAX_UNLOCKED_SLOTS)
		defense_field._update_slot_lock_visuals()
	jamo_belt.set_unlocked_slot_count(defense_field.unlocked_slot_count)
	jamo_belt.restore_assignments(data.get("slot_assignments", []))
	# 저장-로드로 타일 시세를 되돌려 되팔이하는 것을 막는다.
	jamo_belt.set_tile_purchase_count(int(data.get("tile_purchase_count", 0)))

	_update_topbar_wave_label(defense_field.current_act, defense_field.current_wave)
	ability_uses_left = ABILITY_USES_PER_WAVE
	_refresh_ability_button()

	if data.has("reroll_dice"):
		reroll_dice = int(data["reroll_dice"])

	if data.has("relics"):
		owned_relics = data["relics"].duplicate()
	defense_field.relic_ids = owned_relics.map(func(r): return r.get("id", ""))
	jamo_belt.set_relics(defense_field.relic_ids)
	_render_relic_bar()

	# 불러오기는 '단어 완성' 도 '승리' 도 아니다 — 되돌려 놓을 뿐이다.
	# 벨트가 통째로 교체되므로 가드가 없으면 세이브에 타워가 있을 때마다
	# "단어 완성" 배너와 소리가 터진다. (예전엔 여기서 승리 팡파레까지 울렸다)
	jamo_belt.begin_restore()
	jamo_belt.render_belt()
	btn_load.disabled = false
	print("📂 Game state successfully restored! (Act: %d, Wave: %d, Gold: %d, Dice: %d, Relics: %d)" % [
		defense_field.current_act, defense_field.current_wave, defense_field.gold, reroll_dice, owned_relics.size()
	])

	_is_loading_state = false
	_update_settings_menu()

func _on_settings_item_pressed(id: int) -> void:
	match id:
		0: _on_reset_pressed()
		1: _on_lexicon_pressed()
		2:
			_on_mute_pressed()
			_update_settings_menu()
		3: _on_save_pressed()
		4: _on_load_pressed()
		5: _on_lore_pressed()
		6: _show_volume_settings()

func _update_settings_menu() -> void:
	if not btn_settings: return
	var popup := btn_settings.get_popup()
	popup.clear()
	popup.add_item("새 게임", 0)
	popup.add_item("연성 비급", 1)
	popup.add_item("소리 켜기" if SoundEngine.muted else "소리 끄기", 2)
	popup.add_separator()
	popup.add_item("저장", 3)
	popup.add_item("이어하기", 4)
	popup.add_item("세계관", 5)
	popup.add_separator()
	popup.add_item("볼륨 설정", 6)
	popup.set_item_disabled(popup.get_item_index(4), not SaveManager.has_save_file())

func _show_volume_settings() -> void:
	var modal := PanelContainer.new()
	modal.theme_type_variation = "ModalPanel"
	modal.custom_minimum_size = Vector2(400, 300)
	modal.z_index = 80
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	modal.add_child(vb)
	
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "볼륨 설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	
	# 마스터 볼륨
	var master_row := HBoxContainer.new()
	master_row.add_theme_constant_override("separation", 10)
	vb.add_child(master_row)
	
	var master_label := Label.new()
	master_label.text = "마스터"
	master_label.custom_minimum_size = Vector2(80, 0)
	master_row.add_child(master_label)
	
	var master_slider := HSlider.new()
	master_slider.min_value = -40.0
	master_slider.max_value = 0.0
	master_slider.value = SoundEngine.master_volume_db
	master_slider.custom_minimum_size = Vector2(200, 30)
	master_slider.value_changed.connect(func(v): SoundEngine.set_master_volume(v))
	master_row.add_child(master_slider)
	
	# 효과음 볼륨
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	vb.add_child(sfx_row)
	
	var sfx_label := Label.new()
	sfx_label.text = "효과음"
	sfx_label.custom_minimum_size = Vector2(80, 0)
	sfx_row.add_child(sfx_label)
	
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -40.0
	sfx_slider.max_value = 0.0
	sfx_slider.value = SoundEngine.sfx_volume_db
	sfx_slider.custom_minimum_size = Vector2(200, 30)
	sfx_slider.value_changed.connect(func(v): SoundEngine.set_sfx_volume(v))
	sfx_row.add_child(sfx_slider)
	
	# UI 볼륨
	var ui_row := HBoxContainer.new()
	ui_row.add_theme_constant_override("separation", 10)
	vb.add_child(ui_row)
	
	var ui_label := Label.new()
	ui_label.text = "UI"
	ui_label.custom_minimum_size = Vector2(80, 0)
	ui_row.add_child(ui_label)
	
	var ui_slider := HSlider.new()
	ui_slider.min_value = -40.0
	ui_slider.max_value = 0.0
	ui_slider.value = SoundEngine.ui_volume_db
	ui_slider.custom_minimum_size = Vector2(200, 30)
	ui_slider.value_changed.connect(func(v): SoundEngine.set_ui_volume(v))
	ui_row.add_child(ui_slider)
	
	var close := Button.new()
	close.theme_type_variation = "PrimaryButton"
	close.text = "닫기"
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(func():
		modal.queue_free()
		SoundEngine.play_tile_click()
	)
	vb.add_child(close)
	
	modal_layer.add_child(modal)
	_show_modal(modal)

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
		owned_relics,
		defense_field.current_act,
		defense_field.unlocked_slot_count,
		jamo_belt.slot_assignments,
		defense_field.tower_damage,
		defense_field.tower_positions,
		defense_field.orbit_directions,
		defense_field.target_modes,
		jamo_belt.tile_purchase_count
	)
	btn_load.disabled = false

## 적이 안전밸브에 가까워지면 **그 사실을 보이게** 한다.
##
## 안전밸브(`DefenseField.MAX_ENEMIES`)는 동시 생존 적이 그 수에 닿는 순간 런을 끝낸다.
## 그런데 화면에는 '적 12' 만 있어서, **기지 HP 가 가득한 채로 갑자기 지는** 이유를 알
## 방법이 없었다. 평소에는 숫자만 두고(소음 금지), 위험 구간에 들어서야 분모와 경고를
## 함께 낸다 — 분모가 보이는 순간 "이 숫자가 어디까지 가면 안 되는지" 가 규칙으로 읽힌다.
func _on_enemy_count_changed(current: int) -> void:
	if monster_count_label == null:
		return
	var cap := DefenseField.MAX_ENEMIES
	if current >= int(ceil(cap * ENEMY_OVERLOAD_WARN_RATIO)):
		monster_count_label.text = "적 %d / %d ⚠" % [current, cap]
		monster_count_label.add_theme_color_override("font_color", Palette.HP_DANGER)
	else:
		monster_count_label.text = "적 %d" % current
		# 씬이 정한 색으로 되돌린다 — 여기서 색을 직접 박으면 테마를 바꿔도 안 따라온다.
		monster_count_label.remove_theme_color_override("font_color")

func _on_base_hp_changed(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maxi(1, maximum))
	# '남은 HP' 가 아니라 '몇 마리가 통과했는가' 를 보여준다. 플레이어에게 의미 있는 건
	# 남은 체력 숫자가 아니라 "지금까지 몇 마리를 흘려보냈는가" 다.
	# 막대는 통과 수에 따라 차오르고, 남은 여유가 줄수록 붉어진다.
	var breached := maxi(0, maximum - current)
	if base_hp_label:
		base_hp_label.text = "침입 %d / %d" % [breached, maximum]
		base_hp_label.add_theme_color_override("font_color", Palette.hp_color(ratio))
	if base_hp_bar:
		base_hp_bar.max_value = float(maxi(1, maximum))
		# 값은 _process 의 Juice.approach 가 따라가게 한다. 즉시 대입하면
		# 적이 여러 마리 연달아 새어 나갈 때 바가 계단처럼 튄다.
		_base_bar_target = float(breached)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Palette.hp_color(ratio)
		fill.set_corner_radius_all(3)
		base_hp_bar.add_theme_stylebox_override("fill", fill)
	# 위험 임계(남은 여유 30% 이하)에서는 기지 표시가 맥동하도록 경고
	_update_low_hp_warning(ratio)

## 기지가 위험 수준이면 지속적인 맥동으로 시선을 끌어 위기감을 전달한다.
##
## ⚠️ 위험 구간을 **나가는** 쪽이 이 함수의 본체다. 예전에는 메타만 지우고 트윈을 놓아버려서
## `set_loops()` 트윈이 계속 `modulate` 를 덮어썼다 — 체력이 회복됐는데도 맥동했고, 재진입마다
## 트윈이 쌓였다. 위험 구간을 나가는 경로가 실재하므로(회복의 향로 · 철옹성 룬 · 불러오기)
## 이론이 아니라 실제 버그였다. `tools/LowHpWarningProbe.gd` 가 양방향으로 잰다.
func _update_low_hp_warning(ratio: float) -> void:
	var hp_box := base_hp_label.get_parent() if base_hp_label else null
	if hp_box == null:
		return
	if ratio <= 0.3 and ratio > 0.0:
		if _low_hp_tween != null and _low_hp_tween.is_valid():
			return
		_low_hp_tween = hp_box.create_tween().set_loops()
		_low_hp_tween.tween_property(hp_box, "modulate", Color(1.35, 0.75, 0.75), 0.5).set_trans(Tween.TRANS_SINE)
		_low_hp_tween.tween_property(hp_box, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		# 트윈을 **죽인다.** 색 복원만으로는 부족하다 — 살아 있는 `set_loops()` 트윈이
		# 다음 프레임에 `modulate` 를 다시 덮어쓰기 때문이다. (죽이기와 색 복원은 같은
		# 호출 안에서 일어나므로 **둘 사이의 순서는 결과를 바꾸지 않는다** — 프레임이
		# 끼어들지 않는다. 중요한 건 둘 다 한다는 것이다.)
		if _low_hp_tween != null and _low_hp_tween.is_valid():
			_low_hp_tween.kill()
		_low_hp_tween = null
		hp_box.modulate = Color.WHITE

func _process(_delta: float) -> void:
	if not defense_field:
		return

	# 기지 침입 바 — 적이 연달아 새어 나가도 계단처럼 튀지 않게 따라간다.
	if base_hp_bar:
		Juice.approach(base_hp_bar, _base_bar_target, _delta)

	# 골드 카운트업(§5.2 22). 침입 바와 **같은 감쇠 곡선**을 쓴다(`Juice.approach_value`).
	# 정수로 반올림한 값이 실제로 바뀔 때만 라벨을 다시 쓴다 — 매 프레임 문자열을
	# 새로 만들면 60fps 내내 할당이 생기는데, 그 대가로 얻는 것이 없다.
	if gold_label and _gold_shown >= 0.0:
		var shown_before := roundi(_gold_shown)
		_gold_shown = Juice.approach_value(_gold_shown, float(_gold_target), _delta, GOLD_COUNT_RATE)
		if roundi(_gold_shown) != shown_before:
			_apply_gold_label()

	# 카운트다운 — **이 한 곳뿐이다** (§5.2 21). 예고 바가 예고(`telegraph_label`)와
	# 남은 시간(`telegraph_timer`)을 함께 소유한다: "무엇이 오는가" 와 "언제 오는가" 는
	# 붙어 있어야 한 문장으로 읽힌다. 상단 바에 같은 값을 한 번 더 쓰지 말 것.
	if telegraph_timer:
		if not defense_field.is_wave_running:
			telegraph_timer.text = "대기 중"
		elif defense_field.is_planning_phase:
			telegraph_timer.text = "배치 %d초" % ceili(defense_field.planning_timer)
		elif defense_field.current_wave >= defense_field.MAX_WAVES_PER_ACT:
			telegraph_timer.text = "마지막 라운드"
		else:
			var remain := defense_field.ROUND_INTERVAL - defense_field.round_timer
			telegraph_timer.text = "다음 웨이브 %d초" % ceili(maxf(0.0, remain))

## 골드가 바뀔 때. **표시만** 굴리고, 경제 판단은 진짜 값을 쓴다.
##
## 왜 굴리는가(§5.2 22): 웨이브 클리어 보너스처럼 한 번에 크게 늘어날 때 숫자가
## 튀면 '얼마가 들어왔는가' 가 안 읽힌다. 체력 바는 이미 따라오는데 골드만 튀는 것도
## 화면 안에서 일관성이 없었다.
##
## ⚠️ **줄어들 때는 굴리지 않는다.** 표시가 실제보다 큰 동안에는 상점 버튼이 이미
##    꺼져 있어서, 플레이어는 "돈이 있는데 왜 못 사지" 를 알 길이 없다. 늘어나는 것은
##    보상이라 굴려도 되지만, 줄어드는 것은 **계약**이라 즉시여야 한다.
func _on_gold_changed(current: int) -> void:
	_gold_target = current
	# 첫 값이거나 줄어들면 즉시 맞춘다(위 ⚠️). `-1` 은 '아직 못 받았다' 는 뜻이라
	# 새 게임·불러오기가 0 에서 굴러 올라오는 것을 막는다.
	if _gold_shown < 0.0 or float(current) < _gold_shown:
		_gold_shown = float(current)
		_apply_gold_label()
	# 구매 가능 여부는 **진짜 값**으로 즉시 판단한다. 여기서 굴러가는 수를 넘기면
	# 벨트의 구매 버튼이 0.25초 동안 거짓말을 한다.
	if jamo_belt: jamo_belt.set_gold(current)

func _apply_gold_label() -> void:
	if gold_label:
		gold_label.text = "🪙 %d G" % roundi(_gold_shown)

func _on_wave_status_changed(act: int, max_act: int, wave: int, max_wave: int, is_running: bool) -> void:
	_update_topbar_wave_label(act, wave)
	_update_next_round_preview()
	# 밀어내기는 웨이브 중에만, 웨이브당 한 번. 웨이브가 시작될 때 충전된다.
	if is_running:
		ability_uses_left = ABILITY_USES_PER_WAVE
	# ⚠️ **벨트와 버튼을 함께** 갱신한다 — 예전에는 여기서 벨트에만 알려서
	# (`set_ability_available`) 버튼이 `disabled` 로 굳었고, 그래서 이 능력을 **런 내내 쓸 수
	# 없었다**(§2.40). 두 표면을 정하는 곳은 `_refresh_ability_button()` **하나**다 — 손으로
	# 맞추면 반드시 어긋난다(그 함수의 주석이 이미 그렇게 적고 있었다).
	# 그 안이 `defense_field.is_wave_running` 을 다시 읽지만, 이 신호는 그 필드를 켠/끈 **직후**에
	# 나므로(`:835`→`:869` · `:1334`→`:1335`) `is_running` 과 같은 값이다.
	_refresh_ability_button()

func _on_wave_cleared(_act: int, wave: int, bonus_gold: int) -> void:
	jamo_belt.set_unlocked_slot_count(defense_field.unlocked_slot_count)
	jamo_belt.render_belt()
	if wave % DefenseField.BOSS_ROUND_INTERVAL == 0 and is_instance_valid(shop_modal):
		shop_modal.refresh_stock()
	save_game_state()
	# 로그라이크 핵심 루프: 웨이브 클리어 → 활자 3택 1 드래프트
	# ⚠️ 예전엔 앞에 `and not defense_field.is_wave_running` 이 있었다 — 그 절은 **항상
	# 거짓**이라 이 드래프트가 게임에서 **한 번도** 뜨지 않았다(§2.44). `wave_cleared` 는
	# 라운드마다 `DefenseField._process` 안에서, 즉 `is_wave_running == true` 인 채로 발화한다.
	if not _is_terminal_modal_open():
		_show_wave_reward(wave, bonus_gold)

## 종료성 모달(막 클리어/게임오버)이 떠 있으면 보상 모달을 겹쳐 띄우지 않는다.
func _is_terminal_modal_open() -> bool:
	return modal_layer.get_child_count() > 0

## 보상 드래프트가 떠 있는 동안 전투를 멈춘다(§2.44, 2026-10-06).
##
## ⚠️ `Engine.time_scale` 을 쓰지 않는다 — 그 값은 **배속 버튼의 상태 그 자체**라
## (`is_paused()` 가 그 값만 읽는다) 여기서 건드리면 버튼이 거짓말을 한다.
## `process_mode` 는 노드별이라 그 문제가 없다.
## 실측(`tools/_PMProbe.gd`): `PROCESS_MODE_DISABLED`(4) 로 두면 `DefenseField._process`
## (라운드 타이머)와 그 자식인 적의 이동이 **함께** 멈추고, `PROCESS_MODE_INHERIT`(0) 로
## 되돌리면 함께 재개된다.
func _set_combat_frozen(frozen: bool) -> void:
	if defense_field == null:
		return
	defense_field.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT

## 보상 모달이 **어느 문으로** 나가든 전투를 재개한다(멱등).
##
## 정상 경로(카드 선택·건너뛰기)는 `_on_wave_reward_chosen` 이 **즉시** 푼다. 이 보험이
## 필요한 이유는 봇·플레이테스트가 쓰는 `_clear_modals()` 가 모달의 `_close()` 를 태우는데
## 그 문은 콜백을 부르지 않기 때문이다 — 그때 풀리지 않으면 필드가 **영영 멈춘 채** 남고
## 난이도 게이트가 조용히 멈춘다.
func _on_reward_modal_exited() -> void:
	_set_combat_frozen(false)

## 웨이브 클리어 보상 드래프트 팝업
##
## ⚠️ **뜨는 동안 전투를 멈춘다**(§2.44, 2026-10-06). 보상은 `DefenseField._process` 의
## *배치 단계* 진입에서 오는데, 그 단계는 `planning_timer`(3초)를 세면서 **적은 계속 걷는다.**
## 멈추지 않으면 플레이어가 카드를 고르는 동안 다음 라운드가 시작된다 — 그 3초는
## `Engine.time_scale` 을 따르므로 **4배속에서 0.75 실초**다(실측). 고르는 도중에 판이 뒤집힌다.
##
## ⚠️ 모달은 **스스로 `Engine.time_scale` 을 건드리지 않는다** — 이유는 `_set_combat_frozen`
## 주석에 있다. 대신 필드의 `process_mode` 를 끄고, 나갈 때 되돌린다.
func _show_wave_reward(wave: int, bonus_gold: int) -> void:
	var modal: WaveRewardModal = WAVE_REWARD_SCENE.instantiate()
	modal_layer.add_child(modal)
	_set_combat_frozen(true)
	# 보험 — 모달이 **어느 문으로** 나가든 전투가 멈춘 채 남지 않는다(`_on_reward_modal_exited`).
	modal.tree_exited.connect(_on_reward_modal_exited)
	modal.setup(
		wave,
		bonus_gold,
		reroll_dice,
		_on_wave_reward_chosen,
		_on_wave_reward_dice_changed
	)

func _on_wave_reward_chosen(chosen_char: String, from_global: Vector2 = Vector2.ZERO) -> void:
	# ⚠️ 보상 드래프트의 **모든 탈출구**(카드 선택·건너뛰기)가 이 함수를 지난다 — 그래서
	# 재개도 여기서 **즉시** 한다. 모달의 페이드아웃 트윈(`_close`)에 기대면 안 된다:
	# 트윈은 `Engine.time_scale` 을 따르므로 일시정지 중에는 영원히 오지 않아 전투가
	# **영영 멈춘 채** 남는다(§6.8 — 3초가 766ms 가 된 그 함정). `_show_wave_reward` 참고.
	_set_combat_frozen(false)
	if chosen_char != "":
		jamo_belt.add_jamo(chosen_char)
		jamo_belt.render_belt()
		_toast("활자 [%s] 획득" % chosen_char)
	# ⚠️ 연출 호출은 **밖에** 둔다. 안에 두면 `_fly_jamo_to_belt` 의 가드가 도달 불가능해진다
	# — 건너뛰기는 위 `if` 에서 이미 걸러지므로 그 함수는 빈 활자를 영원히 못 본다.
	# "무엇을 띄울 것인가" 는 연출 함수가 스스로 판단하는 편이 맞다(`Juice.shake`·
	# `Juice.impact` 가 null·무효 노드를 스스로 거르는 것과 같은 구조).
	_fly_jamo_to_belt(chosen_char, from_global)
	save_game_state()

## 보상 카드가 벨트로 **날아가는** 연출 (감사 §2.6 문제 2).
##
## 왜 필요한가: 카드를 고르면 `add_jamo` 가 즉시 벨트를 다시 그려서 활자가 벨트에
## **툭 나타난다.** 클릭과 결과 사이에 시각적 연결이 없어 "획득했다" 는 감각이 없다
## (사용자 지적: "아이템은 얻지만 획득감을 못 느낌"). 글자 하나가 카드에서 벨트까지
## 날아가면 그 둘이 이어진다 — 도착점이 **그 칸**이라 "어디로 들어갔는가" 도 정보가 된다.
##
## ⚠️ `add_jamo` 를 연출에 맞춰 **늦추지 않는다.** 상태 변경을 연출에 미루면 그 사이에
## 벨트를 건드리는 다른 경로(드래그·구매·회전·불러오기)와 어긋난다. 연출만 따라간다.
##
## 띄울 것이 없으면 아무것도 하지 않는다 — 가드가 **두 절**이다:
##   · `char_str == ""`              : 활자가 없으면 띄울 글자가 없다(건너뛰기)
##   · `from_global == Vector2.ZERO` : 출발점을 안 알려준 호출자는 띄우지 않는다
## ⚠️ 두 절이 각각 실재하지만 **결정적인 것은 좌표 절**이다(2026-09-23 주입으로 실측):
## 건너뛰기는 활자도 비고 좌표도 0 이라 **어느 한 절만으로도** 막힌다 — 즉 건너뛰기만
## 보면 활자 절을 지워도 통과한다(주입 RC=0). 좌표 절을 지우면 1인자 호출
## (`DifficultyPlaytest.gd:272`)이 **화면 좌상단에서** 날아온다(주입 RC=1).
## 활자 절은 `("", 0이 아닌 좌표)` 를 넘기는 미래 호출자를 위한 **방어 절**이고,
## `tools/RewardFlightProbe.gd` §6 이 그 계약만 따로 잰다.
func _fly_jamo_to_belt(char_str: String, from_global: Vector2) -> void:
	if char_str == "" or from_global == Vector2.ZERO:
		return
	# ⚠️ 레이아웃은 **다음 프레임**에 확정된다. `add_jamo` 직후에 타일의 rect 를 읽으면
	# `HFlowContainer` 가 아직 자식을 배치하지 않아 (0,0) 이 나오고, 연출이 화면
	# 좌상단으로 날아간다. 한 프레임 기다린 **뒤에** 도착점을 조회한다.
	# 노드를 미리 잡아 두지 않는 이유: 기다리는 동안 다시 렌더되면 그 노드가 해제된다 —
	# 기다린 뒤에 조회하면 그 사이가 안전하다.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var tile: Control = jamo_belt.tile_node_at(jamo_belt.jamo_list.size() - 1)
	if tile == null:
		return
	var to_global: Vector2 = tile.get_global_rect().get_center()

	var ghost := Label.new()
	# 이름을 붙인다 — `tools/RewardFlightProbe.gd` 가 이 이름으로 찾아 수명을 잰다.
	ghost.name = "RewardFlightGhost"
	ghost.text = char_str
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.add_theme_font_size_override("font_size", 30)
	ghost.add_theme_color_override("font_color", Palette.TX_GOLD)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ `modal_layer` 가 아니라 **여기** 붙인다. 그 레이어의 자식 수는
	# `_is_terminal_modal_open()` 의 판정에 쓰인다 — 지나가는 연출이 그 수를 늘리면
	# 막 클리어·게임오버 모달이 막힌다. 위에 그리는 것은 `z_index` 로 해결한다.
	ghost.z_index = 100
	add_child(ghost)
	ghost.size = Vector2(40, 40)
	var half := Vector2(20, 20)
	# ⚠️ 트리에 들어간 **뒤**에 잡아야 `global_position` 이 먹는다(`Juice.impact` 와 같은 함정).
	ghost.global_position = from_global - half

	# 0.28초 — 연출 예산의 '중요(런당 30~60회)' 구간 상한(0.3초) 안이다.
	# 이 이벤트는 웨이브마다 일어나므로 클라이맥스(1.2초) 예산을 쓸 수 없다.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", to_global - half, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 줄어들며 사라진다 — '벨트에 흡수됐다' 로 읽힌다.
	tw.tween_property(ghost, "scale", Vector2(0.55, 0.55), 0.28).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.14).set_delay(0.14)
	# 캡처 대신 바운드 Callable 을 넘긴다 — 연출 도중 씬이 해제돼도
	# "Lambda capture ... was freed" 가 찍히지 않는다(`Juice.shake` 와 같은 이유).
	tw.chain().tween_callback(ghost.queue_free)

func _on_wave_reward_dice_changed(remaining: int) -> void:
	reroll_dice = remaining
	# ⚠️ 툴팁 조립은 `_refresh_stage_tooltip()` 한 곳이 맡는다. 여기서 직접 대입하면
	# 다음 웨이브 시작에 `_update_next_round_preview()` 가 통째로 덮어써 **주사위 줄이 사라진다**
	# (예전이 정확히 그랬다 — `tools/DiceVisibilityProbe.gd` 실측: 잔량이 4개 상태 중 1개에서만 보였다).
	if defense_field:
		_refresh_stage_tooltip(defense_field.next_round_preview())
	save_game_state()

## 화면 하단에 짧은 정보 토스트를 띄운다. (획득/알림 피드백 공용)
func _toast(message: String) -> void:
	if message == "":
		return
	var layer := get_node_or_null("/root/ToastLayer")
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "ToastLayer"
		layer.layer = 90
		get_tree().root.add_child(layer)
	var label := Label.new()
	label.theme_type_variation = "StatLabel"
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(0, -140)
	layer.add_child(label)
	label.modulate.a = 0.0
	var tw := label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.14)
	tw.tween_interval(1.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(label.queue_free)

func _update_next_round_preview() -> void:
	if not defense_field:
		return
	var preview = defense_field.next_round_preview()
	# ⚠️ 예고가 **화면에** 나오는 곳은 **여기 하나뿐이다**(§5.2 21). 예전에는 숨겨진
	# `NextRoundLabel` 에도 같은 문자열을 썼다 — 코드는 보여준다고 믿는데 화면에는 없었다.
	# 상단 바 툴팁은 **다른 채널**이라 중복이 아니다(마우스를 올려야 보인다).
	# ⚠️ 바에는 **짧은 형태**를 넣는다(§2.13-2). 라벨 폭이 1104 px 인데 상성 절이 혼자
	#    1322 px 라 도달 가능한 60개 문구가 **전부** 잘렸다(실측, 최장 1777 px).
	#    아래 툴팁과 라운드 정보 모달은 **전체 문구**를 그대로 받는다 — 정보는 안 준다.
	if telegraph_label:
		telegraph_label.text = defense_field.next_round_preview(true)
	_refresh_stage_tooltip(preview)

## `btn_stage` 툴팁의 **유일한 작성자**.
##
## ⚠️ 왜 함수로 뽑았나 — 예전에는 두 함수가 각자 `btn_stage.tooltip_text` 를 **통째로 대입**했다:
##
##     `_update_next_round_preview()`  → "다음 라운드 적 예고\n<예고>"
##     `_update_dice_display()`        → "<예고>\n\n남은 주사위: N개 (웨이브 보상 새로고침)"
##
## 나중에 부르는 쪽이 이기므로, `wave_status_changed`(웨이브가 시작/끝날 때마다)에서 불리는
## 앞쪽 함수가 **주사위 줄을 지웠다.** 실측(`tools/DiceVisibilityProbe.gd`):
## 주사위 잔량이 보이는 상태가 **4개 중 1개**뿐이었고 — **런 시작(3개)에도 안 보였다.**
## 런 시작조차 안 보인 이유는 `_update_next_round_preview()` 가 `_ready` 경로에서 먼저 불리기 때문이다.
##
## 주사위는 **런 지속 자원**이다(시작 3 · 막 클리어 +1 · 유물 +2, 웨이브마다 안 채워진다).
## §2.6-b 가 리롤 **전용음**을 만들 수 있었던 근거가 그 희소성인데, 정작 그 잔량을 볼 수 있는
## 곳이 툴팁 하나뿐이었고 그마저 대부분의 상태에서 덮여 있었다.
##
## ⚠️ §2.13-1(카운트다운이 두 라벨에 중복 표기)과 **같은 부류의 결함**이다 —
## 채널이 하나면 **작성자도 하나**여야 한다. 두 곳에서 쓰면 한쪽이 조용히 다른 쪽을 지운다.
##
## ⚠️ 이 함수는 툴팁만 만진다. `telegraph_label`(화면에 보이는 예고)은 위 함수가 계속 소유한다 —
## 여기까지 넘기면 "무엇이 화면에 보이는가" 의 소유자가 둘이 되어 같은 결함이 재발한다.
func _refresh_stage_tooltip(preview: String) -> void:
	if btn_stage == null:
		return
	# §5.2 31 (B) — `ATTR_INFO.desc` 가 여기서 처음으로 플레이어에게 도달한다.
	# ⚠️ **멈춰 있는 표면**이라 여기 붙였다. 배지(움직이는 적 머리 위)는 `MOUSE_FILTER_IGNORE`
	#    이고, 풀어도 10px 움직이는 표적에 호버를 요구하는 것은 신뢰할 수 없는 UX 다.
	var desc: String = defense_field.next_round_attr_desc() if defense_field else ""
	var tail := "\n\n속성 설명\n%s" % desc if desc != "" else ""
	btn_stage.tooltip_text = "다음 라운드 적 예고\n%s\n\n남은 주사위: %d개 (웨이브 보상 새로고침)%s" \
		% [preview, reroll_dice, tail]

func _on_tile_purchase_requested(is_vowel: bool) -> void:
	var price := jamo_belt.current_tile_price()
	# ⚠️ 용량은 `JamoBelt.MAX_BELT_TILES` 하나에서 온다. 여기에 숫자를 적으면
	# `_update_buy_buttons()` 의 비활성 판정과 어긋나 **버튼이 거짓말을 한다**
	# (눌리는데 안 담기거나, 담기는데 안 눌린다).
	if defense_field.gold < price or jamo_belt.jamo_list.size() >= JamoBelt.MAX_BELT_TILES:
		return
	if is_vowel:
		var choice := HangulEngine.get_weighted_random_jamo(HangulEngine.VOWEL_POOL)
		defense_field.gold -= price
		jamo_belt.register_tile_purchase()
		jamo_belt.add_jamo(choice)
		defense_field.gold_changed.emit(defense_field.gold)
		# 골드를 낸 '구매' 다 — word_crafted 는 단어 완성 전용이다.
		# 참고: add_jamo 가 이미 render_belt 를 태우므로, 이 구매가 단어를 완성하면
		# 완성음과 같은 프레임에 겹친다. 구매음을 분리해 그 겹침도 함께 없앤다.
		SoundEngine.play_coin()
		save_game_state()
	else:
		_show_tile_draft(false)

func _show_tile_draft(is_vowel: bool) -> void:
	var pool = HangulEngine.VOWEL_POOL if is_vowel else HangulEngine.CONSONANT_POOL
	var choices: Array[String] = []
	while choices.size() < 3:
		var choice := HangulEngine.get_weighted_random_jamo(pool)
		if choice not in choices: choices.append(choice)
	var modal_data := _make_choice_modal("%s 타일 선택 · %dG" % ["모음" if is_vowel else "자음", jamo_belt.current_tile_price()])
	for choice in choices:
		var button := Button.new()
		button.text = choice
		button.custom_minimum_size = Vector2(90, 64)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_buy_draft_choice.bind(choice, modal_data.panel))
		modal_data.row.add_child(button)

func _buy_draft_choice(choice: String, modal: Control) -> void:
	var price := jamo_belt.current_tile_price()
	if defense_field.gold < price: return
	defense_field.gold -= price
	jamo_belt.register_tile_purchase()
	jamo_belt.add_jamo(choice)
	defense_field.gold_changed.emit(defense_field.gold)
	# 모음 타일 즉시 구매와 **같은 거래**다(골드를 내고 활자를 받는다) — 같은 소리를 쓴다.
	SoundEngine.play_coin()
	save_game_state()
	modal.queue_free()

func _on_strategy_recommendations_requested() -> void:
	var words := WordDatabase.get_all_words().filter(func(data): return str(data.get("word", "")).length() <= 3)
	var candidates := AutoArrange.buildable_words_for(jamo_belt.recommendation_tiles(), words)
	var modal_data := _make_choice_modal("미등록 타워 + 대기 타일로 가능한 조합")
	var card := Label.new()
	card.custom_minimum_size = Vector2(700, 150)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", 16)
	var lines: Array[String] = []
	for data in candidates: lines.append(_recommendation_line(data))
	card.text = "\n".join(lines) if not lines.is_empty() else "현재 남는 타일로 만들 수 있는 등록 단어가 없습니다."
	modal_data.row.add_child(card)

## 한 줄 = "단어(특성 DPS x.x · 레시피)".
##
## **숫자와 특성 이름은 타워가 실제로 낼 값이어야 한다.** 예전에는 category 로 특성을
## 추측하고 자체 base 표(`[5.0, 18.75, 35.0]`)를 곱하는 세 번째 공식을 썼다. 그래서
## 2음절에서 입구 35.6(실제 53.1), 바늘 30.5(45.4), 안개 23.4(34.9) 로 전부 어긋났고,
## **기운은 특성 이름까지 틀렸다** — 카드는 '연쇄', 실제 특성은 관통(53.1). 3배 넘게
## 낮게 적힌 것이다. 플레이어가 "무엇을 노릴까" 를 정하는 숫자가 여기 있으므로,
## WordTower.preview_stats 하나만 본다(타워 툴팁·자동 배치와 같은 출처).
func _recommendation_line(data: Dictionary) -> String:
	var word := str(data.get("word", ""))
	var stats: Dictionary = WordTower.preview_stats(word, data)
	var trait_id := str(stats.get("trait", ""))
	var trait_name := str(WordTower.TRAIT_NAMES.get(trait_id, trait_id))
	var recipe: Array[String] = []
	for syllable in AutoArrange.get_word_syllable_slots(word):
		for slot in syllable:
			for tile in slot: recipe.append(str(tile))
	return "%s(%s DPS %.1f · %s)" % [word, trait_name, float(stats.get("dps", 0.0)), "".join(recipe)]

func _make_choice_modal(title_text: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	panel.custom_minimum_size = Vector2(760, 230)
	panel.z_index = 50
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var close := Button.new()
	close.text = "닫기"
	close.pressed.connect(panel.queue_free)
	box.add_child(close)
	_show_modal(panel)
	return {"panel": panel, "row": row}

## 모달을 화면 중앙에 띄우고 등장 애니메이션을 재생한다.
## centered=false 면 호출부가 이미 앵커를 잡아 둔 것으로 보고 위치를 건드리지 않는다.
## delay > 0 이면 그만큼 **실시간으로** 기다린 뒤 등장한다(§2.8 여운 — 아래 ⚠️).
func _show_modal(panel: Control, centered: bool = true, delay: float = 0.0) -> void:
	if panel.get_parent() == null:
		modal_layer.add_child(panel)
	# 주의: PRESET_CENTER 는 반드시 **트리에 들어간 뒤**에 적용해야 한다.
	# 트리 밖에서는 get_parent_anchorable_rect() 가 Rect2() 를 돌려주므로 '중앙'
	# 계산이 (0,0) 기준이 되고, 결과적으로 패널의 **좌상단이 화면 중앙**에 놓인다.
	# 실측: 760px 드래프트 모달이 x 640~1400 이 되어 1280 화면 밖으로 120px 잘려
	# 나갔고(닫기 버튼이 화면에 없었다), 460px 게임오버 모달도 중앙이 아니라
	# 우하단에 걸려 자모 벨트를 덮었다. 호출부에서 미리 preset 을 잡던 코드를 전부
	# 걷어내고 여기 한 곳에서만 정렬한다.
	if centered:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		# 트리 진입 직후 부모 크기가 아직 0 일 수 있다. 그 경우 preset 이 음수 위치를
		# 만들어 화면 밖으로 밀리므로, 실제 크기로 한 번 더 보정한다.
		var host: Vector2 = modal_layer.size
		if host.x <= 0.0 or host.y <= 0.0:
			host = get_viewport_rect().size
		var want: Vector2 = (host - panel.size) * 0.5
		if panel.position.distance_to(want) > 0.5:
			panel.position = want
	# 피벗도 같은 이유로 레이아웃 확정 뒤에 잡아야 한다. size 가 (0,0) 이면
	# BACK_OUT 팝이 가운데가 아니라 좌상단에서 자란다.
	var pivot: Vector2 = panel.size * 0.5
	if pivot.x <= 0.0 or pivot.y <= 0.0:
		pivot = panel.custom_minimum_size * 0.5
	panel.pivot_offset = pivot
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	if delay > 0.0:
		# ── 여운 (§2.8, §5.2 10) ────────────────────────────────────────
		# **모달은 지금 트리에 넣되 아직 투명하다.** 이 순서가 세 가지를 지킨다:
		#   · 모달을 나중에 *만들면* 그동안 노드가 트리 밖에 떠 있어 **고아 노드**가 된다.
		#     `test_tower_traits._test_no_nodes_are_left_behind` 가 실측으로 잡았다(27개).
		#   · `_is_terminal_modal_open()` 이 이 순간에도 참이어야 한다. 함락 직후 남은 적이
		#     정리돼 `wave_cleared` 가 오면, '터미널 모달 없음' 으로 보여 **보상 드래프트가
		#     결과 화면 위에 겹쳐** 뜬다.
		#   · 그래서 '모달 개수' 를 세는 계약(`_test_game_over_records_the_run_only_once`)도
		#     여운과 무관하게 그대로 성립한다.
		# ⚠️ 대기는 **실시간**이다. 트윈은 기본적으로 `Engine.time_scale` 을 따르므로
		#    4배속에서 0.4초가 100ms 가 되고 정지 중에는 **영원히 오지 않는다**
		#    (§6.8 — 3초가 766ms 가 된 그 함정. `tools/PauseAbilityProbe.gd:142` 와 같은 인자).
		# ⚠️ 대기와 등장을 **두 트윈으로 나눴다.** 한 트윈에서 `tween_interval` 뒤에
		#    `set_parallel(true)` 를 부르면 뒤따르는 프로퍼티가 interval 과 **평행**해져
		#    여운이 통째로 사라진다 — 단계 의미가 헷갈리는 자리라 나눠서 명시한다.
		var wait := create_tween()
		wait.set_ignore_time_scale(true)
		wait.tween_interval(delay)
		wait.tween_callback(func(): _play_modal_entrance(panel, true))
	else:
		_play_modal_entrance(panel)
	# 레이아웃이 확정된 다음 프레임에 피벗을 다시 잡아 준다. 다만 인자는 **호출 시점**에
	# 평가되므로 여기서 size 를 그대로 넘기면 (0,0) 이 박혀 위 계산을 덮어쓴다.
	panel.call_deferred("set_pivot_offset", pivot)

## 모달 등장 연출(BACK_OUT 팝). `_show_modal` 에서 분리한 이유는 그쪽 delay 주석 참고 —
## 여운을 '대기' 와 '등장' 두 트윈으로 나눠야 순서가 명시되기 때문이다.
##
## `ignore_time_scale` 은 **여운 경로에서만** 참이다. 그 경우 대기와 등장이 모두 실시간이어야
## 한다 — 대기만 실시간이고 등장이 배속을 따르면, 플레이어가 여운 중에 `[P]` 를 눌렀을 때
## 등장 트윈이 얼어붙어 **결과 패널이 영원히 투명하게 남는다**(게임오버 패널은 반드시
## 나타나야 하는 것이므로 시간축에 기대면 안 된다 — §2.9 타워 등장이
## `set_ignore_time_scale(true)` 를 쓰는 것과 같은 판단이다).
func _play_modal_entrance(panel: Control, ignore_time_scale := false) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tw := create_tween().set_parallel(true)
	if ignore_time_scale:
		tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18)

func _on_tile_removal_requested(index: int) -> void:
	if defense_field.gold < JamoBelt.TILE_REMOVE_PRICE or index < 0 or index >= jamo_belt.jamo_list.size():
		return
	defense_field.gold -= JamoBelt.TILE_REMOVE_PRICE
	jamo_belt.remove_jamo(index)
	defense_field.gold_changed.emit(defense_field.gold)
	SoundEngine.play_tile_click()
	save_game_state()

## 활자 교체 — 벨트가 꽉 차서 구매가 막힌 뒤에도 쓸 수 있는 골드 소비처.
## 같은 종류(자음/모음) 안에서만 바꾼다. 그래야 벨트의 자음·모음 구성이 유지된다.
func _on_tile_swap_requested(index: int) -> void:
	var price := jamo_belt.current_swap_price()
	if defense_field.gold < price or index < 0 or index >= jamo_belt.jamo_list.size():
		return
	var old_char: String = jamo_belt.jamo_list[index]
	var pool: Array = HangulEngine.VOWEL_POOL if HangulEngine.is_vowel(old_char) else HangulEngine.CONSONANT_POOL
	var new_char := HangulEngine.get_weighted_random_jamo(pool)
	if new_char == old_char:
		# 2026-09-26 까지 여기는 `return` 한 줄이 전부였다 — 골드를 안 받는 것은 의도지만
		# **그 밖에 아무 일도 안 일어나서** 버튼이 고장 난 것과 구별되지 않았다(§2.24).
		# 화면 하단 토스트는 이 프로젝트가 이미 쓰는 채널이다(4곳) — 새 기제 0.
		# ⚠️ 모드는 **일부러 안 푼다** — 다시 눌러 다른 활자를 뽑을 수 있는 상태가 맞다.
		_toast("같은 활자가 나왔습니다 · 골드는 그대로입니다")
		return  # 같은 활자가 나오면 돈을 받지 않는다
	defense_field.gold -= price
	jamo_belt.swap_jamo(index, new_char)
	defense_field.gold_changed.emit(defense_field.gold)
	SoundEngine.play_tile_combine()
	save_game_state()

## 밀어내기 — 자모 타일 1장을 **영구히** 소모해 경로 위의 모든 적을 뒤로 민다.
##
## 자모는 이 게임에서 유일하게 소모되지 않는 자원이었다(단어를 세워도 타일은 남는다).
## 그래서 "지금을 사는 대가로 앞으로 만들 수 있는 단어를 하나 포기한다" 가 성립한다 —
## 웨이브 중 '값을 치르는 개입' 이 없던 자리를, 새 자원을 만들지 않고 채운다.
func _on_tile_ability_requested(index: int) -> void:
	if ability_uses_left <= 0 or not defense_field.is_wave_running:
		return
	if index < 0 or index >= jamo_belt.jamo_list.size():
		return
	# 값을 먼저 치른다. 밀려난 적이 0마리여도 타일은 돌아오지 않는다 — 그게 이 능력의 전부다.
	ability_uses_left -= 1
	jamo_belt.remove_jamo(index)
	defense_field.push_back_enemies(DefenseField.PUSH_BACK_RATIO)
	_refresh_ability_button()
	# 밀어내기는 **값을 치르는 개입**이지 '좋은 일이 있었다' 가 아니다 — 2026-09-26 까지
	# `play_buff()`(=`play_heal()`) 였고, 그래서 라운드 보상음과 **같은 파형**이 났다(§2.22-4).
	# 내려가는 스윙(700→250Hz)이라 '밀려난다' 와 방향이 맞고, 보상 계열(상행 아르페지오)과 갈린다.
	# ⚠️ 잔여 — `play_magic` 은 원소 타워 공격음과 이름을 공유하므로 50 ms 스로틀이 이 소리를
	#    삼킬 수 있다(§2.23 과 같은 부류). 그래도 보상 계열 파형을 쓰는 것보다는 낫다.
	SoundEngine.play_magic()
	save_game_state()

## 밀어내기 버튼을 누르면 벨트가 '밀어낼 타일 고르기' 모드로 들어간다.
func _on_ability_pressed() -> void:
	if btn_ability.disabled:
		return
	jamo_belt._toggle_ability_mode()
	_refresh_ability_button()

## 툴팁 **본문**. 씬이 선언한 문장을 처음 한 번만 붙잡아 둔다.
##
## ⚠️ 매번 씬 문장을 다시 읽으면 안 되고(씬은 한 값뿐이다), 사유가 붙은 문장을 본문으로
##    삼아도 안 된다 — 그러면 갱신할 때마다 사유가 **누적**된다. 그래서 첫 호출에서 한 번만.
var _ability_base_tip := ""

## 밀어내기 버튼의 (비활성 여부, 사유) 를 **한 곳에서** 만든다.
##
## ⚠️ `JamoBelt._button_state()` · `ShopModal._button_state()` 와 **같은 규칙**이다.
##    밀어내기는 그 규칙의 **세 번째 화면**인데 §2.40-3 까지 혼자 규칙 밖이었다 —
##    두 화면이 같은 서식을 써야 플레이어가 "막힌 이유는 툴팁에 있다" 를 **한 번만** 배운다.
## ⚠️ 판정과 사유를 **묶는** 이유도 같다: 따로 만들면 둘이 어긋나 툴팁이 거짓말을 한다.
##    여기서는 `disabled = reason != ""` 이므로 **사유가 곧 판정**이다.
func _ability_button_state() -> Dictionary:
	var reason := ""
	if not defense_field.is_wave_running:
		reason = "⚠️ 웨이브가 진행 중일 때만 쓸 수 있습니다"
	elif ability_uses_left <= 0:
		reason = "⚠️ 이번 웨이브에는 이미 사용했습니다 (웨이브마다 %d회)" % ABILITY_USES_PER_WAVE
	elif jamo_belt.jamo_list.is_empty():
		reason = "⚠️ 밀어낼 자모 타일이 없습니다"
	return {"disabled": reason != "", "reason": reason}


## 툴팁 본문에 막힌 사유를 덧붙인다. 사유가 없으면 본문 그대로.
## ⚠️ 버튼 **글자**를 늘리지 않는 이유는 `JamoBelt._with_reason()` 과 같다 —
##    상단 바는 폭이 빠듯해 넘치면 조용히 잘린다(§2.39 가 그 부류를 실측했다).
func _with_reason(base: String, reason: String) -> String:
	if reason == "":
		return base
	return "%s\n\n%s" % [base, reason]


## 밀어내기 버튼의 상태를 **한 곳에서만** 정한다.
##
## 쓸 수 있는 조건이 여러 곳에서 바뀐다(웨이브 시작·종료, 사용, 새 게임, 불러오기).
## 매번 손으로 맞추면 반드시 어긋나서, 못 쓰는데 눌리는 버튼이 생긴다 —
## 이 프로젝트 규칙: "조용히 아무 일도 안 일어나면 버튼이 고장 난 것처럼 보인다".
##
## ⚠️ §2.40 (2026-10-06) — 이 함수가 **막힌 사유까지** 정한다. `disabled` 는 bool 하나라
##    사유가 사라지는데, 이 버튼은 서로 다른 **세** 이유로 막히고 그중 둘(웨이브 시점·
##    타일 보유)은 플레이어가 스스로 바꿀 수 있다. 사유가 없으면 **고장 난 버튼**과
##    구별되지 않는다(§2.40-3).
func _refresh_ability_button() -> void:
	var state := _ability_button_state()
	var wave_open := defense_field.is_wave_running and ability_uses_left > 0
	jamo_belt.set_ability_available(wave_open)
	if btn_ability:
		btn_ability.disabled = bool(state["disabled"])
		btn_ability.text = "밀어낼 타일 선택" if jamo_belt.ability_mode else "밀어내기"
		if _ability_base_tip == "":
			_ability_base_tip = btn_ability.tooltip_text
		btn_ability.tooltip_text = _with_reason(_ability_base_tip, str(state["reason"]))

## 막 클리어 모달이 **떠 있는 동안** 참.
##
## `_is_terminal_modal_open()` 은 이름과 달리 `modal_layer.get_child_count() > 0` 이라
## 상점·보상 드래프트까지 전부 참으로 돌려준다 — "막 클리어 모달이 떠 있다" 로는 못 쓴다.
## 그래서 인스턴스를 직접 들고 있는 좁은 술어를 따로 둔다.
func _act_clear_modal_open() -> bool:
	return is_instance_valid(_act_clear_modal) and _act_clear_modal.is_inside_tree()

## 막 클리어 모달이 닫힐 때 **참조를 먼저 비우고** 다음 막을 시작한다.
##
## 순서가 계약이다 — 비우기 전에 `_start_wave_automatically()` 를 부르면 그 안의
## `_on_start_wave_pressed()` 가 `_act_clear_modal_open()` 을 참으로 보고 **자기 자신**을
## 닫으려 든다. `_close()` 는 `_closed` 로 막혀 그대로 되돌아오므로, 웨이브가
## **영영 시작되지 않는다**(모달이 스스로의 시작을 막는다).
func _on_act_clear_dismissed() -> void:
	_act_clear_modal = null
	_start_wave_automatically()

func _on_act_cleared(act: int, bonus_gold: int) -> void:
	var act_name = DefenseField.ACT_NAMES.get(act, "미지의 영역")
	var next_act = act + 1
	var next_act_name = DefenseField.ACT_NAMES.get(next_act, "다음 장")

	reroll_dice += 1

	# 주의 — 여기서 다음 막 웨이브를 **시작하지 않는다.** 시작은 이 모달을 닫는 순간이다
	# (`ActClearModal._close` → `_start_wave_automatically`). 예전에는 이 자리에서
	# 곧바로 시작해서, 축하 문구를 읽는 동안 적이 이미 걷고 있었고 중앙 패널이
	# 경로의 S자 중간을 통째로 가렸다.
	# 3초 자동 닫기 타이머도 함께 걷어냈다 — 그 타이머는 `Engine.time_scale` 을 따라
	# 4배속에서 0.77초 만에 사라졌고(실측: tools/PauseAbilityProbe.gd), 정지 중에는
	# 아예 오지 않아서 '닫기 버튼 없는 모달' 의 유일한 탈출구였다.
	var modal := ActClearModal.new()
	# 닫힐 때 부를 것은 `_start_wave_automatically` 가 **아니라** `_on_act_clear_dismissed` 다 —
	# 그쪽이 참조를 먼저 비운다(위 함수의 주석 참고).
	modal.setup(act, act_name, next_act, next_act_name, bonus_gold, _on_act_clear_dismissed)
	_show_modal(modal)
	# 트리에 들어간 **뒤에** 참조를 잡는다 — 술어가 `is_inside_tree()` 를 보므로 순서를
	# 뒤집으면 '떠 있지 않은데 주인인' 한 프레임이 생긴다.
	_act_clear_modal = modal
	save_game_state()

func _trigger_merchant_encounter(wave: int) -> void:
	_open_relic_shop()

func _open_relic_shop() -> void:
	if is_instance_valid(shop_modal):
		shop_modal.sync_state(defense_field.gold, owned_relics)
		shop_modal.show()
		shop_modal.move_to_front()
		return
	var modal_scene = load("res://scenes/tower/ShopModal.tscn")
	if modal_scene != null:
		var modal = modal_scene.instantiate()
		shop_modal = modal
		modal_layer.add_child(modal)
		modal.setup(defense_field.gold, owned_relics)

		modal.refresh_bought.connect(func(cost: int):
			defense_field.gold -= cost
			defense_field.gold_changed.emit(defense_field.gold)
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
	defense_field.relic_ids = owned_relics.map(func(r): return r.get("id", ""))
	jamo_belt.set_relics(defense_field.relic_ids)
	_render_relic_bar()
	var r_id = relic_data.get("id", "")
	_toast("유물 획득 · %s" % relic_data.get("name", r_id))

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
		var current_dmg = tower.damage_per_attack() * tower.damage_multiplier
		var hint := ""
		if tower.trait_id == "orbit":
			hint = "↻ 선회 방향: %s — 우클릭으로 전환" % tower.orbit_direction_label()
		modal.setup(tower.word_data, tower.syllable, tower.attack_range, tower.attack_interval, tower.synergy_labels, current_dmg, hint, tower.total_crit_chance(), defense_field.tower_damage_share(tower.syllable), tower)

func _on_jamo_changed() -> void:
	if not _is_loading_state:
		save_game_state()

func _on_parsed_towers_updated(parsed_list: Array) -> void:
	if defense_field:
		defense_field.update_towers_from_parsed_list(parsed_list)

func _on_start_wave_pressed() -> void:
	# 런이 끝난 뒤에는 웨이브를 시작할 수 없다.
	# ⚠️ 이 가드가 없으면 게임오버 모달이 떠 있는 동안에도 Space 가 여기를 지나
	#    `start_next_wave()` 를 부르고 `current_wave` 를 **조용히** 올린다. 모달은
	#    키를 막지 않는다(`ModalLayer` 는 `MOUSE_FILTER_IGNORE`). 화면에는 아무 일도
	#    안 일어난 것처럼 보이지만, '처음부터 다시하기' 를 누르면 `_run_recorded` 만
	#    풀리고 웨이브 번호는 올라간 채로 남는다.
	if _run_recorded:
		return
	# 막 클리어 모달이 다음 막 시작의 **주인**이다. 여기서 그냥 시작해 버리면 모달의
	# 약속("다음 막은 이 창을 닫으면 시작됩니다")이 거짓이 되고, 모달의 버튼은
	# `is_wave_running` 가드에 걸려 **먹통**이 된다(눌러도 아무 일이 없다).
	# 그래서 막지 않고 **같은 문**으로 보낸다 — 닫으면 그때 시작한다.
	# Space(KEY_SPACE)가 이 함수를 지나므로, 문 하나면 충분하다.
	if _act_clear_modal_open():
		_act_clear_modal._close()
		return
	if defense_field:
		defense_field.start_next_wave()
		SoundEngine.play_wave_start()

func _on_speed_pressed() -> void:
	if is_paused():
		# 배속 버튼으로도 재개된다 — 규칙은 하나다(멈추기 직전 배속으로 돌아간다).
		toggle_pause()
	elif current_speed_scale == 1.0:
		set_speed_scale(2.0)
	elif current_speed_scale == 2.0:
		set_speed_scale(4.0)
	else:
		set_speed_scale(1.0)

func set_speed_scale(speed: float) -> void:
	current_speed_scale = speed
	Engine.time_scale = speed
	if speed <= 0.0:
		btn_speed.text = "⏸ 정지"
	elif speed == 1.0:
		btn_speed.text = "1x 배속"
	elif speed == 2.0:
		btn_speed.text = "2x 배속"
	elif speed >= 4.0:
		btn_speed.text = "⚡ 4x 초고속"

## 일시정지 여부는 current_speed_scale **하나로만** 판단한다.
## 별도 bool 을 두면 set_speed_scale 과 어긋나 조용히 거짓말을 한다.
func is_paused() -> bool:
	return current_speed_scale <= 0.0

func toggle_pause() -> void:
	if is_paused():
		set_speed_scale(_speed_before_pause if _speed_before_pause > 0.0 else 1.0)
	else:
		_speed_before_pause = current_speed_scale
		set_speed_scale(0.0)

func _on_lexicon_pressed() -> void:
	var modal = load("res://scenes/LexiconModal.tscn").instantiate()
	modal_layer.add_child(modal)

func _on_lore_pressed() -> void:
	if modal_layer.get_node_or_null("LoreModal"):
		return
	SoundEngine.play_tile_click()
	var modal = PanelContainer.new()
	modal.name = "LoreModal"
	modal.theme_type_variation = "ModalPanel"
	modal.custom_minimum_size = Vector2(640, 480)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	modal.add_child(box)
	var title = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "활자술사 · 말의 심연"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var story = RichTextLabel.new()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story.bbcode_enabled = true
	story.text = "[center][color=#F5C451]소리와 글자를 엮어 만물을 연성하는 활자 방어술[/color][/center]\n\n말의 심연이 열리며, 세상의 낱말들이 조각으로 흩어졌습니다. 흩어진 자모는 스스로를 지키려 몰려들고, 마지막 활자술사인 당신만이 그 조각들을 다시 엮어 탑을 세울 수 있습니다.\n\n[color=#A78BFA][b]제 1막 · 초원의 문자[/b][/color]\n가장 기초가 되는 자모를 익히고, 첫 번째 탑을 세웁니다.\n\n[color=#A78BFA][b]제 2막 · 고대 유적의 어둠[/b][/color]\n갑옷을 두른 적이 나타납니다. 관통하는 글자를 엮어야 합니다.\n\n[color=#A78BFA][b]제 3막 · 차원의 심연[/b][/color]\n군집·질풍·중갑이 뒤섞여 밀려옵니다. 탑을 조합하고 시너지를 완성하세요.\n\n[center][color=#A99FC4][i]글자를 알면, 세상의 이치가 보인다.[/i][/color][/center]"
	story.add_theme_font_size_override("font_size", 15)
	story.fit_content = false
	story.scroll_active = true
	box.add_child(story)
	var close = Button.new()
	close.theme_type_variation = "PrimaryButton"
	close.text = "연성을 시작한다"
	close.custom_minimum_size = Vector2(200, 44)
	close.pressed.connect(func(): modal.queue_free())
	box.add_child(close)
	_show_modal(modal)

func _on_mute_pressed() -> void:
	var is_muted = SoundEngine.toggle_mute()
	btn_mute.text = "🔇" if is_muted else "🔊"

func _on_reset_pressed() -> void:
	SoundEngine.play_tile_click()
	start_new_game()

func start_new_game() -> void:
	SaveManager.delete_save_file()
	_is_loading_state = true
	# 새 런이 시작됐으니 '이번 런을 이미 기록했다' 도 함께 푼다.
	_run_recorded = false

	# Clear all active modallayers
	# 모달을 통째로 버리므로 '다음 막 시작의 주인' 참조도 함께 버린다. 남겨 두면 새 게임의
	# 첫 Space 가 이미 죽은 모달을 닫으려 들고, 정작 웨이브는 시작되지 않는다.
	_act_clear_modal = null
	for child in modal_layer.get_children():
		child.queue_free()

	if defense_field:
		defense_field.reset_combat_state()
		defense_field.first_magic_circle_pending = true
		# 기지 수치는 한 곳에서만 정의한다 (DefenseField.MAX_BASE_HP).
		defense_field.base_hp = DefenseField.MAX_BASE_HP
		defense_field.max_base_hp = DefenseField.MAX_BASE_HP
		defense_field.gold = 40
		defense_field.current_act = 1
		defense_field.current_wave = 0
		defense_field.is_wave_running = false
		defense_field.unlocked_slot_count = 3
		defense_field.tower_damage.clear()
		defense_field.orbit_directions.clear()
		defense_field.target_modes.clear()
		# 새 게임이 정지 상태로 시작하면 안 된다. Engine.time_scale 은 전역이라
		# 정지한 채 새 게임을 시작하면 아무것도 움직이지 않는다.
		set_speed_scale(1.0)
		ability_uses_left = ABILITY_USES_PER_WAVE
		if jamo_belt: _refresh_ability_button()
		defense_field.restore_tower_positions([])
		defense_field._update_slot_lock_visuals()
		defense_field.base_hp_changed.emit(DefenseField.MAX_BASE_HP, DefenseField.MAX_BASE_HP)
		defense_field.gold_changed.emit(30)
		_update_topbar_wave_label(1, 0)

	reroll_dice = 3
	owned_relics.clear()
	defense_field.relic_ids.clear()
	jamo_belt.set_relics([])
	_render_relic_bar()

	if jamo_belt:
		jamo_belt.jamo_list = JamoBelt.generate_starting_jamo()
		jamo_belt.slot_assignments.clear()
		jamo_belt.set_unlocked_slot_count(3)
		jamo_belt.reset_tile_purchase_price()
		jamo_belt.clear_slot_locks()
		jamo_belt.render_belt()

	btn_load.disabled = true
	_update_settings_menu()

	# 여기서 소리를 내지 않는다 — 바로 아래 `_start_wave_automatically()` 가
	# `play_wave_start()` 를 울리므로 겹치기만 한다(예전엔 word_crafted 가 붙어 있었다).
	_is_loading_state = false
	call_deferred("_start_wave_automatically")
	print("🔄 [Game] New game successfully started from Act 1, Wave 0!")

func _on_game_over(is_victory: bool) -> void:
	# 기지 HP 가 0 이 되면 신호가 **반복해서** 온다(적이 기지에 닿을 때마다).
	# 두 번째부터는 아무것도 만들지 않는다 — 모달이 겹겹이 쌓이고 같은 런이 여러 번
	# 기록되던 자리다.
	if _run_recorded:
		return
	_run_recorded = true
	# 런의 마지막 문장. 여기까지 **오디오가 0건**이었다 — 60라운드를 끝낸 순간도, 기지가
	# 함락된 순간도 무음이라 감정적 마침표가 없었다(§2.8). 모달이 뜨는 그 순간에 낸다.
	#
	# 두 소리 다 **여기서만** 쓴다. `play_victory()` 를 승리에 재사용하지 않은 이유:
	# 그 소리는 이미 '라운드 종료' 로 런당 수십 번 울리고 있어서, 승리에 쓰면 그 순간이
	# '또 한 라운드 끝났다' 와 구별되지 않는다 — **침묵보다 나쁜 거짓 신호**다.
	# (보스 등장음에서 `play_wave_start()` 를 거부한 것과 같은 판단.)
	if is_victory:
		SoundEngine.play_final_victory()
	else:
		SoundEngine.play_defeat()
	var modal = PanelContainer.new()
	modal.theme_type_variation = "ModalPanel"
	modal.custom_minimum_size = Vector2(460, 300)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	modal.add_child(vbox)

	var title = Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "심연 봉인 완료" if is_victory else "기지 함락"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var verdict = Label.new()
	verdict.theme_type_variation = "MutedLabel"
	verdict.text = "세상의 낱말을 다시 엮어냈습니다." if is_victory else _defeat_verdict(defense_field.last_defeat_reason)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(verdict)

	# 런 요약 — 타워별 누적 피해 랭킹
	var summary_wrap = PanelContainer.new()
	summary_wrap.theme_type_variation = "InsetPanel"
	vbox.add_child(summary_wrap)

	var summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 6)
	summary_wrap.add_child(summary_box)

	var rank_title = Label.new()
	rank_title.theme_type_variation = "HeadingLabel"
	rank_title.text = "런 요약 · 타워별 누적 피해"
	rank_title.add_theme_font_size_override("font_size", 15)
	summary_box.add_child(rank_title)

	# 순위표는 **칸이 맞아야** 읽힌다.
	#
	# 예전에는 한 줄짜리 Label 에 `"%d위   %s 타워   %s  (%d%%)"` 를 만들어 줄마다
	# **가운데 정렬**로 찍었다. 그래서 '1위' 와 '3위' 의 시작점이 다르고 피해 숫자가
	# 세로로 하나도 맞지 않아, 표가 아니라 문장 덩어리로 보였다. 비례폭 폰트에서는
	# 공백 몇 개로 칸을 맞출 수 없다 — 눈으로 훑을 수 있는 것은 칸 자체다.
	# 런 요약은 이 게임의 결산 화면이라, 여기서 "누가 일했나" 가 한눈에 안 들어오면
	# 요약의 뜻이 없다. 그래서 4열 격자로 바꾸고 수치는 오른쪽 정렬한다.
	var ranking = defense_field.damage_ranking()
	# 비중을 함께 적는다. 순위만으로는 "1위가 혼자 다 했다" 와
	# "셋이 비슷하게 나눠 했다" 가 구분되지 않는데, 그 둘은 완전히 다른 런이다.
	var total_dealt: float = defense_field.total_tower_damage()
	var rank_grid = GridContainer.new()
	rank_grid.columns = 4
	rank_grid.add_theme_constant_override("h_separation", 12)
	rank_grid.add_theme_constant_override("v_separation", 4)
	# 표는 패널 폭을 쓴다. 가운데로 모아 두면 양옆에 빈 칸만 남고, 이름과 수치가
	# 가까이 붙어 '1위가 얼마를 냈나' 를 한 줄에서 읽기 어려워진다.
	rank_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# §2.34 — 이 표만 **상한이 없다.** 줄 수가 '서로 다른 타워 단어' 수라 20~30줄이 평범하다
	# (런마다 초기화되지만 한 런 안에서도 3칸을 계속 갈아 끼운다).
	# 실측(`tools/ModalFitProbe` S1b · 1280×720): 12줄 656 · **20줄 784** · **30줄 944** px.
	# `_show_modal()` 이 중앙 정렬이라 넘칠 때 **위아래로 함께** 나가고, 그러면 결산 화면의
	# 주 행동인 `처음부터 다시하기` 가 아래로 통째로 사라진다(§2.34-2).
	# 표를 스크롤 그릇에 넣고 높이를 묶는다 — **내용을 줄이지 않으므로 정보 손실 0** 이고,
	# 앞으로 표가 더 늘어도 같은 결함이 재발하지 않는다(§2.32 의 '자동 줄바꿈' 과 같은 판단).
	var rank_scroll = ScrollContainer.new()
	# 가로는 묶지 않는다 — 표가 패널 폭을 그대로 쓰게 두고 세로만 스크롤한다.
	rank_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rank_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_scroll.add_child(rank_grid)
	summary_box.add_child(rank_scroll)
	_cap_scroll_height(rank_scroll, RANK_LIST_MAX_HEIGHT, modal)
	if ranking.is_empty():
		rank_grid.add_child(_summary_cell("기록된 피해 없음", HORIZONTAL_ALIGNMENT_LEFT, Palette.TX_SECONDARY))
	for i in range(ranking.size()):
		var share_pct := 0.0
		if total_dealt > 0.0:
			share_pct = float(ranking[i].damage) / total_dealt * 100.0
		rank_grid.add_child(_summary_cell("%d위" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, Palette.TX_SECONDARY))
		rank_grid.add_child(_summary_cell("%s 타워" % ranking[i].tower, HORIZONTAL_ALIGNMENT_LEFT, Palette.TX_PRIMARY))
		rank_grid.add_child(_summary_cell(NumText.comma(ranking[i].damage), HORIZONTAL_ALIGNMENT_RIGHT, Palette.TX_GOLD))
		rank_grid.add_child(_summary_cell("(%d%%)" % roundi(share_pct), HORIZONTAL_ALIGNMENT_RIGHT, Palette.TX_SECONDARY))

	# 순위표와 결산 항목 사이의 숨. 한 덩어리로 붙어 보이지 않게만 띄운다.
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	summary_box.add_child(gap)

	var meta_grid = GridContainer.new()
	meta_grid.columns = 2
	meta_grid.add_theme_constant_override("h_separation", 14)
	meta_grid.add_theme_constant_override("v_separation", 3)
	# 결산 항목은 표의 **왼쪽 끝**에 맞춘다. 가운데로 모으면 위의 표와 시작점이 어긋나
	# 두 덩어리로 흩어져 보인다.
	meta_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary_box.add_child(meta_grid)
	for row in [
		["도달 지점", "제 %d막 %d라운드" % [defense_field.current_act, defense_field.current_wave]],
		["보유 유물", "%d개" % owned_relics.size()],
		["벨트 활자", "%d개" % jamo_belt.jamo_list.size()],
	]:
		meta_grid.add_child(_summary_cell(str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, Palette.TX_SECONDARY))
		meta_grid.add_child(_summary_cell(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, Palette.TX_PRIMARY))

	# 역대 기록. 결산 화면에서 **바로** 보여야 의미가 있다 — "이번 런이 어디에 섰나" 는
	# 방금 끝낸 사람이 가장 알고 싶은 것이고, 다른 화면에 숨겨 두면 아무도 안 본다.
	# 순위 기준은 SaveManager.run_ranking_is_better 한 곳에만 있다(점수를 지어내지 않는다).
	var result := SaveManager.submit_run({
		"victory": is_victory,
		"act": defense_field.current_act,
		"wave": defense_field.current_wave,
		"total_damage": total_dealt,
		"base_hp": defense_field.base_hp,
		"max_base_hp": defense_field.max_base_hp,
		"towers": ranking.size(),
		"top_tower": str(ranking[0].tower) if not ranking.is_empty() else "",
	})
	var entries: Array = result.get("entries", [])
	var my_rank := int(result.get("rank", 0))
	var my_total := int(result.get("total", 0))
	var my_index := int(result.get("index", -1))

	var history_wrap = PanelContainer.new()
	history_wrap.theme_type_variation = "InsetPanel"
	vbox.add_child(history_wrap)
	var history_box = VBoxContainer.new()
	history_box.add_theme_constant_override("separation", 6)
	history_wrap.add_child(history_box)

	var history_title = Label.new()
	history_title.theme_type_variation = "HeadingLabel"
	history_title.text = "역대 기록 · %d회 중 %d위" % [my_total, my_rank]
	history_title.add_theme_font_size_override("font_size", 15)
	history_box.add_child(history_title)

	var history_grid = GridContainer.new()
	history_grid.columns = 4
	history_grid.add_theme_constant_override("h_separation", 12)
	history_grid.add_theme_constant_override("v_separation", 4)
	history_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_box.add_child(history_grid)
	for i in range(entries.size()):
		var item: Dictionary = entries[i]
		var is_mine := i == my_index
		var win := bool(item.get("victory", false))
		# 이번 런은 금색으로 도드라지게 한다 — 표에서 자기 줄을 못 찾으면 표가 아니다.
		var rank_color: Color = Palette.TX_GOLD if is_mine else Palette.TX_SECONDARY
		var reach_color: Color = Palette.TX_GOLD if is_mine else Palette.TX_PRIMARY
		history_grid.add_child(_summary_cell("%d위" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, rank_color))
		history_grid.add_child(_summary_cell("제 %d막 %dR" % [int(item.get("act", 1)), int(item.get("wave", 0))], HORIZONTAL_ALIGNMENT_LEFT, reach_color))
		history_grid.add_child(_summary_cell(NumText.comma(float(item.get("total_damage", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, reach_color))
		history_grid.add_child(_summary_cell("봉인" if win else "함락", HORIZONTAL_ALIGNMENT_RIGHT, rank_color))

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var btn_retry = Button.new()
	btn_retry.theme_type_variation = "PrimaryButton"
	btn_retry.text = "처음부터 다시하기"
	btn_retry.custom_minimum_size = Vector2(200, 44)
	btn_retry.pressed.connect(func(): start_new_game())
	btn_row.add_child(btn_retry)

	# ── 여운 (§2.8, §5.2 10) ─────────────────────────────────────────────
	# 여기까지 와서 곧바로 띄우면 패널이 **마지막 피해·보스 사망·전용음**을 덮는다.
	# 실측상 승리는 마지막 보스 사망과 정확히 겹쳐서, 60라운드를 끝낸 순간이
	# '패널이 뜬 순간' 과 같은 프레임이 된다. 그래서 등장을 `GAME_OVER_HOLD_SEC` 만큼
	# 늦춘다 — **모달은 지금 트리에 들어가고**(고아 노드·`_is_terminal_modal_open()`
	# 때문에 순서가 중요하다) 그동안 투명하다가 그 뒤에 팝인한다.
	# 자세한 이유와 안 고른 대안은 `_show_modal()` 의 `delay` 주석에 있다.
	_show_modal(modal, true, GAME_OVER_HOLD_SEC)


## 스크롤 그릇의 높이를 **내용 높이와 상한 중 작은 쪽**으로 맞추고, 패널을 다시 중앙에 놓는다.
##
## ⚠️ **한 프레임 뒤에 재야 한다.** 그 전에는 자식의 최소 크기가 아직 서지 않아 0 이 나오고,
##    그러면 `min(0, cap) = 0` 이 되어 표가 **통째로 사라진다**(조용히).
## ⚠️ **크기를 바꾼 쪽이 위치도 다시 잡아야 한다.** `_show_modal()` 은 호출 **시점**의 크기로
##    중앙을 계산하는데, 그때는 순위표가 아직 배치 전이라 높이가 0 에 가깝다(실측 468px).
##    상한을 나중에 주면 패널이 **커진 채 제자리**에 남아 아래로 삐져나간다(실측 94px).
## ⚠️ 두 프레임을 기다리는 비용은 화면에 안 보인다 — 모달은 이 시점에 이미 트리에 있지만
##    `GAME_OVER_HOLD_SEC` 동안 **투명**하므로, 크기·위치가 바뀌는 순간이 가려진다.
## ⚠️ `await` 을 안 붙이고 부른다(의도) — 결산 모달의 등장 순서를 이 함수가 붙잡으면
##    여운 연출이 함수 실행 시간에 묶인다.
func _cap_scroll_height(scroll: ScrollContainer, cap: float, panel: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(panel):
		return
	var inner: Control = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if inner == null:
		return
	scroll.custom_minimum_size = Vector2(0, minf(inner.get_combined_minimum_size().y, cap))
	# 크기가 바뀐 뒤 레이아웃이 한 번 더 돌아야 `panel.size` 가 선다 — 그 뒤에 위치를 잡는다.
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(panel):
		return
	var host: Vector2 = modal_layer.size
	if host.x <= 0.0 or host.y <= 0.0:
		host = get_viewport_rect().size
	panel.position = (host - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5


## 런 요약의 표 한 칸. 격자에 넣어 **열을 맞추는 것**이 목적이므로 폭을 스스로
## 주장하지 않는다(격자가 열 너비를 정한다). 정렬만 칸의 성격에 맞춰 준다 —
## 이름은 왼쪽, 수치는 오른쪽이라야 자릿수가 달라도 끝이 맞는다.
func _summary_cell(text: String, align: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


## 패배 문구. **왜 졌는지**를 말한다.
##
## 예전에는 승리/패배 두 문구뿐이라, 적 50마리 과부하로 끝난 런도 "활자의 빛이 꺼졌습니다…"
## 로만 보였다. 그 경우 기지 HP 는 가득 차 있을 수 있어서 — 화면 어디에도 근거가 없었다.
## 원인을 받아 문구를 고르는 순수 함수로 둔 것은, 이 문구가 이 게임에서 유일하게
## "왜 졌는가" 를 말하는 자리라 테스트로 잠가 둘 가치가 있기 때문이다.
func _defeat_verdict(reason: String) -> String:
	match reason:
		"overload":
			return "적 %d마리가 한꺼번에 몰려 기지가 과부하로 무너졌습니다." % DefenseField.MAX_ENEMIES
		"breach":
			return "적 %d마리가 기지를 통과했습니다." % DefenseField.MAX_BASE_HP
	return "활자의 빛이 꺼졌습니다…"
