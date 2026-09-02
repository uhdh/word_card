# HangulEngine.gd
# 15종 핵심 자모(ㄱ,ㄴ,ㄷ,ㄹ,ㅁ,ㅂ,ㅅ,ㅇ,ㅈ / ㅏ,ㅓ,ㅗ,ㅜ,ㅡ,ㅣ) 기반 한글 조합 및 희귀도 엔진
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

# Rarity System: ㄱ, ㅡ, ㅜ are high-value RARE tiles
const RARE_TILES = ["ㄱ", "ㅡ", "ㅜ"]

# 15 Valid Draw Pool (Excluded: ㅑ, ㅕ, ㅛ, ㅠ and ㅋ, ㅌ, ㅊ, ㅍ, ㅎ)
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

func is_rare(char_str: String) -> bool:
	return RARE_TILES.has(char_str)

func get_weighted_random_jamo(custom_pool: Array = []) -> String:
	var pool = custom_pool if not custom_pool.is_empty() else ALL_DRAW_POOL
	var weighted_entries = []
	var total_weight = 0

	for item in pool:
		var ch = str(item)
		var weight = 20 if is_rare(ch) else 100 # Rare tiles have 1/5 probability
		weighted_entries.append({"char": ch, "weight": weight})
		total_weight += weight

	var roll = randi_range(1, total_weight)
	var current = 0
	for entry in weighted_entries:
		current += entry["weight"]
		if roll <= current:
			return entry["char"]

	return pool.pick_random()

func is_rotatable(char_str: String) -> bool:
	return ROTATABLE_TILES.has(char_str)

func rotate(char_str: String) -> String:
	return ROTATABLE_TILES.get(char_str, char_str)

func can_combine(char1: String, char2: String) -> bool:
	var key1 = char1 + "+" + char2
	var key2 = char2 + "+" + char1
	return CONSONANT_COMBINATIONS.has(key1) or CONSONANT_COMBINATIONS.has(key2) or \
		   VOWEL_COMBINATIONS.has(key1) or VOWEL_COMBINATIONS.has(key2)

func combine(char1: String, char2: String) -> String:
	var key1 = char1 + "+" + char2
	var key2 = char2 + "+" + char1
	if CONSONANT_COMBINATIONS.has(key1): return CONSONANT_COMBINATIONS[key1]
	if CONSONANT_COMBINATIONS.has(key2): return CONSONANT_COMBINATIONS[key2]
	if VOWEL_COMBINATIONS.has(key1): return VOWEL_COMBINATIONS[key1]
	if VOWEL_COMBINATIONS.has(key2): return VOWEL_COMBINATIONS[key2]
	return ""

func compose_syllable(chosung: String, jungsung: String, jongsung: String = "") -> String:
	var cho_idx = CHOSUNG.find(chosung)
	var jung_idx = JUNGSUNG.find(jungsung)
	var jong_idx = JONGSUNG.find(jongsung)

	if cho_idx == -1 or jung_idx == -1:
		return ""
	if jong_idx == -1:
		jong_idx = 0

	var unicode = 0xAC00 + (cho_idx * 21 * 28) + (jung_idx * 28) + jong_idx
	return String.chr(unicode)

func decompose_syllable(syllable: String) -> Dictionary:
	if syllable.length() != 1:
		return {}

	var code = syllable.unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return {}

	var offset = code - 0xAC00
	var jong_idx = offset % 28
	var jung_idx = (offset / 28) % 21
	var cho_idx = offset / (21 * 28)

	return {
		"chosung": CHOSUNG[cho_idx],
		"jungsung": JUNGSUNG[jung_idx],
		"jongsung": JONGSUNG[jong_idx]
	}
