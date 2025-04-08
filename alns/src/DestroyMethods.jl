module DestroyMethods

using Random, UnPack, LinearAlgebra, domain, utils, ..ALNSDomain

export randomDestroy!, worstRemoval!, shawRemoval!, findNumberOfRequestToRemove

#==
 Set seed each time module is reloaded
==#
function __init__()
    Random.seed!(1234)  # Ensures reproducibility each time the module is reloaded
end

#==
 Module that containts destroy methods 
==#

#==
 Random removal 
==#
function randomDestroy!(scenario::Scenario,currentState::ALNSState,parameters::ALNSParameters;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}())
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance, serviceTimes,requests = scenario
    @unpack minPercentToDestroy, maxPercentToDestroy = parameters

    if nAssignedRequests == 0
        #println("Warning: No requests available to remove.")
        return
    end
    
    # Find number of requests currently in solution 
    nRequests = length(assignedRequests)

    # Determine number of requests that cannot be moved
    notMoveRequests = Set{Int}()
    for schedule in currentSolution.vehicleSchedules
        if schedule.route[1].activity.activityType == PICKUP
            push!(notMoveRequests, schedule.route[1].activity.requestId)
        end
    end

    # Find number of requests to remove 
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy,maxPercentToDestroy,nAssignedRequests-length(notMoveRequests))
    
    # Collect customers to remove
    requestsToRemove = Set{Int}()
    possibleToRemove = setdiff(assignedRequests, notMoveRequests)

    # Choose requests to remove  
    selectedIdx = randperm(nRequests-length(notMoveRequests))[1:nRequestsToRemove]
    requestsToRemove = Set(possibleToRemove[selectedIdx])
    append!(requestBank,requestsToRemove)
    setdiff!(assignedRequests, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove
    currentState.currentSolution.totalCost += nRequestsToRemove*scenario.taxiParameter

    removeRequestsFromSolution!(time,distance,serviceTimes,requests,currentSolution,requestsToRemove,visitedRoute = visitedRoute,scenario = scenario)

end

#==
 Worst removal
==#
# TODO: check how often it is not idx == 1
function worstRemoval!(scenario::Scenario, currentState::ALNSState, parameters::ALNSParameters;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}())
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance, serviceTimes,requests = scenario
    @unpack p, minPercentToDestroy, maxPercentToDestroy = parameters

    # Find number of requests currently in solution
    if nAssignedRequests == 0
        #println("Warning: No requests available to remove.")
        return
    end

    # Determine number of requests that cannot be moved
    notMoveRequests = Set{Int}()
    for schedule in currentSolution.vehicleSchedules
        if schedule.route[1].activity.activityType == PICKUP
            push!(notMoveRequests, schedule.route[1].activity.requestId)
        end
    end
    
    # Find number of requests to remove
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy, maxPercentToDestroy, nAssignedRequests-length(notMoveRequests))
    
    # Compute cost impact for each request
    costImpacts = Dict()
    for schedule in currentSolution.vehicleSchedules
        for activityAssignment in schedule.route
            if activityAssignment.activity.activityType == PICKUP && !(activityAssignment.activity.requestId in notMoveRequests)
                pickUpPosition, dropOffPosition = findPositionOfRequest(schedule, activityAssignment.activity.requestId)
                costImpacts[activityAssignment.activity.requestId] = getCostOfRequest(time, schedule.route[pickUpPosition], schedule.route[dropOffPosition])   
            end
        end
    end
    
    # Sort requests by descending cost
    sortedRequests = [x[1] for x in sort(collect(costImpacts), by=x -> -x[2])]  # Sort by cost, highest first
    
    # Remove requests probabilistically
    requestsToRemove = Set{Int}()
    for _ in 1:nRequestsToRemove
        requestId = chooseRequest(p, sortedRequests)
        push!(requestsToRemove, requestId)
        setdiff!(sortedRequests, [requestId])
    end
    append!(requestBank, requestsToRemove)
    setdiff!(assignedRequests, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove
    currentState.currentSolution.totalCost += nRequestsToRemove *scenario.taxiParameter
        
    # Remove requests from solution
    removeRequestsFromSolution!(time, distance,serviceTimes,requests, currentSolution, requestsToRemove,visitedRoute=visitedRoute,scenario=scenario)
end



#==
 Shaw removal
==#
function shawRemoval!(scenario::Scenario, currentState::ALNSState, parameters::ALNSParameters;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}())
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance, requests,serviceTimes,requests = scenario
    @unpack p, minPercentToDestroy, maxPercentToDestroy, shawRemovalPhi, shawRemovalXi, minDriveTime, maxDriveTime, minStartOfTimeWindowPickUp, maxStartOfTimeWindowPickUp, minStartOfTimeWindowDropOff, maxStartOfTimeWindowDropOff = parameters

    # Find number of requests currently in solution
    if nAssignedRequests == 0
        #println("Warning: No requests available to remove.") #TODO Do we want it to be commented?
        return
    end

    # Determine number of requests that cannot be moved
    notMoveRequests = Set{Int}()
    for schedule in currentSolution.vehicleSchedules
        if schedule.route[1].activity.activityType == PICKUP
            push!(notMoveRequests, schedule.route[1].activity.requestId)
        end
    end

    # Find number of requests to remove 
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy, maxPercentToDestroy, nAssignedRequests-length(notMoveRequests))
     
    # Requests to remove 
    requestsToRemove = Set{Int}()

    # Randomly select a request to remove
    possibleToMove = setdiff(assignedRequests, notMoveRequests)
    chosenRequestId = rand(possibleToMove)
    chosenRequest = requests[chosenRequestId]

    push!(requestsToRemove,chosenRequestId)
    setdiff!(possibleToMove, [chosenRequestId])
    setdiff!(assignedRequests, [chosenRequestId])

    while length(requestsToRemove) < nRequestsToRemove

        # Find relatedness measure for all assigned requests 
        relatednessMeasures = Dict{Int,Float64}()
        for requestId in possibleToMove
            relatednessMeasures[requestId] = relatednessMeasure(shawRemovalPhi,shawRemovalXi,time,maxDriveTime,minDriveTime,minStartOfTimeWindowPickUp,maxStartOfTimeWindowPickUp,minStartOfTimeWindowDropOff,maxStartOfTimeWindowDropOff,chosenRequest,requests[requestId]) 
        end

        # Sort array of not chosen requests according to relatedness measure
        sortedRequests = [x[1] for x in sort(collect(relatednessMeasures), by=x -> -x[2])]

        # Select request to remove (probabilistically)
        requestId = chooseRequest(p, sortedRequests)

        # Update lists 
        push!(requestsToRemove,requestId)
        setdiff!(possibleToMove, [requestId])
        setdiff!(assignedRequests, [requestId])

        # Choose request 
        chosenRequestId = rand(requestsToRemove)
        chosenRequest = requests[chosenRequestId]
    end
    append!(requestBank, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove
    currentState.currentSolution.totalCost += nRequestsToRemove *scenario.taxiParameter

    # Remove requests 
    removeRequestsFromSolution!(time, distance, serviceTimes,requests,currentSolution, requestsToRemove,visitedRoute = visitedRoute,scenario = scenario)
end

#==
 Method to find relatedness measure between two requests 
==#
function relatednessMeasure(shawRemovalPhi::Float64, shawRemovalXi::Float64, time::Array{Int,2}, maxDriveTime::Float64, minDriveTime::Float64, minStartOfTimeWindowPickUp::Float64,maxStartOfTimeWindowPickUp::Float64,minStartOfTimeWindowDropOff::Float64,maxStartOfTimeWindowDropOff::Float64,request1::Request,request2::Request)

    # Direct drive time relatedness 
    normalizedDriveTimePickUp = (Float64(time[request1.pickUpActivity.id,request2.pickUpActivity.id]) - minDriveTime)/(maxDriveTime - minDriveTime)
    normalizedDriveTimeDropOff = (Float64(time[request1.dropOffActivity.id,request2.dropOffActivity.id]) - minDriveTime)/(maxDriveTime - minDriveTime)
    driveTimeRelatedness = normalizedDriveTimePickUp + normalizedDriveTimeDropOff

    # Time window relatedness
    normalizationTimeWindowPickUp = abs((Float64(request1.pickUpActivity.timeWindow.startTime) - minStartOfTimeWindowPickUp)/(maxStartOfTimeWindowPickUp - minStartOfTimeWindowPickUp) - (Float64(request2.pickUpActivity.timeWindow.startTime) - minStartOfTimeWindowPickUp)/(maxStartOfTimeWindowPickUp - minStartOfTimeWindowPickUp))
    normalizationTimeWindowDropOff = abs((Float64(request1.dropOffActivity.timeWindow.startTime) - minStartOfTimeWindowDropOff)/(maxStartOfTimeWindowDropOff - minStartOfTimeWindowDropOff) - (Float64(request2.dropOffActivity.timeWindow.startTime) - minStartOfTimeWindowDropOff)/(maxStartOfTimeWindowDropOff - minStartOfTimeWindowDropOff))
    timeWindowRelatedness = normalizationTimeWindowPickUp + normalizationTimeWindowDropOff

    return shawRemovalPhi*driveTimeRelatedness + shawRemovalXi*timeWindowRelatedness
end


#==
 Method to determine number of requests to remove 
==#
function findNumberOfRequestToRemove(minPercentToDestroy::Float64,maxPercentToDestroy::Float64,nRequests::Int)::Int
    minimumNumberToRemove = max(1,round(Int,minPercentToDestroy*nRequests))
    maximumNumberToRemove = max(minimumNumberToRemove,round(Int,maxPercentToDestroy*nRequests))

    return min(nRequests,rand(minimumNumberToRemove:maximumNumberToRemove))
end

#==
 Choose request in sorted list 
==#
function chooseRequest(p::Float64, sortedRequests::Vector{Int})::Int
    y = rand()  # Random number in [0,1]
    idx = round(Int, y^p * length(sortedRequests))  # Skewed selection
    idx = clamp(idx, 1, length(sortedRequests))  # Ensure valid index
    return sortedRequests[idx]
end

#==
 Method to remove requests
==#
function removeRequestsFromSolution!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},solution::Solution,requestsToRemove::Set{Int};visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),scenario::Scenario=Scenario())   
    # Create a mutable copy of requestsToRemove
    remainingRequests = copy(requestsToRemove)

    # Loop through routes and remove customers
    for schedule in solution.vehicleSchedules
        if isempty(remainingRequests)
            break  # Exit early if all requests are removed
        end

        # Retrieve requests to remove in schedule
        requestsToRemoveInSchedule = map(a -> a.activity.requestId, filter(a -> a.activity.requestId in remainingRequests && a.activity.activityType == PICKUP , schedule.route))
    
        if !isempty(requestsToRemoveInSchedule)
            # Update solution KPIs
            solution.totalDistance -= schedule.totalDistance
            solution.totalIdleTime -= schedule.totalIdleTime
            solution.totalCost -= schedule.totalCost
            solution.totalRideTime -= schedule.totalTime

            # Remove requests from schedule 
            removeRequestsFromSchedule!(time,distance,serviceTimes,requests,schedule,requestsToRemoveInSchedule,visitedRoute,scenario) 

            # Update solution KPIs
            solution.totalDistance += schedule.totalDistance
            solution.totalIdleTime += schedule.totalIdleTime
            solution.totalCost += schedule.totalCost
            solution.totalRideTime += schedule.totalTime

            # Update remaining requests
            setdiff!(remainingRequests, requestsToRemoveInSchedule)
        end
    end
