using onlinesolution
using CSV, DataFrames, Statistics, Plots, Plots.PlotMeasures, PrettyTables, JSON

nRequestList = [20,100,300,500]
nRuns = 5
relocateVehiclesList = [("true","true"),("true","false"),("false","false"),("inhindsight","")]
gamma = 0.7
baseFolder = "runfiles/output/Waiting/Dynamic/"
plotName = "Dynamic"

plotResults = false
generateTables = false

if !isdir("plots/Waiting/$(plotName)/")
    mkdir("plots/Waiting/$(plotName)/")
end

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
if plotResults
    ytickfont = font(13)
    xtickfont = font(15)
    xguidefont = font(18)
    yguidefont = font(18)
    titlefont = font(18)
    legendfontsize = 15

    for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "", xlabel = "", ylabel = "No. unserviced requests",leftmargin=5mm,topmargin=5mm,legend=:topright,legend_background_color = RGBA(1,1,1,0.6),legend_position = (3, 0.5),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

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
                color = :forestgreen
                linestyle = :dot
                label = "Relocation strategy 1"
            elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
                color = :darkorange
                linestyle = :dot
                label = "Relocation strategy 2"
            elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
                color = :steelblue
                linestyle = :dash
                label = "Base method"
            else
                color = :gray20 
                linestyle = :dash
                label = "In Hindsight"
            end

            plot!(df.nTaxi_mean; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        if n >= 300 
            tickSpace = 5
        else
            tickSpace = 2 
        end 
        ylimMin = tickSpace * floor((minnTaxi - 2) / tickSpace)
        ylimMax = tickSpace * ceil((maxnTaxi + 2) / tickSpace)
        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))
        yticks!((ylimMin:tickSpace:ylimMax,string.(Int.(ylimMin:tickSpace:ylimMax))))
        ylims!(ylimMin, ylimMax)

        savefig(p, "plots/Waiting/$(plotName)/results_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_$(plotName)_$(n).pdf")
    end



    # Plot excess ride time pr. serviced request
    for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "Excess ride time pr. serviced request (min)",leftmargin=5mm,topmargin=5mm,legend = :topright,legend_background_color = RGBA(1,1,1,0.6),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

        nRows = 0
        maxnTaxi = 0
        minnTaxi = typemax(Int)
        for relocateVehiclesOption in relocateVehiclesList
            outPutFolder = baseFolder*string(n)
            resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2],".csv")
            df = CSV.read(resultFile, DataFrame)
            nRows = nrow(df)
           

              # Plot 
              if relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "true"
                color = :forestgreen
                linestyle = :dot
                label = "Relocation strategy 1"
            elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
                color = :darkorange
                linestyle = :dot
                label = "Relocation strategy 2"
            elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
                color = :steelblue
                linestyle = :dash
                label = "Base method"
            else
                color = :gray20 
                linestyle = :dash
                label = "In Hindsight"
            end


            plot!(df.ExcessRideTimePrServicedRequest_mean; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        tickSpace = 2 

        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))

        savefig(p, "plots/Waiting/$(plotName)/results_RideTime_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_RideTime_$(plotName)_$(n).pdf")
    end



     # Plot ride sharing 
    for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "% ride sharing",leftmargin=5mm,topmargin=5mm,legend = :topright,legend_background_color = RGBA(1,1,1,0.6),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

        nRows = 0
        maxnTaxi = 0
        minnTaxi = typemax(Int)
        for relocateVehiclesOption in relocateVehiclesList
            outPutFolder = baseFolder*string(n)
            resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2],".csv")
            df = CSV.read(resultFile, DataFrame)
            nRows = nrow(df)
           

            # Plot 
            if relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "true"
                color = :forestgreen
                linestyle = :dot
                label = "Relocation strategy 1"
            elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
                color = :darkorange
                linestyle = :dot
                label = "Relocation strategy 2"
            elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
                color = :steelblue
                linestyle = :dash
                label = "Base method"
            else
                color = :gray20 
                linestyle = :dash
                label = "In Hindsight"
            end


            plot!(df.AveragePercentRideSharing_mean; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        tickSpace = 2 

        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))

        savefig(p, "plots/Waiting/$(plotName)/results_RideSharing_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_RideSharing_$(plotName)_$(n).pdf")
    end


    # Plot empty drive time to/from depot 
    for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "Total duration of empty relocation time",leftmargin=5mm,topmargin=5mm,legend = :right,legend_background_color = RGBA(1,1,1,0.6),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

        nRows = 0
        maxnTaxi = 0
        minnTaxi = typemax(Int)
        for relocateVehiclesOption in relocateVehiclesList
            outPutFolder = baseFolder*string(n)
            resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2],".csv")
            df = CSV.read(resultFile, DataFrame)
            nRows = nrow(df)
           
        # Plot 
        if relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "true"
            color = :forestgreen
            linestyle = :dot
            label = "Relocation strategy 1"
        elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
            color = :darkorange
            linestyle = :dot
            label = "Relocation strategy 2"
        elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
            color = :steelblue
            linestyle = :dash
            label = "Base method"
        else
            color = :gray20 
            linestyle = :dash
            label = "In Hindsight"
        end


            plot!(df.TotalEmptyRelocationTime_mean; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        tickSpace = 2 

        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))

        savefig(p, "plots/Waiting/$(plotName)/results_EmptyRelocationTime_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_EmptyRelocationTime_$(plotName)_$(n).pdf")
    end


     # Plot distance to depot pr. customer 
     for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "Average drive time pr. request to nearest idle vehicle ",leftmargin=5mm,topmargin=5mm,legend = :topright,legend_background_color = RGBA(1,1,1,0.6),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

        nRows = 0
        maxnTaxi = 0
        minnTaxi = typemax(Int)
        for relocateVehiclesOption in relocateVehiclesList
            outPutFolder = baseFolder*string(n)
            resultFile = string(outPutFolder, "/results_avgOverRuns_",relocateVehiclesOption[1],"_",relocateVehiclesOption[2],".csv")
            df = CSV.read(resultFile, DataFrame)
            nRows = nrow(df)
           

            # Plot 
            if relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "true"
                color = :forestgreen
                linestyle = :dot
                label = "Relocation strategy 1"
            elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
                color = :darkorange
                linestyle = :dot
                label = "Relocation strategy 2"
            elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
                color = :steelblue
                linestyle = :dash
                label = "Base method"
            else
                color = :gray20 
                linestyle = :dash
                label = "In Hindsight"
            end


            prCustomer = df.TotalDriveTimeToNearestIdleVehicle_mean ./ df.TotalNumberOfRequestsOverlapIdleVehicle_mean

            plot!(prCustomer; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        tickSpace = 2 

        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))

        savefig(p, "plots/Waiting/$(plotName)/results_DriveTimeToIdle_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_DriveTimeToIdle_$(plotName)_$(n).pdf")
    end



    for n in nRequestList
        println("n requests: ",n)
        p = plot(size = (1000,1000),title = "Results for n = $n", xlabel = "", ylabel = "No. requests with pick-up time window overlapping with idle vehicle",leftmargin=5mm,topmargin=5mm,legend=:topright,legend_background_color = RGBA(1,1,1,0.6),legend_position = (3, 0.5),
        legendfontsize = legendfontsize,
        ytickfont = ytickfont,
        xtickfont = xtickfont,
        xguidefont = xguidefont,
        yguidefont = yguidefont,
        titlefont = titlefont,
        xrotation = 90)

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
                color = :forestgreen
                linestyle = :dot
                label = "Relocation strategy 1"
            elseif relocateVehiclesOption[1] == "true" && relocateVehiclesOption[2] == "false"
                color = :darkorange
                linestyle = :dot
                label = "Relocation strategy 2"
            elseif relocateVehiclesOption[1] == "false" && relocateVehiclesOption[2] == "false"
                color = :steelblue
                linestyle = :dash
                label = "Base method"
            else
                color = :gray20 
                linestyle = :dash
                label = "In Hindsight"
            end

            plot!(df.TotalNumberOfRequestsOverlapIdleVehicle_mean; linestyle = linestyle, marker = :circle, color = color, label = label,markerstrokewidth=0,linewidth=2,markersize=5)
        end

        xtickLabel = ["Inst. $(i)" for i in 1:nRows]
        xticks!((1:nRows,xtickLabel))

        savefig(p, "plots/Waiting/$(plotName)/results_TotalNumberOfRequestsOverlapIdleVehicle_$(plotName)_$(n).pdf")
        println("saved plot at: ", "plots/Waiting/$(plotName)/results_TotalNumberOfRequestsOverlapIdleVehicle_$(plotName)_$(n).pdf")
    end
