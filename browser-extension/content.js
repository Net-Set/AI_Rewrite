// Tracks the last known selection so we can replace it after the async API call
// (the browser selection can be lost once the context menu opens on some sites).
let lastSelection = null;

document.addEventListener("selectionchange", () => {
  const sel = window.getSelection();
  const active = document.activeElement;

  if (active && (active.tagName === "TEXTAREA" || active.tagName === "INPUT")) {
    const start = active.selectionStart;
    const end = active.selectionEnd;
    if (start !== end) {
      lastSelection = { type: "input", el: active, start, end };
    }
  } else if (sel && sel.rangeCount > 0 && !sel.isCollapsed) {
    lastSelection = { type: "range", range: sel.getRangeAt(0).cloneRange() };
  }
});

function showToast(message, isError = false) {
  if (!document.body) return; // no DOM to attach to (e.g. about:blank) — nothing we can do
  let toast = document.getElementById("__ai_rewrite_toast__");
  if (!toast) {
    toast = document.createElement("div");
    toast.id = "__ai_rewrite_toast__";
    toast.style.cssText = `
      position: fixed; bottom: 20px; right: 20px; z-index: 2147483647;
      background: ${isError ? "#c0392b" : "#2d2d2d"}; color: white;
      padding: 10px 16px; border-radius: 8px; font-family: sans-serif;
      font-size: 13px; box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      max-width: 320px; white-space: pre-wrap;
    `;
    document.body.appendChild(toast);
  }
  toast.style.background = isError ? "#c0392b" : "#2d2d2d";
  toast.textContent = message;
  toast.style.display = "block";
  clearTimeout(toast._hideTimer);
  // Errors stay on screen much longer (8s) so they're actually readable;
  // success/status messages clear quickly.
  toast._hideTimer = setTimeout(() => { toast.style.display = "none"; }, isError ? 8000 : 3000);
  if (isError) console.error("[AI Rewrite]", message);
}

function replaceSelectionText(newText) {
  if (!lastSelection) {
    showToast("Couldn't find the original selection — copied to clipboard instead:\n" + newText, true);
    navigator.clipboard.writeText(newText).catch(() => {});
    return;
  }

  try {
    if (lastSelection.type === "input") {
      const { el, start, end } = lastSelection;
      if (!el.isConnected) throw new Error("field no longer on the page");
      const before = el.value.slice(0, start);
      const after = el.value.slice(end);
      el.value = before + newText + after;
      el.selectionStart = start;
      el.selectionEnd = start + newText.length;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.focus();
    } else if (lastSelection.type === "range") {
      const range = lastSelection.range;
      if (!range.startContainer.isConnected) throw new Error("original text no longer on the page");

      range.deleteContents();
      const textNode = document.createTextNode(newText);
      range.insertNode(textNode);

      // Move the caret to just after the inserted text, so the user can keep typing
      // naturally instead of landing back at the start of what was just replaced.
      const sel = window.getSelection();
      const newRange = document.createRange();
      newRange.setStartAfter(textNode);
      newRange.collapse(true);
      sel.removeAllRanges();
      sel.addRange(newRange);

      // Fire input event for React/contenteditable-based apps (Gmail, Docs, etc.)
      const editableRoot = textNode.parentElement;
      editableRoot?.dispatchEvent(new Event("input", { bubbles: true }));
    }
  } catch (err) {
    // The page may have re-rendered (SPA navigation, React re-render, etc.) between the
    // click and the API response, detaching the node we captured. Fail safely rather
    // than throwing into the void — the user still gets their rewritten text.
    showToast("Couldn't replace the text in place (page changed) — copied to clipboard instead:\n" + newText, true);
    navigator.clipboard.writeText(newText).catch(() => {});
  }

  lastSelection = null;
}

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "REWRITE_START") {
    showToast((msg.label || "Rewriting") + "…");
  } else if (msg.type === "REWRITE_RESULT") {
    replaceSelectionText(msg.text);
    showToast("✓ Rewritten");
  } else if (msg.type === "REWRITE_ERROR") {
    showToast("Error: " + msg.error, true);
  }
});
