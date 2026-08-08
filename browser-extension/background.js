// ---- Fixed rewrite modes (shown as context-menu items) ----
const MODES = [
  { id: "fix-grammar", title: "✏️ Fix Grammar & Spelling", prompt: "Fix all grammar, spelling, and punctuation errors in the following text. Keep the meaning, tone, and length as close to the original as possible. Return ONLY the corrected text with no preamble, no quotes, no explanation." },
  { id: "improve", title: "✨ Improve Writing", prompt: "Improve the clarity, flow, and word choice of the following text while keeping the original meaning and approximate length. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "formal", title: "👔 Make Formal / Professional", prompt: "Rewrite the following text in a formal, professional tone suitable for business communication. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "casual", title: "😊 Make Casual / Friendly", prompt: "Rewrite the following text in a casual, friendly, conversational tone. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "shorten", title: "✂️ Make Shorter", prompt: "Rewrite the following text to be significantly shorter and more concise, while keeping the key meaning. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
];

const CUSTOM_MODE_ID = "custom-instruction";

// ---- AI providers ----
// To add a new provider: add an entry here, write a call<Provider>() function with the
// same (apiKey, model, instruction, text) -> Promise<string> shape, and add a case to
// callProvider()'s switch. Also add the corresponding host_permissions entry in manifest.json.
const PROVIDERS = {
  gemini:    { label: "Google Gemini",     defaultModel: "gemini-3.1-flash-lite" },
  openai:    { label: "OpenAI (ChatGPT)",  defaultModel: "gpt-4o-mini" },
  anthropic: { label: "Anthropic Claude",  defaultModel: "claude-sonnet-4-6" },
};

// Guard against pathologically large selections (e.g. an accidental whole-page select) —
// fail fast with a clear message instead of burning a slow/likely-to-fail API call.
const MAX_SELECTION_CHARS = 50000;

// ---- Context menu setup ----
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "ai-rewrite-root",
    title: "AI Rewrite",
    contexts: ["editable", "selection"]
  });
  for (const mode of MODES) {
    chrome.contextMenus.create({
      id: mode.id,
      parentId: "ai-rewrite-root",
      title: mode.title,
      contexts: ["editable", "selection"]
    });
  }
  chrome.contextMenus.create({
    id: "custom-sep",
    parentId: "ai-rewrite-root",
    type: "separator",
    contexts: ["editable", "selection"]
  });
  chrome.contextMenus.create({
    id: CUSTOM_MODE_ID,
    parentId: "ai-rewrite-root",
    title: "✍️ Custom Instruction...",
    contexts: ["editable", "selection"]
  });

  migrateLegacyStorage();
});

// Service workers can be re-woken without onInstalled firing (e.g. browser restart) —
// make sure a stale legacy key still gets migrated in that case too.
chrome.runtime.onStartup.addListener(() => {
  migrateLegacyStorage();
});

// ---- One-time migration: pre-1.1 single-provider chrome.storage.sync -> multi-provider
// chrome.storage.local. Local storage is used for keys going forward so they never leave
// this device via Google's sync infrastructure (see README "Privacy & security").
async function migrateLegacyStorage() {
  try {
    const local = await chrome.storage.local.get(["apiKeys"]);
    if (local.apiKeys && local.apiKeys.gemini) return; // already migrated

    const legacy = await chrome.storage.sync.get(["apiKey", "model"]);
    if (!legacy.apiKey) return;

    const apiKeys = { gemini: legacy.apiKey, openai: "", anthropic: "" };
    const models = {
      gemini: legacy.model || PROVIDERS.gemini.defaultModel,
      openai: PROVIDERS.openai.defaultModel,
      anthropic: PROVIDERS.anthropic.defaultModel,
    };
    await chrome.storage.local.set({ provider: "gemini", apiKeys, models });
    await chrome.storage.sync.remove(["apiKey", "model"]);
    console.log("[AI Rewrite] Migrated settings from sync storage to local storage.");
  } catch (err) {
    console.error("[AI Rewrite] Storage migration failed:", err);
  }
}

// ---- Handle context-menu click ----
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab || tab.id === undefined) return;

  const selection = info.selectionText || "";
  if (!selection.trim()) {
    safeSendMessage(tab.id, { type: "REWRITE_ERROR", error: "No text selected — highlight some text first." });
    return;
  }
  if (selection.length > MAX_SELECTION_CHARS) {
    safeSendMessage(tab.id, {
      type: "REWRITE_ERROR",
      error: `Selection too long (${selection.length.toLocaleString()} characters, limit ${MAX_SELECTION_CHARS.toLocaleString()}). Select a smaller chunk of text.`
    });
    return;
  }

  let instruction, label;

  if (info.menuItemId === CUSTOM_MODE_ID) {
    const typed = await promptForCustomInstruction(tab.id);
    if (typed === null) return; // cancelled or unavailable on this page
    if (!typed.trim()) return;  // submitted blank
    instruction = `${typed.trim()}. Return ONLY the rewritten text with no preamble, no quotes, no explanation.`;
    label = "Applying custom instruction";
  } else {
    const mode = MODES.find(m => m.id === info.menuItemId);
    if (!mode) return;
    instruction = mode.prompt;
    label = mode.title.replace(/^\S+\s/, ""); // strip the leading emoji for the toast text
  }

  safeSendMessage(tab.id, { type: "REWRITE_START", label });

  try {
    const rewritten = await callProvider(instruction, selection);
    safeSendMessage(tab.id, { type: "REWRITE_RESULT", text: rewritten });
  } catch (err) {
    safeSendMessage(tab.id, { type: "REWRITE_ERROR", error: err.message });
  }
});

