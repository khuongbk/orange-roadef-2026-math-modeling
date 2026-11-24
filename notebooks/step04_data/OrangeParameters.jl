module OrangeParameters
using JSON3,SHA
include("OrangeR.jl")
export load_parameters, summary, check_reference, export_evidence, selftest, r, load_coefficient

"""Period-0 model Data from net, tm and scenario JSON. No solver is loaded.
Original node/link/demand IDs are retained. Numeric parameters are exact rationals.
"""
function load_parameters(prefix)
    filenames=Dict(s=>abspath(prefix*"-"*s*".json") for s in ("net","tm","scenario"))
    all(isfile(p) for p in values(filenames)) || error("Missing one of net/tm/scenario JSON files")
    net=JSON3.read(read(filenames["net"],String))
    tm=JSON3.read(read(filenames["tm"],String))
    sc=JSON3.read(read(filenames["scenario"],String))
    R0=OrangeR.prepare(filenames["net"])
    horizon=Int(tm.num_time_slots);horizon>=1 || error("num_time_slots must be positive")
    c=Dict(Int(a.id)=>OrangeR.decimal(a.capacity) for a in net.links)
    all(x>0 for x in values(c)) || error("Capacity must be positive")
    MaxSeg=Int(sc.max_segments);MaxSeg>=1 || error("MaxSeg must be positive")
    demands=[(id=k-1,source=Int(q.s),target=Int(q.t)) for (k,q) in enumerate(tm.demands)]
    isempty(demands) && error("Empty traffic matrix")
    v=Dict{Tuple{Int,Int},Rational{BigInt}}()
    for (k,q) in enumerate(tm.demands)
        d=demands[k]
        haskey(R0.idx,d.source) && haskey(R0.idx,d.target) && d.source!=d.target || error("Invalid demand endpoints")
        length(q.v)==horizon || error("Wrong traffic-vector length")
        traffic_values=OrangeR.decimal.(q.v)
        all(x>=0 for x in traffic_values) || error("Negative traffic")
        v[(d.id,0)]=traffic_values[1]
        R0.sigma[R0.idx[d.source],R0.idx[d.target]]>0 || error("Unreachable period-0 demand $(d.id)")
    end
    # Preserve later-period information but do not apply it in the period-0 model.
    down=Dict(t=>Set{Int}() for t in 0:horizon-1)
    for q in sc.interventions
        t=Int(q.t);0<=t<horizon || error("Invalid intervention period")
        union!(down[t],Int.(q.links))
    end
    isempty(down[0]) || error("Period 0 must have no intervention")
    arc_ids=Set(keys(c))
    all(issubset(a,arc_ids) for a in values(down)) || error("Unknown down-link ID")
    budget=Dict(Int(q.t)=>Int(q.value) for q in sc.budget)
    length(budget)==length(sc.budget) || error("Duplicate budget period")
    all(0<t<horizon && b>=0 for (t,b) in budget) || error("Invalid budget")
    omega=Dict(a.id=>a.weight//R0.scale for a in R0.arcs)
    hashes=Dict(s=>bytes2hex(sha256(read(p))) for (s,p) in filenames)
    (;instance=basename(prefix),period=0,V=R0.ids,A=[a.id for a in R0.arcs],demands,c,v,MaxSeg,omega,R0,horizon,down,budget,filenames,hashes)
end

r(D,i,j,a,t=0)=OrangeR.r(D.R0,i,j,a,t)
function load_coefficient(D,d,i,j,a)
    D.v[(d,0)]*r(D,i,j,a,0)/D.c[a]
end

function summary(D)
    Dict("instance"=>D.instance,"period"=>0,"vertices"=>length(D.V),"links"=>length(D.A),
        "demands"=>length(D.demands),"MaxSeg"=>D.MaxSeg,
        "total_traffic_period0"=>string(sum(values(D.v))),"source_files"=>D.filenames,
        "input_sha256"=>D.hashes,"budget_constraint_in_period0"=>false,
        "forwarding"=>"path_uniform per calculating_r.pdf",
        "r_representation"=>"exact on-demand from all-pairs distances/counts; no dense 4D tensor",
        "scope"=>"Data only; no optimization or experiment runs")
end

function check_reference(D,path)
    ref=JSON3.read(read(path,String));checks=0
    @assert D.instance==ref.instance
    @assert length(D.V)==ref.vertices && length(D.A)==ref.links && length(D.demands)==ref.demands
    @assert D.MaxSeg==ref.MaxSeg
    @assert D.V==Int.(ref.vertex_ids)
    for s in ("net","tm","scenario");@assert D.hashes[s]==ref.input_sha256[s];end
    parse_fraction(s)=begin
        z=split(string(s),'/');length(z)==1 ? parse(BigInt,z[1])//big(1) : parse(BigInt,z[1])//parse(BigInt,z[2])
    end
    for q in ref.capacities
        @assert D.c[Int(q.arc_id)]==parse_fraction(q.value)
        @assert D.omega[Int(q.arc_id)]==parse_fraction(q.metric)
        checks+=1
    end
    for q in ref.traffic
        d=D.demands[Int(q.d)+1]
        @assert d.source==q.source && d.target==q.target
        @assert D.v[(Int(q.d),0)]==parse_fraction(q.value)
        checks+=1
    end
    for q in ref.r_probes
        @assert r(D,Int(q.i),Int(q.j),Int(q.arc_id),0)==parse_fraction(q.value)
        @assert load_coefficient(D,0,Int(q.i),Int(q.j),Int(q.arc_id))==parse_fraction(q.load_coefficient_d0)
        checks+=1
    end
    (;status="PASSED",capacity_and_metric_checks=length(ref.capacities),
        demand_and_traffic_checks=length(ref.traffic),r_and_normalized_load_checks=length(ref.r_probes),checks)
end

function export_evidence(D;folder=joinpath(@__DIR__,"results","step04"))
    mkpath(folder);base=joinpath(folder,D.instance)
    report=summary(D);report["julia_version"]=string(VERSION)
    report["validation"]="Input schema, positive capacities/metrics, valid demand endpoints/traffic, period-0 reachability and no period-0 intervention checked"
    open(base*"-data-summary.json","w") do io;JSON3.pretty(io,report);end
    open(base*"-capacity.csv","w") do io
        println(io,"arc_id,from,to,metric_numerator,metric_denominator,capacity_numerator,capacity_denominator")
        for a in D.R0.arcs
            metric=D.omega[a.id];capacity=D.c[a.id]
            println(io,join((a.id,D.V[a.u],D.V[a.v],numerator(metric),denominator(metric),numerator(capacity),denominator(capacity)),','))
        end
    end
    open(base*"-traffic0.csv","w") do io
        println(io,"d,source,target,period,traffic_numerator,traffic_denominator")
        for d in D.demands
            value=D.v[(d.id,0)]
            println(io,join((d.id,d.source,d.target,0,numerator(value),denominator(value)),','))
        end
    end
    (;status="SAVED",folder,summary_file=base*"-data-summary.json",capacity_file=base*"-capacity.csv",traffic_file=base*"-traffic0.csv")
end

function selftest()
    mktempdir() do dir
        prefix=joinpath(dir,"toy")
        net=Dict("directed"=>true,"nodes"=>[Dict("id"=>10),Dict("id"=>20)],"links"=>[Dict("id"=>100,"from"=>10,"to"=>20,"metric"=>0.1,"capacity"=>2.5)])
        tm=Dict("num_time_slots"=>2,"demands"=>[Dict("s"=>10,"t"=>20,"v"=>[7.5,99.0])])
        sc=Dict("max_segments"=>6,"interventions"=>[Dict("t"=>1,"links"=>[100])],"budget"=>[Dict("t"=>1,"value"=>3)])
        write_json(s,obj)=open(prefix*"-"*s*".json","w") do io;JSON3.write(io,obj);end
        write_json("net",net);write_json("tm",tm);write_json("scenario",sc)
        D=load_parameters(prefix)
        @assert D.c[100]==big(5)//big(2)
        @assert D.v[(0,0)]==big(15)//big(2) # Not 99 from the second period.
        @assert D.MaxSeg==6 && isempty(D.down[0]) && D.down[1]==Set([100])
        @assert r(D,10,20,100)==1 && load_coefficient(D,0,10,20,100)==3
        tm["demands"][1]["v"]=[-1.0,99.0];write_json("tm",tm)
        rejected=false
        try;load_parameters(prefix);catch;rejected=true;end
        @assert rejected
        true
    end
end
end
