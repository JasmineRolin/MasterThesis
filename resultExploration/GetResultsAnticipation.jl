using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

methodListBase = ["AnticipationKeepExpected" "BaseCase" "InHindsight"]
nRequestList = [300,500]
runList = [1,2,3,4,5]
gamma = 0.5
anticipationDegrees = [0.4]
date = "2025-05-31_original_v2_0.5_long_online"

#==============================#
# Create method list 
#==============================#
methodList = []
for method in methodListBase
    if method == "AnticipationKeepExpected"
        for anticipationDegree in anticipationDegrees
            push!(methodList,"AnticipationKeepExpected_"*string(anticipationDegree))
        end
    else
        push!(methodList,method)
    end
end


#===============================#
# Retrieve CSV files 
#===============================#
for run in runList
    for method in methodList
        if method != "InHindsight"
            for n in nRequestList            
                outPutFolder = "resultExploration/results/"*date*"/"*method*"/"*string(n)*"/run"*string(run)
                outputFiles = Vector{String}()

                for i in 1:10
                    scenarioName = string("Gen_Data_",n,"_",i,"_false")
                    push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
                end

                # Get CSV
                if !isdir(outPutFolder)
                    mkpath(outPutFolder)
                end
                dfResults = processResults(outputFiles)
                result_file = string(outPutFolder, "/results", ".csv")
                append_mode = false
                CSV.write(result_file, dfResults; append=append_mode)
            end
        else
            for n in nRequestList
                all_runs_data = DataFrame()
                outPutFolder = "resultExploration/results/" * date * "/" * method * "/" * string(n) * "/run" * string(run)
                if !isdir(outPutFolder)
                    mkpath(outPutFolder)
                end
            
                results = DataFrame(
                    ScenarioName = String[],
                    nTaxi = Int[], 
                    TotalCost = Float64[],
                )
            
                for i in 1:10
                    file_path = "resultExploration/results/"*date*"/"* method*"/"* string(n) * "/run" * string(run) *"/Simulation_KPI_Gen_Data_$(n)_$(i)_false.txt"
                    if isfile(file_path)
                        for line in eachline(file_path)
                            m = match(r"Dataset:\s*(\d+),\s*TotalCost:\s*([\d\.]+),\s*UnservedRequests:\s*(\d+)", line)
                            if m !== nothing
                                scenario_name = "Gen_Data_$(n)_$(m.captures[1])"
                                row = DataFrame(ScenarioName=scenario_name,
                                                TotalCost=parse(Float64, m.captures[2]),
                                                nTaxi=parse(Int, m.captures[3]))
                                append!(all_runs_data, row)
                            end
                        end
                    else
                        @warn "Missing file: $file_path"
                    end
                end
            
                CSV.write(joinpath(outPutFolder, "results.csv"), all_runs_data)
            end
        end
    end
end

#===============================#
# Get averages 
#===============================#
function average_kpis_by_run(base_path::String,dataSizeList,runList,method)

        for n in dataSizeList
            all_runs_data = DataFrame()
            
            for run in runList
                filePath = base_path* method*"/"* string(n) * "/run" * string(run) * "/results.csv"
                df = CSV.read(filePath, DataFrame)
                append!(all_runs_data, df)
            end

            grouped = groupby(all_runs_data, :ScenarioName)
            avg_data = combine(grouped, names(all_runs_data, Number) .=> mean)

            CSV.write(base_path*"/"*method*"/"*string(n)*"/results_avgOverRuns"*".csv", avg_data)

        end
    

end

for method in methodList
    results_df = average_kpis_by_run("resultExploration/results/"*date*"/",nRequestList,runList,method)
end


#===============================#
# Plot results 
#===============================#
for n in nRequestList

    # Determine number of scenarios
    nRows = 0
    xtickLabel = String[]
    maxVals = fill(-Inf, 3)
    minVals = fill(Inf, 3)

    # Create containers for each metric
    plots = [plot(legend=:topright) for _ in 1:3]

    for method in methodList

        if method != "InHindsight"
            resultFile = "resultExploration/results/" * date * "/" * method * "/" * string(n) * "/results_avgOverRuns.csv"
            println(resultFile)
            df = CSV.read(resultFile, DataFrame)

            nRows = nrow(df)
            xtickLabel = ["Scenario $(i)" for i in 1:nRows]
            # Track global min/max
            maxVals[1] = max(maxVals[1], maximum(df.nTaxi_mean))
            minVals[1] = min(minVals[1], minimum(df.nTaxi_mean))
            maxVals[2] = max(maxVals[2], maximum(df.UnservicedOfflineRequest_mean))
            minVals[2] = min(minVals[2], minimum(df.UnservicedOfflineRequest_mean))
            maxVals[3] = max(maxVals[3], maximum(df.UnservicedOnlineRequests_mean))
            minVals[3] = min(minVals[3], minimum(df.UnservicedOnlineRequests_mean))

            # Plot each metric
            plot!(plots[1], df.nTaxi_mean; linestyle=:dash, marker=:circle, label=method, linewidth=2, markersize=5, markerstrokewidth=0)
            plot!(plots[2], df.UnservicedOfflineRequest_mean; linestyle=:solid, marker=:diamond, label=method, linewidth=2, markersize=5, markerstrokewidth=0)
            plot!(plots[3], df.UnservicedOnlineRequests_mean; linestyle=:dot, marker=:star5, label=method, linewidth=2, markersize=5, markerstrokewidth=0)
        else
            # Handle InHindsight separately
            resultFile = "resultExploration/results/" * date * "/" * method * "/" * string(n) * "/results_avgOverRuns.csv"
            df = CSV.read(resultFile, DataFrame)

            nRows = nrow(df)
            xtickLabel = ["Scenario $(i)" for i in 1:nRows]

            # Track global min/max
            maxVals[1] = max(maxVals[1], maximum(df.nTaxi_mean))
            minVals[1] = min(minVals[1], minimum(df.nTaxi_mean))

            # Plot each metric
            plot!(plots[1], df.nTaxi_mean; linestyle=:dash, marker=:circle, label=method, linewidth=2, markersize=5, markerstrokewidth=0)
        end
    end

    # Configure each subplot
    ylabels = ["Unserviced Requests", "Unserviced Offline Requests", "Unserviced Online Requests"]
    for i in 1:3
        ylimMin = 5 * floor((minVals[i] - 2) / 5)
        ylimMax = 5 * ceil((maxVals[i] + 2) / 5)
        yticksStep = n == 500 ? 10 : 5
        plot!(plots[i], xticks=(1:nRows, xtickLabel), xrotation=90, ylabel=ylabels[i], ylims=(ylimMin, ylimMax), yticks=ylimMin:yticksStep:ylimMax)
    end

    # Compose the final plot
    if !isdir("plots/Anticipation/"*date*"_noAnti/")
        mkpath("plots/Anticipation/"*date*"_noAnti/")
    end

    finalPlot = plot(plots[1], plots[2], plots[3]; layout=(3,1), size=(1000,1200),leftmargin=5mm,bottommargin=5mm,topmargin=5mm)
    savefig(finalPlot, "plots/Anticipation/"*date*"_noAnti/results_$(n).png")
    singlePlot = plot(plots[1]; title = "No. Requests: $(n), Gamma: $(gamma)")
    savefig(singlePlot, "plots/Anticipation/$(date)_noAnti/results_$(n)_single.png")
end

