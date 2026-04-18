#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <manifest-path>" >&2
  exit 1
fi

MANIFEST_PATH="$1"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-manual}"
ITERATIONS="${ITERATIONS:-6}"
MAX_PLIES="${MAX_PLIES:-16}"
CPUCT="${CPUCT:-1.35}"
FITNESS="${FITNESS:-mixed}"

modal run modal_app.py::eval_generation \
  --manifest-path "${MANIFEST_PATH}" \
  --iterations "${ITERATIONS}" \
  --max-plies "${MAX_PLIES}" \
  --cpuct "${CPUCT}" \
  --fitness "${FITNESS}" \
  --artifact-prefix "${ARTIFACT_PREFIX}"
