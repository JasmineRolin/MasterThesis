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
    println("| Step | Activity Type |  Id |  Location  | Start/End Service | Time Window | Load |")
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

function printSimpleRoute(route::Vector{ActivityAssignment})    
    route_ids = [assignment.activity.id for assignment in route]
    
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
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,scenario::Scenario,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},waitingActivitiesToDelete::Vector{Int};totalCost::Float64=-1.0,totalDistance::Float64=-1.0,totalIdleTime::Int=-1,totalTime::Int=-1,visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())

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

    # Update KPIs 
    if totalCost != -1 
        vehicleSchedule.totalCost = totalCost
        vehicleSchedule.totalDistance = totalDistance
        vehicleSchedule.totalIdleTime = totalIdleTime
        vehicleSchedule.totalTime = totalTime
    else
        # Update idle time 
        vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route)

        # Update total time 
        vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow)

        # Update total cost
        vehicleSchedule.totalCost = getTotalCostRouteOnline(scenario.time,route,visitedRoute,scenario.serviceTimes)

        #Update total distance
        vehicleSchedule.totalDistance = getTotalDistanceRoute(route,scenario.distance)
    end
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
 Method to check if it is feasible to insert a request in a vehicle schedule
==#
function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario;visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())

    @unpack route,numberOfWalking, vehicle = vehicleSchedule
    @unpack time,serviceTimes = scenario

    # Check load 
    if any(numberOfWalking[pickUpIdx:dropOffIdx] .+ 1 .> vehicle.totalCapacity) 
        return false, [], [], [],0.0,0.0,0,0
    end

    # Check times for pick up 
    if route[pickUpIdx].activity.timeWindow.startTime > request.pickUpActivity.timeWindow.endTime || route[pickUpIdx+1].activity.timeWindow.endTime < request.pickUpActivity.timeWindow.startTime
        return false, [], [], [],0.0,0.0,0,0
    end

    # Check times for drop off
    if route[dropOffIdx].activity.timeWindow.startTime > request.dropOffActivity.timeWindow.endTime || route[dropOffIdx+1].activity.timeWindow.endTime < request.dropOffActivity.timeWindow.startTime
        return false, [], [], [],0.0,0.0,0,0
    end

    # Retrieve schedule block
    pickUpIdxInBlock = pickUpIdx + 1 # Index as if pickup is inserted 
    dropOffIdxInBlock = dropOffIdx+ 2 # Index as if pickup and dropoff is inserted

    # Check feasibility 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete,totalCost, totalDistance, totalIdleTime, totalTime = checkFeasibilityOfInsertionInRoute(scenario.time,scenario.distance,scenario.serviceTimes,scenario.requests,vehicleSchedule.totalIdleTime,route,pickUpIdxInBlock = pickUpIdxInBlock,dropOffIdxInBlock = dropOffIdxInBlock,request = request,visitedRoute=visitedRoute)
    
    return  feasible, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime
end

#==
 Method to check if it is feasible to insert request in route 
