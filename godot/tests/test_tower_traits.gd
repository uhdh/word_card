extends Node

const WordTowerScript = preload("res://scripts/tower/WordTower.gd")
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const TowerOrbitScript = preload("res://scripts/tower/TowerOrbit.gd")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")
const JamoBeltScene = preload("res://scenes/tower/JamoBelt.tscn")
const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const DefenseFieldScene = preload("res://scenes/tower/DefenseField.tscn")
const TowerInfoScene = preload("res://scenes/tower/TowerInfoModal.tscn")
const LexiconModalScene = preload("res://scenes/LexiconModal.tscn")
const AutoArrange = preload("res://scripts/core/AutoArrange.gd")
const Palette = preload("res://scripts/ui/Palette.gd")
const MainScript = preload("res://scripts/ui/TowerDefenseMain.gd")
const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
const TraitIconScript = preload("res://scripts/ui/TraitIcon.gd")

var failures := 0


## 볼터(발수) 검증용 최소 필드 스텁.
## DefenseField 씬 전체를 띄우지 않고도 '사거리 안의 적 목록' 만 통제하려고 쓴다.
## WordTower 는 field_ref 에서 relic_ids / has_relic / get_enemies 만 읽는다.
class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []

	func has_relic(_id: String) -> bool:
		return false

	func get_enemies() -> Array:
		return enemies


func _ready() -> void:
	_test_consonant_purchase_weights()
	_test_damage_uses_only_length_and_completion()
	_test_traits_have_distinct_combat_profiles()
	_test_category_trait_assignments()
	_test_new_attack_styles()
	_test_word_meaning_decides_attack_form()
	_test_meaning_coverage_does_not_regress()
	_test_long_words_fire_more_projectiles()
	_test_every_boss_weakness_is_reachable()
	_test_multi_target_and_dot_traits_keep_the_damage_budget()
	_test_ball_bounces_to_three_targets()
	_test_damage_over_time_applications_stack()
	_test_burn_survives_removed_source_tower()
	_test_projectile_types_use_image_assets()
	_test_belt_separates_tower_tiles_and_offers_slot_hints()
	_test_tile_purchase_buttons_request_the_right_pool()
	_test_tile_price_escalates_with_every_purchase()
	_test_tile_removal_requires_a_selection()
	_test_tile_swap_is_the_post_cap_gold_sink()
	_test_tile_click_selects_without_rebuilding_the_tree()
	_test_slot_hint_grades_like_wordle_and_locks_tiles()
	_test_slot_hint_can_be_cancelled()
	_test_slot_hint_never_spells_the_target_word()
	_test_no_word_hint_still_names_what_is_standing()
	_test_missing_jamo_ghosts_are_shuffled_into_a_bag()
	# 이 검사는 프레임을 기다린다(`await get_tree().process_frame`). `await` 없이 부르면
	# `await` 뒤의 단언들이 **`_ready` 가 끝난 뒤 임의의 시점에** 실행된다 —
	# 그때는 다른 검사가 세운 노드가 트리에 섞여 있어 결과를 믿을 수 없다.
	await _test_the_modal_layer_stays_above_everything_else()
	_test_run_ranking_orders_by_progress_then_damage()
	_test_run_ranking_keeps_only_the_best_ten()
	_test_run_ranking_reports_the_new_runs_rank()
	await _test_game_over_records_the_run_only_once()
	_test_a_defeat_says_why_it_happened()
	await _test_the_enemy_cap_becomes_visible_before_it_is_reached()
	await _test_rotatable_tiles_grade_as_rotate_not_near()
	_test_slot_hint_stays_within_the_keep_ratio()
	_test_recommendation_card_shows_the_real_tower_value()
	_test_each_trait_leaves_its_promised_shape()
	_test_projectile_hit_leaves_its_trait_shape()
	_test_any_placement_is_allowed_even_when_it_is_not_a_word()
	await _test_tray_head_stays_inside_and_keeps_the_target_next_to_the_title()
	_test_global_shop_relics_change_every_tower()
	_test_each_tower_slot_parses_only_its_tiles()
	_test_parser_prefers_registered_word_at_double_consonant_boundary()
	_test_every_registered_word_survives_its_own_jamo_column()
	_test_pig_tower_uses_three_tile_vowel()
	_test_auto_arrange_builds_highest_tier_word()
	_test_optimize_rebuilds_all_slots()
	_test_optimize_does_not_repeat_the_same_tower()
	_test_optimize_builds_multi_syllable_word_with_rotation()
	_test_recommendation_uses_only_unknown_and_waiting_tiles()
	_test_tower_hover_shows_range_and_description()
	_test_tower_info_shows_tile_recipe()
	_test_tower_info_styles_synergies()
	_test_orbit_direction_defaults_to_clockwise_and_reverses()
	_test_right_click_reverses_only_orbit_towers()
	_test_orbit_direction_is_stated_on_the_tooltip()
	_test_orbit_direction_survives_a_tower_rebuild()
	_test_targeting_modes_pick_different_enemies()
	_test_right_click_cycles_targeting_on_non_orbit_towers()
	_test_targeting_is_stated_on_the_tooltip()
	_test_targeting_survives_a_tower_rebuild()
	_test_shape_bonuses_are_small_and_always_present()
	_test_shape_bonus_matches_the_word_shape()
	_test_receiving_final_consonant_is_a_trade_off()
	_test_shape_bonus_reaches_the_real_tower()
	_test_shape_bonus_is_stated_on_the_tooltip_and_the_modal()
	_test_preview_stats_matches_the_real_tower()
	_test_hint_never_prefers_a_weaker_word()
	await _test_lexicon_shows_the_real_tower_value()
	_test_no_nodes_are_left_behind()
	if failures == 0:
		print("tower trait tests passed")
	get_tree().quit(failures)


## 검사가 끝나고 트리 밖에 떠 있는 노드가 남았는지 본다.
##
## 남긴 노드는 종료 시 `Node2D 누수` **경고**로만 나온다 — 경고는 아무도 안 읽으므로
## 조용히 쌓인다. 그래서 마지막에 **실패로** 만든다.
## 실제로 이 검사가 없을 때 이 스위트가 고아 노드 8개(= 누수 16 ObjectDB + RID 1개)를
## 남기고 있었고, 원인은 `check(make_tower(...))` 처럼 **검사식 안에서 만든 타워를
## 해제하지 않은 것**이었다. 해제할 방법이 없으니 눈에도 안 띄었다.
func _test_no_nodes_are_left_behind() -> void:
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(orphans == 0,
		"%d orphan node(s) left behind — free everything you built before the suite ends" % orphans)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_consonant_purchase_weights() -> void:
	var total := 0
	for consonant in HangulEngine.CONSONANT_POOL:
		total += HangulEngine.get_rare_draw_weight(consonant) if consonant in ["ㄱ", "ㄴ"] else 100
	check(HangulEngine.get_rare_draw_weight("ㄱ") == 48 and HangulEngine.get_rare_draw_weight("ㅡ") == 30, "Consonant weighting must not change vowel weighting")
	check(is_equal_approx(48.0 / total, 0.0603015), "ㄱ and ㄴ purchase chance must be about 6 percent each")
	# 테두리 색은 이제 등급·회전 여부와 무관하게 한 색이다. 회전 가능 표시는
	# 우하단 ↻ 배지가 담당하므로, 테두리로 또 구분하면 같은 정보가 두 번 말해진다.
	# (예전 계약은 "회전 가능한 타일끼리 같은 색" 이었다 — 그보다 강한 계약으로 바뀌었다)
	check(HangulEngine.get_rarity_border_color("ㄱ") == HangulEngine.get_rarity_border_color("ㅏ"),
		"Rotatable tiles must share one border color")
	check(HangulEngine.get_rarity_border_color("ㄷ") == HangulEngine.get_rarity_border_color("ㅏ"),
		"Non-rotatable tiles must use the same border color as rotatable ones")
	check(HangulEngine.get_rarity_border_color("ㄱ") == HangulEngine.get_rarity_border_color("ㄷ"),
		"Every tile border must be identical regardless of rarity or rotation")


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
	# 발당 피해는 '음절 수' 와 '단어 완성 여부' 만 본다.
	# 1→2→3 음절의 체감 위력은 이제 숫자가 아니라 '발수 · 간격 · 탄 크기' 가 만든다
	# (WordTower.VOLLEY_BY_LENGTH / INTERVAL_MULT_BY_LENGTH / PROJECTILE_SCALE_BY_LENGTH).
	var expected_unknown = [8.0, 9.5, 11.0]
	var expected_known = [10.0, 11.875, 13.75]
	for length in range(1, 4):
		var text = "가".repeat(length)
		var unknown = make_tower(text, "basic", true)
		var known = make_tower(text, "basic", false)
		check(is_equal_approx(float(property_value(unknown, "base_damage", -1.0)), expected_unknown[length - 1]), "Unknown %d-letter damage is wrong" % length)
		check(is_equal_approx(float(property_value(known, "base_damage", -1.0)), expected_known[length - 1]), "Known %d-letter damage is wrong" % length)
		unknown.free()
		known.free()


func _test_traits_have_distinct_combat_profiles() -> void:
	var heavy = make_tower("가나", "weapon")
	var short_strong = make_tower("가나", "defense")
	var long_weak = make_tower("가나", "heal")
	var splash = make_tower("가나", "nature")
	var rapid = make_tower("가나", "buff")
	var meteor = make_tower("가나", "magic")
	var orbit = make_tower("가나", "summon")
	var plain = make_tower("가나", "basic")
	# 저격은 여전히 '느리고 묵직' 해야 한다. 다만 음절이 길면 발사 간격이 줄어들므로
	# 절대값(1.5초) 대신 '기본 타워 대비 배수' 로 고정한다 — 그래야 밸런스 조정에 흔들리지 않는다.
	check(heavy.attack_interval > plain.attack_interval * 1.8, "Weapon must fire much slower than a plain tower")
	check(heavy.damage_per_attack() > heavy.base_damage * 2.0, "Weapon must have a slow, heavy hit")
	check(short_strong.attack_range <= 110.0 and short_strong.damage_per_attack() > short_strong.base_damage, "Defense must be short-range and strong")
	check(long_weak.attack_range >= 280.0 and long_weak.damage_per_attack() < long_weak.base_damage, "Heal must be long-range and weak")
	check(splash.trait_id == "splash", "Nature must deal splash damage")
	check(rapid.attack_interval <= 0.3 and rapid.damage_per_attack() < rapid.base_damage, "Buff must fire rapidly")
	# 새 공격 방식: 마법은 하늘에서 유성을 부르고, 소환은 주위를 맴도는 성경책을 돌린다.
	check(meteor.trait_id == "meteor", "Magic must call down meteors")
	check(orbit.trait_id == "orbit", "Summon must orbit the tower")
	check(orbit.get_node_or_null("Orbit") != null, "Orbit trait must attach an orbiting satellite node")
	check(meteor.get_node_or_null("Orbit") == null, "Meteor trait must not orbit")
	for tower in [heavy, short_strong, long_weak, splash, rapid, meteor, orbit, plain]: tower.free()


func _test_category_trait_assignments() -> void:
	var expected = {
		"basic": "balanced", "weapon": "sniper", "element": "damage_over_time",
		"nature": "splash", "magic": "meteor", "summon": "orbit",
		"buff": "rapid", "defense": "pierce", "heal": "control", "skill": "chain"
	}
	for category in expected:
		var tower = make_tower("가", category)
		check(property_value(tower, "trait_id", "") == expected[category], "%s trait assignment is wrong" % category)
		check(tower.synergy_labels.any(func(label): return str(label).begins_with("특성: ")), "%s trait must be visible in tower details" % category)
		tower.free()


func _test_new_attack_styles() -> void:
	# 공격 형태는 '음절 수' 가 아니라 '단어의 뜻' 이 정한다.
	# (예전에는 3음절이 되면 무조건 meteor/orbit 로 '승격' 시켜 단어 뜻을 통째로 지웠다)
	#
	# 주의: `check(...)` 안에서 바로 `make_tower(...)` 를 부르면 그 타워를 해제할 방법이
	# 없다. 타워는 `WordTowerScript.new()` 로 만들어져 **트리에 들어가지 않으므로**
	# (그리고 선회 타워는 `Orbit` 자식을 달고 있으므로) 그대로 두면 종료 시 고아 노드가
	# 되어 `Node2D 누수` 로 잡힌다. 실제로 이 네 줄이 5개를 남겨 8개 누수 중 절반이었다.
	# 그래서 변수로 받아 두고 아래에서 한꺼번에 해제한다.
	var magic_two = make_tower("가나", "magic")
	var magic_three = make_tower("가나다", "magic")
	var summon_three = make_tower("가나다", "summon")
	var skill_three = make_tower("가나다", "skill")
	check(property_value(magic_two, "trait_id", "") == "meteor",
		"Magic must be meteor-based at every length")
	check(property_value(magic_three, "trait_id", "") == "meteor",
		"Magic must stay meteor-based even at three syllables")
	check(property_value(summon_three, "trait_id", "") == "orbit",
		"Summon must orbit at every length")
	check(property_value(skill_three, "trait_id", "") == "chain",
		"A long word must keep its own category's attack form")

	# 선회: 음절이 길수록 오브가 많고, 궤도 반지름은 사거리를 따라간다.
	var one = make_tower("가", "summon")
	var three = make_tower("가나다", "summon")
	var one_orbit = one.get_node_or_null("Orbit")
	var three_orbit = three.get_node_or_null("Orbit")
	check(one_orbit != null and three_orbit != null, "Orbit towers must own their satellite node")
	check(one_orbit.orb_count == 1 and three_orbit.orb_count == 3,
		"Orbit count must follow word length (1 → 3)")
	check(is_equal_approx(three_orbit.orbit_radius, three.attack_range),
		"Orbit radius must follow the tower's range so range relics matter")
	check(three_orbit.orbit_radius > 0.0, "Orbit radius must be positive")
	# 궤도는 '투사체를 쏘지 않는다' — 타워가 직접 공격 루프를 돌면 안 된다.
	check(three.trait_id == "orbit" and three.damage_per_attack() < three.base_damage,
		"Orbit satellites must trade per-hit damage for continuous contact damage")

	# 유성: 광역이라 기본 사격보다 강하고, 투사체가 아니라 '낙하 연출'을 쓴다.
	var meteor = make_tower("가나", "magic")
	check(meteor.damage_per_attack() > meteor.base_damage, "Meteors must hit harder than a basic shot")
	check(meteor.get_node_or_null("Orbit") == null, "Meteor towers must not orbit")
	check(meteor.attack_range > 0.0, "Meteor tower must have a casting range")
	for t in [magic_two, magic_three, summon_three, skill_three, one, three, meteor]: t.free()


## 단어의 '뜻' → 공격의 '형태' 매핑. 이 테스트가 깨지면 의미와 특성이 다시 어긋난 것이다.
## 키워드는 2글자 이상만 쓴다 — 한 글자는 "문화"의 '화', "그물"의 '물' 처럼 엉뚱하게 걸린다.
func _test_word_meaning_decides_attack_form() -> void:
	var cases := [
		["불꽃", "element", "damage_over_time"],
		["불", "element", "damage_over_time"],
		["번개", "element", "chain"],
		["벼락", "element", "chain"],
		["얼음", "element", "control"],
		["서리", "element", "control"],
		["질풍", "element", "rapid"],
		["바위", "nature", "splash"],
		["칼날", "weapon", "sniper"],
		["함성", "skill", "chain"],
		["성경", "summon", "orbit"],
	]
	for case in cases:
		var style: Dictionary = AttackStyle.style_for(case[0], {"category": case[1]})
		check(str(style["trait"]) == case[2],
			"'%s' must attack as %s (got %s)" % [case[0], case[2], style["trait"]])
		check(str(style["label"]) != "", "'%s' must carry a visible meaning label" % case[0])

	# 뜻을 못 찾으면 예전 카테고리 규칙 그대로 — 회귀 없음.
	var fallback: Dictionary = AttackStyle.style_for("가나다", {"category": "weapon"})
	check(str(fallback["trait"]) == "sniper" and not bool(fallback["matched"]),
		"Words with no meaning keyword must fall back to the category rule")
	check(AttackStyle.proj_for_trait("chain") == "lightning", "Chain must fire lightning")
	check(AttackStyle.proj_for_trait("control") == "ice", "Control must fire ice")


## 단어 뜻 → 형태 연결의 '커버리지' 를 고정한다.
## tools/MeaningAudit.tscn 이 366단어 전체를 감사해 알려 준 수치를 여기서 최소선으로 잠근다.
## 이 테스트가 없으면 RULES 에서 키를 지워도 아무도 모른다 — 폴백은 조용히 옛 특성을 쓴다.
func _test_meaning_coverage_does_not_regress() -> void:
	var words: Array = WordDatabase.get_all_words()
	var total := 0
	var word_only := 0
	var fallback := 0
	var labeled_fallback := 0
	var bad_source := ""

	for entry in words:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = entry
		var word := str(data.get("word", ""))
		if word == "":
			continue
		total += 1
		# 이름/설명을 비운 사본으로 물어보면 '단어 자체' 만의 판정이 나온다.
		var stripped: Dictionary = AttackStyle.style_for(word, {
			"category": str(data.get("category", "")), "name": "", "desc": ""})
		var source := str(stripped.get("source", ""))
		if not (source in ["exact", "rule", "category"]) and bad_source == "":
			bad_source = "%s → '%s'" % [word, source]

		if bool(stripped.get("matched", false)):
			word_only += 1
			continue
		# 단어만으로는 못 정한다 — 실제 게임에서는 설명이 대신 정해 줄 수도 있다.
		var full: Dictionary = AttackStyle.style_for(word, data)
		if bool(full.get("matched", false)):
			continue
		fallback += 1
		if str(full.get("label", "")) != "":
			labeled_fallback += 1

	check(total > 300, "감사가 단어 DB 전체를 봐야 한다 (본 개수 %d)" % total)
	check(bad_source == "", "style_for 는 알려진 source 를 돌려줘야 한다 (문제: %s)" % bad_source)

	# 2026-09-18 측정: 단어 자체 결정 18.6%, 폴백 51.1%. 콘텐츠가 늘면 비율이
	# 내려갈 수 있으므로 여유를 두고 최소선만 잠근다.
	var word_only_ratio := float(word_only) / float(total)
	check(word_only_ratio >= 0.15,
		"단어 자체로 형태가 정해지는 비율이 너무 낮다: %.1f%% (최소 15%%)" % [100.0 * word_only_ratio])

	# 폴백으로 떨어진 단어는 '분류에서 왔다' 는 표시가 반드시 있어야 한다.
	check(fallback > 0 and labeled_fallback == fallback,
		"폴백 %d개 중 %d개만 라벨을 가졌다 — 플레이어가 형태의 출처를 알 수 없다"
			% [fallback, labeled_fallback])

	# 타워가 그 출처를 구분해 들고 있는지 (툴팁이 '뜻:' / '형태: ~ 분류' 로 갈린다).
	# make_tower 는 반환 타입이 없어 Variant 다 → `:=` 가 아니라 `=` 로 받는다.
	var from_meaning = make_tower("불꽃", "element")
	check(from_meaning.attack_style_source == "rule" and from_meaning.attack_style_label == "불꽃",
		"뜻에서 온 형태는 source=rule / label=불꽃 이어야 한다 (got %s / %s)"
			% [from_meaning.attack_style_source, from_meaning.attack_style_label])
	from_meaning.free()

	var from_category = make_tower("가나다", "weapon")
	check(from_category.attack_style_source == "category" and from_category.attack_style_label == "무기",
		"분류에서 온 형태는 source=category / label=무기 여야 한다 (got %s / %s)"
			% [from_category.attack_style_source, from_category.attack_style_label])
	from_category.free()


