/**
 * hangulEngine.js - Web ES Module (15 Core Jamos)
 * 한글 자모 분해, 합성, 회전, 완성형 음절 조합 및 희귀도(Rarity) 가중치 엔진
 */

export const CHOSUNG = [
  "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
  "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
];

export const JUNGSUNG = [
  "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
  "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
];

export const JONGSUNG = [
  "", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ",
  "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ",
  "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
];

export const RARE_TILES = ["ㄱ", "ㅡ", "ㅜ"];

// 15 Valid Draw Pool (Excluded: ㅑ, ㅕ, ㅛ, ㅠ and ㅋ, ㅌ, ㅊ, ㅍ, ㅎ)
export const ALL_DRAW_POOL = [
  "ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ",
  "ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"
];

export const ROTATABLE_TILES = {
  "ㄱ": "ㄴ", "ㄴ": "ㄱ",
  "ㅏ": "ㅜ", "ㅜ": "ㅓ", "ㅓ": "ㅗ", "ㅗ": "ㅏ",
  "ㅣ": "ㅡ", "ㅡ": "ㅣ"
};

export const CONSONANT_COMBINATIONS = {
  "ㄱ+ㄱ": "ㄲ", "ㄷ+ㄷ": "ㄸ", "ㅂ+ㅂ": "ㅃ", "ㅅ+ㅅ": "ㅆ", "ㅈ+ㅈ": "ㅉ",
  "ㄱ+ㅅ": "ㄳ", "ㄴ+ㅈ": "ㄵ", "ㄹ+ㄱ": "ㄺ", "ㄹ+ㅁ": "ㄻ",
  "ㄹ+ㅂ": "ㄼ", "ㄹ+ㅅ": "ㄽ", "ㅂ+ㅅ": "ㅄ"
};

export const VOWEL_COMBINATIONS = {
  "ㅗ+ㅏ": "ㅘ", "ㅗ+ㅣ": "ㅚ",
  "ㅜ+ㅓ": "ㅝ", "ㅜ+ㅣ": "ㅟ",
  "ㅡ+ㅣ": "ㅢ", "ㅏ+ㅣ": "ㅐ", "ㅓ+ㅣ": "ㅔ"
};

export function isRare(charStr) {
  return RARE_TILES.includes(charStr);
}

export function getWeightedRandomJamo(customPool = []) {
  const pool = customPool.length > 0 ? customPool : ALL_DRAW_POOL;
  const weighted = [];
  let totalWeight = 0;

  for (const item of pool) {
    const weight = isRare(item) ? 20 : 100;
    weighted.push({ char: item, weight });
    totalWeight += weight;
  }

  const roll = Math.floor(Math.random() * totalWeight) + 1;
  let current = 0;
  for (const entry of weighted) {
    current += entry.weight;
    if (roll <= current) return entry.char;
  }
  return pool[Math.floor(Math.random() * pool.length)];
}

export function isRotatable(charStr) {
  return Object.prototype.hasOwnProperty.call(ROTATABLE_TILES, charStr);
}

export function rotate(charStr) {
  return ROTATABLE_TILES[charStr] || charStr;
}

export function composeSyllable(cho, jung, jong = "") {
  const choIdx = CHOSUNG.indexOf(cho);
  const jungIdx = JUNGSUNG.indexOf(jung);
  const jongIdx = JONGSUNG.indexOf(jong);

  if (choIdx === -1 || jungIdx === -1) return "";
  const finalJongIdx = jongIdx === -1 ? 0 : jongIdx;
  const code = 0xAC00 + (choIdx * 21 * 28) + (jungIdx * 28) + finalJongIdx;
  return String.fromCharCode(code);
}

export function decomposeSyllable(syllable) {
  if (!syllable || syllable.length !== 1) return null;
  const code = syllable.charCodeAt(0);
  if (code < 0xAC00 || code > 0xD7A3) return null;

  const offset = code - 0xAC00;
  const jongIdx = offset % 28;
  const jungIdx = Math.floor(offset / 28) % 21;
  const choIdx = Math.floor(offset / (21 * 28));

  return {
    chosung: CHOSUNG[choIdx],
    jungsung: JUNGSUNG[jungIdx],
    jongsung: JONGSUNG[jongIdx]
  };
}
