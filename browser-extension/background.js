// ---- Context menu setup ----
const MODES = [
  { id: "fix-grammar", title: "✏️ Fix Grammar & Spelling", prompt: "Fix all grammar, spelling, and punctuation errors in the following text. Keep the meaning, tone, and length as close to the original as possible. Return ONLY the corrected text with no preamble, no quotes, no explanation." },
  { id: "improve", title: "✨ Improve Writing", prompt: "Improve the clarity, flow, and word choice of the following text while keeping the original meaning and approximate length. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "formal", title: "👔 Make Formal / Professional", prompt: "Rewrite the following text in a formal, professional tone suitable for business communication. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "casual", title: "😊 Make Casual / Friendly", prompt: "Rewrite the following text in a casual, friendly, conversational tone. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
  { id: "shorten", title: "✂️ Make Shorter", prompt: "Rewrite the following text to be significantly shorter and more concise, while keeping the key meaning. Return ONLY the rewritten text with no preamble, no quotes, no explanation." },
];

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
});

// ---- Handle click ----
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const mode = MODES.find(m => m.id === info.menuItemId);
  if (!mode || !info.selectionText) return;

  // Tell the content script to show a "working..." state
  chrome.tabs.sendMessage(tab.id, { type: "REWRITE_START" });

  try {
    const rewritten = await callClaude(mode.prompt, info.selectionText);
    chrome.tabs.sendMessage(tab.id, { type: "REWRITE_RESULT", text: rewritten });
  } catch (err) {
    chrome.tabs.sendMessage(tab.id, { type: "REWRITE_ERROR", error: err.message });
  }
});

// ---- Gemini API call (free tier, no credit card required) ----
async function callClaude(instruction, text) {
  const { apiKey, model } = await chrome.storage.sync.get(["apiKey", "model"]);
  if (!apiKey) {
    throw new Error("No API key set. Click the extension icon to add your free Gemini API key.");
  }

  const geminiModel = model || "gemini-3.1-flash-lite";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent`;

  const response = await fetch(url, {
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
    throw new Error(`API error ${response.status}: ${errBody.slice(0, 200)}`);
  }

  const data = await response.json();
  const resultText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!resultText) throw new Error("No text returned from API.");
  return resultText.trim();
}
