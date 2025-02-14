module ConstructionHeuristic

using utils
using domain

export simpleConstruction



# Function to find the closest depot
function getClosestDepot(request::Request, triedVehicles::Vector{Int},scenario::Scenario)
    closest_depot = -1
    nRequests = length(scenario.requests)
    allDepotsIdx = collect(2 * nRequests + 1 : 2 * nRequests + scenario.nDepots)
    considerDepots = setdiff(allDepotsIdx,triedVehicles)

    if isempty(considerDepots)
        return -1  # No valid depots left
    end

    # Find the closest depot index
    closestDepotIdx = argmin(scenario.time[considerDepots, request.id])  # Get index within considerDepots
    closest_depot = considerDepots[closestDepotIdx]  # Convert back to original index

    return closest_depot
end

# Function to check feasibility of given placement of a request for a vehicle
function checkFeasibilityRoute(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    updatedRideTime = vehicleSchedule.vehicle.availableTimeWindow.endTime - vehicleSchedule.vehicle.availableTimeWindow.startTime

    for activity in [request.pickUpActivity, request.dropOffActivity]
        if activity == request.pickUpActivity
            idx = pickUpIdx
        else
            idx = dropOffIdx
        end
        
        # Check timewindows
        if vehicleSchedule.route[idx].endOfServiceTime > activity.timeWindow.endTime || vehicleSchedule.route[idx+1].startOfServiceTime < activity.timeWindow.startTime
            return false
        end
        
        # Check drive time: Vehicle cannot reach activity within timewindow from first node
        if vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime
            return false
        end
        
        # Check drive time: Vehicle cannot reach next node from activity
        endService = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
        if endService + scenario.time[activity.id, vehicleSchedule.route[idx+1].activity.id] > vehicleSchedule.route[idx+1].startOfServiceTime
            return false
        end

        # Determine ride time
        if idx == 1
            updatedRideTime += scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
        elseif idx == length(vehicleSchedule.route)-1
            updatedRideTime += scenario.time[activity.id,vehicleSchedule.route[idx+1].activity.id] + scenario.serviceTimes[activity.mobilityType]
        end
    end

    # Check maximum ride time
    if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
        return false
    end
    

    # If all checks pass, the activity is feasible
    return true
end

# Function to check feasibility of inserting a request in a vehicle schedule
function feasibilityInsertion(request::Request,vehicleSchedule::VehicleSchedule,scenario::Scenario)

    for idx_pickup in 1:length(vehicleSchedule.route)-1
        for idx_dropoff in idx_pickup+1:length(vehicleSchedule.route)
            # Check feasibility
            if checkFeasibilityRoute(request,vehicleSchedule,idx_pickup,idx_dropoff,scenario)
                return true, idx_pickup, idx_dropoff
            end
        end 
    end
    return false, -1, -1
end


# Function to insert a request in a vehicle schedule
function insertRequest(request::Request,solution::Solution,depot::Int,idx_pickup::Int,idx_dropoff::Int,scenario::Scenario)

    ### Update Vehicle Schedule
    # Update route
    startOfServicePick = solution.vehicleSchedules[depot-2*nRequests].route[idx_pickup].endOfServiceTime + scenario.time[solution.vehicleSchedules[depot-2*nRequests].route[idx_pickup].activity.id,request.pickUpActivity.id] 
    startOfServiceDrop = solution.vehicleSchedules[depot-2*nRequests].route[idx_dropoff].endOfServiceTime + scenario.time[solution.vehicleSchedules[depot-2*nRequests].route[idx_dropoff].activity.id,request.dropOffActivity.id] 
    pickUpActivity = ActivityAssignment(request.pickUpActivity, depot, startOfServicePick, startOfServicePick+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, depot, startOfServiceDrop, startOfServiceDrop+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    insert!(solution.vehicleSchedules[depot-2*nRequests].route,idx_pickup,pickUpActivity)
    insert!(solution.vehicleSchedules[depot-2*nRequests].route,idx_dropoff+1,dropOffActivity)

    # TODO Update activeTimeWindow + totalDistance
    # TODO Update vehicle

    return solution
end

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
        closestDepot = -1
        while !feasible && !getTaxi
            closestDepot = getClosestDepot(request,triedDepots,scenario)
            feasible, idx_pickup, idx_dropoff = feasibilityInsertion(request,solution.vehicleSchedules[closestDepot-2*nRequests],scenario)
            if !feasible
                append!(triedDepots,closestDepot)
            end
            println(triedDepots)
            println(length(triedDepots) == scenario.nDepots)
            getTaxi = length(triedDepots) == scenario.nDepots
        end
        println(getTaxi)

        # Insert request
        if feasible
            solution = insertRequest(request,solution,closestDepot,idx_pickup,idx_dropoff,scenario)

            # Update solution
            solution.vehicleSchedules = newVehicleSchedule
            solution.totalCost += getTotalCostRoute(scenario,route)
            solution.totalDistance += getTotalDistanceRoute(route,scenario)
        else
            solution.nTaxi += getTaxi
        end

    end

    return solution
    
end



end