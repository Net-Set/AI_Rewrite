const providerSelect = document.getElementById("provider");
const geminiKeyInput = document.getElementById("geminiKey");
const openaiKeyInput = document.getElementById("openaiKey");
const anthropicKeyInput = document.getElementById("anthropicKey");
const status = document.getElementById("status");

const DEFAULT_MODELS = {
  gemini: "gemini-3.1-flash-lite",
  openai: "gpt-4o-mini",
  anthropic: "claude-sonnet-4-6",
};

function setStatus(text, color) {
  status.textContent = text;
  status.style.color = color;
}

chrome.storage.local.get(["provider", "apiKeys"], (data) => {
  providerSelect.value = data.provider || "gemini";
  const keys = data.apiKeys || {};
  geminiKeyInput.value = keys.gemini || "";
  openaiKeyInput.value = keys.openai || "";
  anthropicKeyInput.value = keys.anthropic || "";
});

document.getElementById("save").addEventListener("click", async () => {
  const provider = providerSelect.value;
  const apiKeys = {
    gemini: geminiKeyInput.value.trim(),
    openai: openaiKeyInput.value.trim(),
    anthropic: anthropicKeyInput.value.trim(),
  };

  if (!apiKeys[provider]) {
    setStatus("⚠ Enter a key for the selected provider first.", "#e0a030");
    return;
  }

  // Preserve any previously-saved model overrides (there's no UI for these — advanced
  // users can set them directly via chrome://extensions → this extension → storage,
  // or they simply stay at the defaults).
  const { models: existingModels } = await chrome.storage.local.get(["models"]);
  const models = { ...DEFAULT_MODELS, ...existingModels };

  chrome.storage.local.set({ provider, apiKeys, models }, () => {
    if (chrome.runtime.lastError) {
      setStatus("⚠ Couldn't save: " + chrome.runtime.lastError.message, "#e0524a");
      return;
    }
    setStatus("✓ Saved", "#7cd992");
    setTimeout(() => { setStatus("", ""); }, 2000);
  });
});
