export function groupTilesByTowers(jamoList, parsed) {
  const visibleTowers = parsed.slice(0, 4);
  const used = new Set(visibleTowers.flatMap(tower => tower.indices));
  return {
    towers: visibleTowers.map(tower => ({ word: tower.syllable, indices: [...tower.indices].sort((a, b) => a - b) })),
    waiting: jamoList.map((_, index) => index).filter(index => !used.has(index))
  };
}
