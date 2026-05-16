module MinMaxSolver 

using JuMP, GLPK 
using ..GameModule 

export minmax_solution

function minmax_solution(game::Game) 
    # if !game.zero_sum 
    #     error("minmax only for zero-sum games") 
    # end 

    A = game.matrix[:,:,1]  # taky only the first player's payoff matrix 
    m, n = size(A) 

    model = Model(GLPK.Optimizer) 
    @variable(model, x[1:m] >= 0)  # mixed strategy for player 1 
    @variable(model, v)  # the value of the game 

    @constraint(model, sum(x) == 1)  # probabilities sum to 1 
    @constraint(model, [j=1:n], sum(A[i,j] * x[i] for i in 1:m) >= v)  # minimax constraint 

    @objective(model, Max, v)  # maximizing the minimum guaranteed payofff 

    optimize!(model) 

    x_sol = value.(x)  # optimal mixed strategy 
    v_sol = objective_value(model)  # value of the game 

    return x_sol, v_sol 
end 


end # module 
