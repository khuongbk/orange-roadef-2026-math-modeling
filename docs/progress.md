# Progress log

## 2026-10-21 — scaffold milestone

- Supplied ZIP unpacked: 20 instances / 60 JSON files.
- Dataset inventory generator and independent Python forwarding checks included.
- Julia loader, two forwarding modes, MLU baseline and joint two-period extension drafted.
- Corrected a variable-name defect in the draft model; default forwarding now follows calculating_r.pdf.
- Added execution scripts, resume/failure handling, aggregate tables, Pluto entry point and model notes.
- Julia runtime unavailable here: dependency installation, Julia tests, first MILP solve and route validation have NOT been executed.

## Next milestones

1. DONE: install dependencies and execute Julia tests; record Manifest.toml.
2. DONE: run SetA-01 single-period smoke solve and inspect independent route/load checks.
3. Confirm objective and route assumptions with instructor; update model and documentation together.
4. Measure construction/memory on increasing instance sizes and choose a scalable formulation.
5. Run final experiments; record failures and coverage alongside average results.
6. Complete two-period verification, tables and <=10-page report.

## Update after each change

### 2026-10-21 — first verified local Julia run

- Linux x86_64, Intel Core i7-13650HX, Julia 1.13.2, Python 3.12.3; JuMP 1.32.1, HiGHS.jl 1.26.1, HiGHS solver 1.15.1, JSON3 1.14.3. Instantiation/precompilation succeeded; Manifest.toml generated. Pkg flags JSON3 as deprecated; no migration needed for this smoke run.
- Executed instantiation, inventory (20 instances), Python unittest discovery (2 tests passed), SetA-01 data audit, and Julia tests (2 forwarding + 4 tiny MILP/budget assertions passed).
- Smoke command: `julia --project=. scripts/run.jl data/raw/SetA/setA-01 single 60 1 path_uniform results/raw/smoke-2026-10-21/setA-01-1period-seed1-path_uniform.json`.
- OPTIMAL, objective = best_bound = 0.929383899821109, gap 0, one B&B node. 15,200 binary / 16,001 total variables; one thread; limit 60 s.
- Preprocess 0.119982780 s; build 5.445046599 s; optimize! wall elapsed 2.729973237 s; script end-to-end 19.745570898 s. Script timer starts after imports, excluding process startup/imports; HiGHS internal timing was approximately 1.00 s, a distinct measurement.
- Independent Python ad-hoc terminal check reused `coefficients()` from scripts/check_data.py, not Julia coefficients. All 40 routes checked for coverage, valid nodes, simple segment paths, max_segments, reachability, failed-arc loads and MLU. Passed; most loaded arc ID = 29. This check is not yet a saved standalone route-validator script.
- Baseline t=0 MLU = 1.0000006861063466; relative reduction = 7.061673783464559%. 39 demands use no waypoint, one uses one waypoint.
- Artifacts: [run JSON](../results/raw/smoke-2026-10-21/setA-01-1period-seed1-path_uniform.json), [audit](../results/data-audit.json), [summary](../results/tables/summary.csv), [plan](run-plan.md).
- Real-instance two-period solve and full Step 6/9 batches NOT executed. Objective/route assumptions and dense-model scaling remain unresolved. Tiny two-period tests do not establish real-instance two-period performance.

Record: question, model/code change, command run, observed result, remaining limitation. Never write a numerical claim without its run record.
