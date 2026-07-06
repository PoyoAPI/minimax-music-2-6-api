# MiniMax Music 2.6 API Examples for PoYo

[![Model page](https://img.shields.io/badge/Model%20page-minimax--music--2--6-84cc16)](https://poyo.ai/models/minimax-music-2-6)
[![API docs](https://img.shields.io/badge/API%20docs-docs.poyo.ai-22d3ee)](https://docs.poyo.ai/api-manual/music-series/minimax-music-2.6)
[![License: MIT](https://img.shields.io/badge/License-MIT-111827)](LICENSE)
[![Main examples](https://img.shields.io/badge/Main%20examples-PoyoAPI%2Fpoyo--examples-0f172a?logo=github)](https://github.com/PoyoAPI/poyo-examples)

Focused server-side examples for building music generation workflows with MiniMax Music 2.6 on PoYo.

MiniMax Music 2.6 is useful for creator tools that need background music drafts, short campaign audio, instrumental loops, or audio concepts before polishing.

[Try on PoYo](https://poyo.ai/models/minimax-music-2-6) | [Get API Key](https://poyo.ai/dashboard/api-key) | [Docs](https://docs.poyo.ai/api-manual/music-series/minimax-music-2.6) | [Pricing](https://poyo.ai/pricing) | [Main Examples](https://github.com/PoyoAPI/poyo-examples)

## What This Repo Covers

- Music generation with `minimax-music-2.6`
- Instrumental and lyric-guided drafts
- Audio output settings
- Polling and webhook handling for production music generation
- cURL and Node.js backend examples

## Quick Start

```bash
cp .env.example .env
export POYO_API_KEY="your-api-key"
```

Run the Node.js example:

```bash
cd node
npm start
```

Keep `POYO_API_KEY` on the server. Do not expose it in browser code, mobile apps, screenshots, or public logs.

## Production Pattern

- Keep `POYO_API_KEY` on the server
- Submit a generation task
- Store `data.task_id`
- Poll status while testing
- Use `callback_url` webhooks in production

## Models

This repo uses `minimax-music-2.6`.

## Examples

| Path | What it covers |
| --- | --- |
| [`curl/generate.md`](curl/generate.md) | Copy-paste API request. |
| [`node/`](node/) | Native Node.js backend example. |
| [`docs/prompt-examples.md`](docs/prompt-examples.md) | Practical prompts for product workflows and creative tests. |
| [`docs/production-notes.md`](docs/production-notes.md) | Security and reliability notes before launch. |
| [`webhooks/express-webhook/`](webhooks/express-webhook/) | Minimal Express receiver for PoYo callbacks. |

## Run Checks

```bash
make check
```

On Windows:

```powershell
./scripts/check.ps1
```

## License

MIT