## 1→2→3음절이 '화면에서' 강해지는지. 숫자만 커지던 예전 동작의 회귀를 막는다.
func _test_long_words_fire_more_projectiles() -> void:
	var field := StubField.new()
	var counts := [1, 2, 3]
	for length in range(1, 4):
		var tower = WordTowerScript.new()
		tower.setup_tower("가".repeat(length), {"category": "basic", "damage": 4}, field)
		check(tower.volley_count() == counts[length - 1],
			"%d-syllable towers must fire %d projectile(s)" % [length, counts[length - 1]])
		tower.free()
	# 유성은 한 발짜리 광역 낙하, 선회는 궤도 오브가 직접 때린다 → 발수를 늘리지 않는다.
	# (위와 같은 이유로 변수로 받는다 — 검사식 안에서 만들면 해제할 수 없다.
	#  선회 타워는 `Orbit` 자식까지 있어서 고아가 2개가 된다)
	var meteor_volley = make_tower("가나다", "magic")
	var orbit_volley = make_tower("가나다", "summon")
	check(meteor_volley.volley_count() == 1, "Meteors must stay a single cast")
	check(orbit_volley.volley_count() == 1, "Orbit towers must not fire volleys")
	meteor_volley.free()
	orbit_volley.free()

	# 탄 크기도 길이를 따라가야 '여러 발 + 굵은 탄' 이 한눈에 보인다.
	var small = make_tower("가", "basic")
	var big = make_tower("가나다", "basic")
	check(big.projectile_scale() > small.projectile_scale(), "Longer words must fire fatter projectiles")
	small.free()
	big.free()

	# 실제로 여러 발이 나가는지 — 적 3마리를 세워 두고 발수만큼 겨냥하는지 본다.
	var volley_field := StubField.new()
	var three = WordTowerScript.new()
	three.setup_tower("가나다", {"category": "basic", "damage": 4}, volley_field)
	var enemies := []
	for i in range(3):
		var enemy = EnemyUnitScene.instantiate()
		enemy.init_enemy("test", 100.0, 0.0, i, "")
		enemy.global_position = three.global_position + Vector2(40.0 + float(i) * 12.0, 0.0)
		enemies.append(enemy)
	volley_field.enemies = enemies
	var shots: Array = three._volley_targets(enemies[0], three.volley_count())
	check(shots.size() == 3, "A volley must fire as many projectiles as the word has syllables")
	check(shots[0] == enemies[0], "The primary target must lead the volley")
	check(shots[1] != shots[0] and shots[2] != shots[1],
		"A volley must spread across distinct targets when enemies are available")
	# 적이 1마리뿐이면 남은 발은 그 적에게 집중된다 — 피해가 버려지면 안 된다.
	volley_field.enemies = [enemies[0]]
	var focused: Array = three._volley_targets(enemies[0], three.volley_count())
	check(focused.size() == 3 and focused.all(func(e): return e == enemies[0]),
		"A volley must focus on the only target instead of wasting shots")
	for enemy in enemies: enemy.free()
	three.free()
	volley_field.free()
	field.free()


func _test_every_boss_weakness_is_reachable() -> void:
	# 보스 약점은 '실제로 만들 수 있는 특성'이어야 한다.
	# (마법을 유성으로 바꾸면서 splash 가 고아 특성이 될 뻔했다 → 테스트로 고정)
	var reachable := {}
	for category in ["basic", "weapon", "element", "nature", "magic", "summon", "buff", "defense", "heal", "skill"]:
		for length in [1, 2, 3]:
			var tower = make_tower("가".repeat(length), category)
			reachable[property_value(tower, "trait_id", "")] = true
			tower.free()
	var field = DefenseFieldScript.new()
	var seen_boss := 0
	for act in range(1, 4):
		for wave in range(1, 21):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			for enemy in field.spawn_queue:
				if enemy.get("type", "") != "boss":
					continue
				seen_boss += 1
				check(reachable.has(enemy["weakness"]),
					"Boss weakness '%s' must be reachable by some tower" % enemy["weakness"])
	check(seen_boss > 0, "There must be boss rounds to check")
	field.free()


func _test_multi_target_and_dot_traits_keep_the_damage_budget() -> void:
	for category in ["nature", "defense", "skill"]:
		var tower = make_tower("가나", category)
		var shares: Array = tower.call("damage_shares", 3) if tower.has_method("damage_shares") else []
		check(shares.size() == 3, "%s must hit up to three targets" % category)
		var total := 0.0
		for share in shares: total += float(share)
		check(is_equal_approx(total, tower.damage_per_attack()), "%s must split, not multiply, its damage" % category)
		tower.free()
	var dot = make_tower("가나", "element")
	var parts: Array = dot.call("damage_over_time_parts") if dot.has_method("damage_over_time_parts") else []
	# 발당 피해 = 9.5 * 1.25(완성 단어) = 11.875. 총량은 그대로 보존되어야 한다.
	check(parts.size() == 2 and is_equal_approx(float(parts[0]) + float(parts[1]), 11.875), "Damage over time must preserve total damage")
	dot.free()


func _test_ball_bounces_to_three_targets() -> void:
	var field = DefenseFieldScript.new()
	var tower = WordTowerScript.new()
	tower.setup_tower("볼", {"word": "볼", "category": "weapon"}, field)
	var shares: Array = tower.damage_shares(3, 13.0)
	check(tower.trait_id == "bounce", "Ball tower must use its bounce trait")
	check(shares == [13.0, 13.0, 13.0], "Ball tower must deal damage to each of three targets")
	tower.free()
	field.free()


func _test_damage_over_time_applications_stack() -> void:
	var enemy = EnemyUnitScene.instantiate()
	enemy.init_enemy("test", 100.0, 0.0, 0, "")
	enemy.apply_burn(3.0, 1.0)
	enemy.apply_burn(3.0, 1.0)
	if enemy.has_method("_tick_burn"):
		enemy._tick_burn(0.5)
	check(is_equal_approx(enemy.hp, 97.0), "Overlapping damage-over-time attacks must both deal damage")
	enemy.free()


func _test_burn_survives_removed_source_tower() -> void:
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("test", 100.0, 0.0, 0, "")
	var projectile = ProjectileScene.instantiate()
	add_child(projectile)
	var source = WordTowerScript.new()
	projectile.setup(enemy, 4.0, "fire", "damage_over_time", source)
	source.free()
	projectile.hit_target()
	check(enemy.burn_effects.size() == 1, "Burn must apply after its source tower is removed")
	check(get_tree().get_nodes_in_group("damage_numbers").size() == 1, "Enemy hits must show a floating damage number")
	for number in get_tree().get_nodes_in_group("damage_numbers"): number.free()
	enemy.free()


func _test_projectile_types_use_image_assets() -> void:
	var expected = {
		"slash": "proj_slash_32px_pastel.png",
		"fire": "proj_fire_32px_pastel.png",
		"ice": "proj_ice_32px_pastel.png",
		"arrow": "proj_arrow_32px_pastel.png",
		"lightning": "proj_lightning_32px_pastel.png",
		"bullet": "proj_magic_32px_pastel.png",
		"dot": "proj_dot_32px_pastel.png",
		"pierce": "proj_pierce_32px_pastel.png",
		"bounce": "proj_bounce_32px_pastel.png"
	}
	# 9종 특성별 단어가 올바른 투사체를 발사하는지 검증
	var words_by_trait = [
		{"word": "가", "proj": "bullet"},
		{"word": "바람", "proj": "slash"},
		{"word": "대지", "proj": "fire"},
		{"word": "독", "proj": "dot"},
		{"word": "화살", "proj": "arrow"},
		{"word": "강타", "proj": "pierce"},
		{"word": "얼음", "proj": "ice"},
		{"word": "번개", "proj": "lightning"},
		{"word": "볼", "proj": "bounce"}
	]
	for item in words_by_trait:
		var st = AttackStyle.style_for(item.word, {})
		check(st.proj == item.proj, "Word '%s' must map to '%s' projectile but got '%s'" % [item.word, item.proj, st.proj])

	for type in expected:
		var projectile = ProjectileScene.instantiate()
		add_child(projectile)
		projectile.setup(null, 1.0, type)
		check(projectile.get_node("Sprite") is Sprite2D, "%s projectile must use an image sprite" % type)
		if projectile.get_node("Sprite") is Sprite2D:
			check(projectile.get_node("Sprite").texture.resource_path.ends_with(expected[type]), "%s projectile uses the wrong image" % type)
		projectile.free()
	var bounce = ProjectileScene.instantiate()
	add_child(bounce)
	bounce.setup(null, 1.0, "bounce", "bounce")
	check(bounce.spin_speed > 0.0, "Bounce projectile must have spin speed")
	bounce.free()


## 설명이 계약이다 — TraitStyle.DESCRIPTIONS 가 약속한 '모양' 이 실제로 나오는지 본다.
## 예전에는 11종이 전부 같은 라디얼 섬광 하나를 써서, 화면에서 '폭발' 과 '관통' 의
## 타격이 구분되지 않았다(탄 색만 달랐다).
##
## 그리고 **타격당 노드는 정확히 1개** 여야 한다. 기본 공격은 분당 100회가 넘어서
## 여기서 2개를 만들면 그대로 부하가 된다 — 모양을 늘리되 비용은 늘리지 않는다.
func _test_each_trait_leaves_its_promised_shape() -> void:
	var Juice = preload("res://scripts/ui/Juice.gd")
	var shaped := {
		"splash": 25, "control": 25,   # 닫힌 고리 = 24분할 + 닫는 점
		"pierce": 2, "sniper": 2,      # 직선
		"chain": 5, "bounce": 5,       # 꺾은선
	}
	for trait_id in shaped:
		var layer := Node2D.new()
		add_child(layer)
		Juice.trait_impact(layer, Vector2(10, 20), Color.WHITE, trait_id, 0.0)
		if layer.get_child_count() > 0:
			var fx: Node = layer.find_child("*", false, false)
			for c in layer.get_children():
				if c is Line2D:
					fx = c
					break
			check(fx is Line2D, "%s impact must be a shape, not a radial flash" % trait_id)
			if fx is Line2D:
				check(fx.points.size() == shaped[trait_id],
					"%s impact must draw its promised shape (%d points)" % [trait_id, shaped[trait_id]])
		layer.free()
	# 모양을 약속하지 않은 특성(연사·지속피해·균형)은 기존 섬광을 그대로 쓴다 —
	# 약속하지 않은 것에 모양을 지어내면 그건 설명을 넘어서는 것이다.
	for trait_id in ["rapid", "damage_over_time", "balanced"]:
		var layer := Node2D.new()
		add_child(layer)
		Juice.trait_impact(layer, Vector2.ZERO, Color.WHITE, trait_id, 0.0)
		check(layer.get_child_count() == 1, "%s must still leave one flash" % trait_id)
		if layer.get_child_count() > 0:
			check(layer.get_child(0) is Sprite2D, "%s keeps the radial flash" % trait_id)
		layer.free()


## 배선 확인 — 특성은 **투사체를 거쳐** 타격 모양까지 도달해야 한다.
## 예전에는 Projectile 이 p_trait 을 받고도 버려서, 어떤 특성이든 모양이 같았다.
## 그래서 모양 함수만 검사하면 '만들어 놨지만 아무도 안 부르는' 상태를 통과시킨다.
func _test_projectile_hit_leaves_its_trait_shape() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	var enemy = EnemyUnitScene.instantiate()
	field.add_child(enemy)
	enemy.init_enemy("test", 500.0, 0.0, 0, "")
	var layer: Node2D = field.projectiles_layer
	check(layer != null, "The field must expose a projectile layer for impacts")
	if layer == null:
		field.free()
		return
	var before := layer.get_child_count()
	var projectile = ProjectileScene.instantiate()
	layer.add_child(projectile)
	projectile.setup(enemy, 4.0, "arrow", "pierce", null)
	projectile.hit_target()
	var shape: Node = null
	for i in range(before, layer.get_child_count()):
		if layer.get_child(i) is Line2D:
			shape = layer.get_child(i)
	check(shape != null, "A pierce hit must leave a straight-line mark on the field")
	if shape != null:
		check(shape.points.size() == 2, "A pierce mark is a straight line")
	# 이 검사가 남긴 피해 숫자가 뒤 검사에 섞이지 않게 치운다.
	for number in get_tree().get_nodes_in_group("damage_numbers"):
		number.free()
	field.free()


