module ALNSFunctions 

using UnPack, JSON3, domain, ..ALNSDomain, TimerOutputs

export readALNSParameters
export addMethod!
export destroy!, repair!
export rouletteWheel
export calculateScore, updateWeights!
export termination, findStartTemperature, accept, updateScoreAndCount, updateWeightsAfterEndOfSegment


#==
 Method to read parameters from file  
==#
function readALNSParameters(parametersFile::String)::ALNSParameters
    jsonData = JSON3.read(read(parametersFile, String))  # Read JSON file as a string and parse it
    return ALNSParameters(
        Float64(jsonData["timeLimit"]),
        Int(jsonData["printSegmentSize"]),
        Int(jsonData["segmentSize"]),
        Float64(jsonData["reactionFactor"]),
        Float64(jsonData["scoreAccepted"]),
        Float64(jsonData["scoreImproved"]),
        Float64(jsonData["scoreNewBest"]),
        Float64(jsonData["minPercentToDestroy"]),
        Float64(jsonData["maxPercentToDestroy"]),
        Float64(jsonData["p"]),
        Float64(jsonData["shawRemovalPhi"]),
        Float64(jsonData["shawRemovalXi"]),
        Int(jsonData["maxNumberOfIterationsWithoutImprovement"]),
        Int(jsonData["maxNumberOfIterationsWithoutNewBest"])
        )
end

#==
 Methods to add method 
==#
 function addMethod!(methods::Vector{GenericMethod},name::String, method::Function)
    push!(methods,GenericMethod(name,method))
end


#==
 Method to Destroy 
==#
function destroy!(scenario::Scenario,state::ALNSState,parameters::ALNSParameters, configuration::ALNSConfiguration;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput())::Int
    # Select method 
    destroyIdx = rouletteWheel(state.destroyWeights)

    #println("\t Destroy method: ", configuration.destroyMethods[destroyIdx].name)

    # Use method 
    configuration.destroyMethods[destroyIdx].method(scenario,state,parameters,visitedRoute = visitedRoute,TO=TO)

    return destroyIdx
end

#==
 Method to Repair  
==#
function repair!(scenario::Scenario, state::ALNSState, configuration::ALNSConfiguration;visitedRoute::Dict{Int, Dict{String, Int}}=Dict{Int, Dict{String, Int}}(),TO::TimerOutput=TimerOutput(),splitRequestBank::Bool=true)::Int  
    # Select method 
    repairIdx = rouletteWheel(state.repairWeights)

    # println("\t Repair method: ", configuration.repairMethods[repairIdx].name)

    # Use method 
    configuration.repairMethods[repairIdx].method(state,scenario,visitedRoute=visitedRoute,TO=TO,splitRequestBank=splitRequestBank)

    return repairIdx
end


#==
 Method to do roulette wheel selection 
==#
function rouletteWheel(weights::Vector{Float64})::Int
    totalWeight = sum(weights)
    r = rand() * totalWeight  # Generate a random number in [0, totalWeight]

    cumulativeSum = 0.0
    for (i, w) in enumerate(weights)
        cumulativeSum += w
        if r <= cumulativeSum
            return i  # Return the index of the selected element
        end
    end

    return length(weights)  # Fallback (should never be reached)
end


#==
 Method to calculate score of destroy or repair method 
==#
function calculateScore(scoreAccepted::Float64, scoreImproved::Float64, scoreNewBest::Float64,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)::Float64    
    score = 0 # Initialize score to 0 of no update should be made 

	if isAccepted
		score = max(score, scoreAccepted)
	end
	if isImproved
		score = max(score, scoreImproved)
	end
	if isNewBest
		score = max(score, scoreNewBest)
	end

    return score 
end

#==
 Method to update score and count of methods 
==#
function updateScoreAndCount(scoreAccepted::Float64, scoreImproved::Float64, scoreNewBest::Float64, state::ALNSState,destroyIdx::Int, repairIdx::Int, isAccepted::Bool, isImproved::Bool, isNewBest::Bool)
    # Update counts
    state.repairNumberOfUses[repairIdx] += 1
    state.destroyNumberOfUses[destroyIdx] += 1

    # Update scores 
    score = calculateScore(scoreAccepted, scoreImproved, scoreNewBest,isAccepted, isImproved, isNewBest)
    state.destroyScores[destroyIdx] += score
    state.repairScores[repairIdx] += score
end

#==
 Method to update weights of destroy/repair method 
==#
function updateWeights!(weights::Vector{Float64}, scores::Vector{Float64}, numberOfUses::Vector{Int}, reactionFactor::Float64)
    # Only update weights where numberOfUses > 0
    for i in eachindex(weights)
        if numberOfUses[i] > 0
            weights[i] = weights[i] * (1 - reactionFactor) + reactionFactor * (scores[i] / numberOfUses[i])
        end
    end
end


#==
 Method to set start temperature to use in simulated annealing 
==#
function findStartTemperature(w::Float64, solution::Solution,taxiParameter::Float64)::Float64 
    # Cost of solution without request bank 
    cost = solution.totalCost - solution.nTaxi*taxiParameter 
    
    # Find start temperature 
    return (w*cost)/0.6931
end

#==
 Method to update weights after segment 
==#
function updateWeightsAfterEndOfSegment(segmentSize::Int,state::ALNSState, reactionFactor, iteration::Int)
    if iteration % segmentSize == 0
        # Update weights of destroy methods
        updateWeights!(state.destroyWeights,state.destroyScores,state.destroyNumberOfUses,reactionFactor)

        # Update weights of repair methods
        updateWeights!(state.repairWeights,state.repairScores,state.repairNumberOfUses,reactionFactor)

        # Reset scores and counts
        nDestroy = length(state.destroyScores)
        nRepair = length(state.repairScores)
        state.destroyScores = zeros(nDestroy)
        state.repairScores = zeros(nRepair)
        state.destroyNumberOfUses = zeros(nDestroy)
        state.repairNumberOfUses = zeros(nRepair)
    end
end

#==
 Method to if ALNS should terminate
==#
function termination(startTime,timeLimit)
    elapsedTime = time() - startTime

    if elapsedTime > timeLimit
        return true
    end

    return false
end

#==
 Method to check acceptance of new solution using simulated annealing acceptance criterion 
==#
function accept(tempature::Float64,delta::Float64)
    delta = Float64(delta)
    p = exp(-delta/tempature)
    if rand() < p 
        return true,p,delta 
    end

    return false,p,delta
end

function accept(timeLimit::Float64,startTime::Float64,trialCost::Float64,bestCost::Float64)
    
    startThreshold = 1
    delta = abs(bestCost - trialCost)
    elapsedTime = time() - startTime
    if delta/bestCost < startThreshold*(1-elapsedTime/timeLimit)
        return true,startThreshold*(1-elapsedTime/timeLimit),delta/bestCost 
    end

    return false,startThreshold*(1-elapsedTime/timeLimit),delta/bestCost 
end

end