module ConstructionHeuristic

using utils
using domain

export simpleConstruction
export checkFeasibilityRoute
export feasibilityInsertion


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
# Function to check feasibility of given placement of a request for a vehicle
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityRoute(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    typeOfSeat = nothing

    # Determine ride time
    updatedRideTime = vehicleSchedule.activeTimeWindow.endTime - vehicleSchedule.activeTimeWindow.startTime

    if pickUpIdx == dropOffIdx
        # Determine arrival times
        idx = pickUpIdx
        earliestStartOfServicePick = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
        endOfPickUp = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType]
        earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
        endOfDropOff = startOfServiceDrop + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]

        # Check drive time: First node
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime
            println("Infeasible: Drive time from first node")
            return false, typeOfSeat
        end
        
        # Check drive time:Next node
        if arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        end

        # Determine ride time
        if idx == 1 || idx == length(vehicleSchedule.route)-1
            updatedRideTime += arrivalNextNode-startOfServicePick-scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
        end

        # Check maximum ride time
        if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
            println("Infeasible: Maximum ride time")
            return false, typeOfSeat
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
                return false, typeOfSeat
            end
            
            # Check drive time: Vehicle cannot reach activity within timewindow from first node
            if (vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] > activity.timeWindow.endTime)
                println("Infeasible: Drive time from first node")
                return false, typeOfSeat
            end
            
            # Check drive time: Vehicle cannot reach next node from activity
            endService = vehicleSchedule.route[idx].endOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
            arrivalNextNode = endService + scenario.time[activity.id, vehicleSchedule.route[idx+1].activity.id]
            if arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
                println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            end
    
            # Determine ride time
            if idx == 1
                direct_ride = scenario.time[vehicleSchedule.route[idx].activity.id, activity.id] + scenario.serviceTimes[activity.mobilityType]
                shortest_possible_ride = vehicleSchedule.route[idx].startOfServiceTime-activity.timeWindow.endTime
                updatedRideTime += max(direct_ride,shortest_possible_ride)
            elseif idx == length(vehicleSchedule.route)-1
                direct_ride = scenario.time[activity.id, vehicleSchedule.route[idx].activity.id] + scenario.serviceTimes[activity.mobilityType]
                shortest_possible_ride = activity.timeWindow.startTime-vehicleSchedule.route[idx].endOfServiceTime
                updatedRideTime += max(direct_ride,shortest_possible_ride)
            end

            # Check maximum ride time
            if updatedRideTime > vehicleSchedule.vehicle.maximumRideTime
                println("Infeasible: Maximum ride time")
                return false, typeOfSeat
            end
        end
    end

    # Check vehicle capacity
    if request.mobilityType == WHEELCHAIR && all(vehicleSchedule.numberOfWheelchair[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WHEELCHAIR])
        typeOfSeat = WHEELCHAIR
    elseif request.mobilityType == WALKING && all(vehicleSchedule.numberOfWalking[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WALKING])
        typeOfSeat = WALKING
    elseif request.mobilityType == WALKING && all(vehicleSchedule.numberOfWheelchair[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.capacities[WHEELCHAIR])
        typeOfSeat = WHEELCHAIR
    else
        println("Infeasible: Not enough capacity")
        return false, typeOfSeat
    end
        
    # If all checks pass, the activity is feasible
    println("FEASIBLE")
    return true, typeOfSeat
end

# ----------
# Function to check feasibility of inserting a request in a vehicle schedule
# ----------
function feasibilityInsertion(request::Request,vehicleSchedule::VehicleSchedule,scenario::Scenario)

    # Check inside available time window
    if vehicleSchedule.vehicle.availableTimeWindow.startTime > request.pickUpActivity.timeWindow.endTime || vehicleSchedule.vehicle.availableTimeWindow.endTime < request.dropOffActivity.timeWindow.startTime 
        println("Infeasible: Outside available time window")
        return false, -1, -1, nothing
    end

    # Find and return first feasible placement for given schedule
    for idx_pickup in 1:length(vehicleSchedule.route)-1
        for idx_dropoff in idx_pickup:length(vehicleSchedule.route)-1
            # Check feasibility
            feasible, typeOfSeat = checkFeasibilityRoute(request,vehicleSchedule,idx_pickup,idx_dropoff,scenario)
            if feasible
                return true, idx_pickup, idx_dropoff, typeOfSeat
            end
        end 
    end

    return false, -1, -1, nothing
end

# ----------
# Function to insert a request in a vehicle schedule
# ----------
function insertRequest(request::Request,vehicleSchedule::VehicleSchedule,idx_pickup::Int,idx_dropoff::Int,typeOfSeat::MobilityType,scenario::Scenario)

    # Update routes
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

    # Update active time windows
    if idx_pickup == 1
        vehicleSchedule.activeTimeWindow.startTime = startOfServicePick - scenario.time[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id]
        vehicleSchedule.route[1].startOfServiceTime = vehicleSchedule.activeTimeWindow.startTime
        vehicleSchedule.route[1].endOfServiceTime = vehicleSchedule.activeTimeWindow.startTime
    elseif idx_dropoff == length(vehicleSchedule.route)-3
        vehicleSchedule.activeTimeWindow.endTime = startOfServiceDrop + scenario.time[request.dropOffActivity.id,vehicleSchedule.route[idx_dropoff+3].activity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        vehicleSchedule.route[idx_dropoff+3].startOfServiceTime = vehicleSchedule.activeTimeWindow.endTime
        vehicleSchedule.route[idx_dropoff+3].endOfServiceTime = vehicleSchedule.activeTimeWindow.endTime
    end
    if length(vehicleSchedule.route) == 4
        vehicleSchedule.activeTimeWindow.endTime = startOfServiceDrop + scenario.time[request.dropOffActivity.id,vehicleSchedule.route[idx_dropoff+3].activity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
    end

    # Update capacities
    if typeOfSeat == WHEELCHAIR
        # Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idx_pickup+1,vehicleSchedule.numberOfWheelchair[idx_pickup]+1)
        insert!(vehicleSchedule.numberOfWheelchair,idx_dropoff+2,vehicleSchedule.numberOfWheelchair[idx_dropoff+2])
        for i in idx_pickup+2:idx_dropoff+1
            vehicleSchedule.numberOfWheelchair[i] = vehicleSchedule.numberOfWheelchair[i] + 1
        end

        #Walking
        insert!(vehicleSchedule.numberOfWalking,idx_pickup+1,vehicleSchedule.numberOfWalking[idx_pickup])
        insert!(vehicleSchedule.numberOfWalking,idx_dropoff+2,vehicleSchedule.numberOfWalking[idx_dropoff+2])

    else
        # Walking
        insert!(vehicleSchedule.numberOfWalking,idx_pickup+1,vehicleSchedule.numberOfWalking[idx_pickup]+1)
        insert!(vehicleSchedule.numberOfWalking,idx_dropoff+2,vehicleSchedule.numberOfWalking[idx_dropoff+2])
        for i in idx_pickup+2:idx_dropoff+1
            vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
        end

        #Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idx_pickup+1,vehicleSchedule.numberOfWheelchair[idx_pickup])
        insert!(vehicleSchedule.numberOfWheelchair,idx_dropoff+2,vehicleSchedule.numberOfWheelchair[idx_dropoff+2])
    end

    # Update total distance
    if idx_dropoff == idx_pickup
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id,vehicleSchedule.route[idx_pickup+3].activity.id])/1000
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicleSchedule.route[idx_pickup+3].activity.id])/1000
    else
        # PickUp
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id,vehicleSchedule.route[idx_pickup+2].activity.id])/1000
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,vehicleSchedule.route[idx_pickup+2].activity.id])/1000
        # DropOff
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idx_dropoff].activity.id,vehicleSchedule.route[idx_dropoff+2].activity.id])/1000
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idx_dropoff].activity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicleSchedule.route[idx_dropoff+2].activity.id])/1000
    end

    # Update total time
    if idx_dropoff == idx_pickup
        vehicleSchedule.totalTime -= (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id, vehicleSchedule.route[idx_pickup+3].activity.id]) / 1000
        vehicleSchedule.totalTime += (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id, request.pickUpActivity.id] + 
                                    scenario.distance[request.pickUpActivity.id, request.dropOffActivity.id] + 
                                    scenario.distance[request.dropOffActivity.id, vehicleSchedule.route[idx_pickup+3].activity.id]) / 1000
    else
        # PickUp
        vehicleSchedule.totalTime -= (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id, vehicleSchedule.route[idx_pickup+2].activity.id]) / 1000
        vehicleSchedule.totalTime += (scenario.distance[vehicleSchedule.route[idx_pickup].activity.id, request.pickUpActivity.id] + 
                                    scenario.distance[request.pickUpActivity.id, vehicleSchedule.route[idx_pickup+2].activity.id]) / 1000
        # DropOff
        vehicleSchedule.totalTime -= (scenario.distance[vehicleSchedule.route[idx_dropoff].activity.id, vehicleSchedule.route[idx_dropoff+2].activity.id]) / 1000
        vehicleSchedule.totalTime += (scenario.distance[vehicleSchedule.route[idx_dropoff].activity.id, request.dropOffActivity.id] + 
                                    scenario.distance[request.dropOffActivity.id, vehicleSchedule.route[idx_dropoff+2].activity.id]) / 1000
    end

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario, vehicleSchedule.totalTime)

    return vehicleSchedule
end

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
        idx_pickup, idx_dropoff = -1, -1
        vehicle = -1
        closestDepot = -1
        
        
        # Determine closest feasible depot
        while !feasible && !getTaxi
            closestDepot = getClosestDepot(request,triedDepots,scenario)
            for vehicleIdx in scenario.depots[closestDepot]
                vehicle = vehicleIdx
                println(vehicle)
                println(triedDepots)
                feasible, idx_pickup, idx_dropoff, typeOfSeat = feasibilityInsertion(request,solution.vehicleSchedules[vehicle],scenario)
                if !feasible
                    push!(triedDepots, closestDepot)
                end
            end
            getTaxi = length(triedDepots) == scenario.nDepots
        end

        # Insert request
        if feasible
            solution.vehicleSchedules[vehicle] = insertRequest(request,solution.vehicleSchedules[vehicle],idx_pickup,idx_dropoff,typeOfSeat,scenario)
        else
            solution.nTaxi += getTaxi
        end

    end

    # Update solution
    solution.totalCost = 0
    solution.totalDistance = 0
    for schedule in solution.vehicleSchedules
        solution.totalCost += Int(round(schedule.totalCost))
        solution.totalDistance += Int(round(schedule.totalDistance))
    end

    return solution
    
end



end