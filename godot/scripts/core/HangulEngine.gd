# HangulEngine.gd
# 15종 핵심 자모 기반 한글 조합 및 회전 동치성 3단계 등급 시스템 (Common / Rare / Super Rare)
extends Node

const CHOSUNG = [
	"ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
	"ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
]

const JUNGSUNG = [
	"ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
	"ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
]

const JONGSUNG = [
	"", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ",
	"ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ",
	"ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
]

# 3단계 희귀도 체계
# 1. 초희귀 (Super Rare - 4방향 회전 만능 타일: ㅏ, ㅓ, ㅗ, ㅜ) -> 가장 낮은 확률 (가중치 10)
const SUPER_RARE_TILES = ["ㅏ", "ㅓ", "ㅗ", "ㅜ"]

# 2. 희귀 (Rare - 2방향 회전 타일: ㄱ, ㄴ / ㅡ, ㅣ) -> 중간 확률 (가중치 30)
const RARE_TILES = ["ㄱ", "ㄴ", "ㅡ", "ㅣ"]

# 3. 일반 (Common - 비회전 자음: ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ) -> 기본 확률 (가중치 100)
const COMMON_TILES = ["ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ"]

const ALL_DRAW_POOL = [
	"ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ",
	"ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"
]

const ROTATABLE_TILES = {
	"ㄱ": "ㄴ", "ㄴ": "ㄱ",
	"ㅏ": "ㅜ", "ㅜ": "ㅓ", "ㅓ": "ㅗ", "ㅗ": "ㅏ",
	"ㅣ": "ㅡ", "ㅡ": "ㅣ"
}

const CONSONANT_COMBINATIONS = {
	"ㄱ+ㄱ": "ㄲ", "ㄷ+ㄷ": "ㄸ", "ㅂ+ㅂ": "ㅃ", "ㅅ+ㅅ": "ㅆ", "ㅈ+ㅈ": "ㅉ",
	"ㄱ+ㅅ": "ㄳ", "ㄴ+ㅈ": "ㄵ", "ㄴ+ㅎ": "ㄶ", "ㄹ+ㄱ": "ㄺ", "ㄹ+ㅁ": "ㄻ",
	"ㄹ+ㅂ": "ㄼ", "ㄹ+ㅅ": "ㄽ", "ㄹ+ㅌ": "ㄾ", "ㄹ+ㅍ": "ㄿ", "ㄹ+ㅎ": "ㅀ", "ㅂ+ㅅ": "ㅄ"
}

const VOWEL_COMBINATIONS = {
	"ㅗ+ㅏ+ㅣ": "ㅙ",
	"ㅜ+ㅓ+ㅣ": "ㅞ",
	"ㅗ+ㅏ": "ㅘ", "ㅗ+ㅣ": "ㅚ",
	"ㅜ+ㅓ": "ㅝ", "ㅜ+ㅣ": "ㅟ",
	"ㅡ+ㅣ": "ㅢ", "ㅏ+ㅣ": "ㅐ", "ㅓ+ㅣ": "ㅔ"
}

static func get_rarity(char_str: String) -> String:
	if SUPER_RARE_TILES.has(char_str):
		return "super_rare"
	elif RARE_TILES.has(char_str):
		return "rare"
	return "common"

static func is_rare(char_str: String) -> bool:
	return RARE_TILES.has(char_str) or SUPER_RARE_TILES.has(char_str)

static func is_super_rare(char_str: String) -> bool:
	return SUPER_RARE_TILES.has(char_str)

# 카드 배경은 등급과 관계없이 통일한다.
static func get_rarity_bg_color(_char_str: String) -> Color:
	return Color(0.14, 0.12, 0.20, 0.95)

## 카드 테두리도 등급과 관계없이 한 색으로 통일한다.
##
## 사실 확인: 예전 테두리 색은 '회전 가능' 이 아니라 **등급** 을 인코딩했다 —
## 초희귀=금색(0.96, 0.65, 0.10), 희귀=보라(0.68, 0.35, 0.98), 일반=슬레이트.
## 다만 이 게임에서 등급과 회전 가능 여부는 **같은 집합** 이다
## (ROTATABLE_TILES 의 키 == RARE_TILES ∪ SUPER_RARE_TILES, 실측 확인).
## 그래서 "보라 = 회전 가능" 처럼 읽혀도 결과는 같았고, ↻ 배지와 색이 항상 같이 움직였다.
##
## 이 변경의 실제 결과는 "같은 정보를 두 번 말하던 것을 정리" 가 아니라
## **벨트에서 등급을 알 수 있는 시각 채널이 사라진 것** 이다. 배경색이 먼저 통일됐고
## 테두리까지 통일됐으므로, 남은 등급 표시는 타일 툴팁 텍스트뿐이다
## (JamoBelt._build_tile 의 rarity_name). 등급을 다시 보이게 하려면 색이 아닌
## **새 채널**(예: 모서리 점/별)이 필요하다 — 색으로 되돌리면 방금 통일한 이유가
## 그대로 되살아난다.
static func get_rarity_border_color(_char_str: String) -> Color:
	return Color(0.35, 0.30, 0.48, 0.8)     # 차분한 슬레이트 테두리

