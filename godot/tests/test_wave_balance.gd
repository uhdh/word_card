extends Node

const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const ShopModalScript = preload("res://scripts/ui/ShopModal.gd")
const DefenseFieldScene = preload("res://scenes/tower/DefenseField.tscn")


var failures := 0


func _ready() -> void:
	_test_wave_compositions()
	_test_enemy_hp_progression()
	_test_gold_income()
	_test_enemy_shield()
	_test_relic_icons_are_unique()
	_test_tower_slots_follow_marked_map_positions()
	_test_three_slots_start_unlocked()
	_test_towers_keep_assigned_slot_positions()
	if failures == 0:
		print("wave balance tests passed")
	get_tree().quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()


func _test_wave_compositions() -> void:
	var field = DefenseFieldScript.new()
	var expected_counts = [[7, 10, 13, 16, 18, 15], [12, 16, 20, 24, 28, 20], [16, 20, 24, 28, 32, 24]]
	check(DefenseFieldScript.MAX_WAVES_PER_ACT == 6, "Each act must contain six waves")
	for act in range(1, 4):
		for wave in range(1, 7):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			check(field.spawn_queue.size() == expected_counts[act - 1][wave - 1], "Act %d wave %d enemy count is wrong" % [act, wave])
			var bosses = field.spawn_queue.filter(func(enemy): return enemy.get("type") == "boss")
			check(bosses.size() == (1 if wave == 6 else 0), "Act %d wave %d boss placement is wrong" % [act, wave])
	check(_has_type(field, 1, "fast"), "Act 1 needs a fast enemy")
	check(_has_type(field, 1, "armored"), "Act 1 needs an armored enemy")
	field.free()


func _test_enemy_hp_progression() -> void:
	var expected_hp = [[8.0, 6.0, 12.0, 8.0, 5.0], [30.0, 20.0, 40.0, 30.0, 15.0], [45.0, 30.0, 55.0, 40.0, 22.0]]
	var field = DefenseFieldScript.new()
	for act in range(1, 4):
		field.spawn_queue.clear()
		field._build_wave_monsters(act, 1)
		for enemy in field.spawn_queue:
			var type: String = enemy["type"]
			var index = ["normal", "fast", "armored"].find(type)
			check(enemy["hp"] == expected_hp[act - 1][index], "Act %d %s HP is wrong" % [act, type])
			if type == "armored": check(enemy["shield"] == expected_hp[act - 1][3], "Act %d armored shield is wrong" % act)
		field.spawn_queue.clear()
		field._build_wave_monsters(act, 3)
		check(field.spawn_queue[0]["hp"] == expected_hp[act - 1][4], "Act %d swarm HP is wrong" % act)
	field.free()


func _has_type(field, act: int, type: String) -> bool:
	for wave in range(1, 7):
		field.spawn_queue.clear()
		field._build_wave_monsters(act, wave)
		for enemy in field.spawn_queue:
			if enemy.get("type", "normal") == type:
				return true
	return false


func _test_gold_income() -> void:
	var field = DefenseFieldScript.new()
	for act in range(1, 4):
		for wave in range(1, 7):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			for enemy in field.spawn_queue:
				if enemy.get("type") != "boss":
					check(enemy["gold"] <= 2, "regular enemies must award at most 2 gold")
	field.current_wave = 1
	check(is_equal_approx(field.SPAWN_INTERVAL, 0.65), "Spawn interval must be 0.65 seconds")
	check(field._wave_clear_bonus() == 10, "regular wave clear must award 10 gold")
	field.current_wave = 6
	check(field._wave_clear_bonus() == 20, "act clear must award 20 gold")
	field.free()


func _test_enemy_shield() -> void:
	var enemy = EnemyUnitScript.new()
	var has_shield := enemy.get_property_list().any(func(property): return property["name"] == "shield")
	check(has_shield, "armored enemies need a shield property")
	if not has_shield:
		return
	enemy.init_enemy.callv(["중갑병", 100.0, 50.0, 2, "", 40.0])
	enemy.take_damage(25.0, false)
	check(enemy.shield == 15.0, "shield must absorb damage first")
	check(enemy.hp == 100.0, "HP must remain while shield absorbs damage")
	enemy.take_damage(25.0, false)
	check(enemy.shield == 0.0, "shield must be depleted")
	check(enemy.hp == 90.0, "overflow damage must reduce HP")
	enemy.free()


func _test_relic_icons_are_unique() -> void:
	var icons: Dictionary = {}
	var image_hashes: Dictionary = {}
	for relic in ShopModalScript.ALL_RELIC_POOL:
		var icon: String = relic["icon"]
		check(not icons.has(icon), "%s and %s share %s" % [icons.get(icon, ""), relic["id"], icon])
		check(FileAccess.file_exists(icon), "%s icon is missing: %s" % [relic["id"], icon])
		var hash := _sha256(icon)
		check(not image_hashes.has(hash), "%s and %s use the same image" % [image_hashes.get(hash, ""), relic["id"]])
		icons[icon] = relic["id"]
		image_hashes[hash] = relic["id"]


func _test_tower_slots_follow_marked_map_positions() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	var expected = [Vector2(255.0 / 1024.0, 140.0 / 352.0), Vector2(405.0 / 1024.0, 137.0 / 352.0), Vector2(575.0 / 1024.0, 218.0 / 352.0), Vector2(760.0 / 1024.0, 190.0 / 352.0)]
	for i in expected.size():
		check((field.tower_slots[i].position / field.size).is_equal_approx(expected[i]), "Tower slot %d is not at its marked map position" % (i + 1))
	field.free()


func _test_three_slots_start_unlocked() -> void:
	var field = DefenseFieldScript.new()
	check(field.unlocked_slot_count == 3, "A new game must start with three tower slots")
	field.free()


func _test_towers_keep_assigned_slot_positions() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.update_towers_from_parsed_list([{}, {"syllable": String.chr(0xB8E8), "word_data": {"category": "basic", "damage": 4, "is_unknown": true}}, {}, {}])
	check(not field.tower_slots[0].get_children().any(func(child): return child is WordTower), "Empty slot must stay empty")
	check(field.tower_slots[1].get_children().any(func(child): return child is WordTower), "Slot 2 tower must stay in slot 2")
	field.free()
