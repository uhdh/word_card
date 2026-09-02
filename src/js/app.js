/**
 * Hangul Roguelike Tower Defense - Web Main App Controller
 * (Event Merchant, Relic Artifacts, Balanced Economy, Streamlined Jamos)
 */

import { WORD_DATABASE, getWordData, getAllWords } from './core/wordDatabase.js';
import * as HangulEngine from './core/hangulEngine.js';
import { parseJamoStream } from './core/hangulStreamParser.js';
import { SaveManager } from './core/saveManager.js';
import { sound } from './core/soundEngine.js';

const ALL_RELIC_POOL = [
  {
    id: "relic_golden_dice",
    name: "🎲 황금 주사위",
    cost: 25,
    desc: "보상 리롤 주사위를 +2개 즉시 지급합니다.",
    icon: "./assets/relics/relic_golden_dice_32px_pastel.png"
  },
  {
    id: "relic_essence_power",
    name: "⚔️ 활자의 정수",
    cost: 35,
    desc: "모든 활자 타워의 공격력이 +20% 증가합니다.",
    icon: "./assets/relics/relic_essence_power_32px_pastel.png"
  },
  {
    id: "relic_fortress_rune",
    name: "🛡️ 철옹성 룬",
    cost: 30,
    desc: "기지 최대 체력이 +10 증가하고 즉시 10 회복합니다.",
    icon: "./assets/relics/relic_fortress_rune_32px_pastel.png"
  },
  {
    id: "relic_haste_compass",
    name: "⏱️ 신속의 나침반",
    cost: 35,
    desc: "모든 활자 타워의 공격 속도가 20% 빨라집니다.",
    icon: "./assets/relics/relic_haste_compass_32px_pastel.png"
  },
  {
    id: "relic_merchant_pouch",
    name: "💰 상인의 보물주머니",
    cost: 30,
    desc: "웨이브 클리어 골드 보상이 +50% 증가합니다.",
    icon: "./assets/relics/relic_merchant_pouch_32px_pastel.png"
  },
  {
    id: "relic_crit_lens",
    name: "🎯 예리한 렌즈",
    cost: 35,
    desc: "타워 공격 시 25% 확률로 2배 치명타 피해를 입힙니다.",
    icon: "./assets/relics/relic_crit_lens_32px_pastel.png"
  }
];

class HangulTDApp {
  constructor() {
    this.baseHp = 20;
    this.maxBaseHp = 20;
    this.gold = 30; // 시작 골드 30 G 밸런스
    this.currentWave = 0;
    this.maxWave = 5;
    this.rerollDice = 3;
    this.ownedRelics = [];
    this.isWaveRunning = false;
    this.speedScale = 1.0;

    this.jamoList = ["ㅂ", "ㅜ", "ㄹ"]; // Starting Deck -> [불]
    this.selectedSwapIndex = -1;

    // Towers & Field
    this.activeTowers = [];
    this.enemies = [];
    this.projectiles = [];
    this.particles = [];

    // Slot Positions (matching Godot winding curve)
    this.slots = [
      { x: 300, y: 200, label: "1번 슬롯" },
      { x: 490, y: 200, label: "2번 슬롯" },
      { x: 680, y: 200, label: "3번 슬롯" },
      { x: 870, y: 200, label: "4번 슬롯" }
    ];

    // Winding Path Points
    this.pathPoints = [
      { x: 60, y: 100 },
      { x: 280, y: 100 },
      { x: 395, y: 100 },
      { x: 395, y: 300 },
      { x: 490, y: 300 },
      { x: 585, y: 300 },
      { x: 585, y: 100 },
      { x: 680, y: 100 },
      { x: 775, y: 100 },
      { x: 775, y: 300 },
      { x: 870, y: 300 },
      { x: 960, y: 300 },
      { x: 960, y: 370 },
      { x: 80, y: 370 }
    ];

    this.initDOM();
    this.initCanvas();
    this.initShortcuts();
    this.renderBelt();
    this.startGameLoop();

    // Initial save
    this.saveGame();
  }

