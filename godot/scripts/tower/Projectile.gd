# Projectile.gd
# 타워에서 발사되는 투사체
class_name Projectile
extends Area2D

## 프로젝트 관례대로 preload 한다(전역 class_name 캐시에 의존하지 않는다).
const Juice = preload("res://scripts/ui/Juice.gd")

var target: EnemyUnit = null
var target_pos: Vector2
var speed: float = 350.0
var damage: float = 5.0
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var burn_dps: float = 0.0
var burn_duration: float = 0.0
var source_tower: WordTower = null
var spin_speed := 0.0
## 이 탄을 쏜 타워의 특성. 타격 **모양**을 정한다 — 예전에는 받기만 하고 버려서
## (`p_trait` 은 외형/피해 계산에만 쓰였다) 11종이 전부 같은 섬광을 냈다.
var trait_id: String = "balanced"
## 화상 지속시간의 기준값(초). 발화 기름 유물은 여기에 배수를 곱한다.
const BASE_BURN_SECONDS: float = 3.0
## 화상 지속시간 배수. setup() 에서 source_tower 를 보고 정해진다.
var burn_duration_multiplier: float = 1.0

const TEXTURES = {
	"slash": "res://assets/projectiles/proj_slash_32px_pastel.png",
	"fire": "res://assets/projectiles/proj_fire_32px_pastel.png",
	"ice": "res://assets/projectiles/proj_ice_32px_pastel.png",
	"arrow": "res://assets/projectiles/proj_arrow_32px_pastel.png",
	"lightning": "res://assets/projectiles/proj_lightning_32px_pastel.png",
	"bullet": "res://assets/projectiles/proj_magic_32px_pastel.png",
	"dot": "res://assets/projectiles/proj_dot_32px_pastel.png",
	"pierce": "res://assets/projectiles/proj_pierce_32px_pastel.png",
	"bounce": "res://assets/projectiles/proj_bounce_32px_pastel.png"
}

@onready var sprite: Sprite2D = $Sprite

## 이 타격에 적용된 속성 배율. EnemyUnit 이 피해 숫자에 '약점'/'내성' 을 붙이는 데 쓴다.
## 배율을 여기서 구해 피해에 곱해 버리면, 적은 자기가 약점을 찔렸는지 알 수 없다.
var damage_mult: float = 1.0

## 이 탄이 **치명타로 굴린 한 발**인가. 피해에는 이미 배수가 곱해져 있으므로(`setup` 참조)
## 이 값은 순수하게 표시용이다 — 적이 피해 숫자를 치명타 전용 색으로 띄우게 한다(§2.21 (A)).
## ⚠️ 스플래쉬(둔화 범위 피해)에는 **전달하지 않는다** — 그건 이 탄의 명중이 아니라
##    주변에 흩뿌려진 2차 피해다.
var is_crit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_target: EnemyUnit, p_damage: float, p_type: String = "bullet", p_trait: String = "balanced", p_source: WordTower = null, p_scale: float = 1.0, p_is_crit: bool = false) -> void:
	target = p_target
	is_crit = p_is_crit
	damage_mult = target.damage_multiplier_for(p_trait) if is_instance_valid(target) else 1.0
	damage = p_damage * damage_mult
	source_tower = p_source
	trait_id = p_trait
	if target != null:
		target_pos = target.global_position
	sprite.texture = load(TEXTURES.get(p_type, TEXTURES["bullet"]))

	match p_type:
		"slash":
			speed = 700.0
		"fire":
			speed = 300.0
		"ice":
			slow_factor = 0.5
			slow_duration = 2.5
		"arrow":
			speed = 650.0
		"pierce":
			speed = 500.0
		"lightning":
			speed = 600.0
		"dot":
			speed = 350.0
		"bounce":
			speed = 350.0
			spin_speed = 9.0
	_apply_trait_appearance(p_trait)
	# 음절이 긴 타워의 탄은 더 크게 그린다. 특성 외형(_apply_trait_appearance)이
	# 정한 크기 '위에' 곱해야 한다 — 그래야 의미별 외형이 유지된다.
	if not is_equal_approx(p_scale, 1.0):
		sprite.scale *= p_scale

	if p_trait == "damage_over_time":
		damage *= 0.25
		# 발화 기름 유물은 source_tower 의 배수로 들어온다.
		if is_instance_valid(source_tower):
			burn_duration_multiplier = source_tower.burn_duration_multiplier
		# 초당 피해는 '기본 3초' 기준으로 고정하고, 지속시간만 늘린다 —
		# 그래야 발화 기름 유물이 '총 화상 피해' 를 늘리는 강화가 된다.
		# (둘을 함께 나누면 총량이 그대로라 아무 효과가 없다)
		var base_dps := p_damage * damage_mult * 0.75 / BASE_BURN_SECONDS
		burn_dps = base_dps
		burn_duration = BASE_BURN_SECONDS * burn_duration_multiplier
	elif p_trait == "control":
		slow_factor = 0.8
		slow_duration = 1.5

