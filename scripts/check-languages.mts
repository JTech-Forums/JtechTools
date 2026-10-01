#!/usr/bin/env -S node --experimental-strip-types --no-warnings
// The repo is written in three languages: Ruby, TypeScript and SCSS
// (AGENTS.md). Fails on any tracked file in another language, except build
// output marked linguist-generated in .gitattributes. Data and docs (YAML,
// JSON, Markdown, images, fonts) aren't code and don't count.
//
//   pnpm lint:languages

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { basename, extname } from "node:path";

const CODE = new Set([".rb", ".rake", ".ts", ".gts", ".mts", ".scss"]);
const DATA = new Set([
  ".md",
  ".yml",
  ".yaml",
  ".json",
  ".txt",
  ".lock",
  ".png",
  ".jpg",
  ".svg",
  ".woff2",
]);
// Files without an extension that aren't code
const NAMED = new Set(["Gemfile", "LICENSE", "CODEOWNERS"]);

const git = (...args: string[]) =>
  execFileSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });

const files = git("ls-files", "-z").split("\0").filter(Boolean);

const generated = new Set(
  git("check-attr", "-z", "linguist-generated", "--", ...files)
    .split("\0")
    // path, attribute, value triples
    .reduce<string[][]>((rows, field, i) => {
      if (i % 3 === 0) {
        rows.push([]);
      }
      rows[rows.length - 1].push(field);
      return rows;
    }, [])
    .filter(([, , value]) => value === "set" || value === "true")
    .map(([path]) => path)
);

const problems: string[] = [];
for (const file of files) {
  if (generated.has(file)) {
    continue;
  }
  const name = basename(file);
  const ext = extname(name);
  if (CODE.has(ext) || DATA.has(ext)) {
    continue;
  }
  if (ext !== "") {
    problems.push(`${file}: not Ruby, TypeScript or SCSS`);
    continue;
  }
  // No extension: a script still has to be Ruby or TypeScript (Node);
  // anything else is a tool's settings file or the license.
  const firstLine = readFileSync(file, "utf8").split("\n", 1)[0];
  if (firstLine.startsWith("#!")) {
    if (!/\b(ruby|node)\b/.test(firstLine)) {
      problems.push(`${file}: script for ${firstLine.slice(2).trim()}`);
    }
  } else if (!NAMED.has(name) && !name.startsWith(".")) {
    problems.push(`${file}: not Ruby, TypeScript or SCSS`);
  }
}

if (problems.length) {
  console.error(
    "Only Ruby, TypeScript and SCSS belong in this repo (AGENTS.md):\n" +
      problems.map((p) => `  ${p}`).join("\n") +
      "\nRewrite it in one of those, or, if it's build output, mark it" +
      " linguist-generated in .gitattributes."
  );
  process.exit(1);
}
console.log(`${files.length} files: Ruby, TypeScript and SCSS only`);
