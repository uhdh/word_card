/**
 * <언어의 조각 : 말의 심연> Master Game UI & View Controller
 * Slay the Spire 스타일의 맵, 전투, 모닥불, 상점, 이벤트, 보상 UI 통합 제어
 */

import { sound } from '../core/soundEngine.js';
import { WORD_DATABASE } from '../core/wordDatabase.js';

export class GameUI {
  constructor(appContainer, game) {
    this.container = appContainer;
    this.game = game; // Master game instance

    this.selectedTileIdForCombine = null;
    this.currentView = 'map'; // 'map' | 'battle' | 'rest' | 'shop' | 'event'
    this.initDOM();
  }

  initDOM() {
    this.container.innerHTML = `
      <!-- TOP BAR -->
      <header class="top-bar">
        <div class="player-info">
          <div class="hp-box">
            <span style="font-size: 16px;">❤️</span>
            <div class="hp-bar-outer">
              <div id="playerHpFill" class="hp-bar-fill" style="width: 100%;"></div>
            </div>
            <span id="playerHpText" style="font-weight: 800; font-size: 13px;">80/80</span>
          </div>
          <div class="gold-box">
            <span>🪙</span>
            <span id="playerGoldText">99</span>
          </div>
          <div class="floor-box">
            <span>📍</span>
            <span id="floorText">1막 1층</span>
          </div>
          <div id="relicsList" class="relics-list"></div>
        </div>

        <div class="top-actions">
          <button id="btnToggleLexicon" class="btn-icon">📖 단어 도감 (100)</button>
          <button id="btnToggleDeck" class="btn-icon">🎴 덱 (<span id="deckCountBadge">10</span>)</button>
          <button id="btnToggleMap" class="btn-icon">🗺️ 지도</button>
          <button id="btnMute" class="btn-icon">🔊</button>
        </div>
      </header>

      <!-- MAIN VIEW AREA -->
      <main id="mainView" class="main-view"></main>

      <!-- MODAL OVERLAY (FOR REWARDS / DECK / POPUPS) -->
      <div id="modalOverlay" class="overlay-modal" style="display: none;"></div>
    `;

    // Global Top Bar Event Listeners
    document.getElementById('btnMute').addEventListener('click', () => {
      const isMuted = sound.toggleMute();
      document.getElementById('btnMute').innerText = isMuted ? '🔇' : '🔊';
    });

    document.getElementById('btnToggleLexicon').addEventListener('click', () => {
      this.showLexiconModal();
    });

    document.getElementById('btnToggleMap').addEventListener('click', () => {
      if (this.game.battleManager.state === 'player_turn' || this.game.battleManager.state === 'enemy_turn') {
        // In battle: open map modal preview
        this.showMapModal();
      } else {
        this.renderMap();
      }
    });

    document.getElementById('btnToggleDeck').addEventListener('click', () => {
      this.showDeckModal();
    });
  }

  updateTopBar() {
    const player = this.game.player;
    const hpPercent = Math.max(0, (player.hp / player.maxHp) * 100);
    document.getElementById('playerHpFill').style.width = `${hpPercent}%`;
    document.getElementById('playerHpText').innerText = `${player.hp}/${player.maxHp}`;
    document.getElementById('playerGoldText').innerText = player.gold;
    document.getElementById('deckCountBadge').innerText = player.deck.length;

    const floor = this.game.mapManager.currentFloor;
    document.getElementById('floorText').innerText = floor === -1 ? '1막 시작' : `1막 ${floor + 1}층`;

    // Relics list
    const relicsContainer = document.getElementById('relicsList');
    relicsContainer.innerHTML = '';
    for (const r of player.relicManager.relics) {
      const el = document.createElement('div');
      el.className = 'relic-icon';
      el.innerText = r.icon;
      el.title = `[${r.name}]\n${r.desc}`;
      relicsContainer.appendChild(el);
    }
  }

