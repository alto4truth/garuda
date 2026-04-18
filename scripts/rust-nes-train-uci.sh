#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_CMD="$ROOT_DIR/scripts/stockfish-js-uci.sh"
BINARY="$ROOT_DIR/target/release/garuda-chess"
OPENINGS_FILE="$ROOT_DIR/data/rust-stockfish-openings.fen"
OUTPUT_VECTOR="${1:-$ROOT_DIR/rust-nes-uci.vec}"
INPUT_VECTOR="${2:-/tmp/garuda-model.vec}"
GENERATIONS="${3:-4}"
POPULATION_SIZE="${4:-4}"
SIGMA="${5:-0.02}"
LEARNING_RATE="${6:-0.01}"
SEED="${7:-7}"
GAMES="${8:-2}"
PLIES="${9:-12}"
MOVETIME_MS="${10:-10}"
SIMULATIONS="${11:-16}"
CPUCT="${12:-1.35}"

cd "$ROOT_DIR"
cargo build --release --bin garuda-chess >/dev/null

if [[ ! -f "$INPUT_VECTOR" ]]; then
  "$BINARY" model-vector > "$INPUT_VECTOR"
fi

exec "$BINARY" nes-train-uci \
  "$ENGINE_CMD" "$OUTPUT_VECTOR" "$INPUT_VECTOR" \
  "$GENERATIONS" "$POPULATION_SIZE" "$SIGMA" "$LEARNING_RATE" "$SEED" \
  "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
