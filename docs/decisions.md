# Decisions and questions

| Topic | Working choice | Needs confirmation |
|---|---|---|
| Forwarding r | Uniform shortest paths per calculating_r.pdf | Difference from local ECMP in challenge statement |
| Objective | MLU baseline for first executable milestone | Whether instructor accepts MLU or requires full sorted lexicographic objective |
| Routing | One simple path in segment space per demand | Verify equivalence to required route domain; excluding repeated waypoints is an assumption |
| Time periods | Step 6: [0]; Step 9: joint [0,1] | Step 9 repeats 'only time period 0', likely copy error |
| Repetitions | 10 fresh solves, seeds 1–10, one solver thread | README says average over ten runs; not 'at least ten' |
| Gap | 1 - lower_bound / incumbent | Scalar MLU only; full lexicographic objective needs a separate protocol |
| Scope | All 20 SetA intended | Dense formulation cannot cover large instances yet |
| Submission | <=10-page report plus runnable code prepared | Whether code is a mandatory separate submission |

No candidate-route reduction is implemented. Adding one later changes the feasible set unless completeness is established. Optimality and bounds from a reduced model must be labeled as restricted-model results.
