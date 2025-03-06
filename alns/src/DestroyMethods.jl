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
function randomDestroy!(scenario::Scenario,currentState::ALNSState,parameters::ALNSParameters)
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance = scenario
    @unpack minPercentToDestroy, maxPercentToDestroy = parameters

    if nAssignedRequests == 0
        println("Warning: No requests available to remove.")
        return
    end
    
    # Find number of requests currently in solution 
    nRequests = length(assignedRequests)

    # Find number of requests to remove 
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy,maxPercentToDestroy,nAssignedRequests)
    
    # Collect customers to remove
    requestsToRemove = Set{Int}()

    # Choose requests to remove  
    selectedIdx = randperm(nRequests)[1:nRequestsToRemove]
    requestsToRemove = Set(assignedRequests[selectedIdx])
    append!(requestBank,requestsToRemove)
    setdiff!(assignedRequests, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove

    println("==========> Removing requests: ",requestsToRemove)

    # Remove requests from solution
    removeRequestsFromSolution!(time,distance,currentSolution,requestsToRemove)
end

#==
 Worst removal
==#
# TODO: check how often it is not idx == 1
function worstRemoval!(scenario::Scenario, currentState::ALNSState, parameters::ALNSParameters)
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance = scenario
    @unpack p, minPercentToDestroy, maxPercentToDestroy = parameters
    
    # Find number of requests currently in solution
    if nAssignedRequests == 0
        println("Warning: No requests available to remove.")
        return
    end
    
    # Find number of requests to remove
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy, maxPercentToDestroy, nAssignedRequests)
    println("nRequestsToRemove: ", nRequestsToRemove)
    
    # Compute cost impact for each request
    costImpacts = Dict()
    for schedule in currentSolution.vehicleSchedules
        for activityAssignment in schedule.route
            if activityAssignment.activity.activityType == PICKUP
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
        println(sortedRequests)
    end
    append!(requestBank, requestsToRemove)
    setdiff!(assignedRequests, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove
    
    println("==========> Removing requests: ", requestsToRemove)
    
    # Remove requests from solution
    removeRequestsFromSolution!(time, distance, currentSolution, requestsToRemove)
end



#==
 Shaw removal
==#
function shawRemoval!(scenario::Scenario, currentState::ALNSState, parameters::ALNSParameters)
    @unpack currentSolution, assignedRequests, nAssignedRequests, requestBank = currentState
    @unpack time, distance, requests = scenario
    @unpack p, minPercentToDestroy, maxPercentToDestroy, shawRemovalPhi, shawRemovalXi, minDriveTime, maxDriveTime, minStartOfTimeWindowPickUp, maxStartOfTimeWindowPickUp, minStartOfTimeWindowDropOff, maxStartOfTimeWindowDropOff = parameters

    # Find number of requests currently in solution
    if nAssignedRequests == 0
        println("Warning: No requests available to remove.")
        return
    end

    # Find number of requests to remove 
    nRequestsToRemove = findNumberOfRequestToRemove(minPercentToDestroy, maxPercentToDestroy, nAssignedRequests)
     
    # Requests to remove 
    requestsToRemove = Set{Int}()

    # Randomly select a request to remove
    chosenRequestId = rand(assignedRequests)
    chosenRequest = requests[chosenRequestId]

    push!(requestsToRemove,chosenRequestId)
    setdiff!(assignedRequests, [chosenRequestId])

    while length(requestsToRemove) < nRequestsToRemove

        # Find relatedness measure for all assigned requests 
        relatednessMeasures = Dict{Int,Float64}()
        for requestId in assignedRequests
            relatednessMeasures[requestId] = relatednessMeasure(shawRemovalPhi,shawRemovalXi,time,maxDriveTime,minDriveTime,minStartOfTimeWindowPickUp,maxStartOfTimeWindowPickUp,minStartOfTimeWindowDropOff,maxStartOfTimeWindowDropOff,chosenRequest,requests[requestId]) 
        end

        # Sort array of not chosen requests according to relatedness measure
        sortedRequests = [x[1] for x in sort(collect(relatednessMeasures), by=x -> -x[2])]

        # Select request to remove (probabilistically)
        requestId = chooseRequest(p, sortedRequests)

        # Update lists 
        push!(requestsToRemove,requestId)
        setdiff!(assignedRequests, [requestId])

        # Choose request 
        chosenRequestId = rand(requestsToRemove)
        chosenRequest = requests[chosenRequestId]
    end
    append!(requestBank, requestsToRemove)
    currentState.nAssignedRequests -= nRequestsToRemove
    currentState.currentSolution.nTaxi += nRequestsToRemove

    println("==========> Removing requests: ", requestsToRemove)

    # Remove requests 
    removeRequestsFromSolution!(time, distance, currentSolution, requestsToRemove)
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
function removeRequestsFromSolution!(time::Array{Int,2},distance::Array{Float64,2},solution::Solution,requestsToRemove::Set{Int})   

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
            # Remove requests from schedule 
            distanceDelta, idleTimeDelta, costDelta, rideTimeDelta = removeRequestsFromSchedule!(time,distance,schedule,requestsToRemoveInSchedule) 

            # Update solution KPIs
            solution.totalDistance += distanceDelta
            solution.totalIdleTime += idleTimeDelta
            solution.totalCost += costDelta
            solution.totalRideTime += rideTimeDelta

            # Update remaining requests
            setdiff!(remainingRequests, requestsToRemoveInSchedule)
        end
    end
end

#==
 Method to remove list of requests from schedule
==#
function removeRequestsFromSchedule!(time::Array{Int,2},distance::Array{Float64,2},schedule::VehicleSchedule,requestsToRemove::Vector{Int})

    distanceDelta = 0.0
    idleTimeDelta = 0
    costDelta = 0.0
    rideTimeDelta = 0.0
    # Remove requests from schedule
    for requestToRemove in requestsToRemove
        # Find positions of pick up and drop off activity   
        pickUpPosition,dropOffPosition = findPositionOfRequest(schedule,requestToRemove)
        mobilityType = schedule.route[pickUpPosition].mobilityAssignment

        # Save cost of request 
        cost = getCostOfRequest(time,schedule.route[pickUpPosition],schedule.route[dropOffPosition])

        # Remove pickup activity 
        distanceDeltaPickUp, idleTimeDeltaPickup, routeReductionPickUp = removeActivityFromRoute!(time,distance,schedule,pickUpPosition)

        # Remove drop off activity 
        distanceDeltaDropOff, idleTimeDeltaDropOff, routeReductionDropOff = removeActivityFromRoute!(time,distance,schedule,dropOffPosition-routeReductionPickUp)

        # Check if vehicle schedule is empty 
        if isVehicleScheduleEmpty(schedule)
            # Update deltas
            distanceDelta -= schedule.totalDistance
            idleTimeDelta -= schedule.totalIdleTime
            costDelta -= schedule.totalCost
            rideTimeDelta -= schedule.totalTime

            # Update schedule KPIs
            schedule.totalDistance = 0.0
            schedule.totalIdleTime = 0
            schedule.totalCost = 0.0
            schedule.totalTime = 0
            schedule.numberOfWalking = [0,0]
            schedule.numberOfWheelchair = [0,0]

            # Update route 
            schedule.route[1].startOfServiceTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].endOfServiceTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].activity.timeWindow.startTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[1].activity.timeWindow.endTime = schedule.vehicle.availableTimeWindow.endTime
            schedule.route[end].activity.timeWindow.startTime = schedule.vehicle.availableTimeWindow.startTime
            schedule.route[end].activity.timeWindow.endTime = schedule.vehicle.availableTimeWindow.endTime

            schedule.route = [schedule.route[1],schedule.route[end]]
        else

            # Update KPIs
            schedule.totalDistance += distanceDeltaPickUp + distanceDeltaDropOff
            schedule.totalIdleTime += idleTimeDeltaPickup + idleTimeDeltaDropOff
            schedule.totalCost -= cost

            distanceDelta += distanceDeltaPickUp + distanceDeltaDropOff
            idleTimeDelta += idleTimeDeltaPickup + idleTimeDeltaDropOff
            costDelta -= cost

            if mobilityType == WALKING
                schedule.numberOfWalking[pickUpPosition:dropOffPosition-1] .-= 1
            else
                schedule.numberOfWheelchair[pickUpPosition:dropOffPosition-1] .-= 1
            end
            if routeReductionPickUp == 1
                deleteat!(schedule.numberOfWalking,pickUpPosition)
                deleteat!(schedule.numberOfWheelchair,pickUpPosition)
            end
            if routeReductionDropOff == 1
                deleteat!(schedule.numberOfWalking,dropOffPosition-routeReductionPickUp)
                deleteat!(schedule.numberOfWheelchair,dropOffPosition-routeReductionPickUp)
            end 

        end
    end

    return distanceDelta, idleTimeDelta, costDelta, rideTimeDelta
