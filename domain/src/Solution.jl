module Solutions 

using ..VehicleSchedules 

export Solution 

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
    nTaxi::Int
    totalRideTime::Int
    totalViolationTW::Int
    totalDistance::Int
    idleTime::Int

end

end