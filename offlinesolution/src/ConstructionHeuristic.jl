module ConstructionHeuristic

using utils
using domain

export simpleConstruction
export findFeasibleInsertionInSchedule


# ----------
# Construct a solution using a simple construction heuristic
# ----------
function simpleConstruction(scenario::Scenario,requests::Vector{Request})
   
    # Initialize solution
    solution = Solution(scenario)
    requestBank = Int[]

    for request in requests
        # Determine closest feasible vehicle
        closestVehicleIdx, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, startOfScheduleBlock, endOfScheduleBlock   = getClosestFeasibleVehicle(request,solution,scenario)

        # Insert request
        if closestVehicleIdx != -1
            insertRequest!(request,solution.vehicleSchedules[closestVehicleIdx],idxPickUp,idxDropOff,startOfScheduleBlock,endOfScheduleBlock,scenario,newStartOfServiceTimes,newEndOfServiceTimes)
        else
            append!(requestBank,request.id)
        end

    end

    # Update solution
    solution.nTaxi = length(requestBank)
    # TODO: burde det her ikke bare løbende blive opdateret i insertRequest! ?
    solution.totalCost, solution.totalDistance, solution.totalRideTime, solution.totalIdleTime = getTotalCostDistanceTimeOfSolution(scenario,solution)
    
    
    return solution, requestBank
    
end


# ----------
# Function to find the closest vehicle
# ----------
function getClosestFeasibleVehicle(request::Request, solution::Solution, scenario::Scenario)
    closestVehicle = nothing
    minTravelTime = Inf
    closestVehicleIdx = -1
    bestPickUpIdx = -1
    bestDropOffIdx = -1
    bestNewStartOfServiceTimes = []
    bestNewEndOfServiceTimes = []
    bestStartOfScheduleBlock = -1
    bestEndOfScheduleBlock = -1
    requestPickupId = request.pickUpActivity.id
    requestTime = request.pickUpActivity.timeWindow.startTime

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

        # Determine if there is a feasible place to insert it
        feasible, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, startOfScheduleBlock, endOfScheduleBlock  = findFeasibleInsertionInSchedule(request,solution.vehicleSchedules[vehicleIdx],scenario)

        # Update closest vehicle if a shorter travel time is found
        if feasible && travelTime < minTravelTime
            minTravelTime = travelTime
            closestVehicle = vehicle
            closestVehicleIdx = vehicleIdx
            bestPickUpIdx = idxPickUp
            bestDropOffIdx = idxDropOff
            bestNewStartOfServiceTimes = deepcopy(newStartOfServiceTimes)
            bestNewEndOfServiceTimes = deepcopy(newEndOfServiceTimes)
            bestStartOfScheduleBlock = startOfScheduleBlock
            bestEndOfScheduleBlock = endOfScheduleBlock
        end
    end
    
    return closestVehicleIdx, bestPickUpIdx, bestDropOffIdx, bestNewStartOfServiceTimes, bestNewEndOfServiceTimes, bestStartOfScheduleBlock, bestEndOfScheduleBlock
end


# ----------
# Function to check feasibility of inserting a request in a vehicle schedule and returning feasible position
# ----------
function findFeasibleInsertionInSchedule(request::Request,vehicleSchedule::VehicleSchedule,scenario::Scenario)

    # Check inside available time window
    if vehicleSchedule.vehicle.availableTimeWindow.startTime > request.pickUpActivity.timeWindow.endTime || vehicleSchedule.vehicle.availableTimeWindow.endTime < request.dropOffActivity.timeWindow.startTime 
        println("Infeasible: Outside available time window")
        return false, -1, -1, nothing
    end

    # Find and return first feasible placement for given schedule
    for idxPickUp in 1:length(vehicleSchedule.route)-1
        for idxDropOff in idxPickUp:length(vehicleSchedule.route)-1
            # Check feasibility
            feasible, newStartOfServiceTimes, newEndOfServiceTimes, startOfScheduleBlock, endOfScheduleBlock= checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,idxPickUp,idxDropOff,scenario)
            if feasible
                return true, idxPickUp, idxDropOff, newStartOfServiceTimes, newEndOfServiceTimes, startOfScheduleBlock, endOfScheduleBlock
            end
        end 
    end

    return false, -1, -1, [], [], -1, -1
end





end