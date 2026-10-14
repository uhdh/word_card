# WordTower.gd
# 자모 결합으로 자동 생성되는 단어 타워
class_name WordTower
extends Node2D

signal tower_clicked(tower: WordTower)

var word_data: Dictionary = {}
var syllable: String = ""

## 모든 타워가 setup_tower 에서 시작하는 사거리. 특성/유물이 여기서부터 곱해진다.
## DefenseField 가 '발판이 경로를 얼마나 덮는지' 를 계산할 때도 이 값을 쓴다.
## 발판 배치의 기본값이 이 사거리에 의존하므로 반드시 한 곳에서만 정의할 것.
const BASE_ATTACK_RANGE: float = 150.0

## ── 음절 길이 = 위력 ────────────────────────────────────────────────────────
## 예전에는 1→2→3음절이 '공격력 숫자' 만 키웠다(8 / 22 / 42). 화면에서는 똑같이
## 한 발씩 쏘는 게 보여서 강해진 느낌이 전혀 없었다.
## 이제 길이가 세 가지를 동시에 바꾼다:
##   (1) 한 번에 쏘는 발수  1 → 2 → 3   (화면에 여러 발이 보인다)
##   (2) 발사 간격 배수     1.0 → 0.85 → 0.70
##   (3) 투사체 크기        1.0 → 1.18 → 1.38
## 발당 피해는 BASE_DAMAGE_BY_LENGTH 로 낮춰, 총 DPS 는 기존과 비슷하게 유지한다.
## 실측(완성 단어 기준): 12.5 / 34.9 / 73.7 vs 기존 12.5 / 34.4 / 65.6.
## 즉 '한 발이 세지는' 게 아니라 '더 많이, 더 빠르게' 쏘는 방향으로 바꾼 것이다.
const VOLLEY_BY_LENGTH: Array[int] = [1, 2, 3]
const INTERVAL_MULT_BY_LENGTH: Array[float] = [1.0, 0.85, 0.70]
## 발당 피해. 발수·간격과 곱해져 총 DPS 가 나온다.
const BASE_DAMAGE_BY_LENGTH: Array[float] = [8.0, 9.5, 11.0]
const PROJECTILE_SCALE_BY_LENGTH: Array[float] = [1.0, 1.18, 1.38]

## 신속의 나침반이 올리는 **공격속도** 증가율(%). 상점 설명 "공격 속도 +20%" 와 같은 숫자다.
##
## 공격속도는 '초당 공격 횟수' 다 — 간격이 아니다. 그래서 간격에는 **역수**를 곱한다:
## `interval *= 0.8` 은 속도 +25% 이고, +20% 는 `interval /= 1.2` 다. 예전에는 앞의 것을
## 쓰면서 설명에는 뒤의 숫자를 적어 두었다(플레이어에게 유리한 방향이라 조용히 넘어갔다).
## 숫자는 여기 한 곳에만 두고 설명·라벨·테스트가 모두 이 상수를 읽는다.
const HASTE_COMPASS_SPEED_PCT := 20

@export var attack_range: float = 140.0
@export var attack_interval: float = 0.8
var attack_timer: float = 0.0

var projectile_scene = preload("res://scenes/tower/Projectile.tscn")
## 특성의 이름·색·아이콘 단일 출처. class_name 을 쓰지 않으므로 preload 한다
## (전역 클래스 캐시를 다시 만들지 않아도 되고, 참조 순환도 생기지 않는다).
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
var field_ref: Node = null
var magic_circle_time_left := 0.0
var attack_count := 0
var damage_multiplier := 1.0
var crit_chance := 0.0
var synergy_labels: Array = []
var base_damage := 4.0
var trait_id := "balanced"
## 공격 형태의 의미 라벨 (AttackStyle 이 정한다). 툴팁에 "불꽃" 처럼 표시된다.
var attack_style_label := ""
## 형태가 어디서 결정됐는지: "exact" / "rule" / "category" (AttackStyle.style_for 참고).
var attack_style_source := ""
## 이 타워가 쏘는 투사체 외형 키 (Projectile.TEXTURES).
var attack_proj_type := "bullet"
## 다중 타격 특성이 '한 번에 몇 마리' 를 때리는지. 특성 전용 유물이 여기를 늘린다.
## (예: 폭발의 뇌관 → 폭발 타워가 3 → 4 마리)
var bonus_targets := 0
## 화상 지속시간 배수. 발화 기름 유물이 올린다.
## 주의: 초당 피해(burn_dps)는 그대로 두고 '시간' 만 늘려야 총 화상 피해가 늘어난다.
var burn_duration_multiplier := 1.0
var is_hovered := false
var logical_slot_index := -1
var _drag_start := Vector2.ZERO
var _dragging := false
var _was_dragged := false
var _orbit_node: TowerOrbit = null
## 선회(orbit) 오브가 도는 방향. true = 화면상 시계 방향(기본값).
##
## 이 값을 타워가 들고 있는 이유: 방향은 '타워가 어떻게 때리는가' 의 일부라서
## 툴팁·정보창이 이 값을 읽어야 하고, 자모를 고쳐 타워가 다시 세워질 때
## DefenseField 가 이 값을 되돌려 놓아야 하기 때문이다.
var orbit_clockwise := true
## 조준 우선순위 — 타워를 세운 뒤에도 플레이어가 '무엇을 때릴지' 를 바꿀 수 있게 한다.
##
## 장르 표준을 따른다 (BTD 는 BTD3부터 First/Last/Close/Strong 4종을 20년째 유지한다).
## 기본값 "first" 는 예전과 같은 동작(진행도 최대)이라 손대지 않은 판은 그대로다.
##
## 선회(orbit) 타워에는 조준이 없다 — 오브가 스스로 때리고 _process 가 find_target 을
## 부르지 않는다. 그래서 우클릭은 선회 타워에서 방향 전환으로 남는다.
const TARGETING_MODES: Array[String] = ["first", "last", "strong", "close"]
## 조준 모드 → 화면에 보이는 이름. 툴팁·정보창이 같은 표를 쓴다.
const TARGETING_NAMES := {
	"first": "진급 우선", "last": "후미 우선",
	"strong": "강적 우선", "close": "근접 우선",
}
## 조준 모드 → 한 줄 설명. 이름만으로는 무엇을 고르는지 알 수 없다.
##
## 설명 안에서는 `—` 를 쓰지 않는다. 화면에는 `조준: <이름> — <설명>` 으로 이어 붙기
## 때문에, 설명에도 대시가 있으면 `진급 우선 — … 노린다 — 새는 적을 …` 처럼
## 대시가 두 번 겹쳐 어디까지가 이름인지 읽히지 않는다.
const TARGETING_DESCS := {
	"first": "기지에 가장 가까운 적을 노린다. 새는 적을 먼저 막는다.",
	"last": "가장 뒤처진 적을 노린다. 뒤에 쌓인 무리를 정리한다.",
	"strong": "체력이 가장 높은 적을 노린다. 중갑·보스를 먼저 뚫는다.",
	"close": "가장 가까운 적을 노린다. 붙은 적을 즉시 떼어낸다.",
}
var targeting_mode := "first"
## 특성 id → 한국어 이름. 실제 표는 TraitStyle 에 있다 (단일 출처).
## 여기서 다시 적어 두면 반드시 어긋난다 — 예전에 TowerInfoModal 이 자기 표를
## 따로 들고 있다가 선회/유성을 빠뜨려 배지가 ◆ 로 떨어졌다.
const TRAIT_NAMES := TraitStyle.NAMES
## 특성별 한 줄 설명. 툴팁에서 '이 타워가 어떻게 때리는지'를 바로 알려준다.
const TRAIT_DESCS := TraitStyle.DESCRIPTIONS
## 선회 특성의 오브 개수 — 음절이 길수록 많이 돈다.
const ORBIT_ORBS_BY_LENGTH := [1, 2, 3]
## 특성별 기본 사거리/발사 간격.
## 카테고리가 아니라 '실제로 어떻게 때리는지' 에 맞춘다 — 의미 태그가 카테고리를
## 덮어쓸 수 있게 되면서(예: weapon 단어가 번개로 판정) 카테고리 기준 값이
## 엉뚱하게 붙는 것을 막는다. 값 자체는 예전 카테고리 규칙과 동일하다.
const TRAIT_RANGE: Dictionary = {
	"sniper": 230.0, "pierce": 105.0, "rapid": 125.0, "control": 290.0, "chain": 185.0,
	"splash": 135.0, "damage_over_time": 150.0, "meteor": 175.0, "orbit": 76.0,
	"bounce": 150.0, "balanced": 150.0,
}
const TRAIT_INTERVAL: Dictionary = {
	"sniper": 1.6, "pierce": 1.0, "rapid": 0.3, "control": 1.2, "chain": 0.9,
	"splash": 1.1, "damage_over_time": 0.8, "meteor": 2.2, "orbit": 0.9,
	"bounce": 0.8, "balanced": 0.8,
}
## 유성이 떨어지는 지점의 흩어짐(px). 0이면 항상 적 위에 정확히 떨어진다.
const METEOR_SCATTER := 34.0
## 유성 폭발 반지름(px).
const METEOR_BLAST_RADIUS := 64.0
## 유성 낙하 시간(초).
const METEOR_FALL_TIME := 0.55

