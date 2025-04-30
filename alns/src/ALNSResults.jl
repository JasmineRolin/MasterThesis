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

        # Route plot 
        routePlot = plotRoutes(solution,scenario,requestBank,"Route Plot - $(scenario.name)")

        writeALNSSpecificationsFile(specificationsFileName,scenario,parameters,configuration)
        writeKPIsToFile(KPIFileName,scenario,solution)

        # Display and save plots
        savefig(costPlot, joinpath(plotFolder, "ALNSCostPlot.png"))
        savefig(repairWeightPlot, joinpath(plotFolder, "ALNSRepairWeightPlot.png"))
        savefig(destroyWeightPlot, joinpath(plotFolder, "ALNSDestroyWeightPlot.png"))
        savefig(temperaturePlot, joinpath(plotFolder, "ALNSTemperaturePlot.png"))
        savefig(gantChart, joinpath(plotFolder, "ALNSGantChart.png"))
        savefig(gantChartSolution, joinpath(plotFolder, "ALNSGantChartSolution.png"))
        savefig(routePlot, joinpath(plotFolder, "ALNSRoutePlot.png"))


        if displayPlots
            display(costPlot)
            display(repairWeightPlot)
            display(destroyWeightPlot)
            display(temperaturePlot)
            display(gantChart) 
            display(gantChartSolution)
            display(routePlot)
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

    # Filter only accepted 
    onlyAccepted = isAccepted .& .!isNewBest .& .!isImproved

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

    scatter!(p1, iterations[onlyAccepted], total_cost[onlyAccepted],
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
    p = plot(title=string(scenarioName," - Repair Weights Over Iterations"), xlabel="Iteration", ylabel="RW",size=(2000,1000))

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
    p = plot(title=string(scenarioName," - Destroy Weights Over Iterations"), xlabel="Iteration", ylabel="DW",size=(2000,1000))

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



#==
 Plot routes 
==#
function plotRoutes(solution::Solution,scenario::Scenario,requestBank::Vector{Int},title::String)

    p = plot(size = (2000, 1500),bottom_margin=12mm, left_margin=12mm,
    top_margin=5mm, right_margin=5mm)

    # Retrieve assigned requests
    firstPickUp = true 
    firstDropoff = true 
    firstDepot = true 
    firstWaiting = true 
    offset = 0.025
    assignedRequests = Vector{Int}()

    # Plot routes 
    palette_func = palette(:rainbow, length(solution.vehicleSchedules))
    colors = [palette_func[i] for i in 1:length(solution.vehicleSchedules)]
    arrow_scale = 0.8 
    for (i, vehicleSchedule) in enumerate(solution.vehicleSchedules)
        routeLats = [v.activity.location.lat for v in vehicleSchedule.route]
        routeLongs = [v.activity.location.long for v in vehicleSchedule.route]

        # Cycle through colors if there are more vehicles than colors
        c = colors[i]

        plot!(routeLongs, routeLats, label = "Vehicle $i", color = c, linewidth = 2)
        # Plot arrows (quiver from each point to the next)
        for j in 1:(length(routeLats)-1)
            y = routeLats[j]
            x = routeLongs[j]
            dx = routeLongs[j+1] - x
            dy = routeLats[j+1] - y
            quiver!([x], [y], quiver=([arrow_scale * dx], [arrow_scale * dy]), color=c, arrow=:small, linewidth=1)
        end
    end

    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            if assignment.activity.activityType == PICKUP
                push!(assignedRequests, assignment.activity.requestId)

                
            end

            if assignment.activity.activityType == PICKUP
                if firstPickUp
                    firstPickUp = false 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "Pick Up", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.long, r.pickUpActivity.location.lat+offset, text("PU$(r.id)", :center, 8, color = :green))
                else
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.long], [r.pickUpActivity.location.lat], label = "", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.long, r.pickUpActivity.location.lat+offset, text("PU$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DROPOFF
                if firstDropoff
                    firstDropoff = false
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "Drop off", color = :darkgreen, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.long, r.dropOffActivity.location.lat+offset, text("DO$(r.id)", :center, 8, color = :green))
                else 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.long], [r.dropOffActivity.location.lat], label = "", color = :darkgreen, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.long, r.dropOffActivity.location.lat+offset, text("DO$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DEPOT
                if firstDepot
                    firstDepot = false
                    v = schedule.vehicle
                    scatter!([v.depotLocation.long], [v.depotLocation.lat], label = "Depot", color = :black, markersize = 10, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.long, v.depotLocation.lat+offset, text("D$(v.id)", :center, 8, color = :black))
                else
                    v = schedule.vehicle
                    scatter!([v.depotLocation.long], [v.depotLocation.lat], label = "", color = :black, markersize = 10, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.long, v.depotLocation.lat+offset, text("D$(v.id)", :center, 8, color = :black))
                end
            else
                if firstWaiting
                    firstWaiting = false
                    scatter!([assignment.activity.location.long], [assignment.activity.location.lat], label = "Waiting", color = :grey, markersize = 10, marker = :diamond,markerstrokewidth=0)
                    annotate!(assignment.activity.location.long, assignment.activity.location.lat+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                else 
                    scatter!([assignment.activity.location.long], [assignment.activity.location.lat], label = "", color = :grey, markersize = 10, marker = :diamond,markerstrokewidth=0)
                    annotate!(assignment.activity.location.long,assignment.activity.location.lat+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                end
            end
        end
    end

  
    # Request bank 
    for (idx,r) in enumerate(requestBank)
        if idx == 1
            scatter!([scenario.requests[r].pickUpActivity.location.long], [scenario.requests[r].pickUpActivity.location.lat], label = "PU request bank", color = :red, markersize = 10, marker = :circle,markerstrokewidth=1,markerstrokecolor=:red)
            annotate!(scenario.requests[r].pickUpActivity.location.long, scenario.requests[r].pickUpActivity.location.lat+offset, text("PU$(r)", :center, 8, color = :red))

            scatter!([scenario.requests[r].dropOffActivity.location.long], [scenario.requests[r].dropOffActivity.location.lat], label = "DO request bank", color = :red, markersize = 10, marker = :square,markerstrokewidth=1,markerstrokecolor=:red)
            annotate!(scenario.requests[r].dropOffActivity.location.long, scenario.requests[r].dropOffActivity.location.lat+offset, text("DO$(r)", :center, 8, color = :red))
        else
            scatter!([scenario.requests[r].pickUpActivity.location.long], [scenario.requests[r].pickUpActivity.location.lat], label = "", color = :red, markersize = 10, marker = :circle,markerstrokewidth=1,markerstrokecolor=:red)
            annotate!(scenario.requests[r].pickUpActivity.location.long, scenario.requests[r].pickUpActivity.location.lat+offset, text("PU$(r)", :center, 8, color = :red))

            scatter!([scenario.requests[r].dropOffActivity.location.long], [scenario.requests[r].dropOffActivity.location.lat], label = "", color = :red, markersize = 10, marker = :square,markerstrokewidth=1,markerstrokecolor=:red)
            annotate!(scenario.requests[r].dropOffActivity.location.long, scenario.requests[r].dropOffActivity.location.lat+offset, text("DO$(r)", :center, 8, color = :red))
        end

    end
  

  

    title!(title)
    xlabel!("Longitude")
    ylabel!("Latitude")
    return p 
end


end 