  initDOM() {
    this.hpLabel = document.getElementById("hp-label");
    this.goldLabel = document.getElementById("gold-label");
    this.waveLabel = document.getElementById("wave-label");
    this.diceTopLabel = document.getElementById("dice-top-label");

    this.btnStartWave = document.getElementById("btn-start-wave");
    this.btnSave = document.getElementById("btn-save");
    this.btnLoad = document.getElementById("btn-load");
    this.btnSpeed = document.getElementById("btn-speed");
    this.btnLexicon = document.getElementById("btn-lexicon");
    this.btnMute = document.getElementById("btn-mute");

    this.beltContainer = document.getElementById("tiles-container");
    this.previewLabel = document.getElementById("preview-label");
    this.modalOverlay = document.getElementById("modal-overlay");
    this.modalContent = document.getElementById("modal-content");

    this.btnStartWave.addEventListener("click", () => this.startNextWave());
    this.btnSave.addEventListener("click", () => this.saveGame(true));
    this.btnLoad.addEventListener("click", () => this.loadGame());
    this.btnSpeed.addEventListener("click", () => this.toggleSpeed());
    this.btnLexicon.addEventListener("click", () => this.openLexiconModal());
    this.btnMute.addEventListener("click", () => this.toggleMute());

    this.btnLoad.disabled = !SaveManager.hasSaveFile();
    this.updateTopBar();
  }

  initCanvas() {
    this.canvas = document.getElementById("field-canvas");
    this.ctx = this.canvas.getContext("2d");
    this.canvas.width = 1000;
    this.canvas.height = 420;

    this.canvas.addEventListener("click", (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const scaleX = this.canvas.width / rect.width;
      const scaleY = this.canvas.height / rect.height;
      const clickX = (e.clientX - rect.left) * scaleX;
      const clickY = (e.clientY - rect.top) * scaleY;

      for (let i = 0; i < this.slots.length; i++) {
        const slot = this.slots[i];
        if (Math.abs(clickX - slot.x) < 36 && Math.abs(clickY - slot.y) < 40) {
          if (this.activeTowers[i]) {
            this.openTowerInfoModal(this.activeTowers[i]);
          }
          break;
        }
      }
    });
  }

  initShortcuts() {
    window.addEventListener("keydown", (e) => {
      if (this.modalOverlay.style.display === "flex") {
        if (e.key === "Escape") this.closeModal();
        return;
      }

      if (e.code === "Space") {
        e.preventDefault();
        if (!this.isWaveRunning) this.startNextWave();
      } else if (e.key === "1") {
        this.setSpeed(1.0);
      } else if (e.key === "2") {
        this.setSpeed(2.0);
      } else if (e.key === "3" || e.key === "4") {
        this.setSpeed(4.0);
      } else if (e.key === "Tab" || e.key === "d" || e.key === "D") {
        e.preventDefault();
        this.openLexiconModal();
      } else if (e.key === "s" || e.key === "S") {
        if (!e.ctrlKey) this.saveGame(true);
      } else if (e.key === "l" || e.key === "L") {
        this.loadGame();
      } else if (e.key === "m" || e.key === "M") {
        this.toggleMute();
      }
    });
  }

  updateTopBar() {
    this.hpLabel.textContent = `기지 HP: ${this.baseHp} / ${this.maxBaseHp}`;
    this.goldLabel.textContent = `${this.gold} G`;
    this.waveLabel.textContent = `${this.currentWave} / ${this.maxWave} 웨이브`;
    if (this.diceTopLabel) this.diceTopLabel.textContent = `🎲 ${this.rerollDice}개`;
    this.btnStartWave.disabled = this.isWaveRunning;
    this.btnStartWave.textContent = this.isWaveRunning ? "⚔️ 웨이브 진행 중..." : "▶ 다음 웨이브 시작";
  }

  setSpeed(speed) {
    this.speedScale = speed;
    if (speed === 1.0) this.btnSpeed.textContent = "▶ 1x 배속";
    else if (speed === 2.0) this.btnSpeed.textContent = "⏩ 2x 배속";
    else if (speed >= 4.0) this.btnSpeed.textContent = "⚡ 4x 초고속";
  }

  toggleSpeed() {
    if (this.speedScale === 1.0) this.setSpeed(2.0);
    else if (this.speedScale === 2.0) this.setSpeed(4.0);
    else this.setSpeed(1.0);
  }

  toggleMute() {
    const isMuted = sound.toggleMute();
    this.btnMute.textContent = isMuted ? "🔇" : "🔊";
  }

  hasRelic(rId) {
    return this.ownedRelics.some(r => r.id === rId);
  }

