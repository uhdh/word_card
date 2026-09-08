extends Node

const WordTowerScript = preload("res://scripts/tower/WordTower.gd")
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")
const JamoBeltScene = preload("res://scenes/tower/JamoBelt.tscn")
const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")

var failures := 0


func _ready() -> void:
	_test_damage_uses_only_length_and_completion()
	_test_traits_preserve_damage_per_second()
	_test_category_trait_assignments()
	_test_multi_target_and_dot_traits_keep_the_damage_budget()
	_test_damage_over_time_applications_stack()
	_test_projectile_types_use_image_assets()
	_test_belt_separates_tower_tiles_and_shows_hint()
	_test_each_tower_slot_parses_only_its_tiles()
	_test_tower_hover_shows_range_and_description()
	if failures == 0:
		print("tower trait tests passed")
	get_tree().quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func make_tower(text: String, category: String, is_unknown := false):
	var field = DefenseFieldScript.new()
	var tower = WordTowerScript.new()
	tower.setup_tower(text, {"category": category, "damage": 999, "is_unknown": is_unknown}, field)
	field.free()
	return tower


func property_value(object: Object, property: StringName, fallback = null):
	if object.get_property_list().any(func(item): return item["name"] == property):
		return object.get(property)
	return fallback


func _test_damage_uses_only_length_and_completion() -> void:
	var expected_unknown = [4.0, 15.0, 28.0]
	var expected_known = [5.0, 18.75, 35.0]
	for length in range(1, 4):
		var text = "가".repeat(length)
		var unknown = make_tower(text, "basic", true)
		var known = make_tower(text, "basic", false)
		check(is_equal_approx(float(property_value(unknown, "base_damage", -1.0)), expected_unknown[length - 1]), "Unknown %d-letter damage is wrong" % length)
		check(is_equal_approx(float(property_value(known, "base_damage", -1.0)), expected_known[length - 1]), "Known %d-letter damage is wrong" % length)
		unknown.free()
		known.free()


func _test_traits_preserve_damage_per_second() -> void:
	var categories = ["basic", "weapon", "element", "magic", "summon", "defense", "heal", "skill", "nature", "buff"]
	var expected_dps := 18.75 / 0.8
	for category in categories:
		var tower = make_tower("가나", category)
		var damage := float(tower.call("damage_per_attack")) if tower.has_method("damage_per_attack") else -1.0
		check(is_equal_approx(damage / tower.attack_interval, expected_dps), "%s changes expected DPS" % category)
		tower.free()


func _test_category_trait_assignments() -> void:
	var expected = {
		"basic": "balanced", "weapon": "sniper", "element": "damage_over_time",
		"nature": "damage_over_time", "magic": "splash", "summon": "rapid",
		"buff": "rapid", "defense": "pierce", "heal": "control", "skill": "chain"
	}
	for category in expected:
		var tower = make_tower("가", category)
		check(property_value(tower, "trait_id", "") == expected[category], "%s trait assignment is wrong" % category)
		check(tower.synergy_labels.any(func(label): return str(label).begins_with("특성: ")), "%s trait must be visible in tower details" % category)
		tower.free()


func _test_multi_target_and_dot_traits_keep_the_damage_budget() -> void:
	for category in ["magic", "defense", "skill"]:
		var tower = make_tower("가나", category)
		var shares: Array = tower.call("damage_shares", 3) if tower.has_method("damage_shares") else []
		check(shares.size() == 3, "%s must hit up to three targets" % category)
		var total := 0.0
		for share in shares: total += float(share)
		check(is_equal_approx(total, 18.75), "%s must split, not multiply, its damage" % category)
		tower.free()
	var dot = make_tower("가나", "element")
	var parts: Array = dot.call("damage_over_time_parts") if dot.has_method("damage_over_time_parts") else []
	check(parts.size() == 2 and is_equal_approx(float(parts[0]) + float(parts[1]), 18.75), "Damage over time must preserve total damage")
	dot.free()


