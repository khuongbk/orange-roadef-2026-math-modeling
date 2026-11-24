### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# ╔═╡ 5f2d823b-eee0-49dc-b29f-46269dc516f5
begin
    using JSON3
    using Graphs
    using Multigraphs
    using SparseArrays
end

# ╔═╡ 7f6ddf55-9818-44a4-8ac7-17ff789f8df2
RAPI = include(joinpath(@__DIR__, "OrangeR.jl"))

# ╔═╡ f9b0f7ce-a589-4495-938f-33f03be74d1b
md"""
# JSON multigraph → Julia `DiMultigraph`

This Pluto notebook reads a JSON network file with the same structure as
`setA-14-net.json` and converts it into a directed multigraph.

Expected JSON structure:

- `directed`
- `multigraph`
- `graph`
- `nodes`
- `links`

Each node contains:

- `id`
- `name`

Each link contains:

- `id`
- `from`
- `to`
- `metric`
- `capacity`

Unlike `SimpleDiGraph`, a `DiMultigraph` can represent several parallel
arcs having the same ordered pair of endpoints.
"""

# ╔═╡ 7e277083-f31e-4ddd-891c-1657be9f5ab1
md"""
## Representation

`Multigraphs.jl` stores the multiplicity of an ordered pair of vertices.

The JSON file, however, gives every arc its own `id`, `metric`, and
`capacity`. Therefore these attributes are stored separately, one entry
per JSON arc.

This is important when two parallel arcs have different attributes.
"""

# ╔═╡ 2cda6636-29e9-488a-b3cd-1710aa69af0a
struct MultiNetworkData{G}
    graph::G

    # Node information
    id_to_vertex::Dict{Int, Int}
    vertex_to_id::Vector{Int}
    vertex_name::Vector{String}

    # Arc information: position a = 1,...,m
    link_id::Vector{Int}
    arc_from::Vector{Int}
    arc_to::Vector{Int}
    metric::Vector{Float64}
    capacity::Vector{Float64}

    # Look-up tables
    id_to_arc::Dict{Int, Int}
    pair_to_arcs::Dict{Tuple{Int, Int}, Vector{Int}}
end

# ╔═╡ e68aa8c2-3269-4b3a-8eca-a36fcf2b10a1
md"""
## Conversion function
"""

# ╔═╡ c5650c13-2860-4605-9b84-d0392335053d
function json_to_multigraph(filename::AbstractString)
    data = JSON3.read(read(filename, String))

    # ---------- Check top-level structure ----------
    required_top = ("directed", "multigraph", "nodes", "links")
    missing_top = [k for k in required_top if !haskey(data, k)]

    isempty(missing_top) ||
        error("Missing top-level JSON field(s): $(join(missing_top, ", "))")

    Bool(data["directed"]) ||
        error("This notebook expects a directed multigraph.")

    Bool(data["multigraph"]) ||
        error("The JSON file does not declare multigraph=true.")

    nodes = data["nodes"]
    links = data["links"]

    isempty(nodes) && error("The JSON file contains no nodes.")

    # ---------- Nodes ----------
    for (i, node) in enumerate(nodes)
        haskey(node, "id") ||
            error("Node $i has no 'id' field.")
        haskey(node, "name") ||
            error("Node $i has no 'name' field.")
    end

    vertex_to_id = Int[Int(node["id"]) for node in nodes]

    length(unique(vertex_to_id)) == length(vertex_to_id) ||
        error("Node IDs must be unique.")

    id_to_vertex = Dict(
        json_id => julia_vertex
        for (julia_vertex, json_id) in enumerate(vertex_to_id)
    )

    vertex_name = String[String(node["name"]) for node in nodes]

    # ---------- Directed multigraph ----------
    n = length(nodes)
    g = DiMultigraph(n)

    # ---------- One record per JSON arc ----------
    m = length(links)

    link_id = Vector{Int}(undef, m)
    arc_from = Vector{Int}(undef, m)
    arc_to = Vector{Int}(undef, m)
    metric = Vector{Float64}(undef, m)
    capacity = Vector{Float64}(undef, m)

    id_to_arc = Dict{Int, Int}()
    pair_to_arcs = Dict{Tuple{Int, Int}, Vector{Int}}()

    for (a, link) in enumerate(links)
        for field in ("id", "from", "to", "metric", "capacity")
            haskey(link, field) ||
                error("Link $a has no '$field' field.")
        end

        json_link_id = Int(link["id"])
        from_id = Int(link["from"])
        to_id = Int(link["to"])

        haskey(id_to_arc, json_link_id) &&
            error("Duplicate link ID: $json_link_id")

        haskey(id_to_vertex, from_id) ||
            error("Link $json_link_id refers to unknown node ID $from_id.")

        haskey(id_to_vertex, to_id) ||
            error("Link $json_link_id refers to unknown node ID $to_id.")

        u = id_to_vertex[from_id]
        v = id_to_vertex[to_id]

        # Every call adds one copy of the arc.
        add_edge!(g, u, v)

        link_id[a] = json_link_id
        arc_from[a] = u
        arc_to[a] = v
        metric[a] = Float64(link["metric"])
        capacity[a] = Float64(link["capacity"])

        id_to_arc[json_link_id] = a
        push!(get!(pair_to_arcs, (u, v), Int[]), a)
    end

    return MultiNetworkData(
        g,
        id_to_vertex,
        vertex_to_id,
        vertex_name,
        link_id,
        arc_from,
        arc_to,
        metric,
        capacity,
        id_to_arc,
        pair_to_arcs,
    )
