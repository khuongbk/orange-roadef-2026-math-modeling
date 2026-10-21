# Orange ROADEF 2026 — Mathematical Modeling

Julia/JuMP course project on T-Adaptive Segment Routing. Working package: data preprocessing, an initial MLU MILP, a two-period extension, independent Python forwarding checks, experiment scripts, and living model/report notes.

## Start here

Run all commands from this project directory. Install Julia 1.10+ and Python 3 first.

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
python3 -m unittest discover -s test -p 'test_*.py' -v
python3 scripts/check_data.py data/raw/SetA/setA-01
julia --project=. test/runtests.jl
# Smoke solve: 60-second optimizer limit, not a final experiment
julia --project=. scripts/run.jl data/raw/SetA/setA-01 single 60 1 path_uniform
```

The archive includes all 20 supplied instances and the three reference documents for local use. Raw inputs/reference documents are ignored by git. Original node/arc IDs are preserved in data; Julia indices are mapped internally.

## Layout

| Path | Responsibility |
|---|---|
| `src/OrangeASR.jl` | Loader, shortest-path coefficients, MLU MILP, route/load validation |
| `scripts/run.jl` | One solve; JSON record and waypoint routes |
| `scripts/batch.py` | Repetitions, solver limits, failure logs, resume by completed output |
| `scripts/summarize.py` | CSV averages and status counts, grouped by instance/model/mode |
| `scripts/inventory.py` | Fast input validation and size table for all SetA |
| `scripts/check_data.py` | Independent Python forwarding and no-waypoint baseline audit |
| `notebooks/01_pipeline.jl` | Pluto entry point using the same source module |
| `config/smoke.json` | One small solve to verify the pipeline |
| `config/step6.json`, `config/step9.json` | Planned full experiments; 10 runs per instance |
| `docs/model-t0.md` | Variables, MLU objective, constraints and assumptions |
| `docs/decisions.md`, `docs/progress.md` | Open specification questions and verified progress |
| `report/report.md` | Report outline to update as results become available |
| `results/raw/` | Individual run records and failure logs |
| `results/tables/` | Inventory and aggregated CSV outputs |

## Experiment commands

```bash
python3 scripts/inventory.py
python3 scripts/batch.py config/smoke.json
python3 scripts/summarize.py
# Only after the smoke solve and correctness review pass:
python3 scripts/batch.py config/step6.json
python3 scripts/batch.py config/step9.json
```

`single` means period 0; `two` jointly optimizes periods 0 and 1. Default forwarding is `path_uniform`, matching calculating_r.pdf. `ecmp` remains available for comparison. Solver uses one thread per run; batch runs sequentially. For 20 instances x 10 repetitions, total solver-limit budget is 100 hours (Step 6) + 200 hours (Step 9). Early completion can reduce it.

**Scaling guard:** this initial dense formulation refuses instances requiring more than 1,000,000 estimated binary variables, before allocating the dense coefficient tensor. Full configs enumerate all SetA; large instances will produce explicit failure logs, not fabricated results. This scaffold does not yet solve the scaling problem. Such failures must appear in experimental coverage, not be silently omitted.

A repeated seed identifies each fresh run. Repetitions may produce identical solutions. The optimizer limit excludes data loading, forwarding preprocessing and model construction. JSON records report those timings separately; elapsed `optimize!` time is wall-clock, labeled explicitly rather than CPU process time. Keep `Manifest.toml` after the first successful instantiation for reproducibility.

## GitHub description

Mathematical modeling of Orange ROADEF 2026 T-Adaptive Segment Routing in Julia/JuMP, with shortest-path preprocessing, MILP baselines, and reproducible experiments.

This is an independent course project. No repository has been created or pushed by this package.