const VOWEL_POOL = ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"]
const CONSONANT_POOL = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ"]

static func get_weighted_random_jamo(custom_pool: Array = []) -> String:
	var pool = custom_pool if not custom_pool.is_empty() else ALL_DRAW_POOL
	var weighted_entries = []
	var total_weight = 0

	for item in pool:
		var ch = str(item)
		var r = get_rarity(ch)
		var weight = 100
		if r == "super_rare":
			weight = 10 # 4방향 회전 만능이라 그룹 총합이 커지므로 개별 가중치는 가장 낮게
		elif r == "rare":
			weight = get_rare_draw_weight(ch)
		weighted_entries.append({"char": ch, "weight": weight})
		total_weight += weight

	var roll = randi_range(1, total_weight)
	var current_acc = 0
	for entry in weighted_entries:
		current_acc += entry["weight"]
		if roll <= current_acc:
			return entry["char"]

	return ALL_DRAW_POOL.pick_random()

static func get_rare_draw_weight(char_str: String) -> int:
	return 48 if char_str in CONSONANT_POOL else 30

# 3개의 보상 선택지 생성 시 최소 1개는 반드시 모음이 나오도록 보장
static func generate_reward_choices(count: int = 3) -> Array:
	var choices = []
	# 1번: 무작위 가중치 뽑기
	choices.append(get_weighted_random_jamo())
	# 2번: 확정 모음 슬롯 (단어 조합을 원활하게 하기 위해 모음 보장)
	choices.append(get_weighted_random_jamo(VOWEL_POOL))
	# 3번 이후: 무작위 가중치 뽑기
	for i in range(2, count):
		choices.append(get_weighted_random_jamo())

	choices.shuffle()
	return choices

static func is_rotatable(char_str: String) -> bool:
	return ROTATABLE_TILES.has(char_str)

static func rotate(char_str: String) -> String:
	return ROTATABLE_TILES.get(char_str, char_str)

static func compose_syllable(cho: String, jung: String, jong: String = "") -> String:
	var cho_idx = CHOSUNG.find(cho)
	var jung_idx = JUNGSUNG.find(jung)
	var jong_idx = JONGSUNG.find(jong)

	if cho_idx == -1 or jung_idx == -1:
		return cho + jung + jong

	if jong_idx == -1:
		jong_idx = 0

	var unicode_val = 0xAC00 + (cho_idx * 21 * 28) + (jung_idx * 28) + jong_idx
	return String.chr(unicode_val)

static func combine_jamo(cho: String, jung: String, jong: String = "") -> String:
	return compose_syllable(cho, jung, jong)

static func decompose_syllable(syllable: String) -> Dictionary:
	if syllable.length() == 0:
		return {"chosung": "", "jungsung": "", "jongsung": ""}

	var code = syllable.unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return {"chosung": syllable, "jungsung": "", "jongsung": ""}

	var syl_idx = code - 0xAC00
	var cho_idx = int(syl_idx / (21 * 28))
	var jung_idx = int((syl_idx % (21 * 28)) / 28)
	var jong_idx = int(syl_idx % 28)

	return {
		"chosung": CHOSUNG[cho_idx] if cho_idx < CHOSUNG.size() else "",
		"jungsung": JUNGSUNG[jung_idx] if jung_idx < JUNGSUNG.size() else "",
		"jongsung": JONGSUNG[jong_idx] if jong_idx < JONGSUNG.size() else ""
	}

static func is_consonant(c: String) -> bool:
	return CHOSUNG.has(c) or JONGSUNG.has(c)

static func is_vowel(c: String) -> bool:
	return JUNGSUNG.has(c) or VOWEL_COMBINATIONS.has(c)
