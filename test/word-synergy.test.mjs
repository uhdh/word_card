import test from 'node:test';
import assert from 'node:assert/strict';
import { analyzeWord, getInitialHint, getRelicBonuses, applyTowerSynergies } from '../src/js/core/wordSynergy.js';

test('analyzes composable Hangul features for relic activation', () => {
  assert.deepEqual(analyzeWord('꿇'), {
    hasTense: true, hasFinal: true, hasClusterFinal: true, hasCompoundVowel: false,
    repeatedInitial: false, repeatedVowel: false, linkedConsonant: false, balanced: false
  });
  assert.equal(analyzeWord('가가').repeatedInitial, true);
  assert.equal(analyzeWord('불로').linkedConsonant, true);
});

test('initial hint only reveals initials of a word buildable from the belt', () => {
  const words = [{ word: '불' }, { word: '불사조' }, { word: '검' }];
  assert.equal(getInitialHint(['ㅂ', 'ㅜ', 'ㄹ'], words), 'ㅂ');
  assert.equal(getInitialHint(['ㅂ', 'ㅜ'], words), null);
});

test('jamo relics combine their conditional tower bonuses', () => {
  const bonus = getRelicBonuses('딱', ['relic_tense_hammer', 'relic_final_weight']);
  assert.equal(bonus.damageMultiplier, 1.5);
  assert.deepEqual(bonus.labels, ['된소리 망치', '종성의 무게추']);
});

test('adjacent tower categories activate tower synergies', () => {
  const towers = [
    { wordData: { category: 'element' }, damage: 100, attackInterval: 1 },
    { wordData: { category: 'element' }, damage: 100, attackInterval: 1 },
    { wordData: { category: 'skill' }, damage: 100, attackInterval: 1 },
    { wordData: { category: 'weapon' }, damage: 100, attackInterval: 1 }
  ];
  applyTowerSynergies(towers);
  assert.equal(towers[0].damage, 115);
  assert.equal(towers[1].damage, 115);
  assert.equal(towers[3].attackInterval, 0.85);
});
