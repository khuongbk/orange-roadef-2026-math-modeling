### A Pluto.jl notebook ###
# v0.20.0
using Markdown
using InteractiveUtils

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281001
md"""# Orange — first verified pipeline
Open this notebook with Pluto installed in your Julia environment.
Default: load data and compute period-0 forwarding. Enable the solve only after tests pass.
The objective is an MLU baseline; see docs/decisions.md.
"""

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281002
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,".."))
    include(joinpath(@__DIR__,"..","src","OrangeASR.jl"))
    using .OrangeASR
end

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281003
instance_prefix = joinpath(@__DIR__,"..","data","raw","SetA","setA-01")

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281004
data = OrangeASR.load_instance(instance_prefix)

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281005
coefficients_t0 = OrangeASR.forwarding(data,0;mode=:path_uniform)

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281006
run_solver = false

# ╔═╡ c1a0caaf-56b2-44d6-8d20-3d0819281007
result = run_solver ? OrangeASR.solve_mlu(data;limit=60.0,mode=:path_uniform) : "Solver disabled"

# ╔═╡ Cell order:
# ╟─c1a0caaf-56b2-44d6-8d20-3d0819281001
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281002
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281003
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281004
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281005
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281006
# ╠═c1a0caaf-56b2-44d6-8d20-3d0819281007
