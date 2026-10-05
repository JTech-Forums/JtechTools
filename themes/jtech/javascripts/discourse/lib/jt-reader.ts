import { tracked } from "@glimmer/tracking";

// Text sizes and column widths reader mode steps through.
export const READER_SIZES = [1, 1.125, 1.25, 1.375, 1.5];
export const READER_WIDTHS = ["34rem", "40rem", "46rem", "54rem"];

const KEY = "jt-reader-mode";

interface Stored {
  size?: number;
  width?: number;
  serif?: boolean;
}

// Reader mode (setting reader_mode): on for the rest of the visit once
// turned on, like the component it replaces; its text size, width and type
// are kept per browser. It works through classes and custom properties on
// <html> (stylesheets/jt-reader.scss), which only act on topic pages.
class ReaderMode {
  @tracked on = false;
  @tracked size = 0;
  @tracked width = 1;
  @tracked serif = false;

  constructor() {
    try {
      const stored = JSON.parse(localStorage.getItem(KEY) || "{}") as Stored;
      this.size = clamp(stored.size ?? 0, READER_SIZES.length);
      this.width = clamp(stored.width ?? 1, READER_WIDTHS.length);
      this.serif = !!stored.serif;
    } catch {
      // private windows and blocked storage: the defaults
    }
  }

  toggle() {
    this.on = !this.on;
    this.apply();
  }

  step(what: "size" | "width", by: number) {
    const count = what === "size" ? READER_SIZES.length : READER_WIDTHS.length;
    this[what] = clamp(this[what] + by, count);
    this.apply();
    this.save();
  }

  toggleSerif() {
    this.serif = !this.serif;
    this.apply();
    this.save();
  }

  apply() {
    const html = document.documentElement;
    html.classList.toggle("jt-reader", this.on);
    html.classList.toggle("jt-reader--serif", this.on && this.serif);
    html.style.setProperty(
      "--jt-reader-scale",
      String(READER_SIZES[this.size])
    );
    html.style.setProperty("--jt-reader-width", READER_WIDTHS[this.width]);
  }

  save() {
    try {
      localStorage.setItem(
        KEY,
        JSON.stringify({
          size: this.size,
          width: this.width,
          serif: this.serif,
        })
      );
    } catch {
      // not kept, still applied
    }
  }
}

function clamp(value: number, count: number) {
  return Math.max(0, Math.min(count - 1, Math.round(value)));
}

export const readerMode = new ReaderMode();
