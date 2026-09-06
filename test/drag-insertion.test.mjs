import test from 'node:test';
import assert from 'node:assert/strict';
import { getInsertionIndex } from '../src/js/core/dragInsertion.js';
import { readFileSync } from 'node:fs';

test('a drop in a tile gap inserts at that gap instead of either end', () => {
  const tileCenters = [30, 100, 170, 240];

  assert.equal(getInsertionIndex(65, tileCenters), 1);
  assert.equal(getInsertionIndex(135, tileCenters), 2);
});

test('tower defense offers the six additional relics in both runtimes', () => {
  const web = readFileSync('src/js/app.js', 'utf8');
  const godot = readFileSync('godot/scripts/ui/ShopModal.gd', 'utf8');
  for (const id of ['range_rune', 'bounty_coin', 'healing_incense', 'first_strike', 'three_syllable_seal', 'merchant_coupon']) {
    assert.match(web, new RegExp(`relic_${id}`));
    assert.match(godot, new RegExp(`relic_${id}`));
  }
});
