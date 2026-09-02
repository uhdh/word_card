/**
 * hangulEngine.js - Web ES Module (15 Core Jamos - 3-Tier Rarity System)
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

// 1. 초희귀 (Super Rare - 4방향 회전 만능 타일: ㅏ, ㅓ, ㅗ, ㅜ) -> 가장 낮은 확률 (가중치 10)
export const SUPER_RARE_TILES = ["ㅏ", "ㅓ", "ㅗ", "ㅜ"];

// 2. 희귀 (Rare - 2방향 회전 타일: ㄱ, ㄴ / ㅡ, ㅣ) -> 중간 확률 (가중치 30)
export const RARE_TILES = ["ㄱ", "ㄴ", "ㅡ", "ㅣ"];

// 3. 일반 (Common - 비회전 자음: ㄷ, ㄹ, ㅁ, ㅂ, ㅅ, ㅇ, ㅈ) -> 기본 확률 (가중치 100)
export const COMMON_TILES = ["ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ"];

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

export function getRarity(charStr) {
  if (SUPER_RARE_TILES.includes(charStr)) return "super_rare";
  if (RARE_TILES.includes(charStr)) return "rare";
  return "common";
}

export function isRare(charStr) {
  return RARE_TILES.includes(charStr) || SUPER_RARE_TILES.includes(charStr);
}

export function isSuperRare(charStr) {
  return SUPER_RARE_TILES.includes(charStr);
}

export function getWeightedRandomJamo(customPool = []) {
  const pool = customPool.length > 0 ? customPool : ALL_DRAW_POOL;
  const weighted = [];
  let totalWeight = 0;

  for (const item of pool) {
    const r = getRarity(item);
    let weight = 100;
    if (r === "super_rare") weight = 10;
    else if (r === "rare") weight = 30;

    weighted.push({ char: item, weight });
    totalWeight += weight;
  }

  const roll = Math.floor(Math.random() * totalWeight) + 1;
  let acc = 0;
  for (const entry of weighted) {
    acc += entry.weight;
    if (roll <= acc) {
      return entry.char;
    }
  }

  return pool[Math.floor(Math.random() * pool.length)];
}

export function isRotatable(charStr) {
  return charStr in ROTATABLE_TILES;
}

export function rotate(charStr) {
  return ROTATABLE_TILES[charStr] || charStr;
}

export function combineJamo(cho, jung, jong = "") {
  const choIdx = CHOSUNG.indexOf(cho);
  const jungIdx = JUNGSUNG.indexOf(jung);
  const jongIdx = jong ? JONGSUNG.indexOf(jong) : 0;

  if (choIdx === -1 || jungIdx === -1) {
    return cho + jung + jong;
  }

  const code = 0xAC00 + (choIdx * 21 * 28) + (jungIdx * 28) + jongIdx;
  return String.fromCharCode(code);
}

export function composeSyllable(cho, jung, jong = "") {
  return combineJamo(cho, jung, jong);
}

export function decomposeSyllable(syllable) {
  if (!syllable || syllable.length === 0) {
    return { chosung: "", jungsung: "", jongsung: "" };
  }
  const code = syllable.charCodeAt(0);
  if (code < 0xAC00 || code > 0xD7A3) {
    return { chosung: syllable, jungsung: "", jongsung: "" };
  }
  const sylIdx = code - 0xAC00;
  const choIdx = Math.floor(sylIdx / (21 * 28));
  const jungIdx = Math.floor((sylIdx % (21 * 28)) / 28);
  const jongIdx = sylIdx % 28;

  return {
    chosung: CHOSUNG[choIdx] || "",
    jungsung: JUNGSUNG[jungIdx] || "",
    jongsung: JONGSUNG[jongIdx] || ""
  };
}

export function isConsonant(c) {
  return CHOSUNG.includes(c) || JONGSUNG.includes(c);
}

export function isVowel(c) {
  return JUNGSUNG.includes(c) || (c in VOWEL_COMBINATIONS);
}
