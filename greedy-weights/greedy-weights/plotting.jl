
module Plotting 

using Plots

export plot_strategy_evolution, plot_avg_strategy_history

function plot_strategy_evolution(strategy_history::Dict{Int, Vector{Vector{Float64}}}, player::Int, save_path::String="")

    strategy_data = strategy_history[player]  

    num_moves = length(strategy_data[1]) 
    iterations = length(strategy_data)  

    strategy_matrix = hcat(strategy_data...)'

    plt = plot(
        title="Strategy Evolution for Player $player",
        xlabel="Iteration",
        ylabel="Probability",
        legend=:topright, 
        dpi=300, 
        grid=true,
        gridstyle=:dot
        )

    for move in 1:num_moves
        plot!(plt, 
        1:iterations, 
        strategy_matrix[:, move], 
        label="Move $move")
    end

    # display(plt) 

    if save_path != ""
        savefig(plt, save_path)
        println("Plot saved to: $save_path")
    end
end



"""
plot_avg_strategy_history(avg_history, player, filename; title_prefix="Average Strategy History")

Plot the evolution of a player's *average* mixed strategy over time.

- `avg_history` is Dict{Int, Vector{Vector{Float64}}}
- `player` is the player index (1 or 2)
- `filename` is where to save the PNG
"""
function plot_avg_strategy_history(
    avg_history::Dict{Int, Vector{Vector{Float64}}},
    player::Int,
    filename::String;
    title_prefix::String = "Average Strategy History",
)

    T = length(avg_history[player])          # number of time steps
    num_moves = length(avg_history[player][1])

    p = plot(
        xlabel = "Iteration",
        ylabel = "Average probability",
        title  = "$title_prefix – Player $player",
        legend = :right,
        dpi    = 300,
        size   = (1000, 600),
    )

    # For each action a, plot its avg prob over time
    for a in 1:num_moves
        series_a = [avg_history[player][t][a] for t in 1:T]
        plot!(p, 1:T, series_a, label = "Action $a", lw = 1.5)
    end

    savefig(p, filename)
    println("Saved avg strategy history for player $player to $filename")
end


end  # module