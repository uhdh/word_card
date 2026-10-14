extends Node

const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const ShopModalScript = preload("res://scripts/ui/ShopModal.gd")
const TowerInfoModalScript = preload("res://scripts/ui/TowerInfoModal.gd")
const NumTextScript = preload("res://scripts/ui/NumText.gd")
const ShopModalScene = preload("res://scenes/tower/ShopModal.tscn")
const DefenseFieldScene = preload("res://scenes/tower/DefenseField.tscn")
const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")
const Palette = preload("res://scripts/ui/Palette.gd")
const Juice = preload("res://scripts/ui/Juice.gd")
const MainScene = preload("res://scenes/TowerDefenseMain.tscn")


## 한 런(3막 60웨이브) 전체 골드 수입의 상한/하한.
## 소비처는 타일(누진 10G부터, 30장이면 735G) + 유물(25~40G, 실사용 약 300G) ≈ 1,035G.
## 수입이 이보다 크게 앞서면 후반에 쓸 곳 없이 골드만 쌓인다 (tools/EconomyProbe 실측).
const GOLD_BUDGET := 1150
const GOLD_FLOOR := 950

## 기본 타워 배치의 커버리지 하한(경로 대비). 최적에서 안전 마진을 뺀 값이다.
##   1막 경로 1329.7px: 최적 [5,1,8]  = 84.0% → 하한 80%
##   2막 경로 1215.0px: 최적 [10,5,1] = 92.6% → 하한 88%
##   3막 경로  966.1px: 최적 [2,6,9]  = 88.1% → 하한 84%
## 참고: 예전 고정 배치 [0,1,2] 의 실제 커버리지(합집합)는 31.1% / 39.0% / 42.6% 였다.
## (개별 커버리지를 더하면 겹친 구간이 두 번 세어져 값이 부풀려진다 — 합집합으로 잴 것)
const DEFAULT_COVERAGE_FLOOR := {1: 0.80, 2: 0.88, 3: 0.84}

## 기본 배치가 '고정 [0,1,2]' 대비 최소 몇 배를 덮어야 하는가.
## 실측 배율: 2.70x / 2.35x / 2.04x. 3막이 가장 빡빡하다 —
## 3막 발판 3개가 이미 중앙에 몰려 있어 [0,1,2] 도 나쁘지 않기 때문.
const DEFAULT_COVERAGE_MULTIPLE := 1.8

var failures := 0

## `_make_tower` 가 만든 스텁 필드들. **바로 free 하면 안 된다.**
##
## `WordTower` 는 `field_ref` 를 setup 이후에도 읽는다(예: `first_strike_multiplier()` —
## '지금 이 타워가 때리면 몇 배인가' 는 공격 시점에 묻는 질문이다). Godot 은 Node 를
## free 하면 그 참조를 null 로 만들므로, 즉시 free 하면 **setup 이후의 모든 질문이
## 조용히 '유물 없음'** 이 된다. setup 시점에 계산되는 값만 보던 기존 테스트들은
## 그 사실을 알 수 없었다.
## 테스트가 끝날 때 한꺼번에 free 한다.
var _stub_fields: Array = []


func _ready() -> void:
	_test_wave_compositions()
	_test_round_starts_on_timer_with_pending_monsters()
	_test_enemy_limit_allows_late_act_pressure()
	_test_enemy_hp_progression()
	_test_gold_income()
	_test_enemy_count_keeps_wave_hp()
	_test_tower_damage_ranking()
	_test_tower_info_shows_damage_share()
	_test_enemy_shield()
	# 이 검사는 프레임을 기다린다(`await get_tree().process_frame`). `await` 없이 부르면
	# 나머지 절반이 **`_ready` 가 끝난 뒤 임의의 시점에** 실행된다 — 그때는 다른 테스트가
	# 만든 피해 숫자까지 세게 되어 "정확히 1개" 가 엉뚱한 값으로 실패한다.
	# 실제로 이 상태로 통과하고 있었다: 타이밍이 우연히 맞았을 뿐이다.
	# (다른 검사를 하나 추가하자마자 `got 5` 로 깨져서 드러났다)
	await _test_absorbed_hits_are_not_reported_as_normal_damage()
	_test_relic_descriptions_state_exactly_what_the_code_does()
	_test_word_shape_relics_honour_the_percent_in_their_text()
	_test_wave_heal_relic_heals_exactly_what_its_text_says()
	_test_relic_icons_are_unique()
	_test_shop_sells_relics_only()
	_test_no_relic_survives_without_its_effect()
	_test_every_shop_relic_has_an_effect()
	_test_trait_relics_boost_only_their_own_trait()
	_test_orbit_direction_changes_how_often_it_hits()
	_test_orbit_keeps_hitting_and_rewards_longer_words()
	_test_burn_oil_extends_total_burn_damage()
	_test_burn_shows_a_persistent_indicator()
	_test_state_chips_share_one_row()
	_test_synergy_is_visible_on_the_tower_tooltip()
	_test_tower_pair_synergies_reward_matching_forms()
	_test_enemy_path_follows_road_center()
	_test_tower_slots_follow_marked_map_positions()
	_test_act_switch_swaps_map_art()
	_test_three_slots_start_unlocked()
	_test_towers_keep_assigned_slot_positions()
	_test_towers_can_move_and_swap_positions()
	_test_tower_drag_moves_and_click_still_works()
	_test_reset_clears_live_combat_nodes()
	_test_enemy_trait_counters()
	_test_each_act_has_its_own_monster_roster()
	_test_monster_attributes_change_the_counter()
	_test_regen_undoes_sustained_damage()
	_test_splitter_spawns_children_without_gold()
	_test_enemy_shows_its_attribute_badge()
	_test_type_counters_are_named()
	_test_boss_entrance_is_visible_and_lethal()
	_test_enemy_decorations_stay_outside_the_sprite()
	_test_next_round_preview_and_physical_adjacency()
	_test_act_cleared_reports_the_cleared_act_to_late_listeners()
	_test_enemies_damage_the_base_on_arrival()
	_test_default_tower_placement_covers_the_route()
	# 이 검사는 MainScene 을 세우고 프레임을 기다린다 — `await` 없이 부르면 나머지가
	# `_ready` 가 끝난 뒤로 밀려서 결과 줄이 이미 찍힌 다음에 실패할 수 있다.
	# 그래서 마지막에 두고 반드시 await 한다.
	await _test_flat_relics_honour_the_number_in_their_text()
	for field in _stub_fields:
		if is_instance_valid(field):
			field.free()
	_stub_fields.clear()
	_test_no_nodes_are_left_behind()
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
	check(DefenseFieldScript.MAX_WAVES_PER_ACT == 20, "Each act must contain twenty rounds")
	check(is_equal_approx(DefenseFieldScript.ROUND_INTERVAL, 15.0), "Rounds must start every 15 seconds")
	var act_wave_one: Dictionary = {}
	for act in range(1, 4):
		var previous_regulars := -1
		for wave in range(1, 21):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			var bosses = field.spawn_queue.filter(func(enemy): return enemy.get("type") == "boss")
			# 보스는 5라운드마다 정확히 한 마리만.
			check(bosses.size() == (1 if wave % 5 == 0 else 0),
				"Act %d round %d boss placement is wrong" % [act, wave])
			var regulars: int = field.spawn_queue.size() - bosses.size()
			# 웨이브가 진행될수록 물량이 줄어들면 안 된다 (난이도 곡선 단조 증가).
			check(regulars >= previous_regulars,
				"Act %d round %d must not send fewer monsters than round %d" % [act, wave, wave - 1])
			previous_regulars = regulars
			if wave == 1:
				act_wave_one[act] = regulars
		# 물량이 50마리 상한을 넘으면 웨이브가 즉시 붕괴한다.
		check(field.spawn_queue.size() <= DefenseFieldScript.MAX_ENEMIES,
			"Act %d round 20 must stay under the enemy cap" % act)
	# 뒤 막일수록 같은 라운드에서 더 많이 몰려온다.
	check(act_wave_one[2] > act_wave_one[1] and act_wave_one[3] > act_wave_one[2],
		"Later acts must send more monsters on the same round")
	check(_has_type(field, 1, "fast"), "Act 1 needs a fast enemy")
	check(_has_type(field, 1, "armored"), "Act 1 needs an armored enemy")
	field.free()


func _test_round_starts_on_timer_with_pending_monsters() -> void:
	var field = DefenseFieldScript.new()
	var rewarded_round := [0]
	field.wave_cleared.connect(func(_act, round_number, _gold): rewarded_round[0] = round_number)
	field.is_wave_running = true
	field.current_wave = 1
	field.spawn_queue = [{"pending": true}]
	field._process(field.ROUND_INTERVAL)
	check(field.current_wave == 1 and field.is_planning_phase, "A planning phase must open between rounds")
	check(rewarded_round[0] == 1, "The completed timed round must grant its reward")
	field._process(field.PLANNING_INTERVAL)
	check(field.current_wave == 2 and field.spawn_queue.size() > 1, "The next round must start after planning while monsters are pending")
	field.free()


func _test_enemy_limit_allows_late_act_pressure() -> void:
	check(DefenseFieldScript.MAX_ENEMIES == 50, "Enemy limit must be 50")


func _test_reset_clears_live_combat_nodes() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field._spawn_enemy({"name": "test", "hp": 10.0, "speed": 0.0, "gold": 0, "icon": ""})
	field.spawn_queue.append({"pending": true})
	field.is_wave_running = true
	var enemy = field.get_enemies()[0]
	field.reset_combat_state()
	check(enemy.is_queued_for_deletion(), "New game must remove existing monsters")
	check(field.spawn_queue.is_empty() and not field.is_wave_running, "New game must clear pending spawns")
	field.free()


func _test_enemy_trait_counters() -> void:
	var enemy = EnemyUnitScript.new()
	enemy.enemy_type = "armored"
	check(enemy.damage_multiplier_for("pierce") > 1.0 and enemy.damage_multiplier_for("rapid") < 1.0, "Armored enemies must reward piercing and resist rapid fire")
	enemy.enemy_type = "swarm"
	check(enemy.damage_multiplier_for("splash") > 1.0 and enemy.damage_multiplier_for("sniper") < 1.0, "Swarm enemies must reward area damage and resist sniping")
	enemy.free()


## 막이 바뀌면 '새로운 몬스터' 가 나와야 한다.
## 예전에는 네 종류가 세 막에 그대로 나오고 이름만 "1막/2막/3막 침략자" 로 바뀌었다.
func _test_each_act_has_its_own_monster_roster() -> void:
	var seen_names := {}
	var seen_icons := {}
	for act in range(1, 4):
		var roster := MonsterRoster.entries_for(act)
		check(roster.size() >= 4, "Act %d needs at least four monster kinds" % act)
		# 어느 막에서든 타입 상성이 의미를 가지려면 네 타입이 다 있어야 한다.
		for type_id in ["normal", "fast", "armored", "swarm"]:
			check(MonsterRoster.types_for(act).has(type_id),
				"Act %d roster must include a %s monster" % [act, type_id])
		for entry in roster:
			var name := str(entry["name"])
			var icon := str(entry["icon"])
			check(not seen_names.has(name), "'%s' must not appear in two acts" % name)
			check(not seen_icons.has(icon), "'%s' must not be reused in another act" % icon)
			seen_names[name] = act
			seen_icons[icon] = act
			check(ResourceLoader.exists(MonsterRoster.icon_path(icon)),
				"Act %d monster '%s' must have real art" % [act, name])
	# 보스도 막마다 달라야 한다 (적어도 1막과 뒤 막은 다르다).
	check(MonsterRoster.BOSS_ICONS[1] != MonsterRoster.BOSS_ICONS[2],
		"Act 2 must introduce a new boss instead of reusing the act 1 golem")

	# 미리보기가 그 막의 명단을 실제로 보여줘야 한다 — 안 그러면 플레이어는 알 방법이 없다.
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.current_act = 1
	field.current_wave = 0
	check(field.next_round_preview().contains("낱자 슬라임"), "Preview must name the act's monsters")
	field.current_act = 2
	field.current_wave = 0
	var act2: String = field.next_round_preview()
	check(act2.contains("갱도 거미") and not act2.contains("낱자 슬라임"),
		"Switching acts must swap the previewed roster")
	field.free()


## 속성이 '무엇으로 때려야 하는지' 를 실제로 바꾸는지.
## 이 테스트가 깨지면 속성이 이름만 붙고 동작은 그대로인 것이다.
func _test_monster_attributes_change_the_counter() -> void:
	var regen = EnemyUnitScript.new()
	regen.init_enemy("재생", 100.0, 50.0, 1, "")
	regen.apply_attrs(["regen"])
	check(regen.regen_per_sec > 0.0, "The regen attribute must actually regenerate")
	check(regen.damage_multiplier_for("sniper") > 1.0,
		"Regenerating monsters must be punished by burst damage")
	check(regen.damage_multiplier_for("damage_over_time") < 1.0,
		"Regenerating monsters must shrug off damage over time")
	check(regen.damage_multiplier_for("rapid") < 1.0,
		"Regenerating monsters must out-heal rapid fire")
	regen.free()

	var splitter = EnemyUnitScript.new()
	splitter.init_enemy("분열", 100.0, 50.0, 1, "")
	splitter.apply_attrs(["splitter"])
	check(splitter.split_into >= 2, "The splitter attribute must split into children")
	check(splitter.damage_multiplier_for("splash") > 1.0,
		"Splitters must be punished by area damage")
	check(splitter.damage_multiplier_for("sniper") < 1.0,
		"Splitters must waste single-target sniping")
	splitter.free()

	var swift = EnemyUnitScript.new()
	swift.init_enemy("질주", 100.0, 50.0, 1, "")
	swift.apply_attrs(["swift"])
	swift.apply_slow(0.5, 3.0)
	check(is_equal_approx(swift.slow_factor, 1.0) and is_equal_approx(swift.slow_timer, 0.0),
		"The swift attribute must ignore slows entirely")
	check(swift.damage_multiplier_for("control") < 1.0,
		"Control towers must be wasted on swift monsters")
	# 감속 면역이 없는 적은 그대로 감속돼야 한다 (속성이 진짜 원인인지 확인).
	var plain = EnemyUnitScript.new()
	plain.init_enemy("보통", 100.0, 50.0, 1, "")
	plain.apply_slow(0.5, 3.0)
	check(plain.slow_factor < 1.0, "Slows must still work on monsters without the swift attribute")
	plain.free()
	swift.free()

	var warded = EnemyUnitScript.new()
	warded.init_enemy("결계", 100.0, 50.0, 1, "")
	warded.apply_attrs(["warded:control"])
	check(warded.damage_multiplier_for("control") < 0.5,
		"A warded monster must nearly block the trait it wards")
	check(is_equal_approx(warded.damage_multiplier_for("splash"), 1.0),
		"A warded monster must take normal damage from everything else")
	check(warded.attrs_label().contains("결계"), "Warded monsters must describe what they block")
	warded.free()

	# 속성이 없으면 예전과 완전히 같아야 한다 (회귀 없음).
	var vanilla = EnemyUnitScript.new()
	vanilla.init_enemy("평범", 100.0, 50.0, 1, "")
	vanilla.enemy_type = "armored"
	check(is_equal_approx(vanilla.damage_multiplier_for("pierce"), 1.6),
		"An attribute-free armored monster must keep its old multiplier")
	check(is_equal_approx(vanilla.damage_multiplier_for("rapid"), 0.65),
		"An attribute-free armored monster must keep its old weakness")
	vanilla.free()


