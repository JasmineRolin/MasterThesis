module CostCalculator

using domain

export getTotalDistanceRoute
export getTotalCostRoute
export getTotalTimeRoute
export getTotalIdleTimeRoute
export getTotalCostDistanceTimeOfSolution
export getCostOfRequest


#==
#  Function to get total distance of a route
==# 
function getTotalDistanceRoute(route::Vector{ActivityAssignment},scenario::Scenario)
    totalDistance = 0
    distanceMatrix = scenario.distance

    for i in 1:length(route)-1
        totalDistance += distanceMatrix[route[i].activity.id, route[i+1].activity.id]
    end

    return totalDistance
end

function getTotalDistanceRoute(route::Vector{ActivityAssignment},distanceMatrix::Array{Float64,2})
    totalDistance = 0

    for i in 1:length(route)-1
        totalDistance += distanceMatrix[route[i].activity.id, route[i+1].activity.id]
    end

    return totalDistance
end

#==
#  Function to get total time of a route 
==#
function getTotalTimeRoute(schedule::VehicleSchedule)
    return duration(schedule.activeTimeWindow)
end


#==
#  Function to get total cost/excees ridetime of route
==#
function getTotalCostRoute(scenario::Scenario,route::Vector{ActivityAssignment})
    time = scenario.time
    excessTimeRatio = 0
    pickupTimes = Dict{Int, Int}()
    
    for assignment in route
        activity = assignment.activity
        if activity.activityType == PICKUP
            pickupTimes[activity.requestId] = assignment.endOfServiceTime
        elseif activity.activityType == DROPOFF && haskey(pickupTimes, activity.requestId)
            pickupTime = pickupTimes[activity.requestId]
            dropoffTime = assignment.startOfServiceTime
            directTime = time[activity.requestId, activity.id] 
            excessTime = (dropoffTime - pickupTime) - directTime
            excessTimeRatio += (dropoffTime - pickupTime) #(excessTime / directTime)*10.0
        end
    end
    
    return excessTimeRatio
end

#==
# Function to get cost of request 
=#
function getCostOfRequest(time::Array{Int,2},pickUpActivity::ActivityAssignment,dropOffActivity::ActivityAssignment)
    directTime = time[pickUpActivity.activity.id,dropOffActivity.activity.id]
    excessTime = (dropOffActivity.startOfServiceTime - pickUpActivity.endOfServiceTime) - directTime
    return  (dropOffActivity.startOfServiceTime - pickUpActivity.endOfServiceTime) #(excessTime/directTime)*10.0
end

#==
# Function to get total idle time of route 
==#
function getTotalIdleTimeRoute(route::Vector{ActivityAssignment})
    totalIdleTime = 0
    for activityAssignment in route
        if activityAssignment.activity.activityType == WAITING
            totalIdleTime += activityAssignment.endOfServiceTime - activityAssignment.startOfServiceTime
        end
    end

    return totalIdleTime
end


#==
# Function to get total cost and distance of solution 
==#
function getTotalCostDistanceTimeOfSolution(scenario::Scenario,solution::Solution)
    totalCost = 0.0
    totalDistance = 0.0
    totalTime = 0
    for schedule in solution.vehicleSchedules
        if length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            continue
        end

        totalCost += schedule.totalCost
        totalDistance += schedule.totalDistance
        totalTime += schedule.totalTime
    end

    totalCost += solution.nTaxi * scenario.taxiParameter

    return totalCost, totalDistance, totalTime
end

end