# MonsterRoster.gd
# 막별 몬스터 명단과 '속성' 정의.
#
# 문제: 예전에는 네 종류(일반/질풍/중갑/군집)가 세 막에 걸쳐 그대로 나왔고
# 이름만 "1막 침략자" → "3막 침략자" 로 바뀌었다. 아트도 두 종류뿐이었다.
# 그래서 막이 바뀌어도 "새로운 몬스터가 나온다" 는 느낌이 전혀 없었고,
# 속성도 hp/속도 차이뿐이라 "무엇으로 때려야 하나" 라는 판단이 없었다.
#
# 해법:
#   1) 막마다 다른 명단(이름·아트·타입)을 쓴다 — 14종 아트를 5/5/4 로 나눠 배치.
#   2) 타입 위에 '속성(attrs)' 을 얹는다. 각 속성은 특정 특성에 약하고 다른 특성에 강하다:
#        재생(regen)      — 스스로 회복. 지속 피해/연사로는 못 잡는다 → 저격·관통
#        분열(splitter)   — 죽으면 둘로 갈라진다 → 폭발·연쇄·유성
#        결계(warded)     — 한 특성을 막아낸다 → 그 특성이 아닌 다른 것으로
#        질주(swift)      — 감속 면역 → 제어가 무의미
#   즉 '이번 라운드는 무엇으로 때려야 하나' 가 매 라운드 달라진다.
#
# 타입별 hp/보호막/속도는 여기 한 곳에서만 정의한다 — tests/test_wave_balance 가
# '중갑 > 일반 > 질풍 > 군집' 서열과 보호막 보유를 검증한다.
class_name MonsterRoster
extends RefCounted

## `TraitStyle` 은 `class_name` 이 없다 — `WordTower.gd:47` 과 **같은 방식**으로 가져온다.
## ⚠️ 방향에 주의: `TraitStyle` 은 이 파일을 **참조하지 않는다**(참조하면 순환이 된다).
##    `TraitStyle` → (없음) · `MonsterRoster` → `TraitStyle` 한 방향뿐이다.
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")

const ICON_DIR := "res://assets/monsters/"

## 타입별 기본 능력치. hp_mult 는 그 라운드의 기준 체력에 곱해진다.
## 서열(중갑 > 일반 > 질풍 > 군집)은 테스트로 고정돼 있으니 바꿀 때 주의할 것.
const TYPE_STATS: Dictionary = {
	"normal":  {"hp": 1.0, "shield": 0.0, "speed": 75.0, "speed_per_act": 5.0,  "gold": 1},
	"fast":    {"hp": 0.7, "shield": 0.0, "speed": 145.0, "speed_per_act": 10.0, "gold": 1},
	"armored": {"hp": 1.5, "shield": 0.8, "speed": 55.0, "speed_per_act": 3.0,  "gold": 1},
	"swarm":   {"hp": 0.5, "shield": 0.0, "speed": 95.0, "speed_per_act": 5.0,  "gold": 1},
	"boss":    {"hp": 8.0, "shield": 0.0, "speed": 40.0, "speed_per_act": 0.0,  "gold": 6},
}

