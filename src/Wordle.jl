module Wordle

using Crayons

export Word, WordStatus, GuessResult, Possibilities
export letterstatus, HERE, SOMEWHERE, NOWHERE
export statuscrayon, statusindex, guess

struct Word
    letters::NTuple{5,Char}
end

function Word(word::AbstractString)
    letters = NTuple{5,Char}(lowercase(word))
    return Word(letters)
end

function Base.show(io::IO, mime::MIME"text/plain", word::Word)
    show(io, mime, join(word.letters))
end

function Base.getindex(word::Word, i)
    return word.letters[i]
end

function Base.lastindex(::Word)
    return 5
end

function Base.keys(word::Word)
    return keys(word.letters)
end

@enum LetterStatus NOWHERE=1 SOMEWHERE=2 HERE=3

function letterstatus(c::AbstractChar)
    if c == '-'
        return NOWHERE
    elseif c == '?'
        return SOMEWHERE
    elseif c == '+'
        return HERE
    else
        throw(ArgumentError("letter status '$c' not recognized"))
    end
end

function statuscrayon(s::LetterStatus)
    if s == NOWHERE
        return Crayon(reset=true)
    elseif s == SOMEWHERE
        return Crayon(reset=true, foreground=:yellow, italics=true)
    elseif s == HERE
        return Crayon(reset=true, foreground=:green, underline=true)
    else
        return Crayon(reset=true, background=:red)
    end
end

struct WordStatus
    status::NTuple{5,LetterStatus}
end

function WordStatus(s::AbstractString)
    st = NTuple{5,LetterStatus}(letterstatus.(collect(s)))
    return WordStatus(st)
end

function Base.getindex(status::WordStatus, i)
    return status.status[i]
end

function Base.lastindex(::WordStatus)
    return 5
end

function Base.keys(status::WordStatus)
    return keys(status.status)
end

function statusindex(status::WordStatus)
    idx = 0
    pow = 1
    for i in eachindex(status)
        idx += (Int(status[i]) - 1) * pow
        pow *= 3
    end
    return idx + 1
end

struct GuessResult
    word::Word
    status::WordStatus
end

function GuessResult(word::AbstractString, status::AbstractString)
    return GuessResult(Word(word), WordStatus(status))
end

function Base.getindex(result::GuessResult, i)
    return (result.word[i], result.status[i])
end

function Base.keys(result::GuessResult)
    return keys(result.word)
end

function Base.lastindex(::GuessResult)
    return 5
end

function Base.show(io::IO, ::MIME"text/plain", guess::GuessResult)
    for l in eachindex(guess)
        print(io, statuscrayon(guess.status[l]))
        print(io, guess.word[l])
    end
end

function guess(word::Word, solution::Word)
    # tricky: repeated letters
    # a HERE letter overrides a SOMEWHERE letter, so hello:world -> ---+?, NOT --?+?
    # the first SOMEWHERE letter overrides the second, so llama:world -> ?----, NOT ??---
    # two popable lists might be the only reasonable way to do this
    wordlist = collect(word.letters)
    solnlist = collect(solution.letters)
    
    # here letters override all
    heres = findall(wordlist .== solnlist)
    wordlist[heres] .= '+'
    solnlist[heres] .= '+'

    # somewhere letters are ordered from left to right
    for i in eachindex(wordlist)
        c = wordlist[i]
        if c == '+'
            continue
        end
        j = findfirst(==(c), solnlist)
        if !isnothing(j)
            wordlist[i] = '?'
            solnlist[j] = '?'
        end
    end

    # everything else is a miss
    for i in eachindex(wordlist)
        c = wordlist[i]
        if c != '+' && c != '?'
            wordlist[i] = '-'
        end
    end

    return GuessResult(word, WordStatus(String(wordlist)))
end

struct Possibilities
    letters::NTuple{5,Set{Char}}
    minima::NTuple{26,Int8}
    maxima::NTuple{26,Int8}

    function Possibilities(guesses::Vector{GuessResult})
        # multiple letters is tricky
        possible = (Set('a':'z'), Set('a':'z'), Set('a':'z'), Set('a':'z'), Set('a':'z'))
        minima = zeros(Int8, 26)
        maxima = ones(Int8, 26) .* Int8(5)

        for gr in guesses
            localmins = zeros(Int8, 26)
            localmaxs = ones(Int8, 26) .* Int8(5)
            for i in eachindex(gr)
                c = gr.word[i]
                idx = c - 'a' + 1
                if gr.status[i] == HERE
                    intersect!(possible[i], c)
                    localmins[idx] += 1
                    localmaxs[idx] += 1 # trick to make sure we catch a HERE or SOMEWHERE after a NOWHERE
                elseif gr.status[i] == SOMEWHERE
                    setdiff!(possible[i], c)
                    localmins[idx] += 1
                    localmaxs[idx] += 1 # trick to make sure we catch a HERE or SOMEWHERE after a NOWHERE
                else
                    setdiff!(possible[i], c)
                    localmaxs[idx] = localmins[idx]
                end
            end
            minima = max.(minima, localmins)
            maxima = min.(maxima, localmaxs)
        end
        return new(possible, NTuple{26,Int8}(minima), NTuple{26,Int8}(maxima))
    end
end

function Base.isvalid(possible::Possibilities, word::Word)
    counts = zeros(Int8, 26)
    for i in eachindex(word)
        c = word[i]
        if c ∉ possible.letters[i]
            return false
        end
        idx = c - 'a' + 1
        counts[idx] += 1
        if counts[idx] > possible.maxima[idx]
            return false
        end
    end
    for i in eachindex(counts)
        if counts[i] < possible.minima[i]
            return false
        end
    end
    return true
end

end
