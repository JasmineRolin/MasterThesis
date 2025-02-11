module Solutions 

using ..VehicleSchedules 

export Solution 

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
    nTaxi::Int
    totalRideTime::Int
    totalViolationTW::Int
    totalDistance::Float32
    idleTime::Int

end

end