module Vehicles 

using ..TimeWindows, ..Locations

export Vehicle, copyVehicle 

mutable struct Vehicle 
    id::Int 
    availableTimeWindow::TimeWindow # Minutes after midnight 
    depotId::Int 
    depotLocation::Location 
    maximumRideTime::Int # Minutes 
    totalCapacity::Int

    # Constructors
    function Vehicle()
        return new(0, TimeWindow(0,0), 0, Location("",0,0), 0, 0)
    end

    function Vehicle(id::Int, availableTimeWindow::TimeWindow, depotId::Int, depotLocation::Location, maximumRideTime::Int, totalCapacity::Int)
        return new(id, availableTimeWindow, depotId, depotLocation, maximumRideTime, totalCapacity)
    end
end

function copyVehicle(v::Vehicle)
    return Vehicle(
        v.id,
        copyTimewindow(v.availableTimeWindow),
        v.depotId,
        copyLocation(v.depotLocation),
        v.maximumRideTime,
        v.totalCapacity
    )
end

end
