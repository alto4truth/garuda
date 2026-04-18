#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_CMD="$ROOT_DIR/scripts/stockfish-js-uci.sh"
GAMES="${1:-10}"
PLIES="${2:-80}"
MOVETIME_MS="${3:-50}"
GARUDA_DEPTH="${4:-2}"
GARUDA_QUIESCENCE="${5:-4}"

cd "$ROOT_DIR"
exec cargo run --bin garuda-chess -- bo-uci "$ENGINE_CMD" "$GAMES" "$PLIES" "$MOVETIME_MS" "$GARUDA_DEPTH" "$GARUDA_QUIESCENCE"
