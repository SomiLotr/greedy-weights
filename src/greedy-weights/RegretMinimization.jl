module RegretMinimization 
using Distributions
using LinearAlgebra 
using Random
using ..Exploitability: compute_exploitability_avg, compute_exploitability_avg_history, best_response_value_p1, best_response_value_p2
using ..GameModule

# external_regret(), optimize(), get_best_weight() etc 

#  also, budu to potrebovat plotit 
# ale to asi v `examples.jl`, idk 

# include("Game.jl")

export external_regret, compute_exploitability_avg_history, compute_exploitability_avg

"""

######### OVERVIEW ######### 

CUM_REGRET: (game.num_players, game.num_moves)  
    stores the regret values for each player and each possible move 

REGRET: list (length updated at each iteration) 
    a list where each entry is the normalized regret at a given iteration 

ALL_MOVES: (iterations, game.num_players, game.num_moves)
    stores the history of all moves played in each iteration 

WEIGHTS: list (length updated at each iteration) 
    stores the history of weights applied to regret updates 

CLOCK: list (length updated at each iteration) 
    to measure performance - added timestamp each iteration 

best_w: 
    the weight factor dynamically chosen to minimize regret 

w_sum: 
    cumulative weight of regret updates over time 

strategy_history: dict `{player: [list of strategy vectors]}` 
    tracks the evolution of strategy distributions over iterations 

last_moves: (game.num_players, game.num_moves) 
    stores the probs of each player's chosen actions 


"""


function total_regrets(CUM_REGRET::Array{Float64, 2}, game::Game) 
    """
    compute total regret for all players 
    
    Args:
        CUM_REGRET::Array{Float64,2} : The regret matrix (game.num_players, game.num_moves)
        game::Game : The game instance 
    
    Returns: 
        Float64 : The total sum of maximum regrets for each player. 
    
    selects maximum regret for each player and puts it all together 
    """
    
    # `max(a,b)` - returns the larger of two values 
    # `maximum(A)` - returns the largest element in an array 
    return sum(max(0, maximum(CUM_REGRET[player, :])) for player in 1:game.num_players)

end 


function update_regrets(CUM_REGRET::Array{Float64, 2}, game::Game, last_moves::Matrix{Float64}, weight::Float64=1.0, dilution::Float64=1.0)  
    """
    Update regrets given regret minimization settings and the last moves played
    
    Args: 
        CUM_REGRET::Array{Float64,2} : matrix storing regrets (game.num_players × game.num_moves) 
        game::Game 
        last_moves::Matrix{Float64} : The previous stategy distributions 
        weight::Float64 : Scaling factor for regret updates, default = 1.0 
        dilution::Float64 : Factor reducing past regrets, default = 1.0 
    
    Returns: 
        Matrix{Float64} : the updated regret matrix (CUM_REGRET) 
    
    """ 

    CUM_REGRET ./= dilution  # scale down past regret (reduce the influence of past regrets) 
    player_regrets = similar(CUM_REGRET)
    
    for player in 1:game.num_players  # bcs the regret function always takes only one player 
        player_regret = weight .* instantaneous_regret(game, last_moves, player)  # update regret for the player 
        player_regrets[player, :] .= player_regret
        CUM_REGRET[player, :] .+= player_regret  # update regret matrix 
    end 

    return CUM_REGRET, player_regrets 

end 

# processes one player at a time and computes the probability distribution for that player based on their regrets 
function blackwells(CUM_REGRET::Matrix{Float64}, player::Int) 
    #? neni potreba `game` jako parametr 
    """
    Computes the probability distro for a player based on their regrets. 
    
        Args: 
            CUM_REGRET::Matrix{Float64} : Regret matrix (game.num_players × game.num_moves).
            player::Int : The player index. 
            game::Game : The game. 

        Returns: 
            Vector{Float64} : A probability vector of size `game.num_moves`
    """
    
    regrets = CUM_REGRET[player, :]  # extract regret values for the given player 
    # small floor to avoid division by zero
    regrets = max.(regrets, 1e-3)

    return regrets ./ sum(regrets)  # normalize 
    # return probs  


end 

