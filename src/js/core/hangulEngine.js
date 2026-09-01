/**
 * <언어의 조각 : 말의 심연> Hangul Engine
 * 자모 분해, 1음절 조합, 자모 타일 회전 및 합성 로직
 */

export const CHOSUNG = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
];

export const JUNGSUNG = [
  'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
  'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'
];

export const JONGSUNG = [
  '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
  'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
];

export const ROTATABLE_TILES = new Set([
  'ㄱ', 'ㄴ',
  'ㅏ', 'ㅓ', 'ㅗ', 'ㅜ',
  'ㅑ', 'ㅕ', 'ㅛ', 'ㅠ',
  'ㅣ', 'ㅡ'
]);

export function isRotatable(tile) {
  return ROTATABLE_TILES.has(tile);
}

export const CONSONANT_ROTATIONS = {
  'ㄱ': 'ㄴ',
  'ㄴ': 'ㄱ'
};

export const VOWEL_ROTATIONS = {
  'ㅏ': 'ㅜ',
  'ㅜ': 'ㅓ',
  'ㅓ': 'ㅗ',
  'ㅗ': 'ㅏ',

  'ㅑ': 'ㅠ',
  'ㅠ': 'ㅕ',
  'ㅕ': 'ㅛ',
  'ㅛ': 'ㅑ',

  'ㅣ': 'ㅡ',
  'ㅡ': 'ㅣ'
};

export const VOWEL_REVERSE_ROTATIONS = {
  'ㅏ': 'ㅗ',
  'ㅗ': 'ㅓ',
  'ㅓ': 'ㅜ',
  'ㅜ': 'ㅏ',

  'ㅑ': 'ㅛ',
  'ㅛ': 'ㅕ',
  'ㅕ': 'ㅠ',
  'ㅠ': 'ㅑ',

  'ㅣ': 'ㅡ',
  'ㅡ': 'ㅣ'
};

export const CONSONANT_COMBINATIONS = {
  'ㄱ+ㄱ': 'ㄲ',
  'ㄷ+ㄷ': 'ㄸ',
  'ㅂ+ㅂ': 'ㅃ',
  'ㅅ+ㅅ': 'ㅆ',
  'ㅈ+ㅈ': 'ㅉ',
  'ㄱ+ㅅ': 'ㄳ',
  'ㄴ+ㅈ': 'ㄵ',
  'ㄴ+ㅎ': 'ㄶ',
  'ㄹ+ㄱ': 'ㄺ',
  'ㄹ+ㅁ': 'ㄻ',
  'ㄹ+ㅂ': 'ㄼ',
  'ㄹ+ㅅ': 'ㄽ',
  'ㄹ+ㅌ': 'ㄾ',
  'ㄹ+ㅍ': 'ㄿ',
  'ㄹ+ㅎ': 'ㅀ',
  'ㅂ+ㅅ': 'ㅄ'
};

export const VOWEL_COMBINATIONS = {
  'ㅏ+ㅣ': 'ㅐ',
  'ㅓ+ㅣ': 'ㅔ',
  'ㅗ+ㅣ': 'ㅚ',
  'ㅜ+ㅣ': 'ㅟ',
  'ㅑ+ㅣ': 'ㅒ',
  'ㅕ+ㅣ': 'ㅖ',
  'ㅗ+ㅏ': 'ㅘ',
  'ㅜ+ㅓ': 'ㅝ',
  'ㅗ+ㅐ': 'ㅙ',
  'ㅘ+ㅣ': 'ㅙ',
  'ㅗ+ㅏ+ㅣ': 'ㅙ',
  'ㅜ+ㅔ': 'ㅞ',
  'ㅝ+ㅣ': 'ㅞ',
  'ㅜ+ㅓ+ㅣ': 'ㅞ',
  'ㅡ+ㅣ': 'ㅢ'
};

export function rotateTile(tile, reverse = false) {
  if (CONSONANT_ROTATIONS[tile]) return CONSONANT_ROTATIONS[tile];
  if (reverse && VOWEL_REVERSE_ROTATIONS[tile]) return VOWEL_REVERSE_ROTATIONS[tile];
  if (VOWEL_ROTATIONS[tile]) return VOWEL_ROTATIONS[tile];
  return tile;
}

export function combineTiles(tiles) {
  if (!tiles || tiles.length < 2) return null;
  const key2 = `${tiles[0]}+${tiles[1]}`;
  if (tiles.length === 2) {
    if (CONSONANT_COMBINATIONS[key2]) return CONSONANT_COMBINATIONS[key2];
    if (VOWEL_COMBINATIONS[key2]) return VOWEL_COMBINATIONS[key2];
  } else if (tiles.length === 3) {
    const key3 = `${tiles[0]}+${tiles[1]}+${tiles[2]}`;
    if (VOWEL_COMBINATIONS[key3]) return VOWEL_COMBINATIONS[key3];
  }
  return null;
}

export function isConsonant(char) {
  return CHOSUNG.includes(char) || JONGSUNG.includes(char);
}

export function isVowel(char) {
  return JUNGSUNG.includes(char);
}

export function decomposeHangul(char) {
  if (!char || char.length !== 1) return { cho: '', jung: '', jong: '', isHangul: false };
  const code = char.charCodeAt(0) - 0xAC00;
  if (code < 0 || code > 11171) return { cho: char, jung: '', jong: '', isHangul: false };
  const choIdx = Math.floor(code / 588);
  const jungIdx = Math.floor((code % 588) / 28);
  const jongIdx = code % 28;
  return {
    cho: CHOSUNG[choIdx],
    jung: JUNGSUNG[jungIdx],
    jong: JONGSUNG[jongIdx],
    isHangul: true
  };
}

export function composeHangul(cho, jung, jong = '') {
  const choIdx = CHOSUNG.indexOf(cho);
  const jungIdx = JUNGSUNG.indexOf(jung);
  const jongIdx = JONGSUNG.indexOf(jong);

  if (choIdx === -1 || jungIdx === -1 || jongIdx === -1) {
    return null;
  }
  const code = 0xAC00 + (choIdx * 588) + (jungIdx * 28) + jongIdx;
  return String.fromCharCode(code);
}
