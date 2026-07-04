import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import express from "express";

function loadEnv() {
  for (const envPath of [resolve(process.cwd(), ".env"), resolve(process.cwd(), "../../.env")]) {
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

function createTimeoutSignal(timeoutMs) {
  if (typeof AbortSignal !== "undefined" && typeof AbortSignal.timeout === "function") {
    return AbortSignal.timeout(timeoutMs);
  }

  const controller = new AbortController();
  setTimeout(() => controller.abort(), timeoutMs);
  return controller.signal;
}

loadEnv();

const app = express();
const port = Number(process.env.PORT || 3000);
const baseUrl = process.env.POYO_BASE_URL || "https://api.poyo.ai";
const apiKey = process.env.POYO_API_KEY;
const allowUnlistedTaskIds = process.env.POYO_ALLOW_UNLISTED_TASK_IDS === "true";
const knownTaskIds = new Set(
  (process.env.POYO_KNOWN_TASK_IDS || "")
    .split(",")
    .map((taskId) => taskId.trim())
    .filter(Boolean),
);
const lastStatusByTaskId = new Map();

app.use(express.json({ limit: "2mb" }));

function isKnownTaskId(taskId) {
  return knownTaskIds.has(taskId) || allowUnlistedTaskIds;
}

async function reconcileTaskStatus(taskId, timeoutMs = 5000) {
  if (!apiKey || apiKey === "YOUR_POYO_API_KEY_HERE") {
    return { task_id: taskId, reconciled: false, reason: "POYO_API_KEY is not set" };
  }

  try {
    const response = await fetch(`${baseUrl}/api/generate/status/${taskId}`, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
      signal: createTimeoutSignal(timeoutMs),
    });
    const body = await response.json().catch(() => ({}));
    return {
      task_id: taskId,
      reconciled: response.ok,
      http_status: response.status,
      status: body?.data?.status,
    };
  } catch (error) {
    return {
      task_id: taskId,
      reconciled: false,
      reason: error?.name === "AbortError" ? "status request timed out" : error?.message || "unknown error",
    };
  }
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/api/poyo/webhook", (req, res) => {
  const event = req.body || {};
  const taskId = event?.data?.task_id || event?.task_id;

  if (!taskId) {
    return res.status(400).json({ ok: false, error: "Missing task_id" });
  }

  if (!isKnownTaskId(taskId)) {
    return res.status(202).json({ ok: true, ignored: true, reason: "Unknown task_id" });
  }

  const status = event?.data?.status || event?.status || "unknown";
  const dedupeKey = `${taskId}:${status}`;

  if (lastStatusByTaskId.get(taskId) === dedupeKey) {
    return res.json({ ok: true, duplicate: true });
  }

  lastStatusByTaskId.set(taskId, dedupeKey);

  console.log(
    JSON.stringify(
      {
        task_id: taskId,
        status,
        accepted: true,
      },
      null,
      2,
    ),
  );

  void reconcileTaskStatus(taskId).then((result) => {
    console.log(JSON.stringify({ task_id: taskId, reconciled: result }, null, 2));
  });

  return res.json({ ok: true });
});

app.listen(port, () => {
  console.log(`PoYo webhook receiver listening on port ${port}`);
});