==#
# If pickUpIdxInBlock = dropOffIdxInBlock = -1 we are not inserting a request in route but repairing a route where some request has been removed 
function checkFeasibilityOfInsertionInRoute(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},idleTime::Int,route::Vector{ActivityAssignment}; pickUpIdxInBlock::Int=-1, dropOffIdxInBlock::Int=-1,request::Union{Request,Nothing}=nothing,visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}())  
    insertRequest = !isnothing(request)
    nActivities = length(route) + 2*insertRequest
    visitedRouteIds = keys(visitedRoute)

    # New service times 
    newStartOfServiceTimes = zeros(Int,nActivities)
    newEndOfServiceTimes = zeros(Int,nActivities)

    # Keep track of waiting activities to delete 
    waitingActivitiesToDelete = Vector{Int}()
    waitingActivitiesToDeleteId = Vector{Int}()
    waitingActivitiesToKeep = Vector{Int}() # Keep track of waiting activities to keep

    # Keep track of ride times 
    pickUpIndexes = Dict{Int,Int}() # (RequestId, index)

    # Initialize
    currentActivity = route[1].activity
    previousActivity = route[1].activity
    newStartOfServiceTimes[1] = route[1].startOfServiceTime
    newEndOfServiceTimes[1] = route[1].endOfServiceTime ### Spørg Jasmine: Hvorfor kan den ikke ændres fx hvis det er en witing node?
    #newEndOfServiceTimes[end] = route[end].endOfServiceTime

    # Keep track of KPIs 
    totalDistance = 0.0 
    totalIdleTime = 0 
    totalCost = 0

    # Check first activity in route
    if route[1].activity.activityType == PICKUP
        pickUpIndexes[route[1].activity.requestId] = 1
    elseif route[1].activity.activityType == DROPOFF
        requestId = route[1].activity.requestId
        totalCost += getCostOfRequest(time,visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes,route[1].startOfServiceTime,requestId,route[1].activity.id)
    elseif route[1].activity.activityType == WAITING
        totalIdleTime = route[1].endOfServiceTime - route[1].startOfServiceTime
    end
    
    # Find maximum shift backward and forward
    if route[1].activity.activityType == WAITING || route[1].activity.activityType == DEPOT
        maximumShiftBackward = route[1].startOfServiceTime - route[1].activity.timeWindow.startTime
    else
        maximumShiftBackward = 0
    end

    if route[1].activity.activityType == DROPOFF || route[1].activity.activityType == PICKUP 
        maximumShiftForward = 0
    elseif route[end-1].activity.activityType == WAITING && length(route) != 2 # Waiting activity but not in route with only [waiting,depot]
        maximumShiftForward =  route[end-1].activity.timeWindow.endTime - route[end-1].startOfServiceTime
    elseif length(route) == 2 && route[1].activity.activityType == DEPOT && route[2].activity.activityType == DEPOT # EMpty route 
        maximumShiftForward = route[1].activity.timeWindow.endTime - route[1].activity.timeWindow.startTime
    else # Depot but non-empty route or [waiting,depot]
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
        return false, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0
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

        # Check if we skipped an activity because we removed a waiting activity
        if newStartOfServiceTimes[idx] != 0 
            requestId = currentActivity.requestId
            if currentActivity.activityType == PICKUP
                pickUpIndexes[requestId] = idx
            elseif currentActivity.activityType == DROPOFF
                newEndOfServiceTimePickUp = requestId in visitedRouteIds ? visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes : newEndOfServiceTimes[pickUpIndexes[requestId]]

                if newStartOfServiceTimes[idx] - newEndOfServiceTimePickUp > requests[requestId].maximumRideTime
                    return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0
                end

                # Update total cost
                totalCost += getCostOfRequest(time,newEndOfServiceTimePickUp,newStartOfServiceTimes[idx],requests[requestId].pickUpActivity.id,requests[requestId].dropOffActivity.id)
            end

            # Set previous as current activity
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
                push!(waitingActivitiesToDeleteId, currentActivity.id)

                # Give the next activity the service times of the waiting activity
                if idx != nActivities
                    newStartOfServiceTimes[idx+1] = newStartOfServiceTimes[idx]
                    newEndOfServiceTimes[idx+1] = newEndOfServiceTimes[idx]
                end

                # Update total distance 
                totalDistance += distance[previousActivity.id,nextActivity.id]

            # Keep waiting activity     
            else
                # Check if we can minimize waiting node
                # earliestArrivalFromCurrent = currentActivity.startOfServiceTime + time[currentActivity.id,nextActivity.id]
                # latestArrival = currentActivity.endOfServiceTime + time[previousActivity.id,nextActivity.id]
                # earliestArrival= max(earliestArrivalFromCurrent,nextActivity.timeWindow.startTime)
                
                # if earliestArrival < latestArrival && earliestArrival < nextActivity.timeWindow.endTime 
                #     newEndOfServiceTimes[idx] = earliestArrival - time[currentActivity.id,nextActivity.id]
                #     newStartOfServiceTimes[idx] = currentActivity.timeWindow.startTime
                #     totalIdleTime += newEndOfServiceTimes[idx] - newStartOfServiceTimes[idx]
                #     totalDistance += distance[previousActivity.id,currentActivity.id]

                #     push!(waitingActivitiesToKeep,currentActivity.id)
               # else
                    # Keep waiting activity byt try to shift route
                    feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
                    if !feasible
                        return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0
                    end

                    # Update total idle time 
                    totalIdleTime += newEndOfServiceTimes[idx] - newStartOfServiceTimes[idx]
                    totalDistance += distance[previousActivity.id,currentActivity.id]
                    push!(waitingActivitiesToKeep,currentActivity.id)
              #  end
              
            end
        # Check if activity can be inserted
        else 
            feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
            if !feasible
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0
            end

            # Update total distance 
            totalDistance += distance[previousActivity.id,currentActivity.id]
        end

        # Check maximum ride time 
        requestId = currentActivity.requestId
        if currentActivity.activityType == PICKUP
            pickUpIndexes[requestId] = idx
        elseif currentActivity.activityType == DROPOFF
            newEndOfServiceTimePickUp = requestId in visitedRouteIds ? visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes : newEndOfServiceTimes[pickUpIndexes[requestId]]
            if newStartOfServiceTimes[idx] - newEndOfServiceTimePickUp > requests[requestId].maximumRideTime
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0
            end

            # Update total cost
            totalCost += getCostOfRequest(time,newEndOfServiceTimePickUp,newStartOfServiceTimes[idx],requests[requestId].pickUpActivity.id,requests[requestId].dropOffActivity.id)
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
        if currentActivity.activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif currentActivity.activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivity.timeWindow.endTime 
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

        # Update maximum shifts 
        maximumShiftBackward = min(maximumShiftBackward,arrivalAtCurrentActivity - currentActivity.timeWindow.startTime)
        maximumShiftForward = min(maximumShiftForward,currentActivity.timeWindow.endTime - arrivalAtCurrentActivity)

        return true, maximumShiftBackward, maximumShiftForward
    # Check if we can insert next activity by shifting route forward
    elseif arrivalAtCurrentActivity < currentActivity.timeWindow.startTime  && arrivalAtCurrentActivity + maximumShiftForward >= currentActivity.timeWindow.startTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivity.timeWindow.startTime
        if currentActivity.activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif currentActivity.activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivity.timeWindow.endTime 
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

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
    elseif  arrivalAtCurrentActivity > currentActivity.timeWindow.endTime &&  arrivalAtCurrentActivity - maximumShiftBackward <= currentActivity.timeWindow.endTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivity.timeWindow.endTime
        if currentActivity.activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif currentActivity.activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivity.timeWindow.endTime 
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

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
