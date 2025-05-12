
using CSV, DataFrames, Statistics

function average_kpis_by_data_size(base_path::String)
    all_data = DataFrame()

    for dataSize in [20, 100, 300]
        full_path = joinpath(base_path, string(dataSize), "results.csv")
        df = CSV.read(full_path, DataFrame)
        df[!, :DataSize] = fill(dataSize, nrow(df))
        append!(all_data, df)
    end

    # Select all KPI columns (excluding identifiers like ScenarioName)
    exclude_cols = [:ScenarioName]
    kpi_cols = names(all_data, Not(vcat(exclude_cols, [:DataSize])))

    # Compute average for each KPI grouped by DataSize
    grouped = combine(groupby(all_data, :DataSize),
        kpi_cols .=> mean ∘ skipmissing .=> kpi_cols)

    return grouped
end

date = "12-05-2025"
folder = "BaseCase"

results_df = average_kpis_by_data_size("resultExploration/results/"*date*"/"*folder)
CSV.write("resultExploration/results/"*date*"/"*folder*"/average_results_by_size.csv", results_df)