module ALNSFunctions 

using ..ALNSDomain

export readParameters
export addDestroyMethod!, addRepairMethod!
export destroy, repair
export rouletteWheel


#==
 Method to read parameters from file  
==#
 # TODO: Implement function to read parameters 
 function readParameters(parametersFile::String)::ALNSParameters
    return ALNSParameter()
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
function destroy()
    # TODO: use roulettewheel to select method and then use method 
    # Return solution and destroy method index
end

#==
 Method to Repair  
==#
function repair()
    # TODO: use roulettewheel to select method and then use method 
    # Return solution and repair method index
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
function updateWeights!(state::ALNSState,configuration::ALNSConfiguration,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)
    @unpack reactionFactor = configuration.parameters

    # Find score of destroy-repair pair 
    score = calculateScore(configuration.parameters,isAccepted,isImproved,isNewBest)

    # Update weights 


end


end