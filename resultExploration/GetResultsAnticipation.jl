using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

methodListBase = ["Anticipation","BaseCase"]
nRequestList = [300]
runList = [1,2,3]
gamma = 0.5
anticipationDegrees = [0.4]
date = "2025-05-22_expCost100"

#==============================#
# Create method list 
#==============================#
methodList = []
for method in methodListBase
    if method == "Anticipation"
        for anticipationDegree in anticipationDegrees
            push!(methodList,"Anticipation_"*string(anticipationDegree))
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
        for n in nRequestList            
            outPutFolder = "resultExploration/results/"*date*"/"*method*"/"*string(n)*"/run"*string(run)
            outputFiles = Vector{String}()

            for i in 1:10
                scenarioName = string("Gen_Data_",n,"_",i,"_false")
                push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
            end

            # Get CSV
            dfResults = processResults(outputFiles)
            result_file = string(outPutFolder, "/results", ".csv")
            append_mode = false
            println(result_file)
            CSV.write(result_file, dfResults; append=append_mode)
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
        resultFile = "resultExploration/results/" * date * "/" * method * "/" * string(n) * "/results_avgOverRuns.csv"
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
    end

    # Configure each subplot
    ylabels = ["No. taxis", "Unserviced Offline Requests", "Unserviced Online Requests"]
    for i in 1:3
        ylimMin = 5 * floor((minVals[i] - 2) / 5)
        ylimMax = 5 * ceil((maxVals[i] + 2) / 5)
        yticksStep = n == 500 ? 10 : 5
        plot!(plots[i], xticks=(1:nRows, xtickLabel), xrotation=90, ylabel=ylabels[i], ylims=(ylimMin, ylimMax), yticks=ylimMin:yticksStep:ylimMax)
    end

    # Compose the final plot
    mkdir("plots/Anticipation/"*date*"/")

    finalPlot = plot(plots[1], plots[2], plots[3]; layout=(3,1), size=(1000,1200),leftmargin=5mm,bottommargin=5mm,topmargin=5mm)
    savefig(finalPlot, "plots/Anticipation/"*date*"/results_$(n).png")
end

