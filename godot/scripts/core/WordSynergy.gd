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

static func bonuses(word: String, relic_ids: Array) -> Dictionary:
	var a = analyze(word)
	var b = {"damage": 1.0, "interval": 1.0, "range": 1.0, "crit": 0.0, "labels": []}
	var rules = [
		["relic_tense_hammer", "has_tense", "damage", 1.25, "된소리 망치"], ["relic_final_weight", "has_final", "damage", 1.2, "종성의 무게추"],
		["relic_open_feather", "has_final", "interval", 0.82, "민소리 깃털", true], ["relic_cluster_anvil", "has_cluster", "damage", 1.35, "겹받침 모루"],
		["relic_vowel_crystal", "has_compound_vowel", "range", 1.2, "겹모음 수정"], ["relic_initial_drum", "repeated_initial", "damage", 1.25, "첫소리 북"],
		["relic_vowel_resonance", "repeated_vowel", "interval", 0.8, "모음 공명석"], ["relic_consonant_ring", "linked", "crit", 0.2, "자음 고리"],
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

static func initial_hint(belt: Array, words: Array, offset: int) -> String:
	var candidates := []
	for data in words:
		var word = str(data.get("word", ""))
		var needed := []
		for c in word:
			var p = HangulEngine.decompose_syllable(c)
			needed.append_array(EXPAND.get(p["chosung"], [p["chosung"]]))
			needed.append_array(EXPAND.get(p["jungsung"], [p["jungsung"]]))
			if p["jongsung"] != "": needed.append_array(EXPAND.get(p["jongsung"], [p["jongsung"]]))
		var available = belt.duplicate()
		var buildable := true
		for required in needed:
			var found := -1
			for i in range(available.size()):
				var rotated = available[i]
				for ignored in range(4):
					if rotated == required: found = i; break
					rotated = HangulEngine.rotate(rotated)
				if found >= 0: break
			if found < 0: buildable = false; break
			available.remove_at(found)
		if buildable: candidates.append(word)
	if candidates.is_empty(): return ""
	candidates.sort_custom(func(a, b): return a.length() > b.length())
	candidates = candidates.filter(func(word): return word.length() == candidates[0].length())
	var result := ""
	for c in candidates[offset % candidates.size()]: result += HangulEngine.decompose_syllable(c)["chosung"]
	return result
