include(joinpath(@__DIR__,"..","src","OrangeASR.jl"))
using .OrangeASR, JSON3
prefix = length(ARGS)>=1 ? ARGS[1] : joinpath(@__DIR__,"..","data","raw","SetA","setA-01")
length(ARGS)>=2 && !(ARGS[2] in ("single","two")) && error("Use single or two")
periods = length(ARGS)>=2 && ARGS[2]=="two" ? [0,1] : [0]
limit = length(ARGS)>=3 ? parse(Float64,ARGS[3]) : (length(periods)==1 ? 1800.0 : 3600.0)
seed = length(ARGS)>=4 ? parse(Int,ARGS[4]) : 1
mode = length(ARGS)>=5 ? Symbol(ARGS[5]) : :path_uniform
output = length(ARGS)>=6 ? ARGS[6] : joinpath(@__DIR__,"..","results","raw","$(basename(prefix))-$(length(periods))period-seed$(seed)-$(mode).json")
started = time()
result = OrangeASR.solve_mlu(OrangeASR.load_instance(prefix);periods,limit,seed,mode)
result["instance"] = basename(prefix)
result["end_to_end_seconds"] = time()-started
mkpath(dirname(abspath(output)))
open(output*".tmp","w") do io; JSON3.pretty(io,result); end
mv(output*".tmp",output;force=true)
println("Saved: ",output)
