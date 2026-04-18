#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_FILE="${1:-$ROOT_DIR/rust-nes-seed-sweep/summary.tsv}"
OUTPUT_VECTOR="${2:-$ROOT_DIR/rust-nes-best.vec}"

if [[ ! -f "$SUMMARY_FILE" ]]; then
  echo "missing summary file at $SUMMARY_FILE" >&2
  exit 1
fi

best_line="$(
  tail -n +2 "$SUMMARY_FILE" \
    | sort -t $'\t' -k3,3nr -k4,4nr -k6,6nr \
    | head -n 1
)"

if [[ -z "$best_line" ]]; then
  echo "summary file had no candidate rows" >&2
  exit 1
fi

best_seed="$(printf "%s\n" "$best_line" | cut -f1)"
best_vector="$(printf "%s\n" "$best_line" | cut -f2)"
best_fitness="$(printf "%s\n" "$best_line" | cut -f3)"
best_bo_garuda_wins="$(printf "%s\n" "$best_line" | cut -f4)"
best_bo_uci_wins="$(printf "%s\n" "$best_line" | cut -f5)"
best_bo_draws="$(printf "%s\n" "$best_line" | cut -f6)"

if [[ ! -f "$best_vector" ]]; then
  echo "best vector from summary is missing: $best_vector" >&2
  exit 1
fi

cp "$best_vector" "$OUTPUT_VECTOR"

echo "best_seed=$best_seed"
echo "best_vector=$best_vector"
echo "best_fitness=$best_fitness"
echo "best_bo_garuda_wins=$best_bo_garuda_wins"
echo "best_bo_uci_wins=$best_bo_uci_wins"
echo "best_bo_draws=$best_bo_draws"
echo "output_vector=$OUTPUT_VECTOR"
