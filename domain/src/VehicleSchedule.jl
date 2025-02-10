module VehicleSchedules 

using ..Vehicles, ..RequestAssignments, ..TimeWindows 

export VehicleSchedule 

mutable struct VehicleSchedule 
    vehicle::Vehicle 
    route::Vector{RequestAssignment}
    activeTimeWindow::TimeWindow 
    totalDistance::Float32
    totalCost::Float32 
end 


end