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
 Method to remove customer
==#
function removeCustomers!(solution::Solution,customersToRemove::Set{Int})   
    
end



end