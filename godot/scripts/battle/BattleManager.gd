# BattleManager.gd
# 턴제 전투 라이프사이클, 플레이어/적 상태 동기화, 100개 단어 특수 능력 발동 및 승패 처리
class_name BattleManager
extends RefCounted

signal state_changed
signal combat_log_added(message: String)

var player: PlayerState
var card_system: CardSystem
var enemy: EnemyInstance

var turn: int = 1
var state: String = "idle" # "player_turn" | "enemy_turn" | "victory" | "defeat"
var combat_logs: Array[Dictionary] = []
var rewards: Dictionary = {}

func _init(p_player: PlayerState = null) -> void:
	player = p_player if p_player != null else PlayerState.new()
	card_system = CardSystem.new()

func add_log(msg: String) -> void:
	combat_logs.push_front({
		"turn": turn,
		"message": msg,
		"time": Time.get_ticks_msec()
	})
	if combat_logs.size() > 30:
		combat_logs.pop_back()
	combat_log_added.emit(msg)

func start_battle(enemy_template_id: String = "letter_slime") -> void:
	enemy = EnemyInstance.new(enemy_template_id)
	card_system.init_deck(player.deck)
	turn = 1
	combat_logs.clear()
	state = "player_turn"

	add_log("⚔️ %s과의 전투가 시작되었습니다!" % enemy.name)
	start_player_turn()

func start_player_turn() -> void:
	state = "player_turn"
	player.reset_turn_status()

	# Regen effect
	if player.regen > 0:
		var recovered = player.heal(player.regen)
		add_log("🌿 재생 효과로 체력을 %d 회복했습니다." % recovered)

	# DoT effects
	if player.poison > 0:
		player.hp -= player.poison
		add_log("🧪 독으로 인해 플레이어가 %d의 피해를 입었습니다." % player.poison)
		player.poison = maxi(0, player.poison - 1)

	if player.bleed > 0:
		player.hp -= 3
		add_log("🩸 출혈로 인해 플레이어가 3의 피해를 입었습니다.")
		player.bleed = maxi(0, player.bleed - 1)

	if player.hp <= 0:
		handle_defeat()
		return

	# Relic Turn Start Hooks
	var relic_logs = player.relic_manager.trigger_turn_start(player, card_system)
	for m in relic_logs:
		add_log("👑 " + m)

	# Draw 5 tiles
	card_system.draw(5)
	state_changed.emit()

