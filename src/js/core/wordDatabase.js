/**
 * <언어의 조각 : 말의 심연> 1글자 단어 카드 데이터베이스
 * 37종 단어의 전투 스펙 (데미지, 방어도, 특수 효과, 사운드, 에셋 경로, 음운 속성)
 */

export const WORD_DATABASE = {
  // === 01. 무기 / 물리 공격 ===
  '검': {
    word: '검',
    name: '검 (Sword)',
    category: 'weapon',
    cost: 1,
    damage: 10,
    shield: 0,
    desc: '적에게 10의 물리 피해를 입힙니다.',
    icon: './assets/01_무기_공격/sword_검/sword_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'weapon', 'rieul_mim'] // 종성 ㅁ (울림소리)
  },
  '칼': {
    word: '칼',
    name: '칼 (Dagger)',
    category: 'weapon',
    cost: 1,
    damage: 7,
    critBonus: 1.5,
    desc: '적에게 7의 피해를 2회 입히며, 30% 확률로 치명타가 발동합니다.',
    hits: 2,
    icon: './assets/01_무기_공격/dagger_칼/dagger_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'weapon', 'rough', 'rieul_mim'] // ㅋ(거센소리), ㄹ(울림소리)
  },
  '창': {
    word: '창',
    name: '창 (Spear)',
    category: 'weapon',
    cost: 1,
    damage: 12,
    pierce: true,
    desc: '적의 방어도를 무시하고 12의 관통 피해를 입힙니다.',
    icon: './assets/01_무기_공격/spear_창/spear_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'weapon', 'rough', 'rieul_mim'] // ㅊ(거센소리), ㅇ(울림소리)
  },
  '활': {
    word: '활',
    name: '활 (Bow)',
    category: 'weapon',
    cost: 1,
    damage: 9,
    weak: 1,
    desc: '적에게 9의 피해를 입히고 1턴간 취약(받는 피해 50% 증가)을 부여합니다.',
    icon: './assets/01_무기_공격/bow_활/bow_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'weapon', 'rieul_mim'] // ㄹ(울림소리)
  },
  '총': {
    word: '총',
    name: '총 (Gun)',
    category: 'weapon',
    cost: 1,
    damage: 13,
    desc: '적에게 13의 강력한 총탄 피해를 입힙니다.',
    icon: './assets/01_무기_공격/gun_총/gun_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'weapon', 'rough', 'rieul_mim'] // ㅊ(거센소리), ㅇ(울림소리)
  },
  '도': {
    word: '도',
    name: '도 (Axe / Blade)',
    category: 'weapon',
    cost: 1,
    damage: 8,
    bleed: 3,
    desc: '적에게 8의 피해를 입히고 3턴간 출혈(매 턴 3 피해)을 부여합니다.',
    icon: './assets/01_무기_공격/axe_mace_도/axe_mace_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['no_jong', 'weapon']
  },
  '봉': {
    word: '봉',
    name: '봉 (Staff)',
    category: 'weapon',
    cost: 1,
    damage: 6,
    magicPower: 2,
    desc: '적에게 6의 피해를 입히고, 다음 마법 단어의 위력을 +4 증가시킵니다.',
    icon: './assets/01_무기_공격/staff_봉/staff_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'weapon', 'rieul_mim'] // ㅇ(울림소리)
  },

  // === 02. 방어 / 장비 ===
  '방': {
    word: '방',
    name: '방 (Shield / Guard)',
    category: 'defense',
    cost: 1,
    damage: 0,
    shield: 10,
    desc: '10의 방어도를 획득합니다.',
    icon: './assets/02_방어_장비/shield_방/shield_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'defense', 'rieul_mim'] // ㅇ(울림소리)
  },
  '갑': {
    word: '갑',
    name: '갑 (Armor)',
    category: 'defense',
    cost: 1,
    damage: 0,
    shield: 14,
    desc: '14의 단단한 철갑 방어도를 획득합니다.',
    icon: './assets/02_방어_장비/armor_갑/armor_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'defense']
  },
  '약': {
    word: '약',
    name: '약 (Potion / Heal)',
    category: 'skill',
    cost: 1,
    damage: 0,
    heal: 8,
    desc: '체력을 8 회복하고 해로운 효과 1개를 정화합니다.',
    icon: './assets/03_원소_마법/potion_약/potion_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'magic', 'heal']
  },
  '끈': {
    word: '끈',
    name: '끈 (Rope / Bind)',
    category: 'skill',
    cost: 1,
    damage: 3,
    stun: true,
    desc: '적을 포박하여 1턴간 행동 불능(기절)으로 만듭니다. (엘리트/보스는 1턴 약화)',
    icon: './assets/02_방어_장비/rope_끈/rope_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'defense', 'double_cho', 'rieul_mim'] // ㄲ(된소리), ㄴ(울림소리)
  },
  '북': {
    word: '북',
    name: '북 (Drum / Buff)',
    category: 'skill',
    cost: 1,
    buffAttack: 3,
    desc: '군악을 울려 이번 전투 동안 모든 공격 단어의 피해량을 +3 증가시킵니다.',
    icon: './assets/02_방어_장비/drum_북/drum_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'defense']
  },

  // === 03. 원소 / 마법 ===
  '불': {
    word: '불',
    name: '불 (Fire)',
    category: 'element',
    cost: 1,
    damage: 7,
    burn: 4,
    desc: '적에게 7의 화염 피해를 입히고 3턴간 화상(매 턴 4 피해)을 부여합니다.',
    icon: './assets/03_원소_마법/fire_불/fire_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'element', 'rieul_mim'] // ㄹ(울림소리)
  },
  '물': {
    word: '물',
    name: '물 (Water)',
    category: 'element',
    cost: 1,
    damage: 6,
    shield: 6,
    cleanse: true,
    desc: '적에게 6의 피해를 입히고, 6의 방어도를 얻으며 자신을 정화합니다.',
    icon: './assets/03_원소_마법/water_물/water_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'element', 'rieul_mim'] // ㄹ(울림소리)
  },
  '빛': {
    word: '빛',
    name: '빛 (Holy Light)',
    category: 'element',
    cost: 1,
    damage: 9,
    blind: 1,
    desc: '적에게 9의 신성 피해를 입히고 1턴간 실명(적 공격 빗나감 50%)을 부여합니다.',
    icon: './assets/03_원소_마법/light_빛/light_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'element', 'light']
  },
  '독': {
    word: '독',
    name: '독 (Poison)',
    category: 'element',
    cost: 1,
    poison: 6,
    desc: '적에게 6의 맹독을 주입합니다. (독은 턴마다 피해를 입히고 1씩 감소)',
    icon: './assets/03_원소_마법/poison_독/poison_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'element', 'poison']
  },
  '피': {
    word: '피',
    name: '피 (Blood)',
    category: 'element',
    cost: 1,
    damage: 14,
    selfDamage: 3,
    desc: '자신의 HP를 3 소모하여 적에게 14의 묵직한 혈액 피해를 입힙니다.',
    icon: './assets/03_원소_마법/blood_피/blood_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['no_jong', 'element', 'rough'] // ㅍ(거센소리)
  },
  '뼈': {
    word: '뼈',
    name: '뼈 (Bone Spear)',
    category: 'element',
    cost: 1,
    damage: 11,
    desc: '날카로운 해골 뼈를 발사하여 적에게 11의 관통 피해를 입힙니다.',
    icon: './assets/03_원소_마법/bone_뼈/bone_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['no_jong', 'element', 'double_cho'] // ㅃ(된소리)
  },
  '돌': {
    word: '돌',
    name: '돌 (Stone)',
    category: 'element',
    cost: 1,
    damage: 8,
    shield: 4,
    desc: '적에게 8의 돌을 던지고 4의 방어도를 얻습니다.',
    icon: './assets/03_원소_마법/stone_돌/stone_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'element', 'rieul_mim'] // ㄹ(울림소리)
  },
  '눈': {
    word: '눈',
    name: '눈 (Snow / Freeze)',
    category: 'element',
    cost: 1,
    damage: 6,
    freeze: 1,
    desc: '적에게 6의 냉기 피해를 입히고 1턴간 적의 공격력을 -3 감소시킵니다.',
    icon: './assets/03_원소_마법/snow_ice_눈/snow_ice_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'element', 'rieul_mim'] // ㄴ(울림소리)
  },

  // === 04. 생물 / 소환 ===
  '곰': {
    word: '곰',
    name: '곰 (Bear Summon)',
    category: 'summon',
    cost: 1,
    damage: 6,
    shield: 8,
    taunt: true,
    desc: '우직한 곰을 소환합니다. 적에게 6 피해를 입히고 8 실드를 얻습니다.',
    icon: './assets/04_생물_소환/bear_곰/bear_1_32px_pastel.png',
    sound: 'playSummon',
    tags: ['has_jong', 'summon', 'rieul_mim'] // ㅁ(울림소리)
  },
  '뱀': {
    word: '뱀',
    name: '뱀 (Snake Summon)',
    category: 'summon',
    cost: 1,
    damage: 4,
    poison: 4,
    desc: '초록 뱀을 소환해 4 피해를 입히고 4의 맹독을 부여합니다.',
    icon: './assets/04_생물_소환/snake_뱀/snake_1_32px_pastel.png',
    sound: 'playSummon',
    tags: ['has_jong', 'summon', 'rieul_mim'] // ㅁ(울림소리)
  },
  '새': {
    word: '새',
    name: '새 (Bird)',
    category: 'summon',
    cost: 1,
    drawCards: 2,
    desc: '정찰 새를 날려 즉시 자모 카드 2장을 추가 드로우합니다.',
    icon: './assets/04_생물_소환/bird_새/bird_1_32px_pastel.png',
    sound: 'playSummon',
    tags: ['no_jong', 'summon']
  },
  '용': {
    word: '용',
    name: '용 (Dragon Awaken)',
    category: 'summon',
    cost: 1,
    damage: 18,
    burn: 5,
    desc: '고대 드래곤을 소환합니다! 18의 폭발적 피해와 5의 화상을 입힙니다.',
    icon: './assets/04_생물_소환/dragon_용/dragon_1_32px_pastel.png',
    sound: 'playSummon',
    tags: ['has_jong', 'summon', 'rieul_mim'] // ㅇ(울림소리)
  },
  '풀': {
    word: '풀',
    name: '풀 (Herb & Thorns)',
    category: 'summon',
    cost: 1,
    thorns: 4,
    heal: 3,
    desc: '가시풀을 둘러 HP를 3 회복하고 피격 시 4의 반격 가시 피해를 입힙니다.',
    icon: './assets/04_생물_소환/herb_plant_풀/herb_plant_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'summon', 'rough', 'rieul_mim'] // ㅍ(거센소리), ㄹ(울림소리)
  },
  '꽃': {
    word: '꽃',
    name: '꽃 (Flower Sleep)',
    category: 'summon',
    cost: 1,
    sleep: 1,
    desc: '수면 꽃가루를 살포하여 적의 다음 턴 공격력을 반토막냅니다.',
    icon: './assets/04_생물_소환/flower_꽃/flower_1_32px_pastel.png',
    sound: 'playMagic',
    tags: ['has_jong', 'summon', 'double_cho', 'rough'] // ㄲ(된소리), ㅊ(거센소리)
  },

  // === 05. 구조 / 필드 ===
  '문': {
    word: '문',
    name: '문 (Door Barrier)',
    category: 'structure',
    cost: 1,
    invulnerable: 1,
    desc: '견고한 대문을 닫아, 다음 1회 동안 적의 피해를 완전히 무효화합니다.',
    icon: './assets/05_구조_필드/door_문/door_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'structure', 'rieul_mim'] // ㄴ(울림소리)
  },
  '벽': {
    word: '벽',
    name: '벽 (Stone Wall)',
    category: 'structure',
    cost: 1,
    shield: 10,
    reflect: 3,
    desc: '10의 방어도를 얻고, 이번 턴 공격받을 때마다 적에게 3의 반사 피해를 줍니다.',
    icon: './assets/05_구조_필드/wall_벽/wall_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'structure']
  },
  '성': {
    word: '성',
    name: '성 (Castle Fortress)',
    category: 'structure',
    cost: 1,
    shield: 12,
    retainShield: true,
    desc: '12의 방어도를 획득하며, 이번 턴에 남은 방어도가 다음 턴으로 이월됩니다.',
    icon: './assets/05_구조_필드/castle_성/castle_1_32px_pastel.png',
    sound: 'playShield',
    tags: ['has_jong', 'structure', 'rieul_mim'] // ㅇ(울림소리)
  },
  '덫': {
    word: '덫',
    name: '덫 (Trap)',
    category: 'structure',
    cost: 1,
    trapDamage: 15,
    desc: '함정을 설치합니다. 적이 다음 턴에 공격을 시도할 때 즉시 15의 카운터 피해를 입힙니다.',
    icon: './assets/05_구조_필드/trap_덫/trap_1_32px_pastel.png',
    sound: 'playAttack',
    tags: ['has_jong', 'structure', 'double_cho']
  }
};

/**
 * Check if a Hangul word is defined in our battle database
 * @param {string} syllable 
 * @returns {object|null}
 */
export function getWordData(syllable) {
  return WORD_DATABASE[syllable] || null;
}
