module waitingstrategies

include("GeneratePredictedDemand.jl")
using .GeneratePredictedDemand
export generatePredictedDemand,generatePredictedVehiclesDemand

include("RelocateVehicleUtils.jl")
using .RelocateVehicleUtils
export determineWaitingLocation,determineActiveVehiclesPrCell

end # module waitingstrategies
