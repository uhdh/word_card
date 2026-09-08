# DefenseField.gd
# 타워 디펜스 맵 필드, 적 이동 경로(Path2D), 타워 슬롯들 및 3막 4웨이브(총 12웨이브) 관리
class_name DefenseField
extends Control

signal base_hp_changed(current: int, max: int)
signal gold_changed(current: int)
signal wave_status_changed(act: int, max_act: int, wave: int, max_wave: int, is_running: bool)
signal wave_cleared(act: int, wave: int, bonus_gold: int)
signal act_cleared(act: int, bonus_gold: int)
signal tower_info_requested(tower: WordTower)
signal game_over(is_victory: bool)

@export var max_base_hp: int = 20
var base_hp: int = 20
var gold: int = 40

var current_act: int = 1
const MAX_ACTS: int = 3

var current_wave: int = 0
const MAX_WAVES_PER_ACT: int = 6
const SPAWN_INTERVAL := 0.65

var is_wave_running: bool = false
var spawn_queue: Array = []
var spawn_timer: float = 0.0

@onready var path_2d: Path2D = $Path2D
@onready var tower_slots_container: Node2D = $TowerSlots
@onready var projectiles_layer: Node2D = $ProjectilesLayer
@onready var road_line: Line2D = $RoadLine

var enemy_unit_scene = preload("res://scenes/tower/EnemyUnit.tscn")
var word_tower_scene = preload("res://scenes/tower/WordTower.tscn")

var tower_slots: Array[Node2D] = []
var active_towers: Array[WordTower] = []
var first_magic_circle_pending := true
var relic_ids: Array = []

const MAX_UNLOCKED_SLOTS: int = 4
var unlocked_slot_count: int = 3

func has_relic(id: String) -> bool:
	return id in relic_ids

const MAP_PATH_POINTS: Array[Vector2] = [
	Vector2(0, 76), Vector2(256, 81), Vector2(320, 145), Vector2(344, 191),
	Vector2(400, 279), Vector2(472, 265), Vector2(512, 172), Vector2(560, 88),
	Vector2(656, 112), Vector2(696, 288), Vector2(784, 300), Vector2(840, 217),
	Vector2(872, 165), Vector2(960, 110)
]
const MAP_SLOT_POINTS: Array[Vector2] = [
	Vector2(255, 140), Vector2(405, 137), Vector2(575, 218), Vector2(760, 190)
]

const ACT_NAMES = {
	1: "초원의 문자",
	2: "고대 유적의 어둠",
	3: "차원의 심연"
}

func _ready() -> void:
	base_hp = max_base_hp
	base_hp_changed.emit(base_hp, max_base_hp)
	gold_changed.emit(gold)

	# Collect tower slot nodes
	for child in tower_slots_container.get_children():
		tower_slots.append(child)

	resized.connect(_layout_sanctuary)
	_layout_sanctuary()
	_update_slot_lock_visuals()

func _update_slot_lock_visuals() -> void:
	for i in range(tower_slots.size()):
		var is_unlocked = i < unlocked_slot_count
		tower_slots[i].modulate = Color(1, 1, 1, 1.0) if is_unlocked else Color(1, 1, 1, 0.35)
		var lbl = tower_slots[i].get_node_or_null("SlotBg/SlotLabel")
		if lbl:
			lbl.text = ("%d번 슬롯" % (i + 1)) if is_unlocked else "🔒 잠김"

func _layout_sanctuary() -> void:
	var map_scale := Vector2(size.x / 1024.0, size.y / 352.0)
	var curve := Curve2D.new()
	for point in MAP_PATH_POINTS:
		curve.add_point(point * map_scale)
	path_2d.curve = curve
	for i in range(mini(tower_slots.size(), MAP_SLOT_POINTS.size())):
		tower_slots[i].position = MAP_SLOT_POINTS[i] * map_scale

	if path_2d and path_2d.curve:
		var pts = path_2d.curve.get_baked_points()
		if road_line: road_line.points = pts
		var road_outer = get_node_or_null("RoadOuter") as Line2D
		if road_outer: road_outer.points = pts
		var road_inner = get_node_or_null("RoadInner") as Line2D
		if road_inner: road_inner.points = pts

