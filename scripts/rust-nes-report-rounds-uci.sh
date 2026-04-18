#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${1:-$ROOT_DIR/rust-nes-rounds}"
CONFIG_FILE="$RUN_DIR/config.txt"
HISTORY_FILE="$RUN_DIR/history.tsv"
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
current_line="$(tail -n 1 "$HISTORY_FILE")"
best_line="$(
  tail -n +2 "$HISTORY_FILE" \
    | awk -F $'\t' '{print ($8 - $9) "\t" $10 "\t" $7 "\t" $0}' \
    | sort -t $'\t' -k1,1nr -k2,2nr -k3,3nr \
    | head -n 1 \
    | cut -f4-
)"

echo "run_dir=$RUN_DIR"
echo "config_file=$CONFIG_FILE"
echo "history_file=$HISTORY_FILE"
echo "round_count=$row_count"
if [[ -n "$latest_round" ]]; then
  echo "latest_round=$latest_round"
fi

echo
echo "=== config ==="
cat "$CONFIG_FILE"

if [[ -n "$current_line" ]]; then
  current_round="$(printf "%s\n" "$current_line" | cut -f1)"
  current_summary="$(printf "%s\n" "$current_line" | cut -f2)"
  current_seed="$(printf "%s\n" "$current_line" | cut -f3)"
  current_generation="$(printf "%s\n" "$current_line" | cut -f4)"
  current_updated_fitness="$(printf "%s\n" "$current_line" | cut -f5)"
  current_final_fitness="$(printf "%s\n" "$current_line" | cut -f6)"
  current_uci_fitness="$(printf "%s\n" "$current_line" | cut -f7)"
  current_bo_garuda_wins="$(printf "%s\n" "$current_line" | cut -f8)"
  current_bo_uci_wins="$(printf "%s\n" "$current_line" | cut -f9)"
  current_bo_draws="$(printf "%s\n" "$current_line" | cut -f10)"
  current_vector="$(printf "%s\n" "$current_line" | cut -f11)"
  current_run_dir="$(printf "%s\n" "$current_line" | cut -f12)"
  current_global_best_round="$(printf "%s\n" "$current_line" | cut -f13)"

  echo
  echo "=== current ==="
  echo "round=$current_round"
  echo "summary=$current_summary"
  echo "seed=$current_seed"
  echo "generation=$current_generation"
  echo "updated_fitness=$current_updated_fitness"
  echo "final_fitness=$current_final_fitness"
  echo "uci_fitness=$current_uci_fitness"
  echo "bo_garuda_wins=$current_bo_garuda_wins"
  echo "bo_uci_wins=$current_bo_uci_wins"
  echo "bo_draws=$current_bo_draws"
  echo "vector=$current_vector"
  echo "run_dir=$current_run_dir"
  echo "global_best_round=$current_global_best_round"
fi

if [[ -n "$best_line" ]]; then
  best_round="$(printf "%s\n" "$best_line" | cut -f1)"
  best_summary="$(printf "%s\n" "$best_line" | cut -f2)"
  best_seed="$(printf "%s\n" "$best_line" | cut -f3)"
  best_generation="$(printf "%s\n" "$best_line" | cut -f4)"
  best_updated_fitness="$(printf "%s\n" "$best_line" | cut -f5)"
  best_final_fitness="$(printf "%s\n" "$best_line" | cut -f6)"
  best_uci_fitness="$(printf "%s\n" "$best_line" | cut -f7)"
  best_bo_garuda_wins="$(printf "%s\n" "$best_line" | cut -f8)"
  best_bo_uci_wins="$(printf "%s\n" "$best_line" | cut -f9)"
  best_bo_draws="$(printf "%s\n" "$best_line" | cut -f10)"
  best_vector="$(printf "%s\n" "$best_line" | cut -f11)"
  best_run_dir="$(printf "%s\n" "$best_line" | cut -f12)"
  best_global_best_round="$(printf "%s\n" "$best_line" | cut -f13)"

  echo
  echo "=== best ==="
  echo "round=$best_round"
  echo "summary=$best_summary"
  echo "seed=$best_seed"
  echo "generation=$best_generation"
  echo "updated_fitness=$best_updated_fitness"
  echo "final_fitness=$best_final_fitness"
  echo "uci_fitness=$best_uci_fitness"
  echo "bo_garuda_wins=$best_bo_garuda_wins"
  echo "bo_uci_wins=$best_bo_uci_wins"
  echo "bo_draws=$best_bo_draws"
  echo "vector=$best_vector"
  echo "run_dir=$best_run_dir"
  echo "global_best_round=$best_global_best_round"
fi

echo
echo "=== history tail ==="
tail -n 5 "$HISTORY_FILE"
