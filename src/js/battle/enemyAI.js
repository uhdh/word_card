/**
 * <언어의 조각 : 말의 심연> Enemy AI & Intent System
 * 1막(Act 1. 흩어진 활자의 숲) 몬스터 데이터 및 행동 패턴
 */

export const ENEMIES_ACT_1 = {
  // === 일반 몬스터 (Common) - 2~3턴 컷 ===
  'letter_slime': {
    id: 'letter_slime',
    name: '낱자 슬라임',
    maxHp: 16,
    icon: './assets/04_생물_소환/snake_뱀/snake_1_32px_pastel.png',
    type: 'normal',
    moves: [
      { name: '먹물 뱉기', type: 'attack', damage: 4, desc: '4의 피해를 입힙니다.' },
      { name: '점액 방벽', type: 'defense', shield: 5, desc: '5의 방어도를 얻습니다.' },
      { name: '오염된 산성', type: 'attack_debuff', damage: 3, poison: 1, desc: '3의 피해와 1의 독을 부여합니다.' }
    ]
  },
  'wild_boar': {
    id: 'wild_boar',
    name: '사나운 멧돼지',
    maxHp: 22,
    icon: './assets/04_생물_소환/dog_wolf_개/dog_wolf_1_32px_pastel.png',
    type: 'normal',
    moves: [
      { name: '돌진 들이받기', type: 'attack', damage: 7, desc: '7의 돌진 피해를 입힙니다.' },
      { name: '전의 고취', type: 'buff', buffPower: 2, desc: '자신의 공격력을 +2 증가시킵니다.' },
      { name: '위협의 포효', type: 'debuff', weak: 1, damage: 3, desc: '3의 피해를 입히고 1턴간 취약을 겁니다.' }
    ]
  },
  'thorn_vine': {
    id: 'thorn_vine',
    name: '가시 돋친 넝쿨',
    maxHp: 18,
    icon: './assets/04_생물_소환/herb_plant_풀/herb_plant_1_32px_pastel.png',
    type: 'normal',
    moves: [
      { name: '가시 채찍', type: 'attack', damage: 5, bleed: 2, desc: '5의 피해와 2턴간 출혈을 입힙니다.' },
      { name: '가시 껍질', type: 'defense_buff', shield: 6, thorns: 2, desc: '6의 방어도와 2의 가시를 얻습니다.' }
    ]
  },

  // === 엘리트 몬스터 (Elite) ===
  'ink_spirit': {
    id: 'ink_spirit',
    name: '먹물 웅덩이의 악령',
    maxHp: 38,
    icon: './assets/04_생물_소환/dragon_용/dragon_1_32px_pastel.png',
    type: 'elite',
    moves: [
      { name: '먹물 폭풍', type: 'attack', damage: 9, desc: '9의 암흑 피해를 입힙니다.' },
      { name: '부식 침식', type: 'defense_debuff', shield: 8, poison: 2, desc: '8의 방어도를 얻고 2의 독을 부여합니다.' },
      { name: '영혼 흡수', type: 'attack_heal', damage: 6, heal: 5, desc: '6 피해를 입히고 체력을 5 흡혈합니다.' }
    ]
  },

  // === 1막 보스 (Boss) ===
  'ink_golem': {
    id: 'ink_golem',
    name: '먹물에 잠식된 서예 골렘',
    maxHp: 65,
    icon: './assets/04_생물_소환/bear_곰/bear_1_32px_pastel.png',
    type: 'boss',
    moves: [
      { name: '대필 일격', type: 'attack', damage: 8, desc: '8의 묵직한 붓질 타격을 가합니다.' },
      { name: '먹물 요새화', type: 'defense_buff', shield: 10, buffPower: 1, desc: '10 방어도를 얻고 공격력이 +1 증가합니다.' },
      { name: '묵향 난무', type: 'multi_attack', damage: 4, hits: 3, desc: '4의 피해를 3회 연속 타격합니다!' },
      { name: '침묵의 도장', type: 'heavy_attack', damage: 12, desc: '12의 강력한 일격을 준비합니다!' }
    ]
  }
};

