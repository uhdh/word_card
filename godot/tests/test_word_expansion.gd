extends Node

const AutoArrange = preload("res://scripts/core/AutoArrange.gd")

var failures := 0

func _ready() -> void:
	_test_expansion_shape()
	_test_compound_vowels()
	_test_compound_consonants()
	_test_auto_arrange_and_parse_every_expansion()
	if failures == 0:
		print("word expansion tests passed")
	get_tree().quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_expansion_shape() -> void:
	var file := FileAccess.open("res://assets/data/word_database_expansion_100.json", FileAccess.READ)
	check(file != null, "Expansion JSON must exist")
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	check(typeof(parsed) == TYPE_DICTIONARY, "Expansion JSON must be an object")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	check(WordDatabase.WORD_DATABASE.size() == 366, "Runtime database must contain base 265 + expansion 100 + 돼지")
	var base_file := FileAccess.open("res://assets/data/word_database_265.json", FileAccess.READ)
	var base = JSON.parse_string(base_file.get_as_text()) if base_file != null else {}
	check(parsed.size() == 100, "Expansion JSON must contain exactly 100 words")
	var seen := {}
	var open_source_icons := {}
	for key in parsed:
		var word := str(key)
		check(not seen.has(word), "Expansion contains duplicate word: " + word)
		seen[word] = true
		var data: Dictionary = parsed[key]
		for field in ["word", "name", "category", "tier", "cost", "damage", "desc", "icon", "sound"]:
			check(data.has(field), "%s is missing %s" % [word, field])
		check(data.get("word", "") == word, "Expansion key and word field must agree: " + word)
		check(ResourceLoader.exists("res://" + str(data.get("icon", "")).replace("./assets/", "assets/")), "Missing icon for " + word)
		var icon_path := str(data.get("icon", ""))
		check(icon_path.begins_with("./assets/open_source/"), "Expansion must use an open-source icon: " + word)
		open_source_icons[icon_path] = true
		check(not base.has(word), "Expansion duplicates a base word: " + word)
	check(open_source_icons.size() >= 80, "Expansion should use at least 80 distinct icons")

func _test_compound_vowels() -> void:
	var parsed_wae := HangulStreamParser.parse_jamo_stream(["ㄷ", "ㅗ", "ㅏ", "ㅣ", "ㅈ", "ㅣ"])
	check(parsed_wae.size() == 1 and parsed_wae[0].syllable == "돼지", "Three-vowel 돼지 recipe must parse")
	var parsed_we := HangulStreamParser.parse_jamo_stream(["ㄱ", "ㅜ", "ㅓ", "ㅣ"])
	check(parsed_we.size() == 1 and parsed_we[0].syllable == "궤", "Three-vowel ㅞ recipe must parse")

func _test_compound_consonants() -> void:
	var parsed_final := HangulStreamParser.parse_jamo_stream(["ㄷ", "ㅏ", "ㄹ", "ㄱ"])
	check(parsed_final.size() == 1 and parsed_final[0].syllable == "닭", "ㄷ+ㅏ+ㄹ+ㄱ must parse as 닭")
	var parsed_initial := HangulStreamParser.parse_jamo_stream(["ㄱ", "ㄱ", "ㅏ"])
	check(parsed_initial.size() == 1 and parsed_initial[0].syllable == "까", "Double initial consonants must parse")
	var parsed_nieun_hieut := HangulStreamParser.parse_jamo_stream(["ㅇ", "ㅏ", "ㄴ", "ㅎ"])
	check(parsed_nieun_hieut.size() == 1 and parsed_nieun_hieut[0].syllable == "않", "ㄴ+ㅎ double final must parse")

func _test_auto_arrange_and_parse_every_expansion() -> void:
	var file := FileAccess.open("res://assets/data/word_database_expansion_100.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in parsed:
		var word := str(key)
		var data: Dictionary = parsed[key]
		var slots := AutoArrange.get_word_syllable_slots(word)
		var owned: Array[String] = []
		for syllable in slots:
			for slot in syllable:
				for tile in slot:
					owned.append(str(tile))
		var arranged := AutoArrange.shuffled_tiles_for(owned, [data])
		check(arranged.get("word", "") == word, "AutoArrange cannot build " + word)
		var rebuilt := HangulStreamParser.parse_jamo_stream(arranged.get("tiles", []))
		check(rebuilt.size() == 1 and rebuilt[0].get("syllable", "") == word, "Parser cannot rebuild " + word)