## 재생은 지속 피해를 '되돌린다' — 이게 성립해야 저격으로 잡아야 할 이유가 생긴다.
func _test_regen_undoes_sustained_damage() -> void:
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("재생", 100.0, 0.0, 1, "")
	enemy.apply_attrs(["regen"])
	enemy.take_damage(30.0, false)
	var after_hit: float = enemy.hp
	check(is_equal_approx(after_hit, 70.0), "The hit must land before regen is measured")
	# 1초 분량을 여러 번 나눠 틱한다 (프레임당 회복이 누적되는지).
	for i in range(10):
		enemy._process(0.1)
	check(enemy.hp > after_hit, "Regenerating monsters must heal back over time")
	# 상한을 넘겨 회복하면 안 된다.
	enemy.hp = enemy.max_hp
	enemy._process(1.0)
	check(enemy.hp <= enemy.max_hp, "Regen must never exceed max HP")
	enemy.free()


## 분열: 죽은 자리에서 자식이 즉시 나오고, 골드를 파밍 수단으로 만들면 안 된다.
func _test_splitter_spawns_children_without_gold() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.gold = 0
	field._spawn_enemy({
		"name": "갱도 거미", "type": "swarm", "hp": 60.0, "shield": 0.0,
		"speed": 100.0, "gold": 1, "icon": "", "attrs": ["splitter"], "base_damage": 1,
	})
	var spawned: Array = field.get_enemies()
	check(spawned.size() == 1, "A splitter must spawn as a single monster first")
	if spawned.is_empty():
		field.free()
		return
	var parent = spawned[0]
	check(parent.split_into >= 2, "The spawned splitter must carry its split count")
	var progress_before: float = parent.progress
	parent.take_damage(99999.0, false)

	var children: Array = field.get_enemies()
	check(children.size() == parent.split_into,
		"A dying splitter must leave exactly %d children (got %d)" % [parent.split_into, children.size()])
	for child in children:
		check(not child.attrs.has("splitter"),
			"Children must lose the splitter attribute so splitting cannot chain forever")
		check(child.gold_reward == 0, "Split children must not pay gold")
		check(absf(float(child.progress) - progress_before) <= 12.0,
			"Children must appear where their parent died, not back at the spawn gate")
	# 골드는 부모 몫만 들어와야 한다.
	check(field.gold == 1, "Splitting must not multiply the gold reward (got %d)" % field.gold)
	field.free()


## 적이 속성·타입을 가지면 머리 위에 배지가 보여야 한다 — 안 보이면 플레이어가
## '뭘로 때려야 하는지' 알 수 없다.
##
## 예전에는 속성 첫 번째 것만 배지로 떴고(루프가 첫 일치에서 return) 타입은 아예
## 안 떴다. '중갑 + 재생' 인 적은 재생만 보였고, 정작 그 적을 무엇으로 때려야
## 하는지를 정하는 타입 상성은 화면 어디에도 없었다.
func _test_enemy_shows_its_attribute_badge() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	# 각 속성별로 하나씩 세워 본다.
	# queue_free() 는 지연되므로 매번 get_enemies()[0] 을 쓰면 유령이 섞인다.
	# _spawn_enemy 의 반환값(없음) 대신 spawn 직후의 전체 목록에서
	# '아직 삭제 대기가 아닌' 마지막 원소를 고른다.
	var cases := [
		{"type": "normal", "attrs": ["regen"],    "want": ["재생"]},
		{"type": "normal", "attrs": ["splitter"], "want": ["분열"]},
		{"type": "normal", "attrs": ["swift"],    "want": ["질주"]},
		{"type": "normal", "attrs": ["warded:control"], "want": ["결계(둔화)"]},
		# 타입도 배지로 뜬다. 일반은 소음이라 일부러 붙이지 않는다.
		{"type": "armored", "attrs": [],        "want": ["중갑"]},
		{"type": "swarm",   "attrs": [],        "want": ["군집"]},
		{"type": "fast",    "attrs": ["swift"], "want": ["질풍", "질주"]},
		{"type": "armored", "attrs": ["regen"], "want": ["중갑", "재생"]},
	]
	for case in cases:
		field._spawn_enemy({
			"name": "배지 테스트", "type": case["type"], "hp": 10.0, "shield": 0.0,
			"speed": 50.0, "gold": 0, "icon": "", "attrs": case["attrs"], "base_damage": 1,
		})
		var enemies: Array = field.get_enemies().filter(func(e): return not e.is_queued_for_deletion())
		check(not enemies.is_empty(), "spawn must succeed for %s %s" % [case["type"], str(case["attrs"])])
		if enemies.is_empty():
			continue
		var enemy: EnemyUnit = enemies[-1]
		var got: Array = _badge_texts(enemy)
		check(got == case["want"],
			"badge row must read %s for %s %s (got %s)"
				% [str(case["want"]), case["type"], str(case["attrs"]), str(got)])
		if got.is_empty():
			continue
		# 두 축은 색이 아니라 '형태' 로 구분한다. 질풍(타입)과 질주(속성)는 표에서 같은
		# 주황이라, 둘 다 칠하면 똑같은 주황 블록 두 개가 나란히 떠서 어느 쪽이 타입
		# 상성인지 알 수 없다. 타입 = 꽉 채움, 속성 = 테두리.
		var has_type := MonsterRoster.type_label(case["type"]) != ""
		var type_sb := _badge_style(enemy, 0) if has_type else null
		if type_sb != null:
			check(type_sb.border_width_top == 0, "type badges must be solid fills, not outlines")
			check(type_sb.bg_color.is_equal_approx(MonsterRoster.type_color(case["type"])),
				"type badge must use the type table's color (got %s)" % str(type_sb.bg_color))
		var attr_index := 1 if has_type else 0
		if attr_index < got.size():
			var attr_sb := _badge_style(enemy, attr_index)
			check(attr_sb != null and attr_sb.border_width_top > 0,
				"attr badges must be outlined so the axis stays readable (%s)" % str(case["attrs"]))
			if attr_sb != null:
				check(attr_sb.border_color.is_equal_approx(MonsterRoster.attr_color(str(case["attrs"][0]))),
					"attr badge must use the attr table's color (got %s)" % str(attr_sb.border_color))
	# 타입도 속성도 없으면 배지 줄 자체를 만들지 않는다.
	field._spawn_enemy({
		"name": "평범", "type": "normal", "hp": 10.0, "shield": 0.0,
		"speed": 50.0, "gold": 0, "icon": "", "attrs": [], "base_damage": 1,
	})
	var plain = field.get_enemies().filter(func(e): return not e.is_queued_for_deletion())
	if not plain.is_empty():
		check(plain[-1]._badge_row == null,
			"an enemy with no type and no attrs must not have a badge row")
	field.free()


## 적 머리에 실제로 그려진 배지 문구들(왼쪽부터). 배지가 없으면 빈 배열.
func _badge_texts(enemy: EnemyUnit) -> Array:
	if enemy._badge_row == null:
		return []
	var row := enemy._badge_row.get_child(0) as HBoxContainer
	if row == null:
		return []
	var out: Array = []
	for badge in row.get_children():
		out.append((badge as Label).text)
	return out


## n번째 배지의 배경 스타일. 없으면 null.
func _badge_style(enemy: EnemyUnit, index: int) -> StyleBoxFlat:
	var row := enemy._badge_row.get_child(0) as HBoxContainer
	if row == null or index >= row.get_child_count():
		return null
	var sb = (row.get_child(index) as Label).get_theme_stylebox("normal")
	return sb if sb is StyleBoxFlat else null


## 상성은 타입(중갑/군집/질풍)과 속성(재생/분열/질주) 두 축의 곱이다.
## 그런데 화면에는 속성만 있었다 — 타입 상성을 배울 곳이 인트로 문구밖에 없었다.
func _test_type_counters_are_named() -> void:
	for act in range(1, 4):
		var text := MonsterRoster.counters_text(act)
		for type_id in MonsterRoster.types_for(act):
			var want := MonsterRoster.type_label(str(type_id))
			if want == "":
				continue
			check(text.contains(want + "▸"),
				"Act %d preview must name the %s counter (got '%s')" % [act, want, text])
	# 문구는 표에서 나온다 — 표에 약점으로 적힌 특성이 하나도 빠지면 안 된다.
	for type_id in MonsterRoster.TYPE_MULTIPLIERS:
		var line := MonsterRoster.type_counter_text(str(type_id))
		for trait_id in MonsterRoster.TYPE_MULTIPLIERS[type_id]:
			if float(MonsterRoster.TYPE_MULTIPLIERS[type_id][trait_id]) < MonsterRoster.COUNTER_WEAK_MULT:
				continue
			var trait_name := str(WordTower.TRAIT_NAMES.get(str(trait_id), str(trait_id)))
			check(line.contains(trait_name),
				"%s counter text must list '%s' (got '%s')" % [str(type_id), trait_name, line])
	# 판정이 표를 그대로 읽는지: 표의 값과 함수의 결과가 어긋나면 화면이 거짓말을 한다.
	var armored = EnemyUnitScript.new()
	armored.enemy_type = "armored"
	for trait_id in MonsterRoster.TYPE_MULTIPLIERS["armored"]:
		check(is_equal_approx(armored.damage_multiplier_for(str(trait_id)),
			float(MonsterRoster.TYPE_MULTIPLIERS["armored"][trait_id])),
			"Armored %s multiplier must come from TYPE_MULTIPLIERS" % str(trait_id))
	armored.free()
	# 일반은 배지도 문구도 만들지 않는다 — 대부분의 적이 일반이라 소음이 된다.
	check(MonsterRoster.type_label("normal") == "" and MonsterRoster.type_counter_text("normal") == "",
		"The normal type must stay silent in both badge and preview")


## 보스전: 보스가 '등장' 했다는 것이 화면에 보여야 하고, 놓치면 더 아파야 한다.
func _test_boss_entrance_is_visible_and_lethal() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.spawn_queue.clear()
	field._build_wave_monsters(1, 5)
	var boss_data = field.spawn_queue.filter(func(e): return e.get("type") == "boss")
	check(boss_data.size() == 1, "Round 5 must send exactly one boss")
	if boss_data.is_empty():
		field.free()
		return
	check(int(boss_data[0].get("base_damage", 1)) == MonsterRoster.BOSS_BASE_DAMAGE,
		"Bosses must hurt the base more than regular monsters")
	check(MonsterRoster.BOSS_BASE_DAMAGE > 1, "A boss leak must cost more than one base HP")

	field._spawn_enemy(boss_data[0])
	var spawned: Array = field.get_enemies()
	check(spawned.size() == 1, "The boss must actually enter the field")
	if spawned.is_empty():
		field.free()
		return
	var boss = spawned[0]
	# 1) 실루엣이 커야 잡몹과 구분된다.
	check(boss.sprite.scale.x > 1.0,
		"A boss must be visibly bigger than a regular monster (got %.2f)" % boss.sprite.scale.x)
	# 2) 등장 배너 (이름 + 약점)
	var banner = field.get_node_or_null("BossBanner")
	check(banner != null, "A boss must announce itself with an on-screen banner")
	if banner != null:
		var text := ""
		for label in banner.get_children():
			if label is Label:
				text += label.text + " "
		check(text.contains(boss.enemy_name), "The boss banner must name the boss")
		check(text.contains("약점"), "The boss banner must reveal its weakness")
	# 3) 전용 체력바
	check(field._boss_bar != null, "A boss must get a dedicated health bar")
	if field._boss_bar != null:
		var bar = field._boss_bar.get_node_or_null("BossColumn/BossHp")
		check(bar != null, "The boss health bar must be wired up")
		if bar != null:
			check(is_equal_approx(float(bar.max_value), boss.max_hp + boss.max_shield),
				"The boss bar must show the boss's full health")
			boss.take_damage(boss.max_hp * 0.5, false)
			# 보스 바는 이제 즉시 튀지 않고 따라간다(_process 가 매 프레임 갱신).
			# 그래서 한 번의 호출로는 목표에 도달하지 않는다 — '한 프레임에 점프하지
			# 않는 것' 자체가 지켜야 할 계약이므로, 그것을 여기서 검사한다.
			# (예전에는 이 테스트가 인자 없는 _update_boss_bar() 를 불렀고, 시그니처가
			#  delta 를 받도록 바뀐 뒤로는 SCRIPT ERROR 만 찍고 조용히 통과했다.)
			var bar_before := float(bar.value)
			field._update_boss_bar(1.0 / 60.0)
			check(float(bar.value) < bar_before, "The boss bar must react to damage")
			check(float(bar.value) > float(bar.max_value) * 0.75,
				"The boss bar must ease toward the target, not snap in a single frame")
			for _i in range(180):
				field._update_boss_bar(1.0 / 60.0)
			check(is_equal_approx(float(bar.value), boss.hp + boss.shield),
				"The boss bar must converge to the boss's health (got %.1f, want %.1f)" % [
					float(bar.value), boss.hp + boss.shield])

	# 4) 보스가 죽으면 체력바가 즉시 사라져야 한다.
	boss.take_damage(999999.0, false)
	field._update_boss_bar(1.0 / 60.0)
	check(field._boss_target == null and field._boss_bar == null,
		"A dead boss must not leave its health bar on screen")
	field.free()


## 적이 커져도 장식(체력바·배지·상태 칩)이 몸통을 침범하지 않아야 한다.
##
## 스프라이트 상자를 키우거나 보스 배율을 바꾸면 장식 좌표가 낡는다. 그런데 그 사실은
## **화면을 봐야만** 알 수 있다 — 체력바가 몸에 파묻히고 상태 칩이 발밑에 붙는데,
## 경고도 오류도 나지 않는다. 실제로 이 게임은 36px 상자를 전제로 한 좌표를 씬과
## 스크립트 두 곳에 각각 박아 두고 있었다.
##
## 그래서 여기서는 **좌표값이 아니라 관계**를 잠근다: "장식은 항상 스프라이트 바깥".
## 크기를 더 키우는 것은 자유롭게 하되, 침범은 못 하게 한다.
func _test_enemy_decorations_stay_outside_the_sprite() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	# 잡몹: 타입 배지 + 속성 배지 + 상태 칩을 전부 만들어 세 줄을 다 세운다.
	# 아트를 실제 경로로 준다 — 그림의 빈 여백까지 반영해야 의미가 있다.
	field._spawn_enemy({
		"name": "크기 테스트", "type": "armored", "hp": 10.0, "shield": 0.0, "speed": 50.0,
		"gold": 0, "icon": MonsterRoster.icon_path("monster_slime_1_32px_pastel.png"),
		"attrs": ["regen"], "base_damage": 1,
	})
	var mobs: Array = field.get_enemies().filter(func(e): return not e.is_queued_for_deletion())
	check(not mobs.is_empty(), "the size test needs a spawned monster")
	if not mobs.is_empty():
		var mob: EnemyUnit = mobs[-1]
		# 상태 칩 줄은 상태가 생길 때 만들어진다 — 실제 입구로 만들어야 줄이 존재한다.
		mob.apply_burn(1.0, 5.0)
		_check_decorations_clear(mob, "monster")
	# 보스: 배율이 다르다. 배율이 바뀔 때 레이아웃을 다시 잡지 않으면 **여기서만** 깨진다.
	field._spawn_enemy(MonsterRoster.boss_entry(1, 5, 30.0, 1.0, 1.0, 5))
	var bosses: Array = field.get_enemies().filter(
		func(e): return not e.is_queued_for_deletion() and e.enemy_type == "boss")
	check(not bosses.is_empty(), "the size test needs a spawned boss")
	if not bosses.is_empty():
		var boss: EnemyUnit = bosses[-1]
		check(boss.sprite.scale.y > 1.0, "the boss must be scaled up for this check to mean anything")
		_check_decorations_clear(boss, "boss")
	field.free()


