module States 

using ..VehicleSchedules 

export State 

mutable struct State 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
    nTaxi::Int
    totalRideTime::Int
    totalViolationTW::Int
    totalDistance::Int
    idleTime::Int

end



end