## 속성 하나의 의미와 대응법. UI 문구와 툴팁이 이 표를 그대로 읽는다.
##
## ⚠️ **이 첫 줄은 2026-10-01 까지 거짓이었다** — `label`·`color`·`counter` 는 읽히는데
##    **`desc` 를 읽는 코드가 0건**이었다(§2.19-3). 네 문장이 표 안에서만 살았다.
##    이제 `attr_desc_text()` 하나가 유일한 소비처다(§5.2 31 (B)).
## color 는 적 머리 위 배지의 배경색이다 — 라벨과 색이 같은 표에 있어야
## 새 속성을 추가할 때 한 곳만 고치면 된다.
const ATTR_INFO: Dictionary = {
	"regen": {"label": "재생", "counter": "저격·관통·유성", "color": Color(0.20, 0.75, 0.35, 0.88),
		"desc": "스스로 체력을 회복합니다. 지속 피해와 연사는 효과가 낮습니다."},
	"splitter": {"label": "분열", "counter": "폭발·연쇄·유성·3연속 바운스", "color": Color(0.75, 0.25, 0.70, 0.88),
		"desc": "죽을 때 둘로 갈라집니다. 광역으로 함께 정리해야 합니다."},
	"warded": {"label": "결계", "counter": "다른 특성", "color": Color(0.25, 0.50, 0.95, 0.88),
		"desc": "한 가지 특성을 거의 막아냅니다."},
	"swift": {"label": "질주", "counter": "둔화 외 아무거나", "color": Color(0.95, 0.60, 0.10, 0.88),
		"desc": "감속에 걸리지 않습니다. 둔화 타워가 무의미합니다."},
}

## 속성 → 피해 배율. 타입 배율과 곱해진다 (EnemyUnit.damage_multiplier_for).
## 1.0 은 표에 없다 — 없는 특성은 그대로 1.0 이다.
const ATTR_MULTIPLIERS: Dictionary = {
	"regen":    {"sniper": 1.4, "pierce": 1.25, "meteor": 1.3, "damage_over_time": 0.55, "rapid": 0.7},
	"splitter": {"splash": 1.45, "chain": 1.3, "bounce": 1.3, "meteor": 1.35, "sniper": 0.75},
	"swift":    {"control": 0.5},
}

## 타입 하나의 표시 이름과 색. ATTR_INFO 와 같은 모양이다.
##
## 'normal' 은 라벨을 비워 둔다 — 대부분의 적이 일반이라 적 머리에 '일반' 이 붙으면
## 정보가 아니라 소음이고, 예고 문구에서도 '일반→...' 은 아무 말도 하지 않는다.
## 'boss' 도 배지를 달지 않는다: 보스는 등장 배너가 약점까지 크게 알려 준다.
const TYPE_INFO: Dictionary = {
	"normal":  {"label": ""},
	"fast":    {"label": "질풍", "color": Color(0.95, 0.60, 0.10)},
	"armored": {"label": "중갑", "color": Color(0.58, 0.68, 0.82)},
	"swarm":   {"label": "군집", "color": Color(0.85, 0.45, 0.68)},
	"boss":    {"label": "보스", "color": Color(0.95, 0.35, 0.35)},
}

## 타입 → 특성별 피해 배율. EnemyUnit.damage_multiplier_for 가 이 표를 그대로 읽는다.
##
## 예전에는 이 내용이 그 함수의 match 문 안에만 있었다. 그래서 '무엇이 무엇에
## 강한가' 를 화면에 쓰려면 같은 표를 손으로 한 번 더 적어야 했고, 결국 아무 데도
## 안 쓰여서 **타입 상성 전체가 화면에 없었다**(플레이어는 맞아 본 뒤에야 알았다).
## 이제 표가 데이터라서 예고 문구와 배지가 같은 출처를 읽는다.
const TYPE_MULTIPLIERS: Dictionary = {
	"armored": {"pierce": 1.6, "meteor": 1.25, "rapid": 0.65, "orbit": 0.75},
	"swarm":   {"splash": 1.5, "bounce": 1.5, "chain": 1.5, "orbit": 1.5, "meteor": 1.5, "sniper": 0.75},
	"fast":    {"control": 1.5},
}

## 이 배율을 넘으면 '약점', 이 아래면 '내성' 으로 말한다.
##
## ⚠️ `EnemyUnit.WEAK_MULT` / `RESIST_MULT` 와 **같은 값**이어야 한다(2026-09-26 정렬).
##    두 파일이 각자 상수를 갖는 것은 의도다(추출하지 않는다 — §2.16 규칙).
##    대신 `tools/CounterThresholdProbe` 가 **두 값이 같은지**를 단언한다.
const COUNTER_WEAK_MULT := 1.25
const COUNTER_RESIST_MULT := 0.75