  // === 1. MAP VIEW RENDERER ===
  renderMap() {
    this.currentView = 'map';
    this.updateTopBar();
    const map = this.game.mapManager;
    const mainView = document.getElementById('mainView');

    const availableNodes = map.getAvailableNextNodes();
    const availableIds = new Set(availableNodes.map(n => n.id));

    let floorsHtml = '';
    map.floors.forEach((floor, fIdx) => {
      let nodesHtml = '';
      floor.forEach(node => {
        const isCurrent = map.currentNodeId === node.id;
        const isAvailable = availableIds.has(node.id);
        const isVisited = map.currentFloor > node.floor;

        let stateClass = '';
        if (isCurrent) stateClass = 'current';
        else if (isAvailable) stateClass = 'available';
        else if (isVisited) stateClass = 'visited';

        nodesHtml += `
          <div class="map-node ${stateClass}" data-node-id="${node.id}" title="${node.name}">
            <span>${node.icon}</span>
            <div class="node-tooltip">${node.name}</div>
          </div>
        `;
      });

      floorsHtml += `
        <div class="map-floor-row">
          ${nodesHtml}
        </div>
      `;
    });

    mainView.innerHTML = `
      <div class="map-view-container">
        <div class="map-title-box">
          <h2 class="map-act-title">${map.actName}</h2>
          <p class="map-act-sub">노란색으로 빛나는 다음 노드를 선택하여 전진하세요.</p>
        </div>
        <div class="map-floors-grid">
          ${floorsHtml}
        </div>
      </div>
    `;

    // Bind click events on available nodes
    mainView.querySelectorAll('.map-node.available').forEach(el => {
      el.addEventListener('click', () => {
        const nodeId = el.dataset.nodeId;
        this.game.handleNodeSelect(nodeId);
      });
    });
  }

