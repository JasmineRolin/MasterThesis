module States 

using ..VehicleSchedules 

export State 

mutable struct State 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32 = 0
    nTaxi::Int = 0
    totalRideTime::Int = 0
    totalDistance::Int = 0
    idleTime::Int = 0

end



end