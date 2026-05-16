import Pkg 
Pkg.activate(@__DIR__)

# include("greedy-weights/ugh.jl")
# Pokus.hello()


include("src/Game.jl")
include("exploitability.jl")
include("src/RegretMinimization.jl") 
include("src/plotting.jl") 
include("src/minmax.jl")
# include("fictitious_play/fictitious_play.jl")
# include("mwu/mwu.jl")



using .GameModule 
using .RegretMinimization
using .Exploitability
using .Plotting
using .MinMaxSolver
using .FictitiousPlay
using .MWURunner

using Random, StatsBase, Distributions, Plots, CSV, DataFrames, LinearAlgebra, Measures, ColorSchemes

ENV["GKSwstype"] = "100"  # some errors with opening gkswt permissions 



pal = cgrad(:plasma, 10, categorical = true)
# gw:4, fp: 7

function run_and_collect(game::Game, label_prefix::String, color_gw=pal[2], color_fp=pal[7], color_mwu=pal[8], color_rm=pal[4], color_rmplus=pal[5], color_prm=pal[6], linestyle_gw=:dashdot, linestyle_fp=:dot, linestyle_mwu=:dash, linestyle_rm=:solid, linestyle_rmplus=:dashdotdot, linestyle_prm=:dashdotdot)
    
    # Run Greedy Weights
    ALL_MOVES, REGRET, WEIGHTS, CLOCK, strat_hist, avg_hist = external_regret(game, iterations, target_epsilon, time_limit)
    regret_gw = compute_exploitability_avg_history(game, avg_hist)
    # time_gw = CLOCK[1:length(regret_gw)] .- CLOCK[1]
    iters_gw = 1:length(regret_gw)
    println("gw done")

    # # Run Double Oracle
    # A = game.matrix[:,:,1]
    # B = game.matrix[:,:,2]
    # oracle = matrix_oracle((A,B))
    # _, (_, _, _, _, _), timestamps, regret_do = until_eps(oracle, target_epsilon, time_limit)
    # println("do done")

    # Run Fictitious Play 
    regret_fp, time_fp, strat_history_fp = run_fictitious_play(game; iterations=iterations, time_limit=time_limit)
    iters_fp = 1:length(regret_fp)
    println("fp done")

    # Run MWU (decaying epsilon version)
    regret_mwu, iters_mwu, _ = run_mwu(game, iterations; record_every=1)
    println("mwu done")

    # Run Regret Matching (static, no plus)
    regret_rm, iters_rm = begin
        _, _, _, _, _, avg_hist_rm = external_regret(game, iterations, target_epsilon, time_limit; static=true)
        (compute_exploitability_avg_history(game, avg_hist_rm), 1:length(avg_hist_rm[1]))
    end
    println("rm done")

    # Run Regret Matching+ (static, plus)
    regret_rmplus, iters_rmplus = begin
        _, _, _, _, _, avg_hist_rmplus = external_regret(game, iterations, target_epsilon, time_limit; static=true, plus=true)
        (compute_exploitability_avg_history(game, avg_hist_rmplus), 1:length(avg_hist_rmplus[1]))
    end
    println("rm+ done")

    # Run Predictive Regret Matching (static==true, plus==true, predictive==true, prediction = last instaregret)
    regret_prm, iters_prm = begin
        _, _, _, _, _, avg_hist_prm = external_regret(game, iterations, target_epsilon, time_limit; static=true, plus=true, predictive=true)
        (compute_exploitability_avg_history(game, avg_hist_prm), 1:length(avg_hist_prm[1]))
    end
    println("prm done")


    plot_avg_strategy_history(
        avg_hist, 1, 
        "media/AVG_STRAT/player1_$(label_prefix)_$(game_size)_$(time_limit)s.png";
        title_prefix = "avg strategy"
    )

    ########## testing explo etc ##########
    # q1_last = avg_hist[1][end]
    # q2_last = avg_hist[2][end]
    # avg_mat_last = vcat(q1_last', q2_last')
    # final_explo = compute_exploitability_avg(game, avg_mat_last)
    # v_avg = payoff(game, [q1_last, q2_last])[1]
    # # ----- Minmax LP -----
    # x_minmax, v_minmax = minmax_solution(game)
    # println("[$label_prefix] final avg exploitability = $(final_explo)")
    # println("[$label_prefix] LP minmax value v*       = $(v_minmax)")
    #######################################

    return (
        # regret_gw, time_gw,
        regret_gw, iters_gw,
        # regret_do, timestamps,
        # regret_fp, time_fp,
        regret_fp, iters_fp,
        regret_mwu, iters_mwu,
        regret_rm, iters_rm,
        regret_rmplus, iters_rmplus,
        regret_prm, iters_prm,
        # label_prefix, color_gw, color_do, color_fp, 
        # linestyle_gw, linestyle_do, linestyle_fp
        label_prefix, color_gw, color_fp, color_mwu, color_rm, color_rmplus, color_prm,
        linestyle_gw, linestyle_fp, linestyle_mwu, linestyle_rm, linestyle_rmplus, linestyle_prm
    )

end # run_and_collect() 

# :solid, :dot, :dash, :dashdot, :dashdotdot, :dashdotdotdot 

players = 2
target_epsilon = 0.00

"""
game types: 

matching_pennies
rps
rps_k 
morra
morra_k
blotto_n-p
transitive_k
symmetric_k
/random/ size
"""

results = []




time_limit = Inf
iterations = 10

