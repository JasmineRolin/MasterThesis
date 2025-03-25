module RouteUtils 

using UnPack, domain, Printf, ..CostCalculator

export printRoute,printSimpleRoute,insertRequest!,checkFeasibilityOfInsertionAtPosition, checkFeasibilityOfInsertionAtPosition2,printRouteHorizontal,printSolution,updateRoute!,determineServiceTimesAndShiftsCase1, determineServiceTimesAndShiftsCase5, determineServiceTimesAndShiftsCase6

#==
# Method to print solution 
==#
function printSolution(solution::Solution,printRouteFunc::Function)
    println("Solution")
    println("Total Distance: ", solution.totalDistance, " km")
    println("Total time: ", solution.totalRideTime, " min")
    println("Total Cost: \$", solution.totalCost)
    println("Total Idle time: ", solution.totalIdleTime)

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
    println("Walking capacities: ", schedule.numberOfWalking)
    println("\nRoute:")
    
    for (i, assignment) in enumerate(schedule.route)
        println("  Step ", i, ":")
        println("    Activity Type: ", assignment.activity.activityType)
        println("    Location: ", assignment.activity.location.name, " (",assignment.activity.location.lat, ",",assignment.activity.location.long,")")
        println("    Start/end of service: ","(", assignment.startOfServiceTime, ",", assignment.endOfServiceTime,")")
        println("    Time Window: ", "(",assignment.activity.timeWindow.startTime, ",", assignment.activity.timeWindow.endTime,")")
        println("    Load: (", schedule.numberOfWalking[i],")")
    end
    println("\n--------------------------------------")
end

function printRouteHorizontal(schedule::VehicleSchedule)
    println("Vehicle Schedule for: ", schedule.vehicle.id)
    println("Available Time Window: ($(schedule.vehicle.availableTimeWindow.startTime), $(schedule.vehicle.availableTimeWindow.endTime)), Active Time Window: ($(schedule.activeTimeWindow.startTime), $(schedule.activeTimeWindow.endTime))")
    println("Total Distance: $(schedule.totalDistance) km, Total Time: $(schedule.totalTime) min,  Total Idle Time: $(schedule.totalIdleTime) min Total Cost: \$$(schedule.totalCost)")
    
    println("------------------------------------------------------------------------------------------------------------")
    println("| Step | Activity Type |  Id |  Location  | Start/End Service | Time Window | (Walking) |")
    println("------------------------------------------------------------------------------------------------------------")

    for (i, assignment) in enumerate(schedule.route)
        start_service = assignment.startOfServiceTime
        end_service = assignment.endOfServiceTime
        activity = assignment.activity
        location = activity.location
        time_window = activity.timeWindow
        
        # Extract load details safely
        walking_load = i <= length(schedule.numberOfWalking) ? schedule.numberOfWalking[i] : "N/A"
        
        # Print each route step in a single horizontal line
        @printf("| %-4d | %-13s | %-4d| %-10s | (%5d, %5d) | (%5d, %5d) | (%3s) |\n",
                i,
                activity.activityType,
                activity.id,
                location.name, 
                start_service, end_service,
                time_window.startTime, time_window.endTime,
                walking_load)
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
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,scenario::Scenario)

    # Update route
    updateRoute!(scenario.time,scenario.distance,scenario.serviceTimes,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff)

    # Update depots
    updateDepots!(scenario.time,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update waiting
    updatedIdxPickUp, updatedIdxDropOff = updateWaiting!(scenario.time,scenario.distance,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update idle time 
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Update total time 
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

    # Update total cost
    vehicleSchedule.totalCost += getCostOfRequest(scenario.time,vehicleSchedule.route[updatedIdxPickUp],vehicleSchedule.route[updatedIdxDropOff])
end


#==
    New insert request 
==#
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,scheduleBlockStart::Int,scheduleBlockEnd::Int,scenario::Scenario,startOfServiceTimePickUp::Int, startOfServiceTimeDropOff::Int, shiftBeforePickUp::Int, shiftBetweenPickupAndDropOff::Int, shiftAfterDropOff::Int, addWaitingActivity::Bool)

    route = vehicleSchedule.route
    vehicle = vehicleSchedule.vehicle
    serviceTime = scenario.serviceTimes

    # Shift route
    for i in scheduleBlockStart+1:idxPickUp
        route[i].startOfServiceTime += shiftBeforePickUp
        route[i].endOfServiceTime += shiftBeforePickUp
    end
    for i in (idxPickUp+1):(idxDropOff)
        route[i].startOfServiceTime += shiftBetweenPickupAndDropOff
        route[i].endOfServiceTime += shiftBetweenPickupAndDropOff
    end
    for i in (idxDropOff+1):scheduleBlockEnd-1
        route[i].startOfServiceTime += shiftAfterDropOff
        route[i].endOfServiceTime += shiftAfterDropOff
    end
    if route[scheduleBlockStart].activity.activityType == WAITING
        route[scheduleBlockStart].activity.timeWindow.endTime += shiftBeforePickUp
        route[scheduleBlockStart].endOfServiceTime += shiftBeforePickUp
    else
        route[scheduleBlockStart].startOfServiceTime += shiftBeforePickUp
        route[scheduleBlockStart].endOfServiceTime += shiftBeforePickUp
    end
    if route[scheduleBlockEnd].activity.activityType == WAITING
        route[scheduleBlockEnd].activity.timeWindow.startTime += shiftAfterDropOff
        route[scheduleBlockEnd].startOfServiceTime += shiftAfterDropOff
    end

    # Insert request
    insert!(route,idxPickUp+1,ActivityAssignment(request.pickUpActivity,vehicle,startOfServiceTimePickUp,startOfServiceTimePickUp + serviceTime))
    insert!(route,idxDropOff+2,ActivityAssignment(request.dropOffActivity,vehicle,startOfServiceTimeDropOff,startOfServiceTimeDropOff + serviceTime))

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff)

    # Update depots
    updateDepots!(scenario.time,vehicleSchedule,request,idxPickUp,idxDropOff,scheduleBlockStart,shiftBeforePickUp)

    # Update waiting
    updatedIdxPickUp, updatedIdxDropOff = updateWaiting!(scenario.time,scenario.distance,vehicleSchedule,request,idxPickUp,idxDropOff)

    # Update idle time 
    vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

    # Update total time 
    vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

    # Update total cost
    vehicleSchedule.totalCost = getTotalCostRoute(scenario,route) #TODO

    #Update total distance
    vehicleSchedule.totalDistance = getTotalDistanceRoute(route,scenario.distance) #TODO
end