## 재생 속도 — 최대 체력 대비 초당 비율.
## 실측 기준: 1음절 타워 DPS 가 약 12.5 라서 2%면 저지되지 않고,
## 지속 피해(초당 약 2.5)는 거의 상쇄된다 — '저격으로 잡아야 한다' 가 성립한다.
const REGEN_RATIO: float = 0.02

## 분열 시 갈라지는 마릿수와 체력 비율. 자식은 '분열' 속성을 잃는다(무한 분열 방지).
const SPLIT_COUNT: int = 2
const SPLIT_HP_RATIO: float = 0.45

## 결계가 막아내는 특성을 지정하는 접두사. 예: "warded:control".
const WARD_PREFIX := "warded:"

## ── 막별 명단 ────────────────────────────────────────────────────────────────
## 모든 막이 normal/fast/armored/swarm 을 하나씩 갖는다 —
## 그래야 어느 막에서든 '타입 상성' 이 의미를 갖는다 (테스트가 이걸 검증한다).
const ACTS: Dictionary = {
	# 1막 정원 — 들짐승과 풀숲. 재생/질주로 시작해 기본기를 가르친다.
	1: [
		{"name": "낱자 슬라임", "type": "normal", "icon": "monster_slime_1_32px_pastel.png", "attrs": []},
		{"name": "그늘 박쥐", "type": "fast", "icon": "monster_bat_1_32px_pastel.png", "attrs": ["swift"]},
		{"name": "엄니 멧돼지", "type": "armored", "icon": "monster_boar_1_32px_pastel.png", "attrs": []},
		{"name": "풀숲 고블린", "type": "swarm", "icon": "monster_goblin_1_32px_pastel.png", "attrs": []},
		{"name": "되살아난 덩굴", "type": "normal", "icon": "monster_vine_1_32px_pastel.png", "attrs": ["regen"]},
	],
	# 2막 광산 — 갱도의 언데드와 결정. 결계/분열이 처음 등장한다.
	2: [
		{"name": "뼈 무덤지기", "type": "armored", "icon": "monster_skeleton_1_32px_pastel.png", "attrs": []},
		{"name": "갱도 거미", "type": "swarm", "icon": "monster_spider_1_32px_pastel.png", "attrs": ["splitter"]},
		{"name": "심연 늑대", "type": "fast", "icon": "monster_wolf_1_32px_pastel.png", "attrs": ["swift"]},
		{"name": "광맥 망령", "type": "normal", "icon": "monster_spirit_1_32px_pastel.png", "attrs": ["warded:control"]},
		{"name": "결정 슬라임", "type": "normal", "icon": "monster_slime_2_32px_pastel.png", "attrs": ["regen"]},
	],
	# 3막 천공성 — 뇌운과 성광. 재생+분열+결계가 겹쳐 '한 가지 답' 이 없다.
	3: [
		{"name": "뇌운의 아룡", "type": "fast", "icon": "monster_dragon_1_32px_pastel.png", "attrs": ["swift"]},
		{"name": "성광 정령", "type": "normal", "icon": "monster_spirit_2_32px_pastel.png", "attrs": ["warded:damage_over_time"]},
		{"name": "창공 가시덩굴", "type": "swarm", "icon": "monster_vine_2_32px_pastel.png", "attrs": ["splitter"]},
		{"name": "강철 멧돼지", "type": "armored", "icon": "monster_boar_2_32px_pastel.png", "attrs": ["regen"]},
	],
}

## 막별 보스. 아트 두 종류를 1막 → 2막/3막 순으로 쓴다.
const BOSS_ICONS: Dictionary = {
	1: "monster_golem_boss_1_32px_pastel.png",
	2: "monster_golem_boss_2_32px_pastel.png",
	3: "monster_golem_boss_2_32px_pastel.png",
}

