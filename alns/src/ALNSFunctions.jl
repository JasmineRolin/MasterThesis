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
function rouletteWheel()
    # TODO: implement roulette wheel selection 
end

#==
 Method to calculate score of destroy or repair method 
==#
function calculateScore(parameters::ALNSParameters,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)::Float64
    # TODO: implement method to calculate score 
    # Return score 
end

#==
 Method to update weight of destroy/repair method 
==#
function updateWeights!(parameters::ALNSParameters,state::ALNSState,isAccepted::Bool, isImproved::Bool, isNewBest::Bool)
    # TODO: implement method to update weights 
    # Use calculateScore
end


end