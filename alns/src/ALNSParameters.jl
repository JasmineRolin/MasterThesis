module ALNSParameters 

export ALNSParameter

#==
 Struct that contains ALNS parameters 
==#

# TODO: e.g. time limit, limit for accepted solutions 

struct ALNSParameter
    timeLimit::Int 
    decay::Float64 # How quickly to react to new score -  new_weight = old_weight*ALNSDecay + score * (1-ALNSDecay);
    startThreshold::Float64 # Start threshold for simulated annealing - (cost(trialSol) - cost(bestSol)) / cost(bestSol) < startThreshold*(1-elapsedSeconds/timeLimit)
    solCostEps::Float64 # A solution is only accepted as new global best solution if new_solution_cost < old_global_best_cost - solCostEps
    scoreAccepted::Float64 # Score given for an accepted solution
	scoreImproved::Float64 # Score given for a solution that is better than the current solution
	scoreNewGlobalBest::Float64 # Score given for a new global best solution

end



end 