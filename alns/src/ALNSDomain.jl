module ALNSDomain 

export GenericMethod
export ALNSParameter
export ALNSConfiguration
#==
 Struct to describe destroy or repair method 
==#
struct GenericMethod
    name::String 
    method::Function
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
 Struct that contains ALNS parameters 
==#
struct ALNSParameters
    timeLimit::Float64 
    decay::Float64 # How quickly to react to new score -  new_weight = old_weight*ALNSDecay + score * (1-ALNSDecay);
    startThreshold::Float64 # Start threshold for simulated annealing - (cost(trialSol) - cost(bestSol)) / cost(bestSol) < startThreshold*(1-elapsedSeconds/timeLimit)
    solCostEps::Float64 # A solution is only accepted as new global best solution if new_solution_cost < old_global_best_cost - solCostEps
    scoreAccepted::Float64 # Score given for an accepted solution
	scoreImproved::Float64 # Score given for a solution that is better than the current solution
	scoreNewGlobalBest::Float64 # Score given for a new global best solution
    # TODO: add parameters for different destroy/repair methods 

    function ALNSParameter()
        new(10.0,0.01,0.03,0.0,2.0,4.0,10.0)        
    end
end

#==
 Struct to describe current state of ALNS algorithm 
==#
mutable struct ALNSState 
    destroyWeights::Vector{Float64}
    repairWeights::Vector{Float64}
    bestSolution::Solution 
    currentSolution::Solution
end


end