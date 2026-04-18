#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${1:-$ROOT_DIR/rust-nes-rounds}"
CONFIG_FILE="$RUN_DIR/config.txt"
HISTORY_FILE="$RUN_DIR/history.tsv"
CURRENT_FILE="$RUN_DIR/current.tsv"
GLOBAL_BEST_FILE="$RUN_DIR/global-best.tsv"
LATEST_ROUND_FILE="$RUN_DIR/latest.round"

if [[ ! -d "$RUN_DIR" ]]; then
  echo "missing run dir at $RUN_DIR" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "missing config file at $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$HISTORY_FILE" ]]; then
  echo "missing history file at $HISTORY_FILE" >&2
  exit 1
fi

latest_round=""
if [[ -f "$LATEST_ROUND_FILE" ]]; then
  latest_round="$(cat "$LATEST_ROUND_FILE")"
fi

row_count="$(tail -n +2 "$HISTORY_FILE" | wc -l | tr -d ' ')"

echo "run_dir=$RUN_DIR"
echo "config_file=$CONFIG_FILE"
echo "history_file=$HISTORY_FILE"
if [[ -f "$CURRENT_FILE" ]]; then
  echo "current_file=$CURRENT_FILE"
fi
if [[ -f "$GLOBAL_BEST_FILE" ]]; then
  echo "global_best_file=$GLOBAL_BEST_FILE"
fi
echo "round_count=$row_count"
if [[ -n "$latest_round" ]]; then
  echo "latest_round=$latest_round"
fi

echo
echo "=== config ==="
cat "$CONFIG_FILE"

if [[ -f "$CURRENT_FILE" ]]; then
  echo
  echo "=== current ==="
  cat "$CURRENT_FILE"
fi

if [[ -f "$GLOBAL_BEST_FILE" ]]; then
  echo
  echo "=== best ==="
  cat "$GLOBAL_BEST_FILE"
fi

echo
echo "=== history tail ==="
tail -n 5 "$HISTORY_FILE"