#==
Method to update route in vehicle schedule after insertion of request. Will do it so minimize excess drive time and secondly as late as possible
==#
function updateRoute!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)

    route = vehicleSchedule.route

    # Get time when end of service is for node before pick up
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
    latestStartOfServicePickUp = min(startOfServiceAfterPick - time[request.pickUpActivity.id,route[idxPickUp+1].activity.id] - serviceTimes,request.pickUpActivity.timeWindow.endTime)
    earliestStartOfServiceDropOff = max(endOfServiceBeforeDrop + time[route[idxDropOff].activity.id,request.dropOffActivity.id],request.dropOffActivity.timeWindow.startTime)
    latestStartOfServiceDropOff = min(startOfServiceAfterDrop - time[request.dropOffActivity.id,route[idxDropOff+1].activity.id] - serviceTimes,request.dropOffActivity.timeWindow.endTime)  

    # Get available service time window for pick up considering minimized excess drive time
    earliestStartOfServicePickUpMinimization = max(earliestStartOfServicePickUp,earliestStartOfServiceDropOff - max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes))
    latestStartOfServicePickUpMinimization = min(latestStartOfServicePickUp,latestStartOfServiceDropOff-max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTimes))

    # Choose the best time for pick up (Here the latest time is chosen)
    startOfServicePick = latestStartOfServicePickUpMinimization

    # Determine the time for drop off
    startOfServiceDrop = startOfServicePick + max(earliestStartOfServiceDropOff - latestStartOfServicePickUp, time[request.pickUpActivity.id,request.dropOffActivity.id]+serviceTimes)

    # Save original nodes before and after pick up and drop off
    activityAssignmentBeforePickUp = route[idxPickUp].activity.id
    activityAssignmentAfterPickUp = route[idxPickUp+1].activity.id
    activityAssignmentBeforeDropOff = route[idxDropOff].activity.id
    activityAssignmentAfterDropOff = route[idxDropOff+1].activity.id

    # Insert request
    pickUpActivity = ActivityAssignment(request.pickUpActivity, vehicleSchedule.vehicle, startOfServicePick, startOfServicePick + serviceTimes)
    dropOffActivity = ActivityAssignment(request.dropOffActivity, vehicleSchedule.vehicle, startOfServiceDrop, startOfServiceDrop + serviceTimes)
    insert!(vehicleSchedule.route,idxPickUp+1,pickUpActivity)
    insert!(vehicleSchedule.route,idxDropOff+2,dropOffActivity)

    # Update total distance by removing distance betweeen old neighbors  
    if idxDropOff == idxPickUp
        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp]
    else
        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp] + distance[activityAssignmentBeforeDropOff,activityAssignmentAfterDropOff]
    end

end


