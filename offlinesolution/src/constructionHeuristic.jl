module ConstructionHeuristic

using utils
using domain

export simpleConstruction
export checkFeasibilityRoute
export feasibilityInsertion


# ----------
# Function to find the closest depot
# ----------
function getClosestDepot(request::Request, triedDepots::Vector{Int},scenario::Scenario)
    closest_depot = -1
    nRequests = length(scenario.requests)
    allDepotsIdx = collect(2 * nRequests + 1 : 2 * nRequests + scenario.nDepots)
    considerDepots = setdiff(allDepotsIdx,triedDepots)

    if isempty(considerDepots)
        return -1  # No valid depots left
    end

    # Find the closest depot index
    closestDepotIdx = argmin(scenario.time[considerDepots, request.id])  # Get index within considerDepots
    closest_depot = considerDepots[closestDepotIdx]  # Convert back to original index

    return closest_depot
end

# ----------
# Function to check feasibility of given placement of a request for a vehicle
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityRoute(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    # Determine ride time
    updatedRideTime = vehicleSchedule.activeTimeWindow.endTime - vehicleSchedule.activeTimeWindow.startTime

    for activity in [request.pickUpActivity, request.dropOffActivity]
        if activity == request.pickUpActivity
            idx = pickUpIdx
        else
            idx = dropOffIdx
        end
        
        # Check timewindows
        if (vehicleSchedule.route[idx].endOfServiceTime > activity.timeWindow.endTime) || (vehicleSchedule.route[idx+1].startOfServiceTime < activity.timeWindow.startTime)
            println("Infeasible: Time window")
            return false
        end
        
        # Check drive time: Vehicle cannot reach activity within timewindow from first node
        if activity == request.dropOffActivity && dropOffIdx == pickUpIdx
            continue
        elseif (vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime)
            println("Infeasible: Drive time from first node")
            return false
        end
        
        # Check drive time: Vehicle cannot reach next node from activity
        if activity == request.dropOffActivity && dropOffIdx == pickUpIdx
            endOfPickUp = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id] + scenario.serviceTimes[request.pickUpActivity.mobilityType]
            endOfDropOff = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
            arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
        else
            endService = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
            arrivalNextNode = endService + scenario.time[activity.id, vehicleSchedule.route[idx+1].activity.id]
        end

        if arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            println("Infeasible: Drive time to next node")
            return false
        end

        # Determine ride time
        if pickUpIdx == dropOffIdx == 1 || pickUpIdx == dropOffIdx == length(vehicleSchedule.route)-1
            timeToEndOfPickUp = scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id] + scenario.serviceTimes[request.pickUpActivity.mobilityType]
            timeToEndOfDropOff = scenario.time[request.pickUpActivity.id, request.dropOffActivity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
            totalTimeToArrivalNextNode = timeToEndOfDropOff + timeToEndOfPickUp + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
            updatedRideTime += totalTimeToArrivalNextNode/2   
        elseif idx == 1
            updatedRideTime += scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
        elseif idx == length(vehicleSchedule.route)-1
            updatedRideTime += scenario.time[activity.id,vehicleSchedule.route[idx+1].activity.id] + scenario.serviceTimes[activity.mobilityType]
        end
    end

    # Check maximum ride time
    if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
        println("Infeasible: Maximum ride time")
        return false
    end
    

    # If all checks pass, the activity is feasible
    println("FEASIBLE")
    return true
end

# ----------
# Function to check feasibility of inserting a request in a vehicle schedule
# ----------
function feasibilityInsertion(request::Request,vehicleSchedule::VehicleSchedule,scenario::Scenario)
    
    # Check vehicle capacity 
    if request.mobilityType == WHEELCHAIR && vehicleSchedule.nWheelchair == vehicleSchedule.vehicle.capacities[WHEELCHAIR] 
        return false, -1, -1
    elseif request.mobilityType == WALKING && vehicleSchedule.nWalking + vehicleSchedule.nWheelchair == vehicleSchedule.vehicle.totalCapacity
        return false, -1, -1
    end

    # Check inside available time window
    if vehicleSchedule.vehicle.availableTimeWindow.startTime > request.pickUpActivity.timeWindow.endTime || vehicleSchedule.vehicle.availableTimeWindow.endTime < request.dropOffActivity.timeWindow.startTime 
        return false, -1, -1
    end

    # Find and return first feasible placement for given schedule
    for idx_pickup in 1:length(vehicleSchedule.route)-1
        for idx_dropoff in idx_pickup:length(vehicleSchedule.route)-1
            # Check feasibility
            if checkFeasibilityRoute(request,vehicleSchedule,idx_pickup,idx_dropoff,scenario)
                return true, idx_pickup, idx_dropoff
            end
        end 
    end

    return false, -1, -1
end

# ----------
# Function to insert a request in a vehicle schedule
# ----------
function insertRequest(request::Request,vehicleSchedule::VehicleSchedule,idx_pickup::Int,idx_dropoff::Int,scenario::Scenario)
    nRequests = length(scenario.requests)
    ### Update Vehicle Schedule
    # Update route
    startOfServicePick = vehicleSchedule.route[idx_pickup].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] 
    startOfServiceDrop = vehicleSchedule.route[idx_dropoff].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_dropoff].activity.id,request.dropOffActivity.id] 
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idx_pickup,pickUpActivity)
    insert!(vehicleSchedule.route,idx_dropoff+1,dropOffActivity)

    # TODO Update activeTimeWindow + totalDistance
    # TODO Update vehicle

    return vehicleSchedule
end

# ----------
# Construct a solution using a simple construction heuristic
# ----------
function simpleConstruction(scenario::Scenario)
   
    # Initialize solution
    solution = Solution(scenario)
    nRequests = length(scenario.requests)

    for request in scenario.offlineRequests

        # Determine closest depot until feasible request is found
        feasible = false
        getTaxi = false
        triedDepots = Int[]
        nVehicles = length(scenario.vehicles)
        idx_pickup, idx_dropoff = -1, -1
        
        
        # Determine closest feasible depot
        closestDepot = -1
        while !feasible && !getTaxi
            closestDepot = getClosestDepot(request,triedDepots,scenario)
            feasible, idx_pickup, idx_dropoff = feasibilityInsertion(request,solution.vehicleSchedules[closestDepot-2*nRequests],scenario)
            if !feasible
                append!(triedDepots,closestDepot)
            end
            getTaxi = length(triedDepots) == scenario.nDepots
        end

        # Insert request
        if feasible
            #TODO: Everything here has to be done right
            solution.vehicleSchedules[closestDepot-2*nRequests] = insertRequest(request,solution.vehicleSchedules[closestDepot-2*nRequests],idx_pickup,idx_dropoff,scenario)

            # Update solution
            solution.totalCost = getTotalCostRoute(scenario,solution.vehicleSchedules)
            solution.totalDistance += getTotalDistanceRoute(solution.vehicleSchedules[closestDepot-2*nRequests].route,scenario)
        else
            solution.nTaxi += getTaxi
        end

    end

    return solution
    
end



end