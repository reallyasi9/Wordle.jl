using Wordle
using Documenter

DocMeta.setdocmeta!(Wordle, :DocTestSetup, :(using Wordle); recursive=true)

makedocs(;
    modules=[Wordle],
    authors="Phil Killewald <reallyasi9@users.noreply.github.com> and contributors",
    sitename="Wordle.jl",
    format=Documenter.HTML(;
        canonical="https://reallyasi9.github.io/Wordle.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/reallyasi9/Wordle.jl",
    devbranch="main",
)
