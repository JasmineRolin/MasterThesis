module ALNSFunctions 

using UnPack, JSON3, domain, ..ALNSDomain

export readALNSParameters
export addDestroyMethod!, addRepairMethod!
export destroy!, repair!
export rouletteWheel
export calculateScore, updateWeights!


#==
 Method to read parameters from file  
==#
 # TODO: Implement function to read parameters 
 function readALNSParameters(parametersFile::String)::ALNSParameters
    jsonData = JSON3.read(read(parametersFile, String))  # Read JSON file as a string and parse it
    return ALNSParameters(
        Float64(jsonData["timeLimit"]),
        Float64(jsonData["reactionFactor"]),
        Float64(jsonData["startThreshold"]),
        Float64(jsonData["solCostEps"]),
        Float64(jsonData["scoreAccepted"]),
        Float64(jsonData["scoreImproved"]),
        Float64(jsonData["scoreNewBest"])
    )
    
end

#==
 Methods to add destroy and repair methods to configuration 
==#
# Method to add destroy method to configuration
 function addDestroyMethod!(configuration::ALNSConfiguration,name::String, method::Function)
    push!(configuration.destroyMethods,GenericMethod(name,method))
end

# Method to add repair method to configuration
function addRepairMethod!(configuration::ALNSConfiguration,name::String, method::Function)
    push!(configuration.repairMethods,GenericMethod(name,method))
end


#==
 Method to Destroy 
==#
function destroy!(nRequests::Int,configuration::ALNSConfiguration,parameters::ALNSParameters,state::ALNSState)::Int
    # Select method 
    destroyIdx = rouletteWheel(state.destroyWeights)

    # Update count 
    state.destroyNumberOfUses[destroyIdx] += 1

    # Use method 
    configuration.destroyMethods[destroyIdx].method(nRequests,state,parameters)

    return destroyIdx
end

#==
 Method to Repair  
==#
function repair!(configuration::ALNSConfiguration,parameters::ALNSParameters,state::ALNSState,solution::Solution)::Int
    # Select method 
    repairIdx = rouletteWheel(state.repairWeights)

    # Update count 
    state.repairNumberOfUses[repairIdx] += 1

    # Use method 
    configuration.repairMethods[repairIdx].method(solution,parameters)

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
function calculateScore(parameters::ALNSParameters,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)::Float64
    @unpack scoreAccepted, scoreImproved, scoreNewBest = parameters
    
    score = 1.0 # Initialize score to 1 of no update should be made 

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
 Method to update weight of destroy/repair method 
==#
function updateWeights!(state::ALNSState,configuration::ALNSConfiguration,destroyIdx::Int, repairIdx::Int,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)
    @unpack reactionFactor = configuration.parameters

    # Find score of destroy-repair pair 
    score = calculateScore(configuration.parameters,isAccepted,isImproved,isNewBest)

    # Update weights 
    state.destroyWeights[destroyIdx] = state.destroyWeights[destroyIdx]*(1-reactionFactor) + reactionFactor*(score/state.destroyNumberOfUses[destroyIdx])
    state.repairWeights[repairIdx] = state.repairWeights[repairIdx]*(1-reactionFactor) + reactionFactor*(score/state.repairNumberOfUses[repairIdx])
end


end