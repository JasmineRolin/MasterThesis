module alns

# TODO: remove exports that are not relevant outside of module 


#==
 Import from ALNSDomain 
==#
include("ALNSDomain.jl")
using .ALNSDomain
export GenericMethod
export ALNSParameters, readParameters
export ALNSConfiguration
export ALNSState
export setMinMaxValuesALNSParameters,ALNSParametersToDict,copyALNSState

#== 
 Import from ALNSFunctions 
==#
include("ALNSFunctions.jl")
using .ALNSFunctions
export readALNSParameters
export addMethod!
export destroy!, repair!
export rouletteWheel
export calculateScore, updateWeights!
export termination, findStartTemperature, accept, updateScoreAndCount,updateWeightsAfterEndOfSegment


#==
 Import from DestroyMethods 
==#
include("DestroyMethods.jl")
using .DestroyMethods
export randomDestroy!, worstRemoval!, shawRemoval!, findNumberOfRequestToRemove, removeRequestsFromSolution!

#==
 Import from RepairMethods 
==#
include("RepairMethods.jl")
using .RepairMethods
export greedyInsertion
export regretInsertion

#==
 Import from ALNSResults
==#
include("ALNSResults.jl")
using .ALNSResults 
export ALNSResult, plotRoutes,createGantChartOfSolution,createGantChartOfRequestsAndVehicles

#==
 Import from ALNSAlgorithm
==#
include("ALNSAlgorithm.jl")
using .ALNSAlgorithm
export ALNS

#==
 Import from ALNSRunner 
==#
include("ALNSRunner.jl")
using .ALNSRunner
export runALNS



end
