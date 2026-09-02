/**
 * hangulStreamParser.js - Web ES Module
 * 하단 자모 벨트를 분석하여 연속 자모 자동 합성 (ㄱ+ㄱ+ㅏ -> 까, ㅗ+ㅏ -> ㅘ, ㄹ+ㄱ -> ㄺ) 및
 * 1글자 / 2글자 / 3글자 복합 단어 타워를 최장 일치(Greedy)로 자동 파싱
 */

import * as HangulEngine from './hangulEngine.js';
import { WORD_DATABASE, getWordData } from './wordDatabase.js';

export function isVowel(c) {
  return HangulEngine.JUNGSUNG.includes(c) || Object.prototype.hasOwnProperty.call(HangulEngine.VOWEL_COMBINATIONS, c);
}

export function canBeNextSyllableStart(jamoList, idx) {
  const n = jamoList.length;
  if (idx >= n) return false;
  const c1 = jamoList[idx];
  if (!HangulEngine.CHOSUNG.includes(c1)) return false;

  // 1) c1 right before a vowel (e.g. ㄱ + ㅏ)
  if (idx + 1 < n && isVowel(jamoList[idx + 1])) return true;

  // 2) c1 + c2 is a double consonant chosung and followed by vowel (e.g. ㄱ + ㄱ + ㅗ)
  if (idx + 2 < n) {
    const doubleKey = `${c1}+${jamoList[idx + 1]}`;
    if (Object.prototype.hasOwnProperty.call(HangulEngine.CONSONANT_COMBINATIONS, doubleKey)) {
      const comb = HangulEngine.CONSONANT_COMBINATIONS[doubleKey];
      if (HangulEngine.CHOSUNG.includes(comb) && isVowel(jamoList[idx + 2])) {
        return true;
      }
    }
  }
  return false;
}

export function parseJamoStream(jamoList) {
  const rawSyllables = [];
  let i = 0;
  const n = jamoList.length;

  while (i < n) {
    // 1. Chosung
    let cho = "";
    let choIndices = [];

    if (i + 1 < n) {
      const doubleKey = `${jamoList[i]}+${jamoList[i + 1]}`;
      if (Object.prototype.hasOwnProperty.call(HangulEngine.CONSONANT_COMBINATIONS, doubleKey)) {
        const combinedCho = HangulEngine.CONSONANT_COMBINATIONS[doubleKey];
        if (HangulEngine.CHOSUNG.includes(combinedCho) && i + 2 < n && isVowel(jamoList[i + 2])) {
          cho = combinedCho;
          choIndices = [i, i + 1];
          i += 2;
        }
      }
    }

    if (!cho) {
      const singleC = jamoList[i];
      if (HangulEngine.CHOSUNG.includes(singleC)) {
        cho = singleC;
        choIndices = [i];
        i += 1;
      } else {
        i += 1;
        continue;
      }
    }

    // 2. Jungsung
    let jung = "";
    let jungIndices = [];

    if (i < n) {
      if (i + 1 < n) {
        const doubleVKey = `${jamoList[i]}+${jamoList[i + 1]}`;
        if (Object.prototype.hasOwnProperty.call(HangulEngine.VOWEL_COMBINATIONS, doubleVKey)) {
          const combinedV = HangulEngine.VOWEL_COMBINATIONS[doubleVKey];
          if (HangulEngine.JUNGSUNG.includes(combinedV)) {
            jung = combinedV;
            jungIndices = [i, i + 1];
            i += 2;
          }
        }
      }

      if (!jung) {
        const singleV = jamoList[i];
        if (HangulEngine.JUNGSUNG.includes(singleV)) {
          jung = singleV;
          jungIndices = [i];
          i += 1;
        }
      }
    }

    if (!jung) continue;

    // 3. Jongsung
    let jong = "";
    let jongIndices = [];

    if (i < n) {
      if (!canBeNextSyllableStart(jamoList, i)) {
        let tryDoubleJong = false;
        if (i + 1 < n) {
          if (!canBeNextSyllableStart(jamoList, i + 1)) {
            const doubleJKey = `${jamoList[i]}+${jamoList[i + 1]}`;
            if (Object.prototype.hasOwnProperty.call(HangulEngine.CONSONANT_COMBINATIONS, doubleJKey)) {
              const combinedJ = HangulEngine.CONSONANT_COMBINATIONS[doubleJKey];
              if (HangulEngine.JONGSUNG.includes(combinedJ)) {
                jong = combinedJ;
                jongIndices = [i, i + 1];
                i += 2;
                tryDoubleJong = true;
              }
            }
          }
        }

        if (!tryDoubleJong) {
          const singleJ = jamoList[i];
          if (HangulEngine.JONGSUNG.includes(singleJ) && singleJ !== "") {
            jong = singleJ;
            jongIndices = [i];
            i += 1;
          }
        }
      }
    }

    const syllable = HangulEngine.composeSyllable(cho, jung, jong);
    if (syllable) {
      rawSyllables.push({
        syllable,
        indices: [...choIndices, ...jungIndices, ...jongIndices]
      });
    }
  }

  // 2nd stage: 3-letter -> 2-letter -> 1-letter Greedy Word Matching
  const finalTowers = [];
  let sIdx = 0;
  const totalS = rawSyllables.length;

  while (sIdx < totalS) {
    // 3-letter check
    if (sIdx + 2 < totalS) {
      const triWord = rawSyllables[sIdx].syllable + rawSyllables[sIdx + 1].syllable + rawSyllables[sIdx + 2].syllable;
      if (Object.prototype.hasOwnProperty.call(WORD_DATABASE, triWord)) {
        const data = getWordData(triWord);
        finalTowers.push({
          syllable: triWord,
          wordData: data,
          indices: [...rawSyllables[sIdx].indices, ...rawSyllables[sIdx + 1].indices, ...rawSyllables[sIdx + 2].indices],
          tier: 3
        });
        sIdx += 3;
        continue;
      }
    }

    // 2-letter check
    if (sIdx + 1 < totalS) {
      const biWord = rawSyllables[sIdx].syllable + rawSyllables[sIdx + 1].syllable;
      if (Object.prototype.hasOwnProperty.call(WORD_DATABASE, biWord)) {
        const data = getWordData(biWord);
        finalTowers.push({
          syllable: biWord,
          wordData: data,
          indices: [...rawSyllables[sIdx].indices, ...rawSyllables[sIdx + 1].indices],
          tier: 2
        });
        sIdx += 2;
        continue;
      }
    }

    // 1-letter word
    const monoWord = rawSyllables[sIdx].syllable;
    let data = getWordData(monoWord);
    if (!data) {
      data = {
        word: monoWord,
        name: `${monoWord} (미지의 활자)`,
        category: "basic",
        is_unknown: true,
        cost: 1,
        damage: 4,
        desc: "사전에 등록되지 않은 미지의 활자입니다. 기본 활자 탄환을 발사합니다.",
        icon: "",
        sound: "playAttack"
      };
    }

    finalTowers.push({
      syllable: monoWord,
      wordData: data,
      indices: rawSyllables[sIdx].indices,
      tier: 1
    });
    sIdx += 1;
  }

  return finalTowers;
}
