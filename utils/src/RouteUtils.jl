module RouteUtils 

using UnPack, domain, Printf, ..CostCalculator, TimerOutputs

export printRoute,printSimpleRoute,insertRequest!,checkFeasibilityOfInsertionAtPosition,printRouteHorizontal,printSolution,updateRoute!,checkFeasibilityOfInsertionInRoute
export insertWaiting!, feasibleWhenInsertWaiting!

const INFEASIBLE_RESULT = (false, Any[], Any[], Any[], 0.0, 0.0, 0, 0, Any[], false, false, false)
const INFEASIBLE_ROUTE_PICKUP = (false, Any[], Any[], Any[], 0.0, 0.0, 0, 0, Any[], true, true, false)
const INFEASIBLE_ROUTE_DROPOFF = (false, Any[], Any[], Any[], 0.0, 0.0, 0, 0, Any[], false, true, false)
const INFEASIBLE_ROUTE__DROPOFF_FOREVER = (false, Any[], Any[], Any[], 0.0, 0.0, 0, 0, Any[], false, true, true)


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
function insertRequest!(request::Request,vehicleSchedule::VehicleSchedule,idxPickUp::Int,idxDropOff::Int,scenario::Scenario,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},waitingActivitiesToDelete::Vector{Int};totalCost::Float64=-1.0,totalDistance::Float64=-1.0,totalIdleTime::Int=-1,totalTime::Int=-1,visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(),waitingActivitiesToAdd::Vector{Int} = Vector{Int}())
    time = scenario.time
    distance = scenario.distance
    route = vehicleSchedule.route
    vehicle = vehicleSchedule.vehicle
    nActivities = length(route) + 2


    # Insert request
    insert!(route,idxPickUp+1,ActivityAssignment(request.pickUpActivity,vehicle,0,0))
    insert!(route,idxDropOff+2,ActivityAssignment(request.dropOffActivity,vehicle,0,0))

    # Shift route
    for (i,a) in enumerate(route)
        a.startOfServiceTime = newStartOfServiceTimes[i]
        a.endOfServiceTime = newEndOfServiceTimes[i]

        # Update waiting activities if it should not be deleted
        if a.activity.activityType == WAITING && !(i in waitingActivitiesToDelete)
            # Check if waiting activity follows wait first 
            if (i != 1) && (i != (nActivities-1)) && (a.activity.id != route[i-1].activity.id)
                activityAssignmentBefore = route[i-1]
                activityAssignmentAfter = route[i+1]

                oldDistance = distance[activityAssignmentBefore.activity.id,a.activity.id] + distance[a.activity.id,activityAssignmentAfter.activity.id]
                oldIdleTime = newEndOfServiceTimes[i] - newStartOfServiceTimes[i]

                startOfWaiting = newEndOfServiceTimes[i-1]
                endOfWaiting = newStartOfServiceTimes[i+1] - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

                # Is it feasible to change to wait first 
                if startOfWaiting > endOfWaiting
                    a.activity.timeWindow.startTime = newStartOfServiceTimes[i]
                    a.activity.timeWindow.endTime = newEndOfServiceTimes[i]    
                    continue
                end

                # Update waiting activity
                a.startOfServiceTime = startOfWaiting
                a.endOfServiceTime = endOfWaiting
                a.activity.timeWindow.startTime = startOfWaiting
                a.activity.timeWindow.endTime = endOfWaiting

                a.activity.id = activityAssignmentBefore.activity.id
                a.activity.location = activityAssignmentBefore.activity.location

                # Update KPIs 
                newDistance = distance[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
                totalDistance -= oldDistance
                totalDistance += newDistance

                newIdleTime = endOfWaiting - startOfWaiting
                totalIdleTime -= oldIdleTime
                totalIdleTime += newIdleTime
            else
                a.activity.timeWindow.startTime = newStartOfServiceTimes[i]
                a.activity.timeWindow.endTime = newEndOfServiceTimes[i]    
            end
        end
    end

    # Delete waiting activities 
    deleteat!(route,waitingActivitiesToDelete)   

    # Update active time window 
    vehicleSchedule.activeTimeWindow.startTime = route[1].startOfServiceTime
    vehicleSchedule.activeTimeWindow.endTime = route[end].endOfServiceTime

    # Update capacities
    updateCapacities!(vehicleSchedule,idxPickUp,idxDropOff,waitingActivitiesToDelete)

    # Update newStartOfServiceTimes and newEndOfServiceTimes
    deleteat!(newStartOfServiceTimes,waitingActivitiesToDelete) 
    deleteat!(newEndOfServiceTimes,waitingActivitiesToDelete)

    # Add waiting nodes 
    if length(waitingActivitiesToAdd) > 0
        insertWaiting!(waitingActivitiesToAdd, waitingActivitiesToDelete,vehicleSchedule,scenario,newStartOfServiceTimes,newEndOfServiceTimes)
    end

    # Update KPIs 
    if totalCost != -1 && length(waitingActivitiesToAdd) == 0
        vehicleSchedule.totalCost = totalCost
        vehicleSchedule.totalDistance = totalDistance
        vehicleSchedule.totalIdleTime = getTotalIdleTimeRoute(vehicleSchedule.route) #totalIdleTime TODO correct delta calculations
        vehicleSchedule.totalTime = duration(vehicleSchedule.activeTimeWindow) # totalTime TODO correct delta calculations
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


function insertWaiting!(waitingActivitiesToAdd::Vector{Int}, waitingActivitiesToDelete::Vector{Int},vehicleSchedule::VehicleSchedule,scenario::Scenario,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int})
    route = vehicleSchedule.route
    numberOfAdded = 0
    for idx in waitingActivitiesToAdd

        # Get correct index
        countBefore = count(i -> i < idx, waitingActivitiesToDelete)
        corr_idx = idx - countBefore + numberOfAdded

        # Insert waiting activity
        startOfServiceTime = newEndOfServiceTimes[corr_idx-1]
        endOfServiceTime = newStartOfServiceTimes[corr_idx] - scenario.time[route[corr_idx-1].activity.id,route[corr_idx].activity.id]

        if startOfServiceTime < endOfServiceTime
            waitingActivity = Activity(route[corr_idx-1].activity.id,-1,WAITING,vehicleSchedule.route[corr_idx-1].activity.location,TimeWindow(startOfServiceTime,endOfServiceTime))
            insert!(vehicleSchedule.route,corr_idx,ActivityAssignment(waitingActivity,vehicleSchedule.vehicle,startOfServiceTime,endOfServiceTime))
            insert!(newStartOfServiceTimes,corr_idx,startOfServiceTime)
            insert!(newEndOfServiceTimes,corr_idx,endOfServiceTime)
            insert!(vehicleSchedule.numberOfWalking,corr_idx,vehicleSchedule.numberOfWalking[corr_idx-1])

            # Update KPIs
            vehicleSchedule.totalIdleTime += endOfServiceTime - startOfServiceTime
            vehicleSchedule.totalTime += endOfServiceTime - startOfServiceTime

            numberOfAdded += 1
        end

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

