using CSV
using DataFrames
using Printf
using Statistics
using ExcelFiles

# Parameters
methods = ["Anticipation_0.5", "Anticipation_0.9"]
run_tags = ["2025-05-12_run1", "2025-05-12_run2", "2025-05-12_run3"]
n_requests_list = [20, 100, 300, 500]
base_dir = joinpath(@__DIR__, "results")

# Output DataFrames
all_run_results = DataFrame()
averaged_results = DataFrame()

# Excel File for output
excel_file = "hierarchical_results_table.xlsx"

# Write to Excel
@xlsx begin
    for method in methods
        anticipation = parse(Float64, split(method, "_")[end])  # Extract 0.5 or 0.9
        
        for n_requests in n_requests_list
            run_dfs = DataFrame[]

            for run_tag in run_tags
                filepath = string(base_dir)*"/"*string(run_tag)*"/"*string(method)*"/"*string(n_requests)*"/results.csv"
                if isfile(filepath)
                    df = CSV.read(filepath, DataFrame)
                    df[!, :method] = fill(method, nrow(df))
                    df[!, :anticipation] = fill(anticipation, nrow(df))
                    df[!, :n_requests] = fill(n_requests, nrow(df))
                    df[!, :run_tag] = fill(run_tag, nrow(df))
                    push!(run_dfs, df)
                    append!(all_run_results, df)
                else
                    println("Run: $run_tag — Missing")
                end
            end

            if !isempty(run_dfs)
                combined = vcat(run_dfs...)
                numeric_cols = names(combined, Number)

                # Add AVERAGE row
                avg_row = combine(combined, numeric_cols .=> mean)
                avg_row[!, :run_tag] .= "AVERAGE"
                avg_row[!, :method] .= method
                avg_row[!, :anticipation] .= anticipation
                avg_row[!, :n_requests] .= n_requests

                # Combine for Excel formatting
                display_df = vcat(combined[:, [:run_tag; numeric_cols]], avg_row[:, [:run_tag; numeric_cols]])

                # Add method and anticipation info as headers
                sheet_name = "Method_$method Requests_$n_requests"
                @sheet sheet_name begin
                    # First row with headers
                    headers = ["Method", "Anticipation", "Number of Requests", string.(numeric_cols)]
                    append!(display_df, [method, anticipation, n_requests], 1)

                    # Write the DataFrame to the Excel sheet
                    DataFrame(headers)  # Add header row
                    append!(display_df)
                end
            else
                println("No valid data to average for $method with $n_requests requests")
            end
        end
    end
end
