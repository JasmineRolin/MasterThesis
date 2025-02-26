module DestroyMethods

using Random, UnPack, ..ALNSDomain

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
function removeRequestsFromSchedule!(time::Array{Int,Int},schedule::Vector{ActivityAssignment},requestsToRemove::Vector{Int})

    # Remove requests from schedule
    for requestsToRemove in requestsToRemove
        pickUpPosition,dropOffPosition = findPositionOfRequest(schedule,requestId)

        # Remove pickup activity 
        # Extend waiting activity before pick up 
        if schedule[pickUpPosition-1].activity.activityType == WAITING
            schedule[pickUpPosition-1].endOfServiceTime = schedule[pickUpPosition+1].startOfServiceTime - time[schedule[pickUpPosition-1].activity.id,schedule[pickUpPosition+1].activity.id]
            # TODO: update KPIs
            deleteat!(schedule,pickUpPosition)
        # Extend waiting activity after pick up
        elseif schedule[dropOffPosition+1].activity.activityType == WAITING
            schedule[pickUpPosition+1].startOfServiceTime = schedule[pickUpPosition-1].startOfServiceTime + time[schedule[pickUpPosition-1].activity.id,schedule[pickUpPosition+1].activity.id]
            # TODO: update KPIs
            deleteat!(schedule,pickUpPosition)
        # Insert waiting activity 
        else
            
        end

        # Remove drop off activity 

    end


end


end