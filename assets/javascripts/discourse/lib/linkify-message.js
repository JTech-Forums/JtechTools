import { htmlSafe } from "@ember/template";

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// Escapes a moderator-set message, turns http(s) URLs into links, keeps
// line breaks, and returns a trusted HTML string. Shared by the precheck
// confirmation dialog and the category prompt preview so both render a
// message the same way.
export function messageToHtml(text) {
  const linked = escapeHtml(text || "").replace(
    /(https?:\/\/[^\s<]+)/g,
    (url) =>
      `<a href="${url}" target="_blank" rel="noopener noreferrer">${url}</a>`
  );
  return htmlSafe(linked.replace(/\r?\n/g, "<br>"));
}
