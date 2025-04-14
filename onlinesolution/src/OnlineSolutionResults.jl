module OnlineSolutionResults

using Plots, JSON
using domain, utils 

export createGantChartOfSolutionOnline,writeOnlineKPIsToFile


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
 Write KPIs to file  
==#
function writeOnlineKPIsToFile(fileName::String, scenario::Scenario,solution::Solution,requestBank::Vector{Int},requestBankOffline::Vector{Int},totalElapsedTime::Float64,averageResponseTime::Float64)
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
        "AverageResponseTime" => round(averageResponseTime,digits=2)
    )

    # Write the dictionary to a JSON file
    file = open(fileName, "w") 
    write(file, JSON.json(KPIDict))
    close(file)
end 



end