#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAINER="$ROOT_DIR/scripts/rust-nes-train-uci.sh"
EVALUATOR="$ROOT_DIR/scripts/rust-nes-eval-uci.sh"
BO_RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish-mcts.sh"
OUTPUT_DIR="${1:-$ROOT_DIR/rust-nes-seed-sweep}"
INPUT_VECTOR="${2:-/tmp/garuda-model.vec}"
GENERATIONS="${3:-2}"
POPULATION_SIZE="${4:-2}"
SIGMA="${5:-0.02}"
LEARNING_RATE="${6:-0.01}"
SEEDS="${7:-7 8 9}"
TRAIN_GAMES="${8:-2}"
TRAIN_PLIES="${9:-4}"
TRAIN_MOVETIME_MS="${10:-10}"
SIMULATIONS="${11:-8}"
CPUCT="${12:-1.35}"
BO_GAMES="${13:-2}"
BO_PLIES="${14:-4}"
BO_MOVETIME_MS="${15:-10}"

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

mkdir -p "$OUTPUT_DIR"
SUMMARY_FILE="$OUTPUT_DIR/summary.tsv"
printf "seed\tvector_file\tuci_fitness\tbo_garuda_wins\tbo_uci_wins\tbo_draws\n" > "$SUMMARY_FILE"

for seed in $SEEDS; do
  vector_file="$OUTPUT_DIR/seed-$seed.vec"
  echo "=== seed=$seed train ==="
  "$TRAINER" "$vector_file" "$INPUT_VECTOR" \
    "$GENERATIONS" "$POPULATION_SIZE" "$SIGMA" "$LEARNING_RATE" "$seed" \
    "$TRAIN_GAMES" "$TRAIN_PLIES" "$TRAIN_MOVETIME_MS" "$SIMULATIONS" "$CPUCT"

  echo
  echo "=== seed=$seed eval ==="
  eval_output="$("$EVALUATOR" "$vector_file" "$TRAIN_GAMES" "$TRAIN_PLIES" "$TRAIN_MOVETIME_MS" "$SIMULATIONS" "$CPUCT")"
  printf "%s\n" "$eval_output"
  uci_fitness="$(printf "%s\n" "$eval_output" | sed -n 's/^fitness \(.*\)$/\1/p')"

  echo
  echo "=== seed=$seed bo ==="
  bo_output="$("$BO_RUNNER" "$BO_GAMES" "$BO_PLIES" "$BO_MOVETIME_MS" "$SIMULATIONS" "$CPUCT" "$vector_file")"
  printf "%s\n" "$bo_output"
  summary_line="$(printf "%s\n" "$bo_output" | grep '^summary ')"
  bo_garuda_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*garuda_wins=\([0-9][0-9]*\).*/\1/p')"
  bo_uci_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*uci_wins=\([0-9][0-9]*\).*/\1/p')"
  bo_draws="$(printf "%s\n" "$summary_line" | sed -n 's/.*draws=\([0-9][0-9]*\).*/\1/p')"

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$seed" "$vector_file" "$uci_fitness" "$bo_garuda_wins" "$bo_uci_wins" "$bo_draws" >> "$SUMMARY_FILE"
  echo
done

echo "summary_file=$SUMMARY_FILE"