export class EnemyInstance {
  constructor(templateId) {
    const template = ENEMIES_ACT_1[templateId] || ENEMIES_ACT_1['letter_slime'];
    this.id = template.id;
    this.name = template.name;
    this.maxHp = template.maxHp;
    this.hp = template.maxHp;
    this.shield = 0;
    this.type = template.type;
    this.icon = template.icon;
    this.moves = template.moves;
    this.moveIndex = 0;

    // Status effects
    this.power = 0;
    this.poison = 0;
    this.bleed = 0;
    this.weak = 0;
    this.thorns = 0;
    this.stunned = false;

    this.nextMove = this.decideNextMove();
  }

  decideNextMove() {
    const move = this.moves[this.moveIndex % this.moves.length];
    this.moveIndex++;
    return move;
  }

  takeDamage(rawDamage, isPiercing = false) {
    let damage = rawDamage;
    if (this.weak > 0) {
      damage = Math.floor(damage * 1.5);
    }

    let actualHpHit = 0;
    if (isPiercing) {
      this.hp -= damage;
      actualHpHit = damage;
    } else {
      if (this.shield >= damage) {
        this.shield -= damage;
      } else {
        const remaining = damage - this.shield;
        this.shield = 0;
        this.hp -= remaining;
        actualHpHit = remaining;
      }
    }
    this.hp = Math.max(0, this.hp);
    return { actualHpHit, remainingHp: this.hp, isDead: this.hp <= 0 };
  }

  executeTurn(player) {
    if (this.stunned) {
      this.stunned = false;
      this.nextMove = this.decideNextMove();
      return { log: `${this.name}은(는) 기절하여 행동하지 못했습니다!` };
    }

    // Reset shield at turn start
    this.shield = 0;

    // DoT effects
    let dotLogs = [];
    if (this.poison > 0) {
      this.hp -= this.poison;
      dotLogs.push(`${this.name}이(가) 독으로 ${this.poison}의 피해를 입었습니다.`);
      this.poison = Math.max(0, this.poison - 1);
    }
    if (this.bleed > 0) {
      this.hp -= 3;
      dotLogs.push(`${this.name}이(가) 출혈로 3의 피해를 입었습니다.`);
      this.bleed = Math.max(0, this.bleed - 1);
    }

    if (this.hp <= 0) {
      return { log: dotLogs.join(' ') + ` ${this.name} 처치!` };
    }

    const move = this.nextMove;
    const moveLogs = [];

    // Calculate actual attack damage with power
    const dmg = (move.damage || 0) + this.power;

    if (move.type === 'attack') {
      const res = player.takeDamage(dmg);
      moveLogs.push(`${this.name}의 [${move.name}]! 플레이어에게 ${dmg}의 피해!`);
    } else if (move.type === 'multi_attack') {
      let total = 0;
      for (let i = 0; i < (move.hits || 2); i++) {
        player.takeDamage(dmg);
        total += dmg;
      }
      moveLogs.push(`${this.name}의 [${move.name}]! 플레이어에게 총 ${total}의 연속 피해!`);
    } else if (move.type === 'defense') {
      this.shield += move.shield || 0;
      moveLogs.push(`${this.name}이(가) [${move.name}]으로 방어도 ${move.shield}을(를) 얻었습니다.`);
    } else if (move.type === 'buff') {
      this.power += move.buffPower || 0;
      moveLogs.push(`${this.name}이(가) [${move.name}]으로 공격력이 +${move.buffPower} 증가했습니다.`);
    } else if (move.type === 'attack_debuff') {
      player.takeDamage(dmg);
      if (move.poison) player.poison = (player.poison || 0) + move.poison;
      moveLogs.push(`${this.name}의 [${move.name}]! 피해 ${dmg} 및 독 ${move.poison} 부여!`);
    } else if (move.type === 'defense_buff') {
      this.shield += move.shield || 0;
      if (move.thorns) this.thorns += move.thorns;
      moveLogs.push(`${this.name}이(가) [${move.name}]으로 방어도와 가시를 얻었습니다.`);
    } else if (move.type === 'heavy_attack') {
      player.takeDamage(dmg);
      moveLogs.push(`${this.name}의 [${move.name}]! 플레이어에게 강력한 ${dmg}의 피해!`);
    }

    if (this.weak > 0) this.weak--;

    // Prepare next turn's move
    this.nextMove = this.decideNextMove();

    return {
      log: [...dotLogs, ...moveLogs].join(' ')
    };
  }
}
