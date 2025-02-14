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

    if pickUpIdx == dropOffIdx
        # Determine arrival times
        idx = pickUpIdx
        earliestStartOfServicePick = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
        endOfPickUp = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime) + scenario.serviceTimes[request.pickUpActivity.mobilityType]
        earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
        endOfDropOff = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime) + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]

        # Check drive time: First node
        if earliestStartOfServicePick > request.pickUpActivity.timeWindow.endTime
            println("Infeasible: Drive time from first node")
            return false
        end
        
        # Check drive time:Next node
        if arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            println("Infeasible: Drive time to next node")
            return false
        end

        # Determine ride time
        if idx == 1 || idx == length(vehicleSchedule.route)-1
            updatedRideTime += arrivalNextNode-earliestStartOfServicePick-scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
        end

        # Check maximum ride time
        if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
            println("Infeasible: Maximum ride time")
            return false
        end


    else

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
            if (vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime)
                println("Infeasible: Drive time from first node")
                return false
            end
            
            # Check drive time: Vehicle cannot reach next node from activity
            endService = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
            arrivalNextNode = endService + scenario.time[activity.id, vehicleSchedule.route[idx+1].activity.id]
            if arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
                println("Infeasible: Drive time to next node")
                return false
            end
    
            # Determine ride time
            if idx == 1
                updatedRideTime += scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
            elseif idx == length(vehicleSchedule.route)-1
                updatedRideTime += scenario.time[activity.id,vehicleSchedule.route[idx+1].activity.id] + scenario.serviceTimes[activity.mobilityType]
            end

            # Check maximum ride time
            if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
                println("Infeasible: Maximum ride time")
                return false
            end
        end
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
    # Update service time
    if idx_pickup == idx_dropoff
        earliestStartOfServicePick = vehicleSchedule.route[idx_pickup].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
        earliestStartOfServiceDrop = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType] + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    else
        earliestStartOfServicePick = vehicleSchedule.route[idx_pickup].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
        earliestStartOfServiceDrop = vehicleSchedule.route[idx_dropoff].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_dropoff].activity.id,request.dropOffActivity.id] 
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    end

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick+scenario.serviceTimes[request.pickUpActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idx_pickup+1,pickUpActivity)
    insert!(vehicleSchedule.route,idx_dropoff+2,dropOffActivity)

    # TODO Update activeTimeWindow + totalDistance

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
            println(triedDepots)
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