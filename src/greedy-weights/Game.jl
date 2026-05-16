module GameModule 

export Game, initialize_matrix, marginals_to_outcome_matrix, payoff_from_outcome_matrix, payoff, generate_blotto_actions


# defines the `Game` structure 

mutable struct Game 
    num_players::Int 
    num_moves::Int 
    matrix::Array{Float64,3}  # 3D array to store payoffs 
    
    function Game(num_players::Int, num_moves::Int, special_type::String)
        matrix = initialize_matrix(num_players, num_moves, special_type)
        new(num_players, num_moves, matrix)
    end 
end 


function initialize_matrix(num_players::Int, num_moves::Int, special_type::String) 

    if occursin(r"^random_\d+", special_type)
        @assert num_players == 2 "two players only" 
        k = parse(Int, split(special_type, "_")[2]) 

        matrix = zeros(k, k, 2) 
        A = rand(k,k) .- 0.5  # uniformly distributed matrix size (k,k), nums in range -0.5..0.5
        matrix[:,:,1] = A 
        matrix[:,:,2] = -A 
        # display(matrix)
        return matrix 
        
    elseif occursin(r"^symmetric_\d+$", special_type)
        @assert num_players == 2 "two players mf" 
        k = parse(Int, split(special_type, "_")[2]) 

        matrix = zeros(k, k, 2) 
        A = rand(k,k) .- 0.5 
        A = A .- A' 
        matrix[:,:,1] = A 
        matrix[:,:,2] = -A 
        return matrix        

    # special game types 
    elseif special_type == "matching_pennies" 
        @assert num_players == 2 && num_moves == 2 "matching pennies requires 2 players, 2 moves, zero-sum" 
        return reshape([1 -1; -1 1; -1 1; 1 -1], (2, 2, 2)) 
    
    elseif special_type == "rps" 
        @assert num_players == 2 && num_moves == 3 "2 players 3 moves zero-sum for rps" 
        return reshape([ 
            0 -1  1  0  1 -1; 
            1  0 -1 -1  0  1; 
           -1  1  0  1 -1  0
        ], (3, 3, 2))  
    
    elseif occursin(r"^rps_\d+", special_type)
        # odd = (num_moves % 2 == 1) ? true : false
        k = parse(Int, split(special_type, "_")[2])
        @assert num_players == 2 && isodd(k) "we require two players and an odd number of actions"

        matrix = zeros(k,k,2)
        # half = (k - 1) / 2 
        half = (k - 1) ÷ 2 

        for i in 1:k 
            for j in 1:k
                if i == j 
                    payoff1 = 0.0
                else 
                    # dist from i to j modulo k (how far ahead j is on the cycle) 
                    dist = mod(j - i, k)
                    if 1 <= dist <= half 
                        payoff1 = -1.0 
                    else 
                        payoff1 = 1.0
                    end # if 
                end # if i == j 

                matrix[i,j,1] = payoff1 
                matrix[i,j,2] = -payoff1 
            end # for j 
        end # for i         

        return matrix 

    elseif special_type == "morra" 
        @assert num_players == 2 && num_moves == 9 "2 players 9 actions zero-sum required for morra" 

        matrix = zeros(9,9,2) 
        
        moves = [(1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 3), (3, 1), (3, 2), (3, 3)]

        for (i, (p1_raised, p1_guess)) in enumerate(moves) 
            for (j, (p2_raised, p2_guess)) in enumerate(moves) 
                total_fingers = p1_raised + p2_raised 
                p1_correct = (p1_guess == p2_raised) 
                p2_correct = (p2_guess == p1_raised) 
                if p1_correct && !p2_correct
                    matrix[i, j, 1] = total_fingers 
                    matrix[i, j, 2] = -total_fingers 
                elseif p2_correct && !p1_correct 
                    matrix[i, j, 1] = -total_fingers 
                    matrix[i, j, 2] = total_fingers 
                end # if 
            end # for j 
        end # for i 
        return matrix 

    elseif occursin(r"^morra_\d+$", special_type)
        @assert num_players == 2 "2 players required for morra" 
        k = parse(Int, split(special_type, "_")[2]) 
        num_moves = k * k
        matrix = zeros(num_moves, num_moves, 2) 
        
        moves = [(raised, guess) for guess in 1:k, raised in 1:k]
        moves = vec(moves)
        # display(moves)

        @assert length(moves) == num_moves

        for (i, (p1_raised, p1_guess)) in enumerate(moves) 
            for (j, (p2_raised, p2_guess)) in enumerate(moves) 
                total_fingers = p1_raised + p2_raised 
                p1_correct = (p1_guess == p2_raised) 
                p2_correct = (p2_guess == p1_raised) 
                if p1_correct && !p2_correct
                    matrix[i, j, 1] = total_fingers 
                    matrix[i, j, 2] = -total_fingers 
                elseif p2_correct && !p1_correct 
                    matrix[i, j, 1] = -total_fingers 
                    matrix[i, j, 2] = total_fingers 
                end # if 
            end # for j 
        end # for i 
        return matrix 

    elseif occursin(r"^blotto_\d+-\d+$", special_type)
        r = split(special_type, "_")[2]
        n = parse(Int, split(r, "-")[1])  # n...battlefiedls 
        p = parse(Int, split(r, "-")[2])  # p...soldiers total 
        # num_actions = (factorial(n+p-1))/(factorial(p)*factorial(n-1))
        # num_moves = binomial(n+p-1, p)

        actions = generate_blotto_actions(n,p)
        num_moves = length(actions)
        # println(actions)
        @assert num_players == 2 "only two players mf.." 
        matrix = zeros(num_moves, num_moves, 2)
        
        for i in 1:num_moves
            ai = actions[i]  #p1s 
            for j in 1:num_moves
                aj = actions[j]

                wins1 = 0
                wins2 = 0 

                for field in 1:n 
                    if ai[field] > aj[field]
                        wins1 += 1 
                    elseif ai[field] < aj[field]
                        wins2 += 1
                    end
                end 

                # the winner takes it all 🎶 
                if wins1 > wins2 
                    matrix[i, j, 1] = 1.0
                    matrix[i, j, 2] = -1.0
                elseif wins1 < wins2 
                    matrix[i, j, 1] = -1.0
                    matrix[i, j, 2] = 1.0
                else
                    matrix[i, j, 1] = 0.0
                    matrix[i, j, 2] = 0.0
                end 
            end # for j 
        end # for i

        return matrix
    elseif occursin(r"^transitive_\d+$", special_type)
        k = parse(Int, split(special_type, "_")[2]) 
        @assert num_players == 2 "two players required" 

        matrix = zeros(k,k,2)

        for i in 1:k 
            for j in 1:k 
                if i == j 
                    payoff1 = 0.0
                elseif i < j 
                    payoff1 = -1.0
                else # i > j 
                    payoff1 = 1.0
                end # if 

                matrix[i,j,1] = payoff1
                matrix[i,j,2] = -payoff1

            end # for j 
        end # for i 

        return matrix 

    else 
        error("unknown special type: $special_type")
    end 
