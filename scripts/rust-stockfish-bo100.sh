#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish.sh"
GAMES="${1:-100}"
PLIES="${2:-80}"
MOVETIME_MS="${3:-50}"
GARUDA_DEPTH="${4:-2}"
GARUDA_QUIESCENCE="${5:-4}"
LOG_FILE="${6:-$ROOT_DIR/rust-stockfish-bo100.log}"

if [[ ! -x "$RUNNER" ]]; then
  echo "missing runner at $RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"
{
  echo "=== rust-stockfish bo run ==="
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "games=$GAMES plies=$PLIES movetime_ms=$MOVETIME_MS depth=$GARUDA_DEPTH quiescence=$GARUDA_QUIESCENCE"
  "$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$GARUDA_DEPTH" "$GARUDA_QUIESCENCE"
} | tee "$LOG_FILE"
