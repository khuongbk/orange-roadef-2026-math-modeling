### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# ╔═╡ 431cb550-d52d-4d54-8c21-7ca44fe9fcbd
using JSON3

# ╔═╡ c54ebb99-8b20-4b64-a4b0-af2568f1b276
DataModule = include(joinpath(@__DIR__, "OrangeParameters.jl"))

# ╔═╡ 99f1d2f2-8989-4d65-ac0b-4106d3ee66c9
md"""
# Step 4 — Data from three JSON files, period 0
This notebook supplies r(i,j,a,0), c(a), v(d,0), MaxSeg and valid original IDs.
It reuses the exact OrangeR computation validated in Step 3. No solver runs.
"""

# ╔═╡ 2fd45647-a57b-4280-84e4-c637db438f79
instance_prefix = joinpath(@__DIR__, "data", "setA-14")

# ╔═╡ be965086-2552-47ef-b4c2-68844614f808
data_selftest_passed = DataModule.selftest()

# ╔═╡ f799b466-060f-42f1-be90-9c483da516d0
D0 = DataModule.load_parameters(instance_prefix)

# ╔═╡ 0e8880a3-4963-46be-aba3-bdb875443fb9
data_summary = DataModule.summary(D0)

# ╔═╡ 3a097b50-ac3b-4b34-8963-c8cd781d78ea
begin
    c = D0.c
    v = D0.v
    MaxSeg = D0.MaxSeg
end

# ╔═╡ c310aa9e-0409-4a74-8b83-fdfcfa0639a3
parameter_preview = (
    capacities = [(arc_id=a, capacity=D0.c[a]) for a in D0.A[1:min(5,length(D0.A))]],
    traffic = [(d=d.id, source=d.source, target=d.target, volume=D0.v[(d.id,0)]) for d in D0.demands[1:min(5,length(D0.demands))]],
    MaxSeg = D0.MaxSeg,
)

# ╔═╡ 251055f3-7c99-44ed-8085-a96401255d50
r0(i,j,a) = DataModule.r(D0,i,j,a,0)

# ╔═╡ 7306f739-3198-49c0-b0ff-a99b96ef98a5
r_example = DataModule.OrangeR.example(D0.R0)

# ╔═╡ 32560431-4b01-427d-b401-1ac1512f3615
data_reference_check = DataModule.check_reference(D0, joinpath(@__DIR__, "reference", "setA-14-parameters.json"))

# ╔═╡ 81b3c2ee-af02-4067-b29a-673f3fa18c46
data_evidence = DataModule.export_evidence(D0)

# ╔═╡ 695cf7b7-a354-454d-92b6-3ff6951eeffb
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
# ╟─99f1d2f2-8989-4d65-ac0b-4106d3ee66c9
# ╠═431cb550-d52d-4d54-8c21-7ca44fe9fcbd
# ╠═c54ebb99-8b20-4b64-a4b0-af2568f1b276
# ╠═2fd45647-a57b-4280-84e4-c637db438f79
# ╠═be965086-2552-47ef-b4c2-68844614f808
# ╠═f799b466-060f-42f1-be90-9c483da516d0
# ╠═0e8880a3-4963-46be-aba3-bdb875443fb9
# ╠═3a097b50-ac3b-4b34-8963-c8cd781d78ea
# ╠═c310aa9e-0409-4a74-8b83-fdfcfa0639a3
# ╠═251055f3-7c99-44ed-8085-a96401255d50
# ╠═7306f739-3198-49c0-b0ff-a99b96ef98a5
# ╠═32560431-4b01-427d-b401-1ac1512f3615
# ╠═81b3c2ee-af02-4067-b29a-673f3fa18c46
# ╟─695cf7b7-a354-454d-92b6-3ff6951eeffb
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