end

# ╔═╡ dbfa58a1-795c-479a-8d81-1aeef7eb3fad
md"""
## Helper functions
"""

# ╔═╡ feadcc8d-0049-4211-aac0-b55c029bd6b8
function arc_attributes(network::MultiNetworkData, a::Int)
    1 <= a <= length(network.link_id) ||
        error("Arc index $a is outside 1:$(length(network.link_id)).")

    u = network.arc_from[a]
    v = network.arc_to[a]

    return (
        arc_index = a,
        id = network.link_id[a],
        from_vertex = u,
        to_vertex = v,
        from_json_id = network.vertex_to_id[u],
        to_json_id = network.vertex_to_id[v],
        metric = network.metric[a],
        capacity = network.capacity[a],
    )
end

# ╔═╡ 51c767b3-ca14-4ce9-97e0-92c0bff724ae
function arc_by_id(network::MultiNetworkData, json_link_id::Int)
    haskey(network.id_to_arc, json_link_id) ||
        error("Unknown JSON link ID $json_link_id.")

    return arc_attributes(
        network,
        network.id_to_arc[json_link_id],
    )
end

# ╔═╡ 3a674046-dfbb-4ca4-9dab-50fa509929d8
function arcs_between(
    network::MultiNetworkData,
    u::Int,
    v::Int,
)
    a = get(network.pair_to_arcs, (u, v), Int[])
    return [arc_attributes(network, k) for k in a]
end

# ╔═╡ dc7846d6-932d-4b3b-ad7e-b956192c3edc
function multiplicity(
    network::MultiNetworkData,
    u::Int,
    v::Int,
)
    return length(get(network.pair_to_arcs, (u, v), Int[]))
end

# ╔═╡ 679d5686-e249-4028-9634-53bbd9b441df
md"""
## Simple Graphs.jl projection

Some Graphs.jl algorithms are naturally formulated on a simple graph.
The following function keeps one directed edge `u → v` whenever at least
one multigraph arc exists from `u` to `v`.
"""

# ╔═╡ 3469e52f-adca-48da-a84f-25d0fbc86a09
function simple_projection(network::MultiNetworkData)
    g = SimpleDiGraph(length(network.vertex_to_id))

    for (u, v) in keys(network.pair_to_arcs)
        add_edge!(g, u, v)
    end

    return g
end

