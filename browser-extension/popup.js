const keyInput = document.getElementById("apiKey");
const modelSelect = document.getElementById("model");
const status = document.getElementById("status");

chrome.storage.sync.get(["apiKey", "model"], (data) => {
  if (data.apiKey) keyInput.value = data.apiKey;
  if (data.model) modelSelect.value = data.model;
});

document.getElementById("save").addEventListener("click", () => {
  const apiKey = keyInput.value.trim();
  const model = modelSelect.value;
  chrome.storage.sync.set({ apiKey, model }, () => {
    status.textContent = "✓ Saved";
    status.style.color = "#7cd992";
    setTimeout(() => { status.textContent = ""; }, 2000);
  });
});