end

#==
 Method to remove activity from route 
==#
function removeActivityFromRoute!(time::Array{Int,2},distance::Array{Float64,2},schedule::VehicleSchedule,idx::Int)

    # TODO: needs to be updated when waiting strategies are implemented 
    # TODO: jas - remove double waiting activities 

    # Retrieve activities before and after activity to remove
    route = schedule.route
    activityToRemove = route[idx]
    activityAssignmentBefore = route[idx-1]
    activityAssignmentAfter = route[idx+1]

    # How much did the route length reduce 
    routeReduction = 0

    # Remove activity 
    deltaDistance = 0.0
    deltaIdleTime = 0
    # Extend waiting activity before activity to remove
    if activityAssignmentBefore.activity.activityType == WAITING

        # Update waiting activity 
        oldIdleTime = activityAssignmentBefore.endOfServiceTime - activityAssignmentBefore.startOfServiceTime
        activityAssignmentBefore.endOfServiceTime = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentBefore.activity.timeWindow.endTime = activityAssignmentBefore.endOfServiceTime

        # Update deltas 
        deltaDistance = distance[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (activityAssignmentBefore.endOfServiceTime - activityAssignmentBefore.startOfServiceTime) - oldIdleTime

        # Delete activity
        deleteat!(route,idx)

        routeReduction = 1

    # Extend waiting activity after activity to remove
    elseif activityAssignmentAfter.activity.activityType == WAITING

        # Update waiting activity
        oldIdleTime = activityAssignmentAfter.endOfServiceTime - activityAssignmentAfter.startOfServiceTime
        activityAssignmentAfter.startOfServiceTime = activityAssignmentBefore.endOfServiceTime + time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
        activityAssignmentAfter.activity.timeWindow.startTime = activityAssignmentAfter.startOfServiceTime
        
        # Update deltas 
        deltaDistance = distance[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (activityAssignmentAfter.endOfServiceTime - activityAssignmentAfter.startOfServiceTime) - oldIdleTime

        # Delete activity 
        deleteat!(route,idx)

        routeReduction = 1

    # Insert waiting activity before activity to remove
    else
        # Create waiting activity 
        startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
        endOfWaitingActivity = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

        waitingActivity = Activity(activityAssignmentBefore.activity.id,-1,WAITING,WALKING,activityAssignmentBefore.activity.location,TimeWindow(startOfWaitingActivity,endOfWaitingActivity))
        waitingActivityAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity,WALKING)
        
        # Update deltas
        deltaDistance = distance[waitingActivityAssignment.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (endOfWaitingActivity - startOfWaitingActivity)

        # Update route 
        route[idx] = waitingActivityAssignment
    end

    return deltaDistance,deltaIdleTime, routeReduction

end


end