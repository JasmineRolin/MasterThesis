module States 

using ..VehicleSchedules 

export State 

mutable struct State 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
end



end