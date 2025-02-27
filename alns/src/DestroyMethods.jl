module DestroyMethods

using Random, UnPack, domain, ..ALNSDomain

export randomDestroy, worstRemoval, shawRemoval, findNumberOfRequestToRemove

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
function randomDestroy!(currentState::ALNSState,parameters::ALNSParameters)
    @unpack currentSolution, assignedRequests, requestBank = currentState
    
    # Find number of requests currently in solution 
    nRequests = length(assignedRequests)

    # Find number of requests to remove 
    nRequestsToRemove = findNumberOfRequestToRemove(parameters.minPercentToDestroy,parameters.maxPercentToDestroy,nRequests)
    
    # Collect customers to remove
    customersToRemove = Set{Int}()

    # Choose requests to remove  
    for _ in 1:nRequestsToRemove
        idx = rand(1:length(assignedRequests))
        push!(customersToRemove,assignedRequests[idx])
        push!(requestBank,assignedRequests[idx])
        deleteat!(assignedRequests,idx)
    end

    # Remove requests from solution
    removeCustomers!(solution,customersToRemove)
end

#==
 Worst removal
==#
function worstRemoval()
    
end

#==
 Shaw removal
==#
function shawRemoval()
end


#==
 Method to determine number of requests to remove 
==#
function findNumberOfRequestToRemove(minPercentToDestroy::Float64,maxPercentToDestroy::Float64,nRequests::Int)::Int
    minimumNumberToRemove = max(1,round(Int,minPercentToDestroy*nRequests))
    maximumNumberToRemove = max(minimumNumberToRemove,round(Int,maxPercentToDestroy*nRequests))

    return rand(1:maximumNumberToRemove)
end


#==
 Method to remove requests
==#
function removeRequests!(solution::Solution,customersToRemove::Set{Int})   
    
    # Loop through routes and remove customers
    for schedule in solution.vehicleSchedule
        requestsToRemove = findall(activityAssignment -> activityAssignment.activity.requestId in customersToRemove, schedule)

        # Remove requests from schedule 
        [removeRequestFromSchedule!(schedule,id) for id in requestsToRemove]

    end
end

#==
 Method to remove activity at idx from route
==#
function removeRequestsFromSchedule!(time::Array{Int,Int},distance::Array{Float64,Float64},schedule::VehicleSchedule,requestsToRemove::Vector{Int})

    # Remove requests from schedule
    for requestsToRemove in requestsToRemove
        # Find positions of pick up and drop off activity   
        pickUpPosition,dropOffPosition = findPositionOfRequest(schedule,requestId)

        # Save ride time of request 
        rideTime = schedule.route[dropOffPosition].endOfServiceTime - schedule.route[pickUpPosition].startOfServiceTime

        # Remove pickup activity 
        distanceDeltaPickUp, idleTimeDeltaPickup = removeActivityFromRoute!(time,distance,schedule,pickUpPosition)

        # Remove drop off activity 
        distanceDeltaDropOff, idleTimeDeltaDropOff = removeActivityFromRoute!(time,distance,schedule,dropOffPosition-1)

        # Update KPIs
        schedule.totalDistance += distanceDeltaPickUp + distanceDeltaDropOff
        schedule.totalIdleTime += idleTimeDeltaPickup + idleTimeDeltaDropOff
        schedule.totalTime -= rideTime

        # TODO: correct
        schedule.numberOfWalking[pickUpPosition:dropOffPosition] .-= 1
        schedule.numberOfWalking[pickUpPosition:dropOffPosition] .-= 1 
    end


end

#==
 Method to remove activity from route 
==#
function removeActivityFromRoute!(time::Array{Int,Int},distance::Array{Float64,Float64},schedule::VehicleSchedule,idx::Int)

    # Retrieve activities before and after activity to remove
    route = schedule.route
    activityToRemove = route[idx]
    activityAssignmentBefore = route[idx-1]
    activityAssignmentAfter = route[idx+1]

    # Remove activity 
    distanceDelta = 0.0
    idleTimeDelta = 0
    # Extend waiting activity before activity to remove
    if activityAssignmentBefore.activityType == WAITING

        # Update waiting activity 
        oldIdleTime = activityAssignmentBefore.endOfServiceTime - activityAssignmentBefore.startOfServiceTime
        activityAssignmentBefore.endOfServiceTime = activityAssignmentAfter.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

        # Update deltas 
        deltaDistance = distance[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (activityAssignmentBefore.endOfServiceTime - activityAssignmentBefore.startOfServiceTime) - oldIdleTime

        # Delete activity
        deleteat!(route,idx)

       
    # Extend waiting activity after activity to remove
    elseif activityAssignmentAfter.activity.activityType == WAITING

        # Update waiting activity
        oldIdleTime = activityAssignmentAfter.endOfServiceTime - activityAssignmentAfter.startOfServiceTime
        activityAssignmentAfter.startOfServiceTime = activityAssignmentBefore.startOfServiceTime + time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]
       
        # Update deltas 
        deltaDistance = distance[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (activityAssignmentAfter.endOfServiceTime - activityAssignmentAfter.startOfServiceTime) - oldIdleTime

        # Delete activity 
        deleteat!(route,pickUpPosition)

    # Insert waiting activity before activity to remove
    else
        # Create waiting activity 
        startOfWaitingActivity = activityAssignmentBefore.endOfServiceTime
        endOfWaitingActivity = activityAssignmentBefore.startOfServiceTime - time[activityAssignmentBefore.activity.id,activityAssignmentAfter.activity.id]

        waitingActivity = Activity(activityAssignmentBefore.id,-1,WAITING,WALKING,activityAssignmentBefore.location,TimeWindow(startOfWaitingActivity,endOfWaitingActivity))
        waitingActivityAssignment = ActivityAssignment(waitingActivity,activityAssignmentBefore.vehicle,startOfWaitingActivity,endOfWaitingActivity)
        
        # Update deltas
        deltaDistance = distance[waitingActivityAssignment.activity.id,activityAssignmentAfter.activity.id] - distance[activityAssignmentBefore.activity.id,activityToRemove.activity.id] - distance[activityToRemove.activity.id,activityAssignmentAfter.activity.id]
        deltaIdleTime = (endOfWaitingActivity - startOfWaitingActivity)

        # Update route 
        route[idx] = waitingActivityAssignment
    end

    return distanceDelta,idleTimeDelta

end


end