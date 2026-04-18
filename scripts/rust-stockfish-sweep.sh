#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/rust-bo-stockfish.sh"
GAMES="${1:-4}"
PLIES="${2:-0}"
MOVETIME_MS="${3:-15}"
OUTPUT_FILE="${4:-$ROOT_DIR/rust-stockfish-sweep.tsv}"

if [[ ! -x "$RUNNER" ]]; then
  echo "missing runner at $RUNNER" >&2
  exit 1
fi

cd "$ROOT_DIR"
cargo build --release --bin garuda-chess >/dev/null

if [[ ! -f "$OUTPUT_FILE" ]]; then
  printf "depth\tquiescence\tgames\tmax_plies\tmovetime_ms\tgaruda_wins\tuci_wins\tdraws\n" > "$OUTPUT_FILE"
fi

for depth in 2 3 4; do
  for quiescence in 4 6; do
    echo "=== depth=$depth quiescence=$quiescence games=$GAMES max_plies=$PLIES movetime_ms=$MOVETIME_MS ==="
    run_output="$("$RUNNER" "$GAMES" "$PLIES" "$MOVETIME_MS" "$depth" "$quiescence")"
    printf "%s\n" "$run_output"
    summary_line="$(printf "%s\n" "$run_output" | grep '^summary ')"
    if [[ -n "$summary_line" ]]; then
      garuda_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*garuda_wins=\([0-9][0-9]*\).*/\1/p')"
      uci_wins="$(printf "%s\n" "$summary_line" | sed -n 's/.*uci_wins=\([0-9][0-9]*\).*/\1/p')"
      draws="$(printf "%s\n" "$summary_line" | sed -n 's/.*draws=\([0-9][0-9]*\).*/\1/p')"
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$depth" "$quiescence" "$GAMES" "$PLIES" "$MOVETIME_MS" \
        "$garuda_wins" "$uci_wins" "$draws" >> "$OUTPUT_FILE"
    fi
    echo
  done
done
