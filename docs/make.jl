using Colosseum
using Documenter

DocMeta.setdocmeta!(Colosseum, :DocTestSetup, :(using Colosseum); recursive=true)

makedocs(;
    modules=[Colosseum],
    authors="Gabriel Previato <gabriel.previato@gmail.com> and contributors",
    repo="https://github.com/gabrielpreviato/Colosseum.jl/blob/{commit}{path}#{line}",
    sitename="Colosseum.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://docs.previato.tech/Colosseum.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api/api_reference.md",
    ],
)

deploydocs(;
    repo="github.com/gabrielpreviato/Colosseum.jl",
    devbranch="main",
)