func _test_damage_over_time_applications_stack() -> void:
	var enemy = EnemyUnitScript.new()
	enemy.init_enemy("test", 100.0, 0.0, 0, "")
	enemy.apply_burn(3.0, 1.0)
	enemy.apply_burn(3.0, 1.0)
	if enemy.has_method("_tick_burn"):
		enemy._tick_burn(0.5)
	check(is_equal_approx(enemy.hp, 97.0), "Overlapping damage-over-time attacks must both deal damage")
	enemy.free()


func _test_projectile_types_use_image_assets() -> void:
	var expected = {
		"slash": "proj_slash_32px_pastel.png",
		"fire": "proj_fire_32px_pastel.png",
		"ice": "proj_ice_32px_pastel.png",
		"arrow": "proj_arrow_32px_pastel.png",
		"lightning": "proj_lightning_32px_pastel.png",
		"bullet": "proj_magic_32px_pastel.png"
	}
	for type in expected:
		var projectile = ProjectileScene.instantiate()
		add_child(projectile)
		projectile.setup(null, 1.0, type)
		check(projectile.get_node("Sprite") is Sprite2D, "%s projectile must use an image sprite" % type)
		if projectile.get_node("Sprite") is Sprite2D:
			check(projectile.get_node("Sprite").texture.resource_path.ends_with(expected[type]), "%s projectile uses the wrong image" % type)
		projectile.free()


func _test_belt_separates_tower_tiles_and_shows_hint() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F), String.chr(0x3137), String.chr(0x314F), String.chr(0x3139), String.chr(0x314F)])
	belt.render_belt()
	var trays = belt.tiles_container.get_children().filter(func(child): return child is PanelContainer)
	check(trays.size() == 5, "Four tower trays and one waiting tray must be separate")
	check(belt.hint_button.visible, "Initial hint must be available without a relic")
	belt.free()


func _test_each_tower_slot_parses_only_its_tiles() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3142), String.chr(0x315C), String.chr(0x3139), String.chr(0x315C)])
	if not property_value(belt, "slot_assignments") is Array:
		check(false, "Belt needs per-tile slot assignments")
		belt.free()
		return
	belt.slot_assignments.assign([0, 0, 1, 1])
	belt.set_unlocked_slot_count(3)
	belt.render_belt()
	var emitted = belt.parsed_slots()
	check(emitted.size() == 4, "Belt must emit four positional tower slots")
	check(emitted[0].get("syllable", "") == String.chr(0xBD80), "Slot 1 must build its own syllable")
	check(emitted[1].get("syllable", "") == String.chr(0xB8E8), "Slot 2 must build its own syllable")
	belt.add_jamo(String.chr(0x3131))
	check(belt.slot_assignments[-1] == -1, "New jamo must enter waiting")
	belt.restore_assignments([])
	check(belt.slot_assignments.all(func(slot): return slot == -1), "Old saves must migrate all jamo to waiting")
	check(not belt.move_jamo_to_slot(0, 3), "Locked tower tray must reject drops")
	belt.free()


func _test_tower_hover_shows_range_and_description() -> void:
	var field = DefenseFieldScript.new()
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower(String.chr(0xBD80), {"category": "basic", "damage": 4, "is_unknown": true, "desc": "설명 확인"}, field)
	if not property_value(tower, "is_hovered") is bool:
		check(false, "Tower needs hover range state")
	else:
		tower.btn_select.mouse_entered.emit()
		check(tower.is_hovered, "Tower hover must show its range")
		check(tower.btn_select.tooltip_text.contains(str(int(tower.attack_range))), "Tooltip must include range")
		check(tower.btn_select.tooltip_text.contains("설명 확인"), "Tooltip must include description")
		tower.btn_select.mouse_exited.emit()
		check(not tower.is_hovered, "Tower range must hide after hover")
	tower.free()
	field.free()
