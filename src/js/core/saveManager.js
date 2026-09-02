/**
 * saveManager.js - Web LocalStorage Game & Lexicon Save Manager
 */

const SAVE_KEY = "hangul_tower_defense_save";
const LEXICON_KEY = "hangul_tower_defense_discovered_lexicon";

export class SaveManager {
  static hasSaveFile() {
    return localStorage.getItem(SAVE_KEY) !== null;
  }

  static saveGame(state) {
    try {
      const data = {
        jamoList: state.jamoList || ["ㅂ", "ㅜ", "ㄹ"],
        baseHp: state.baseHp || 20,
        maxBaseHp: state.maxBaseHp || 20,
        gold: state.gold || 40,
        currentWave: state.currentWave || 0,
        rerollDice: state.rerollDice !== undefined ? state.rerollDice : 3,
        savedAt: new Date().toISOString()
      };
      localStorage.setItem(SAVE_KEY, JSON.stringify(data));
      console.log("💾 [SaveManager] Game saved to LocalStorage:", data);
      return true;
    } catch (e) {
      console.error("Save error:", e);
      return false;
    }
  }

  static loadGame() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return null;
      return JSON.parse(raw);
    } catch (e) {
      console.error("Load error:", e);
      return null;
    }
  }

  static deleteSaveFile() {
    try {
      localStorage.removeItem(SAVE_KEY);
      console.log("🗑️ [SaveManager] Save file deleted from LocalStorage");
      return true;
    } catch (e) {
      console.error("Delete save error:", e);
      return false;
    }
  }

  static getDiscoveredWords() {
    try {
      const raw = localStorage.getItem(LEXICON_KEY);
      if (!raw) return ["불"];
      const list = JSON.parse(raw);
      if (!list.includes("불")) list.push("불");
      return list;
    } catch (e) {
      return ["불"];
    }
  }

  static isWordDiscovered(word) {
    const list = this.getDiscoveredWords();
    return list.includes(word);
  }

  static discoverWord(word) {
    if (!word) return false;
    const list = this.getDiscoveredWords();
    if (!list.includes(word)) {
      list.push(word);
      try {
        localStorage.setItem(LEXICON_KEY, JSON.stringify(list));
      } catch (e) {}
      console.log(`✨ [Lexicon] 새 단어 도감 해금: [${word}] (총 ${list.length}개 발견)`);
      return true;
    }
    return false;
  }
}
