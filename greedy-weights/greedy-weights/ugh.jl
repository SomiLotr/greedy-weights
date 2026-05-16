

module Pokus 
include("Game.jl")
using .GameModule
using Printf
export hello, print_matrix_formatted, compute_exploitability 

function hello()
    println("what the actual fuck")
end 

function print_matrix_formatted(A::Array{Float64, 3})
    for i in 1:size(A, 3)
        println("Slice $i:")
        for row in 1:size(A, 1)
            for col in 1:size(A, 2)
                @printf("%.2f  ", A[row, col, i])
            end
            println()
        end
        println()
    end
end



end # module 