function checkFeasibilityOfInsertionAtPosition(request::Request, vehicleSchedule::VehicleSchedule,pickUpIdx::Int,dropOffIdx::Int,scenario::Scenario;
    visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(), TO::TimerOutput=TimerOutput(),
    newStartOfServiceTimes::Vector{Int} = Vector{Int}(),newEndOfServiceTimes::Vector{Int} = Vector{Int}(),waitingActivitiesToDelete::Vector{Int} = Vector{Int}(),waitingActivitiesToAdd::Vector{Int} = Vector{Int}(),visitedRouteIds::Set{Int}=Set{Int}())

    @unpack route,numberOfWalking, vehicle = vehicleSchedule
    @unpack time, distance,serviceTimes,requests = scenario

    # Make sure that arrays are correct size 
    if isempty(newStartOfServiceTimes) 
        nActivities = length(route) + 2 # Assuming this is only called from here when inserting a request
        resize!(newStartOfServiceTimes, nActivities)
        resize!(newEndOfServiceTimes, nActivities)
        fill!(newStartOfServiceTimes, 0)
        fill!(newEndOfServiceTimes, 0)
    end

   # @timeit TO "CheckHighLevelConstraints" begin
        pickUpActivity = request.pickUpActivity
        dropOffActivity = request.dropOffActivity
        pickUpStartTime = pickUpActivity.timeWindow.startTime
        pickUpEndTime = pickUpActivity.timeWindow.endTime
        dropOffStartTime = dropOffActivity.timeWindow.startTime
        dropOffEndTime = dropOffActivity.timeWindow.endTime

        # TODO: lav lige et dobbelt check med astrid 
        if route[pickUpIdx+1].activity.timeWindow.endTime < pickUpStartTime 
            return INFEASIBLE_ROUTE_DROPOFF
        end

        if route[pickUpIdx].activity.timeWindow.startTime > pickUpEndTime 
            return INFEASIBLE_ROUTE_PICKUP
        end

        if route[dropOffIdx+1].activity.timeWindow.endTime < dropOffStartTime
            return INFEASIBLE_RESULT
        end

        if route[dropOffIdx].activity.timeWindow.startTime > dropOffEndTime
            return INFEASIBLE_ROUTE__DROPOFF_FOREVER
        end

        @views for i in pickUpIdx:dropOffIdx
            if numberOfWalking[i] + 1 > vehicle.totalCapacity
                return INFEASIBLE_ROUTE_DROPOFF
            end
        end

     #   println("AFTER CHECK HIGH LEVEL CONSTRAINTS")
   # end

    pickUpIdxInBlock = pickUpIdx + 1
    dropOffIdxInBlock = dropOffIdx + 2

    return @timeit TO "CallCheckFeasibilityOfInsertionInRoute" begin
        checkFeasibilityOfInsertionInRoute(time,distance,serviceTimes,requests,vehicleSchedule.totalIdleTime,vehicleSchedule,
        newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToDelete,waitingActivitiesToAdd,
                                           pickUpIdxInBlock = pickUpIdxInBlock, dropOffIdxInBlock = dropOffIdxInBlock, request = request, visitedRoute=visitedRoute, TO=TO,visitedRouteIds=visitedRouteIds)
    end