end




#===============================#
# Result table 
#===============================#
if generateTables
    # No. unserviced requests 
    for n in nRequestList
        outPutFolder = baseFolder * string(n)

        # Read base method result
        resultFileBase = string(outPutFolder, "/results_avgOverRuns_false_false.csv")
        dfBase = CSV.read(resultFileBase, DataFrame)

    

        summary_table = DataFrame(Scenario = String[],
        BaseValue = Float64[], 
        RS1 = Float64[], DifferenceRS1 = Float64[],PercentDifferenceRS1 = Float64[],
        RS2 = Float64[], DifferenceRS2 = Float64[],PercentDifferenceRS2 = Float64[])

        
        # Relocation strategy 1 
        resultFile1 = string(outPutFolder, "/results_avgOverRuns_true_true.csv")
        if !isfile(resultFile1)
            @warn "Missing file: $resultFile"
            continue
        end
        df1 = CSV.read(resultFile1, DataFrame)


        # Relocation strategy 2
        resultFile2 = string(outPutFolder, "/results_avgOverRuns_true_false.csv")
        if !isfile(resultFile2)
            @warn "Missing file: $resultFile"
            continue
        end
        df2 = CSV.read(resultFile2, DataFrame)


        base_values = Float64[]
        new_values1 = Float64[]
        differences1 = Float64[]
        percentDifferences1 = Float64[]

        new_values2 = Float64[]
        differences2 = Float64[]
        percentDifferences2 = Float64[]

        # Collect values for each scenario 
        for (i,row) in enumerate(eachrow(df1))
            baseRow = filter(r -> r.BaseScenario == row.BaseScenario, dfBase)
            RS2Row = filter(r -> r.BaseScenario == row.BaseScenario, df2)


            if nrow(baseRow) == 1 && nrow(RS2Row) == 1
                push!(base_values, round(baseRow[1, :nTaxi_mean],digits=2))

                push!(new_values1, round(row.nTaxi_mean,digits=2))
                push!(differences1, round(new_values1[i]-base_values[i],digits=2))
                if isapprox(differences1[i],0)
                    push!(percentDifferences1,0.0)
                else
                    push!(percentDifferences1,round((differences1[i]/base_values[i]) * 100, digits=2))
                end

                push!(new_values2, round(RS2Row[1, :nTaxi_mean],digits=2))
                push!(differences2, round(new_values2[i]-base_values[i],digits=2))
                if isapprox(differences2[i],0)
                    push!(percentDifferences2,0.0)
                else
                    push!(percentDifferences2,round((differences2[i]/base_values[i]) * 100, digits=2))
                end
            else
                @warn "Scenario mismatch or duplicate in base data: $(row.BaseScenario)"
            end

            push!(summary_table, (
                Scenario = "Inst. $(i)",
                BaseValue = base_values[i],

                RS1 = new_values1[i],
                DifferenceRS1 = differences1[i], 
                PercentDifferenceRS1 = percentDifferences1[i],

                RS2 = new_values2[i],
                DifferenceRS2 = differences2[i], 
                PercentDifferenceRS2 = percentDifferences2[i]
            ))

        end


        # Compute mean 
        if !isempty(base_values)
            mean_base = round(mean(base_values),digits=2)

            mean_new1 = round(mean(new_values1),digits=2)
            diff1 = round(mean(differences1),digits=2)
            percentDiff1 = round(mean(filter(x -> isfinite(x), percentDifferences1)),digits=2)

            mean_new2 = round(mean(new_values2),digits=2)
            diff2 = round(mean(differences2),digits=2)
            percentDiff2 = round(mean(filter(x -> isfinite(x), percentDifferences2)),digits=2)

            push!(summary_table, (
                Scenario = "Average",
                BaseValue = mean_base,

                RS1 = mean_new1,
                DifferenceRS1 = diff1, 
                PercentDifferenceRS1 = percentDiff1,

                RS2 = mean_new2,
                DifferenceRS2 = diff2, 
                PercentDifferenceRS2 = percentDiff2
            ))
        end 


        # Save latex table 
        output_file = "plots/Waiting/$(plotName)/comparison_nTaxi_summary_$(n)_$(plotName)"

        if plotName == "Base"
            instanceType = "I"
        else
            instanceType = "II"
        end


        open(output_file*".tex", "w") do io
            # Manually write the LaTeX table environment
            println(io, "\\begin{table}[H]")
            println(io, "\\centering")
        
            pretty_table(io, summary_table;
                backend = Val(:latex),
                tf = tf_latex_default,  # or tf_latex_grid for more lines
                header = ["Inst.", "Base", "RS1", "\$\\Delta\$  RS1", "% \$\\Delta\$  RS1","RS2", "\$\\Delta\$  RS2", "% \$\\Delta\$  RS2"],
                alignment = :c
            )
        
            println(io, "\\caption{Comparison of number of unserviced requests for instance type $(instanceType) and instance size n = $(n)}")
            println(io, "\\label{tab:wait:resrelocation-nTaxi-comparison_$(instanceType)_$(n)}")
            println(io, "\\end{table}")
        end

        # Save table for this n
        CSV.write(output_file*".csv", summary_table)
        println("✅ Saved summary table for n=$n → $output_file")
    end

    # Total time spent wmpty relocation 
    for n in nRequestList
        outPutFolder = baseFolder * string(n)

        # Read base method result
        resultFileBase = string(outPutFolder, "/results_avgOverRuns_false_false.csv")
        dfBase = CSV.read(resultFileBase, DataFrame)

    

        summary_table = DataFrame(Scenario = String[],
        BaseValue = Float64[], 
        RS1 = Float64[], DifferenceRS1 = Float64[],PercentDifferenceRS1 = Float64[],
        RS2 = Float64[], DifferenceRS2 = Float64[],PercentDifferenceRS2 = Float64[])

        
        # Relocation strategy 1 
        resultFile1 = string(outPutFolder, "/results_avgOverRuns_true_true.csv")
        if !isfile(resultFile1)
            @warn "Missing file: $resultFile"
            continue
        end
        df1 = CSV.read(resultFile1, DataFrame)


        # Relocation strategy 2
        resultFile2 = string(outPutFolder, "/results_avgOverRuns_true_false.csv")
        if !isfile(resultFile2)
            @warn "Missing file: $resultFile"
            continue
        end
        df2 = CSV.read(resultFile2, DataFrame)


        base_values = Float64[]
        new_values1 = Float64[]
        differences1 = Float64[]
        percentDifferences1 = Float64[]

        new_values2 = Float64[]
        differences2 = Float64[]
        percentDifferences2 = Float64[]

        # Collect values for each scenario 
        for (i,row) in enumerate(eachrow(df1))
            baseRow = filter(r -> r.BaseScenario == row.BaseScenario, dfBase)
            RS2Row = filter(r -> r.BaseScenario == row.BaseScenario, df2)


            if nrow(baseRow) == 1 && nrow(RS2Row) == 1
                push!(base_values, round(baseRow[1, :TotalEmptyRelocationTime_mean],digits=2))

                push!(new_values1, round(row.TotalEmptyRelocationTime_mean,digits=2))
                push!(differences1, round(new_values1[i]-base_values[i],digits=2))
                if isapprox(differences1[i],0)
                    push!(percentDifferences1,0.0)
                else
                    push!(percentDifferences1,round((differences1[i]/base_values[i]) * 100, digits=2))
                end

                push!(new_values2, round(RS2Row[1, :TotalEmptyRelocationTime_mean],digits=2))
                push!(differences2, round(new_values2[i]-base_values[i],digits=2))
                if isapprox(differences2[i],0)
                    push!(percentDifferences2,0.0)
                else
                    push!(percentDifferences2,round((differences2[i]/base_values[i]) * 100, digits=2))
                end
            else
                @warn "Scenario mismatch or duplicate in base data: $(row.BaseScenario)"
            end

            push!(summary_table, (
                Scenario = "Inst. $(i)",
                BaseValue = base_values[i],

                RS1 = new_values1[i],
                DifferenceRS1 = differences1[i], 
                PercentDifferenceRS1 = percentDifferences1[i],

                RS2 = new_values2[i],
                DifferenceRS2 = differences2[i], 
                PercentDifferenceRS2 = percentDifferences2[i]
            ))

        end


        # Compute mean 
        if !isempty(base_values)
            mean_base = round(mean(base_values),digits=2)

            mean_new1 = round(mean(new_values1),digits=2)
            diff1 = round(mean(differences1),digits=2)
            percentDiff1 = round(mean(filter(x -> isfinite(x), percentDifferences1)),digits=2)

            mean_new2 = round(mean(new_values2),digits=2)
            diff2 = round(mean(differences2),digits=2)
            percentDiff2 = round(mean(filter(x -> isfinite(x), percentDifferences2)),digits=2)

            push!(summary_table, (
                Scenario = "Average",
                BaseValue = mean_base,

                RS1 = mean_new1,
                DifferenceRS1 = diff1, 
                PercentDifferenceRS1 = percentDiff1,

                RS2 = mean_new2,
                DifferenceRS2 = diff2, 
                PercentDifferenceRS2 = percentDiff2
            ))
        end 


        # Save latex table 
        output_file = "plots/Waiting/$(plotName)/comparison_TotalEmptyRelocationTime_mean_summary_$(n)_$(plotName)"

        if plotName == "Base"
            instanceType = "I"
        else
            instanceType = "II"
        end


        open(output_file*".tex", "w") do io
            # Manually write the LaTeX table environment
            println(io, "\\begin{table}[H]")
            println(io, "\\centering")
        
            pretty_table(io, summary_table;
                backend = Val(:latex),
                tf = tf_latex_default,  # or tf_latex_grid for more lines
                header = ["Inst.", "Base", "RS1", "\$\\Delta\$  RS1", "% \$\\Delta\$  RS1","RS2", "\$\\Delta\$  RS2", "% \$\\Delta\$  RS2"],
                alignment = :c
            )
        
            println(io, "\\caption{Comparison of total duration of empty relocation time for instance type $(instanceType) and instance size n = $(n)}")
            println(io, "\\label{tab:wait:resrelocation-empty-relocation-comparison_$(instanceType)_$(n)}")
            println(io, "\\end{table}")
        end

        # Save table for this n
        CSV.write(output_file*".csv", summary_table)
        println("✅ Saved summary table for n=$n → $output_file")
    end



     # Drive time to nearest idle vehicle 
     for n in nRequestList
        outPutFolder = baseFolder * string(n)

        # Read base method result
        resultFileBase = string(outPutFolder, "/results_avgOverRuns_false_false.csv")
        dfBase = CSV.read(resultFileBase, DataFrame)

    

        summary_table = DataFrame(Scenario = String[],
        BaseValue = Float64[], 
        RS1 = Float64[], DifferenceRS1 = Float64[],PercentDifferenceRS1 = Float64[],
        RS2 = Float64[], DifferenceRS2 = Float64[],PercentDifferenceRS2 = Float64[])

        
        # Relocation strategy 1 
        resultFile1 = string(outPutFolder, "/results_avgOverRuns_true_true.csv")
        if !isfile(resultFile1)
            @warn "Missing file: $resultFile"
            continue
        end
        df1 = CSV.read(resultFile1, DataFrame)


        # Relocation strategy 2
        resultFile2 = string(outPutFolder, "/results_avgOverRuns_true_false.csv")
        if !isfile(resultFile2)
            @warn "Missing file: $resultFile"
            continue
        end
        df2 = CSV.read(resultFile2, DataFrame)


        base_values = Float64[]
        new_values1 = Float64[]
        differences1 = Float64[]
        percentDifferences1 = Float64[]

        new_values2 = Float64[]
        differences2 = Float64[]
        percentDifferences2 = Float64[]

        # Collect values for each scenario 
        for (i,row) in enumerate(eachrow(df1))
            baseRow = filter(r -> r.BaseScenario == row.BaseScenario, dfBase)
            RS2Row = filter(r -> r.BaseScenario == row.BaseScenario, df2)


            if nrow(baseRow) == 1 && nrow(RS2Row) == 1
                valueBase = baseRow[1, :TotalDriveTimeToNearestIdleVehicle_mean] ./ baseRow[1, :TotalNumberOfRequestsOverlapIdleVehicle_mean]
                push!(base_values, round(valueBase,digits=2))

                values1 = row.TotalDriveTimeToNearestIdleVehicle_mean ./ row.TotalNumberOfRequestsOverlapIdleVehicle_mean
                push!(new_values1, round(values1,digits=2))
                push!(differences1, round(new_values1[i]-base_values[i],digits=2))
                if isapprox(differences1[i],0)
                    push!(percentDifferences1,0.0)
                else
                    push!(percentDifferences1,round((differences1[i]/base_values[i]) * 100, digits=2))
                end

                value2 = RS2Row[1, :TotalDriveTimeToNearestIdleVehicle_mean] ./ RS2Row[1, :TotalNumberOfRequestsOverlapIdleVehicle_mean]
                push!(new_values2, round(value2,digits=2))
                push!(differences2, round(new_values2[i]-base_values[i],digits=2))
                if isapprox(differences2[i],0)
                    push!(percentDifferences2,0.0)
                else
                    push!(percentDifferences2,round((differences2[i]/base_values[i]) * 100, digits=2))
                end
            else
                @warn "Scenario mismatch or duplicate in base data: $(row.BaseScenario)"
            end

            push!(summary_table, (
                Scenario = "Inst. $(i)",
                BaseValue = base_values[i],

                RS1 = new_values1[i],
                DifferenceRS1 = differences1[i], 
                PercentDifferenceRS1 = percentDifferences1[i],

                RS2 = new_values2[i],
                DifferenceRS2 = differences2[i], 
                PercentDifferenceRS2 = percentDifferences2[i]
            ))

        end


        # Compute mean 
        if !isempty(base_values)
            mean_base = round(mean(base_values),digits=2)

            mean_new1 = round(mean(new_values1),digits=2)
            diff1 = round(mean(differences1),digits=2)
            percentDiff1 = round(mean(filter(x -> isfinite(x), percentDifferences1)),digits=2)

            mean_new2 = round(mean(new_values2),digits=2)
            diff2 = round(mean(differences2),digits=2)
            percentDiff2 = round(mean(filter(x -> isfinite(x), percentDifferences2)),digits=2)

            push!(summary_table, (
                Scenario = "Average",
                BaseValue = mean_base,

                RS1 = mean_new1,
                DifferenceRS1 = diff1, 
                PercentDifferenceRS1 = percentDiff1,

                RS2 = mean_new2,
                DifferenceRS2 = diff2, 
                PercentDifferenceRS2 = percentDiff2
            ))
        end 


        # Save latex table 
        output_file = "plots/Waiting/$(plotName)/comparison_TotalDriveTimeToNearestIdleVehicle_mean_summary_$(n)_$(plotName)"

        if plotName == "Base"
            instanceType = "I"
        else
            instanceType = "II"
        end


        open(output_file*".tex", "w") do io
            # Manually write the LaTeX table environment
            println(io, "\\begin{table}[H]")
            println(io, "\\centering")
        
            pretty_table(io, summary_table;
                backend = Val(:latex),
                tf = tf_latex_default,  # or tf_latex_grid for more lines
                header = ["Inst", "Base", "RS1", "\$\\Delta\$  RS1", "% \$\\Delta\$  RS1","RS2", "\$\\Delta\$  RS2", "% \$\\Delta\$  RS2"],
                alignment = :c
            )
        
            println(io, "\\caption{Comparison of average drive time to nearest idle vehicle for instance type $(instanceType) and instance size n = $(n)}")
            println(io, "\\label{tab:wait:resrelocation-nearest-drive-time-comparison_$(instanceType)_$(n)}")
            println(io, "\\end{table}")
        end

        # Save table for this n
        CSV.write(output_file*".csv", summary_table)
        println("✅ Saved summary table for n=$n → $output_file")
    end



     # Excess ride time pr. serviced request
     for n in nRequestList
        outPutFolder = baseFolder * string(n)

        # Read base method result
        resultFileBase = string(outPutFolder, "/results_avgOverRuns_false_false.csv")
        dfBase = CSV.read(resultFileBase, DataFrame)

    

        summary_table = DataFrame(Scenario = String[],
        BaseValue = Float64[], 
        RS1 = Float64[], DifferenceRS1 = Float64[],PercentDifferenceRS1 = Float64[],
        RS2 = Float64[], DifferenceRS2 = Float64[],PercentDifferenceRS2 = Float64[])

        
        # Relocation strategy 1 
        resultFile1 = string(outPutFolder, "/results_avgOverRuns_true_true.csv")
        if !isfile(resultFile1)
            @warn "Missing file: $resultFile"
            continue
        end
        df1 = CSV.read(resultFile1, DataFrame)


        # Relocation strategy 2
        resultFile2 = string(outPutFolder, "/results_avgOverRuns_true_false.csv")
        if !isfile(resultFile2)
            @warn "Missing file: $resultFile"
            continue
        end
        df2 = CSV.read(resultFile2, DataFrame)


        base_values = Float64[]
        new_values1 = Float64[]
        differences1 = Float64[]
        percentDifferences1 = Float64[]

        new_values2 = Float64[]
        differences2 = Float64[]
        percentDifferences2 = Float64[]

        # Collect values for each scenario 
        for (i,row) in enumerate(eachrow(df1))
            baseRow = filter(r -> r.BaseScenario == row.BaseScenario, dfBase)
            RS2Row = filter(r -> r.BaseScenario == row.BaseScenario, df2)


            if nrow(baseRow) == 1 && nrow(RS2Row) == 1
                push!(base_values, round(baseRow[1, :ExcessRideTimePrServicedRequest_mean],digits=2))

                push!(new_values1, round(row.ExcessRideTimePrServicedRequest_mean,digits=2))
                push!(differences1, round(new_values1[i]-base_values[i],digits=2))
                if isapprox(differences1[i],0)
                    push!(percentDifferences1,0.0)
                else
                    push!(percentDifferences1,round((differences1[i]/base_values[i]) * 100, digits=2))
                end

                push!(new_values2, round(RS2Row[1, :ExcessRideTimePrServicedRequest_mean],digits=2))
                push!(differences2, round(new_values2[i]-base_values[i],digits=2))
                if isapprox(differences2[i],0)
                    push!(percentDifferences2,0.0)
                else
                    push!(percentDifferences2,round((differences2[i]/base_values[i]) * 100, digits=2))
                end
            else
                @warn "Scenario mismatch or duplicate in base data: $(row.BaseScenario)"
            end

            push!(summary_table, (
                Scenario = "Inst. $(i)",
                BaseValue = base_values[i],

                RS1 = new_values1[i],
                DifferenceRS1 = differences1[i], 
                PercentDifferenceRS1 = percentDifferences1[i],

                RS2 = new_values2[i],
                DifferenceRS2 = differences2[i], 
                PercentDifferenceRS2 = percentDifferences2[i]
            ))

        end


        # Compute mean 
        if !isempty(base_values)
            mean_base = round(mean(base_values),digits=2)

            mean_new1 = round(mean(new_values1),digits=2)
            diff1 = round(mean(differences1),digits=2)
            percentDiff1 = round(mean(filter(x -> isfinite(x), percentDifferences1)),digits=2)

            mean_new2 = round(mean(new_values2),digits=2)
            diff2 = round(mean(differences2),digits=2)
            percentDiff2 = round(mean(filter(x -> isfinite(x), percentDifferences2)),digits=2)

            push!(summary_table, (
                Scenario = "Average",
                BaseValue = mean_base,

                RS1 = mean_new1,
                DifferenceRS1 = diff1, 
                PercentDifferenceRS1 = percentDiff1,

                RS2 = mean_new2,
                DifferenceRS2 = diff2, 
                PercentDifferenceRS2 = percentDiff2
            ))
        end 


        # Save latex table 
        output_file = "plots/Waiting/$(plotName)/comparison_ExcessRideTimePrServicedRequest_mean_summary_$(n)_$(plotName)"

        if plotName == "Base"
            instanceType = "I"
        else
            instanceType = "II"
        end


        open(output_file*".tex", "w") do io
            # Manually write the LaTeX table environment
            println(io, "\\begin{table}[H]")
            println(io, "\\centering")
        
            pretty_table(io, summary_table;
                backend = Val(:latex),
                tf = tf_latex_default,  # or tf_latex_grid for more lines
                header = ["Inst.", "Base", "RS1", "\$\\Delta\$  RS1", "% \$\\Delta\$  RS1","RS2", "\$\\Delta\$  RS2", "% \$\\Delta\$  RS2"],
                alignment = :c
            )
        
            println(io, "\\caption{Comparison of excess ride time (min) pr. serviced customer for instance type $(instanceType) and instance size n = $(n)}")
            println(io, "\\label{tab:wait:resrelocation-excess-ride-time-comparison_$(instanceType)_$(n)}")
            println(io, "\\end{table}")
        end

        # Save table for this n
        CSV.write(output_file*".csv", summary_table)
        println("✅ Saved summary table for n=$n → $output_file")
    end




     # request overlapping
     summary_table = DataFrame(NRequests = Int[],BaseValue = Float64[], RS1 = Float64[],  RS2 = Float64[])

     for n in nRequestList
        outPutFolder = baseFolder * string(n)

        # Read base method result
        resultFileBase = string(outPutFolder, "/results_avgOverRuns_false_false.csv")
        dfBase = CSV.read(resultFileBase, DataFrame)
        
        # Relocation strategy 1 
        resultFile1 = string(outPutFolder, "/results_avgOverRuns_true_true.csv")
        if !isfile(resultFile1)
            @warn "Missing file: $resultFile"
            continue
        end
        df1 = CSV.read(resultFile1, DataFrame)


        # Relocation strategy 2
        resultFile2 = string(outPutFolder, "/results_avgOverRuns_true_false.csv")
        if !isfile(resultFile2)
            @warn "Missing file: $resultFile"
            continue
        end
        df2 = CSV.read(resultFile2, DataFrame)


        meanBase = mean(dfBase.TotalNumberOfRequestsOverlapIdleVehicle_mean)
        mean1 = mean(df1.TotalNumberOfRequestsOverlapIdleVehicle_mean)
        mean2 = mean(df2.TotalNumberOfRequestsOverlapIdleVehicle_mean)
       

        push!(summary_table,(
            NRequests = n,
            BaseValue = round(meanBase, digits=2),
            RS1 = round(mean1, digits=2),
            RS2 = round(mean2, digits=2)
        ))

        # Save latex table 

       
    end

    if plotName == "Base"
        instanceType = "I"
    else
        instanceType = "II"
    end

    output_file = "plots/Waiting/$(plotName)/comparison_NumberRequestOverlap_mean_summary_$(plotName)"

    open(output_file*".tex", "w") do io
        # Manually write the LaTeX table environment
        println(io, "\\begin{table}[H]")
        println(io, "\\centering")
    
        pretty_table(io, summary_table;
            backend = Val(:latex),
            tf = tf_latex_default,  # or tf_latex_grid for more lines
            header = ["n","Base", "RS1", "RS2"],
            alignment = :c
        )
    
        println(io, "\\caption{Number of requests that overlap with idle vehicle $(instanceType) ")
        println(io, "\\label{tab:wait:resrelocation-number-request-overlap-comparison_$(instanceType)")
        println(io, "\\end{table}")
    end

    # Save table for this n
    CSV.write(output_file*".csv", summary_table)