@onready var icon_container: CenterContainer = $IconContainer
@onready var icon_sprite: TextureRect = $IconContainer/IconSprite
@onready var label_big_word: Label = $LabelBigWord
@onready var label_word: Label = $LabelWord
@onready var range_circle: Node2D = $RangeCircle
@onready var btn_select: Button = $BtnSelect
var _trait_badge_canvas: Node2D = null

class TraitBadgeCanvas extends Node2D:
	var tower: WordTower
	func _init(p_tower: WordTower) -> void:
		tower = p_tower
		z_index = 2
	func _draw() -> void:
		if is_instance_valid(tower):
			tower._draw_trait_badge_on(self)

func _ready() -> void:
	attack_timer = 0.0
	_apply_visual_style()
	_trait_badge_canvas = TraitBadgeCanvas.new(self)
	add_child(_trait_badge_canvas)
	if btn_select:
		# 클릭과 드래그를 gui_input 한 곳에서 모두 처리한다.
		# Button.pressed 를 같이 쓰면 드래그 직후의 첫 클릭이 삼켜졌다.
		btn_select.gui_input.connect(_on_drag_input)
		btn_select.mouse_entered.connect(_set_hovered.bind(true))
		btn_select.mouse_exited.connect(_set_hovered.bind(false))

func _set_hovered(value: bool) -> void:
	is_hovered = value
	if value:
		btn_select.tooltip_text = _build_tooltip()
	queue_redraw()
	if _trait_badge_canvas != null:
		_trait_badge_canvas.queue_redraw()


## 툴팁 문구. 호버와 '선회 방향 전환' 이 같은 문구를 쓰도록 분리했다 —
## 방향을 바꾼 뒤 툴팁이 예전 방향을 계속 말하면 안 된다.
func _build_tooltip() -> String:
	var trait_line: String = TRAIT_NAMES.get(trait_id, trait_id)
	if attack_style_label != "":
		# "무기 분류 · 관통" 처럼 읽히게 한다. 뜻에서 온 경우와 구분된다.
		var prefix := "%s 분류" % attack_style_label if attack_style_source == "category" else attack_style_label
		trait_line = "%s · %s" % [prefix, trait_line]
	if TRAIT_DESCS.has(trait_id):
		# ⚠️ §2.18 · §5.2 29 (C) — `TRAIT_DESCS` 는 **행동 설명만** 담는다. 상성은 표에서
		#    유도해야 하므로 `trait_full_desc()` 를 거친다(손으로 적으면 드리프트한다).
		trait_line += " — " + MonsterRoster.trait_full_desc(trait_id)
	var shots := volley_count()
	var per_hit := damage_per_attack() * damage_multiplier
	var stats := "공격력 %.1f | 사거리 %d | 간격 %.2f초" % [per_hit, int(attack_range), attack_interval]
	if shots > 1:
		# 발수가 늘어난 타워는 '한 번에 몇 발이 나가는지' 를 먼저 보여준다.
		stats = "공격력 %.1f (%d발 × %.1f) | 사거리 %d | 간격 %.2f초" % [
			per_hit * float(shots), shots, per_hit, int(attack_range), attack_interval]
	if bonus_targets > 0:
		# ⚠️ **`3 + bonus_targets` 를 그냥 적으면 2·3음절에서 거짓이다** — 그 경로는
		#    `bonus_targets` 를 읽지 않는다(`target_bonus_applies()` 참조). 실제로 나가는
		#    발수를 적는다: 1음절은 3+bonus, 2·3음절은 발수 그대로. **둘 다 참이다.**
		#    `test_wave_balance` 의 *"A widened multi-hit must be stated on the tooltip"*
		#    계약은 이 줄이 **있는 것**을 요구한다(2음절 '바위' 로 검사한다) — 지우면 안 된다.
		stats += "\n동시 타격 %d마리" % (3 + bonus_targets if target_bonus_applies() else shots)
	# 치명타는 매 발마다 굴리는 값인데 지금까지 화면 어디에도 없었다.
	# 유물(수정 렌즈·사거리 룬)로 올린 값이 보이지 않으면 산 보람을 알 수 없다.
	var crit := total_crit_chance()
	if crit > 0.0:
		stats += "\n치명타 %.0f%% (피해 2배)" % (crit * 100.0)
	if trait_id == "orbit":
		# 도는 방향은 화면에서 보이긴 하지만, '바꿀 수 있다' 는 것은 보이지 않는다.
		# 이 기능이 있는지조차 모르면 없는 것과 같다.
		stats += "\n↻ 선회 방향: %s (우클릭으로 전환)" % orbit_direction_label()
	else:
		# 조준은 방향과 다르다 — '진급 우선' 같은 이름만으로는 무엇을 고르는지 알 수 없다.
		# 그래서 이름과 설명을 함께 적는다. 설명 없이 이름만 두면 네 모드의 차이를
		# 알 방법이 없어 기능이 없는 것과 같아진다.
		stats += "\n🎯 조준: %s — %s (우클릭으로 전환)" % [targeting_label(), targeting_desc()]
	# 시너지는 '붙어 있다' 는 사실만으로는 아무 의미가 없다 — 툴팁에 보여야
	# 플레이어가 배치와 유물 구매를 그걸 기준으로 결정할 수 있다.
	var synergy_line := ""
	if not synergy_labels.is_empty():
		synergy_line = "\n✦ " + " / ".join(synergy_labels)
	return "%s\n%s\n[%s]\n%s%s" % [
		syllable, word_data.get("desc", ""), trait_line, stats, synergy_line]

