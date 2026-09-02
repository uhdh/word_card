# EnemyAI.gd
# 1막(Act 1. 흩어진 활자의 숲) 몬스터 데이터 및 행동 패턴
class_name EnemyInstance
extends RefCounted

const ENEMIES_ACT_1 = {
	"letter_slime": {
		"id": "letter_slime",
		"name": "낱자 슬라임",
		"maxHp": 16,
		"icon": "res://assets/monsters/monster_slime_1_32px_pastel.png",
		"type": "normal",
		"moves": [
			{ "name": "먹물 뱉기", "type": "attack", "damage": 4, "desc": "4의 피해를 입힙니다." },
			{ "name": "점액 방벽", "type": "defense", "shield": 5, "desc": "5의 방어도를 얻습니다." },
			{ "name": "오염된 산성", "type": "attack_debuff", "damage": 3, "poison": 1, "desc": "3의 피해와 1의 독을 부여합니다." }
		]
	},
	"wild_boar": {
		"id": "wild_boar",
		"name": "사나운 멧돼지",
		"maxHp": 22,
		"icon": "res://assets/monsters/monster_boar_1_32px_pastel.png",
		"type": "normal",
		"moves": [
			{ "name": "돌진 들이받기", "type": "attack", "damage": 7, "desc": "7의 돌진 피해를 입힙니다." },
			{ "name": "전의 고취", "type": "buff", "buffPower": 2, "desc": "자신의 공격력을 +2 증가시킵니다." },
			{ "name": "위협의 포효", "type": "debuff", "weak": 1, "damage": 3, "desc": "3의 피해를 입히고 1턴간 취약을 겁니다." }
		]
	},
	"thorn_vine": {
		"id": "thorn_vine",
		"name": "가시 돋친 넝쿨",
		"maxHp": 18,
		"icon": "res://assets/monsters/monster_vine_1_32px_pastel.png",
		"type": "normal",
		"moves": [
			{ "name": "가시 채찍", "type": "attack", "damage": 5, "bleed": 2, "desc": "5의 피해와 2턴간 출혈을 입힙니다." },
			{ "name": "가시 껍질", "type": "defense_buff", "shield": 6, "thorns": 2, "desc": "6의 방어도와 2의 가시를 얻습니다." }
		]
	},
	"ink_spirit": {
		"id": "ink_spirit",
		"name": "먹물 웅덩이의 악령",
		"maxHp": 38,
		"icon": "res://assets/monsters/monster_spirit_1_32px_pastel.png",
		"type": "elite",
		"moves": [
			{ "name": "먹물 폭풍", "type": "attack", "damage": 9, "desc": "9의 암흑 피해를 입힙니다." },
			{ "name": "부식 침식", "type": "defense_debuff", "shield": 8, "poison": 2, "desc": "8의 방어도를 얻고 2의 독을 부여합니다." },
			{ "name": "영혼 흡수", "type": "attack_heal", "damage": 6, "heal": 5, "desc": "6 피해를 입히고 체력을 5 흡혈합니다." }
		]
	},
	"ink_golem": {
		"id": "ink_golem",
		"name": "먹물에 잠식된 서예 골렘",
		"maxHp": 65,
		"icon": "res://assets/monsters/monster_golem_boss_1_32px_pastel.png",
		"type": "boss",
		"moves": [
			{ "name": "대필 일격", "type": "attack", "damage": 8, "desc": "8의 묵직한 붓질 타격을 가합니다." },
			{ "name": "먹물 요새화", "type": "defense_buff", "shield": 10, "buffPower": 1, "desc": "10 방어도를 얻고 공격력이 +1 증가합니다." },
			{ "name": "묵향 난무", "type": "multi_attack", "damage": 4, "hits": 3, "desc": "4의 피해를 3회 연속 타격합니다!" },
			{ "name": "침묵의 도장", "type": "heavy_attack", "damage": 12, "desc": "12의 강력한 일격을 준비합니다!" }
		]
	}
}

var id: String
var name: String
var max_hp: int
var hp: int
var shield: int = 0
var type: String
var icon: String
var moves: Array
var move_index: int = 0