end




#================================================================================#
#================================================================================#
#================================================================================#
#================================================================================#
ytickfont = font(13)
xtickfont = font(15)
xguidefont = font(18)
yguidefont = font(18)
titlefont = font(18)
legendfontsize = 15
markersize = 10

# p = plot(size = (1000,1000),title = "", xlabel = "", ylabel = "Comparison",leftmargin=5mm,topmargin=5mm,legend=:topright,legend_background_color = RGBA(1,1,1,0.6),legend_position = (3, 0.5),
# legendfontsize = legendfontsize,
# ytickfont = ytickfont,
# xtickfont = xtickfont,
# xguidefont = xguidefont,
# yguidefont = yguidefont,
# titlefont = titlefont,
# xrotation = 90)


# resultFile = "plots/Waiting/Dynamic/comparison_nTaxi_summary_300_Dynamic.csv"
# dfUnservicedRequests = CSV.read(resultFile, DataFrame)

# resultFile = "plots/Waiting/Dynamic/comparison_TotalEmptyRelocationTime_mean_summary_300_Dynamic.csv"
# dfEmptyRelocationTime = CSV.read(resultFile, DataFrame)

# resultFile = "plots/Waiting/Dynamic/comparison_TotalDriveTimeToNearestIdleVehicle_mean_summary_300_Dynamic.csv"
# dfDriveTimeToNearest = CSV.read(resultFile, DataFrame)

