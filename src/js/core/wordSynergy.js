import { decomposeSyllable, ROTATABLE_TILES } from './hangulEngine.js';

const TENSE = new Set(['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ']);
const CLUSTER_FINALS = new Set(['ㄳ', 'ㄵ', 'ㄶ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅄ']);
const COMPOUND_VOWELS = new Set(['ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ']);
const EXPAND = {
  'ㄲ': ['ㄱ', 'ㄱ'], 'ㄸ': ['ㄷ', 'ㄷ'], 'ㅃ': ['ㅂ', 'ㅂ'], 'ㅆ': ['ㅅ', 'ㅅ'], 'ㅉ': ['ㅈ', 'ㅈ'],
  'ㄳ': ['ㄱ', 'ㅅ'], 'ㄵ': ['ㄴ', 'ㅈ'], 'ㄶ': ['ㄴ', 'ㅎ'], 'ㄺ': ['ㄹ', 'ㄱ'], 'ㄻ': ['ㄹ', 'ㅁ'],
  'ㄼ': ['ㄹ', 'ㅂ'], 'ㄽ': ['ㄹ', 'ㅅ'], 'ㄾ': ['ㄹ', 'ㅌ'], 'ㄿ': ['ㄹ', 'ㅍ'], 'ㅀ': ['ㄹ', 'ㅎ'], 'ㅄ': ['ㅂ', 'ㅅ'],
  'ㅘ': ['ㅗ', 'ㅏ'], 'ㅙ': ['ㅗ', 'ㅐ'], 'ㅚ': ['ㅗ', 'ㅣ'], 'ㅝ': ['ㅜ', 'ㅓ'], 'ㅞ': ['ㅜ', 'ㅔ'], 'ㅟ': ['ㅜ', 'ㅣ'], 'ㅢ': ['ㅡ', 'ㅣ']
};

const expand = jamo => EXPAND[jamo] || [jamo];

export function analyzeWord(word) {
  const parts = [...word].map(decomposeSyllable);
  const consonants = parts.flatMap(p => [...expand(p.chosung), ...(p.jongsung ? expand(p.jongsung) : [])]);
  const vowels = parts.flatMap(p => expand(p.jungsung));
  return {
    hasTense: parts.some(p => TENSE.has(p.chosung)),
    hasFinal: parts.some(p => p.jongsung),
    hasClusterFinal: parts.some(p => CLUSTER_FINALS.has(p.jongsung)),
    hasCompoundVowel: parts.some(p => COMPOUND_VOWELS.has(p.jungsung)),
    repeatedInitial: parts.length > 1 && new Set(parts.map(p => p.chosung)).size === 1,
    repeatedVowel: parts.length > 1 && new Set(parts.map(p => p.jungsung)).size < parts.length,
    linkedConsonant: parts.slice(0, -1).some((p, i) => p.jongsung && p.jongsung === parts[i + 1].chosung),
    balanced: consonants.length === vowels.length
  };
}

function requiredTiles(word) {
  return [...word].flatMap(char => {
    const p = decomposeSyllable(char);
    return [...expand(p.chosung), ...expand(p.jungsung), ...(p.jongsung ? expand(p.jongsung) : [])];
  });
}

function rotations(tile) {
  const result = new Set([tile]);
  let next = ROTATABLE_TILES[tile];
  while (next && !result.has(next)) {
    result.add(next);
    next = ROTATABLE_TILES[next];
  }
  return result;
}

export function canBuildWord(word, belt) {
  const available = belt.map(rotations);
  return requiredTiles(word).every(required => {
    const index = available.findIndex(options => options.has(required));
    if (index < 0) return false;
    available.splice(index, 1);
    return true;
  });
}

export function getInitialHint(belt, words, offset = 0) {
  const candidates = words.filter(({ word }) => canBuildWord(word, belt)).sort((a, b) => b.word.length - a.word.length);
  if (!candidates.length) return null;
  const longest = candidates.filter(({ word }) => word.length === candidates[0].word.length);
  return [...longest[offset % longest.length].word].map(char => decomposeSyllable(char).chosung).join('');
}

const RELICS = [
  ['relic_tense_hammer', '된소리 망치', a => a.hasTense, 'damageMultiplier', 1.25],
  ['relic_final_weight', '종성의 무게추', a => a.hasFinal, 'damageMultiplier', 1.2],
  ['relic_open_feather', '민소리 깃털', a => !a.hasFinal, 'intervalMultiplier', 0.82],
  ['relic_cluster_anvil', '겹받침 모루', a => a.hasClusterFinal, 'damageMultiplier', 1.35],
  ['relic_vowel_crystal', '겹모음 수정', a => a.hasCompoundVowel, 'rangeMultiplier', 1.2],
  ['relic_initial_drum', '첫소리 북', a => a.repeatedInitial, 'damageMultiplier', 1.25],
  ['relic_vowel_resonance', '모음 공명석', a => a.repeatedVowel, 'intervalMultiplier', 0.8],
  ['relic_consonant_ring', '자음 고리', a => a.linkedConsonant, 'critChance', 0.2],
  ['relic_balance_ink', '균형의 먹', a => a.balanced, 'damageMultiplier', 1.1]
];

export function getRelicBonuses(word, relicIds) {
  const analysis = analyzeWord(word);
  const bonus = { damageMultiplier: 1, intervalMultiplier: 1, rangeMultiplier: 1, critChance: 0, labels: [] };
  for (const [id, label, matches, key, value] of RELICS) {
    if (!relicIds.includes(id) || !matches(analysis)) continue;
    bonus[key] = key === 'critChance' ? bonus[key] + value : bonus[key] * value;
    bonus.labels.push(label);
  }
  if (relicIds.includes('relic_balance_ink') && analysis.balanced) bonus.rangeMultiplier *= 1.1;
  return bonus;
}

export function applyTowerSynergies(towers, relicIds = []) {
  towers.forEach(tower => { tower.synergies ||= []; });
  for (let i = 0; i < towers.length - 1; i++) {
    const left = towers[i], right = towers[i + 1];
    const a = left.wordData?.category, b = right.wordData?.category;
    if (a === 'element' && b === 'element') {
      left.damage = Math.round(left.damage * 1.15);
      right.damage = Math.round(right.damage * 1.15);
      left.synergies.push('원소 공명'); right.synergies.push('원소 공명');
    }
    if (a === 'weapon' && ['skill', 'buff'].includes(b)) {
      left.attackInterval *= 0.85; left.synergies.push('전술 연계');
    }
    if (b === 'weapon' && ['skill', 'buff'].includes(a)) {
      right.attackInterval *= 0.85; right.synergies.push('전술 연계');
    }
    if ([a, b].includes('defense') && [a, b].includes('heal')) {
      left.synergies.push('수호의 순환'); right.synergies.push('수호의 순환');
    }
    if (relicIds.includes('relic_open_chime') && !analyzeWord(left.syllable).hasFinal && !analyzeWord(right.syllable).hasFinal) {
      left.attackInterval *= 0.88; right.attackInterval *= 0.88;
      left.synergies.push('무받침 풍경'); right.synergies.push('무받침 풍경');
    }
  }
  return towers;
}

export function getWaveSynergyHealing(towers) {
  for (let i = 0; i < towers.length - 1; i++) {
    const pair = [towers[i].wordData?.category, towers[i + 1].wordData?.category];
    if (pair.includes('defense') && pair.includes('heal')) return 1;
  }
  return 0;
}
