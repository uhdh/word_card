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
var magic_circle_time_left := 0.0
var attack_count := 0
var damage_multiplier := 1.0
var crit_chance := 0.0
var synergy_labels: Array = []
var base_damage := 4.0
var trait_id := "balanced"
var is_hovered := false
const TRAIT_NAMES := {
	"balanced": "균형", "sniper": "저격", "damage_over_time": "지속 피해",
	"splash": "폭발", "rapid": "연사", "pierce": "관통", "control": "제어", "chain": "연쇄"
}

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
		btn_select.mouse_entered.connect(_set_hovered.bind(true))
		btn_select.mouse_exited.connect(_set_hovered.bind(false))

func _set_hovered(value: bool) -> void:
	is_hovered = value
	if value:
		btn_select.tooltip_text = "%s\n%s\n공격력 %.1f | 사거리 %d | 공격 간격 %.2f초" % [syllable, word_data.get("desc", ""), damage_per_attack() * damage_multiplier, int(attack_range), attack_interval]
	queue_redraw()

func setup_tower(p_syllable: String, p_data: Dictionary, p_field: Node, show_magic_circle := false) -> void:
	syllable = p_syllable
	word_data = p_data.duplicate()
	field_ref = p_field
	magic_circle_time_left = 0.8 if show_magic_circle else 0.0

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

	attack_range = 150.0
	attack_interval = 0.8
	base_damage = [4.0, 15.0, 28.0][clampi(syllable.length(), 1, 3) - 1]
	if not word_data.get("is_unknown", false):
		base_damage *= 1.25

	# Category traits keep the same long-term damage budget.
	var cat = word_data.get("category", "weapon")
	match cat:
		"weapon":
			trait_id = "sniper"
			attack_range = 240.0
			attack_interval = 1.2
		"element", "nature":
			trait_id = "damage_over_time"
		"magic":
			trait_id = "splash"
		"summon", "buff":
			trait_id = "rapid"
			attack_interval = 0.4
		"defense":
			trait_id = "pierce"
		"heal":
			trait_id = "control"
		"skill":
			trait_id = "chain"
		_:
			trait_id = "balanced"
	synergy_labels.append("특성: %s" % TRAIT_NAMES[trait_id])

	var bonus = WordSynergy.bonuses(syllable, field_ref.relic_ids)
	damage_multiplier *= bonus["damage"]
	attack_interval *= bonus["interval"]
	attack_range *= bonus["range"]
	crit_chance += bonus["crit"]
	synergy_labels.append_array(bonus["labels"])
	if field_ref.has_relic("relic_range_rune") and cat == "weapon": crit_chance += 0.1
	if field_ref.has_relic("relic_range_rune") and cat == "weapon": synergy_labels.append("천리안 조준")
	if field_ref.has_relic("relic_first_strike") and cat == "summon": synergy_labels.append("소환 선봉")
	if field_ref.has_relic("relic_healing_incense") and cat == "heal": synergy_labels.append("치유 증폭")

	queue_redraw()

func _process(delta: float) -> void:
	if magic_circle_time_left > 0.0:
		magic_circle_time_left -= delta
		if magic_circle_time_left <= 0.0:
			queue_redraw()

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
	var damage = damage_per_attack() * damage_multiplier
	if field_ref.has_relic("relic_three_syllable_seal") and syllable.length() >= 3:
		damage *= 1.25
	if field_ref.has_relic("relic_first_strike") and attack_count == 0:
		damage *= 3 if word_data.get("category") == "summon" else 2
	attack_count += 1
	if randf() < ((0.25 if field_ref.has_relic("relic_crit_lens") else 0.0) + crit_chance): damage *= 2

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
		var targets := _trait_targets(target)
		var shares := damage_shares(targets.size(), damage)
		for i in targets.size():
			_fire_projectile(targets[i], shares[i], proj_type)


func damage_per_attack() -> float:
	match trait_id:
		"sniper": return base_damage * 1.5
		"rapid": return base_damage * 0.5
		_: return base_damage


func damage_shares(target_count: int, total_damage := -1.0) -> Array:
	var count := clampi(target_count, 1, 3)
	var share := (damage_per_attack() if total_damage < 0.0 else total_damage) / count
	var result: Array = []
	for i in count:
		result.append(share)
	return result


func damage_over_time_parts() -> Array:
	return [damage_per_attack() * 0.25, damage_per_attack() * 0.75]


func _trait_targets(primary: EnemyUnit) -> Array[EnemyUnit]:
	var result: Array[EnemyUnit] = [primary]
	if trait_id not in ["splash", "pierce", "chain"]:
		return result
	for enemy in field_ref.get_enemies():
		if result.size() >= 3:
			break
		if enemy == primary or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if global_position.distance_to(enemy.global_position) <= attack_range:
			result.append(enemy)
	return result


func _fire_projectile(target: EnemyUnit, damage: float, proj_type: String) -> void:
	var proj = projectile_scene.instantiate() as Projectile
	proj.global_position = global_position
	field_ref.add_projectile(proj)
	proj.setup(target, damage, proj_type, trait_id)

func _draw() -> void:
	if is_hovered:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 48, Color(0.35, 0.9, 1.0, 0.8), 2.0)
	# 사거리 원 시각화 (반투명 청록색)
	if magic_circle_time_left > 0.0:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 32, Color(0.3, 0.8, 1.0, 0.35), 2.0)
