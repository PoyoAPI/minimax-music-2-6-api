# MiniMax Music 2.6 cURL Examples

Use these requests to submit a generation task and poll for the result.

## Instrumental Music Draft

```bash
export POYO_API_KEY="YOUR_POYO_API_KEY_HERE"
export POYO_BASE_URL="https://api.poyo.ai"

curl --fail-with-body --request POST \
  --url "$POYO_BASE_URL/api/generate/submit" \
  --header "Authorization: Bearer $POYO_API_KEY" \
  --header "Content-Type: application/json" \
  --data '{
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
}'
```

Store the returned `data.task_id`, then poll:

```bash
curl --fail-with-body --request GET \
  --url "$POYO_BASE_URL/api/generate/status/task-unified-example" \
  --header "Authorization: Bearer $POYO_API_KEY"
```

## Lyric-Guided Draft

```json
{
  "model": "minimax-music-2.6",
  "input": {
    "prompt": "An energetic indie pop jingle for a short product launch clip.",
    "lyrics": "Build it faster, make it clear\nTurn the idea into something real",
    "lyrics_optimizer": true,
    "is_instrumental": false,
    "audio_setting": {
      "sample_rate": 44100,
      "bitrate": 128000,
      "format": "mp3"
    }
  }
}
```

## Expected Submit Response

```json
{
  "code": 200,
  "data": {
    "task_id": "task-unified-example",
    "status": "not_started",
    "created_time": "2026-07-04T08:00:00"
  }
}
```

## Expected Status Response

```json
{
  "code": 200,
  "data": {
    "task_id": "task-unified-example",
    "status": "finished",
    "progress": 100,
    "files": [
      {
        "file_url": "https://storage.poyo.ai/generated/output-file",
        "file_type": "media"
      }
    ],
    "error_message": null
  }
}
```
