import test from 'node:test';
import assert from 'node:assert/strict';
import { groupTilesByTowers } from '../src/js/core/tileGroups.js';

test('tiles are grouped under the tower that consumed them and leftovers stay waiting', () => {
  const parsed = [
    { syllable: '불', indices: [0, 1, 2] },
    { syllable: '난', indices: [4, 5, 6] }
  ];
  assert.deepEqual(groupTilesByTowers(['ㅂ', 'ㅜ', 'ㄹ', 'ㅅ', 'ㄴ', 'ㅏ', 'ㄴ'], parsed), {
    towers: [
      { word: '불', indices: [0, 1, 2] },
      { word: '난', indices: [4, 5, 6] }
    ],
    waiting: [3]
  });
});
