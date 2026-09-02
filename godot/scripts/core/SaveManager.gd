# SaveManager.gd
# 게임 상태 (자모 벨트, 기지 체력, 골드, 도달 웨이브 등) 영구 저장 및 불러오기 유틸리티
class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://tower_defense_save.json"

static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save_game(jamo_list: Array, base_hp: int, max_base_hp: int, gold: int, current_wave: int) -> bool:
	var save_dict = {
		"jamo_list": jamo_list,
		"base_hp": base_hp,
		"max_base_hp": max_base_hp,
		"gold": gold,
		"current_wave": current_wave,
		"saved_at": Time.get_datetime_string_from_system()
	}

	var json_str = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for write: %s" % SAVE_PATH)
		return false

	file.store_string(json_str)
	file.close()
	print("💾 [SaveManager] Game successfully saved! (Wave %d, Gold %d, Jamo %d)" % [current_wave, gold, jamo_list.size()])
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

	print("📂 [SaveManager] Game successfully loaded! (Wave %d, Gold %d)" % [
		parse_result.get("current_wave", 0), parse_result.get("gold", 0)
	])
	return parse_result
