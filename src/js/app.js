/**
 * <언어의 조각 : 말의 심연> Main Entry Point & App Controller
 */

import { PlayerState, BattleManager } from './battle/battleManager.js';
import { MapManager } from './map/mapManager.js';
import { GameUI } from './ui/gameUI.js';
import { sound } from './core/soundEngine.js';

class WordCardGame {
  constructor() {
    this.player = new PlayerState();
    this.mapManager = new MapManager();
    this.battleManager = new BattleManager(this.player);

    const appContainer = document.getElementById('app');
    this.ui = new GameUI(appContainer, this);

    this.initGame();
  }

  initGame() {
    // Battle state subscription
    this.battleManager.subscribe((bm) => {
      if (bm.state === 'victory') {
        if (bm.enemy.type === 'boss') {
          this.ui.showActClearModal();
        } else {
          this.ui.showRewardModal(bm.rewards, () => {
            this.ui.renderMap();
          });
        }
      } else if (bm.state === 'defeat') {
        this.ui.showDefeatModal(() => {
          this.restartGame();
        });
      } else if (this.ui.currentView === 'battle') {
        this.ui.renderBattle();
      }
    });

    // Global Keyboard Shortcuts
    window.addEventListener('keydown', (e) => {
      if (this.ui.currentView === 'battle') {
        if (e.code === 'Space') {
          e.preventDefault();
          this.battleManager.playCraftedCard();
        } else if (e.code === 'KeyE') {
          e.preventDefault();
          this.battleManager.endPlayerTurn();
        }
      }
    });

    // Start in Map View
    this.ui.renderMap();
  }

  handleNodeSelect(nodeId) {
    const node = this.mapManager.moveToNode(nodeId);
    if (!node) return;

    sound.playTileClick();

    if (node.type === 'monster' || node.type === 'elite' || node.type === 'boss') {
      this.battleManager.startBattle(node.enemy);
      this.ui.renderBattle();
    } else if (node.type === 'rest') {
      this.ui.renderRest();
    } else if (node.type === 'shop') {
      this.ui.renderShop();
    } else if (node.type === 'event') {
      this.ui.renderEvent(node);
    }
  }

  restartGame() {
    this.player = new PlayerState();
    this.mapManager = new MapManager();
    this.battleManager = new BattleManager(this.player);
    this.initGame();
  }
}

// Bootstrap
window.addEventListener('DOMContentLoaded', () => {
  window.gameInstance = new WordCardGame();
});