func _test_belt_separates_tower_tiles_and_offers_slot_hints() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F), String.chr(0x3137), String.chr(0x314F), String.chr(0x3139), String.chr(0x314F)])
	belt.render_belt()
	var trays = belt.tiles_container.get_children().filter(func(child): return child is PanelContainer)
	check(trays.size() == 4, "Three tower trays and one waiting tray must be separate")
	check(belt.tiles_container is HFlowContainer, "Tile trays must wrap instead of requiring horizontal scrolling")
	# Phase 2 재설계: 벨트 높이를 300 → 210 으로 줄여 필드 가시 영역을 넓혔다.
	# (디자인 문서 01_UIUX_AUDIT_AND_PLAN.md 참조)
	check(belt.custom_minimum_size.y == 210.0, "Tile belt must reserve room by narrowing the map")
	check(belt.scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Wrapped tiles must remain visible without an inner scrollbar")
	var rotatable_tile = belt._tile_boxes(belt.tiles_container).filter(func(tile): return tile.has_node("RotationOverlay/RotateButton"))[0]
	var overlay: Control = rotatable_tile.get_node("RotationOverlay")
	var rotate_button: Button = rotatable_tile.get_node("RotationOverlay/RotateButton")
	var rotate_badge: Panel = rotatable_tile.get_node("RotationOverlay/RotateBadge")
	check(overlay.get_parent() == rotatable_tile, "Rotation icon must sit inside its tile")
	# 회전 아이콘이 안 보이던 원인은 overlay 크기가 0 이었던 것 → 전체 타일을 덮어야 한다.
	check(overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0, "Rotation overlay must cover the whole tile")
	# Phase 2 재설계: 72x72 정사각 → 64x62 로 슬림화해 정보 밀도를 높였다.
	check(rotatable_tile.custom_minimum_size == Vector2(64, 62), "Jamo tiles must keep the compact Phase 2 footprint")
	check(rotate_button.anchor_left == 1.0 and rotate_button.anchor_top == 1.0, "Rotate hit area must anchor to the tile's bottom-right")
	check(rotate_button.custom_minimum_size.x >= 24.0, "Rotate hit area must be a usable touch target")
	check(rotate_badge.get_parent() == overlay, "Visible rotate badge must live in the tile overlay")
	# 회전 버튼이 타일 가운데를 덮으면 선택이 안 된다 → 타일 면적의 1/4 이하만 차지할 것.
	var tile_area: float = rotatable_tile.custom_minimum_size.x * rotatable_tile.custom_minimum_size.y
	var rot_area: float = rotate_button.custom_minimum_size.x * rotate_button.custom_minimum_size.y
	check(rot_area <= tile_area * 0.25, "Rotate hit area must leave the tile body easily clickable")
	# 우하단 사분면 안에만 머물러야 가운데(선택 영역)를 침범하지 않는다.
	check(rotatable_tile.custom_minimum_size.x + rotate_button.offset_left > rotatable_tile.custom_minimum_size.x * 0.5
		and rotatable_tile.custom_minimum_size.y + rotate_button.offset_top > rotatable_tile.custom_minimum_size.y * 0.5,
		"Rotate hit area must stay inside the bottom-right quadrant")
	# 이중 테두리 제거: 상자(PanelContainer)는 테두리를 그리지 않고 버튼 하나만 그린다.
	check(rotatable_tile.get_theme_stylebox("panel") is StyleBoxEmpty, "Tile box must not draw a second border")
	var tile_button: Button = rotatable_tile.get_child(0)
	check(tile_button.get_theme_stylebox("normal") is StyleBoxFlat, "The tile button owns the single visible border")
	check((tile_button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_top > 0, "The single tile border must be visible")
	check(tile_button.get_theme_stylebox("focus") is StyleBoxEmpty, "A focus ring must not add a third border")
	# 반드시 PASS 여야 한다. STOP 으로 바꾸면 엔진이 드래그 소스로 이 버튼만 보고
	# 부모(JamoTileBox)의 _get_drag_data 를 부르지 않아 드래그&드롭이 죽는다.
	# (tests/test_belt_drag_drop.gd 참고 — 창을 띄워야 재현되는 회귀)
	check(tile_button.mouse_filter == Control.MOUSE_FILTER_PASS,
		"The tile button must stay PASS so the parent can be the drag source")
	# 힌트는 이제 헤더에 하나가 아니라 슬롯마다 붙는다(초성 조회 → 배치 채점).
	check(belt.find_children("HintButton", "Button", true, false).size() == 3,
		"Every unlocked slot must offer its own hint")
	check(belt.find_children("LockButton", "Button", true, false).size() == 3,
		"Every unlocked slot must offer its own lock")
	check(not belt.hint_button.visible, "The all-slot hint must stay behind the compass relic")
	rotate_button.pressed.emit()
	check(is_instance_valid(rotatable_tile) and not rotatable_tile.is_inside_tree(), "Tile rerender must detach without freeing the button that emitted the signal")
	belt.free()


func _test_tile_purchase_buttons_request_the_right_pool() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	var requests := []
	belt.tile_purchase_requested.connect(func(is_vowel): requests.append(is_vowel))
	belt.set_gold(belt.TILE_PRICE)
	belt.consonant_buy_button.pressed.emit()
	belt.vowel_buy_button.pressed.emit()
	check(requests == [false, true], "Purchase buttons must request consonant and vowel tiles")
	belt.set_gold(0)
	check(belt.consonant_buy_button.disabled and belt.vowel_buy_button.disabled, "Purchase buttons must disable without enough gold")
	belt.free()


func _test_tile_price_escalates_with_every_purchase() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	var base: int = belt.TILE_PRICE
	var step: int = belt.TILE_PRICE_STEP
	check(belt.current_tile_price() == base, "The first tile must cost the base price")

	belt.set_gold(1000)
	belt.register_tile_purchase()
	check(belt.current_tile_price() == base + step, "Each purchase must raise the price by one step")
	check(belt.consonant_buy_button.text == "자음 구매 %dG" % (base + step),
		"The consonant button must print the raised price")
	check(belt.vowel_buy_button.text == "모음 구매 %dG" % (base + step),
		"The vowel button must print the raised price")

	# 자음과 모음이 같은 시세를 공유해야 두 버튼이 서로 다른 값을 보여주지 않는다.
	for i in range(9):
		belt.register_tile_purchase()
	check(belt.current_tile_price() == base + step * 10, "The price must keep climbing with the purchase count")

	# 버튼을 눌러 요청만 하고 결제가 없으면 시세는 그대로여야 한다.
	var before: int = belt.current_tile_price()
	belt.vowel_buy_button.pressed.emit()
	belt.consonant_buy_button.pressed.emit()
	check(belt.current_tile_price() == before, "Requesting a tile must not raise the price on its own")

	# 버튼 잠금도 상승한 가격을 기준으로 판단해야 한다.
	belt.set_gold(before - 1)
	check(belt.consonant_buy_button.disabled and belt.vowel_buy_button.disabled,
		"Purchase buttons must disable when gold is below the raised price")
	belt.set_gold(before)
	check(not belt.consonant_buy_button.disabled and not belt.vowel_buy_button.disabled,
		"Purchase buttons must enable exactly at the raised price")

	# 저장-로드 복원과 새 게임 초기화 경로.
	belt.set_tile_purchase_count(4)
	check(belt.current_tile_price() == base + step * 4, "Restoring a saved purchase count must rebuild the price")
	belt.reset_tile_purchase_price()
	check(belt.current_tile_price() == base, "A new run must start from the base price")
	belt.free()


func _test_tile_click_selects_without_rebuilding_the_tree() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134)])
	belt.render_belt()
	var boxes = belt._tile_boxes(belt.tiles_container)
	check(boxes.size() == 3, "Three tiles must be laid out")
	var first = boxes[0]
	# 누르는 즉시 선택돼야 한다. 놓을 때까지 기다리면 엔진 드래그 판정(10px)에
	# 취소되어 '선택이 잘 안 되는' 증상이 났다.
	belt._on_tile_clicked(0)
	check(belt.selected_index_for_swap == 0, "Clicking a tile must select it immediately")
	# 선택만 바뀔 때는 트리를 다시 만들면 안 된다 (다시 만들면 드래그가 죽는다).
	check(is_instance_valid(first) and first.is_inside_tree(), "Selecting must not rebuild the tile tree")
	var btn: Button = first.get_child(0)
	check((btn.get_theme_stylebox("normal") as StyleBoxFlat).border_color.is_equal_approx(Palette.TX_GOLD),
		"The selected tile must show a gold border")
	# 다시 누르면 해제된다.
	belt._on_tile_clicked(0)
	check(belt.selected_index_for_swap == -1, "Clicking the selected tile again must deselect it")
	# 다른 타일을 누르면 자리가 바뀐다.
	belt._on_tile_clicked(1)
	var before = belt.jamo_list.duplicate()
	belt._on_tile_clicked(2)
	check(belt.jamo_list[1] == before[2] and belt.jamo_list[2] == before[1],
		"Selecting then clicking another tile must swap them")
	check(belt.selected_index_for_swap == -1, "A swap must clear the selection")
	belt.free()


func _test_tile_removal_requires_a_selection() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.set_gold(belt.TILE_REMOVE_PRICE)
	check(not belt.remove_tile_button.disabled, "Tile removal must be available for 10G")
	var requests := []
	belt.tile_removal_requested.connect(func(index): requests.append(index))
	belt.remove_tile_button.pressed.emit()
	belt._on_tile_clicked(0)
	check(requests == [0], "Tile removal must request the selected tile")
	belt.free()


## 활자 교체 — 실측(EconomyPlaytest)에서 벨트가 41라운드에 30장으로 포화되고
## 그 뒤로 골드 408G 가 쌓이는 게 확인됐다. 구매가 막힌 뒤에도 쓸 수 있는 출구가 필요하다.
func _test_tile_swap_is_the_post_cap_gold_sink() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134)])  # ㄱ ㅏ ㄴ
	belt.render_belt()

	# 활자 교체는 10G 고정 유지
	check(belt.current_swap_price() == 10,
		"A tile swap must cost fixed 10G")

	# 벨트가 꽉 차면 구매 버튼은 잠기지만, 교체 버튼은 살아 있어야 한다.
	belt.set_gold(1000)
	var price: int = belt.current_swap_price()
	check(not belt.swap_tile_button.disabled, "A swap must be available when gold allows it")
	check(belt.swap_tile_button.text == "활자 교체 %dG" % price,
		"The swap button must print the market price")

	# 모드는 서로 배타적이어야 한다 — 둘 다 켜지면 타일 클릭의 의미가 모호해진다.
	belt.remove_tile_button.pressed.emit()
	check(belt.removal_mode, "Pressing the remove button must enter removal mode")
	belt.swap_tile_button.pressed.emit()
	check(belt.swap_mode and not belt.removal_mode,
		"Entering swap mode must turn removal mode off")
	belt.remove_tile_button.pressed.emit()
	check(belt.removal_mode and not belt.swap_mode,
		"Entering removal mode must turn swap mode off")

	# 교체 모드에서 타일을 누르면 '교체' 요청이 가야 한다 (제거가 아니라).
	belt.swap_tile_button.pressed.emit()
	var swaps := []
	var removals := []
	belt.tile_swap_requested.connect(func(index): swaps.append(index))
	belt.tile_removal_requested.connect(func(index): removals.append(index))
	belt._on_tile_clicked(1)
	check(swaps == [1], "A tile click in swap mode must request a swap for that index")
	check(removals.is_empty(), "A tile click in swap mode must not request a removal")

	# swap_jamo 는 그 한 장만 갈아 끼우고 벨트 크기는 유지한다.
	var before_size: int = belt.jamo_list.size()
	belt.swap_jamo(1, String.chr(0x3145))  # ㅓ
	check(belt.jamo_list[1] == String.chr(0x3145), "swap_jamo must replace only the target tile")
	check(belt.jamo_list.size() == before_size, "A swap must not change the belt size")
	check(belt.jamo_list[0] == String.chr(0x3131) and belt.jamo_list[2] == String.chr(0x3134),
		"A swap must leave the other tiles alone")
	check(not belt.swap_mode, "A completed swap must leave swap mode")

	# 값이 모자라면 모드가 자동으로 꺼져야 한다 (제거 모드와 같은 규칙).
	belt.set_gold(price)
	belt.swap_tile_button.pressed.emit()
	check(belt.swap_mode, "Swap mode must be enterable at exactly the price")
	belt.set_gold(price - 1)
	check(not belt.swap_mode, "Swap mode must switch off when gold drops below the price")
	belt.set_gold(price - 1)
	check(belt.swap_tile_button.disabled, "The swap button must disable below the price")

	# 빈 벨트에서는 교체할 것이 없다.
	belt.jamo_list.clear()
	belt.set_gold(1000)
	check(belt.swap_tile_button.disabled, "A swap must be unavailable on an empty belt")
	belt.free()


func _test_slot_hint_grades_like_wordle_and_locks_tiles() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F), String.chr(0x3141)])
	belt.slot_assignments.assign([0, 0, 1, 1, 1])
	belt.render_belt()

	# 채점은 Wordle 과 같은 2단계다: 자리 맞음 → 이 단어에 쓰임 → 안 씀.
	# 목표 [가나] = ㄱ ㅏ ㄴ ㅏ, 1번 슬롯은 ㄱ ㅏ 를 들고 있다.
	var head: Dictionary = belt._grade_slot(0, "가나")
	check(head["states"] == ["pos", "pos"], "Tiles already in the right place must grade as exact")
	check(head["missing"] == ["ㄴ", "ㅏ"], "The grade must name the jamo this slot still needs")
	# 2번 슬롯은 ㄴ ㅏ ㅁ — ㄴ 은 이 단어에 있지만 자리가 다르고, ㅁ 은 안 쓴다.
	var tail: Dictionary = belt._grade_slot(1, "가나")
	check(tail["states"] == ["near", "pos", "off"],
		"A tile used elsewhere in the word must grade as near, and an unused one as off")

	# 부족한 활자는 유령 상자로 세워 둔다 — 색만으로는 몇 칸이 더 필요한지 안 보인다.
	belt.slot_grades[0] = head
	belt.slot_targets[0] = "가나"
	belt.render_belt()
	check(belt.find_children("GhostTile_*", "PanelContainer", true, false).size() == 2,
		"Missing jamo must be shown as ghost slots")
	# 트레이만 보고도 읽혀야 한다. 채점 색과 유령 상자는 '무엇을 향해 채점되는지' 를
	# 알아야 읽히는데, 목표가 벨트 헤더 한 줄에만 있으면 트레이는 해독이 안 된다.
	# 다만 그 '무엇' 은 **모양**이다 — 목표 단어를 그대로 적으면 힌트가 답이 된다.
	var target_labels: Array = belt.find_children("TargetLabel", "Label", true, false)
	check(target_labels.size() == 1 and (target_labels[0] as Label).text == "목표 2음절",
		"The tray must state the target's shape without spelling it out (got '%s')"
			% ((target_labels[0] as Label).text if target_labels.size() == 1 else "없음"))
	# [내 타일…][빠진 자모…] 를 이어 붙이면 없는 단어처럼 읽힌다. 사이를 갈라 둔다.
	var need_labels: Array = belt.find_children("NeedLabel", "Label", true, false)
	check(need_labels.size() == 1, "A divider must separate the tiles from the missing jamo")
	# 채점 한 줄은 '다음에 할 일' 까지 말해야 한다. 색의 뜻은 머릿속에 없다.
	# 목표 단어는 여기에도 쓰지 않는다 — 어떤 활자가 몇 개 빠졌는지만 말한다.
	var hint_line: String = belt._slot_hint_text(0)
	check(not hint_line.contains("가나"),
		"The hint line must not spell the target word out (got %s)" % hint_line)
	check(hint_line.contains("2음절") and hint_line.contains("빠진 활자 2개"),
		"The hint line must state the shape and how many jamo are still missing (got %s)" % hint_line)
	check(not hint_line.contains("이동"),
		"A slot whose tiles are all in place must not be told to move anything (got %s)" % hint_line)
	belt.slot_grades[1] = tail
	belt.slot_targets[1] = "가나"
	check(belt._slot_hint_text(1).contains("이동"),
		"A slot with a misplaced tile must say the gold tile has to move (got %s)" % belt._slot_hint_text(1))
	# 회색 타일은 '옮기면 되는' 것이 아니라 **빼야** 하는 것이다. 이 줄이 없으면
	# 화면은 [ㄱ][ㅣ][필요][ㅇ][ㅂ] 로 보이고, 플레이어는 ㄱ 을 맨 앞에 둔 채
	# ㅇ ㅂ 을 뒤에 붙여 없는 단어를 상상한다.
	check(belt._slot_hint_text(1).contains("회색 1개"),
		"A tile the word does not use must be reported as unused, not left unexplained (got %s)"
			% belt._slot_hint_text(1))

	# 훈민정음의 나침반: 슬롯을 하나씩 누르는 대신 세 슬롯을 한 번에 채점한다.
	# (예전에는 '완성 단어를 알려 주는' 유물이었지만, 이제 힌트 자체가 단어를 준다)
	belt.set_relics(["relic_initial_compass"])
	check(belt.hint_button.visible, "The compass relic must reveal the all-slot hint button")
	belt.hint_button.pressed.emit()
	check(belt.parsed_preview_label.text.begins_with("최적 조합:"),
		"The all-slot hint must report the whole combination in the preview line")
	# 이 줄이 말해야 하는 것은 **나침반만 아는 것** 이다 — 지금보다 센가, 얼마나 센가.
	# 모양(음절 수)은 트레이 머리가 슬롯마다 '목표 N음절' 로 이미 말하고 있어 중복이었다.
	check(belt.parsed_preview_label.text.contains("DPS"),
		"The all-slot hint must state how strong the best combination is (got '%s')"
			% belt.parsed_preview_label.text)
	# 세 슬롯을 한 번에 보는 화면이라 새는 통로가 가장 넓다. **목표 단어는 어디에도
	# 쓰지 않는다.** 형식이 아니라 계약을 직접 잠근다 — 고정 낱말을 걷어낸 나머지에
	# 목표가 남아 있으면 힌트가 답을 적은 것이다.
	# (걷어내지 않으면 1음절 목표 '조' 가 '조합' 안에서 걸려 거짓 양성이 난다)
	var residue: String = belt.parsed_preview_label.text
	for token in ["최적 조합", "지금", "배치", "그대로", "완성", "최고", "회전", "이동", "제외"]:
		residue = residue.replace(token, "")
	for slot_index in belt._open_slots():
		var target: String = belt.slot_targets[slot_index]
		check(target == "" or not residue.contains(target),
			"The all-slot hint must never spell a target word out (residue '%s', target '%s')"
				% [residue, target])

	# 이 줄의 존재 이유는 **비교** 다. '지금 배치가 곧 최적' 과 '더 센 조합이 있다' 를
	# 구분하지 못하면, 이미 1음절 단어를 세워 둔 플레이어는 '목표 1음절' 을 보고
	# "바뀌는 게 없다" 고 읽는다. 실측: 감·날·굴(41.0 DPS)을 세워 둔 벨트에서 나침반은
	# 문·골·날(54.3 DPS)을 찾아냈는데 — **32% 더 센 조합** — 옛 줄은 그 사실을 말하지
	# 못했다. 35G 를 주고 산 힌트의 결론이 화면에서 사라진 것이다.
	belt.jamo_list.assign([
		String.chr(0x3131), String.chr(0x314F), String.chr(0x3141),
		String.chr(0x3134), String.chr(0x314F), String.chr(0x3139),
		String.chr(0x3131), String.chr(0x315C), String.chr(0x3139),
	])
	belt.slot_assignments.assign([0, 0, 0, 1, 1, 1, 2, 2, 2])
	belt.clear_slot_locks()
	belt.render_belt()
	var open_slots: Array = belt._open_slots()
	# 지금 서 있는 단어를 그대로 목표로 세우면 '그대로 완성' 이어야 한다.
	var standing: Array = belt.parsed_slots()
	for k in open_slots:
		var item: Dictionary = standing[k] if k < standing.size() else {}
		var word := str(item.get("syllable", ""))
		belt.slot_targets[k] = word
		belt.slot_grades[k] = belt._grade_slot(k, word)
	var done_line: String = belt._all_hint_text(open_slots)
	check(done_line.contains("그대로 완성"),
		"A belt that already stands as the best set must be told so (got '%s')" % done_line)
	# 목표를 하나만 바꿔도 '더 세다' 는 비교가 나와야 한다.
	belt.slot_targets[open_slots[0]] = "문"
	belt.slot_grades[open_slots[0]] = belt._grade_slot(open_slots[0], "문")
	var upgrade_line: String = belt._all_hint_text(open_slots)
	check(upgrade_line.contains("▸") and upgrade_line != done_line,
		"A stronger combination must be reported as a comparison (got '%s', done '%s')"
			% [upgrade_line, done_line])
	check(not upgrade_line.contains("문"),
		"The comparison must not name the target word it found (got '%s')" % upgrade_line)
	# '해야 할 일' 의 규모도 함께 말한다 — 색만으로는 '한 장 밀기' 와 '여섯 장 부수기' 가
	# 똑같이 파란 타일 몇 개로 보인다.
	check(upgrade_line.contains("회전") or upgrade_line.contains("이동") or upgrade_line.contains("제외"),
		"The comparison must fold the tile colours into the size of the job (got '%s')" % upgrade_line)

	# 고정: 한 슬롯의 단어를 잠그면 그 타일은 옆 슬롯의 힌트 조합에서 빠진다.
	# 1번 슬롯 = ㄱ ㅏ ㅁ ([감]), 대기 = ㄴ ㅏ ㄹ ([날]).
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3141), String.chr(0x3134), String.chr(0x314F), String.chr(0x3139)])
	belt.slot_assignments.assign([0, 0, 0, -1, -1, -1])
	belt.clear_slot_locks()
	belt.render_belt()
	belt._toggle_slot_lock(0)
	check(belt.slot_locked[0], "Locking must stick")
	check(belt.slot_targets[0] == "감", "Locking without a hint must lock the word already in the slot")
	check(belt.slot_reserved[0] == [0, 1, 2], "The locked word's tiles must be reserved")
	belt._show_slot_hint(1)
	# 요점은 '무엇을 골랐는가' 가 아니라 **1번 슬롯이 고정한 타일을 나눠 쓰지 않는다**는
	# 것이다. 예전에는 특정 단어([굴])를 못 박아 뒀는데, 힌트의 순위 기준이 'DB 의
	# damage 필드' 에서 '실제 타워의 초당 피해' 로 바뀌면서 뽑히는 단어가 달라졌다.
	# 단어 이름을 잠그면 기준이 바뀔 때마다 무관한 실패가 나므로, 계약을 직접 잠근다:
	# 남은 타일로 만들 수 있어야 하고, 고정된 단어와 같으면 안 된다.
	var neighbour: String = belt.slot_targets[1]
	var left_over: Array[String] = []
	for i in belt._slot_available_indices(1): left_over.append(belt.jamo_list[i])
	check(neighbour != "" and not AutoArrange.tile_indices_for(neighbour, left_over, []).is_empty(),
		"A neighbour hint must be buildable from the tiles the locked slot left (got '%s' from %s)"
			% [neighbour, str(left_over)])
	check(neighbour != belt.slot_targets[0],
		"A neighbour hint must not repeat the locked word (got '%s')" % neighbour)
	belt._toggle_slot_lock(0)
	check(not belt.slot_locked[0] and belt._slot_available_indices(1).size() == 6,
		"Unlocking must return the tiles to the other slots")

	# 목표는 플레이어의 계획이라 고정되지만, 채점은 벨트를 따라와야 한다.
	# 안 그러면 타일을 옮겨도 '부족한 활자' 에 그 타일이 남아 화면이 거짓말을 한다.
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F)])
	belt.slot_assignments.assign([0, 0, 0, 0])
	belt.clear_slot_locks()
	belt.slot_targets[0] = "가나"
	belt.render_belt()
	check(belt.find_children("GhostTile_*", "PanelContainer", true, false).is_empty(),
		"Ghost slots must disappear once every jamo of the target sits in the slot")
	# 다 맞았으면 '완성' 이라고 말해 준다. 할 일이 없다는 것도 정보다.
	check(belt._slot_hint_text(0).contains("완성"),
		"A slot that is already correct must say so instead of listing nothing (got %s)"
			% belt._slot_hint_text(0))
	# 타일을 팔아 목표를 만들 수 없게 되면 채점을 지운다 — 전부 회색인 화면만 남는다.
	belt.remove_jamo(0)
	check(belt.slot_targets[0] == "" and belt.slot_grades[0].is_empty(),
		"An unreachable target must be dropped instead of grading everything as unused")
	belt.free()