end 

function generate_blotto_actions(n::Int, p::Int)
    if n == 1
        return [[p]]
    end

    actions = Vector{Vector{Int}}()
    for k in 0:p
        for tail in generate_blotto_actions(n - 1, p - k)
            push!(actions, [k; tail])
        end
    end
    return actions
end


function marginals_to_outcome_matrix(moves::Vector{Vector{Float64}}, num_players::Int) 
    """
    It computes the probability distribution over joint actions when players use mixed strategies. 

    Args:
        moves::Vector{Vector{Float64}} a list of probability distributions, one for each player. 
        e.g. 
        moves = [
            [0.5, 0.25, 0.25],  # P1: 50% Rock, 25% Paper, 25% Scissors
            [0.5, 0.5, 0.0]     # P2: 50% Rock, 50% Paper, 0% Scissors
        ]

    Returns:   
        (result = matrix: actionsP1 × actionsP2 telling probs of P1 choosing `i` and P2 choosing `j`) 
        Array{Float64, N}: A joint probability matrix representing all players' mixed strategies. 
    """
    # compute outer product of probability distributions to get joins actions probabilities 
    joint_probs = moves[1]  # moves for the first player 
    # iterate over remaining players to construct the joint probability distribution 
    for i in 2:length(moves) 
        # reshape Player i''s probability vector to align with the correct dimensions 
        # to ensure broadcasting (element-wise multiplication here) works properly 

        # e.g. if we have 2 3 players: 
        #     P2's probs are reshaped to (1, len(P2), 1) 
        #     P3's probs are reshaped to (1, 1, len(P3)) 

        # `fill(1, ..)` ... adds singleton dimensions before/after Player i's moves

        joint_probs = joint_probs .* reshape(moves[i], fill(1, i-1)..., length(moves[i]), fill(1, length(moves)-i)...)
    end 
    # `repeat`: duplicate along last axis (if joint_pros is (3,3) for two player, it becomes (3,3,2) to store payoff for both) 

    # return repeat(joint_probs, outer=(ones(Int, ndims(joint_probs))..., num_players)) 
    return repeat(joint_probs, outer=(1,1,num_players))
