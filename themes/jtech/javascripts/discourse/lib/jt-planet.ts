// The hero's planet (components/jt-hero): a globe of dots that turns, lit
// from the side the copy is on, with an atmosphere, two orbits and their
// satellites. It is drawn in the theme's text colour over the hero's own
// background, both read from the page, so it follows light, dark, Dim and an
// admin's palette edits, and a switch between them. It stops while it's off
// screen or the tab is hidden, and draws one still frame for people who ask
// for reduced motion.
//
// The box it fills is laid out by jt-hero.scss, which also says where in the
// box the globe sits: --jt-planet-x / --jt-planet-y (its centre) and
// --jt-planet-r (its radius), as fractions of the box's width. The box holds
// four stacked canvases: the parts that don't move (the atmosphere; the far
// side of the orbits and the globe's disc; the near side of the orbits and
// the lit rim) are drawn once per size or colour, and only the dots and the
// satellites are drawn again each frame, 24 times a second (60 while
// someone is turning it by hand, lib/jt-hero-quirks).

const TAU = Math.PI * 2;
const SEED = 17.17;

// Terrain above this level is land; the sea is a sparse lattice, a share of
// its points kept
const LAND = 0.5;
const SEA_KEPT = 0.32;

// One turn in a little over two minutes, the axis leaning towards the viewer
// and to one side
const SPIN = TAU / 140;
const TILT = 0.36;
const ROLL = -0.32;

// Dots are drawn in batches by brightness: one path per step
const STEPS = 12;

// 24 frames a second: the globe turns slowly, and fewer frames is less work
// for a phone. Between them it sleeps on a timer that wakes it a little
// before the next is due, so the screen's frames in between cost nothing.
const FRAME_MS = 1000 / 24;
const HAND_FRAME_MS = 1000 / 60;
const WAKE_EARLY_MS = 6;

// A ping (a tap on the globe): two rings running out from the rim
const PING_S = 1.5;
const PING_LAG = 0.22;

// Orbits, in globe radii: width, height, lean
const ORBITS = [
  { rx: 1.3, ry: 0.34, lean: -0.26, dash: false },
  { rx: 1.52, ry: 0.46, lean: -0.17, dash: true },
];

// Satellites: which orbit, speed (radians per second), where they start
const SATELLITES = [
  { orbit: 0, speed: 0.3, phase: 0.6 },
  { orbit: 0, speed: 0.2, phase: 3.9 },
  { orbit: 1, speed: 0.12, phase: 2.2 },
];

interface Rgb {
  r: number;
  g: number;
  b: number;
}

interface Dots {
  pos: Float32Array;
  land: Uint8Array;
  glint: Float32Array;
  spark: Uint8Array;
  count: number;
}

export interface PlanetOptions {
  still: boolean;
  intro: boolean;
}

// A lattice point's pseudo-random value in [0, 1): the fractional part of a
// large sine, the usual shader trick
function hash(x: number, y: number, z: number): number {
  const v = Math.sin(x * 127.1 + y * 311.7 + z * 74.7 + SEED) * 43758.5453;
  return v - Math.floor(v);
}

function fade(t: number): number {
  return t * t * (3 - 2 * t);
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

// Smooth noise in 3D, so the land runs continuously over the globe
function noise(x: number, y: number, z: number): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const zi = Math.floor(z);
  const u = fade(x - xi);
  const v = fade(y - yi);
  const w = fade(z - zi);
  const c = (dx: number, dy: number, dz: number) =>
    hash(xi + dx, yi + dy, zi + dz);
  return lerp(
    lerp(lerp(c(0, 0, 0), c(1, 0, 0), u), lerp(c(0, 1, 0), c(1, 1, 0), u), v),
    lerp(lerp(c(0, 0, 1), c(1, 0, 1), u), lerp(c(0, 1, 1), c(1, 1, 1), u), v),
    w
  );
}

// Four octaves: continents, then coasts
function terrain(x: number, y: number, z: number): number {
  let sum = 0;
  let amp = 0.5;
  let freq = 1.6;
  for (let i = 0; i < 4; i++) {
    sum += amp * noise(x * freq + 11.3, y * freq + 4.7, z * freq + 8.1);
    freq *= 2.1;
    amp *= 0.5;
  }
  return sum;
}

