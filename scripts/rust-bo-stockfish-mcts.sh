#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_CMD="${ENGINE_CMD:-$ROOT_DIR/scripts/stockfish-js-uci.sh}"
BINARY="$ROOT_DIR/target/release/garuda-chess"
GAMES="${1:-10}"
PLIES="${2:-0}"
MOVETIME_MS="${3:-50}"
SIMULATIONS="${4:-64}"
CPUCT="${5:-1.35}"
VECTOR_FILE="${6:-}"
OPENINGS_FILE="${7:-${OPENINGS_FILE:-$ROOT_DIR/data/rust-stockfish-openings.fen}}"

cd "$ROOT_DIR"
cargo build --release --bin garuda-chess >/dev/null

if [[ -n "$VECTOR_FILE" ]]; then
  exec "$BINARY" bo-uci-mcts-vector \
    "$ENGINE_CMD" "$VECTOR_FILE" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
fi

exec "$BINARY" bo-uci-mcts \
  "$ENGINE_CMD" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