# ╔═╡ 16dd473f-01fb-4b9d-9462-a76bebc3a7f7
md"""
## Matrices for algorithms on the simple projection

For parallel arcs:

- the shortest-path `metric` between `u` and `v` is the minimum metric;
- the total `capacity` between `u` and `v` is the sum of capacities.
"""

# ╔═╡ eac7e670-e435-4ce4-a6c4-4e418962e339
function metric_matrix(network::MultiNetworkData)
    n = length(network.vertex_to_id)

    I = Int[]
    J = Int[]
    V = Float64[]

    for ((u, v), arcs) in network.pair_to_arcs
        push!(I, u)
        push!(J, v)
        push!(V, minimum(network.metric[a] for a in arcs))
    end

    return sparse(I, J, V, n, n)
end

# ╔═╡ eec77268-b7dd-420f-8cc8-6c825805daa5
function capacity_matrix(network::MultiNetworkData)
    n = length(network.vertex_to_id)

    I = Int[]
    J = Int[]
    V = Float64[]

    for ((u, v), arcs) in network.pair_to_arcs
        push!(I, u)
        push!(J, v)
        push!(V, sum(network.capacity[a] for a in arcs))
    end

    return sparse(I, J, V, n, n)
end

# ╔═╡ 42e9e132-3232-4921-9288-bd68be51ee1e
md"""
## Read a JSON file

Put the JSON file in the same directory as this Pluto notebook.
Only the filename below needs to be changed for another instance.
"""

# ╔═╡ d23567dd-d73d-46ef-b87a-669ba42b6f5a
json_file = joinpath(@__DIR__, "setA-14-net.json")

# ╔═╡ af14cfa8-5f98-43cd-9b75-301d9c1a9b53
network = json_to_multigraph(json_file)

# ╔═╡ 8b0f96b8-1cf7-4ff3-82e3-fd12541698e2
mg = network.graph

# ╔═╡ 298a2ab8-7b61-4ad1-841b-faa8e10d6824
begin
    multiplicities = length.(values(network.pair_to_arcs))

    (
        graph_type = typeof(mg),
        number_of_vertices = length(network.vertex_to_id),
        number_of_json_arcs = length(network.link_id),
        number_of_distinct_ordered_pairs = length(network.pair_to_arcs),
        maximum_multiplicity = maximum(multiplicities),
        number_of_pairs_with_parallel_arcs =
            count(>(1), multiplicities),
    )
end

# ╔═╡ f4c2b4da-a72f-45eb-b243-5583652c0ab1
md"""
## Node-ID conversion

The JSON node IDs are not assumed to coincide with Julia vertex numbers.

For the supplied file the JSON nodes appear in descending order
(`249, 248, …, 0`), so this explicit mapping is essential.
"""

# ╔═╡ 4cfebd27-408d-4798-8ee1-8e1594675170
begin
    json_node_id = 248
    julia_vertex = network.id_to_vertex[json_node_id]

    (
        json_id = json_node_id,
        julia_vertex = julia_vertex,
        name = network.vertex_name[julia_vertex],
    )
end

# ╔═╡ 993ff416-ebe8-43cd-8671-ca7fd80ad9f8
md"""
## Inspect an arc by its JSON link ID
"""

# ╔═╡ 18c46f3e-a92d-466f-a5f6-e4f0c3a257ab
arc_by_id(network, 0)

# ╔═╡ a02c2d97-4bc4-4a5b-9a4f-b7b403b20b9c
md"""
## Inspect all parallel arcs between two nodes

The endpoints below are given as JSON node IDs and then converted to
Julia vertex numbers.
"""

# ╔═╡ 995ddd1c-c2bd-453a-896a-f7ef6e591d17
begin
    from_id = 248
    to_id = 239

    u = network.id_to_vertex[from_id]
    v = network.id_to_vertex[to_id]

    arcs_between(network, u, v)
end

# ╔═╡ 801a3391-ee64-4ffe-ac65-e17200889884
md"""
## Shortest paths using `metric`

When parallel arcs exist, Dijkstra only needs the smallest metric among
parallel arcs joining the same ordered pair.

Therefore we use the simple projection together with `metric_matrix`.
"""

