module Solutions 

using ..VehicleSchedules 

export Solution 

struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
end

end