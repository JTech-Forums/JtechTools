// Stylesheet build. The sources use CSS custom properties for the themes;
// browsers older than Chrome 49 / Firefox 31 do not understand var(), so
// every declaration that uses one gets a plain fallback in front of it
// (resolved against the dark theme), and the light theme is repeated as
// plain rules inside `@supports not (--a: 0)` — a block only engines
// without custom properties apply.

import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import * as esbuild from "esbuild";
import postcss from "postcss";

type Vars = Record<string, string>;

const THEME_ROOT = ":root";
const THEME_LIGHT = "html.light";

function collectVars(rootNode: postcss.Root, selector: string): Vars {
  const vars: Vars = {};
  rootNode.walkRules((rule) => {
    if (rule.selector !== selector) return;
    if (rule.parent && rule.parent.type !== "root") return;
    rule.walkDecls((decl) => {
      if (decl.prop.startsWith("--")) vars[decl.prop] = decl.value;
    });
  });
  return vars;
}

// Resolves var(--x) / var(--x, fallback) against `vars`, recursively.
// Returns null if something cannot be resolved.
export function resolveVars(
  value: string,
  vars: Vars,
  depth = 0
): string | null {
  if (depth > 10) return null;
  let failed = false;
  const out = value.replace(
    /var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*(?:\([^()]*\)[^()]*)*))?\)/g,
    (_m, name: string, fallback?: string) => {
      const found =
        vars[name] ?? (fallback !== undefined ? fallback.trim() : undefined);
      if (found === undefined) {
        failed = true;
        return "";
      }
      const resolved = resolveVars(found, vars, depth + 1);
      if (resolved === null) {
        failed = true;
        return "";
      }
      return resolved;
    }
  );
  if (failed) return null;
  return out.includes("var(") ? resolveVars(out, vars, depth + 1) : out;
}

function insideKeyframes(node: postcss.Node): boolean {
  let parent = node.parent;
  while (parent && parent.type !== "root") {
    if (
      parent.type === "atrule" &&
      /keyframes$/.test((parent as postcss.AtRule).name)
    )
      return true;
    parent = parent.parent;
  }
  return false;
}

function lightSelector(selector: string): string {
  return selector
    .split(",")
    .map((part) => {
      const s = part.trim();
      if (s.startsWith("html")) return s.replace(/^html/, THEME_LIGHT);
      return `${THEME_LIGHT} ${s}`;
    })
    .join(",");
}

export function transformCss(source: string): string {
  const rootNode = postcss.parse(source);
  const dark = collectVars(rootNode, THEME_ROOT);
  const light = { ...dark, ...collectVars(rootNode, THEME_LIGHT) };

  const twins: string[] = [];

  rootNode.walkRules((rule) => {
    if (rule.selector === THEME_ROOT || rule.selector === THEME_LIGHT) return;
    if (insideKeyframes(rule)) return;

    const lightDecls: string[] = [];
    rule.walkDecls((decl) => {
      if (decl.prop.startsWith("--") || !decl.value.includes("var(")) return;
      const darkValue = resolveVars(decl.value, dark);
      if (darkValue !== null) {
        decl.cloneBefore({ value: darkValue });
      }
      const lightValue = resolveVars(decl.value, light);
      if (lightValue !== null && lightValue !== darkValue) {
        lightDecls.push(
          `${decl.prop}:${lightValue}${decl.important ? " !important" : ""}`
        );
      }
    });
    if (!lightDecls.length) return;

    let css = `${lightSelector(rule.selector)}{${lightDecls.join(";")}}`;
    let parent = rule.parent;
    while (parent && parent.type === "atrule") {
      const at = parent as postcss.AtRule;
      css = `@${at.name} ${at.params}{${css}}`;
      parent = parent.parent;
    }
    twins.push(css);
  });

  let out = rootNode.toString();
  if (twins.length) out += `\n@supports not (--a: 0){${twins.join("")}}\n`;
  return out;
}

export async function buildCss(dir: string): Promise<string> {
  const source = readdirSync(dir)
    .filter((name) => name.endsWith(".css"))
    .sort()
    .map((name) => readFileSync(join(dir, name), "utf8"))
    .join("\n");
  const transformed = transformCss(source);
  const minified = await esbuild.transform(transformed, {
    loader: "css",
    minify: true,
    // Low targets keep esbuild from rewriting anything into newer syntax.
    target: ["chrome30", "firefox30", "safari8"],
    legalComments: "none",
    charset: "ascii",
  });
  return minified.code;
}
