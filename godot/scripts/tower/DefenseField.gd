# DefenseField.gd
# 타워 디펜스 맵 필드, 적 이동 경로(Path2D), 타워 슬롯들 및 웨이브 관리
class_name DefenseField
extends Control

signal base_hp_changed(current: int, max: int)
signal gold_changed(current: int)
signal wave_status_changed(wave: int, max_wave: int, is_running: bool)
signal wave_cleared(wave: int, bonus_gold: int)
signal tower_info_requested(tower: WordTower)
signal game_over(is_victory: bool)

@export var max_base_hp: int = 20
var base_hp: int = 20
var gold: int = 40

var current_wave: int = 0
const MAX_WAVES: int = 5
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
		if spawn_timer >= 1.2:
			spawn_timer = 0.0
			var next_enemy_data = spawn_queue.pop_front()
			_spawn_enemy(next_enemy_data)

	elif is_wave_running and spawn_queue.is_empty():
		# Check if all enemies in path are cleared
		var alive_enemies = get_enemies()
		if alive_enemies.is_empty():
			_on_wave_cleared()

func start_next_wave() -> void:
	if is_wave_running:
		return

	current_wave += 1
	if current_wave > MAX_WAVES:
		game_over.emit(true)
		return

	is_wave_running = true
	spawn_timer = 0.0
	spawn_queue.clear()

	# Build wave spawn list
	match current_wave:
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
		4:
			for i in range(2):
				spawn_queue.append({"name": "먹물 악령", "hp": 55.0, "speed": 60.0, "gold": 12, "icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png"})
			for i in range(4):
				spawn_queue.append({"name": "가시 넝쿨", "hp": 28.0, "speed": 80.0, "gold": 6, "icon": "res://assets/monsters/monster_vine_2_32px_pastel.png"})
		5:
			# Boss wave
			spawn_queue.append({"name": "서예 골렘 (BOSS)", "hp": 150.0, "speed": 45.0, "gold": 30, "icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png"})
			for i in range(4):
				spawn_queue.append({"name": "낱자 슬라임", "hp": 20.0, "speed": 95.0, "gold": 4, "icon": "res://assets/monsters/monster_slime_1_32px_pastel.png"})

	wave_status_changed.emit(current_wave, MAX_WAVES, true)
	SoundEngine.play_summon()

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
	wave_status_changed.emit(current_wave, MAX_WAVES, false)
	var bonus_gold = 15
	gold += bonus_gold
	gold_changed.emit(gold)
	SoundEngine.play_victory()

	if current_wave >= MAX_WAVES:
		game_over.emit(true)
	else:
		wave_cleared.emit(current_wave, bonus_gold)

func update_towers_from_parsed_list(parsed_list: Array) -> void:
	# Clear old towers
	for t in active_towers:
		if is_instance_valid(t):
			t.queue_free()
	active_towers.clear()

	# Place new towers in slots
	for i in range(mini(parsed_list.size(), tower_slots.size())):
		var item = parsed_list[i]
		var slot_node = tower_slots[i]
		
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