func setup_tower(p_syllable: String, p_data: Dictionary, p_field: Node, show_magic_circle := false, p_logical_slot := -1) -> void:
	syllable = p_syllable
	word_data = p_data.duplicate()
	field_ref = p_field
	logical_slot_index = p_logical_slot
	magic_circle_time_left = 0.8 if show_magic_circle else 0.0

	var has_icon = word_data.get("icon", "") != "" and ResourceLoader.exists(word_data.get("icon", ""))
	var is_unknown = word_data.get("is_unknown", false) or not has_icon

	if is_unknown:
		if icon_container: icon_container.visible = false
		if label_word: label_word.visible = false
		if label_big_word:
			label_big_word.visible = true
			label_big_word.text = syllable
	else:
		if icon_container: icon_container.visible = true
		if label_word:
			label_word.visible = true
			label_word.text = syllable
		if label_big_word: label_big_word.visible = false
		if icon_sprite:
			icon_sprite.texture = load(word_data["icon"])

	var level := clampi(syllable.length(), 1, VOLLEY_BY_LENGTH.size())
	attack_range = BASE_ATTACK_RANGE
	attack_interval = 0.8
	base_damage = BASE_DAMAGE_BY_LENGTH[level - 1]
	if not word_data.get("is_unknown", false):
		base_damage *= 1.25

	# ── 공격 형태는 '단어의 뜻' 이 정한다 ──
	# 예전에는 category 만 보고 정했고, 3음절이면 무조건 meteor/orbit 로 승격시켜
	# 단어 뜻을 지웠다. 이제 의미 키워드가 우선이고 카테고리는 폴백이다.
	var cat = word_data.get("category", "weapon")
	var style := AttackStyle.style_for(syllable, word_data)
	trait_id = str(style["trait"])
	attack_proj_type = str(style["proj"])
	attack_style_label = str(style["label"])
	# 형태가 어디서 왔는지 (exact / rule / category). 폴백일 때 문구를 바꿔 보여 준다.
	attack_style_source = str(style.get("source", ""))
	attack_range = float(TRAIT_RANGE.get(trait_id, BASE_ATTACK_RANGE))
	attack_interval = float(TRAIT_INTERVAL.get(trait_id, 0.8))
	# 길이가 발사 간격을 줄인다 — "긴 단어일수록 빠르게 쏜다".
	attack_interval *= INTERVAL_MULT_BY_LENGTH[level - 1]

	synergy_labels.append("특성: %s" % TRAIT_NAMES.get(trait_id, trait_id))
	if attack_style_label != "":
		# 단어 뜻에서 온 형태와, 분류(카테고리)에서 온 형태를 구분해 보여 준다.
		# 구분하지 않으면 플레이어는 "왜 이 단어가 이렇게 공격하지?" 를 알 수 없다.
		if attack_style_source == "category":
			synergy_labels.append("형태: %s 분류" % attack_style_label)
		else:
			synergy_labels.append("뜻: %s" % attack_style_label)

	# ── 형태의 결 — 단어 모양이 **유물 없이도** 작게 작동한다 ──
	# 유물(아래)보다 **먼저** 붙인다. 툴팁에서 "이 단어가 원래 그런 것" 이 "내가 산 것"
	# 보다 앞에 와야, 플레이어가 유물을 사기 전에 형태 축을 먼저 배운다.
	var shape = WordSynergy.native_shape_bonuses(syllable)
	damage_multiplier *= shape["damage"]
	attack_interval *= shape["interval"]
	attack_range *= shape["range"]
	synergy_labels.append_array(shape["labels"])

	var bonus = WordSynergy.bonuses(syllable, field_ref.relic_ids)
	damage_multiplier *= bonus["damage"]
	attack_interval *= bonus["interval"]
	attack_range *= bonus["range"]
	crit_chance += bonus["crit"]
	synergy_labels.append_array(bonus["labels"])
	# 여기 있던 두 줄(천리안의 룬 → 무기 타워 치명타 +10%, 선봉의 깃털 → 소환 타워 3배)은
	# **설명에 없는 효과**였다. 상점 설명은 골드를 내고 사는 사람이 읽는 유일한 계약이므로,
	# 코드를 설명에 맞춰 지웠다(디렉터 지시: "설명과 코드를 일치시켜줘. 설명에 맞춰").
	# 천리안의 룬은 이제 범위 +15% 하나, 선봉의 깃털은 첫 공격 2배 하나만 한다.
	if field_ref.has_relic("relic_first_strike"):
		# 첫 공격 배수는 전투 중에만 드러난다 — 라벨이 없으면 이 유물은 정보창에서
		# 아무 흔적도 남기지 않는다(폭발의 뇌관·발화 기름 같은 전투 유물은 모두 라벨이 있다).
		synergy_labels.append("선봉의 깃털 (첫 공격 2배)")
	# `치유 증폭` 라벨은 여기 있었다. 그 라벨이 가리키던 효과(치유 타워가 있으면
	# 회복의 향로가 +1 더 회복)는 상점 설명에 없어서 지웠다(DefenseField._grant_round_reward).
	# 효과가 사라졌으므로 라벨도 지운다 — 남겨 두면 '증폭되고 있다' 는 거짓말이 된다.
	# '모든 활자 타워' 에 걸리는 상점 유물. WordSynergy.bonuses 는 음절 모양(된소리/받침 등)에
	# 따라 걸리는 유물만 다루므로, 조건 없는 전역 유물은 여기서 적용한다.
	if field_ref.has_relic("relic_essence_power"):
		damage_multiplier *= 1.2
		synergy_labels.append("활자의 정수 (+20% 피해)")
	if field_ref.has_relic("relic_haste_compass"):
		# 설명은 '공격 속도 +20%' 다. 간격에 0.8 을 곱하면 속도는 +25% 가 되므로 역수를 쓴다.
		attack_interval *= WordSynergy.speed_pct_to_interval(HASTE_COMPASS_SPEED_PCT)
		synergy_labels.append("신속의 나침반 (+%d%% 속도)" % HASTE_COMPASS_SPEED_PCT)

	# ── 공격 특성 전용 유물 ────────────────────────────────────────────────
	# '무슨 형태로 때리는가' 를 강화한다. 그래서 유물을 사기 전에
	# 내 타워가 무슨 특성인지 보는 것이 의미를 갖는다.
	# ⚠️ **'대상 +1' 은 이 타워에서 실제로 쓰일 때만 적는다**(§2.7 (A), 2026-10-03).
	#    2·3음절은 `_volley_targets()` 를 타서 `bonus_targets` 를 안 읽는다 — 그런데도
	#    라벨이 '+1' 을 약속하면 툴팁의 '동시 타격 N마리' 와 **한 화면 안에서 모순**된다.
	#    판단은 `target_bonus_applies()` 하나가 한다(문구를 두 번 적지 않는다).
	var target_suffix := ", 대상 +1" if target_bonus_applies() else ""
	if field_ref.has_relic("relic_blast_charge") and trait_id == "splash":
		damage_multiplier *= 1.25
		bonus_targets += 1
		synergy_labels.append("폭발의 뇌관 (+25%% 피해%s)" % target_suffix)
	if field_ref.has_relic("relic_chain_loom") and trait_id == "chain":
		damage_multiplier *= 1.15
		bonus_targets += 1
		synergy_labels.append("연쇄의 베틀 (+15%% 피해%s)" % target_suffix)
	if field_ref.has_relic("relic_pierce_auger") and trait_id == "pierce":
		attack_range *= 1.1
		bonus_targets += 1
		synergy_labels.append("관통 송곳 (사거리 +10%%%s)" % target_suffix)
	if field_ref.has_relic("relic_burn_oil") and trait_id == "damage_over_time":
		burn_duration_multiplier *= 1.5
		synergy_labels.append("발화 기름 (화상 +50% 지속)")
	# 선회 오브 수는 _setup_attack_style 이 읽는다 (아래에서 호출된다).
	if field_ref.has_relic("relic_orbit_gear") and trait_id == "orbit":
		synergy_labels.append("선회의 톱니 (오브 +1)")

	_apply_visual_style()
	_setup_attack_style()
	queue_redraw()


## 특성에 맞는 '공격 방식' 노드를 붙인다.
## 대부분은 투사체를 쏘지만, 선회(orbit)는 궤도를 도는 오브가 직접 때리므로
## 타워가 아니라 이 노드가 피해를 준다.
func _setup_attack_style() -> void:
	if _orbit_node != null and is_instance_valid(_orbit_node):
		_orbit_node.queue_free()
	_orbit_node = null
	if trait_id != "orbit":
		return
	_orbit_node = TowerOrbit.new()
	_orbit_node.name = "Orbit"
	var level := clampi(syllable.length(), 1, ORBIT_ORBS_BY_LENGTH.size())
	add_child(_orbit_node)
	# 선회의 톱니 유물은 음절 길이와 무관하게 오브를 하나 더 돌린다.
	# (ORBIT_ORBS_BY_LENGTH 는 untyped const Array 라 원소가 Variant 다 → 명시적 int)
	var orbs: int = int(ORBIT_ORBS_BY_LENGTH[level - 1])
	if field_ref != null and field_ref.has_relic("relic_orbit_gear"):
		orbs += 1
	_orbit_node.setup(self, orbs, orbit_clockwise)