## 힌트는 토글이다 — 한 번 누른 힌트를 되돌릴 수 있어야 한다.
##
## 취소 수단이 없으면 목표와 채점 색이 영원히 남아, 화면이 계속 '이 단어를 만들어라'
## 라고 말한다. 고정을 풀어도 마찬가지다. 플레이어가 마음을 바꾸는 일은 정상이다.
func _test_slot_hint_can_be_cancelled() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F)])
	belt.slot_assignments.assign([0, 0, 1, 1])
	belt.render_belt()

	check(not belt._slot_has_hint(0), "A fresh slot must not claim to have a hint")
	belt._show_slot_hint(0)
	check(belt._slot_has_hint(0), "Pressing hint must produce a target")
	check(belt.slot_targets[0] != "", "The hint must name a word")

	# 취소: 목표와 채점이 사라진다. 버튼도 다시 '힌트' 로 돌아가야 한다.
	belt._show_slot_hint(0)
	check(not belt._slot_has_hint(0),
		"Pressing hint again must cancel it (target='%s')" % belt.slot_targets[0])
	check(belt.slot_grades[0].is_empty(), "Cancelling must also drop the grading")
	check(belt.find_children("TargetLabel", "Label", true, false).is_empty(),
		"The target label must disappear from the tray")
	# 취소는 '계획' 을 지우는 일이지 배치를 되돌리는 일이 아니다.
	check(belt._slot_chars(0) == [String.chr(0x3131), String.chr(0x314F)],
		"Cancelling a hint must leave the tiles where they are (got %s)" % str(belt._slot_chars(0)))
	# 다시 누르면 새로 채점한다(취소가 힌트 기능을 죽이지 않는다).
	belt._show_slot_hint(0)
	check(belt._slot_has_hint(0), "A cancelled hint must be re-computable")

	# 고정된 슬롯은 힌트를 못 지운다 — 고정이 잡아 둔 계획이 먼저다.
	belt._toggle_slot_lock(0)
	belt._show_slot_hint(0)
	check(belt.slot_targets[0] != "", "A locked slot must keep its hint")
	belt.free()


## 힌트가 실제로 '말하는' 글자들만 모은다 — 트레이 머리의 목표 라벨, 상태 줄,
## 유령 상자의 활자와 툴팁. 목표 단어가 새어 나갈 수 있는 통로가 정확히 이 넷이다.
##
## 벨트 전체를 훑지 않는 이유: 화면에는 '조합 추천' 버튼처럼 게임이 이미 쓰는 낱말이
## 널려 있다. 그것까지 검사하면 목표가 하필 그 낱말일 때 테스트가 거짓으로 실패한다.
func _hint_texts(belt: Node) -> Array:
	var out: Array = []
	for label in belt.find_children("TargetLabel", "Label", true, false):
		out.append((label as Label).text)
	out.append(belt.parsed_preview_label.text)
	for ghost in belt.find_children("GhostTile_*", "PanelContainer", true, false):
		out.append((ghost.get_child(0) as Label).text)
		out.append((ghost as Control).tooltip_text)
	return out


## 힌트는 답을 적어 주지 않는다.
##
## 힌트가 목표 단어를 그대로 보여 주면 플레이어가 할 일이 '단어를 찾기' 에서
## '받아쓰기' 로 바뀐다. 자모를 모아 단어를 만드는 것이 이 게임의 핵심 고리인데,
## 힌트가 그 고리를 대신 풀어 버리면 힌트가 아니라 건너뛰기가 된다.
## 실제로 트레이 머리에 "목표 수정구" 라고 적혀 있었다.
##
## 이 테스트가 잠그는 것은 '무엇을 보여 주는가' 가 아니라 **무엇을 보여 주지 않는가** 다.
## 라벨 하나만 보면 유령 상자 툴팁이나 상태 줄로 새는 것을 못 잡는다 — 통로가 넷이다.
func _test_slot_hint_never_spells_the_target_word() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	# 수정구의 자모를 전부 들고 있되 아무 데도 놓지 않는다. 슬롯이 비면 채점이
	# '전부 빠짐' 이 되어 유령 상자가 목표의 자모를 전부 나열한다 — 새는 통로가
	# 가장 넓게 열리는 상태다.
	belt.jamo_list.assign([
		String.chr(0x3145), String.chr(0x315C), String.chr(0x3148), String.chr(0x3153),
		String.chr(0x3147), String.chr(0x3131), String.chr(0x315C)])
	belt.slot_assignments.assign([-1, -1, -1, -1, -1, -1, -1])
	belt.render_belt()
	belt._show_slot_hint(0)
	var target: String = belt.slot_targets[0]
	check(target != "", "The hint must still pick a word to grade against")
	if target == "":
		belt.free()
		return
	for text in _hint_texts(belt):
		check(not str(text).contains(target),
			"The hint must never spell the target word out (found '%s' for target '%s')"
				% [str(text), target])
	# 답을 감추는 것과 돕지 않는 것은 다르다. 모양과 자리 채점은 남아야 한다.
	check(belt.parsed_preview_label.text.contains("음절"),
		"The hint line must still state the shape of the target (got %s)"
			% belt.parsed_preview_label.text)
	var target_labels: Array = belt.find_children("TargetLabel", "Label", true, false)
	check(target_labels.size() == 1 and (target_labels[0] as Label).text.contains("음절"),
		"The tray must still say what shape it is grading against")
	check(not belt.find_children("GhostTile_*", "PanelContainer", true, false).is_empty(),
		"Hiding the word must not remove the placement help — the ghost boxes must stay")
	belt.free()


## 사전 단어를 하나도 못 세울 때, 헤더가 **슬롯이 서 있는 것**을 말하는가.
##
## 예전에는 두 상태를 같은 문장으로 뭉갰다 — 슬롯이 비어 있는 경우와, 슬롯이
## '미지의 활자'(사전에 없는 음절)를 세우고 있는 경우다. 후자는 **일하고 있는 타워**다:
## 기본 탄환을 쏘고 있고 화면에도 서 있다. 그런데 줄은 "만들 수 있는 단어가 없어요"
## 라고만 말해 '이 슬롯은 아무것도 아니다' 로 읽혔다 — 지워야 하는지 남겨야 하는지
## 판단할 근거가 화면에 없다.
##
## 실측(봉지 15종 = `HangulEngine.ALL_DRAW_POOL`, 1~5장 전수 15503개):
## 이 줄이 뜨는 경우 3924건(25.3%). 그중 2462건은 슬롯이 비어 있었고,
## **1462건(37%)은 미지의 활자를 세우고 있었다.** 등록어를 세우고 있는데 이 줄이 뜨는
## 경우는 0건이다 — 그런 모순은 도달하지 않는다.
##
## 서 있는 음절을 적는 것은 답을 흘리는 게 아니다(화면에 이미 있는 글자다).
## '미지의 활자' 도 이 게임이 이미 쓰는 말이다 — `HangulStreamParser.make_unknown_word_data`,
## `LexiconModal`. 벨트 헤더만 그 말을 안 쓰고 있었다.
func _test_no_word_hint_still_names_what_is_standing() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)

	# (1) 슬롯이 미지의 활자 [가] 를 세우고 있다. ㄱ + ㅏ = 가 — 1음절 등록어 47개에 없다.
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F)])
	belt.slot_assignments.assign([0, 0])
	belt.clear_slot_locks()
	belt.render_belt()

	# 이 벨트가 정말 '단어 없음' 인지 먼저 못 박는다 — 아니면 이 테스트는 헛돈다.
	var available: Array[String] = [belt.jamo_list[0], belt.jamo_list[1]]
	check(AutoArrange.buildable_words_for(available, WordDatabase.get_all_words(), 1).is_empty(),
		"This belt must genuinely have no buildable dictionary word")
	check(str(belt.parsed_slots()[0].get("syllable", "")) == "가",
		"The slot must be standing on 가 for this test to mean anything")

	belt._show_slot_hint(0)
	var standing_line: String = belt.parsed_preview_label.text
	check(standing_line.contains("가"),
		"The line must name the syllable the slot is standing on (got '%s')" % standing_line)
	check(standing_line.contains("미지의 활자"),
		"The line must use the game's own word for an unregistered syllable (got '%s')" % standing_line)
	check(not standing_line.contains("만들 수 있는 단어가 없어요"),
		"A slot standing on a working tower must not be told 'no word can be made' (got '%s')"
			% standing_line)

	# (2) 슬롯이 비어 있으면 그때는 '없어요' 가 정직한 말이다.
	# 같은 자모를 들고 있되 아무 데도 놓지 않는다 — 판정은 벨트 전체로 하므로
	# '만들 수 있는 단어가 없다' 는 사실은 그대로다.
	belt.slot_assignments.assign([-1, -1])
	belt.clear_slot_locks()
	belt.render_belt()
	belt._show_slot_hint(0)
	var empty_line: String = belt.parsed_preview_label.text
	check(empty_line != standing_line,
		"An empty slot and a slot standing on 미지의 활자 must not read the same (both '%s')"
			% empty_line)
	check(empty_line.contains("만들 수 있는 단어가 없어요"),
		"An empty slot with no buildable word must keep the honest dead-end line (got '%s')"
			% empty_line)
	check(not empty_line.contains("미지의 활자"),
		"An empty slot must not be described as holding 미지의 활자 (got '%s')" % empty_line)

	# (3) 두 줄 다 헤더를 넘지 않아야 한다 — 이 라벨은 clip_text = true 라
	# 넘치면 조용히 잘린다. 실측(유물 보유 = 가장 좁은 479 px): 둘 다 312 px.
	var font: Font = belt.parsed_preview_label.get_theme_font("font")
	var font_size: int = belt.parsed_preview_label.get_theme_font_size("font_size")
	for line in [standing_line, empty_line]:
		var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		check(width <= 479.0,
			"The line must fit the narrowest header (479 px with relics), got %.1f px for '%s'"
				% [width, line])
	belt.free()


## 빠진 자모는 '단어의 나머지' 가 아니라 '아직 필요한 활자 더미' 로 보여 준다.
##
## 목표 순서대로 유령 상자를 세우면 [내 타일…][빠진 자모…] 가 그대로 이어져 화면에
## 목표 단어가 적힌다. 목표 [수정구] 에 ㅅ ㅜ 를 놓은 상태가 정확히 그 경우다 —
## 유령이 ㅈ ㅓ ㅇ ㄱ ㅜ 순서로 서면 ㅅㅜ 뒤에 그대로 붙어 수정구로 읽힌다.
##
## 가나다순으로 흩으면 플레이어는 '무엇이 더 필요한지' 는 알지만 '어디에 놓을지' 는
## 스스로 찾아야 한다. 힌트가 도와야 하는 지점이 정확히 그 '배치' 다.
func _test_missing_jamo_ghosts_are_shuffled_into_a_bag() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([
		String.chr(0x3145), String.chr(0x315C), String.chr(0x3148), String.chr(0x3153),
		String.chr(0x3147), String.chr(0x3131), String.chr(0x315C)])
	# 1번 슬롯에 ㅅ ㅜ = 목표 [수정구] 의 앞 두 자리. 나머지 다섯이 유령으로 선다.
	belt.slot_assignments.assign([0, 0, -1, -1, -1, -1, -1])
	belt.slot_targets[0] = "수정구"
	belt.render_belt()

	var ghosts: Array = belt.find_children("GhostTile_0_*", "PanelContainer", true, false)
	check(ghosts.size() == 5,
		"The five jamo missing from the slot must get ghost boxes (got %d)" % ghosts.size())
	var shown: Array = []
	for ghost in ghosts:
		shown.append((ghost.get_child(0) as Label).text)
	# 목표 순서는 ㅈ ㅓ ㅇ ㄱ ㅜ 다. 가나다순은 ㄱ ㅇ ㅈ ㅓ ㅜ — 둘은 다르다.
	check(shown == ["ㄱ", "ㅇ", "ㅈ", "ㅓ", "ㅜ"],
		"Ghost jamo must be shown in 가나다순, not in target order (got %s)" % str(shown))
	belt.free()