// Rows of dots along the lines of latitude, each row as evenly spaced as the
// equator's, the poles iced over
function makeDots(spacing: number): Dots {
  const rows = Math.max(10, Math.round(Math.PI / spacing));
  const pos: number[] = [];
  const land: number[] = [];
  const glint: number[] = [];
  const spark: number[] = [];
  for (let i = 0; i < rows; i++) {
    const lat = -Math.PI / 2 + ((i + 0.5) * Math.PI) / rows;
    const ring = Math.cos(lat);
    const y = Math.sin(lat);
    const count = Math.max(1, Math.round((TAU * ring) / spacing));
    for (let j = 0; j < count; j++) {
      const lon = ((j + (i % 2) * 0.5) * TAU) / count;
      const x = ring * Math.cos(lon);
      const z = ring * Math.sin(lon);
      const isLand = Math.abs(y) > 0.9 || terrain(x, y, z) > LAND;
      if (!isLand && hash(i, j, 7) > SEA_KEPT) {
        continue;
      }
      pos.push(x, y, z);
      land.push(isLand ? 1 : 0);
      glint.push(0.72 + 0.28 * hash(i, j, 3));
      // one land point in thirty glitters in the light
      spark.push(isLand && hash(i, j, 11) > 0.966 ? 1 : 0);
    }
  }
  return {
    pos: new Float32Array(pos),
    land: new Uint8Array(land),
    glint: new Float32Array(glint),
    spark: new Uint8Array(spark),
    count: land.length,
  };
}

function easeOut(t: number): number {
  const c = Math.min(1, Math.max(0, t));
  return 1 - Math.pow(1 - c, 3);
}

export default class JtPlanet {
  #box: HTMLElement;
  #aura: HTMLCanvasElement;
  #back: HTMLCanvasElement;
  #canvas: HTMLCanvasElement;
  #front: HTMLCanvasElement;
  #ctx: CanvasRenderingContext2D;
  #halo = document.createElement("canvas");
  #dots: Dots | null = null;
  #dotsRadius = 0;
  #px = new Float32Array(0);
  #py = new Float32Array(0);
  #ps = new Float32Array(0);
  #pb = new Uint8Array(0);
  #order = new Uint32Array(0);
  #counts = new Uint32Array(STEPS * 2);
  #starts = new Uint32Array(STEPS * 2);
  #fills: string[] = [];
  #ink: Rgb = { r: 0, g: 0, b: 0 };
  #paperRgb: Rgb = { r: 255, g: 255, b: 255 };
  #paper = "";
  #onDark = true;
  #colors = "";
  #width = 0;
  #height = 0;
  #ratio = 1;
  #cx = 0;
  #cy = 0;
  #r = 0;
  #lightX = -0.65;
  #lightY = 0.55;
  #lightZ = 0.52;
  #glow = 1;
  #auraLevel = -1;
  #still: boolean;
  #visible = true;
  #frame: number | null = null;
  #timer: ReturnType<typeof setTimeout> | null = null;
  #last = 0;
  #time = 0;
  #introAt: number;
  #spin = 1.2;
  #orbitTime = 0;
  #boost = 0;
  #boostTo = 0;
  #pulse = 0;
  #pointX = 0;
  #pointY = 0;
  #aimX = 0;
  #aimY = 0;
  #held = false;
  #drift = 0;
  #throw = 0;
  #lastDrag = 0;
  #pings: number[] = [];
  #nightLights: number;
  #sinceCheck = 0;
  #poll: ReturnType<typeof setInterval> | null = null;
  #resizer: ResizeObserver;
  #watcher: IntersectionObserver;
  #darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