func play_crafted_card() -> bool:
	var card = card_system.crafted_card
	if card.is_empty():
		return false

	var cost = card.get("cost", 0)
	if player.ap < cost:
		add_log("⚠️ 행동력(AP)이 부족합니다! (필요: %d, 현재: %d)" % [cost, player.ap])
		state_changed.emit()
		return false

	card_system.consume_crafted_card()
	player.ap -= cost

	var context = {
		"bonusDamage": player.power,
		"critMultiplier": card.get("critBonus", 1.0),
		"bonusShield": 0,
		"extraPoison": 0,
		"playerHeal": card.get("heal", 0)
	}

	var relic_msgs = player.relic_manager.trigger_word_play(card, context)
	for m in relic_msgs:
		add_log("👑 " + m)

	# 0. Cleanse
	if card.get("cleanse", false):
		player.cleanse()
		add_log("✨ [%s] 모든 해로운 효과(독, 출혈)를 정화했습니다!" % card["word"])

	# 1. Break / Strip Enemy Shield
	if card.get("breakShield", false) or card.get("stripShield", false):
		if enemy.shield > 0:
			add_log("💥 [%s] %s의 방어도(%d)를 산산조각 냈습니다!" % [card["word"], enemy.name, enemy.shield])
			enemy.shield = 0

	# 2. Damage calculation
	var base_dmg = card.get("damage", 0)
	if card.get("execute", false) and enemy.hp <= int(enemy.max_hp * 0.5):
		base_dmg *= 2
		add_log("⚡ [%s] 처형 발동! 적 체력 50%% 이하 2배 피해!" % card["word"])

	var raw_dmg = base_dmg + context["bonusDamage"]
	raw_dmg = int(raw_dmg * context["critMultiplier"])

	var total_dealt = 0
	if raw_dmg > 0:
		var hits = card.get("hits", 1)
		var is_piercing = card.get("pierce", false)
		for h in range(hits):
			enemy.take_damage(raw_dmg, is_piercing)
			total_dealt += raw_dmg
		add_log("💥 [%s] 발동! %s에게 %d의 피해%s!" % [card["word"], enemy.name, total_dealt, " (방어 관통)" if is_piercing else ""])

		# Vamp
		if card.has("vamp"):
			var vamp_heal = maxi(1, int(total_dealt * (float(card["vamp"]) / 100.0)))
			player.heal(vamp_heal)
			add_log("🩸 흡혈 효과로 HP를 %d 회복했습니다!" % vamp_heal)

	# Audio
	var sound_name = card.get("sound", "")
	if sound_name == "playShield": SoundEngine.play_shield()
	elif sound_name == "playMagic": SoundEngine.play_magic()
	elif sound_name == "playSummon": SoundEngine.play_summon()
	elif card.has("heal"): SoundEngine.play_heal()
	elif card.has("buffAtk") or card.has("buffAttack") or card.has("gainAp"): SoundEngine.play_buff()
	elif card.has("freeze"): SoundEngine.play_freeze()
	else: SoundEngine.play_attack()

	# 3. Shield & Defense
	var total_shield = card.get("shield", 0) + context["bonusShield"]
	if total_shield > 0:
		player.shield += total_shield
		add_log("🛡️ [%s] 방어도 %d 획득!" % [card["word"], total_shield])
	if card.get("retainShield", false):
		player.retain_shield = true
		add_log("🏰 방어도가 다음 턴까지 유지됩니다.")
	if card.has("invulnerable"):
		player.invulnerable += card["invulnerable"]
		add_log("✨ [%s] 적 공격 무효화 장막 (%d회) 발동!" % [card["word"], card["invulnerable"]])
	if card.has("thorns"):
		player.thorns += card["thorns"]
		add_log("🌵 가시 수치 +%d 증가 (피격 시 적에게 반격)" % card["thorns"])
	if card.has("counter"):
		player.counter += card["counter"]
		add_log("⚔️ 반격 자세 (+%d 반격 피해)" % card["counter"])

	# 4. Heal & MaxHP & Regen
	if context["playerHeal"] > 0:
		var actual_healed = player.heal(context["playerHeal"])
		add_log("💚 HP를 %d 회복했습니다!" % actual_healed)
	if card.has("maxHp"):
		player.increase_max_hp(card["maxHp"])
		add_log("💖 최대 체력 +%d 영구 증가!" % card["maxHp"])
	if card.has("regen"):
		player.regen += card["regen"]
		add_log("🌿 지속 재생 +%d 스택 획득!" % card["regen"])

	# 5. Status Effects
	if card.has("poison") or context.get("extraPoison", 0) > 0:
		var p = card.get("poison", 0) + context.get("extraPoison", 0)
		enemy.poison += p
		add_log("🧪 %s에게 독 %d 부여!" % [enemy.name, p])
	if card.has("burn"):
		enemy.poison += card["burn"]
		add_log("🔥 %s에게 화상 %d 부여!" % [enemy.name, card["burn"]])
	if card.has("bleed"):
		enemy.bleed += card["bleed"]
		add_log("🩸 %s에게 출혈 %d 부여!" % [enemy.name, card["bleed"]])
	if card.has("weak") or card.has("weaken"):
		var w = card.get("weak", card.get("weaken", 1))
		enemy.weak += w
		add_log("💫 %s에게 취약 %d턴 부여!" % [enemy.name, w])
	if card.get("stun", false) or card.get("freeze", false):
		enemy.stunned = true
		add_log("⛓️ %s을(를) 기절/빙결시켰습니다! (다음 턴 행동 불가)" % enemy.name)

	# 6. Buffs / AP / Draw / Gold
	if card.has("buffAtk") or card.has("buffAttack"):
		var b = card.get("buffAtk", card.get("buffAttack", 1))
		player.power += b
		add_log("🥁 공격력이 영구히 +%d 증가했습니다!" % b)
	if card.get("doublePower", false):
		player.power = maxi(1, player.power * 2)
		add_log("🔥 공격력이 2배(%d)로 증폭되었습니다!" % player.power)
	if card.has("gainAp") or card.has("extraAction"):
		var gain = card.get("gainAp", card.get("extraAction", 1))
		player.ap += gain
		add_log("⚡ 추가 행동력(AP) +%d 획득!" % gain)
	if card.has("draw") or card.has("drawCards"):
		var count = card.get("draw", card.get("drawCards", 1))
		card_system.draw(count)
		add_log("🦅 자모 카드 %d장 추가 드로우!" % count)
	if card.has("bonusGold"):
		player.gold += card["bonusGold"]
		SoundEngine.play_coin()
		add_log("🪙 황금 %d 골드를 즉시 획득했습니다!" % card["bonusGold"])
	if card.has("selfDmg") or card.has("selfDamage"):
		var sd = card.get("selfDmg", card.get("selfDamage", 0))
		player.take_damage(sd)
		add_log("🩸 자신의 체력을 %d 소모했습니다." % sd)

	# Check Death
	if enemy.hp <= 0:
		handle_victory()
		return true

	state_changed.emit()
	return true