## 스프라이트가 화면에서 실제로 차지하는 세로 범위(중심 기준, 위·아래).
##
## **idle + 걸음 프레임을 모두 합쳐서 잰다.** 걸음 프레임은 idle 보다 아래로 더 뻗으므로
## (실측: 보스 +3px), idle 만 보면 걷는 동안 칩이 발을 밟는 것을 못 잡는다.
##
## **그림에서 직접 잰다** — EnemyUnit 이 들고 있는 비율을 그대로 쓰면 그 비율이 틀렸을 때
## 검사도 같이 틀린다(구현을 베낀 검사는 아무것도 못 잡는다).
func _art_extent(enemy: EnemyUnit) -> Vector2:
	var half: float = enemy.sprite.custom_minimum_size.x * 0.5 * absf(enemy.sprite.scale.y)
	var top := 1.0
	var bottom := 0.0
	var measured := false
	var frames: Array = [enemy.sprite.texture]
	frames.append_array(enemy._walk_frames)
	for tex in frames:
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null or img.get_height() <= 0:
			continue
		var used: Rect2i = img.get_used_rect()
		if used.size.y <= 0:
			continue
		var h := float(img.get_height())
		top = minf(top, float(used.position.y) / h)
		bottom = maxf(bottom, float(used.position.y + used.size.y) / h)
		measured = true
	if not measured:
		return Vector2(-half, half)
	return Vector2(-half + top * half * 2.0, -half + bottom * half * 2.0)


## 장식 하나하나가 **보이는 그림** 바깥에 있는지. who 는 실패 문구에만 쓴다.
##
## 핵심은 배율이 다른 보스다. 보스는 sprite.scale 로 커지므로, 배율이 바뀔 때 레이아웃을
## 다시 잡지 않으면 장식만 예전 자리에 남아 몸통에 파묻힌다.
func _check_decorations_clear(enemy: EnemyUnit, who: String) -> void:
	if enemy.sprite == null:
		check(false, "a %s needs a sprite to size its decorations against" % who)
		return
	check(enemy.sprite.texture != null,
		"the %s needs real art for this check to mean anything" % who)
	var ext := _art_extent(enemy)
	check(ext.y - ext.x > 1.0,
		"the %s must actually draw something (art spans %.1f..%.1f)" % [who, ext.x, ext.y])
	if enemy.hp_bar != null:
		check(float(enemy.hp_bar.offset_bottom) <= ext.x,
			("the %s health bar must sit above the art, not on its body "
				+ "(bar bottom %.1f, art top %.1f)") % [who, float(enemy.hp_bar.offset_bottom), ext.x])
		check(float(enemy.hp_bar.offset_top) < float(enemy.hp_bar.offset_bottom),
			"the %s health bar must have a height" % who)
	if enemy._badge_row != null:
		check(enemy._badge_row.position.y + EnemyUnit.BADGE_ROW_HEIGHT <= float(enemy.hp_bar.offset_top),
			"the %s badge row must stack above the health bar" % who)
	if enemy._state_wrapper != null:
		check(enemy._state_wrapper.position.y >= ext.y,
			("the %s state chips must sit below the art, not on its feet "
				+ "(chips %.1f, art bottom %.1f)") % [who, enemy._state_wrapper.position.y, ext.y])


func _test_next_round_preview_and_physical_adjacency() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.current_wave = 4
	check(field.next_round_preview().contains("보스") and field.next_round_preview().contains("약점"), "Boss preview must reveal its weakness")
	field.update_towers_from_parsed_list([
		{"syllable": "불", "word_data": {"category": "element", "is_unknown": true}},
		{"syllable": "물", "word_data": {"category": "element", "is_unknown": true}}
	])
	# 인접(시너지) 판정은 두 타워의 실제 거리로 결정된다.
	field.active_towers[1].global_position = field.active_towers[0].global_position + Vector2(40, 0)
	check(field.towers_are_adjacent(field.active_towers[0], field.active_towers[1]), "Nearby towers must count as adjacent")
	field.active_towers[1].global_position = field.active_towers[0].global_position + Vector2(300, 0)
	check(not field.towers_are_adjacent(field.active_towers[0], field.active_towers[1]), "Distant towers must not be adjacent")
	field.free()


## 시그널 인자는 emit 시점에 스냅샷되지 않는다 (Godot 4.7.2 실측).
## 멤버 변수를 그대로 넘기면 핸들러마다 그 값을 다시 읽기 때문에, 앞선 핸들러가
## 그 멤버를 바꾸면 뒤 핸들러는 '바뀐 값'을 받는다. 실제로 진단 도구에서
## 1막 클리어가 2막 클리어로 보고됐다 (TowerDefenseMain._on_act_cleared 가 첫 핸들러라
## _start_wave_automatically() 로 current_act 를 먼저 올려버린다).
## 그래서 _grant_round_reward 는 지역 변수로 스냅샷해서 넘긴다.
func _test_act_cleared_reports_the_cleared_act_to_late_listeners() -> void:
	var field = DefenseFieldScript.new()
	# 주의: GDScript 람다는 지역 변수를 '값으로' 캡처한다. 람다 안에서 대입해도
	# 바깥 지역 변수는 안 바뀐다. 결과를 받으려면 참조 타입(Array/Dictionary)을 써야 한다.
	var seen: Array = [-1, -1]   # [막, 웨이브]
	# 첫 리스너 = 실제 게임처럼 다음 막을 시작해 current_act 를 올린다.
	field.act_cleared.connect(func(_act: int, _gold: int): field.current_act += 1)
	field.act_cleared.connect(func(act: int, _gold: int): seen[0] = act)
	# wave_cleared 도 같은 함정을 공유한다.
	field.wave_cleared.connect(func(_act: int, _wave: int, _gold: int): field.current_wave += 1)
	field.wave_cleared.connect(func(_act: int, wave: int, _gold: int): seen[1] = wave)

	field.current_act = 1
	field.current_wave = 20
	field._grant_round_reward(true)
	check(seen[0] == 1,
		"뒤에 붙은 리스너도 '클리어한 막'을 받아야 한다 (받은 값 %d)" % int(seen[0]))

	field.current_act = 1
	field.current_wave = 7
	field._grant_round_reward(false)
	check(seen[1] == 7,
		"뒤에 붙은 리스너도 '클리어한 웨이브'를 받아야 한다 (받은 값 %d)" % int(seen[1]))
	field.free()


## 적이 기지에 닿으면 기지 HP 가 깎여야 한다 — 타워 디펜스의 기본 전제.
##
## 예전에는 EnemyUnit 이 loop = true 라, 경로 끝(기지)에서 처음으로 되돌아가 영원히
## 돌아다녔다. 그래서 reached_base 가 한 번도 emit 되지 않아 **기지 HP 가 절대 줄지
## 않았고**, 죽지도 않은 적이 계속 쌓여 MAX_ENEMIES(50) 초과 → '즉시 패배' 로만 끝났다.
## 실측: 타워 3개로 3막 완주에 기지 HP 20/20, 잃은 HP 0.
func _test_enemies_damage_the_base_on_arrival() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.spawn_queue.clear()
	field._build_wave_monsters(1, 1)
	check(not field.spawn_queue.is_empty(), "A wave must have monsters to spawn")
	field._spawn_enemy(field.spawn_queue[0])

	# get_enemies() 는 untyped Array 를 돌려준다. `:=` 로 받으면 추론 실패로
	# 스크립트가 통째로 로드되지 않고, 테스트 씬이 quit() 에 도달하지 못해 멈춘다.
	var enemies: Array = field.get_enemies()
	check(enemies.size() == 1, "Spawning a monster must register exactly one live enemy")
	if enemies.is_empty():
		field.free()
		return
	var enemy = enemies[0]
	check(not enemy.loop,
		"An enemy must reach the base instead of looping around the path forever")

	var hp_before: int = field.base_hp
	var dmg: int = enemy.base_damage
	check(dmg >= 1, "An enemy must deal at least 1 damage to the base")

	# 경로 끝(=기지)으로 보낸 뒤 한 프레임 진행시킨다.
	var path: Path2D = enemy.get_parent()
	enemy.progress = path.curve.get_baked_length()
	enemy._process(0.0)

	check(field.base_hp == hp_before - dmg,
		"Reaching the base must cost %d HP (base %d → %d)" % [dmg, hp_before, field.base_hp])
	check(field.get_enemies().is_empty(),
		"An enemy that reached the base must leave the field")
	field.free()


func _test_enemy_path_follows_road_center() -> void:
	# 막마다 전용 맵(1024x352)을 쓰고, 경로는 그 맵의 길 중심선을 따라야 한다.
	check(DefenseFieldScript.ACT_PATHS.size() == 3, "Every act must define its own enemy path")
	check(DefenseFieldScript.ACT_MAP_TEXTURES.size() == 3, "Every act must define its own map art")
	check(DefenseFieldScript.ACT_SLOTS.size() == 3, "Every act must define its own tower pads")
	for act in range(1, 4):
		var path: Array = DefenseFieldScript.ACT_PATHS[act]
		var slots: Array = DefenseFieldScript.ACT_SLOTS[act]
		check(path.size() >= 10, "Act %d path must be a real route, not a stub" % act)
		check(slots.size() == DefenseFieldScript.MAX_SLOT_COUNT,
			"Act %d must offer the same number of tower pads" % act)
		var all_in_bounds: bool = path.all(func(p: Vector2) -> bool:
			return p.x >= 0.0 and p.x <= DefenseFieldScript.MAP_W and p.y >= 0.0 and p.y <= DefenseFieldScript.MAP_H)
		check(all_in_bounds, "Act %d path must stay inside the map bounds" % act)
		# 타워 발판은 길과 겹치면 안 된다 (사용자 신고: 타워가 길 위에 겹침).
		# 중심선 거리만 보면 안 된다 — 길 폭이 막마다 다르므로
		# '길 반폭 + 발판 반지름 + 여유' 를 넘겨야 실제로 겹치지 않는다.
		var need: float = DefenseFieldScript.ACT_ROAD_HALF[act] + DefenseFieldScript.PAD_RADIUS
		for pad in slots:
			var nearest := INF
			for i in range(path.size() - 1):
				nearest = minf(nearest, _dist_point_segment(pad, path[i], path[i + 1]))
			check(nearest >= need + 4.0,
				"Act %d tower pad %s must clear the road edge (need %.0f, got %.1f)" % [act, pad, need + 4.0, nearest])
		# 발판끼리도 서로 붙지 않게 충분히 떨어져 있어야 한다 (타워 카드는 64px).
		for i in range(slots.size()):
			for j in range(i + 1, slots.size()):
				check(slots[i].distance_to(slots[j]) >= DefenseFieldScript.PAD_DIAMETER,
					"Act %d pads %d/%d overlap each other (%.1f px)" % [act, i + 1, j + 1, slots[i].distance_to(slots[j])])


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _type_hp(field, act: int, wave: int) -> Dictionary:
	field.spawn_queue.clear()
	field._build_wave_monsters(act, wave)
	var out := {}
	for enemy in field.spawn_queue:
		var t: String = enemy.get("type", "normal")
		if t != "boss" and not out.has(t):
			out[t] = float(enemy["hp"])
	return out


func _test_enemy_hp_progression() -> void:
	var field = DefenseFieldScript.new()
	var act_round_one: Dictionary = {}
	for act in range(1, 4):
		var early := _type_hp(field, act, 1)
		var late := _type_hp(field, act, 15)
		# 라운드가 오를수록 같은 종류도 단단해진다.
		for t in ["normal", "fast", "armored", "swarm"]:
			check(late[t] > early[t], "Act %d %s must get tougher by round 15" % [act, t])
		# 종류별 서열: 중갑 > 일반 > 질풍 > 군집
		check(early["armored"] > early["normal"], "Act %d armored must out-tank normal" % act)
		check(early["normal"] > early["fast"], "Act %d fast enemies must be squishier than normal" % act)
		check(early["fast"] > early["swarm"], "Act %d swarm must be the weakest" % act)
		# 중갑은 보호막까지 갖는다.
		field.spawn_queue.clear()
		field._build_wave_monsters(act, 1)
		var armored = field.spawn_queue.filter(func(e): return e.get("type") == "armored")
		check(not armored.is_empty() and float(armored[0].get("shield", 0.0)) > 0.0,
			"Act %d armored enemies need a shield" % act)
		# 보스는 같은 라운드 잡몹보다 압도적으로 강해야 한다.
		field.spawn_queue.clear()
		field._build_wave_monsters(act, 5)
		var boss = field.spawn_queue.filter(func(e): return e.get("type") == "boss")
		check(not boss.is_empty() and float(boss[0]["hp"]) > early["normal"] * 3.0,
			"Act %d boss must dwarf regular monsters" % act)
		act_round_one[act] = early["normal"]
	check(act_round_one[2] > act_round_one[1] and act_round_one[3] > act_round_one[2],
		"Later acts must be tougher on the same round")
	field.free()


func _has_type(field, act: int, type: String) -> bool:
	for wave in range(1, 21):
		field.spawn_queue.clear()
		field._build_wave_monsters(act, wave)
		for enemy in field.spawn_queue:
			if enemy.get("type", "normal") == type:
				return true
	return false


func _test_gold_income() -> void:
	var field = DefenseFieldScript.new()
	var total := 0
	for act in range(1, 4):
		for wave in range(1, 21):
			field.spawn_queue.clear()
			field._build_wave_monsters(act, wave)
			var round_gold := 0
			for enemy in field.spawn_queue:
				var t: String = enemy.get("type", "normal")
				check(int(enemy["gold"]) >= 1, "every enemy must drop at least 1 gold")
				if t == "boss":
					check(int(enemy["gold"]) > 5, "bosses must drop a real payout")
				else:
					check(int(enemy["gold"]) <= 2, "regular enemies must stay low-value")
				round_gold += int(enemy["gold"])
			field.current_act = act
			field.current_wave = wave
			total += round_gold + field._wave_clear_bonus()
	check(is_equal_approx(field.SPAWN_INTERVAL, 0.8), "Spawn interval must be 0.8 seconds")

	# 골드 예산 — 사용자 신고 "골드가 너무 많아".
	# 예전에는 한 런에 2,808 G 가 들어와 소비처(약 900 G)의 3배가 쌓였다.
	# 1차로 1,523 G 까지 줄였지만 여전히 소비처(1,035 G)보다 앞서 약 490 G 가 남았다.
	# 2차로 수입을 ~1,050 G 로 낮춰 타일과 유물이 서로 경쟁하게 만들었다.
	check(total <= GOLD_BUDGET,
		"A full run must not print money (income %d > budget %d)" % [total, GOLD_BUDGET])
	check(total >= GOLD_FLOOR,
		"A full run must still afford real choices (income %d < floor %d)" % [total, GOLD_FLOOR])

	# 라운드 보상은 막이 오를수록 커지고, 보스 라운드는 확실히 더 준다.
	field.current_act = 1
	field.current_wave = 1
	var early_bonus: int = field._wave_clear_bonus()
	field.current_wave = 5
	var boss_bonus: int = field._wave_clear_bonus()
	check(boss_bonus > early_bonus, "boss rounds must pay more than early rounds")
	field.current_wave = 12
	check(field._wave_clear_bonus() > early_bonus, "later rounds must pay more than round 1")
	field.current_act = 3
	check(field._wave_clear_bonus() > early_bonus, "later acts must pay more than act 1")
	field.current_act = 1
	field.current_wave = 12
	field.relic_ids = ["relic_bounty_coin"]
	check(field._wave_clear_bonus() == (1 + 1 + 1 + 5), "bounty coin must add 5 gold to round rewards")
	# 상인의 보물주머니: 덧셈 유물을 다 더한 뒤 50% 를 곱한다.
	field.relic_ids = ["relic_merchant_pouch"]
	check(field._wave_clear_bonus() == ceili((1 + 1 + 1) * 1.5),
		"the merchant pouch must raise round rewards by 50%")
	field.relic_ids = ["relic_bounty_coin", "relic_merchant_pouch"]
	check(field._wave_clear_bonus() == ceili((1 + 1 + 1 + 5) * 1.5),
		"the pouch must multiply the bounty coin bonus instead of ignoring it")
	field.free()