end

#==
 Method to check if it is feasible to insert request in route 
==#
# If pickUpIdxInBlock = dropOffIdxInBlock = -1 we are not inserting a request in route but repairing a route where some request has been removed 
function checkFeasibilityOfInsertionInRoute(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},idleTime::Int,vehicleSchedule::VehicleSchedule,
     newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},waitingActivitiesToDelete::Vector{Int},waitingActivitiesToAdd::Vector{Int};
     pickUpIdxInBlock::Int=-1, dropOffIdxInBlock::Int=-1,request::Union{Request,Nothing}=nothing,visitedRoute::Dict{Int, Dict{String, Int}}= Dict{Int, Dict{String, Int}}(), state::String = "Repair",TO::TimerOutput=TimerOutput(),visitedRouteIds::Set{Int}=Set{Int}()) 
   
    # Initialize 
    route = vehicleSchedule.route
    insertRequest = !isnothing(request)
    routeLength = length(route)
    nActivities = routeLength + 2*insertRequest
    if isempty(visitedRouteIds)
        visitedRouteIds = Set(keys(visitedRoute))
    end
    pickUpActivity = insertRequest ? request.pickUpActivity : nothing 
    dropOffActivity = insertRequest ? request.dropOffActivity : nothing 
    firstActivity = route[1]

    # New service times - assuming that the size is correct
    fill!(newStartOfServiceTimes, 0)
    fill!(newEndOfServiceTimes, 0)

    # Keep track of waiting activities to delete 
    resize!(waitingActivitiesToDelete, 0)
    resize!(waitingActivitiesToAdd, 0)

    # Keep track of ride times 
    pickUpIndexes = Dict{Int,Int}() # (RequestId, index)

    # Initialize
    currentActivity = firstActivity.activity
    previousActivity = firstActivity.activity
    newStartOfServiceTimes[1] = firstActivity.startOfServiceTime
    newEndOfServiceTimes[1] = firstActivity.endOfServiceTime ### Spørg Jasmine: Hvorfor kan den ikke ændres fx hvis det er en witing node?

    # Keep track of KPIs 
    totalDistance = 0.0 
    totalIdleTime = 0 
    totalCost = 0.0

    # Check first activity in route
    if firstActivity.activity.activityType == PICKUP
        pickUpIndexes[firstActivity.activity.requestId] = 1
    elseif firstActivity.activity.activityType == DROPOFF
        requestId = firstActivity.activity.requestId
        totalCost += getCostOfRequest(time,visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes,firstActivity.startOfServiceTime,requestId,firstActivity.activity.id)
    elseif firstActivity.activity.activityType == WAITING
        totalIdleTime = firstActivity.endOfServiceTime - firstActivity.startOfServiceTime
    end
    
    # Find maximum shift backward and forward
    if firstActivity.activity.activityType == WAITING 
        maximumShiftBackward = firstActivity.endOfServiceTime - firstActivity.startOfServiceTime
        maximumShiftForward = vehicleSchedule.vehicle.availableTimeWindow.endTime - firstActivity.endOfServiceTime

    elseif firstActivity.activity.activityType == DEPOT
        maximumShiftBackward = firstActivity.startOfServiceTime - firstActivity.activity.timeWindow.startTime
        maximumShiftForward = firstActivity.activity.timeWindow.endTime - firstActivity.startOfServiceTime
    else
        maximumShiftBackward = 0
        maximumShiftForward = 0
    end

    # Check if there is room for detour 
    detour = 0 
    if pickUpIdxInBlock == dropOffIdxInBlock - 1
        detour = findDetour(time,serviceTimes,route[pickUpIdxInBlock-1].activity.id,route[pickUpIdxInBlock].activity.id,pickUpActivity.id,dropOffActivity.id)
    elseif pickUpIdxInBlock != -1 
        detour = findDetour(time,serviceTimes,route[pickUpIdxInBlock-1].activity.id,route[pickUpIdxInBlock].activity.id,pickUpActivity.id) + findDetour(time,serviceTimes,route[dropOffIdxInBlock-2].activity.id,route[dropOffIdxInBlock-2].activity.id,dropOffActivity.id) 
    end



    # Detour just has to be "swallowed" by time in start and end 
    slackTime = 0

    # Empty route 
    if length(route) == 2 && firstActivity.activity.activityType == DEPOT && route[end].activity.activityType == DEPOT
        slackTime = vehicleSchedule.vehicle.availableTimeWindow.endTime - firstActivity.activity.timeWindow.startTime
    # Depots have to swallow detour 
    else
        slackTime = route[end].activity.timeWindow.endTime - route[end].startOfServiceTime
        if firstActivity.activity.activityType == DEPOT
            slackTime += firstActivity.startOfServiceTime - firstActivity.activity.timeWindow.startTime
        end
    end
    if detour > idleTime + slackTime    
        return false, newStartOfServiceTimes, newEndOfServiceTimes, waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0, waitingActivitiesToAdd, false, false, false
    end

    # Keep track of requests that are partially in route, i.e. pick-up is in visited route 
    requestsWithVisitedPickUp = Vector{Tuple{Int,Int}}() # Save (requestId,dropOffIdx)

    # Find new service times 
    idxActivityInSchedule = 1
    for idx in 2:nActivities
        # Find current activity
        if idx == pickUpIdxInBlock
            currentActivity = pickUpActivity
        elseif idx == dropOffIdxInBlock
            currentActivity = dropOffActivity
        else
            idxActivityInSchedule += 1
            currentActivity = route[idxActivityInSchedule].activity
        end 
        activityType = currentActivity.activityType
        currentActivityId = currentActivity.id
        previousActivityId = previousActivity.id

        # Check if we skipped an activity because we removed a waiting activity
        if newStartOfServiceTimes[idx] != 0 
            # Check maximum ride time and calculate cost 
            feasible, totalCost, maximumShiftForward = checkMaximumRideTimeAndUpdateCost(time,serviceTimes,requests,currentActivity,activityType,idx,newStartOfServiceTimes,newEndOfServiceTimes,maximumShiftForward,totalCost,pickUpIndexes,visitedRouteIds,visitedRoute,requestsWithVisitedPickUp)

            if !feasible
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0, waitingActivitiesToAdd, false, false, false
            end

            # Set previous as current activity
            previousActivity = currentActivity
            continue
        end

        # Find arrival at current activity
        arrivalAtCurrentActivity = newEndOfServiceTimes[idx-1] + time[previousActivityId,currentActivityId] 
    
        # Check if we can remove a waiting activity 
        if activityType == WAITING
            if idx+1 == pickUpIdxInBlock
                nextActivity = pickUpActivity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivityId,nextActivity.id] 
            elseif idx+1 == dropOffIdxInBlock
                nextActivity = dropOffActivity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivityId,nextActivity.id] 
            else
                nextActivity = route[idxActivityInSchedule+1].activity
                arrivalAtNextActivity = newEndOfServiceTimes[idx-1] + time[previousActivityId,nextActivity.id] 
            end  


            # Check if we can drive from previous activity to activity after waiting 
            if idx == nActivities-1 
                feasible = false
            else
                feasible, maximumShiftBackwardTrial, maximumShiftForwardTrial = canActivityBeInserted(firstActivity.activity,nextActivity,arrivalAtNextActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
            end


            # Remove waiting activity 
            if feasible

                maximumShiftBackward = maximumShiftBackwardTrial
                maximumShiftForward = maximumShiftForwardTrial

                # Keep track of waiting activities to delete 
                push!(waitingActivitiesToDelete,idx)

                # Give the next activity the service times of the waiting activity Astrid Here
                if idx != nActivities
                    newStartOfServiceTimes[idx+1] = newStartOfServiceTimes[idx]
                    newEndOfServiceTimes[idx+1] = newEndOfServiceTimes[idx]
                end

                # Update total distance 
                totalDistance += distance[previousActivityId,nextActivity.id]

            # Keep waiting activity     
            else

                # Check if we can minimize waiting node
                earliestArrivalFromCurrent = newEndOfServiceTimes[idx-1] + time[previousActivityId,currentActivityId] + time[currentActivityId,nextActivity.id]
                latestArrival = currentActivity.timeWindow.endTime + time[currentActivityId,nextActivity.id]
                earliestArrival= max(earliestArrivalFromCurrent,nextActivity.timeWindow.startTime)
                
                if earliestArrival < latestArrival && earliestArrival <= nextActivity.timeWindow.endTime 
                    newEndOfServiceTimes[idx] = earliestArrival - time[currentActivityId,nextActivity.id]
                    newStartOfServiceTimes[idx] = newEndOfServiceTimes[idx-1] + time[previousActivityId,currentActivityId]
                    totalIdleTime += newEndOfServiceTimes[idx] - newStartOfServiceTimes[idx]
                    totalDistance += distance[previousActivityId,currentActivityId]
                else
                    # Keep waiting activity but try to shift route
                    feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(firstActivity.activity,currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)

                    if !feasible
                        return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0, waitingActivitiesToAdd, false, false, false
                    end

                    # Update total idle time 
                    totalIdleTime += newEndOfServiceTimes[idx] - newStartOfServiceTimes[idx]
                    totalDistance += distance[previousActivityId,currentActivityId]
                end
            
            end
        # Check if activity can be inserted
        else 
            feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(firstActivity.activity,currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)

            # Check if can insert by inserting waiting activity 
            if state == "Repair" && !feasible && idx <= routeLength

                # Extend waiting 
                if previousActivity.activityType == WAITING 
                    endOfWaitingActivity = currentActivity.timeWindow.startTime - time[previousActivity.id,currentActivityId]
                    newEndOfServiceTimes[idx-1] = endOfWaitingActivity

                    feasible, maximumShiftBackward, maximumShiftForward = canActivityBeInserted(firstActivity.activity,currentActivity,arrivalAtCurrentActivity,maximumShiftBackward,maximumShiftForward,newStartOfServiceTimes,newEndOfServiceTimes,serviceTimes,idx)
                # Attempt to insert waiting activity
                else
                    feasible, maximumShiftBackward, maximumShiftForward = feasibleWhenInsertWaiting!(time,requests,serviceTimes,currentActivity,activityType,previousActivity,vehicleSchedule,idx,newStartOfServiceTimes,newEndOfServiceTimes,waitingActivitiesToAdd,maximumShiftBackward, maximumShiftForward)                        
                end
            end
            
            if !feasible
                # No possible way to insert it
                return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0, waitingActivitiesToAdd, false, false, false
            end

            # Update total distance 
            totalDistance += distance[previousActivityId,currentActivityId]
        end

        # Check maximum ride time and calculate cost  
        feasible, totalCost, maximumShiftForward = checkMaximumRideTimeAndUpdateCost(time,serviceTimes,requests,currentActivity,activityType,idx,newStartOfServiceTimes,newEndOfServiceTimes,maximumShiftForward,totalCost,pickUpIndexes,visitedRouteIds,visitedRoute,requestsWithVisitedPickUp)

        if !feasible
            return false, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, 0, waitingActivitiesToAdd, false, false, false
        end

        # Set current as previous activity
        previousActivity = currentActivity
    end

    # Update total time 
    totalTime = newEndOfServiceTimes[end] - newStartOfServiceTimes[1]

    # Calculate cost of requests that are only partially contained in route 
    for (requestId,dropoffIdx) in requestsWithVisitedPickUp
        r = requests[requestId]
        newEndOfServiceTimePickUp = visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes

        totalCost += getCostOfRequest(time,newEndOfServiceTimePickUp,newStartOfServiceTimes[dropoffIdx], r.pickUpActivity.id, r.dropOffActivity.id)
    end

    return true, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete, totalCost, totalDistance, totalIdleTime, totalTime, waitingActivitiesToAdd, false, false, false
end

#==
Method to check if it is feasible to insert a waiting activity
==#
function feasibleWhenInsertWaiting!(time::Array{Int,2},requests::Vector{Request},serviceTimes::Int,currentActivity::Activity,currentActivityType::ActivityType,previousActivity::Activity,vehicleSchedule::VehicleSchedule,idx::Int,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},waitingActivitiesToAdd::Vector{Int},maximumShiftBackward::Int,maximumShiftForward::Int)
    previousId = previousActivity.id
    currentId = currentActivity.id
    requestId = currentActivity.requestId
    currentRequest = requests[requestId]
    currentActivityStartTime = currentActivity.timeWindow.startTime

   
    # If it is a pick-up activity and pickup request or drop off activity we insert at start of time window
    if  (currentActivityType == PICKUP && requests[currentActivity.requestId].requestType == PICKUP_REQUEST)  ||  currentActivityType == DROPOFF
        newStartOfServiceTimesPickUp = currentActivityStartTime
        newEndOfServiceTimesPickUp = newStartOfServiceTimesPickUp + serviceTimes
    # If it is a pick-up activity and drop off request we ensure that we can drive directly to drop off activity 
    else currentActivityType == PICKUP && requests[currentActivity.requestId].requestType == DROPOFF_REQUEST
        newStartOfServiceTimesPickUp = currentRequest.dropOffActivity.timeWindow.startTime - time[currentRequest.pickUpActivity.id,currentRequest.dropOffActivity.id] 
        newEndOfServiceTimesPickUp = newStartOfServiceTimesPickUp + serviceTimes
    end

    # Waiting service times 
    newStartOfServiceTimeWaiting = newEndOfServiceTimes[idx-1]
    newEndOfServiceTimeWaiting = newStartOfServiceTimesPickUp - time[previousId,currentId]

    # Update service times
    newEndOfServiceTimes[idx] = newEndOfServiceTimesPickUp
    newStartOfServiceTimes[idx] = newStartOfServiceTimesPickUp

    # Update maximum shifts 
    maximumShiftBackward = min(maximumShiftBackward,newStartOfServiceTimesPickUp - currentActivityStartTime)
    maximumShiftForward = min(maximumShiftForward,currentActivity.timeWindow.endTime - newStartOfServiceTimesPickUp)

    # Check that insertion times are feasible 
    if newEndOfServiceTimes[idx] + time[currentId,vehicleSchedule.vehicle.id] < vehicleSchedule.vehicle.availableTimeWindow.endTime && newStartOfServiceTimeWaiting < newEndOfServiceTimeWaiting
        push!(waitingActivitiesToAdd,idx)
        return true, maximumShiftBackward, maximumShiftForward
    else
        return false, 0, 0
    end

