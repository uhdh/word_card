export const getInsertionIndex = (x, tileCenters) => {
  const index = tileCenters.findIndex(center => x < center);
  return index === -1 ? tileCenters.length : index;
};
