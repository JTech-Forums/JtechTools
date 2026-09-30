// espree ships no types; the build only needs parse().
declare module "espree" {
  export function parse(
    code: string,
    options: { ecmaVersion: number; sourceType: "script" | "module" }
  ): unknown;
}
