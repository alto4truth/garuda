#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_JS="$ROOT_DIR/node_modules/stockfish/bin/stockfish-18-lite-single.js"

if [[ ! -f "$ENGINE_JS" ]]; then
  echo "missing Stockfish JS engine at $ENGINE_JS" >&2
  echo "run 'npm install' in $ROOT_DIR first" >&2
  exit 1
fi

exec node "$ENGINE_JS"
