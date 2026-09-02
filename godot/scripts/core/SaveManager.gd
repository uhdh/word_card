# SaveManager.gd
# 게임 상태 (자모 벨트, 기지 체력, 골드, 도달 웨이브, 리롤 주사위 등) 및 단어 도감 해금 영구 저장 유틸리티
class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://tower_defense_save.json"
const DISCOVERED_PATH: String = "user://discovered_lexicon.json"

static var _cached_discovered: Array = []
static var _is_discovered_loaded: bool = false

static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save_game(jamo_list: Array, base_hp: int, max_base_hp: int, gold: int, current_wave: int, reroll_dice: int = 3) -> bool:
	var save_dict = {
		"jamo_list": jamo_list,
		"base_hp": base_hp,
		"max_base_hp": max_base_hp,
		"gold": gold,
		"current_wave": current_wave,
		"reroll_dice": reroll_dice,
		"saved_at": Time.get_datetime_string_from_system()
	}

	var json_str = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for write: %s" % SAVE_PATH)
		return false

	file.store_string(json_str)
	file.close()
	print("💾 [SaveManager] Game successfully saved! (Wave %d, Gold %d, Dice %d, Jamo %d)" % [current_wave, gold, reroll_dice, jamo_list.size()])
	return true

static func load_game() -> Dictionary:
	if not has_save_file():
		return {}

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for read: %s" % SAVE_PATH)
		return {}

	var content = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(content)
	if typeof(parse_result) != TYPE_DICTIONARY:
		push_error("Corrupted save file content: %s" % content)
		return {}

	print("📂 [SaveManager] Game successfully loaded! (Wave %d, Gold %d, Dice %d)" % [
		parse_result.get("current_wave", 0), parse_result.get("gold", 0), parse_result.get("reroll_dice", 3)
	])
	return parse_result

# ==============================================================================
# 단어 도감 해금 (Lexicon Discovery) 시스템
# ==============================================================================
static func get_discovered_words() -> Array:
	if _is_discovered_loaded:
		return _cached_discovered

	_cached_discovered = ["불"] # Starting word is unlocked by default

	if FileAccess.file_exists(DISCOVERED_PATH):
		var file = FileAccess.open(DISCOVERED_PATH, FileAccess.READ)
		if file != null:
			var content = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(content)
			if typeof(parsed) == TYPE_ARRAY:
				for item in parsed:
					var w = str(item)
					if not _cached_discovered.has(w):
						_cached_discovered.append(w)

	_is_discovered_loaded = true
	return _cached_discovered

static func is_word_discovered(word: String) -> bool:
	var list = get_discovered_words()
	return list.has(word)

static func discover_word(word: String) -> bool:
	if word == "" or not WordDatabase.WORD_DATABASE.has(word):
		return false

	var list = get_discovered_words()
	if not list.has(word):
		list.append(word)
		_save_discovered_words()
		print("✨ [Lexicon] 새 단어 도감 해금: [%s] (총 발견: %d개)" % [word, list.size()])
		return true
	return false

static func _save_discovered_words() -> void:
	var json_str = JSON.stringify(_cached_discovered, "\t")
	var file = FileAccess.open(DISCOVERED_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()
