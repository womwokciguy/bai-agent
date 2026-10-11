#!/bin/bash
# Bootstrap Hermes untuk Railway.
# Semua setting dibaca dari Variables Railway. Jangan taruh key/token di repo.
#
# Dua mode, dipilih otomatis:
#   - ANTHROPIC_API_KEY terisi -> provider Anthropic (Claude API)
#   - selain itu               -> endpoint OpenAI-compatible (OPENAI_API_KEY + OPENAI_BASE_URL)
#
# Model/provider di config.yaml hanya ditulis dari Variables saat:
#   (a) boot pertama (belum ada catatan), atau
#   (b) nilai Variables (provider/base URL/model/api mode) berubah sejak boot terakhir.
# Selain itu pilihan /model di Telegram dibiarkan, jadi tidak ketimpa saat restart.
#   - Kunci permanen : touch /opt/data/.keep_model   (atau set HERMES_SYNC_MODEL=0)
#   - Paksa sinkron  : rm /opt/data/.model_env_sig

export HERMES_HOME="${HERMES_HOME:-/opt/data}"
mkdir -p "$HERMES_HOME"

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  MODE="anthropic"
  REQUIRED="ANTHROPIC_API_KEY TELEGRAM_BOT_TOKEN"
  DEFAULT_MODEL="claude-sonnet-5-5"
else
  MODE="custom"
  REQUIRED="OPENAI_API_KEY OPENAI_BASE_URL TELEGRAM_BOT_TOKEN"
  DEFAULT_MODEL="DeepSeek-V4-Pro"
fi

# 1. Variable wajib
missing=""
for v in $REQUIRED; do
  if [ -z "${!v}" ]; then
    missing="$missing $v"
  fi
done
if [ -n "$missing" ]; then
  echo "❌ Variable belum diisi di Railway:$missing"
  exit 1
fi

# 2. Model. Nilai kosong atau "0" dianggap belum diisi.
MODEL="${HERMES_MODEL:-}"
if [ -z "$MODEL" ] || [ "$MODEL" = "0" ]; then
  MODEL="$DEFAULT_MODEL"
  echo "⚠️  HERMES_MODEL kosong/0, pakai default: $MODEL"
fi
if [ "$MODE" = "anthropic" ] && [[ "$MODEL" != claude* ]]; then
  echo "⚠️  HERMES_MODEL '$MODEL' bukan model Claude, pakai default: $DEFAULT_MODEL"
  MODEL="$DEFAULT_MODEL"
fi
export HERMES_MODEL="$MODEL"

# 3. Nilai dari Variables
if [ "$MODE" = "anthropic" ]; then
  # Pastikan key/URL relay lama tidak ikut terbaca oleh Hermes
  unset OPENAI_API_KEY OPENAI_BASE_URL
  PROVIDER="anthropic"
  BASE_URL="https://api.anthropic.com"
  API_MODE="anthropic_messages"
else
  PROVIDER="custom"
  BASE_URL="$OPENAI_BASE_URL"
  # chat_completions paling aman untuk relay/endpoint pihak ketiga.
  # Ganti lewat variable HERMES_API_MODE kalau perlu.
  API_MODE="${HERMES_API_MODE:-chat_completions}"
fi

# 4. Putuskan perlu menulis ke config.yaml atau tidak
SIG_FILE="$HERMES_HOME/.model_env_sig"
SIG="$PROVIDER|$BASE_URL|$MODEL|$API_MODE"

if [ "${HERMES_SYNC_MODEL:-1}" = "0" ] || [ -f "$HERMES_HOME/.keep_model" ]; then
  SYNC=0
  echo "🔒 Dikunci (.keep_model / HERMES_SYNC_MODEL=0): model di config.yaml tidak ditimpa"
elif [ ! -f "$HERMES_HOME/config.yaml" ] || [ ! -f "$SIG_FILE" ]; then
  SYNC=1
  echo "🆕 Boot pertama (atau catatan hilang): menerapkan Variables ke config Hermes"
elif [ "$(cat "$SIG_FILE")" != "$SIG" ]; then
  SYNC=1
  echo "🔄 Variables berubah sejak boot terakhir: menerapkan ke config Hermes"
else
  SYNC=0
  echo "⏭️  Variables tidak berubah: pilihan /model yang tersimpan dipertahankan"
fi

# 5. Terapkan (hanya kalau SYNC=1)
FAILED=0
apply() {
  if hermes config set "$1" "$2" >/dev/null 2>&1; then
    echo "   ✓ $1"
  else
    echo "   ⚠️  gagal set $1 (cek nama setting di versi Hermes ini)"
    FAILED=1
  fi
}

if [ "$SYNC" = "1" ]; then
  echo "⚙️  Menerapkan config Hermes (mode: $MODE)..."
  apply model.provider "$PROVIDER"
  apply model.base_url "$BASE_URL"
  apply model.default "$MODEL"
  apply model.api_mode "$API_MODE"
  # Catat hanya kalau semua berhasil, supaya boot berikutnya mencoba lagi bila ada yang gagal
  if [ "$FAILED" = "0" ]; then
    printf '%s' "$SIG" > "$SIG_FILE"
  fi
  echo "📡 Base URL : $BASE_URL"
  echo "🤖 Model    : $MODEL"
  echo "🔌 API mode : $API_MODE"
else
  echo "ℹ️  Variables (tidak diterapkan): $PROVIDER | $BASE_URL | $MODEL | $API_MODE"
fi

echo "📄 Bagian model di $HERMES_HOME/config.yaml:"
grep -A8 '^model:' "$HERMES_HOME/config.yaml" 2>/dev/null || echo "   (config.yaml belum ada)"

exec hermes gateway run
