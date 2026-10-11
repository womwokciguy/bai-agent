# bai-agent

Hermes Agent + Telegram bot, siap deploy di Railway.

## Deploy ke Railway

1. Deploy repo ini dari GitHub.
2. Tambah Volume dan mount ke `/opt/data`. Sesi, memory, config, dan provider tambahan disimpan di sini; tanpa volume semuanya reset tiap redeploy.
3. Isi Variables:

| Variable | Wajib | Isi |
| --- | --- | --- |
| `OPENAI_API_KEY` | ya | API key endpoint LLM |
| `OPENAI_BASE_URL` | ya | Base URL endpoint, contoh `https://host/v1` |
| `HERMES_MODEL` | ya | Nama model persis seperti di endpoint, contoh `DeepSeek-V4-Pro` |
| `TELEGRAM_BOT_TOKEN` | ya | Token dari @BotFather |
| `TELEGRAM_ALLOWED_USERS` | disarankan | User ID Telegram yang boleh pakai bot |
| `TELEGRAM_HOME_CHANNEL` | disarankan | User ID kamu sendiri |
| `HERMES_API_MODE` | tidak | Default `chat_completions` |
| `HERMES_DASHBOARD` | tidak | `1` untuk WebUI (butuh basic auth) |
| `ANTHROPIC_API_KEY` | tidak | Kalau diisi, dipakai provider Anthropic menggantikan endpoint OpenAI-compatible |

## Model dan provider

- Variables di atas menentukan model/provider awal. `bootstrap.sh` menuliskannya ke config Hermes saat boot pertama dan setiap kali nilainya berubah.
- Di luar itu, pilihan `/model` di Telegram dipertahankan setelah restart.
  - Kunci permanen: `touch /opt/data/.keep_model` (atau set `HERMES_SYNC_MODEL=0`).
  - Paksa sinkron ulang dari Variables: `rm /opt/data/.model_env_sig`, lalu restart.
- Tambah provider tanpa redeploy (lewat agent dengan tool terminal, atau shell):

```
hermes config set FREEMODEL_API_KEY <key>
hermes config set providers.fm-api.api https://api.freemodel.dev/v1
hermes config set providers.fm-api.key_env FREEMODEL_API_KEY
hermes config set providers.fm-api.transport chat_completions
```

  Lalu pilih lewat `/model` atau ketik `/model custom:fm-api:<nama-model>`.
- Cadangan kalau `hermes config set` menolak: `/opt/hermes/.venv/bin/python /opt/add_provider.py --help`.

## Jangan commit rahasia

API key, token bot, dan token Railway hanya boleh ada di Variables Railway atau di volume, tidak di repo.

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
