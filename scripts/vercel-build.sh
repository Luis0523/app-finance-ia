#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.0"
FLUTTER_ROOT="${HOME}/flutter-sdk"

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  echo "Descargando Flutter ${FLUTTER_VERSION}..."
  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C "${HOME}"
  rm -f /tmp/flutter.tar.xz
  mv "${HOME}/flutter" "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"

# El SDK descargado se extrae con otro UID y Vercel ejecuta como root.
git config --global --add safe.directory "${FLUTTER_ROOT}"
git config --global --add safe.directory "${FLUTTER_ROOT}/*"

flutter config --no-analytics --enable-web
flutter pub get

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Faltan SUPABASE_URL o SUPABASE_ANON_KEY en las variables de Vercel."
  exit 1
fi

cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
LLM_API_KEY=proxy
LLM_BASE_URL=/api/llm
LLM_MODEL=${LLM_MODEL:-deepseek-chat}
LLM_PROVIDER=${LLM_PROVIDER:-deepseek}
EOF

flutter build web --release
