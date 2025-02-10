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
include("DistanceMatrix.jl")
using .DistanceMatrix 
export getDistanceMatrix

end 