## 선회 방향을 정한다. 타워를 다시 세우지 않고 지금 도는 오브에 바로 반영한다.
func set_orbit_direction(p_clockwise: bool) -> void:
	orbit_clockwise = p_clockwise
	if _orbit_node != null and is_instance_valid(_orbit_node):
		_orbit_node.set_clockwise(p_clockwise)
	if btn_select != null:
		btn_select.tooltip_text = _build_tooltip()


## 지금 도는 방향을 글로. 툴팁·정보창이 같은 문구를 쓰도록 한 곳에서 만든다.
func orbit_direction_label() -> String:
	return "시계 방향" if orbit_clockwise else "반시계 방향"


## 선회 타워의 방향을 뒤집는다.
##
## 두 단계로 나눠서 한다:
##   (1) 내 오브를 직접 뒤집는다 — 플레이어가 누른 결과는 반드시 일어나야 한다.
##   (2) 필드에 '이 슬롯은 이 방향' 이라고 알린다.
## 필드에만 맡기면, 필드가 이 타워를 목록에서 못 찾는 순간 클릭이 조용히 씹힌다.
## 반대로 (2) 를 빼면, 자모를 고쳐 타워가 다시 세워질 때 선택이 사라진다.
func toggle_orbit_direction() -> void:
	if trait_id != "orbit":
		# 오브가 없는 타워에는 뒤집을 방향이 없다.
		return
	var next := not orbit_clockwise
	set_orbit_direction(next)
	if is_instance_valid(field_ref) and field_ref.has_method("remember_orbit_direction"):
		field_ref.remember_orbit_direction(logical_slot_index, next)
	SoundEngine.play_tile_click()


## 조준 우선순위를 다음 것으로 돌린다.
##
## 선회 타워는 조준 자체가 없으므로(오브가 스스로 때린다) 여기서 아무 일도 하지 않는다 —
## 그래야 우클릭이 선회 타워에서 방향 전환으로 남는다.
##
## 두 단계로 나눠서 한다(선회 방향과 같은 이유):
##   (1) 내 조준을 바꾼다 — 플레이어가 누른 결과는 반드시 일어나야 한다.
##   (2) 필드에 '이 슬롯은 이 조준' 이라고 알린다.
func cycle_targeting_mode() -> void:
	if trait_id == "orbit":
		return
	var i := TARGETING_MODES.find(targeting_mode)
	targeting_mode = TARGETING_MODES[(i + 1) % TARGETING_MODES.size()]
	if is_instance_valid(field_ref) and field_ref.has_method("remember_targeting_mode"):
		field_ref.remember_targeting_mode(logical_slot_index, targeting_mode)
	if btn_select != null:
		btn_select.tooltip_text = _build_tooltip()
	SoundEngine.play_tile_click()


## 조준 모드를 직접 정한다. 모르는 id 는 무시한다 — 오타 하나가 타워를 조용히
## 기본값으로 되돌리면 안 된다.
func set_targeting_mode(p_mode: String) -> void:
	if not TARGETING_MODES.has(p_mode):
		return
	targeting_mode = p_mode
	if btn_select != null:
		btn_select.tooltip_text = _build_tooltip()


## 지금 조준의 이름. 툴팁·정보창이 같은 문구를 쓰도록 한 곳에서 만든다.
func targeting_label() -> String:
	return str(TARGETING_NAMES.get(targeting_mode, targeting_mode))


## 지금 조준이 무엇을 고르는지. 이름만으로는 알 수 없어서 설명이 필요하다.
func targeting_desc() -> String:
	return str(TARGETING_DESCS.get(targeting_mode, ""))


## 선회 오브 한 대의 피해. 오브는 계속 때리므로 1회 피해는 낮게 잡는다.
func orbit_damage() -> float:
	return damage_per_attack() * damage_multiplier

