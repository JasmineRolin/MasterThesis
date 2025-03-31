module utils

#==
 Export from TimeUtils module
==#
include("TimeUtils.jl")
using .TimeUtils 
export minutesSinceMidnight

#==
 Export from TimeUtils module
==#
include("DistanceUtils.jl")
using .DistanceUtils 
export getDistanceAndTimeMatrix, getDistanceAndTimeMatrixFromLocations

#==
 Export from InstanceReaders module
==#
include("InstanceReader.jl")
using .InstanceReaders
export readInstance
export readVehicles
export readRequests
export splitRequests


#==
 Export from CostCalculator module
==#
include("CostCalculator.jl")
using .CostCalculator
export getTotalDistanceRoute
export getTotalCostRoute
export getTotalTimeRoute
export getTotalIdleTimeRoute
export getTotalCostDistanceTimeOfSolution
export getCostOfRequest


#==
 Export from RouteUtils module
==#
include("RouteUtils.jl")
using .RouteUtils
export printRoute,printSimpleRoute, insertRequest!,checkFeasibilityOfInsertionAtPosition,printRouteHorizontal,printSolution,updateRoute!,checkFeasibilityOfInsertionInRoute

#==
    Export from SolutionUtils module   
==#
include("SolutionValidator.jl")
using .SolutionValidator
export checkSolutionFeasibility,checkRouteFeasibility

end 