func _test_enemy_count_keeps_wave_hp() -> void:
	# 적 수를 줄인 대신 1마리당 HP 를 올려 '웨이브 총 HP' 가 그대로여야 한다.
	# 이래야 골드만 줄고 난이도는 안 변한다.
	var field = DefenseFieldScript.new()
	for act in range(1, 4):
		for wave in [1, 3, 7, 12, 20]:
			var w: int = int(wave)
			var legacy: float = 8.0 + w + (act - 1) * 2
			var count: float = float(field.enemy_count_for(act, w))
			check(count < legacy, "Act %d wave %d must spawn fewer enemies than before" % [act, w])
			check(is_equal_approx(count * field.hp_compensation_for(act, w), legacy),
				"Act %d wave %d must keep the same total wave HP" % [act, w])
			check(count >= 5.0, "Act %d wave %d must still feel like a wave" % [act, w])
	field.free()


func _test_tower_damage_ranking() -> void:
	var field = DefenseFieldScript.new()
	field.record_tower_damage("불", 12.5)
	field.record_tower_damage("물", 20.0)
	field.record_tower_damage("불", 10.0)
	var ranking = field.damage_ranking()
	check(ranking[0].tower == "불" and is_equal_approx(ranking[0].damage, 22.5), "Tower damage must accumulate and rank by total")
	check(is_equal_approx(field.total_tower_damage(), 42.5), "total tower damage must sum every tower")

	# 누적 피해는 게임오버 요약에만 있었다. 플레이 중 '다음 골드를 어디에 넣을까' 의
	# 근거로 쓰려면 그 타워의 몫과 순위를 그 자리에서 물어볼 수 있어야 한다.
	var best: Dictionary = field.tower_damage_share("불")
	check(is_equal_approx(best["damage"], 22.5), "share must report the tower's own damage")
	check(is_equal_approx(best["total"], 42.5), "share must report the run total")
	check(best["rank"] == 1 and best["count"] == 2, "share must rank the tower against the others")
	check(field.tower_damage_share("물")["rank"] == 2, "the weaker tower must rank below")
	# 아직 한 발도 못 맞춘 타워도 '기록된 타워 수' 는 늘리지 않는다 —
	# 순위표는 실제로 딜을 넣은 타워만 센다.
	var idle: Dictionary = field.tower_damage_share("흙")
	check(idle["damage"] == 0.0 and idle["count"] == 2, "a tower that never fired must not enter the ranking")
	field.free()


## 정보창의 '누적 피해' 줄 — 플레이 중에 보이는 유일한 성과 지표다.
func _test_tower_info_shows_damage_share() -> void:
	check(NumTextScript.comma(1240.0) == "1,240", "damage must be grouped by thousands")
	check(NumTextScript.comma(42.0) == "42", "short numbers must stay bare")
	check(NumTextScript.comma(1000.0) == "1,000", "a round thousand must still be grouped")
	var modal = TowerInfoModalScript.new()
	var ranked: String = modal._share_line({"damage": 300.0, "total": 1000.0, "rank": 1, "count": 3})
	check(ranked.contains("누적 피해 300") and ranked.contains("30%") and ranked.contains("1위"),
		"the info modal must name the damage, its share and the rank (got %s)" % ranked)
	# 타워가 하나뿐이면 '1위' 는 정보가 아니다.
	var solo: String = modal._share_line({"damage": 300.0, "total": 300.0, "rank": 1, "count": 1})
	check(not solo.contains("위"), "a lone tower must not be labelled 1st place (got %s)" % solo)
	var quiet: String = modal._share_line({"damage": 0.0, "total": 300.0, "rank": 2, "count": 2})
	check(quiet.contains("없음"), "a tower that never hit anything must say so (got %s)" % quiet)
	check(modal._share_line({}) == "", "missing share data must not add a line")
	modal.free()


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


## 방어도가 타격을 전부 먹은 순간은 **HP 가 한 대도 안 깎인 순간**이다.
##
## 그런데 예전에는 그 타격도 흰 숫자로 '30' 이라고 떴다 — 실제로 HP 30 을 깎은 타격과
## **완전히 똑같이** 보였다. 플레이어는 자기 타워가 잘 하고 있다고 읽는다.
## 'armored' 적은 HP 가 base_hp 의 1.5배, 방어도가 0.8배라 바 전체의 약 35% 가
## 방어도이고, 모든 막에 한 마리씩 나오므로 드문 일이 아니다. Juice 에는 'shield'
## 종류가 예전부터 정의돼 있었지만 **아무도 그 종류를 돌려주지 않아** 화면에 나온
## 적이 없었다(죽은 분기).
func _test_absorbed_hits_are_not_reported_as_normal_damage() -> void:
	# ── 순수 분류기. 실제 값으로 직접 부른다.
	var probe = EnemyUnitScript.new()
	check(probe._damage_kind(25.0, 25.0, 25.0, 1.0) == "shield",
		"A hit the shield ate entirely must be named 'shield', not 'normal'")
	# 40 방어도에 60 → 40 흡수 + 20 HP. HP 가 실제로 줄었으니 기존 분류를 지킨다.
	check(probe._damage_kind(40.0, 60.0, 60.0, 1.0) != "shield",
		"A hit that reached HP must keep its normal/weakness classification")
	# 상성(약점)이 정답인 타격이라도 방어도가 전부 먹었으면 방어도라고 말한다 —
	# HP 에 닿지 않은 피해에 '약점' 이라는 품질을 붙이면 그게 곧 거짓말이다.
	check(probe._damage_kind(25.0, 25.0, 25.0, 1.6) == "shield",
		"An absorbed weakness hit must still be reported as shield")
	# 방어도가 아예 없으면 상성 분류가 그대로 살아 있어야 한다.
	check(probe._damage_kind(0.0, 25.0, 25.0, 1.6) == "weak",
		"A weakness hit with no shield must keep its weakness name")
	check(probe._damage_kind(0.0, 25.0, 25.0, 0.65) == "resist",
		"A resisted hit with no shield must keep its resist name")
	probe.free()

	# ── 종류가 색으로 구분되는가. 겹치면 이름을 붙인 의미가 없다.
	var seen := {}
	# ⚠️ 2026-10-01 — `big` 추가(§2.21 (A)). `crit` 이 이제 **굴림**을 뜻하므로,
	#    60 임계(예전 `crit`)는 `big` 이라는 자기 이름을 얻었다. 일곱 종류가 전부
	#    서로 다른 색이어야 한다 — `crit`(브랜드 보라)과 `big`(금색)이 그 증거다.
	for kind in ["normal", "crit", "big", "dot", "shield", "weak", "resist"]:
		var col: Color = Juice.damage_style(100.0, kind)["color"]
		check(not seen.has(col),
			"Damage kinds must be told apart by colour ('%s' collides with '%s')"
				% [kind, str(seen.get(col, ""))])
		seen[col] = kind

	# ── 실제 경로: 피해 숫자 라벨의 색까지 확인한다.
	for stale in get_tree().get_nodes_in_group("damage_numbers"):
		stale.free()
	var armored = EnemyUnitScene.instantiate()
	add_child(armored)
	armored.init_enemy("중갑병", 100.0, 50.0, 2, "", 40.0)
	await get_tree().process_frame
	armored.take_damage(25.0, false)
	await get_tree().process_frame
	var labels: Array = get_tree().get_nodes_in_group("damage_numbers")
	check(labels.size() == 1, "One absorbed hit must raise exactly one damage number (got %d)" % labels.size())
	if labels.size() == 1:
		var fresh := labels[0] as Label
		check(fresh.get_theme_color("font_color") == Palette.SHIELD,
			"An absorbed hit must be drawn in the shield colour (got %s)"
				% str(fresh.get_theme_color("font_color")))
		check(roundi(float(fresh.text)) == 25,
			"The absorbed hit must still show its real magnitude (got '%s')" % fresh.text)

	# ── 바 색이 '방어도' 라고 말할 수 있는 근거를 잠근다.
	# 방어도가 먼저 전부 먹으므로 `shield > 0` 이면 HP 는 한 번도 안 깎였다. 그래서
	# 방어도가 남아 있는 동안 HP 심각도 축(초록/노랑/빨강)은 퇴화해 있고, 같은 통로를
	# 방어도 색이 써도 축이 충돌하지 않는다. 이 불변식이 깨지면 바 색이 거짓말이 된다.
	var drain = EnemyUnitScene.instantiate()
	add_child(drain)
	drain.init_enemy("중갑병", 100.0, 50.0, 2, "", 40.0)
	var armour_sb := drain.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(armour_sb != null and armour_sb.bg_color == Palette.SHIELD,
		"While armour holds, the bar must be drawn in the shield colour (got %s)"
			% str(armour_sb.bg_color if armour_sb != null else "없음"))
	for i in range(20):
		drain.take_damage(7.0, false)
		if drain.shield > 0.0:
			check(is_equal_approx(drain.hp, drain.max_hp),
				"While any shield remains HP must be untouched, or the bar colour lies (hp %.1f, shield %.1f)"
					% [drain.hp, drain.shield])
	# 방어도가 깨지면 색이 HP 축으로 넘어온다 — 그 변화가 '방어도가 벗겨졌다' 는 신호다.
	check(drain.shield == 0.0, "The drain must have broken the shield")
	var broken_sb := drain.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(broken_sb != null and broken_sb.bg_color != Palette.SHIELD,
		"Once armour breaks the bar must fall back to the HP colour ramp (got %s)"
			% str(broken_sb.bg_color if broken_sb != null else "없음"))
	check(broken_sb.bg_color == Palette.hp_color(drain.hp / (drain.max_hp + drain.max_shield)),
		"The broken bar must use the ordinary HP colour for its ratio")
	drain.free()
	armored.free()


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


