# HangulEngine.gd
# 한글 자모 분해, 합성, 회전, 완성형 음절 조합 엔진
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

const ROTATABLE_TILES = {
	"ㄱ": "ㄴ", "ㄴ": "ㄱ",
	"ㅏ": "ㅜ", "ㅜ": "ㅓ", "ㅓ": "ㅗ", "ㅗ": "ㅏ",
	"ㅣ": "ㅡ", "ㅡ": "ㅣ"
}

const CONSONANT_COMBINATIONS = {
	"ㄱ+ㄱ": "ㄲ", "ㄷ+ㄷ": "ㄸ", "ㅂ+ㅂ": "ㅃ", "ㅅ+ㅅ": "ㅆ", "ㅈ+ㅈ": "ㅉ",
	"ㄱ+ㅅ": "ㄳ", "ㄴ+ㅈ": "ㄵ", "ㄴ+ㅎ": "ㄶ", "ㄹ+ㄱ": "ㄺ", "ㄹ+ㅁ": "ㄻ",
	"ㄹ+ㅂ": "ㄼ", "ㄹ+ㅅ": "ㄽ", "ㄹ+ㅌ": "ㄾ", "ㄹ+ㅍ": "ㄿ", "ㄹ+ㅎ": "ㅀ",
	"ㅂ+ㅅ": "ㅄ"
}

const VOWEL_COMBINATIONS = {
	"ㅗ+ㅏ": "ㅘ", "ㅗ+ㅐ": "ㅙ", "ㅗ+ㅣ": "ㅚ",
	"ㅜ+ㅓ": "ㅝ", "ㅜ+ㅔ": "ㅞ", "ㅜ+ㅣ": "ㅟ",
	"ㅡ+ㅣ": "ㅢ", "ㅏ+ㅣ": "ㅐ", "ㅓ+ㅣ": "ㅔ",
	"ㅑ+ㅣ": "ㅒ", "ㅕ+ㅣ": "ㅖ"
}

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

func compose_syllable(cho: String, jung: String, jong: String = "") -> String:
	var cho_idx = CHOSUNG.find(cho)
	var jung_idx = JUNGSUNG.find(jung)
	var jong_idx = JONGSUNG.find(jong)

	if cho_idx == -1 or jung_idx == -1:
		return ""
	if jong_idx == -1:
		jong_idx = 0

	var code = 0xAC00 + (cho_idx * 21 * 28) + (jung_idx * 28) + jong_idx
	return String.chr(code)

func decompose_syllable(syllable: String) -> Dictionary:
	if syllable.length() != 1:
		return {}
	var code = syllable.unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return {}

	var offset = code - 0xAC00
	var jong_idx = offset % 28
	var jung_idx = int(offset / 28) % 21
	var cho_idx = int(offset / (21 * 28))

	return {
		"cho": CHOSUNG[cho_idx],
		"jung": JUNGSUNG[jung_idx],
		"jong": JONGSUNG[jong_idx]
	}