const BOSS_TITLES: Dictionary = {
	1: "정원의 파수 골렘",
	2: "갱도의 심장 골렘",
	3: "천공의 수문장",
}

## 보스 약점 순환 — 5라운드마다 관통 → 폭발 → 제어 → 지속 피해.
const BOSS_WEAKNESSES: Array = ["pierce", "splash", "control", "damage_over_time"]
const BOSS_WEAKNESS_LABELS: Dictionary = {
	"pierce": "관통", "splash": "폭발", "control": "둔화", "damage_over_time": "지속 피해",
}

## 보스가 기지에 닿으면 잡몹보다 훨씬 큰 피해를 준다 — 놓치면 아프다.
const BOSS_BASE_DAMAGE: int = 3


static func icon_path(file_name: String) -> String:
	return ICON_DIR + file_name


## 그 막의 명단. 알 수 없는 막은 1막으로 떨어진다.
static func entries_for(act: int) -> Array:
	return ACTS.get(clampi(act, 1, 3), ACTS[1])


## 그 막에 등장하는 타입 목록 (중복 없이, 등장 순서 유지).
static func types_for(act: int) -> Array:
	var seen: Array = []
	for entry in entries_for(act):
		var type_id: String = str(entry["type"])
		if not seen.has(type_id):
			seen.append(type_id)
	return seen


## 속성 문자열에서 결계가 막는 특성을 뽑는다. 결계가 아니면 빈 문자열.
static func warded_trait_of(attrs: Array) -> String:
	for attr in attrs:
		var text := str(attr)
		if text.begins_with(WARD_PREFIX):
			return text.substr(WARD_PREFIX.length())
	return ""


## 속성 하나의 표시 이름. 결계는 '결계(제어)' 처럼 무엇을 막는지까지 보여준다.
static func attr_label(attr: String) -> String:
	var text := str(attr)
	if text.begins_with(WARD_PREFIX):
		var blocked: String = text.substr(WARD_PREFIX.length())
		return "%s(%s)" % [str(ATTR_INFO["warded"]["label"]), WordTower.TRAIT_NAMES.get(blocked, blocked)]
	return str(ATTR_INFO.get(text, {}).get("label", text))


## 속성 배지의 색. 결계는 어떤 특성을 막든 같은 파란색이다.
static func attr_color(attr: String) -> Color:
	var text := str(attr)
	var base := "warded" if text.begins_with(WARD_PREFIX) else text
	return ATTR_INFO.get(base, {}).get("color", Color(0.35, 0.35, 0.35, 0.75))


## 타입의 표시 이름. '일반' 은 빈 문자열이다(배지도 예고 문구도 달지 않는다).
static func type_label(type_id: String) -> String:
	return str(TYPE_INFO.get(type_id, {}).get("label", ""))


## 타입 배지의 색. 모르는 타입은 배지 색 없음(회색)으로 떨어진다.
static func type_color(type_id: String) -> Color:
	return TYPE_INFO.get(type_id, {}).get("color", Color(0.35, 0.35, 0.35))

## 타입 배지에 쓸 색이 **표에 있는가**. '일반' 처럼 배지를 안 다는 타입은 false.
##
## ⚠️ `type_color()` 의 회색 폴백과 **구별해야 하는 자리**(파편 색 등)가 있다 —
##    "색이 없어서 회색" 과 "회색이 그 타입의 색" 은 다르다. `type_color()` 만 보면
##    둘을 구별할 수 없어서, 파편이 일반 적에게서도 회색으로 떨어진다.
static func has_type_color(type_id: String) -> bool:
	return TYPE_INFO.get(type_id, {}).has("color")


