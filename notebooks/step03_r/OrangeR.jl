module OrangeR
using JSON3
export prepare, r, ratios, example, summary, export_evidence, selftest

function decimal(x)
    s=split(lowercase(string(x)),'e'); exponent=length(s)==2 ? parse(Int,s[2]) : 0
    m=split(s[1],'.');fraction=length(m)==2 ? m[2] : ""
    numerator=parse(BigInt,m[1]*fraction);scale=length(fraction)-exponent
    scale>=0 ? numerator//big(10)^scale : numerator*big(10)^(-scale)//big(1)
end

"""Read net JSON, preserve each physical arc ID, including parallel arcs.
Integer scaling of exact decimal metrics makes shortest-path equality exact.
"""
function prepare(filename)
    net=JSON3.read(read(filename,String))
    Bool(net.directed) || error("A directed network is required")
    ids=Int[q.id for q in net.nodes];n=length(ids)
    idx=Dict(id=>k for (k,id) in enumerate(ids));n==length(idx)>0 || error("Duplicate/empty node IDs")
    metrics=[decimal(q.metric) for q in net.links]
    all(w>0 for w in metrics) || error("Strictly positive metrics required")
    scale=foldl(lcm,(denominator(w) for w in metrics);init=big(1))
    arcs=[(id=Int(a.id),u=idx[Int(a.from)],v=idx[Int(a.to)],weight=numerator(metrics[k]*scale)) for (k,a) in enumerate(net.links)]
    length(unique(a.id for a in arcs))==length(arcs) || error("Duplicate link ID")
    outgoing=[Int[] for _ in ids]
    for (k,a) in enumerate(arcs);push!(outgoing[a.u],k);end
    distances=Matrix{Union{Nothing,BigInt}}(undef,n,n);fill!(distances,nothing)
    sigma=fill(big(0),n,n)
    for source in 1:n
        dist=Vector{Union{Nothing,BigInt}}(undef,n);fill!(dist,nothing)
        count=fill(big(0),n);visited=falses(n)
        dist[source]=big(0);count[source]=big(1)
        for _ in 1:n
            u=0
            for v in 1:n
                if !visited[v] && dist[v]!==nothing && (u==0 || dist[v]<dist[u]);u=v;end
            end
            u==0 && break
            visited[u]=true
            for k in outgoing[u]
                a=arcs[k];v=a.v;candidate=dist[u]+a.weight
                if dist[v]===nothing || candidate<dist[v]
                    dist[v]=candidate;count[v]=count[u]
                elseif candidate==dist[v]
                    count[v]+=count[u]
                end
            end
        end
        distances[source,:]=dist;sigma[source,:]=count
    end
    (;ids,idx,arcs,scale,distances,sigma,n)
end

function ratios(R,i_original,j_original)
    i=R.idx[i_original];j=R.idx[j_original]
    R.sigma[i,j]>0 || error("Unreachable segment ($i_original,$j_original); exclude it from the model")
    result=Dict{Int,Rational{BigInt}}()
    i==j && return result
    for a in R.arcs
        left=R.distances[i,a.u];right=R.distances[a.v,j]
        if left!==nothing && right!==nothing && left+a.weight+right==R.distances[i,j]
            result[a.id]=(R.sigma[i,a.u]*R.sigma[a.v,j])//R.sigma[i,j]
        end
    end
    result
end

