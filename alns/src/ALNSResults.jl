module ALNSResults 

using DataFrames, CSV, Plots, JSON, domain,..ALNSDomain
using Plots.PlotMeasures

export ALNSResult

#==
 Method to plot ALNS results  
==#
function ALNSResult(specificationsFileName::String,KPIFileName::String,ALNSOutputFile::String,scenario::Scenario,configuration::ALNSConfiguration,solution::Solution,requests::Vector{Request},requestBank::Vector{Int},parameters::ALNSParameters;saveResults=true::Bool,displayPlots=true::Bool,plotFolder=""::String)
   
    if saveResults
        # Read the CSV file into a DataFrame
        ALNSOutput = CSV.read(ALNSOutputFile, DataFrame)

        # Cost plot 
        costPlot = createCostPlot(ALNSOutput,scenario.name)

        # Repair weight plot
        repairWeightPlot = createRepairWeightPlot(ALNSOutput,configuration,scenario.name)

        # Destroy weight plot
        destroyWeightPlot = createDestroyWeightPlot(ALNSOutput,configuration,scenario.name)

        # Temperature plot
        temperaturePlot = createTemperaturePlot(ALNSOutput,scenario.name)

        # Gant chart 
        gantChart = createGantChartOfRequestsAndVehicles(scenario.vehicles,requests,requestBank,scenario.name)

        # Gant chart of solution 
        gantChartSolution = createGantChartOfSolution(solution,scenario.name)

        writeALNSSpecificationsFile(specificationsFileName,scenario,parameters,configuration)
        writeKPIsToFile(KPIFileName,scenario,solution)

        # Display and save plots
        savefig(costPlot, joinpath(plotFolder, "ALNSCostPlot.png"))
        savefig(repairWeightPlot, joinpath(plotFolder, "ALNSRepairWeightPlot.png"))
        savefig(destroyWeightPlot, joinpath(plotFolder, "ALNSDestroyWeightPlot.png"))
        savefig(temperaturePlot, joinpath(plotFolder, "ALNSTemperaturePlot.png"))
        savefig(gantChart, joinpath(plotFolder, "ALNSGantChart.png"))
        savefig(gantChartSolution, joinpath(plotFolder, "ALNSGantChartSolution.png"))


        if displayPlots
            display(costPlot)
            display(repairWeightPlot)
            display(destroyWeightPlot)
            display(temperaturePlot)
            display(gantChart) 
            display(gantChartSolution)
        end
    end
end

#==
    Write ALNS specifications to file 
==#
function writeALNSSpecificationsFile(fileName::String, scenario::Scenario,parameters::ALNSParameters,configuration::ALNSConfiguration)
    # Create a dictionary for the entire specifications
    specificationsDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "RepairMethods" => [m.name for m in configuration.repairMethods],
        "DestroyMethods" => [m.name for m in configuration.destroyMethods],
        "Parameters" => ALNSParametersToDict(parameters)
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(specificationsDict))
    close(file)
end

#==
 Write KPIs to file  
==#
function writeKPIsToFile(fileName::String, scenario::Scenario,solution::Solution)
    KPIDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "TotalCost" => solution.totalCost,
        "TotalDistance" => solution.totalDistance,
        "TotalRideTime" => solution.totalRideTime,
        "TotalIdleTime" => solution.totalIdleTime,
        "nTaxi" => solution.nTaxi
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(KPIDict))
    close(file)
end 


#==
 Method create plot of cost of run 
==#
function createCostPlot(df::DataFrame, scenarioName::String)
    # Extract relevant columns
    iterations = df.Iteration
    total_cost = df.TotalCost
    isAccepted = df.IsAccepted
    isImproved = df.IsImproved
    isNewBest = df.IsNewBest
    nRequestBank = df.nRequestBank

    # Filter isImproved points to exclude isNewBest
    onlyImproved = isImproved .& .!isNewBest

    # Define a 2-row layout
    l = @layout [a; b]

    # First plot: Total Cost
    p1 = plot(iterations, total_cost,
              label="Total Cost",
              linewidth=1,
              linestyle=:dash,
              color=:darkgray,
              xlabel="Iteration",
              ylabel="Total Cost",
              title=string(scenarioName, " - ALNS Total Cost Over Iterations"),
              legend=:topright)

    scatter!(p1, iterations[isAccepted], total_cost[isAccepted],
             markershape=:circle, color=:yellow, label="Accepted",markerstrokewidth=0)

    scatter!(p1, iterations[onlyImproved], total_cost[onlyImproved],
             markershape=:circle, color=:orange, label="Improved",markerstrokewidth=0)

    scatter!(p1, iterations[isNewBest], total_cost[isNewBest],
             markershape=:star5, color=:green, label="New Best", markersize=10,markerstrokewidth=0)

    # Second plot: Number of Requests in the Bank
    p2 = plot(iterations, nRequestBank,
              label="Request Bank Size",
              linewidth=2,
              color=:blue,
              xlabel="Iteration",
              ylabel="# Requests in Bank",
              title="Request Bank Over Iterations")

    # Combine plots into a subplot layout
    finalPlot = plot(p1, p2, layout=l, size=(2500, 2500),
                     bottom_margin=12mm, left_margin=12mm,
                     top_margin=5mm, right_margin=5mm)

    return finalPlot
