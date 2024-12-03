using Wordle
using ArgParse
using Statistics
using Combinatorics
using SparseArrays

const AGGREGATION_FUNCTIONS = Dict(
    "maximum" => maximum,
    "mean" => mean,
    "median" => median,
    "variance" => var,
)

function argparse(args::AbstractVector{T}=ARGS) where {T <: AbstractString}
    settings = ArgParseSettings("Solve a Wordle puzzle by suggesting the next best guesses based on results from previous guesses.")
    @add_arg_table! settings begin
        "solutions"
        help = "file containing list of possible solutions (one per line)"
        "guessables"
        help = "file containing list of possible guesses (one per line)"
        "--aggregation", "-a"
        help = "how to aggregate guesses to compute best guess: the minimum of this statistic (zeros removed) will be computed"
        range_tester = ∈(keys(AGGREGATION_FUNCTIONS))
        default="maximum"
        "--number", "-n"
        help = "number of best guesses to compute"
        arg_type = Int
        range_tester = >(0)
        default = 1
        "--max", "-m"
        help = "maximum number of guesses to show, zero meaning show all"
        arg_type = Int
        range_tester = >=(0)
        default = 10
        "guesses"
        help = "pairs of guessed words and results, using a string of '+' (here), '?' (somewhere), and '-' (nowhere) to encode results (e.g., \"hello\" \"-?-+?\")"
        nargs = '*'
        range_tester = (v -> length(v) == 5)
    end

    parsed = parse_args(args, settings)
    if isodd(length(parsed["guesses"]))
        throw(ArgParseError("guesses must be in pairs of words and results"))
    end
    return parsed
end

struct Aggregator{F<:Function}
    fcn::F
    words::Vector{Word}
    solutions::Vector{Word}
    n::Int
end

function aggregate(a::Aggregator, c::Channel{Pair{Vector{Word}, Float64}})
    for words in combinations(a.words, a.n)
        breakdown = spzeros(Int, repeat([3^5], length(words))...)
        for soln in a.solutions
            idxs = [statusindex(guess(word, soln).status) for word in words]
            breakdown[idxs...] += 1
        end
        bd = last(findnz(breakdown))
        put!(c, words => a.fcn(bd))
    end
    close(c)
end

function find_best(c::Channel{Pair{Vector{Word}, Float64}})
    best_score = typemax(Float64)
    best_words = Vector{Vector{Word}}()
    for (words, score) in c
        if score < best_score
            best_score = score
            empty!(best_words)
            push!(best_words, words)
            @debug "New best guess found" words score
        elseif score ≈ best_score
            push!(best_words, words)
            @debug "Additional best guess found" words
        end
    end
    return (best_score, best_words)
end

function (@main)(args)
    options = try
        argparse(args)
    catch e
        @error "Error parsing arguments" exception=e
        return -1
    end

    solutions = Word.(readlines(options["solutions"]))
    @info "$(length(solutions)) solutions loaded"
    guessables = Word.(readlines(options["guessables"]))
    @info "$(length(guessables)) guessables loaded"

    guess_results = Vector{GuessResult}(undef, length(options["guesses"]) ÷ 2)
    map!(gr_pair -> GuessResult(gr_pair...), guess_results, collect(Iterators.partition(options["guesses"], 2)))
    @info "$(length(guess_results)) guesses recorded" guesses=guess_results

    # remove previous guesses from guessables
    already_guessed = [gr.word for gr in guess_results]
    filter!(∉(already_guessed), guessables)
    @info "$(length(guessables)) guessables remain"

    # generate possiblities computer
    possibilities = Possibilities(guess_results)
    # filter soltions to only include possible solutions
    filter!(x -> isvalid(possibilities, x), solutions)
    @info "$(length(solutions)) possible solutions remain" solutions

    # compute aggregated entropy of guesses
    agg_fcn = AGGREGATION_FUNCTIONS[options["aggregation"]]
    aggregator = Aggregator(agg_fcn, guessables, solutions, options["number"])
    # produce
    channel = Channel{Pair{Vector{Word},Float64}}(c -> aggregate(aggregator, c), 1024)
    # consume
    (best_score, best_words) = find_best(channel)

    @info "Best guess(es) computed" guesses=best_words aggregation=options["aggregation"] constraint=best_score

    # promote guesses that are solutions
    sort!(best_words, by=(x -> all(∈(solutions), x) ? -2 : any(∈(solutions), x) ? -1 : 0))
    m = options["max"] == 0 ? length(best_words) : options["max"]
    for words in first(best_words, m)
        for guess in words
            possible = guess ∈ solutions ? " (possible solution) " : " "
            show(stdout, "text/plain", guess)
            print(possible)
        end
        println()
    end

    return 0
end

