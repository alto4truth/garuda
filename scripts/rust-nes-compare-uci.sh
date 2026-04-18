#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVALUATOR="$ROOT_DIR/scripts/rust-nes-eval-uci.sh"
BO_RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish-mcts.sh"
VECTOR_A="${1:-/tmp/garuda-model.vec}"
VECTOR_B="${2:-$ROOT_DIR/rust-nes-best.vec}"
GAMES="${3:-2}"
PLIES="${4:-12}"
MOVETIME_MS="${5:-10}"
SIMULATIONS="${6:-16}"
CPUCT="${7:-1.35}"
BO_GAMES="${8:-2}"
BO_PLIES="${9:-4}"
BO_MOVETIME_MS="${10:-10}"
OPENINGS_FILE="${11:-$ROOT_DIR/data/rust-stockfish-openings.fen}"

if [[ ! -x "$EVALUATOR" ]]; then
  echo "missing evaluator at $EVALUATOR" >&2
  exit 1
fi

if [[ ! -x "$BO_RUNNER" ]]; then
  echo "missing bo runner at $BO_RUNNER" >&2
  exit 1
fi

echo "=== config ==="
echo "vector_a=$VECTOR_A"
echo "vector_b=$VECTOR_B"
echo "games=$GAMES plies=$PLIES movetime_ms=$MOVETIME_MS simulations=$SIMULATIONS cpuct=$CPUCT"
echo "bo_games=$BO_GAMES bo_plies=$BO_PLIES bo_movetime_ms=$BO_MOVETIME_MS"
echo "openings_file=$OPENINGS_FILE"
echo

echo "=== eval:a ==="
"$EVALUATOR" "$VECTOR_A" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
echo

echo "=== bo:a ==="
"$BO_RUNNER" "$BO_GAMES" "$BO_PLIES" "$BO_MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$VECTOR_A" "$OPENINGS_FILE"
echo

echo "=== eval:b ==="
"$EVALUATOR" "$VECTOR_B" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"
echo

echo "=== bo:b ==="
"$BO_RUNNER" "$BO_GAMES" "$BO_PLIES" "$BO_MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$VECTOR_B" "$OPENINGS_FILE"
