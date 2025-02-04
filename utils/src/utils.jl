module utils

#==
 Export from TimeUtils module
==#
include("TimeUtils.jl")
using .TimeUtils 
export minutesSinceMidnight 

end 
