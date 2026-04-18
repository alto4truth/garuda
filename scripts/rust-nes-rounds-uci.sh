#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_SWEEP="$ROOT_DIR/scripts/rust-nes-seed-sweep-uci.sh"
SELECT_BEST="$ROOT_DIR/scripts/rust-nes-select-best.sh"
RUN_DIR="${1:-$ROOT_DIR/rust-nes-rounds}"
INPUT_VECTOR="${2:-/tmp/garuda-model.vec}"
ROUNDS="${3:-3}"
GENERATIONS="${4:-2}"
POPULATION_SIZE="${5:-2}"
SIGMA="${6:-0.02}"
LEARNING_RATE="${7:-0.01}"
SEEDS="${8:-7 8 9}"
TRAIN_GAMES="${9:-2}"
TRAIN_PLIES="${10:-4}"
TRAIN_MOVETIME_MS="${11:-10}"
SIMULATIONS="${12:-8}"
CPUCT="${13:-1.35}"
BO_GAMES="${14:-2}"
BO_PLIES="${15:-4}"
BO_MOVETIME_MS="${16:-10}"
OPENINGS_FILE="${17:-$ROOT_DIR/data/rust-stockfish-openings.fen}"

if [[ ! -x "$SEED_SWEEP" ]]; then
  echo "missing seed sweep at $SEED_SWEEP" >&2
  exit 1
fi

if [[ ! -x "$SELECT_BEST" ]]; then
  echo "missing selector at $SELECT_BEST" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"
HISTORY_FILE="$RUN_DIR/history.tsv"
CURRENT_VECTOR="$RUN_DIR/current.vec"
BEST_VECTOR="$RUN_DIR/best.vec"
BEST_RUN_DIR="$RUN_DIR/best.run"
CURRENT_RUN_DIR="$RUN_DIR/current.run"
CONFIG_FILE="$RUN_DIR/config.txt"
LATEST_ROUND_FILE="$RUN_DIR/latest.round"
GLOBAL_BEST_ROUND=""
GLOBAL_BEST_SEED=""
GLOBAL_BEST_GENERATION=""
GLOBAL_BEST_UPDATED_FITNESS=""
GLOBAL_BEST_FINAL_FITNESS=""
GLOBAL_BEST_UCI_FITNESS=""
GLOBAL_BEST_BO_GARUDA_WINS=""
GLOBAL_BEST_BO_UCI_WINS=""
GLOBAL_BEST_BO_DRAWS=""
GLOBAL_BEST_BO_BALANCE=""

if [[ -f "$INPUT_VECTOR" ]]; then
  cp "$INPUT_VECTOR" "$CURRENT_VECTOR"
else
  cargo build --release --bin garuda-chess >/dev/null
  "$ROOT_DIR/target/release/garuda-chess" model-vector > "$CURRENT_VECTOR"
fi

cat > "$CONFIG_FILE" <<EOF
input_vector=$INPUT_VECTOR
rounds=$ROUNDS
generations=$GENERATIONS
population_size=$POPULATION_SIZE
sigma=$SIGMA
learning_rate=$LEARNING_RATE
seeds=$SEEDS
train_games=$TRAIN_GAMES
train_plies=$TRAIN_PLIES
train_movetime_ms=$TRAIN_MOVETIME_MS
simulations=$SIMULATIONS
cpuct=$CPUCT
bo_games=$BO_GAMES
bo_plies=$BO_PLIES
bo_movetime_ms=$BO_MOVETIME_MS
openings_file=$OPENINGS_FILE
EOF

printf "round\tsummary_file\tbest_seed\tbest_generation\tbest_updated_fitness\tbest_final_fitness\tbest_uci_fitness\tbest_bo_garuda_wins\tbest_bo_uci_wins\tbest_bo_draws\tbest_vector\tbest_run_dir\tglobal_best_round\n" > "$HISTORY_FILE"

