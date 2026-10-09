// Ranking a ballot on the keypad: pure list moves, kept apart from the
// screen so they can be tested without a browser (test/elections.test.ts).

// `id` moved to `place` (1 = first). A place past the end puts it last.
export function placeAt(
  ranking: number[],
  id: number,
  place: number
): number[] {
  const rest = removeFrom(ranking, id);
  const at = Math.max(0, Math.min(place - 1, rest.length));
  return rest.slice(0, at).concat([id], rest.slice(at));
}

export function removeFrom(ranking: number[], id: number): number[] {
  return ranking.filter((x) => x !== id);
}

export function moveBy(ranking: number[], id: number, by: number): number[] {
  const at = ranking.indexOf(id);
  if (at < 0) return ranking;
  return placeAt(ranking, id, at + 1 + by);
}

export function sameRanking(a: number[], b: number[]): boolean {
  return a.join(",") === b.join(",");
}