func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_drag(get_global_mouse_position())
		else:
			end_drag(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 우클릭 = 선회 타워는 방향 전환, 나머지는 조준 우선순위 전환.
		# 좌클릭(선택/이동)과 겹치지 않고, 정보창을 열지 않아도 되므로 화면을 가리지
		# 않고 결과를 바로 볼 수 있다. 선회 타워에는 조준이 없어서 둘은 겹치지 않는다.
		if trait_id == "orbit":
			toggle_orbit_direction()
		else:
			cycle_targeting_mode()
	elif event is InputEventMouseMotion and _dragging:
		update_drag(get_global_mouse_position())


## 드래그 시작. (좌표를 직접 넣을 수 있게 입력 이벤트와 분리했다 — 테스트용)
func begin_drag(at: Vector2) -> void:
	_drag_start = at
	_dragging = true
	_was_dragged = false


## 드래그 중. 6px 넘게 움직여야 실제 이동으로 인정한다.
func update_drag(at: Vector2) -> void:
	if not _dragging:
		return
	if not _was_dragged and at.distance_to(_drag_start) > 6.0:
		_was_dragged = true
		_set_drag_lift(true)
	if _was_dragged:
		global_position = at


## 드래그 종료 → 이동 확정, 아니면 클릭으로 처리.
func end_drag(at: Vector2) -> void:
	# 예전에는 _was_dragged 를 Button.pressed 콜백에서만 풀어서,
	# 드래그가 버튼 밖에서 끝나면 이후 첫 클릭이 계속 씹혔다.
	var dragged := _was_dragged
	_dragging = false
	_was_dragged = false
	_set_drag_lift(false)
	if dragged:
		if field_ref != null:
			field_ref.move_tower_to_nearest(logical_slot_index, at)
	else:
		SoundEngine.play_tile_click()
		tower_clicked.emit(self)


## 드래그 중인 타워가 다른 타워 위로 떠 보이게 한다.
func _set_drag_lift(value: bool) -> void:
	z_index = 60 if value else 0
	modulate = Color(1.2, 1.2, 1.2, 1.0) if value else Color.WHITE

func _process(delta: float) -> void:
	if magic_circle_time_left > 0.0:
		magic_circle_time_left -= delta
		if magic_circle_time_left <= 0.0:
			queue_redraw()

	if word_data.is_empty() or field_ref == null:
		return

	# 선회(orbit)는 궤도 오브가 스스로 때린다 — 타워는 쏘지 않는다.
	if trait_id == "orbit":
		return

	attack_timer += delta
	if attack_timer >= attack_interval:
		var target = find_target()
		if target != null:
			attack_target(target)
			attack_timer = 0.0

## 사거리 안의 적 중 조준 우선순위가 가장 높은 하나를 고른다.
##
## 예전에는 `progress` 최대(기지에 가장 가까운 적) 하나뿐이었다. 그래서 타워를 세운 뒤
## 플레이어가 손댈 것이 하나도 없었다 — 같은 타워도 '무엇을 때리느냐' 로 성능이
## 완전히 달라지는데, 그 선택이 아예 존재하지 않았다.
func find_target() -> EnemyUnit:
	if field_ref == null:
		return null
	var enemies = field_ref.get_enemies()
	var best_target: EnemyUnit = null
	var best_score: float = 0.0

	for e in enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist > attack_range:
			continue
		var score := _targeting_score(e, dist)
		if best_target == null or score > best_score:
			best_score = score
			best_target = e

	return best_target


## 조준 점수 — 클수록 우선. 모드가 바뀌어도 '무엇을 고르는가' 만 바뀌고
## 사거리 판정은 그대로다(사거리 밖 적은 위 루프에서 이미 걸러진다).
func _targeting_score(e: EnemyUnit, dist: float) -> float:
	match targeting_mode:
		"last":
			return -e.progress
		"strong":
			# 체력이 같으면 기지에 가까운 쪽을 고른다 — 0.001 은 그 동점 처리용이다.
			return e.hp + e.progress * 0.001
		"close":
			return -dist
		_:
			return e.progress

## 첫 공격 배수(선봉의 깃털).
##
## 상점 설명은 "각 타워의 첫 공격 피해 2배" 다. 예전에는 **소환 타워만 3배** 라는 예외가
## 있었는데, 그 예외가 설명 어디에도 없었다 — 소환 덱을 짜는 사람은 자기가 이 유물의
## 절반만 알고 사는 셈이었다. 디렉터 지시("설명과 코드를 일치시켜줘. 설명에 맞춰")에 따라
## 예외를 지우고 설명대로 **모든 타워 2배** 로 맞췄다.
##
## 순수 함수다 — `attack_count` 를 건드리지 않는다(호출자가 증가시킨다).
func first_strike_multiplier() -> float:
	if field_ref == null or not field_ref.has_relic("relic_first_strike"):
		return 1.0
	if attack_count != 0:
		return 1.0
	return 2.0


## 3글자 이상 타워의 피해 배수(삼문자 인장).
##
## 상점 설명은 "3글자 타워 피해 +25%" 다 — **3글자 이상**이라는 말은 없다.
## `syllable.length() >= 3` 이 그 뜻이므로 4·5음절도 포함된다. 설명대로다.
##
## 순수 함수다 — `attack_target` 이 매 공격마다 부른다(테스트가 직접 부를 수 있다).
func three_syllable_multiplier() -> float:
	if field_ref == null or not field_ref.has_relic("relic_three_syllable_seal"):
		return 1.0
	return 1.25 if syllable.length() >= 3 else 1.0


## 치명타가 터졌을 때의 피해 배수.
##
## 상점 설명(예리한 렌즈 "25% 확률로 2배 치명타")이 이 숫자를 말한다. 확률은
## `total_crit_chance()`, 배수는 여기 — 둘을 한 곳에 두어 설명·코드가 어긋나지 않게 한다.
const CRIT_DAMAGE_MULT := 2.0

func attack_target(target: EnemyUnit) -> void:
	# ✅ **§2.21-6 고침 (2026-10-01)** — 굴림을 **분기 앞으로** 옮겼다. 예전에는 유성이
	#    첫 줄에서 `_cast_meteor()` 로 빠져나가 **아래 굴림에 도달하지 못했고**, 선회는
	#    `attack_target()` 자체를 안 타서 둘 다 굴리지 않았다 → 유물 `예리한 렌즈`(35 G)의
	#    *"타워 공격 시 25% 확률로 2배 치명타"* 계약이 **그 두 특성에서 거짓**이었다.
	#    이제 세 경로가 **같은 문**(`roll_crit()`)을 지난다.
	var is_crit := roll_crit()

	# 유성은 '조준 사격'이 아니라 '하늘에서 떨어지는 광역기'라 타깃팅이 다르다.
	if trait_id == "meteor":
		# 유성은 **한 발**이다 — 굴림도 한 번이고, 광역에 맞은 적들이 **함께** 2배가 된다.
		_cast_meteor(is_crit)
		return

	var damage = damage_per_attack() * damage_multiplier
	damage *= three_syllable_multiplier()
	damage *= first_strike_multiplier()
	attack_count += 1
	# §2.21 (A) — 치명타 **여부**를 아래로 내려보낸다. 예전에는 여기서 피해만 2배로 만들고
	#   끝이라, 화면은 '치명타가 났는가' 가 아니라 '피해가 60 을 넘었는가' 로 판단했다.
	#   그래서 진짜 치명타가 안 보이고(약한 타워), 치명타가 아닌 큰 한 방이 치명타처럼 보였다.
	damage = crit_damage(damage, is_crit)

	# 공격 형태(투사체 외형)는 '단어의 뜻' 이 정해 둔 값을 그대로 쓴다.
	# 예전에는 여기서 카테고리를 다시 보고 match trait_id 로 덮어써서,
	# AttackStyle 이 의미로 정한 외형(예: 돌 → bullet)이 지워졌다.
	var proj_type := attack_proj_type if attack_proj_type != "" else "bullet"
	_play_attack_sound()

	if projectile_scene == null or field_ref == null:
		return

	var volley := volley_count()
	if volley <= 1:
		# 1음절(그리고 유성/선회): 예전과 완전히 동일한 경로.
		# 여러 적을 때리는 특성은 '한 발씩 나눠서' 총량을 유지한다.
		var targets := _trait_targets(target)
		var shares := damage_shares(targets.size(), damage)
		for i in targets.size():
			_fire_projectile(targets[i], shares[i], proj_type, is_crit)
		return

	# 2음절·3음절: 화면에 여러 발이 '동시에' 날아간다.
	# 발당 피해는 그대로 두고 발수만 늘린다 — "더 세게" 가 아니라 "더 많이" 로 강해진다.
	for enemy in _volley_targets(target, volley):
		_fire_projectile(enemy, damage, proj_type, is_crit)


## 카테고리별 발사음. 예전에는 투사체 외형을 정하는 분기 안에 섞여 있었는데,
## 외형을 AttackStyle 이 맡으면서 소리만 따로 남겼다.
func _play_attack_sound() -> void:
	match word_data.get("category", "weapon"):
		"element": SoundEngine.play_magic()
		"summon": SoundEngine.play_summon()
		_: SoundEngine.play_attack()


## 한 번의 공격에서 쏘아지는 투사체 수.
## '음절이 길수록 화면에 여러 발이 보인다' 가 목적이라 발수만 늘린다.
## 유성은 한 발짜리 광역 낙하라 늘리지 않는다(늘리면 화면이 광역기로 덮인다).
## 선회는 궤도 오브가 직접 때리므로 애초에 쏘지 않는다(1을 돌려준다).
func volley_count() -> int:
	if trait_id == "meteor" or trait_id == "orbit":
		return 1
	var level := clampi(syllable.length(), 1, VOLLEY_BY_LENGTH.size())
	return VOLLEY_BY_LENGTH[level - 1]


## 특성 전용 유물이 약속한 **'대상 +1' 이 이 타워에서 실제로 쓰이는가.**
##
## ⚠️ **§2.7 (A) — 2026-10-03 고침.** `bonus_targets` 는 `attack_target()` 의 `volley <= 1`
##    분기에서만 불리는 `_trait_targets()` 의 상한에서 읽힌다 — **2·3음절은
##    `_volley_targets()` 를 타서 이 값을 아무 데도 안 쓴다.** 그런데 툴팁
##    (*"동시 타격 4마리"*)과 시너지 라벨(*"대상 +1"*)은 1·2·3음절 모두에게 그렇게
##    말하고 있었다 — **거짓**이었다. `tools/TraitBlastProbe` 실측: 2음절 4≠2 · 3음절 4≠3.
##
##    문구를 두 곳에 손으로 적는 대신 **이 함수 하나**를 근거로 삼는다(§2.18 과 같은 처방).
##    ⚠️ 밸런스는 안 바뀐다 — 표시 문구만 진실이 된다. **로직을 설명 쪽으로 올리는 (B)**
##    (2·3음절도 `bonus_targets` 만큼 더 때리게 하는 것)는 밸런스 변경이라 **감독 몫**이다.
func target_bonus_applies() -> bool:
	return volley_count() <= 1


## 투사체 크기 배수. 길이가 길수록 탄이 굵어져 '여러 발 + 큰 탄' 이 한눈에 보인다.
func projectile_scale() -> float:
	var level := clampi(syllable.length(), 1, PROJECTILE_SCALE_BY_LENGTH.size())
	return PROJECTILE_SCALE_BY_LENGTH[level - 1]


## 사거리 안에서 '서로 다른' 적을 최대 count 마리 고른다 (진행도 높은 순).
## 적이 모자라면 주 타깃으로 채운다 — 여러 발이 한 적에게 집중되는 연출이 되고,
## 발수만큼 피해가 들어가므로 '긴 단어가 확실히 세다' 는 것이 화면으로 읽힌다.
func _volley_targets(primary: EnemyUnit, count: int) -> Array[EnemyUnit]:
	var result: Array[EnemyUnit] = [primary]
	if count <= 1 or field_ref == null:
		return result
	var rest: Array[EnemyUnit] = []
	for enemy in field_ref.get_enemies():
		if not is_instance_valid(enemy) or enemy.is_dead or enemy == primary:
			continue
		if _in_reach(primary, enemy):
			rest.append(enemy)
	rest.sort_custom(func(a, b): return a.progress > b.progress)
	for enemy in rest:
		if result.size() >= count:
			break
		result.append(enemy)
	while result.size() < count:
		result.append(primary)
	return result


## 특성별 발당 피해 배율.
##
## **표를 static 으로 꺼내 둔 이유**: 힌트와 도감도 '이 단어가 실제로 센가' 를 알아야
## 한다. 인스턴스 안에만 두면 바깥에서 같은 표를 베껴 쓰게 되고, 한쪽만 고쳐지는
## 순간 화면의 숫자와 전장의 숫자가 갈라진다 — DB 의 `damage` 필드가 정확히 그렇게
## 죽어 있었다(아무도 읽지 않는 숫자를 힌트와 도감이 1위 기준으로 쓰고 있었다).
##
## 매개변수 이름이 `trait_id` 인 이유: `trait` 은 Godot 4.4+ 의 예약어라
## 매개변수 이름으로 쓰면 "Expected parameter name." 파싱 에러가 난다.
static func trait_damage_multiplier(trait_id: String) -> float:
	match trait_id:
		"sniper": return 2.6
		"splash": return 1.35
		"rapid": return 0.38
		"pierce": return 1.9
		"control": return 0.55
		"chain": return 0.85
		# 선회는 '여러 대' 로 값을 치른다. 0.35 는 '초당 여러 대 맞는다' 는 전제였는데,
		# 실측(tools/OrbitBalanceProbe.gd)에서 적 한 마리가 지나가는 동안 실제로는
		# 1대밖에 안 들어갔다 — 전제가 틀렸으니 배율도 틀렸다.
		#
		# 다만 '적 한 마리' 기준으로만 맞추면 안 된다. 선회는 사거리 안의 **모든** 적을
		# 동시에 때리고 과잉 피해(오버킬)를 한 번도 안 버린다. 그래서 마릿수가 늘면
		# 다른 특성과의 격차가 누적으로 벌어진다 — 실측: 0.9 로 올렸더니 봇 플레이에서
		# 선회 타워가 전체 피해의 61% 를 혼자 냈다(난이도 게이트도 92% → 118% 로 악화).
		# 0.6 은 '한 대는 기본 사격보다 약하다' 는 계약을 지키면서 그 누적을 되돌린다.
		"orbit": return 0.6
		"meteor": return 1.5
		_: return 1.0


func damage_per_attack() -> float:
	return base_damage * trait_damage_multiplier(trait_id)


## 이 단어를 지금 놓으면 실제로 나올 값 — 유물 없이, 단어 자체만으로.
##
## 돌려주는 것: base(특성 배율 전 발당 피해) / per_hit / volley / interval / dps /
## trait / range. **힌트(어느 단어를 목표로 삼을까)와 도감(이 단어가 얼마나 센가)이
## 같은 답을 내야 하므로** 이 한 곳에서만 계산한다.
##
## DB 의 `damage` 필드는 여기 없다. 그 필드는 게임이 읽지 않는다 — 발당 피해는
## 음절 수와 특성 배율이, 발수는 음절 수가, 간격은 특성과 음절 수가 정한다.
## 그런데 힌트와 도감은 그 필드를 읽고 있어서 화면의 숫자와 실제 타워가 갈라졌다.
## 실측(tools/HintValueProbe.gd): 가루 도감 44 · 실제 9.5 DPS / 바늘 도감 22 ·
## 실제 45.4 DPS — 도감이 **4.8배 약한 쪽**을 1위로 보여 주고 있었다.
##
## **발수(volley)를 빼면 안 된다.** 2·3음절 타워는 한 번의 공격에 각각 만피 피해로
## 여러 발을 쏜다(`attack_target`: volley > 1 이면 damage_shares 로 나누지 않는다).
## 이 항을 빼면 2음절을 0.7배로 재고, "긴 단어가 세다" 는 약속이 거짓이 된다.
## 상수 주석의 실측치 12.5 / 34.9 / 73.7 이 정확히 이 식의 값이다.
##
## relics 를 받지 않는 이유: 힌트와 도감은 '지금 유물이 뭘 해 주는가' 가 아니라
## '이 단어 자체가 센가' 를 비교한다. 유물은 모든 후보에 걸리므로 순위를 바꾸지 않는다.
static func preview_stats(syllable: String, word_data: Dictionary, is_unknown := false) -> Dictionary:
	var level := clampi(syllable.length(), 1, VOLLEY_BY_LENGTH.size())
	var base := BASE_DAMAGE_BY_LENGTH[level - 1]
	if not is_unknown:
		base *= 1.25
	var trait_id := str(AttackStyle.style_for(syllable, word_data)["trait"])
	# 형태의 결도 실제 타워와 **같은 식**으로 반영한다. 빠뜨리면 힌트·도감이 실제보다
	# 약한 값을 보여 준다 — 이 파일에서 이미 한 번 났던 종류의 거짓말이다.
	# `base` 는 건드리지 않는다: 이 필드의 뜻은 '특성 배율 전 발당 피해' 다.
	var shape = WordSynergy.native_shape_bonuses(syllable)
	var interval := float(TRAIT_INTERVAL.get(trait_id, 0.8)) * INTERVAL_MULT_BY_LENGTH[level - 1] * float(shape["interval"])
	var per_hit := base * trait_damage_multiplier(trait_id) * float(shape["damage"])
	var volley: int = 1 if trait_id == "meteor" or trait_id == "orbit" else VOLLEY_BY_LENGTH[level - 1]
	return {
		"base": base,
		"per_hit": per_hit,
		"volley": volley,
		"interval": interval,
		"dps": per_hit * float(volley) / maxf(interval, 0.001),
		"trait": trait_id,
		"range": float(TRAIT_RANGE.get(trait_id, BASE_ATTACK_RANGE)) * float(shape["range"]),
	}


## 이 타워가 실제로 굴리는 치명타 확률. 피해 2배가 터지는 빈도다.
##
## 판정(_fire)과 표시(툴팁·정보창)가 **반드시 같은 식**을 써야 한다. 예전에는
## 판정식이 _fire 안에만 인라인으로 있어서 화면에 쓸 수가 없었고, 그래서
## 유물로 올린 치명타가 어디에도 안 보였다.
func total_crit_chance() -> float:
	var chance := crit_chance
	if field_ref != null and field_ref.has_relic("relic_crit_lens"):
		chance += 0.25
	return clampf(chance, 0.0, 1.0)


## 이 타워가 지금 치명타를 굴린다. **굴림은 여기 한 곳**이다.
##
## ✅ **§2.21-6 고침 (2026-10-01).** 예전에는 굴림이 `attack_target()` 안에 **인라인**으로
##    있었고, 유성은 그 위에서 `_cast_meteor()` 로 빠져나가고 선회는 `attack_target()` 을
##    아예 안 타서 **둘 다 굴림에 도달하지 못했다**. 유물 `예리한 렌즈`(35 G)의 계약
##    (*"타워 공격 시 25% 확률로 2배 치명타"*)이 그 두 특성에서 **거짓**이었다.
##    굴림을 함수로 빼서 **세 경로가 같은 문을 지나게** 한다.
##
## ⚠️ **기대값은 특성과 무관하게 같다.** 굴림이 한 번이든 백 번이든 25%·2배의 기대 배수는
##    `1 + 0.25 × (2 − 1) = 1.25` 다. 그래서 이것은 **밸런스 변경이 아니라 일관성 수정**이다.
##    (*"선회는 초당 다수 타격이라 확률이 과해진다"* 는 우려는 **분산**에 대한 것인데,
##     선회는 원래 지속 피해라 분산이 낮은 쪽이 오히려 특성에 맞는다.)
func roll_crit() -> bool:
	return randf() < total_crit_chance()


## 굴림 결과를 피해에 적용한다. **배수도 굴림과 같은 곳**에 둔다 —
## 둘이 다른 파일에 있으면 상점 설명(`CRIT_DAMAGE_MULT` 를 말한다)과 코드가 어긋난다.
func crit_damage(damage: float, is_crit: bool) -> float:
	if is_crit:
		return damage * CRIT_DAMAGE_MULT
	return damage


## 유성을 한 발 떨어뜨린다.
## 사거리 안의 적 하나를 고른 뒤 그 '주변'에 떨어뜨린다 —
## 정확히 조준하지 않기 때문에 "랜덤하게 떨어진다"는 느낌이 살고,
## 광역이라 빗나가도 옆의 적이 함께 맞는다.
##
## `is_crit` 는 **이 한 발이 굴림을 통과했는가** 다(§2.21-6). 피해에는 이미
## `crit_damage()` 로 배수가 들어와 있고, 이 값은 **피해 숫자의 종류**를 정하러
## `Meteor` → `take_damage` 로 내려간다 — 안 내려보내면 2배로 맞은 적이 흰 숫자로 뜬다.
func _cast_meteor(is_crit: bool = false) -> void:
	if field_ref == null:
		return
	var candidates: Array = []
	for e in field_ref.get_enemies():
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) <= attack_range:
			candidates.append(e)
	if candidates.is_empty():
		return
	var victim: EnemyUnit = candidates[randi() % candidates.size()]
	var drop_point: Vector2 = victim.global_position + Vector2(
		randf_range(-METEOR_SCATTER, METEOR_SCATTER),
		randf_range(-METEOR_SCATTER, METEOR_SCATTER))
	var meteor := Meteor.new()
	meteor.global_position = drop_point
	field_ref.add_effect(meteor)
	meteor.setup(crit_damage(damage_per_attack() * damage_multiplier, is_crit),
		METEOR_BLAST_RADIUS, self, METEOR_FALL_TIME, is_crit)
	attack_count += 1
	SoundEngine.play_magic()


