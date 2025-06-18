using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

methodListBase = ["InHindsight" "BaseCase" "AnticipationKeepExpected" "AnticipationKeepExpected_long" "AnticipationKeepExpected_long_long" "AnticipationKeepExpected_long_long_two"] # "AnticipationKeepExpected_long" "AnticipationKeepExpected_long_long" "AnticipationKeepExpected_long_long_two"]
nRequestList = [300]
runList = [1,2,3,4,5]
gamma = 0.5
anticipationDegrees = [0.4]
#date = "2025-06-04_original_0.7"
date = "Final_anticiaption - v2"
name = "Base-InHind-Anti-300"

# Define display names
legend_names = Dict(
    "InHindsight" => "In-hindsight",
    "BaseCase" => "Base method",
    "AnticipationKeepExpected_0.4" => "Anticipation",
    "AnticipationKeepExpected_long" => "Anticipation IIa",
    "AnticipationKeepExpected_online" => "Anticipation Ib",
    "AnticipationKeepExpected_long_online" => "Anticipation IIb",
    "AnticipationKeepExpected_long_long_online" => "Anticipation IIIb",
    "AnticipationKeepExpected_long_long_two_online" => "Anticipation IVb",
    "AnticipationKeepExpected_long_long" => "Anticipation IIIa",
    "AnticipationKeepExpected_long_long_two" => "Anticipation IVa",
)


colors = Dict(
    "InHindsight" => :gray30,
    "BaseCase" => :steelblue,
    "AnticipationKeepExpected_0.4" => :forestgreen,
    "AnticipationKeepExpected_long" => :darkorange,
    "AnticipationKeepExpected_online" => :mediumvioletred,
    "AnticipationKeepExpected_long_online" => :darkorange,
    "AnticipationKeepExpected_long_long_online" => :darkgoldenrod,  # deeper and more distinct than goldenrod
    "AnticipationKeepExpected_long_long_two_online" => :deepskyblue,  # brighter than teal and visually distinct
    "AnticipationKeepExpected_long_long" => :darkgoldenrod,
    "AnticipationKeepExpected_long_long_two" => :deepskyblue
)


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
    plots = [plot(legend=:outerright,guidefontsize=20,tickfontsize=20,legendfontsize=20,titlefontsize=26) for _ in 1:3]

    for method in methodList

        if method != "InHindsight"
            resultFile = "resultExploration/results/" * date * "/" * method * "/" * string(n) * "/results_avgOverRuns.csv"
            df = CSV.read(resultFile, DataFrame)

            nRows = nrow(df)
            xtickLabel = ["Inst. $(i)" for i in 1:nRows]
            # Track global min/max
            maxVals[1] = max(maxVals[1], maximum(df.nTaxi_mean))
            minVals[1] = min(minVals[1], minimum(df.nTaxi_mean))
            maxVals[2] = max(maxVals[2], maximum(df.UnservicedOfflineRequest_mean))
            minVals[2] = min(minVals[2], minimum(df.UnservicedOfflineRequest_mean))
            maxVals[3] = max(maxVals[3], maximum(df.UnservicedOnlineRequests_mean))
            minVals[3] = min(minVals[3], minimum(df.UnservicedOnlineRequests_mean))

            if method in ["BaseCase"]
                linestyle = :dash
            else
                linestyle = :dot
            end

            # Plot each metric
            plot!(plots[1], df.nTaxi_mean; linestyle=linestyle, marker=:diamond, label=legend_names[method], linewidth=3, markersize=6, markerstrokewidth=0, color=colors[method])
            plot!(plots[2], df.UnservicedOfflineRequest_mean; linestyle=linestyle, marker=:diamond, label=legend_names[method], linewidth=3, markersize=6, markerstrokewidth=0, color=colors[method])
            plot!(plots[3], df.UnservicedOnlineRequests_mean; linestyle=linestyle, marker=:diamond, label=legend_names[method], linewidth=3, markersize=6, markerstrokewidth=0, color=colors[method])
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
            plot!(plots[1], df.nTaxi_mean; linestyle=:dash, marker=:diamond, label=legend_names[method], linewidth=3, markersize=6, markerstrokewidth=0, color=colors[method])
        end
    end

    # Configure each subplot
    ylabels = ["No. Unserviced Requests", "No. Unserviced Offline Requests", "No. Unserviced Online Requests"]
    for i in 1:3
        ylimMin = 5 * floor((minVals[i] - 2) / 5)
        ylimMax = 5 * ceil((maxVals[i] + 2) / 5)
        yticksStep = n == 500 ? 10 : 5
        plot!(plots[i], xticks=(1:nRows, xtickLabel), xrotation=90, ylabel=ylabels[i], ylims=(ylimMin, ylimMax), yticks=ylimMin:yticksStep:ylimMax)
    end

    # Compose the final plot
    if !isdir("plots/Anticipation/PlotsReport/"*name*"/")
        mkpath("plots/Anticipation/PlotsReport/"*name*"/")
    end

    finalPlot = plot(plots[2], plots[3]; layout=(2,1), size=(1000,2000),leftmargin=5mm,bottommargin=10mm,topmargin=5mm)
    savefig(finalPlot, "plots/Anticipation/PlotsReport/$(name)/results_$(n).pdf")
    singlePlot = plot(plots[1]; title = "No. Requests: $(n), Gamma: $(gamma)",size=(1500,750),leftmargin=10mm,bottommargin=15mm,topmargin=10mm,rightmargin=10mm)
    savefig(singlePlot, "plots/Anticipation/PlotsReport/$(name)/results_$(n)_single.pdf")
end