func _process(delta: float) -> void:
	if is_wave_running and not spawn_queue.is_empty():
		spawn_timer += delta
		if spawn_timer >= SPAWN_INTERVAL:
			spawn_timer = 0.0
			var next_enemy_data = spawn_queue.pop_front()
			_spawn_enemy(next_enemy_data)

	elif is_wave_running and spawn_queue.is_empty():
		var alive_enemies = get_enemies()
		if alive_enemies.is_empty():
			_on_wave_cleared()

func start_next_wave() -> void:
	if is_wave_running:
		return

	current_wave += 1
	if current_wave > MAX_WAVES_PER_ACT:
		# Next Act Transition
		if current_act < MAX_ACTS:
			current_act += 1
			current_wave = 1
		else:
			game_over.emit(true)
			return

	is_wave_running = true
	spawn_timer = 0.0
	spawn_queue.clear()

	# Build monster spawn list by Act and Wave
	_build_wave_monsters(current_act, current_wave)

	wave_status_changed.emit(current_act, MAX_ACTS, current_wave, MAX_WAVES_PER_ACT, true)
	SoundEngine.play_summon()

func _build_wave_monsters(act: int, wave: int) -> void:
	var hp = [[8.0, 6.0, 12.0, 8.0, 5.0], [30.0, 20.0, 40.0, 30.0, 15.0], [45.0, 30.0, 55.0, 40.0, 22.0]][act - 1]
	var normal = {"name": "%d막 침략자" % act, "type": "normal", "hp": hp[0], "speed": 75.0 + act * 5.0, "gold": 1, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"}
	var fast = {"name": "%d막 질풍병" % act, "type": "fast", "hp": hp[1], "speed": 145.0 + act * 10.0, "gold": 1, "icon": "res://assets/monsters/monster_slime_2_32px_pastel.png"}
	var armored = {"name": "%d막 중갑병" % act, "type": "armored", "hp": hp[2], "shield": hp[3], "speed": 55.0 + act * 3.0, "gold": 2, "icon": "res://assets/monsters/monster_boar_2_32px_pastel.png"}
	var swarm = {"name": "%d막 군집 잡몹" % act, "type": "swarm", "hp": hp[4], "speed": 95.0 + act * 5.0, "gold": 1, "icon": "res://assets/monsters/monster_slime_1_32px_pastel.png"}
	var wave_counts = [
		[[6, 0, 1], [6, 2, 2], [13, 0, 0], [8, 4, 4], [18, 0, 0], [8, 3, 3]],
		[[8, 2, 2], [10, 3, 3], [20, 0, 0], [12, 6, 6], [28, 0, 0], [10, 5, 4]],
		[[10, 3, 3], [12, 4, 4], [24, 0, 0], [14, 7, 7], [32, 0, 0], [12, 6, 5]]
	]
	var counts = wave_counts[act - 1][wave - 1]
	if wave in [3, 5]:
		for i in range(counts[0]): spawn_queue.append(swarm.duplicate())
		return
	if wave == MAX_WAVES_PER_ACT:
		spawn_queue.append({"name": "%d막 우두머리" % act, "type": "boss", "hp": [150.0, 260.0, 450.0][act - 1], "speed": 40.0, "gold": [15, 22, 30][act - 1], "icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png"})
	for i in range(counts[0]): spawn_queue.append(normal.duplicate())
	for i in range(counts[1]): spawn_queue.append(fast.duplicate())
	for i in range(counts[2]): spawn_queue.append(armored.duplicate())

func _spawn_enemy(enemy_data: Dictionary) -> void:
	if enemy_unit_scene == null or path_2d == null:
		return
	var enemy = enemy_unit_scene.instantiate() as EnemyUnit
	path_2d.add_child(enemy)
	enemy.init_enemy(enemy_data["name"], enemy_data["hp"], enemy_data["speed"], enemy_data["gold"], enemy_data["icon"], enemy_data.get("shield", 0.0))
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)

func _on_enemy_died(enemy: EnemyUnit) -> void:
	gold += enemy.gold_reward + (1 if has_relic("relic_bounty_coin") else 0)
	gold_changed.emit(gold)
	SoundEngine.play_coin()

func _on_enemy_reached_base(enemy: EnemyUnit, dmg: int) -> void:
	base_hp = maxi(0, base_hp - dmg)
	base_hp_changed.emit(base_hp, max_base_hp)
	SoundEngine.play_hit()
	if base_hp <= 0:
		game_over.emit(false)

