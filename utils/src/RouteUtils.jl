module RouteUtils 

using UnPack, domain 

export printRoute,insertRequest!

#==
 Method to print vehicle schedule 
==#
function printRoute(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Active Time Window: ", "(",schedule.activeTimeWindow.startTime, ",", schedule.activeTimeWindow.endTime,")")
    println("Total Distance: ", schedule.totalDistance, " km")
    println("Total Cost: \$", schedule.totalCost)
    println("Passengers (Walking/Wheelchair): ", schedule.nWalking, "/", schedule.nWheelchair)
    println("\nRoute:")
    
    for (i, assignment) in enumerate(schedule.route)
        println("  Step ", i, ":")
        println("    Activity Type: ", assignment.activity.activityType)
        println("    Location: ", assignment.activity.location.name, " (",assignment.activity.location.lat, ",",assignment.activity.location.long,")")
        println("    Start/end of service: ","(", assignment.startOfServiceTime, ",", assignment.endOfServiceTime,")")
        println("    Time Window: ", "(",assignment.activity.timeWindow.startTime, ",", assignment.activity.timeWindow.endTime,")")
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

    # TODO Update activeTimeWindow + totalDistance
    # TODO Update vehicle
end


#==
 Method to check feasibility of route  
==#
function checkRouteFeasibility(scenario::Scenario,vehicleSchedule::VehicleSchedule)
    @unpack vehicle, route, activeTimeWindow, totalDistance, totalCost, numberOfWalking, numberOfWheelchair = vehicleSchedule
    nActivities = length(route)

    # Check vehicle capacities


    # Check available time window
    
    # Check maximum route duration 
        # Check that active time window matches and is correct 

    # Check total distance

    # Check cost 

    # Check activity assignments 
        # Check that vehicle is compatible with request 
        # Check that time windows are respected
        # Check that service times are correct
        # Check that pickup is before dropoff
        # Check that capacities are respected
        # Check maximum ride time 

    totalDistanceCheck = 0.0
    totalDurationCheck = 0.0 
    hasPickUpBeenServiced = Set{Int}()
    for (idx,activityAssignment) in enumerate(route) 
        @unpack activity, startOfServiceTime, endOfServiceTime = activityAssignment

        # Check vehicle compatibility with the request
        if activity.mobilityType == WHEELCHAIR && vehicle.capacities[WHEELCHAIR] == 0
            error("ROUTE INFEASIBLE: Activity $(activity.id) is not compatible with vehicle $(vehicle.id)")
            return false
        end

        # Ensure pickup is visited before drop-off
        if activity.activityType == PICKUP
            push!(pickupServiced,activity.requestId)
        elseif activity.activityType == DROPOFF
            if !haskey(pickupServiced, activity.requestId) || !(pickupServicedactivity.requestId in pickupServiced)
                error("ROUTE INFEASIBLE: Drop-off $(activity.id) before pick-up, vehicle: $(vehicle.id)")
                return false
            end
        end


        # Check that time windows are respected
        if startOfServiceTime < activity.timeWindow.startTime || endOfServiceTime > activity.timeWindow.endTime
            error("ROUTE INFEASIBLE: Time window not respected for activity $(activity.id) on vehicle $(vehicle.id). 
                   Start/End of Service: ($startOfServiceTime, $endOfServiceTime), 
                   Expected Time Window: ($(activity.timeWindow.startTime), $(activity.timeWindow.endTime))")
        end



    end



    return true
    
end


end