  renderBelt() {
    this.beltContainer.innerHTML = "";

    const parsed = parseJamoStream(this.jamoList);
    const speedBoost = this.hasRelic("relic_haste_compass") ? 0.8 : 1.0;
    const powerBoost = this.hasRelic("relic_essence_power") ? 1.2 : 1.0;

    this.activeTowers = parsed.map((p, idx) => ({
      slotIndex: idx,
      syllable: p.syllable,
      wordData: p.wordData,
      tier: p.tier,
      attackCooldown: 0,
      attackInterval: (p.wordData.rapid_fire ? 0.25 : (p.tier === 3 ? 0.7 : (p.tier === 2 ? 0.85 : 0.95))) * speedBoost,
      range: p.tier === 3 ? 200 : (p.tier === 2 ? 180 : 150),
      damage: Math.round((p.wordData.damage || 4) * powerBoost)
    }));

    const previewTexts = [];
    for (const p of parsed) {
      previewTexts.push(`[${p.syllable} 타워]`);
      SaveManager.discoverWord(p.syllable);
    }
    this.previewLabel.textContent = previewTexts.length > 0 ?
      `🏰 자동 완성 타워: ${previewTexts.join(" ➔ ")}` : "단어 조합 없음";

    this.jamoList.forEach((charStr, idx) => {
      const rarity = HangulEngine.getRarity(charStr);
      const isRot = HangulEngine.isRotatable(charStr);

      let rarityClass = "";
      if (rarity === "super_rare") rarityClass = "super-rare-tile";
      else if (rarity === "rare") rarityClass = "rare-tile";

      const tileBox = document.createElement("div");
      tileBox.className = `jamo-tile-box ${rarityClass} ${this.selectedSwapIndex === idx ? "selected-tile" : ""}`;
      tileBox.draggable = true;

      tileBox.addEventListener("dragstart", (e) => {
        e.dataTransfer.setData("text/plain", idx.toString());
        tileBox.classList.add("dragging");
      });
      tileBox.addEventListener("dragend", () => tileBox.classList.remove("dragging"));
      tileBox.addEventListener("dragover", (e) => e.preventDefault());
      tileBox.addEventListener("drop", (e) => {
        e.preventDefault();
        const fromIdx = parseInt(e.dataTransfer.getData("text/plain"), 10);
        if (!isNaN(fromIdx) && fromIdx !== idx) {
          const item = this.jamoList.splice(fromIdx, 1)[0];
          this.jamoList.splice(idx, 0, item);
          sound.playTileClick();
          this.renderBelt();
          this.saveGame();
        }
      });

      const btnTile = document.createElement("button");
      btnTile.className = "btn-jamo-tile";
      btnTile.textContent = charStr;
      btnTile.addEventListener("click", () => {
        if (this.selectedSwapIndex === -1) {
          this.selectedSwapIndex = idx;
          sound.playTileClick();
          this.renderBelt();
        } else if (this.selectedSwapIndex === idx) {
          this.selectedSwapIndex = -1;
          this.renderBelt();
        } else {
          const tmp = this.jamoList[this.selectedSwapIndex];
          this.jamoList[this.selectedSwapIndex] = this.jamoList[idx];
          this.jamoList[idx] = tmp;
          this.selectedSwapIndex = -1;
          sound.playTileClick();
          this.renderBelt();
          this.saveGame();
        }
      });
      tileBox.appendChild(btnTile);

      if (isRot) {
        const btnRot = document.createElement("button");
        btnRot.className = "btn-rot";
        btnRot.textContent = "🔄";
        btnRot.title = "90도 회전";
        btnRot.addEventListener("click", (e) => {
          e.stopPropagation();
          this.jamoList[idx] = HangulEngine.rotate(this.jamoList[idx]);
          sound.playTileRotate();
          this.renderBelt();
          this.saveGame();
        });
        tileBox.appendChild(btnRot);
      }

      this.beltContainer.appendChild(tileBox);
    });

    this.saveGame();
  }

  startNextWave() {
    if (this.isWaveRunning) return;
    this.currentWave += 1;
    this.isWaveRunning = true;
    this.updateTopBar();
    sound.playWaveStart();

    const count = 5 + this.currentWave * 3;
    const enemyHp = 20 + this.currentWave * 15;
    const speed = 65;

    let spawned = 0;
    const spawnTimer = setInterval(() => {
      if (spawned >= count) {
        clearInterval(spawnTimer);
        return;
      }
      this.enemies.push({
        id: Math.random(),
        pathIndex: 0,
        x: this.pathPoints[0].x,
        y: this.pathPoints[0].y,
        hp: enemyHp,
        maxHp: enemyHp,
        speed: speed,
        isBoss: (spawned === count - 1 && this.currentWave % 2 === 0),
        goldValue: 1 + Math.floor(this.currentWave * 0.6)
      });
      spawned += 1;
    }, 900 / this.speedScale);
  }

