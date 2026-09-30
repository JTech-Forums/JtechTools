// Just enough of a browser for the app's pure modules to import under
// Node's test runner. Import it (dynamically, before the module under test).

const store: Record<string, string> = {};
const g = globalThis as unknown as Record<string, unknown>;

g.window = g;
g.localStorage = {
  getItem: (k: string) => (k in store ? store[k] : null),
  setItem: (k: string, v: string) => {
    store[k] = String(v);
  },
  removeItem: (k: string) => {
    delete store[k];
  },
  key: (i: number) => Object.keys(store)[i] ?? null,
  get length() {
    return Object.keys(store).length;
  },
};
g.location = {
  protocol: "https:",
  host: "forum.example",
  pathname: "/dumb/",
  search: "",
  hash: "",
};
g.document = {
  getElementById: () => null,
  querySelector: () => null,
  querySelectorAll: () => [],
  documentElement: {
    className: "",
    style: {},
    clientWidth: 240,
    clientHeight: 320,
  },
  createElement: () => ({ style: {}, setAttribute() {}, appendChild() {} }),
  addEventListener() {},
  cookie: "",
};
g.innerWidth = 240;
g.innerHeight = 320;
g.matchMedia = () => ({ matches: false });

export {};
