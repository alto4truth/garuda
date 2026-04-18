**Setup**

Use `uv`, not `pip`, for the fastest path on a clean machine:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install modal
modal token new
modal profile current
```

If `modal profile current` prints your active profile, this repo is ready for the next step.

**Run**

Distributed tune from the repo root:

```bash
modal run modal_app.py::distributed_tune --population-size 16 --generations 4 --iterations 6 --max-plies 16 --artifact-prefix first-real-run
```

Evaluate an existing manifest in parallel:

```bash
modal run modal_app.py::eval_generation --manifest-path modal-runs/first-real-run/generation-001.manifest.json --iterations 6 --max-plies 16 --artifact-prefix first-real-run
```

**What It Does**

- `modal_app.py` packages the JS chess engine into a Modal image.
- `evaluate_candidate()` is the remote worker for one NES candidate.
- `distributed_tune()` is the local coordinator that plans generations locally and fans worker jobs out with Modal.
- run artifacts are written locally under `modal-runs/<artifact-prefix>/`
- worker result JSON is also written to the Modal volume `garuda-chess-runs` under `/mnt/runs/<artifact-prefix>/`

**Current Limitation**

This environment does not have Python or `modal` installed, so I could not execute the Modal program here. The JS side it wraps is already verified locally.