# each player chooses their moves based on past regrets
function compute_next_moves(CUM_REGRET::Matrix{Float64}, last_moves::Matrix{Float64}, game::Game, strategy_history::Dict{Int, Vector{Vector{Float64}}}) # for all players (not applying individually) 
    """
    Updates the strategies for each player based on past regrets. 

    Args: 
        CUM_REGRET::Matrix{Float64} : Regret matrix (game.num_players × game.num_moves). 
        last_moves::Matrix{Float64} : The previous strategy distributions. 
        game::Game : the game. what a surprise. 
        strategy_history::Dict : Tracks strategy evolution. 

    Returns: 
        Matrix{Flaot64} : Updated strategy matrix (game.num_players × game.num_moves). 
    """
    for player in 1:game.num_players 
        probs = blackwells(CUM_REGRET, player)  # convert regrets to probability distribution 
        # probs .+= 1e-3 
        # probs ./=sum(probs)
        # println("probs player $player: ", probs)
        push!(strategy_history[player], copy(probs))  # store teh strategy so later we can plot it 


        last_moves[player, :] .= 0.0  # reset move probabilities 
        chosen_action = rand(Categorical(probs))  # pick an action based on probs 
        last_moves[player, chosen_action] = 1.0  
            
    end 

    return last_moves  # return updated strategies - matrix with rows for players, cols for each action 
    
end 


function external_regret(game::Game, iterations::Int, target_epsilon::Float64, time_limit; static::Bool=false, plus::Bool=false, predictive::Bool=false, seed::Union{Nothing, Int}=nothing)  
    """
    Args: 
        game::Game : The game. 
        iterations::Int : Number of iterations to run. 
        target_epsilon::Float64 : Stop early if regret falls below this (default: 0.0). 
        seed::Union{Nothing, Int} : Optional RNG seed for reproducible sampling.

    Returns: 
        ALL_MOVES 
        REGRET 
        WEIGHTS 
        CLOCK 
        strategy_history 
    """
    # init 
    if seed !== nothing
        Random.seed!(seed)
    end
    start_time = time()
    CLOCK = [time()]  # start tracking execution time 

    strategy_history = Dict(player => Vector{Vector{Float64}}() for player in 1:game.num_players)  # a dict tracking each player's move probabilities over time 
    avg_history = Dict(player => Vector{Vector{Float64}}() for player in 1:game.num_players) # a dict tracking average strategies over time 

    # init last moves with uniform strategies 
    last_moves = zeros(game.num_players, game.num_moves)
    for player in 1:game.num_players
        probs = fill(1.0 / game.num_moves, game.num_moves)  # uniform probs 
        last_moves[player, :] .= 0.0 
        chosen_action = rand(Categorical(probs)) 
        last_moves[player, chosen_action] = 1.0 
    end  # for player 

    # initialize regret tracking 
    # CUM_REGRET keeps track of all the regrets (row per player, column for action) 
    CUM_REGRET, last_weighted_regret = update_regrets(zeros(game.num_players, game.num_moves), game, last_moves) 
    if plus
        CUM_REGRET .= max.(CUM_REGRET, 0.0)
    end

    # predictive: 
    pred_regret = copy(last_weighted_regret)

    REGRET = [total_regrets(CUM_REGRET, game)]  # keeps track of the regret over time 
    ALL_MOVES = [deepcopy(last_moves)]  # stores all moves played across iterations  
    w_sum = 1.0 
    WEIGHTS = [1.0] 
    avg_strategy = deepcopy(last_moves)
    for player in 1:game.num_players
        push!(avg_history[player], copy(avg_strategy[player,:]))
    end
    # end of init 

    for t in 2:iterations 
        if time() - start_time > time_limit
            println("out of time")
            break
        end 

        effective_regret = predictive ? CUM_REGRET .+ pred_regret : CUM_REGRET

        last_moves = zeros(game.num_players, game.num_moves)  # reset last moves 
        last_moves = compute_next_moves(effective_regret, last_moves, game, strategy_history)  # using blackwells (blackwells for everyone) 
        # find `best_w`        
        
        # option for basic regret matching: 
        if static == true 
            best_w = 1.0 
        else
            best_w = optimize(CUM_REGRET, game, last_moves, w_sum) 
        end # if 

        dilution = 1.0 
        # if `best_w` is infinite, reset to 1 and apply large dilution to avoid instability s
        if isinf(best_w) 
            best_w = 1.0 
            dilution = 1e6  # in such a case we wanna reset the total_weights (s_sum) bcs if it grows too high we are fucked (problems with future updates) 
        end 

        avg_strategy .= (w_sum .* avg_strategy .+ best_w .* last_moves) ./ (w_sum + best_w)
        for player in 1:game.num_players
            push!(avg_history[player], copy(avg_strategy[player,:]))
        end

        # update `SWAP` with the new regrets using computed weight and dilution 
        CUM_REGRET, last_weighted_regret = update_regrets(CUM_REGRET, game, last_moves, best_w, dilution) 
        if plus
            CUM_REGRET .= max.(CUM_REGRET, 0.0)
        end
        if predictive
            pred_regret .= last_weighted_regret
        end
        # update total regret weight (dilution is almost always == 0) 
        w_sum = w_sum / dilution + best_w 
        # adjust weight history 
        WEIGHTS = WEIGHTS ./ dilution 
        push!(WEIGHTS, best_w) 


        # append normalized sum of maximum regrets of each player, stores one value (that sum) per iteration 
        push!(REGRET, total_regrets(CUM_REGRET, game) / w_sum) 
        # store the moves played this iteration 
        push!(ALL_MOVES, deepcopy(last_moves)) 

        if REGRET[end] < target_epsilon  # if regret falls below `target_epsilon`, stop early (algorihm has converged) 
            println("regret small enough")
            break 
        end 

        push!(CLOCK, time()) 
    end 

    return ALL_MOVES, REGRET, WEIGHTS, CLOCK, strategy_history, avg_history

