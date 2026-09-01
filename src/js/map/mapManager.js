/**
 * <언어의 조각 : 말의 심연> Slay the Spire-style Map Manager
 * 1막(Act 1. 흩어진 활자의 숲) 절차적 노드 맵 생성 및 진행도 관리
 */

export class MapManager {
  constructor() {
    this.act = 1;
    this.actName = '제 1막 : 흩어진 활자의 숲';
    this.currentFloor = -1; // -1: Not started
    this.currentNodeId = null;
    this.floors = [];
    this.generateAct1Map();
  }

  generateAct1Map() {
    // 10 Floors (Floor 0 to 9, where Floor 9 is Boss)
    this.floors = [
      // Floor 0: Starter monsters
      [
        { id: 'f0_n0', floor: 0, type: 'monster', enemy: 'letter_slime', name: '낱자 슬라임', icon: '👾', next: ['f1_n0', 'f1_n1'] },
        { id: 'f0_n1', floor: 0, type: 'monster', enemy: 'thorn_vine', name: '가시 돋친 넝쿨', icon: '🌿', next: ['f1_n1', 'f1_n2'] }
      ],
      // Floor 1: Monster / Event
      [
        { id: 'f1_n0', floor: 1, type: 'monster', enemy: 'wild_boar', name: '사나운 멧돼지', icon: '🐗', next: ['f2_n0'] },
        { id: 'f1_n1', floor: 1, type: 'event', name: '신비한 활자의 샘', icon: '❓', next: ['f2_n0', 'f2_n1'] },
        { id: 'f1_n2', floor: 1, type: 'monster', enemy: 'letter_slime', name: '낱자 슬라임', icon: '👾', next: ['f2_n1'] }
      ],
      // Floor 2: Shop / Rest
      [
        { id: 'f2_n0', floor: 2, type: 'shop', name: '방랑 고서 상인', icon: '🏬', next: ['f3_n0', 'f3_n1'] },
        { id: 'f2_n1', floor: 2, type: 'rest', name: '활자의 모닥불', icon: '🔥', next: ['f3_n1', 'f3_n2'] }
      ],
      // Floor 3: Elite / Dangerous Battle
      [
        { id: 'f3_n0', floor: 3, type: 'monster', enemy: 'wild_boar', name: '사나운 멧돼지', icon: '🐗', next: ['f4_n0'] },
        { id: 'f3_n1', floor: 3, type: 'elite', enemy: 'ink_spirit', name: '먹물 웅덩이의 악령', icon: '👿', next: ['f4_n0', 'f4_n1'] },
        { id: 'f3_n2', floor: 3, type: 'monster', enemy: 'thorn_vine', name: '가시 돋친 넝쿨', icon: '🌿', next: ['f4_n1'] }
      ],
      // Floor 4: Event / Rest
      [
        { id: 'f4_n0', floor: 4, type: 'event', name: '고대 필경사의 비석', icon: '❓', next: ['f5_n0', 'f5_n1'] },
        { id: 'f4_n1', floor: 4, type: 'rest', name: '활자의 모닥불', icon: '🔥', next: ['f5_n1', 'f5_n2'] }
      ],
      // Floor 5: Strong Monster
      [
        { id: 'f5_n0', floor: 5, type: 'monster', enemy: 'wild_boar', name: '사나운 멧돼지', icon: '🐗', next: ['f6_n0'] },
        { id: 'f5_n1', floor: 5, type: 'monster', enemy: 'thorn_vine', name: '가시 돋친 넝쿨', icon: '🌿', next: ['f6_n0', 'f6_n1'] },
        { id: 'f5_n2', floor: 5, type: 'shop', name: '방랑 고서 상인', icon: '🏬', next: ['f6_n1'] }
      ],
      // Floor 6: Elite Challenge
      [
        { id: 'f6_n0', floor: 6, type: 'elite', enemy: 'ink_spirit', name: '먹물 웅덩이의 악령', icon: '👿', next: ['f7_n0'] },
        { id: 'f6_n1', floor: 6, type: 'event', name: '부서진 활자판의 수수께끼', icon: '❓', next: ['f7_n0'] }
      ],
      // Floor 7: Pre-Boss Rest
      [
        { id: 'f7_n0', floor: 7, type: 'rest', name: '결전 전야의 모닥불', icon: '🔥', next: ['f8_n0'] }
      ],
      // Floor 8: Boss
      [
        { id: 'f8_n0', floor: 8, type: 'boss', enemy: 'ink_golem', name: '먹물에 잠식된 서예 골렘', icon: '👑', next: [] }
      ]
    ];
  }

  getAvailableNextNodes() {
    if (this.currentFloor === -1) {
      // First floor nodes available
      return this.floors[0];
    }
    const current = this.findNodeById(this.currentNodeId);
    if (!current || !current.next) return [];

    return current.next.map(id => this.findNodeById(id)).filter(Boolean);
  }

  findNodeById(id) {
    for (const floor of this.floors) {
      const found = floor.find(n => n.id === id);
      if (found) return found;
    }
    return null;
  }

  moveToNode(nodeId) {
    const node = this.findNodeById(nodeId);
    if (!node) return null;

    this.currentFloor = node.floor;
    this.currentNodeId = node.id;
    return node;
  }
}