## 타입이 '무엇에 강하고 무엇에 약한지' 한 줄. 예: "중갑→관통·유성 (연사·선회에 약함)".
##
## 표(TYPE_MULTIPLIERS)에서 바로 뽑는다 — 문구를 손으로 적어 두면 표를 고칠 때
## 조용히 어긋나고, 그게 바로 이 정보가 화면에 없었던 이유다.
static func type_counter_text(type_id: String) -> String:
	var table: Dictionary = TYPE_MULTIPLIERS.get(type_id, {})
	if table.is_empty():
		return ""
	var weak: Array = []
	var resist: Array = []
	for trait_id in table:
		var value := float(table[trait_id])
		var name := str(WordTower.TRAIT_NAMES.get(trait_id, trait_id))
		if value >= COUNTER_WEAK_MULT: weak.append(name)
		elif value <= COUNTER_RESIST_MULT: resist.append(name)
	if weak.is_empty() and resist.is_empty():
		return ""
	var head := type_label(type_id)
	if not weak.is_empty():
		head = "%s→%s" % [head, "·".join(weak)]
	if resist.is_empty():
		return head
	return "%s (%s에 약함)" % [head, "·".join(resist)]


## 그 막에서 '무엇으로 때려야 하는지' 한 줄. 알려 줄 것이 없으면 빈 문자열.
##
## 타입(중갑/군집/질풍)과 속성(재생/분열/결계/질주)을 함께 준다. 상성은 두 축의
## 곱인데 예전에는 속성만 나와서, 정작 매 막 절반을 차지하는 타입 상성을 배울 곳이
## 인트로 문구밖에 없었다.
static func counters_text(act: int) -> String:
	var parts: Array = []
	for type_id in types_for(act):
		var line := type_counter_text(str(type_id))
		if line != "" and not parts.has(line):
			parts.append(line)
	for entry in entries_for(act):
		for attr in entry.get("attrs", []):
			var text := str(attr)
			var base := text.substr(0, text.find(":")) if text.find(":") >= 0 else text
			var counter: String = str(ATTR_INFO.get(base, {}).get("counter", ""))
			if counter == "":
				continue
			var line := "%s→%s" % [attr_label(text), counter]
			if not parts.has(line):
				parts.append(line)
	return "  ".join(parts)


## 그 막에 등장하는 속성들의 **설명 문장**을 한 덩어리로. 해당 속성이 없으면 빈 문자열.
##
## ⚠️ **§2.19-3 · §5.2 31 (B), 2026-10-01 신설.** `ATTR_INFO.desc` 네 문장은 표에 있었지만
##    **읽는 코드가 0건**이라 플레이어에게 도달하지 않았다 — 배지의 *이름*과 예고의 *상성 목록*은
##    보이는데 *"그게 무슨 뜻인지"* 를 볼 곳이 없었다.
##
## ## 왜 배지 툴팁이 아닌가 (두 번 기각된 안)
## ① 배지는 **적 머리 위**라 `MOUSE_FILTER_IGNORE` 다 — 풀면 적을 클릭하는 입력을 가로챈다.
## ② 풀더라도 **움직이는 10px 배지에 마우스를 올리는 것은 신뢰할 수 없는 UX** 다.
## → 그래서 **멈춰 있는 표면**에 붙인다: 상단 `btn_stage` 툴팁과 라운드 정보 모달.
##   두 곳이지만 **작성자는 이 함수 하나**다(§2.13-1 의 *"채널이 하나면 작성자도 하나"* 를
##   채널이 둘이어도 지킨다 — 문구를 손으로 두 번 적지 않는다).
##
## ⚠️ **막별로 다르다.** 1막에는 `swift`·`regen` 둘뿐이고, `splitter`·`warded` 는 2막에 처음
##    나온다. 그래서 "네 문장을 한 번에" 가 아니라 **그 막에 실제로 오는 것만** 보여준다 —
##    아직 안 나온 속성의 설명은 예고가 아니라 소음이다.
static func attr_desc_text(act: int) -> String:
	var seen: Array = []
	var lines: Array = []
	for entry in entries_for(act):
		for attr in entry.get("attrs", []):
			var text := str(attr)
			var base := text.substr(0, text.find(":")) if text.find(":") >= 0 else text
			if seen.has(base):
				continue
			seen.append(base)
			var info: Dictionary = ATTR_INFO.get(base, {})
			var desc := str(info.get("desc", ""))
			if desc == "":
				continue
			lines.append("%s — %s" % [str(info.get("label", base)), desc])
	return "\n".join(lines)