## 상점은 유물만 판다. 예전에는 [자모 진열대] + [덱 압축] 칸도 있었지만
## 씬에서 `visible = false` 로 시작해 **어느 코드도 켜지 않았다** — 아무도 볼 수 없는
## 위젯을 매 갱신마다 만들고, 칸 제목은 없는 기능을 광고했다.
## 자모 구매·제거는 벨트 헤더가 하므로 상점에 두 번째 구매 창구를 두지 않는다.
func _test_shop_sells_relics_only() -> void:
	var shop = ShopModalScene.instantiate()
	add_child(shop)
	shop.setup(100, [])
	check(shop.get_node_or_null("Panel/VBox/Scroll/AllContentVBox/SectionJamo") == null,
		"the shop must not keep the hidden jamo shelf")
	check(shop.get_node_or_null("Panel/VBox/Scroll/AllContentVBox/SectionRemove") == null,
		"the shop must not keep the hidden tile-removal shelf")
	check(shop.get_node_or_null("Panel/VBox/Scroll/AllContentVBox/SectionRelics") != null,
		"the shop must still sell relics")
	check(shop.mouse_filter == Control.MOUSE_FILTER_IGNORE and shop.get_node("Overlay").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Shop must not block gameplay outside its panel")
	var refresh_costs := []
	shop.refresh_bought.connect(func(cost): refresh_costs.append(cost))
	shop.btn_refresh.pressed.emit()
	check(shop.current_gold == 90 and refresh_costs == [10], "Shop refresh must cost 10 gold")
	shop.free()


## 할인패(상인의 할인패)는 '상점 자모 가격 20% 할인' 이 유일한 효과였다.
## 자모 판매가 사라지면 효과가 없는 25G 유물이 되므로 재고에서도 빠져야 한다.
func _test_no_relic_survives_without_its_effect() -> void:
	var ids: Array = []
	for relic in ShopModalScript.ALL_RELIC_POOL:
		ids.append(str(relic["id"]))
	check(not ids.has("relic_merchant_coupon"),
		"상인의 할인패 must not be sold once the shop stops selling jamo")
	check(ShopModalScript.ALL_RELIC_POOL.size() == ids.size(),
		"relic ids must stay unique")


## res://scripts 아래의 .gd 소스를 전부 모아 하나의 문자열로 합친다.
func _collect_gd_source(root: String, into: Dictionary) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if dir.current_is_dir():
			_collect_gd_source(path, into)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				into[path] = file.get_as_text()
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()


## 유물의 '효과' 가 적힌 코드만 모은다.
## - 상점의 ALL_RELIC_POOL 정의 줄(`"id": "relic_x",`)은 효과가 아니다.
## - 아이콘 경로(relic_x_32px_pastel.png)에 id 가 들어 있어도 효과가 아니다.
##   (이걸 걸러내지 않으면 죽은 유물도 통과해 버린다 — 실제로 그럴 뻔했다)
func _relic_effect_source() -> String:
	var sources: Dictionary = {}
	for root in ["res://scripts/tower", "res://scripts/core", "res://scripts/ui"]:
		_collect_gd_source(root, sources)
	var blob := ""
	for path in sources:
		for line in str(sources[path]).split("\n"):
			if line.contains("\"icon\""):
				continue
			if line.strip_edges().begins_with("\"id\":"):
				continue
			blob += line + "\n"
	return blob


func _test_every_shop_relic_has_an_effect() -> void:
	# 상점 유물은 25~40G 다. 효과가 없는데 파는 건 그냥 사기다.
	# 실제로 '활자의 정수' / '신속의 나침반' / '상인의 보물주머니' / '훈민정음의 나침반'
	# 네 개가 상점 정의에만 있고 게임 로직이 아무 데서도 읽지 않았다.
	var blob := _relic_effect_source()
	check(blob.length() > 10000, "The relic audit must be able to read the game scripts")

	for relic in ShopModalScript.ALL_RELIC_POOL:
		var id: String = str(relic["id"])
		check(blob.count(id) >= 1,
			"Shop relic %s costs %dG but no game logic reads it" % [id, int(relic["cost"])])


## 상점 유물 하나의 설명 문구.
func _relic_desc(id: String) -> String:
	for relic in ShopModalScript.ALL_RELIC_POOL:
		if str(relic["id"]) == id:
			return str(relic["desc"])
	return ""


## 설명 문구에 적힌 첫 'N%' 의 N. 없으면 -1.
##
## `+` 는 **있어도 되고 없어도 된다** — 상점 문구가 일관되지 않기 때문이다:
## "공격 범위 +15%" 도 있고 "25% 확률로 2배 치명타" 도 있다. `+` 를 요구하면
## 뒤쪽 문구를 못 읽어서 검사가 조용히 -1 을 돌려주고, 그러면 이 가드가 통과해 버린다.
##
## 설명과 코드의 숫자를 사람이 눈으로 맞추지 않게 하려고 만든 것이다 —
## 바로 그 눈으로 맞추기가 오래 실패해 있었다(`×0.8` 을 보고 '+20%' 라고 적었다).
func _pct_in(text: String) -> float:
	var re := RegEx.new()
	re.compile("\\+?\\s*(\\d+(?:\\.\\d+)?)\\s*%")
	var m := re.search(text)
	return float(m.get_string(1)) if m != null else -1.0


## 설명 문구에 적힌 첫 평면 가산량 N. 없으면 -1.
##
## `+` 는 있어도 되고 없어도 된다("기지 최대 체력 +10" / "기지 HP 2 회복").
## **평면 가산을 적는 유물에만 쓴다** — 퍼센트 문구에 쓰면 "+25% 피해" 의 25 를
## 금액으로 잘못 읽는다(그래서 퍼센트는 `_pct_in` 이 따로 있다).
func _plus_in(text: String) -> float:
	var re := RegEx.new()
	re.compile("\\+?\\s*(\\d+(?:\\.\\d+)?)")
	var m := re.search(text)
	return float(m.get_string(1)) if m != null else -1.0


## 설명 문구에 적힌 'N배' 의 N. 없으면 -1.
func _times_in(text: String) -> float:
	var re := RegEx.new()
	re.compile("(\\d+(?:\\.\\d+)?)\\s*배")
	var m := re.search(text)
	return float(m.get_string(1)) if m != null else -1.0


## 상점 설명은 **사는 사람이 읽는 유일한 계약**이다.
##
## `_test_every_shop_relic_has_an_effect` 는 "효과가 하나라도 있으면" 만 본다 — 그래서
## 설명에 없는 효과가 있어도, 설명이 말한 것과 **다른 것**을 줘도 통과한다.
##
## 실제로 셋이 그랬다. 앞의 둘은 설명에 없는 효과를 **더** 줬고, 셋째는 설명과 **숫자가
## 달랐다**(공격속도 +20% 라고 적고 간격 ×0.8 = 실제 +25% 를 줬다):
##
##   - **천리안의 룬(30G)**: 설명은 "공격 범위 +15%" 뿐인데 무기 타워에 치명타 +10% 를 더 줬다.
##   - **선봉의 깃털(35G)**: 설명은 "첫 공격 피해 2배" 인데 소환 타워는 3배였다.
##   - **신속의 나침반 / 민소리 깃털 / 모음 공명석**: 설명은 속도 +N% 인데 간격 ×(1−N/100),
##     즉 실제로는 더 빨랐다. 셋 다 **플레이어에게 유리한** 방향이라 아무도 신고하지 않았다.
##
## 디렉터 지시("설명과 코드를 일치시켜줘. 설명에 맞춰")에 따라 **설명이 계약**이 되었다:
## 코드를 설명에 맞춰 고쳤고, 이 가드가 그 계약을 잠근다.
##
## 가드는 **양쪽을 함께** 잠근다 — 설명에 없는 효과가 생기면 실패하고(과잉),
## 설명이 말한 효과가 사라져도 실패한다(누락). 한쪽만 고치는 드리프트를 막는 것이 목적이다.
func _test_relic_descriptions_state_exactly_what_the_code_does() -> void:
	# `_make_tower` 는 트리에 안 붙는 타워를 준다 — 아무도 안 치워 주므로 여기서 치운다.
	# (안 치우면 종료 시 'resources still in use' 줄이 늘어나 테스트 출력이 지저분해진다)
	var made: Array = []
	var mk := func(syllable: String, category: String, relics: Array) -> WordTower:
		var t: WordTower = _make_tower(syllable, category, relics)
		made.append(t)
		return t

	# ── (1) 천리안의 룬: 범위만 준다. 치명타는 어느 분류에도 주지 않는다.
	#     주의: 범위 +15% 는 타워가 아니라 **필드**가 건다(`DefenseField._rebuild_towers`).
	#     그래서 타워 하나만 세워서는 잴 수 없다 — 설명의 숫자와 상수를 직접 대조한다.
	var range_plain: WordTower = mk.call("날", "weapon", [])
	var range_runed: WordTower = mk.call("날", "weapon", ["relic_range_rune"])
	check(is_equal_approx(range_runed.crit_chance, range_plain.crit_chance),
		"천리안의 룬 must NOT give a hidden crit bonus — its shop text promises range only")
	var nature_plain: WordTower = mk.call("바위", "nature", [])
	var nature_runed: WordTower = mk.call("바위", "nature", ["relic_range_rune"])
	check(is_equal_approx(nature_runed.crit_chance, nature_plain.crit_chance),
		"천리안의 룬 must not touch crit for any tower category")
	check(not _relic_desc("relic_range_rune").contains("치명타"),
		"천리안의 룬's shop text must not promise a crit bonus it no longer gives (got '%s')"
			% _relic_desc("relic_range_rune"))
	var rune_pct := (DefenseFieldScript.RANGE_RUNE_RANGE_MULT - 1.0) * 100.0
	check(is_equal_approx(_pct_in(_relic_desc("relic_range_rune")), rune_pct),
		"천리안의 룬's text and its range multiplier must state the same number (text '%s', code %.1f%%)"
			% [_relic_desc("relic_range_rune"), rune_pct])

	# ── (2) 선봉의 깃털: 모든 분류가 똑같이 2배다. 소환 예외는 없다.
	var summon: WordTower = mk.call("엄니", "summon", ["relic_first_strike"])
	check(str(summon.word_data.get("category", "")) == "summon",
		"The test word must actually be a summon tower")
	check(is_equal_approx(summon.first_strike_multiplier(), 2.0),
		"선봉의 깃털 must give summon towers the same 2x its shop text promises — no exception")
	var other: WordTower = mk.call("바위", "nature", ["relic_first_strike"])
	check(is_equal_approx(other.first_strike_multiplier(), 2.0),
		"선봉의 깃털 must give every other tower 2x on the first hit")
	# '첫 공격' 이라는 말이 그 뜻이다 — 한 대 뒤에는 배수가 사라져야 한다.
	summon.attack_count = 1
	check(is_equal_approx(summon.first_strike_multiplier(), 1.0),
		"The first-strike bonus must not survive the first attack")
	# 유물이 없으면 배수도 없다.
	check(is_equal_approx(mk.call("바위", "nature", []).first_strike_multiplier(), 1.0),
		"Without the relic there must be no first-strike bonus")
	check(not _relic_desc("relic_first_strike").contains("소환"),
		"선봉의 깃털's shop text must not promise a summon exception it no longer gives (got '%s')"
			% _relic_desc("relic_first_strike"))

	# ── (3) '공격속도 +N%' 는 **초당 공격 횟수**가 N% 늘어난다는 뜻이다.
	#     설명에 적힌 숫자를 직접 읽어, 실제 속도 증가와 기계적으로 대조한다.
	#     (사람이 설명과 코드를 눈으로 맞추지 않아도 되게 하는 것이 이 검사의 목적이다)
	_test_attack_speed_relics_honour_the_percent_in_their_text(mk)

	for t in made:
		if is_instance_valid(t):
			t.free()


## 설명에 '공격속도 +N%' 라고 적힌 유물을 **전부** 찾아, 실제 속도 증가가 그 N% 인지 본다.
##
## 간격(interval)을 재는 것으로는 부족하다 — 사람이 `×0.8` 을 보고 '+20%' 라고 적어 두는 것이
## 바로 이 버그였기 때문이다. 그래서 **초당 공격 횟수**(= 1/간격)의 비율을 잰다.
##
## 이 검사는 유물 목록을 손으로 적지 않고 **설명에서 찾는다.** 그래서 나중에 '공격속도 +N%'
## 라고 적는 유물이 새로 생기면 저절로 검사 대상이 된다 — 실제로 이 방식으로 네 번째
## 유물(무받침 풍경)을 찾아냈다(손으로 적은 목록에는 없었다).
func _test_attack_speed_relics_honour_the_percent_in_their_text(mk: Callable) -> void:
	# 타워 하나만 세워서 재는 유물 → 그 유물의 조건을 만족하는 시험 단어.
	#   · 나침반   : 조건 없음. 대신 다른 둘이 걸리지 않는 단어를 고른다(받침 있음 + 모음 반복 없음).
	#   · 민소리   : 받침이 **없어야** 한다(규칙이 반전돼 있다). 모음은 반복하지 않는다.
	#   · 공명석   : 같은 모음이 반복돼야 한다.
	var probe_words := {
		"relic_haste_compass": "간",
		"relic_open_feather": "가니",
		"relic_vowel_resonance": "가나",
	}
	# 인접 배치가 조건인 유물 → 타워 하나로는 잴 수 없다(양쪽에 걸린다).
	var adjacency_words := {
		"relic_open_chime": ["가나", "가니"],
	}
	var re := RegEx.new()
	re.compile("공격\\s*속도\\s*\\+\\s*(\\d+)\\s*%")
	var checked := 0
	for relic in ShopModalScript.ALL_RELIC_POOL:
		var id := str(relic["id"])
		var desc := str(relic["desc"])
		var m := re.search(desc)
		if m == null:
			continue
		checked += 1
		var pct := float(m.get_string(1))
		var expected := 1.0 + pct / 100.0
		if probe_words.has(id):
			var word: String = probe_words[id]
			var plain: WordTower = mk.call(word, "weapon", [])
			var runed: WordTower = mk.call(word, "weapon", [id])
			# 초당 공격 횟수의 비율 = 간격의 역수 비율.
			var rate: float = plain.attack_interval / runed.attack_interval
			check(is_equal_approx(rate, expected),
				"%s's text says 공격속도 +%d%% but the code gives %.2f%% (rate %.4f on '%s')"
					% [id, int(pct), (rate - 1.0) * 100.0, rate, word])
			# 이 유물이 실제로 걸리는 단어인지도 확인한다 — 안 걸리면 위 검사가 통과해도 무의미하다.
			check(rate > 1.001,
				"%s must actually apply to the probe word '%s' — pick a word that meets its condition"
					% [id, word])
		elif adjacency_words.has(id):
			var pair: Array = adjacency_words[id]
			var without: float = _adjacent_pair_interval(pair[0], pair[1], [])
			var with_relic: float = _adjacent_pair_interval(pair[0], pair[1], [id])
			var rate: float = without / with_relic
			check(is_equal_approx(rate, expected),
				"%s's text says 공격속도 +%d%% but the code gives %.2f%% (rate %.4f on the pair %s)"
					% [id, int(pct), (rate - 1.0) * 100.0, rate, str(pair)])
			check(rate > 1.001,
				"%s must actually apply to the adjacent pair %s — check the pair meets its condition"
					% [id, str(pair)])
		else:
			check(false, "%s's text promises 공격속도 +%d%% but no probe is set up for it"
				% [id, int(pct)])
	# 설명에 '공격속도 +N%' 를 적어 둔 유물이 하나도 안 잡히면 이 검사는 아무것도 안 지킨다.
	check(checked >= 4,
		"The attack-speed contract must cover the relics whose text names a speed percent (found %d)"
			% checked)


## 인접 배치 유물이 만드는 속도 증가를 **실제 필드에서** 잰다.
##
## 무받침 풍경은 타워 하나가 아니라 **양쪽**에 걸리므로 `setup_tower` 만으로는 잴 수 없다.
## 같은 두 타워를 유물 없이/있이 세우고 간격을 재면, 다른 시너지(밀집·사다리 등)는
## 양쪽에 똑같이 걸리므로 **두 간격의 차이가 곧 이 유물의 몫**이 된다.
func _adjacent_pair_interval(word_a: String, word_b: String, relics: Array) -> float:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.relic_ids = relics
	var a: WordTower = _make_tower(word_a, "basic", [])
	var b: WordTower = _make_tower(word_b, "basic", [])
	add_child(a)
	add_child(b)
	a.global_position = Vector2(200, 200)
	b.global_position = Vector2(230, 200)
	field.active_towers.assign([a, b])
	field._apply_tower_synergies()
	var interval: float = a.attack_interval
	# 두 타워는 트리에 남으므로 여기서 치운다(안 치우면 'resources still in use' 줄이 는다).
	a.free()
	b.free()
	field.free()
	return interval


## 설명에 '피해/사거리/치명타 +N%' 라고 적힌 **글자 모양 유물**의 숫자를 실제 값과 맞춘다.
##
## 이 유물들은 이 가드를 쓰기 전까지 **테스트 커버리지가 0** 이었다. 설명에 숫자를 적어
## 놓고 아무도 그 숫자를 재지 않았다는 뜻이다 — 실제로 같은 구멍에서 '공격속도 +N%' 네 개가
## 설명과 다른 값을 주고 있었다(그 넷은 `_test_attack_speed_relics_honour_...` 가 잡는다).
##
## 시험 단어는 그 유물의 조건을 만족해야 한다(아니면 검사가 조용히 헛돈다). 그래서 단어와
## **왜 그 조건을 만족하는지**를 함께 적고, 조건이 실제로 걸렸는지도 따로 확인한다.
func _test_word_shape_relics_honour_the_percent_in_their_text() -> void:
	var made: Array = []
	var mk := func(syllable: String, category: String, relics: Array) -> WordTower:
		var t: WordTower = _make_tower(syllable, category, relics)
		made.append(t)
		return t
	# id → [시험 단어, 스탯, 그 단어가 조건을 만족하는 이유]
	var cases := {
		"relic_tense_hammer":  ["꽃", "damage", "된소리 초성 ㄲ"],
		"relic_final_weight":  ["간", "damage", "받침 ㄴ"],
		"relic_cluster_anvil": ["닭", "damage", "겹받침 ㄺ"],
		"relic_vowel_crystal": ["사과", "range", "겹모음 ㅘ"],
		"relic_initial_drum":  ["사슴", "damage", "두 음절 초성이 모두 ㅅ"],
		"relic_balance_ink":   ["나무", "damage", "자음 2 · 모음 2"],
	}
	for id in cases:
		var word: String = cases[id][0]
		var stat: String = cases[id][1]
		var why: String = cases[id][2]
		var plain: WordTower = mk.call(word, "nature", [])
		var runed: WordTower = mk.call(word, "nature", [id])
		var base: float = plain.damage_multiplier if stat == "damage" else plain.attack_range
		var boosted: float = runed.damage_multiplier if stat == "damage" else runed.attack_range
		var pct := _pct_in(_relic_desc(id))
		check(is_equal_approx(boosted / base, 1.0 + pct / 100.0),
			"%s's text says +%d%% (%s) but the code gives %.2f%% on '%s' [%s]"
				% [id, int(pct), stat, (boosted / base - 1.0) * 100.0, word, why])
		check(boosted > base,
			"%s must actually apply to '%s' [%s] — pick a word that meets its condition"
				% [id, word, why])

	# 균형의 먹은 설명에 '피해·사거리 +10%' 라고 **둘 다** 적혀 있다. 하나만 검사하면
	# 나머지 하나가 조용히 사라져도 통과한다.
	var ink_pct := _pct_in(_relic_desc("relic_balance_ink"))
	var ink_plain: WordTower = mk.call("나무", "nature", [])
	var ink_runed: WordTower = mk.call("나무", "nature", ["relic_balance_ink"])
	check(is_equal_approx(ink_runed.attack_range / ink_plain.attack_range, 1.0 + ink_pct / 100.0),
		"균형의 먹's text promises 사거리 +%d%% as well as 피해" % int(ink_pct))

	# 자음 고리(받침 → 다음 초성)는 치명타이고 **배수가 아니라 가산**이라 따로 잰다.
	var ring_pct := _pct_in(_relic_desc("relic_consonant_ring"))
	var ring_plain: WordTower = mk.call("신나", "nature", [])
	var ring_runed: WordTower = mk.call("신나", "nature", ["relic_consonant_ring"])
	check(is_equal_approx(ring_runed.crit_chance - ring_plain.crit_chance, ring_pct / 100.0),
		"자음 고리's text says 치명타 +%d%% but the code adds %.4f on '신나' [받침 ㄴ → 초성 ㄴ]"
			% [int(ring_pct), ring_runed.crit_chance - ring_plain.crit_chance])
	check(ring_runed.crit_chance > ring_plain.crit_chance,
		"자음 고리 must actually apply to '신나' [받침 ㄴ → 초성 ㄴ]")

	# 삼문자 인장 — "3글자 타워 피해 +25%". 순수 함수로 떼어 두어 설명의 숫자를 직접 댈 수 있다.
	var seal_pct := _pct_in(_relic_desc("relic_three_syllable_seal"))
	var seal_three: WordTower = mk.call("나무꾼", "nature", ["relic_three_syllable_seal"])
	check(is_equal_approx(seal_three.three_syllable_multiplier(), 1.0 + seal_pct / 100.0),
		"삼문자 인장's text says +%d%% but the code gives ×%.2f on a 3-syllable tower"
			% [int(seal_pct), seal_three.three_syllable_multiplier()])
	check(is_equal_approx(mk.call("나무", "nature", ["relic_three_syllable_seal"]).three_syllable_multiplier(), 1.0),
		"삼문자 인장 must not apply to a two-syllable tower")
	check(is_equal_approx(mk.call("나무꾼", "nature", []).three_syllable_multiplier(), 1.0),
		"Without the relic there must be no three-syllable bonus")

	# 예리한 렌즈 — "25% 확률로 2배 치명타". 확률은 total_crit_chance(), 배수는 CRIT_DAMAGE_MULT.
	var lens_pct := _pct_in(_relic_desc("relic_crit_lens"))
	var lens_plain: WordTower = mk.call("나무", "nature", [])
	var lens_runed: WordTower = mk.call("나무", "nature", ["relic_crit_lens"])
	check(is_equal_approx(lens_runed.total_crit_chance() - lens_plain.total_crit_chance(), lens_pct / 100.0),
		"예리한 렌즈's text says %d%% but the code adds %.4f to the crit chance"
			% [int(lens_pct), lens_runed.total_crit_chance() - lens_plain.total_crit_chance()])
	check(is_equal_approx(WordTower.CRIT_DAMAGE_MULT, _times_in(_relic_desc("relic_crit_lens"))),
		"예리한 렌즈's text says %d배 but CRIT_DAMAGE_MULT is %.2f"
			% [int(_times_in(_relic_desc("relic_crit_lens"))), WordTower.CRIT_DAMAGE_MULT])

	for t in made:
		if is_instance_valid(t):
			t.free()


## 회복의 향로가 웨이브 종료 때 **실제로 회복시키는 양**.
##
## `_grant_round_reward` 는 골드·슬롯까지 함께 건드리므로 HP 차이만 본다.
## 시작 HP 를 최대보다 낮춰 두는 이유: 상한에 잘리면 회복량이 실제보다 작게 보인다.
func _wave_heal_amount(relics: Array, tower_categories: Array) -> int:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.relic_ids = relics
	var made: Array = []
	for cat in tower_categories:
		var t: WordTower = _make_tower("바위", cat, [])
		add_child(t)
		made.append(t)
	field.active_towers.assign(made)
	field.max_base_hp = 50
	field.base_hp = 40
	field._grant_round_reward(false)
	var healed: int = field.base_hp - 40
	for t in made:
		t.free()
	field.free()
	return healed


## 회복의 향로 — 설명은 "웨이브 종료 시 기지 HP 1 회복" 이다.
##
## 예전에는 치유 타워가 하나라도 있으면 **조용히 3** 을 회복했다(설명에 없는 조건부 +1).
## 정보창에는 그 +1 을 설명하는 라벨(`치유 증폭`)까지 붙어 있었는데, 상점 문구는 2 라고만
## 적혀 있었다. 디렉터 규칙("설명과 코드를 일치시켜줘. 설명에 맞춰")에 따라 +1 을 지웠고,
## 이 가드가 **치유 타워가 있든 없든 똑같이 2** 임을 잠근다.
func _test_wave_heal_relic_heals_exactly_what_its_text_says() -> void:
	var promised := int(_plus_in(_relic_desc("relic_healing_incense")))
	check(promised > 0, "회복의 향로's text must state a heal amount (got '%s')"
		% _relic_desc("relic_healing_incense"))
	check(_wave_heal_amount([], ["heal"]) == 0,
		"Without the relic no wave must heal the base")
	check(_wave_heal_amount(["relic_healing_incense"], []) == promised,
		"회복의 향로 must heal exactly the %d its text promises" % promised)
	# 이 줄이 이 가드의 핵심이다 — 치유 타워가 있어도 더 회복하면 안 된다.
	check(_wave_heal_amount(["relic_healing_incense"], ["heal"]) == promised,
		"회복의 향로 must heal %d even with a heal tower — its text states no such bonus"
			% promised)
	# 정보창에 '증폭' 이라고 적어 두고 아무것도 안 하는 라벨이 남아 있으면 안 된다.
	var tower: WordTower = _make_tower("바위", "heal", ["relic_healing_incense"])
	check(not tower.synergy_labels.any(func(l): return str(l).contains("치유 증폭")),
		"회복의 향로 must not claim 치유 증폭 — it no longer amplifies anything")
	tower.free()


## 검사가 끝나고 트리 밖에 떠 있는 노드가 남았는지 본다.
##
## 남긴 노드는 종료 시 `Node2D 누수` **경고**로만 나온다 — 경고는 아무도 안 읽으므로
## 조용히 쌓인다. 그래서 마지막에 **실패로** 만든다.
## 실제로 이 검사가 없을 때 `test_tower_traits` 가 고아 노드 8개(= 누수 16 ObjectDB)를
## 남기고 있었고, 원인은 `check(make_tower(...))` 처럼 **검사식 안에서 만든 타워를
## 해제하지 않은 것**이었다. 해제할 방법이 없으니 눈에도 안 띄었다.
func _test_no_nodes_are_left_behind() -> void:
	var orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(orphans == 0,
		"%d orphan node(s) left behind — free everything you built before the suite ends" % orphans)


## 설명에 평면 가산(+N, %)을 적어 둔 **필드/메인 레벨 유물**의 숫자를 실제 값과 맞춘다.
##
## 이 둘은 타워가 아니라 게임 본체가 처리한다(`TowerDefenseMain.apply_relic_effect`).
## 상점 문구가 말하는 숫자와 실제 지급량이 같은지 여기서 잠근다.
func _test_flat_relics_honour_the_number_in_their_text() -> void:
	SaveManager.delete_save_file()
	# 실제 MainScene 을 세우면 `_ready` 가 사운드를 재생한다(웨이브 시작음 · 소환음).
	# 그 소리가 **아직 재생 중인 채로** 프로세스가 끝나면 `AudioStreamWAV` 와 그
	# `AudioStreamPlaybackWAV` 가 종료 시 ObjectDB 누수로 잡힌다 — 재생이 끝나기를
	# 기다리면 안 잡히므로 **운에 따라 0개였다 4개였다 한다**. 실제로 그랬다.
	# 이 검사는 유물 숫자를 보는 것이지 소리를 보는 게 아니므로, 세우는 동안만 음소거한다.
	# (`SoundEngine._play_synth_stream` 은 muted 면 스트림을 **만들지도 않는다** — 그래서 확실하다)
	var was_muted: bool = SoundEngine.muted
	SoundEngine.muted = true
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	SoundEngine.muted = was_muted
	var field = main.get_node_or_null("VBox/FieldContainer/DefenseField")
	if field == null:
		field = main.find_child("DefenseField", true, false)
	check(field != null, "The main scene needs a DefenseField for the flat relic checks")
	if field == null:
		main.free()
		return

	# 철옹성 룬 — "기지 최대 체력 +10 및 즉시 10 회복"
	var rune_amount := int(_plus_in(_relic_desc("relic_fortress_rune")))
	check(rune_amount > 0, "철옹성 룬's text must state an amount")
	field.base_hp = 20
	var max_before: int = field.max_base_hp
	var hp_before: int = field.base_hp
	main.apply_relic_effect({"id": "relic_fortress_rune", "name": "철옹성 룬"})
	check(field.max_base_hp - max_before == rune_amount,
		"철옹성 룬's text says 최대 체력 +%d but the code gave +%d"
			% [rune_amount, field.max_base_hp - max_before])
	check(field.base_hp - hp_before == rune_amount,
		"철옹성 룬's text says 즉시 %d 회복 but the code healed %d"
			% [rune_amount, field.base_hp - hp_before])

	# 황금 주사위 — "보상 리롤 주사위를 +2개 즉시 지급합니다."
	var dice_amount := int(_plus_in(_relic_desc("relic_golden_dice")))
	check(dice_amount > 0, "황금 주사위's text must state an amount")
	var dice_before: int = main.reroll_dice
	main.apply_relic_effect({"id": "relic_golden_dice", "name": "황금 주사위"})
	check(main.reroll_dice - dice_before == dice_amount,
		"황금 주사위's text says 주사위 +%d but the code gave +%d"
			% [dice_amount, main.reroll_dice - dice_before])

	# `apply_relic_effect` 는 토스트를 띄우고, 그 토스트는 **씬 트리 루트**에 레이어를 만든다
	# (`TowerDefenseMain._toast` → `/root/ToastLayer`). `main.free()` 로는 안 지워진다.
	# (게임에서는 일부러 남겨 두는 레이어다 — 토스트마다 새로 만들면 매번 깜빡인다)
	#
	# 정확히 말하면 이걸 안 치워도 **누수는 아니다** — 씬 트리 루트는 종료 시 함께 해제된다.
	# 확인했다: 지우든 말든 ObjectDB 누수는 0 이었다. 그래도 치운다 — 검사가 루트에
	# 자기 흔적을 남겨 두면, 나중에 `/root/ToastLayer` 를 보는 다른 검사가 헷갈린다.
	var toast_layer := get_tree().root.get_node_or_null("ToastLayer")
	if toast_layer != null:
		toast_layer.free()
	main.free()


## 특성 전용 유물은 '그 특성에만' 걸려야 한다.
## 전역 유물만 있으면 "내 타워가 무슨 형태인지" 가 구매 기준이 되지 못한다.
func _test_trait_relics_boost_only_their_own_trait() -> void:
	# 폭발의 뇌관
	var splash_plain = _make_tower("바위", "nature", [])
	var splash_boosted = _make_tower("바위", "nature", ["relic_blast_charge"])
	check(splash_boosted.trait_id == "splash", "The test word must actually be a splash tower")
	check(splash_boosted.damage_multiplier > splash_plain.damage_multiplier,
		"폭발의 뇌관 must raise splash damage")
	check(splash_boosted.bonus_targets > splash_plain.bonus_targets,
		"폭발의 뇌관 must widen how many enemies a splash hits")
	var chain_plain = _make_tower("함성", "skill", [])
	var chain_crossed = _make_tower("함성", "skill", ["relic_blast_charge"])
	check(is_equal_approx(chain_crossed.damage_multiplier, chain_plain.damage_multiplier)
		and chain_crossed.bonus_targets == chain_plain.bonus_targets,
		"폭발의 뇌관 must not touch chain towers")

	# 연쇄의 베틀
	var chain_boosted = _make_tower("함성", "skill", ["relic_chain_loom"])
	check(chain_boosted.damage_multiplier > chain_plain.damage_multiplier,
		"연쇄의 베틀 must raise chain damage")
	check(chain_boosted.bonus_targets > chain_plain.bonus_targets,
		"연쇄의 베틀 must add one more chain jump")

	# 관통 송곳
	var pierce_plain = _make_tower("가나", "defense", [])
	var pierce_boosted = _make_tower("가나", "defense", ["relic_pierce_auger"])
	check(pierce_boosted.trait_id == "pierce", "The test word must actually be a pierce tower")
	check(pierce_boosted.attack_range > pierce_plain.attack_range,
		"관통 송곳 must extend pierce range")
	check(pierce_boosted.bonus_targets > pierce_plain.bonus_targets,
		"관통 송곳 must pierce one more enemy")

	# 선회의 톱니 — 궤도 오브가 하나 늘어야 한다.
	var orbit_plain = _make_tower("가나", "summon", [])
	var orbit_boosted = _make_tower("가나", "summon", ["relic_orbit_gear"])
	var plain_orbit = orbit_plain.get_node_or_null("Orbit")
	var boosted_orbit = orbit_boosted.get_node_or_null("Orbit")
	check(plain_orbit != null and boosted_orbit != null, "Orbit towers must own a satellite node")
	if plain_orbit != null and boosted_orbit != null:
		check(boosted_orbit.orb_count == plain_orbit.orb_count + 1,
			"선회의 톱니 must add exactly one orbit orb (%d → %d)"
				% [plain_orbit.orb_count, boosted_orbit.orb_count])

	# 3음절에서도 같아야 한다. 예전에는 MAX_ORBS 가 3 이라 3 + 1 = 4 가 3 으로
	# 잘려서, **40G 짜리 유물이 3음절 선회 타워에서 아무 일도 안 했다**.
	# 2음절만 검사하면 이 구멍이 그대로 남는다 (2 + 1 = 3 은 잘리지 않는다).
	var three_plain = _make_tower("가나다", "summon", [])
	var three_boosted = _make_tower("가나다", "summon", ["relic_orbit_gear"])
	var three_plain_orbit = three_plain.get_node_or_null("Orbit")
	var three_boosted_orbit = three_boosted.get_node_or_null("Orbit")
	check(three_plain_orbit != null and three_boosted_orbit != null,
		"A three-syllable summon word must still be an orbit tower")
	if three_plain_orbit != null and three_boosted_orbit != null:
		check(three_boosted_orbit.orb_count == three_plain_orbit.orb_count + 1,
			"선회의 톱니 must also work on a 3-syllable tower (%d → %d)"
				% [three_plain_orbit.orb_count, three_boosted_orbit.orb_count])

	# 발화 기름 — 지속시간 배수만 올린다 (투사체 쪽 검증은 별도 테스트).
	var dot_plain = _make_tower("불꽃", "element", [])
	var dot_boosted = _make_tower("불꽃", "element", ["relic_burn_oil"])
	check(dot_boosted.trait_id == "damage_over_time", "The test word must actually be a burn tower")
	check(dot_boosted.burn_duration_multiplier > dot_plain.burn_duration_multiplier,
		"발화 기름 must extend the burn duration multiplier")

	for tower in [splash_plain, splash_boosted, chain_plain, chain_crossed, chain_boosted,
			pierce_plain, pierce_boosted, orbit_plain, orbit_boosted, dot_plain, dot_boosted,
			three_plain, three_boosted]:
		tower.free()


## 발화 기름은 '초당 피해는 그대로, 시간만 길게' 여야 총 화상 피해가 늘어난다.
## 둘을 함께 나누면 총량이 그대로라 30G 를 내고 아무것도 못 얻는다.
func _test_burn_oil_extends_total_burn_damage() -> void:
	var plain = _make_tower("불꽃", "element", [])
	var oiled = _make_tower("불꽃", "element", ["relic_burn_oil"])
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("test", 1000.0, 0.0, 0, "")
	var p_plain = ProjectileScene.instantiate()
	add_child(p_plain)
	p_plain.setup(enemy, 10.0, "fire", "damage_over_time", plain)
	var p_oiled = ProjectileScene.instantiate()
	add_child(p_oiled)
	p_oiled.setup(enemy, 10.0, "fire", "damage_over_time", oiled)

	check(is_equal_approx(p_plain.burn_dps, p_oiled.burn_dps),
		"발화 기름 must not change the burn's damage per second")
	check(p_oiled.burn_duration > p_plain.burn_duration,
		"발화 기름 must make the burn last longer")
	check(p_oiled.burn_dps * p_oiled.burn_duration > p_plain.burn_dps * p_plain.burn_duration,
		"발화 기름 must raise the total burn damage, not just spread it thinner")

	enemy.free()
	plain.free()
	oiled.free()


## 화상은 매 프레임 피해를 넣고 있었지만, 화면에는 합산된 피해 **숫자**만 떴다.
## 숫자는 순간이고 화상은 몇 초 이어지는 상태다 — "지금도 타고 있다" 를 보여 주는 것이
## 없어서 지속 피해 타워를 사 둔 플레이어는 그 타워가 일하고 있는지 알 수 없었다.
func _test_burn_shows_a_persistent_indicator() -> void:
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("test", 1000.0, 0.0, 0, "")
	check(enemy._burn_badge == null or not enemy._burn_badge.visible,
		"an enemy that is not burning must not wear a burn chip")
	enemy.apply_burn(3.0, 4.0)
	check(enemy._burn_badge != null and enemy._burn_badge.visible,
		"applying burn must raise a persistent chip")
	if enemy._burn_badge == null:
		enemy.free()
		return
	check(enemy._burn_badge.text == "화상",
		"a single burn must read 화상 (got %s)" % str(enemy._burn_badge.text))
	# 겹수 — 같은 적에게 두 번 들어가면 피해가 두 배가 되는데, 숫자만으로는 구분되지 않는다.
	enemy.apply_burn(3.0, 4.0)
	check(enemy._burn_badge.text.contains("2"),
		"a stacked burn must say how many (got %s)" % str(enemy._burn_badge.text))
	# 다 타면 내려가야 한다. 안 그러면 화면이 '계속 일하고 있다' 고 거짓말한다.
	enemy.burn_effects.clear()
	enemy._tick_burn(0.016)
	check(not enemy._burn_badge.visible,
		"the chip must come down once the burn has expired")
	enemy.free()


## 상태 칩은 하나의 줄에 담긴다. 칩마다 위치를 손으로 잡으면 질주하는 적이
## 제어 타워와 지속 피해 타워 사거리에 함께 들어갈 때 두 칩이 겹친다.
func _test_state_chips_share_one_row() -> void:
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("test", 1000.0, 0.0, 0, "")
	enemy.apply_attrs(["swift"])
	enemy.apply_burn(3.0, 4.0)
	enemy.apply_slow(0.5, 2.0)   # swift 라 거부된다 → '면역' 칩이 뜬다
	check(enemy._state_row != null, "state chips must live in a row container")
	if enemy._state_row == null:
		enemy.free()
		return
	var visible_chips: Array = enemy._state_row.get_children().filter(
		func(c): return (c as Label).visible)
	check(visible_chips.size() == 2,
		"burning and slow-immune must both be readable at once (got %d)" % visible_chips.size())
	check(enemy._slow_badge != null and enemy._burn_badge != null
		and enemy._slow_badge.get_parent() == enemy._state_row
		and enemy._burn_badge.get_parent() == enemy._state_row,
		"both chips must be children of the row, so the container positions them")
	enemy.free()


## 시너지는 '붙어 있다' 만으로는 의미가 없다 — 툴팁에 보여야 배치와 구매를 결정할 수 있다.
func _test_synergy_is_visible_on_the_tower_tooltip() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.relic_ids = ["relic_blast_charge"]
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("바위", {"category": "nature", "damage": 4, "is_unknown": true}, field)
	check(tower.trait_id == "splash", "The tooltip test needs a splash tower")
	tower.btn_select.mouse_entered.emit()
	var tooltip: String = tower.btn_select.tooltip_text
	check(tooltip.contains("폭발의 뇌관"),
		"Trait relics must be visible on the tower tooltip, not only in the shop")
	check(tooltip.contains("동시 타격"),
		"A widened multi-hit must be stated on the tooltip")
	check(tooltip.contains("폭발"),
		"The tooltip must still name the attack form")
	tower.free()
	field.free()


## 타워끼리의 시너지 — 같은 형태를 겹치거나, 서로를 보완하는 형태를 붙였을 때.
func _test_tower_pair_synergies_reward_matching_forms() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)

	# (1) 같은 특성 2개를 붙여 놓으면 '밀집'.
	var same_a = _make_tower("바위", "nature", [])
	var same_b = _make_tower("산", "nature", [])
	add_child(same_a)
	add_child(same_b)
	check(same_a.trait_id == same_b.trait_id, "The pair test needs two towers of the same trait")
	same_a.global_position = Vector2(200, 200)
	same_b.global_position = Vector2(230, 200)
	field.active_towers.assign([same_a, same_b])
	field._apply_tower_synergies()
	check(same_a.synergy_labels.any(func(l): return str(l).contains("밀집")),
		"Same-trait neighbours must gain a density synergy")
	check(same_a.damage_multiplier > 1.0 and same_b.damage_multiplier > 1.0,
		"Density synergy must raise both towers' damage")
	# 멀리 떨어뜨리면 시너지가 사라져야 한다 (인접 판정이 진짜 원인인지 확인).
	var far_a = _make_tower("바위", "nature", [])
	var far_b = _make_tower("산", "nature", [])
	add_child(far_a)
	add_child(far_b)
	far_a.global_position = Vector2(200, 200)
	far_b.global_position = Vector2(700, 200)
	field.active_towers.assign([far_a, far_b])
	field._apply_tower_synergies()
	check(not far_a.synergy_labels.any(func(l): return str(l).contains("밀집")),
		"Distant towers must not gain the density synergy")

	# (2) 서로를 보완하는 형태 조합.
	var freeze = _make_tower("얼음", "heal", [])
	var burn = _make_tower("불꽃", "element", [])
	add_child(freeze)
	add_child(burn)
	check(freeze.trait_id == "control" and burn.trait_id == "damage_over_time",
		"The pair test needs a control tower and a burn tower")
	freeze.global_position = Vector2(200, 200)
	burn.global_position = Vector2(240, 200)
	field.active_towers.assign([freeze, burn])
	field._apply_tower_synergies()
	check(freeze.synergy_labels.any(func(l): return str(l).contains("동결 작열")),
		"Complementary traits must be rewarded when adjacent")
	check(freeze.damage_multiplier > 1.0 and burn.damage_multiplier > 1.0,
		"A complementary pair must raise both towers' damage")

	# (3) 1·2·3음절이 모두 모이면 '음절 사다리'.
	var one = _make_tower("가", "basic", [])
	var two = _make_tower("가나", "basic", [])
	var three = _make_tower("가나다", "basic", [])
	for tower in [one, two, three]:
		add_child(tower)
	field.active_towers.assign([one, two, three])
	field._apply_tower_synergies()
	for tower in [one, two, three]:
		check(tower.synergy_labels.any(func(l): return str(l).contains("음절 사다리")),
			"A 1·2·3 syllable set must reward every tower")
		check(tower.damage_multiplier > 1.0, "The syllable ladder must raise damage")
	# 2음절만 둘이면 사다리가 아니다.
	var only_two_a = _make_tower("가나", "basic", [])
	var only_two_b = _make_tower("가나다", "basic", [])
	for tower in [only_two_a, only_two_b]:
		add_child(tower)
	field.active_towers.assign([only_two_a, only_two_b])
	field._apply_tower_synergies()
	check(not only_two_a.synergy_labels.any(func(l): return str(l).contains("음절 사다리")),
		"Missing a syllable length must not grant the ladder bonus")

	field.free()