end



#== 
 Method to check if activity can be inserted according to previous activity 
==# 
function canActivityBeInserted(firstActivity::Activity,currentActivity::Activity,arrivalAtCurrentActivity::Int,maximumShiftBackward::Int,maximumShiftForward::Int,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},serviceTimes::Int,idx::Int)
    currentActivityStartTime = currentActivity.timeWindow.startTime
    currentActivityEndTime = currentActivity.timeWindow.endTime
    activityType = currentActivity.activityType

    # Check if we can insert it directly
    if currentActivityStartTime <= arrivalAtCurrentActivity <= currentActivityEndTime
        # Service times for current activity 
        newStartOfServiceTimes[idx] = arrivalAtCurrentActivity
        if activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivityEndTime
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

        # Update maximum shifts 
        maximumShiftBackward = min(maximumShiftBackward,arrivalAtCurrentActivity - currentActivityStartTime)
        maximumShiftForward = min(maximumShiftForward,currentActivityEndTime- arrivalAtCurrentActivity)

        return true, maximumShiftBackward, maximumShiftForward
    # Check if we can insert next activity by shifting route forward
    elseif arrivalAtCurrentActivity < currentActivityStartTime  && arrivalAtCurrentActivity + maximumShiftForward >= currentActivityStartTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivityStartTime
        if activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivityEndTime
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

        # Determine shift 
        shift = currentActivityStartTime - arrivalAtCurrentActivity

        # Update maximum shifts
        maximumShiftBackward = 0
        maximumShiftForward = min(maximumShiftForward - shift,currentActivityEndTime - currentActivityStartTime)

        # Update service times for previous activities 
        if firstActivity.activityType != WAITING
            newStartOfServiceTimes[1] += shift
            newEndOfServiceTimes[1] += shift
        else
            newEndOfServiceTimes[1] += shift
        end
        for i in 2:(idx-1)
            newStartOfServiceTimes[i] += shift
            newEndOfServiceTimes[i] += shift
        end

        return true, maximumShiftBackward, maximumShiftForward

    # Check if we can insert next activity be shifting route backwards 
    elseif  arrivalAtCurrentActivity > currentActivityEndTime &&  arrivalAtCurrentActivity - maximumShiftBackward <= currentActivityEndTime
        # Service times for current activity
        newStartOfServiceTimes[idx] = currentActivityEndTime
        if activityType == DEPOT 
            newEndOfServiceTimes[idx] =  newStartOfServiceTimes[idx]
        elseif activityType == WAITING
            newEndOfServiceTimes[idx] = currentActivityEndTime
        else
            newEndOfServiceTimes[idx] = newStartOfServiceTimes[idx] + serviceTimes
        end 

        # Determine shift
        shift = arrivalAtCurrentActivity - currentActivityEndTime

        # Update maximum shifts
        maximumShiftBackward = min(maximumShiftBackward - shift ,currentActivityEndTime - currentActivityStartTime)
        maximumShiftForward = 0

        # Update service times for previous activities 
        if firstActivity.activityType != WAITING
            newStartOfServiceTimes[1] -= shift
            newEndOfServiceTimes[1] -= shift
        else
            newEndOfServiceTimes[1] -= shift
        end
        for i in 2:(idx-1)
            newStartOfServiceTimes[i] -= shift
            newEndOfServiceTimes[i] -= shift
        end

        return true, maximumShiftBackward, maximumShiftForward
    else
       # println("Cannot insert activity: ", currentActivity.id)
        return false, -1, -1
    end