## 특성 하나가 **표에서** 갖는 상성을 한 줄로. 예: `"(중갑·군집에 효과적, 재생에 약함)"`.
##
## ⚠️ **§2.18 · §5.2 29 (C), 2026-10-01 신설.** 예전에는 이 문장이 `TraitStyle.DESCRIPTIONS`
##    안에 **손으로** 적혀 있었다 — 11개 중 **4개만** 괄호를 달았고, 그중 `rapid` 는 **거짓**이었다:
##    *"민첩/고속형에 효과적"* 이라 약속하는데 표에서 `rapid` 는 질풍에 **1.00(중립)** 이고
##    오히려 **중갑 0.65 · 재생 0.70** 으로 깎인다. 게다가 `민첩`·`고속형`·`방어형` 은
##    **배지 라벨이 아니라서**(배지는 8개: 질풍·중갑·군집·보스·재생·분열·결계·질주)
##    플레이어가 머릿속에서 번역해야 했다.
##
## → `type_counter_text()` 와 **같은 규칙**으로 표에서 뽑는다. 손으로 적은 사본이 없으므로
##   표를 고치면 문구가 따라오고, 드리프트가 **원리적으로 불가능**하다.
## ⚠️ 라벨은 반드시 `type_label()`·`attr_label()` 을 거친다 — 그래야 화면 어휘와 일치한다.
static func trait_counter_text(trait_id: String) -> String:
	var strong: Array = []
	var weak: Array = []
	for type_id in TYPE_MULTIPLIERS:
		var v := float(TYPE_MULTIPLIERS[type_id].get(trait_id, 1.0))
		if v >= COUNTER_WEAK_MULT:
			strong.append(type_label(str(type_id)))
		elif v <= COUNTER_RESIST_MULT:
			weak.append(type_label(str(type_id)))
	for attr_id in ATTR_MULTIPLIERS:
		var v := float(ATTR_MULTIPLIERS[attr_id].get(trait_id, 1.0))
		if v >= COUNTER_WEAK_MULT:
			strong.append(attr_label(str(attr_id)))
		elif v <= COUNTER_RESIST_MULT:
			weak.append(attr_label(str(attr_id)))
	var parts: Array = []
	if not strong.is_empty():
		parts.append("%s에 효과적" % "·".join(strong))
	if not weak.is_empty():
		parts.append("%s에 약함" % "·".join(weak))
	if parts.is_empty():
		return ""
	return "(%s)" % ", ".join(parts)


## 특성 설명 **전문** = 행동 설명(`TraitStyle`) + 표에서 유도한 상성(위 함수).
##
## ⚠️ **문구가 필요한 곳은 전부 이 함수를 써라.** `TraitStyle.desc_for()` 를 직접 쓰면
##    상성이 빠지고, 표를 직접 읽어 괄호를 만들면 손으로 적는 것과 같은 드리프트가 돌아온다.
static func trait_full_desc(trait_id: String) -> String:
	var base := TraitStyle.desc_for(trait_id)
	var counter := trait_counter_text(trait_id)
	if counter == "":
		return base
	if base == "":
		return counter
	return "%s %s" % [base, counter]


## 그 막의 몬스터 이름들을 한 줄로. 미리보기에서 '새 몬스터' 를 알려준다.
static func roster_text(act: int) -> String:
	var names: Array = []
	for entry in entries_for(act):
		names.append(str(entry["name"]))
	return "·".join(names)