## 테스트용 타워 하나. 특성은 카테고리 폴백으로 정해진다.
##
## **씬에서 만든다.** 예전에는 `WordTower.new()` — 맨 스크립트 인스턴스 — 를 썼는데,
## 그러면 자식 노드가 하나도 없어서 호출자가 `add_child()` 하는 순간 `_ready()` 의
## `@onready` 여섯 개가 전부 실패했다(`IconContainer`, `IconContainer/IconSprite`,
## `LabelBigWord`, `LabelWord`, `RangeCircle`, `BtnSelect`). 한 번 실행에 ERROR 66줄이
## 쏟아져 **테스트 출력을 회귀 신호로 쓸 수 없게** 만들었고, 무엇보다 이 테스트가
## 검증하던 타워는 화면에 존재하는 타워가 아니었다.
## `setup_tower()` 는 노드 접근을 전부 `if node:` 로 감싸고 있으므로 트리에 들어가기
## 전에 불러도 안전하다 — 순서를 바꾸지 않고 씬만 바꾼다.
func _make_tower(syllable: String, category: String, relics: Array) -> WordTower:
	var field = DefenseFieldScript.new()
	field.relic_ids = relics
	var tower: WordTower = WordTowerScene.instantiate()
	tower.setup_tower(syllable, {"category": category, "damage": 4, "is_unknown": true}, field)
	_stub_fields.append(field)
	return tower


