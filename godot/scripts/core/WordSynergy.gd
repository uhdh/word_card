class_name WordSynergy
extends RefCounted

const TENSE := ["ㄲ", "ㄸ", "ㅃ", "ㅆ", "ㅉ"]
const CLUSTER_FINALS := ["ㄳ", "ㄵ", "ㄶ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅄ"]
const COMPOUND_VOWELS := ["ㅘ", "ㅙ", "ㅚ", "ㅝ", "ㅞ", "ㅟ", "ㅢ"]
const EXPAND := {
	"ㄲ": ["ㄱ", "ㄱ"], "ㄸ": ["ㄷ", "ㄷ"], "ㅃ": ["ㅂ", "ㅂ"], "ㅆ": ["ㅅ", "ㅅ"], "ㅉ": ["ㅈ", "ㅈ"],
	"ㄳ": ["ㄱ", "ㅅ"], "ㄵ": ["ㄴ", "ㅈ"], "ㄶ": ["ㄴ", "ㅎ"], "ㄺ": ["ㄹ", "ㄱ"], "ㄻ": ["ㄹ", "ㅁ"],
	"ㄼ": ["ㄹ", "ㅂ"], "ㄽ": ["ㄹ", "ㅅ"], "ㄾ": ["ㄹ", "ㅌ"], "ㄿ": ["ㄹ", "ㅍ"], "ㅀ": ["ㄹ", "ㅎ"], "ㅄ": ["ㅂ", "ㅅ"],
	"ㅘ": ["ㅗ", "ㅏ"], "ㅙ": ["ㅗ", "ㅐ"], "ㅚ": ["ㅗ", "ㅣ"], "ㅝ": ["ㅜ", "ㅓ"], "ㅞ": ["ㅜ", "ㅔ"], "ㅟ": ["ㅜ", "ㅣ"], "ㅢ": ["ㅡ", "ㅣ"]
}

static func analyze(word: String) -> Dictionary:
	var parts := []
	var consonants := 0
	var vowels := 0
	for c in word:
		var p = HangulEngine.decompose_syllable(c)
		parts.append(p)
		consonants += EXPAND.get(p["chosung"], [p["chosung"]]).size()
		vowels += EXPAND.get(p["jungsung"], [p["jungsung"]]).size()
		if p["jongsung"] != "": consonants += EXPAND.get(p["jongsung"], [p["jongsung"]]).size()
	var initials = parts.map(func(p): return p["chosung"])
	var middle = parts.map(func(p): return p["jungsung"])
	var linked := false
	for i in range(parts.size() - 1):
		linked = linked or (parts[i]["jongsung"] != "" and parts[i]["jongsung"] == parts[i + 1]["chosung"])
	return {
		"has_tense": parts.any(func(p): return p["chosung"] in TENSE),
		"has_final": parts.any(func(p): return p["jongsung"] != ""),
		"has_cluster": parts.any(func(p): return p["jongsung"] in CLUSTER_FINALS),
		"has_compound_vowel": parts.any(func(p): return p["jungsung"] in COMPOUND_VOWELS),
		"repeated_initial": parts.size() > 1 and initials.all(func(v): return v == initials[0]),
		"repeated_vowel": parts.size() > 1 and middle.duplicate().filter(func(v): return middle.count(v) > 1).size() > 0,
		"linked": linked, "balanced": consonants == vowels
	}

## '공격속도 +N%' 를 **공격 간격 배수**로 바꾼다.
##
## 공격속도는 '초당 공격 횟수' 다. 그게 N% 늘어나면 간격은 `1/(1+N/100)` 배가 된다.
## `interval *= 0.8` 은 속도 +25% 이지 +20% 가 아니다 — 그런데 상점 설명은 +20% 라고
## 적혀 있었고, 어긋남이 오래 남아 있었다(플레이어에게 **유리한** 방향이라 아무도 신고하지
## 않는다). 이제 **설명이 계약**이다: 설명에 적힌 N% 가 실제 속도 증가가 되도록 역수를 취한다.
##
## 간격 배수를 직접 적지 않고 퍼센트로 적는 이유는, 설명의 숫자와 코드의 숫자를
## 사람이 눈으로 대조하지 않아도 되게 하기 위해서다(테스트가 둘을 기계적으로 맞춘다).
static func speed_pct_to_interval(pct: float) -> float:
	return 1.0 / (1.0 + pct / 100.0)


