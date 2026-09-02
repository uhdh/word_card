# Projectile.gd
# 타워에서 발사되는 투사체
class_name Projectile
extends Area2D

var target: EnemyUnit = null
var target_pos: Vector2
var speed: float = 350.0
var damage: float = 5.0
var is_aoe: bool = false
var aoe_radius: float = 60.0
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var burn_dps: float = 0.0
var burn_duration: float = 0.0

@onready var sprite: Label = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_target: EnemyUnit, p_damage: float, p_type: String = "bullet") -> void:
	target = p_target
	damage = p_damage
	if target != null:
		target_pos = target.global_position

	match p_type:
		"slash":
			sprite.text = "🗡️"
			speed = 450.0
		"fire":
			sprite.text = "🔥"
			is_aoe = true
			aoe_radius = 70.0
			burn_dps = damage * 0.4
			burn_duration = 2.0
		"ice":
			sprite.text = "❄️"
			slow_factor = 0.5
			slow_duration = 2.5
		"arrow":
			sprite.text = "🏹"
			speed = 500.0
		"lightning":
			sprite.text = "⚡"
			speed = 600.0
		_:
			sprite.text = "✨"

func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.is_dead:
		target_pos = target.global_position

	var dir = (target_pos - global_position).normalized()
	global_position += dir * speed * delta

	if global_position.distance_to(target_pos) < 16.0:
		hit_target()

func hit_target() -> void:
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(damage)
		if slow_duration > 0.0:
			target.apply_slow(slow_factor, slow_duration)
		if burn_duration > 0.0:
			target.apply_burn(burn_dps, burn_duration)

	queue_free()

func _on_body_entered(_body: Node) -> void:
	pass
