module OrangeASR
using JSON3, JuMP, HiGHS

"""Read original IDs without assuming consecutive or one-based numbering."""
function load_instance(prefix)
    net = JSON3.read(read(prefix * "-net.json", String))
    tm = JSON3.read(read(prefix * "-tm.json", String))
    sc = JSON3.read(read(prefix * "-scenario.json", String))
    ids = Int[n.id for n in net.nodes]
    @assert length(unique(ids)) == length(ids)
    idx = Dict(id => i for (i,id) in enumerate(ids))
    arcs = [(id=Int(a.id), u=idx[Int(a.from)], v=idx[Int(a.to)],
             metric=Float64(a.metric), capacity=Float64(a.capacity)) for a in net.links]
    @assert length(unique(a.id for a in arcs)) == length(arcs)
    @assert length(unique((a.u,a.v) for a in arcs)) == length(arcs)
    @assert all(a.metric > 0 && a.capacity > 0 for a in arcs)
    demands = [(s=idx[Int(d.s)], target=idx[Int(d.t)], volume=Float64.(d.v)) for d in tm.demands]
    @assert all(d.s != d.target && length(d.volume) == tm.num_time_slots && all(d.volume .>= 0) for d in demands)
    down = Dict(t => Set{Int}() for t in 0:Int(tm.num_time_slots)-1)
    for q in sc.interventions
        union!(down[Int(q.t)], Int.(q.links))
    end
    @assert isempty(down[0])
    @assert all(issubset(v, Set(a.id for a in arcs)) for v in values(down))
    budget = Dict(Int(b.t) => Int(b.value) for b in sc.budget)
    return (; ids, arcs, demands, down, budget, maxseg=Int(sc.max_segments), periods=Int(tm.num_time_slots))
end

"""Distances and forwarding fractions, indexed by segment source, target, physical arc.
ECMP splits equally among shortest next hops; path_uniform implements calculating_r.
"""
function forwarding(data, t; mode=:path_uniform)
    mode in (:ecmp, :path_uniform) || error("Unknown forwarding mode")
    n, m = length(data.ids), length(data.arcs)
    active = [a.id ∉ data.down[t] for a in data.arcs]
    dist = fill(Inf,n,n)
    for i in 1:n; dist[i,i] = 0; end
    for (k,a) in enumerate(data.arcs)
        active[k] && (dist[a.u,a.v] = a.metric)
    end
    for k in 1:n, i in 1:n, j in 1:n
        dist[i,j] = min(dist[i,j], dist[i,k]+dist[k,j])
    end
    r = zeros(n,n,m)
    for target in 1:n
        # Strictly positive metrics make the shortest-path forwarding graph acyclic.
        order = sortperm(dist[:,target], rev=true)
        outgoing = [[k for (k,a) in enumerate(data.arcs)
                     if active[k] && a.u == u && isfinite(dist[u,target]) &&
                        isapprox(a.metric+dist[a.v,target],dist[u,target]; atol=1e-8, rtol=1e-12)] for u in 1:n]
        suffix = zeros(n); suffix[target] = 1
        for u in reverse(order)
            u == target && continue
            suffix[u] = sum((suffix[data.arcs[k].v] for k in outgoing[u]); init=0.0)
        end
        for source in 1:n
            (source == target || !isfinite(dist[source,target])) && continue
            flow = zeros(n); flow[source] = 1
            for u in order
                isempty(outgoing[u]) && continue
                for k in outgoing[u]
                    v = data.arcs[k].v
                    fraction = mode == :ecmp ? 1/length(outgoing[u]) : suffix[v]/suffix[u]
                    amount = flow[u]*fraction
                    r[source,target,k] += amount
                    flow[v] += amount
                end
            end
            @assert isapprox(flow[target],1; atol=1e-8)
        end
    end
    return (; dist, r, active)
end

"""Feasible period-0 starting solution: one direct node segment per demand.
This uses default shortest-path forwarding, not necessarily a physical direct arc.
Returns nothing if the data do not support this starting solution.
"""
function nominal_start(data, coefficients)
    data.maxseg >= 1 || return nothing
    n, m = length(data.ids), length(data.arcs)
    loads = zeros(m)
    for demand in data.demands
        demand.s != demand.target || return nothing
        isfinite(coefficients.dist[demand.s,demand.target]) || return nothing
        for a in 1:m
            loads[a] += demand.volume[1] * coefficients.r[demand.s,demand.target,a]
        end
    end
    active_arcs = findall(coefficients.active)
    isempty(active_arcs) && return nothing
    all(isfinite, loads) || error("Non-finite no-waypoint traffic")
    all(abs(loads[a]) <= 1e-8 for a in 1:m if !coefficients.active[a]) ||
        error("No-waypoint start uses an inactive arc")
    mlu = maximum(loads[a] / data.arcs[a].capacity for a in active_arcs)
    # Source and unused nodes have order zero, target has order one.
    # Each selected source-target segment satisfies the order constraint;
    # all unselected segments satisfy its big-M relaxation for n >= 2.
    return (; mlu, loads)
