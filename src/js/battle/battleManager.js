/**
 * <언어의 조각 : 말의 심연> Battle Manager
 * 턴제 전투 라이프사이클, 플레이어/적 상태 동기화, 데미지 계산 및 승패 처리
 */

import { CardSystem, STARTER_DECK } from './cardSystem.js';
import { EnemyInstance } from './enemyAI.js';
import { RelicManager } from './relicSystem.js';
import { sound } from '../core/soundEngine.js';

export class PlayerState {
  constructor() {
    this.maxHp = 80;
    this.hp = 80;
    this.maxAp = 1; // 1턴 1단어의 스피디한 템포
    this.ap = 1;
    this.shield = 0;
    this.gold = 99;

    // Status effects
    this.power = 0;
    this.poison = 0;
    this.bleed = 0;
    this.invulnerable = 0;
    this.retainShield = false;
    this.thorns = 0;

    // Deck & Relics
    this.deck = [...STARTER_DECK];
    this.relicManager = new RelicManager();
    // Start with starter relic
    this.relicManager.addRelic('relic_hunmin_lens');
  }

  heal(amount) {
    this.hp = Math.min(this.maxHp, this.hp + amount);
  }

  takeDamage(rawDamage) {
    if (this.invulnerable > 0) {
      this.invulnerable--;
      sound.playShield();
      return { actualHpHit: 0, shieldHit: 0, isDead: false, invulnerable: true };
    }

    let actualHpHit = 0;
    let shieldHit = 0;

    if (this.shield >= rawDamage) {
      this.shield -= rawDamage;
      shieldHit = rawDamage;
      sound.playShield();
    } else {
      shieldHit = this.shield;
      const remaining = rawDamage - this.shield;
      this.shield = 0;
      this.hp -= remaining;
      actualHpHit = remaining;
      sound.playHit();
    }

    this.hp = Math.max(0, this.hp);
    return {
      actualHpHit,
      shieldHit,
      isDead: this.hp <= 0,
      remainingHp: this.hp
    };
  }

  resetTurnStatus() {
    if (!this.retainShield) {
      this.shield = 0;
    }
    this.retainShield = false;
    this.ap = this.maxAp;
  }
}

export class BattleManager {
  constructor(player) {
    this.player = player || new PlayerState();
    this.cardSystem = new CardSystem();
    this.enemy = null;
    this.turn = 1;
    this.state = 'idle'; // 'player_turn' | 'enemy_turn' | 'victory' | 'defeat'
    this.combatLogs = [];
    this.listeners = [];
  }

  subscribe(callback) {
    this.listeners.push(callback);
  }

  notify() {
    for (const cb of this.listeners) {
      cb(this);
    }
  }

  addLog(message) {
    this.combatLogs.unshift({
      turn: this.turn,
      message,
      time: Date.now()
    });
    if (this.combatLogs.length > 20) this.combatLogs.pop();
  }

  startBattle(enemyTemplateId = 'letter_slime') {
    this.enemy = new EnemyInstance(enemyTemplateId);
    this.cardSystem.initDeck(this.player.deck);
    this.turn = 1;
    this.combatLogs = [];
    this.state = 'player_turn';

    this.addLog(`⚔️ ${this.enemy.name}과의 전투가 시작되었습니다!`);
    this.startPlayerTurn();
  }

  startPlayerTurn() {
    this.state = 'player_turn';
    this.player.resetTurnStatus();

    // DoT effects on player
    if (this.player.poison > 0) {
      this.player.hp -= this.player.poison;
      this.addLog(`독으로 인해 플레이어가 ${this.player.poison}의 피해를 입었습니다.`);
      this.player.poison = Math.max(0, this.player.poison - 1);
    }
    if (this.player.bleed > 0) {
      this.player.hp -= 3;
      this.addLog(`출혈로 인해 플레이어가 3의 피해를 입었습니다.`);
      this.player.bleed = Math.max(0, this.player.bleed - 1);
    }

    if (this.player.hp <= 0) {
      this.handleDefeat();
      return;
    }

    // Trigger Relic Turn Start
    const relicLogs = this.player.relicManager.triggerTurnStart(this.player, this.cardSystem);
    for (const msg of relicLogs) this.addLog(`👑 ${msg}`);

    // Draw 5 tiles
    this.cardSystem.draw(5);
    this.notify();
  }

