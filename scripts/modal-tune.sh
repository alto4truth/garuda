#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-latest}"
POPULATION_SIZE="${POPULATION_SIZE:-16}"
GENERATIONS="${GENERATIONS:-4}"
ITERATIONS="${ITERATIONS:-6}"
MAX_PLIES="${MAX_PLIES:-16}"
CPUCT="${CPUCT:-1.35}"
SIGMA="${SIGMA:-0.12}"
LEARNING_RATE="${LEARNING_RATE:-0.18}"
SEED="${SEED:-1337}"
FITNESS="${FITNESS:-mixed}"
MODEL_TYPE="${MODEL_TYPE:-neural}"

uv tool run modal run modal_app.py::distributed_tune \
  --population-size "${POPULATION_SIZE}" \
  --generations "${GENERATIONS}" \
  --iterations "${ITERATIONS}" \
  --max-plies "${MAX_PLIES}" \
  --cpuct "${CPUCT}" \
  --sigma "${SIGMA}" \
  --learning-rate "${LEARNING_RATE}" \
  --seed "${SEED}" \
  --fitness "${FITNESS}" \
  --model-type "${MODEL_TYPE}" \
  --artifact-prefix "${ARTIFACT_PREFIX}"