end


#==
 Method to create plot of repair weights 
==#
function createRepairWeightPlot(df::DataFrame,configuration::ALNSConfiguration,scenarioName::String)
    # Extract iteration numbers
    iterations = df.Iteration

    repair_methods = configuration.repairMethods

    # Identify RW columns dynamically
    rw_columns = filter(col -> startswith(string(col), "RW"), names(df))

    # Create a plot
    p = plot(title=string(scenarioName," - RW Over Iterations"), xlabel="Iteration", ylabel="RW",size=(2000,1000))

    # Plot each RW column
    for (idx,col) in enumerate(rw_columns)
        plot!(p, iterations, df[!, col], label=repair_methods[idx].name)
    end

    return p
end

#==
 Method to create plot of destroy weights 
==#
function createDestroyWeightPlot(df::DataFrame,configuration::ALNSConfiguration,scenarioName::String)
    # Extract iteration numbers
    iterations = df.Iteration

    destroyMethods = configuration.destroyMethods

    # Identify RW columns dynamically
    rw_columns = filter(col -> startswith(string(col), "DW"), names(df))

    # Create a plot
    p = plot(title=string(scenarioName," - DW Over Iterations"), xlabel="Iteration", ylabel="DW",size=(2000,1000))

    # Plot each RW column
    for (idx,col) in enumerate(rw_columns)
        plot!(p, iterations, df[!, col], label=destroyMethods[idx].name)
    end

    return p
end

#==
 Method to create plot of temperature
==#
function createTemperaturePlot(df::DataFrame,scenarioName::String)
    # Extract iteration numbers
    iterations = df.Iteration


    # Create a plot
    p = plot(title=string(scenarioName," - Temperature"), xlabel="Iteration", ylabel="Temperature")
    plot!(p, iterations, df[!, "Temperature"])

    return p
end

# Create gant chart of vehicles and requests
function createGantChartOfRequestsAndVehicles(vehicles, requests, requestBank,scenarioName)
    p = plot(size=(2000,2100))
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = range(5*60,24*60,step=60)
    xLabels = string.(Int.(collect(xPositions)/60))

    linewidth = 11.5
    
    for (idx,vehicle) in enumerate(vehicles)
        # Vehicle availability window
        tw = vehicle.availableTimeWindow

        if idx == 1
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=linewidth, label="Vehicle TW", color=:black,seriestype=:step)
        else
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=linewidth,label="", color=:black,seriestype=:step)
        end
        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(vehicle.id)")

        scatter!([tw.startTime, tw.endTime], [yPos, yPos], marker=:square, markersize=6, color=:black, label="",markerstrokewidth=0)

        hline!([yPos - 2], linewidth=1, color=:gray, label="")

        yPos += 4
    end
    
    legendServiced = false 
    legendUnserviced = false
    for (idx,request) in enumerate(requests)
        pickupTW = request.pickUpActivity.timeWindow
        dropoffTW = request.dropOffActivity.timeWindow
        
        # Determine color based on whether request is serviced
        unServiced = request.id in requestBank
        colorPickup = unServiced ? :orange : :green
        colorDropoff = unServiced ? :red : :palegreen

        # Plot pickup and dropoff window as a bar
        if unServiced && !legendUnserviced
            legendUnserviced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=linewidth, label="Unserviced Pickup TW", color=colorPickup,seriestype=:step)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=linewidth, label="Unserviced Dropoff TW", color=colorDropoff,seriestype=:step)
        elseif !unServiced && !legendServiced
            legendServiced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=linewidth, label="Serviced Pickup TW", color=colorPickup,seriestype=:step)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=linewidth, label="Serviced Dropoff TW", color=colorDropoff,seriestype=:step)
        else
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=linewidth, label="", color=colorPickup,seriestype=:step)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=linewidth,label="", color=colorDropoff,seriestype=:step)
        end 

        scatter!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], marker=:square, markersize=6, color=colorPickup, label="",markerstrokewidth=0)
        scatter!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], marker=:square, markersize=6, color=colorDropoff, label="",markerstrokewidth=0)
        hline!([yPos - 2], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Request $(request.id)")
        yPos += 4
    end
    
    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels))

    xlabel!("Time (Hours)")
    title!(string(scenarioName," - Vehicle Availability and Request Time Windows"))

    return p
end

# Plot vehicle schedules 
# Define a function to plot activity assignments for each vehicle
function createGantChartOfSolution(solution::Solution,scenarioName::String)
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = range(6*60,24*60,step=60)
    xLabels = string.(Int.(collect(xPositions)/60))
    
    p = plot(size=(2000,2000))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = :lightgreen 
                markersize = 10
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)

            elseif assignment.activity.activityType == DROPOFF
                color = :tomato
                markersize = 10

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 7

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:circle,markerstrokewidth=0,markersize=markersize)

            else
                offset = 0
                color = :gray67
                markersize = 10

                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=19.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)

            end
        end
        hline!([yPos - 1], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end
    
    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels))
    xlabel!("Time (Hour)")
    title!(string(scenarioName," - Activity Assignments for Vehicles"))
    
    return p
end






end 