func _apply_trait_appearance(trait_id: String) -> void:
	match trait_id:
		"sniper": sprite.scale = Vector2.ONE * 1.0; speed = 650.0
		"damage_over_time": sprite.scale = Vector2.ONE * 0.9; sprite.modulate = Color(1.0, 1.0, 1.0)
		"splash": sprite.scale = Vector2.ONE * 1.25; speed = 300.0
		"rapid": sprite.scale = Vector2.ONE * 0.75; speed = 700.0
		"pierce": sprite.scale = Vector2.ONE * 1.15; sprite.modulate = Color(1.0, 1.0, 1.0)
		"control": sprite.scale = Vector2.ONE * 1.0; sprite.modulate = Color(1.0, 1.0, 1.0)
		"chain": sprite.scale = Vector2.ONE * 0.95; sprite.modulate = Color(1.0, 1.0, 1.0)
		"bounce": sprite.scale = Vector2.ONE * 1.0; sprite.modulate = Color(1.0, 1.0, 1.0); spin_speed = 9.0

func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.is_dead:
		target_pos = target.global_position

	var dir = (target_pos - global_position).normalized()
	global_position += dir * speed * delta

	# spin_speed 가 있는 투사체(반사탄)는 **회전 연출을 우선**한다.
	# 예전에는 아래 dir.angle() 이 매 프레임 덮어써서 bounce 전용으로 넣어 둔
	# spin_speed = 9.0 이 완전한 죽은 코드였다(육안 확인: 진행 방향으로 고정).
	if spin_speed != 0.0:
		sprite.rotation += spin_speed * delta
	elif dir.length() > 0.01:
		# 그 외에는 이동 방향을 향한다.
		sprite.rotation = dir.angle()

	if global_position.distance_to(target_pos) < 16.0:
		hit_target()

func hit_target() -> void:
	if is_instance_valid(target) and not target.is_dead:
		var valid_source: WordTower = source_tower if is_instance_valid(source_tower) else null
		var dealt := target.take_damage(damage, true, damage_mult, false, is_crit)
		if valid_source != null: valid_source.record_damage(dealt)
		if slow_duration > 0.0:
			target.apply_slow(slow_factor, slow_duration)
			# 둔화(control) 특성 스플래쉬: 착탄 주변 48px 내 적들에게도 둔화 및 범위 피해 적용
			var field = valid_source.field_ref if valid_source != null else null
			if field != null and field.has_method("get_enemies"):
				var splash_radius := 48.0
				for nearby in field.get_enemies():
					if nearby == target or not is_instance_valid(nearby) or nearby.is_dead:
						continue
					if global_position.distance_to(nearby.global_position) <= splash_radius:
						nearby.apply_slow(slow_factor, slow_duration)
						# 치명타 여부를 넘기지 않는다 — 이 피해는 이 탄의 명중이 아니라
						# 둔화 범위에 함께 들어간 2차 피해다(§2.21 (A)).
						var s_dmg: float = float(nearby.take_damage(damage * 0.4, false, damage_mult))
						if valid_source != null: valid_source.record_damage(s_dmg)
		if burn_duration > 0.0:
			target.apply_burn(burn_dps, burn_duration, valid_source)
		# 명중 섬광. 예전에는 피해를 주고 곧바로 사라져서, 분당 100회 넘게 일어나는
		# 기본 공격이 화면에 아무 흔적도 남기지 않았다(감사 §6.1 확정).
		_spawn_impact()

	queue_free()

## 타격 지점에 특성에 맞는 흔적을 남긴다.
## 부모(투사체 레이어)에 붙여야 이 투사체가 사라져도 흔적이 살아남는다.
func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# 투사체 자체의 색을 쓰되 **흰색 쪽으로 민다**. 배경이 초원이라 초록 탄의
	# 초록 섬광은 그대로 쓰면 배경에 묻힌다. 흰색에 가깝게 밀면 색은 남기면서
	# 밝기만 확보된다 — 화염탄은 주황, 관통탄은 하늘색으로 읽힌다.
	var base: Color = sprite.modulate if sprite != null else Color.WHITE
	var tint: Color = Color(base.r, base.g, base.b).lerp(Color.WHITE, 0.5)
	tint.a = 0.9
	# 모양은 특성이 정한다. 방향은 '어디서 왔는가' 다 — 명중 직전의 진행 방향이라
	# 관통/저격의 직선과 연쇄/바운스의 꺾은선이 날아온 방향으로 놓인다.
	var travel := target_pos - global_position
	var angle: float = travel.angle() if travel.length() > 0.01 else 0.0
	Juice.trait_impact(parent, global_position, tint, trait_id, angle)

func _on_body_entered(_body: Node) -> void:
	pass
