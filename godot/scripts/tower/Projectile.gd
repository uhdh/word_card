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

const TEXTURES = {
	"slash": "res://assets/projectiles/proj_slash_32px_pastel.png",
	"fire": "res://assets/projectiles/proj_fire_32px_pastel.png",
	"ice": "res://assets/projectiles/proj_ice_32px_pastel.png",
	"arrow": "res://assets/projectiles/proj_arrow_32px_pastel.png",
	"lightning": "res://assets/projectiles/proj_lightning_32px_pastel.png",
	"bullet": "res://assets/projectiles/proj_magic_32px_pastel.png"
}

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_target: EnemyUnit, p_damage: float, p_type: String = "bullet", p_trait: String = "balanced") -> void:
	target = p_target
	damage = p_damage
	if target != null:
		target_pos = target.global_position
	sprite.texture = load(TEXTURES.get(p_type, TEXTURES["bullet"]))

	match p_type:
		"slash":
			speed = 450.0
		"ice":
			slow_factor = 0.5
			slow_duration = 2.5
		"arrow":
			speed = 500.0
		"lightning":
			speed = 600.0

	if p_trait == "damage_over_time":
		damage = p_damage * 0.25
		burn_duration = 3.0
		burn_dps = p_damage * 0.75 / burn_duration
	elif p_trait == "control":
		slow_factor = 0.8
		slow_duration = 1.5

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
