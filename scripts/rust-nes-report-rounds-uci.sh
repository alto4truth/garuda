#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${1:-$ROOT_DIR/rust-nes-rounds}"
CONFIG_FILE="$RUN_DIR/config.txt"
HISTORY_FILE="$RUN_DIR/history.tsv"
CURRENT_FILE="$RUN_DIR/current.tsv"
GLOBAL_BEST_FILE="$RUN_DIR/global-best.tsv"
LATEST_ROUND_FILE="$RUN_DIR/latest.round"

for path in "$CONFIG_FILE" "$HISTORY_FILE" "$CURRENT_FILE" "$GLOBAL_BEST_FILE"; do
  if [[ ! -f "$path" ]]; then
    echo "missing required rounds artifact: $path" >&2
    exit 1
  fi
done

echo "run_dir=$RUN_DIR"
echo
echo "=== config ==="
cat "$CONFIG_FILE"
echo

if [[ -f "$LATEST_ROUND_FILE" ]]; then
  echo "latest_round=$(cat "$LATEST_ROUND_FILE")"
  echo
fi

echo "=== current ==="
cat "$CURRENT_FILE"
echo

echo "=== global_best ==="
cat "$GLOBAL_BEST_FILE"
echo

echo "=== recent_history ==="
tail -n 5 "$HISTORY_FILE"
