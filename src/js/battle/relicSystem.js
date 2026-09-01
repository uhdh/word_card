/**
 * <언어의 조각 : 말의 심연> Relic (유물) System
 * 한글 음운 규칙 및 단어 테마 시너지 유물 관리
 */

export const RELIC_DATABASE = {
  // === 01. 한글 음운/형태 규칙 유물 ===
  'relic_jong_weight': {
    id: 'relic_jong_weight',
    name: '종성의 무게추',
    tier: 'common',
    desc: '받침(종성)이 있는 단어 발동 시 추가 피해 +5',
    icon: '⚖️',
    onWordPlay: (wordData, context) => {
      if (wordData.tags && wordData.tags.includes('has_jong') && wordData.damage > 0) {
        context.bonusDamage += 5;
        return '종성의 무게추 발동! (피해 +5)';
      }
    }
  },
  'relic_rough_flint': {
    id: 'relic_rough_flint',
    name: '거센소리 부싯돌',
    tier: 'rare',
    desc: '거센소리(ㅋ, ㅌ, ㅍ, ㅊ) 단어 공격 시 100% 치명타 (피해량 1.5배)',
    icon: '🔥',
    onWordPlay: (wordData, context) => {
      if (wordData.tags && wordData.tags.includes('rough') && wordData.damage > 0) {
        context.critMultiplier *= 1.5;
        return '거센소리 부싯돌 발동! (치명타 1.5배)';
      }
    }
  },
  'relic_vowel_bell': {
    id: 'relic_vowel_bell',
    name: '울림소리 방울',
    tier: 'common',
    desc: '울림소리(ㄴ, ㄹ, ㅁ, ㅇ) 받침 단어 발동 시 HP 2 회복',
    icon: '🔔',
    onWordPlay: (wordData, context) => {
      if (wordData.tags && wordData.tags.includes('rieul_mim')) {
        context.playerHeal += 2;
        return '울림소리 방울 발동! (HP 2 회복)';
      }
    }
  },
  'relic_ink_stone': {
    id: 'relic_ink_stone',
    name: '된소리의 벼루',
    tier: 'rare',
    desc: '된소리(ㄲ, ㄸ, ㅃ, ㅆ, ㅉ) 단어 발동 시 방어도 +6 획득',
    icon: '🪨',
    onWordPlay: (wordData, context) => {
      if (wordData.tags && wordData.tags.includes('double_cho')) {
        context.bonusShield += 6;
        return '된소리의 벼루 발동! (방어도 +6)';
      }
    }
  },

  // === 02. 단어 테마 시너지 유물 ===
  'relic_whetstone': {
    id: 'relic_whetstone',
    name: '명장의 숫돌',
    tier: 'common',
    desc: '무기 단어(검, 칼, 창, 활 등) 사용 시 피해량 +3 및 방어도 2 획득',
    icon: '🗡️',
    onWordPlay: (wordData, context) => {
      if (wordData.category === 'weapon') {
        context.bonusDamage += 3;
        context.bonusShield += 2;
        return '명장의 숫돌 발동! (피해 +3, 방어도 +2)';
      }
    }
  },
  'relic_alchemist_pot': {
    id: 'relic_alchemist_pot',
    name: '연금술사의 도가니',
    tier: 'rare',
    desc: '원소/마법 단어 발동 시 적에게 독 2스택 추가 부여',
    icon: '🧪',
    onWordPlay: (wordData, context) => {
      if (wordData.category === 'element') {
        context.extraPoison += 2;
        return '연금술사의 도가니 발동! (독 +2)';
      }
    }
  },
  'relic_beast_flute': {
    id: 'relic_beast_flute',
    name: '야수 조련용 피리',
    tier: 'common',
    desc: '생물/소환 단어 발동 시 8의 방어도 추가 획득',
    icon: '🪈',
    onWordPlay: (wordData, context) => {
      if (wordData.category === 'summon') {
        context.bonusShield += 8;
        return '야수 조련용 피리 발동! (방어도 +8)';
      }
    }
  },

  // === 03. 자모 조작 & 드로우 유물 ===
  'relic_hunmin_lens': {
    id: 'relic_hunmin_lens',
    name: '훈민정음 돋보기',
    tier: 'starter',
    desc: '매 턴 시작 시 모음 타일 1장 확정 추가 드로우',
    icon: '🔍',
    onTurnStart: (player, battle) => {
      battle.drawSpecificType('vowel', 1);
      return '훈민정음 돋보기 발동! (모음 1장 드로우)';
    }
  },
  'relic_healing_incense': {
    id: 'relic_healing_incense',
    name: '치유의 향로',
    tier: 'common',
    desc: '전투 종료 시 체력을 6 회복',
    icon: '🕯️',
    onBattleEnd: (player, victory) => {
      if (victory) {
        player.heal(6);
        return '치유의 향로 발동! (HP 6 회복)';
      }
    }
  }
};

export class RelicManager {
  constructor() {
    this.relics = [];
  }

  addRelic(relicId) {
    if (RELIC_DATABASE[relicId] && !this.hasRelic(relicId)) {
      this.relics.push(RELIC_DATABASE[relicId]);
      return RELIC_DATABASE[relicId];
    }
    return null;
  }

  hasRelic(relicId) {
    return this.relics.some(r => r.id === relicId);
  }

  triggerTurnStart(player, battle) {
    const logs = [];
    for (const r of this.relics) {
      if (r.onTurnStart) {
        const msg = r.onTurnStart(player, battle);
        if (msg) logs.push(msg);
      }
    }
    return logs;
  }

  triggerWordPlay(wordData, context) {
    const logs = [];
    for (const r of this.relics) {
      if (r.onWordPlay) {
        const msg = r.onWordPlay(wordData, context);
        if (msg) logs.push(msg);
      }
    }
    return logs;
  }

  triggerBattleEnd(player, victory) {
    const logs = [];
    for (const r of this.relics) {
      if (r.onBattleEnd) {
        const msg = r.onBattleEnd(player, victory);
        if (msg) logs.push(msg);
      }
    }
    return logs;
  }
}