#==
# Method to update capacities of vehicle schedule after insertion of request
==#
function updateCapacities!(vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int)

    # Update capacities
    beforePickUp = vehicleSchedule.numberOfWalking[idxPickUp]
    beforeDropOff = vehicleSchedule.numberOfWalking[idxDropOff]
    insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,beforePickUp+1)
    insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,beforeDropOff)
    for i in idxPickUp+2:idxDropOff+1
        vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
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
        waitingActivity = ActivityAssignment(Activity(route[idx-1].activity.id,-1,WAITING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx,vehicleSchedule.numberOfWalking[idx-1])
        newIdleTime = waitingActivity.endOfServiceTime - waitingActivity.startOfServiceTime

        return 1, route[idx-2].activity.id, newIdleTime
    end

    return 0, route[idx-1].activity.id,0
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
        waitingActivity = ActivityAssignment(Activity(route[idx].activity.id,-1,WAITING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
        insert!(route,idx+1,waitingActivity)
        insert!(vehicleSchedule.numberOfWalking,idx+1,vehicleSchedule.numberOfWalking[idx])
        newIdleTime = waitingActivity.endOfServiceTime - waitingActivity.startOfServiceTime

        return 1, route[idx+2].activity.id, newIdleTime
    end

    return 0, route[idx+1].activity.id,0
end


#==
Update waiting after node
==#
function updateWaitingAfterNode!(time::Array{Int,2},distance::Array{Float64,2},vehicleSchedule::VehicleSchedule,idx::Int)

    route = vehicleSchedule.route

    # Idle time delta
    oldIdleTime = route[idx-1].endOfServiceTime - route[idx-1].startOfServiceTime

    route[idx+1].startOfServiceTime = route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id]
    route[idx+1].activity.timeWindow.startTime = route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id]

    if route[idx+1].startOfServiceTime < route[idx+1].endOfServiceTime
        newIdleTime = route[idx+1].endOfServiceTime - route[idx+1].startOfServiceTime

        return 0, route[idx+1].activity.id, (newIdleTime-oldIdleTime)
    else
        # Update distance 
        vehicleSchedule.totalDistance -= distance[route[idx+1].activity.id,route[idx+2].activity.id]

        # Remove waiting after node
        deleteat!(route,idx+1)
        deleteat!(vehicleSchedule.numberOfWalking,idx+1)

          # Check if a waiting node is still needed, but at location for node before 
          if route[idx].endOfServiceTime + time[route[idx].activity.id,route[idx+1].activity.id] < route[idx+1].startOfServiceTime
            startOfServiceWaiting = route[idx].endOfServiceTime 
            endOfServiceWaiting = route[idx+1].startOfServiceTime - time[route[idx].activity.id,route[idx+1].activity.id]
            waitingActivity = ActivityAssignment(Activity(route[idx].activity.id,-1,WAITING,route[idx].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
            insert!(route,idx+1,waitingActivity)
            insert!(vehicleSchedule.numberOfWalking,idx+1,vehicleSchedule.numberOfWalking[idx])

            newIdleTime = route[idx+1].endOfServiceTime - route[idx+1].startOfServiceTime

            return 0, route[idx+1].activity.id, (newIdleTime-oldIdleTime)
        end

        return -1, route[idx+1].activity.id, oldIdleTime
    end
end

#==
Update waiting before node at index idx
==#
function updateWaitingBeforeNode!(time::Array{Int,2},distance::Array{Float64,2},vehicleSchedule::VehicleSchedule,idx::Int)
    route = vehicleSchedule.route

    # Idle time delta
    oldIdleTime = route[idx-1].endOfServiceTime - route[idx-1].startOfServiceTime

    # Update waiting before node
    route[idx-1].endOfServiceTime = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
    route[idx-1].activity.timeWindow.endTime = route[idx].startOfServiceTime - time[route[idx-1].activity.id,route[idx].activity.id]
    
    # Check if node should still be there
    if route[idx-1].startOfServiceTime < route[idx-1].endOfServiceTime
        newIdleTime = route[idx-1].endOfServiceTime - route[idx-1].startOfServiceTime

        return 0, route[idx-1].activity.id, (newIdleTime-oldIdleTime)
    else
        # Update distance 
        vehicleSchedule.totalDistance -= distance[route[idx-2].activity.id,route[idx-1].activity.id]

        deleteat!(route,idx-1)
        deleteat!(vehicleSchedule.numberOfWalking,idx-1)

        # Check if a waiting node is still needed, but at location for node before 
        if route[idx-2].endOfServiceTime + time[route[idx-2].activity.id,route[idx-1].activity.id] < route[idx-1].startOfServiceTime
            startOfServiceWaiting = route[idx-2].endOfServiceTime 
            endOfServiceWaiting = route[idx-1].startOfServiceTime - time[route[idx-2].activity.id,route[idx-1].activity.id]
            waitingActivity = ActivityAssignment(Activity(route[idx-2].activity.id,-1,WAITING,route[idx-2].activity.location,TimeWindow(startOfServiceWaiting,endOfServiceWaiting)),vehicleSchedule.vehicle,startOfServiceWaiting,endOfServiceWaiting)
            insert!(route,idx-1,waitingActivity)
            insert!(vehicleSchedule.numberOfWalking,idx-1,vehicleSchedule.numberOfWalking[idx-2])

            newIdleTime = route[idx-1].endOfServiceTime - route[idx-1].startOfServiceTime

            return 0, route[idx-2].activity.id, (newIdleTime-oldIdleTime)
        end

        return -1, route[idx-2].activity.id, oldIdleTime
    end
end


#== 
Update or insert Waiting nodes 
==#
function updateWaiting!(time::Array{Int,2},distance::Array{Float64,2},vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int)
    route = vehicleSchedule.route

    # Keep track of updated index 
    updatedIdxPickUp = idxPickUp+1
    updatedIdxDropOff = idxDropOff+2

    # Keep track of activities 
    updatedActivityAssignmentBeforePickUp = route[idxPickUp].activity.id
    updatedActivityAssignmentAfterPickUp = route[idxPickUp+1].activity.id
    updatedActivityAssignmentBeforeDropOff = route[idxDropOff].activity.id
    updatedActivityAssignmentAfterDropOff = route[idxDropOff+1].activity.id

    # Keep track of idle time 
    totalIdleTimeDelta = 0

    # If empty route 
    if length(vehicleSchedule.route) == 2 && vehicleSchedule.route[1].activity.activityType == DEPOT && vehicleSchedule.route[2].activity.activityType == DEPOT
        return updatedIdxPickUp, updatedIdxDropOff
    # If pick-up and drop-off are inserted 
    else
        # Update or insert waiting before pick up
        if route[updatedIdxPickUp-1].activity.activityType != WAITING && route[updatedIdxPickUp-1].activity.activityType != DEPOT
            inserted, updatedActivityAssignmentBeforePickUp, idleTimeDelta = insertWaitingBeforeNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
            totalIdleTimeDelta += idleTimeDelta
        elseif route[updatedIdxPickUp-1].activity.activityType != DEPOT
            inserted, updatedActivityAssignmentBeforePickUp, idleTimeDelta = updateWaitingBeforeNode!(time,distance,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            updatedIdxPickUp += inserted
            totalIdleTimeDelta += idleTimeDelta
        end       

        # Update or insert waiting after pick up 
        if route[updatedIdxPickUp+1].activity.activityType != WAITING
            inserted,updatedActivityAssignmentAfterPickUp, idleTimeDelta = insertWaitingAfterNode!(time,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            totalIdleTimeDelta += idleTimeDelta
        else
            inserted,updatedActivityAssignmentAfterPickUp, idleTimeDelta = updateWaitingAfterNode!(time,distance,vehicleSchedule,updatedIdxPickUp)
            updatedIdxDropOff += inserted
            totalIdleTimeDelta += idleTimeDelta
        end

        # Update or insert waiting before drop-off
        if route[updatedIdxDropOff-1].activity.activityType != WAITING
            inserted,updatedActivityAssignmentBeforeDropOff,idleTimeDelta = insertWaitingBeforeNode!(time,vehicleSchedule,updatedIdxDropOff)
            updatedIdxDropOff += inserted
            totalIdleTimeDelta += idleTimeDelta
        else
            inserted,updatedActivityAssignmentBeforeDropOff,idleTimeDelta = updateWaitingBeforeNode!(time,distance,vehicleSchedule,updatedIdxDropOff)
            updatedIdxDropOff += inserted
            totalIdleTimeDelta += idleTimeDelta
        end

        #  Update or insert waiting after drop-off 
        if route[updatedIdxDropOff+1].activity.activityType != WAITING 
            _, updatedActivityAssignmentAfterDropOff,idleTimeDelta = insertWaitingAfterNode!(time,vehicleSchedule,updatedIdxDropOff)
            totalIdleTimeDelta += idleTimeDelta
        else
            _, updatedActivityAssignmentAfterDropOff,idleTimeDelta = updateWaitingAfterNode!(time,distance,vehicleSchedule,updatedIdxDropOff)
            totalIdleTimeDelta += idleTimeDelta
        end

    end

    # Update total idle time 
    vehicleSchedule.totalIdleTime += totalIdleTimeDelta

    # Update total distance
    if idxDropOff == idxPickUp
        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])

    else
        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,updatedActivityAssignmentAfterPickUp] +  distance[updatedActivityAssignmentBeforeDropOff,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])
    end

    return updatedIdxPickUp, updatedIdxDropOff

end

#==
# Method to update depots in vehicle schedule after insertion of request
==#
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,request::Request,idxPickUp::Int,idxDropOff::Int,scheduleBlockStart::Int,shift_before_pick_up::Int)
    route = vehicleSchedule.route

    # Update start depot 
    if idxPickUp == 1 || (shift_before_pick_up !== 0 && route[scheduleBlockStart].activity.activityType == DEPOT)
        newActiveTimeWindowStart = route[2].startOfServiceTime - time[route[1].activity.id,route[2].activity.id]
        vehicleSchedule.activeTimeWindow.startTime = newActiveTimeWindowStart
        route[1].startOfServiceTime = newActiveTimeWindowStart
        route[1].endOfServiceTime = newActiveTimeWindowStart
    end

end

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
        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp]
        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])
    else
        vehicleSchedule.totalDistance -= distance[activityAssignmentBeforePickUp,activityAssignmentAfterPickUp] + distance[activityAssignmentBeforeDropOff,activityAssignmentAfterDropOff]
        vehicleSchedule.totalDistance += (distance[updatedActivityAssignmentBeforePickUp,request.pickUpActivity.id] + distance[request.pickUpActivity.id,updatedActivityAssignmentAfterPickUp] +  distance[updatedActivityAssignmentBeforeDropOff,request.dropOffActivity.id] + distance[request.dropOffActivity.id,updatedActivityAssignmentAfterDropOff])
    end