# nRows = nrow(dfDriveTimeToNearest)

# i = 1

# scatter!([i],[abs(dfUnservicedRequests[i,:PercentDifferenceRS2])]; 
# marker = :square, 
# color = :forestgreen, 
# label = "Unserviced requests",
# markersize = markersize,
# markerstrokewidth = 0,
# linestyle = :solid,
# linewidth = 2)

# scatter!([i],[abs(dfEmptyRelocationTime[i,:PercentDifferenceRS2])]; 
# marker = :circle, 
# color = :steelblue, 
# label = "Empty relocation",
# markersize = markersize,
# markerstrokewidth = 0,
# linestyle = :solid,
# linewidth = 2)

# scatter!([i],[abs(dfDriveTimeToNearest[i,:PercentDifferenceRS2])]; 
# marker = :diamond, 
# color = :darkorange, 
# label = "Drive time to nearest",
# markersize = markersize,
# markerstrokewidth = 0,
# linestyle = :solid,
# linewidth = 2)

# for i in 2:(nRows-1)

#     scatter!([i],[abs(dfUnservicedRequests[i,:PercentDifferenceRS2])]; 
#         marker = :square, 
#         color = :forestgreen, 
#         label = "",
#         markersize = markersize,
#         markerstrokewidth = 0,
#         linestyle = :solid,
#         linewidth = 2)

