import type { Config } from "prettier";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const config: Config = require("@discourse/lint-configs/prettier");

export default config;
