module Vehicles 

using ..TimeWindows, ..Locations

export Vehicle 

struct Vehicle 
    id::Int 
    availableTimeWindow::TimeWindow
    depotLocation::Location 
    maximumRideTime::Int 
    capacities::Dict 
    totalCapacity::Int
end


end