end


#==
 Method to check maximum ride time and update cost 
==#
function checkMaximumRideTimeAndUpdateCost(time::Array{Int,2},serviceTimes::Int,requests::Vector{Request},currentActivity::Activity,activityType::ActivityType,idx::Int,newStartOfServiceTimes::Vector{Int},newEndOfServiceTimes::Vector{Int},maximumShiftForward::Int,totalCost::Float64,pickUpIndexes::Dict{Int,Int},visitedRouteIds::Set{Int},visitedRoute::Dict{Int, Dict{String, Int}},requestsWithVisitedPickUp::Vector{Tuple{Int,Int}})

    requestId = currentActivity.requestId

    # Save pick up idx 
    if activityType  == PICKUP
        pickUpIndexes[requestId] = idx
        return true, totalCost, maximumShiftForward

    # Check maximum ride time and find new cost 
    elseif activityType == DROPOFF
        r = requests[requestId]
        isPickUpVisited = requestId in visitedRouteIds
        newEndOfServiceTimePickUp =  isPickUpVisited ? visitedRoute[requestId]["PickUpServiceStart"] + serviceTimes : newEndOfServiceTimes[pickUpIndexes[requestId]]

        # Check maximum ride time 
        if newStartOfServiceTimes[idx] - newEndOfServiceTimePickUp > r.maximumRideTime
            return false, 0,0
        end

        # If pick-up is visited update maximum shift forward 
        if isPickUpVisited
            push!(requestsWithVisitedPickUp,(requestId,idx))

            # Ensure that we do not shift more that maximim ride time 
            maximumShiftForwardTemp = r.maximumRideTime - (newStartOfServiceTimes[idx] - newEndOfServiceTimePickUp)
            maximumShiftForward = min(maximumShiftForward,maximumShiftForwardTemp)

            return true, totalCost, maximumShiftForward
        # Add cost of request
        else
            # Update total cost
            totalCost += getCostOfRequest(time,newEndOfServiceTimePickUp,newStartOfServiceTimes[idx], r.pickUpActivity.id, r.dropOffActivity.id)

            return true, totalCost, maximumShiftForward
        end
        
    end

    return true, totalCost, maximumShiftForward
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
