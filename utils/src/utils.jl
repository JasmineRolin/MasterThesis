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
export getDistanceAndTimeMatrix

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
 Export from costCalculator module
==#
include("costCalculator.jl")
using .costCalculator
export getTotalDistanceRoute
export getTotalCostRoute
export getTotalTimeRoute

end 
