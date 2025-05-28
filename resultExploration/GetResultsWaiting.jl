using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

nRequestList = [20,100, 300, 500]
nRuns = 3
relocateVehiclesList = [true,false]
gamma = 0.7 

#===============================#
# Retrieve CSV files 
#===============================#
for n in nRequestList
    for run in 1:nRuns 
        outPutFolder = "runfiles/output/Waiting/"*string(n)*"/Run"*string(run)

        for relocateVehicles in relocateVehiclesList
            outputFiles = Vector{String}()

            # TODO: jas 
            for i in 1:10
                scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)
                push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_"*string(relocateVehicles)*".json")
            end

            # Get CSV
            dfResults = processResults(outputFiles)
            result_file = string(outPutFolder, "/results_", gamma,"_",relocateVehicles, ".csv")
            append_mode = false
            CSV.write(result_file, dfResults; append=append_mode)
        end
    end

end

#===============================#
# Get averages 
#===============================#
function average_kpis_by_data_size(base_path::String,dataSizeList,relocateVehicles)
    all_data = DataFrame()

    for dataSize in dataSizeList
        full_path = joinpath(base_path, string(dataSize), "results_"*string(gamma)*"_"*string(relocateVehicles)*".csv")
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

function average_kpis_by_run(base_path::String,dataSizeList,nRuns,relocateVehicles)
    for n in dataSizeList
        all_runs_data = DataFrame()
        
        for run in 1:nRuns
            filePath = base_path*"/"* string(n) * "/Run" * string(run) * "/results_"*string(gamma)*"_"*string(relocateVehicles)*".csv"
            df = CSV.read(filePath, DataFrame)
            append!(all_runs_data, df)
        end

        all_runs_data[!, :BaseScenario] = replace.(all_runs_data.ScenarioName, r"_Run\d+" => "")

        grouped = groupby(all_runs_data, :BaseScenario)
        avg_data = combine(grouped, names(all_runs_data, Number) .=> mean)

        CSV.write(base_path*"/"*string(n)*"/results_avgOverRuns_"*string(relocateVehicles)*".csv", avg_data)

    end
end

for relocateVehicles in relocateVehiclesList
    average_kpis_by_run("runfiles/output/Waiting/",nRequestList,nRuns,relocateVehicles)
end


#===============================#
# Plot results 
#===============================#
for n in nRequestList
    println("n requests: ",n)
    p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "No. taxis",leftmargin=5mm,topmargin=5mm,legend = :topright)

    nRows = 0
    maxnTaxi = 0
    minnTaxi = typemax(Int)
    for relocateVehicles in relocateVehiclesList
        outPutFolder = "runfiles/output/Waiting/"*string(n)
        resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehicles,".csv")
        df = CSV.read(resultFile, DataFrame)
        nRows = nrow(df)
        maxnTaxi = max(maxnTaxi,maximum(df.nTaxi_mean))
        minnTaxi = min(minnTaxi,minimum(df.nTaxi_mean))

        # Plot 
        color = relocateVehicles ? :blue : :red
        label = relocateVehicles ? "With Relocation" : "Without Relocation"

        plot!(df.nTaxi_mean; linestyle = :dash, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
    end

    tickSpace = 2 

    ylimMin = tickSpace * floor((minnTaxi - 2) / tickSpace)
    ylimMax = tickSpace * ceil((maxnTaxi + 2) / tickSpace)
    xtickLabel = ["Scenario $(i)" for i in 1:nRows]
    xticks!((1:nRows,xtickLabel),rotation=90)
    if n == 500 
        yticks!((ylimMin:10:ylimMax,string.(Int.(ylimMin:10:ylimMax))))
    else 
        yticks!((ylimMin:tickSpace:ylimMax,string.(Int.(ylimMin:tickSpace:ylimMax))))
    end
    ylims!(ylimMin, ylimMax)

    savefig(p, "plots/Waiting/results_$(n).png")
    println("saved plot at: ", "plots/Waiting/results_$(n).png")
end