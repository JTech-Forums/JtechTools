// Dates, counts and plurals, short enough for a 240-pixel-wide screen.

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

export function parseDate(
  value: string | number | Date | null | undefined
): Date | null {
  if (value === null || value === undefined || value === "") return null;
  if (value instanceof Date) return isNaN(value.getTime()) ? null : value;
  let d = new Date(value as string);
  if (isNaN(d.getTime()) && typeof value === "string") {
    // Old engines choke on fractional seconds / offsets in ISO strings.
    d = new Date(
      value
        .replace(/\.\d+/, "")
        .replace(/-/g, "/")
        .replace("T", " ")
        .replace(/Z$/, " UTC")
    );
  }
  return isNaN(d.getTime()) ? null : d;
}

export function timeAgo(
  value: string | number | Date | null | undefined,
  now = Date.now()
): string {
  const d = parseDate(value);
  if (!d) return "";
  const s = Math.max(0, Math.floor((now - d.getTime()) / 1000));
  if (s < 45) return "now";
  if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m";
  if (s < 86400) return Math.round(s / 3600) + "h";
  if (s < 86400 * 30) return Math.round(s / 86400) + "d";
  const nowDate = new Date(now);
  if (d.getFullYear() === nowDate.getFullYear())
    return MONTHS[d.getMonth()] + " " + d.getDate();
  return MONTHS[d.getMonth()] + " '" + String(d.getFullYear()).slice(2);
}

export function longDate(
  value: string | number | Date | null | undefined
): string {
  const d = parseDate(value);
  if (!d) return "";
  return MONTHS[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
}

export function dateTime(
  value: string | number | Date | null | undefined
): string {
  const d = parseDate(value);
  if (!d) return "";
  const h = d.getHours();
  const m = d.getMinutes();
  return (
    longDate(d) +
    " " +
    (h % 12 || 12) +
    ":" +
    (m < 10 ? "0" : "") +
    m +
    (h < 12 ? " AM" : " PM")
  );
}

export function count(n: number | null | undefined): string {
  const v = n || 0;
  if (v < 1000) return String(v);
  if (v < 10000)
    return (Math.round(v / 100) / 10).toString().replace(/\.0$/, "") + "k";
  if (v < 1000000) return Math.round(v / 1000) + "k";
  return (Math.round(v / 100000) / 10).toString().replace(/\.0$/, "") + "M";
}

export function plural(n: number, one: string, many?: string): string {
  return n + " " + (n === 1 ? one : many || one + "s");
}

export function truncate(text: string, max: number): string {
  const clean = String(text || "")
    .replace(/\s+/g, " ")
    .replace(/^\s+|\s+$/g, "");
  if (clean.length <= max) return clean;
  return clean.slice(0, max - 1).replace(/\s+\S*$/, "") + "…";
}
