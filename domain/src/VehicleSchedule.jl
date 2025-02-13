module VehicleSchedules 

using ..Vehicles, ..ActivityAssignments, ..TimeWindows 

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{ActivityAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float32
    totalCost::Float32 
end 


end