  playCraftedCard() {
    const card = this.cardSystem.craftedCard;
    if (!card) return false;

    // Check AP cost
    const cost = card.cost || 1;
    if (this.player.ap < cost) {
      this.addLog(`⚠️ 행동력(AP)이 부족합니다! (필요: ${cost}, 현재: ${this.player.ap})`);
      this.notify();
      return false;
    }

    // Consume card from slots
    this.cardSystem.consumeCraftedCard();
    this.player.ap -= cost;

    // Context for relic modifiers
    const context = {
      bonusDamage: this.player.power,
      critMultiplier: card.critBonus || 1.0,
      bonusShield: 0,
      extraPoison: 0,
      playerHeal: card.heal || 0
    };

    // Trigger Relic onWordPlay
    const relicMsgs = this.player.relicManager.triggerWordPlay(card, context);
    for (const msg of relicMsgs) this.addLog(`👑 ${msg}`);

    // 1. Calculate Damage
    let rawDmg = (card.damage || 0) + context.bonusDamage;
    rawDmg = Math.floor(rawDmg * context.critMultiplier);

    if (rawDmg > 0) {
      const hits = card.hits || 1;
      let totalDealt = 0;
      for (let h = 0; h < hits; h++) {
        const res = this.enemy.takeDamage(rawDmg, card.pierce);
        totalDealt += rawDmg;
      }
      this.addLog(`💥 [${card.word}] 발동! ${this.enemy.name}에게 ${totalDealt}의 피해!`);
    }

    // Play Sound
    if (sound[card.sound]) {
      sound[card.sound]();
    } else {
      sound.playAttack();
    }

    // 2. Shield & Defense
    const totalShield = (card.shield || 0) + context.bonusShield;
    if (totalShield > 0) {
      this.player.shield += totalShield;
      this.addLog(`🛡️ [${card.word}] 방어도 ${totalShield} 획득!`);
    }
    if (card.retainShield) {
      this.player.retainShield = true;
    }
    if (card.invulnerable) {
      this.player.invulnerable += card.invulnerable;
      this.addLog(`✨ [${card.word}] 적의 공격 1회 무효화 장막 발동!`);
    }

    // 3. Heal
    if (context.playerHeal > 0) {
      this.player.heal(context.playerHeal);
      this.addLog(`💚 HP를 ${context.playerHeal} 회복했습니다!`);
    }

    // 4. Status Effects to Enemy
    if (card.poison || context.extraPoison) {
      const p = (card.poison || 0) + context.extraPoison;
      this.enemy.poison = (this.enemy.poison || 0) + p;
      this.addLog(`🧪 ${this.enemy.name}에게 독 ${p} 부여!`);
    }
    if (card.burn) {
      this.enemy.poison = (this.enemy.poison || 0) + card.burn;
      this.addLog(`🔥 ${this.enemy.name}에게 화상 ${card.burn} 부여!`);
    }
    if (card.weak) {
      this.enemy.weak = (this.enemy.weak || 0) + card.weak;
      this.addLog(`💫 ${this.enemy.name}에게 취약 1턴 부여!`);
    }
    if (card.stun) {
      this.enemy.stunned = true;
      this.addLog(`⛓️ ${this.enemy.name}을(를) 기절시켰습니다!`);
    }

    // 5. Self buffs / Draw
    if (card.buffAttack) {
      this.player.power += card.buffAttack;
      this.addLog(`🥁 공격력이 영구히 +${card.buffAttack} 증가했습니다!`);
    }
    if (card.drawCards) {
      this.cardSystem.draw(card.drawCards);
      this.addLog(`🦅 자모 카드 ${card.drawCards}장을 추가 드로우했습니다!`);
    }
    if (card.selfDamage) {
      this.player.takeDamage(card.selfDamage);
      this.addLog(`🩸 자신의 체력을 ${card.selfDamage} 소모했습니다.`);
    }

    // Check Enemy Death
    if (this.enemy.hp <= 0) {
      this.handleVictory();
      return true;
    }

    this.notify();
    return true;
  }

  endPlayerTurn() {
    if (this.state !== 'player_turn') return;
    this.state = 'enemy_turn';
    this.cardSystem.discardHandAndSlots();
    this.notify();

    // Execute enemy turn with small delay for animations
    setTimeout(() => {
      const enemyResult = this.enemy.executeTurn(this.player);
      this.addLog(enemyResult.log);

      if (this.player.hp <= 0) {
        this.handleDefeat();
        return;
      }

      this.turn++;
      this.startPlayerTurn();
    }, 600);
  }

  handleVictory() {
    this.state = 'victory';
    sound.playVictory();
    this.addLog(`🏆 승리! ${this.enemy.name}을(를) 쓰러뜨렸습니다!`);

    // Relic end hook
    const relicMsgs = this.player.relicManager.triggerBattleEnd(this.player, true);
    for (const msg of relicMsgs) this.addLog(`👑 ${msg}`);

    // Generate Rewards
    const earnedGold = 15 + Math.floor(Math.random() * 12) + (this.enemy.type === 'elite' ? 25 : 0) + (this.enemy.type === 'boss' ? 50 : 0);
    this.player.gold += earnedGold;

    this.rewards = {
      gold: earnedGold,
      tileOptions: this.generateRewardTiles(),
      relicDrop: (this.enemy.type === 'elite' || this.enemy.type === 'boss') ? this.generateRewardRelic() : null
    };

    this.notify();
  }

  generateRewardTiles() {
    const pool = ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ', 'ㅏ', 'ㅓ', 'ㅗ', 'ㅜ', 'ㅡ', 'ㅣ'];
    const chosen = [];
    while (chosen.length < 3) {
      const pick = pool[Math.floor(Math.random() * pool.length)];
      if (!chosen.includes(pick)) chosen.push(pick);
    }
    return chosen;
  }

  generateRewardRelic() {
    const allRelics = ['relic_jong_weight', 'relic_rough_flint', 'relic_vowel_bell', 'relic_ink_stone', 'relic_whetstone', 'relic_alchemist_pot', 'relic_beast_flute', 'relic_healing_incense'];
    const available = allRelics.filter(id => !this.player.relicManager.hasRelic(id));
    if (available.length === 0) return null;
    return available[Math.floor(Math.random() * available.length)];
  }

  handleDefeat() {
    this.state = 'defeat';
    sound.playHit();
    this.addLog(`💀 패배... 활자술사의 여정이 여기서 끝났습니다.`);
    this.notify();
  }
}