## 힌트의 네 번째 색: '돌려야 그 자모가 되는 타일'.
##
## 금색은 '자리만 다름'(끌어다 놓으면 됨)이고 파랑은 '돌려야 함'(↻ 를 눌러야 함)이다.
## 플레이어가 할 일이 다르므로 색도 달라야 한다 — 한 색으로 묶여 있으면 ㅏ 를 ㅗ 자리에
## 끌어다 놓고 "왜 안 되지" 를 반복한다.
##
## 합자(ㄲ)는 회전 대상이 아니다(ROTATABLE_TILES 에 없다). 조각 ㄱ 이 회전 가능하다는
## 이유로 합자 타일에 파랑을 칠하면, 화면에 ↻ 배지조차 없는 타일을 돌리라고 시키는 셈이다.
func _test_rotatable_tiles_grade_as_rotate_not_near() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)

	# 목표 [고] = ㄱ ㅗ. 타일은 ㅏ ㄱ.
	# ㅏ 는 ㅏ→ㅜ→ㅓ→ㅗ 로 돌아 ㅗ 가 되므로 '돌려야' 파랑, ㄱ 은 이미 그 자모라 '옮겨야' 금색.
	belt.jamo_list.assign([String.chr(0x314F), String.chr(0x3131)])
	belt.slot_assignments.assign([0, 0])
	belt.render_belt()
	var grade: Dictionary = belt._grade_slot(0, "고")
	check(grade["states"] == ["rotate", "near"],
		"A tile that becomes the jamo only after rotating must not grade like one that just moves (got %s)"
			% str(grade["states"]))
	check(grade["missing"].is_empty(),
		"Rotating a tile into the needed jamo must not leave that jamo missing (got %s)"
			% str(grade["missing"]))

	# 색의 뜻은 문장으로도 말해야 한다 — 색만으로는 무엇을 하라는지 알 수 없다.
	check(belt._grade_label("rotate").contains("돌"),
		"The rotate grade must say the tile has to be turned (got '%s')" % belt._grade_label("rotate"))
	belt.slot_grades[0] = grade
	belt.slot_targets[0] = "고"
	var line: String = belt._slot_hint_text(0)
	check(line.contains("파랑") and line.contains("회전"),
		"The hint line must explain the blue tile in words (got %s)" % line)
	check(not line.contains("완성"),
		"A slot that still needs a rotation must not be called finished (got %s)" % line)

	# 자리만 바꾸면 되는 경우는 파랑이 아니다. [가] = ㄱ ㅏ 를 ㅏ ㄱ 으로 들고 있다.
	belt.jamo_list.assign([String.chr(0x314F), String.chr(0x3131)])
	belt.render_belt()
	var swapped: Dictionary = belt._grade_slot(0, "가")
	check(swapped["states"] == ["near", "near"],
		"A pure swap must stay gold — nothing here has to be rotated (got %s)" % str(swapped["states"]))

	# 합자는 회전할 수 없다. ㄲ 한 장으로 ㄴ 을 채우라고 시키면 안 된다.
	belt.jamo_list.assign([String.chr(0x3132), String.chr(0x314F)])  # ㄲ ㅏ
	belt.render_belt()
	var compound: Dictionary = belt._grade_slot(0, "나")
	check(not compound["states"].has("rotate"),
		"A compound tile has no rotate badge, so it must never grade as rotate (got %s)"
			% str(compound["states"]))
	check(compound["states"] == ["off", "near"],
		"A compound tile that cannot become the needed jamo must not be called usable (got %s)"
			% str(compound["states"]))

	# 네 색이 한 슬롯에 다 나오는 배치 — 힌트 한 줄이 가장 길어지는 경우다.
	# 목표 [고기] = ㄱ ㅗ ㄱ ㅣ, 타일은 ㄱ ㅏ ㅁ ㅡ ㄱ.
	# ㄱ 은 제자리(초록), ㅏ 는 돌려야 ㅗ(파랑), ㅁ 은 안 씀(회색), 끝의 ㄱ 은 자리만 다름(금색).
	belt.jamo_list.assign([
		String.chr(0x3131), String.chr(0x314F), String.chr(0x3141),
		String.chr(0x3161), String.chr(0x3131)])
	belt.slot_assignments.assign([0, 0, 0, 0, 0])
	belt.render_belt()
	var all_four: Dictionary = belt._grade_slot(0, "고기")
	check(all_four["states"] == ["pos", "rotate", "off", "rotate", "near"],
		"All four grades must be reachable in one slot (got %s)" % str(all_four["states"]))
	check(all_four["missing"].is_empty(),
		"A slot whose jamo are all present must not report anything missing (got %s)"
			% str(all_four["missing"]))
	belt.slot_grades[0] = all_four
	belt.slot_targets[0] = "고기"
	belt.render_belt()
	# 힌트 한 줄은 벨트 헤더에서 구매 버튼과 폭을 나눠 쓴다. clip_text 라 넘치면 **조용히
	# 잘리고**, 잘리는 쪽은 늘 마지막 절('회색 N개 제외')이었다 — 실제로 그렇게 잘려서
	# '빼야 한다' 는 안내가 화면에서 사라졌다. 절이 넷 다 나오는 이 배치가 가장 긴 줄이다.
	# 컨테이너 배치는 프레임을 넘겨야 확정되므로 최소 크기가 아니라 실제 폭으로 잰다.
	# 실측: 옛 문구 746px 대 라벨 592px(154px 초과 = 잘림), 지금 문구 428px.
	await get_tree().process_frame
	await get_tree().process_frame
	var full_line: String = belt._slot_hint_text(0)
	var font: Font = belt.parsed_preview_label.get_theme_font("font")
	var font_size: int = belt.parsed_preview_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(full_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	check(text_width <= belt.parsed_preview_label.size.x,
		"The hint line must fit in the belt header — it is clipped, not wrapped (%.0fpx of text, %.0fpx of label: %s)"
			% [text_width, belt.parsed_preview_label.size.x, full_line])
	check(full_line.contains("회색 1개"),
		"The last clause must survive to the screen, not get pushed out by the blue one (got %s)"
			% full_line)
	belt.free()


## 슬롯 힌트는 **그 슬롯이 쓸 수 있는 타일 중 DPS 1위 *근처*** 를 목표로 삼아야 한다.
##
## 감독 결정(2026-10-02): 늘 1위 하나만 가리키면 "하던 것" 만 하게 된다 → **DPS 1위의
## `AutoArrange.HINT_KEEP_RATIO`(0.8) 이상인 후보 중에서 봉지 시드로 하나**를 고른다.
## 그래서 이 테스트가 잠그는 것은 **바닥**이다 — 목표는 1위와 같지 않아도 되지만
## **1위의 80% 아래로는 내려가지 않는다.**
##
## 예전에는 벨트 전체를 세 슬롯에 재분배하는 조합(`_best_set_for`)의 같은 순번을 목표로
## 썼다. 조합은 **총합**을 키우는 계산이라 한 슬롯에 1음절 잔여를 떼어 주는 것이 정상
## 동작이었고, 그래서 디렉터 화면에서 타일 7장을 들고 있는 3번 슬롯이 '목표 1음절' 을
## 받았다 — 같은 벨트로 2음절 53.1 DPS(구름·마루)를 세울 수 있는데도.
##
## ⚠️ 같은 계약이 이미 한 번 보고돼 테스트로 잠겨 있다(가루 vs 바늘,
## `_test_hint_never_prefers_a_weaker_word`). 힌트가 약한 쪽을 가리키면 플레이어는 그
## 약한 쪽을 세운다 — 힌트의 존재 이유가 뒤집힌다. **그래서 바닥이 있다.**
##
## ⚠️ 순위 함수도 패널과 같아야 한다. 두 화면이 같은 질문("무엇을 노릴까")에 다른 답을 하면
## 플레이어는 어느 쪽도 믿지 못한다.
##
## ⚠️ 아래 첫 단언은 **자기 참조**다 — `belt.slot_targets[2]` 를 **같은 함수**의 출력과
## 비교하므로 그 함수가 무엇을 고르든 초록이다. 그래서 **바닥 단언이 따로 필요하다.**
func _test_slot_hint_stays_within_the_keep_ratio() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	# 디렉터 화면 그대로: 1번 비어 있음 · 2번 ㄱ ㅡ · 3번 ㄴ ㅜ ㄹ ㄱ ㅜ ㄴ ㅡ · 대기 ㅁ.
	belt.jamo_list.assign([
		String.chr(0x3131), String.chr(0x3161),
		String.chr(0x3134), String.chr(0x315C), String.chr(0x3139),
		String.chr(0x3131), String.chr(0x315C), String.chr(0x3134),
		String.chr(0x3161), String.chr(0x3141)])
	belt.slot_assignments.assign([1, 1, 2, 2, 2, 2, 2, 2, 2, -1])
	belt.render_belt()

	# 이 벨트의 조합은 3번 슬롯에 1음절 잔여를 떼어 준다(구름 · 곡 · 기). 그 몫을 목표로
	# 쓰면 아래 검사가 깨진다 — 그것이 보고된 증상이다.
	var available: Array[String] = []
	for i in belt._slot_available_indices(2): available.append(belt.jamo_list[i])
	check(available.size() == 10, "The reported belt must offer every tile to the third slot")
	var top: Array = AutoArrange.buildable_words_for(available, WordDatabase.get_all_words(), 1)
	check(not top.is_empty(), "The reported belt must have at least one buildable word")

	belt._show_slot_hint(2)
	var target: String = belt.slot_targets[2]
	check(target == str(top[0].get("word", "")),
		"A slot hint must aim at what the shared ranking function recommends (got '%s', picked '%s')"
			% [target, str(top[0].get("word", ""))])
	# 그리고 그 목표는 실제로 이 슬롯이 쓸 수 있는 타일로 만들 수 있어야 한다.
	check(not AutoArrange.tile_indices_for(target, available, []).is_empty(),
		"The target '%s' must be buildable from the tiles this slot may use" % target)
	# ⭐ 이 테스트가 실제로 잠그는 것 — **바닥**.
	# 봉지 전체에서 만들 수 있는 '가장 센 단어' 를 따로 구해, 목표가 그 80% 위인지 본다.
	# (위의 첫 단언은 자기 참조라 이 바닥이 없으면 무엇도 안 잠근다)
	var best_word := ""
	var best_value := 0
	for data in WordDatabase.get_all_words():
		var w := str(data.get("word", ""))
		if AutoArrange.tile_indices_for(w, available, []).is_empty():
			continue
		var v := AutoArrange.word_value(w, data)
		if v > best_value:
			best_value = v
			best_word = w
	check(best_value > 0, "The reported belt must be able to build something")
	var target_value := AutoArrange.word_value(target, WordDatabase.get_word_data(target))
	var floor_value := int(round(float(best_value) * AutoArrange.HINT_KEEP_RATIO))
	check(target_value >= floor_value,
		"The hint must stay within the keep ratio of the best (target %s = %d, floor = %d, best %s = %d)"
			% [target, target_value, floor_value, best_word, best_value])
	belt.free()


## 조합 추천 카드의 숫자와 특성 이름은 **실제 타워 값**이어야 한다.
##
## `_recommendation_line` 은 category 로 trait 을 **추측**하고 자체 base 표
## (`[5.0, 18.75, 35.0]`)를 쓰는 세 번째 공식이었다. 실측(2음절): 입구 35.6 vs 실제 53.1,
## 바늘 30.5 vs 45.4, 안개 23.4 vs 34.9. **기운은 특성 이름까지 틀렸다** — 카드는 '연쇄',
## 실제 trait 은 관통(53.1). 플레이어가 "무엇을 노릴까" 를 정하는 숫자가 여기 있다.
func _test_recommendation_card_shows_the_real_tower_value() -> void:
	var main = MainScript.new()
	var checked := 0
	for word in ["입구", "보루", "기운", "바늘", "안개", "구름"]:
		var data: Dictionary = WordDatabase.get_word_data(word)
		if data.is_empty(): continue
		checked += 1
		var stats: Dictionary = WordTower.preview_stats(word, data)
		var line: String = main._recommendation_line(data)
		check(line.contains("%.1f" % float(stats["dps"])),
			"The recommendation card must show the real DPS for %s (got '%s', real %.1f)"
				% [word, line, stats["dps"]])
		check(line.contains(str(WordTower.TRAIT_NAMES.get(str(stats["trait"]), str(stats["trait"])))),
			"The recommendation card must name the real trait for %s (got '%s', real %s)"
				% [word, line, stats["trait"]])
	check(checked >= 5, "The recommendation guard must actually check words (checked %d)" % checked)
	main.free()


## 자유 배치: 단어가 안 되는 배치도 놓을 수 있어야 한다.
##
## 예전 규칙은 "슬롯의 **모든** 자모가 하나의 스트림으로 소비되어야 한다" 였다
## (`parsed[0].indices.size() == 슬롯 타일 수`). 그래서 파서가 버리는 자모가 섞이면
## 드롭이 거부됐다 — ㅅ ㅣ ㅜ ㅏ 가 정확히 그 경우다(ㅜ·ㅏ 는 초성이 아니라 버려진다).
## 사용자가 말한 "말이 안 되는 단어도 자유롭게 배치" 가 이 지점이다.
##
## 이제 놓는 것은 자유롭고, 그 슬롯이 **타워가 되는지**는 parsed_slots() 가 따로
## 판단한다. 배치를 막는 것과 벌을 주는 것은 다른 일이다.
func _test_any_placement_is_allowed_even_when_it_is_not_a_word() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	# ㅅ ㅣ ㅜ ㅏ — 시 까지만 스트림이 되고 ㅜ·ㅏ 는 버려진다.
	belt.jamo_list.assign([String.chr(0x3145), String.chr(0x3163), String.chr(0x315C), String.chr(0x314F)])
	belt.slot_assignments.assign([-1, -1, -1, -1])
	belt.render_belt()
	for i in range(4):
		check(belt.move_jamo_to_slot(i, 0),
			"Tile %d must be placeable even though the slot is not a word" % i)
	check(belt._slot_chars(0) == [String.chr(0x3145), String.chr(0x3163), String.chr(0x315C), String.chr(0x314F)],
		"Every placed tile must stay in the slot (got %s)" % str(belt._slot_chars(0)))
	check(belt.jamo_list.size() == 4, "No tile may be dropped on the floor")
	# 벌은 남는다: 자모가 버려지는 슬롯은 타워가 안 된다.
	check(belt.parsed_slots()[0].is_empty(),
		"A slot whose jamo do not form one stream must not produce a tower")

	# 배치를 자유롭게 한 것이 타워 규칙을 바꾼 건 아니다. 한 단어가 되는 배치는
	# 여전히 타워가 되고, 2음절(가나)은 원래도 한 타워로 묶였다(3음절까지 묶는 규칙).
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F)])
	belt.slot_assignments.assign([-1, -1, -1, -1])
	belt.render_belt()
	for i in range(4):
		check(belt.move_jamo_to_slot(i, 0), "가나 must be placeable")
	check(not belt.parsed_slots()[0].is_empty(),
		"A slot that forms one word must still produce a tower")
	belt.free()


## 트레이 머리 줄의 배치 계약.
##
## 이 계약은 코드를 읽어서는 안 지켜진다. 폰트 크기 10px 의 한글은 7px 남짓으로
## 그려져서, [목표 2음절][힌트][고정] 이 오른쪽 끝에 뭉쳐 있어도 '그냥 작은 글씨' 로
## 보인다. 실제로 제목이 EXPAND_FILL 로 남는 폭을 혼자 다 먹은 탓에 목표가
## 버튼 무리에 섞여 나갔고, 플레이 중에는 그것을 알아챌 방법이 없었다.
##
## 그래서 눈이 아니라 좌표로 잠근다: 머리는 트레이 안에 들어가고, 목표는
## 제목 **바로 옆**에 붙는다. 목표가 오른쪽으로 밀리면 실패한다.
func _test_tray_head_stays_inside_and_keeps_the_target_next_to_the_title() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign([String.chr(0x3131), String.chr(0x314F), String.chr(0x3134), String.chr(0x314F), String.chr(0x3141)])
	belt.slot_assignments.assign([0, 0, 1, 1, 1])
	belt.render_belt()
	belt.slot_grades[0] = belt._grade_slot(0, "가나")
	belt.slot_targets[0] = "가나"
	belt.render_belt()
	# 컨테이너 배치는 프레임을 넘겨야 확정된다. 최소 크기만 보면 실제 배치를 못 본다.
	await get_tree().process_frame
	await get_tree().process_frame

	var tray: Control = belt.tiles_container.get_child(0)
	var tray_rect: Rect2 = tray.get_global_rect()
	var titles: Array = belt.find_children("SlotTitle", "Label", true, false)
	var target_labels: Array = belt.find_children("TargetLabel", "Label", true, false)
	var hint_buttons: Array = belt.find_children("HintButton", "Button", true, false)
	check(not titles.is_empty() and not target_labels.is_empty() and not hint_buttons.is_empty(),
		"The tray head must keep its title, target label and buttons")
	if titles.is_empty() or target_labels.is_empty() or hint_buttons.is_empty():
		belt.free()
		return
	var title: Label = titles[0]
	var target_label: Label = target_labels[0]
	var hint_button: Button = hint_buttons[0]

	check(hint_button.get_global_rect().end.x <= tray_rect.end.x,
		"The slot buttons must stay inside their tray (button ends at %.1f, tray at %.1f)"
			% [hint_button.get_global_rect().end.x, tray_rect.end.x])
	# 제목과 목표는 한 문장('1번 슬롯 · 목표 2음절')으로 읽혀야 한다. 사이가 벌어지면
	# 목표가 오른쪽 버튼 무리에 섞여 버튼처럼 보인다.
	#
	# 재는 기준은 제목의 **글자 폭**(get_minimum_size)이지 제목 라벨의 사각형이 아니다.
	# 사각형으로 재면 이 계약이 통째로 무력해진다 — 예전 버그는 제목이 EXPAND_FILL 로
	# 사각형만 181px 로 늘어난 것이었고, 글자는 그 안 가운데에 그대로 있었다.
	var title_text_width: float = title.get_minimum_size().x
	var title_to_target: float = target_label.get_global_rect().position.x - (title.get_global_rect().position.x + title_text_width)
	check(title_to_target >= 0.0 and title_to_target <= 8.0,
		"The target word must sit right next to the slot title text, not against the buttons (gap %.1f)" % title_to_target)
	# 목표 단어는 버튼보다 왼쪽에 있어야 한다 — 순서가 뒤집히면 읽는 순서가 깨진다.
	check(target_label.get_global_rect().end.x < hint_button.get_global_rect().position.x,
		"The target word must be read before the hint button")
	belt.free()


func _test_global_shop_relics_change_every_tower() -> void:
	# '활자의 정수' / '신속의 나침반' 은 조건 없이 모든 타워에 걸리는 상점 유물이다.
	# 한때 이 둘은 상점에만 있고 게임 로직이 아무 데서도 읽지 않아 35G 짜리 사기였다.
	var fields := []
	var towers := []
	for relic_set in [[], ["relic_essence_power"], ["relic_haste_compass"]]:
		var field = DefenseFieldScript.new()
		field.relic_ids = relic_set
		var tower = WordTowerScript.new()
		tower.setup_tower("가나", {"category": "weapon", "damage": 999}, field)
		fields.append(field)
		towers.append(tower)
	var plain = towers[0]
	var essence = towers[1]
	var haste = towers[2]

	check(is_equal_approx(essence.damage_multiplier, plain.damage_multiplier * 1.2),
		"활자의 정수 must raise every tower's damage by 20%")
	check(is_equal_approx(essence.attack_interval, plain.attack_interval),
		"활자의 정수 must not touch attack speed")
	# 상점 설명은 "공격 속도 +20%" 다. 공격속도는 '초당 공격 횟수' 이므로 간격은 **역수**인
	# 1/1.2 배가 되어야 한다. 예전 이 검사는 `plain.attack_interval * 0.8` 을 요구했는데,
	# 그건 속도 +25% 라서 **설명(+20%)과 코드가 어긋난 상태를 테스트가 잠그고 있었다.**
	check(is_equal_approx(haste.attack_interval, plain.attack_interval / 1.2),
		"신속의 나침반 must raise attack SPEED by 20%% (interval /= 1.2), not shorten the interval by 20%%")
	check(is_equal_approx(haste.damage_multiplier, plain.damage_multiplier),
		"신속의 나침반 must not touch damage")
	check(essence.synergy_labels.any(func(label): return str(label).begins_with("활자의 정수")),
		"The essence power relic must be visible in tower details")
	check(haste.synergy_labels.any(func(label): return str(label).begins_with("신속의 나침반")),
		"The haste compass relic must be visible in tower details")
	check(not plain.synergy_labels.any(func(label): return str(label).begins_with("활자의 정수")),
		"A tower without the relic must not claim its bonus")

	for tower in towers: tower.free()
	for field in fields: field.free()


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
	check(emitted.size() == 3, "Belt must emit three positional tower slots")
	check(emitted[0].get("syllable", "") == String.chr(0xBD80), "Slot 1 must build its own syllable")
	check(emitted[1].get("syllable", "") == String.chr(0xB8E8), "Slot 2 must build its own syllable")
	belt.add_jamo(String.chr(0x3131))
	check(belt.slot_assignments[-1] == -1, "New jamo must enter waiting")
	belt.restore_assignments([])
	check(belt.slot_assignments.all(func(slot): return slot == -1), "Old saves must migrate all jamo to waiting")
	check(not belt.move_jamo_to_slot(0, 3), "Locked tower tray must reject drops")
	belt.free()


