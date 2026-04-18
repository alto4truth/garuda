#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_CMD="$ROOT_DIR/scripts/stockfish-js-uci.sh"
BINARY="$ROOT_DIR/target/release/garuda-chess"
OPENINGS_FILE="$ROOT_DIR/data/rust-stockfish-openings.fen"
VECTOR_FILE="${1:-/tmp/garuda-model.vec}"
GAMES="${2:-2}"
PLIES="${3:-12}"
MOVETIME_MS="${4:-10}"
SIMULATIONS="${5:-16}"
CPUCT="${6:-1.35}"

cd "$ROOT_DIR"
cargo build --release --bin garuda-chess >/dev/null

exec "$BINARY" nes-eval-uci \
  "$ENGINE_CMD" "$VECTOR_FILE" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
