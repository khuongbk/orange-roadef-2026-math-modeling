# T-Adaptive Segment Routing — Course Report

Target: at most ten pages. This is a working outline, not a finished report.

## 1. Introduction (~1 page)
Context: directed communication networks, congestion, planned link outages, node-segment routing, limited reconfiguration. Explain contribution and the scope actually implemented.

## 2. Data and preprocessing (~1–1.5 pages)
Describe net/tm/scenario files; reference results/tables/instances.csv. Explain metric versus capacity, the selected forwarding semantics, unreachable pairs, graph changes, and ID mapping.

## 3. Mathematical models (~3 pages)
Import verified formulation from docs/model-t0.md. State MLU versus full lexicographic objective clearly. Explain time-0 model, route validity, maximum segments, joint two-period extension and segment-addition/removal budget. State any route-domain restrictions.

## 4. Numerical experiments (~3 pages)
Record hardware, OS, Julia/JuMP/solver versions, thread count, seeds, time limits, ten runs per instance and timing definition. Provide objective, lower bound, requested gap, optimize-call time, termination states and B&B nodes. Identify failed/guarded instances and missing incumbents explicitly. Report valid sample counts; do not present incomplete groups as ten-run averages.

Results pending: no solver numbers available yet.

## 5. Conclusions (~0.5–1 page)
Discuss verified findings, limitations and scaling. No claims before measurements.