end


function payoff_from_outcome_matrix(game::Game, outcome_matrix::Array{Float64})
    """
    Compute expected payoffs from an outcome probability matrix. 

    Element-wise multilplication of `outcome_matrix` and `self_matrix` (individually for P1 and P2). 
    Then sum all the items in each player's matrix. 
    Return these sums. 

    Args:
        game::Game
        outcome_matrix (_type_): _description_

    Returns:
        Vector{Float64} : Expecetd payoffs for each player. 

    example cuz im dumb: 
        
        self.matrix = np.array([ 
            [[0,  0], [-1,  1], [1, -1]],  # Rock
            [[1, -1], [0,  0], [-1, 1]],  # Paper
            [[-1, 1], [1, -1], [0,  0]]  # Scissors
        ])
        
        outcome_matrix = np.array([
            [[0.25, 0.25], [0.25, 0.25], [0.0, 0.0]],  # Probabilities when P1 plays Rock
            [[0.125, 0.125], [0.125, 0.125], [0.0, 0.0]],  # Probabilities when P1 plays Paper
            [[0.125, 0.125], [0.125, 0.125], [0.0, 0.0]]  # Probabilities when P1 plays Scissors
        ])

    """
    # element-wise multiplication of outcome probs and payoffs 
    weighted_payoffs = outcome_matrix .* game.matrix 
    # sum along all dimensions except the last one (which represents players)
    return dropdims(sum(weighted_payoffs, dims=Tuple(1:ndims(outcome_matrix)-1)), dims=Tuple(1:ndims(outcome_matrix)-1))
end


function payoff(game::Game, moves::Vector{Vector{Float64}})
    """
    if players choose pure strategies, we return the corresponding matrix 
    if players use mixed strategies, we compute the expected payoff 

    `moves` is an array representing chosen strategies. 

    Args:
        game::Game : The game object
        moves::Vector{Vector{Float64}} : List of probability distributions for each player

    Returns:
        Vectoor{Float64} : Payoff for each player. 
        a vector of payoffs, one for each player. 
    """
    # println("payoff() running...")
    # check if pure strategies (some probability has to be (close to) 1.0) 
    if all(maximum(m) ≈ 1.0 for m in moves)  # if one value is 1.0, the rest will be 0.0 
        # println("payoff(): inside the if")
        # display(game.matrix)
        # println("matrix size: ", size(game.matrix))
        
        # println("moves: ")
        # display(moves)
        return [game.matrix[argmax.(moves)..., player] for player in 1:game.num_players]  # get the corresponding payoff 
        # `.`: apply `argmax` to each vector inside `moves` (returning the index of tha maximum value for each player) 
    end 
    # println("payoff(): after the if")
    # if not pure (--> mixed) strategies 
    outcome_matrix = marginals_to_outcome_matrix(moves, game.num_players) 
    return payoff_from_outcome_matrix(game, outcome_matrix)
end

end # module 