var power: int = 0
var poison: int = 0
var bleed: int = 0
var weak: int = 0
var thorns: int = 0
var stunned: bool = false

var next_move: Dictionary

func _init(template_id: String = "letter_slime") -> void:
	var template = ENEMIES_ACT_1.get(template_id, ENEMIES_ACT_1["letter_slime"])
	id = template["id"]
	name = template["name"]
	max_hp = template["maxHp"]
	hp = max_hp
	type = template["type"]
	icon = template["icon"]
	moves = template["moves"]
	move_index = 0
	next_move = decide_next_move()

func decide_next_move() -> Dictionary:
	var move = moves[move_index % moves.size()]
	move_index += 1
	return move

func take_damage(raw_damage: int, is_piercing: bool = false) -> Dictionary:
	var damage = raw_damage
	if weak > 0:
		damage = int(damage * 1.5)

	var actual_hp_hit = 0
	if is_piercing:
		hp -= damage
		actual_hp_hit = damage
	else:
		if shield >= damage:
			shield -= damage
		else:
			var remaining = damage - shield
			shield = 0
			hp -= remaining
			actual_hp_hit = remaining

	hp = maxi(0, hp)
	return { "actualHpHit": actual_hp_hit, "remainingHp": hp, "isDead": hp <= 0 }

func execute_turn(player: PlayerState) -> Dictionary:
	if stunned:
		stunned = false
		next_move = decide_next_move()
		return { "attackDamage": 0, "log": "%s은(는) 기절/빙결되어 행동하지 못했습니다!" % name }

	shield = 0
	var dot_logs = []

	if poison > 0:
		hp -= poison
		dot_logs.append("%s이(가) 독으로 %d의 피해를 입었습니다." % [name, poison])
		poison = maxi(0, poison - 1)

	if bleed > 0:
		hp -= 3
		dot_logs.append("%s이(가) 출혈로 3의 피해를 입었습니다." % name)
		bleed = maxi(0, bleed - 1)

	if hp <= 0:
		return { "attackDamage": 0, "log": " ".join(dot_logs) + " %s 처치!" % name }

	var move = next_move
	var move_logs = []
	var attack_damage = 0
	var dmg = move.get("damage", 0) + power

	match move.get("type", ""):
		"attack":
			player.take_damage(dmg)
			attack_damage = dmg
			move_logs.append("%s의 [%s]! 플레이어에게 %d의 피해!" % [name, move["name"], dmg])
		"multi_attack":
			var total = 0
			var hits = move.get("hits", 2)
			for i in range(hits):
				player.take_damage(dmg)
				total += dmg
			attack_damage = total
			move_logs.append("%s의 [%s]! 플레이어에게 총 %d의 연속 피해!" % [name, move["name"], total])
		"defense":
			shield += move.get("shield", 0)
			move_logs.append("%s이(가) [%s]으로 방어도 %d을(를) 얻었습니다." % [name, move["name"], move.get("shield", 0)])
		"buff":
			power += move.get("buffPower", 0)
			move_logs.append("%s이(가) [%s]으로 공격력이 +%d 증가했습니다." % [name, move["name"], move.get("buffPower", 0)])
		"attack_debuff":
			player.take_damage(dmg)
			attack_damage = dmg
			if move.has("poison"):
				player.poison += move["poison"]
			move_logs.append("%s의 [%s]! 피해 %d 및 독 %d 부여!" % [name, move["name"], dmg, move.get("poison", 0)])
		"defense_buff":
			shield += move.get("shield", 0)
			if move.has("thorns"):
				thorns += move["thorns"]
			move_logs.append("%s이(가) [%s]으로 방어도와 가시를 얻었습니다." % [name, move["name"]])
		"heavy_attack":
			player.take_damage(dmg)
			attack_damage = dmg
			move_logs.append("%s의 [%s]! 플레이어에게 강력한 %d의 피해!" % [name, move["name"], dmg])

	if weak > 0:
		weak -= 1

	next_move = decide_next_move()
	dot_logs.append_array(move_logs)
	return {
		"attackDamage": attack_damage,
		"log": " ".join(dot_logs)
	}
