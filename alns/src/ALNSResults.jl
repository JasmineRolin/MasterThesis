module ALNSResults 

using DataFrames, CSV, Plots, JSON, domain

export ALNSResult

#==
 Method to plot ALNS results  
==#
function ALNSResult(specificationsFile::String,ALNSKPISFile::String,ALNSOutputFile::String,scenario::Scenario,solution::Solution,requests::Vector{Request},requestBank::Vector{Int};savePlots=true::Bool,displayPlots=true::Bool,plotFolder=""::String)
    # TODO: should we also input a solution and somehow save a solution? 

    # Read the CSV file into a DataFrame
    ALNSOutput = CSV.read(ALNSOutputFile, DataFrame)

    # Read specifications 
    specifications = JSON.parsefile(specificationsFile)
    specificationsTable = createSpecificationTable(specifications)

    # Read KPIs
    KPIS = JSON.parsefile(ALNSKPISFile)
    KPIsTable = createKPITable(KPIS)

    # Cost plot 
    costPlot = createCostPlot(ALNSOutput,scenario.name)

    # Repair weight plot
    repairWeightPlot = createRepairWeightPlot(ALNSOutput,specifications,scenario.name)

    # Destroy weight plot
    destroyWeightPlot = createDestroyWeightPlot(ALNSOutput,specifications,scenario.name)

    # Temperature plot
    temperaturePlot = createTemperaturePlot(ALNSOutput,scenario.name)

    # Gant chart 
    gantChart = createGantChartOfRequestsAndVehicles(scenario.vehicles,requests,requestBank,scenario.name)

    # Gant chart of solution 
    gantChartSolution = createGantChartOfSolution(solution,scenario.name)

    # Display and save plots
    if displayPlots
        display(costPlot)
        display(repairWeightPlot)
        display(destroyWeightPlot)
        display(temperaturePlot)
        display(gantChart) 
        display(gantChartSolution)
    end
    if savePlots
        savefig(costPlot, joinpath(plotFolder, "ALNSCostPlot.png"))
        savefig(repairWeightPlot, joinpath(plotFolder, "ALNSRepairWeightPlot.png"))
        savefig(destroyWeightPlot, joinpath(plotFolder, "ALNSDestroyWeightPlot.png"))
        savefig(temperaturePlot, joinpath(plotFolder, "ALNSTemperaturePlot.png"))
        savefig(gantChart, joinpath(plotFolder, "ALNSGantChart.png"))
        savefig(gantChartSolution, joinpath(plotFolder, "ALNSGantChartSolution.png"))
    end

    return specificationsTable, KPIsTable
end

#==
 Method to create a table of the specifications
==#
function createSpecificationTable(specifications::Dict)

    # Extract relevant sections from the parsed data
    destroy_methods = specifications["DestroyMethods"]
    repair_methods = specifications["RepairMethods"]
    scenario_name = specifications["Scenario"]["name"]
    
    parameters = specifications["Parameters"]

    # Combine data into a table format
    tableData = [
        ("DestroyMethods", join(destroy_methods, ", ")),
        ("RepairMethods", join(repair_methods, ", ")),
        ("Scenario", scenario_name)
    ]
    
    # Add the parameters to the table
    for (param, value) in parameters
        push!(tableData, (param, string(value)))
    end
    
    # Convert list of tuples into a DataFrame
    df = DataFrame(tableData, [:Parameter, :Value])

    # Return the DataFrame
    return df
end

#==
 Method to create KPI table 
==#
function createKPITable(KPIS::Dict)

   # Extract KPIs and convert to a list of tuples
   tableData = [
        ("nTaxi", KPIS["nTaxi"]),
        ("TotalCost", KPIS["TotalCost"]),
        ("TotalDistance", KPIS["TotalDistance"]),
        ("TotalIdleTime", KPIS["TotalIdleTime"]),
        ("TotalRideTime", KPIS["TotalRideTime"])
    ]

    # Convert the list of tuples into a DataFrame
    df = DataFrame(tableData, [:KPI, :Value])
        
    # Return the table for printing or further usage
    return df
end


#==
 Method create plot of cost of run 
