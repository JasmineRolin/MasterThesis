module Vehicles 

using ..TimeWindows, ..Locations

export Vehicle 

struct Vehicle 
    id::Int 
    availableTimeWindow::TimeWindow # Minutes after midnight 
    depotId::Int 
    depotLocation::Location 
    maximumRideTime::Int # Minutes 
    capacities::Dict 
    totalCapacity::Int
end


end