# ╔═╡ a8c28b02-2d0f-4563-a4c0-8bd27bf12ce6
begin
    g_simple = simple_projection(network)
    W = metric_matrix(network)

    source_json_id = 248
    source = network.id_to_vertex[source_json_id]

    sp = dijkstra_shortest_paths(g_simple, source, W)
end

# ╔═╡ 60fe50e2-5d7c-47d1-8aea-86f12cc15012
md"""
`sp.dists[v]` is the shortest-path distance from JSON node `248`
to Julia vertex `v`.

To recover a JSON node ID from a Julia vertex `v`, use

```julia
network.vertex_to_id[v]
```
"""

# ╔═╡ 360d5a9f-73fd-467c-a65d-75e98b3964ea
md"""
# Step 3 — r(i,j,a,0)
The following cells extend the teacher's graph notebook. Coefficients follow
calculating_r.pdf: uniform over complete shortest paths, not equal next hops.
All distances/counts and ratios are computed with exact arithmetic.
"""

# ╔═╡ 4a5ca454-8b49-443c-9e4b-d46f553e2ebb
r_selftest_passed = RAPI.selftest()

# ╔═╡ ae1ff2a2-1b8d-42d8-b68f-794c9a97b563
R0 = RAPI.prepare(json_file)

# ╔═╡ 49602fc7-c322-4200-8813-0668285c8040
r_summary = RAPI.summary(R0)

# ╔═╡ ef5fe140-51bc-429d-8de4-b276a3c2b4a2
r_example = RAPI.example(R0)

# ╔═╡ bb0816e8-e1a0-4250-988f-78266945184d
r0(i, j, a) = RAPI.r(R0, i, j, a, 0)

# ╔═╡ eb0d0153-b3a7-455c-9516-abcb8874d0be
r_evidence = RAPI.export_evidence(R0, json_file; full=false)

# ╔═╡ b803d4c1-989b-47c4-8ac5-0e2b171d7cd4
md"""
`r0(i,j,a)` uses the ORIGINAL node and physical-arc IDs. Missing coefficients
are zero for reachable segments; unreachable segments are rejected.
`r_example` selects a reachable pair with the largest shortest-path count.
`r_evidence.folder` contains the JSON summary, all-pairs distances/path counts
and an example coefficient CSV. To also export all nonzero r values, change
`full=false` to `full=true` in the previous cell; this can take longer.
The sibling results/ folder in the supplied archive already contains complete
Python-reference coefficients for setA-09 and setA-14. Julia cross-check is pending.
"""


# ╔═╡ 0fad1973-577b-40a0-a5f0-af68834e6a6c
r_reference_check = RAPI.check_reference(R0, json_file)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Multigraphs = "7ebac608-6c66-46e6-9856-b5f43e107bac"
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[compat]
Graphs = "~1.15.0"
JSON3 = "~1.14.3"
Multigraphs = "~0.3.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.13.2"
manifest_format = "2.1"
project_hash = "73f8382d43a7c8fed287d84fb73333e8f87559a3"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
registries = "General"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.5.5+2"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "b0bc6d2cad1fed8b7fd59a1551a991cb3d2809e6"
registries = "General"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.6"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Inflate", "LinearAlgebra", "Random", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "dbb2b976f605b220dfe139d6db9f3859680da09e"
registries = "General"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.15.0"

    [deps.Graphs.extensions]
    GraphsSharedArraysExt = "SharedArrays"

    [deps.Graphs.weakdeps]
    Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"
    SharedArrays = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
