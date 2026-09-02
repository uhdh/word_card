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
const MAX_WAVES_PER_ACT: int = 4

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

	# Setup Road Line from Path2D curve
	if path_2d and path_2d.curve and road_line:
		road_line.points = path_2d.curve.get_baked_points()

func _process(delta: float) -> void:
	if is_wave_running and not spawn_queue.is_empty():
		spawn_timer += delta
		if spawn_timer >= 1.1:
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
	match act:
		1: # 제 1막: 초원의 문자
			match wave:
				1:
					for i in range(5):
						spawn_queue.append({"name": "낱자 슬라임", "hp": 16.0, "speed": 85.0, "gold": 4, "icon": "res://assets/monsters/monster_slime_1_32px_pastel.png"})
				2:
					for i in range(3):
						spawn_queue.append({"name": "낱자 슬라임", "hp": 18.0, "speed": 90.0, "gold": 4, "icon": "res://assets/monsters/monster_slime_2_32px_pastel.png"})
					for i in range(2):
						spawn_queue.append({"name": "사나운 멧돼지", "hp": 30.0, "speed": 65.0, "gold": 8, "icon": "res://assets/monsters/monster_boar_1_32px_pastel.png"})
				3:
					for i in range(3):
						spawn_queue.append({"name": "가시 넝쿨", "hp": 25.0, "speed": 75.0, "gold": 6, "icon": "res://assets/monsters/monster_vine_1_32px_pastel.png"})
					for i in range(3):
						spawn_queue.append({"name": "사나운 멧돼지", "hp": 35.0, "speed": 70.0, "gold": 8, "icon": "res://assets/monsters/monster_boar_2_32px_pastel.png"})
				4: # 1막 보스
					spawn_queue.append({"name": "서예 골렘 (1막 BOSS)", "hp": 150.0, "speed": 45.0, "gold": 35, "icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png"})
					for i in range(4):
						spawn_queue.append({"name": "낱자 슬라임", "hp": 20.0, "speed": 95.0, "gold": 4, "icon": "res://assets/monsters/monster_slime_1_32px_pastel.png"})

		2: # 제 2막: 고대 유적의 어둠
			match wave:
				1:
					for i in range(4):
						spawn_queue.append({"name": "먹물 악령", "hp": 45.0, "speed": 65.0, "gold": 10, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
				2:
					for i in range(3):
						spawn_queue.append({"name": "유적 가고일", "hp": 55.0, "speed": 75.0, "gold": 12, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
					for i in range(2):
						spawn_queue.append({"name": "먹물 악령", "hp": 50.0, "speed": 70.0, "gold": 10, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
				3:
					for i in range(4):
						spawn_queue.append({"name": "유적 가고일", "hp": 65.0, "speed": 80.0, "gold": 14, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
					for i in range(2):
						spawn_queue.append({"name": "사나운 멧돼지", "hp": 60.0, "speed": 70.0, "gold": 10, "icon": "res://assets/monsters/monster_boar_2_32px_pastel.png"})
				4: # 2막 보스
					spawn_queue.append({"name": "활자 사서 리치 (2막 BOSS)", "hp": 260.0, "speed": 42.0, "gold": 50, "icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png"})
					for i in range(4):
						spawn_queue.append({"name": "먹물 악령", "hp": 40.0, "speed": 80.0, "gold": 8, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})

		3: # 제 3막: 차원의 심연 (최종막)
			match wave:
				1:
					for i in range(5):
						spawn_queue.append({"name": "차원 공허 괴수", "hp": 80.0, "speed": 75.0, "gold": 15, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
				2:
					for i in range(4):
						spawn_queue.append({"name": "심연의 드래곤", "hp": 105.0, "speed": 70.0, "gold": 18, "icon": "res://assets/monsters/monster_boar_2_32px_pastel.png"})
					for i in range(2):
						spawn_queue.append({"name": "차원 공허 괴수", "hp": 90.0, "speed": 80.0, "gold": 15, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
				3:
					for i in range(5):
						spawn_queue.append({"name": "종말의 파괴수", "hp": 125.0, "speed": 65.0, "gold": 20, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
				4: # 최종 보스
					spawn_queue.append({"name": "언어의 파괴자: 보이드 드래곤 (FINAL BOSS)", "hp": 450.0, "speed": 38.0, "gold": 100, "icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png"})
					for i in range(5):
						spawn_queue.append({"name": "차원 공허 괴수", "hp": 70.0, "speed": 90.0, "gold": 12, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})

func _spawn_enemy(enemy_data: Dictionary) -> void:
	if enemy_unit_scene == null or path_2d == null:
		return
	var enemy = enemy_unit_scene.instantiate() as EnemyUnit
	path_2d.add_child(enemy)
	enemy.init_enemy(enemy_data["name"], enemy_data["hp"], enemy_data["speed"], enemy_data["gold"], enemy_data["icon"])
	enemy.died.connect(_on_enemy_died)
	enemy.reached_base.connect(_on_enemy_reached_base)

func _on_enemy_died(enemy: EnemyUnit) -> void:
	gold += enemy.gold_reward
	gold_changed.emit(gold)
	SoundEngine.play_coin()

func _on_enemy_reached_base(enemy: EnemyUnit, dmg: int) -> void:
	base_hp = maxi(0, base_hp - dmg)
	base_hp_changed.emit(base_hp, max_base_hp)
	SoundEngine.play_hit()
	if base_hp <= 0:
		game_over.emit(false)

func _on_wave_cleared() -> void:
	is_wave_running = false
	wave_status_changed.emit(current_act, MAX_ACTS, current_wave, MAX_WAVES_PER_ACT, false)
	
	var is_act_final = (current_wave >= MAX_WAVES_PER_ACT)
	var bonus_gold = 30 if is_act_final else 15
	gold += bonus_gold
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

	for i in range(mini(parsed_list.size(), tower_slots.size())):
		var item = parsed_list[i]
		var slot_node = tower_slots[i]
		var lbl = slot_node.get_node_or_null("SlotBg/SlotLabel")
		if lbl: lbl.visible = false
		
		var tower = word_tower_scene.instantiate() as WordTower
		slot_node.add_child(tower)
		tower.setup_tower(item["syllable"], item["word_data"], self)
		tower.tower_clicked.connect(func(t): tower_info_requested.emit(t))
		active_towers.append(tower)

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