// Uses the page's own window.prompt() (a native browser dialog, unaffected by the page's
// CSP) to ask for a free-form instruction. Returns null if the page can't be scripted
// (chrome://, the Chrome Web Store, PDF viewer, etc.) or the user cancelled.
async function promptForCustomInstruction(tabId) {
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId },
      func: () => window.prompt("Custom instruction for the selected text (e.g. \"translate to Spanish\"):", "")
    });
    return results?.[0]?.result ?? null;
  } catch (err) {
    safeSendMessage(tabId, { type: "REWRITE_ERROR", error: "Can't run on this page (browser-internal pages, the Web Store, and PDF viewer aren't scriptable)." });
    return null;
  }
}

// chrome.tabs.sendMessage rejects if there's no content script listening (chrome://
// pages, the PDF viewer, a page loaded before the extension was installed, etc.) —
// that's expected on some pages, not a bug, so swallow it rather than let it surface
// as an unhandled promise rejection in the service worker's console.
function safeSendMessage(tabId, message) {
  chrome.tabs.sendMessage(tabId, message).catch(() => {});
}

// ---- Provider dispatch ----
async function callProvider(instruction, text) {
  const { provider = "gemini", apiKeys = {}, models = {} } = await chrome.storage.local.get(["provider", "apiKeys", "models"]);
  const providerInfo = PROVIDERS[provider];
  if (!providerInfo) {
    throw new Error(`Unknown provider "${provider}" in settings. Reopen the extension popup and re-save.`);
  }

  const apiKey = (apiKeys && apiKeys[provider]) || "";
  if (!apiKey) {
    throw new Error(`No ${providerInfo.label} API key set. Click the extension icon to add one.`);
  }
  const model = (models && models[provider]) || providerInfo.defaultModel;

  switch (provider) {
    case "gemini":    return callGemini(apiKey, model, instruction, text);
    case "openai":    return callOpenAI(apiKey, model, instruction, text);
    case "anthropic": return callAnthropic(apiKey, model, instruction, text);
    default:
      // Unreachable given the PROVIDERS lookup above, but keeps the switch exhaustive.
      throw new Error(`Unknown provider "${provider}".`);
  }
}

// Every provider nests the actual human-readable explanation at error.message in its JSON
// error body — pull that out instead of showing the raw JSON blob.
function extractErrorMessage(bodyText) {
  try {
    return JSON.parse(bodyText)?.error?.message || null;
  } catch {
    return null;
  }
}

function friendlyApiError(providerLabel, status, bodyText) {
  const message = extractErrorMessage(bodyText);

  let base;
  if (status === 429) {
    base = `${providerLabel} rate limit hit — wait a moment and try again.`;
  } else if (status === 401 || status === 403) {
    base = `${providerLabel} rejected the API key (HTTP ${status}). Check it in the extension popup.`;
  } else if (message && /credit|balance|quota|billing/i.test(message)) {
    base = `${providerLabel} account issue (HTTP ${status}) — this is a billing/quota problem on your account, not a bug.`;
  } else {
    base = `${providerLabel} API error ${status}.`;
  }

  return message ? `${base} ${message}` : `${base} ${bodyText.slice(0, 300)}`;
}

// fetch() with a hard timeout — without this, a stalled connection leaves the user's
// selection frozen in "Rewriting…" indefinitely with no feedback.
async function fetchWithTimeout(url, options, timeoutMs = 30000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } catch (err) {
    if (err.name === "AbortError") throw new Error("Request timed out — the API took too long to respond.");
    throw new Error("Network error — could not reach the API. Check your internet connection.");
  } finally {
    clearTimeout(timer);
  }
}

// ---- Google Gemini (free tier, no credit card required) ----
async function callGemini(apiKey, model, instruction, text) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey
    },
    body: JSON.stringify({
      contents: [
        { role: "user", parts: [{ text: `${instruction}\n\nTEXT:\n${text}` }] }
      ]
    })
  });

  if (!response.ok) {
    const errBody = await response.text();
    throw new Error(friendlyApiError("Gemini", response.status, errBody));
  }

  const data = await response.json();
  const resultText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!resultText) {
    const blockReason = data?.promptFeedback?.blockReason;
    throw new Error(blockReason ? `Gemini blocked the response (${blockReason}).` : "No text returned from Gemini.");
  }
  return resultText.trim();
}

// ---- OpenAI (Chat Completions) ----
async function callOpenAI(apiKey, model, instruction, text) {
  const url = "https://api.openai.com/v1/chat/completions";

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: `${instruction}\n\nTEXT:\n${text}` }]
    })
  });

  if (!response.ok) {
    const errBody = await response.text();
    throw new Error(friendlyApiError("OpenAI", response.status, errBody));
  }

  const data = await response.json();
  const resultText = data?.choices?.[0]?.message?.content;
  if (!resultText) throw new Error("No text returned from OpenAI.");
  return resultText.trim();
}

// ---- Anthropic Claude (Messages API) ----
async function callAnthropic(apiKey, model, instruction, text) {
  const url = "https://api.anthropic.com/v1/messages";

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      // Anthropic requires this explicit opt-in header for calls made directly from a
      // browser context (rather than a server), which is exactly what this extension does.
      "anthropic-dangerous-direct-browser-access": "true"
    },
    body: JSON.stringify({
      model,
      max_tokens: 4096,
      messages: [{ role: "user", content: `${instruction}\n\nTEXT:\n${text}` }]
    })
  });

  if (!response.ok) {
    const errBody = await response.text();
    throw new Error(friendlyApiError("Anthropic", response.status, errBody));
  }

  const data = await response.json();
  const resultText = data?.content?.[0]?.text;
  if (!resultText) throw new Error("No text returned from Anthropic.");
  return resultText.trim();
}