#     scatter!([i],[abs(dfEmptyRelocationTime[i,:PercentDifferenceRS2])]; 
#         marker = :circle, 
#         color = :steelblue, 
#         label = "",
#         markersize = markersize,
#         markerstrokewidth = 0,
#         linestyle = :solid,
#         linewidth = 2)

#     scatter!([i],[abs(dfDriveTimeToNearest[i,:PercentDifferenceRS2])]; 
#         marker = :diamond, 
#         color = :darkorange, 
#         label = "",
#         markersize = markersize,
#         markerstrokewidth = 0,
#         linestyle = :solid,
#         linewidth = 2)
# end

# for x in 1.5:(nRows - 0.5)
#     vline!([x], linestyle = :dot, color = :black, alpha = 0.9,label="")
# end

# xtickLabel = ["Inst. $(i)" for i in 1:nRows]
# xticks!((1:nRows,xtickLabel))

# savefig(p, "plots/Waiting/$(plotName)/results_COMPARISON_300_$(plotName).pdf")
# println("saved plot at: ", "plots/Waiting/$(plotName)/results_COMPARISON_300_$(plotName).pdf")
using Plots
using CSV
using DataFrames

# Fonts & styles
tickfont = font(13)
xtickfont = font(15)
xguidefont = font(18)
yguidefont = font(18)
titlefont = font(18)
legendfontsize = 15
markersize = 10

