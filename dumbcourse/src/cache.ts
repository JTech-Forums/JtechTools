// Stale-while-revalidate for GET requests. A screen shows whatever it last
// saw immediately (instant on a slow 2G/3G link), then the network copy
// replaces it when it arrives. Entries live in memory and, bounded, in
// localStorage — bound to the signed-in account by storage.claimFor().

import { get } from "./api.ts";
import { getJson, hasOwner, remove, setJson } from "./storage.ts";

interface Entry {
  t: number;
  v: unknown;
}

const MAX_ENTRIES = 40;
const MAX_ENTRY_CHARS = 150000;
const INDEX_KEY = "cache:index";

const memory: Record<string, Entry> = {};
const inflight: Record<string, Promise<unknown>> = {};

function storageKey(path: string): string {
  return "cache:" + path;
}

function index(): string[] {
  return getJson<string[]>(INDEX_KEY, []);
}

function persist(path: string, entry: Entry): void {
  if (!hasOwner()) return;
  let serialized: string;
  try {
    serialized = JSON.stringify(entry);
  } catch {
    return;
  }
  if (serialized.length > MAX_ENTRY_CHARS) return;
  const list = index().filter((p) => p !== path);
  list.unshift(path);
  while (list.length > MAX_ENTRIES) {
    const dropped = list.pop();
    if (dropped) remove(storageKey(dropped));
  }
  setJson(INDEX_KEY, list);
  setJson(storageKey(path), entry);
}

export function peek<T>(path: string, maxAgeMs = 24 * 3600 * 1000): T | null {
  let entry = memory[path];
  if (!entry && hasOwner()) {
    entry = getJson<Entry | null>(storageKey(path), null) as Entry;
    if (entry) memory[path] = entry;
  }
  if (!entry || Date.now() - entry.t > maxAgeMs) return null;
  return entry.v as T;
}

export function store(path: string, value: unknown): void {
  const entry = { t: Date.now(), v: value };
  memory[path] = entry;
  persist(path, entry);
}

// Fetches fresh data, sharing one request between callers that ask for the
// same path at the same time.
export function fetchFresh<T>(path: string): Promise<T> {
  const running = inflight[path];
  if (running) return running as Promise<T>;
  const p = get<T>(path).then(
    (value) => {
      delete inflight[path];
      store(path, value);
      return value;
    },
    (error: unknown) => {
      delete inflight[path];
      throw error;
    }
  );
  inflight[path] = p;
  return p;
}

// Shows the cached copy first (if any) via `onData(value, true)`, then the
// network copy via `onData(value, false)` — skipped if nothing changed.
// Resolves once the fresh copy has been handled; rejects only if there was
// nothing cached to fall back on.
export function swr<T>(
  path: string,
  onData: (value: T, stale: boolean) => void
): Promise<void> {
  const cached = peek<T>(path);
  let cachedJson = "";
  if (cached) {
    try {
      cachedJson = JSON.stringify(cached);
    } catch {
      cachedJson = "";
    }
    onData(cached, true);
  }
  return fetchFresh<T>(path).then(
    (fresh) => {
      let same = false;
      if (cachedJson) {
        try {
          same = JSON.stringify(fresh) === cachedJson;
        } catch {
          same = false;
        }
      }
      if (!same) onData(fresh, false);
    },
    (error: unknown) => {
      if (!cached) throw error;
    }
  );
}

export function invalidate(prefix?: string): void {
  for (const key in memory) {
    if (memory.hasOwnProperty(key) && (!prefix || key.indexOf(prefix) === 0))
      delete memory[key];
  }
  const list = index();
  const keep: string[] = [];
  for (let i = 0; i < list.length; i++) {
    if (!prefix || list[i].indexOf(prefix) === 0) remove(storageKey(list[i]));
    else keep.push(list[i]);
  }
  setJson(INDEX_KEY, keep);
}