  #run = () => {
    const go =
      !this.#still && this.#visible && !document.hidden && this.#width > 0;
    // what it's doing, for anyone checking: turning, still or paused
    this.#box.dataset.jtPlanet = this.#still
      ? "still"
      : go
        ? "running"
        : "paused";
    if (go && this.#frame === null && this.#timer === null) {
      this.#last = performance.now();
      this.#frame = requestAnimationFrame(this.#tick);
    } else if (!go) {
      this.#stop();
    }
  };

  #tick = (now: number) => {
    this.#frame = null;
    const elapsed = now - this.#last;
    // smooth while it's held, coasting or pinging; otherwise 24 a second
    if (elapsed >= (this.#busy() ? HAND_FRAME_MS : FRAME_MS) - 2) {
      this.#last = now;
      this.#step(Math.min(0.1, elapsed / 1000));
      this.#draw();
      this.#sinceCheck += elapsed;
      if (this.#sinceCheck > 1500) {
        this.#sinceCheck = 0;
        this.#recolor();
      }
    }
    // busy, the screen's next frame; otherwise a timer until just before
    // the next is due, then the screen's frame after it
    const wait = this.#last + FRAME_MS - 2 - WAKE_EARLY_MS - performance.now();
    if (this.#busy() || wait <= 0) {
      this.#frame = requestAnimationFrame(this.#tick);
    } else {
      this.#timer = setTimeout(() => {
        this.#timer = null;
        this.#frame = requestAnimationFrame(this.#tick);
      }, wait);
    }
  };

  #recolor = () => {
    if (this.#readColors()) {
      this.#build();
      this.#draw();
    }
  };

  constructor(box: HTMLElement, options: PlanetOptions) {
    this.#box = box;
    const layer = (name: string) =>
      box.querySelector(`canvas[data-layer="${name}"]`) as HTMLCanvasElement;
    this.#aura = layer("aura");
    this.#back = layer("back");
    this.#canvas = layer("dots");
    this.#front = layer("front");
    this.#ctx = this.#canvas.getContext("2d") as CanvasRenderingContext2D;
    this.#still = options.still;
    this.#introAt = options.intro && !options.still ? 0 : -1e9;
    // night owls (10pm to 5am where the reader is) see more lights on the
    // night side
    const hour = new Date().getHours();
    this.#nightLights = hour >= 22 || hour < 5 ? 0.95 : 0.985;

    this.#resizer = new ResizeObserver(() => this.#layout());
    this.#resizer.observe(box);
    this.#watcher = new IntersectionObserver(([entry]) => {
      this.#visible = entry.isIntersecting;
      this.#run();
    });
    this.#watcher.observe(box);
    document.addEventListener("visibilitychange", this.#run);
    this.#darkQuery.addEventListener("change", this.#recolor);
    if (this.#still) {
      // a still frame still follows a switch between light and dark
      this.#poll = setInterval(this.#recolor, 1500);
    }
    this.#layout();
  }

  // Search has focus: the atmosphere brightens and the globe turns faster
  boost(on: boolean) {
    this.#boostTo = on ? 1 : 0;
    if (this.#still) {
      this.#boost = this.#boostTo;
      this.#draw();
    }
  }

  // A key typed in the search: a short flare of the atmosphere
  pulse() {
    this.#pulse = 1;
  }

  // The pointer over the hero, -1…1 across and down: the globe turns
  // towards it a little
  point(x: number, y: number) {
    this.#aimX = x;
    this.#aimY = y;
  }

  // Whether a point on the page (client coordinates) is on the globe
  hit(x: number, y: number): boolean {
    if (!this.#width) {
      return false;
    }
    const box = this.#box.getBoundingClientRect();
    const scale = box.width / this.#width;
    const dx = x - (box.left + this.#cx * scale);
    const dy = y - (box.top + this.#cy * scale);
    const r = this.#r * scale;
    return dx * dx + dy * dy <= r * r;
  }

  // Held: it stops coasting and turns only by hand
  grab() {
    this.#held = true;
    this.#drift = 0;
    this.#throw = 0;
    this.#lastDrag = performance.now();
    this.#wake();
  }

  // Dragged across by dx (CSS pixels): the surface under the pointer
  // follows it
  drag(dx: number) {
    const box = this.#box.getBoundingClientRect();
    const r = this.#width ? (this.#r / this.#width) * box.width : 0;
    if (!r) {
      return;
    }
    const turn = dx / r;
    this.#spin += turn;
    const now = performance.now();
    const dt = Math.max(4, now - this.#lastDrag) / 1000;
    this.#lastDrag = now;
    // how fast it's being turned, smoothed, for the throw
    this.#throw = this.#throw * 0.5 + (turn / dt) * 0.5;
    if (this.#still) {
      this.#draw();
    }
  }

  // Let go: it coasts at the speed it was thrown, slowing back to its own
  // pace (a hand that stopped before letting go doesn't throw it)
  release() {
    this.#held = false;
    const resting = performance.now() - this.#lastDrag > 120;
    this.#drift =
      this.#still || resting ? 0 : Math.max(-14, Math.min(14, this.#throw));
  }

  // Tapped: a ping rings out, the atmosphere flares and the satellites
  // hurry
  ping() {
    if (this.#still) {
      return;
    }
    this.#pings.push(this.#time);
    this.#pulse = 1.6;
    this.#wake();
  }

  // Sent spinning (the meteor shower), radians a second
  whirl(speed: number) {
    if (!this.#still) {
      this.#drift = speed;
      this.#wake();
    }
  }

  destroy() {
    this.#stop();
    this.#resizer.disconnect();
    this.#watcher.disconnect();
    document.removeEventListener("visibilitychange", this.#run);
    this.#darkQuery.removeEventListener("change", this.#recolor);
    if (this.#poll) {
      clearInterval(this.#poll);
    }
  }

  #stop() {
    if (this.#frame !== null) {
      cancelAnimationFrame(this.#frame);
      this.#frame = null;
    }
    if (this.#timer !== null) {
      clearTimeout(this.#timer);
      this.#timer = null;
    }
  }

  // Held, coasting or pinging: drawn on every frame it can be
  #busy(): boolean {
    return this.#held || Math.abs(this.#drift) > 0.3 || this.#pings.length > 0;
  }

  // Just made busy: on the screen's next frame, not after the timer
  #wake() {
    if (this.#timer !== null) {
      clearTimeout(this.#timer);
      this.#timer = null;
      this.#frame = requestAnimationFrame(this.#tick);
    }
  }

  #step(dt: number) {
    this.#time += dt;
    const intro = this.#time - this.#introAt;
    // spun up on arrival, settling to its own pace over a couple of seconds
    const settle = 1 + 7 * Math.exp(-Math.max(0, intro) / 0.9);
    this.#boost += (this.#boostTo - this.#boost) * Math.min(1, dt * 4);
    this.#pulse *= Math.exp(-dt * 3);
    if (!this.#held) {
      this.#spin +=
        dt * SPIN * settle * (1 + 3 * this.#boost) + this.#drift * dt;
    }
    this.#drift *= Math.exp(-dt / 1.4);
    this.#orbitTime += dt * (1 + 1.5 * this.#boost + 2.5 * this.#pulse);
    this.#pointX += (this.#aimX - this.#pointX) * Math.min(1, dt * 2.5);
    this.#pointY += (this.#aimY - this.#pointY) * Math.min(1, dt * 2.5);
  }

  // Ink (the text colour), paper (the hero's background) and how strongly
  // the atmosphere glows; true if any changed since the last read
  #readColors(): boolean {
    const style = getComputedStyle(this.#box);
    const ink = style.color;
    const glow = style.getPropertyValue("--jt-planet-glow");
    const hero = this.#box.closest(".jt-hero") || this.#box;
    const paper = getComputedStyle(hero).backgroundColor;
    const key = `${ink}|${paper}|${glow}`;
    if (key === this.#colors) {
      return false;
    }
    this.#colors = key;
    this.#paper = paper;
    this.#glow = parseFloat(glow) || 1;
    const rgb = (color: string): Rgb => {
      const m = color.match(/[\d.]+/g) || ["0", "0", "0"];
      return { r: +m[0], g: +m[1], b: +m[2] };
    };
    const light = ({ r, g, b }: Rgb) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
    this.#ink = rgb(ink);
    this.#paperRgb = rgb(paper);
    // light ink on dark paper (dark palettes) or dark ink on light paper
    this.#onDark = light(this.#ink) > light(this.#paperRgb);
    this.#fills = [];
    for (let i = 0; i < STEPS; i++) {
      this.#fills.push(this.#rgba((i + 0.5) / STEPS));
    }
    return true;
  }

  #rgba(alpha: number, color: Rgb = this.#ink): string {
    const { r, g, b } = color;
    return `rgba(${r}, ${g}, ${b}, ${Math.max(0, Math.min(1, alpha))})`;
  }

  #layout() {
    const width = this.#box.clientWidth;
    const height = this.#box.clientHeight;
    if (!width || !height) {
      this.#width = 0;
      this.#run();
      return;
    }
    // a small or modest device: fewer pixels, sparser dots
    const modest = width < 420 || (navigator.hardwareConcurrency || 8) <= 4;
    this.#ratio = Math.min(window.devicePixelRatio || 1, modest ? 1.5 : 2);
    this.#width = Math.round(width * this.#ratio);
    this.#height = Math.round(height * this.#ratio);
    for (const canvas of [this.#aura, this.#back, this.#front]) {
      canvas.width = this.#width;
      canvas.height = this.#height;
    }
    // the moving dots at no more than 1.5 pixels a point, drawn in the same
    // coordinates as the rest through a scale
    const scale = Math.min(1, 1.5 / this.#ratio);
    this.#canvas.width = Math.round(this.#width * scale);
    this.#canvas.height = Math.round(this.#height * scale);
    this.#ctx.setTransform(scale, 0, 0, scale, 0, 0);

    const style = getComputedStyle(this.#box);
    const fraction = (name: string, fallback: number) => {
      const value = parseFloat(style.getPropertyValue(name));
      return Number.isFinite(value) ? value : fallback;
    };
    this.#cx = fraction("--jt-planet-x", 0.5) * this.#width;
    this.#cy = fraction("--jt-planet-y", 0.5) * this.#width;
    this.#r = fraction("--jt-planet-r", 0.3) * this.#width;

    // lit from the copy's side: the left, or the right in a right-to-left
    // interface (Hebrew), where the globe sits on the left
    this.#lightX = style.direction === "rtl" ? 0.65 : -0.65;

    // about 7px between dots, fewer on a modest device; rebuilt only when
    // the globe's size really changes
    if (!this.#dots || Math.abs(this.#r - this.#dotsRadius) > this.#r * 0.15) {
      const gap = (modest ? 8.5 : 7) * this.#ratio;
      this.#dots = makeDots(Math.max(gap / this.#r, 0.016));
      this.#dotsRadius = this.#r;
      const n = this.#dots.count;
      this.#px = new Float32Array(n);
      this.#py = new Float32Array(n);
      this.#ps = new Float32Array(n);
      this.#pb = new Uint8Array(n);
      this.#order = new Uint32Array(n);
    }

    this.#colors = "";
    this.#readColors();
    this.#build();
    this.#draw();
    this.#run();
  }

  #build() {
    const r = this.#r;
    const cx = this.#cx;
    const cy = this.#cy;
    const lx = this.#lightX;
    const ly = this.#lightY;
    const glow = this.#glow;
    const context = (canvas: HTMLCanvasElement) => {
      const ctx = canvas.getContext("2d") as CanvasRenderingContext2D;
      ctx.clearRect(0, 0, this.#width, this.#height);
      return ctx;
    };

    // the atmosphere, at full strength: its canvas's opacity sets how much
    // of it shows. Each glow fades out before the canvas's nearest edge, or
    // the edge shows as a line in the sky.
    const reach = (x: number, y: number, want: number) =>
      Math.min(want, x, y, this.#width - x, this.#height - y);
    const aura = context(this.#aura);
    let g = aura.createRadialGradient(
      cx,
      cy,
      r * 0.96,
      cx,
      cy,
      Math.max(r, reach(cx, cy, r * 1.55))
    );
    g.addColorStop(0, this.#rgba(0.4 * glow));
    g.addColorStop(0.18, this.#rgba(0.15 * glow));
    g.addColorStop(0.5, this.#rgba(0.045 * glow));
    g.addColorStop(1, this.#rgba(0));
    aura.fillStyle = g;
    aura.fillRect(0, 0, this.#width, this.#height);
    const bx = cx + lx * r * 0.9;
    const by = cy - ly * r * 0.9;
    g = aura.createRadialGradient(bx, by, 0, bx, by, reach(bx, by, r * 1.4));
    g.addColorStop(0, this.#rgba(0.18 * glow));
    g.addColorStop(1, this.#rgba(0));
    aura.fillStyle = g;
    aura.fillRect(0, 0, this.#width, this.#height);

    // the far side of the orbits, then the disc that hides it
    const back = context(this.#back);
    back.lineWidth = Math.max(1, this.#ratio * 0.75);
    for (const orbit of ORBITS) {
      back.setLineDash(orbit.dash ? [2 * this.#ratio, 5 * this.#ratio] : []);
      back.strokeStyle = this.#rgba(orbit.dash ? 0.16 : 0.13);
      back.beginPath();
      back.ellipse(cx, cy, orbit.rx * r, orbit.ry * r, orbit.lean, 0, TAU);
      back.stroke();
    }
    back.setLineDash([]);
    back.fillStyle = this.#paper;
    back.beginPath();
    back.arc(cx, cy, r, 0, TAU);
    back.fill();
    if (this.#onDark) {
      // in the dark, the lit side catches the light
      const sx = cx + lx * r * 0.5;
      const sy = cy - ly * r * 0.5;
      g = back.createRadialGradient(sx, sy, 0, sx, sy, r * 1.3);
      g.addColorStop(0, this.#rgba(0.11));
      g.addColorStop(1, this.#rgba(0));
    } else {
      // on paper, the night side falls into shade
      const nx = cx - lx * r * 0.75;
      const ny = cy + ly * r * 0.75;
      g = back.createRadialGradient(nx, ny, 0, nx, ny, r * 1.75);
      g.addColorStop(0, this.#rgba(0.17));
      g.addColorStop(0.55, this.#rgba(0.06));
      g.addColorStop(1, this.#rgba(0.015));
    }
    back.fillStyle = g;
    back.fill();

    // the near side of the orbits, a crescent of light inside the lit limb,
    // and the rim
    const front = context(this.#front);
    front.lineWidth = Math.max(1, this.#ratio * 0.9);
    for (const orbit of ORBITS) {
      front.setLineDash(orbit.dash ? [2 * this.#ratio, 5 * this.#ratio] : []);
      front.strokeStyle = this.#rgba(orbit.dash ? 0.22 : 0.3);
      front.beginPath();
      front.ellipse(cx, cy, orbit.rx * r, orbit.ry * r, orbit.lean, 0, Math.PI);
      front.stroke();
    }
    front.setLineDash([]);
    front.save();
    front.beginPath();
    front.arc(cx, cy, r, 0, TAU);
    front.clip();
    const qx = cx + lx * r * 1.3;
    const qy = cy - ly * r * 1.3;
    g = front.createRadialGradient(qx, qy, r * 0.62, qx, qy, r * 1.45);
    g.addColorStop(0, this.#rgba(0.2));
    g.addColorStop(1, this.#rgba(0));
    front.fillStyle = g;
    front.fillRect(0, 0, this.#width, this.#height);
    front.restore();
    const rim = front.createLinearGradient(
      cx + lx * r,
      cy - ly * r,
      cx - lx * r,
      cy + ly * r
    );
    rim.addColorStop(0, this.#rgba(0.95));
    rim.addColorStop(0.28, this.#rgba(0.22));
    rim.addColorStop(0.55, this.#rgba(0));
    front.strokeStyle = rim;
    front.lineWidth = Math.max(1.2, r * 0.014);
    // the rim glows (a blurred stroke under the sharp one)
    front.save();
    front.shadowColor = this.#rgba(this.#onDark ? 0.9 : 0.45);
    front.shadowBlur = r * 0.09;
    front.beginPath();
    front.arc(cx, cy, r, 0, TAU);
    front.stroke();
    front.restore();
    front.beginPath();
    front.arc(cx, cy, r, 0, TAU);
    front.stroke();

    // a gloss on the lit side: the light's own reflection, in the ink on a
    // dark palette and in the paper on a light one
    front.save();
    front.beginPath();
    front.arc(cx, cy, r, 0, TAU);
    front.clip();
    const tint = this.#onDark ? this.#ink : this.#paperRgb;
    const peak = this.#onDark ? 0.24 : 0.75;
    const hx = cx + lx * r * 0.46;
    const hy = cy - ly * r * 0.46;
    g = front.createRadialGradient(hx, hy, 0, hx, hy, r * 0.46);
    g.addColorStop(0, this.#rgba(peak, tint));
    g.addColorStop(0.3, this.#rgba(peak * 0.4, tint));
    g.addColorStop(1, this.#rgba(0, tint));
    front.fillStyle = g;
    front.fillRect(0, 0, this.#width, this.#height);
    front.restore();

    // a satellite: a point of light with a halo and a four-pointed glint
    const size = Math.round(36 * this.#ratio);
    this.#halo.width = size;
    this.#halo.height = size;
    const halo = this.#halo.getContext("2d") as CanvasRenderingContext2D;
    const c = size / 2;
    g = halo.createRadialGradient(c, c, 0, c, c, c * 0.55);
    g.addColorStop(0, this.#rgba(1));
    g.addColorStop(0.15, this.#rgba(0.9));
    g.addColorStop(0.38, this.#rgba(0.2));
    g.addColorStop(1, this.#rgba(0));
    halo.fillStyle = g;
    halo.fillRect(0, 0, size, size);
    const line = Math.max(1, this.#ratio * 0.8);
    for (const across of [true, false]) {
      const flare = across
        ? halo.createLinearGradient(0, c, size, c)
        : halo.createLinearGradient(c, 0, c, size);
      flare.addColorStop(0, this.#rgba(0));
      flare.addColorStop(0.5, this.#rgba(0.85));
      flare.addColorStop(1, this.#rgba(0));
      halo.fillStyle = flare;
      if (across) {
        halo.fillRect(0, c - line / 2, size, line);
      } else {
        halo.fillRect(c - line / 2, 0, line, size);
      }
    }
    this.#auraLevel = -1;
  }

  #draw() {
    if (!this.#width || !this.#dots) {
      return;
    }
    const intro = this.#time - this.#introAt;
    const level =
      easeOut(intro / 2.2) * (0.6 + 0.3 * this.#boost + 0.2 * this.#pulse);
    // only touch the style when the atmosphere visibly changes
    if (Math.abs(level - this.#auraLevel) > 0.01) {
      this.#auraLevel = level;
      this.#aura.style.opacity = Math.min(1, level).toFixed(3);
    }
    this.#ctx.clearRect(0, 0, this.#width, this.#height);
    this.#drawDots(easeOut((intro - 0.25) / 1.4));
    this.#drawSatellites(easeOut((intro - 0.9) / 1.2));
    this.#drawPings();
  }

  #drawDots(level: number) {
    const dots = this.#dots as Dots;
    const ctx = this.#ctx;
    const r = this.#r;
    const cx = this.#cx;
    const cy = this.#cy;
    const spin = this.#spin + this.#pointX * 0.4;
    const tilt = TILT + this.#pointY * 0.12;
    const cosA = Math.cos(spin);
    const sinA = Math.sin(spin);
    const cosT = Math.cos(tilt);
    const sinT = Math.sin(tilt);
    const cosR = Math.cos(ROLL);
    const sinR = Math.sin(ROLL);
    const lx = this.#lightX;
    const ly = this.#lightY;
    const lz = this.#lightZ;
    const base = Math.max(this.#ratio, r * 0.0105);
    const counts = this.#counts;
    counts.fill(0);
    const pos = dots.pos;
    let n = 0;

    for (let i = 0; i < dots.count; i++) {
      const bx = pos[i * 3];
      const by = pos[i * 3 + 1];
      const bz = pos[i * 3 + 2];
      const x1 = bx * cosA + bz * sinA;
      const z1 = bz * cosA - bx * sinA;
      const y2 = by * cosT - z1 * sinT;
      const z = by * sinT + z1 * cosT;
      if (z <= 0) {
        continue;
      }
      const x = x1 * cosR - y2 * sinR;
      const y = x1 * sinR + y2 * cosR;
      const sx = cx + x * r;
      const sy = cy - y * r;
      if (sx < -4 || sy < -4 || sx > this.#width + 4 || sy > this.#height + 4) {
        continue;
      }
      const lit = Math.max(0, x * lx + y * ly + z * lz);
      const limb = 0.3 + 0.7 * z;
      const land = dots.land[i] === 1;
      let alpha;
      if (land) {
        // the night side keeps a few lights on
        alpha =
          lit < 0.08 && dots.glint[i] > this.#nightLights
            ? 0.8 * limb
            : (0.08 + 0.92 * Math.pow(lit, 0.8)) * limb * dots.glint[i];
      } else {
        alpha = (0.05 + 0.3 * lit) * limb;
      }
      let grow = 1;
      if (dots.spark[i] === 1 && lit > 0.3) {
        // glittering in the light, each on its own beat
        const beat = 0.5 + 0.5 * Math.sin(this.#time * 2.2 + i * 1.7);
        alpha = Math.min(1, alpha + 0.55 * beat * lit);
        grow = 1 + 0.9 * beat;
      }
      alpha *= level;
      if (alpha < 0.02) {
        continue;
      }
      const step = Math.min(STEPS - 1, Math.floor(alpha * STEPS));
      const bucket = (land ? STEPS : 0) + step;
      this.#px[n] = sx;
      this.#py[n] = sy;
      this.#ps[n] = base * (land ? 1 : 0.5) * (0.55 + 0.45 * z) * grow;
      this.#pb[n] = bucket;
      counts[bucket]++;
      n++;
    }

    // order the dots by batch, then draw each batch as one path
    let offset = 0;
    for (let b = 0; b < counts.length; b++) {
      this.#starts[b] = offset;
      offset += counts[b];
    }
    const next = this.#starts.slice();
    for (let i = 0; i < n; i++) {
      this.#order[next[this.#pb[i]]++] = i;
    }
    for (let b = 0; b < counts.length; b++) {
      if (!counts[b]) {
        continue;
      }
      ctx.fillStyle = this.#fills[b % STEPS];
      ctx.beginPath();
      const end = this.#starts[b] + counts[b];
      for (let k = this.#starts[b]; k < end; k++) {
        const i = this.#order[k];
        const s = this.#ps[i];
        ctx.rect(this.#px[i] - s / 2, this.#py[i] - s / 2, s, s);
      }
      ctx.fill();
    }
  }

  // Satellites and their trails; on the far side of the globe a point is
  // hidden behind the disc, and dimmer beside it
  #drawSatellites(level: number) {
    if (level <= 0) {
      return;
    }
    const ctx = this.#ctx;
    const r = this.#r;
    const cx = this.#cx;
    const cy = this.#cy;
    const hidden = (x: number, y: number, near: boolean) =>
      !near && (x - cx) ** 2 + (y - cy) ** 2 < r * r;
    for (const satellite of SATELLITES) {
      const orbit = ORBITS[satellite.orbit];
      const cos = Math.cos(orbit.lean);
      const sin = Math.sin(orbit.lean);
      const at = (a: number) => {
        const ex = Math.cos(a) * orbit.rx * r;
        const ey = Math.sin(a) * orbit.ry * r;
        return [cx + ex * cos - ey * sin, cy + ex * sin + ey * cos];
      };
      const a = satellite.phase + this.#orbitTime * satellite.speed;
      const near = Math.sin(a) > 0;
      const dim = near ? 1 : 0.5;
      for (let k = 1; k <= 6; k++) {
        const [x, y] = at(a - k * 0.045);
        if (hidden(x, y, near)) {
          continue;
        }
        ctx.fillStyle = this.#rgba((0.45 - k * 0.07) * level * dim);
        const size = Math.max(1, this.#ratio * (1.4 - k * 0.15));
        ctx.fillRect(x - size / 2, y - size / 2, size, size);
      }
      const [x, y] = at(a);
      if (hidden(x, y, near)) {
        continue;
      }
      const twinkle = 0.85 + 0.15 * Math.sin(this.#time * 3 + satellite.phase);
      const size =
        this.#halo.width * (near ? 1 : 0.6) * twinkle * (1 + 0.3 * this.#pulse);
      ctx.globalAlpha = level * dim;
      ctx.drawImage(this.#halo, x - size / 2, y - size / 2, size, size);
      ctx.globalAlpha = 1;
    }
  }

  // A ping's two rings, running out from the rim and fading
  #drawPings() {
    if (!this.#pings.length) {
      return;
    }
    this.#pings = this.#pings.filter(
      (at) => this.#time - at < PING_S + PING_LAG
    );
    const ctx = this.#ctx;
    ctx.lineWidth = Math.max(1, this.#ratio);
    for (const at of this.#pings) {
      for (const lag of [0, PING_LAG]) {
        const t = (this.#time - at - lag) / PING_S;
        if (t <= 0 || t >= 1) {
          continue;
        }
        ctx.strokeStyle = this.#rgba(0.55 * (1 - t));
        ctx.beginPath();
        ctx.arc(
          this.#cx,
          this.#cy,
          this.#r * (1.02 + 0.6 * easeOut(t)),
          0,
          TAU
        );
        ctx.stroke();
      }
    }
  }
}