  // === 2. BATTLE VIEW RENDERER ===
  renderBattle() {
    this.currentView = 'battle';
    this.updateTopBar();
    const bm = this.game.battleManager;
    const player = this.game.player;
    const enemy = bm.enemy;
    const cardSys = bm.cardSystem;
    const mainView = document.getElementById('mainView');

    const enemyHpPercent = Math.max(0, (enemy.hp / enemy.maxHp) * 100);

    // Render Intent Icon & Text
    let intentHtml = '';
    const nextMove = enemy.nextMove;
    if (nextMove) {
      let intentIcon = '⚔️';
      let intentText = `${nextMove.damage || 0}`;
      if (nextMove.type === 'defense') {
        intentIcon = '🛡️';
        intentText = `${nextMove.shield || 0}`;
      } else if (nextMove.type === 'buff') {
        intentIcon = '⚡';
        intentText = '강화';
      } else if (nextMove.type === 'multi_attack') {
        intentIcon = '⚔️';
        intentText = `${nextMove.damage} x ${nextMove.hits}`;
      }
      intentHtml = `
        <div class="intent-bubble" title="${nextMove.name}: ${nextMove.desc}">
          <span>${intentIcon}</span>
          <span>${intentText}</span>
        </div>
      `;
    }

    // Crafting Slots HTML
    const slotLabels = ['초성 (자음)', '중성 (모음)', '종성 (받침)'];
    let slotsHtml = '';
    for (let i = 0; i < 3; i++) {
      const tile = cardSys.slots[i];
      slotsHtml += `
        <div class="craft-slot ${tile ? 'filled' : ''}" data-slot-idx="${i}" title="${tile ? '클릭 시 손패로 회수' : slotLabels[i]}">
          <span class="slot-label">${slotLabels[i]}</span>
          <span class="slot-char">${tile ? tile.char : '+'}</span>
        </div>
      `;
    }

    // Crafted Word Card Box HTML
    let craftedBoxHtml = '';
    if (cardSys.craftedCard) {
      const card = cardSys.craftedCard;
      craftedBoxHtml = `
        <div class="crafted-card-box active">
          <div class="card-header">
            <span class="card-title">${card.word} <span style="font-size: 11px; color: #fff;">(${card.syllable})</span></span>
            <span class="card-cost">${card.cost || 1} AP</span>
          </div>
          <div class="card-body">
            <img src="${card.icon}" class="card-icon-img" alt="${card.word}" />
            <div class="card-desc">${card.desc}</div>
          </div>
          <button id="btnPlayCard" class="btn-play-card">발동 (SPACE)</button>
        </div>
      `;
    } else {
      craftedBoxHtml = `
        <div class="crafted-empty-placeholder">
          <span>자모를 슬롯에 장착하여<br><strong>1글자 단어</strong>를 완성하세요</span>
          <span style="font-size: 10px; margin-top: 4px; color: #6d698e;">(예: ㄱ + ㅓ + ㅁ = 검)</span>
        </div>
      `;
    }

    // Hand Tiles HTML
    let handTilesHtml = '';
    cardSys.hand.forEach(tile => {
      const isSelected = this.selectedTileIdForCombine === tile.id;
      handTilesHtml += `
        <div class="jamo-tile ${isSelected ? 'selected' : ''}" data-tile-id="${tile.id}">
          <div class="tile-char">${tile.char}</div>
          <div class="tile-actions">
            ${tile.isRotatable ? `<button class="btn-tile-action btn-rotate" data-tile-id="${tile.id}" title="회전">🔄</button>` : ''}
            <button class="btn-tile-action btn-combine" data-tile-id="${tile.id}" title="합성 모드">⚡</button>
          </div>
        </div>
      `;
    });

    mainView.innerHTML = `
      <div class="battle-container">
        <!-- TOP: ARENA -->
        <div class="arena-area">
          <!-- Player Avatar -->
          <div class="player-entity">
            <div class="player-avatar">🧙‍♂️</div>
            <div class="player-status-row">
              ${player.shield > 0 ? `<div class="status-badge badge-shield">🛡️ ${player.shield}</div>` : ''}
              ${player.power > 0 ? `<div class="status-badge badge-power">⚔️ +${player.power}</div>` : ''}
              ${player.thorns > 0 ? `<div class="status-badge" style="background:#2d4a22; border:1px solid #7bc676;">🌵 ${player.thorns}</div>` : ''}
              ${player.regen > 0 ? `<div class="status-badge" style="background:#1d4a3b; border:1px solid #52c49c;">🌿 ${player.regen}</div>` : ''}
              ${player.invulnerable > 0 ? `<div class="status-badge" style="background:#4a3f12; border:1px solid #f6d365;">✨ ${player.invulnerable}</div>` : ''}
              ${player.poison > 0 ? `<div class="status-badge badge-poison">🧪 ${player.poison}</div>` : ''}
              ${player.bleed > 0 ? `<div class="status-badge" style="background:#4a1212; border:1px solid #ff4d4f;">🩸 ${player.bleed}</div>` : ''}
            </div>
          </div>

          <!-- Enemy Avatar -->
          <div class="enemy-entity">
            ${intentHtml}
            <div class="enemy-sprite-box">
              <img src="${enemy.icon}" class="enemy-sprite-img" alt="${enemy.name}" />
            </div>
            <div class="enemy-name">${enemy.name}</div>
            <div class="player-status-row" style="margin-bottom: 4px;">
              ${enemy.shield > 0 ? `<div class="status-badge badge-shield">🛡️ ${enemy.shield}</div>` : ''}
              ${enemy.power > 0 ? `<div class="status-badge badge-power">⚔️ +${enemy.power}</div>` : ''}
              ${enemy.weak > 0 ? `<div class="status-badge" style="background:#3d234a; border:1px solid #b37feb;">💫 취약 ${enemy.weak}</div>` : ''}
              ${enemy.stunned ? `<div class="status-badge" style="background:#123a4a; border:1px solid #40a9ff;">⛓️ 기절/빙결</div>` : ''}
              ${enemy.poison > 0 ? `<div class="status-badge badge-poison">🧪 ${enemy.poison}</div>` : ''}
              ${enemy.bleed > 0 ? `<div class="status-badge" style="background:#4a1212; border:1px solid #ff4d4f;">🩸 ${enemy.bleed}</div>` : ''}
            </div>
            <div class="enemy-hp-box">
              <div class="enemy-hp-bar">
                <div class="enemy-hp-fill" style="width: ${enemyHpPercent}%;"></div>
              </div>
              <div style="display: flex; justify-content: space-between; font-size: 11px; font-weight: 800; margin-top: 2px;">
                <span>${enemy.shield > 0 ? `🛡️ ${enemy.shield}` : ''}</span>
                <span>${enemy.hp}/${enemy.maxHp}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- CENTER: CRAFTING WORKBENCH -->
        <div class="crafting-area">
          <div class="slots-wrapper">
            <div class="slots-title">조합 슬롯</div>
            <div class="slots-container">
              ${slotsHtml}
            </div>
          </div>

          <div class="craft-arrow">➔</div>

          ${craftedBoxHtml}
        </div>

        <!-- BOTTOM: HAND & AP & END TURN -->
        <div class="bottom-panel">
          <div class="energy-orb">
            <div class="energy-num">${player.ap} / ${player.maxAp}</div>
            <div class="energy-label">AP 에너지</div>
          </div>

          <div class="hand-tiles-container">
            ${handTilesHtml}
          </div>

          <div class="turn-actions">
            <button id="btnEndTurn" class="btn-end-turn">턴 종료</button>
            <div class="deck-count-box">
              <span>뽑을 덱: ${cardSys.drawPile.length}</span>
              <span>버린 덱: ${cardSys.discardPile.length}</span>
            </div>
          </div>
        </div>
      </div>
    `;

    this.bindBattleEvents();
  }

