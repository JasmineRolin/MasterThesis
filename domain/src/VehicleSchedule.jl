module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows 

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float32
    totalCost::Float32 

    #Constructor
    function VehicleSchedule(vehicle::Vehicle)
        # Create empty VehicleSchedule objects
        return new(vehicle, Vector{ActivityAssignment}(), TimeWindow(0, 0), 0.0, 0.0) 
    end

end 



end