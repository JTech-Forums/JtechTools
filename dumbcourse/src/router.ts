// History-based router. Each history entry remembers where you were (scroll
// position and the focused item), so Back lands you on the exact topic
// you opened — essential when you move with a D-pad.

import { APP_ROOT } from "./config.ts";

export interface RouteContext {
  path: string;
  params: Record<string, string>;
  query: Record<string, string>;
  // Set when arriving by Back/Forward.
  restore: { scroll: number; focusKey: string } | null;
}

export type ViewFn = (ctx: RouteContext) => Promise<void> | void;

interface Route {
  pattern: RegExp;
  keys: string[];
  view: ViewFn;
  public: boolean;
}

interface HistoryState {
  dc: number;
  layer?: boolean;
}

const routes: Route[] = [];
const saved: Record<number, { scroll: number; focusKey: string }> = {};
let counter = Date.now();
let currentId = 0;
let fallback: ViewFn | null = null;
let beforeRoute: ((ctx: RouteContext, isPublic: boolean) => boolean) | null =
  null;
let renderRoute: ((view: ViewFn, ctx: RouteContext) => void) | null = null;
let popHook: ((state: HistoryState | null) => boolean) | null = null;
let snapshot: (() => { scroll: number; focusKey: string }) | null = null;

// "/t/:slug/:id" style patterns; a trailing "*" matches the rest.
export function route(
  pattern: string,
  view: ViewFn,
  opts: { public?: boolean } = {}
): void {
  const keys: string[] = [];
  const source = pattern
    .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
    .replace(/\/:(\w+)/g, (_m, key: string) => {
      keys.push(key);
      return "/([^/]+)";
    })
    .replace(/\*$/, "(.*)");
  if (/\*$/.test(pattern)) keys.push("rest");
  routes.push({
    pattern: new RegExp("^" + source + "/?$"),
    keys,
    view,
    public: !!opts.public,
  });
}

export function notFound(view: ViewFn): void {
  fallback = view;
}

export function configure(opts: {
  guard: (ctx: RouteContext, isPublic: boolean) => boolean;
  render: (view: ViewFn, ctx: RouteContext) => void;
  onPop: (state: HistoryState | null) => boolean;
  snapshot: () => { scroll: number; focusKey: string };
}): void {
  beforeRoute = opts.guard;
  renderRoute = opts.render;
  popHook = opts.onPop;
  snapshot = opts.snapshot;
}

export function parseQuery(search: string): Record<string, string> {
  const out: Record<string, string> = {};
  const q = search.replace(/^\?/, "");
  if (!q) return out;
  const parts = q.split("&");
  for (let i = 0; i < parts.length; i++) {
    const eq = parts[i].indexOf("=");
    const k = eq < 0 ? parts[i] : parts[i].slice(0, eq);
    const v = eq < 0 ? "" : parts[i].slice(eq + 1);
    if (!k) continue;
    try {
      out[decodeURIComponent(k)] = decodeURIComponent(
        (v || "").replace(/\+/g, " ")
      );
    } catch {
      out[k] = v || "";
    }
  }
  return out;
}

export function buildQuery(
  params: Record<string, string | number | null | undefined>
): string {
  const parts: string[] = [];
  for (const key in params) {
    if (!params.hasOwnProperty(key)) continue;
    const v = params[key];
    if (v === null || v === undefined || v === "") continue;
    parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(v)));
  }
  return parts.length ? "?" + parts.join("&") : "";
}

// App path ("/t/5") → full URL path ("/forum/dumb/t/5").
export function href(path: string): string {
  if (path.indexOf(APP_ROOT + "/") === 0 || path === APP_ROOT) return path;
  return APP_ROOT + (path.charAt(0) === "/" ? path : "/" + path);
}

export function currentPath(): string {
  let p = location.pathname || "/";
  if (p.indexOf(APP_ROOT) === 0) p = p.slice(APP_ROOT.length);
  return p || "/";
}

function match(
  path: string
): { route: Route; params: Record<string, string> } | null {
  for (let i = 0; i < routes.length; i++) {
    const m = routes[i].pattern.exec(path);
    if (!m) continue;
    const params: Record<string, string> = {};
    for (let k = 0; k < routes[i].keys.length; k++) {
      try {
        params[routes[i].keys[k]] = decodeURIComponent(m[k + 1] || "");
      } catch {
        params[routes[i].keys[k]] = m[k + 1] || "";
      }
    }
    return { route: routes[i], params };
  }
  return null;
}

function stateId(): number {
  const s = history.state as HistoryState | null;
  return s && typeof s.dc === "number" ? s.dc : 0;
}

function remember(): void {
  if (currentId && snapshot) saved[currentId] = snapshot();
}

function dispatch(restore: RouteContext["restore"]): void {
  const path = currentPath();
  const found = match(path);
  const ctx: RouteContext = {
    path,
    params: found ? found.params : {},
    query: parseQuery(location.search),
    restore,
  };
  const view = found ? found.route.view : fallback;
  if (!view) return;
  if (beforeRoute && !beforeRoute(ctx, found ? found.route.public : false))
    return;
  if (renderRoute) renderRoute(view, ctx);
}

export function navigate(path: string, opts: { replace?: boolean } = {}): void {
  remember();
  const target = href(path);
  currentId = ++counter;
  const state: HistoryState = { dc: currentId };
  try {
    if (opts.replace) history.replaceState(state, "", target);
    else history.pushState(state, "", target);
  } catch {
    location.href = target;
    return;
  }
  dispatch(null);
}

export function reload(): void {
  remember();
  dispatch(saved[currentId] || null);
}

// Adds a history entry for an open layer, so the phone's Back key closes
// the layer instead of leaving the screen. False if the engine can't.
export function pushLayerState(): boolean {
  try {
    history.pushState(
      { dc: currentId, layer: true } as HistoryState,
      "",
      location.href
    );
    return true;
  } catch {
    // Old engines without pushState: layers still close with Back/Escape keys.
    return false;
  }
}

export function isLayerState(): boolean {
  const s = history.state as HistoryState | null;
  return !!(s && s.layer);
}

export function back(): void {
  if (history.length > 1) history.back();
  else navigate("/");
}

export function start(): void {
  currentId = stateId() || ++counter;
  try {
    history.replaceState({ dc: currentId } as HistoryState, "", location.href);
  } catch {
    // ignore
  }
  window.addEventListener("popstate", (e: PopStateEvent) => {
    const state = e.state as HistoryState | null;
    if (popHook && popHook(state)) return;
    if (state && state.layer) return;
    remember();
    currentId = state && typeof state.dc === "number" ? state.dc : ++counter;
    dispatch(saved[currentId] || null);
  });
  dispatch(null);
}
