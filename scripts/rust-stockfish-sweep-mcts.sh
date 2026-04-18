#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish-mcts.sh"
GAMES="${1:-4}"
PLIES="${2:-0}"
MOVETIME_MS="${3:-15}"
OUTPUT_FILE="${4:-$ROOT_DIR/rust-stockfish-mcts-sweep.tsv}"
VECTOR_FILE="${5:-}"

if [[ ! -x "$RUNNER" ]]; then
  echo "missing runner at $RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"
cargo build --release --bin garuda-chess >/dev/null

if [[ ! -f "$OUTPUT_FILE" ]]; then
  printf "simulations\tcpuct\tgames\tmax_plies\tmovetime_ms\tgaruda_wins\tuci_wins\tdraws\n" > "$OUTPUT_FILE"
fi

for simulations in 16 32 64; do
  for cpuct in 1.00 1.35 1.70; do
    echo "=== simulations=$simulations cpuct=$cpuct games=$GAMES max_plies=$PLIES movetime_ms=$MOVETIME_MS ==="
    if [[ -n "$VECTOR_FILE" ]]; then
      run_output="$("$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$simulations" "$cpuct" "$VECTOR_FILE")"
    else
      run_output="$("$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$simulations" "$cpuct")"
    fi
    printf "%s\n" "$run_output"
    summary_line="$(printf "%s\n" "$run_output" | grep '^summary ')"
    if [[ -n "$summary_line" ]]; then
      garuda_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*garuda_wins=\([0-9][0-9]*\).*/\1/p')"
      uci_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*uci_wins=\([0-9][0-9]*\).*/\1/p')"
      draws="$(printf "%s\n" "$summary_line" | sed -n 's/.*draws=\([0-9][0-9]*\).*/\1/p')"
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$simulations" "$cpuct" "$GAMES" "$PLIES" "$MOVETIME_MS" \
        "$garuda_wins" "$uci_wins" "$draws" >> "$OUTPUT_FILE"
    fi
    echo
  done
done