end



# ----------
# Function to check feasibility of given placement of a request for in a vehicle schedule 
# ----------
# OBS: Made for when a service time is determined, and it cannot be changed
function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)

    # Check vehicle capacity
    if !(all(vehicleSchedule.numberOfWalking[(pickUpIdx + 1):dropOffIdx] .< vehicleSchedule.vehicle.totalCapacity))
        return false
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
            endOfPickUp = startOfServicePick + scenario.serviceTimes

            earliestStartOfServiceDrop = endOfPickUp + scenario.time[request.pickUpActivity.id, request.dropOffActivity.id]
            startOfServiceDrop = max(earliestStartOfServiceDrop,request.dropOffActivity.timeWindow.startTime)
            endOfDropOff = startOfServiceDrop + scenario.serviceTimes
            arrivalNextNode = endOfDropOff + scenario.time[request.dropOffActivity.id, vehicleSchedule.route[idx+1].activity.id]
        else
            return false
        end

        # Check time window
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime || startOfServicePick < request.pickUpActivity.timeWindow.startTime
            #println("Infeasible: Time window pick-up")
            return false
        elseif startOfServiceDrop > request.dropOffActivity.timeWindow.endTime || startOfServiceDrop < request.dropOffActivity.timeWindow.startTime
            #println("Infeasible: Time window drop-off")
            return false
        end
        
        # Check drive time: First node
        if startOfServicePick > request.pickUpActivity.timeWindow.endTime
            #println("Infeasible: Drive time from first node")
            return false
        end
        
        # Check drive time:Next node
        if idx == length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
            #println("Infeasible: Drive time to next node")
            return false
        elseif idx < length(vehicleSchedule.route)-1 && arrivalNextNode > vehicleSchedule.route[idx+1].startOfServiceTime
            #println("Infeasible: Drive time to next node")
            return false
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
                
                endOfActivity = startOfServiceActivity + scenario.serviceTimes
                arrivalNextNode = endOfActivity + scenario.time[activity.id, route[idx+1].activity.id]
            else
                return false
            end

            # Check time window
            if startOfServiceActivity > activity.timeWindow.endTime || startOfServiceActivity < activity.timeWindow.startTime
                #println("Infeasible: Time window")
                return false
            end

            # Check drive time: First node
            if startOfServiceActivity > activity.timeWindow.endTime
                #println("Infeasible: Drive time from first node")
                return false
            end
            
            # Check drive time:Next node
            if idx == length(route)-1 && arrivalNextNode > vehicleSchedule.vehicle.availableTimeWindow.endTime
                #println("Infeasible: Drive time to next node")
                return false
            elseif idx < length(route)-1 && arrivalNextNode > route[idx+1].startOfServiceTime
                #println("Infeasible: Drive time to next node")
                return false
            end
    
        end
    end

    
        
    # If all checks pass, the activity is feasible
    #println("FEASIBLE")
    return true
end


function checkFeasibilityOfInsertionAtPosition2(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)

    @unpack route,numberOfWalking, vehicle = vehicleSchedule
    @unpack time,serviceTimes = scenario

    # Identify schedule block in  route 
    waitingOrDepotIndices = findall(x -> x.activity.activityType in (WAITING, DEPOT), route)
    waitingActivityIdxBeforePickUp = waitingOrDepotIndices[findlast(x -> x <= pickUpIdx, waitingOrDepotIndices)]
    waitingActivityIdxAfterPickUp = waitingOrDepotIndices[findfirst(x -> x > pickUpIdx, waitingOrDepotIndices)]
    waitingActivityIdxBeforeDropOff = waitingOrDepotIndices[findlast(x -> x <= dropOffIdx, waitingOrDepotIndices)]
    waitingActivityIdxAfterDropOff = waitingOrDepotIndices[findfirst(x -> x > dropOffIdx, waitingOrDepotIndices)]

    println("HERE")
    # Check if in same schedule block 
    if waitingActivityIdxBeforePickUp != waitingActivityIdxBeforeDropOff || waitingActivityIdxAfterPickUp != waitingActivityIdxAfterDropOff
        println("INFEASIBLE: DIFFERENT SCHEDULE BLOCKS")
        return false,0,0,0,0,0,0,0
    end

    # Check load 
    if any(numberOfWalking[pickUpIdx:dropOffIdx] .+ 1 .> vehicle.totalCapacity) # TODO: jas - check rigtigt 
        println("INFEASIBLE: CAPACITY")
        return false,0,0,0,0,0,0,0
    end

    # Check times for pick up 
    if route[pickUpIdx].activity.timeWindow.startTime > request.pickUpActivity.timeWindow.endTime || route[pickUpIdx+1].activity.timeWindow.endTime < request.pickUpActivity.timeWindow.startTime
        println("INFEASIBLE: PICK-UP TIME WINDOW")
        return false,0,0,0,0,0,0,0
    end

    # Check times for drop off
    if route[dropOffIdx].activity.timeWindow.startTime > request.dropOffActivity.timeWindow.endTime || route[dropOffIdx+1].activity.timeWindow.endTime < request.dropOffActivity.timeWindow.startTime
        println("INFEASIBLE: DROP-OFF TIME WINDOW")
        return false,0,0,0,0,0,0,0
    end

    # Retrieve schedule block
    pickUpIdxInBlock = (pickUpIdx - (waitingActivityIdxBeforePickUp-1))  # Index as if pickup is inserted 
    dropOffIdxInBlock = (dropOffIdx - (waitingActivityIdxBeforePickUp-1))  # Index as if pickup and dropoff is inserted
    scheduleBlock = route[waitingActivityIdxBeforePickUp:waitingActivityIdxAfterPickUp]

    # Check feasibility 
    # Case 1 : W - ROUTE - P - D - W
    if pickUpIdxInBlock == 1 && dropOffIdxInBlock == pickUpIdxInBlock  
        println("No Case1")    
        return false,0,0,0,0,0,0,0
    # Case 2 : W - P - D - ROUTE - W 
    elseif pickUpIdxInBlock == length(scheduleBlock) - 1 && dropOffIdxInBlock == pickUpIdxInBlock
        println("No case2")
        return false,0,0,0,0,0,0,0
    # Case 5 : W - ROUTE - P - D - ROUTE - W
    elseif pickUpIdxInBlock == dropOffIdxInBlock
        feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = determineServiceTimesAndShiftsCase5(time,serviceTimes,request,scheduleBlock,pickUpIdxInBlock,scenario.requests)
    # Case 6 : W - ROUTE - P - ROUTE - D - ROUTE - W
    else
        feasible,  startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = determineServiceTimesAndShiftsCase6(time,serviceTimes,request,scheduleBlock, pickUpIdxInBlock, dropOffIdxInBlock, scenario.requests)
    end
    
    println("HERE2")
    return  feasible,  startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, waitingActivityIdxBeforePickUp, waitingActivityIdxAfterPickUp
