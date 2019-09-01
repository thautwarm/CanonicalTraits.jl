using Documenter, CanonicalTraits

makedocs(;
    modules=[CanonicalTraits],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/thautwarm/CanonicalTraits.jl/blob/{commit}{path}#L{line}",
    sitename="CanonicalTraits.jl",
    authors="thautwarm",
    assets=String[],
)

deploydocs(;
    repo="github.com/thautwarm/CanonicalTraits.jl",
)
