using JSON
using Statistics

# Define parameters
base_dir = raw"C:/Users/Astrid/OneDrive - Danmarks Tekniske Universitet/Dokumenter/Master Thesis/MasterThesis/resultExploration/results"
Data = "Final_anticiaption"
method = "AnticipationKeepExpected_long_long_two_online"
nRequests = "300"

# Store averages per instance
averages_fixed = []
averages_expected = []

# Loop over Y (1 to 10) = instance numbers
for Y in 1:10
    values_fixed = Float64[]
    values_expected = Float64[]

    # Loop over X (1 to 5) = runs
    for X in 1:5
        file_path = joinpath(base_dir, Data, method, nRequests,
                             "run$(X)", "Anticipation_KPI_Gen_Data_$(nRequests)_$(Y).json")
        try
            data = JSON.parsefile(file_path)

            avg_objs = data["averageObj"]
            not_serviced_expected = data["nInitialNotServicedExpectedRequests"]
            not_serviced_fixed = data["nInitialNotServicedFixedRequests"]

            # Find index of the minimum objective value
            min_index = argmin(avg_objs)

            # Store the corresponding not serviced value
            push!(values_fixed, not_serviced_fixed[min_index])
            push!(values_expected, not_serviced_expected[min_index])
        catch e
            @warn "Could not open file" file_path exception=e
        end
    end

    # Store average per instance
    push!(averages_fixed, mean(values_fixed))
    push!(averages_expected, mean(values_expected))
end

println("Averages of best-not-serviced-expected per instance:")
println(averages_expected)
println("Averages of best-not-serviced-fixed per instance:")
println(averages_fixed)
