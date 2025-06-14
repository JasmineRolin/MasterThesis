using JSON
using DataFrames
using Statistics
using CSV

# Define parameters
base_dir = "C:/Users/Astrid/OneDrive - Danmarks Tekniske Universitet/Dokumenter/Master Thesis/MasterThesis/resultExploration/results"
Data = "2025-06-14_tables"             # Example value
method = "AnticipationKeepExpected_0.4"         # Example value
nRequests = "20"   # Example value
# A FILE LOOK LIKE THIS: C:\Users\Astrid\OneDrive - Danmarks Tekniske Universitet\Dokumenter\Master Thesis\MasterThesis\resultExploration\results\2025-06-14_tables\AnticipationKeepExpected_0.4\100\run1\whatHappensToExpectedRequests_Gen_Data_100_10.json

# Build matrix as list of rows
result_matrix = Matrix{Float64}(undef, 10, 6)

# Loop over Y (1 to 10)
for Y in 1:10
    run_data = []

    # Loop over X (1 to 5)
    for X in 1:5
        file_path = joinpath(base_dir, Data, method, nRequests,
                             "run$(X)", "whatHappensToExpectedRequests_Gen_Data_$(nRequests)_$(Y).json")
        try
            open(file_path, "r") do io
                data = JSON.parse(IOBuffer(read(io, String)))
                push!(run_data, data)
            end
        catch e
            @warn "Could not open file" file_path exception=e
        end
    end

    if !isempty(run_data)
        avg_vector = mean(reduce(hcat, run_data), dims=2)[:]
        result_matrix[Y, :] = avg_vector
    else
        result_matrix[Y, :] .= NaN
    end
end

# Convert to DataFrame
df = DataFrame(result_matrix, :auto)
println(df)
rename!(df, Symbol.("Case_", 1:6))
df.Instance = "Y_" .* string.(1:10)
select!(df, :Instance, Not(:Instance))

# Save to CSV
CSV.write("whatHappendToExpected_$(nRequests)_$(method).csv", df)

println("Averaged results saved to 'averaged_results.csv'.")
