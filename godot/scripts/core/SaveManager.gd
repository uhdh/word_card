# SaveManager.gd
# 게임 상태 (자모 벨트, 기지 체력, 골드, 현재 막/웨이브, 리롤 주사위, 보유 유물) 및 단어 도감 해금 영구 저장 유틸리티
class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://tower_defense_save.json"
const DISCOVERED_PATH: String = "user://discovered_lexicon.json"
const TEST_SAVE_PATH: String = "user://tower_defense_save_test.json"
const TEST_DISCOVERED_PATH: String = "user://discovered_lexicon_test.json"

static var _cached_discovered: Array = []
static var _is_discovered_loaded: bool = false

static func _is_test_run() -> bool:
	for arg in OS.get_cmdline_args():
		var a := arg.replace("\\", "/")
		# tools/ 아래 진단 스크립트도 반드시 테스트 경로를 써야 한다.
		# 안 그러면 플레이어의 실제 세이브를 덮어쓰거나 지워 버린다.
		#
		# ⚠️ 2026-09-23 — 이름을 하나씩 나열하는 방식은 **실제로 샜다.** `tools/CelebrationProbe`
		# 와 `tools/ActClearModalProbe` 를 새로 만들면서 여기에 등록하지 않았고, 그 둘은
		# 플레이어의 **실제** 도감 파일(`user://discovered_lexicon.json`)을 향하고 있었다.
		# (CelebrationProbe 가 파싱한 `가`·`속` 이 이미 해금돼 있어 쓰기가 일어나지 않았을 뿐 —
		#  즉 운으로 무사했지 구조적으로 안전하지 않았다.)
		# 그래서 이름 나열 **위에 경로 규칙**을 하나 둔다. 새 도구가 생겨도 자동으로 덮인다.
		if a.contains("/tools/"):
			return true
		if a.contains("/tests/") or a.contains("AutoPlayTDTest") or a.contains("AutoPlayTest"):
			return true
		if a.contains("EconomyProbe") or a.contains("EconomyPlaytest"):
			return true
		if a.contains("DifficultyPlaytest"):
			return true
		# tools/Shot (스크린샷 도구) 도 테스트 경로를 써야 한다.
		# 실제 세이브를 읽으면 캡처에 저장된 막/웨이브/타워가 섞여 들어오고,
		# fresh=1 로 초기화할 때 플레이어의 진행을 지워 버린다.
		if a.contains("/tools/Shot") or a.contains("Shot.tscn"):
			return true
		# tools/FrameStrip (연속 프레임 캡처) 도 같은 이유로 테스트 경로를 쓴다.
		if a.contains("FrameStrip"):
			return true
		# tools/TraitBlastProbe (특성 다중 타격 실측) 도 같은 이유로 테스트 경로를 쓴다.
		if a.contains("TraitBlastProbe"):
			return true
		# tools/SaveSchemaProbe (세이브 키 정렬 검증) 도 같은 이유로 테스트 경로를 쓴다.
		if a.contains("SaveSchemaProbe"):
			return true
		# tools/PauseAbilityProbe (일시정지·밀어내기 실측) 도 같은 이유로 테스트 경로를 쓴다.
		if a.contains("PauseAbilityProbe"):
			return true
	return false

static func _save_path() -> String:
	return TEST_SAVE_PATH if _is_test_run() else SAVE_PATH

static func _lexicon_path() -> String:
	return TEST_DISCOVERED_PATH if _is_test_run() else DISCOVERED_PATH

static func has_save_file() -> bool:
	return FileAccess.file_exists(_save_path())

static func save_game(jamo_list: Array, base_hp: int, max_base_hp: int, gold: int, current_wave: int, reroll_dice: int = 3, relics: Array = [], current_act: int = 1, unlocked_slots: int = 3, slot_assignments: Array = [], tower_damage: Dictionary = {}, tower_positions: Array = [], orbit_directions: Dictionary = {}, target_modes: Dictionary = {}, tile_purchase_count: int = 0) -> bool:
	var save_dict = {
		"jamo_list": jamo_list,
		"base_hp": base_hp,
		"max_base_hp": max_base_hp,
		"gold": gold,
		"current_act": current_act,
		"current_wave": current_wave,
		"reroll_dice": reroll_dice,
		"relics": relics,
		"unlocked_slots": unlocked_slots,
		"slot_assignments": slot_assignments,
		"tower_damage": tower_damage,
		"tower_positions": tower_positions,
		"orbit_directions": orbit_directions,
		"target_modes": target_modes,
		"tile_purchase_count": tile_purchase_count,
		"saved_at": Time.get_datetime_string_from_system()
	}

	var json_str = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for write: %s" % _save_path())
		return false

	file.store_string(json_str)
	file.close()
	print("💾 [SaveManager] Game successfully saved! (Act %d, Wave %d, Gold %d, Dice %d, Relics %d, Jamo %d)" % [
		current_act, current_wave, gold, reroll_dice, relics.size(), jamo_list.size()
	])
	return true

