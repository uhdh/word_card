# PlayerState.gd
# 플레이어 상태, 덱, 유물, 체력, 행동력 관리
class_name PlayerState
extends RefCounted

const STARTER_DECK = [
	"ㄱ", "ㅂ", "ㅅ", "ㅁ", "ㄹ", "ㅇ", "ㅏ", "ㅏ", "ㅓ", "ㅣ"
]

var max_hp: int = 80
var hp: int = 80
var max_ap: int = 1
var ap: int = 1
var shield: int = 0
var gold: int = 99

# Status effects
var power: int = 0
var poison: int = 0
var bleed: int = 0
var invulnerable: int = 0
var retain_shield: bool = false
var thorns: int = 0
var regen: int = 0
var counter: int = 0

var deck: Array[String] = []
var relic_manager: RelicManager

func _init() -> void:
	deck.clear()
	for d in STARTER_DECK:
		deck.append(d)
	relic_manager = RelicManager.new()
	relic_manager.add_relic("relic_hunmin_lens")

func heal(amount: int) -> int:
	var actual = mini(max_hp - hp, amount)
	hp = mini(max_hp, hp + amount)
	return actual

func increase_max_hp(amount: int) -> void:
	max_hp += amount
	hp += amount

func cleanse() -> void:
	poison = 0
	bleed = 0

func take_damage(raw_damage: int) -> Dictionary:
	if invulnerable > 0:
		invulnerable -= 1
		SoundEngine.play_shield()
		return { "actualHpHit": 0, "shieldHit": 0, "isDead": false, "invulnerable": true }

	var actual_hp_hit = 0
	var shield_hit = 0

	if shield >= raw_damage:
		shield -= raw_damage
		shield_hit = raw_damage
		SoundEngine.play_shield()
	else:
		shield_hit = shield
		var remaining = raw_damage - shield
		shield = 0
		hp -= remaining
		actual_hp_hit = remaining
		SoundEngine.play_hit()

	hp = maxi(0, hp)
	return {
		"actualHpHit": actual_hp_hit,
		"shieldHit": shield_hit,
		"isDead": hp <= 0,
		"remainingHp": hp
	}

func reset_turn_status() -> void:
	if not retain_shield:
		shield = 0
	retain_shield = false
	ap = max_ap