func _wave_clear_bonus() -> int:
	return 20 if current_wave >= MAX_WAVES_PER_ACT else 10

func _on_wave_cleared() -> void:
	is_wave_running = false
	wave_status_changed.emit(current_act, MAX_ACTS, current_wave, MAX_WAVES_PER_ACT, false)

	if unlocked_slot_count < mini(MAX_UNLOCKED_SLOTS, tower_slots.size()):
		unlocked_slot_count += 1
		_update_slot_lock_visuals()

	var is_act_final = (current_wave >= MAX_WAVES_PER_ACT)
	var bonus_gold = _wave_clear_bonus()
	gold += bonus_gold
	if has_relic("relic_healing_incense"):
		var extra = 1 if active_towers.any(func(t): return t.word_data.get("category") == "heal") else 0
		base_hp = mini(max_base_hp, base_hp + 2 + extra)
		base_hp_changed.emit(base_hp, max_base_hp)
	for i in range(active_towers.size() - 1):
		var pair = [active_towers[i].word_data.get("category"), active_towers[i + 1].word_data.get("category")]
		if "defense" in pair and "heal" in pair:
			base_hp = mini(max_base_hp, base_hp + 1)
			base_hp_changed.emit(base_hp, max_base_hp)
			break
	gold_changed.emit(gold)
	SoundEngine.play_victory()

	if is_act_final:
		if current_act >= MAX_ACTS:
			game_over.emit(true)
		else:
			act_cleared.emit(current_act, bonus_gold)
	else:
		wave_cleared.emit(current_act, current_wave, bonus_gold)

func update_towers_from_parsed_list(parsed_list: Array) -> void:
	for t in active_towers:
		if is_instance_valid(t):
			t.queue_free()
	active_towers.clear()

	for slot_node in tower_slots:
		var lbl = slot_node.get_node_or_null("SlotBg/SlotLabel")
		if lbl: lbl.visible = true

	for i in range(mini(parsed_list.size(), unlocked_slot_count)):
		var item = parsed_list[i]
		if item.is_empty(): continue
		var slot_node = tower_slots[i]
		var lbl = slot_node.get_node_or_null("SlotBg/SlotLabel")
		if lbl: lbl.visible = false
		
		var tower = word_tower_scene.instantiate() as WordTower
		slot_node.add_child(tower)
		tower.setup_tower(item["syllable"], item["word_data"], self, first_magic_circle_pending)
		if has_relic("relic_range_rune"):
			tower.attack_range *= 1.15
		first_magic_circle_pending = false
		tower.tower_clicked.connect(func(t): tower_info_requested.emit(t))
		active_towers.append(tower)
	_apply_tower_synergies()

func _apply_tower_synergies() -> void:
	for i in range(active_towers.size() - 1):
		var left = active_towers[i]
		var right = active_towers[i + 1]
		var a = left.word_data.get("category", "")
		var b = right.word_data.get("category", "")
		if a == "element" and b == "element":
			left.damage_multiplier *= 1.15; right.damage_multiplier *= 1.15
			left.synergy_labels.append("원소 공명"); right.synergy_labels.append("원소 공명")
		if a == "weapon" and b in ["skill", "buff"]:
			left.attack_interval *= 0.85; left.synergy_labels.append("전술 연계")
		if b == "weapon" and a in ["skill", "buff"]:
			right.attack_interval *= 0.85; right.synergy_labels.append("전술 연계")
		if "defense" in [a, b] and "heal" in [a, b]:
			left.synergy_labels.append("수호의 순환"); right.synergy_labels.append("수호의 순환")
		if has_relic("relic_open_chime") and not WordSynergy.analyze(left.syllable)["has_final"] and not WordSynergy.analyze(right.syllable)["has_final"]:
			left.attack_interval *= 0.88; right.attack_interval *= 0.88
			left.synergy_labels.append("무받침 풍경"); right.synergy_labels.append("무받침 풍경")

func get_enemies() -> Array:
	var list = []
	if path_2d:
		for child in path_2d.get_children():
			if child is EnemyUnit and not child.is_dead:
				list.append(child)
	return list

func add_projectile(proj: Projectile) -> void:
	if projectiles_layer:
		projectiles_layer.add_child(proj)
