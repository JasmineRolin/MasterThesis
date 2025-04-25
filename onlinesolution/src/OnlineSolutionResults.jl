module OnlineSolutionResults

using Plots, JSON, DataFrames
using domain, utils 

export createGantChartOfSolutionOnline,writeOnlineKPIsToFile,processResults, plotRoutes,createGantChartOfSolutionAndEventOnline


# Plot vehicle schedules 
# Define a function to plot activity assignments for each vehicle
function createGantChartOfSolutionOnline(solution::Solution,title::String;eventId::Int=-10,eventTime::Int=-10)
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []
    
    p = plot(size=(1500,1500))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId == eventId ? :lightblue1 : :lightgreen 
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId == eventId ? :blue : :tomato
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.id), :white, 8))
            else
                offset = 0
                color = :gray67
                markersize = 15

                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=29.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("W"*string(assignment.activity.location.name), :black, 8))

            end

            push!(xPositions, assignment.startOfServiceTime)
            push!(xLabels, string(round(assignment.startOfServiceTime/60.0,digits = 1)))

        end
        hline!([yPos - 1], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end
    
    if eventTime != -10 
        vline!([eventTime],lineWidth=1, color=:red, label="")
    end

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    title!(string(title," - Activity Assignments for Vehicles"))
    
    return p
end

#==
 Plot routes 
==#
function plotRoutes(solution::Solution,scenario::Scenario,requestBank::Vector{Int},title::String)

    p = plot(size = (2000, 1500))

    # Retrieve assigned requests
    firstPickUp = true 
    firstDropoff = true 
    firstDepot = true 
    firstWaiting = true 
    offset = 0.025
    assignedRequests = Vector{Int}()
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            if assignment.activity.activityType == PICKUP
                push!(assignedRequests, assignment.activity.requestId)

                
            end

            if assignment.activity.activityType == PICKUP
                if firstPickUp
                    firstPickUp = false 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.lat], [r.pickUpActivity.location.long], label = "Pick Up", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.lat, r.pickUpActivity.location.long+offset, text("PU$(r.id)", :center, 8, color = :green))
                else
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.pickUpActivity.location.lat], [r.pickUpActivity.location.long], label = "", color = :lightgreen, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(r.pickUpActivity.location.lat, r.pickUpActivity.location.long+offset, text("PU$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DROPOFF
                if firstDropoff
                    firstDropoff = false
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.lat], [r.dropOffActivity.location.long], label = "Pick Up", color = :tomato, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.lat, r.dropOffActivity.location.long+offset, text("DO$(r.id)", :center, 8, color = :green))
                else 
                    r = scenario.requests[assignment.activity.requestId]
                    scatter!([r.dropOffActivity.location.lat], [r.dropOffActivity.location.long], label = "", color = :tomato, markersize = 10, marker = :square,markerstrokewidth=0)
                    annotate!(r.dropOffActivity.location.lat, r.dropOffActivity.location.long+offset, text("DO$(r.id)", :center, 8, color = :green))
                end
            elseif assignment.activity.activityType == DEPOT
                if firstDepot
                    firstDepot = false
                    v = schedule.vehicle
                    scatter!([v.depotLocation.lat], [v.depotLocation.long], label = "Depot", color = :black, markersize = 10, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.lat, v.depotLocation.long+offset, text("D$(v.id)", :center, 8, color = :black))
                else
                    v = schedule.vehicle
                    scatter!([v.depotLocation.lat], [v.depotLocation.long], label = "", color = :black, markersize = 10, marker = :star,markerstrokewidth=0)
                    annotate!(v.depotLocation.lat, v.depotLocation.long+offset, text("D$(v.id)", :center, 8, color = :black))
                end
            else
                if firstWaiting
                    firstWaiting = false
                    scatter!([assignment.activity.location.lat], [assignment.activity.location.long], label = "Waiting", color = :grey, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(assignment.activity.location.lat, assignment.activity.location.long+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                else 
                    scatter!([assignment.activity.location.lat], [assignment.activity.location.long], label = "", color = :grey, markersize = 10, marker = :circle,markerstrokewidth=0)
                    annotate!(assignment.activity.location.lat,assignment.activity.location.long+offset, text("W$(assignment.activity.id)", :center, 8, color = :grey))
                end
            end
        end
    end

  
    # Request bank 
    for r in requestBank
        scatter!([scenario.requests[r].pickUpActivity.location.lat], [scenario.requests[r].pickUpActivity.location.long], label = "", color = :grey, markersize = 10, marker = :circle,markerstrokewidth=1,markerstrokecolor=:red)
        annotate!(scenario.requests[r].pickUpActivity.location.lat, scenario.requests[r].pickUpActivity.location.long+offset, text("PU$(r)", :center, 8, color = :grey))

        scatter!([scenario.requests[r].dropOffActivity.location.lat], [scenario.requests[r].dropOffActivity.location.long], label = "", color = :grey, markersize = 10, marker = :square,markerstrokewidth=1,markerstrokecolor=:red)
        annotate!(scenario.requests[r].dropOffActivity.location.lat, scenario.requests[r].dropOffActivity.location.long+offset, text("DO$(r)", :center, 8, color = :grey))

    end
  

    # Plot routes 
    palette_func = palette(:rainbow, length(solution.vehicleSchedules))
    colors = [palette_func[i] for i in 1:length(solution.vehicleSchedules)]
    arrow_scale = 0.8 
    for (i, vehicleSchedule) in enumerate(solution.vehicleSchedules)
        routeLats = [v.activity.location.lat for v in vehicleSchedule.route]
        routeLongs = [v.activity.location.long for v in vehicleSchedule.route]

        # Cycle through colors if there are more vehicles than colors
        c = colors[i]

        plot!(routeLats, routeLongs, label = "Vehicle $i", color = c, linewidth = 2)
        # Plot arrows (quiver from each point to the next)
        for j in 1:(length(routeLats)-1)
            x = routeLats[j]
            y = routeLongs[j]
            dx = routeLats[j+1] - x
            dy = routeLongs[j+1] - y
            quiver!([x], [y], quiver=([arrow_scale * dx], [arrow_scale * dy]), color=c, arrow=:small, linewidth=1)
        end
    end

    title!(title)
    return p 
end

function createGantChartOfSolutionAndEventOnline(solution::Solution,title::String;eventId::Int=-10,eventTime::Int=-10,event::Request= Request())
    yPositions = []
    yLabels = []
    yPos = 1

    xPositions = []
    xLabels = []
    
    p = plot(size=(1500,1500))
    
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            offset = 0 # TO offset waiting activities visually 
            if assignment.activity.activityType == PICKUP
                color = assignment.activity.requestId == eventId ? :lightblue1 : :lightgreen 
                markersize = 15
                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("PU"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DROPOFF
                color = assignment.activity.requestId == eventId ? :blue : :tomato
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("DO"*string(assignment.activity.requestId), :black, 8))

            elseif assignment.activity.activityType == DEPOT
                color = :black
                markersize = 15

                scatter!(p, [assignment.startOfServiceTime], [yPos], linewidth=11.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("D"*string(schedule.vehicle.id), :white, 8))
                scatter!(p, [assignment.activity.timeWindow.startTime], [yPos], linewidth=11.5, label="", color=:darkgray, marker=:circle,markerstrokewidth=0,markersize=7)
                scatter!(p, [assignment.activity.timeWindow.endTime], [yPos], linewidth=11.5, label="", color=:darkgray, marker=:circle,markerstrokewidth=0,markersize=7)
            else
                offset = 0
                color = :gray67
                markersize = 15

                plot!(p, [assignment.startOfServiceTime, assignment.endOfServiceTime], [yPos, yPos], linewidth=29.5, label="", color=color, marker=:square,markerstrokewidth=0,markersize=markersize)
                annotate!(p, assignment.startOfServiceTime, yPos, text("W"*string(assignment.activity.location.name), :black, 8))

            end

            push!(xPositions, assignment.startOfServiceTime)
            push!(xLabels, string(round(assignment.startOfServiceTime/60.0,digits = 1)))

        end
        hline!([yPos - 1], linewidth=1, color=:gray, label="")

        push!(yPositions, yPos)
        push!(yLabels, "Vehicle $(schedule.vehicle.id)")
        yPos += 2
    end
    
    if eventTime != -10 
        vline!([eventTime],lineWidth=1, color=:red, label="")
    end

    # Plot the event
    offset = 0
    markersize = 10
    plot!(p, [event.pickUpActivity.timeWindow.startTime, event.pickUpActivity.timeWindow.endTime], [yPos, yPos], linewidth=19.5, label="Pick up", color = :green, marker=:square,markerstrokewidth=0,markersize=markersize)
    plot!(p, [event.dropOffActivity.timeWindow.startTime, event.dropOffActivity.timeWindow.endTime], [yPos, yPos], linewidth=19.5, label="Drop off", color = :red, marker=:square,markerstrokewidth=0,markersize=markersize)
    scatter!(p, [event.callTime], [yPos], linewidth=11.5, label="Call time", color=:blue, marker=:circle,markerstrokewidth=0,markersize=markersize)
    push!(yPositions, yPos)
    push!(yLabels, "Event $(event.id)")

    plot!(p, yticks=(yPositions, yLabels))
    plot!(p, xticks=(xPositions, xLabels), xrotation=90)
    xlabel!("Time (Hour)")
    title!(string(title," - Activity Assignments for Vehicles"))
    
    return p
end


#==
 Write KPIs to file  
==#
function writeOnlineKPIsToFile(fileName::String, scenario::Scenario,solution::Solution,requestBank::Vector{Int},requestBankOffline::Vector{Int},totalElapsedTime::Float64,averageResponseTime::Float64,eventsInsertedByALNS::Int)
    # Find drive times for customers
    totalDirectRideTime = sum(r.directDriveTime for r in scenario.requests if !(r.id in requestBank))
    totalActualRideTime = 0
    pickUpTimes = Dict{Int,Int}()
    for schedule in solution.vehicleSchedules
        for assignment in schedule.route
            activity = assignment.activity
            if activity.activityType == PICKUP
                pickUpTimes[activity.requestId] = assignment.endOfServiceTime
            elseif activity.activityType == DROPOFF
                pickupTime = pickUpTimes[activity.requestId]
                dropoffTime = assignment.startOfServiceTime
                totalActualRideTime += dropoffTime - pickupTime
            end
        end
    end

    # Find idle time with customers 
    totalIdleTimeWithCustomer = 0 
    for schedule in solution.vehicleSchedules
        for (idx,assignment) in enumerate(schedule.route)
            if assignment.activity.activityType == WAITING && schedule.numberOfWalking[idx] > 0
                totalIdleTimeWithCustomer += assignment.endOfServiceTime - assignment.startOfServiceTime
            end
        end
    end

    # Find percent of ride sharing 
    averagePercentRideSharing = 0.0 
    for schedule in solution.vehicleSchedules
        if length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            continue
        end
        averagePercentRideSharing += sum(schedule.numberOfWalking .> 1)/sum(schedule.numberOfWalking .> 0)
    end
    averagePercentRideSharing = (averagePercentRideSharing/length(solution.vehicleSchedules))*100.0

    # Create a dictionary for the entire KPIs
    KPIDict = Dict(
        "Scenario" => Dict("name" => scenario.name),
        "TotalCost" => solution.totalCost,
        "TotalDistance" => solution.totalDistance,
        "TotalRideTime" => solution.totalRideTime,
        "TotalIdleTime" => solution.totalIdleTime,
        "TotalIdleTimeWithCustomer" => totalIdleTimeWithCustomer,
        "nTaxi" => solution.nTaxi, 
        "nOfflineRequests" => length(scenario.offlineRequests),
        "nOnlineRequests" => length(scenario.onlineRequests),
        "UnservicedOfflineRequests" => length(requestBankOffline),
        "UnservicedOnlineRequests" => length(setdiff(requestBank, requestBankOffline)),
        "TotalDirectRideTime" => totalDirectRideTime,
        "TotalActualRideTime" => totalActualRideTime,
        "TotalElapsedTime" => round(totalElapsedTime,digits=2),
        "AverageResponseTime" => round(averageResponseTime,digits=2), 
        "EventsInsertedByALNS" => eventsInsertedByALNS,
        "AveragePercentRideSharing" => round(averagePercentRideSharing,digits=3)
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(KPIDict))
    close(file)
end 

#==
 Method to process results 
==#
function processResults(files::Vector{String})
    results = DataFrame(
        ScenarioName = String[],
        TotalElapsedTime = Float64[],
        AverageResponseTime = Float64[],
        EventsInsertedByALNS = Int[], 
        nTaxi = Int[],
        TotalCost = Float64[],
        TotalDistance = Float64[],
        TotalIdleTime = Int[],
        TotalIdleTimeWithCustomer= Int[],
        TotalRideTime= Int[], 
        TotalDirectRideTime= Int[], 
        TotalActualRideTime= Int[],
        nOfflineRequests= Int[], 
        UnservicedOfflineRequest= Int[],
        nOnlineRequests= Int[],
        UnservicedOnlineRequests= Int[],
        AveragePercentRideSharing = Float64[]
    )

    # Assuming you have multiple JSON files, you can read them like this
    appendResults(files,results)

    return results
end

# Create an empty DataFrame with the KPIs as camel case column names

# Function to read and append multiple JSON files to the DataFrame
function appendResults(files,results)
    for file_path in files
        row = parse_json(file_path)
        push!(results, row)
    end
end



# Function to parse the JSON file and extract relevant information (camel case)
function parse_json(file_path)
    data = JSON.parsefile(file_path)
    
    # Extract values from the JSON structure with camel case keys
    scenarioName = data["Scenario"]["name"]
    totalIdleTime = data["TotalIdleTime"]
    eventsInsertedByALNS = data["EventsInsertedByALNS"]
    totalElapsedTime = data["TotalElapsedTime"]
    unservicedOnlineRequests = data["UnservicedOnlineRequests"]
    totalRideTime = data["TotalRideTime"]
    nTaxi = data["nTaxi"]
    unservicedOfflineRequests = data["UnservicedOfflineRequests"]
    averageResponseTime = data["AverageResponseTime"]
    totalIdleTimeWithCustomer = data["TotalIdleTimeWithCustomer"]
    totalDirectRideTime = data["TotalDirectRideTime"]
    nOnlineRequests = data["nOnlineRequests"]
    totalCost = data["TotalCost"]
    totalDistance = data["TotalDistance"]
    nOfflineRequests = data["nOfflineRequests"]
    totalActualRideTime = data["TotalActualRideTime"]
    averagePercentRideSharing = data["AveragePercentRideSharing"]
    
    return [
       scenarioName,
        totalElapsedTime,
        averageResponseTime,
        eventsInsertedByALNS, 
        nTaxi,
        totalCost,
        totalDistance,
        totalIdleTime,
        totalIdleTimeWithCustomer,
        totalRideTime, 
        totalDirectRideTime, 
        totalActualRideTime,
        nOfflineRequests, 
        unservicedOfflineRequests,
        nOnlineRequests,
        unservicedOnlineRequests, 
        averagePercentRideSharing
    ]
end








end