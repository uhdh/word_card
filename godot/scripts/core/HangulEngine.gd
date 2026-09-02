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
	"ㄱ+ㅅ": "ㄳ", "ㄴ+ㅈ": "ㄵ", "ㄹ+ㄱ": "ㄺ", "ㄹ+ㅁ": "ㄻ",
	"ㄹ+ㅂ": "ㄼ", "ㄹ+ㅅ": "ㄽ", "ㅂ+ㅅ": "ㅄ"
}

const VOWEL_COMBINATIONS = {
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

# 등급별 배경 색상 (별 모양 텍스트 대신 배경색으로 분류)
static func get_rarity_bg_color(char_str: String) -> Color:
	var r = get_rarity(char_str)
	if r == "super_rare":
		return Color(0.38, 0.22, 0.05, 0.95) # 찬란한 골드 앰버 (Super Rare)
	elif r == "rare":
		return Color(0.24, 0.12, 0.42, 0.95) # 신비로운 딥 바이올렛 (Rare)
	return Color(0.14, 0.12, 0.20, 0.95)     # 다크 슬레이트 (Common)

static func get_rarity_border_color(char_str: String) -> Color:
	var r = get_rarity(char_str)
	if r == "super_rare":
		return Color(0.96, 0.65, 0.10, 1.0) # 황금빛 테두리
	elif r == "rare":
		return Color(0.68, 0.35, 0.98, 1.0) # 보랏빛 테두리
	return Color(0.35, 0.30, 0.48, 0.8)     # 차분한 슬레이트 테두리

static func get_weighted_random_jamo(custom_pool: Array = []) -> String:
	var pool = custom_pool if not custom_pool.is_empty() else ALL_DRAW_POOL
	var weighted_entries = []
	var total_weight = 0

	for item in pool:
		var ch = str(item)
		var r = get_rarity(ch)
		var weight = 100
		if r == "super_rare":
			weight = 10 # 4변환 만능 모음: 가장 희귀 (1/10 확률)
		elif r == "rare":
			weight = 30 # 2변환 자음/모음: 희귀 (약 1/3 확률)
		weighted_entries.append({"char": ch, "weight": weight})
		total_weight += weight

	var roll = randi_range(1, total_weight)
	var current_acc = 0
	for entry in weighted_entries:
		current_acc += entry["weight"]
		if roll <= current_acc:
			return entry["char"]

	return ALL_DRAW_POOL.pick_random()

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
