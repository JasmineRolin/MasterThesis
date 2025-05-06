module waitingstrategies

global N_TIME_PERIODS = 24

include("GeneratePredictedDemand.jl")
using .GeneratePredictedDemand
export generatePredictedDemand,generatePredictedVehiclesDemand

include("RelocateVehicleUtils.jl")
using .RelocateVehicleUtils
export determineWaitingLocation,determineActiveVehiclesPrCell,determineVehicleBalancePrCell

end # module waitingstrategies
