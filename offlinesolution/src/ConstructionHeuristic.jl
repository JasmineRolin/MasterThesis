module ConstructionHeuristic

using utils
using domain
using TimerOutputs

export simpleConstruction
export findFeasibleInsertionInSchedule


# ----------
# Construct a solution using a simple construction heuristic
# ----------
function simpleConstruction(scenario::Scenario,requests::Vector{Request};visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
   
    # Initialize solution
    solution = Solution(scenario)
    requestBank = Int[]

    for request in requests
        # Determine closest feasible vehicle
        closestVehicleIdx, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete,totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = getClosestFeasibleVehicle(request,solution,scenario,visitedRoute=visitedRoute,TO=TO)

        # Insert request
        if closestVehicleIdx != -1
            insertRequest!(request,solution.vehicleSchedules[closestVehicleIdx],idxPickUp,idxDropOff,scenario,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,totalCost=totalCost,totalDistance=totalDistance,totalIdleTime=totalIdleTime,totalTime=totalTime,visitedRoute=visitedRoute,waitingActivitiesToAdd=waitingActivitiesToAdd)
        else
            append!(requestBank,request.id)
        end
    end

    # Update solution
    solution.nTaxi = sum(requestBank .<= scenario.nFixed)
    solution.nTaxiExpected = sum(requestBank .> scenario.nFixed)
    solution.totalCost, solution.totalDistance, solution.totalRideTime, solution.totalIdleTime = getTotalCostDistanceTimeOfSolution(scenario,solution)
    
    
    return solution, requestBank
    
end


# ----------
# Function to find the closest vehicle
# ----------
function getClosestFeasibleVehicle(request::Request, solution::Solution, scenario::Scenario; visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())
    closestVehicle = nothing
    minTravelTime = Inf
    closestVehicleIdx = -1
    bestPickUpIdx = -1
    bestDropOffIdx = -1
    bestNewStartOfServiceTimes = Vector{Int}()
    bestNewEndOfServiceTimes = Vector{Int}()
    bestWaitingActivitiesToDelete = Vector{Int}()
    bestCost = typemax(Float64)
    bestDistance = 0.0
    bestIdleTime = 0 
    bestTime = 0
    requestPickupId = request.pickUpActivity.id
    requestTime = request.pickUpActivity.timeWindow.startTime
    bestWaitingActivitiesToAdd = Vector{Int}()

    considerVehicles = collect(1:length(scenario.vehicles))

    for vehicleIdx in considerVehicles
        vehicle = scenario.vehicles[vehicleIdx]
        vehicleSchedule = solution.vehicleSchedules[vehicle.id]
        
        # Ensure the vehicle is available within the time window
        if vehicle.availableTimeWindow.startTime > requestTime || vehicle.availableTimeWindow.endTime < requestTime
            continue
        end
        
        # Find the vehicle's activity at the request pickup time
        vehicleLocationId = nothing
        for (idx,activity) in enumerate(vehicleSchedule.route)
            if idx == length(vehicleSchedule.route)
                vehicleLocationId = vehicleSchedule.route[end].activity.id
                break
            elseif vehicleSchedule.route[idx+1].startOfServiceTime >= requestTime
                vehicleLocationId = activity.activity.id
                break
            end
        end
        
        # Compute travel time from the determined vehicle location to the pickup location
        travelTime = scenario.time[vehicleLocationId, requestPickupId]

        if travelTime < minTravelTime
            # Determine if there is a feasible place to insert it
            feasible, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd  = findFeasibleInsertionInSchedule(request,solution.vehicleSchedules[vehicleIdx],scenario,visitedRoute=visitedRoute,TO=TO)

            # Update closest vehicle if a shorter travel time is found
            if feasible
                minTravelTime = travelTime
                closestVehicle = vehicle
                closestVehicleIdx = vehicleIdx
                bestPickUpIdx = idxPickUp
                bestDropOffIdx = idxDropOff
                bestNewStartOfServiceTimes = deepcopy(newStartOfServiceTimes)
                bestNewEndOfServiceTimes = deepcopy(newEndOfServiceTimes)
                bestWaitingActivitiesToDelete = deepcopy(waitingActivitiesToDelete)
                bestCost = totalCost
                bestDistance = totalDistance
                bestIdleTime = totalIdleTime
                bestTime = totalTime
                bestWaitingActivitiesToAdd = deepcopy(waitingActivitiesToAdd)
            end
        end
    end
    
    return closestVehicleIdx, bestPickUpIdx, bestDropOffIdx, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestWaitingActivitiesToDelete, bestCost, bestDistance, bestIdleTime, bestTime, bestWaitingActivitiesToAdd
end


# ----------
# Function to check feasibility of inserting a request in a vehicle schedule and returning feasible position
# ----------
function findFeasibleInsertionInSchedule(request::Request,vehicleSchedule::VehicleSchedule,scenario::Scenario;visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())

    # Check inside available time window
    if vehicleSchedule.vehicle.availableTimeWindow.startTime > request.pickUpActivity.timeWindow.endTime || vehicleSchedule.vehicle.availableTimeWindow.endTime < request.dropOffActivity.timeWindow.startTime 
        #println("Infeasible: Outside available time window")
        return false, -1, -1, [],[],[],-1.0,-1.0,-1,-1,[]
    end

    # Find and return first feasible placement for given schedule
    for idxPickUp in 1:length(vehicleSchedule.route)-1
        for idxDropOff in idxPickUp:length(vehicleSchedule.route)-1
            # Check feasibility
            feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,idxPickUp,idxDropOff,scenario,visitedRoute=visitedRoute,TO=TO)
            if feasible
                return true, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete,totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd
            end
        end 
    end

    return false, -1, -1, [],[],[],-1.0,-1.0,-1,-1,[]
end





end