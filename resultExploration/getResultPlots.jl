using JSON
using Statistics
using Printf

date = "2025-05-26"
base_path = "/zhome/a7/e/146976/MasterThesis/resultExploration/results"
request_sizes = ["300"]
anticipation = "0.4"
methods = ["BaseCase", "InHindsight", "AnticipationKeepExpected"]
run_tags = ["run1", "run2", "run3"]

aggregated_results = Dict{String, Dict{String, Dict{String, Float64}}}()

for method in methods
    method_results = Dict{String, Vector{Dict{String, Float64}}}()

    for run_tag in run_tags
        for n_requests in request_sizes
            folder = method == "BaseCase" || method == "InHindsight" ?
                "$base_path/$date/$run_tag/$method/$n_requests" :
                "$base_path/$date/$run_tag/${method}_$anticipation/$n_requests"

            if isdir(folder)
                for file in readdir(folder)
                    file_path = joinpath(folder, file)
                    try
                        if method == "InHindsight" && endswith(file, ".txt")
                            lines = readlines(file_path)
                            for line in lines
                                m = match(r"Dataset: (\d+), TotalCost: ([\d\.]+), UnservedRequests: (\d+)", line)
                                if m !== nothing
                                    scenario = "Gen_Data_$(n_requests)_$(m.captures[1])"
                                    entry = Dict(
                                        "TotalCost" => parse(Float64, m.captures[2]),
                                        "UnservicedOnlineRequests" => parse(Float64, m.captures[3])
                                    )
                                    push!(get!(method_results, scenario, Vector{Dict{String, Float64}}()), entry)
                                end
                            end
                        elseif endswith(file, ".json")
                            data = JSON.parsefile(file_path)
                            scenario = data["Scenario"]["name"]
                            entry = Dict{String, Float64}()
                            for k in ["TotalCost", "TotalRideTime", "TotalIdleTime", "UnservicedOnlineRequests", "AverageResponseTime"]
                                if haskey(data, k)
                                    entry[k] = data[k]
                                end
                            end
                            push!(get!(method_results, scenario, Vector{Dict{String, Float64}}()), entry)
                        end
                    catch e
                        @warn "Failed to parse $file_path: $e"
                    end
                end
            end
        end
    end

    method_avg = Dict{String, Dict{String, Float64}}()
    for (scenario, entries) in method_results
        avg_metrics = Dict{String, Float64}()
        for metric in keys(entries[1])
            avg_metrics[metric] = mean([entry[metric] for entry in entries if haskey(entry, metric)])
        end
        method_avg[scenario] = avg_metrics
    end

    aggregated_results[method] = method_avg
end

# Print final results
for (method, scenarios) in aggregated_results
    println("Method: $method")
    for (scenario, metrics) in scenarios
        println("  Scenario: $scenario")
        for (metric, avg) in metrics
            @printf("    %-30s : %.2f\n", metric, avg)
        end
    end
end