  startGameLoop() {
    let lastTime = performance.now();
    const loop = (time) => {
      const dt = Math.min((time - lastTime) / 1000, 0.1) * this.speedScale;
      lastTime = time;

      this.update(dt);
      this.render();

      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  update(dt) {
    if (dt <= 0) return;

    for (let i = this.enemies.length - 1; i >= 0; i--) {
      const enemy = this.enemies[i];
      const targetPt = this.pathPoints[enemy.pathIndex + 1];

      if (!targetPt) {
        this.baseHp -= enemy.isBoss ? 5 : 1;
        sound.playHurt();
        this.enemies.splice(i, 1);
        this.updateTopBar();
        if (this.baseHp <= 0) this.handleGameOver(false);
        continue;
      }

      const dx = targetPt.x - enemy.x;
      const dy = targetPt.y - enemy.y;
      const dist = Math.hypot(dx, dy);
      const step = enemy.speed * dt;

      if (dist <= step) {
        enemy.x = targetPt.x;
        enemy.y = targetPt.y;
        enemy.pathIndex += 1;
      } else {
        enemy.x += (dx / dist) * step;
        enemy.y += (dy / dist) * step;
      }
    }

    // Towers Attack
    for (let tIdx = 0; tIdx < this.activeTowers.length; tIdx++) {
      const tower = this.activeTowers[tIdx];
      const slot = this.slots[tIdx];
      if (!slot) continue;

      tower.attackCooldown -= dt;
      if (tower.attackCooldown <= 0) {
        let target = null;
        let minDist = tower.range;

        for (const enemy of this.enemies) {
          const d = Math.hypot(enemy.x - slot.x, enemy.y - slot.y);
          if (d <= minDist) {
            minDist = d;
            target = enemy;
          }
        }

        if (target) {
          tower.attackCooldown = tower.attackInterval;
          let dmg = tower.damage || 4;

          // Crit check
          let isCrit = false;
          if (this.hasRelic("relic_crit_lens") && Math.random() < 0.25) {
            dmg *= 2;
            isCrit = true;
          }

          this.projectiles.push({
            startX: slot.x,
            startY: slot.y,
            targetX: target.x,
            targetY: target.y,
            targetRef: target,
            damage: dmg,
            tier: tower.tier,
            life: 0.15
          });

          target.hp -= dmg;
          sound.playAttack();

          this.particles.push({
            x: target.x,
            y: target.y,
            text: isCrit ? `💥CRIT -${dmg}` : `-${dmg}`,
            color: isCrit ? "#fbbf24" : (tower.tier >= 3 ? "#f43f5e" : (tower.tier === 2 ? "#eab308" : "#38bdf8")),
            life: 0.6
          });

          if (target.hp <= 0) {
            const eIdx = this.enemies.indexOf(target);
            if (eIdx !== -1) {
              this.gold += target.goldValue;
              this.enemies.splice(eIdx, 1);
              sound.playHit();
              this.updateTopBar();
            }
          }
        }
      }
    }

    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      this.projectiles[i].life -= dt;
      if (this.projectiles[i].life <= 0) this.projectiles.splice(i, 1);
    }

    for (let i = this.particles.length - 1; i >= 0; i--) {
      this.particles[i].life -= dt;
      this.particles[i].y -= 20 * dt;
      if (this.particles[i].life <= 0) this.particles.splice(i, 1);
    }

    // Check Wave Clear
    if (this.isWaveRunning && this.enemies.length === 0) {
      this.isWaveRunning = false;
      let baseBonus = 10 + this.currentWave * 5; // 15G, 20G, 25G, 30G, 35G
      if (this.hasRelic("relic_merchant_pouch")) {
        baseBonus = Math.round(baseBonus * 1.5);
      }
      this.gold += baseBonus;
      sound.playWaveClear();
      this.updateTopBar();

      const clearedWave = this.currentWave;
      this.openWaveRewardModal(clearedWave, baseBonus, () => {
        // 방랑 상인 이벤트 조우 (2, 4 웨이브 클리어 시)
        if (clearedWave === 2 || clearedWave === 4) {
          setTimeout(() => this.openShopModal(), 300);
        }
      });
      this.saveGame();

      if (this.currentWave >= this.maxWave) {
        this.handleGameOver(true);
      }
    }
  }

  render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    // 1. Draw Winding Path Road
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    ctx.strokeStyle = "#473c60";
    ctx.lineWidth = 46;
    ctx.beginPath();
    this.pathPoints.forEach((pt, idx) => {
      if (idx === 0) ctx.moveTo(pt.x, pt.y);
      else ctx.lineTo(pt.x, pt.y);
    });
    ctx.stroke();

    ctx.strokeStyle = "#272138";
    ctx.lineWidth = 38;
    ctx.stroke();

    ctx.strokeStyle = "#6d5e8a";
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 8]);
    ctx.stroke();
    ctx.setLineDash([]);

    // 2. Spawn Portal & Base
    ctx.fillStyle = "#ef4444";
    ctx.beginPath();
    ctx.arc(60, 100, 22, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 11px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("차원의 문", 60, 140);

    ctx.fillStyle = "#06b6d4";
    ctx.beginPath();
    ctx.arc(80, 370, 24, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.fillText("활자 본진", 80, 410);

    // 3. Draw Tower Slots
    this.slots.forEach((slot, idx) => {
      const tower = this.activeTowers[idx];

      ctx.fillStyle = "#1e1a2e";
      ctx.strokeStyle = tower ? (tower.tier >= 3 ? "#ec4899" : (tower.tier === 2 ? "#eab308" : "#3b82f6")) : "#554c6d";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(slot.x - 34, slot.y - 38, 68, 76, 8);
      ctx.fill();
      ctx.stroke();

      if (tower) {
        ctx.fillStyle = tower.tier >= 3 ? "#f472b6" : (tower.tier === 2 ? "#fde047" : "#67e8f9");
        ctx.font = "bold 16px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(tower.syllable, slot.x, slot.y - 8);

        ctx.fillStyle = "#ffffff";
        ctx.font = "11px sans-serif";
        ctx.fillText(`💥 ${tower.damage}`, slot.x, slot.y + 12);
        ctx.fillStyle = "#94a3b8";
        ctx.font = "10px sans-serif";
        ctx.fillText(tower.tier === 3 ? "⭐⭐⭐" : (tower.tier === 2 ? "⭐⭐" : "⭐"), slot.x, slot.y + 26);
      } else {
        ctx.fillStyle = "#64748b";
        ctx.font = "11px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(slot.label, slot.x, slot.y + 4);
      }
    });

    // 4. Draw Projectiles
    this.projectiles.forEach((proj) => {
      ctx.strokeStyle = proj.tier >= 3 ? "#f43f5e" : (proj.tier === 2 ? "#eab308" : "#38bdf8");
      ctx.lineWidth = proj.tier >= 3 ? 4 : (proj.tier === 2 ? 3 : 2);
      ctx.beginPath();
      ctx.moveTo(proj.startX, proj.startY);
      ctx.lineTo(proj.targetX, proj.targetY);
      ctx.stroke();
    });

    // 5. Draw Enemies
    this.enemies.forEach((enemy) => {
      ctx.fillStyle = enemy.isBoss ? "#dc2626" : "#7c3aed";
      ctx.beginPath();
      ctx.arc(enemy.x, enemy.y, enemy.isBoss ? 18 : 12, 0, Math.PI * 2);
      ctx.fill();

      const barW = enemy.isBoss ? 36 : 24;
      ctx.fillStyle = "#1e293b";
      ctx.fillRect(enemy.x - barW / 2, enemy.y - (enemy.isBoss ? 28 : 20), barW, 4);
      ctx.fillStyle = "#22c55e";
      const hpRatio = Math.max(0, enemy.hp / enemy.maxHp);
      ctx.fillRect(enemy.x - barW / 2, enemy.y - (enemy.isBoss ? 28 : 20), barW * hpRatio, 4);
    });

    // 6. Draw Particles
    this.particles.forEach((p) => {
      ctx.fillStyle = p.color;
      ctx.font = "bold 13px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(p.text, p.x, p.y);
    });
  }

  saveGame(showToast = false) {
    SaveManager.saveGame({
      jamoList: this.jamoList,
      baseHp: this.baseHp,
      maxBaseHp: this.maxBaseHp,
      gold: this.gold,
      currentWave: this.currentWave,
      rerollDice: this.rerollDice,
      relics: this.ownedRelics
    });
    this.btnLoad.disabled = false;
    if (showToast) {
      this.btnSave.textContent = "✅ 저장됨!";
      sound.playBuff();
      setTimeout(() => { this.btnSave.textContent = "💾 저장"; }, 1500);
    }
  }

  loadGame() {
    const data = SaveManager.loadGame();
    if (!data) return;
    this.jamoList = data.jamoList || ["ㅂ", "ㅜ", "ㄹ"];
    this.baseHp = data.baseHp || 20;
    this.maxBaseHp = data.maxBaseHp || 20;
    this.gold = data.gold || 30;
    this.currentWave = data.currentWave || 0;
    this.rerollDice = data.rerollDice !== undefined ? data.rerollDice : 3;
    this.ownedRelics = data.relics || [];
    this.isWaveRunning = false;
    this.enemies = [];

    this.renderBelt();
    this.updateTopBar();
    sound.playWordCrafted();
  }

  openModal(contentHtml) {
    this.modalContent.innerHTML = contentHtml;
    this.modalOverlay.style.display = "flex";
  }

  closeModal() {
    this.modalOverlay.style.display = "none";
    this.modalContent.innerHTML = "";
  }

  openTowerInfoModal(tower) {
    const data = tower.wordData;
    this.openModal(`
      <div class="modal-box">
        <div class="modal-header">
          <h3>🏰 ${data.name || tower.syllable}</h3>
          <button class="btn-modal-close" id="btn-modal-close">✖</button>
        </div>
        <div class="tower-specs-grid">
          <div><strong>티어:</strong> ${tower.tier === 3 ? "⭐⭐⭐ 3글자 신화" : (tower.tier === 2 ? "⭐⭐ 2글자 상위" : "⭐ 1글자 기본")}</div>
          <div><strong>공격력:</strong> 💥 ${tower.damage}</div>
          <div><strong>사거리:</strong> 🎯 ${tower.range} px</div>
          <div><strong>공속:</strong> ⏱️ ${tower.attackInterval.toFixed(2)} 초</div>
        </div>
        <div class="modal-desc">${data.desc || "활자 타워입니다."}</div>
      </div>
    `);

    document.getElementById("btn-modal-close").addEventListener("click", () => this.closeModal());
  }

  openShopModal() {
    sound.playTileClick();
    let currentTab = "buy";

    const stock = [];
    for (let i = 0; i < 4; i++) {
      const pick = HangulEngine.getWeightedRandomJamo();
      const rarity = HangulEngine.getRarity(pick);
      let cost = 10;
      if (rarity === "super_rare") cost = 25;
      else if (rarity === "rare") cost = 18;

      stock.push({
        char: pick,
        rarity,
        cost
      });
    }

    const availableRelics = ALL_RELIC_POOL.filter(r => !this.hasRelic(r.id)).slice(0, 3);

    const renderShop = () => {
      let stockHtml = "";
      stock.forEach((item, idx) => {
        let rClass = "";
        if (item.rarity === "super_rare") rClass = "super-rare-card";
        else if (item.rarity === "rare") rClass = "rare-card";

        stockHtml += `
          <div class="shop-card ${rClass}">
            <div class="shop-char">${item.char}</div>
            <button class="btn-buy-stock" data-idx="${idx}">${item.sold ? '품절' : item.cost + ' G'}</button>
          </div>
        `;
      });

      let relicHtml = "";
      availableRelics.forEach((r, idx) => {
        const isOwned = this.hasRelic(r.id);
        relicHtml += `
          <div class="relic-card">
            <div class="relic-name">${r.name}</div>
            <div class="relic-desc">${r.desc}</div>
            <button class="btn-buy-relic" data-idx="${idx}" ${isOwned ? 'disabled' : ''}>
              ${isOwned ? '보유 중' : r.cost + ' G 구매'}
            </button>
          </div>
        `;
      });

      let removeTilesHtml = "";
      this.jamoList.forEach((ch, idx) => {
        removeTilesHtml += `<button class="btn-remove-tile" data-idx="${idx}">${ch}</button>`;
      });

      this.openModal(`
        <div class="modal-box shop-modal">
          <div class="modal-header">
            <h3>🧙‍♂️ 방랑 상인 모로크 (이벤트 조우)</h3>
            <div class="shop-gold">🪙 보유: ${this.gold} G</div>
            <button class="btn-modal-close" id="btn-modal-close">✖</button>
          </div>
          <p class="npc-dialog">“운이 좋군! 차원의 길목에서 나를 만나다니. 자모와 신비한 유물을 둘러보게.”</p>
          
          <div class="shop-tab-buttons" style="display:flex; gap:8px; margin: 8px 0;">
            <button class="btn ${currentTab === 'buy' ? 'btn-primary' : ''}" id="tab-btn-buy">🏪 자모 구매</button>
            <button class="btn ${currentTab === 'relic' ? 'btn-primary' : ''}" id="tab-btn-relic">🏺 신비한 유물</button>
            <button class="btn ${currentTab === 'remove' ? 'btn-primary' : ''}" id="tab-btn-remove">✂️ 덱 압축 (15 G)</button>
          </div>

          <div id="shop-tab-buy" style="display: ${currentTab === 'buy' ? 'block' : 'none'};">
            <div class="shop-grid">${stockHtml}</div>
          </div>

          <div id="shop-tab-relic" style="display: ${currentTab === 'relic' ? 'block' : 'none'};">
            <div class="relic-grid" style="display:flex; gap:10px; justify-content:center;">${relicHtml}</div>
          </div>

          <div id="shop-tab-remove" style="display: ${currentTab === 'remove' ? 'block' : 'none'};">
            <p style="font-size:12px; color:#94a3b8; margin-bottom:6px;">제거할 자모 타일을 클릭하세요 (비용: 15 G):</p>
            <div class="remove-tiles-row">${removeTilesHtml}</div>
          </div>
        </div>
      `);

      document.getElementById("btn-modal-close").addEventListener("click", () => this.closeModal());

      document.getElementById("tab-btn-buy").addEventListener("click", () => { currentTab = "buy"; renderShop(); });
      document.getElementById("tab-btn-relic").addEventListener("click", () => { currentTab = "relic"; renderShop(); });
      document.getElementById("tab-btn-remove").addEventListener("click", () => { currentTab = "remove"; renderShop(); });

      // Buy Jamo
      document.querySelectorAll(".btn-buy-stock").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.target.getAttribute("data-idx"), 10);
          const item = stock[idx];
          if (!item.sold && this.gold >= item.cost && this.jamoList.length < 15) {
            this.gold -= item.cost;
            item.sold = true;
            this.jamoList.push(item.char);
            sound.playCoin();
            this.renderBelt();
            this.updateTopBar();
            renderShop();
          }
        });
      });

      // Buy Relic
      document.querySelectorAll(".btn-buy-relic").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.target.getAttribute("data-idx"), 10);
          const r = availableRelics[idx];
          if (!this.hasRelic(r.id) && this.gold >= r.cost) {
            this.gold -= r.cost;
            this.ownedRelics.push(r);
            if (r.id === "relic_golden_dice") this.rerollDice += 2;
            if (r.id === "relic_fortress_rune") {
              this.maxBaseHp += 10;
              this.baseHp = Math.min(this.baseHp + 10, this.maxBaseHp);
            }
            sound.playBuff();
            this.renderBelt();
            this.updateTopBar();
            renderShop();
          }
        });
      });

      // Remove Jamo
      document.querySelectorAll(".btn-remove-tile").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.target.getAttribute("data-idx"), 10);
          if (this.gold >= 15 && this.jamoList.length > 1) {
            this.gold -= 15;
            this.jamoList.splice(idx, 1);
            sound.playTileClick();
            this.renderBelt();
            this.updateTopBar();
            renderShop();
          }
        });
      });
    };

    renderShop();
  }

  openLexiconModal() {
    sound.playWordCrafted();
    const discovered = SaveManager.getDiscoveredWords();
    const allWords = getAllWords();
    const rate = ((discovered.length / allWords.length) * 100).toFixed(1);

    let cardsHtml = "";
    allWords.forEach((w) => {
      const isUn = discovered.includes(w.word);
      const tierBadge = w.word.length >= 3 ? "⭐⭐⭐ 신화" : (w.word.length === 2 ? "⭐⭐ 상위" : "⭐ 기본");

      if (isUn) {
        cardsHtml += `
          <div class="lex-card unlocked">
            <div class="lex-header">
              <span class="lex-name">${w.word} [${tierBadge}]</span>
              <span class="lex-dmg">💥 ${w.damage}</span>
            </div>
            <div class="lex-desc">${w.desc}</div>
          </div>
        `;
      } else {
        cardsHtml += `
          <div class="lex-card locked">
            <div class="lex-header">
              <span class="lex-name">❓ ??? [${tierBadge}]</span>
              <span class="lex-dmg">💥 ???</span>
            </div>
            <div class="lex-desc">“미지의 활자입니다. 자모를 결합하여 도감을 해금하세요.”</div>
          </div>
        `;
      }
    });

    this.openModal(`
      <div class="modal-box lexicon-modal">
        <div class="modal-header">
          <h3>📖 활자 대도감 (달성률: ${discovered.length}/${allWords.length} [${rate}%])</h3>
          <button class="btn-modal-close" id="btn-modal-close">✖</button>
        </div>
        <div class="lexicon-grid">${cardsHtml}</div>
      </div>
    `);

    document.getElementById("btn-modal-close").addEventListener("click", () => this.closeModal());
  }

  openWaveRewardModal(wave, bonusGold, onClosedCallback = null) {
    const renderRewardModal = () => {
      const choices = [];
      for (let i = 0; i < 3; i++) {
        choices.push(HangulEngine.getWeightedRandomJamo());
      }

      let choicesHtml = "";
      choices.forEach((ch) => {
        const rarity = HangulEngine.getRarity(ch);
        let rClass = "";
        let tag = "기본 자모";
        if (rarity === "super_rare") {
          rClass = "super-rare-choice";
          tag = "🔥 초희귀 (4변환)";
        } else if (rarity === "rare") {
          rClass = "rare-choice";
          tag = "✨ 희귀 (2변환)";
        }

        choicesHtml += `
          <button class="btn-reward-choice ${rClass}" data-char="${ch}">
            <div class="reward-char">${ch}</div>
            <div class="reward-tag">${tag}</div>
          </button>
        `;
      });

      this.openModal(`
        <div class="modal-box reward-modal">
          <div class="modal-header">
            <h3>🏆 제 ${wave} 웨이브 클리어! (+${bonusGold} G)</h3>
          </div>
          <p>벨트에 추가할 자모 1개를 선택하세요:</p>
          <div class="reward-choices-row">${choicesHtml}</div>
          <div class="reward-reroll-row" style="display:flex; justify-content:center; align-items:center; gap:12px; margin-top:14px;">
            <button class="btn btn-reroll-dice" id="btn-reroll-dice" ${this.rerollDice <= 0 ? 'disabled' : ''}>
              ${this.rerollDice > 0 ? '🎲 보상 새로고침' : '🎲 주사위 소진'}
            </button>
            <span style="color:#fde047; font-size:13px; font-weight:bold;">남은 주사위: ${this.rerollDice}개</span>
          </div>
        </div>
      `);

      // Choice click
      document.querySelectorAll(".btn-reward-choice").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const charStr = e.currentTarget.getAttribute("data-char");
          if (charStr && this.jamoList.length < 15) {
            this.jamoList.push(charStr);
            sound.playWordCrafted();
            this.renderBelt();
            this.closeModal();
            this.saveGame();
            if (onClosedCallback) onClosedCallback();
          }
        });
      });

      // Reroll click
      const btnReroll = document.getElementById("btn-reroll-dice");
      if (btnReroll) {
        btnReroll.addEventListener("click", () => {
          if (this.rerollDice > 0) {
            this.rerollDice -= 1;
            sound.playTileRotate();
            this.saveGame();
            renderRewardModal();
          }
        });
      }
    };

    renderRewardModal();
  }

  handleGameOver(isVictory) {
    this.openModal(`
      <div class="modal-box game-over-modal">
        <h2>${isVictory ? "🎉 활자 디펜스 승리!" : "💀 기지 함락 (패배)"}</h2>
        <p>${isVictory ? "모든 차원의 마수들을 활자의 힘으로 소멸시켰습니다!" : "기지가 마수들의 침공으로 무너졌습니다."}</p>
        <button class="btn-start-again" id="btn-restart">🔄 처음부터 다시하기</button>
      </div>
    `);

    document.getElementById("btn-restart").addEventListener("click", () => {
      this.baseHp = 20;
      this.maxBaseHp = 20;
      this.gold = 30;
      this.currentWave = 0;
      this.rerollDice = 3;
      this.ownedRelics = [];
      this.jamoList = ["ㅂ", "ㅜ", "ㄹ"];
      this.isWaveRunning = false;
      this.enemies = [];
      this.renderBelt();
      this.updateTopBar();
      this.closeModal();
    });
  }
}

// Start Web App
window.addEventListener("DOMContentLoaded", () => {
  window.hangulTDApp = new HangulTDApp();
});
