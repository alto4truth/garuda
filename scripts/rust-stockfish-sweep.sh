#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish.sh"
GAMES="${1:-4}"
PLIES="${2:-20}"
MOVETIME_MS="${3:-15}"

if [[ ! -x "$RUNNER" ]]; then
  echo "missing runner at $RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"
if [[ ! -x "$ROOT_DIR/target/debug/garuda-chess" ]]; then
  cargo build --bin garuda-chess
fi

for depth in 2 3 4; do
  for quiescence in 4 6; do
    echo "=== depth=$depth quiescence=$quiescence games=$GAMES plies=$PLIES movetime_ms=$MOVETIME_MS ==="
    "$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$depth" "$quiescence"
    echo
  done
done