## 보스 약점(특성 id) — 라운드가 오를수록 순환한다.
static func weakness_for(wave: int, interval: int) -> String:
	var index := int(wave / interval) - 1
	return str(BOSS_WEAKNESSES[index % BOSS_WEAKNESSES.size()])


## 보스 한 마리의 스폰 데이터.
static func boss_entry(act: int, wave: int, base_hp: float, wave_scale: float, act_scale: float, interval: int) -> Dictionary:
	var stats: Dictionary = TYPE_STATS["boss"]
	var weakness := weakness_for(wave, interval)
	return {
		"name": "%d막 %dR %s" % [act, wave, str(BOSS_TITLES.get(act, BOSS_TITLES[1]))],
		"type": "boss",
		"weakness": weakness,
		"hp": base_hp * float(stats["hp"]) * wave_scale * act_scale,
		"shield": 0.0,
		"speed": float(stats["speed"]),
		"gold": int(stats["gold"]) + act * 2,
		"icon": icon_path(str(BOSS_ICONS.get(act, BOSS_ICONS[1]))),
		"attrs": [],
		"base_damage": BOSS_BASE_DAMAGE,
	}


## 잡몹 한 마리의 스폰 데이터. index 는 라운드 내 등장 순번.
static func regular_entry(act: int, index: int, base_hp: float, wave_scale: float, act_scale: float) -> Dictionary:
	var roster := entries_for(act)
	var entry: Dictionary = roster[index % roster.size()]
	var stats: Dictionary = TYPE_STATS[str(entry["type"])]
	var attrs: Array = entry.get("attrs", [])
	return {
		"name": str(entry["name"]),
		"type": str(entry["type"]),
		"hp": base_hp * float(stats["hp"]) * wave_scale * act_scale,
		"shield": base_hp * float(stats["shield"]) * wave_scale * act_scale,
		"speed": float(stats["speed"]) + float(stats["speed_per_act"]) * float(act),
		"gold": int(stats["gold"]),
		"icon": icon_path(str(entry["icon"])),
		"attrs": attrs,
		"base_damage": 1,
	}


## ⚠️ §2.38 (2026-10-06) — 여기 있던 `GLYPHS`(8종) 와 `glyph_for()` 를 **지웠다.**
##    소비자가 **0건**이었다(트리 실측으로 확인) — 이주 과정에서 텍스트 표면이
##    `visible = false` 로 숨겨졌고, 그 뒤로 아무도 이 표를 읽지 않았다.
##    남은 `draw_icon()` 이 같은 정보를 **직접 그린다** — 그리고 그게 원래 계약이었다
##    (아래 헤더: *"neodgm 폰트 코드포인트 누락/OS 폰트 대체 문제 없이 100% 동일하게"*).
##    ⚠️ `NAMES` · `COLORS` 는 지우면 안 된다 — `draw_icon` 과 예고 아이콘이 쓴다.

