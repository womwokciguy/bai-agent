# bai-agent

Hermes Agent + Telegram bot, siap deploy di Railway.

## Deploy ke Railway

1. Deploy repo ini dari GitHub.
2. Tambah Volume dan mount ke `/opt/data` (supaya sesi, memory, dan config tidak hilang tiap redeploy).
3. Isi Variables:

| Variable | Wajib | Isi |
| --- | --- | --- |
| `OPENAI_API_KEY` | ya | API key endpoint LLM |
| `OPENAI_BASE_URL` | ya | Base URL endpoint, contoh `https://host/v1` |
| `HERMES_MODEL` | ya | Nama model persis seperti di endpoint, contoh `DeepSeek-V4-Pro` |
| `TELEGRAM_BOT_TOKEN` | ya | Token dari @BotFather |
| `TELEGRAM_ALLOWED_USERS` | disarankan | User ID Telegram yang boleh pakai bot |
| `TELEGRAM_HOME_CHANNEL` | disarankan | User ID kamu sendiri |
| `HERMES_API_MODE` | tidak | Default `chat_completions`. Ganti hanya kalau endpoint mendukung mode lain |
| `HERMES_DASHBOARD` | tidak | `1` untuk WebUI (butuh basic auth) |

`bootstrap.sh` menyinkronkan config Hermes dengan variable di atas setiap kali container start.

## Jangan commit rahasia

API key, token bot, dan token Railway hanya boleh ada di Variables Railway, tidak di repo.

## Docker lokal

```
docker build -t bai-agent .
docker run --rm \
  -e OPENAI_API_KEY=... \
  -e OPENAI_BASE_URL=https://host/v1 \
  -e HERMES_MODEL=DeepSeek-V4-Pro \
  -e TELEGRAM_BOT_TOKEN=... \
  -v hermes_data:/opt/data \
  bai-agent
```