end

"""Joint-period MILP baseline: minimize maximum link utilization.
Degree and order constraints enforce simple paths in segment space.
"""
function solve_mlu(data; periods=[0], limit=1800.0, seed=1, threads=1, mode=:path_uniform, max_variables=1_000_000, warm_start=true)
    periods == collect(0:maximum(periods)) || error("Periods must be consecutive from 0")
    maximum(periods) < data.periods || error("Missing time slots")
    n, nd = length(data.ids), length(data.demands)
    estimate = nd * length(periods) * n * (n-1)
    estimate <= max_variables || error("Dense baseline needs approximately $estimate binary variables; exceeds guard $max_variables. Use a smaller instance or redesign the formulation.")
    preprocess_seconds = @elapsed coeff = Dict(t => forwarding(data,t; mode) for t in periods)
    build_started = time_ns()
    model = Model(HiGHS.Optimizer)
    set_time_limit_sec(model,limit)
    set_optimizer_attribute(model,"random_seed",seed)
    set_optimizer_attribute(model,"threads",threads)
    @variable(model,U >= 0)
    keys = [(d,t,i,j) for d in 1:nd for t in periods for i in 1:n for j in 1:n
            if i != j && isfinite(coeff[t].dist[i,j])]
    keyset = Set(keys)
    by_dt = Dict((d,t) => NTuple{4,Int}[] for d in 1:nd for t in periods)
    by_t = Dict(t => NTuple{4,Int}[] for t in periods)
    for k in keys
        push!(by_dt[(k[1],k[2])],k)
        push!(by_t[k[2]],k)
    end
    @variable(model,x[keys],Bin)
    @variable(model,0 <= position[1:nd,periods,1:n] <= n-1)
    for d in 1:nd, t in periods
        source, target = data.demands[d].s, data.demands[d].target
        fix(position[d,t,source],0; force=true)
        for i in 1:n
            out = sum((x[(d,t,i,j)] for j in 1:n if (d,t,i,j) in keyset); init=0.0)
            inc = sum((x[(d,t,j,i)] for j in 1:n if (d,t,j,i) in keyset); init=0.0)
            @constraint(model,out-inc == (i == source ? 1 : i == target ? -1 : 0))
            @constraint(model,out <= (i == target ? 0 : 1))
            @constraint(model,inc <= (i == source ? 0 : 1))
        end
        @constraint(model,sum(x[k] for k in by_dt[(d,t)]) <= data.maxseg)
    end
    for k in keys
        d,t,i,j = k
        @constraint(model,position[d,t,j] >= position[d,t,i]+1-n*(1-x[k]))
    end
    for t in periods, (aidx,a) in enumerate(data.arcs)
        coeff[t].active[aidx] || continue
        @constraint(model,sum(data.demands[k[1]].volume[t+1]*coeff[t].r[k[3],k[4],aidx]*x[k]
                              for k in by_t[t] if coeff[t].r[k[3],k[4],aidx]>0) <= a.capacity*U)
    end
    for t in periods[2:end]
        haskey(data.budget,t) || error("Missing budget for period $t")
        changes = AffExpr(0.0)
        for d in 1:nd, i in 1:n, j in 1:n
            i == j && continue
            now = (d,t,i,j) in keyset ? x[(d,t,i,j)] : 0.0
            prev = (d,t-1,i,j) in keyset ? x[(d,t-1,i,j)] : 0.0
            z = @variable(model,lower_bound=0)
            @constraint(model,z >= now-prev)
            @constraint(model,z >= prev-now)
            add_to_expression!(changes,z)
        end
        @constraint(model,changes <= data.budget[t])
    end
    @objective(model,Min,U)
    # Keep this first improvement focused on the nominal period-0 model.
    start = periods == [0] ? nominal_start(data,coeff[0]) : nothing
    start_applied = warm_start && start !== nothing
    if start_applied
        for k in keys
            d,t,i,j = k
            demand = data.demands[d]
            set_start_value(x[k], (i == demand.s && j == demand.target) ? 1.0 : 0.0)
        end
        for d in 1:nd, i in 1:n
            set_start_value(position[d,0,i], i == data.demands[d].target ? 1.0 : 0.0)
        end
        set_start_value(U,start.mlu)
        println("No-waypoint MIP start supplied; MLU = ",start.mlu)
    end
    build_seconds = (time_ns()-build_started)/1e9
    elapsed = @elapsed optimize!(model)
    result = Dict{String,Any}("objective_kind"=>"MLU baseline (not full lexicographic)",
        "forwarding"=>string(mode),"periods"=>periods,"seed"=>seed,"threads"=>threads,
        "nodes"=>n,"arcs"=>length(data.arcs),"demands"=>nd,
        "termination_status"=>string(termination_status(model)),"optimize_elapsed_seconds"=>elapsed,
        "time_limit_seconds"=>limit,"solver"=>"HiGHS",
        "implementation_version"=>"mlu-warmstart-v1",
        "warm_start_requested"=>warm_start,"warm_start_supplied"=>start_applied,
        "no_waypoint_mlu"=>(start === nothing ? nothing : start.mlu),
        "julia_version"=>string(VERSION),"solver_version"=>string(MOI.get(model,MOI.SolverVersion())),
        "machine"=>Sys.MACHINE,"cpu"=>Sys.cpu_info()[1].model,
        "preprocess_seconds"=>preprocess_seconds,"build_seconds"=>build_seconds,
        "binary_variables"=>length(keys),"total_variables"=>num_variables(model))
    # Solver clock and the outer optimize! clock need not cover identical work.
    result["solver_reported_seconds"] = try solve_time(model) catch; nothing end
    result["primal_status"] = string(primal_status(model))
    result["raw_status"] = raw_status(model)
    result["best_bound"] = try objective_bound(model) catch; nothing end
    result["best_bound"] = result["best_bound"] isa Real && isfinite(result["best_bound"]) ? result["best_bound"] : nothing
    result["bb_nodes"] = try MOI.get(model,MOI.NodeCount()) catch; nothing end
    if has_values(model) && primal_status(model) == MOI.FEASIBLE_POINT
        objective = objective_value(model)
        result["objective"] = objective
        bound = result["best_bound"]
        result["gap"] = bound !== nothing && isfinite(bound) && objective > 0 ? 1-bound/objective : nothing
        routes = Any[]
        recomputed = 0.0
        selected = Dict{Tuple{Int,Int},Set{Tuple{Int,Int}}}()
        for t in periods
            loads = zeros(length(data.arcs))
            for d in 1:nd
                edges = Set((k[3],k[4]) for k in by_dt[(d,t)] if value(x[k])>0.5)
                selected[(d,t)] = edges
                path = [data.demands[d].s]
                while last(path) != data.demands[d].target
                    nxt = [j for (i,j) in edges if i == last(path)]
                    @assert length(nxt)==1 && length(path)<=data.maxseg
                    @assert nxt[1] ∉ path
                    push!(path,nxt[1])
                end
                @assert length(edges)==length(path)-1 <= data.maxseg
                for (i,j) in edges
                    loads .+= data.demands[d].volume[t+1] .* coeff[t].r[i,j,:]
                end
                push!(routes,Dict("d"=>d-1,"t"=>t,"w"=>data.ids[path[2:end-1]]))
            end
            @assert all(abs(loads[k])<1e-8 for k in eachindex(loads) if !coeff[t].active[k])
            recomputed = max(recomputed,maximum(loads[k]/a.capacity for (k,a) in enumerate(data.arcs) if coeff[t].active[k]))
        end
        for t in periods[2:end]
            used = sum(length(symdiff(selected[(d,t)],selected[(d,t-1)])) for d in 1:nd)
            @assert used <= data.budget[t]
            result["budget_used_$(t)"] = used
        end
        @assert isapprox(recomputed,objective;atol=1e-5,rtol=1e-5)
        result["recomputed_mlu"] = recomputed
        result["srpaths"] = routes
        result["validation"] = "passed: segment paths, maxSeg, active arcs, budget, MLU"
    else
        result["objective"] = nothing
        result["gap"] = nothing
        result["validation"] = "no solver-confirmed feasible incumbent available; supplied start is not counted as an incumbent"
    end
    return result
end
end