/**
 * <언어의 조각 : 말의 심연> Card & Hand & Crafting System
 * 자모 덱 드로우, 손패 관리, 타일 회전/합성, 3슬롯 단어 조합
 */

import {
  rotateTile,
  combineTiles,
  isConsonant,
  isVowel,
  composeHangul,
  isRotatable
} from '../core/hangulEngine.js';
import { getWordData } from '../core/wordDatabase.js';
import { sound } from '../core/soundEngine.js';

// 기본 시작 자모 덱 구성 (총 10장 - 컴팩트 스타터 덱)
// 회전 기능(ㄱ↔ㄴ, ㅏ↔ㅜ↔ㅓ↔ㅗ, ㅣ↔ㅡ)으로 다양한 단어 조합 가능
export const STARTER_DECK = [
  'ㄱ', // 회전 시 'ㄴ' (검, 문, 눈, 방 등)
  'ㅂ', // 불, 방, 뱀, 벽 등
  'ㅅ', // 성, 손, 숲 등
  'ㅁ', // 문, 물, 말 등
  'ㄹ', // 불, 물, 칼, 활 등의 받침
  'ㅇ', // 방, 용, 약, 옷 등
  'ㅏ', // 기본 모음 (회전 시 ㅜ, ㅓ, ㅗ)
  'ㅏ', // 2번째 모음
  'ㅓ', // 검, 벽 등
  'ㅣ'  // 회전 시 ㅡ (빛, 피, 침, 끈 등)
];

export class CardSystem {
  constructor() {
    this.drawPile = [];
    this.discardPile = [];
    this.hand = []; // Array of { id, char, isRotated, isSelected }

    // Crafting slots: [cho, jung, jong]
    this.slots = [null, null, null];
    this.craftedCard = null; // Complete Word Card Object if valid

    this.idCounter = 1;
    this.initDeck();
  }

  initDeck(customDeck = null) {
    const rawDeck = customDeck || [...STARTER_DECK];
    this.drawPile = this.shuffle(rawDeck.map(char => this.createTile(char)));
    this.discardPile = [];
    this.hand = [];
    this.slots = [null, null, null];
    this.craftedCard = null;
  }

  createTile(char) {
    return {
      id: `tile_${this.idCounter++}`,
      char: char,
      isConsonant: isConsonant(char),
      isVowel: isVowel(char),
      isRotatable: isRotatable(char)
    };
  }

