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
    println("Total Idle time: \$", solution.totalIdleTime)

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
   
   println("====================================================================================================")
   printRouteHorizontal(vehicleSchedule)

    # Update r  oute
    activityAssignmentBeforePickUp, activityAssignmentAfterPickUp, activityAssignmentBeforeDropOff, activityAssignmentAfterDropOff = updateRoute!(scenario.time,scenario.serviceTimes,vehicleSchedule,request,typeOfSeat,idxPickUp,idxDropOff)

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff,typeOfSeat)

    # Update depots
    updateDepots!(scenario.time,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update waiting
    updatedIdxPickUp, updatedIdxDropOff,  updatedActivityAssignmentBeforePickUp, updatedActivityAssignmentAfterPickUp, updatedActivityAssignmentBeforeDropOff, updatedActivityAssignmentAfterDropOff = updateWaiting!(scenario.time,vehicleSchedule,idxPickUp,idxDropOff)

    # Update total distance
    updateDistance!(scenario,vehicleSchedule,request,updatedIdxDropOff,updatedIdxPickUp,
                    activityAssignmentBeforePickUp, activityAssignmentAfterPickUp, activityAssignmentBeforeDropOff, activityAssignmentAfterDropOff,
                       updatedActivityAssignmentBeforePickUp, updatedActivityAssignmentAfterPickUp, updatedActivityAssignmentBeforeDropOff, updatedActivityAssignmentAfterDropOff)
   
    # Update idle time 
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Update total time 
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario, vehicleSchedule.route)
    println("====================================================================================================")

end


#==
Method to update route in vehicle schedule after insertion of request. Will do it so minimize excess drive time and secondly as late as possible
==#
function updateRoute!(time::Array{Int,2},serviceTimes::Dict{MobilityType,Int},vehicleSchedule::VehicleSchedule,request::Request,typeOfSeat::MobilityType,idxPickUp::Int,idxDropOff::Int)

    route = vehicleSchedule.route

    # Get time when cend of service is for node before pick up
    if route[idxPickUp].activity.activityType == WAITING || route[idxPickUp].activity.activityType == DEPOT
        endOfServiceBeforePick = route[idxPickUp].activity.timeWindow.startTime
    else
        endOfServiceBeforePick = route[idxPickUp].endOfServiceTime
    end

    # Get time when end of service is for node before drop off
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
    latestStartOfServicePickUp = min(startOfServiceAfterPick - time[request.pickUpActivity.id,route[idxPickUp+1].activity.id] - serviceTimes[request.pickUpActivity.mobilityType],request.pickUpActivity.timeWindow.endTime)
    earliestStartOfServiceDropOff = max(endOfServiceBeforeDrop + time[route[idxDropOff].activity.id,request.dropOffActivity.id],request.dropOffActivity.timeWindow.startTime)
    latestStartOfServiceDropOff = min(startOfServiceAfterDrop - time[request.dropOffActivity.id,route[idxDropOff+1].activity.id] - serviceTimes[request.dropOffActivity.mobilityType],request.dropOffActivity.timeWindow.endTime)  

    # Get available service time window for pick up considering minimized excess drive time
    earliestStartOfServicePickUpMinimization = max(earliestStartOfServicePickUp,earliestStartOfServiceDropOff - max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes[request.pickUpActivity.mobilityType]))
    latestStartOfServicePickUpMinimization = min(latestStartOfServicePickUp,latestStartOfServiceDropOff-max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes[request.pickUpActivity.mobilityType]))

    # Choose the best time for pick up (Here the latest time is chosen)
    startOfServicePick = latestStartOfServicePickUpMinimization

    # Determine the time for drop off
    startOfServiceDrop = startOfServicePick + max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id]+serviceTimes[request.pickUpActivity.mobilityType])

    # Save original nodes before and after pick up and drop off
    activityAssignmentBeforePickUp = route[idxPickUp].activity.id
    activityAssignmentAfterPickUp = route[idxPickUp+1].activity.id
    activityAssignmentBeforeDropOff = route[idxDropOff].activity.id
    activityAssignmentAfterDropOff = route[idxDropOff+1].activity.id

    # Insert request
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick + serviceTimes[request.pickUpActivity.mobilityType],typeOfSeat)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop + serviceTimes[request.dropOffActivity.mobilityType],typeOfSeat)
    insert!(vehicleSchedule.route,idxPickUp+1,pickUpActivity)
    insert!(vehicleSchedule.route,idxDropOff+2,dropOffActivity)

    return activityAssignmentBeforePickUp, activityAssignmentAfterPickUp, activityAssignmentBeforeDropOff, activityAssignmentAfterDropOff