func _test_tower_slots_follow_marked_map_positions() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	# 발판 좌표는 원본 맵 좌표계(1024x352)로 정의되고, 화면 좌표는 map_to_screen()
	# 하나만 거친다. 막을 바꾸면 배경/경로/발판이 함께 갈아끼워져야 한다.
	check(field.tower_slots.size() == DefenseFieldScript.MAX_SLOT_COUNT,
		"Field must always expose every tower pad")
	for act in range(1, 4):
		field.set_act(act)
		var expected: Array = DefenseFieldScript.ACT_SLOTS[act]
		check(expected.size() == field.tower_slots.size(),
			"Act %d must map one pad coordinate per slot" % act)
		for i in range(expected.size()):
			var want: Vector2 = field.map_to_screen(expected[i])
			check(field.tower_slots[i].position.is_equal_approx(want),
				"Act %d tower pad %d is not at its mapped position" % [act, i + 1])
	field.free()


func _test_act_switch_swaps_map_art() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	var act1_texture = field.background.texture
	check(act1_texture == DefenseFieldScript.ACT_MAP_TEXTURES[1], "Act 1 must start on the garden map")
	field.set_act(2)
	check(field.current_act == 2, "Switching acts must update the act counter")
	check(field.background.texture == DefenseFieldScript.ACT_MAP_TEXTURES[2],
		"Act 2 must swap in the mine map")
	field.set_act(3)
	check(field.background.texture == DefenseFieldScript.ACT_MAP_TEXTURES[3],
		"Act 3 must swap in the sky citadel map")
	# 경로와 발판도 함께 갈아끼워져야 한다.
	check(field.path_2d.curve.point_count == (DefenseFieldScript.ACT_PATHS[3] as Array).size(),
		"Act 3 must rebuild the enemy path")
	field.free()


func _test_three_slots_start_unlocked() -> void:
	var field = DefenseFieldScript.new()
	check(field.unlocked_slot_count == 3 and field.MAX_UNLOCKED_SLOTS == 3, "A game must have exactly three tower slots")
	field.free()


func _test_towers_keep_assigned_slot_positions() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	# 이 테스트는 '논리 슬롯 → 발판' 매핑만 본다. 기본 배치는 이제 경로 커버리지로
	# 계산되므로(고정 [0,1,2] 가 아니다) 여기서 명시적으로 고정한다.
	field.tower_positions.assign([0, 1, 2])
	field.update_towers_from_parsed_list([{}, {"syllable": String.chr(0xB8E8), "word_data": {"category": "basic", "damage": 4, "is_unknown": true}}, {}, {}])
	check(not field.tower_slots[0].get_children().any(func(child): return child is WordTower), "Empty slot must stay empty")
	check(field.tower_slots[1].get_children().any(func(child): return child is WordTower), "Slot 2 tower must stay in slot 2")
	field.free()


func _test_towers_can_move_and_swap_positions() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	# 이동/스왑 의미론을 보는 테스트다. 기본 배치(경로 커버리지 기반)에 의존하면
	# 발판 좌표가 바뀔 때마다 깨지므로 시작 배치를 명시적으로 고정한다.
	field.tower_positions.assign([0, 1, 2])
	field.update_towers_from_parsed_list([
		{"syllable": "불", "word_data": {"category": "element", "damage": 4, "is_unknown": true}},
		{"syllable": "물", "word_data": {"category": "element", "damage": 4, "is_unknown": true}}
	])
	check(field.move_tower(0, 5), "Tower must move to an empty map slot")
	check(field.tower_positions[0] == 5 and field.active_towers[0].get_parent() == field.tower_slots[5], "Moved tower must use the target slot")
	check(field.move_tower(1, 5), "Tower must swap with an occupied map slot")
	check(field.tower_positions.slice(0, 2) == [1, 5], "Occupied tower positions must swap")
	# 웨이브 중에도 재배치할 수 있어야 한다 (사용자 신고: "타워 이동이 안되").
	field.is_wave_running = true
	field.is_planning_phase = false
	check(field.move_tower(0, 2), "Towers must be repositionable while a wave is running")
	check(field.tower_positions[0] == 2, "A mid-wave move must actually change the slot")
	check(not field.move_tower(0, field.tower_slots.size()), "Out-of-range slots must be rejected")
	field.free()


func _test_tower_drag_moves_and_click_still_works() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.update_towers_from_parsed_list([
		{"syllable": "불", "word_data": {"category": "element", "damage": 4, "is_unknown": true}}
	])
	var tower = field.active_towers[0]
	var clicks := []
	tower.tower_clicked.connect(func(t): clicks.append(t))
	# 1) 그냥 클릭하면 정보가 열린다.
	tower.begin_drag(Vector2.ZERO)
	tower.end_drag(Vector2.ZERO)
	check(clicks.size() == 1, "A plain click must open the tower info")
	# 2) 드래그하면 가장 가까운 발판으로 옮겨진다.
	clicks.clear()
	var target: Node2D = field.tower_slots[4]
	tower.begin_drag(target.global_position)
	tower.update_drag(target.global_position + Vector2(24, 0))
	check(tower._was_dragged, "Moving more than 6px must count as a drag")
	tower.end_drag(target.global_position)
	check(field.tower_positions[0] == 4, "Dropping near a pad must move the tower there")
	check(clicks.is_empty(), "A drag must not also fire the click action")
	check(not tower._was_dragged and not tower._dragging, "Drag state must reset when the button is released")
	# 3) 드래그 직후의 첫 클릭이 씹히면 안 된다 (예전 _was_dragged 래치 버그).
	clicks.clear()
	tower.begin_drag(Vector2.ZERO)
	tower.end_drag(Vector2.ZERO)
	check(clicks.size() == 1, "The first click after a drag must not be swallowed")
	field.free()