end

#==
 Method to remove list of requests from schedule
==#
function removeRequestsFromSchedule!(time::Array{Int,2},distance::Array{Float64,2},serviceTimes::Int,requests::Vector{Request},schedule::VehicleSchedule,requestsToRemove::Vector{Int},visitedRoute::Dict{Int, Dict{String, Int}},scenario::Scenario)

    # Remove requests from schedule
    for requestToRemove in requestsToRemove
        # Find positions of pick up and drop off activity   
        pickUpPosition,dropOffPosition = findPositionOfRequest(schedule,requestToRemove)

        # Remove pickup activity 
        routeReductionPickUp = removeActivityFromRoute!(time,schedule,pickUpPosition)

        # Remove drop off activity 
        routeReductionDropOff = removeActivityFromRoute!(time,schedule,dropOffPosition-routeReductionPickUp)

        # Check if vehicle schedule is empty 
        if isVehicleScheduleEmpty(schedule)
            # Update schedule KPIs
            schedule.totalDistance = 0.0
            schedule.totalIdleTime = 0
            schedule.totalCost = 0.0
            schedule.totalTime = 0
            schedule.numberOfWalking = [0,0]

            # Update route 
            schedule.route[1].startOfServiceTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].endOfServiceTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].activity.timeWindow.startTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].activity.timeWindow.endTime = schedule.vehicle.availableTimeWindow.endTime
            schedule.route[end].activity.timeWindow.startTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[end].activity.timeWindow.endTime = schedule.vehicle.availableTimeWindow.endTime
            schedule.route = [schedule.route[1],schedule.route[end]]

            return
        else
            schedule.numberOfWalking[pickUpPosition:dropOffPosition-1] .-= 1
            if routeReductionPickUp == 1
                deleteat!(schedule.numberOfWalking,pickUpPosition)
            elseif routeReductionPickUp == 2
                deleteat!(schedule.numberOfWalking,pickUpPosition) # Delete pickup activity
                deleteat!(schedule.numberOfWalking,pickUpPosition) # Delete waiting activity after pick up 
            end

            if routeReductionDropOff == 1
                deleteat!(schedule.numberOfWalking,dropOffPosition-routeReductionPickUp)
            elseif routeReductionDropOff == 2
                deleteat!(schedule.numberOfWalking,dropOffPosition-routeReductionPickUp) # Delete drop off activity
                deleteat!(schedule.numberOfWalking,dropOffPosition-routeReductionPickUp) # Delete waiting activity after drop off 
            end 

        end
    end

    # TODO: remocve 
    totalCost = getTotalCostRouteOnline(time,schedule.route,visitedRoute,serviceTimes)
    totalDistance = getTotalDistanceRoute(schedule.route,distance)
    totalIdleTime = getTotalIdleTimeRoute(schedule.route)
    totalTime = duration(schedule.activeTimeWindow)

    # Update active time window 
    schedule.activeTimeWindow.startTime = schedule.route[1].startOfServiceTime
    schedule.activeTimeWindow.endTime = schedule.route[end].endOfServiceTime

    # Update KPIs 
    schedule.totalDistance = totalDistance 
    schedule.totalIdleTime = totalIdleTime
    schedule.totalCost = totalCost
    schedule.totalTime = totalTime

    feasible,_ = checkRouteFeasibilityOnline(scenario,schedule,visitedRoute)
    if !feasible
        println("remove requestr from schedule before update")
        printRouteHorizontal(schedule)
    end

    copyScehdule = deepcopy(schedule)

    # Repair route 
    feasible, newStartOfServiceTimes, newEndOfServiceTimes,waitingActivitiesToDelete,totalCost, totalDistance, totalIdleTime, totalTime = checkFeasibilityOfInsertionInRoute(time,distance,serviceTimes,requests,-1,schedule.route,visitedRoute = visitedRoute)

    # Shift route
    if feasible 
        for (i,a) in enumerate(schedule.route)
            a.startOfServiceTime = newStartOfServiceTimes[i]
            a.endOfServiceTime = newEndOfServiceTimes[i]

            if a.activity.activityType == WAITING
                if newStartOfServiceTimes[i] == 360 && newEndOfServiceTimes[i] == 360
                   printRouteHorizontal(schedule)
                   println(newStartOfServiceTimes)
                   println(newEndOfServiceTimes)
                end

                a.activity.timeWindow.startTime = newStartOfServiceTimes[i]
                a.activity.timeWindow.endTime = newEndOfServiceTimes[i]
            end
        end

        # Delete waiting activities 
        deleteat!(schedule.route,waitingActivitiesToDelete)   

        # Update capacities 
        deleteat!(schedule.numberOfWalking,waitingActivitiesToDelete)
    else 
        totalCost = getTotalCostRouteOnline(time,schedule.route,visitedRoute,serviceTimes)
        totalDistance = getTotalDistanceRoute(schedule.route,distance)
        totalIdleTime = getTotalIdleTimeRoute(schedule.route)
        totalTime = duration(schedule.activeTimeWindow)
    end


    # Update active time window 
    schedule.activeTimeWindow.startTime = schedule.route[1].startOfServiceTime
    schedule.activeTimeWindow.endTime = schedule.route[end].endOfServiceTime

    # Update KPIs 
    schedule.totalDistance = totalDistance 
    schedule.totalIdleTime = totalIdleTime
    schedule.totalCost = totalCost
    schedule.totalTime = totalTime

    feasible,_ = checkRouteFeasibilityOnline(scenario,schedule,visitedRoute)
    if !feasible
        println("remove requestr from schedule after update")
        println(newStartOfServiceTimes)
        println(newEndOfServiceTimes)
        printRouteHorizontal(schedule)

        println("===>>>> BEFORE UPDATE")
        printRouteHorizontal(copyScehdule)
    end


    return
