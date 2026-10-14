# SaveSchemaProbe.gd — 세이브 스키마 검증 프로브.
#
#   godot --headless --path . res://tools/SaveSchemaProbe.tscn
#
# 왜 필요한가: SaveManager.save_game 은 **위치 인자(positional)** 함수다.
# 시그니처에서 인자를 빼거나 순서를 바꾸면서 호출부에서도 같이 고치지 않으면,
# 남은 값들이 엉뚱한 JSON 키로 조용히 밀려 들어간다 — 컴파일도, 다른 테스트도
# 실패하지 않고, 그저 플레이어의 세이브가 조용히 깨진다. 이 프로브는 그 정렬을
# 검증한다. 센티넬 값(서로 절대 겹치지 않는 값)을 위치 인자로 넣고, 파일에서
# 읽은 JSON 키마다 그대로 들어 있는지 확인한다.
#
# 특히 orbit_directions 와 target_modes 를 집중해서 본다 — 이 둘은 밀리면
# 조용히 사라지는 자리다(정수 키/JSON 문자열 키 규칙도 DefenseField 를 참고).
#
# 주의: 이 스크립트 이름은 SaveManager._is_test_run() 에 있어야 한다.
#       안 그러면 플레이어의 실제 세이브를 덮어쓴다.
extends Node2D

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _ready() -> void:
	var path := SaveManager._save_path()
	var global_path := ProjectSettings.globalize_path(path)
	# 1) 원본 세이브 백업 — 검증 후 반드시 복원한다.
	var had_original := FileAccess.file_exists(path)
	var original_content := ""
	if had_original:
		var file := FileAccess.open(path, FileAccess.READ)
		original_content = file.get_as_text()
		file.close()

	# 2) 센티넬 값으로 저장 — 각 위치 인자가 서로 확실히 구별되게 한다.
	var ok: bool = SaveManager.save_game(
		["검", "증"],
		41,
		50,
		4321,
		7,
		6,
		[{"id": "relic_probe"}],
		2,
		3,
		[1, 2, 3],
		{"프로브": 12.5},
		[4, 5, 6],
		{"0": true, "2": false},
		{"1": "strongest"},
		9
	)
	check(ok, "save_game must return true")

	# 3) 파일을 읽어 키마다 센티넬이 그대로 들어 있는지 확인한다.
	var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	check(typeof(parsed) == TYPE_DICTIONARY, "Saved file must parse to a dictionary")
	if typeof(parsed) == TYPE_DICTIONARY:
		check(parsed.get("jamo_list", []) == ["검", "증"], "jamo_list must not shift")
		check(int(parsed.get("base_hp", 0)) == 41, "base_hp must not shift")
		check(int(parsed.get("max_base_hp", 0)) == 50, "max_base_hp must not shift")
		check(int(parsed.get("gold", 0)) == 4321, "gold must not shift")
		check(int(parsed.get("current_wave", 0)) == 7, "current_wave must not shift")
		check(int(parsed.get("reroll_dice", 0)) == 6, "reroll_dice must not shift")
		var relics: Array = parsed.get("relics", [])
		check(relics.size() == 1 and str((relics[0] as Dictionary).get("id", "")) == "relic_probe", "relics must not shift")
		check(int(parsed.get("current_act", 0)) == 2, "current_act must not shift")
		check(int(parsed.get("unlocked_slots", 0)) == 3, "unlocked_slots must not shift")
		# JSON.parse_string 은 숫자를 전부 float 로 되돌린다. Godot 의 Array == 는
		# 해시 비교라 int 1 과 float 1.0 을 다르게 보므로, 배열은 원소를 숫자로 바꿔 비교한다.
		var slot_assignments: Array = parsed.get("slot_assignments", [])
		check(slot_assignments.size() == 3 and int(slot_assignments[0]) == 1 and int(slot_assignments[1]) == 2 and int(slot_assignments[2]) == 3, "slot_assignments must not shift")
		var tower_damage: Dictionary = parsed.get("tower_damage", {})
		check(float(tower_damage.get("프로브", 0.0)) == 12.5, "tower_damage must not shift")
		var tower_positions: Array = parsed.get("tower_positions", [])
		check(tower_positions.size() == 3 and int(tower_positions[0]) == 4 and int(tower_positions[1]) == 5 and int(tower_positions[2]) == 6, "tower_positions must not shift")
		# 이 둘이 밀리면 조용히 깨지는 자리다.
		var orbit_directions: Dictionary = parsed.get("orbit_directions", {})
		check(bool(orbit_directions.get("0", false)) == true and bool(orbit_directions.get("2", true)) == false, "orbit_directions must not shift")
		var target_modes: Dictionary = parsed.get("target_modes", {})
		check(str(target_modes.get("1", "")) == "strongest", "target_modes must not shift")
		check(int(parsed.get("tile_purchase_count", 0)) == 9, "tile_purchase_count must not shift")
		# 4) 제거된 키가 다시 생기면 안 된다.
		# 여기에 그 키 이름이 문자열로 남는 것은 정상이다 — 이 프로브가 그 키의
		# **부재를 주장하는 유일한 자리**이기 때문이다. 잔재를 셀 때는 이 파일을 뺀다.
		check(not parsed.has("tower_mastery"), "removed legacy key must be gone from the save schema")

	# 5) 원본 복원 — 빠뜨리면 플레이어/테스트 세이브가 오염된다.
	if had_original:
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(original_content)
		out.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if failures == 0:
		print("SAVE_SCHEMA_PROBE_OK")
	else:
		print("SAVE_SCHEMA_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
