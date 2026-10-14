# Meteor.gd
# 하늘에서 떨어지는 유성. 사용자 요청: "랜덤하게 떨어지는 메테오".
#
# 조준 사격이 아니라 '예고 → 낙하 → 광역 폭발' 3단계다.
# 바닥에 예고 원을 먼저 그려서 "여기가 맞는다"를 플레이어가 읽을 수 있게 한다.
# 씬 파일 없이 코드로만 그린다(자식 노드가 필요 없다).
class_name Meteor
extends Node2D

const Palette = preload("res://scripts/ui/Palette.gd")
const Juice = preload("res://scripts/ui/Juice.gd")

## 낙하 시작 높이(px). 이만큼 위에서 떨어진다.
const FALL_HEIGHT := 300.0
## 착탄 후 잔불/충격파가 남아 있는 시간(초).
const AFTER_LIFE := 0.5
## 꼬리 길이(px).
const TRAIL_LENGTH := 74.0

var damage := 20.0
var blast_radius := 62.0
var fall_time := 0.55
var source_tower: WordTower = null
## 이 한 발이 치명타 굴림을 통과했는가 (§2.21-6, 2026-10-01).
##
## ⚠️ 피해에는 이미 배수가 들어와 있다(`WordTower.crit_damage()`). 이 값이 필요한 이유는
##    **피해 숫자의 종류**다 — 안 내려보내면 2배로 맞은 적이 평범한 흰 숫자로 떠서,
##    §2.21 (A) 가 만든 치명타 채널이 유성에서만 죽는다.
var is_crit := false

var _elapsed := 0.0
var _impacted := false
var _after := 0.0


func setup(p_damage: float, p_blast_radius: float, p_source: WordTower,
		p_fall_time := 0.55, p_is_crit := false) -> void:
	damage = p_damage
	blast_radius = p_blast_radius
	source_tower = p_source
	fall_time = p_fall_time
	is_crit = p_is_crit
	z_index = 40


func progress() -> float:
	return clampf(_elapsed / maxf(fall_time, 0.01), 0.0, 1.0)


func _process(delta: float) -> void:
	if not _impacted:
		_elapsed += delta
		if _elapsed >= fall_time:
			_impacted = true
			_impact()
	else:
		_after += delta
		if _after >= AFTER_LIFE:
			queue_free()
	queue_redraw()


func _impact() -> void:
	var field = source_tower.field_ref if is_instance_valid(source_tower) else null
	if field != null:
		for enemy in field.get_enemies():
			if not is_instance_valid(enemy) or enemy.is_dead:
				continue
			if enemy.global_position.distance_to(global_position) > blast_radius:
				continue
			var mult: float = enemy.damage_multiplier_for("meteor")
			# §2.21-6 — 굴림 결과를 **피해 숫자까지** 내려보낸다(안 보내면 2배 피해가 흰 숫자다).
			var dealt: float = enemy.take_damage(damage * mult, true, mult, false, is_crit)
			if is_instance_valid(source_tower):
				source_tower.record_damage(dealt)
		Juice.shake(field, 7.0, 0.24)
	SoundEngine.play_magic()


func _draw() -> void:
	var hot := Color(1.0, 0.62, 0.18)
	var core := Color(1.0, 0.94, 0.72)

	if not _impacted:
		# ① 예고 — 착탄 지점에 조여드는 원. 남은 시간이 한눈에 보인다.
		var p := progress()
		draw_circle(Vector2.ZERO, blast_radius, Color(hot.r, hot.g, hot.b, 0.07))
		draw_arc(Vector2.ZERO, blast_radius, 0, TAU, 40, Color(hot.r, hot.g, hot.b, 0.45), 1.5)
		draw_arc(Vector2.ZERO, blast_radius * (1.0 - p), 0, TAU, 40, Color(core.r, core.g, core.b, 0.75), 2.0)
		# ② 낙하 중인 유성 + 꼬리
		var body := Vector2(0.0, -FALL_HEIGHT * (1.0 - p))
		draw_line(body + Vector2(0.0, -TRAIL_LENGTH), body, Color(hot.r, hot.g, hot.b, 0.55), 7.0)
		draw_line(body + Vector2(0.0, -TRAIL_LENGTH * 0.5), body, Color(core.r, core.g, core.b, 0.65), 3.0)
		draw_circle(body, 11.0, Color(hot.r, hot.g, hot.b, 0.95))
		draw_circle(body, 6.0, core)
	else:
		# ③ 착탄 — 퍼져 나가는 충격파 + 식어가는 잔불
		var t := clampf(_after / AFTER_LIFE, 0.0, 1.0)
		var wave := blast_radius * (0.55 + 0.65 * t)
		draw_circle(Vector2.ZERO, blast_radius * (1.0 - t), Color(hot.r, hot.g, hot.b, 0.30 * (1.0 - t)))
		draw_arc(Vector2.ZERO, wave, 0, TAU, 48, Color(core.r, core.g, core.b, 0.85 * (1.0 - t)), 4.0)
		draw_arc(Vector2.ZERO, wave * 0.7, 0, TAU, 48, Color(hot.r, hot.g, hot.b, 0.5 * (1.0 - t)), 2.0)