end


#==
 Method to determine the time to start service at new request and how much to shift the existing route  
==#
# Case 1 : W - ROUTE - P - D - W
function determineServiceTimesAndShiftsCase1(time::Array{Int,2},serviceTime::Int,request::Request,scheduleBlock::Vector{ActivityAssignment})
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    # Retrieve info 
    pickUpActivity, dropOffActivity = request.pickUpActivity, request.dropOffActivity
    pickUpId, dropOffId = pickUpActivity.id, dropOffActivity.id
    startActivity = scheduleBlock[1]
    endActivity = scheduleBlock[end]
    activityBeforePickUp = scheduleBlock[end-1]
  
    # Duration of waiting activities at start and end of schedule block
    detour = findDetour(time,serviceTime,activityBeforePickUp.activity.id,endActivity.activity.id,pickUpId,dropOffId)
    waitingTimeStart = startActivity.activity.activityType == DEPOT ? startActivity.endOfServiceTime - startActivity.activity.timeWindow.startTime : startActivity.endOfServiceTime - startActivity.startOfServiceTime
    waitingTimeEnd = endActivity.activity.activityType == DEPOT ? endActivity.activity.timeWindow.endTime - endActivity.startOfServiceTime : (endActivity.endOfServiceTime - endActivity.startOfServiceTime) - detour

    arrivalAtPickUp = activityBeforePickUp.endOfServiceTime + time[activityBeforePickUp.activity.id,pickUpId]
    # Can request be inserted directly at end of schedule block 
    if pickUpActivity.timeWindow.startTime <= arrivalAtPickUp <= pickUpActivity.timeWindow.endTime && dropOffActivity.timeWindow.startTime <= arrivalAtPickUp + serviceTime + time[pickUpId,dropOffId] <= dropOffActivity.timeWindow.endTime
        feasible = true 
        startOfServiceTimePickUp = activityBeforePickUp.endOfServiceTime + time[activityBeforePickUp.activity.id,pickUpId]
        startOfServiceTimeDropOff = startOfServiceTimePickUp  + serviceTime + time[pickUpId,dropOffId] 
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Can request be inserted at end of schedule block by shifting route forward 
    if arrivalAtPickUp < pickUpActivity.timeWindow.startTime
        shift = determineMaximumShiftForward(waitingTimeEnd,scheduleBlock[2:(end-1)])
        shiftedArrivalAtPickUp = arrivalAtPickUp + shift
        shiftedArrivalAtDropOff = shiftedArrivalAtPickUp + serviceTime + time[pickUpId,dropOffId]
        
        # Insert if feasible 
        if shiftedArrivalAtPickUp >= pickUpActivity.timeWindow.startTime && shiftedArrivalAtDropOff >= dropOffActivity.timeWindow.startTime 
            shift = min(shift, shift - min(shiftedArrivalAtDropOff-dropOffActivity.timeWindow.startTime, shiftedArrivalAtPickUp-pickUpActivity.timeWindow.startTime)) # Place request at drop off earliest time window 
            feasible = true
            startOfServiceTimePickUp = arrivalAtPickUp + shift
            startOfServiceTimeDropOff = startOfServiceTimePickUp  + serviceTime + time[pickUpId,dropOffId]
            shiftBeforePickUp = shift
            shiftAfterDropOff = shift + detour 

            return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
        end
    end

    # Can request be inserted at end of schedule block by shifting route backward
    if arrivalAtPickUp > pickUpActivity.timeWindow.endTime
        shift = determineMaximumShiftBackward(waitingTimeStart,scheduleBlock[2:(end-1)])

        # Insert if feasible 
        if arrivalAtPickUp - shift <= pickUpActivity.timeWindow.endTime 
            shiftedArrivalAtPickUp = max(pickUpActivity.timeWindow.startTime,arrivalAtPickUp - shift)
            shiftedArrivalAtDropOff = shiftedArrivalAtPickUp + serviceTime + time[pickUpId,dropOffId]

            # Infeasible if we can only arrive after latest start of drop off
            if shiftedArrivalAtDropOff >= dropOffActivity.timeWindow.endTime
                return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
            end

            # Insert if feasible
            if dropOffActivity.timeWindow.startTime <= shiftedArrivalAtDropOff <= dropOffActivity.timeWindow.endTime 
                feasible = true
                shift = arrivalAtPickUp - shiftedArrivalAtPickUp
                startOfServiceTimePickUp = shiftedArrivalAtPickUp
                startOfServiceTimeDropOff = shiftedArrivalAtDropOff
                shiftBeforePickUp = -shift
                shiftAfterDropOff = -shift + detour

                return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity

            end

            # Find new shift to arrive in drop off time window 
            shift = shift - (dropOffActivity.timeWindow.startTime - shiftedArrivalAtDropOff)
            startOfServiceTimePickUp = arrivalAtPickUp - shift
            startOfServiceTimeDropOff = startOfServiceTimePickUp + serviceTime + time[pickUpId,dropOffId]
            shiftBeforePickUp = -shift
            shiftAfterDropOff = -shift + detour

            return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
        end
    end

    # Can request be inserted at end of schedule by inserting waiting activity before pick-up
    startOfWaitingActivity = activityBeforePickUp.endOfServiceTime
    endOfWaitingActivity = dropOffActivity.timeWindow.startTime - time[pickUpId,dropOffId] - serviceTime - time[activityBeforePickUp.activity.id,pickUpId]

    if startOfWaitingActivity > endOfWaitingActivity
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Infeasible arrival at pick up 
    arrivalAtPickUp = endOfWaitingActivity + time[activityBeforePickUp.activity.id,pickUpId]
    if  arrivalAtPickUp > pickUpActivity.timeWindow.endTime || arrivalAtPickUp < pickUpActivity.timeWindow.startTime
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff,addWaitingActivity
    end

    # Infeasible arrival at drop off 
    arrivalAtDropOff = arrivalAtPickUp + serviceTime + time[pickUpId,dropOffId]
    if arrivalAtDropOff > dropOffActivity.timeWindow.endTime || arrivalAtDropOff < dropOffActivity.timeWindow.startTime
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Infeasible arrival at end of schedule block
    endOfWaitingAtEnd = endActivity.activity.activityType == DEPOT ?  endActivity.activity.timeWindow.endTime : endActivity.endOfServiceTime
    arrivalAtEndWaiting = arrivalAtDropOff + serviceTime + time[dropOffId,endActivity.activity.id]
    if arrivalAtEndWaiting > endOfWaitingAtEnd
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Waiting can be inserted
    feasible = true
    addWaitingActivity = true 
    startOfServiceTimePickUp = arrivalAtPickUp
    startOfServiceTimeDropOff = arrivalAtDropOff
    shiftAfterDropOff = (endOfWaitingActivity - startOfWaitingActivity) + detour

    return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
