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
    this.regen = 0;
    this.counter = 0;

    // Deck & Relics
    this.deck = [...STARTER_DECK];
    this.relicManager = new RelicManager();
    // Start with starter relic
    this.relicManager.addRelic('relic_hunmin_lens');
  }

  heal(amount) {
    const actual = Math.min(this.maxHp - this.hp, amount);
    this.hp = Math.min(this.maxHp, this.hp + amount);
    return actual;
  }

  increaseMaxHp(amount) {
    this.maxHp += amount;
    this.hp += amount;
  }

  cleanse() {
    this.poison = 0;
    this.bleed = 0;
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
    if (this.combatLogs.length > 25) this.combatLogs.pop();
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

    // Regen effect
    if (this.player.regen > 0) {
      const recovered = this.player.heal(this.player.regen);
      this.addLog(`🌿 재생 효과로 체력을 ${recovered} 회복했습니다.`);
    }

    // DoT effects on player
    if (this.player.poison > 0) {
      this.player.hp -= this.player.poison;
      this.addLog(`🧪 독으로 인해 플레이어가 ${this.player.poison}의 피해를 입었습니다.`);
      this.player.poison = Math.max(0, this.player.poison - 1);
    }
    if (this.player.bleed > 0) {
      this.player.hp -= 3;
      this.addLog(`🩸 출혈로 인해 플레이어가 3의 피해를 입었습니다.`);
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
    const cost = card.cost || 0;
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

    // 0. Cleanse
    if (card.cleanse) {
      this.player.cleanse();
      this.addLog(`✨ [${card.word}] 모든 해로운 효과(독, 출혈)를 정화했습니다!`);
    }

    // 1. Break / Strip Enemy Shield
    if (card.breakShield || card.stripShield) {
      if (this.enemy.shield > 0) {
        this.addLog(`💥 [${card.word}] ${this.enemy.name}의 방어도(${this.enemy.shield})를 산산조각 냈습니다!`);
        this.enemy.shield = 0;
      }
    }

    // 2. Calculate Damage
    let baseDmg = card.damage || 0;
    if (card.execute && this.enemy.hp <= Math.floor(this.enemy.maxHp * 0.5)) {
      baseDmg *= 2;
      this.addLog(`⚡ [${card.word}] 처형 발동! 적 체력 50% 이하 2배 피해!`);
    }

    let rawDmg = baseDmg + context.bonusDamage;
    rawDmg = Math.floor(rawDmg * context.critMultiplier);

    let totalDealt = 0;
    if (rawDmg > 0) {
      const hits = card.hits || 1;
      const isPiercing = card.pierce || false;
      for (let h = 0; h < hits; h++) {
        const res = this.enemy.takeDamage(rawDmg, isPiercing);
        totalDealt += rawDmg;
      }
      this.addLog(`💥 [${card.word}] 발동! ${this.enemy.name}에게 ${totalDealt}의 피해${isPiercing ? ' (방어 관통)' : ''}!`);

      // Vamp (흡혈)
      if (card.vamp) {
        const vampHeal = Math.max(1, Math.floor(totalDealt * (card.vamp / 100)));
        this.player.heal(vampHeal);
        this.addLog(`🩸 흡혈 효과로 HP를 ${vampHeal} 회복했습니다!`);
      }
    }

    // Play Sound
    if (sound[card.sound]) {
      sound[card.sound]();
    } else if (card.heal) {
      sound.playHeal();
    } else if (card.buffAtk || card.buffAttack || card.gainAp) {
      sound.playBuff();
    } else if (card.freeze) {
      sound.playFreeze();
    } else {
      sound.playAttack();
    }

    // 3. Shield & Defense
    const totalShield = (card.shield || 0) + context.bonusShield;
    if (totalShield > 0) {
      this.player.shield += totalShield;
      this.addLog(`🛡️ [${card.word}] 방어도 ${totalShield} 획득!`);
    }
    if (card.retainShield) {
      this.player.retainShield = true;
      this.addLog(`🏰 방어도가 다음 턴까지 유지됩니다.`);
    }
    if (card.invulnerable) {
      this.player.invulnerable += card.invulnerable;
      this.addLog(`✨ [${card.word}] 적의 공격 무효화 장막 (${card.invulnerable}회) 발동!`);
    }
    if (card.thorns) {
      this.player.thorns += card.thorns;
      this.addLog(`🌵 가시 수치가 +${card.thorns} 증가했습니다 (피격 시 적에게 반격).`);
    }
    if (card.counter) {
      this.player.counter += card.counter;
      this.addLog(`⚔️ 반격 자세를 취했습니다 (+${card.counter} 반격 피해).`);
    }

    // 4. Heal & MaxHP & Regen
    if (context.playerHeal > 0) {
      const actualHealed = this.player.heal(context.playerHeal);
      this.addLog(`💚 HP를 ${actualHealed} 회복했습니다!`);
    }
    if (card.maxHp) {
      this.player.increaseMaxHp(card.maxHp);
      this.addLog(`💖 최대 체력이 +${card.maxHp} 영구 증가했습니다!`);
    }
    if (card.regen) {
      this.player.regen += card.regen;
      this.addLog(`🌿 지속 재생 +${card.regen} 스택 획득!`);
    }

    // 5. Status Effects to Enemy
    if (card.poison || context.extraPoison) {
      const p = (card.poison || 0) + context.extraPoison;
      this.enemy.poison = (this.enemy.poison || 0) + p;
      this.addLog(`🧪 ${this.enemy.name}에게 독 ${p} 부여!`);
    }
    if (card.burn) {
      this.enemy.poison = (this.enemy.poison || 0) + card.burn;
      this.addLog(`🔥 ${this.enemy.name}에게 화상 ${card.burn} 부여!`);
    }
    if (card.bleed) {
      this.enemy.bleed = (this.enemy.bleed || 0) + card.bleed;
      this.addLog(`🩸 ${this.enemy.name}에게 출혈 ${card.bleed} 부여!`);
    }
    if (card.weak || card.weaken) {
      const w = card.weak || card.weaken || 1;
      this.enemy.weak = (this.enemy.weak || 0) + w;
      this.addLog(`💫 ${this.enemy.name}에게 취약 ${w}턴 부여! (받는 피해 50% 증가)`);
    }
    if (card.stun) {
      this.enemy.stunned = true;
      this.addLog(`⛓️ ${this.enemy.name}을(를) 기절시켰습니다! (다음 턴 행동 불가)`);
    }
    if (card.freeze) {
      this.enemy.stunned = true;
      this.addLog(`❄️ ${this.enemy.name}을(를) 빙결시켰습니다! (다음 턴 행동 불가)`);
    }

    // 6. Self Buffs / AP / Draw / Gold
    if (card.buffAtk || card.buffAttack) {
      const b = card.buffAtk || card.buffAttack || 1;
      this.player.power += b;
      this.addLog(`🥁 공격력이 영구히 +${b} 증가했습니다!`);
    }
    if (card.doublePower) {
      this.player.power = Math.max(1, this.player.power * 2);
      this.addLog(`🔥 공격력이 2배(${this.player.power})로 증폭되었습니다!`);
    }
    if (card.gainAp || card.extraAction) {
      const gain = card.gainAp || card.extraAction || 1;
      this.player.ap += gain;
      this.addLog(`⚡ 추가 행동력(AP) +${gain} 획득!`);
    }
    if (card.draw || card.drawCards) {
      const count = card.draw || card.drawCards || 1;
      this.cardSystem.draw(count);
      this.addLog(`🦅 자모 카드 ${count}장을 추가 드로우했습니다!`);
    }
    if (card.bonusGold) {
      this.player.gold += card.bonusGold;
      sound.playCoin();
      this.addLog(`🪙 황금 ${card.bonusGold} 골드를 즉시 획득했습니다!`);
    }
    if (card.selfDmg || card.selfDamage) {
      const sd = card.selfDmg || card.selfDamage || 0;
      this.player.takeDamage(sd);
      this.addLog(`🩸 자신의 체력을 ${sd} 소모했습니다.`);
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

      // Thorns / Counter back to enemy if player was attacked
      if (enemyResult.attackDamage && enemyResult.attackDamage > 0) {
        const counterDmg = this.player.thorns + this.player.counter;
        if (counterDmg > 0 && this.enemy.hp > 0) {
          this.enemy.takeDamage(counterDmg, true);
          this.addLog(`🌵 가시/반격 피해! ${this.enemy.name}에게 ${counterDmg}의 반격 피해!`);
        }
      }

      if (this.enemy.hp <= 0) {
        this.handleVictory();
        return;
      }

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