func _test_parser_prefers_registered_word_at_double_consonant_boundary() -> void:
	var parsed = HangulStreamParser.parse_jamo_stream(["ㄱ", "ㅜ", "ㅇ", "ㄱ", "ㅡ", "ㄱ", "ㄱ", "ㅣ"])
	check(parsed.size() == 1 and parsed[0].syllable == "궁극기", "Registered 궁극기 must not be parsed as 궁그끼")


## 사전의 **모든** 단어는 자기 자모 열로 다시 파싱되어야 한다.
##
## 같은 자모 열을 두 해독기가 서로 다르게 읽고 있었다:
##   · 채점(_grade_slot) → AutoArrange.required_jamo(word) 로 비교
##   · 타워 생성(parsed_slots) → HangulStreamParser.parse_jamo_stream()
## 도깨비에서 이 둘이 갈렸다. required_jamo 는 ㄷㅗㄱㄱㅏㅣㅂㅣ(= 도 + 깨 + 비)인데
## 파서는 그 열을 '독개비' 로 읽어 **미지의 활자 타워**를 세웠다. 그래서 슬롯은 8장이
## 전부 초록('제자리')인데 도깨비 타워는 서지 않는다 — 화면은 "맞다" 고 말하고
## 필드는 다른 것을 세우니, 플레이어가 할 수 있는 일이 없다.
##
## 원인은 _prefer_registered_jong_split 이 다음 음절의 **중성 합성**을 빼먹은 것이다.
## 깨 = ㄲ + ㅐ 이고 ㅐ = ㅏ + ㅣ 라서 다음 음절은 3장(ㄱ,ㅏ,ㅣ)인데, 그 함수는
## 2장(ㄱ,ㅏ)만 보고 '도까' 를 만들었다. '도까' 로 시작하는 단어는 없으니 등록된
## '독' 쪽을 택했고, 그 순간 열은 독개비로 굳었다.
##
## 위의 궁극기 테스트가 잠근 것은 **자음** 경계(ㄱ+ㄱ → ㄲ)다. 모음 경계(ㅏ+ㅣ → ㅐ)는
## 비어 있었고, 그래서 도깨비가 뚫렸다. 이 감사는 사전 전체를 돈다 — 한 단어만
## 고치면 같은 결함이 다음 단어에서 다시 나온다.
func _test_every_registered_word_survives_its_own_jamo_column() -> void:
	var broken: Array[String] = []
	for data in WordDatabase.get_all_words():
		var word := str(data.get("word", ""))
		if word.length() < 2: continue      # 1음절은 종성 경계 자체가 없다
		var required: Array = AutoArrange.required_jamo(word)
		if required.is_empty(): continue
		var chars: Array[String] = []
		for jamo in required: chars.append(str(jamo))
		var parsed := HangulStreamParser.parse_jamo_stream(chars)
		var consumed := 0
		for p in parsed: consumed += int(p.get("indices", []).size())
		var rebuilt := str(parsed[0].get("syllable", "")) if parsed.size() == 1 else "%d조각" % parsed.size()
		if parsed.size() != 1 or rebuilt != word or consumed != required.size():
			broken.append("%s(%s)→%s" % [word, "".join(required), rebuilt])
	check(broken.is_empty(), "Every registered word must rebuild from its own jamo column, but these do not: %s" % ", ".join(broken))


## CanvasItem 의 **실효 z**. z_as_relative 면 조상들의 z 를 모두 더한다 —
## ModalLayer 가 Control 인 이상 z_index 는 트리 전체가 한 순서로 비교되므로,
## '내 z' 가 아니라 '실효 z' 로만 비교해야 맞다.
func _effective_z(node: CanvasItem) -> int:
	var total := 0
	var cur: Node = node
	while cur is CanvasItem:
		if (cur as CanvasItem).z_as_relative:
			total += int((cur as CanvasItem).z_index)
		else:
			return int((cur as CanvasItem).z_index)
		cur = cur.get_parent()
	return total


## 모달 레이어는 게임 트리의 **어떤 것보다** 위에 있어야 한다.
##
## ModalLayer 는 CanvasLayer 가 아니라 그냥 Control 이라 z_index 가 트리 전체에서
## 하나의 순서로 비교된다. 그래서 필드의 일시적 효과가 z_index 를 크게 잡으면 모달
## **위로** 올라온다. 실제로 런 요약은 z_index 를 아예 안 잡아 0 이었고, 그 위에
## 필드의 골드 라벨(100)과 골드 조각 6개(99)가 찍혀 요약을 덮었다
## (디렉터 보고: "결과 화면이 꽉차서 안보이고, 회전 아이콘이 위로 보인다").
##
## **한 곳만 고치면 다음 모달에서 또 난다** — 상점·도감·타워 정보창도 같은 이유로
## 필드 효과 아래에 깔린다. 그래서 호출부가 아니라 **천장**을 계약으로 잡는다:
## 게임 트리의 어떤 노드도 모달 레이어의 실효 z 에 닿으면 안 된다.
func _test_the_modal_layer_stays_above_everything_else() -> void:
	SaveManager.delete_save_file()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal_layer: Control = main.get_node_or_null("ModalLayer")
	check(modal_layer != null, "The main scene needs a ModalLayer to order modals against the game tree")
	if modal_layer == null:
		main.free()
		return
	# 벨트에 회전 가능한 활자를 넣어 **회전 배지가 실제로 존재하는** 상태로 만든다.
	# (보고의 당사자가 이 배지였다 — 존재하지 않으면 가드가 헛돈다)
	var belt = main.find_child("JamoBelt", true, false)
	if belt != null:
		belt.jamo_list.assign([String.chr(0x314F), String.chr(0x3131)])
		belt.slot_assignments.assign([-1, -1])
		belt.set_unlocked_slot_count(1)
		belt.render_belt()
		check(not belt.find_children("RotateBadge", "Panel", true, false).is_empty(),
			"The guard needs a rotate badge to exist before it can prove anything")
	var ceiling := _effective_z(modal_layer)
	# 천장이 0 이면 게임 트리의 '기본 레이어' 와 구분되지 않는다 — 모달이 게임 트리와
	# 같은 레이어에 있다는 뜻이고, 그것이 바로 이 보고의 원인이었다.
	check(ceiling > 0, "ModalLayer must own a layer above the game tree, but its effective z is %d" % ceiling)
	var offenders: Array[String] = []
	var stack: Array = [main]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			# z 를 **주장한** 노드만 본다. 실효 z 가 0 인 노드는 기본 레이어라
			# 천장이 0 보다 크기만 하면 자동으로 아래다. 신호는 주장에서 나온다.
			if child is CanvasItem and child != modal_layer and not modal_layer.is_ancestor_of(child):
				var z := _effective_z(child)
				if z != 0 and z >= ceiling:
					offenders.append("%s(z=%d)" % [child.name, z])
			stack.append(child)
	check(offenders.is_empty(),
		"Nothing in the game tree may draw at or above ModalLayer (z=%d), but: %s" % [ceiling, ", ".join(offenders)])
	main.free()


## 역대 기록의 **순서 규칙**. 점수를 지어내지 않고 관찰 가능한 사실만 쓴다:
## 이겼는가 → 어디까지 갔는가 → 얼마나 때렸는가.
func _test_run_ranking_orders_by_progress_then_damage() -> void:
	var win := {"victory": true, "act": 3, "wave": 1, "total_damage": 10.0}
	var loss_deep := {"victory": false, "act": 3, "wave": 12, "total_damage": 9999.0}
	var loss_shallow := {"victory": false, "act": 1, "wave": 2, "total_damage": 9999.0}
	check(SaveManager.run_ranking_is_better(win, loss_deep), "A sealed run must outrank any failed run")
	check(SaveManager.run_ranking_is_better(loss_deep, loss_shallow), "Deeper progress must outrank shallower progress")
	check(not SaveManager.run_ranking_is_better(loss_shallow, loss_deep), "The ordering must not be symmetric")
	var far := {"victory": false, "act": 3, "wave": 12, "total_damage": 10.0}
	var hit_hard := {"victory": false, "act": 3, "wave": 12, "total_damage": 5000.0}
	check(SaveManager.run_ranking_is_better(hit_hard, far), "At equal progress the run that dealt more must win")
	check(not SaveManager.run_ranking_is_better(far, far), "An entry must not outrank itself")


## 상위 10개만 남긴다 — 파일이 무한히 자라면 안 된다.
func _test_run_ranking_keeps_only_the_best_ten() -> void:
	SaveManager.clear_run_ranking()
	for i in range(12):
		SaveManager.submit_run({"victory": false, "act": 1, "wave": i + 1, "total_damage": float(i)})
	var stored := SaveManager.get_run_ranking()
	check(stored.size() == SaveManager.RANKING_LIMIT,
		"The ranking must keep %d entries, got %d" % [SaveManager.RANKING_LIMIT, stored.size()])
	check(int(stored[0].get("wave", 0)) == 12, "The best run must be first")
	check(int(stored[-1].get("wave", 0)) == 3, "The two weakest runs must be dropped")
	SaveManager.clear_run_ranking()


## 이번 런이 몇 위인지, 그리고 그 줄이 목록 어디인지 돌려준다.
func _test_run_ranking_reports_the_new_runs_rank() -> void:
	SaveManager.clear_run_ranking()
	var first := SaveManager.submit_run({"victory": false, "act": 1, "wave": 5, "total_damage": 100.0})
	check(int(first.get("rank", 0)) == 1 and bool(first.get("is_best", false)), "The first run is always 1st")
	check(int(first.get("index", -1)) == 0, "The only entry must be at index 0")
	var worse := SaveManager.submit_run({"victory": false, "act": 1, "wave": 2, "total_damage": 100.0})
	check(int(worse.get("rank", 0)) == 2 and not bool(worse.get("is_best", true)), "A shallower run must rank 2nd")
	check(int(worse.get("index", -1)) == 1, "The 2nd-place entry must sit at index 1")
	var better := SaveManager.submit_run({"victory": false, "act": 2, "wave": 1, "total_damage": 100.0})
	check(int(better.get("rank", 0)) == 1, "A deeper run must take 1st")
	check(int(better.get("index", -1)) == 0, "The new 1st-place entry must sit at index 0")
	check(int(better.get("total", 0)) == 3, "All three runs must be counted")
	SaveManager.clear_run_ranking()


## `game_over` 는 한 번만 오지 않는다 — 기지 HP 가 0 이 된 뒤로 적이 기지에 닿을 때마다
## 다시 온다. 그때마다 결과 모달을 새로 만들면 모달이 겹겹이 쌓이고(디렉터 보고의
## '결과 화면이 꽉 차서 안 보인다' 에 이 형태가 섞여 있었다) 같은 런이 여러 번 기록된다.
func _test_game_over_records_the_run_only_once() -> void:
	SaveManager.clear_run_ranking()
	# 세이브가 남아 있으면 메인 씬이 그것을 불러오면서 자기 모달을 하나 연다.
	# 그러면 '모달이 몇 개인가' 가 환경에 따라 달라지므로 먼저 지운다.
	SaveManager.delete_save_file()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var modal_layer: Control = main.get_node_or_null("ModalLayer")
	check(modal_layer != null, "The main scene needs a ModalLayer")
	if modal_layer != null:
		# 개수가 아니라 **증가분**을 본다. 씬이 스스로 연 모달(코치마크·불러오기 안내)이
		# 있으면 절대값은 환경에 따라 달라진다 — 계약은 "세 번 불러도 하나만 는다" 다.
		var before := modal_layer.get_child_count()
		main._on_game_over(false)
		main._on_game_over(false)
		main._on_game_over(false)
		var recorded := SaveManager.get_run_ranking().size()
		check(recorded == 1, "A repeated game_over must record the run exactly once, got %d" % recorded)
		var added := modal_layer.get_child_count() - before
		check(added == 1, "A repeated game_over must add exactly one result modal, got %d" % added)
	main.queue_free()
	SaveManager.clear_run_ranking()
	SaveManager.delete_save_file()


## 패배에는 **이유**가 있어야 한다.
##
## 안전밸브(`MAX_ENEMIES`) 초과와 기지 함락은 둘 다 `game_over(false)` 로 나가지만 원인이
## 전혀 다르다. 문구가 하나뿐이면, 적 50마리 과부하로 끝난 런도 "활자의 빛이 꺼졌습니다…"
## 로만 보인다 — 그 경우 기지 HP 는 가득 차 있을 수 있어 화면 어디에도 근거가 없다.
func _test_a_defeat_says_why_it_happened() -> void:
	# 트리에 넣지 않는다. `_ready` 가 `$VBox`·`$TopBar` 를 찾으므로 씬 없이 add_child 하면
	# 거기서 죽는다(스크립트 단독 인스턴스는 순수 함수만 부를 수 있다).
	var main = MainScript.new()
	var overload := main._defeat_verdict("overload")
	var breach := main._defeat_verdict("breach")
	check(overload.contains(str(DefenseField.MAX_ENEMIES)),
		"The overload verdict must name the cap (got '%s')" % overload)
	check(breach.contains(str(DefenseField.MAX_BASE_HP)),
		"The breach verdict must name how many got through (got '%s')" % breach)
	check(overload != breach, "Overload and breach must not read the same — the cause is different")
	check(not main._defeat_verdict("").is_empty(), "An unknown cause must still produce a verdict")
	main.free()


## 안전밸브는 **닿기 전에** 보여야 한다. 닿는 순간 런이 끝나므로 그때 알려 주면 늦다.
func _test_the_enemy_cap_becomes_visible_before_it_is_reached() -> void:
	SaveManager.delete_save_file()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var label = main.find_child("EnemyLabel", true, false)
	check(label != null, "The top bar needs the enemy counter")
	if label != null:
		main._on_enemy_count_changed(3)
		var calm := str(label.text)
		main._on_enemy_count_changed(DefenseField.MAX_ENEMIES - 1)
		var warning := str(label.text)
		check(not calm.contains(str(DefenseField.MAX_ENEMIES)),
			"The cap must stay hidden while the count is low (got '%s')" % calm)
		check(warning.contains(str(DefenseField.MAX_ENEMIES)),
			"The cap must be shown before it is reached (got '%s')" % warning)
		check(calm != warning, "Approaching the cap must change the counter")
	main.queue_free()
	SaveManager.delete_save_file()


func _test_pig_tower_uses_three_tile_vowel() -> void:
	var parsed = HangulStreamParser.parse_jamo_stream(["ㄷ", "ㅗ", "ㅏ", "ㅣ", "ㅈ", "ㅣ"])
	check(parsed.size() == 1 and parsed[0].syllable == "돼지" and not parsed[0].word_data.get("is_unknown", false), "ㄷ+ㅗ+ㅏ+ㅣ+ㅈ+ㅣ must build the 돼지 tower")


func _test_auto_arrange_builds_highest_tier_word() -> void:
	var owned: Array[String] = ["ㅂ", "ㅜ", "ㄹ", "ㄴ", "ㅏ"]
	var result := AutoArrange.shuffled_tiles_for(owned, [{"word": "불", "tier": 1, "damage": 10}, {"word": "불나", "tier": 2, "damage": 5}])
	check(result.get("word", "") == "불나", "Auto arrange must prefer the highest-tier buildable word")
	check(result.get("tiles", []).size() == owned.size(), "Auto arrange must preserve every owned tile")
	var compound_slots: Array = AutoArrange.get_word_syllable_slots("과")[0]
	check(compound_slots[1].size() == 2 and compound_slots[1][0] == "ㅗ" and compound_slots[1][1] == "ㅏ", "Compound vowels must remain multi-tile slots")
	var rotated_compound := AutoArrange.shuffled_tiles_for(["ㄱ", "ㅏ", "ㅏ"], [{"word": "과", "tier": 1}])
	check(rotated_compound.get("word", "") == "과", "Auto arrange must consider rotation inside compound vowels")


func _test_optimize_rebuilds_all_slots() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign(["ㅂ", "ㅜ", "ㄹ", "ㅂ", "ㅏ", "ㄹ", "ㄱ", "ㅣ", "ㅁ"])
	belt.slot_assignments.assign([0, 0, 0, 0, 0, 0, -1, -1, -1])
	for index in range(21):
		belt.jamo_list.append(HangulEngine.ALL_DRAW_POOL[index % HangulEngine.ALL_DRAW_POOL.size()])
		belt.slot_assignments.append(-1)
	belt.set_unlocked_slot_count(3)
	var before: Array = belt.slot_assignments.duplicate()
	var requested := [false]
	belt.strategy_recommendations_requested.connect(func(): requested[0] = true)
	check(belt.optimize_tiles() and requested[0], "Optimize must open strategic recommendations")
	check(belt.slot_assignments == before, "Recommendations must not place tiles for the player")
	belt.free()


func _test_optimize_does_not_repeat_the_same_tower() -> void:
	var words = [{"word": "가", "tier": 3, "damage": 99}, {"word": "나", "tier": 2, "damage": 10}]
	var result := AutoArrange.best_word_set_for(["ㄱ", "ㅏ", "ㄱ", "ㅏ", "ㄴ", "ㅏ"], words, 2)
	check(result.map(func(data): return data.word) == ["가", "나"], "Optimize must not build the same tower in every slot")


func _test_optimize_builds_multi_syllable_word_with_rotation() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign(["ㄱ", "ㅡ", "ㅁ", "ㄱ", "ㅏ", "ㅇ", "ㅅ", "ㅓ", "ㄱ"])
	belt.slot_assignments.assign([-1, -1, -1, -1, -1, -1, -1, -1, -1])
	belt.set_unlocked_slot_count(1)
	var before: Array = belt.slot_assignments.duplicate()
	var requested := [false]
	belt.strategy_recommendations_requested.connect(func(): requested[0] = true)
	check(belt.optimize_tiles() and requested[0], "Optimize must request multi-syllable recommendations")
	check(belt.slot_assignments == before, "Recommendations must preserve manual tile placement")
	belt.free()


