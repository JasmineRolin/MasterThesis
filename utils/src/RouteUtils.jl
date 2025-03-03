module RouteUtils 

using UnPack, domain, Printf, ..CostCalculator

export printRoute,printSimpleRoute,insertRequest!,checkFeasibilityOfInsertionAtPosition,printRouteHorizontal,printSolution,updateRoute!


#==
# Method to print solution 
==#
function printSolution(solution::Solution,printRouteFunc::Function)
    println("Solution")
    println("Total Distance: ", solution.totalDistance, " km")
    println("Total time: ", solution.totalRideTime, " min")
    println("Total Cost: \$", solution.totalCost)
    println("Total Idle time: \$", solution.idleTime)

    for schedule in solution.vehicleSchedules
        printRouteFunc(schedule)
    end
end

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

function printRouteHorizontal(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Available Time Window: ($(schedule.vehicle.availableTimeWindow.startTime), $(schedule.vehicle.availableTimeWindow.endTime)), Active Time Window: ($(schedule.activeTimeWindow.startTime), $(schedule.activeTimeWindow.endTime))")
    println("Total Distance: $(schedule.totalDistance) km, Total Time: $(schedule.totalTime) min, Total Cost: \$$(schedule.totalCost)")
    
    println("------------------------------------------------------------------------------------------------------------")
    println("| Step | Mobility Type | Activity Type |  Id |  Location  | Start/End Service | Time Window | (Walking, Wheelchair) |")
    println("------------------------------------------------------------------------------------------------------------")

    for (i, assignment) in enumerate(schedule.route)
        start_service = assignment.startOfServiceTime
        end_service = assignment.endOfServiceTime
        activity = assignment.activity
        location = activity.location
        time_window = activity.timeWindow
        
        # Extract load details safely
        walking_load = i <= length(schedule.numberOfWalking) ? schedule.numberOfWalking[i] : "N/A"
        wheelchair_load = i <= length(schedule.numberOfWheelchair) ? schedule.numberOfWheelchair[i] : "N/A"
        
        # Print each route step in a single horizontal line
        @printf("| %-4d | %-13s | %-13s | %-4d| %-10s | (%5d, %5d) | (%5d, %5d) | (%3s, %3s) |\n",
                i,
                activity.mobilityType,
                activity.activityType,
                activity.id,
                location.name, 
                start_service, end_service,
                time_window.startTime, time_window.endTime,
                walking_load, wheelchair_load)
    end
    println("------------------------------------------------------------------------------------------------------------\n")
end


function printSimpleRoute(schedule::VehicleSchedule)
    print("Route ",schedule.vehicle.id,": ")
    
    route_ids = [assignment.activity.location.name for assignment in schedule.route]
    
    println(join(route_ids, " -> "))
end


# ----------
# Function to insert a request in a vehicle schedule
# ----------
# idxPickUp: index of link where pickup should be inserted 
# idxDropOff: index of link where dropoff should be inserted 
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType,scenario::Scenario)

    # Update route
    updateRoute!(scenario.time,scenario.serviceTimes,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff,typeOfSeat)

    # Update waiting
    updatedIdxPickUp, updatedIdxDropOff = updateWaiting!(scenario.time,vehicleSchedule,idxPickUp,idxDropOff)

    # Update depots
    updateDepots!(scenario.time,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update total distance
    updateDistance!(scenario.distance,vehicleSchedule,request,updatedIdxDropOff,updatedIdxPickUp)

    # Update total time 
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario, vehicleSchedule.route)
end


