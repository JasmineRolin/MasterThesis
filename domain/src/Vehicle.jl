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

    # Constructors
    function Vehicle()
        return new(0, TimeWindow(0,0), 0, Location("",0,0), 0, Dict(), 0)
    end

    function Vehicle(id::Int, availableTimeWindow::TimeWindow, depotId::Int, depotLocation::Location, maximumRideTime::Int, capacities::Dict, totalCapacity::Int)
        return new(id, availableTimeWindow, depotId, depotLocation, maximumRideTime, capacities, totalCapacity)
    end
end


end