# Read data
dfUnservicedRequests = CSV.read("plots/Waiting/Dynamic/comparison_nTaxi_summary_300_Dynamic.csv", DataFrame)
dfEmptyRelocationTime = CSV.read("plots/Waiting/Dynamic/comparison_TotalEmptyRelocationTime_mean_summary_300_Dynamic.csv", DataFrame)
dfDriveTimeToNearest = CSV.read("plots/Waiting/Dynamic/comparison_TotalDriveTimeToNearestIdleVehicle_mean_summary_300_Dynamic.csv", DataFrame)

nRows = nrow(dfUnservicedRequests)-1
x_vals = collect(1:nRows)

# Absolute values for all 3 metrics
u_vals = abs.(dfUnservicedRequests[1:(end-1), :PercentDifferenceRS2])
e_vals = abs.(dfEmptyRelocationTime[1:(end-1), :PercentDifferenceRS2])
d_vals = abs.(dfDriveTimeToNearest[1:(end-1), :PercentDifferenceRS2])

# Initialize empty plot
p = plot(size=(1000,1000), title="", xlabel="", ylabel="Percent absolute decrease",
    legend=:topright, legendfontsize=legendfontsize,
    leftmargin=5mm, topmargin=5mm,
    legend_background_color=RGBA(1,1,1,0.6),
    legend_position=(3, 0.5),
    ytickfont=tickfont, xtickfont=xtickfont,
    xguidefont=xguidefont, yguidefont=yguidefont,
    titlefont=titlefont, xrotation=90)

# Bar width and offset setup
bar_width = 0.25

# Slightly offset x-positions for each category
x_u = x_vals .- bar_width
x_e = x_vals
x_d = x_vals .+ bar_width

# Plot bars manually side-by-side
bar!(x_u, u_vals; bar_width=bar_width, label="Unserviced requests", color=:forestgreen)
bar!(x_e, e_vals; bar_width=bar_width, label="Empty relocation", color=:steelblue)
bar!(x_d, d_vals; bar_width=bar_width, label="Drive time to nearest", color=:darkorange)

# Add vertical dashed lines between groups
for x in 1.5:(nRows - 0.5)
    vline!(p, [x]; linestyle=:dot, color=:black, alpha=0.5, label="")
end

# Custom xtick labels centered at original x values
xtick_labels = ["Inst. $(i)" for i in 1:nRows]
xticks!(x_vals, xtick_labels)

# Save
plotName = "Dynamic"
savefig(p, "plots/Waiting/$(plotName)/results_COMPARISON_300_$(plotName).pdf")
println("saved plot at: plots/Waiting/$(plotName)/results_COMPARISON_300_$(plotName).pdf")



#================================================================================#
#================================================================================#
#================================================================================#
#================================================================================#
instances = [1]
