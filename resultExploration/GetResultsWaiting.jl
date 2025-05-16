using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

nRequestList = [20,100,300,500]
relocateVehiclesList = [true,false]
gamma = 0.7 

#===============================#
# Retrieve CSV files 
#===============================#
for n in nRequestList
    outPutFolder = "runfiles/output/Waiting/"*string(n)

    for relocateVehicles in relocateVehiclesList
        outputFiles = Vector{String}()

        for i in 1:20:81
            scenarioName = string("Gen_Data_",n,"_",gamma,"_",i)
            push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_"*string(relocateVehicles)*".json")
        end

        # Get CSV
        dfResults = processResults(outputFiles)
        result_file = string(outPutFolder, "/results_", gamma,"_",relocateVehicles, ".csv")
        append_mode = false
        CSV.write(result_file, dfResults; append=append_mode)
    end

end

#===============================#
# Get averages 
#===============================#
function average_kpis_by_data_size(base_path::String,dataSizeList,relocateVehicles)
    all_data = DataFrame()

    for dataSize in dataSizeList
        full_path = joinpath(base_path, string(dataSize), "results_0.7_"*string(relocateVehicles)*".csv")
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

for relocateVehicles in [true,false]
    results_df = average_kpis_by_data_size("runfiles/output/Waiting/",nRequestList,relocateVehicles)
    CSV.write("runfiles/output/Waiting/average_results_by_size_0.7_"*string(relocateVehicles)*".csv", results_df)
end


#===============================#
# Plot results 
#===============================#
for n in nRequestList
    p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "No. taxis",leftmargin=5mm,topmargin=5mm,legend = :topright)

    nRows = 0
    maxnTaxi = 0
    minnTaxi = typemax(Int)
    for relocateVehicles in [true,false]
        outPutFolder = "runfiles/output/Waiting/"*string(n)
        resultFile = string(outPutFolder, "/results_", gamma,"_",relocateVehicles, ".csv")
        df = CSV.read(resultFile, DataFrame)
        nRows = nrow(df)
        maxnTaxi = max(maxnTaxi,maximum(df.nTaxi))
        minnTaxi = min(minnTaxi,minimum(df.nTaxi))

        # Plot 
        color = relocateVehicles ? :blue : :red
        label = relocateVehicles ? "With Relocation" : "Without Relocation"

        plot!(df.nTaxi; linestyle = :dash, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
    end

    ylimMin = 5 * floor((minnTaxi - 2) / 5)
    ylimMax = 5 * ceil((maxnTaxi + 2) / 5)
    xtickLabel = ["Scenario $(i)" for i in 1:nRows]
    xticks!((1:nRows,xtickLabel),rotation=90)
    if n == 500 
        yticks!((ylimMin:10:ylimMax,string.(Int.(ylimMin:10:ylimMax))))
    else 
        yticks!((ylimMin:5:ylimMax,string.(Int.(ylimMin:5:ylimMax))))
    end
    ylims!(ylimMin, ylimMax)

    savefig(p, "plots/Waiting/results_$(n).png")
end
