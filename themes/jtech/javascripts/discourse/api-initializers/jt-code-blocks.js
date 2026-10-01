import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";

// Code blocks whose author named a language (```bash) get a header showing it.
// Auto-detected blocks stay bare: highlight.js guesses (smali reads as
// "ruby"), and a wrong label is worse than none.
const SKIP = new Set(["auto", "nohighlight", "plaintext", "text", "txt"]);
const ALIASES = {
  js: "javascript",
  md: "markdown",
  ps1: "powershell",
  py: "python",
  sh: "shell",
  ts: "typescript",
  yml: "yaml",
};

export default apiInitializer((api) => {
  if (!settings.code_language_labels) {
    return;
  }

  api.decorateCookedElement(
    (element) => {
      for (const code of element.querySelectorAll("pre > code[class*='lang-']")) {
        const lang = code.className.match(/(?:^|\s)lang-([\w+#.-]+)/)?.[1];
        if (lang && !SKIP.has(lang.toLowerCase())) {
          code.parentElement.dataset.jtLang =
            ALIASES[lang.toLowerCase()] || lang.toLowerCase();
        }
      }
    },
    { id: "jt-code-blocks" }
  );
});
