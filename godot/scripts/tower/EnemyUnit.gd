# EnemyUnit.gd
# 타워 디펜스 경로(PathFollow2D)를 따라 이동하는 적 유닛
class_name EnemyUnit
extends PathFollow2D

signal died(enemy: EnemyUnit)
signal reached_base(enemy: EnemyUnit, damage: int)

@export var max_hp: float = 20.0
var hp: float = 20.0
@export var speed: float = 80.0
@export var gold_reward: int = 5
@export var enemy_name: String = "낱자 슬라임"
@export var base_damage: int = 1

var slow_factor: float = 1.0
var slow_timer: float = 0.0
var burn_dps: float = 0.0
var burn_timer: float = 0.0
var is_dead: bool = false

@onready var sprite: TextureRect = $Sprite
@onready var hp_bar: ProgressBar = $HpBar

func _ready() -> void:
	hp = max_hp
	loop = false
	rotates = false
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

func init_enemy(p_name: String, p_hp: float, p_speed: float, p_gold: int, icon_path: String) -> void:
	enemy_name = p_name
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	gold_reward = p_gold
	if ResourceLoader.exists(icon_path) and sprite != null:
		sprite.texture = load(icon_path)

func _process(delta: float) -> void:
	if is_dead:
		return

	# Handle Slow
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0

	# Handle Burn DoT
	if burn_timer > 0.0:
		burn_timer -= delta
		take_damage(burn_dps * delta, false)
		if is_dead:
			return

	# Move along path
	var current_speed = speed * slow_factor
	progress += current_speed * delta

	# Check reached base
	if progress_ratio >= 0.99:
		is_dead = true
		reached_base.emit(self, base_damage)
		queue_free()

func take_damage(amount: float, show_hit_sound: bool = true) -> void:
	if is_dead:
		return

	hp -= amount
	if hp_bar:
		hp_bar.value = hp

	if show_hit_sound:
		SoundEngine.play_hit()

	# Visual flash
	if sprite:
		sprite.modulate = Color(1.5, 0.4, 0.4)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

	if hp <= 0.0:
		is_dead = true
		died.emit(self)
		queue_free()

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_timer = maxf(slow_timer, duration)

func apply_burn(dps: float, duration: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)