end 

# dynamically choose the weights to minimize something
function optimize(CUM_REGRET::Matrix{Float64}, game::Game, last_moves::Matrix{Float64}, w_sum::Float64)  
    """
    Dynamically choose the weights to minimize the objective (`phi` from the paper). 
    
    Args: 
        CUM_REGRET::Matrix{Float64} : The regret matrix (game.num_players × game.num_actions). 
        game::Game : The game. 
        last_moves::Matrix{Float64} : The latest action played by each player. 
        w_sum::Float64 : The cumulative weight of previous regret updates. 
    
    Returns: 
        Float64: The optimal weight `best_w`. 
    """ 
        
    # create an empty regret matrix (calls `update_regrets()`, computing how the regret would change with a unit vector) 
    NEW_CUM_REGRET, _ = update_regrets(zeros(size(CUM_REGRET)), game, last_moves, 1.0) 

    # flatten regret matrices into 1D vectors 
    R = vcat([CUM_REGRET[player, :] for player in 1:game.num_players]...)  # the total regret accumulated for all players and all moves together 
    r = vcat([NEW_CUM_REGRET[player, :] for player in 1:game.num_players]...)  # the immediate regrets - the new regret values for the urrent turn inf we applied a weight of `1` 

    best_w, best_phi = find_optimal_weight(R, r, w_sum)  
    return best_w 


end 


function get_objective(R::Vector{Float64}, r::Vector{Float64}, w::Float64, wsum::Float64)  
    """
    objective from the paper; insert weight and get a value 

    Args: 
        R::Vector{Float64} : Total accumulated regrets for all actions. 
        r::Vector{Float64} : Immmediate regret for the current iteration. 
        w::Float64 : The weight applied to regret updates. 
        wsum::Float64 : Total weight of previos regret updates (`w_T` from the paper). 
    
    Returns: 
        Float64 : The objective function value. 
    """
    if isinf(w) 
        return sum(max.(r, 0.0) .^ 2) 
    end
    terms = max.(R .+ r .* w, 0.0)
    return sum((terms ./ (wsum+w)) .^ 2)
end 