==#
function createCostPlot(df::DataFrame,scenarioName::String)
    # Extract relevant columns
    iterations = df.Iteration
    total_cost = df.TotalCost
    isAccepted = df.IsAccepted
    isImproved = df.IsImproved
    isNewBest = df.IsNewBest

    # Filter isImproved points to exclude isNewBest
    onlyImproved = isImproved .& .!isNewBest

    # Create the line plot for total cost
    p = plot(iterations, total_cost, label="Total Cost", linewidth=2, color=:darkgray, xlabel="Iteration", ylabel="Total Cost", title=string(scenarioName," - ALNS Total Cost Over Iterations"),size=(1500,900))

    # Add yellow dots for accepted solutions
    scatter!(iterations[isAccepted], total_cost[isAccepted], markershape=:circle, color=:yellow, label="Accepted")

    # Add green dots for improved solutions
    scatter!(iterations[onlyImproved], total_cost[onlyImproved], markershape=:circle, color=:orange, label="Improved")

    # Add green stars for new best solutions
    scatter!(iterations[isNewBest], total_cost[isNewBest], markershape=:star5, color=:green, label="New Best",markersize=10)

    return p
end

#==
 Method to create plot of repair weights 
==#
function createRepairWeightPlot(df::DataFrame,specifications::Dict,scenarioName::String)
    # Extract iteration numbers
    iterations = df.Iteration

    repair_methods = specifications["RepairMethods"]

    # Identify RW columns dynamically
    rw_columns = filter(col -> startswith(string(col), "RW"), names(df))

    # Create a plot
    p = plot(title=string(scenarioName," - RW Over Iterations"), xlabel="Iteration", ylabel="RW")

    # Plot each RW column
    for (idx,col) in enumerate(rw_columns)
        plot!(p, iterations, df[!, col], label=repair_methods[idx])
    end

    return p
end

#==
 Method to create plot of destroy weights 
==#
function createDestroyWeightPlot(df::DataFrame,specifications::Dict,scenarioName::String)
    # Extract iteration numbers
    iterations = df.Iteration

    destroyMethods = specifications["DestroyMethods"]

    # Identify RW columns dynamically
    rw_columns = filter(col -> startswith(string(col), "DW"), names(df))

    # Create a plot
    p = plot(title=string(scenarioName," - DW Over Iterations"), xlabel="Iteration", ylabel="DW")

    # Plot each RW column
    for (idx,col) in enumerate(rw_columns)
        plot!(p, iterations, df[!, col], label=destroyMethods[idx])
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
    p = plot(size=(1500,900))
    yPositions = []
    yLabels = []
    yPos = 1
    
    for (idx,vehicle) in enumerate(vehicles)
        # Vehicle availability window
        tw = vehicle.availableTimeWindow

        if idx == 1
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5, label="Vehicle TW", color=:black)
        else
            plot!([tw.startTime, tw.endTime], [yPos, yPos], linewidth=5,label="", color=:black)
        end
        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(vehicle.id)")
        yPos += 1
    end
    
    legendServiced = false 
    legendUnserviced = false
    for (idx,request) in enumerate(requests)
        pickupTW = request.pickUpActivity.timeWindow
        dropoffTW = request.dropOffActivity.timeWindow
        
        # Determine color based on whether request is serviced
        unServiced = request.id in requestBank
        colorPickup = unServiced ? :red : :blue
        colorDropoff = unServiced ? :orange : :purple

        # Plot pickup and dropoff window as a bar
        if unServiced && !legendUnserviced
            legendUnserviced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Unserviced Pickup TW", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Unserviced Dropoff TW", color=colorDropoff)
        elseif !unServiced && !legendServiced
            legendServiced = true
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="Serviced Pickup TW", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5, label="Serviced Dropoff TW", color=colorDropoff)
        else
            plot!([pickupTW.startTime, pickupTW.endTime], [yPos, yPos], linewidth=5, label="", color=colorPickup)
            plot!([dropoffTW.startTime, dropoffTW.endTime], [yPos, yPos], linewidth=5,label="", color=colorDropoff)
        end 

      
        
        push!(yPositions, yPos)
        push!(yLabels, "Request $(request.id)")
        yPos += 1
    end
    
    plot!(p, yticks=(yPositions, yLabels))
    xlabel!("Time (Minutes after Midnight)")
    title!(string(scenarioName," - Vehicle Availability and Request Time Windows"))

    return p
end

# Plot vehicle schedules 
# Define a function to plot activity assignments for each vehicle
function createGantChartOfSolution(solution::Solution,scenarioName::String)
    yPositions = []
    yLabels = []
    yPos = 1
    
    p = plot(size=(1500,1000))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = :green 
            elseif assignment.activity.activityType == DROPOFF
                color = :purple
            elseif assignment.activity.activityType == DEPOT
                color = :red
            else
                offset = 2
                color = :gray
            end
            plot!(p, [assignment.startOfServiceTime+offset, assignment.endOfServiceTime-offset], [yPos, yPos], linewidth=10, label="", color=color)
        end
        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 1
    end
    
    plot!(p, yticks=(yPositions, yLabels))
    xlabel!("Time (Minutes after Midnight)")
    title!(string(scenarioName," - Activity Assignments for Vehicles"))
    
    return p
end






end 