**Setup**

Use `uv`, not `pip`, for the fastest path on a clean machine:

```bash
./scripts/modal-setup.sh
```

If `modal profile current` prints your active profile, this repo is ready for the next step.

**Run**

Distributed tune from the repo root:

```bash
ARTIFACT_PREFIX=first-real-run ./scripts/modal-tune.sh
```

Evaluate an existing manifest in parallel:

```bash
ARTIFACT_PREFIX=first-real-run ./scripts/modal-eval-manifest.sh modal-runs/first-real-run/generation-001.manifest.json
```

Override tuning parameters with environment variables:

```bash
ARTIFACT_PREFIX=large-run POPULATION_SIZE=32 GENERATIONS=8 ITERATIONS=10 MAX_PLIES=24 ./scripts/modal-tune.sh
```

**What It Does**

- `modal_app.py` packages the JS chess engine into a Modal image.
- `evaluate_candidate()` is the remote worker for one NES candidate.
- `distributed_tune()` is the local coordinator that plans generations locally and fans worker jobs out with Modal.
- run artifacts are written locally under `modal-runs/<artifact-prefix>/`
- worker result JSON is also written to the Modal volume `garuda-chess-runs` under `/mnt/runs/<artifact-prefix>/`
- `scripts/modal-setup.sh` installs and authenticates Modal with `uv`
- `scripts/modal-tune.sh` launches a distributed tuning run
- `scripts/modal-eval-manifest.sh` fans out evaluation for an existing manifest

**Current Limitation**

This environment does not have Python or `modal` installed, so I could not execute the Modal program here. The JS side it wraps is already verified locally.