func damage_shares(target_count: int, total_damage := -1.0) -> Array:
	# ⚠️ **상한 3 은 낡은 사본이었다 (2026-10-03 고침).** `_trait_targets()` 는
	#    `3 + bonus_targets` 까지 대상을 모으는데(특성 전용 유물이 *"대상 +1"* 을 약속한다),
	#    여기서 3 으로 자르면 **`shares` 가 `targets` 보다 짧아져** 호출부의
	#    `shares[i]` 가 인덱스 초과로 터진다. 실측: 3막에서
	#    `SCRIPT ERROR: Out of bounds get index '3'` 18회, `attack_target:621`.
	#    → 설명(*"동시 타격 3+bonus 마리"*, 유물 *"대상 +1"*)이 계약이므로 **자르는 쪽**을 고친다.
	#    ⚠️ **피해 총량은 안 변한다** — 아래에서 `total / count` 로 나눠 갖는다. 그리고
	#    `bonus_targets` 를 올리는 유물은 splash·chain·pierce 뿐이고 셋 다 나눠 갖는 쪽이라,
	#    `bounce`(나누지 않고 각자 full)는 애초에 3을 못 넘는다 → **밸런스 변화 0.**
	#    상한을 여기서 다시 적지 않는 이유: 그러면 대상 수를 늘리는 새 기구가 생길 때마다
	#    이 줄을 같이 고쳐야 하고, 잊으면 **같은 인덱스 초과가 조용히 돌아온다.**
	var count := maxi(target_count, 1)
	var total := damage_per_attack() if total_damage < 0.0 else total_damage
	var share := total if trait_id == "bounce" else total / count
	var result: Array = []
	for i in count:
		result.append(share)
	return result