func end_player_turn() -> void:
	if state != "player_turn":
		return
	state = "enemy_turn"
	card_system.discard_hand_and_slots()
	state_changed.emit()

	var enemy_result = enemy.execute_turn(player)
	add_log(enemy_result["log"])

	# Thorns / Counter back to enemy
	var attack_damage = enemy_result.get("attackDamage", 0)
	if attack_damage > 0:
		var counter_dmg = player.thorns + player.counter
		if counter_dmg > 0 and enemy.hp > 0:
			enemy.take_damage(counter_dmg, true)
			add_log("🌵 가시/반격 피해! %s에게 %d의 반격 피해!" % [enemy.name, counter_dmg])

	if enemy.hp <= 0:
		handle_victory()
		return

	if player.hp <= 0:
		handle_defeat()
		return

	turn += 1
	start_player_turn()

func handle_victory() -> void:
	state = "victory"
	SoundEngine.play_victory()
	add_log("🏆 승리! %s을(를) 쓰러뜨렸습니다!" % enemy.name)

	var relic_msgs = player.relic_manager.trigger_battle_end(player, true)
	for m in relic_msgs:
		add_log("👑 " + m)

	var earned_gold = 15 + (randi() % 12) + (25 if enemy.type == "elite" else 0) + (50 if enemy.type == "boss" else 0)
	player.gold += earned_gold

	rewards = {
		"gold": earned_gold,
		"tileOptions": generate_reward_tiles(),
		"relicDrop": generate_reward_relic() if (enemy.type == "elite" or enemy.type == "boss") else null
	}
	state_changed.emit()

func generate_reward_tiles() -> Array:
	var pool = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ", "ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"]
	var chosen = []
	while chosen.size() < 3:
		var pick = pool.pick_random()
		if not chosen.has(pick):
			chosen.append(pick)
	return chosen

func generate_reward_relic():
	var all_relics = ["relic_jong_weight", "relic_rough_flint", "relic_vowel_bell", "relic_ink_stone", "relic_whetstone", "relic_alchemist_pot", "relic_beast_flute", "relic_healing_incense"]
	var available = []
	for id in all_relics:
		if not player.relic_manager.has_relic(id):
			available.append(id)
	if available.is_empty():
		return null
	return available.pick_random()

func handle_defeat() -> void:
	state = "defeat"
	SoundEngine.play_hit()
	add_log("💀 패배... 활자술사의 여정이 여기서 끝났습니다.")
	state_changed.emit()