for round in $(seq 1 "$ROUNDS"); do
  round_dir="$RUN_DIR/round-$(printf '%03d' "$round")"
  mkdir -p "$round_dir"
  echo "=== round=$round sweep ==="
  "$SEED_SWEEP" "$round_dir" "$CURRENT_VECTOR" \
    "$GENERATIONS" "$POPULATION_SIZE" "$SIGMA" "$LEARNING_RATE" "$SEEDS" \
    "$TRAIN_GAMES" "$TRAIN_PLIES" "$TRAIN_MOVETIME_MS" "$SIMULATIONS" "$CPUCT" \
    "$BO_GAMES" "$BO_PLIES" "$BO_MOVETIME_MS" "$OPENINGS_FILE"

  echo
  echo "=== round=$round select ==="
  selector_output="$("$SELECT_BEST" "$round_dir/summary.tsv" "$round_dir/selected.vec" "$round_dir/selected.run")"
  printf "%s\n" "$selector_output"

  best_seed="$(printf "%s\n" "$selector_output" | sed -n 's/^best_seed=\(.*\)$/\1/p')"
  best_generation="$(printf "%s\n" "$selector_output" | sed -n 's/^best_generation=\(.*\)$/\1/p')"
  best_updated_fitness="$(printf "%s\n" "$selector_output" | sed -n 's/^best_updated_fitness=\(.*\)$/\1/p')"
  best_final_fitness="$(printf "%s\n" "$selector_output" | sed -n 's/^best_final_fitness=\(.*\)$/\1/p')"
  best_uci_fitness="$(printf "%s\n" "$selector_output" | sed -n 's/^best_fitness=\(.*\)$/\1/p')"
  best_bo_garuda_wins="$(printf "%s\n" "$selector_output" | sed -n 's/^best_bo_garuda_wins=\(.*\)$/\1/p')"
  best_bo_uci_wins="$(printf "%s\n" "$selector_output" | sed -n 's/^best_bo_uci_wins=\(.*\)$/\1/p')"
  best_bo_draws="$(printf "%s\n" "$selector_output" | sed -n 's/^best_bo_draws=\(.*\)$/\1/p')"
  selected_vector="$(printf "%s\n" "$selector_output" | sed -n 's/^output_vector=\(.*\)$/\1/p')"
  selected_run_dir="$(printf "%s\n" "$selector_output" | sed -n 's/^output_run_dir=\(.*\)$/\1/p')"

  cp "$selected_vector" "$CURRENT_VECTOR"
  rm -rf "$CURRENT_RUN_DIR"
  if [[ -n "$selected_run_dir" && -d "$selected_run_dir" ]]; then
    cp -R "$selected_run_dir" "$CURRENT_RUN_DIR"
  fi

  bo_balance=$((best_bo_garuda_wins - best_bo_uci_wins))
  if [[ -z "$GLOBAL_BEST_ROUND" ]] \
    || [[ "$bo_balance" -gt "$GLOBAL_BEST_BO_BALANCE" ]] \
    || { [[ "$bo_balance" -eq "$GLOBAL_BEST_BO_BALANCE" ]] && [[ "$best_bo_draws" -gt "$GLOBAL_BEST_BO_DRAWS" ]]; } \
    || { [[ "$bo_balance" -eq "$GLOBAL_BEST_BO_BALANCE" ]] && [[ "$best_bo_draws" -eq "$GLOBAL_BEST_BO_DRAWS" ]] \
      && awk "BEGIN { exit !($best_uci_fitness > $GLOBAL_BEST_UCI_FITNESS) }"; }; then
    GLOBAL_BEST_ROUND="$round"
    GLOBAL_BEST_SEED="$best_seed"
    GLOBAL_BEST_GENERATION="$best_generation"
    GLOBAL_BEST_UPDATED_FITNESS="$best_updated_fitness"
    GLOBAL_BEST_FINAL_FITNESS="$best_final_fitness"
    GLOBAL_BEST_UCI_FITNESS="$best_uci_fitness"
    GLOBAL_BEST_BO_GARUDA_WINS="$best_bo_garuda_wins"
    GLOBAL_BEST_BO_UCI_WINS="$best_bo_uci_wins"
    GLOBAL_BEST_BO_DRAWS="$best_bo_draws"
    GLOBAL_BEST_BO_BALANCE="$bo_balance"
    cp "$selected_vector" "$BEST_VECTOR"
    rm -rf "$BEST_RUN_DIR"
    if [[ -n "$selected_run_dir" && -d "$selected_run_dir" ]]; then
      cp -R "$selected_run_dir" "$BEST_RUN_DIR"
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$round" "$round_dir/summary.tsv" "$best_seed" "$best_generation" \
    "$best_updated_fitness" "$best_final_fitness" "$best_uci_fitness" \
    "$best_bo_garuda_wins" "$best_bo_uci_wins" "$best_bo_draws" \
    "$selected_vector" "${selected_run_dir:-}" "${GLOBAL_BEST_ROUND:-}" >> "$HISTORY_FILE"
  printf "%s\n" "$round_dir" > "$LATEST_ROUND_FILE"
  echo
done

echo "config_file=$CONFIG_FILE"
echo "history_file=$HISTORY_FILE"
echo "current_vector=$CURRENT_VECTOR"
if [[ -d "$CURRENT_RUN_DIR" ]]; then
  echo "current_run_dir=$CURRENT_RUN_DIR"
fi
echo "best_vector=$BEST_VECTOR"
echo "latest_round_file=$LATEST_ROUND_FILE"
if [[ -d "$BEST_RUN_DIR" ]]; then
  echo "best_run_dir=$BEST_RUN_DIR"
fi
if [[ -n "$GLOBAL_BEST_ROUND" ]]; then
  echo "global_best_round=$GLOBAL_BEST_ROUND"
  echo "global_best_seed=$GLOBAL_BEST_SEED"
  echo "global_best_generation=$GLOBAL_BEST_GENERATION"
  echo "global_best_updated_fitness=$GLOBAL_BEST_UPDATED_FITNESS"
  echo "global_best_final_fitness=$GLOBAL_BEST_FINAL_FITNESS"
  echo "global_best_uci_fitness=$GLOBAL_BEST_UCI_FITNESS"
  echo "global_best_bo_garuda_wins=$GLOBAL_BEST_BO_GARUDA_WINS"
  echo "global_best_bo_uci_wins=$GLOBAL_BEST_BO_UCI_WINS"
  echo "global_best_bo_draws=$GLOBAL_BEST_BO_DRAWS"
fi
