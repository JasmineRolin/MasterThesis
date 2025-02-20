module RouteUtils 

using UnPack, domain, ..CostCalculator

export printRoute,insertRequest!,checkRouteFeasibility,checkFeasibilityOfInsertionAtPosition

#==
 Method to print vehicle schedule 
==#
function printRoute(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Active Time Window: ", "(",schedule.activeTimeWindow.startTime, ",", schedule.activeTimeWindow.endTime,")")
    println("Total Distance: ", schedule.totalDistance, " km")
    println("Total time: ", schedule.totalTime, " min")
    println("Total Cost: \$", schedule.totalCost)
    println("Wheelchair capacities: ", schedule.numberOfWheelchair)
    println("Walking capacities: ", schedule.numberOfWalking)
    println("\nRoute:")
    
    for (i, assignment) in enumerate(schedule.route)
        println("  Step ", i, ":")
        println("    Mobility Type: ", assignment.activity.mobilityType)
        println("    Activity Type: ", assignment.activity.activityType)
        println("    Location: ", assignment.activity.location.name, " (",assignment.activity.location.lat, ",",assignment.activity.location.long,")")
        println("    Start/end of service: ","(", assignment.startOfServiceTime, ",", assignment.endOfServiceTime,")")
        println("    Time Window: ", "(",assignment.activity.timeWindow.startTime, ",", assignment.activity.timeWindow.endTime,")")
        println("    Load: (", schedule.numberOfWalking[i], ",", schedule.numberOfWheelchair[i],")")
    end
    println("\n--------------------------------------")
end

# ----------
# Function to insert a request in a vehicle schedule
# ----------
# idxPickUp: index of link where pickup should be inserted 
# idxDropOff: index of link where dropoff should be inserted 
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType,scenario::Scenario)

    # Update routes
    if idxPickUp == idxDropOff
        earliestStartOfServicePick = vehicleSchedule.route[idxPickUp].endOfServiceTime + scenario.time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
        earliestStartOfServiceDrop = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType] + scenario.time[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    else
        earliestStartOfServicePick = vehicleSchedule.route[idxPickUp].endOfServiceTime + scenario.time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] 
        startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
        earliestStartOfServiceDrop = vehicleSchedule.route[idxDropOff].endOfServiceTime + scenario.time[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] 
        startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
    end

    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick+scenario.serviceTimes[request.pickUpActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idxPickUp+1,pickUpActivity)
    insert!(vehicleSchedule.route,idxDropOff+2,dropOffActivity)

    # Update active time windows
    if idxPickUp == 1
        vehicleSchedule.activeTimeWindow.startTime = startOfServicePick - scenario.time[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id]
        vehicleSchedule.route[1].startOfServiceTime = vehicleSchedule.activeTimeWindow.startTime
        vehicleSchedule.route[1].endOfServiceTime = vehicleSchedule.activeTimeWindow.startTime
    end
    if idxDropOff == length(vehicleSchedule.route)-3 
        vehicleSchedule.activeTimeWindow.endTime = startOfServiceDrop + scenario.time[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+3].activity.id] + scenario.serviceTimes[request.dropOffActivity.mobilityType]
        vehicleSchedule.route[end].startOfServiceTime = vehicleSchedule.activeTimeWindow.endTime
        vehicleSchedule.route[end].endOfServiceTime = vehicleSchedule.activeTimeWindow.endTime
    end

    # Update capacities
    if typeOfSeat == WHEELCHAIR
        # Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff+2])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWheelchair[i] = vehicleSchedule.numberOfWheelchair[i] + 1
        end

        #Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp])
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff+2])

    else
        # Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff+2])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
        end

        #Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp])
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff+2])
    end

    # Update total distance
    if idxDropOff == idxPickUp
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
    else
        # PickUp
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idxPickUp].activity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idxPickUp].activity.id,request.pickUpActivity.id] + scenario.distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        # DropOff
        vehicleSchedule.totalDistance -= (scenario.distance[vehicleSchedule.route[idxDropOff].activity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
        vehicleSchedule.totalDistance += (scenario.distance[vehicleSchedule.route[idxDropOff].activity.id,request.dropOffActivity.id] + scenario.distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
    end

    # Update total time
    if idxDropOff == idxPickUp
        # Remove time between previous consecutive customers 
        vehicleSchedule.totalTime -= vehicleSchedule.route[idxPickUp+3].startOfServiceTime - vehicleSchedule.route[idxPickUp].endOfServiceTime

        # Add time between new consecutive customers
        vehicleSchedule.totalTime += (vehicleSchedule.route[idxPickUp+1].endOfServiceTime - vehicleSchedule.route[idxPickUp].endOfServiceTime)
                                     + (vehicleSchedule.route[idxPickUp+1].endOfServiceTime - vehicleSchedule.route[idxPickUp+2].endOfServiceTime)
                                     + (vehicleSchedule.route[idxPickUp+2].endOfServiceTime - vehicleSchedule.route[idxPickUp+3].startOfServiceTime)
    else
        # Remove time between previous consecutive customers 
        vehicleSchedule.totalTime -= vehicleSchedule.route[idxPickUp+2].startOfServiceTime - vehicleSchedule.route[idxPickUp].endOfServiceTime
        vehicleSchedule.totalTime -= vehicleSchedule.route[idxDropOff+2].startOfServiceTime - vehicleSchedule.route[idxDropOff].endOfServiceTime

        
        # Add time between new consecutive customers
        vehicleSchedule.totalTime += (vehicleSchedule.route[idxPickUp+1].endOfServiceTime - vehicleSchedule.route[idxPickUp].endOfServiceTime)
                                     + (vehicleSchedule.route[idxPickUp+2].endOfServiceTime - vehicleSchedule.route[idxPickUp+1].startOfServiceTime)
        vehicleSchedule.totalTime += (vehicleSchedule.route[idxDropOff+1].endOfServiceTime - vehicleSchedule.route[idxDropOff].endOfServiceTime)
                                     + (vehicleSchedule.route[idxDropOff+2].endOfServiceTime - vehicleSchedule.route[idxDropOff+1].startOfServiceTime)
    end

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario, vehicleSchedule.totalTime)
end


# ----------
# Function to check feasibility of given placement of a request for in a vehicle schedule 
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    typeOfSeat = nothing

    # Determine ride time
    updatedRideTime = vehicleSchedule.activeTimeWindow.endTime - vehicleSchedule.activeTimeWindow.startTime

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

    # Check if insertion is feasible 
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

    
        
    # If all checks pass, the activity is feasible
    println("FEASIBLE")
    return true, typeOfSeat
end


#==
 Method to check feasibility of route  
==#
function checkRouteFeasibility(scenario::Scenario,vehicleSchedule::VehicleSchedule)
    @unpack vehicle, route, activeTimeWindow, totalDistance, totalCost,totalTime, numberOfWalking, numberOfWheelchair = vehicleSchedule
    @unpack requests, distance, time, serviceTimes, vehicleCostPrHour,vehicleStartUpCost  = scenario
    nRequests = length(requests)

    if length(route) == 2
        return true, "", Set{Int}()
    end

    # Check that active time window of vehicle is correct 
    if activeTimeWindow.startTime != route[1].startOfServiceTime || activeTimeWindow.endTime != route[end].endOfServiceTime
        msg = "ROUTE INFEASIBLE: Active time window of vehicle $(vehicle.id) is incorrect"
        return false, msg, Set{Int}()
    end

    # Check available time window of vehicle 
    if activeTimeWindow.startTime < vehicle.availableTimeWindow.startTime || activeTimeWindow.endTime > vehicle.availableTimeWindow.endTime
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) is not available during the route"
        return false, msg, Set{Int}() 
    end
    
    # Check maximum route duration 
    durationActiveTimeWindow = duration(activeTimeWindow)
    if durationActiveTimeWindow > vehicle.maximumRideTime 
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) exceeds maximum ride time"
        return false, msg, Set{Int}()
    end

    # Check cost and total time 
    if totalTime != durationActiveTimeWindow
        msg = "ROUTE INFEASIBLE: Total time is incorrect for vehicle $(vehicle.id). Calculated time $(durationActiveTimeWindow), actual time $(totalTime)"
        return false, msg, Set{Int}()
    end
    if totalCost != vehicleCostPrHour * totalTime + vehicleStartUpCost
        msg = "ROUTE INFEASIBLE: Total cost is incorrect for vehicle $(vehicle.id). Calculated cost $(vehicleCostPrHour * totalTime + vehicleStartUpCost), actual cost $(totalCost)"
        return false, msg, Set{Int}()
    end
    
    
    # Check all activities on route 
    totalDistanceCheck = 0.0
    currentCapacities = Dict{MobilityType,Int}(WALKING => 0, WHEELCHAIR => 0)
    hasBeenServiced = Set{Int}() # TODO: Check if this still works with waiting activities
    endOfServiceTimePickUps = Dict{Int,Int}() # Keep track of end of service time for pick-ups
    for (idx,activityAssignment) in zip(2:length(route)-1, route[2:end-1]) # Do not check depots
        @unpack activity, startOfServiceTime, endOfServiceTime = activityAssignment

        # Check vehicle compatibility with the request
        if activity.mobilityType == WHEELCHAIR && vehicle.capacities[WHEELCHAIR] == 0
            msg = "ROUTE INFEASIBLE: Activity $(activity.id) is not compatible with vehicle $(vehicle.id)"
            return false, msg, Set{Int}()
        end

        # Check that activity is not visited more than once
        if activity.id in hasBeenServiced
            msg = "ROUTE INFEASIBLE: Activity $(activity.id) visited more than once on vehicle $(vehicle.id)"
            return false, msg, Set{Int}()
        else
            push!(hasBeenServiced,activity.id)
        end
        
        # Check that pickup is serviced before drop-off and that maximum ride time is satisfied 
        if activity.activityType == PICKUP
            endOfServiceTimePickUps[activity.id] = endOfServiceTime
        elseif activity.activityType == DROPOFF 
            pickUpId = findCorrespondingId(activity,nRequests)
            if !(pickUpId in hasBeenServiced)
                msg = "ROUTE INFEASIBLE: Drop-off $(activity.id) before pick-up, vehicle: $(vehicle.id)"
                return false, msg, Set{Int}()
            end

            rideTime = endOfServiceTime - endOfServiceTimePickUps[pickUpId]
            if rideTime > requests[activity.requestId].maximumRideTime || rideTime < requests[activity.requestId].directDriveTime
                msg = "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off $(activity.id) on vehicle $(vehicle.id)"
                return false, msg, Set{Int}()
            end

        end


        # Check that time windows are respected
        if startOfServiceTime < activity.timeWindow.startTime || endOfServiceTime > activity.timeWindow.endTime
            msg = "ROUTE INFEASIBLE: Time window not respected for activity $(activity.id) on vehicle $(vehicle.id), Start/End of Service: ($startOfServiceTime, $endOfServiceTime), Time Window: ($(activity.timeWindow.startTime), $(activity.timeWindow.endTime))"
            return false, msg, Set{Int}()
        end

        # Check that start of service and end of service are feasible 
        if startOfServiceTime < route[idx-1].endOfServiceTime + time[route[idx-1].activity.id,activity.id]
            msg = "ROUTE INFEASIBLE: Start of service time $(startOfServiceTime) of activity $(activity.id) is not correct"
            return false, msg, Set{Int}()
        end
        if endOfServiceTime != startOfServiceTime + serviceTimes[activity.mobilityType]
            msg = "ROUTE INFEASIBLE: End of service time $(endOfServiceTime) of activity $(activity.id) is not correct"
            return false, msg, Set{Int}()
        end

        # Update and check current capacities
        if activity.mobilityType == WHEELCHAIR
            currentCapacities[WHEELCHAIR] += findLoadOfActivity(activity)

            if currentCapacities[WHEELCHAIR] > vehicle.capacities[WHEELCHAIR] || currentCapacities[WHEELCHAIR] < 0
                msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                return false, msg, Set{Int}()
            end
        else
            # Walking customers can take wheelchair space if no walking space is available
            if currentCapacities[WALKING] == vehicle.capacities[WALKING] 
                currentCapacities[WHEELCHAIR] += findLoadOfActivity(activity)
            else
                currentCapacities[WALKING] += findLoadOfActivity(activity)
            end

            if currentCapacities[WHEELCHAIR] > vehicle.capacities[WHEELCHAIR] || currentCapacities[WHEELCHAIR] < 0 || currentCapacities[WALKING] > vehicle.capacities[WALKING] || currentCapacities[WALKING] < 0
                msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                return false, msg, Set{Int}() 
            end

        end

        if currentCapacities[WHEELCHAIR] != numberOfWheelchair[idx] || currentCapacities[WALKING] != numberOfWalking[idx]
            msg = "ROUTE INFEASIBLE: Capacities not updated correctly for vehicle $(vehicle.id)"
            return false, msg, Set{Int}() 
        end
        
        # Keep track of total distance and total time 
        totalDistanceCheck += distance[route[idx-1].activity.id,activity.id]
    end

    # Add end depot to total distance 
    totalDistanceCheck += distance[route[end-1].activity.id,route[end].activity.id]

    # Check that total distance is correct
    if totalDistanceCheck != totalDistance
        msg = "ROUTE INFEASIBLE: Total distance $(totalDistance) is incorrect"
        return false, msg, Set{Int}() 
    end
    
   
    return true, "", hasBeenServiced
    
end


end