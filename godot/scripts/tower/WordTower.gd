# WordTower.gd
# 자모 결합으로 자동 생성되는 단어 타워
class_name WordTower
extends Node2D

signal tower_clicked(tower: WordTower)

var word_data: Dictionary = {}
var syllable: String = ""

@export var attack_range: float = 140.0
@export var attack_interval: float = 0.8
var attack_timer: float = 0.0

var projectile_scene = preload("res://scenes/tower/Projectile.tscn")
var field_ref: Node = null

@onready var icon_container: CenterContainer = $IconContainer
@onready var icon_sprite: TextureRect = $IconContainer/IconSprite
@onready var label_big_word: Label = $LabelBigWord
@onready var label_word: Label = $LabelWord
@onready var range_circle: Node2D = $RangeCircle
@onready var btn_select: Button = $BtnSelect

func _ready() -> void:
	attack_timer = 0.0
	if btn_select:
		btn_select.pressed.connect(func():
			SoundEngine.play_tile_click()
			tower_clicked.emit(self)
		)

func setup_tower(p_syllable: String, p_data: Dictionary, p_field: Node) -> void:
	syllable = p_syllable
	word_data = p_data
	field_ref = p_field

	var has_icon = word_data.get("icon", "") != "" and ResourceLoader.exists(word_data.get("icon", ""))
	var is_unknown = word_data.get("is_unknown", false) or not has_icon

	if is_unknown:
		if icon_container: icon_container.visible = false
		if label_word: label_word.visible = false
		if label_big_word:
			label_big_word.visible = true
			label_big_word.text = syllable
	else:
		if icon_container: icon_container.visible = true
		if label_word:
			label_word.visible = true
			label_word.text = syllable
		if label_big_word: label_big_word.visible = false
		if icon_sprite:
			icon_sprite.texture = load(word_data["icon"])

	# Category-based stats
	var cat = word_data.get("category", "weapon")
	match cat:
		"weapon":
			attack_range = 150.0
			attack_interval = 0.65
		"element":
			attack_range = 160.0
			attack_interval = 0.9
		"summon":
			attack_range = 140.0
			attack_interval = 1.0
		"defense":
			attack_range = 130.0
			attack_interval = 0.95
		"heal":
			attack_range = 145.0
			attack_interval = 0.85
		"skill":
			attack_range = 150.0
			attack_interval = 0.8

	# Specific word mechanics
	if word_data.get("rapid_fire", false):
		attack_interval = 0.25
	if word_data.has("range_bonus"):
		attack_range += float(word_data["range_bonus"])

	# Multi-syllable Tier Bonus
	var word_len = syllable.length()
	if word_len == 2:
		attack_range += 30.0
		attack_interval *= 0.85
	elif word_len >= 3:
		attack_range += 60.0
		attack_interval *= 0.7

	queue_redraw()

func _process(delta: float) -> void:
	if word_data.is_empty() or field_ref == null:
		return

	attack_timer += delta
	if attack_timer >= attack_interval:
		var target = find_target()
		if target != null:
			attack_target(target)
			attack_timer = 0.0

func find_target() -> EnemyUnit:
	if field_ref == null:
		return null
	var enemies = field_ref.get_enemies()
	var best_target: EnemyUnit = null
	var best_progress: float = -1.0

	for e in enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist <= attack_range:
			if e.progress > best_progress:
				best_progress = e.progress
				best_target = e

	return best_target

func attack_target(target: EnemyUnit) -> void:
	var damage = word_data.get("damage", 4)
	if damage <= 0:
		damage = 4

	var cat = word_data.get("category", "weapon")
	var proj_type = "bullet"
	if cat == "weapon":
		proj_type = "slash"
		SoundEngine.play_attack()
	elif cat == "element":
		if word_data.get("burn", 0) > 0 or word_data.get("word", "") == "불":
			proj_type = "fire"
		elif word_data.get("freeze", false) or word_data.get("word", "") in ["빙", "얼", "눈"]:
			proj_type = "ice"
		else:
			proj_type = "lightning"
		SoundEngine.play_magic()
	elif cat == "summon":
		proj_type = "slash"
		SoundEngine.play_summon()
	else:
		proj_type = "bullet"
		SoundEngine.play_attack()

	if projectile_scene != null and field_ref != null:
		var proj = projectile_scene.instantiate() as Projectile
		proj.global_position = global_position
		field_ref.add_projectile(proj)
		proj.setup(target, float(damage), proj_type)

func _draw() -> void:
	# 사거리 원 시각화 (반투명 청록색)
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.15), 1.5)
