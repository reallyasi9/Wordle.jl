using Wordle
using Test
using TestItems
using TestItemRunner


@testitem "Word Constructor" begin
    w1 = Word("hello")
    @test w1.letters == ('h', 'e', 'l', 'l', 'o')
    
    w2 = Word("HeLlO")
    @test w2.letters == w1.letters

    w3 = Word("hello!") # truncates
    @test w3.letters == w1.letters

    @test_throws ArgumentError Word("hi")
end

@testitem "Word getindex" begin
    w1 = Word("hello")
    @test w1[1] == 'h'
    @test w1[2:end] == ('e', 'l', 'l', 'o')
    @test_throws BoundsError w1[6]
end

@testitem "Word iterate" begin
    let
        w1 = Word("hello")
        x = 1
        for i in eachindex(w1)
            @test w1[i] == w1[x]
            x += 1
        end
    end
end

@testitem "letterstatus" begin
    @test letterstatus('-') == NOWHERE
    @test letterstatus('?') == SOMEWHERE
    @test letterstatus('+') == HERE
    @test_throws ArgumentError letterstatus('x')
end

@testitem "statuscrayon" begin
    using Crayons
    @test statuscrayon(letterstatus('-')) == Crayon(reset=true)
    @test statuscrayon(letterstatus('?')) == Crayon(foreground=:yellow, italics=true)
    @test statuscrayon(letterstatus('+')) == Crayon(foreground=:green, underline=true)
    @test_throws ArgumentError statuscrayon(letterstatus('x'))
end

@testitem "WordStatus Constructor" begin
    ws1 = WordStatus("+-?+-")
    ws2 = WordStatus((HERE, NOWHERE, SOMEWHERE, HERE, NOWHERE))
    @test ws1.status == ws2.status

    ws3 = WordStatus("+-?+-?") # truncates
    @test ws3.status == ws1.status

    @test_throws ArgumentError WordStatus("+-")
    @test_throws ArgumentError WordStatus("+-x+-")
end

@testitem "WordStatus getindex" begin
    ws1 = WordStatus("+-?+-")
    @test ws1[1] == HERE
    @test ws1[2:end] == (NOWHERE, SOMEWHERE, HERE, NOWHERE)
    @test_throws BoundsError ws1[6]
end

@testitem "WordStatus iterate" begin
    let
        ws1 = WordStatus("+-?+-")
        x = 1
        for i in eachindex(ws1)
            @test ws1[i] == ws1[x]
            x += 1
        end
    end
end

@testitem "statusindex" begin
    @test statusindex(WordStatus("-----")) == 1
    @test statusindex(WordStatus("+++++")) == 3^5
    @test statusindex(WordStatus("+-?+-")) == 2 * 3^0 + 0 * 3^1 + 1 * 3^2 + 2 * 3^3 + 0 * 3^4 + 1
end

@testitem "GuessResult Constructor" begin
    gr1 = GuessResult(Word("hello"), WordStatus("+-?+-"))
    gr2 = GuessResult("hello", "+-?+-")
    @test gr1.word == gr2.word
    @test gr1.status == gr2.status

    gr3 = GuessResult("HeLlO!", "+-?+-?") # truncates and normalizes
    @test gr3.word == gr1.word
    @test gr3.status == gr1.status


    @test_throws ArgumentError GuessResult("hello", "+-")
    @test_throws ArgumentError GuessResult("hi", "+-?+-")
    @test_throws ArgumentError GuessResult("hello", "+-x+-")
end

@testitem "guess" begin
    @test guess(Word("hello"), Word("world")) == GuessResult("hello", "---+?")
    @test guess(Word("llama"), Word("world")) == GuessResult("llama", "?----")
    @test guess(Word("xxxyy"), Word("zxzzx")) == GuessResult("xxxyy", "?+---")
end

@testitem "Possibilities isvalid" begin
    gr1 = guess(Word("hello"), Word("world"))
    gr2 = guess(Word("llama"), Word("world"))
    guesses = [gr1, gr2]
    p = Possibilities(guesses)
    
end

@run_package_tests