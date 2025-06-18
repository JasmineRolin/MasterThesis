using JSON
using DataFrames
using Statistics
using CSV

# Define parameters
base_dir = "C:/Users/Astrid/OneDrive - Danmarks Tekniske Universitet/Dokumenter/Master Thesis/MasterThesis/resultExploration/results"
Data = "2025-06-14_tables_long"             # Example value
method = "AnticipationKeepExpected_0.4"         # Example value
nRequests = "300"   # Example value
nRequest = 120
# A FILE LOOK LIKE THIS: C:\Users\Astrid\OneDrive - Danmarks Tekniske Universitet\Dokumenter\Master Thesis\MasterThesis\resultExploration\results\2025-06-14_tables\AnticipationKeepExpected_0.4\100\run1\whatHappensToExpectedRequests_Gen_Data_100_10.json

# Build matrix as list of rows
result_matrix = Matrix{Float64}(undef, 10, 6)
result_matrix_percent = Matrix{Float64}(undef, 10, 6)

# Loop over Y (1 to 10)
for Y in 1:10
    run_data = []
    run_data_percent = []

    # Loop over X (1 to 5)
    for X in 1:5
        file_path = joinpath(base_dir, Data, method, nRequests,
                             "run$(X)", "whatHappensToExpectedRequests_Gen_Data_$(nRequests)_$(Y).json")
        try
            open(file_path, "r") do io
                data = JSON.parse(IOBuffer(read(io, String)))
                push!(run_data, data)
                push!(run_data_percent, data/nRequest)
            end
        catch e
            @warn "Could not open file" file_path exception=e
        end
    end

    if !isempty(run_data)
        avg_vector = mean(reduce(hcat, run_data), dims=2)[:]
        result_matrix[Y, :] = avg_vector

        avg_vector_percent = mean(reduce(hcat, run_data_percent), dims=2)[:]
        result_matrix_percent[Y, :] = avg_vector_percent
    else
        result_matrix[Y, :] .= NaN
        result_matrix[Y, :] .= NaN
    end
end

# Convert to DataFrame
df = DataFrame(result_matrix, :auto)

rename!(df, Symbol.("Case_", 1:6))
df.Instance = "Y_" .* string.(1:10)

average_row = mean(result_matrix_percent,dims=1)
df_average = DataFrame(average_row,:auto)
rename!(df_average, Symbol.("Case_", 1:6))
df_average[!,"Instance"].= "Average"


# Format values as percentages (e.g., 0.75 → "75%")
for col in names(df_average)
    if col != :Instance && eltype(df_average[!, col]) <: Number
        df_average[!, col] = string.(round.(df_average[!, col] .* 100; digits=0)) .* "%"
    end
end


# Save to CSV
CSV.write("whatHappendToExpected_$(nRequests)_$(method)_long.csv", df)
CSV.write("whatHappendToExpected_$(nRequests)_$(method)_average_long.csv", df_average)

println("Averaged results saved to 'averaged_results.csv'.")
