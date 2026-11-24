### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# ╔═╡ ef7ff4fe-a7f1-41d6-9aa4-b49185ea0bf3
using JSON3

# ╔═╡ 01e106eb-7bfb-4e74-8aa8-9f178a000ea1
DataModule = include(joinpath(@__DIR__, "OrangeParameters.jl"))

# ╔═╡ 3ff77862-fb55-4559-81ce-e921e4c84396
md"""
# Step 4 — Data from three JSON files, period 0
This notebook supplies r(i,j,a,0), c(a), v(d,0), MaxSeg and valid original IDs.
It reuses the exact OrangeR computation validated in Step 3. No solver runs.
"""

# ╔═╡ a960a838-ea48-41de-bd05-acc56e0731c7
instance_prefix = joinpath(@__DIR__, "data", "setA-09")

# ╔═╡ 0ba903bf-1620-4ece-9600-320a1b22f585
data_selftest_passed = DataModule.selftest()

# ╔═╡ 99d485cb-4784-498e-a455-a1fbf094f75a
D0 = DataModule.load_parameters(instance_prefix)

# ╔═╡ 34df4064-5052-459e-8af6-76c5c59878d1
data_summary = DataModule.summary(D0)

# ╔═╡ cee4e652-139c-45b4-b66a-6961b9dc2cde
begin
    c = D0.c
    v = D0.v
    MaxSeg = D0.MaxSeg
end

# ╔═╡ 508d42c9-037d-44fb-9e77-7e1e0eaead27
parameter_preview = (
    capacities = [(arc_id=a, capacity=D0.c[a]) for a in D0.A[1:min(5,length(D0.A))]],
    traffic = [(d=d.id, source=d.source, target=d.target, volume=D0.v[(d.id,0)]) for d in D0.demands[1:min(5,length(D0.demands))]],
    MaxSeg = D0.MaxSeg,
)

# ╔═╡ 8b34ba63-7770-49c6-8504-0ef906aa10cd
r0(i,j,a) = DataModule.r(D0,i,j,a,0)

# ╔═╡ 74cecfde-7684-4c8c-9bfd-c3e7e314d159
r_example = DataModule.OrangeR.example(D0.R0)

# ╔═╡ 59c8da9e-0e01-4d3c-9621-e2fdd4ab89f6
data_reference_check = DataModule.check_reference(D0, joinpath(@__DIR__, "reference", "setA-09-parameters.json"))

# ╔═╡ 60701fbc-0417-4867-837e-5dbca97baa15
data_evidence = DataModule.export_evidence(D0)

# ╔═╡ 43eaf89d-1dbc-4df2-9e78-1ffaf8f2f6b2
md"""
Completion checks: `data_selftest_passed == true`,
`data_reference_check.status == "PASSED"`, and `data_evidence.status == "SAVED"`.
`c[a]` is capacity, `v[(d,0)]` is traffic, and `MaxSeg` is the segment bound.
Use original node/link IDs for `r0(i,j,a)`. Demand IDs start at zero.
The period-0 data retain later-period interventions/budgets but do not apply them.
Export this notebook to HTML for evidence. Generated Data CSV/JSON are saved
under `results/step04/` in this extracted folder. Optimization starts at Step 5.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

[compat]
JSON3 = "~1.14.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.13.2"
manifest_format = "2.1"
project_hash = "5aab0f42118bacadc71e4cbcafd918308498c600"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "411eccfe8aba0814ffa0fdf4860913ed09c34975"
registries = "General"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.3"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "ba0dc8a8a67cacac4842631f960c046e4e563675"
registries = "General"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.8"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
registries = "General"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "aef1987d90dcc2e2cbd919ad10b2d25bcce4f418"
registries = "General"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.6.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "1.0.0"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "fd6a55e88450cb4256e49103a5a243f065c7b781"
registries = "General"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[registries.General]
url = "https://github.com/JuliaRegistries/General.git"
uuid = "23338594-aafe-5451-b93e-139f81909106"
"""

# ╔═╡ Cell order:
# ╟─3ff77862-fb55-4559-81ce-e921e4c84396
# ╠═ef7ff4fe-a7f1-41d6-9aa4-b49185ea0bf3
# ╠═01e106eb-7bfb-4e74-8aa8-9f178a000ea1
# ╠═a960a838-ea48-41de-bd05-acc56e0731c7
# ╠═0ba903bf-1620-4ece-9600-320a1b22f585
# ╠═99d485cb-4784-498e-a455-a1fbf094f75a
# ╠═34df4064-5052-459e-8af6-76c5c59878d1
# ╠═cee4e652-139c-45b4-b66a-6961b9dc2cde
# ╠═508d42c9-037d-44fb-9e77-7e1e0eaead27
# ╠═8b34ba63-7770-49c6-8504-0ef906aa10cd
# ╠═74cecfde-7684-4c8c-9bfd-c3e7e314d159
# ╠═59c8da9e-0e01-4d3c-9621-e2fdd4ab89f6
# ╠═60701fbc-0417-4867-837e-5dbca97baa15
# ╟─43eaf89d-1dbc-4df2-9e78-1ffaf8f2f6b2
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
