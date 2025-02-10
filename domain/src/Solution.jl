module Solutions 

using ..VehicleSchedules 

export Solution 

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
end

end