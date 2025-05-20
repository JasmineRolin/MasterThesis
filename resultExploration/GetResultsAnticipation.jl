using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures

methodListBase = ["Anticipation","BaseCase"]
nRequestList = [300,500]
runList = [1]
gamma = 0.5
anticipationDegrees = [0.4]
date = "2025-05-20_2"

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

            # if method == "Anticipation"
            #     for anticipationDegree in anticipationDegrees
            #         outPutFolder = "resultExploration/results/"*date*"/"*method*"_"*string(anticipationDegree)*"/"*string(n)*"/run"*string(run)
            #         outputFiles = Vector{String}()

            #         for i in 1:10
            #             scenarioName = string("Gen_Data_",n,"_",i,"_false")
            #             push!(outputFiles, outPutFolder*"/Simulation_KPI_"*string(scenarioName)*".json")
            #         end

            #         # Get CSV
            #         dfResults = processResults(outputFiles)
            #         result_file = string(outPutFolder, "/results", ".csv")
            #         append_mode = false
            #         CSV.write(result_file, dfResults; append=append_mode)
            #     end
            # else
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
            #end
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


# # #===============================#
# # # Plot results 
# # #===============================#
# for n in nRequestList
#     p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "No. taxis",leftmargin=5mm,topmargin=5mm,legend = :topright)

#     nRows = 0
#     maxnTaxi = 0
#     minnTaxi = typemax(Int)
#     for relocateVehicles in [true,false]
#         outPutFolder = "runfiles/output/Waiting/"*string(n)
#         resultFile = string(outPutFolder, "/results_", gamma,"_",relocateVehicles, ".csv")
#         df = CSV.read(resultFile, DataFrame)
#         nRows = nrow(df)
#         maxnTaxi = max(maxnTaxi,maximum(df.nTaxi))
#         minnTaxi = min(minnTaxi,minimum(df.nTaxi))

#         # Plot 
#         color = relocateVehicles ? :blue : :red
#         label = relocateVehicles ? "With Relocation" : "Without Relocation"

#         plot!(df.nTaxi; linestyle = :dash, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
#     end

#     ylimMin = 5 * floor((minnTaxi - 2) / 5)
#     ylimMax = 5 * ceil((maxnTaxi + 2) / 5)
#     xtickLabel = ["Scenario $(i)" for i in 1:nRows]
#     xticks!((1:nRows,xtickLabel),rotation=90)
#     if n == 500 
#         yticks!((ylimMin:10:ylimMax,string.(Int.(ylimMin:10:ylimMax))))
#     else 
#         yticks!((ylimMin:5:ylimMax,string.(Int.(ylimMin:5:ylimMax))))
#     end
#     ylims!(ylimMin, ylimMax)

#     savefig(p, "plots/Waiting/results_$(n).png")
# end