end


#==
# Method to update capacities of vehicle schedule after insertion of request
==#
function updateCapacities!(vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,typeOfSeat::MobilityType)

     # Update capacities
     if typeOfSeat == WHEELCHAIR
        beforePickUp = vehicleSchedule.numberOfWheelchair[idxPickUp]
        beforeDropOff = vehicleSchedule.numberOfWheelchair[idxDropOff]

        # Wheelchair
        insert!(vehicleSchedule.numberOfWheelchair,idxPickUp+1,beforePickUp+1)
        insert!(vehicleSchedule.numberOfWheelchair,idxDropOff+2,beforeDropOff)
        for i in idxPickUp+2:idxDropOff+1
            vehicleSchedule.numberOfWheelchair[i] = vehicleSchedule.numberOfWheelchair[i] + 1
        end

        #Walking
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,vehicleSchedule.numberOfWalking[idxPickUp])
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,vehicleSchedule.numberOfWalking[idxDropOff+2])

    else
        # Walking
        beforePickUp = vehicleSchedule.numberOfWalking[idxPickUp]
        beforeDropOff = vehicleSchedule.numberOfWalking[idxDropOff]
        insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,beforePickUp+1)
        insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,beforeDropOff)
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
        waitingActivity = ActivityAssignment(Activity(route[idx-1].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
        insert!(route,idx,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx,vehicleSchedule.numberOfWalking[idx-1])
        insert!(vehicleSchedule.numberOfWheelchair,idx,vehicleSchedule.numberOfWheelchair[idx-1])
        return 1, route[idx-2].activity.id
    end

    return 0, route[idx-1].activity.id
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
        waitingActivity = ActivityAssignment(Activity(route[idx].activity.id,-1,WAITING,WALKING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
        insert!(route,idx+1,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx+1,vehicleSchedule.numberOfWalking[idx])
        insert!(vehicleSchedule.numberOfWheelchair,idx+1,vehicleSchedule.numberOfWheelchair[idx])
        return 1, route[idx+2].activity.id
    end

    return 0, route[idx+1].activity.id
end


#==
Update waiting after node
==#
function updateWaitingAfterNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route

    route[idx+1].startOfServiceTime = route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id]
    route[idx+1].activity.timeWindow.startTime = route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id]

    if route[idx+1].startOfServiceTime < route[idx+1].endOfServiceTime
        return 0, route[idx+1].activity.id
    else
        # Remove waiting after node
        deleteat!(route,idx+1)
        deleteat!(vehicleSchedule.numberOfWalking,idx+1)
        deleteat!(vehicleSchedule.numberOfWheelchair,idx+1)
        return -1, route[idx+1].activity.id
    end
end

#==
Update waiting before node at index idx
==#
function updateWaitingBeforeNode!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route
    # Update waiting before node
    route[idx-1].endOfServiceTime = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
    route[idx-1].activity.timeWindow.endTime = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
    
    # Check if node should still be there
    if route[idx-1].startOfServiceTime < route[idx-1].endOfServiceTime
        return 0, route[idx-1].activity.id
    else
        deleteat!(route,idx-1)
        deleteat!(vehicleSchedule.numberOfWalking,idx-1)
        deleteat!(vehicleSchedule.numberOfWheelchair,idx-1)

        #println("============> HERE")

        # # Check if a waiting node is still needed, but at location for node before 
        # if route[idx-2].endOfServiceTime + time[route[idx-2].activity.id,route[idx-1].activity.id] < route[idx-1].startOfServiceTime

        #     startOfServiceWaiting = route[idx-2].endOfServiceTime 
        #     endOfServiceWaiting = route[idx-1].startOfServiceTime - time[route[idx-2].activity.id,route[idx-1].activity.id]
        #     waitingActivity = ActivityAssignment(Activity(route[idx-2].activity.id,-1,WAITING,WALKING,route[idx-2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting,WALKING)
        #     insert!(route,idx-1,waitingActivity)
        #     insert!(vehicleSchedule.numberOfWalking,idx-1,vehicleSchedule.numberOfWalking[idx-2])
        #     insert!(vehicleSchedule.numberOfWheelchair,idx-1,vehicleSchedule.numberOfWheelchair[idx-2])
        #     return 0
        # end

        return -1, route[idx-2].activity.id
    end
end


#== 
Update or insert Waiting nodes 
==#
function updateWaiting!(time::Array{Int,2},vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int)
    route = vehicleSchedule.route

    # Keep track of updated index 
    updatedIdxPickUp = idxPickUp+1
    updatedIdxDropOff = idxDropOff+2

      # Keep track of activities 
      updatedActivityAssignmentBeforePickUp = route[idxPickUp].activity.id
      updatedActivityAssignmentAfterPickUp = route[idxPickUp+1].activity.id
      updatedActivityAssignmentBeforeDropOff = route[idxDropOff].activity.id
      updatedActivityAssignmentAfterDropOff = route[idxDropOff+1].activity.id

    # If empty route 
    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
        return updatedIdxPickUp, updatedIdxDropOff
    # If pick-up and drop-off are inserted 
    else
        # Update or insert waiting before pick up
        if route[updatedIdxPickUp-1].activity.activityType != WAITING && route[updatedIdxPickUp-1].activity.activityType != DEPOT
            inserted, updatedActivityAssignmentBeforePickUp = insertWaitingBeforeNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
        elseif route[updatedIdxPickUp-1].activity.activityType != DEPOT
            inserted, updatedActivityAssignmentBeforePickUp = updateWaitingBeforeNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
        end       

        # Update or insert waiting after pick up 
        if route[updatedIdxPickUp+1].activity.activityType != WAITING
            inserted,updatedActivityAssignmentAfterPickUp = insertWaitingAfterNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
        else
            inserted,updatedActivityAssignmentAfterPickUp = updateWaitingAfterNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
        end

        # Update or insert waiting before drop-off
        if route[updatedIdxDropOff-1].activity.activityType != WAITING
            inserted,updatedActivityAssignmentBeforeDropOff = insertWaitingBeforeNode!(time,vehicleSchedule,updatedIdxDropOff)
            updatedIdxDropOff += inserted
        else
            inserted,updatedActivityAssignmentBeforeDropOff = updateWaitingBeforeNode!(time,vehicleSchedule,updatedIdxDropOff)
            updatedIdxDropOff += inserted
        end

        #  Update or insert waiting after drop-off 
        if route[updatedIdxDropOff+1].activity.activityType != WAITING 
            _, updatedActivityAssignmentAfterDropOff = insertWaitingAfterNode!(time,vehicleSchedule,updatedIdxDropOff)
        else
            _, updatedActivityAssignmentAfterDropOff = updateWaitingAfterNode!(time,vehicleSchedule,updatedIdxDropOff)
        end

    end

    return updatedIdxPickUp, updatedIdxDropOff, updatedActivityAssignmentBeforePickUp, updatedActivityAssignmentAfterPickUp, updatedActivityAssignmentBeforeDropOff, updatedActivityAssignmentAfterDropOff

end

#==
# Method to update depots in vehicle schedule after insertion of request
==#
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)
    route = vehicleSchedule.route

    # Update start depot 
    if idxPickUp == 1
        newActiveTimeWindowStart = route[2].startOfServiceTime - time[route[1].activity.id,route[2].activity.id]
        vehicleSchedule.activeTimeWindow.startTime = newActiveTimeWindowStart
        route[1].startOfServiceTime = newActiveTimeWindowStart
        route[1].endOfServiceTime = newActiveTimeWindowStart
    end
end


#==
# Method to update total distance of vehicle schedule after insertion of request
==#
function updateDistance!(scenario::Scenario,vehicleSchedule::VehicleSchedule,request::Request,idxDropOff::Int,idxPickUp::Int,
                        activityAssignmentBeforePickUp::Int, activityAssignmentAfterPickUp::Int, activityAssignmentBeforeDropOff::Int, activityAssignmentAfterDropOff::Int, 
                        updatedActivityAssignmentBeforePickUp::Int, updatedActivityAssignmentAfterPickUp::Int, updatedActivityAssignmentBeforeDropOff::Int, updatedActivityAssignmentAfterDropOff::Int)

    route = vehicleSchedule.route 
    distance = scenario.distance


    # Update total distance
    if idxDropOff-1 == idxPickUp
        #println(vehicleSchedule.totalDistance)
        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp]

        #println(distance[activityAssignmentBeforePickUp.activity.id,activityAssignmentAfterPickUp.activity.id])
        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])

        #println((distance[activityAssignmentBeforePickUp.activity.id,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,activityAssignmentAfterDropOff.activity.id]))
    else

        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp] + distance[activityAssignmentBeforeDropOff,activityAssignmentAfterDropOff]

        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,updatedActivityAssignmentAfterPickUp] +  distance[updatedActivityAssignmentBeforeDropOff,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])

    end


    if !isapprox(vehicleSchedule.totalDistance,getTotalDistanceRoute(route, scenario),atol=0.0001)
        println("CALCULATED: ", vehicleSchedule.totalDistance)
        println("REAL: ",getTotalDistanceRoute(route, scenario) )
        println("updatedActivityAssignmentBeforePickUp: ", updatedActivityAssignmentBeforePickUp)
        println("updatedActivityAssignmentAfterPickUp: ", updatedActivityAssignmentAfterPickUp)
        println("updatedActivityAssignmentBeforeDropOff: ", updatedActivityAssignmentBeforeDropOff)
        println("updatedActivityAssignmentAfterDropOff: ", updatedActivityAssignmentAfterDropOff)
        println("activityAssignmentBeforePickUp: ", activityAssignmentBeforePickUp)
        println("activityAssignmentAfterPickUp: ", activityAssignmentAfterPickUp)
        println("activityAssignmentBeforeDropOff: ", activityAssignmentBeforeDropOff)
        println("activityAssignmentAfterDropOff: ", activityAssignmentAfterDropOff)
        println("idxPickUp: ", idxPickUp)
        println("idxDropOff: ", idxDropOff)
        println("request: ", request.id)
        printRouteHorizontal(vehicleSchedule)
    end

    # vehicleSchedule.totalDistance = getTotalDistanceRoute(route, scenario)

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
        #println("Infeasible: Not enough capacity")
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
            #println("Infeasible: Time window pick-up")
            return false, typeOfSeat
        elseif startOfServiceDrop > request.dropOffActivity.timeWindow.endTime || startOfServiceDrop < request.dropOffActivity.timeWindow.startTime
            #println("Infeasible: Time window drop-off")
            return false, typeOfSeat
        end
        
        # Check drive time: First node
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime
            #println("Infeasible: Drive time from first node")
            return false, typeOfSeat
        end
        
        # Check drive time:Next node
        if idx == length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
            #println("Infeasible: Drive time to next node")
            return false, typeOfSeat
        elseif idx < length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            #println("Infeasible: Drive time to next node")
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
                arrivalNextNode = endOfActivity + scenario.time[activity.id, route[idx+1].activity.id]
            else
                return false, typeOfSeat 
            end

            # Check time window
            if startOfServiceActivity > activity.timeWindow.endTime || startOfServiceActivity < activity.timeWindow.startTime
                #println("Infeasible: Time window")
                return false, typeOfSeat
            end

            # Check drive time: First node
            if startOfServiceActivity > activity.timeWindow.endTime
                #println("Infeasible: Drive time from first node")
                return false, typeOfSeat
            end
            
            # Check drive time:Next node
            if idx == length(route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
                #println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            elseif idx < length(route)-1 && arrivalNextNode > route[idx+1].startOfServiceTime
                #println("Infeasible: Drive time to next node")
                return false, typeOfSeat
            end
    
        end
    end

    
        
    # If all checks pass, the activity is feasible
    #println("FEASIBLE")
    return true, typeOfSeat
end




end