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

end 