func damage_over_time_parts() -> Array:
	return [damage_per_attack() * 0.25, damage_per_attack() * 0.75]


func _trait_targets(primary: EnemyUnit) -> Array[EnemyUnit]:
	var result: Array[EnemyUnit] = [primary]
	if trait_id not in ["splash", "pierce", "chain", "bounce", "control"]:
		return result
	# 기본 3마리 + 특성 전용 유물이 늘린 수.
	var cap := 3 + bonus_targets
	for enemy in field_ref.get_enemies():
		if result.size() >= cap:
			break
		if enemy == primary or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if _in_reach(primary, enemy):
			result.append(enemy)
	return result


## splash 의 '착탄 지점 주변' 반경. `control` 의 실제 스플래쉬(`Projectile.hit_target` 48px)와 같다.
const SPLASH_RADIUS := 48.0

## 추가 대상이 될 수 있는가. splash 는 **주 대상(착탄점) 주변**, 나머지는 타워 사거리 안.
## (2026-10-14 §4.2: 예전엔 splash 도 사거리 안을 스폰 순서로 골라 설명과 어긋났다.
##  대상 수 상한과 총피해 분배는 그대로다 — 2음절 이상은 반경 밖 발이 주 대상에게 간다.)
func _in_reach(primary: EnemyUnit, enemy: EnemyUnit) -> bool:
	if trait_id == "splash":
		return primary.global_position.distance_to(enemy.global_position) <= SPLASH_RADIUS
	return global_position.distance_to(enemy.global_position) <= attack_range


## is_crit 은 **이 한 발이 치명타로 굴렸는가** 다. 피해에는 이미 `CRIT_DAMAGE_MULT` 가
## 곱해져 있으므로, 이 인자는 순수하게 **표시**를 위한 것이다(§2.21 (A)) — 예전에는
## 배수만 곱하고 그 사실을 버려서 화면이 치명타를 알 길이 없었다.
func _fire_projectile(target: EnemyUnit, damage: float, proj_type: String, is_crit: bool = false) -> void:
	var proj = projectile_scene.instantiate() as Projectile
	proj.global_position = global_position
	field_ref.add_projectile(proj)
	proj.setup(target, damage, proj_type, trait_id, self, projectile_scale(), is_crit)

func record_damage(amount: float) -> void:
	if field_ref != null: field_ref.record_tower_damage(syllable, amount)

## 그리기 시점에 쓰는 텍스처. **반드시 `preload` 상수로 둔다.**
##
## ⚠️ `_draw()` 안에서 처음 `load()` 하면 그 텍스처는 **흰 사각형**으로 그려지고 그대로 굳는다
##    (실측 2026-10-05, §2.25). 그리기 단계에서는 텍스처의 GPU RID 가 아직 없어 기본 흰
##    텍스처가 바인딩되는데, `_draw()` 는 `queue_redraw()` 때만 다시 돌기 때문에 그 상태가
##    남는다 — `queue_redraw()` 로도, 나중에 밖에서 로드해도 고쳐지지 않는다.
##    (실측: 지연 로드 = 22x22 순백 / 그리기 전 로드 = 정상. `null` 텍스처는 아무것도 안 그린다.)
##    `preload` 는 스크립트가 로드될 때 — 첫 그리기보다 훨씬 전에 — 텍스처를 만들고
##    상수가 참조를 붙잡아 주므로 이 함정에 걸리지 않는다.
##    ⚠️ `static var` 캐시를 게으르게 채우는 방식은 **안 된다** — 첫 호출이 `_draw()` 안이면
##       똑같이 흰 사각형이 된다. `ResourceLoader` 캐시도 약참조라, 참조를 아무도 안 잡으면
##       해제되었다가 `_draw()` 안에서 다시 로드되며 같은 상태가 된다.
const MAGIC_CIRCLE_TEX := preload("res://assets/fx/fx_magic_circle_128px.png")
## 특성 배지 11종. 키는 `TraitStyle.COLORS` 와 같다.
const BADGE_TEXTURES: Dictionary = {
	"balanced": preload("res://assets/fx/badge_balanced.png"),
	"sniper": preload("res://assets/fx/badge_sniper.png"),
	"damage_over_time": preload("res://assets/fx/badge_damage_over_time.png"),
	"splash": preload("res://assets/fx/badge_splash.png"),
	"rapid": preload("res://assets/fx/badge_rapid.png"),
	"pierce": preload("res://assets/fx/badge_pierce.png"),
	"control": preload("res://assets/fx/badge_control.png"),
	"chain": preload("res://assets/fx/badge_chain.png"),
	"bounce": preload("res://assets/fx/badge_bounce.png"),
	"orbit": preload("res://assets/fx/badge_orbit.png"),
	"meteor": preload("res://assets/fx/badge_meteor.png"),
}

