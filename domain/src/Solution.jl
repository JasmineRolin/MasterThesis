module Solutions 

using ..VehicleSchedules 
using ..Scenarios

export Solution

mutable struct Solution 
    vehicleSchedules::Vector{VehicleSchedule}
    totalCost::Float64
    nTaxi::Int
    totalRideTime::Int
    totalDistance::Float64
    idleTime::Int

    # Constructor
    function Solution(scenario::Scenario)
        vehicleSchedules = [VehicleSchedule(vehicle) for vehicle in scenario.vehicles]
        return new(vehicleSchedules, 0.0, 0, 0, 0, 0)
    end

    # All-argument constructor
    function Solution(vehicleSchedules::Vector{VehicleSchedule}, totalCost::Float64, nTaxi::Int, totalRideTime::Int, totalDistance::Int, idleTime::Int)
        new(vehicleSchedules, totalCost, nTaxi, totalRideTime, totalDistance, idleTime)
    end
end

end