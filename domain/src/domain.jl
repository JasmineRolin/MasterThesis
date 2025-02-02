module domain

#==
 Export from Locations module 
==#
include("Location.jl")
using .Locations  # Using the relative module
export Location

#==
 Export from TimeWindows module 
 ==#
include("TimeWindow.jl")
using .TimeWindows
export TimeWindow, duration

#==
 Export from Requests modile 
==#
include("Request.jl")
using .Requests
export Request

end