function r(R,i,j,a,t=0)
    t==0 || error("Step 3 computes period 0 only")
    any(q.id==a for q in R.arcs) || error("Unknown physical arc ID")
    get(ratios(R,i,j),a,big(0)//big(1))
end

function summary(R)
    Dict("period"=>0,"vertices"=>R.n,"links"=>length(R.arcs),
        "reachable_ordered_pairs"=>count(>(0),R.sigma)-R.n,
        "unreachable_ordered_pairs"=>count(==(0),R.sigma),
        "pairs_with_multiple_shortest_paths"=>count(>(1),R.sigma),
        "maximum_shortest_path_count"=>string(maximum(R.sigma)),
        "forwarding"=>"path_uniform per calculating_r.pdf",
        "arithmetic"=>"exact decimal metrics, BigInt distances/counts, Rational{BigInt} coefficients")
end

function example(R)
    pair=nothing;best=big(-1)
    for i in 1:R.n,j in 1:R.n
        if i!=j && R.sigma[i,j]>best && R.sigma[i,j]>0;pair=(i,j);best=R.sigma[i,j];end
    end
    pair===nothing && error("No reachable distinct node pair")
    i,j=pair;rs=ratios(R,R.ids[i],R.ids[j])
    (;origin=R.ids[i],target=R.ids[j],shortest_path_count=R.sigma[i,j],
        distance=R.distances[i,j]//R.scale,
        coefficients=[(arc_id=a,ratio=q) for (a,q) in sort(collect(rs);by=first)])
end

function check_pair(R,i,j,rs)
    balance=fill(big(0)//big(1),R.n);length_sum=big(0)//big(1)
    for a in R.arcs
        q=get(rs,a.id,big(0)//big(1));0<=q<=1 || error("Invalid r")
        balance[a.u]+=q;balance[a.v]-=q;length_sum+=q*a.weight
    end
    for v in 1:R.n
        balance[v]==(v==i ? 1 : v==j ? -1 : 0) || error("Flow conservation failed")
    end
    length_sum==R.distances[i,j] || error("Weighted shortest distance failed")
    true
end

"""Save evidence; full=false saves all distances/counts and one coefficient example.
full=true additionally exports every NONZERO coefficient for every ordered pair.
Missing coefficient rows mean zero ONLY for reachable segments.
"""
function export_evidence(R,filename;full=false)
    folder=joinpath(dirname(abspath(filename)),"results","step03");mkpath(folder)
    tag=replace(basename(filename),r"-net\.json$"=>"")
    report=summary(R);report["instance"]=tag;report["julia_version"]=string(VERSION)
    report["full_coefficients_exported"]=full
    open(joinpath(folder,tag*"-shortest-data.csv"),"w") do io
        println(io,"i,j,reachable,distance,sigma")
        for i in 1:R.n,j in 1:R.n
            i==j && continue
            distance=R.distances[i,j]===nothing ? "" : string(R.distances[i,j]//R.scale)
            println(io,join((R.ids[i],R.ids[j],R.sigma[i,j]>0,distance,R.sigma[i,j]),','))
        end
    end
    ex=example(R);i=R.idx[ex.origin];j=R.idx[ex.target]
    check_pair(R,i,j,ratios(R,ex.origin,ex.target))
    open(joinpath(folder,tag*"-r-example.csv"),"w") do io
        println(io,"i,j,arc_id,r_numerator,r_denominator")
        for q in ex.coefficients
            println(io,join((ex.origin,ex.target,q.arc_id,numerator(q.ratio),denominator(q.ratio)),','))
        end
    end
    if full
        entries=0;pairs_checked=0
        open(joinpath(folder,tag*"-r0-nonzero.csv"),"w") do io
            println(io,"i,j,arc_id,r_numerator,r_denominator")
            for i in 1:R.n,j in 1:R.n
                (i==j || R.sigma[i,j]==0) && continue
                rs=ratios(R,R.ids[i],R.ids[j]);check_pair(R,i,j,rs);pairs_checked+=1
                for (a,q) in sort(collect(rs);by=first)
                    println(io,join((R.ids[i],R.ids[j],a,numerator(q),denominator(q)),','));entries+=1
                end
            end
        end
        report["nonzero_coefficients"]=entries;report["all_reachable_pairs_checked"]=pairs_checked
    end
    open(joinpath(folder,tag*"-r0-summary.json"),"w") do io;JSON3.pretty(io,report);end
    (;folder,report)
end

"""Compare all distances/counts and sample coefficient pairs to independent Python files."""
function check_reference(R,filename)
    tag=replace(basename(filename),r"-net\.json$"=>"")
    folder=joinpath(@__DIR__,"results")
    shortest_file=joinpath(folder,tag*"-shortest-data.csv")
    coefficients_file=joinpath(folder,tag*"-r0-nonzero.csv")
    parse_fraction(s)=begin
        z=split(s,'/');length(z)==1 ? parse(BigInt,z[1])//big(1) : parse(BigInt,z[1])//parse(BigInt,z[2])
    end
    pairs_checked=0;wanted=Set{Tuple{Int,Int}}()
    for line in Iterators.drop(eachline(shortest_file),1)
        fields=split(line,',');i=parse(Int,fields[1]);j=parse(Int,fields[2]);u=R.idx[i];v=R.idx[j]
        @assert (R.sigma[u,v]>0)==(lowercase(fields[3])=="true")
        @assert R.sigma[u,v]==parse(BigInt,fields[5])
        if R.sigma[u,v]>0
            @assert R.distances[u,v]//R.scale==parse_fraction(fields[4])
            length(wanted)<20 && push!(wanted,(i,j))
        end
        pairs_checked+=1
    end
    ex=example(R);push!(wanted,(ex.origin,ex.target))
    expected=Dict(pair=>Dict{Int,Rational{BigInt}}() for pair in wanted)
    for line in Iterators.drop(eachline(coefficients_file),1)
        fields=split(line,',');pair=(parse(Int,fields[1]),parse(Int,fields[2]))
        if pair in wanted
            expected[pair][parse(Int,fields[3])]=parse(BigInt,fields[4])//parse(BigInt,fields[5])
        end
    end
    for ((i,j),rs) in expected;@assert ratios(R,i,j)==rs;end
    (;status="PASSED",distance_and_count_pairs=pairs_checked,coefficient_pairs=length(wanted))
end

function selftest()
    mktempdir() do dir
        # Three equal shortest paths: two start on arc 100; one on arc 101.
        ids=[10,20,40,70,100,150]
        es=[(10,20,1),(10,40,1),(20,70,1),(20,100,1),(70,150,1),(100,150,1),(40,150,2)]
        net=Dict("directed"=>true,"nodes"=>[Dict("id"=>id) for id in ids],"links"=>[Dict("id"=>k+99,"from"=>u,"to"=>v,"metric"=>w) for (k,(u,v,w)) in enumerate(es)])
        filename=joinpath(dir,"toy-net.json")
        open(filename,"w") do io;JSON3.write(io,net);end
        R=prepare(filename)
        @assert R.sigma[R.idx[10],R.idx[150]]==3
        @assert r(R,10,150,100)==big(2)//big(3)
        @assert r(R,10,150,101)==big(1)//big(3)
        @assert R.sigma[R.idx[150],R.idx[10]]==0
        @assert decimal(0.1)+decimal(0.2)==decimal(0.3)
        # Equal-weight parallel arcs remain distinct physical choices.
        net["links"]=Any[Dict("id"=>1,"from"=>10,"to"=>20,"metric"=>1),Dict("id"=>2,"from"=>10,"to"=>20,"metric"=>1)]
        open(filename,"w") do io;JSON3.write(io,net);end
        M=prepare(filename)
        @assert r(M,10,20,1)==big(1)//big(2)
        @assert r(M,10,20,2)==big(1)//big(2)
        true
    end
end
end