#==
Method to update route in vehicle schedule after insertion of request. Will do it so minimize excess drive time and secondly as early as possible
==#
function updateRoute!(time::Array{Int,2},serviceTimes::Dict{MobilityType,Int},vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)

    route = vehicleSchedule.route

    # Get time when cend of service is for node before pick up
    if route[idxPickUp].activity.activityType == WAITING || route[idxPickUp].activity.activityType == DEPOT
        endOfServiceBeforePick = route[idxPickUp].activity.timeWindow.startTime
    else
        endOfServiceBeforePick = route[idxPickUp].endOfServiceTime
    end

    # Get time when cend of service is for node before drop off
    if route[idxDropOff].activity.activityType == WAITING || route[idxDropOff].activity.activityType == DEPOT
        endOfServiceBeforeDrop = route[idxDropOff].activity.timeWindow.startTime
    else
        endOfServiceBeforeDrop = route[idxDropOff].endOfServiceTime
    end

    # Get time when arriving at node after pick up
    startOfServiceAfterPick = route[idxPickUp+1].startOfServiceTime

    # Get time when arriving at node after drop off
    startOfServiceAfterDrop = route[idxDropOff+1].startOfServiceTime


    #Get available service time windows
    earliestStartOfServicePickUp = max(endOfServiceBeforePick + time[route[idxPickUp].activity.id,request.pickUpActivity.id],request.pickUpActivity.timeWindow.startTime)
    latestStartOfServicePickUp = min(startOfServiceAfterPick - time[route[idxPickUp].activity.id,route[idxPickUp+1].activity.id] - serviceTimes[request.pickUpActivity.mobilityType],request.pickUpActivity.timeWindow.endTime)
    earliestStartOfServiceDropOff = max(endOfServiceBeforeDrop + time[route[idxDropOff].activity.id,request.dropOffActivity.id],request.dropOffActivity.timeWindow.startTime)
    latestStartOfServiceDropOff = min(startOfServiceAfterDrop - time[route[idxDropOff].activity.id,route[idxDropOff+1].activity.id] - serviceTimes[request.dropOffActivity.mobilityType],request.dropOffActivity.timeWindow.endTime)

    # Get available service time window for pick up considering minimized excess drive time
    earliestStartOfServicePickUpMinimization = earliestStartOfServiceDropOff - max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes[request.pickUpActivity.mobilityType])
    latestStartOfServicePickUpMinimization = min(latestStartOfServicePickUp,latestStartOfServiceDropOff-max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes[request.pickUpActivity.mobilityType]))

    # Choose the best time for pick up (Here the latest time is chosen)
    startOfServicePick = latestStartOfServicePickUpMinimization

    # Determine the time for drop off
    startOfServiceDrop = startOfServicePick + max(earliestStartOfServiceDropOff - startOfServicePick, time[request.pickUpActivity.id,request.dropOffActivity.id]+serviceTimes[request.pickUpActivity.mobilityType])

    # Insert request
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick + serviceTimes[request.pickUpActivity.mobilityType])
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop + serviceTimes[request.dropOffActivity.mobilityType])
    insert!(vehicleSchedule.route,idxPickUp+1,pickUpActivity)
    insert!(vehicleSchedule.route,idxDropOff+2,dropOffActivity)

end


#==
# Method to update capacities of vehicle schedule after insertion of request
==#
function updateCapacities!(vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType)
     # Update capacities
     if typeOfSeat == WHEELCHAIR
        # Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWheelchair[i] = vehicleSchedule.numberOfWheelchair[i] + 1
        end

        #Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp])
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff+2])

    else
        # Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp]+1)
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff])
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
        end

        #Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,vehicleSchedule.numberOfWheelchair[idxPickUp])
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,vehicleSchedule.numberOfWheelchair[idxDropOff+2])
    end
end


#== 
Insert waiting before node with index idx
==#
function insertWaitingBeforeNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)
    route = vehicleSchedule.route
    # Insert before node
    if route[idx-1].endOfServiceTime + time[route[idx-1].activity.id,route[idx].activity.id] < route[idx].startOfServiceTime
        startOfServiceWaiting = route[idx-1].endOfServiceTime 
        endOfServiceWaiting = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
        waitingActivity = ActivityAssignment(Activity(route[idx-1].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx,vehicleSchedule.numberOfWalking[idx-1])
        insert!(vehicleSchedule.numberOfWheelchair,idx,vehicleSchedule.numberOfWheelchair[idx-1])
        return 1
    end
    return 0
end


#== 
Insert waiting after node with index idx
==#
function insertWaitingAfterNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)
    route = vehicleSchedule.route
    # Insert after node
    if route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id] < route[idx+1].startOfServiceTime
        startOfServiceWaiting = route[idx].endOfServiceTime 
        endOfServiceWaiting = route[idx+1].startOfServiceTime - time[route[idx].activity.id,route[idx+1].activity.id]
        waitingActivity = ActivityAssignment(Activity(route[idx].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx+1,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx+1,vehicleSchedule.numberOfWalking[idx])
        insert!(vehicleSchedule.numberOfWheelchair,idx+1,vehicleSchedule.numberOfWheelchair[idx])
        return 1
    end
    return 0
end


#==
Update waiting after node
==#
function updateWaitingAfterNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route
    if route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+2].activity.id] < route[idx+2].startOfServiceTime
        # Update waiting after node
        route[idx+1].startOfServiceTime = route[idx].endOfServiceTime
        route[idx+1].activity.timeWindow.startTime = route[idx].endOfServiceTime
    else
        # Remove waiting after node
        deleteat!(route,idx+1)
    end
