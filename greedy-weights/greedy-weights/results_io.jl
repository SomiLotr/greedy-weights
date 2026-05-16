module ResultsIO

using CSV
using DataFrames
using Dates
using UUIDs

export save_regrets_csv, save_time_regrets_csv, next_available_index, format_with_index, regrets_from_result, unique_run_suffix

"""
Return the first unused index for `<base>_<XX><ext>` across the provided extensions.
Creates parent directories when needed.
"""
function next_available_index(base::String, exts::Vector{String})
    mkpath(dirname(base))
    i = 1

    while any(isfile(format_with_index(base, i, ext)) for ext in exts)
        i += 1
    end

    return i
end

"""
Format `<base>_<XX><ext>` using a fixed two-digit index.
"""
format_with_index(base::String, idx::Integer, ext::String) =
    string(base, "_", lpad(string(idx), 2, '0'), ext)

"""
Return a unique run suffix combining timestamp and short UUID to avoid collisions.
"""
function unique_run_suffix()
    ts = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
    uid = string(uuid4())[1:8]
    return string(ts, "_", uid)
end

"""
Write per-iteration exploitability for each algorithm into a CSV.

`regrets` maps algorithm names to their regret vectors. Shorter vectors are
padded with `missing` so every column has the same length.
"""
function save_regrets_csv(
    filepath::String,
    regrets::AbstractDict{<:AbstractString, <:AbstractVector{<:Real}},
)
    max_len = maximum(length.(values(regrets)))
    df = DataFrame(iteration = 1:max_len)

    for (name, values) in regrets
        padded = Vector{Union{Float64, Missing}}(undef, max_len)
        padded .= missing
        padded[1:length(values)] = values
        df[!, Symbol(name)] = padded
    end

    mkpath(dirname(filepath))
    CSV.write(filepath, df)
    println("Saved regrets to $filepath")
    return filepath
end


"""
Write time-stamped exploitability for each algorithm into a CSV.

`series` maps algorithm names to `(times, regrets)` tuples. Shorter vectors are
padded with `missing` so every column has the same length.
"""
function save_time_regrets_csv(
    filepath::String,
    series::AbstractDict{
        <:AbstractString,
        <:Tuple{<:AbstractVector, <:AbstractVector},
    },
)
    max_len = maximum(max(length(t), length(r)) for (t, r) in values(series))
    df = DataFrame(row = 1:max_len)

    for (name, (times, regrets)) in series
        tcol = Vector{Union{Float64, Missing}}(fill(missing, max_len))
        rcol = similar(tcol)
        # convert to Float64 while allowing untyped vectors
        times_f = Float64.(collect(times))
        regrets_f = Float64.(collect(regrets))
        tcol[1:length(times_f)] = times_f
        rcol[1:length(regrets_f)] = regrets_f
        df[!, Symbol("time_" * name)] = tcol
        df[!, Symbol("regret_" * name)] = rcol
    end

    mkpath(dirname(filepath))
    CSV.write(filepath, df)
    println("Saved time/regret series to $filepath")
    return filepath
end


"""
Pull out algorithm regrets from the result tuple returned by `run_and_collect`.
"""
function regrets_from_result(result_tuple)
    # unpack first 12 entries: regrets and their iteration counters
    regret_gw, _, regret_fp, _, regret_mwu, _, regret_rm, _, regret_rmplus, _, regret_prm, _ =
        result_tuple[1:12]

    return Dict(
        "GW" => regret_gw,
        "FP" => regret_fp,
        "MWU" => regret_mwu,
        "RM" => regret_rm,
        "RM_plus" => regret_rmplus,
        "PRM" => regret_prm,
    )
end

end # module