  shuffle(array) {
    const arr = [...array];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  draw(count = 5) {
    for (let i = 0; i < count; i++) {
      if (this.drawPile.length === 0) {
        if (this.discardPile.length === 0) break;
        this.drawPile = this.shuffle(this.discardPile);
        this.discardPile = [];
      }
      if (this.drawPile.length > 0) {
        this.hand.push(this.drawPile.pop());
      }
    }
  }

  drawSpecificType(type = 'vowel', count = 1) {
    // Find in drawPile or reshuffle discardPile
    let drawn = 0;
    for (let i = 0; i < this.drawPile.length && drawn < count; i++) {
      const tile = this.drawPile[i];
      if ((type === 'vowel' && tile.isVowel) || (type === 'consonant' && tile.isConsonant)) {
        this.hand.push(tile);
        this.drawPile.splice(i, 1);
        drawn++;
        i--;
      }
    }
  }

  // 타일 회전
  rotateTileInHand(tileId) {
    const tile = this.hand.find(t => t.id === tileId);
    if (!tile || !tile.isRotatable) return false;

    const prev = tile.char;
    tile.char = rotateTile(tile.char);
    tile.isConsonant = isConsonant(tile.char);
    tile.isVowel = isVowel(tile.char);
    tile.isRotatable = isRotatable(tile.char);

    sound.playTileRotate();
    return true;
  }

  // 타일 2개 합성
  combineSelectedTiles(tileId1, tileId2) {
    const t1 = this.hand.find(t => t.id === tileId1);
    const t2 = this.hand.find(t => t.id === tileId2);
    if (!t1 || !t2) return false;

    const result = combineTiles([t1.char, t2.char]);
    if (!result) return false;

    // Remove t1 and t2, add new combined tile
    this.hand = this.hand.filter(t => t.id !== tileId1 && t.id !== tileId2);
    const newTile = this.createTile(result);
    this.hand.push(newTile);

    sound.playTileCombine();
    return newTile;
  }

  // 슬롯에 타일 배치
  placeTileInSlot(tileId, slotIndex) {
    const handIndex = this.hand.findIndex(t => t.id === tileId);
    if (handIndex === -1 || slotIndex < 0 || slotIndex > 2) return false;

    const tile = this.hand[handIndex];

    // Check slot type validity:
    // Slot 0 (초성): 자음만 가능
    // Slot 1 (중성): 모음만 가능
    // Slot 2 (종성): 자음만 가능
    if (slotIndex === 0 && !tile.isConsonant) return false;
    if (slotIndex === 1 && !tile.isVowel) return false;
    if (slotIndex === 2 && !tile.isConsonant) return false;

    // If slot is occupied, return existing tile to hand
    if (this.slots[slotIndex]) {
      this.hand.push(this.slots[slotIndex]);
    }

    // Place tile into slot
    this.slots[slotIndex] = tile;
    this.hand.splice(handIndex, 1);

    sound.playTileClick();
    this.evaluateCraftingSlot();
    return true;
  }

  // 슬롯의 타일을 손패로 회수
  removeTileFromSlot(slotIndex) {
    if (slotIndex < 0 || slotIndex > 2 || !this.slots[slotIndex]) return false;

    const tile = this.slots[slotIndex];
    this.slots[slotIndex] = null;
    this.hand.push(tile);

    sound.playTileClick();
    this.evaluateCraftingSlot();
    return true;
  }

  // 슬롯 전체 비우기
  clearSlots() {
    for (let i = 0; i < 3; i++) {
      if (this.slots[i]) {
        this.hand.push(this.slots[i]);
        this.slots[i] = null;
      }
    }
    this.craftedCard = null;
  }

  // 현재 슬롯의 조합 완성 평가
  evaluateCraftingSlot() {
    const cho = this.slots[0]?.char || '';
    const jung = this.slots[1]?.char || '';
    const jong = this.slots[2]?.char || '';

    if (!cho || !jung) {
      this.craftedCard = null;
      return null;
    }

    const syllable = composeHangul(cho, jung, jong);
    if (!syllable) {
      this.craftedCard = null;
      return null;
    }

    const wordData = getWordData(syllable);
    if (wordData) {
      this.craftedCard = {
        ...wordData,
        syllable: syllable,
        usedTiles: this.slots.filter(Boolean)
      };
      sound.playWordCrafted();
    } else {
      // Valid Hangul syllable, but not in custom database (Basic 4 dmg fallback)
      this.craftedCard = {
        word: syllable,
        name: `${syllable} (일반 단어)`,
        category: 'basic',
        cost: 1,
        damage: 5,
        shield: 0,
        desc: `적에게 5의 기본 단어 피해를 입힙니다.`,
        icon: './assets/01_무기_공격/sword_검/sword_1_32px_pastel.png',
        sound: 'playAttack',
        tags: jong ? ['has_jong'] : ['no_jong'],
        syllable: syllable,
        usedTiles: this.slots.filter(Boolean)
      };
    }
    return this.craftedCard;
  }

  // 완성된 단어 카드를 발동하여 소모
  consumeCraftedCard() {
    if (!this.craftedCard) return null;

    const card = this.craftedCard;
    // Move used tiles to discard pile
    for (let i = 0; i < 3; i++) {
      if (this.slots[i]) {
        this.discardPile.push(this.slots[i]);
        this.slots[i] = null;
      }
    }
    this.craftedCard = null;
    return card;
  }

  // 턴 종료 시 손패 정리
  discardHandAndSlots() {
    this.clearSlots();
    while (this.hand.length > 0) {
      this.discardPile.push(this.hand.pop());
    }
  }
}
