module ALNSDomain 

using domain 

export GenericMethod
export ALNSParameters
export ALNSConfiguration
export ALNSState

#==
 Struct to describe destroy or repair method 
==#
mutable struct GenericMethod
    name::String 
    method::Function
end


#==
 Struct that contains ALNS parameters 
==#
struct ALNSParameters
    timeLimit::Float64 
    reactionFactor::Float64 # How quickly to react to new score -  new_weight = old_weight*(1-reactionFactor) + score *reactionFactor;
    startThreshold::Float64 # Start threshold for simulated annealing - (cost(trialSol) - cost(bestSol)) / cost(bestSol) < startThreshold*(1-elapsedSeconds/timeLimit)
    solCostEps::Float64 # A solution is only accepted as new global best solution if new_solution_cost < old_global_best_cost - solCostEps
    scoreAccepted::Float64 # Score given for an accepted solution
	scoreImproved::Float64 # Score given for a solution that is better than the current solution
	scoreNewBest::Float64 # Score given for a new global best solution
    minPercentToDestroy::Float64 # Minimum percentage of requests to destroy
    maxPercentToDestroy::Float64 # Maximum percentage of requests to destroy
    worstRemovalP::Float64 # Probability of removing worst request

    # TODO: add parameters for different destroy/repair methods 

    function ALNSParameters( 
        timeLimit=10.0, 
        reactionFactor=0.01, 
        startThreshold=0.03, 
        solCostEps=0.0, 
        scoreAccepted=2.0, 
        scoreImproved=4.0, 
        scoreNewBest=10.0,
        minPercentToDestroy=0.1,
        maxPercentToDestroy=0.3,
        worstRemovalP=6.0
    )
        return new(timeLimit, reactionFactor, startThreshold, solCostEps, scoreAccepted, scoreImproved, scoreNewBest,minPercentToDestroy,maxPercentToDestroy,worstRemovalP)
    end
end

#==
 Struct to describe configuration of ALNS algorithm 
==#
mutable struct ALNSConfiguration
    destroyMethods::Vector{GenericMethod}
    repairMethods::Vector{GenericMethod}
    parameters::ALNSParameters

    function ALNSConfiguration(parameters::ALNSParameters)
        return new(Vector{GenericMethod}(), Vector{GenericMethod}(),parameters)
    end
end

#==
 Struct to describe current state of ALNS algorithm 
==#
mutable struct ALNSState 
    destroyWeights::Vector{Float64}
    repairWeights::Vector{Float64}
    destroyNumberOfUses::Vector{Int} # Number of times method has been used in current segment 
    repairNumberOfUses::Vector{Int} # Number of times method has been used in current segment 
    bestSolution::Solution 
    currentSolution::Solution
    requestBank::Vector{Int}
    assignedRequests::Vector{Int}

    function ALNSState(currentSolution::Solution,nDestroy::Int,nRepair::Int)
        assignedRequestsSet = Vector{Int}()
        for schedule in currentSolution.vehicleSchedules
            for activityAssignment in schedule.route
                if activityAssignment.activity.activityType == PICKUP
                    push!(assignedRequestsSet,activityAssignment.activity.requestId)
                end
            end
        end

        assignedRequests = collect(assignedRequestsSet)

        return new(zeros(nDestroy),zeros(nRepair),zeros(Int,nDestroy),zeros(Int,nRepair),currentSolution,currentSolution,Vector{Int}(),assignedRequests)
    end
end


end