func _test_recommendation_uses_only_unknown_and_waiting_tiles() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign(["ㅂ", "ㅣ", "ㄹ"])
	belt.slot_assignments.assign([0, 0, -1])
	belt.set_unlocked_slot_count(1)
	check(belt.recommendation_tiles() == ["ㄹ"], "Registered tower tiles must stay out of recommendations")
	belt.jamo_list.assign(["ㅂ", "ㅣ", "ㄹ", "ㄱ"])
	belt.slot_assignments.assign([0, 0, 0, -1])
	check(belt.recommendation_tiles() == ["ㅂ", "ㅣ", "ㄹ", "ㄱ"], "Unknown tower and waiting tiles must be recommended together")
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


func _test_tower_info_styles_synergies() -> void:
	var modal = TowerInfoScene.instantiate()
	add_child(modal)
	modal.setup({"name": "test", "damage": 10}, "불", 100.0, 1.0, ["특성: 저격", "원소 공명"])
	# ⚠️ §2.38 (2026-10-06) — 예전에는 **안 보이는** 텍스트 표면(`modal.synergy_label`)의
	#    내용을 단언했다. 그 노드는 씬에서 `visible = false` 이고 `visible = true` 대입이
	#    `godot/` 전체에 0건이라 **영영 안 보였으므로**, 이 테스트는 *"테스트가 초록이니
	#    이 코드는 살아 있다"* 로 읽히면서 실제로는 **아무도 안 보는 것을 지키는 초록**이었다.
	#    게다가 정당한 정리(죽은 표면 삭제)를 **회귀처럼** 보이게 만들었다.
	#    이제 **플레이어가 실제로 보는** 표면(배지)만 잠근다.
	var badges: Array = modal.synergy_row.get_children()
	check(badges.size() == 2, "Synergies must render one badge each (got %d)" % badges.size())
	if badges.size() == 2:
		var trait_col: Color = _badge_text_color(badges[0])
		var relic_col: Color = _badge_text_color(badges[1])
		check(trait_col == TraitStyle.color_for("sniper"),
			"Trait badge must use the trait colour (got %s)" % str(trait_col))
		check(trait_col != relic_col, "Synergies must have distinct colours")
		# 글리프가 아니라 **직접 그린 아이콘**이어야 한다 — 이모지는 이 폰트에 없어
		# OS 폴백으로 그려진다(§2.30-4 · §2.37).
		check(_badge_has_drawn_icon(badges[0]),
			"Trait badge must carry a drawn icon, not a font glyph")
	modal.free()


## 배지가 글자에 쓰는 색 — 배지가 화면에 내는 색이다(테두리도 같은 색을 쓴다).
## ⚠️ 스타일박스가 아니라 **라벨의 글자색**을 읽는다: 이 단언의 목적은 "서로 구별되는가" 이고,
##    그걸 플레이어가 보는 것은 글자색이다.
func _badge_text_color(badge: Control) -> Color:
	for c in badge.get_children():
		for g in c.get_children():
			if g is Label:
				return g.get_theme_color("font_color")
	return Color(0, 0, 0, 0)


## 배지 안에 **직접 그린 아이콘**(`TraitIcon`)이 있는가.
func _badge_has_drawn_icon(badge: Control) -> bool:
	for c in badge.get_children():
		for g in c.get_children():
			if g is TraitIconScript:
				return true
	return false


func _test_tower_info_shows_tile_recipe() -> void:
	var modal = TowerInfoScene.instantiate()
	add_child(modal)
	modal.setup({"name": "궁극기", "damage": 10, "desc": "궁극의 힘"}, "궁극기", 100.0, 1.0)
	check(modal.stats_label.text.contains("공격") and modal.stats_label.text.contains("사거리"), "Tower info must show compact stats with labels")
	modal.free()


## ── 선회 방향 (시계 / 반시계) ────────────────────────────────────────────────
##
## Godot 2D 는 y 축이 아래로 향한다. 그래서 각도가 커지는 쪽이 화면에서는
## '시계 방향' 이다 — 3시에서 6시로 내려간다. 예전 코드는 이 방향으로 고정돼 있었다.
## 기본값이 뒤집히면 플레이어가 보던 것과 반대가 되므로 여기서 못 박아 둔다.
func _test_orbit_direction_defaults_to_clockwise_and_reverses() -> void:
	var tower = WordTowerScript.new()
	var orbit = TowerOrbitScript.new()
	orbit.setup(tower, 1, true)
	check(orbit.clockwise, "An orbit must default to clockwise — the direction players already saw")

	# 3시(각도 0)에서 한 프레임 진행하면 6시 쪽(y 가 커지는 쪽)으로 가야 시계다.
	orbit._angle = 0.0
	orbit._angle = orbit._advance(orbit._angle, 0.1)
	check(orbit.orb_positions()[0].y > 0.0,
		"Clockwise must move the orb from 3 o'clock toward 6 o'clock (y down)")

	orbit.set_clockwise(false)
	check(not orbit.clockwise, "set_clockwise(false) must reverse the orbit")
	orbit._angle = 0.0
	orbit._angle = orbit._advance(orbit._angle, 0.1)
	check(orbit.orb_positions()[0].y < 0.0,
		"Counter-clockwise must move the orb from 3 o'clock toward 12 o'clock (y up)")

	# 뒤집어도 각도 자체는 유지돼야 한다 — 오브가 제자리에서 돌아야 눈으로 확인된다.
	orbit.set_clockwise(true)
	orbit._angle = 1.0
	orbit.set_clockwise(false)
	check(is_equal_approx(orbit._angle, 1.0), "Reversing must not teleport the orbs")

	orbit.free()
	tower.free()