end

#==
Update waiting before node
==#
function updateWaitingBeforeNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route
    if route[idx-2].endOfServiceTime + time[route[idx-2].activity.id,route[idx].activity.id] < route[idx].startOfServiceTime
        # Update waiting before node
        route[idx-1].endOfServiceTime = route[idx].startOfServiceTime
        route[idx-1].activity.timeWindow.endTime = route[idx].startOfServiceTime
    else
        # Remove waiting before node
        deleteat!(route,idx-1)
    end
end


#== 
Update or insert Waiting nodes 
==#
function updateWaiting!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int)
    route = vehicleSchedule.route
    updatedIdxDropOff = idxDropOff+2
    updatedIdxPickUp = idxPickUp+1

    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
        return updatedIdxPickUp, updatedIdxDropOff
    elseif idxPickUp == 1 && idxPickUp == idxDropOff
        # After drop-off
        if route[idxPickUp+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        end
        # Potentially after pick up
        inserted = insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        updatedIdxDropOff += inserted
    elseif idxPickUp == idxDropOff
        # After drop-off
        if route[idxPickUp+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+2)
        end
        # Before pick up
        if route[idxPickUp].activity.activityType != WAITING
            inserted = insertWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # Potentially after pick up
        inserted = insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        updatedIdxDropOff += inserted
        
    elseif idxPickUp == 1
        # After pick up
        if route[idxPickUp+2].activity.activityType != WAITING
            inserted = insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
            updatedIdxDropOff += inserted
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # Before drop-off
        if route[idxDropOff+1].activity.activityType != WAITING
            inserted = insertWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
            updatedIdxDropOff += inserted
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        end
        # After drop-off
        if route[idxDropOff+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        end
    else
        # Before pick up
        if route[idxPickUp].activity.activityType != WAITING
            inserted = insertWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # After pick up
        if route[idxPickUp+2].activity.activityType != WAITING
            inserted = insertWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
            updatedIdxDropOff += inserted
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxPickUp+1)
        end
        # Before drop-off
        if route[idxDropOff+1].activity.activityType != WAITING
            inserted = insertWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
            updatedIdxDropOff += inserted
        else
            updateWaitingBeforeNode!(time,vehicleSchedule,idxDropOff+2)
        end
        # After drop-off
        if route[idxDropOff+3].activity.activityType != WAITING
            insertWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        else
            updateWaitingAfterNode!(time,vehicleSchedule,idxDropOff+2)
        end
    end

    return updatedIdxPickUp, updatedIdxDropOff

end

#==
# Method to update depots in vehicle schedule after insertion of request
==#
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)
    
    # Update active time windows
    route = vehicleSchedule.route
    if idxPickUp == 1
        
        newActiveTimeWindowStart = route[2].startOfServiceTime - time[route[1].activity.id,route[2].activity.id]

        vehicleSchedule.activeTimeWindow.startTime = newActiveTimeWindowStart
        route[1].activity.timeWindow.endTime =  newActiveTimeWindowStart
        route[1].startOfServiceTime = newActiveTimeWindowStart
        route[1].endOfServiceTime = newActiveTimeWindowStart
    end
    if (route[end-1].activity.activityType == WAITING && route[end-2].activity == request.dropOffActivity)||(route[end-1].activity == request.dropOffActivity)
        route = vehicleSchedule.route
        newActiveTimeWindowEnd = route[end-1].endOfServiceTime + time[route[end-1].activity.id,route[end].activity.id]

        vehicleSchedule.activeTimeWindow.endTime = newActiveTimeWindowEnd
        route[end].activity.timeWindow.startTime = newActiveTimeWindowEnd
        route[end].startOfServiceTime = newActiveTimeWindowEnd
        route[end].endOfServiceTime = newActiveTimeWindowEnd
    end
end