end

# Case 2 : W - P - D - ROUTE - W 
function determineServiceTimesAndShiftsCase2()
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
end

# Case 3 : W - P - ROUTE - D - ROUTE - W
function determineServiceTimesAndShiftsCase3()
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
end

# Case 4 : W - ROUTE - P - ROUTE - D - W
function determineServiceTimesAndShiftsCase4()
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
end

# Case 5 : W - ROUTE - P - D - ROUTE - W 
function determineServiceTimesAndShiftsCase5(time::Array{Int,2},serviceTime::Int,request::Request,scheduleBlock::Vector{ActivityAssignment}, idx::Int, requests::Vector{Request})
    println("HERE4")
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    # Retrieve info 
    activityBefore = scheduleBlock[idx]
    activityAfter = scheduleBlock[idx+1]
    Detour = findDetour(time,serviceTime,activityBefore.activity.id,activityAfter.activity.id,request.pickUpActivity.id,request.dropOffActivity.id)
    waitingTimeEnd = scheduleBlock[end].activity.activityType == DEPOT ? scheduleBlock[end].activity.timeWindow.endTime - scheduleBlock[end].startOfServiceTime : scheduleBlock[end].endOfServiceTime - scheduleBlock[end].startOfServiceTime 
    waitingTimeStart = scheduleBlock[1].activity.activityType == DEPOT ? scheduleBlock[1].endOfServiceTime - scheduleBlock[1].activity.timeWindow.startTime : scheduleBlock[1].endOfServiceTime - scheduleBlock[1].startOfServiceTime

    # Determine max shifts
    AUP, ADOWN = determinePossibleAfterShift(waitingTimeEnd,scheduleBlock[idx+1:end])
    BUP, BDOWN = determinePossibleBeforeShift(waitingTimeStart,scheduleBlock[1:idx])
    if Detour > BUP + ADOWN
        println("Not possible to fit detour")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Compute max ride time constraint
    max_MRT_shift = determineMaximumShiftMRT(scheduleBlock,idx,requests,serviceTime)
    if Detour > max_MRT_shift
        println("Max ride time conflict")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Determine direct drive time windows
    if request.requestType == PICKUP_REQUEST
        directTimeWindowPick = (request.pickUpActivity.timeWindow.startTime, request.pickUpActivity.timeWindow.startTime + (request.maximumRideTime-request.directDriveTime))
        directTimeWindowDrop = (directTimeWindowPick[1] + time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTime, directTimeWindowPick[2] + time[request.pickUpActivity.id,request.dropOffActivity.id] + serviceTime)
    else
        directTimeWindowDrop = (request.dropOffActivity.timeWindow.endTime - (request.maximumRideTime-request.directDriveTime), request.dropOffActivity.timeWindow.endTime)
        directTimeWindowPick = (directTimeWindowDrop[1] - time[request.pickUpActivity.id,request.dropOffActivity.id] - serviceTime, directTimeWindowDrop[2] - time[request.pickUpActivity.id,request.dropOffActivity.id] - serviceTime)
    end

    # Determine possible arrival times
    possibleArrivalTimePickUp = (activityBefore.endOfServiceTime - BUP + time[activityBefore.activity.id,request.pickUpActivity.id], activityBefore.endOfServiceTime + BDOWN + time[activityBefore.activity.id,request.pickUpActivity.id])
    possibleArrivalTimeDropOff = (activityAfter.startOfServiceTime - AUP - time[request.dropOffActivity.id,activityAfter.activity.id] - serviceTime, activityAfter.startOfServiceTime + ADOWN - time[request.dropOffActivity.id,activityAfter.activity.id ]- serviceTime)

    # Determine feasible arrival times
    arrivalTimePickUp = (max(possibleArrivalTimePickUp[1],directTimeWindowPick[1],request.pickUpActivity.timeWindow.startTime), min(possibleArrivalTimePickUp[2],directTimeWindowPick[2],request.pickUpActivity.timeWindow.endTime))
    arrivalTimeDropOff = (max(possibleArrivalTimeDropOff[1],directTimeWindowDrop[1],request.dropOffActivity.timeWindow.startTime), min(possibleArrivalTimeDropOff[2],directTimeWindowDrop[2],request.dropOffActivity.timeWindow.endTime))
    if arrivalTimePickUp[2] < arrivalTimePickUp[1] || arrivalTimeDropOff[2] < arrivalTimeDropOff[1]
        println("Time window infeasibility")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Determine feasible shifts considering pickup and drop off time windows
    potentialDropOffFromPick = (arrivalTimePickUp[1] + serviceTime + time[request.pickUpActivity.id,request.dropOffActivity.id],arrivalTimePickUp[2] + serviceTime + time[request.pickUpActivity.id,request.dropOffActivity.id])
    possibleDropOffTimeWindow = (max(potentialDropOffFromPick[1],arrivalTimeDropOff[1]), min(potentialDropOffFromPick[2],arrivalTimeDropOff[2]))
    if possibleDropOffTimeWindow[2] < possibleDropOffTimeWindow[1]
        println("No possible drop off")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # determine service windows
    startOfServiceTimeDropOff = possibleDropOffTimeWindow[2]
    startOfServiceTimePickUp = startOfServiceTimeDropOff - serviceTime - time[request.pickUpActivity.id,request.dropOffActivity.id]

    # Determine shifts 
    shiftBeforePickUp = startOfServiceTimePickUp - (activityBefore.endOfServiceTime + time[activityBefore.activity.id,request.pickUpActivity.id])
    shiftBetweenPickupAndDropOff = 0
    shiftAfterDropOff = startOfServiceTimeDropOff - (activityAfter.startOfServiceTime - time[request.dropOffActivity.id,activityAfter.activity.id] - serviceTime)

    return true, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, 0, shiftAfterDropOff, false
end

