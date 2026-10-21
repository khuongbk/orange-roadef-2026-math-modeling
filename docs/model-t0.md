# Period-0 baseline model — provisional MLU formulation

This note documents the implemented baseline, not a claim of equivalence to the full challenge. Original objective is sorted-load lexicographic minimization; MLU covers its first priority only.

## Data

V: router set; A: physical directed arcs; D: demands; s_d,t_d: demand endpoints; v_d: traffic at period 0; c_a>0: capacity; w_a>0: metric; K: maximum segments.

S = {(i,j): i != j and j is reachable from i}. Each (i,j) is a routing segment, potentially spanning multiple physical arcs.

r_ija is computed before optimization. Per calculating_r.pdf, with a=(u,v), shortest distances delta and path counts sigma:

r_ija = sigma_iu sigma_vj / sigma_ij when delta_iu + w_a + delta_vj = delta_ij; otherwise 0.

The implementation computes the same uniform-path distribution using suffix path counts on each target's shortest-path DAG; equal splitting is weighted by the number of remaining shortest paths. It does not enumerate paths. Unreachable segments are excluded, not treated as free routes.

## Variables

- x_dij in {0,1}: demand d uses segment (i,j).
- U >= 0: upper bound on every physical-arc utilization.
- p_di in [0,n-1]: continuous waypoint-order labels to eliminate segment cycles.

## Objective and constraints

Minimize U.

For every d and i, outgoing selected segments minus incoming selected segments equals 1 at s_d, -1 at t_d, and 0 elsewhere.

At most one incoming and one outgoing selected segment at a router. No incoming segment to s_d and no outgoing segment from t_d.

For every d: sum_(i,j in S) x_dij <= K.

Fix p_d,s_d = 0 and impose for every segment:

p_dj >= p_di + 1 - n(1-x_dij).

For every physical arc a:

sum_d v_d sum_(i,j in S) r_ija x_dij <= c_a U.

Together balance, degree bounds and order constraints select one simple source-target path in segment space. The model does not impose utilization <=1. The restriction to simple segment paths is explicit and must be checked against the final specification.

## Two-period extension

Duplicate routing/order variables and forwarding coefficients for periods 0 and 1. Use a common U across both periods. Disable the specified physical arc before recalculating forwarding at period 1.

For each segment and demand, introduce z_dij >= x_dij,1 - x_dij,0 and z_dij >= x_dij,0 - x_dij,1. Sum z_dij <= B. Missing/unreachable segment variables count as zero. Existence of these z variables is equivalent to bounding the sum of absolute binary changes. Validate budget independently from selected segment sets.

## Independent output checks

Reconstruct each source-target waypoint sequence; check absence of repeated waypoints, max segment count, unused failed arcs, recomputed utilization, and segment symmetric-difference budget.

Current limitations: dense coefficients O(n²m), binary variables O(|D|n²|T|), no full lexicographic optimizer, no scalable exact formulation, no measured Julia solve yet.
