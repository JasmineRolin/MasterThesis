module ConstructionHeuristic

using utils
using domain

export simpleConstruction
export findFeasibleInsertionInSchedule


# ----------
# Construct a solution using a simple construction heuristic
# ----------
function simpleConstruction(scenario::Scenario)
   
    # Initialize solution
    solution = Solution(scenario)
    requestBank = Int[]

    for request in scenario.offlineRequests
        # Initialize variables
        feasible = false
        getTaxi = false
        typeOfSeat = nothing
        triedVehicles = Set{Int}()
        idxPickUp, idxDropOff = -1, -1
        closestVehicleIdx = -1

        # Determine closest feasible vehicle
        while !feasible && !getTaxi
            closestVehicleIdx = getClosestVehicle(request,triedVehicles,solution,scenario)

            if closestVehicleIdx == -1 
                feasible = false
                break
            else
                feasible, idxPickUp, idxDropOff, typeOfSeat = findFeasibleInsertionInSchedule(request,solution.vehicleSchedules[closestVehicleIdx],scenario)
                    if !feasible
                        push!(triedVehicles, closestVehicleIdx)
                    else
                        break
                    end
            end
            getTaxi = length(triedVehicles) == length(scenario.vehicles)
        end

        # Insert request
        if feasible
            insertRequest!(request,solution.vehicleSchedules[closestVehicleIdx],idxPickUp,idxDropOff,typeOfSeat,scenario)
        else
            solution.nTaxi += 1
            append!(requestBank,request.id)
        end
        println(solution.nTaxi)

    end

    # Update solution
    solution.totalCost, solution.totalDistance, solution.totalRideTime = getTotalCostDistanceTimeOfSolution(scenario,solution)
    
    return solution, requestBank
    
end


# ----------
# Function to find the closest depot
# ----------
function getClosestDepot(request::Request, triedDepots::Set{Int},scenario::Scenario)
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
# Function to find the closest vehicle
# ----------
function getClosestVehicle(request::Request,triedVehicles::Set{Int}, solution::Solution, scenario::Scenario)
    closest_vehicle = nothing
    min_travel_time = Inf
    closest_vehicle_idx = -1
    request_pickup_id = request.pickUpActivity.id
    request_time = request.pickUpActivity.timeWindow.startTime

    allVehiclesIdx = collect(1:length(scenario.vehicles))
    considerVehicles = setdiff(allVehiclesIdx,triedVehicles)

    for vehicleIdx in considerVehicles
        vehicle = scenario.vehicles[vehicleIdx]
        vehicle_schedule = solution.vehicleSchedules[vehicle.id]
        
        # Ensure the vehicle is available within the time window
        if vehicle.availableTimeWindow.startTime > request_time || vehicle.availableTimeWindow.endTime < request_time
            continue
        end
        
        # Find the vehicle's activity at the request pickup time
        vehicle_location_id = nothing
        for (idx,activity) in enumerate(vehicle_schedule.route)
            if idx == length(vehicle_schedule.route)
                vehicle_location_id = vehicle_schedule.route[end].activity.id
                break
            elseif vehicle_schedule.route[idx+1].startOfServiceTime >= request_time
                vehicle_location_id = activity.activity.id
                break
            end
        end
        
        # Compute travel time from the determined vehicle location to the pickup location
        travel_time = scenario.time[vehicle_location_id, request_pickup_id]

        # Update closest vehicle if a shorter travel time is found
        if travel_time < min_travel_time
            min_travel_time = travel_time
            closest_vehicle = vehicle
            closest_vehicle_idx = vehicleIdx
        end
    end
    
    return closest_vehicle_idx
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
            feasible, typeOfSeat = checkFeasibilityOfInsertionAtPosition(request,vehicleSchedule,idxPickUp,idxDropOff,scenario)
            if feasible
                return true, idxPickUp, idxDropOff, typeOfSeat
            end
        end 
    end

    return false, -1, -1, nothing
end





end