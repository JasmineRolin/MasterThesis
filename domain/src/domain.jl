module domain

#==
 Export from Enums module 
==#
include("Enums.jl")
using .Enums  # Using the relative module
export RequestType,PICKUP_REQUEST,DROPOFF_REQUEST
export MobilityType,WALKING,WHEELCHAIR
export ActivityType, PICKUP, DROPOFF, WAITING, DEPOT 


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
 Export from Activitys module 
==#
include("Activity.jl")
using .Activities
export Activity,findCorrespondingId,findLoadOfActivity

#==
 Export from Requests module 
==#
include("Request.jl")
using .Requests
export Request, RequestType,MobilityType,PICKUP,DROPOFF,WALKING,WHEELCHAIR
export findTimeWindowOfRequestedPickUpTime, findTimeWindowOfDropOff, findTimeWindowOfRequestedDropOffTime, findTimeWindowOfPickUp
export findMaximumRideTime


#==
 Export from Vehicles module 
==#
include("Vehicle.jl")
using .Vehicles
export Vehicle

#==
 Export from RequestAssignment module 
==#
include("ActivityAssignment.jl")
using .ActivityAssignments
export ActivityAssignment

#==
 Export from VehicleSchedule module 
==#
include("VehicleSchedule.jl")
using .VehicleSchedules
export VehicleSchedule, findPositionOfRequest

#==
 Export from Scenario module 
==#
include("Scenario.jl")
using .Scenarios
export Scenario

#==
 Export from Solution module 
==#
include("Solution.jl")
using .Solutions
export Solution


#==
 Export from Scenario module 
==#
include("State.jl")
using .States
export State


end
