#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAINER="$ROOT_DIR/scripts/rust-nes-train-uci.sh"
EVALUATOR="$ROOT_DIR/scripts/rust-nes-eval-uci.sh"
BO_RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish-mcts.sh"
OUTPUT_VECTOR="${1:-$ROOT_DIR/rust-nes-cycle.vec}"
INPUT_VECTOR="${2:-}"
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
BO_GAMES="${13:-10}"
BO_PLIES="${14:-0}"
BO_MOVETIME_MS="${15:-20}"
OPENINGS_FILE="${16:-$ROOT_DIR/data/rust-stockfish-openings.fen}"
RUN_DIR="${17:-${OUTPUT_VECTOR}.run}"

if [[ ! -x "$TRAINER" ]]; then
  echo "missing trainer at $TRAINER" >&2
  exit 1
fi

if [[ ! -x "$EVALUATOR" ]]; then
  echo "missing evaluator at $EVALUATOR" >&2
  exit 1
fi

if [[ ! -x "$BO_RUNNER" ]]; then
  echo "missing bo runner at $BO_RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "=== config ==="
echo "output_vector=$OUTPUT_VECTOR"
echo "input_vector=${INPUT_VECTOR:-<default-model>}"
echo "generations=$GENERATIONS population_size=$POPULATION_SIZE sigma=$SIGMA learning_rate=$LEARNING_RATE seed=$SEED"
echo "train_games=$GAMES train_max_plies=$PLIES train_movetime_ms=$MOVETIME_MS simulations=$SIMULATIONS cpuct=$CPUCT"
echo "bo_games=$BO_GAMES bo_max_plies=$BO_PLIES bo_movetime_ms=$BO_MOVETIME_MS"
echo "openings_file=$OPENINGS_FILE"
echo "run_dir=$RUN_DIR"
echo

echo "=== train ==="
if [[ -n "$INPUT_VECTOR" ]]; then
  "$TRAINER" "$OUTPUT_VECTOR" "$INPUT_VECTOR" \
    "$GENERATIONS" "$POPULATION_SIZE" "$SIGMA" "$LEARNING_RATE" "$SEED" \
    "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE" "$RUN_DIR"
else
  "$TRAINER" "$OUTPUT_VECTOR" "" \
    "$GENERATIONS" "$POPULATION_SIZE" "$SIGMA" "$LEARNING_RATE" "$SEED" \
    "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE" "$RUN_DIR"
fi

echo
echo "=== eval ==="
"$EVALUATOR" "$OUTPUT_VECTOR" "$GAMES" "$PLIES" "$MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OPENINGS_FILE"

echo
echo "=== bo ==="
"$BO_RUNNER" "$BO_GAMES" "$BO_PLIES" "$BO_MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$OUTPUT_VECTOR" "$OPENINGS_FILE"