########## Morra Game ##########
# morra_size = 14
# game_size = morra_size^2
# folder_name = "MORRA"
# special_type_morra = "morra_$(morra_size)"
# special_type = special_type_morra
# push!(results, run_and_collect(Game(players, game_size, special_type_morra), "Morra_$(morra_size)_$(game_size)"))
################################

########## Blotto ##########
blotto_size_n = 9
blotto_size_p = 4
folder_name = "BLOTTO"
game_size = binomial(blotto_size_n + blotto_size_p -1, blotto_size_p)
special_type_blotto = "blotto_$(blotto_size_n)-$(blotto_size_p)"
special_type = special_type_blotto
push!(results, run_and_collect(Game(players, game_size, special_type_blotto), "Blotto_$(blotto_size_n)-$(blotto_size_p)"))
############################

########## RPS_k ########## 
# game_size = 499
# folder_name = "RPS"
# special_type_rps = "rps_$(game_size)"
# special_type = special_type_rps
# push!(results, run_and_collect(Game(players, game_size, special_type_rps), "RPS_$(game_size)"))
###########################

######### Transitive_k ########## 
# game_size = 500
# folder_name = "TRANSITIVE"
# special_type_trans = "transitive_$(game_size)"
# special_type = special_type_trans
# push!(results, run_and_collect(Game(players, game_size, special_type_trans), "Transitive_$(game_size)", pal[3], pal[4]))
##################################

########## Symmetric_k ##########
# game_size = 50
# folder_name = "SYMMETRIC"
# special_type_sym = "symmetric_$(game_size)"
# special_type = special_type_sym
# push!(results, run_and_collect(Game(players, game_size, special_type_sym), "Symmetric_$(game_size)"))
#################################

######### Random Game ##########
# game_size = 500
# folder_name = "RANDOM"
# special_type_random = "random_$(game_size)"
# special_type = special_type_random
# push!(results, run_and_collect(Game(players, game_size, special_type_random), "Random_$(game_size)"))
#################################

########## Matching Pennies ##########
# game_size = 2
# folder_name = "PENNIES"
# special_type_pennies = "matching_pennies"
# special_type = special_type_pennies
# push!(results, run_and_collect(Game(players, game_size, special_type_pennies), "Matching Pennies"))
################################


# results[1] ~ the first game running, but the plotting is not ready for more bcs im lazy af 
# title_label = isempty(results) ? "" : results[1][11]
# # short title: "<game>: <size>"
# plot_title = isempty(title_label) ? "size: $(game_size)" : "$title_label: $(game_size)"

plot_title = results[1][11]

p = plot(
    xlabel = "Iterations",
    ylabel = "Exploitability", 
    title = "$(special_type): $(game_size)×$(game_size)",
    # title = "Greedy Weights vs Double Oracle\nTime Limit: $(time_limit)s",
    # ylims = (0, ylim),
    legend = :none, 
    # linesize = 70,
    # lw = 2, 
    # thickness_scaling = 3, 
    yscale = :log10,
    ylims = (1e-15,1e-1),
    # ylims = (0,10),
    dpi = 300,
    size = (600,450) 
    # left_margin=10mm, 
    # bottom_margin=5mm,
    # right_margin=13mm, 
    # top_margin=20mm
)


# # for loop: GW, DO, FP
# for (regret_gw, time_gw, regret_do, time_do, regret_fp, time_fp, label, color_gw, color_do, color_fp, style_gw, style_do, style_fp) in results
#     plot!(p, time_gw, regret_gw, label = "$label GW", color = color_gw, linestyle = style_gw, lw=1)
#     plot!(p, time_do, regret_do, label = "$label DO", color = color_do, linestyle = style_do, lw=1)
#     plot!(p, time_fp, regret_fp, label = "$label FP", color = color_fp, linestyle = style_fp, lw=1)
# end

# for loop: GW, FP, MWU, RM, RM+, PRM
for (regret_gw, iters_gw, regret_fp, iters_fp, regret_mwu, iters_mwu, regret_rm, iters_rm, regret_rmplus, iters_rmplus, regret_prm, iters_prm, label, color_gw, color_fp, color_mwu, color_rm, color_rmplus, color_prm, style_gw, style_fp, style_mwu, style_rm, style_rmplus, style_prm) in results
    plot!(p, iters_gw, regret_gw, label = "GW", color = color_gw, linestyle = style_gw, lw=1)
    plot!(p, iters_fp, regret_fp, label = "FP", color = color_fp, linestyle = style_fp, lw=1)
    plot!(p, iters_mwu, regret_mwu, label = "MWU", color = color_mwu, linestyle = style_mwu, lw=1)
    plot!(p, iters_rm, regret_rm, label = "RM", color = color_rm, linestyle = style_rm, lw=1)
    plot!(p, iters_rmplus, regret_rmplus, label = "RM+", color = color_rmplus, linestyle = style_rmplus, lw=1)
    plot!(p, iters_prm, regret_prm, label = "PRM", color = color_prm, linestyle = style_prm, lw=1)
end

base = "media/old/$(folder_name)/it_$(game_size)_$(iterations)"
ext = ".png"

comment = ""

let
    i = 1
    filename = base * "_" * lpad(string(i), 2, '0') * ext

    while isfile(filename)
        i += 1
        filename = base * "_" * lpad(string(i), 2, '0') * ext
    end
    
    savefig(p, filename)
    println("Saved combined plot to $filename")
end

# filename = "media/COMBINED/gw_vs_do_$(time_limit)s.png"
# mkpath(dirname(filename))