# Case 6 : W - ROUTE - P - ROUTE - D - ROUTE - W
# OBS: Index here have to be the index in the schedule block
function determineServiceTimesAndShiftsCase6(time::Array{Int,2},serviceTime::Int,request::Request,scheduleBlock::Vector{ActivityAssignment}, pickUpIdx::Int, dropOffIdx::Int, requests::Vector{Request})
    println("HERE3")
    feasible = false
    startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff = 0,0,0,0,0
    addWaitingActivity = false

    # Retrieve info 
    activityBeforePick = scheduleBlock[pickUpIdx]
    activityAfterPick = scheduleBlock[pickUpIdx+1]
    DetourPick = findDetour(time,serviceTime,activityBeforePick.activity.id,activityAfterPick.activity.id,request.pickUpActivity.id)
    activityBeforeDrop = scheduleBlock[dropOffIdx]
    activityAfterDrop = scheduleBlock[dropOffIdx+1]
    DetourDrop = findDetour(time,serviceTime,activityBeforeDrop.activity.id,activityAfterDrop.activity.id,request.dropOffActivity.id)
    waitingTimeEnd = scheduleBlock[end].activity.activityType == DEPOT ? scheduleBlock[end].activity.timeWindow.endTime - scheduleBlock[end].startOfServiceTime : scheduleBlock[end].endOfServiceTime - scheduleBlock[end].startOfServiceTime 
    waitingTimeStart = scheduleBlock[1].activity.activityType == DEPOT ? scheduleBlock[1].endOfServiceTime - scheduleBlock[1].activity.timeWindow.startTime : scheduleBlock[1].endOfServiceTime - scheduleBlock[1].startOfServiceTime

    # Determine max shifts
    AUP, ADOWN = determinePossibleAfterShift(waitingTimeEnd,scheduleBlock[dropOffIdx+1:end])
    BUP, BDOWN = determinePossibleBeforeShift(waitingTimeStart,scheduleBlock[1:pickUpIdx])
    CUP, CDOWN = determinePossibleMiddleShift(BUP,ADOWN,scheduleBlock[(pickUpIdx+1):dropOffIdx])
    ADOWN_prime = min(ADOWN,CDOWN)
    AUP_prime = min(AUP,CUP)
    if DetourPick > BUP + CDOWN || DetourDrop > CUP + ADOWN || DetourPick + DetourDrop > BUP + ADOWN
        println("Not possible to fit detour")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Compute max ride time constraint
    max_MRT_shift_pick = determineMaximumShiftMRT(scheduleBlock,pickUpIdx,requests,serviceTime)
    max_MRT_shift_drop = determineMaximumShiftMRT(scheduleBlock,dropOffIdx,requests,serviceTime)
    max_MRT_shift_PickDrop = determineMaximumShiftMRT(scheduleBlock,pickUpIdx,dropOffIdx,requests,serviceTime)
    if DetourPick > max_MRT_shift_pick || DetourDrop > max_MRT_shift_drop || DetourPick + DetourDrop > max_MRT_shift_PickDrop
        println("Max ride time conflict")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Determine possible arrival times for pick up
    possibleArrivalTimePickUpFromBefore = (activityBeforePick.endOfServiceTime - BUP + time[activityBeforePick.activity.id,request.pickUpActivity.id], activityBeforePick.endOfServiceTime + BDOWN + time[activityBeforePick.activity.id,request.pickUpActivity.id])
    possibleArrivalTimePickUpFromAfter = (activityAfterPick.startOfServiceTime - AUP_prime - time[request.pickUpActivity.id,activityAfterPick.activity.id] - serviceTime, activityAfterPick.startOfServiceTime + ADOWN_prime - time[request.pickUpActivity.id,activityAfterPick.activity.id] - serviceTime)
    possibleArrivalTimePickUP = (max(possibleArrivalTimePickUpFromBefore[1],possibleArrivalTimePickUpFromAfter[1],request.pickUpActivity.timeWindow.startTime), min(possibleArrivalTimePickUpFromBefore[2],possibleArrivalTimePickUpFromAfter[2],request.pickUpActivity.timeWindow.endTime))
    if possibleArrivalTimePickUP[2] < possibleArrivalTimePickUP[1]
        println("Infeasible: Pick up time window")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # Determine shift when pick up is inserted
    initialPickUpTime = possibleArrivalTimePickUP[1]
    initialshiftBeforePickUp = initialPickUpTime - (activityBeforePick.endOfServiceTime + time[activityBeforePick.activity.id,request.pickUpActivity.id])
    initialshiftAfterPickUp = initialPickUpTime - (activityAfterPick.startOfServiceTime - time[request.pickUpActivity.id,activityAfterPick.activity.id] - serviceTime)

    # Determine shift for drop-off
    BUP_prime = 0
    BDOWN_prime = min(possibleArrivalTimePickUP[2] - possibleArrivalTimePickUP[1],CDOWN-initialshiftAfterPickUp)
    AUP_prime = AUP + initialshiftAfterPickUp
    ADOWN_prime = ADOWN - initialshiftAfterPickUp 

    # Determine time window for node before and after drop off
    possibleArrivalTimeDropOffFromBefore = (activityBeforeDrop.endOfServiceTime + initialshiftAfterPickUp - BUP_prime + time[activityBeforeDrop.activity.id,request.dropOffActivity.id], activityBeforeDrop.endOfServiceTime +initialshiftAfterPickUp + BDOWN_prime + time[activityBeforeDrop.activity.id,request.dropOffActivity.id])
    possibleArrivalTimeDropOffFromAfter  = (activityAfterDrop.startOfServiceTime +initialshiftAfterPickUp - AUP_prime - time[request.dropOffActivity.id,activityAfterDrop.activity.id] - serviceTime, activityAfterDrop.startOfServiceTime +initialshiftAfterPickUp + ADOWN_prime - time[request.dropOffActivity.id,activityAfterDrop.activity.id ]- serviceTime)

    # Ensure it can come from pick up
    fromPickToDropTimeWindow = (possibleArrivalTimePickUP[1] + request.directDriveTime, possibleArrivalTimePickUP[2] + request.maximumRideTime)

    # Determine feasible arrival times
    arrivalTimeDropOff = (max(possibleArrivalTimeDropOffFromBefore[1],possibleArrivalTimeDropOffFromAfter[1],fromPickToDropTimeWindow[1],request.dropOffActivity.timeWindow.startTime), min(possibleArrivalTimeDropOffFromBefore[2],possibleArrivalTimeDropOffFromAfter[2],fromPickToDropTimeWindow[2],request.dropOffActivity.timeWindow.endTime))
    if arrivalTimeDropOff[2] < arrivalTimeDropOff[1]
        println("Infeasible: Drop off time window")
        return feasible, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, addWaitingActivity
    end

    # determine service windows and shifts
    startOfServiceTimeDropOff = arrivalTimeDropOff[2]
    shiftAfterDropOff = startOfServiceTimeDropOff - (activityAfterDrop.startOfServiceTime - time[request.dropOffActivity.id,activityAfterDrop.activity.id] - serviceTime)
    shiftBetweenPickupAndDropOff = startOfServiceTimeDropOff - (activityBeforeDrop.endOfServiceTime + time[activityBeforeDrop.activity.id,request.dropOffActivity.id])
    startOfServiceTimePickUp = activityAfterPick.startOfServiceTime + shiftBetweenPickupAndDropOff - serviceTime - time[request.pickUpActivity.id,activityAfterPick.activity.id]
    shiftBeforePickUp =-( -startOfServiceTimePickUp + (activityBeforePick.endOfServiceTime + time[activityBeforePick.activity.id,request.pickUpActivity.id]))
    return true, startOfServiceTimePickUp, startOfServiceTimeDropOff, shiftBeforePickUp, shiftBetweenPickupAndDropOff, shiftAfterDropOff, false
