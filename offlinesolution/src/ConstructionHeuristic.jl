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

    for request in scenario.offlineRequests
        # Initialize variables
        feasible = false
        getTaxi = false
        typeOfSeat = nothing
        triedDepots = Set{Int}()
        idxPickUp, idxDropOff = -1, -1
        vehicle = -1
        closestDepot = -1
        
        # Determine closest feasible vehicle
        while !feasible && !getTaxi
            closestDepot = getClosestDepot(request,triedDepots,scenario)
            for vehicleIdx in scenario.depots[closestDepot]
                vehicle = vehicleIdx
                feasible, idxPickUp, idxDropOff, typeOfSeat = findFeasibleInsertionInSchedule(request,solution.vehicleSchedules[vehicle],scenario)
                if !feasible
                    push!(triedDepots, closestDepot)
                # else
                #     break
                end
            end
            getTaxi = length(triedDepots) == scenario.nDepots
        end

        # Insert request
        if feasible
            insertRequest!(request,solution.vehicleSchedules[vehicle],idxPickUp,idxDropOff,typeOfSeat,scenario)
        else
            solution.nTaxi += getTaxi
        end

    end

    # Update solution
    solution.totalCost, solution.totalDistance, solution.totalRideTime = getTotalCostDistanceTimeOfSolution(scenario,solution)
    
    return solution
    
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