  bindBattleEvents() {
    const bm = this.game.battleManager;
    const cardSys = bm.cardSystem;

    // 1. Play Card Button
    const btnPlay = document.getElementById('btnPlayCard');
    if (btnPlay) {
      btnPlay.addEventListener('click', () => {
        bm.playCraftedCard();
      });
    }

    // 2. End Turn Button
    const btnEnd = document.getElementById('btnEndTurn');
    if (btnEnd) {
      btnEnd.addEventListener('click', () => {
        bm.endPlayerTurn();
      });
    }

    // 3. Slot Click (Remove tile from slot)
    document.querySelectorAll('.craft-slot').forEach(el => {
      el.addEventListener('click', () => {
        const slotIdx = parseInt(el.dataset.slotIdx, 10);
        cardSys.removeTileFromSlot(slotIdx);
        this.renderBattle();
      });
    });

    // 4. Hand Tile Click (Place into appropriate empty slot)
    document.querySelectorAll('.jamo-tile').forEach(el => {
      el.addEventListener('click', (e) => {
        if (e.target.closest('.btn-tile-action')) return; // ignore sub button clicks

        const tileId = el.dataset.tileId;
        const tile = cardSys.hand.find(t => t.id === tileId);
        if (!tile) return;

        // If in combine mode:
        if (this.selectedTileIdForCombine) {
          if (this.selectedTileIdForCombine !== tileId) {
            const combined = cardSys.combineSelectedTiles(this.selectedTileIdForCombine, tileId);
            this.selectedTileIdForCombine = null;
            this.renderBattle();
            return;
          }
          this.selectedTileIdForCombine = null;
          this.renderBattle();
          return;
        }

        // Auto place in first valid empty slot
        if (tile.isConsonant) {
          if (!cardSys.slots[0]) cardSys.placeTileInSlot(tileId, 0);
          else if (!cardSys.slots[2]) cardSys.placeTileInSlot(tileId, 2);
          else cardSys.placeTileInSlot(tileId, 0); // replace
        } else if (tile.isVowel) {
          cardSys.placeTileInSlot(tileId, 1);
        }
        this.renderBattle();
      });
    });

    // 5. Rotate Button
    document.querySelectorAll('.btn-rotate').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const tileId = btn.dataset.tileId;
        cardSys.rotateTileInHand(tileId);
        this.renderBattle();
      });
    });

    // 6. Combine Mode Button
    document.querySelectorAll('.btn-combine').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const tileId = btn.dataset.tileId;
        if (this.selectedTileIdForCombine === tileId) {
          this.selectedTileIdForCombine = null;
        } else {
          this.selectedTileIdForCombine = tileId;
        }
        this.renderBattle();
      });
    });
  }

  // === 3. REST VIEW RENDERER (CAMPFIRE) ===
  renderRest() {
    this.currentView = 'rest';
    this.updateTopBar();
    const mainView = document.getElementById('mainView');

    mainView.innerHTML = `
      <div class="rest-container">
        <div class="rest-campfire-icon">🔥</div>
        <div>
          <h2 style="font-family: var(--font-serif); font-size: 24px; color: var(--border-gold);">활자의 모닥불</h2>
          <p style="color: var(--text-muted); font-size: 14px; margin-top: 6px;">따뜻한 불가에서 숨을 고르며 다음 여정을 준비합니다.</p>
        </div>
        <div class="rest-options">
          <div id="btnRestHeal" class="rest-card">
            <span style="font-size: 32px;">🛌</span>
            <strong style="font-size: 16px; color: var(--accent-green);">휴식</strong>
            <span style="font-size: 12px; color: #a7a9be;">최대 체력의 30% 회복 (+24 HP)</span>
          </div>
          <div id="btnRestPurge" class="rest-card">
            <span style="font-size: 32px;">✂️</span>
            <strong style="font-size: 16px; color: var(--accent-red);">자모 정제</strong>
            <span style="font-size: 12px; color: #a7a9be;">덱에서 불필요한 자모 1장 제거</span>
          </div>
        </div>
      </div>
    `;

    document.getElementById('btnRestHeal').addEventListener('click', () => {
      this.game.player.heal(24);
      sound.playMagic();
      alert('체력을 24 회복했습니다!');
      this.renderMap();
    });

    document.getElementById('btnRestPurge').addEventListener('click', () => {
      this.showPurgeDeckModal(() => {
        this.renderMap();
      });
    });
  }

  // === 4. SHOP VIEW RENDERER ===
  renderShop() {
    this.currentView = 'shop';
    this.updateTopBar();
    const mainView = document.getElementById('mainView');
    const player = this.game.player;

    const shopTiles = [
      { char: 'ㄲ', price: 35, name: '된소리 쌍기역' },
      { char: 'ㅐ', price: 30, name: '결합모음 애' },
      { char: 'ㄹ', price: 25, name: '받침 리을' },
      { char: 'ㅁ', price: 25, name: '받침 미음' }
    ];

    const shopRelics = [
      { id: 'relic_jong_weight', name: '종성의 무게추', price: 80, icon: '⚖️', desc: '받침 단어 피해 +5' },
      { id: 'relic_whetstone', name: '명장의 숫돌', price: 75, icon: '🗡️', desc: '무기 피해 +3, 실드 2' }
    ];

    let tilesHtml = '';
    shopTiles.forEach((item, idx) => {
      tilesHtml += `
        <div class="shop-item-card">
          <div style="font-family: var(--font-serif); font-size: 32px; font-weight: 900; color: #fff;">${item.char}</div>
          <div style="font-size: 12px;">${item.name}</div>
          <div class="shop-item-price">🪙 ${item.price}</div>
          <button class="btn-primary btn-buy-tile" data-idx="${idx}" style="font-size: 12px; padding: 4px 10px;">구매</button>
        </div>
      `;
    });

    let relicsHtml = '';
    shopRelics.forEach((item) => {
      const owned = player.relicManager.hasRelic(item.id);
      relicsHtml += `
        <div class="shop-item-card">
          <div class="shop-item-icon">${item.icon}</div>
          <strong style="font-size: 13px; color: var(--border-gold);">${item.name}</strong>
          <div style="font-size: 11px; color: var(--text-muted);">${item.desc}</div>
          <div class="shop-item-price">${owned ? '보유중' : `🪙 ${item.price}`}</div>
          <button class="btn-primary btn-buy-relic" data-id="${item.id}" data-price="${item.price}" ${owned ? 'disabled style="opacity:0.4"' : ''} style="font-size: 12px; padding: 4px 10px;">${owned ? '완료' : '구매'}</button>
        </div>
      `;
    });

    mainView.innerHTML = `
      <div class="shop-container">
        <div>
          <h2 style="font-family: var(--font-serif); font-size: 24px; color: var(--border-gold); text-align: center;">방랑 고서 상인</h2>
          <p style="color: var(--text-muted); font-size: 13px; text-align: center; margin-top: 4px;">"귀한 활자와 고대 비전의 서를 찾아오셨소?"</p>
        </div>

        <div style="width: 100%; max-width: 700px;">
          <h3 style="font-size: 14px; margin-bottom: 10px; color: var(--accent-blue);">[ 희귀 활자판 판매 ]</h3>
          <div class="shop-grid">
            ${tilesHtml}
          </div>
        </div>

        <div style="width: 100%; max-width: 700px;">
          <h3 style="font-size: 14px; margin-bottom: 10px; color: var(--border-gold);">[ 고대 비전 유물 ]</h3>
          <div class="shop-grid">
            ${relicsHtml}
          </div>
        </div>

        <button id="btnLeaveShop" class="btn-primary" style="margin-top: 10px;">상점 떠나기 (지도 복귀)</button>
      </div>
    `;

    document.getElementById('btnLeaveShop').addEventListener('click', () => {
      this.renderMap();
    });

    mainView.querySelectorAll('.btn-buy-tile').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = shopTiles[btn.dataset.idx];
        if (player.gold >= item.price) {
          player.gold -= item.price;
          player.deck.push(item.char);
          sound.playWordCrafted();
          alert(`'${item.char}' 활자를 덱에 추가했습니다!`);
          this.renderShop();
        } else {
          alert('골드가 부족합니다!');
        }
      });
    });

    mainView.querySelectorAll('.btn-buy-relic').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.id;
        const price = parseInt(btn.dataset.price, 10);
        if (player.gold >= price) {
          player.gold -= price;
          player.relicManager.addRelic(id);
          sound.playVictory();
          alert(`유물 [${id}]을(를) 획득했습니다!`);
          this.renderShop();
        } else {
          alert('골드가 부족합니다!');
        }
      });
    });
  }

  // === 5. EVENT VIEW RENDERER ===
  renderEvent(node) {
    this.currentView = 'event';
    this.updateTopBar();
    const mainView = document.getElementById('mainView');

    mainView.innerHTML = `
      <div class="rest-container">
        <div style="font-size: 60px;">📜</div>
        <div>
          <h2 style="font-family: var(--font-serif); font-size: 24px; color: var(--border-gold);">${node.name}</h2>
          <p style="color: var(--text-muted); font-size: 14px; margin-top: 8px; max-width: 500px; line-height: 1.5;">
            오래된 비석에서 영롱한 푸른빛이 흘러나옵니다. 비석의 문구를 읽자 활자의 기운이 당신의 몸을 감쌉니다.
          </p>
        </div>
        <div class="rest-options">
          <div id="btnEventHeal" class="rest-card">
            <span style="font-size: 32px;">💧</span>
            <strong style="font-size: 15px; color: var(--accent-blue);">영혼의 정화</strong>
            <span style="font-size: 12px; color: #a7a9be;">HP 20 회복</span>
          </div>
          <div id="btnEventGold" class="rest-card">
            <span style="font-size: 32px;">🪙</span>
            <strong style="font-size: 15px; color: var(--accent-yellow);">고대 금화 습득</strong>
            <span style="font-size: 12px; color: #a7a9be;">+40 골드 획득</span>
          </div>
        </div>
      </div>
    `;

    document.getElementById('btnEventHeal').addEventListener('click', () => {
      this.game.player.heal(20);
      sound.playMagic();
      alert('체력을 20 회복했습니다!');
      this.renderMap();
    });

    document.getElementById('btnEventGold').addEventListener('click', () => {
      this.game.player.gold += 40;
      sound.playWordCrafted();
      alert('40 골드를 획득했습니다!');
      this.renderMap();
    });
  }

  // === 6. REWARD POPUP MODAL ===
  showRewardModal(rewards, onComplete) {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';

    let tileChoicesHtml = '';
    rewards.tileOptions.forEach(char => {
      tileChoicesHtml += `
        <button class="reward-tile-btn btn-choose-reward-tile" data-char="${char}">${char}</button>
      `;
    });

    let relicHtml = '';
    if (rewards.relicDrop) {
      relicHtml = `
        <div style="background: #252238; border: 1px solid var(--border-gold); border-radius: 8px; padding: 10px; margin: 12px 0;">
          <div style="font-size: 13px; color: var(--border-gold); font-weight: 800;">👑 희귀 유물 드랍!</div>
          <div style="font-size: 14px; font-weight: 700; margin-top: 4px;">${rewards.relicDrop}</div>
        </div>
      `;
    }

    modal.innerHTML = `
      <div class="modal-card">
        <h2 style="font-family: var(--font-serif); font-size: 22px; color: var(--border-gold);">전투 승리 보상!</h2>
        <p style="font-size: 14px; color: var(--accent-yellow); margin-top: 6px;">🪙 +${rewards.gold} 골드를 획득했습니다.</p>
        
        ${relicHtml}

        <div style="margin-top: 16px;">
          <div style="font-size: 13px; color: var(--text-muted);">새로 획득할 자모 활자 1개를 선택하세요:</div>
          <div class="reward-choices-list">
            ${tileChoicesHtml}
          </div>
        </div>

        <button id="btnSkipReward" class="btn-primary" style="background: #3d3958; font-size: 13px;">선택 없이 진행</button>
      </div>
    `;

    modal.querySelectorAll('.btn-choose-reward-tile').forEach(btn => {
      btn.addEventListener('click', () => {
        const char = btn.dataset.char;
        this.game.player.deck.push(char);
        if (rewards.relicDrop) this.game.player.relicManager.addRelic(rewards.relicDrop);
        modal.style.display = 'none';
        onComplete();
      });
    });

    document.getElementById('btnSkipReward').addEventListener('click', () => {
      if (rewards.relicDrop) this.game.player.relicManager.addRelic(rewards.relicDrop);
      modal.style.display = 'none';
      onComplete();
    });
  }

  // === 7. DECK VIEWER MODAL ===
  showDeckModal() {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';

    let tilesHtml = '';
    this.game.player.deck.forEach(char => {
      tilesHtml += `
        <div style="width: 44px; height: 56px; background: #252238; border: 1px solid #4a456e; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-family: var(--font-serif); font-size: 24px; font-weight: 900; color: #fff;">
          ${char}
        </div>
      `;
    });

    modal.innerHTML = `
      <div class="modal-card" style="max-width: 600px;">
        <h2 style="font-family: var(--font-serif); font-size: 20px; color: var(--border-gold);">현재 자모 덱 (${this.game.player.deck.length}장)</h2>
        <div style="display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; max-height: 350px; overflow-y: auto; margin: 16px 0; padding: 10px; background: #13111f; border-radius: 8px;">
          ${tilesHtml}
        </div>
        <button id="btnCloseDeckModal" class="btn-primary">닫기</button>
      </div>
    `;

    document.getElementById('btnCloseDeckModal').addEventListener('click', () => {
      modal.style.display = 'none';
    });
  }

  // === 8. PURGE MODAL (CAMPFIRE) ===
  showPurgeDeckModal(onPurged) {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';

    let tilesHtml = '';
    this.game.player.deck.forEach((char, idx) => {
      tilesHtml += `
        <button class="btn-purge-tile" data-idx="${idx}" style="width: 48px; height: 60px; background: #2b2742; border: 2px solid var(--accent-red); border-radius: 6px; font-family: var(--font-serif); font-size: 26px; font-weight: 900; color: #fff; cursor: pointer;">
          ${char}
        </button>
      `;
    });

    modal.innerHTML = `
      <div class="modal-card" style="max-width: 600px;">
        <h2 style="font-family: var(--font-serif); font-size: 20px; color: var(--accent-red);">제거할 자모를 선택하세요</h2>
        <div style="display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; max-height: 300px; overflow-y: auto; margin: 16px 0; padding: 10px; background: #13111f; border-radius: 8px;">
          ${tilesHtml}
        </div>
        <button id="btnCancelPurge" class="btn-primary" style="background: #3d3958;">취소</button>
      </div>
    `;

    modal.querySelectorAll('.btn-purge-tile').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.idx, 10);
        const removed = this.game.player.deck.splice(idx, 1);
        sound.playAttack();
        alert(`'${removed[0]}' 활자를 덱에서 제거했습니다!`);
        modal.style.display = 'none';
        onPurged();
      });
    });

    document.getElementById('btnCancelPurge').addEventListener('click', () => {
      modal.style.display = 'none';
    });
  }

  showDefeatModal(onRestart) {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-card">
        <h2 style="font-family: var(--font-serif); font-size: 26px; color: var(--accent-red);">활자가 흩어졌습니다...</h2>
        <p style="color: var(--text-muted); font-size: 14px; margin: 12px 0;">체력이 0이 되어 여정이 중단되었습니다.</p>
        <button id="btnRestartGame" class="btn-primary">처음부터 다시 시작</button>
      </div>
    `;

    document.getElementById('btnRestartGame').addEventListener('click', () => {
      modal.style.display = 'none';
      onRestart();
    });
  }

  showActClearModal() {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';

    modal.innerHTML = `
      <div class="modal-card">
        <div style="font-size: 50px;">🏆</div>
        <h2 style="font-family: var(--font-serif); font-size: 26px; color: var(--border-gold); margin-top: 10px;">제 1막 클리어!</h2>
        <p style="color: #e0e1ec; font-size: 14px; line-height: 1.5; margin: 16px 0;">
          『먹물에 잠식된 서예 골렘』을 쓰러뜨리고 흩어진 활자의 숲을 정화했습니다!<br>
          <strong>『언어의 조각 : 말의 심연』 MVP 1막을 성공적으로 완주하셨습니다.</strong>
        </p>
        <button id="btnPlayAgain" class="btn-primary">다시 플레이하기</button>
      </div>
    `;

    document.getElementById('btnPlayAgain').addEventListener('click', () => {
      modal.style.display = 'none';
      window.location.reload();
    });
  }

  // === 9. LEXICON / ENCYCLOPEDIA MODAL (100 WORDS) ===
  showLexiconModal() {
    const modal = document.getElementById('modalOverlay');
    modal.style.display = 'flex';
    sound.playWordCrafted();

    const allWords = Object.values(WORD_DATABASE);
    const categories = [
      { id: 'all', name: '전체 (100)' },
      { id: 'weapon', name: '⚔️ 무기' },
      { id: 'defense', name: '🛡️ 방어' },
      { id: 'element', name: '🔮 원소' },
      { id: 'summon', name: '🐾 생물' },
      { id: 'heal', name: '💖 회복' },
      { id: 'skill', name: '✨ 버프/유틸' }
    ];

    let currentCategory = 'all';
    let searchQuery = '';

    const renderLexiconContent = () => {
      const filtered = allWords.filter(w => {
        const matchesCategory = currentCategory === 'all' || w.category === currentCategory;
        const matchesSearch = !searchQuery || 
          w.word.includes(searchQuery) || 
          w.name.includes(searchQuery) || 
          w.desc.includes(searchQuery);
        return matchesCategory && matchesSearch;
      });

      const cardsHtml = filtered.map(w => `
        <div class="lexicon-card" style="background: #252238; border: 1px solid #4a456e; border-radius: 8px; padding: 10px; display: flex; gap: 10px; align-items: center; transition: all 0.2s;">
          <img src="${w.icon}" alt="${w.word}" style="width: 40px; height: 40px; border-radius: 6px; background: #13111f; padding: 4px; border: 1px solid #3d3958; object-fit: contain;" />
          <div style="flex: 1; min-width: 0;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 3px;">
              <span style="font-family: var(--font-serif); font-size: 16px; font-weight: 900; color: #fff;">${w.word} <span style="font-size: 11px; color: var(--border-gold); font-weight: normal;">${w.name}</span></span>
              <span style="font-size: 11px; background: #3d3958; padding: 2px 6px; border-radius: 4px; color: var(--accent-yellow); font-weight: 700;">${w.cost || 0} AP</span>
            </div>
            <div style="font-size: 12px; color: #d0d2e6; line-height: 1.35;">${w.desc}</div>
          </div>
        </div>
      `).join('');

      return `
        <div class="modal-card" style="max-width: 780px; width: 95%; max-height: 85vh; display: flex; flex-direction: column;">
          <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #3d3958; padding-bottom: 12px; margin-bottom: 12px;">
            <div>
              <h2 style="font-family: var(--font-serif); font-size: 22px; color: var(--border-gold); margin: 0;">📖 활자술사 단어 도감 (100종)</h2>
              <span style="font-size: 12px; color: var(--text-muted);">시작 덱 10장으로 조합할 수 있는 모든 단어와 고유 능력</span>
            </div>
            <button id="btnCloseLexiconTop" style="background: none; border: none; font-size: 20px; color: #fff; cursor: pointer;">✕</button>
          </div>

          <!-- Search & Tabs -->
          <div style="display: flex; flex-direction: column; gap: 8px; margin-bottom: 12px;">
            <input type="text" id="lexiconSearch" placeholder="🔍 단어명 또는 능력 검색 (예: 검, 불, 방패, 회복)..." value="${searchQuery}" style="width: 100%; padding: 8px 12px; background: #13111f; border: 1px solid #4a456e; border-radius: 6px; color: #fff; font-size: 13px; box-sizing: border-box;" />
            <div style="display: flex; flex-wrap: wrap; gap: 6px;">
              ${categories.map(c => `
                <button class="btn-category-tab ${currentCategory === c.id ? 'active' : ''}" data-cat="${c.id}" style="padding: 4px 10px; border-radius: 4px; border: 1px solid ${currentCategory === c.id ? 'var(--border-gold)' : '#3d3958'}; background: ${currentCategory === c.id ? '#3d3958' : '#1d1a2b'}; color: ${currentCategory === c.id ? 'var(--border-gold)' : '#a7a9be'}; font-size: 12px; font-weight: 700; cursor: pointer;">
                  ${c.name}
                </button>
              `).join('')}
            </div>
          </div>

          <!-- Word Cards Grid -->
          <div id="lexiconCardsContainer" style="flex: 1; overflow-y: auto; display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 10px; padding: 4px; max-height: 460px;">
            ${cardsHtml.length > 0 ? cardsHtml : '<div style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 40px;">검색 결과가 없습니다.</div>'}
          </div>

          <div style="margin-top: 14px; text-align: right; border-top: 1px solid #3d3958; padding-top: 10px;">
            <span style="font-size: 12px; color: var(--text-muted); margin-right: 12px;">표시 중: ${filtered.length} / ${allWords.length}개</span>
            <button id="btnCloseLexiconBottom" class="btn-primary" style="padding: 6px 18px; font-size: 13px;">닫기</button>
          </div>
        </div>
      `;
    };

    const updateView = () => {
      modal.innerHTML = renderLexiconContent();

      // Bind Search
      const searchInput = document.getElementById('lexiconSearch');
      if (searchInput) {
        searchInput.focus();
        searchInput.selectionStart = searchInput.selectionEnd = searchInput.value.length;
        searchInput.addEventListener('input', (e) => {
          searchQuery = e.target.value.trim();
          updateView();
        });
      }

      // Bind Category Tabs
      modal.querySelectorAll('.btn-category-tab').forEach(tab => {
        tab.addEventListener('click', () => {
          currentCategory = tab.dataset.cat;
          sound.playTileClick();
          updateView();
        });
      });

      // Close handlers
      const close = () => { modal.style.display = 'none'; };
      document.getElementById('btnCloseLexiconTop')?.addEventListener('click', close);
      document.getElementById('btnCloseLexiconBottom')?.addEventListener('click', close);
    };

    updateView();
  }
}
