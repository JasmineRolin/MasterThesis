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
    return getTotalCostRoute(scenario.time,route)
end

function getTotalCostRoute(time::Array{Int,2},route::Vector{ActivityAssignment})
    ratio = 0.0
    pickupTimes = Dict{Int, Int}()
    
    for assignment in route
        activity = assignment.activity
        if activity.activityType == PICKUP
            pickupTimes[activity.requestId] = assignment.endOfServiceTime
        elseif activity.activityType == DROPOFF && haskey(pickupTimes, activity.requestId)
            pickupTime = pickupTimes[activity.requestId]
            dropoffTime = assignment.startOfServiceTime
            directTime = Float64(time[activity.requestId, activity.id])
            actualTime = Float64(dropoffTime - pickupTime)
            ratio += actualTime/directTime
        end
    end
    
    return ratio*10.0
end

function getTotalCostRouteOnline(time::Array{Int,2},route::Vector{ActivityAssignment},visitedRoute::Dict{Int, Dict{String, Int}})
    ratio = 0.0
    pickupTimes = Dict{Int, Int}()
    
    for assignment in route
        activity = assignment.activity
        if activity.activityType == PICKUP
            pickupTimes[activity.requestId] = assignment.endOfServiceTime
        elseif activity.activityType == DROPOFF && haskey(pickupTimes, activity.requestId)
            pickupTime = pickupTimes[activity.requestId]
            dropoffTime = assignment.startOfServiceTime
            directTime = Float64(time[activity.requestId, activity.id])
            actualTime = Float64(dropoffTime - pickupTime)
            ratio += actualTime/directTime
        elseif activity.activityType == DROPOFF
            pickupTime = visitedRoute[activity.requestId][PickUpServiceStart]
            dropoffTime = assignment.startOfServiceTime
            directTime = Float64(time[activity.requestId, activity.id])
            actualTime = Float64(dropoffTime - pickupTime)
            ratio += actualTime/directTime
        end
    end
    
    return ratio*10.0
end

#==
# Function to get cost of request 
=#
function getCostOfRequest(time::Array{Int,2},pickUpActivity::ActivityAssignment,dropOffActivity::ActivityAssignment)
    directTime = Float64(time[pickUpActivity.activity.id,dropOffActivity.activity.id])
    actualTime = Float64(dropOffActivity.startOfServiceTime - pickUpActivity.endOfServiceTime)
    return  actualTime/directTime*10.0
end

function getCostOfRequest(time::Array{Int,2},endOfServiceTimePickUp::Int,startOfServiceTimeDropOff::Int,pickUpActivityId::Int,dropOffActivityId::Int)
    directTime = Float64(time[pickUpActivityId,dropOffActivityId])
    actualTime = Float64(startOfServiceTimeDropOff - endOfServiceTimePickUp)
    return  actualTime/directTime*10.0
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
    totalIdleTime = 0
    for schedule in solution.vehicleSchedules
        if length(schedule.route) == 2 && schedule.route[1].activity.activityType == DEPOT && schedule.route[2].activity.activityType == DEPOT
            continue
        end

        totalCost += schedule.totalCost
        totalDistance += schedule.totalDistance
        totalTime += schedule.totalTime
        totalIdleTime += schedule.totalIdleTime
    end

    totalCost += solution.nTaxi * scenario.taxiParameter

    return totalCost, totalDistance, totalTime, totalIdleTime
end

end