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
 Export from Requests module 
==#
include("Request.jl")
using .Requests
export Request, RequestType,MobilityType,PICKUP,DROPOFF,WALKING,WHEELCHAIR


#==
 Export from Vehicles module 
==#
include("Vehicle.jl")
using .Vehicles
export Vehicle

#==
 Export from RequestAssignment module 
==#
include("RequestAssignment.jl")
using .RequestAssignments
export RequestAssignment

#==
 Export from VehicleSchedule module 
==#
include("VehicleSchedule.jl")
using .VehicleSchedules
export VehicleSchedule

#==
 Export from Solution module 
==#
include("Solution.jl")
using .Solutions
export Solution

#==
 Export from Scenario module 
==#
include("Scenario.jl")
using .Scenarios
export Scenario

end