end

#==
 Methods to determine maximum shifts
==#
function determineMaximumShiftForward(waitingTimeEnd::Int,scheduleBlock::Vector{ActivityAssignment})
    minimumDifferenceRoute = findmin([a.activity.timeWindow.endTime - a.startOfServiceTime for a in scheduleBlock])[1]
    return min(waitingTimeEnd,minimumDifferenceRoute)
end

function determineMaximumShiftBackward(waitingTimeStart::Int,scheduleBlock::Vector{ActivityAssignment})
    minimumDifferenceRoute = findmin([a.startOfServiceTime - a.activity.timeWindow.startTime for a in scheduleBlock])[1]
    return min(waitingTimeStart,minimumDifferenceRoute)
end

function determinePossibleBeforeShift(waitingTimeStart::Int,scheduleBlock::Vector{ActivityAssignment})
    BUP = min(waitingTimeStart,findmin([a.startOfServiceTime - a.activity.timeWindow.startTime for a in scheduleBlock])[1])
    BDOWN = findmin([a.activity.timeWindow.endTime - a.startOfServiceTime for a in scheduleBlock])[1]
    return BUP,BDOWN
end

function determinePossibleAfterShift(waitingTimeEnd::Int,scheduleBlock::Vector{ActivityAssignment})
    if length(scheduleBlock) == 1 && scheduleBlock[1].activity.activityType == WAITING
        AUP = 1000
    else
        AUP = findmin([a.startOfServiceTime - a.activity.timeWindow.startTime for a in scheduleBlock[1:end-1]])[1]
    end
    ADOWN = min(waitingTimeEnd,findmin([a.activity.timeWindow.endTime - a.startOfServiceTime for a in scheduleBlock])[1])
    return AUP,ADOWN
end

function determinePossibleMiddleShift(BUP::Int,ADOWN::Int,scheduleBlock::Vector{ActivityAssignment})
    CUP = findmin([a.startOfServiceTime - a.activity.timeWindow.startTime for a in scheduleBlock])[1]
    CDOWN = findmin([a.activity.timeWindow.endTime - a.startOfServiceTime for a in scheduleBlock])[1]
    return min(CUP,BUP),min(CDOWN,ADOWN)
end

#==
 Method to find detour  
==#
function findDetour(time::Array{Int,2},serviceTime::Int,activityBefore::Int,activityAfter::Int,activity::Int)
    return time[activityBefore,activity] + time[activity,activityAfter] + serviceTime - time[activityBefore,activityAfter]
end

function findDetour(time::Array{Int,2},serviceTime::Int,activityBefore::Int,activityAfter::Int,pickUpActivity::Int,dropOffActivity::Int)
    return time[activityBefore,pickUpActivity] + time[pickUpActivity,dropOffActivity] + time[dropOffActivity,activityAfter] + 2*serviceTime - time[activityBefore,activityAfter]
end



#== 
 Method to determine maximum shift for MRT constraint
==#
function determineMaximumShiftMRT(scheduleBlock::Vector{ActivityAssignment}, idx::Int, requests::Vector{Request},serviceTime::Int)
    dropoffTimes = Dict{Int, Float64}()  # requestId → dropoff time
    pickupTimes = Dict{Int, Float64}()   # requestId → pickup time (only valid ones)

    # First pass: Collect all dropoffs after idx
    for i in (idx+1):length(scheduleBlock)
        activityAssignment = scheduleBlock[i]
        if activityAssignment.activity.activityType == DROPOFF
            dropoffTimes[activityAssignment.activity.requestId] = activityAssignment.startOfServiceTime
        end
    end

    # Second pass: Collect pickups before idx that have a corresponding dropoff after idx
    for i in 1:idx
        activityAssignment = scheduleBlock[i]
        requestId = activityAssignment.activity.requestId
        if activityAssignment.activity.activityType == PICKUP && haskey(dropoffTimes, requestId)
            pickupTimes[requestId] = activityAssignment.startOfServiceTime
        end
    end
    
    # Determine minimum ride time for each valid pickup
    max_MRT_shift = Inf 
    for (requestId, pickupTime) in pickupTimes
        dropoffTime = dropoffTimes[requestId]
        rideTime = dropoffTime - pickupTime - serviceTime
        # Ensure requestId is valid before accessing
        if requestId ≤ length(requests)
            maxRideTime = requests[requestId].maximumRideTime
            max_MRT_shift = min(max_MRT_shift, maxRideTime - rideTime)
        end
    end

    return max_MRT_shift == Inf ? Inf : max_MRT_shift  # If no valid shifts, return 0
end

function determineMaximumShiftMRT(scheduleBlock::Vector{ActivityAssignment}, idx1::Int, idx2::Int, requests::Vector{Request},serviceTime::Int)
    dropoffTimes = Dict{Int, Float64}()  # requestId → dropoff time
    pickupTimes = Dict{Int, Float64}()   # requestId → pickup time (only valid ones)

    # First pass: Collect all dropoffs after idx
    for i in (idx2+1):length(scheduleBlock)
        activityAssignment = scheduleBlock[i]
        if activityAssignment.activity.activityType == DROPOFF
            dropoffTimes[activityAssignment.activity.requestId] = activityAssignment.startOfServiceTime
        end
    end

    # Second pass: Collect pickups before idx that have a corresponding dropoff after idx
    for i in 1:idx1
        activityAssignment = scheduleBlock[i]
        requestId = activityAssignment.activity.requestId
        if activityAssignment.activity.activityType == PICKUP && haskey(dropoffTimes, requestId)
            pickupTimes[requestId] = activityAssignment.startOfServiceTime
        end
    end
    
    # Determine minimum ride time for each valid pickup
    max_MRT_shift = Inf 
    for (requestId, pickupTime) in pickupTimes
        dropoffTime = dropoffTimes[requestId]
        rideTime = dropoffTime - pickupTime - serviceTime

        # Ensure requestId is valid before accessing
        if requestId ≤ length(requests)
            maxRideTime = requests[requestId].maximumRideTime
            max_MRT_shift = min(max_MRT_shift, maxRideTime - rideTime)
        end
    end

    return max_MRT_shift == Inf ? Inf : max_MRT_shift  # If no valid shifts, return 0
end

end