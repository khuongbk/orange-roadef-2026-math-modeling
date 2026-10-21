using Test
include(joinpath(@__DIR__,"..","src","OrangeASR.jl"))
using .OrangeASR
@testset "Forwarding semantics" begin
    edges = [(1,2,1),(2,6,2),(1,3,1),(3,4,1),(4,6,1),(3,5,1),(5,6,1)]
    arcs = [(id=k,u=u,v=v,metric=Float64(w),capacity=1.0) for (k,(u,v,w)) in enumerate(edges)]
    data = (;ids=collect(1:6),arcs,down=Dict(0=>Set{Int}()))
    ec=OrangeASR.forwarding(data,0;mode=:ecmp)
    pu=OrangeASR.forwarding(data,0;mode=:path_uniform)
    @test ec.r[1,6,1] ≈ 0.5
    @test pu.r[1,6,1] ≈ 1/3
end
@testset "Tiny MILP and budget" begin
    # Each direction has one physical arc: exact expected MLU = 4/10.
    data=(;ids=[0,1],arcs=[(id=0,u=1,v=2,metric=1.0,capacity=10.0),(id=1,u=2,v=1,metric=1.0,capacity=10.0)],
        demands=[(s=1,target=2,volume=[4.0,3.0])],down=Dict(0=>Set{Int}(),1=>Set{Int}()),budget=Dict(1=>0),maxseg=2,periods=2)
    result=OrangeASR.solve_mlu(data;limit=10.0)
    @test result["termination_status"] == "OPTIMAL"
    @test result["objective"] ≈ 0.4
    both=OrangeASR.solve_mlu(data;periods=[0,1],limit=10.0)
    @test both["objective"] ≈ 0.4
    @test both["budget_used_1"] == 0
end
