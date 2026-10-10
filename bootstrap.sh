#!/bin/bash
# Bootstrap Hermes untuk Railway.
# Semua setting dibaca dari Variables Railway. Jangan taruh key/token di repo.

export HERMES_HOME="${HERMES_HOME:-/opt/data}"
mkdir -p "$HERMES_HOME"

# 1. Variable wajib
missing=""
for v in OPENAI_API_KEY OPENAI_BASE_URL TELEGRAM_BOT_TOKEN; do
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
  MODEL="DeepSeek-V4-Pro"
  echo "⚠️  HERMES_MODEL kosong/0, pakai default: $MODEL"
fi
export HERMES_MODEL="$MODEL"

# 3. Mode API. chat_completions paling aman untuk relay/endpoint pihak ketiga.
#    Ganti lewat variable HERMES_API_MODE kalau perlu.
API_MODE="${HERMES_API_MODE:-chat_completions}"

# 4. Sinkronkan config Hermes dengan Variables Railway (aman dijalankan tiap boot)
apply() {
  if hermes config set "$1" "$2" >/dev/null 2>&1; then
    echo "   ✓ $1"
  else
    echo "   ⚠️  gagal set $1 (cek nama setting di versi Hermes ini)"
  fi
}

echo "⚙️  Menerapkan config Hermes..."
apply model.provider custom
apply model.base_url "$OPENAI_BASE_URL"
apply model.default "$MODEL"
apply model.api_mode "$API_MODE"

echo "📡 Base URL : $OPENAI_BASE_URL"
echo "🤖 Model    : $MODEL"
echo "🔌 API mode : $API_MODE"
echo "📄 Bagian model di $HERMES_HOME/config.yaml:"
grep -A8 '^model:' "$HERMES_HOME/config.yaml" 2>/dev/null || echo "   (config.yaml belum ada)"

exec hermes gateway run
