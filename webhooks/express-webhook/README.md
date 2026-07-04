# Express Webhook Receiver

Minimal receiver for PoYo task callbacks.

```bash
npm install
npm start
```

Environment:

```env
POYO_API_KEY=YOUR_POYO_API_KEY_HERE
POYO_BASE_URL=https://api.poyo.ai
POYO_KNOWN_TASK_IDS=task-unified-example
POYO_ALLOW_UNLISTED_TASK_IDS=false
```

Production notes:

- Store known task IDs in your database.
- Return 2xx quickly.
- Make duplicate callbacks safe.
- Reconcile important callbacks with the status endpoint.
- Do not log API keys or private prompts.
