module RouteUtils 

using UnPack, domain, Printf, ..CostCalculator

export printRoute,printSimpleRoute,insertRequest!,checkFeasibilityOfInsertionAtPosition,printRouteHorizontal,printSolution,updateRoute!,checkFeasibilityOfInsertionInRoute

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

#==
    New insert request 
==#
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,scenario::Scenario,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},waitingActivitiesToDelete::Vector{Int})

    route = vehicleSchedule.route
    vehicle = vehicleSchedule.vehicle

    # Insert request
    insert!(route,idxPickUp+1,ActivityAssignment(request.pickUpActivity,vehicle,0,0))
    insert!(route,idxDropOff+2,ActivityAssignment(request.dropOffActivity,vehicle,0,0))

    # Shift route
    for (i,a) in enumerate(route)
        a.startOfServiceTime = newStartOfServiceTimes[i]
        a.endOfServiceTime = newEndOfServiceTimes[i]

        if a.activity.activityType == WAITING
            a.activity.timeWindow.startTime = newStartOfServiceTimes[i]
            a.activity.timeWindow.endTime = newEndOfServiceTimes[i]
        end
    end

    # Delete waiting activities 
    deleteat!(route,waitingActivitiesToDelete)   

    # Update active time window 
    vehicleSchedule.activeTimeWindow.startTime = route[1].startOfServiceTime
    vehicleSchedule.activeTimeWindow.endTime = route[end].endOfServiceTime

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff,waitingActivitiesToDelete)

    # Update waiting 
    # TODO: stadig brugt? 
   # updateWaiting!(scenario.time,scenario.distance,vehicleSchedule,request,idxPickUp,idxDropOff)

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
# Method to update capacities of vehicle schedule after insertion of request
==#
function updateCapacities!(vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,waitingActivitiesToDelete::Vector{Int} )

    # Update capacities
    beforePickUp = vehicleSchedule.numberOfWalking[idxPickUp]
    beforeDropOff = vehicleSchedule.numberOfWalking[idxDropOff]
    insert!(vehicleSchedule.numberOfWalking,idxPickUp+1,beforePickUp+1)
    insert!(vehicleSchedule.numberOfWalking,idxDropOff+2,beforeDropOff)
    for i in idxPickUp+2:idxDropOff+1
        vehicleSchedule.numberOfWalking[i] = vehicleSchedule.numberOfWalking[i] + 1
    end

    # Delete entries for deleted waiting activities 
    deleteat!(vehicleSchedule.numberOfWalking,waitingActivitiesToDelete)

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
function updateDepots!(time::Array{Int,2}, vehicleSchedule::VehicleSchedule,idxPickUp::Int)
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


function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario)

    @unpack route,numberOfWalking, vehicle = vehicleSchedule
    @unpack time,serviceTimes = scenario

    # Check load 
    if any(numberOfWalking[pickUpIdx:dropOffIdx] .+ 1 .> vehicle.totalCapacity) # TODO: jas - check rigtigt 
        return false, [], [], 0, 0
    end

    # Check times for pick up 
    if route[pickUpIdx].activity.timeWindow.startTime > request.pickUpActivity.timeWindow.endTime || route[pickUpIdx+1].activity.timeWindow.endTime < request.pickUpActivity.timeWindow.startTime
        return false, [], [], 0, 0
    end

    # Check times for drop off
    if route[dropOffIdx].activity.timeWindow.startTime > request.dropOffActivity.timeWindow.endTime || route[dropOffIdx+1].activity.timeWindow.endTime < request.dropOffActivity.timeWindow.startTime
        return false, [], [], 0, 0
    end

    # Retrieve schedule block
    pickUpIdxInBlock = pickUpIdx + 1 # Index as if pickup is inserted 
    dropOffIdxInBlock = dropOffIdx+ 2 # Index as if pickup and dropoff is inserted

    # Check feasibility 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete = checkFeasibilityOfInsertionInRoute(scenario.time,scenario.distance,scenario.serviceTimes,scenario.requests,vehicleSchedule.totalIdleTime,route,pickUpIdxInBlock = pickUpIdxInBlock,dropOffIdxInBlock = dropOffIdxInBlock,request = request)
    
    return  feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete
end