registries = "General"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
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

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.13.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
registries = "General"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.Multigraphs]]
deps = ["Graphs", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "055a7c49a626e17a8c99bcaaf472d0de60848929"
registries = "General"
uuid = "7ebac608-6c66-46e6-9856-b5f43e107bac"
version = "0.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.30+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "b079a6affebde167dad8ffe0d670b53917fbcb68"
registries = "General"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "2.0.3"

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

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "7ddb0b49c109481b046972c0e4ab02b2127d6a75"
registries = "General"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.6"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.13.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "8a8a52f887f38d44014e24ee46b8a7311c625f6d"
registries = "General"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.24"

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

    [deps.StaticArrays.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
registries = "General"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "e2b53ce13a53367e96601081e33d34746b571bad"
registries = "General"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.5"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "fd6a55e88450cb4256e49103a5a243f065c7b781"
registries = "General"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.1"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.10.1+0"

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

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[registries.General]
url = "https://github.com/JuliaRegistries/General.git"
uuid = "23338594-aafe-5451-b93e-139f81909106"
"""

# ╔═╡ Cell order:
# ╟─f9b0f7ce-a589-4495-938f-33f03be74d1b
# ╠═5f2d823b-eee0-49dc-b29f-46269dc516f5
# ╟─7e277083-f31e-4ddd-891c-1657be9f5ab1
# ╠═2cda6636-29e9-488a-b3cd-1710aa69af0a
# ╟─e68aa8c2-3269-4b3a-8eca-a36fcf2b10a1
# ╠═c5650c13-2860-4605-9b84-d0392335053d
# ╟─dbfa58a1-795c-479a-8d81-1aeef7eb3fad
# ╠═feadcc8d-0049-4211-aac0-b55c029bd6b8
# ╠═51c767b3-ca14-4ce9-97e0-92c0bff724ae
# ╠═3a674046-dfbb-4ca4-9dab-50fa509929d8
# ╠═dc7846d6-932d-4b3b-ad7e-b956192c3edc
# ╟─679d5686-e249-4028-9634-53bbd9b441df
# ╠═3469e52f-adca-48da-a84f-25d0fbc86a09
# ╟─16dd473f-01fb-4b9d-9462-a76bebc3a7f7
# ╠═eac7e670-e435-4ce4-a6c4-4e418962e339
# ╠═eec77268-b7dd-420f-8cc8-6c825805daa5
# ╟─42e9e132-3232-4921-9288-bd68be51ee1e
# ╠═d23567dd-d73d-46ef-b87a-669ba42b6f5a
# ╠═af14cfa8-5f98-43cd-9b75-301d9c1a9b53
# ╠═8b0f96b8-1cf7-4ff3-82e3-fd12541698e2
# ╠═298a2ab8-7b61-4ad1-841b-faa8e10d6824
# ╟─f4c2b4da-a72f-45eb-b243-5583652c0ab1
# ╠═4cfebd27-408d-4798-8ee1-8e1594675170
# ╟─993ff416-ebe8-43cd-8671-ca7fd80ad9f8
# ╠═18c46f3e-a92d-466f-a5f6-e4f0c3a257ab
# ╟─a02c2d97-4bc4-4a5b-9a4f-b7b403b20b9c
# ╠═995ddd1c-c2bd-453a-896a-f7ef6e591d17
# ╟─801a3391-ee64-4ffe-ac65-e17200889884
# ╠═a8c28b02-2d0f-4563-a4c0-8bd27bf12ce6
# ╟─60fe50e2-5d7c-47d1-8aea-86f12cc15012
# ╟─360d5a9f-73fd-467c-a65d-75e98b3964ea
# ╠═7f6ddf55-9818-44a4-8ac7-17ff789f8df2
# ╠═4a5ca454-8b49-443c-9e4b-d46f553e2ebb
# ╠═ae1ff2a2-1b8d-42d8-b68f-794c9a97b563
# ╠═49602fc7-c322-4200-8813-0668285c8040
# ╠═ef5fe140-51bc-429d-8de4-b276a3c2b4a2
# ╠═bb0816e8-e1a0-4250-988f-78266945184d
# ╠═eb0d0153-b3a7-455c-9516-abcb8874d0be
# ╟─b803d4c1-989b-47c4-8ac5-0e2b171d7cd4
# ╠═0fad1973-577b-40a0-a5f0-af68834e6a6c
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