## 기본 타워 배치가 경로를 제대로 덮는지.
##
## 예전에는 tower_positions 가 [0, 1, 2] 로 고정이었다. 실측(사거리 150px, 합집합):
##   1막: 기본 414px / 경로 1329.7px = 31.1%  vs 최적 [5,1,8]  1116.9px = 84.0%
##   2막: 기본 474px / 경로 1215.0px = 39.0%  vs 최적 [10,5,1] 1125.4px = 92.6%
##   3막: 기본 412px / 경로  966.1px = 42.6%  vs 최적 [2,6,9]   851.2px = 88.1%
## 즉 신규 플레이어의 첫 타워 3개가 경로의 3~4할만 덮었다. 예전 1막 pad 2 는 경로에서
## 148px 떨어져 사거리에 겨우 걸려 커버가 43px(3.2%) 뿐이었다 — 타워 하나가 놀았다.
func _test_default_tower_placement_covers_the_route() -> void:
	var field = DefenseFieldScene.instantiate()
	add_child(field)

	# 사거리는 타워가 실제로 시작하는 값과 같아야 한다. 다르면 이 계산이 무의미해진다.
	var range_px: float = WordTower.BASE_ATTACK_RANGE

	for act in range(1, 4):
		field.set_act(act)
		var picked: Array = field.tower_positions.duplicate()
		check(picked.size() == 3, "Act %d must default to three pads" % act)
		check(picked[0] != picked[1] and picked[1] != picked[2] and picked[0] != picked[2],
			"Act %d default pads must be distinct" % act)

		var total: float = field.path_length(act)
		check(total > 0.0, "Act %d must have a path to measure" % act)
		var covered: float = field.covered_path_length(act, picked, range_px)
		check(covered >= total * float(DEFAULT_COVERAGE_FLOOR[act]),
			"Act %d default pads must cover >=%d%% of the route (got %.1f%%)"
				% [act, int(float(DEFAULT_COVERAGE_FLOOR[act]) * 100.0), 100.0 * covered / total])

		# 고정 배치 [0,1,2] 대비 최소 DEFAULT_COVERAGE_MULTIPLE 배는 덮어야 한다.
		var naive: float = field.covered_path_length(act, [0, 1, 2], range_px)
		check(covered >= naive * DEFAULT_COVERAGE_MULTIPLE,
			"Act %d default pads must beat the naive [0,1,2] layout by %.1fx (%.0f vs %.0f)"
				% [act, DEFAULT_COVERAGE_MULTIPLE, covered, naive])

		# 기본 발판 하나하나가 '죽어' 있으면 안 된다. 예전 1막 pad 2 가 3.2% 였다.
		for pad in picked:
			var one: float = field.pad_coverage(act, int(pad), range_px)
			check(one >= total * 0.10,
				"Act %d default pad %d must not be dead (covers %.1f%%)"
					% [act, int(pad), 100.0 * one / total])

		# ── 순서 불변식 ──────────────────────────────────────────────────────
		# 반환값은 '집합' 이 아니라 '수열' 이다 — 플레이어가 타워를 하나씩 짓기 때문이다.
		# 1) 첫 자리는 고른 집합 안에서 '단독 커버리지가 가장 큰' 발판이어야 한다.
		#    (예전 집합 전수조사는 이걸 지키지 않아 1라운드 누출이 0 → 1 로 갈렸다)
		for other in picked.slice(1):
			check(field.pad_coverage(act, int(picked[0]), range_px) >= field.pad_coverage(act, int(other), range_px),
				"Act %d first pad %d must be the strongest standalone pad in the set (not %d)"
					% [act, int(picked[0]), int(other)])

		# 2) 순서를 정하는 과정에서 합집합이 손해 보면 안 된다 —
		#    전체 조합 중 최선의 합집합에서 PLACEMENT_COVERAGE_EPSILON 이내여야 한다.
		var best_union := 0.0
		for a in range(field.ACT_SLOTS[act].size()):
			for b in range(a + 1, field.ACT_SLOTS[act].size()):
				for c in range(b + 1, field.ACT_SLOTS[act].size()):
					best_union = maxf(best_union, field.covered_path_length(act, [a, b, c], range_px))
		check(covered >= best_union * (1.0 - field.PLACEMENT_COVERAGE_EPSILON),
			"Act %d default pads must stay within %.1f%% of the best union (%.1f vs %.1f)"
				% [act, field.PLACEMENT_COVERAGE_EPSILON * 100.0, covered, best_union])

	# 논리 슬롯 → 발판 매핑은 기본 배치에서도 지켜져야 한다.
	field.set_act(1)
	field.update_towers_from_parsed_list([
		{"syllable": "불", "word_data": {"category": "element", "damage": 4, "is_unknown": true}}
	])
	var expected_pad: int = field.tower_positions[0]
	check(field.active_towers[0].get_parent() == field.tower_slots[expected_pad],
		"A tower in logical slot 0 must stand on the default pad for that slot")

	# 새 게임/로드 경로도 같은 기본값을 써야 한다 (저장된 배치가 없을 때).
	field.restore_tower_positions([])
	check(str(field.tower_positions) == str(field.default_tower_positions(1, 3, range_px)),
		"An empty save must restore the coverage-based default, not [0,1,2]")

	field.free()

## ── 선회 방향이 '보이는 것' 을 넘어 '전투' 를 바꾸는가 ──────────────────────────
##
## 궤도 오브는 반지름 76px 를 2.6초에 한 바퀴 돈다 → 183.6 px/s.
## 판정 반지름은 HIT_RADIUS + HIT_SLACK = 23px 이므로 지름 46px.
## 적이 60px/s 로 지나갈 때 오브가 적과 '같은 쪽' 으로 돌면 상대속도가 느려져
## 스치는 시간이 길어지고, 재타격 대기(0.3초)를 넘겨 한 대 더 들어간다.
## 반대쪽에서 마주 돌면 짧게 스쳐 한 대로 끝난다.
##
## 그래서 방향은 연출이 아니라 배치다. 그리고 '유리한 방향' 은 적이 궤도의
## 어느 쪽으로 지나가는지에 따라 뒤집힌다 — 아래로 지나가면 반시계가,
## 위로 지나가면 시계가 이긴다. 그래서 전역 스위치가 아니라 타워마다 골라야 한다.
func _test_orbit_direction_changes_how_often_it_hits() -> void:
	# 적이 궤도 '아래' 를 +x 로 지나간다 → 따라 도는 쪽은 반시계.
	var below_chasing := _count_orbit_hits(false, 1.0)
	var below_sweeping := _count_orbit_hits(true, 1.0)
	# 적이 궤도 '위' 를 +x 로 지나간다 → 유리한 방향이 뒤집힌다.
	var above_chasing := _count_orbit_hits(true, -1.0)
	var above_sweeping := _count_orbit_hits(false, -1.0)

	print("    선회 방향 실측 — 아래로 지나갈 때 반시계 %d대 / 시계 %d대, 위로 지나갈 때 시계 %d대 / 반시계 %d대"
		% [below_chasing, below_sweeping, above_chasing, above_sweeping])
	check(below_chasing > below_sweeping,
		"Below the orbit, spinning the way the monster travels must land more hits (%d vs %d)"
			% [below_chasing, below_sweeping])
	check(above_chasing > above_sweeping,
		"Above the orbit the winning direction must flip (%d vs %d)"
			% [above_chasing, above_sweeping])


## 선회가 '한 번 스치고 끝나는' 특성이 아니어야 한다.
##
## 2026-09-19 실측(probe_orbit.gd): 적 한 마리가 선회 발판 앞에 머무는 시간은
## 평균 0.80초, 가장 잘 맞는 발판에서도 2.50초. 그런데 한 바퀴가 2.6초에
## 재타격 대기가 0.3초였으므로, 오브는 적이 지나가는 동안 **한 번 스치고
## 한 대만** 넣었다. 1음절 선회가 적 한 마리에게 넣는 총 피해는 4.5 —
## 가장 약한 다른 특성(유성 31.0)의 15%, 최강(저격 84.3)의 5% 였다.
##
## 이건 밸런스 이전에 '설명대로 동작하지 않는' 상태였다. 툴팁은 "닿은 적을
## 계속 때립니다" 라고 말하는데 실제로는 계속 때리지 않았다.
##
## 그래서 여기서는 두 가지 최소 조건만 잠근다:
##   ① 궤도 위에 서 있는 적을 3초 동안 때리면 여러 대가 들어간다
##   ② 음절이 길수록(오브가 많을수록) 그 대수가 그만큼 늘어난다
##      — 코드가 "긴 단어의 보상" 이라고 약속한 바로 그 성질이다.
##
## 대수의 '절대값'(밸런스)은 여기서 잠그지 않는다. 밸런스는 발판·경로·속성에
## 따라 달라지고, 그건 tools/OrbitBalanceProbe.gd 로 따로 잰다.
## 테스트가 잠그는 것은 '죽지 않았는가' 뿐이다.
func _test_orbit_keeps_hitting_and_rewards_longer_words() -> void:
	var one := _orbit_hits_on_ring("가")
	var three := _orbit_hits_on_ring("가나다")
	check(one >= 2,
		"An orb must sweep past a target standing on its ring more than once in 3s (got %d)" % one)
	check(three >= one * 2,
		"A three-orb orbit must land far more hits than a one-orb orbit (%d vs %d)"
			% [three, one])


## 궤도 위에 적을 세워 두고 sec 초 동안 때린 횟수.
##
## 경로·발판과 무관하게 '오브가 적을 지나가는가' 라는 성질 **하나만** 본다.
## 적이 궤도 원 위에 정지해 있으므로 지나가는 적보다 훨씬 유리한 조건이다 —
## 여기서조차 못 맞으면 그건 기하 문제가 아니라 기능이 죽은 것이다.
func _orbit_hits_on_ring(syllable: String, sec := 3.0) -> int:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.gold = 0

	var tower = WordTowerScene.instantiate()
	field.add_child(tower)
	tower.global_position = Vector2(600.0, 400.0)
	tower.setup_tower(syllable, {"category": "summon", "damage": 4, "is_unknown": true}, field)
	var orbit = tower.get_node_or_null("Orbit")
	if orbit == null:
		check(false, "The orbit measurement needs an orbit tower for '%s'" % syllable)
		field.free()
		return 0
	# 엔진이 같이 돌리면 한 걸음이 두 번 진행된다 — 여기서는 손으로만 돌린다.
	tower.set_process(false)
	orbit.set_process(false)

	field._spawn_enemy({
		"name": "표적", "type": "swarm", "hp": 1000000.0, "shield": 0.0,
		"speed": 60.0, "gold": 0, "icon": "", "attrs": [], "base_damage": 0,
	})
	var spawned: Array = field.get_enemies()
	if spawned.is_empty():
		check(false, "The orbit measurement needs a spawned monster")
		field.free()
		return 0
	var enemy = spawned[0]
	enemy.set_process(false)
	enemy.set_physics_process(false)

	var dt := 1.0 / 60.0
	# 시작 각도를 적의 반대편에 두면 첫 통과가 반드시 일어난다 — 운을 뺀다.
	orbit._angle = PI
	for i in range(int(sec / dt)):
		# 적은 궤도 원 위에 그대로 선다. 매 프레임 다시 놓아 흔들리지 않게 한다.
		enemy.global_position = orbit.global_position + Vector2(orbit.orbit_radius, 0.0)
		orbit._process(dt)

	# 타격 수 = 누적 피해 / 한 대 피해. 둘 다 정확한 값이라 반올림으로 복원된다.
	var per_hit: float = tower.orbit_damage() * enemy.damage_multiplier_for("orbit")
	var total: float = float(field.tower_damage.get(syllable, 0.0))
	var hits := int(round(total / maxf(per_hit, 0.001)))
	field.free()
	return hits


## 적 하나를 궤도 옆으로 지나가게 하고, 그 동안 들어간 타격 수를 센다.
##
## side = +1 → 적이 궤도 '아래' 를, -1 → '위' 를 지난다. 적은 항상 +x 로 간다.
## 두 측정이 '같은 순간 같은 자리에서' 만나도록 시작 각도를 방향별로 맞춘다.
## 그러지 않으면 위상 차이가 방향 차이처럼 보인다.
func _count_orbit_hits(clockwise: bool, side: float) -> int:
	var field = DefenseFieldScene.instantiate()
	add_child(field)
	field.gold = 0

	var tower = WordTowerScene.instantiate()
	field.add_child(tower)
	tower.global_position = Vector2(600.0, 400.0)
	tower.setup_tower("가", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	var orbit = tower.get_node_or_null("Orbit")
	if orbit == null or orbit.orb_count != 1:
		check(false, "The direction measurement needs a single-orb orbit tower")
		field.free()
		return 0
	# 엔진이 같이 돌리면 한 걸음이 두 번 진행된다 — 여기서는 손으로만 돌린다.
	tower.set_process(false)
	orbit.set_process(false)

	field._spawn_enemy({
		"name": "표적", "type": "swarm", "hp": 1000000.0, "shield": 0.0,
		"speed": 60.0, "gold": 0, "icon": "", "attrs": [], "base_damage": 0,
	})
	var spawned: Array = field.get_enemies()
	if spawned.is_empty():
		check(false, "The direction measurement needs a spawned monster")
		field.free()
		return 0
	# 표적은 경로를 걷지 않는다 — 궤도 옆을 일정한 속도로 지나가게 직접 놓는다.
	var enemy = spawned[0]
	enemy.set_process(false)
	enemy.set_physics_process(false)

	var radius: float = orbit.orbit_radius
	var offset_y := radius * side
	var speed := 60.0
	var meet_time := 2.0
	var start_x := -speed * meet_time
	var omega: float = TAU / orbit.TURN_SECONDS
	# 방향을 실제로 뒤집는다. 시작 각도만 바꾸면 위상만 달라지고 방향은 그대로다.
	orbit.set_clockwise(clockwise)
	# 만나는 순간(meet_time)에 오브가 '적이 지나는 쪽' 끝에 오도록 시작 각도를 맞춘다.
	var meet_angle: float = PI * 0.5 if side > 0.0 else -PI * 0.5
	var dir := 1.0 if clockwise else -1.0
	orbit._angle = fposmod(meet_angle - dir * omega * meet_time, TAU)

	var dt := 1.0 / 60.0
	var steps := int((meet_time + 1.0) / dt)
	var hit_frames: Array = []
	var min_dist := 9999.0
	for i in range(steps):
		# 오브는 _process 안에서 '먼저' 진행한 뒤 판정하므로 표적도 같은 시각에 맞춘다.
		var t := float(i + 1) * dt
		enemy.global_position = tower.global_position + Vector2(start_x + speed * t, offset_y)
		var before := float(field.tower_damage.get("가", 0.0))
		orbit._process(dt)
		if float(field.tower_damage.get("가", 0.0)) > before:
			hit_frames.append(i + 1)
		min_dist = minf(min_dist, orbit.orb_positions()[0].distance_to(
			enemy.global_position - orbit.global_position))

	# 타격 수 = 누적 피해 / 한 대 피해. 둘 다 정확한 값이라 반올림으로 복원된다.
	var per_hit: float = tower.orbit_damage() * enemy.damage_multiplier_for("orbit")
	var total: float = float(field.tower_damage.get("가", 0.0))
	var hits := int(round(total / per_hit)) if per_hit > 0.0 else 0
	# 최근접 거리가 0 이어야 두 측정이 '같은 자리에서' 만난 것 — 아니면 위상이 섞인 것이다.
	print("      %s/%s — 타격 %s (최근접 %.1fpx)" % [
		"아래" if side > 0.0 else "위", "시계" if clockwise else "반시계", str(hit_frames), min_dist])
	field.free()
	return hits
