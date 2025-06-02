using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

nRequestList = [20,100, 300, 500]
nRuns = 3
relocateVehiclesList =  [("true","false"),("true","true"),("false","false"),("inhindsight","")]
gamma = 0.5
baseFolder = "runfiles/output/Waiting/Base/"

#===============================#
# Retrieve CSV files 
#===============================#
for n in nRequestList
    for run in 1:nRuns 
        outPutFolder = baseFolder*string(n)*"/Run"*string(run)

        for relocateVehiclesOption in relocateVehiclesList
            outputFiles = Vector{String}()
 
            for i in 1:10
                scenarioName = string("Gen_Data_",n,"_",gamma,"_",i,"_Run",run)
                push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*"_"*string(relocateVehiclesOption[1])*"_"*string(relocateVehiclesOption[2])*".json")
            end

            # Get CSV
            dfResults = processResults(outputFiles)
            result_file = string(outPutFolder, "/results_", gamma,"_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2], ".csv")
            append_mode = false
            CSV.write(result_file, dfResults; append=append_mode)
        end
    end

end

#===============================#
# Get averages 
#===============================#
function average_kpis_by_run(base_path::String,dataSizeList,nRuns,relocateVehiclesOption)
    for n in dataSizeList
        all_runs_data = DataFrame()
        
        for run in 1:nRuns
            filePath = base_path*"/"* string(n) * "/Run" * string(run) * "/results_"*string(gamma)*"_"*string(relocateVehiclesOption[1])*"_"*string(relocateVehiclesOption[2])*".csv"
            df = CSV.read(filePath, DataFrame)
            append!(all_runs_data, df)
        end

        all_runs_data[!, :BaseScenario] = replace.(all_runs_data.ScenarioName, r"_Run\d+" => "")

        grouped = groupby(all_runs_data, :BaseScenario)
        avg_data = combine(grouped, names(all_runs_data, Number) .=> mean)

        CSV.write(base_path*"/"*string(n)*"/results_avgOverRuns_"*string(relocateVehiclesOption[1])*"_"*string(relocateVehiclesOption[2])*".csv", avg_data)

    end
end

for relocateVehiclesOption in relocateVehiclesList
    average_kpis_by_run(baseFolder,nRequestList,nRuns,relocateVehiclesOption)
end


#===============================#
# Plot results 
#===============================#
for n in nRequestList
    println("n requests: ",n)
    p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "No. unserviced requests",leftmargin=5mm,topmargin=5mm,legend = :topright)

    nRows = 0
    maxnTaxi = 0
    minnTaxi = typemax(Int)
    for relocateVehiclesOption in relocateVehiclesList
        outPutFolder = baseFolder*string(n)
        resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2],".csv")
        df = CSV.read(resultFile, DataFrame)
        nRows = nrow(df)
        maxnTaxi = max(maxnTaxi,maximum(df.nTaxi_mean))
        minnTaxi = min(minnTaxi,minimum(df.nTaxi_mean))

        # Plot 
        if relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "true"
            color = :green
            label = "Relocation, method 1"
        elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
            color = :blue
            label = "Relocation, method 2"
        elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
            color = :red
            label = "Without Relocation"
        else
            color = :black 
            label = "In Hindsight"
        end

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