function checkFeasibilityOfInsertionInRoute(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},idleTime::Int,route::Vector{ActivityAssignment}; pickUpIdxInBlock::Int=-1, dropOffIdxInBlock::Int=-1,request::Union{Request,Nothing}=nothing)
    insertRequest = !isnothing(request)
    nActivities = length(route) + 2*insertRequest

    # New service times 
    newStartOfServiceTimes = zeros(Int,nActivities)
    newEndOfServiceTimes = zeros(Int,nActivities)

    # Keep track of waiting activities to delete 
    waitingActivitiesToDelete = Vector{Int}()

    # Keep track of ride times 
    pickUpIndexes = Dict{Int,Int}() # (RequestId, index)

    # Initialize
    currentActivity = route[1].activity
    previousActivity = route[1].activity
    newStartOfServiceTimes[1] = route[1].startOfServiceTime
    newEndOfServiceTimes[1] = route[1].endOfServiceTime 
    newEndOfServiceTimes[end] = route[end].endOfServiceTime

    # Keep track of KPIs 
    totalDistance = 0.0 
    totalIdleTime = 0 
    totalCost = 0

    # Find maximum shift backward and forward
    maximumShiftBackward = route[1].startOfServiceTime - route[1].activity.timeWindow.startTime

    if route[end-1].activity.activityType == WAITING
        maximumShiftForward =  route[end-1].activity.timeWindow.endTime - route[end-1].startOfServiceTime
    elseif length(route) == 2
        maximumShiftForward = route[1].activity.timeWindow.endTime - route[1].activity.timeWindow.startTime
    else
        maximumShiftForward = route[1].startOfServiceTime - route[1].activity.timeWindow.startTime
    end

    # Check if there is room for detour 
    detour = 0 
    if pickUpIdxInBlock == dropOffIdxInBlock - 1
        detour = findDetour(time,serviceTimes,route[pickUpIdxInBlock-1].activity.id,route[pickUpIdxInBlock].activity.id,request.pickUpActivity.id,request.dropOffActivity.id)
    elseif pickUpIdxInBlock != -1 
        detour = findDetour(time,serviceTimes,route[pickUpIdxInBlock-1].activity.id,route[pickUpIdxInBlock].activity.id,request.pickUpActivity.id) + findDetour(time,serviceTimes,route[dropOffIdxInBlock-2].activity.id,route[dropOffIdxInBlock-2].activity.id,request.dropOffActivity.id) 
    end

    if detour > idleTime && detour > maximumShiftBackward + maximumShiftForward
        return false, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete
    end

    # Find new service times 
    idxActivityInSchedule = 1
    for idx in 2:nActivities
        # Find current activity
        if idx == pickUpIdxInBlock
            currentActivity = request.pickUpActivity
        elseif idx == dropOffIdxInBlock
            currentActivity = request.dropOffActivity
        else
            idxActivityInSchedule += 1
            currentActivity = route[idxActivityInSchedule].activity
        end 

        # Check if we skipped one because we removed a waiting activity 
        if newStartOfServiceTimes[idx] != 0 
            requestId = currentActivity.requestId
            if currentActivity.activityType == PICKUP
                pickUpIndexes[requestId] = idx
            elseif currentActivity.activityType == DROPOFF
                if newStartOfServiceTimes[idx] - newEndOfServiceTimes[pickUpIndexes[requestId]] > requests[requestId].maximumRideTime
                    return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete
                end
            end
            previousActivity = currentActivity

            continue
        end

        # Find arrival at current activity
        arrivalAtCurrentActivity = newEndOfServiceTimes[idx-1] + time[previousActivity.id,currentActivity.id] 
    
        # Check if we can remove a waiting activity 
        if currentActivity.activityType == WAITING
            isActivityInSchedule = false
            if idx+1 == pickUpIdxInBlock
                nextActivity = request.pickUpActivity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivity.id,nextActivity.id] 
            elseif idx+1 == dropOffIdxInBlock
                nextActivity = request.dropOffActivity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivity.id,nextActivity.id] 
            else
                isActivityInSchedule = true 
                nextActivity = route[idxActivityInSchedule+1].activity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivity.id,nextActivity.id] 
            end  

            # Check if we can drive from previous activity to activity after waiting 
            feasible, maximumShiftBackwardTrial, maximumShiftForwardTrial = canActivityBeInserted(nextActivity,arrivalAtNextActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)

            # Remove waiting activity 
            if feasible
                #idxActivityInSchedule += isActivityInSchedule
                maximumShiftBackward = maximumShiftBackwardTrial
                maximumShiftForward = maximumShiftForwardTrial

                # Keep track of waiting activities to delete 
                push!(waitingActivitiesToDelete,idx)

                # Give the next activity the service times of the waiting activity
                if idx != nActivities
                    newStartOfServiceTimes[idx+1] = newStartOfServiceTimes[idx]
                    newEndOfServiceTimes[idx+1] = newEndOfServiceTimes[idx]
                end
            # Keep waiting activity     
            else
                feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
                if !feasible
                    return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete
                end

                # Update total idle time 
                totalIdleTime += newEndOfServiceTimes[idx] - newStartOfServiceTimes[idx]
            end
        # Check if activity can be inserted
        else 
            feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
            if !feasible
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete
            end

            # Update total distance 
            totalDistance += distance[previousActivity.id,currentActivity.id]
        end

        # Check maximum ride time 
        requestId = currentActivity.requestId
        if currentActivity.activityType == PICKUP
            pickUpIndexes[requestId] = idx
        elseif currentActivity.activityType == DROPOFF
            if newStartOfServiceTimes[idx] - newEndOfServiceTimes[pickUpIndexes[requestId]] > requests[requestId].maximumRideTime
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete
            end

            totalCost += getCostOfRequest(time,newEndOfServiceTimes[pickUpIndexes[requestId]],newStartOfServiceTimes[idx],requests[requestId].pickUpActivity.id,requests[requestId].dropOffActivity.id)
        end

        # Set current as previous activity
        previousActivity = currentActivity
    end

    # Update total time 
    totalTime = newEndOfServiceTimes[end] - newStartOfServiceTimes[1] 

    return true, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime
end



#== 
 Method to check if activity can be inserted according to previous activity 
==# 
function canActivityBeInserted(currentActivity::Activity,arrivalAtCurrentActivity::Int,maximumShiftBackward::Int,maximumShiftForward::Int,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},serviceTimes::Int,idx::Int)
    if currentActivity.timeWindow.startTime <= arrivalAtCurrentActivity <= currentActivity.timeWindow.endTime 
        # Service times for current activity 
        newStartOfServiceTimes[idx] = arrivalAtCurrentActivity
        newEndOfServiceTimes[idx] = (currentActivity.activityType == DEPOT || currentActivity.activityType == DEPOT) ?  arrivalAtCurrentActivity : arrivalAtCurrentActivity + serviceTimes

        # Update maximum shifts 
        maximumShiftBackward = min(maximumShiftBackward,arrivalAtCurrentActivity - currentActivity.timeWindow.startTime)
        maximumShiftForward = min(maximumShiftForward,currentActivity.timeWindow.endTime - arrivalAtCurrentActivity)

        return true, maximumShiftBackward, maximumShiftForward
    # Check if we can insert next activity by shifting route forward
    elseif arrivalAtCurrentActivity <= currentActivity.timeWindow.startTime  && arrivalAtCurrentActivity + maximumShiftForward >= currentActivity.timeWindow.startTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivity.timeWindow.startTime
        newEndOfServiceTimes[idx] = (currentActivity.activityType == DEPOT || currentActivity.activityType == WAITING) ?  currentActivity.timeWindow.startTime : currentActivity.timeWindow.startTime + serviceTimes

        # Determine shift 
        shift = currentActivity.timeWindow.startTime - arrivalAtCurrentActivity

        # Update maximum shifts
        maximumShiftBackward = 0
        maximumShiftForward = min(maximumShiftForward - shift,currentActivity.timeWindow.endTime - currentActivity.timeWindow.startTime)

        # Update service times for previous activities 
        for i in 1:(idx-1)
            newStartOfServiceTimes[i] += shift
            newEndOfServiceTimes[i] += shift
        end

        return true, maximumShiftBackward, maximumShiftForward

    # Check if we can insert next activity be shifting route backwards 
    elseif  arrivalAtCurrentActivity >= currentActivity.timeWindow.endTime &&  arrivalAtCurrentActivity - maximumShiftBackward <= currentActivity.timeWindow.endTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivity.timeWindow.endTime
        newEndOfServiceTimes[idx] = (currentActivity.activityType == DEPOT || currentActivity.activityType == WAITING) ?  currentActivity.timeWindow.endTime : currentActivity.timeWindow.endTime + serviceTimes

        # Determine shift
        shift = arrivalAtCurrentActivity - currentActivity.timeWindow.endTime

        # Update maximum shifts
        maximumShiftBackward = min(maximumShiftBackward - shift ,currentActivity.timeWindow.endTime - currentActivity.timeWindow.startTime)
        maximumShiftForward = 0

        # Update service times for previous activities 
        for i in 1:(idx-1)
            newStartOfServiceTimes[i] -= shift
            newEndOfServiceTimes[i] -= shift
        end

        return true, maximumShiftBackward, maximumShiftForward
    else
        return false, -1, -1
    end
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


end