func _draw() -> void:
	var cat_col := get_category_color()

	# 호버 시 사거리 원 표시
	if is_hovered:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 48, Color(cat_col.r, cat_col.g, cat_col.b, 0.8), 2.0)
		draw_circle(Vector2.ZERO, attack_range, Color(cat_col.r, cat_col.g, cat_col.b, 0.05))

	# 건설 시 마법진 연출
	if magic_circle_time_left > 0.0:
		var alpha := magic_circle_time_left / 0.8
		var circle_tex: Texture2D = MAGIC_CIRCLE_TEX
		if circle_tex != null:
			var sz := 100.0 * (1.0 + (1.0 - alpha) * 0.25)
			var rect := Rect2(-sz * 0.5, -sz * 0.5, sz, sz)
			draw_texture_rect(circle_tex, rect, false, Color(cat_col.r, cat_col.g, cat_col.b, 0.85 * alpha))


## 타워가 '어떻게 때리는지' 를 아이콘 하나로 보여준다.
##
## 예전에는 특성 이름이 툴팁 텍스트로만 있었다. 그래서 필드에 타워 3개가 서 있어도
## 어느 것이 연사이고 어느 것이 폭발인지 알 수 없었고, 정보 모달을 열어야만 했는데
## 그 모달의 배지조차 전부 ◆ 로 떨어져 있었다(실측: 활성 시너지 줄이 ◆ 4개).
##
## 이모지를 쓰지 않고 직접 그리는 이유는 TraitStyle 주석 참고 —
## 요약하면 (1) OS 폰트 대체에 기대면 빌드에 따라 두부가 되고,
## (2) 작은 크기에서 이모지들은 서로 구분이 안 되는 색 덩어리로 뭉개진다.
##
## ⚠️ 텍스처는 `BADGE_TEXTURES`(preload 상수)에서 온다. `_draw()` 안에서 `load()` 하면
##    흰 사각형이 된다 — 그 기구는 그 상수 옆 주석에 있다(§2.25).
func _draw_trait_badge_on(canvas: CanvasItem) -> void:
	if not TraitStyle.has_icon(trait_id):
		return
	# 우상단 모서리. 45도 방향으로 VISUAL_RADIUS*0.53 만큼 밀면
	# (거리 28.5) + 배지 반지름(8.4) = 36.9 < 38 이라 발자국(반지름 38) 안에 들어온다.
	var c := Vector2(VISUAL_RADIUS, -VISUAL_RADIUS) * 0.53
	var tex: Texture2D = BADGE_TEXTURES.get(trait_id)
	if tex != null:
		var sz := 22.0
		canvas.draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)
	else:
		var col: Color = TraitStyle.color_for(trait_id)
		var r := VISUAL_RADIUS * 0.22
		canvas.draw_circle(c, r, Color(0.04, 0.03, 0.09, 0.92))
		canvas.draw_arc(c, r, 0, TAU, 20, Color(col.r, col.g, col.b, 0.85), 1.2)
		TraitStyle.draw_icon(canvas, c, r * 0.62, trait_id, col)

func get_category_color() -> Color:
	var cat = word_data.get("category", "")
	match cat:
		"weapon": return Color(0.96, 0.58, 0.22)
		"element", "nature": return Color(0.22, 0.86, 0.65)
		"magic": return Color(0.78, 0.45, 0.98)
		"summon", "buff": return Color(0.96, 0.86, 0.28)
		"defense": return Color(0.35, 0.68, 0.98)
		"heal": return Color(0.45, 0.95, 0.5)
		"skill": return Color(0.96, 0.38, 0.42)
		_: return Color(0.7, 0.72, 0.82)

## 타워 카드 한 변(px). 반지름은 이 값의 절반이다.
##
## 이 값은 '그림 크기' 가 아니라 **발자국(footprint)** 이다 — 클릭 영역(BtnSelect)과
## 특성 배지 위치가 이 크기를 기준으로 잡힌다. 실제 그림 크기는 씬의
## `IconContainer/IconSprite.custom_minimum_size` 가 소유한다(에디터에서 눈으로
## 보이는 값이어야 하기 때문이다).
##
## 상한은 길 여유에서 나온다: DefenseField.PAD_RADIUS(32) + PAD_ROAD_GAP(8) = 40.
## 76px(반지름 38) 이면 2px 이 남는다. 타워 그림은 이 발자국 안에 들어가야 한다 —
## 발판은 길 옆에 붙어 있어서, 그림이 40px 를 넘으면 길 위로 삐져나온다.
##
## 아이콘 상자도 같은 40px 로 묶인다. 아이콘은 32x32 캔버스를 꽉 채우지 않으므로
## '상자 크기' 가 아니라 **칠해진 픽셀의 최대 반지름** 으로 재야 한다.
##
## ⚠️ 예전 이 주석은 "114개 타워 아이콘을 실측한 최악값은 0.684" 라고 적었지만 **낡았다**
##    (2026-10-05 실측: DB 는 265 단어 / 365 아이콘이고 **330개가 0.684 를 넘는다**,
##    최악은 1.1049 — 상자 58 에서 채워진 반지름이 64.08px 라 40 을 넘는다).
##    즉 "58 이 상한" 이라는 결론은 지금 **근거가 없다.** 상자를 줄일지(그림이 작아진다),
##    길 여유(DefenseField.PAD_RADIUS · PAD_ROAD_GAP)를 늘릴지는 **감독 결정**이다 — §2.25.
const CARD_SIZE := 76.0
const VISUAL_RADIUS := CARD_SIZE * 0.5


func _apply_visual_style() -> void:
	var base_panel = get_node_or_null("BasePanel") as Panel
	if base_panel == null:
		return
	var style := StyleBoxFlat.new()
	# 배경·테두리·그림자 전부 없다. 타워는 **그림 자체**로만 보인다.
	#
	# 예전에는 배경 없는 원형 카드에 그림자(검정 0.45, 2px)를 얹었다. 배경이 완전
	# 투명하면 그림자가 가려지지 않아서, 카드 모양(반지름 38 원)이 **그대로 채워진
	# 검은 원판**이 되어 화면에 남았다. 실측: 타워 자리에서 지도가 바깥 r=39 까지
	# 25~45% 어두워졌고 r=43 부터는 빈 발판 화면과 픽셀이 완전히 같아졌다.
	# 즉 타워는 '작은 그림 + 지름 78px 검은 원' 으로 보였다 — 그 원을 지운다.
	#
	# 카드 노드 자체는 남긴다 — 클릭 영역(BtnSelect)과 특성 배지 위치가 이 크기를 쓴다.
	# 씬(WordTower.tscn)의 StyleBoxFlat_card 에도 같은 그림자가 들어 있으므로 그쪽도
	# 같이 지웠다. 한쪽만 지우면 다른 쪽이 조용히 원을 되살린다.
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	# 발자국이 '원' 이라는 사실은 남겨 둔다 — 배지 위치가 이 반지름을 기준으로 잡힌다.
	style.set_corner_radius_all(int(VISUAL_RADIUS))
	base_panel.add_theme_stylebox_override("panel", style)
	queue_redraw()
