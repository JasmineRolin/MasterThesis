module offlinesolution


# Export from ConstructionHeuristic module
include("ConstructionHeuristic.jl")
using .ConstructionHeuristic
export simpleConstruction
export findFeasibleInsertionInSchedule

include("OfflineSolutionBasic.jl")
using .OfflineSolutionBasic
export offlineSolution

end 
