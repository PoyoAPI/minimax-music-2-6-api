# Production Notes

- Separate draft generation from final publishing review.
- Store task_id with prompt, lyrics, and audio settings.
- Use webhooks when music generation is part of an automated creator workflow.
- Store `data.task_id` immediately after submit.
- Use polling for local tests and `callback_url` webhooks in production.
- Handle `failed` status as a normal product state, not an unexpected crash.
- Keep `POYO_API_KEY` on the server.
- Do not log full prompts if they may contain user-private data.

## Security Checklist

- Never expose `POYO_API_KEY` in browser code, mobile apps, screenshots, or public logs.
- Use environment variables or a secret manager for API keys.
- Use allowlisted webhook endpoints when callbacks are enabled.
- Store request metadata separately from sensitive user content when possible.
