module Solutions 

using ..VehicleSchedules 
using ..Scenarios

export Solution 

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float32
    nTaxi::Int
    totalRideTime::Int
    totalDistance::Int
    idleTime::Int

    # Constructor
    function Solution(scenario::Scenario)
        vehicleSchedules = [VehicleSchedule(vehicle) for vehicle in scenario.vehicles]
        return new(vehicleSchedules, 0.0, 0, 0, 0, 0)
    end
end


end