// Keeps one history entry per open layer, so the phone's Back closes the top
// layer instead of leaving the screen.
//
// History moves asynchronously: history.back() lands after the current task,
// while pushState() is immediate. Closing one layer and opening another in the
// same click (a menu item that opens the composer, a confirm dialog closing
// together with the composer it belongs to) used to let a late back() pop the
// new layer's entry, or a screen entry under it, and Back then left the app.
// So layers only report that the stack changed; once the click is over the
// entries are brought to the stack depth in one go.
//
// No DOM here, so it can be unit tested.

export interface LayerHistoryOps {
  // How many layers are open now.
  depth: () => number;
  // Adds a layer entry; false where the engine has no pushState.
  push: () => boolean;
  go: (delta: number) => void;
  // Runs fn after the current task.
  defer: (fn: () => void) => void;
}

export interface LayerHistory {
  // The stack changed: bring history in line once the current task ends.
  changed: () => void;
  // A popstate arrived. True if it was one of ours (a go() we made).
  // Otherwise the user went back over one layer entry.
  popped: () => boolean;
  // Leaving the screen: forget the layer entries without touching history.
  // Returns how many there were above the screen's entry.
  reset: () => number;
  // Goes back over n layer entries, then runs fn (once on the screen entry).
  popThen: (n: number, fn: () => void) => void;
}

export function createLayerHistory(ops: LayerHistoryOps): LayerHistory {
  // Layer entries above the screen's own entry, as far as history knows.
  let entries = 0;
  // go() calls whose popstate hasn't arrived yet, each with what to run then.
  const pending: Array<(() => void) | null> = [];
  let queued = false;
  // Bumped by reset() so a sync queued before it does nothing.
  let generation = 0;

  const sync = (gen: number): void => {
    if (gen !== generation) return;
    queued = false;
    const want = ops.depth();
    while (entries < want) {
      if (!ops.push()) break;
      entries++;
    }
    if (entries > want) {
      const n = entries - want;
      entries = want;
      pending.push(null);
      ops.go(-n);
    }
  };

  return {
    changed: () => {
      if (queued) return;
      queued = true;
      const gen = generation;
      ops.defer(() => sync(gen));
    },
    popped: () => {
      if (pending.length) {
        const then = pending.shift();
        if (then) then();
        return true;
      }
      if (entries > 0) entries--;
      return false;
    },
    reset: () => {
      const had = entries;
      entries = 0;
      queued = false;
      generation++;
      return had;
    },
    popThen: (n, fn) => {
      pending.push(fn);
      ops.go(-n);
    },
  };
}