## 몬스터 머리 위 배지 및 UI용 특성/속성 벡터 아이콘 직접 그리기.
## neodgm 폰트 코드포인트 누락/OS 폰트 대체 문제 없이 100% 동일하게 렌더링된다.
static func draw_icon(canvas: CanvasItem, center: Vector2, radius: float, trait_key: String, col: Color) -> void:
	var r := radius
	var base_key := trait_key
	if base_key.begins_with(WARD_PREFIX):
		base_key = "warded"

	match base_key:
		"armored":
			# 중갑 — 미니 방패 실루엣
			var pts := PackedVector2Array([
				center + Vector2(-r * 0.75, -r * 0.7),
				center + Vector2(r * 0.75, -r * 0.7),
				center + Vector2(r * 0.75, 0.0),
				center + Vector2(0.0, r * 0.9),
				center + Vector2(-r * 0.75, 0.0),
			])
			canvas.draw_polygon(pts, PackedColorArray([col]))
			canvas.draw_line(center + Vector2(0, -r * 0.5), center + Vector2(0, r * 0.6), Color(0.1, 0.1, 0.15, 0.9), 1.0)
			canvas.draw_line(center + Vector2(-r * 0.5, -r * 0.15), center + Vector2(r * 0.5, -r * 0.15), Color(0.1, 0.1, 0.15, 0.9), 1.0)

		"fast":
			# 질풍 — 3개의 날렵한 바람 사선
			canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.35), center + Vector2(r * 0.7, -r * 0.55), col, 1.4)
			canvas.draw_line(center + Vector2(-r * 0.5, 0.15 * r), center + Vector2(r * 0.8, -0.05 * r), col, 1.4)
			canvas.draw_line(center + Vector2(-r * 0.8, 0.65 * r), center + Vector2(r * 0.4, 0.45 * r), col, 1.4)

		"swarm":
			# 군집 — 모여 있는 작은 구체 3개 (삼각 배치)
			var off := r * 0.48
			canvas.draw_circle(center + Vector2(0, -off), r * 0.32, col)
			canvas.draw_circle(center + Vector2(-off * 0.9, off * 0.7), r * 0.32, col)
			canvas.draw_circle(center + Vector2(off * 0.9, off * 0.7), r * 0.32, col)

		"boss":
			# 보스 — 왕관 실루엣
			var crown := PackedVector2Array([
				center + Vector2(-r * 0.8, r * 0.7),
				center + Vector2(-r * 0.8, -r * 0.3),
				center + Vector2(-r * 0.35, 0.1 * r),
				center + Vector2(0.0, -r * 0.8),
				center + Vector2(r * 0.35, 0.1 * r),
				center + Vector2(r * 0.8, -r * 0.3),
				center + Vector2(r * 0.8, r * 0.7),
			])
			canvas.draw_polygon(crown, PackedColorArray([col]))

		"regen":
			# 재생 — 치유의 십자가 (+)
			var t := r * 0.32
			canvas.draw_rect(Rect2(center.x - r * 0.8, center.y - t, r * 1.6, t * 2.0), col)
			canvas.draw_rect(Rect2(center.x - t, center.y - r * 0.8, t * 2.0, r * 1.6), col)

		"splitter":
			# 분열 — Y자 세포 분기선
			canvas.draw_line(center + Vector2(0, r * 0.8), center + Vector2(0, 0), col, 1.5)
			canvas.draw_line(center + Vector2(0, 0), center + Vector2(-r * 0.75, -r * 0.75), col, 1.5)
			canvas.draw_line(center + Vector2(0, 0), center + Vector2(r * 0.75, -r * 0.75), col, 1.5)
			canvas.draw_circle(center + Vector2(-r * 0.75, -r * 0.75), r * 0.22, col)
			canvas.draw_circle(center + Vector2(r * 0.75, -r * 0.75), r * 0.22, col)

		"warded":
			# 결계 — 정육각형 쉴드
			var hex := PackedVector2Array()
			for i in 6:
				var a := TAU * float(i) / 6.0 - PI / 6.0
				hex.append(center + Vector2(cos(a), sin(a)) * r * 0.85)
			canvas.draw_polyline(hex, col, 1.3)
			canvas.draw_line(hex[5], hex[0], col, 1.3)
			canvas.draw_circle(center, r * 0.22, col)

		"swift":
			# 질주 — 2중 가속 화살촉 (>>)
			for i in 2:
				var x_off := -r * 0.4 + float(i) * r * 0.65
				canvas.draw_line(Vector2(center.x + x_off - r * 0.35, center.y - r * 0.6), Vector2(center.x + x_off + r * 0.15, center.y), col, 1.4)
				canvas.draw_line(Vector2(center.x + x_off + r * 0.15, center.y), Vector2(center.x + x_off - r * 0.35, center.y + r * 0.6), col, 1.4)

		_:
			canvas.draw_circle(center, r * 0.5, col)
