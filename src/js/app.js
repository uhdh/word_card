/**
 * Hangul Roguelike Tower Defense - Web Main App Controller
 * (3 Acts x 4 Waves = 12 Stages, Precision Drag & Drop, NeoDunggeunmo Pixel Theme)
 */

import { WORD_DATABASE, getWordData, getAllWords } from './core/wordDatabase.js';
import * as HangulEngine from './core/hangulEngine.js';
import { parseJamoStream } from './core/hangulStreamParser.js';
import { SaveManager } from './core/saveManager.js';
import { sound } from './core/soundEngine.js';

const ACT_NAMES = {
  1: "초원의 문자",
  2: "고대 유적의 어둠",
  3: "차원의 심연"
};

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
    this.gold = 30;
    this.currentAct = 1;
    this.maxActs = 3;
    this.currentWave = 0;
    this.maxWavesPerAct = 4;
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

    // Winding Path Points (Forward S-Curve ➔ Turnaround at Slot 4 ➔ Returning S-Curve to Base at y=300)
    this.pathPoints = [
      { x: 60, y: 100 },
      { x: 395, y: 100 },
      { x: 395, y: 300 },
      { x: 585, y: 300 },
      { x: 585, y: 100 },
      { x: 775, y: 100 },
      { x: 775, y: 300 },
      { x: 960, y: 300 },
      { x: 960, y: 100 },
      { x: 775, y: 100 },
      { x: 775, y: 300 },
      { x: 585, y: 300 },
      { x: 585, y: 100 },
      { x: 395, y: 100 },
      { x: 395, y: 300 },
      { x: 60, y: 300 }
    ];

    this.isLoadingState = true;

    this.initDOM();
    this.initCanvas();
    this.initShortcuts();

    if (SaveManager.hasSaveFile()) {
      this.loadGame();
    } else {
      this.renderBelt();
      this.updateTopBar();
    }

    this.isLoadingState = false;
    this.startGameLoop();
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

    this.beltContainer.addEventListener("dragover", (e) => e.preventDefault());
    this.beltContainer.addEventListener("drop", (e) => {
      if (e.target === this.beltContainer) {
        e.preventDefault();
        const fromIdx = parseInt(e.dataTransfer.getData("text/plain"), 10);
        if (!isNaN(fromIdx) && fromIdx >= 0 && fromIdx < this.jamoList.length) {
          const item = this.jamoList.splice(fromIdx, 1)[0];
          this.jamoList.push(item);
          sound.playTileClick();
          this.renderBelt();
          this.saveGame();
        }
      }
    });

    this.btnLoad.disabled = !SaveManager.hasSaveFile();
    this.updateTopBar();
  }

  initCanvas() {
    this.canvas = document.getElementById("field-canvas");
    this.ctx = this.canvas.getContext("2d");
    this.canvas.width = 1000;
    this.canvas.height = 420;

    this.imgGrass = new Image();
    this.imgGrass.src = "./assets/map_ui/map_bg_grass.png";
    this.imgGrass.onload = () => { this.grassPattern = this.ctx.createPattern(this.imgGrass, "repeat"); };

    this.imgRoad = new Image();
    this.imgRoad.src = "./assets/map_ui/map_road_dirt.png";
    this.imgRoad.onload = () => { this.roadPattern = this.ctx.createPattern(this.imgRoad, "repeat"); };

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
            this.openTowerDetailModal(this.activeTowers[i]);
          }
          break;
        }
      }
    });
  }

  initShortcuts() {
    window.addEventListener("keydown", (e) => {
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;

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
    const actName = ACT_NAMES[this.currentAct] || "미지의 영역";
    this.hpLabel.textContent = `기지 HP: ${this.baseHp} / ${this.maxBaseHp}`;
    this.goldLabel.textContent = `${this.gold} G`;
    this.waveLabel.textContent = `🚩 제 ${this.currentAct}막 [${actName}] - 🌊 ${this.currentWave} / ${this.maxWavesPerAct}`;
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

    this.activeTowers = parsed.map(p => ({
      syllable: p.syllable,
      tier: p.tier,
      wordData: p.wordData,
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
      tileBox.addEventListener("dragend", () => {
        document.querySelectorAll(".jamo-tile-box").forEach(el => el.classList.remove("dragging", "drop-left", "drop-right"));
      });
      tileBox.addEventListener("dragover", (e) => {
        e.preventDefault();
        const rect = tileBox.getBoundingClientRect();
        const isRight = (e.clientX - rect.left) > (rect.width / 2);
        tileBox.classList.toggle("drop-left", !isRight);
        tileBox.classList.toggle("drop-right", isRight);
      });
      tileBox.addEventListener("dragleave", () => {
        tileBox.classList.remove("drop-left", "drop-right");
      });
      tileBox.addEventListener("drop", (e) => {
        e.preventDefault();
        tileBox.classList.remove("drop-left", "drop-right");
        const fromIdx = parseInt(e.dataTransfer.getData("text/plain"), 10);
        if (!isNaN(fromIdx) && fromIdx >= 0 && fromIdx < this.jamoList.length) {
          const rect = tileBox.getBoundingClientRect();
          const isRight = (e.clientX - rect.left) > (rect.width / 2);
          let targetIdx = idx + (isRight ? 1 : 0);
          const item = this.jamoList.splice(fromIdx, 1)[0];
          if (fromIdx < targetIdx) targetIdx -= 1;
          this.jamoList.splice(targetIdx, 0, item);
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
  }

  startNextWave() {
    if (this.isWaveRunning) return;

    this.currentWave += 1;
    if (this.currentWave > this.maxWavesPerAct) {
      if (this.currentAct < this.maxActs) {
        this.currentAct += 1;
        this.currentWave = 1;
      } else {
        this.handleGameOver(true);
        return;
      }
    }

    this.isWaveRunning = true;
    this.updateTopBar();
    sound.playWaveStart();

    // Calculate difficulty by Act and Wave
    const totalStage = (this.currentAct - 1) * this.maxWavesPerAct + this.currentWave;
    const count = 4 + this.currentWave * 2 + (this.currentAct - 1) * 3;
    const enemyHp = 15 + totalStage * 18 + (this.currentWave === 4 ? 120 : 0);
    const speed = 65 + (this.currentAct - 1) * 8;

    let spawned = 0;
    const spawnTimer = setInterval(() => {
      if (spawned >= count) {
        clearInterval(spawnTimer);
        return;
      }
      const isBoss = (spawned === count - 1 && this.currentWave === 4);
      this.enemies.push({
        id: Math.random(),
        pathIndex: 0,
        x: this.pathPoints[0].x,
        y: this.pathPoints[0].y,
        hp: isBoss ? enemyHp * 2.2 : enemyHp,
        maxHp: isBoss ? enemyHp * 2.2 : enemyHp,
        speed: isBoss ? speed * 0.7 : speed,
        isBoss: isBoss,
        goldValue: isBoss ? (25 + this.currentAct * 10) : (2 + totalStage)
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

    // Tower Attacks
    for (let i = 0; i < this.activeTowers.length; i++) {
      const tower = this.activeTowers[i];
      const slot = this.slots[i];
      if (!tower || !slot) continue;

      tower.attackCooldown -= dt;
      if (tower.attackCooldown <= 0 && this.enemies.length > 0) {
        let target = null;
        let maxProgress = -1;

        for (const enemy of this.enemies) {
          const d = Math.hypot(enemy.x - slot.x, enemy.y - slot.y);
          if (d <= tower.range) {
            const progress = enemy.pathIndex * 1000 + (enemy.x + enemy.y);
            if (progress > maxProgress) {
              maxProgress = progress;
              target = enemy;
            }
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
      const isActFinal = (this.currentWave >= this.maxWavesPerAct);
      let baseBonus = isActFinal ? (25 + this.currentAct * 10) : (10 + this.currentWave * 4);
      if (this.hasRelic("relic_merchant_pouch")) {
        baseBonus = Math.round(baseBonus * 1.5);
      }
      this.gold += baseBonus;
      sound.playWaveClear();
      this.updateTopBar();

      const clearedAct = this.currentAct;
      const clearedWave = this.currentWave;

      if (isActFinal) {
        if (clearedAct >= this.maxActs) {
          this.handleGameOver(true);
        } else {
          this.openActClearedModal(clearedAct, baseBonus);
        }
      } else {
        this.openWaveRewardModal(clearedWave, baseBonus, () => {
          // 2웨이브 클리어 시 방랑 상인 조우
          if (clearedWave === 2) {
            setTimeout(() => this.openShopModal(), 300);
          }
        });
      }
      this.saveGame();
    }
  }

  openActClearedModal(act, bonusGold) {
    const actName = ACT_NAMES[act] || "미지의 영역";
    const nextAct = act + 1;
    const nextActName = ACT_NAMES[nextAct] || "다음 장";

    this.rerollDice += 1;

    this.openModal(`
      <div class="modal-box act-cleared-modal" style="text-align: center; gap: 16px;">
        <div class="modal-header" style="justify-content: center;">
          <h2 style="color: #fde047; font-size: 22px;">🏆 [제 ${act}막: ${actName}] 완벽 돌파!</h2>
        </div>
        <p style="font-size: 14px; color: #cbd5e1; line-height: 1.6;">
          막 보스를 물리치고 대보상을 획득했습니다!<br>
          <span style="color: #38bdf8; font-weight: bold;">보너스 골드: +${bonusGold} G | 🎲 주사위 +1개 충전</span><br><br>
          다음 장: <strong style="color: #a855f7;">[제 ${nextAct}막: ${nextActName}]</strong>
        </p>
        <div style="display: flex; justify-content: center; gap: 12px; margin-top: 10px;">
          <button class="btn btn-start-next-act" id="btn-start-next-act" style="background:#7c3aed; color:#fff; padding:10px 20px; font-weight:bold; border:none; border-radius:6px; cursor:pointer;">
            ⚔️ 제 ${nextAct}막 진입 & 상점 정비
          </button>
        </div>
      </div>
    `);

    document.getElementById("btn-start-next-act").addEventListener("click", () => {
      this.closeModal();
      this.saveGame();
      setTimeout(() => this.openShopModal(), 300);
    });
  }

  render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    // 0. Draw Grass Texture Background
    if (this.grassPattern) {
      ctx.fillStyle = this.grassPattern;
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    } else {
      ctx.fillStyle = "#1e2e1e";
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }

    // 1. Draw Winding Dirt Path Road
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    // Outer dark dirt border
    ctx.strokeStyle = "#2b1a0e";
    ctx.lineWidth = 46;
    ctx.beginPath();
    ctx.moveTo(this.pathPoints[0].x, this.pathPoints[0].y);
    for (let i = 1; i < this.pathPoints.length; i++) {
      ctx.lineTo(this.pathPoints[i].x, this.pathPoints[i].y);
    }
    ctx.stroke();

    // Inner textured dirt path
    ctx.strokeStyle = this.roadPattern || "#b3824f";
    ctx.lineWidth = 38;
    ctx.beginPath();
    ctx.moveTo(this.pathPoints[0].x, this.pathPoints[0].y);
    for (let i = 1; i < this.pathPoints.length; i++) {
      ctx.lineTo(this.pathPoints[i].x, this.pathPoints[i].y);
    }
    ctx.stroke();

    // 2. Draw Spawn & Base
    ctx.fillStyle = "#ef4444";
    ctx.beginPath();
    ctx.arc(60, 100, 22, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 12px 'NeoDunggeunmo', monospace";
    ctx.textAlign = "center";
    ctx.fillText("차원의 문", 60, 140);

    ctx.fillStyle = "#06b6d4";
    ctx.beginPath();
    ctx.arc(60, 300, 22, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.fillText("활자 본진", 60, 340);

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
        ctx.font = "bold 17px 'NeoDunggeunmo', monospace";
        ctx.textAlign = "center";
        ctx.fillText(tower.syllable, slot.x, slot.y - 8);

        ctx.fillStyle = "#ffffff";
        ctx.font = "12px 'NeoDunggeunmo', monospace";
        ctx.fillText(`💥 ${tower.damage}`, slot.x, slot.y + 12);
        ctx.fillStyle = "#94a3b8";
        ctx.font = "11px 'NeoDunggeunmo', monospace";
        ctx.fillText(tower.tier === 3 ? "⭐⭐⭐" : (tower.tier === 2 ? "⭐⭐" : "⭐"), slot.x, slot.y + 26);
      } else {
        ctx.fillStyle = "#64748b";
        ctx.font = "12px 'NeoDunggeunmo', monospace";
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
      ctx.font = "bold 13px 'NeoDunggeunmo', monospace";
      ctx.textAlign = "center";
      ctx.fillText(p.text, p.x, p.y);
    });
  }

  saveGame(showToast = false) {
    if (this.isLoadingState) return;
    SaveManager.saveGame({
      jamoList: this.jamoList,
      baseHp: this.baseHp,
      maxBaseHp: this.maxBaseHp,
      gold: this.gold,
      currentAct: this.currentAct,
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
    this.isLoadingState = true;
    this.jamoList = data.jamoList || ["ㅂ", "ㅜ", "ㄹ"];
    this.baseHp = data.baseHp || 20;
    this.maxBaseHp = data.maxBaseHp || 20;
    this.gold = data.gold !== undefined ? data.gold : 30;
    this.currentAct = data.currentAct || 1;
    this.currentWave = data.currentWave || 0;
    this.rerollDice = data.rerollDice !== undefined ? data.rerollDice : 3;
    this.ownedRelics = data.relics || [];
    this.isWaveRunning = false;
    this.enemies = [];

    this.renderBelt();
    this.updateTopBar();
    this.btnLoad.disabled = false;
    sound.playWordCrafted();
    this.isLoadingState = false;
  }

  openModal(contentHtml) {
    this.modalContent.innerHTML = contentHtml;
    this.modalOverlay.classList.remove("hidden");
  }

  closeModal() {
    this.modalOverlay.classList.add("hidden");
    this.modalContent.innerHTML = "";
  }

  openTowerDetailModal(tower) {
    sound.playTileClick();
    const w = tower.wordData || {};
    const syl = tower.syllable;
    const tierBadge = tower.tier === 3 ? "⭐⭐⭐ 신화 단어" : (tower.tier === 2 ? "⭐⭐ 상위 단어" : "⭐ 기본 활자");

    this.openModal(`
      <div class="modal-box tower-info-modal">
        <div class="modal-header">
          <h3>🏰 [${syl} 타워] 상세 정보 (${tierBadge})</h3>
          <button class="btn-modal-close" id="btn-modal-close">✖</button>
        </div>
        <div class="tower-specs-grid">
          <div>💥 공격력: <strong>${tower.damage}</strong></div>
          <div>🏹 사거리: <strong>${tower.range} px</strong></div>
          <div>⏱️ 쿨타임: <strong>${tower.attackInterval.toFixed(2)}초</strong></div>
          <div>🏷️ 단어 티어: <strong>${tower.tier}티어</strong></div>
        </div>
        <div class="tower-effect-box">
          <h4>📜 고유 활자 효과</h4>
          <p>${w.desc || "사전에 등록되지 않은 미지의 활자입니다. 기본 활자 탄환을 발사합니다."}</p>
        </div>
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
            <div style="display:flex; align-items:center; justify-content:center; gap:6px; margin-bottom:4px;">
              <img src="${r.icon}" style="width:24px; height:24px; image-rendering:pixelated;" onerror="this.style.display='none'" />
              <div class="relic-name">${r.name}</div>
            </div>
            <div class="relic-desc">${r.desc}</div>
            <button class="btn-buy-relic" data-idx="${idx}" ${isOwned ? 'disabled' : ''}>
              ${isOwned ? '보유 중' : r.cost + ' G 구매'}
            </button>
          </div>
        `;
      });

      let removeTilesHtml = "";
      this.jamoList.forEach((ch, idx) => {
        removeTilesHtml += `<button class="btn-remove-tile" data-idx="${idx}" ${this.gold < 15 || this.jamoList.length <= 1 ? 'disabled' : ''}>${ch}</button>`;
      });

      this.openModal(`
        <div class="modal-box shop-modal" style="width: 680px; max-height: 600px; overflow-y: auto;">
          <div class="modal-header">
            <h3>🧙‍♂️ 방랑 상인 모로크 (보유 골드: ${this.gold} G)</h3>
            <button class="btn-modal-close" id="btn-modal-close">✖</button>
          </div>
          <div class="shop-npc-dialog" style="font-size: 12px; margin-bottom: 6px;">
            “길목에서 마주쳐 반갑소, 영웅이여! 자모 활자와 귀한 에테르 유물들을 한눈에 둘러보시게.”
          </div>

          <div class="shop-all-sections" style="display: flex; flex-direction: column; gap: 14px;">
            <!-- Section 1: Jamo Shelf -->
            <div class="shop-section">
              <h4 style="font-size: 13px; color: #fde047; margin-bottom: 8px;">🔤 자모 활자 진열대 (일반 10G / 희귀 18G / 초희귀 25G)</h4>
              <div class="shop-grid" style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px;">${stockHtml}</div>
            </div>

            <!-- Section 2: Relics -->
            <div class="shop-section">
              <h4 style="font-size: 13px; color: #c084fc; margin-bottom: 8px;">🏺 신비한 에테르 유물 (고유 패시브 아티팩트)</h4>
              <div class="relics-grid" style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px;">${relicHtml}</div>
            </div>

            <!-- Section 3: Deck Thinning -->
            <div class="shop-section">
              <h4 style="font-size: 13px; color: #f87171; margin-bottom: 6px;">✂️ 덱 압축 (타일 영구 제거 - 15 G)</h4>
              <div class="remove-tiles-grid" style="display: flex; flex-wrap: wrap; gap: 8px;">${removeTilesHtml}</div>
            </div>
          </div>
        </div>
      `);

      // Events
      document.getElementById("btn-modal-close").addEventListener("click", () => this.closeModal());

      document.querySelectorAll(".btn-buy-stock").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.currentTarget.getAttribute("data-idx"), 10);
          const item = stock[idx];
          if (!item.sold && this.gold >= item.cost && this.jamoList.length < 15) {
            this.gold -= item.cost;
            item.sold = true;
            this.jamoList.push(item.char);
            sound.playWordCrafted();
            this.updateTopBar();
            this.renderBelt();
            this.saveGame();
            renderShop();
          }
        });
      });

      document.querySelectorAll(".btn-buy-relic").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.currentTarget.getAttribute("data-idx"), 10);
          const r = availableRelics[idx];
          if (!this.hasRelic(r.id) && this.gold >= r.cost) {
            this.gold -= r.cost;
            this.applyRelic(r);
            sound.playBuff();
            this.updateTopBar();
            this.renderBelt();
            this.saveGame();
            renderShop();
          }
        });
      });

      document.querySelectorAll(".btn-remove-tile").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const idx = parseInt(e.currentTarget.getAttribute("data-idx"), 10);
          if (this.gold >= 15 && this.jamoList.length > 1) {
            this.gold -= 15;
            this.jamoList.splice(idx, 1);
            sound.playHit();
            this.updateTopBar();
            this.renderBelt();
            this.saveGame();
            renderShop();
          }
        });
      });
    };

    renderShop();
  }

  applyRelic(relic) {
    this.ownedRelics.push(relic);
    if (relic.id === "relic_golden_dice") {
      this.rerollDice += 2;
    } else if (relic.id === "relic_fortress_rune") {
      this.maxBaseHp += 10;
      this.baseHp = Math.min(this.baseHp + 10, this.maxBaseHp);
    }
  }

  openLexiconModal() {
    sound.playTileClick();
    const discovered = SaveManager.getDiscoveredWords();
    const allWords = getAllWords();
    const rate = Math.round((discovered.length / allWords.length) * 100);

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
            this.saveGame();
          }
          this.closeModal();
          if (onClosedCallback) onClosedCallback();
        });
      });

      // Reroll Dice Click
      const btnReroll = document.getElementById("btn-reroll-dice");
      if (btnReroll) {
        btnReroll.addEventListener("click", () => {
          if (this.rerollDice > 0) {
            this.rerollDice -= 1;
            sound.playTileRotate();
            this.updateTopBar();
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
      <div class="modal-box gameover-modal" style="text-align: center; gap: 16px;">
        <h2>${isVictory ? "🎉 최종 디펜스 승리! (엔딩)" : "💀 기지 함락 (패배)"}</h2>
        <p>${isVictory ? "축하합니다! 3막의 모든 차원 괴수와 최종 보스를 정복하고 활자의 평화를 지켜냈습니다!" : "기지가 파괴되었습니다. 자모를 다시 조합하여 도전하세요!"}</p>
        <button class="btn" id="btn-retry" style="background:#8b5cf6; color:#fff; padding:10px 20px; font-weight:bold; border:none; border-radius:6px; cursor:pointer;">
          처음부터 다시하기
        </button>
      </div>
    `);

    document.getElementById("btn-retry").addEventListener("click", () => {
      location.reload();
    });
  }
}

window.addEventListener("DOMContentLoaded", () => {
  new HangulTDApp();
});
