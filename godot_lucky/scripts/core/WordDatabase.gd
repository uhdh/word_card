# WordDatabase.gd
# 15종 기본 유효 자모로 구성된 전체 단어 타워 DB
extends Node

var WORD_DATABASE: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://assets/data/word_database_265.json", FileAccess.READ)
	if file == null:
		push_error("265종 연성 비급 데이터를 열 수 없습니다.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("265종 연성 비급 데이터가 올바르지 않습니다.")
		return
	WORD_DATABASE = parsed
	for data in WORD_DATABASE.values():
		data["icon"] = str(data.get("icon", "")).replace("./assets/", "res://assets/")
	var expansion_file = FileAccess.open("res://assets/data/word_database_expansion_100.json", FileAccess.READ)
	if expansion_file != null:
		var expansion = JSON.parse_string(expansion_file.get_as_text())
		if typeof(expansion) == TYPE_DICTIONARY:
			for key in expansion:
				var word_key := str(key)
				if WORD_DATABASE.has(word_key):
					push_error("중복 단어를 확장 DB에서 건너뜁니다: " + word_key)
					continue
				var data: Dictionary = expansion[key]
				data["icon"] = str(data.get("icon", "")).replace("./assets/", "res://assets/")
				WORD_DATABASE[word_key] = data
	WORD_DATABASE["돼지"] = {
		"word": "돼지", "name": "돼지 (돌진/꿀꿀 박치기)", "category": "summon",
		"tier": 2, "cost": 2, "damage": 30,
		"desc": "돼지가 빠르게 돌진해 연속 박치기 피해를 줍니다.",
		"icon": "res://assets/monsters/monster_boar_1_32px_pastel.png", "sound": "play_attack"
	}

func get_word_data(word: String) -> Dictionary:
	return WORD_DATABASE.get(word, {})

func get_all_words() -> Array:
	return WORD_DATABASE.values()

func get_words_by_category(cat: String) -> Array:
	var result = []
	for w in WORD_DATABASE.values():
		if w.get("category") == cat:
			result.append(w)
	return result