static func load_game() -> Dictionary:
	if not has_save_file():
		return {}

	var file = FileAccess.open(_save_path(), FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for read: %s" % _save_path())
		return {}

	var content = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(content)
	if typeof(parse_result) != TYPE_DICTIONARY:
		push_error("Corrupted save file content: %s" % content)
		return {}

	print("📂 [SaveManager] Game successfully loaded! (Act %d, Wave %d, Gold %d, Dice %d)" % [
		parse_result.get("current_act", 1), parse_result.get("current_wave", 0), parse_result.get("gold", 0), parse_result.get("reroll_dice", 3)
	])
	return parse_result

static func delete_save_file() -> void:
	if FileAccess.file_exists(_save_path()):
		DirAccess.remove_absolute(_save_path())
		print("🗑️ [SaveManager] Save file deleted successfully.")

# ==============================================================================
# 단어 도감 해금 (Lexicon Discovery) 시스템
# ==============================================================================
static func get_discovered_words() -> Array:
	if _is_discovered_loaded:
		return _cached_discovered

	_cached_discovered = ["불"] # Starting word is unlocked by default

	if FileAccess.file_exists(_lexicon_path()):
		var file = FileAccess.open(_lexicon_path(), FileAccess.READ)
		if file != null:
			var content = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(content)
			if typeof(parsed) == TYPE_ARRAY:
				for w in parsed:
					var w_str = str(w)
					if not _cached_discovered.has(w_str):
						_cached_discovered.append(w_str)

	_is_discovered_loaded = true
	return _cached_discovered

static func is_word_discovered(word_str: String) -> bool:
	var list = get_discovered_words()
	return list.has(word_str)

static func discover_word(word_str: String) -> bool:
	if word_str.is_empty():
		return false
	var list = get_discovered_words()
	if not list.has(word_str):
		list.append(word_str)
		_save_discovered_words()
		print("🌟 [Lexicon] New word discovered: [%s]!" % word_str)
		return true
	return false

static func _save_discovered_words() -> void:
	var json_str = JSON.stringify(_cached_discovered, "\t")
	var file = FileAccess.open(_lexicon_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()

# ==============================================================================
# 역대 런 랭킹 (Run Ranking)
# ==============================================================================
# 도감과 같은 이유로 영구 파일을 따로 쓴다 — 진행 중인 세이브(SAVE_PATH)에 얹으면
# '새 게임' 한 번에 역대 기록이 통째로 날아간다.
const RANKING_PATH: String = "user://run_ranking.json"
const TEST_RANKING_PATH: String = "user://run_ranking_test.json"
const RANKING_LIMIT: int = 10

static func _ranking_path() -> String:
	return TEST_RANKING_PATH if _is_test_run() else RANKING_PATH

## a 가 b 보다 **앞에 서야 하면** true.
##
## **점수를 만들어 가중치를 주지 않는다.** 이 프로젝트는 이미 자체 공식으로 DPS 를 지어내
## 실제 값과 어긋난 적이 있다(추천 패널). 랭킹은 "누가 더 나았나" 를 정하는 자리라,
## 여기서 숫자를 지어내면 순위 전체가 거짓말이 된다. 그래서 관찰 가능한 사실만 순서로
## 쓴다: 이겼는가 → 어디까지 갔는가 → 얼마나 때렸는가.
## 가중치를 정하고 싶어지면 그건 디렉터가 정할 몫이고, 그때도 근거가 화면에 보여야 한다.
static func run_ranking_is_better(a: Dictionary, b: Dictionary) -> bool:
	var a_win := bool(a.get("victory", false))
	var b_win := bool(b.get("victory", false))
	if a_win != b_win:
		return a_win
	var a_act := int(a.get("act", 1))
	var b_act := int(b.get("act", 1))
	if a_act != b_act:
		return a_act > b_act
	var a_wave := int(a.get("wave", 0))
	var b_wave := int(b.get("wave", 0))
	if a_wave != b_wave:
		return a_wave > b_wave
	return float(a.get("total_damage", 0.0)) > float(b.get("total_damage", 0.0))

## 저장된 역대 기록(좋은 순). 파일이 없거나 깨졌으면 빈 배열.
static func get_run_ranking() -> Array:
	if not FileAccess.file_exists(_ranking_path()):
		return []
	var file = FileAccess.open(_ranking_path(), FileAccess.READ)
	if file == null:
		return []
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Corrupted ranking file content: %s" % content)
		return []
	var out: Array = []
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	out.sort_custom(run_ranking_is_better)
	return out

## 이번 런을 기록한다. 반환 {"rank", "total", "is_best", "entries"}.
##
## rank 는 '나보다 나은 기록의 수 + 1' 로 센다. 방금 넣은 항목을 배열에서 다시 찾는
## 방식(find)은 값이 완전히 같은 런이 둘일 때 엉뚱한 쪽을 잡는다 — 동점 런은 실제로
## 나올 수 있으므로 세는 방식이 맞다.
static func submit_run(entry: Dictionary) -> Dictionary:
	var stored := entry.duplicate(true)
	stored["played_at"] = Time.get_datetime_string_from_system()
	var previous := get_run_ranking()
	var better := 0
	for other in previous:
		if run_ranking_is_better(other, stored):
			better += 1
	var ranking := previous.duplicate()
	ranking.append(stored)
	ranking.sort_custom(run_ranking_is_better)
	var kept: Array = ranking.slice(0, RANKING_LIMIT)
	_write_run_ranking(kept)
	# 이번 런이 상위 목록 안에서 **몇 번째 줄인지**를 돌려준다(-1 이면 상위 밖).
	# 값 비교로 화면에서 다시 찾게 하면 동점 런에서 엉뚱한 줄이 강조된다 —
	# played_at 이 초 단위로 다르므로 여기서 한 번만 찾는 편이 정확하다.
	return {
		"rank": better + 1,
		"total": ranking.size(),
		"is_best": better == 0,
		"index": kept.find(stored),
		"entries": kept,
	}

static func clear_run_ranking() -> void:
	if FileAccess.file_exists(_ranking_path()):
		DirAccess.remove_absolute(_ranking_path())

static func _write_run_ranking(entries: Array) -> void:
	var file = FileAccess.open(_ranking_path(), FileAccess.WRITE)
	if file == null:
		push_error("Failed to open ranking file for write: %s" % _ranking_path())
		return
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()