end

#==
 Method to remove activity from route 
==#
function removeActivityFromRoute!(time::Array{Int,2},schedule::VehicleSchedule,idx::Int)

    # TODO: needs to be updated when waiting strategies are implemented 

    # Retrieve activities before and after activity to remove
    route = schedule.route
    activityAssignmentBefore = route[idx-1]
    activityAssignmentAfter = route[idx+1]

    # How much did the route length reduce 
    routeReduction = 0

    # Remove activity 
    # If there is a waiting activity both before and after 
    if activityAssignmentBefore.activity.activityType == WAITING && activityAssignmentAfter.activity.activityType == WAITING

        # Update waiting activity 
        activityAssignemntAfterWaiting = route[idx+2]
        activityAssignmentBefore.endOfServiceTime = activityAssignemntAfterWaiting.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignemntAfterWaiting.activity.id]
        activityAssignmentBefore.activity.timeWindow.endTime = activityAssignmentBefore.endOfServiceTime

        # Delete activity
        deleteat!(route,idx) # Delete activity 
        deleteat!(route,idx) # Delete waiting activity

        routeReduction = 2

    # Extend waiting activity before activity to remove
    elseif activityAssignmentBefore.activity.activityType == WAITING
        # Update waiting activity 
        activityAssignmentBefore.endOfServiceTime = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentBefore.activity.timeWindow.endTime = activityAssignmentBefore.endOfServiceTime

        # Delete activity
        deleteat!(route,idx)

        routeReduction = 1

    # Extend waiting activity after activity to remove
    elseif activityAssignmentAfter.activity.activityType == WAITING
        # Update waiting activity
        activityAssignmentAfter.startOfServiceTime = activityAssignmentBefore.endOfServiceTime + time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentAfter.activity.timeWindow.startTime = activityAssignmentAfter.startOfServiceTime
        
        # Delete activity 
        deleteat!(route,idx)

        routeReduction = 1

    elseif activityAssignmentBefore.activity.activityType == DEPOT
        # Update depot 
        activityAssignmentBefore.startOfServiceTime = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentBefore.endOfServiceTime = activityAssignmentBefore.startOfServiceTime

        schedule.activeTimeWindow.startTime = activityAssignmentBefore.startOfServiceTime
        
        # Delete activity 
        deleteat!(route,idx)

        routeReduction = 1

    elseif activityAssignmentAfter.activity.activityType == DEPOT
        # Update depot 
        activityAssignmentAfter.startOfServiceTime = activityAssignmentBefore.endOfServiceTime + time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentAfter.endOfServiceTime = activityAssignmentAfter.startOfServiceTime

        schedule.activeTimeWindow.endTime = activityAssignmentAfter.startOfServiceTime
        
        # Delete activity 
        deleteat!(route,idx)

        routeReduction = 1

    # Insert waiting activity before activity to remove
    else
        # Create waiting activity 
        startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
        endOfWaitingActivity = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

        waitingActivity = Activity(activityAssignmentBefore.activity.id,-1,WAITING,activityAssignmentBefore.activity.location,TimeWindow(startOfWaitingActivity,endOfWaitingActivity))
        waitingActivityAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity)
                
        # Update route 
        route[idx] = waitingActivityAssignment
    end

    return routeReduction

end


end