static func bonuses(word: String, relic_ids: Array) -> Dictionary:
	var a = analyze(word)
	var b = {"damage": 1.0, "interval": 1.0, "range": 1.0, "crit": 0.0, "labels": []}
	var rules = [
		["relic_tense_hammer", "has_tense", "damage", 1.25, "된소리 망치"], ["relic_final_weight", "has_final", "damage", 1.2, "종성의 무게추"],
		["relic_open_feather", "has_final", "interval", speed_pct_to_interval(18), "민소리 깃털", true], ["relic_cluster_anvil", "has_cluster", "damage", 1.35, "겹받침 모루"],
		["relic_vowel_crystal", "has_compound_vowel", "range", 1.2, "겹모음 수정"], ["relic_initial_drum", "repeated_initial", "damage", 1.25, "첫소리 북"],
		["relic_vowel_resonance", "repeated_vowel", "interval", speed_pct_to_interval(20), "모음 공명석"], ["relic_consonant_ring", "linked", "crit", 0.2, "자음 고리"],
		["relic_balance_ink", "balanced", "damage", 1.1, "균형의 먹"]
	]
	for rule in rules:
		var matches = not a[rule[1]] if rule.size() > 5 else a[rule[1]]
		if rule[0] in relic_ids and matches:
			if rule[2] == "crit": b[rule[2]] += rule[3]
			else: b[rule[2]] *= rule[3]
			b["labels"].append(rule[4])
	if "relic_balance_ink" in relic_ids and a["balanced"]: b["range"] *= 1.1
	return b


## 단어의 **모양**이 유물 없이도 작게 작동하게 한다 — '형태의 결'.
##
## 왜 필요한가: `analyze()` 는 형태 특징 8종을 계산하는데, 그 값을 읽는 곳은 `bonuses()`
## 뿐이고 그건 전부 `relic_*` 로 막혀 있다. 즉 **유물이 없으면 형태는 아무 일도 하지
## 않았다** — 로직은 있는데 표현이 없는 상태다. 여기서 그 축을 항상 켠다.
##
## 표를 이렇게 짠 근거는 **빈도** 다(tools/WordShapeProbe.gd 실측, DB 366개):
##
## - `받침` 은 289개(79%)다. 여기에 순수 보너스를 주면 '선택' 이 아니라 **상시 버프** 가
##   된다 — 플레이어가 고르는 것이 사라지고 기준선만 올라간다. 그래서 받침만 **무게** 로
##   만든다: 피해 +5%, 속도 -4%. DPS 는 x1.008 로 사실상 그대로다.
##   이 극성은 게임이 **이미 갖고 있다** — 유물 `종성의 무게추`(받침=세다)와
##   `민소리 깃털`(무받침=빠르다, 유일한 반전 규칙)이 정확히 그 방향이다.
##   새로 만든 축이 아니라 이미 있는 축을 유물 없이도 보이게 하는 것이다.
## - 나머지 7종은 전부 21% 이하라 **선택** 이 된다.
## - 각 효과는 그 특징을 증폭하는 **기존 유물과 같은 stat** 을 쓴다. 그래야
##   "네이티브는 작게, 유물은 증폭" 이 말로만이 아니라 실제로 성립하고,
##   플레이어가 유물을 사기 전에 그 축을 먼저 배운다.
## - `겹받침` 은 366개 중 **1개**(`닭`)뿐이다. 그래도 남긴다 — 그 한 단어가 기억에
##   남는 것이 목적이고, 증폭 유물(겹받침 모루)도 이미 있다.
##
## 크기를 이만큼 작게 잡은 이유가 하나 더 있다: 난이도 게이트
## (`DifficultyPlaytest -- gate=1`)가 **이미 '게임이 너무 쉬워졌다'** 로 실패 중이라
## (120% > 상한 75%), 총 전력을 올리는 변경은 그 실패를 악화시킨다. 실측 총합은
## DPS +2.34% 다(tools/WordShapeProbe.gd).
##
## 라벨은 `결: ` 로 시작한다. **22자를 넘기면 정보창 배지에서 조용히 사라진다**
## (`TowerInfoModal._render_synergy_badges` 가 그 길이를 거른다). 지금 최장은 20자이고,
## tests/test_tower_traits.gd 가 그 상한을 잠근다.
static func native_shape_bonuses(word: String) -> Dictionary:
	var a = analyze(word)
	var b = {"damage": 1.0, "interval": 1.0, "range": 1.0, "labels": []}
	# [analyze() 키, {stat: 배수}, 표시 라벨]. 간격은 배수를 직접 적지 않고
	# '속도 ±N%' 로 적는다 — 상점 설명과 코드가 갈라졌던 그 실수를 반복하지 않기 위해서다
	# (`speed_pct_to_interval` 주석 참고).
	var rules = [
		["has_final", {"damage": 1.05, "interval": speed_pct_to_interval(-4)}, "결: 받침 (피해+5%, 속도-4%)"],
		["balanced", {"damage": 1.02, "range": 1.02}, "결: 자모 균형 (피해·사거리+2%)"],
		["repeated_vowel", {"interval": speed_pct_to_interval(4)}, "결: 모음 반복 (속도+4%)"],
		["has_compound_vowel", {"range": 1.04}, "결: 겹모음 (사거리+4%)"],
		["repeated_initial", {"damage": 1.04}, "결: 첫소리 반복 (피해+4%)"],
		["linked", {"damage": 1.03}, "결: 연음 (피해+3%)"],
		["has_tense", {"damage": 1.04}, "결: 된소리 (피해+4%)"],
		["has_cluster", {"damage": 1.08}, "결: 겹받침 (피해+8%)"],
	]
	for rule in rules:
		if not a[rule[0]]:
			continue
		for stat in rule[1]:
			b[stat] *= float(rule[1][stat])
		b["labels"].append(rule[2])
	return b