#==
# Method to update total distance of vehicle schedule after insertion of request
==#
function updateDistance!(distance::Array{Float64,2},vehicleSchedule::VehicleSchedule,request::Request,idxDropOff::Int,idxPickUp)
    
    route = vehicleSchedule.route 

    # Update total distance
    if idxDropOff-1 == idxPickUp

        if route[idxPickUp+2].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        end        
    elseif (idxDropOff-2 == idxPickUp) && route[idxPickUp+1].activity.activityType == WAITING
        if route[idxPickUp+3].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+4].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxPickUp+3].activity.id])
        end
    else
        # PickUp
        if route[idxPickUp+1].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+2].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxPickUp-1].activity.id,vehicleSchedule.route[idxPickUp+1].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxPickUp-1].activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,vehicleSchedule.route[idxPickUp+1].activity.id])
        end

        # DropOff
        if route[idxDropOff+1].activity.activityType == WAITING
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxDropOff-1].activity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxDropOff-1].activity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+2].activity.id])
        else
            vehicleSchedule.totalDistance -= (distance[vehicleSchedule.route[idxDropOff-1].activity.id,vehicleSchedule.route[idxDropOff+1].activity.id])
            vehicleSchedule.totalDistance += (distance[vehicleSchedule.route[idxDropOff-1].activity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,vehicleSchedule.route[idxDropOff+1].activity.id])
        end

    end

end


# ----------
# Function to check feasibility of given placement of a request for in a vehicle schedule 
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)
    typeOfSeat = nothing

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
        route = vehicleSchedule.route

        # Determine arrival times for different cases
        if (idx == 1 && route[1].activity.activityType == DEPOT) || (route[idx].activity.activityType == WAITING)
            earliestStartOfServicePick = vehicleSchedule.route[idx].startOfServiceTime + scenario.time[vehicleSchedule.route[idx].activity.id, request.pickUpActivity.id]
            startOfServicePick = max(earliestStartOfServicePick,request.pickUpActivity.timeWindow.startTime)
            endOfPickUp = startOfServicePick + scenario.serviceTimes[request.pickUpActivity.mobilityType]

            earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
            startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
            endOfDropOff = startOfServiceDrop + scenario.serviceTimes[request.dropOffActivity.mobilityType]
            arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
        else
            return false, typeOfSeat 
        end

        # Check time window
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime || startOfServicePick < request.pickUpActivity.timeWindow.startTime
            println("Infeasible: Time window pick-up")
            return false, typeOfSeat
        elseif startOfServiceDrop > request.dropOffActivity.timeWindow.endTime || startOfServiceDrop < request.dropOffActivity.timeWindow.startTime
            println("Infeasible: Time window drop-off")
            return false, typeOfSeat
        end
        
        # Check drive time: First node
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime
            println("Infeasible: Drive time from first node")
            return false, typeOfSeat
        end
        
        # Check drive time:Next node
        if idx == length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
            println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        elseif idx < length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        end


    else
        route = vehicleSchedule.route
        for activity in [request.pickUpActivity, request.dropOffActivity]
            
            if activity == request.pickUpActivity
                idx = pickUpIdx
            else
                idx = dropOffIdx
            end

            # Determine arrival times for different cases
            if (idx == 1 && route[1].activity.activityType == DEPOT) || (route[idx].activity.activityType == WAITING)
                earliestStartOfServiceActivity = route[idx].startOfServiceTime + scenario.time[route[idx].activity.id, activity.id]
                startOfServiceActivity = max(earliestStartOfServiceActivity,activity.timeWindow.startTime)
                endOfActivity = startOfServiceActivity + scenario.serviceTimes[activity.mobilityType]
                arrivalNextNode = endOfActivity + scenario.time[request.dropOffActivity.id, route[idx+1].activity.id]
            else
                return false, typeOfSeat 
            end

            # Check time window
            if startOfServiceActivity > activity.timeWindow.endTime || startOfServiceActivity < activity.timeWindow.startTime
                println("Infeasible: Time window")
                return false, typeOfSeat
            end

            # Check drive time: First node
            if startOfServiceActivity > activity.timeWindow.endTime
                println("Infeasible: Drive time from first node")
                return false, typeOfSeat
            end
            
            # Check drive time:Next node
            if idx == length(route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
                println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            elseif idx < length(route)-1 && arrivalNextNode > route[idx+1].startOfServiceTime
                println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            end
    
        end
    end

    
        
    # If all checks pass, the activity is feasible
    println("FEASIBLE")
    return true, typeOfSeat
end




end