## 방향 전환은 '오브가 있는 타워' 에만 의미가 있다. 다른 특성에서 눌러도 아무 일도
## 없어야 하고, 있어야 할 곳에서는 즉시 반영돼야 한다.
func _test_right_click_reverses_only_orbit_towers() -> void:
	var field = DefenseFieldScript.new()
	var orbit_tower = WordTowerScript.new()
	orbit_tower.setup_tower("가나", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	check(orbit_tower.trait_id == "orbit", "The right-click test needs an orbit tower")
	check(orbit_tower.orbit_clockwise, "A fresh orbit tower must start clockwise")

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	orbit_tower._on_drag_input(right_click)

	check(not orbit_tower.orbit_clockwise, "Right-clicking an orbit tower must reverse its orbit")
	var orbit_node = orbit_tower.get_node_or_null("Orbit")
	check(orbit_node != null and not orbit_node.clockwise,
		"The live orbit node must follow the tower's direction right away")

	orbit_tower._on_drag_input(right_click)
	check(orbit_tower.orbit_clockwise, "Right-clicking twice must return to the original direction")

	# 오브가 없는 타워 — 방향을 뒤집을 대상 자체가 없다.
	var sword = WordTowerScript.new()
	sword.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	check(sword.trait_id != "orbit", "The no-op test needs a non-orbit tower")
	sword._on_drag_input(right_click)
	check(sword.orbit_clockwise, "A tower without orbs must ignore the direction toggle")
	check(sword.get_node_or_null("Orbit") == null, "A non-orbit tower must never gain an orbit node")

	sword.free()
	orbit_tower.free()
	field.free()


## 방향은 화면에서 보이지만, '바꿀 수 있다' 는 보이지 않는다.
## 이 기능이 있는지조차 모르면 없는 것과 같으므로 툴팁이 알려 줘야 한다.
func _test_orbit_direction_is_stated_on_the_tooltip() -> void:
	var field = DefenseFieldScript.new()
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("가나", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	tower.btn_select.mouse_entered.emit()
	check(tower.btn_select.tooltip_text.contains("선회 방향"),
		"The tooltip must tell the player the orbit direction can be changed")
	check(tower.btn_select.tooltip_text.contains("시계 방향"),
		"The tooltip must state the current direction")
	check(tower.btn_select.tooltip_text.contains("우클릭"),
		"The tooltip must say how to change it")

	# 뒤집은 뒤 툴팁이 예전 방향을 계속 말하면 거짓말이 된다.
	tower.set_orbit_direction(false)
	check(tower.btn_select.tooltip_text.contains("반시계 방향"),
		"The tooltip must follow the direction after it changes")

	# 오브가 없는 타워에는 이 줄이 붙으면 안 된다.
	var sword = WordTowerScene.instantiate()
	add_child(sword)
	sword.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	sword.btn_select.mouse_entered.emit()
	check(not sword.btn_select.tooltip_text.contains("선회 방향"),
		"A tower without orbs must not advertise an orbit direction")

	sword.free()
	tower.free()
	field.free()


## 자모를 고치면 update_towers_from_parsed_list 가 타워를 통째로 다시 세운다.
## 방향을 타워 노드에만 담아 두면 그때마다 플레이어의 선택이 사라진다.
func _test_orbit_direction_survives_a_tower_rebuild() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.unlocked_slot_count = DefenseFieldScript.MAX_UNLOCKED_SLOTS

	var parsed: Array = []
	for i in range(DefenseFieldScript.MAX_UNLOCKED_SLOTS):
		parsed.append({"syllable": "가나", "word_data": {"category": "summon", "damage": 4, "is_unknown": true}})
	field.update_towers_from_parsed_list(parsed)
	check(field.active_towers.size() == DefenseFieldScript.MAX_UNLOCKED_SLOTS, "The rebuild test needs three towers")
	if field.active_towers.size() < 1:
		field.free()
		return

	var first = field.active_towers[0]
	check(first.trait_id == "orbit", "The rebuild test needs an orbit tower in slot 0")
	field.remember_orbit_direction(first.logical_slot_index, false)
	first.set_orbit_direction(false)
	check(not first.orbit_clockwise, "Changing the direction must reach the live tower")

	# 자모를 고쳐 타워를 다시 세운다 — 새 노드가 같은 방향으로 돌아야 한다.
	field.update_towers_from_parsed_list(parsed)
	var rebuilt = field.active_towers[0]
	check(rebuilt != first, "The rebuild must actually replace the tower node")
	check(not rebuilt.orbit_clockwise, "The slot must remember the reversed direction")
	var rebuilt_orbit = rebuilt.get_node_or_null("Orbit")
	check(rebuilt_orbit != null and not rebuilt_orbit.clockwise,
		"The rebuilt orbit node must spin the remembered way")

	# 방향을 정하지 않은 슬롯은 기본값(시계)을 유지해야 한다.
	var untouched = field.active_towers[1]
	check(untouched.orbit_clockwise, "A slot that was never changed must keep the default direction")

	# 세이브는 JSON 이라 정수 키가 문자열이 된다. 문자열 키로 저장하지 않으면
	# 불러온 뒤 has(0) 이 false 가 되어 방향이 조용히 사라진다.
	check(field.orbit_directions.has(str(rebuilt.logical_slot_index)),
		"Orbit directions must be keyed by slot string so they survive a JSON round trip")

	field.free()


## ── 조준 우선순위 (진급 / 후미 / 강적 / 근접) ─────────────────────────────────
##
## 네 모드가 **서로 다른 적** 을 고르는가. 하나라도 같은 답을 내면 그 모드는
## 존재할 이유가 없다 — 플레이어가 바꿔도 아무 일이 일어나지 않기 때문이다.
## 그래서 네 축(진행도 최대 / 진행도 최소 / 체력 최대 / 거리 최소)을 각각
## 서로 다른 적이 차지하도록 배치한다.
func _test_targeting_modes_pick_different_enemies() -> void:
	var field = StubField.new()
	add_child(field)
	var tower = WordTowerScript.new()
	tower.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	tower.attack_range = 400.0

	var ahead = EnemyUnitScene.instantiate()
	add_child(ahead)
	ahead.init_enemy("ahead", 100.0, 0.0, 0, "")
	ahead.progress = 900.0
	ahead.hp = 10.0
	ahead.global_position = Vector2(300, 0)

	var behind = EnemyUnitScene.instantiate()
	add_child(behind)
	behind.init_enemy("behind", 100.0, 0.0, 0, "")
	behind.progress = 100.0
	behind.hp = 10.0
	behind.global_position = Vector2(200, 0)

	var heavy = EnemyUnitScene.instantiate()
	add_child(heavy)
	heavy.init_enemy("heavy", 100.0, 0.0, 0, "")
	heavy.progress = 500.0
	heavy.hp = 80.0
	heavy.global_position = Vector2(300, 0)

	var near = EnemyUnitScene.instantiate()
	add_child(near)
	near.init_enemy("near", 100.0, 0.0, 0, "")
	near.progress = 500.0
	near.hp = 10.0
	near.global_position = Vector2(50, 0)

	field.enemies = [ahead, behind, heavy, near]

	check(tower.targeting_mode == "first", "A fresh tower must keep the old behaviour (진급 우선)")
	tower.set_targeting_mode("first")
	check(tower.find_target() == ahead, "진급 우선 must pick the enemy closest to the base")
	tower.set_targeting_mode("last")
	check(tower.find_target() == behind, "후미 우선 must pick the enemy furthest from the base")
	tower.set_targeting_mode("strong")
	check(tower.find_target() == heavy, "강적 우선 must pick the enemy with the most HP")
	tower.set_targeting_mode("close")
	check(tower.find_target() == near, "근접 우선 must pick the nearest enemy")

	# 사거리 밖은 어떤 모드에서도 고르면 안 된다 — 조준은 '무엇을' 만 바꾸고
	# '닿는가' 는 바꾸지 않는다.
	tower.attack_range = 60.0
	tower.set_targeting_mode("first")
	check(tower.find_target() == near, "Targeting must never reach outside the attack range")

	# 모르는 id 는 무시해야 한다. 오타 하나가 타워를 조용히 기본값으로 되돌리면 안 된다.
	tower.set_targeting_mode("close")
	tower.set_targeting_mode("nonsense")
	check(tower.targeting_mode == "close", "An unknown targeting id must be ignored")

	near.free()
	heavy.free()
	behind.free()
	ahead.free()
	tower.free()
	field.free()


## 우클릭은 선회 타워에서 방향을, 나머지에서 조준을 바꾼다. 둘이 겹치면
## 한쪽 기능이 조용히 사라진다.
func _test_right_click_cycles_targeting_on_non_orbit_towers() -> void:
	var field = DefenseFieldScript.new()
	var sword = WordTowerScript.new()
	sword.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	check(sword.trait_id != "orbit", "The targeting test needs a non-orbit tower")

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	var seen: Array[String] = [sword.targeting_mode]
	for i in range(WordTowerScript.TARGETING_MODES.size() - 1):
		sword._on_drag_input(right_click)
		seen.append(sword.targeting_mode)
	var unique := {}
	for m in seen:
		unique[m] = true
	check(unique.size() == WordTowerScript.TARGETING_MODES.size(),
		"Right-clicking must cycle through every distinct targeting mode")

	# 한 바퀴 더 돌면 처음으로 돌아와야 한다.
	sword._on_drag_input(right_click)
	check(sword.targeting_mode == seen[0], "Cycling past the last mode must wrap to the first")

	# 선회 타워는 조준이 없다 — 우클릭이 방향 전환으로 남아야 한다.
	var orbit_tower = WordTowerScript.new()
	orbit_tower.setup_tower("가나", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	check(orbit_tower.trait_id == "orbit", "The orbit side of the test needs an orbit tower")
	var orbit_before: String = orbit_tower.targeting_mode
	orbit_tower._on_drag_input(right_click)
	check(not orbit_tower.orbit_clockwise, "Right-clicking an orbit tower must still reverse its orbit")
	check(orbit_tower.targeting_mode == orbit_before,
		"An orbit tower must not change targeting — it has none")

	orbit_tower.free()
	sword.free()
	field.free()


## 조준은 방향과 다르다 — '진급 우선' 같은 이름만으로는 무엇을 고르는지 알 수 없다.
## 이름·설명·바꾸는 방법이 셋 다 보여야 기능이 있는 것과 같아진다.
func _test_targeting_is_stated_on_the_tooltip() -> void:
	var field = DefenseFieldScript.new()
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	check(tower.trait_id != "orbit", "The tooltip test needs a non-orbit tower")
	tower.btn_select.mouse_entered.emit()
	check(tower.btn_select.tooltip_text.contains("조준"),
		"The tooltip must tell the player the tower has a targeting priority")
	check(tower.btn_select.tooltip_text.contains(tower.targeting_label()),
		"The tooltip must state the current targeting mode")
	check(tower.btn_select.tooltip_text.contains(tower.targeting_desc()),
		"The tooltip must explain what the current mode actually does")
	check(tower.btn_select.tooltip_text.contains("우클릭"),
		"The tooltip must say how to change it")

	# 바꾼 뒤 툴팁이 예전 조준을 계속 말하면 거짓말이 된다.
	tower.cycle_targeting_mode()
	check(tower.btn_select.tooltip_text.contains(tower.targeting_label()),
		"The tooltip must follow the targeting mode after it changes")
	check(not tower.btn_select.tooltip_text.contains("진급 우선"),
		"The tooltip must not keep advertising the previous mode")

	# 선회 타워에는 조준이 없다 — 조준 줄이 붙으면 안 된다.
	var orbit_tower = WordTowerScene.instantiate()
	add_child(orbit_tower)
	orbit_tower.setup_tower("가나", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	orbit_tower.btn_select.mouse_entered.emit()
	check(not orbit_tower.btn_select.tooltip_text.contains("🎯 조준"),
		"An orbit tower must not advertise a targeting priority")

	orbit_tower.free()
	tower.free()
	field.free()


## 자모를 고치면 타워가 통째로 다시 세워진다. 조준을 타워 노드에만 담아 두면
## 그때마다 플레이어의 선택이 사라진다(선회 방향과 같은 문제).
func _test_targeting_survives_a_tower_rebuild() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.unlocked_slot_count = DefenseFieldScript.MAX_UNLOCKED_SLOTS

	var parsed: Array = []
	for i in range(DefenseFieldScript.MAX_UNLOCKED_SLOTS):
		parsed.append({"syllable": "가나", "word_data": {"category": "weapon", "damage": 4, "is_unknown": true}})
	field.update_towers_from_parsed_list(parsed)
	check(field.active_towers.size() == DefenseFieldScript.MAX_UNLOCKED_SLOTS,
		"The rebuild test needs three towers")
	if field.active_towers.size() < 1:
		field.free()
		return

	var first = field.active_towers[0]
	check(first.trait_id != "orbit", "The rebuild test needs a non-orbit tower in slot 0")
	first.cycle_targeting_mode()
	var chosen: String = first.targeting_mode
	check(chosen != "first", "Cycling must actually change the mode")

	# 자모를 고쳐 타워를 다시 세운다 — 새 노드가 같은 조준을 써야 한다.
	field.update_towers_from_parsed_list(parsed)
	var rebuilt = field.active_towers[0]
	check(rebuilt != first, "The rebuild must actually replace the tower node")
	check(rebuilt.targeting_mode == chosen, "The slot must remember the targeting mode")

	# 조준을 정하지 않은 슬롯은 기본값을 유지해야 한다.
	var untouched = field.active_towers[1]
	check(untouched.targeting_mode == "first",
		"A slot that was never changed must keep the default targeting mode")

	# 세이브는 JSON 이라 정수 키가 문자열이 된다 — 문자열 키가 아니면 불러온 뒤 사라진다.
	check(field.target_modes.has(str(rebuilt.logical_slot_index)),
		"Targeting modes must be keyed by slot string so they survive a JSON round trip")

	field.free()


## 도감·힌트가 쓰는 값이 **실제 타워가 내는 값** 과 같은가. DB 전체를 돈다.
##
## 이 테스트가 막는 것은 하나다: '같은 사실을 두 곳에서 따로 계산하는 것'.
## `WordTower.preview_stats` 는 setup_tower 의 식을 옮겨 적은 것이라 언젠가 갈라진다 —
## 갈라지는 순간 화면의 숫자가 다시 거짓말이 된다(그게 원래 버그였다).
## 그래서 366개 단어 전부를 진짜 타워와 대조한다. 배율 하나를 고치고 이걸 안 고치면
## 여기서 바로 터진다.
func _test_preview_stats_matches_the_real_tower() -> void:
	var field = StubField.new()
	add_child(field)
	var checked := 0
	for data in WordDatabase.get_all_words():
		var word := str(data.get("word", ""))
		if word == "":
			continue
		var tower = WordTowerScene.instantiate()
		add_child(tower)
		tower.setup_tower(word, data, field)
		var stats: Dictionary = WordTowerScript.preview_stats(word, data)
		checked += 1
		# 형태의 결은 타워에서 damage_multiplier 로 들어가므로, 실제 발당 피해는
		# damage_per_attack() * damage_multiplier 다. preview per_hit 도 형태를
		# 포함하므로 둘을 그대로 대조한다.
		if not is_equal_approx(tower.damage_per_attack() * tower.damage_multiplier, float(stats["per_hit"])):
			check(false, "%s: preview per_hit %.4f but the real tower does %.4f"
				% [word, stats["per_hit"], tower.damage_per_attack() * tower.damage_multiplier])
		if not is_equal_approx(tower.attack_interval, float(stats["interval"])):
			check(false, "%s: preview interval %.4f but the real tower does %.4f"
				% [word, stats["interval"], tower.attack_interval])
		if tower.volley_count() != int(stats["volley"]):
			check(false, "%s: preview volley %d but the real tower does %d"
				% [word, stats["volley"], tower.volley_count()])
		if tower.trait_id != str(stats["trait"]):
			check(false, "%s: preview trait %s but the real tower is %s"
				% [word, stats["trait"], tower.trait_id])
		tower.free()
	check(checked >= 300, "The comparison must actually cover the database (checked %d)" % checked)
	field.free()


## 힌트는 '지금보다 약한 것' 을 목표로 세우면 안 된다.
##
## 디렉터 보고: 지금 바늘을 세워 뒀는데 힌트가 가루를 목표로 세웠다. 가루의 DB
## `damage` 는 44 로 바늘의 22 보다 컸지만, 실제 타워는 가루 9.5 DPS · 바늘 45.4 DPS 다.
## 순위를 매기던 `damage` 필드를 게임이 읽지 않았기 때문이다.
##
## 두 가지를 잠근다: (1) DB 전체에서 순위가 실제 세기와 어긋나지 않을 것,
## (2) 벨트가 이미 만들 수 있는 단어보다 약한 것을 목표로 삼지 않을 것.
func _test_hint_never_prefers_a_weaker_word() -> void:
	# (1) 같은 음절 수 안에서, 세기가 다른데 더 약한 쪽을 고르면 실패한다.
	#     0.05 DPS 여유를 두는 이유: 점수는 DPS x100 정수라 그보다 작은 차이는
	#     같은 값으로 반올림된다(그 정도 차이는 판단에 영향이 없다).
	var by_len := {}
	for data in WordDatabase.get_all_words():
		var word := str(data.get("word", ""))
		if word == "":
			continue
		by_len.get_or_add(word.length(), []).append(data)
	var inversions := 0
	var first_bad := ""
	for length in by_len:
		var group: Array = by_len[length]
		for i in range(group.size()):
			for j in range(i + 1, group.size()):
				var a: Dictionary = group[i]
				var b: Dictionary = group[j]
				var a_dps: float = float(WordTowerScript.preview_stats(str(a["word"]), a)["dps"])
				var b_dps: float = float(WordTowerScript.preview_stats(str(b["word"]), b)["dps"])
				if absf(a_dps - b_dps) <= 0.05:
					continue
				var stronger: Dictionary = a if a_dps > b_dps else b
				var weaker: Dictionary = b if a_dps > b_dps else a
				if AutoArrange._word_score(weaker) > AutoArrange._word_score(stronger):
					inversions += 1
					if first_bad == "":
						first_bad = "%s (%.1f DPS) scored above %s (%.1f DPS)" % [
							weaker["word"], minf(a_dps, b_dps), stronger["word"], maxf(a_dps, b_dps)]
	check(inversions == 0,
		"The hint's ranking must not prefer a weaker tower (%d inversions, first: %s)"
			% [inversions, first_bad])

	# (2) 보고된 사례 그대로. ㅂㅏㄴㅡㄹ = 바늘, ㄱㅏㄹㅜ = 가루.
	var tiles: Array[String] = []
	for code in [0x3142, 0x314F, 0x3134, 0x3161, 0x3139, 0x3131, 0x314F, 0x3139, 0x315C]:
		tiles.append(String.chr(code))
	var picked_set := AutoArrange.best_word_set_for(tiles, WordDatabase.get_all_words(), 1)
	check(not picked_set.is_empty(), "The reported case needs at least one buildable word")
	if picked_set.is_empty():
		return
	var picked := str(picked_set[0].get("word", ""))
	var needle: Dictionary = WordDatabase.get_word_data("바늘")
	var picked_value := AutoArrange.word_value(picked, WordDatabase.get_word_data(picked))
	var needle_value := AutoArrange.word_value("바늘", needle)
	check(picked != "가루",
		"The reported case: the hint must not target 가루 while the belt can build 바늘")
	check(picked_value >= needle_value,
		"The hint must not target a word weaker than one the belt can already build (picked %s = %d vs 바늘 = %d)"
			% [picked, picked_value, needle_value])


## 도감 카드가 보여 주는 숫자도 같은 식에서 나와야 한다.
##
## 도감은 '무엇을 노릴까' 를 정하는 화면이다. 여기 숫자가 실제 타워와 다르면
## 플레이어는 잘못된 단어를 목표로 삼는다 — 디렉터가 정확히 그렇게 잡았다.
func _test_lexicon_shows_the_real_tower_value() -> void:
	var lexicon = LexiconModalScene.instantiate()
	add_child(lexicon)
	# 발견 목록을 직접 채운다 — 세이브 상태에 기대면 테스트가 세이브에 따라 흔들린다.
	lexicon.discovered_words = ["가루", "바늘"]
	lexicon.render_cards()
	await get_tree().process_frame

	var shown := {}
	for label in lexicon.find_children("*", "Label", true, false):
		var text := (label as Label).text
		if not text.contains("\nDPS "):
			continue
		shown[str(text)] = true
	check(not shown.is_empty(), "The lexicon must render a damage number per card")
	# 카드에는 이름이 함께 그려지므로, 숫자가 실제 값과 같은지만 본다.
	for word in ["가루", "바늘"]:
		var stats: Dictionary = WordTowerScript.preview_stats(word, WordDatabase.get_word_data(word))
		var expected := "%.1f\nDPS %.1f" % [stats["per_hit"], stats["dps"]]
		check(shown.has(expected),
			"The lexicon must show %s's real value (expected '%s', shown %s)"
				% [word, expected, str(shown.keys())])
	lexicon.free()


## ── 형태의 결 (단어 모양의 네이티브 효과) ──────────────────────────────────

## 형태의 결은 **모든 단어**에 붙고, **작아야** 한다.
##
## 두 가지를 한 번에 잠근다:
##   (1) 라벨이 하나도 안 붙는 단어가 있으면 축이 조용히 사라진다.
##   (2) 크기 상한이 없으면 다음 사람이 배율 하나를 1.5 로 바꿔도 아무도 모른다.
##       난이도 게이트가 이미 '게임이 너무 쉽다' 로 실패 중이라 이 상한은 밸런스 계약이다.
##
## 상한의 근거는 실측이다(tools/WordShapeProbe.gd):
##   피해 1.0000(뇌) ~ 1.1340(닭) / 간격 0.9615(비기) ~ 1.0417(굿) / 사거리 1.0000(굿) ~ 1.0608(권)
func _test_shape_bonuses_are_small_and_always_present() -> void:
	var checked := 0
	var longest := 0
	var longest_label := ""
	for data in WordDatabase.get_all_words():
		var word := str(data.get("word", ""))
		if word == "":
			continue
		checked += 1
		var shape: Dictionary = WordSynergy.native_shape_bonuses(word)
		check(not shape["labels"].is_empty(),
			"Every word must carry at least one shape label — %s has none" % word)
		for label in shape["labels"]:
			var text := str(label)
			check(text.begins_with("결: "),
				"A shape label must be marked as the word's own shape, not a relic (%s on %s)"
					% [text, word])
			# 정보창 배지 행은 22자를 넘는 라벨을 **조용히 버린다**. 효과는 적용되는데
			# 화면에서 사라지므로, 길이를 여기서 잠근다.
			check(text.length() <= 22,
				"A shape label over 22 chars is dropped from the info modal (%d chars: '%s')"
					% [text.length(), text])
			if text.length() > longest:
				longest = text.length()
				longest_label = text
		check(float(shape["damage"]) >= 1.0 and float(shape["damage"]) <= 1.15,
			"%s: shape damage x%.4f is outside the small-bonus band" % [word, shape["damage"]])
		check(float(shape["interval"]) >= 0.95 and float(shape["interval"]) <= 1.05,
			"%s: shape interval x%.4f is outside the small-bonus band" % [word, shape["interval"]])
		check(float(shape["range"]) >= 1.0 and float(shape["range"]) <= 1.07,
			"%s: shape range x%.4f is outside the small-bonus band" % [word, shape["range"]])
	check(checked >= 300,
		"The shape contract must cover the database (checked %d, longest label %d '%s')"
			% [checked, longest, longest_label])


## 형태 특징 → 효과 매핑. 이 표가 곧 계약이다.
##
## 특히 **받침은 보너스가 아니라 무게** 다: 피해 +5%, 속도 -4%. 366개 중 289개(79%)가
## 받침을 가지므로, 여기에 순수 보너스를 주면 '선택' 이 아니라 상시 버프가 된다.
## 무게로 만들면 DPS 는 x1.008 로 사실상 그대로면서 단어마다 성격이 갈린다.
func _test_shape_bonus_matches_the_word_shape() -> void:
	var cases := {
		"바늘": {"damage": 1.05, "interval": 1.0 / 0.96, "range": 1.0,
			"labels": ["결: 받침 (피해+5%, 속도-4%)"]},
		"개": {"damage": 1.02, "interval": 1.0, "range": 1.02,
			"labels": ["결: 자모 균형 (피해·사거리+2%)"]},
		"뇌": {"damage": 1.0, "interval": 1.0, "range": 1.04,
			"labels": ["결: 겹모음 (사거리+4%)"]},
		"닭": {"damage": 1.05 * 1.08, "interval": 1.0 / 0.96, "range": 1.0,
			"labels": ["결: 받침 (피해+5%, 속도-4%)", "결: 겹받침 (피해+8%)"]},
		"가나": {"damage": 1.02, "interval": 1.0 / 1.04, "range": 1.02,
			"labels": ["결: 자모 균형 (피해·사거리+2%)", "결: 모음 반복 (속도+4%)"]},
	}
	for word in cases:
		var expected: Dictionary = cases[word]
		var shape: Dictionary = WordSynergy.native_shape_bonuses(word)
		check(is_equal_approx(float(shape["damage"]), float(expected["damage"])),
			"%s: shape damage x%.4f, expected x%.4f" % [word, shape["damage"], expected["damage"]])
		check(is_equal_approx(float(shape["interval"]), float(expected["interval"])),
			"%s: shape interval x%.4f, expected x%.4f" % [word, shape["interval"], expected["interval"]])
		check(is_equal_approx(float(shape["range"]), float(expected["range"])),
			"%s: shape range x%.4f, expected x%.4f" % [word, shape["range"], expected["range"]])
		check(shape["labels"] == expected["labels"],
			"%s: shape labels %s, expected %s" % [word, str(shape["labels"]), str(expected["labels"])])


## 받침은 '세고 느리다' — 순수 보너스가 아니다.
##
## 이 검사가 없으면 다음 사람이 간격 항을 지워도 스위트가 초록으로 남고,
## 그러면 79% 의 단어가 조용히 상시 버프를 받는다(그리고 난이도가 더 쉬워진다).
func _test_receiving_final_consonant_is_a_trade_off() -> void:
	var with_final: Dictionary = WordSynergy.native_shape_bonuses("바늘")
	var without_final: Dictionary = WordSynergy.native_shape_bonuses("개")
	check(float(with_final["damage"]) > 1.0,
		"받침 must make the hit heavier (damage > 1.0)")
	check(float(with_final["interval"]) > 1.0,
		"받침 must also make the tower slower (interval > 1.0) — that is its 무게")
	check(is_equal_approx(float(without_final["interval"]), 1.0),
		"A word without 받침 must not pay the 무게 penalty")


## 형태의 결은 **실제 타워**에 붙어야 하고, 도감·힌트가 쓰는 `preview_stats` 에도
## **같은 식**으로 들어가야 한다. 한쪽만 고치면 화면의 숫자가 다시 거짓말이 된다
## (`_test_preview_stats_matches_the_real_tower` 가 366개를 대조하는 이유와 같다).
func _test_shape_bonus_reaches_the_real_tower() -> void:
	var data: Dictionary = WordDatabase.get_word_data("바늘")
	check(not data.is_empty(), "The shape test needs 바늘 in the database")
	if data.is_empty():
		return
	var field = StubField.new()
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("바늘", data, field)
	var shape: Dictionary = WordSynergy.native_shape_bonuses("바늘")

	check(is_equal_approx(tower.damage_multiplier, float(shape["damage"])),
		"The real tower must apply the shape damage multiplier (got x%.4f, shape x%.4f)"
			% [tower.damage_multiplier, shape["damage"]])

	var level: int = clampi(tower.syllable.length(), 1, WordTowerScript.INTERVAL_MULT_BY_LENGTH.size())
	var bare: float = float(WordTowerScript.TRAIT_INTERVAL.get(tower.trait_id, 0.8)) \
		* float(WordTowerScript.INTERVAL_MULT_BY_LENGTH[level - 1])
	check(tower.attack_interval > bare,
		"바늘 has 받침 — the real tower must be slower than the bare trait interval")
	check(is_equal_approx(tower.attack_interval, bare * float(shape["interval"])),
		"The real tower's interval must include the shape exactly once")

	var stats: Dictionary = WordTowerScript.preview_stats("바늘", data)
	# 실제 발당 피해 = damage_per_attack() * damage_multiplier — 형태의 결은
	# damage_multiplier 쪽에 들어간다. preview per_hit 도 형태를 포함하므로 같은 값이다.
	check(is_equal_approx(float(stats["per_hit"]), tower.damage_per_attack() * tower.damage_multiplier),
		"preview per_hit must include the shape, or the lexicon lies about 바늘")
	check(is_equal_approx(float(stats["interval"]), tower.attack_interval),
		"preview interval must include the shape")

	tower.free()
	field.free()


## 형태의 결은 **보여야** 한다. 로직만 있고 화면에 없으면 없는 것과 같다 —
## 이번 작업의 요점이 정확히 '로직은 있는데 표현이 없던 것' 을 채우는 것이다.
func _test_shape_bonus_is_stated_on_the_tooltip_and_the_modal() -> void:
	var field = DefenseFieldScript.new()
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true}, field)
	var shape: Dictionary = WordSynergy.native_shape_bonuses("가나")
	check(shape["labels"].size() >= 1, "The test word must actually have a word shape")
	for label in shape["labels"]:
		check(tower.synergy_labels.has(label),
			"The tower must carry the shape label '%s' (has %s)" % [label, str(tower.synergy_labels)])

	tower.btn_select.mouse_entered.emit()
	for label in shape["labels"]:
		check(tower.btn_select.tooltip_text.contains(str(label)),
			"The tooltip must state the word shape ('%s')" % label)

	# 정보창 배지 행 — 22자를 넘으면 **조용히 사라진다**. 그래서 실제로 붙었는지 본다.
	var modal = TowerInfoScene.instantiate()
	add_child(modal)
	modal.setup(tower.word_data, tower.syllable, tower.attack_range, tower.attack_interval,
		tower.synergy_labels, -1.0, "", -1.0, {}, tower)
	var badges: Array = []
	for child in modal.synergy_row.get_children():
		for lbl in child.find_children("*", "Label", true, false):
			badges.append(str((lbl as Label).text))
	var joined := " ".join(badges)
	for label in shape["labels"]:
		check(joined.contains(str(label)),
			"The info modal must render the shape as a badge ('%s'); rendered: %s"
				% [label, joined])

	modal.free()
	tower.free()
	field.free()