function find_optimal_weight(R::Vector{Float64}, r::Vector{Float64}, wsum::Float64) 
    """
    Args: 
        R::Vector{Float64} : Accumulated regrets for all actions.  
        r::Vector{Float64} : Immediate regrets for the current iteration. 
        wsum::Float64 : Total weight of previous regret updates (~ `w_T` from the paper). 

    Returns: 
        Tuple{Float64, Float64} : (best_w, best_phi)

        w: min_w sum_a max(0, R + wr)^2 / (wsum + w)^2 
        best_w: The optimal weight that minimizes regret updates; 
        best_phi: the objective function value for `best_w` 

    The function we are trying to minimize is piecewise quadratic (po částech kvadratická, viz vzoreček z paperu) with <= N cutpoints at `w = -R(a) / r(a)` for each a. 
    Within each of these <=N+1 intervals, we can compute a binary vector Z of which actions have R(a)+wr(a)>0. We can solve for the (possible) stationary point in this interval, which leads to equation 

        1/(wsum+w)^3 sum_a Z(a) [ 2r(a)(R(a) + wr(a))(wsum+w) - 2(R(a) + wr(a))^2 ] = 0  # tohle je derivace ty objective 

            (ta byla phi(w) = sum_a Z(a) ((R(a) + wr(a))^2) / ((wsum + w) ^ 2) 
            kdyztak to je na papire barevne pro porovnani vs paper)

    which rearranges to

            sum_a Z(a)[ R(a)^2 - r(a)R(a)wsum ]
        w  = --------------------------------
            sum_a Z(a)[ r(a)^2wsum - r(a)R(a) ]

    which is only valid if it's in the interval. 

    The optimal w will be the minimum of w at each cutpoint, at each inner stationary point, and at the boundaries 0 and inf. 
    """
    # ensure `R` and `r` are valid 
    @assert length(R) == length(r) 

    # compute cutpoints where regret updates change behavior 
    cutpoints = -R[r .!= 0] ./ r[r .!= 0]  # not NaN (avoid division by zero) 
    cutpoints = filter(x -> x > 0, cutpoints)  # w > 0 - a negative weight would increase regret instead of decreasing it 
    sort!(cutpoints) 
    # add boundaries 0.0 & inf 
    pushfirst!(cutpoints, 0.0)
    push!(cutpoints, Inf) 

    to_check = copy(cutpoints) 

    for ci in 1:(length(cutpoints) - 1)  # `ci` ....cutpoint index 
        start, stop = cutpoints[ci], cutpoints[ci + 1] 
        mid = isinf(stop) ? (2 * start + 1) : ((start + stop) / 2)  # (2 * start + 1) ... some point that is not indefinitely large ut is on that interval 

        R_mid = R .+ r .* mid  # compute the updated regret for this `w` (`mid` \in \{w_i\}_{i=0}^{\infty}) 
        Z = (R_mid .> 0) .+ 0.0  # binary vector; where the "new" regret (`R_mid`) is positive 

        # how do we get these: find derivatie of the objective function, set == 0, solve for w 
        # so we get the `w = ...`  fraction from docstring 
        num = dot(Z, R .^ 2 .- r .* R .* wsum) 
        denom = dot(Z, r .^ 2 .* wsum .- r .* R)
        
        if abs(denom) < 1e-10 
            denom += 1e-10  # avoid division by zero 
        end 

        w_star = num / denom 

        if start < w_star < stop  # check if `w*` (our optimal `w` for that interval) is within valid range (ie within that interval) 
            push!(to_check, w_star)
        end 
    end 
    
    push!(to_check, 1.0)  # to ensure 1 is always considered as a candidate weight 

    to_check_values = [get_objective(R, r, w, wsum) for w in to_check]  # pass all the `w`s to our objjevtive function, so we have a list of function values (the `to_check_values`) and we want to find the minimum  # Vector{Float64} 
    best_idx = argmin(to_check_values)  # returns the indices of the minimum value  # "Ranges can have multiple minimal elements. In that case argmin will return a minimal index, but not necessarily the first one." 
    best_w, best_phi = to_check[best_idx], to_check_values[best_idx]  # `best_w` is the actual weight, `best_phi` is value of the objective function when passed `best_w` 
    return best_w, best_phi
end 

# this function calculates regret for one player 
function instantaneous_regret(game::Game, last_moves::Matrix{Float64}, player::Int)  # tested, ok  
    """
    computes instantaneous reget vector for one player vs their realized payoff 

    returns Vector{Float64}
    """

    regrets = zeros(game.num_moves)  # init regret vector 
    last_moves_vec = [last_moves[i, :] for i in 1:size(last_moves, 1)]
    player_utility = payoff(game, last_moves_vec)[player]  # compute the player's utility for their last move 
    alt_play = deepcopy(last_moves_vec)  # copy the last moves array to modify it 
    for alt_move in 1:game.num_moves 
        alt_play[player] .= 0.0  # reset the player's action 
        alt_play[player][alt_move] = 1.0  # simulate playing `alt_move` 
        alt_utility = payoff(game, alt_play)[player]  # compute utility for this alternative move 
        regrets[alt_move] = (alt_utility - player_utility)  # compute 
    end
    return regrets
end

end # module 
