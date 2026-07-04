import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

function loadEnv() {
  for (const envPath of [resolve(process.cwd(), ".env"), resolve(process.cwd(), "../.env")]) {
    if (!existsSync(envPath)) continue;
    const content = readFileSync(envPath, "utf8");
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const index = trimmed.indexOf("=");
      if (index === -1) continue;
      const key = trimmed.slice(0, index).trim();
      const value = trimmed.slice(index + 1).trim();
      if (!process.env[key]) process.env[key] = value;
    }
  }
}

async function requestJson(url, options) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body = {};
  if (text) {
    try { body = JSON.parse(text); } catch { body = { raw: text }; }
  }
  const apiCode = Number(body?.code);
  const hasApiError = Number.isFinite(apiCode) && apiCode !== 0 && apiCode !== 200;
  if (!response.ok || hasApiError) {
    throw new Error(`PoYo request failed: ${JSON.stringify({ http_status: response.status, api_code: body?.code, body }, null, 2)}`);
  }
  return body;
}

loadEnv();
const apiKey = process.env.POYO_API_KEY;
const baseUrl = process.env.POYO_BASE_URL || "https://api.poyo.ai";

if (!apiKey || apiKey === "YOUR_POYO_API_KEY_HERE") {
  console.error("Set POYO_API_KEY in your environment or repo-root .env file.");
  process.exit(1);
}

const sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms));

async function pollTask({ taskId }) {
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const result = await requestJson(`${baseUrl}/api/generate/status/${taskId}`, {
      method: "GET",
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    const status = result.data?.status;
    console.log(`poll ${attempt}: ${status || "unknown"}`);
    if (status === "finished" || status === "failed") return result;
    await sleep(5000);
  }
  throw new Error(`Timed out waiting for task ${taskId}`);
}

const callbackUrl = process.env.POYO_CALLBACK_URL;
const payload = {
  "model": "minimax-music-2.6",
  "input": {
    "prompt": "A clean upbeat electronic background track for a product demo video, warm synths, light percussion, modern and optimistic.",
    "is_instrumental": true,
    "lyrics_optimizer": false,
    "audio_setting": {
      "sample_rate": 44100,
      "bitrate": 128000,
      "format": "mp3"
    }
  }
};
if (callbackUrl) payload.callback_url = callbackUrl;

const submitResult = await requestJson(`${baseUrl}/api/generate/submit`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(payload),
});

const taskId = submitResult.data?.task_id;
if (!taskId) {
  throw new Error(`Submit response did not include data.task_id: ${JSON.stringify(submitResult)}`);
}

console.log(`submitted task: ${taskId}`);
const finalResult = await pollTask({ taskId });
console.log(JSON.stringify(finalResult, null, 2));
