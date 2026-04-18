#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish-mcts.sh"
GAMES="${1:-100}"
PLIES="${2:-0}"
MOVETIME_MS="${3:-50}"
SIMULATIONS="${4:-64}"
CPUCT="${5:-1.35}"
LOG_FILE="${6:-$ROOT_DIR/rust-stockfish-bo100-mcts.log}"
VECTOR_FILE="${7:-}"

if [[ ! -x "$RUNNER" ]]; then
  echo "missing runner at $RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"
{
  echo "=== rust-stockfish mcts bo run ==="
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "games=$GAMES max_plies=${PLIES:-0} movetime_ms=$MOVETIME_MS simulations=$SIMULATIONS cpuct=$CPUCT"
  if [[ -n "$VECTOR_FILE" ]]; then
    echo "vector_file=$VECTOR_FILE"
    "$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$VECTOR_FILE"
  else
    "$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT"
  fi
} | tee "$LOG_FILE"
