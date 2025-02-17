module RouteUtils 

using UnPack, domain 

export printRoute,insertRequest!,checkRouteFeasibility

#==
 Method to print vehicle schedule 
==#
function printRoute(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Active Time Window: ", "(",schedule.activeTimeWindow.startTime, ",", schedule.activeTimeWindow.endTime,")")
    println("Total Distance: ", schedule.totalDistance, " km")
    println("Total Cost: \$", schedule.totalCost)
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

#==
 Method to insert request in VehicleSchedule
==#
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idx_pickup::Int,idx_dropoff::Int,scenario::Scenario)
    nRequests = length(scenario.requests)

    ### Update Vehicle Schedule
    # Update route
    startOfServicePick = vehicleSchedule.route[idx_pickup].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_pickup].activity.id,request.pickUpActivity.id] 
    startOfServiceDrop = vehicleSchedule.route[idx_dropoff].endOfServiceTime + scenario.time[vehicleSchedule.route[idx_dropoff].activity.id,request.dropOffActivity.id] 
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop+scenario.serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idx_pickup,pickUpActivity)
    insert!(vehicleSchedule.route,idx_dropoff+1,dropOffActivity)

    append!(vehicleSchedule.numberOfWalking,[0,0])
    append!(vehicleSchedule.numberOfWheelchair,[0,0])

    # TODO Update activeTimeWindow + totalDistance
    # TODO Update vehicle
end


#==
 Method to check feasibility of route  
==#
function checkRouteFeasibility(scenario::Scenario,vehicleSchedule::VehicleSchedule)
    @unpack vehicle, route, activeTimeWindow, totalDistance, totalCost, numberOfWalking, numberOfWheelchair = vehicleSchedule
    nRequests = length(scenario.requests)

    # Check that active time window of vehicle is correct 
    if activeTimeWindow.startTime != route[1].startOfServiceTime || activeTimeWindow.endTime != route[end].endOfServiceTime
        msg = "ROUTE INFEASIBLE: Active time window of vehicle $(vehicle.id) is incorrect"
        return false, msg
    end

    # Check available time window of vehicle 
    if activeTimeWindow.startTime < vehicle.availableTimeWindow.startTime || activeTimeWindow.endTime > vehicle.availableTimeWindow.endTime
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) is not available during the route"
        return false, msg 
    end
    
    # Check maximum route duration 
    if activeTimeWindow.endTime - activeTimeWindow.startTime > vehicle.maximumRideTime
        msg = "ROUTE INFEASIBLE: Vehicle $(vehicle.id) exceeds maximum ride time"
        return false, msg
    end
    
    # Check all activities on route 
    totalDistanceCheck = 0.0
    currentCapacities = Dict{MobilityType,Int}(WALKING => 0, WHEELCHAIR => 0)
    hasBeenServiced = Set{Int}()
    endOfServiceTimePickUps = Dict{Int,Int}() # Keep track of end of service time for pick-ups
    for (idx,activityAssignment) in zip(2:length(route)-1, route[2:end-1]) # Do not check depots
        @unpack activity, startOfServiceTime, endOfServiceTime = activityAssignment

        # Check vehicle compatibility with the request
        if activity.mobilityType == WHEELCHAIR && vehicle.capacities[WHEELCHAIR] == 0
            msg = "ROUTE INFEASIBLE: Activity $(activity.id) is not compatible with vehicle $(vehicle.id)"
            return false, msg
        end

        # Check that activity is not visited more than once
        if activity.id in hasBeenServiced
            msg = "ROUTE INFEASIBLE: Activity $(activity.id) visited more than once on vehicle $(vehicle.id)"
            return false, msg
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
                return false, msg
            end

            rideTime = endOfServiceTime - endOfServiceTimePickUps[pickUpId]
            if rideTime > scenario.requests[activity.requestId].maximumRideTime || rideTime < scenario.requests[activity.requestId].directDriveTime
                msg = "ROUTE INFEASIBLE: Maximum ride time exceeded for drop-off $(activity.id) on vehicle $(vehicle.id)"
                return false, msg
            end

        end


        # Check that time windows are respected
        if startOfServiceTime < activity.timeWindow.startTime || endOfServiceTime > activity.timeWindow.endTime
            msg = "ROUTE INFEASIBLE: Time window not respected for activity $(activity.id) on vehicle $(vehicle.id), Start/End of Service: ($startOfServiceTime, $endOfServiceTime), Time Window: ($(activity.timeWindow.startTime), $(activity.timeWindow.endTime))"
            return false, msg
        end

        # Check that start of service and end of service are feasible 
        if startOfServiceTime < route[idx-1].endOfServiceTime + scenario.time[route[idx-1].activity.id,activity.id]
            msg = "ROUTE INFEASIBLE: Start of service time $(startOfServiceTime) of activity $(activity.id) is not correct"
            return false, msg 
        end
        if endOfServiceTime != startOfServiceTime + scenario.serviceTimes[activity.mobilityType]
            msg = "ROUTE INFEASIBLE: End of service time $(endOfServiceTime) of activity $(activity.id) is not correct"
            return false, msg
        end

        # Update and check current capacities
        if activity.mobilityType == WHEELCHAIR
            currentCapacities[WHEELCHAIR] += findLoadOfActivity(activity)

            if currentCapacities[WHEELCHAIR] > vehicle.capacities[WHEELCHAIR] || currentCapacities[WHEELCHAIR] < 0
                msg = "ROUTE INFEASIBLE: Capacities exceeded for vehicle $(vehicle.id)"
                return false, msg
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
                return false, msg 
            end

        end

        if currentCapacities[WHEELCHAIR] != numberOfWheelchair[idx] || currentCapacities[WALKING] != numberOfWalking[idx]
            msg = "ROUTE INFEASIBLE: Capacities not updated correctly for vehicle $(vehicle.id)"
            return false, msg 
        end
        
        # Keep track of total distance and total time 
        totalDistanceCheck += scenario.distance[route[idx-1].activity.id,activity.id]
    end

    # Add end depot to total distance 
    totalDistanceCheck += scenario.distance[route[end-1].activity.id,route[end].activity.id]

    # Check that total distance is correct
    if totalDistanceCheck != totalDistance
        msg = "ROUTE INFEASIBLE: Total distance $(totalDistance) is incorrect"
        return false, msg 
    end
    
    # TODO: add cost check when we calculate cost 

    return true, ""
    
end


end