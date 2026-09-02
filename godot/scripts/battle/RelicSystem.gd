# RelicSystem.gd
# 유물 시스템 매니저
class_name RelicManager
extends RefCounted

const ALL_RELICS = {
	"relic_hunmin_lens": {
		"id": "relic_hunmin_lens",
		"name": "훈민정음 돋보기",
		"icon": "res://assets/relics/relic_magnifier_32px_pastel.png",
		"desc": "매 턴 시작 시, 초성 타일 1장을 추가로 확정 드로우합니다.",
		"type": "starter"
	},
	"relic_jong_weight": {
		"id": "relic_jong_weight",
		"name": "종성의 무게추",
		"icon": "res://assets/relics/relic_crystal_32px_pastel.png",
		"desc": "받침(종성)이 포함된 단어 발동 시, 방어도 +3을 추가로 얻습니다.",
		"type": "common"
	},
	"relic_rough_flint": {
		"id": "relic_rough_flint",
		"name": "거친 부싯돌",
		"icon": "res://assets/relics/relic_ink_stone_32px_pastel.png",
		"desc": "[불] 또는 화염 계열 단어 사용 시 데미지가 25% 증가합니다.",
		"type": "common"
	},
	"relic_vowel_bell": {
		"id": "relic_vowel_bell",
		"name": "모음의 풍경",
		"icon": "res://assets/relics/relic_bell_32px_pastel.png",
		"desc": "모음 합성(이중모음) 성공 시, 플레이어 HP를 3 회복합니다.",
		"type": "uncommon"
	},
	"relic_ink_stone": {
		"id": "relic_ink_stone",
		"name": "흑단 벼루",
		"icon": "res://assets/relics/relic_seal_32px_pastel.png",
		"desc": "3글자 이상 완성 시 적 전체에게 독 2를 부여합니다.",
		"type": "uncommon"
	},
	"relic_whetstone": {
		"id": "relic_whetstone",
		"name": "명장의 숫돌",
		"icon": "res://assets/relics/relic_brush_32px_pastel.png",
		"desc": "무기(Weapon) 카테고리 단어의 피해량이 +2 증가합니다.",
		"type": "common"
	},
	"relic_alchemist_pot": {
		"id": "relic_alchemist_pot",
		"name": "연금술사의 약탕기",
		"icon": "res://assets/relics/relic_gourd_32px_pastel.png",
		"desc": "전투 승리 시 HP를 6 회복합니다.",
		"type": "uncommon"
	},
	"relic_beast_flute": {
		"id": "relic_beast_flute",
		"name": "야수의 피리",
		"icon": "res://assets/relics/relic_feather_32px_pastel.png",
		"desc": "생물/소환(Summon) 단어 발동 시 공격력이 +1 영구 증가합니다.",
		"type": "rare"
	},
	"relic_sage_scroll": {
		"id": "relic_sage_scroll",
		"name": "현자의 두루마리",
		"icon": "res://assets/relics/relic_scroll_32px_pastel.png",
		"desc": "상점 이용 시 모든 단어/자모의 가격이 20% 할인됩니다.",
		"type": "rare"
	},
	"relic_healing_incense": {
		"id": "relic_healing_incense",
		"name": "치유의 향로",
		"icon": "🪔",
		"desc": "매 턴 시작 시 방어도 3을 무료로 얻습니다.",
		"type": "rare"
	}
}

var relics: Array = []

func has_relic(id: String) -> bool:
	for r in relics:
		if r["id"] == id:
			return true
	return false

func add_relic(id: String) -> bool:
	if not ALL_RELICS.has(id):
		return false
	if has_relic(id):
		return false
	relics.append(ALL_RELICS[id].duplicate(true))
	return true

func trigger_turn_start(player, card_sys) -> Array:
	var logs = []
	if has_relic("relic_hunmin_lens"):
		card_sys.draw_specific_pool(["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"])
		logs.append("[훈민정음 돋보기] 초성 타일을 1장 추가로 획득했습니다.")
	if has_relic("relic_healing_incense"):
		player.shield += 3
		logs.append("[치유의 향로] 방어도 3을 획득했습니다.")
	return logs

func trigger_word_play(card_data: Dictionary, context: Dictionary) -> Array:
	var logs = []
	if has_relic("relic_jong_weight"):
		if card_data.get("hasJong", false) or card_data.get("jong", "") != "":
			context["bonusShield"] = context.get("bonusShield", 0) + 3
			logs.append("[종성의 무게추] 받침 단어 보너스 방어도 +3 획득!")
	if has_relic("relic_rough_flint"):
		if card_data.get("category", "") == "element" or card_data.get("word", "") == "불":
			context["critMultiplier"] = context.get("critMultiplier", 1.0) * 1.25
			logs.append("[거친 부싯돌] 원소/화염 단어 피해량 25% 증폭!")
	if has_relic("relic_whetstone"):
		if card_data.get("category", "") == "weapon":
			context["bonusDamage"] = context.get("bonusDamage", 0) + 2
			logs.append("[명장의 숫돌] 무기 피해량 +2 증가!")
	return logs

func trigger_battle_end(player, is_victory: bool) -> Array:
	var logs = []
	if is_victory and has_relic("relic_alchemist_pot"):
		player.heal(6)
		logs.append("[연금술사의 약탕기] 전투 승리로 체력을 6 회복했습니다.")
	return logs
